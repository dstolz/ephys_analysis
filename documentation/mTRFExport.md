# mTRFExport

[`mTRFExport`](../pipeline/@mTRFExport/mTRFExport.m) is a static class of
pure packaging functions that prepare this pipeline's signals and stimuli for
the [mTRF-Toolbox](https://github.com/mickcrosse/mTRF-Toolbox) (Crosse,
Di Liberto, Bednar & Lalor 2016, *The Multivariate Temporal Response Function
(mTRF) Toolbox: A MATLAB Toolbox for Relating Neural Signals to Continuous
Stimuli*, Front Hum Neurosci 10:604,
[doi:10.3389/fnhum.2016.00604](https://doi.org/10.3389/fnhum.2016.00604)).
Nothing here reads a recording or calls the toolbox; the toolbox is only
needed to fit and plot models (`mTRFtrain`, `mTRFcrossval`, `mTRFpredict`,
`mTRFplot`). The Signal Processing Toolbox is needed (`resample`, `envelope`,
`hilbert`).

mTRF, [FieldTrip](FieldTripExport.md) and [Chronux](ChronuxDataset.md) are
separate toolboxes with separate exporters. They take the same neutral inputs
but share no code, and no output is derived from another's.

## What the toolbox fits

A **forward model** (direction `1`, a temporal response function, TRF) is a
ridge regression of the response on time-lagged copies of the stimulus: its
weights `w(feature, lag, channel)` say how each channel follows each stimulus
feature at each lag (ms). A **backward model** (direction `-1`, a decoder)
regresses the stimulus on time-lagged copies of every channel at once and
reconstructs the stimulus from the response. The ridge `lambda` is picked by
leave-one-trial-out cross-validation (`mTRFcrossval`: the correlation between
the prediction and the data on the left-out trial, per `lambda`); `mTRFtrain`
fits the final model and `mTRFpredict` tests it on held-out trials.

The toolbox takes

| Input | Shape |
| --- | --- |
| `stim` | `{nTrials x 1}` of `[nTime x nFeatures]` |
| `resp` | `{nTrials x 1}` of `[nTime x nChannels]` |
| `fs` | one rate for both, Hz (its examples fit at 64 to 128 Hz) |

with the same `nTime` in each trial's pair (trials may differ in length). Rows
are observations, as in this pipeline, so nothing is transposed. The weights
are scaled by `fs` (`w = β · fs`), so an impulse stimulus of height `fs` (unit
area, the discrete delta) makes a forward model's weights the response per
event in the signal's own units: that is what the builders below put on an
event by default.

## Static functions

| Call | Returns |
| --- | --- |
| `[Y, fs] = mTRFExport.resample(X, FsIn, FsOut)` | `X` (`[nSamples x nVar]`, row `k` at `(k-1)/FsIn`) at `fs = FsIn·p/q` for `[p, q] = rat(FsOut/FsIn)` (exact for the usual pairs, 2000 → 128 among them), by the Signal Processing Toolbox's `resample`: `t = 0` stays on the first sample, `Y` is double with `ceil(nSamples·p/q)` rows. Pass the `fs` it returns to the toolbox |
| `[Y, fs] = mTRFExport.envelope(X, FsIn, FsOut, ...)` | the amplitude envelope of each column at `fs`, the stimulus feature the toolbox's examples use for speech and sounds: `Method="rms"` (default) the RMS over a sliding window of `round(FsIn/FsOut)` samples (`envelope(x, n, 'rms')`), as `mTRFenvelope` averages the squares over its frames; `"hilbert"` the magnitude of the analytic signal; then resampled, clipped at 0 and raised to `Compression` (`log10(2)` by default, the loudness compression `mTRFenvelope` applies; `1` for none). Each column is centered first (`Center=true`) |
| `x = mTRFExport.pulses(iv, Fs, N, ...)` | an `[N x 1]` feature at `Fs` from pulses `iv` (`[k x 2]` `[t_on t_off]` s on the continuous clock, `sessionData`'s `eventsContinuous.<line>`): `Kind="onset"` (default) 1 on each onset's sample `round(t_on·Fs) + 1`; `"offset"` on each end's; `"boxcar"` 1 from the onset's sample to the end's. `Value=` gives each pulse's height (`k` values; NaN is 0), `Height=` a factor on all (`Height=Fs` for unit-area impulses). Pulses off the signal are left out; pulses on one sample add up |
| `[X, names] = mTRFExport.lines(events, names, Fs, N, ...)` | a column of `pulses` per line of an events struct (`names` `[]` = every line), `Kind=` one for all or one per line, `Height=` on the impulses (a boxcar stays 1) |
| `[C, keep, t, rows] = mTRFExport.trials(X, Fs, onsets, [pre post], Artifacts=)` | `X` cut around event times (s on the continuous clock) into equal trials, sample `round(onset·Fs) + 1 + round(pre·Fs)` to `round(onset·Fs) + 1 + round(post·Fs)`: the samples `FieldTripExport.epochs` gives the same onset. A cell column of `[nTime x nVar]` double, `keep` marking the onsets kept (a NaN onset, a trial running off the signal or touching an artifact period `[tStart tEnd)` is left out), `t` the sample times from the onset, `rows` each trial's `[first last]` samples |
| `[C, rows] = mTRFExport.segments(X, Fs, Artifacts=, MinSeconds=2, MaxSeconds=Inf)` | `X` cut into its artifact-free stretches (every sample a period touches is out; touching periods merge), the continuous data the toolbox cross-validates over, each cell a fold: stretches shorter than `MinSeconds` are dropped, one longer than `MaxSeconds` is split into the fewest equal pieces no longer than that (`MaxSeconds=60` on a clean 10-minute session: ten 1-minute folds); no piece is ever shorter than `MinSeconds`, so when both cannot hold fewer, longer pieces are cut |
| `M = mTRFExport.package(stim, resp, Fs, ...)` | the pair checked (same rows in each trial's pair, same columns across trials; `mTRFExport:Mismatch` otherwise) as a struct: `stim`, `resp` (cell columns of double), `fs`, `nTrials`, `nFeatures`, `nChannels`, `stimLabels`, `respLabels` (`StimLabels=`, `RespLabels=`; `f1..`, `ch1..` by default), `stimUnits`, `respUnits`, `pos` (`Positions=`, `[nChannels x 2]` µm, NaN unknown), `start` (`Start=`, each trial's first sample as s on the continuous clock, for putting predictions back), `t` (`Time=`, the sample times of a cut trial from its event), `trialinfo` (`TrialInfo=`, a table or matrix) and `cfg` (`Cfg=` plus `exporter`) |
| `[t, s] = mTRFExport.lagSamples(tmin, tmax, Fs)` | the lags a model fits (`model.t`): `floor(tmin/1e3·Fs)` to `ceil(tmax/1e3·Fs)` samples, in ms |
| `mTRFExport.hasMTRF()`, `mTRFExport.requireMTRF()` | is the toolbox on the path; error with an install hint when not |

## From the analysis results

Two functions in [`analysis/`](../analysis) build packages from the
[DatasetBrowser](DatasetBrowser.md)'s data, one per dataset, as a cell
column:

| Call | Trials | Response | Stimulus |
| --- | --- | --- | --- |
| [`M = epochMatrixMTRF(R, ...)`](../analysis/epochMatrixMTRF.m), `R` an `epochMatrix` result computed with *Keep single trials* | each epoch of `R.epochs` | a signal's epochs (what `R.data` averages, never normalized) resampled to `Fs=` (`[]` = the result's rate); spike epochs (units / detected) binned at `Fs` (128 Hz) as rates, spikes/s (`SpikeUnits="count"`) | `Stimulus="onset"` (default): an impulse of `ImpulseHeight` (`fs`: unit area) on the sample nearest the event, scaled by `Values=` (a function of the epochs table, `@(E) E.groupIndex`, or a vector per dataset in a cell); or a function `f(E(j, :), t)` returning `[nTime x nFeatures]` per epoch |
| [`M = sessionDataMTRF(D, Stimulus=..., ...)`](../analysis/sessionDataMTRF.m), `D` the `sessionData` structs of *Load whole sessions* (`B.Sessions`) | `Mode="segments"` (default): the artifact-free stretches of the session in pieces of at most `MaxSeconds` (60 s) and at least `MinSeconds` (2 s); `Mode="trials"`: the kept trials cut in `Window=[pre post]` around `Align=` (a trials column, `"TrialOnset"`, or a digital line: every pulse) | the whole signal resampled to `Fs=` (128 Hz), or the spike trains binned as rates | a string array of digital lines (their pulses, `Kind=` `"onset"`, `"offset"`, `"boxcar"` each) and numeric trial columns (an impulse of the trial's value on its `Align` sample, every trial); a struct array of `sessionData` of another signal of the same datasets (AUX: `StimulusChannels=`, `Envelope=true` by default, `EnvelopeMethod=`, `Compression=`); or a function `f(D(k))` returning `struct(x, fs, labels)` at its own rate. Impulses are `ImpulseHeight` tall (`fs`) |

A forward model fit on `epochMatrixMTRF`'s `"onset"` stimulus with (almost)
no ridge is the mean evoked response, lag by lag: the check that the pipeline
and the toolbox agree. On a whole session the TRF of a digital line's onsets
is the evoked response to that event estimated from the continuous recording
with overlapping responses untangled; the envelope of an AUX channel carrying
the sound is the stimulus the toolbox was built for.

Each package carries `respLabels` and `pos` (the channels' probe positions),
`stimLabels`, `start`, `trialinfo` (segments: first and last sample; trials:
the trial's row of `D.trials` and its group, or the pulse's index; epochs:
`resultGroup` and `trial`) and `cfg` (dataset, name, data, mode, window,
align, the stimulus described, the options; for epochs the epochs table).

The post-processing script
[`S_DatasetBrowserToMTRF.m`](../analysis/browser_scripts/S_DatasetBrowserToMTRF.m)
runs both over the browser's result and sessions (`mtEpochs`, `mtSessions`,
`mtTrials`), saves them, and with the toolbox on the path cross-validates the
ridge in both directions, trains a TRF and a decoder, tests them on a held-out
trial, plots the TRFs (per channel, by probe depth, the global field power),
the cross-validation curves and the held-out trial, and checks the epochs'
TRF against the evoked mean. Set `mtrfPath` to the toolbox's `mtrf` folder;
`stimulus`, `kind`, `auxChannel`, `fs`, `tmin`/`tmax`, `lambda` and
`maxSeconds` are the knobs at its top.

## Tests

`test_MTRFExport` (pipeline/) checks the builders on known signals and, with
the toolbox on the path (or at `c:\src\mTRF-Toolbox\mtrf`), that `mTRFtrain`
recovers a known kernel from a package of unit-area impulses;
`test_DatasetBrowser`'s `mtrfOfEpochsAndSessions` checks `epochMatrixMTRF` and
`sessionDataMTRF` against the browser's epochs, sessions, trials, AUX and
spikes.
