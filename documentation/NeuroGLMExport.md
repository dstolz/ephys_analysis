# NeuroGLMExport

[`NeuroGLMExport`](../pipeline/@NeuroGLMExport/NeuroGLMExport.m) hands this
pipeline's trials to the [neuroGLM](https://github.com/pillowlab/neuroGLM)
toolbox (Pillow lab) and runs the common steps around it. neuroGLM is the
reference implementation of Park, Meister, Huk & Pillow, *Encoding and
decoding in parietal cortex during sensorimotor decision-making*, Nat.
Neurosci. 17, 1395–1403 (2014): a trial-based Poisson generalized linear
model whose spike rate is

```
rate(t) = exp( Σ_events  k_e * x_e (t)  +  h * spikes(t) )
```

a kernel `k_e` convolved with each task event's time course, plus a
post-spike filter `h` on the neuron's own history. neuroGLM stores the data
in an **experiment** struct (`buildGLM.initExperiment`, one element of
`expt.trial` per trial), expands it into a design matrix from a **design
specification** (`buildGLM.initDesignSpec`, `addCovariate*`,
`compileSparseDesignMatrix`) and leaves the regression to you.

[`sessionDataNeuroGLM`](../analysis/sessionDataNeuroGLM.m) builds the
experiment struct from one of the [DatasetBrowser](DatasetBrowser.md)'s whole
sessions (`B.Sessions`), and the bundled post-processing script
[`S_DatasetBrowserToNeuroGLM.m`](../analysis/browser_scripts/S_DatasetBrowserToNeuroGLM.m)
fits every unit of each dataset and draws the paper's figures.

neuroGLM is needed for everything here; it is not bundled. Clone it and add
its folder (the one holding `+buildGLM` and `+basisFactory`) to the path;
`NeuroGLMExport.hasNeuroGLM()` / `requireNeuroGLM()` report whether it is
there. `fit` has two routes: neuroGLM's own `matRegress` (its Poisson
log-likelihood `glms.neglog.poisson`, minimized by `fminunc` of the
Optimization Toolbox under the paper's ridge prior, with the prior's weight
picked by evidence optimization; `addpath(<neuroGLM>/matRegress)`,
`hasMatRegress()` / `requireMatRegress()`), and plain maximum likelihood by
`glmfit` (Statistics and Machine Learning Toolbox), the alternative
neuroGLM's tutorial names. Like the [FieldTrip](FieldTripExport.md) and
[Chronux](ChronuxDataset.md) connectors, this one shares no code with the
others.

## Static functions

