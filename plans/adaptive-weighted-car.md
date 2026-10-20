# Plan: adaptive weighted CAR (Khorasani et al. 2019) as an optional derived-signal step

## Context

The owner asked whether the artifact removal in Khorasani, Shalchyan & Daliri 2019, "Adaptive
Artifact Removal From Intracortical Channels for Accurate Decoding of a Force Signal in Freely
Moving Rats" (*Front. Neurosci.* 13:350, doi:10.3389/fnins.2019.00350), can be an optional
preprocessing step.

The method ("weighted CAR") models each channel as z_i(t) = s_i(t) + w_i(t)^T n(t). Here n(t)
holds the CAR (the mean of all channels) and its previous M-1 values. A Kalman filter tracks each
channel's weights w_i sample by sample (eqs. 6-8: w(t+1) = alpha*w(t) + lambda, process
covariance V, observation variance q). The output is s_hat_i = z_i - w_hat_i^T n.

## Decisions made with the owner (2026-10-15)

| Question | Answer |
| --- | --- |
| Scope | **Derived signals only**: `deriveSignals` / `toMat` / `intan2matlab`, the LFP, MUA and SPIKE outputs whose `<TYPE>_Reference` is on. The sorting `.bin`, spike detection, artifact detection and the viewer keep none / CAR / CMR. |
| Estimate subtracted | **Both selectable; the default is the a-priori estimate**, z - n^T*alpha*w_hat(t-1). The posterior estimate, as in the paper's Fig. 1 / eq. 8, is the option. |
| Toolboxes | Any toolbox may be used (owner, 2026-10-15). This plan needs only Signal Processing (already a dependency) and Statistics and Machine Learning (`mad`). |

## Feasibility findings

- **It fits the code.** `deriveSignals` holds the whole recording in memory, so the stateful
  filter runs once over it with no chunking problem.
  - CAR/CMR are memoryless per sample, so chunks do not matter to them (`applyReference.m:14-16`).
    The Kalman filter is not.
  - Reads elsewhere are chunked, parallel (`mapChunks` / `parfeval`) and random-access
    (`readWindowUV`). A reference mode for every step would therefore need state checkpoints
    (one serial pre-pass per recording). The chosen scope avoids that.
- **Cost reduction.** With V, q and P0 shared across channels, as in the paper ("Parameters V and
  q were assumed constant for all intracortical channels"), P(t) and K(t) depend only on n(t).
  One M x M covariance recursion per sample serves all channels, and each channel needs only
  W <- alpha(I - K n^T) W + K z.
- **Posterior identity.** z - n^T w_hat(t) = (innovation) * q / (n^T P^- n + q). The posterior
  output scales the whole sample down, neural signal included, when the common signal is large.
  This acts as soft blanking and distorts amplitudes.
- **Gaps in the paper.**
  - Not specified for real data: M, V, q, w0, P0.
  - alpha = 0.99 (at 1 kHz) was fitted to simulated ground truth, which real data lack.
  - Rates are inconsistent: recorded at 10 kHz, but "4 sample delay (4 ms considering 1 Khz
    sampling rate)".
  - The observation model treats s_i as white. LFP is not, so neural signal shared with the CAR
    can be absorbed into the weights.
- **Evidence base.** 3 rats, 16-channel microwire arrays; force-decoding R^2 rose from 0.33 to
  0.44 (LFP + MUA). Not tested for spike sorting.
- **Rough numpy check.** This was my own simulation, not the paper's VERTEX data: 16 channels,
  1 kHz, mixing U(-1,1) drifting every 2 s or 0.5 s, motion (1.6 + 3.2 Hz) or burst artifacts,
  -20 to 0 dB.
  - Weighted CAR beat CAR in every case.
  - Results were very sensitive to alpha and V. With alpha = 0.99 at 1 kHz and low V it
    underperformed, because alpha < 1 pulls the weights toward 0, i.e. toward no reference.
    alpha = 1 was more robust.
  - Posterior beat prior on bursts. That is the attenuation above, which R^2 rewards.

## Implementation

### 1. Core: `pipeline/weightedCAR.m` (new, public so tests call it directly)