| Call | Returns |
| --- | --- |
| `[expt, keep] = NeuroGLMExport.experiment(spans, ...)` | neuroGLM's experiment struct, one trial per row of `spans` (`[start stop]`, s on the continuous clock). `Spikes=` (struct: label → spike times, s) registers spike trains, `Events=` (label → event times) timing variables, `Values=` (a table, a row per span) per-trial values, `Continuous=` (label → `struct(data=[N x d], fs=)`) continuous variables resampled to the bin rate and cut. `BinMs` (1), `Id`, `Param` (kept in `expt.param`), `Describe` (label → description). `keep` marks the spans that became trials |
| `dspec = NeuroGLMExport.designSpec(expt, ...)` | a design: a raised-cosine kernel per timing variable (`Events=`, all by default; `KernelMs` 500, `NBases` 8, `Shape`), `Acausal=` events whose kernel spans `[-AcausalMs, KernelMs]` (`AcausalMs` = `KernelMs` by default), `GroupBy=` a value variable and `GroupEvents=` the events that get one kernel per value (included only on the trials with it, the paper's coherence-dependent kernels; labels `<event>__<value>`; a value of `""` gets none; several variables split different events: `GroupBy=["group" "response"], GroupEvents={"Stim_on", "RespWindow_on"}`, and an event takes one split), `History` (true; `HistoryMs` 200, `HistoryBases` 10, log-stretched raised cosines), `Coupling` (false; a filter from every other spike train, `coupling_<label>`), `Continuous=` (all; instantaneous). `Response=` the spike train modeled (label or index, 1); kept in `dspec.response` |
| `F = NeuroGLMExport.fit(dspec, Trials=, Response=, Method=, Ridge=, RidgeGrid=)` | the design matrix (`F.dm`, constant columns removed), the binned response `F.y` and a Poisson GLM. `Method="glmfit"` (default): maximum likelihood by `glmfit`, `stats` its stats. `Method="matRegress"`: neuroGLM's route, `glms.neglog.poisson` with its gradient and Hessian minimized by `fminunc` (trust-region) under a ridge prior of precision `Ridge` on every weight but the bias (the penalty `Ridge/2 · ‖w‖²`; 1 by default, 0 = maximum likelihood), or `Ridge="evidence"`: the precision on `RidgeGrid` (`logspace(-2, 4, 13)`) with the largest Laplace approximation of the log marginal likelihood, the paper's evidence optimization (`F.ridge` the value used, `F.evidence` the grid's log evidence); standard errors from the Hessian at the optimum, `stats.hessian` / `stats.covb`. Either way: `bias`, `w`, `se`, `kernels` (`buildGLM.combineWeights`: `kernels.<covariate>.tr` ms from the event, `.data` the log-rate change, so `exp(data)` is the gain), `kernelSE` (the same shape; covariances ignored, as neuroGLM's tutorial), `rate` (spikes/s per bin), `deviance`, `logLik`, `logLikNull` (a constant rate), `bitsPerSpike` (their difference per spike in bits, the paper's single-trial prediction measure), `nSpikes`, `nBins`, `method`, `ridge` |
| `P = NeuroGLMExport.predict(F, trials)` | the model's rate on any trials (held-out ones give the cross-validated prediction): `t{k}` (ms from the trial's start), `rate{k}` (spikes/s), `counts{k}` (the response's spikes per bin), `logLik`, `bitsPerSpike` |
| `fits = NeuroGLMExport.fitUnits(expt, units, Design=, Trials=, Test=, Method=, Ridge=, Workers=, ProgressFcn=, LogFcn=, CheckFcn=)` | a design fitted and tested per row of `units` (`info.units`), on process workers (`Workers=`, 0 = here): `fits(j).unit`, `.dspec`, `.F`, `.P` in the rows' order. `ProgressFcn(fraction, message)` and `LogFcn(message)` report each unit as it finishes; an error from `CheckFcn` (e.g. `@() B.checkCancel()`) stops the workers and is raised |
| `n = NeuroGLMExport.fitWorkers(dspec, trials, maxWorkers)` | how many process workers can fit this design at once, with the pool open: at most `maxWorkers`, fewer when memory is short (a worker holds about 4 full design matrices); 0 = fit here, with the warning `NeuroGLMExport:SerialFit` when workers were asked for and cannot be had |
| `NeuroGLMExport.hasNeuroGLM()`, `requireNeuroGLM()` | is neuroGLM on the path? / error with a hint |
| `NeuroGLMExport.hasMatRegress()`, `requireMatRegress()` | is neuroGLM's `matRegress` on the path (and `fminunc` installed)? / error with a hint |

### Conventions

- Time inside a trial is in **ms from the trial's start** (neuroGLM's
  `unitOfTime` `'ms'`), binned at `BinMs` (1 ms by default, as the paper).
  `expt.binfun(t) = (t == 0) + ceil(t / binSize)`: bin 1 starts at 0.
- Every input time is a second on the **continuous clock** of the signals
  and spikes (sample `k` at `(k-1)/Fs`); digital-event times are moved there
  first ([`sessionData`](DatasetBrowser.md#whole-sessions)'s
  `eventsContinuous` / `toContinuous`), as `epochTable` does.
- A trial's duration is rounded **down to whole bins**; spikes and events at
  or after its end are left out; an event exactly at its start is at 0.
- Continuous signals are resampled to the bin rate (`1000 / BinMs` Hz,
  `resample` when the rates differ) and cut so that row `k` of a trial is
  the bin starting at `(k-1) · BinMs`; a trial a signal does not cover is
  dropped (`keep` false).
- Labels are MATLAB field names (`matlab.lang.makeValidName`, made unique);
  `sessionDataNeuroGLM` keeps the originals in `info` and `expt.param`.

## `sessionDataNeuroGLM`

```matlab
D = B.Sessions;                                   % Load whole sessions, Data = units or detected
[expt, info] = sessionDataNeuroGLM(D(1));          % trials from TrialOnset - 0.5 s to the next trial
[expt, info] = sessionDataNeuroGLM(D(1), Window=[-0.2 1.5], Trials="all", BinMs=5);
L = sessionData(B.source(D(1).key), epochMatrixSettings(B.Settings, data="LFP"));
[expt, info] = sessionDataNeuroGLM(D(1), Signal=L);   % + the LFP channels as a continuous variable
```

One trial per kept trial of `D.trials` (`Trials="kept"`, the browser's
selection; `"all"` for every trial), spanning `[onset + pre, onset + post)`
around `Align` (`"TrialOnset"`). `Window=[-0.5 Inf]` by default: `post = Inf`
ends a trial where the next trial of `D.trials` begins (its onset + pre), the
last at the end of the recording, so the trials tile the session. Trials
running off the recording are dropped (`info.nDroppedEdge`), and those whose
span touches an erased period (`D.artifacts`) unless `DropArtifacts=false`
(`info.nDroppedArtifact`).

| Registered | From | Label |
| --- | --- | --- |
| spike trains | every element of `D.spikes` (`Units=` a subset) | `sp_<unit label>` |
| timing | every digital line's pulses (`Lines=` a subset), onsets and offsets apart | `<line>_on`, `<line>_off` |
| timing | with `ResponseLine=`, the moment of the response: on Hit and FA trials that line's onset + the trial's `ResponseLatency` (`"RespLatency"`, ms), on Miss and CR trials the trial's offset | `response_time` |
| values | the trial's row of `D.trials`, its group (its row of `D.groups`, 0 when not kept), the response code (`D.respField`), every trial parameter (`D.paramNames`) | `trialIndex`, `group`, the column names |
| values | with a response code, the trial's response word: the first of `Responses=` (`["Hit" "Miss" "CR" "FA" "Abort"]`) that it is, `""` when none | `response` |
| continuous | `Signal=`, a `sessionData` struct of the **same dataset** holding a signal, every channel | the signal's name (`LFP`, `MUA`, `AUX`) |

`info` holds `trialIndex` (the row of `D.trials` of each `expt.trial`),
`spans`, `units` (the rows of `D.units` plus `variable`), `lines` (`line`,
`on`, `off`), `values` (`column`, `variable`), `signal`, `response` and
`responseTime` (the variables' names, `""` without them); `expt.param` holds
the same tables with `key`, `name`, `fs`, `binMs`, `window`, `align`,
`trialLine` and `groups`.

## From the DatasetBrowser

[`S_DatasetBrowserToNeuroGLM.m`](../analysis/browser_scripts/S_DatasetBrowserToNeuroGLM.m)
is in the browser's post-processing script list. Tick datasets, set **Data**
to *units* or *detected*, **Load whole sessions**, pick the script and **Run
now** (or tick *Run it after each Compute or Load*). For each dataset it
builds the experiment and, for every unit with spikes, fits the GLM on the
same 80% of the trials with a kernel per line edge (one per trial group for the
browser's event line when `opts.groupKernels` is on), the trial's response (below), a
spike-history filter and,
with `opts.withSignal = "LFP"`, the LFP as a covariate, predicts the held-out
trials and prints bits per spike for both, a line per unit. The fit is the paper's by default
(`opts.fitMethod = "matRegress"`, `opts.ridge = "evidence"`); `opts.fitMethod = "glmfit"`
is the quick maximum-likelihood alternative. The workspace gets `glm{k}` per dataset (`expt`,
`info`, the train/test split, and `fits`, one element per unit: `unit`,
`dspec`, `F`, `P`) and three figures:

1. the **kernels** as gains over time from each event, with their standard
   error, grouped kernels on one tile in the groups' colors;
2. four **held-out trials**: the spikes, a 100-ms boxcar rate and the model's
   rate, with each line's onsets marked (the paper's Fig. 4);
3. the **PSTH per trial group**, data against model, aligned to the trial's
   start (Fig. 2c).

The trial's response enters the model as the paper's choice-dependent saccade
kernels do:

- **A kernel per response word.** `opts.responseEvents` (`"response_time"`) get
  one kernel per word of `opts.responses` (`Hit`, `Miss`, `CR`, `FA`), each on
  the trials with that word: `F.kernels.response_time__Hit`, and so on. A trial
  with another word (an abort) has no kernel on that event. Avoid splitting an
  event a fixed time from the response on some word's trials, such as
  `RespWindow_on` (a Miss's or CR's trial offset follows it by the window's length): the
  fit cannot tell the two kernels apart, and predicting a trial under another
  word then gives wrong rates. An event takes one split, so an event in `opts.responseEvents` cannot also be
  the browser's event line while `opts.groupKernels` is on; the script stops with
  `NeuroGLMExport:BadGroupEvents` when it is. Set `opts.responses = string.empty`
  for none.
- **The moment of the response.** With `opts.responseTime`, the event
  `response_time` is `opts.responseLine`'s onset + `opts.responseLatency`
  (`RespWindow`, `RespLatency`, ms) on Hit and FA trials, and the trial's offset
  on Miss and CR trials, when the trial is coded as one. Its
  kernels reach `opts.acausalMs` (1000) before it and `opts.kernelMs` after it. A
  dataset without that line or column is fitted without it, with a line printed.

Each trial's word is `glm{k}.expt.trial(j).response`, to sort the predictions
by response.

The fields of `opts` at the top of the script (`binMs`, `window`, `kernelMs`,
`acausal`, `acausalMs`, `groupKernels`, `responses`, `responseEvents`, `responseTime`,
`responseLine`, `responseLatency`, `history`, `coupling`, `withSignal`,
`fitMethod`, `ridge`, `workers`, `outDir`) are the knobs; `opts.workers` (4; 0 =
one unit after the other in MATLAB itself) fits the units on process workers
(`fitUnits`), fewer when memory is short, so the per-unit lines print as the fits
finish while `fits` stays in unit order. The browser's progress strip follows
the units, and **Cancel** stops the fits: the datasets finished stay in `glm`
(and in `opts.outDir`, saved as each one finishes); `opts.outDir` saves `<dataset>_neuroglm.mat` per dataset. From there,
neuroGLM's own API applies to `glm{k}.expt` and `glm{k}.fits(j).dspec`
(`buildGLM.addCovariate`, `addCovariateBoxcar`, ... as in its `tutorial.m`),
and `NeuroGLMExport.fit` / `predict` take any design built on the experiment.

## Notes

- **Bins and memory.** `fit` makes the design matrix full for the
  regression: bins × columns doubles. At 1 ms, 300 trials of 3 s and 100 columns are
  720 MB; `BinMs=5` or `10` is usually plenty for event kernels and far
  faster. The spike-history basis keeps its 1-ms resolution only at
  `BinMs=1`.
- **Bits per spike** compares the fit's Poisson log-likelihood with a
  constant rate's, per spike, in bits (the paper's Fig. 5a); a held-out
  `predict` gives the cross-validated value. Above 0 the model predicts
  better than the mean rate.
- **Standard errors of the kernels** combine the basis weights' variances
  without their covariances (as neuroGLM's tutorial does): a guide, not a
  confidence band. `F.stats.covb` has the full covariance.
- **Ridge and evidence.** With few trials, maximum likelihood (`glmfit`, or
  `Ridge=0`) leaves rarely-occurring events' kernels unconstrained (huge
  error bands, gains clamped in the script's plot). The ridge prior shrinks
  them toward no effect; `Ridge="evidence"` lets the data set how much, as
  the paper did, at the cost of one fit per grid value.
- **Decoding** (the paper's second half) is not implemented: the saccade
  kernels' difference as linear decoding weights, and model-based choice
  probability, build directly on `F.kernels` when a design has one kernel
  per choice (`GroupBy` on `response`).