`[S, info] = weightedCAR(Z, n, opts)`
- Z: [nSamples x nCol] µV (single or double; S is returned in Z's class).
- n: [nSamples x 1], the plain CAR of the reference channels.
- Options (arguments block): `Fs` (required), `Order` M = 1, `Alpha1k` = 1, `DriftPerSec` = 1,
  `Q` (required, finite > 0), `HighpassHz` = 0.5, `Estimate` "prior" | "posterior", `W0` = 1,
  `P0` = 1.
- Rate conversion keeps the per-second behaviour independent of Fs: alpha = Alpha1k^(1000/Fs),
  V = DriftPerSec/Fs * I.
- Steps:
  1. Estimation inputs: zero-phase 4th-order Butterworth high-pass at `HighpassHz` (the paper's
     0.5 Hz band edge), using the existing `EphysDataset.filterContinuous`, which switches to SOS
     at low cut-offs. The same filter goes on z and n. `HighpassHz` = 0 means no high-pass.
  2. Shared gain recursion, once: P^-, K(t) from n_hp. Stored as K [M x nSamples].
  3. Per column block (memory-bounded, as `blockColumns`): z_hp, then a time loop.
     - prior: S = Z - n_hp^T*alpha*W(t-1)
     - posterior: S = Z - n_hp^T*W(t)
     - The subtraction uses n_hp, so nothing below `HighpassHz` is removed and channel DC offsets
       are never mixed in through time-varying weights.
  4. Initial state: w0 = [W0; 0 ...] (starts as plain CAR), P0*I. The paper does not specify it.
- `info`: alpha and V per sample, Alpha1k, DriftPerSec, Q, Order, Estimate, HighpassHz, W0, P0,
  and a per-channel weight summary (median, 5th and 95th percentiles over time).

### 2. `deriveSignals` (`pipeline/@EphysDataset/deriveSignals.m`)

- New options:
  - `referenceMethod` "common" (default: `ArtifactConfig.Reference`, as now) | "weighted"
  - `wcarOptions` struct with fields Order, Alpha1k, DriftPerSec, Q (NaN = auto), HighpassHz,
    Estimate
- With "weighted": refMode = "wcar", even when `ArtifactConfig.Reference` is "none".
  - Settle the channels with `prepareReference(Mode="car")`. This needs a new optional `Mode`
    argument so the `ReferenceExclude` suggestion runs.
  - Compute n as the mean over `referenceChannels()` with `referenceTrace(X, Mode="car")` (new
    optional `Mode`), before the keepAmpChannels copy-out, as R is now (line 375).
- Auto Q (NaN): the median over the reference channels of (1.4826 * mad(HP(z_i - n), 1))^2, i.e.
  the robust variance of the high-passed plain-CAR residual, the paper's q = E[s_i^2]. Computed
  before the copy-out.
- In the referenced pass (line 440), replace `subtractRows(AMPSIG, R)` with `weightedCAR` on the
  kept columns, in place, block by block. The order stays as now: reference first, then the
  artifact-period erase. Weight transients after a large artifact can outlast an erased period
  by the adaptation time; document this.
- Record it:
  - `info.reference` gets mode "wcar", channels, signals, and a `wcar` sub-struct (weightedCAR's
    `info`, with the resolved Q and whether it was automatic).
  - `info.<TYPE>.reference` = "wcar".
  - The progress message names the method and its citation.
- Update the classdef declarations in `EphysDataset.m:317-319` for the new optional arguments.
- `intan2matlab.m`: pass the two options through and document them.

### 3. Config (`pipeline/@EphysPipelineConfig`)

- `defaults.m` Signals section, new fields:
  - `ReferenceMethod` "common" | "weighted"
  - `WCAR_Order` 1, `WCAR_Alpha1k` 1, `WCAR_DriftPerSec` 1, `WCAR_Q` NaN,
    `WCAR_HighpassHz` 0.5, `WCAR_Estimate` "prior"
- `validate.m` errors: bad member value; Order not an integer in 1..16; Alpha1k outside (0,1];
  DriftPerSec <= 0; Q neither NaN nor > 0; HighpassHz < 0.
- `validate.m` warning: "weighted" with no `<TYPE>_Reference` ticked.
- `signalOptions.m`: map the fields to `referenceMethod` / `wcarOptions`.
- `runSignals.m:55`: log and dry-run text say "WCAR" when weighted.
- Older configs get the new fields from `normalizeSection`.

### 4. App: `pipeline/@EphysPipelineApp/buildSignalsTab.m` (plus its gather/apply section code)

- A "Reference for ticked signals" dropdown: Common (Reference section) / Weighted CAR
  (adaptive).
- Numeric fields for the WCAR parameters, enabled only when weighted. Tooltips state where each
  default comes from.

### 5. Documentation

- `documentation/EphysDataset.md`: a new subsection "Adaptive weighted CAR", covering
  - the model and equations with the citation,
  - the shared-gain implementation,
  - each parameter and the source of its default,
  - deviations from the paper: alpha default 1 rather than 0.99; per-second scaling;
    automatic q; w0/P0; high-pass on the estimation inputs only; a-priori default,
  - the posterior gain identity,
  - caveats and evidence base,
  - the `deriveSignals` option rows.
- `documentation/EphysPipeline.md`: Signals fields, validation rules, runSignals log text.
- `documentation/intan2matlab.md`: the new options.
- `documentation/README.md` Dependencies: Statistics and Machine Learning Toolbox (`mad`,
  automatic q) and Signal Processing Toolbox (the high-pass).
- `CHANGELOG.md`.

### 6. Tests: new `pipeline/test_WeightedCAR.m`

Function style, using `check()` and `LegacySuiteTest.checkFailed`, as `test_CommonReference.m`
does.
1. Exactness: `weightedCAR` matches a literal per-channel Kalman written in the test (eqs. 6-8
   with separate P_i, matrix form) for M = 1 and M = 3, within 1e-9 of the signal scale.
2. Posterior identity: posterior residual = innovation * q/(n^T P^- n + q).
3. Paper-style simulation (fixed seed; 16 channels; 1.6 + 3.2 Hz motion artifact; mixing
   U(-1,1), updated every 2 s by N(0, 0.2^2); -10 dB): mean R^2 (eq. 11) of weighted CAR > CAR >
   no reference. Only relative assertions, no absolute numbers taken from the paper.
4. Uniform constant mixing: the median final weight lies within 0.05 of 1.
5. Input validation, the `HighpassHz` = 0 path, output class follows input class.
6. `deriveSignals` on a universal-binary fixture (the `writeRecording` pattern from
   `test_CommonReference`):
   - "weighted" gives MUA/SPIKE equal to `weightedCAR` followed by the band filters;
   - the LFP is untouched by default;
   - keepAmpChannels columns equal the full run's columns;
   - it works with `Reference.Mode` "none";
   - `info.reference.wcar` holds the resolved Q.
7. Config: defaults, validate messages, signalOptions mapping, runSignals dry-run text.
8. Informational benchmark: prints seconds per channel-hour at 30 kHz. No pass/fail threshold.

## Verification

- MATLAB is not installed in the cloud container this plan was written in. Before writing the
  MATLAB code, I will cross-check the algorithm (shared-gain equivalence, posterior identity) in a
  numpy prototype.
- The owner then runs:
  `run_all_tests({'test_WeightedCAR','test_CommonReference','test_DeriveSignals','test_EphysDataset','test_EphysPipelineConfig','test_EphysPipeline','test_EphysPipelineApp','test_TrialPairing','test_ClassdefDeclarations','test_EphysPipelineScript','test_PipelineScriptSave'})`.
  These suites cover deriveSignals, prepareReference, referenceTrace, signalOptions, the Signals
  tab builder and the classdef declarations. The whole suite is not run.
- If the benchmark shows the per-sample loop is too slow at 30 kHz, a follow-up adds a MATLAB
  Coder MEX of the per-column loop with the pure-MATLAB version as fallback. It is not part of
  this change.

## Follow-up: the weighted CAR for every read (2026-10-20)

The owner asked for the weighted CAR before artifact detection and Kilosort, with any further CAR
turned off when Kilosort takes it.

| Question | Answer |
| --- | --- |
| How a step chooses it | **One mode for every read**: `Reference.Mode` gains `"wcar"`; artifact detection, the noise level of the fill, the sorting `.bin`, spike detection, the viewer and the derived signals all take it. `Signals.ReferenceMethod` is retired. |
| Where its parameters live | **The Reference section** (`Reference.WCAR_*`), one set for every step, edited on the Artifacts tab; `Signals.WCAR_*` in a saved config move there on load. |

The chunked, parallel and random-access reads need the filter's state where each read starts:
`EphysDataset.prepareWCAR` runs it once over the recording (after a pass for an automatic `Q`), keeps
the state every second (`weightedCAR`'s new `Rows` / `Initial` / `StateRows`), and caches it as
`<Name>_wcar.mat`. Each read pads its zero-phase high-pass by the filter's memory to 1e-12 (23 s at
0.5 Hz), so it agrees with one run over the whole recording to about 1e-12 of the signal (exactly
with `HighpassHz` 0). A numpy port of the MATLAB index arithmetic (two passes, chunks off the grid,
Order 3 posterior, `HighpassHz` 0) agreed with the whole-recording filter to 1e-9 µV, and to 0 without
the high-pass, before the MATLAB tests were written. Kilosort4's `do_CAR` and a SpikeInterface
sorter's own common reference are turned off for a `"wcar"` `.bin`, as for CAR / CMR.
