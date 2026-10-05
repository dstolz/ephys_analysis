# Analysis: quick-look figures

The [`analysis`](../analysis) folder turns the pipeline's outputs into
figures: PSTHs with rasters, evoked potentials, firing rates, tuning curves,
heatmaps, probe maps and unit-by-unit correlation matrices. Every figure can be aligned to **any digital line**
(onset or offset; the first, last, every or nth interval per trial), and
trials can be **filtered and grouped by Epsych2 parameters** (Depth,
TrialType, response bits). Figures are exported as PNG / EPS / SVG / PDF and
collected into a self-contained HTML report and / or a multi-page PDF.

It is for quick looks. Spectra, coherence and other analyses belong in
[Chronux](ChronuxDataset.md) or [FieldTrip](FieldTripExport.md).

`analysis` depends on `pipeline`; `pipeline` never depends on `analysis`
(its only link is the pipeline app's **File → Open analysis app...**).
Three layers, each usable without the next:

| Layer | What | Page |
| --- | --- | --- |
| functions | load a dataset's source, align, select, compute, render, export, report | this page |
| [`EphysAnalysisConfig`](EphysAnalysisConfig.md) + `EphysAnalysisRunner` + `EphysAnalysisScript` | one JSON config describes the figures; the runner draws them; scripts reproduce them | [EphysAnalysisConfig](EphysAnalysisConfig.md), [below](#runner) |
| [`EphysAnalysisApp`](EphysAnalysisApp.md) | GUI over the runner | [EphysAnalysisApp](EphysAnalysisApp.md) |

> Written 2026-09-18 from the source. When the code and this page disagree,
> the code is authoritative.

## A worked script

```matlab
addpath_nogit('C:\src\ephys_analysis')               % pipeline + analysis
out = DatasetOutputs("D:\EPHYS\SYNTH-01\SYNTH-01_260918_101500", CacheData=true);
src = loadAnalysisSource(out);                        % events, trials, what exists

% epochs: the first Stim onset of every paired trial, grouped by Depth
ref = eventRef(line="Stim", edge="onset", which="first", scope="trial");
win = epochWindow(pre=-0.2, post=0.8);
sel = trialSelection(filter="Hit | Miss", groupBy="Depth");
[E, G] = epochTable(src, ref, Window=win, Selection=sel);

% sorted units -> PSTH + raster
[st, meta] = selectUnits(src, struct('source', "units", 'classes', "su"));
R = spikePSTH(st, E, Window=[-0.2 0.8], BinSec=0.01, SmoothSec=0.01, Groups=G, Meta=meta);
R.epochs = E;

fig = newExportFigure(struct('FigureSizeCm', [18 12]));
renderPlot(R, struct('kind', "psth", 'layout', "grid"), fig);
exportFigure(fig, "D:\out\psth_stim", Format=["png" "svg"], Dpi=150);
close(fig)

% LFP evoked potential, stacked by depth, baseline subtracted
[Y, fs, cm] = selectChannels(src, "LFP");
V = evokedPotential(Y, fs, E, Window=[-0.1 0.5], Baseline=[-0.1 0], Groups=G, Meta=cm);
figure; renderEvoked(V, gcf, Layout="stack");
```

## The source

`src = loadAnalysisSource(out)` takes a
[`DatasetOutputs`](DatasetOutputs.md) (or a folder, which becomes
`DatasetOutputs(folder, CacheData=true)`) and reads the small things every
analysis needs. **No signal and no spike time is loaded**: `selectUnits` and
`selectChannels` load those through `src.outputs` when a plot needs them.

| Field | Meaning |
| --- | --- |
| `name`, `key`, `folder`, `outputs` | the dataset, its key (`Key=` option), output folder and `DatasetOutputs` |
| `fs`, `durationSec` | recording rate and length: the manifest's `metadata.fs` / `duration_s`, else the extract (`info.origFs`, `info.<SIG>.nSamples / Fs`), else the pairing. Rates divide by `durationSec`, never by the time of the last spike. `fs` is also the rate the digital-event rows count at (`t = row/fs`), which `epochTable` uses |
| `events` | line → `[k x 2]` `[t_on t_off]` s, **polarity applied**, from the extract (the smallest extract file's `events`) |
| `artifacts` | `[k x 2]` `[tStart tEnd)` s on the continuous clock (row r at `(r − 1)/fs`): the artifact periods the Signals step erased (that file's `info.artifacts.intervals`; `zeros(0,2)` when none). `epochTable` drops the epochs that touch one, for spike plots too. Only these periods count: with `Signals.BlankArtifacts` off (or `Artifacts.ApplyToSignals` off while sorting or detection used the automatic periods) the periods erased before sorting or detection are not here |
| `invertedLines`, `lines` | lines inverted; table `Line, Count, MeanDurationSec, First, Last, Inverted` |
| `labels` | amplifier channel labels (`info.labels`) |
| `signals`, `signalFs` | `LFP / MUA / SPIKE / AUX` → extract present, and its rate |
| `hasBehavior`, `hasTrials` | a behavior file was found; it carries the trial pairing (`TrialOnset`, `TrialEvents`, ...) |
| `trials`, `nTrials`, `pairing` | `behavior.trials` (text columns as `string`), `behavior.pairing` |
| `paramNames` | every trial column but the pairing's times and samples (`TrialOnset`, `TrialOffset`, `TrialOnsetSample...`, `TrialEvents`, `TrialEventSamples`), `RespCode` included, in alphabetical order (ignoring case) |
| `respField` | `"RespCode"`, `"ResponseCode"` or `""` |
| `trialLine`, `subject`, `startTime` | from the pairing and the session |
| `probe`, `probeFile` | the manifest's `probe.file`, decoded (`chanMap` 0-based, `xc`, `yc` µm, `kcoords`) |
| `hasUnits` | the sorting folder holds sorted units (read once through `DatasetOutputs.load("sorting")`) |
| `hasDetected`, `spikesFile` | the spikes file holds threshold detections |

## Event reference, window, selection

Three small structs describe an alignment. Each constructor fills what you
leave out from [`EphysAnalysisConfig.defaults`](EphysAnalysisConfig.md#building-blocks),
coerces the rest and checks it: `eventRef(Name=Value)` or `eventRef(s, Name=Value)`.

### `eventRef`: what each epoch is aligned to

| Field | Default | Meaning |
| --- | --- | --- |
| `line` | `"Stim"` | digital line; `"Trial"` is the paired trial line |
| `edge` | `"onset"` | `"onset"` or `"offset"` of each interval |
| `which` | `"first"` | `"first"`, `"last"`, `"all"`, `"nth"` (per trial in trial scope, over the recording otherwise) |
| `n` | 1 | the interval `"nth"` takes |
| `scope` | `"auto"` | `"trial"`: the line's intervals whose edge lies inside each selected trial, `[TrialOnset, TrialOffset]` (an interval spanning several trials counts once, for the trial holding its edge); `"recording"`: every interval (`src.events`); `"auto"`: trial when the dataset has paired trials |
| `minDurationSec`, `maxDurationSec` | 0, `Inf` | keep intervals whose length is in range |
| `timeRange` | `[-Inf Inf]` | keep events in range: from the trial onset (trial scope) or the recording start |
| `offsetSec` | 0 | added to every event time |

`resolveEvents(src, ref, mask)` returns the event times `t`, the trial row of
each (`NaN` outside trials) and its rank. An interval belongs to the trial
whose `[TrialOnset, TrialOffset]` holds its `edge`, in both scopes: once, and
an edge on the boundary of two touching trials belongs to the earlier trial.
In trial scope `"Trial"` (or the trial line itself) is the trial's own
`[TrialOnset TrialOffset]`, and a line whose intervals lie between trials
(`Platform` on the synthetic fixture) has no event: use recording scope for
it. In recording scope each event is assigned the trial that holds its edge;
with a restrictive selection (below) events outside the kept trials are
dropped. Errors: `resolveEvents:NoTrials`, `resolveEvents:NoLine`,
`resolveEvents:NoEvents`.

### `epochWindow`: the span of each epoch

| Field | Default | Meaning |
| --- | --- | --- |
| `mode` | `"fixed"` | `"fixed"`: `[t0+pre, t0+post]`; `"between"`: `[t0+pre, t1+post]` where `t1` is the stop event |
| `pre`, `post` | -0.2, 0.8 | seconds |
| `stop` | `[]` | an `eventRef` ending each epoch. Required for `"between"`. In `"fixed"` mode it still fills `t1`, so renderers mark it and `spikePSTH` can mask after it |

The stop event of an epoch is the first (`stop.which`) stop event at or
after `t0`, in the same trial when the epoch has one: it is looked up among
the intervals overlapping that trial, so it may fall after the trial ends. Use
`"between"` for a variable-length period, e.g. `RespWindow` onset →
`RespWindow` offset.

### `trialSelection`: which trials, in which groups

| Field | Default | Meaning |
| --- | --- | --- |
| `filter` | `""` | an expression over `behavior.trials`, e.g. `Depth > 0 & RespLatency < 500` or `Hit \| Miss` |
| `response` | none | keep trials that are **any** of these response words |
| `pairingFlags` | `"ok"` | keep trials with this `PairingFlag` (`[]` keeps every flag) |
| `trials` | `[]` | explicit rows of `behavior.trials` |
| `groupBy` | none | 0-2 parameters; one group per value (pair of values) |
| `groupOrder` | `"ascending"` | `"ascending"`, `"descending"` or `"appearance"` |
| `maxGroups` | 12 | more groups is `selectTrials:TooManyGroups` |

Response words are the bits of `RespCode` ([`respCodeBits`](../analysis/respCodeBits.m)):
Hit 1, Miss 2, CR 4, FA 8, Reward 32, Punish 64, NoResponse 128, Response 256.

**Filters** are compiled from an allow-list and never passed to `eval`:
column names become `T.("name")`; response words `bitand(RespCode, bit) > 0`
(a column of the same name wins); `!` is `~`, `!=` is `~=`, a single `=` is
`==`, `&&` / `||` are the row-wise `&` / `|`; the functions `abs round floor
ceil fix mod rem min max isnan isfinite ismissing ismember any all strcmp
strcmpi contains startsWith endsWith lower upper string double bitand` and
`true false pi NaN Inf` are allowed; field access, `;`, `@` and every other
name are rejected (`trialSelection:BadFilter`). Text columns compare with
`==`. A parameter whose name is not a valid MATLAB identifier can only be
grouped by, not filtered on.

`[mask, G, gi] = selectTrials(src, sel)` applies it: `mask` over
`src.trials`, the groups table `G` (`index, label, color, n, <params>`, labels
like `"Depth = 0.5"`), and each trial's group. Colours: a numeric parameter
with more than two values runs through parula; otherwise `lines`; one
ungrouped set is dark grey. Without paired trials there is one group
`"all"`, and a filter / response / trials / groupBy raises
`selectTrials:NoTrials`.

### `epochTable`

`[E, G] = epochTable(src, ref, Window=win, Selection=sel, Incomplete="drop", Artifacts="drop", Baseline=[], Columns=[])`
gives one row per epoch, by time: `epoch, trial, t0, t0Continuous, t1,
tStart, tStop, duration, complete, artifact, groupIndex, group` and the `groupBy` (and
`Columns`) parameters of each epoch's trial. `t0` is the digital-event time
(`t = row/fs`); `t0Continuous` is the same event on the continuous clock of the
signals and spike times, `(row-1)/fs` = `t0 - 1/fs` (plus `offsetSec`),
computed from the row so that it equals the time of a spike in that sample.
`tStart` / `tStop` are on the clock of `t0`. `complete` means the window lies inside the
recording and, in `"between"` mode, has its stop event; incomplete epochs are
dropped unless `Incomplete="keep"`. `artifact` means the window, shifted to
the continuous clock (by `t0Continuous - t0`), touches one of `src.artifacts`
(half-open periods: `EphysDataset.overlapsIntervals`); those epochs are
dropped, for signal and spike plots alike, unless `Artifacts="keep"`,
which keeps them flagged (so with the default the column is always false).
`Baseline=[b0 b1]` (s from `t0`) widens that test to a baseline window that
reaches outside `[tStart, tStop]`; the runner passes each plot's baseline.
`G.n` is the number of epochs per group,
`G.nTrials` the kept trials. `E.Properties.UserData` records `ref`, `window`,
`selection`, `scope`, `nEvents`, `nDroppedNoStop`, `nDroppedEdge`,
`nDroppedArtifact`, `nTrials`, `nTrialsSelected` and `dataset`. Nothing usable is `epochTable:NoEpochs`; an
unknown `src.fs` is `epochTable:NoRate`.

### Units and channels

`[st, meta] = selectUnits(src, usel)` loads spike trains: `st` is
`{nUnits x 1}` spike times (s) and `meta` a table `label, unitId, class,
channel, channelName, shank, x, y, nSpikes`. `usel.source` is `"units"`
(sorted units, filtered by `classes`, `groups`, `ids`) or `"detected"`
(threshold detections, one "unit" per channel, class `"det"`, sites from the
probe map); both filter by `channels`, `shanks` and `maxUnits`. Shanks are
the probe map's `kcoords` values for both: a sorted unit on a mapped channel
takes its channel's shank, since the sorter's own shank numbers
(`channel_shanks.npy`) need not match them. Everything downstream
treats the two alike. `usel.quality` keeps the sorted units that meet
good-unit criteria, and `usel.response` the units that respond to the event
([response statistics](#response-statistics)). The response test needs the
events: `selectUnits(src, usel, Ref=ref, Selection=sel)` (the runner passes
the plot's own; `unitSummary` takes the same two options).

`[Y, fs, meta] = selectChannels(src, "LFP", Channels=...)` loads one derived
signal (`LFP`, `MUA`, `SPIKE` or `AUX`) through the outputs' cache: `Y` is
`[nSamples x nChannels]` single µV (AUX volts). `meta` has `label, channel`
(extract column), `recordingChannel` (`keepAmpChannels(channelRemap(c))`),
`shank, x, y, units`. With every channel in order, `Y` is the cached signal
itself, not a copy, and `evokedPotential` reads only the epochs' rows from it.
A MUA at 2 kHz × 64 channels × 1 h is about 1.8 GB, so
load one signal at a time and `clearCache()` between datasets (the runner
does).

## Time base

- Continuous signals: row `k` is at `t = (k-1)/Fs`, at every rate; spike
  times are seconds on the same clock.
- Digital events: `t = row/Fs` of the recording, one sample later for the same
  row. An event at row `r` happened at `(r-1)/Fs`, which is `E.t0Continuous`.
- `evokedPotential` uses rows `round(t0Continuous*fs) + 1 + (s0:s1)`, with
  `s0 = round(pre*fs)`, `s1 = round(post*fs)` and `R.t = (s0:s1)'/fs`: offset 0
  is the event's own sample at the recording rate, the nearest sample at a
  derived rate, as in `ChronuxDataset.trials` (`OnsetRule="event"`) and the
  pairing's `TrialOnsetSample_<SIG>`.
- Spikes are taken relative to `t0Continuous` (a spike in the event's own
  sample is at 0), and the windows of `firingRate` and `unitCorrelation` are
  moved to the spikes' clock by `t0Continuous - t0`.

## Compute

Pure functions: no I/O, no graphics. Every result `R` carries `kind`,
`params`, `groups`, `labels`, `n`, `units` (the measurement unit) and
`created`; the runner adds `epochs`, `dataset` and `spec`.

| Function | Result |
| --- | --- |
| `spikePSTH(st, E, Window=, BinSec=, SmoothSec=, Measure=, Baseline=, BaselineMode=, MaskAfterStop=, Raster=, Groups=, Meta=, Auroc=)` | `t, edges, window, rate / sem / count [nBins x nUnits x nGroups], nEpochs, raster, epochGroup, epochStop, stopMean, baselineRate, baselineSD`. Spikes are taken relative to each epoch's `t0Continuous`. Bins are whole multiples of `BinSec` from the event, `[k, k+1)·BinSec`, so the event is always an edge and no bin mixes spikes from before and after it; they are half-open (a spike exactly at a bin's end is in the next one). The window shrinks to the whole bins inside it, `R.window` (`[-0.25 0.5]` in 0.1 s bins is `[-0.2 0.5]`); one that holds no whole bin is `spikePSTH:BadWindow`. `Measure` is `"rate"` (default, spikes/s), `"count"` (spikes per bin per epoch) or `"probability"` (the share of epochs with a spike in the bin; its baseline uses whole `BinSec` bins from `b0`). Smoothing (Gaussian SD) applies to each epoch before averaging, renormalized at the edges. Baseline modes `none`, `subtract`, `zscore`, `percent` (per group, from spikes counted in the baseline window), or `auroc`: the curves become `aurocCurves`' auROC windows (`Auroc` holds its settings; `R.auroc` the calls; see [auROC](#auroc)). Named `spikePSTH` so it does not shadow Chronux's `psth` |
| `evokedPotential(Y, fs, E, Window=, Channels=, Baseline=, Detrend=, Incomplete=, KeepEpochs=, Groups=, Meta=, Units=)` | `t, mean / sem [nTime x nChan x nGroups], nEpochs, data (KeepEpochs), channels, labels, fs, units, sampleOffsets, onsetRule "event", keptEpochs, droppedEdge, droppedNonFinite`. Epoch *e* is rows `round(E.t0Continuous(e)*fs) + 1 + (s0:s1)`: onset rule `"event"`, offset 0 the sample nearest the one that produced the event (at the recording rate, that very sample). Only the epochs' rows of the used channels are read from `Y` |
| `firingRate(st, E, Measure=, Baseline=[b0 b1], Normalize=)` | `rate / count [nEpochs x nUnits]` over each epoch's `[tStart, tStop)`, moved to the spikes' clock by `t0Continuous - t0`, `duration`, `baseline` (`[b0 b1]` s around the event), `meanRate / sem / median [nUnits x nGroups]`, `baselineRate`. `Measure`: `rate` (default), `count` (spikes per window) or `probability` (1 for an epoch with a spike in its window; a group's mean is the share of such epochs). `Normalize`: `none`, `subtract` (per epoch), `ratio`, `zscore` (the unit's baseline over all epochs) |
| `tuningCurve(rates, x, Series=, Param=, SeriesParam=)` | `x` (sorted values), `series`, `mean / sem [nX x nUnits x nSeries]`, `n [nX x nSeries]`. Epochs without a value are left out; when none has one (recording-scope events that all fall outside the trials, say) it is `tuningCurve:NoValues` |
| `unitSummary(src, Source=, Units=, Ref=, Selection=)` | table `label, class, channel, shank, x, y, nSpikes, rateHz` with `rateHz = nSpikes / src.durationSec` |
| `probeMapValues(T, probe, Value=)` | one value per probe site: `rate` (summed Hz), `nSpikes`, `nUnits` |
| `unitCorrelation(st, E, Metric=, Type=, BinSec=, SmoothSec=, Baseline=, BaselineMode=, Groups=, Meta=)` | `r / p [nUnits x nUnits x nGroups]`, `meanR` (mean over the pairs), `nEpochs`, `response [nEpochs x nUnits]`. Each epoch's response is its `"mean"` rate over `[tStart, tStop)` (moved to the spikes' clock by `t0Continuous - t0`) or its `"peak"` binned rate (bins from `tStart`; a bin that runs past `tStop` is not used), optionally minus the epoch's baseline rate (`BaselineMode="subtract"`); every pair of units is then correlated over the epochs of each group, `Type="pearson"` or `"spearman"` (ties averaged). Fixed and `"between"` windows. Needs no toolbox; `p` is two-sided from the t distribution |

## Response statistics

`[T, info] = responseStats(st, E, Baseline=[b0 b1], Window=[w0 w1], Param=,
Correction=, Alpha=, Meta=)` tests every unit over the epochs of `E`. The
tests are the Statistics and Machine Learning Toolbox's own; the repository
adds only the counting and the p-value adjustment.

- **Counts.** Spikes per epoch in the baseline window `[t0+b0, t0+b1)` and
  the response window `[t0+w0, t0+w1)`, counted by `firingRate` on the
  spikes' clock (from `t0Continuous`).
- **Evoked.** `signrank(response, baseline)`: the Wilcoxon signed-rank test
  of the paired rates, two-sided, with `signrank`'s default method.
  `direction` comes from the two one-sided tests (`tail` `"right"` /
  `"left"`): `"excited"`, `"suppressed"`, or `"none"` when the two agree to
  1e-12 (equal rank sums).
- **Tuning** (with `Param`). `kruskalwallis(response, E.(Param), "off")`
  across the parameter's levels. Epochs without a level are left out. A
  unit with fewer than two levels is not tested. `bestLevel` is the level
  with the highest mean response rate (on a tie, the first in sorted
  order), and `bestRate` is that mean.
- **Counts or rates.** When the two windows are equally long, the tests
  run on the counts. Rates are the counts over one constant, so the result
  is the same, but the paired differences have no rounding error.
  Otherwise the tests run on the rates.
- **Correction.** Each test's p values are adjusted over the units tested
  with `pAdjust(p, Correction)`: `"bh"` (Benjamini-Hochberg, default),
  `"holm"`, `"bonferroni"` or `"none"`. Its results are R's `p.adjust`
  (NaN is not a test). The Statistics and Machine Learning Toolbox has no
  such function, so this is the one piece written here, and it is checked
  against statsmodels. A unit is `responsive` / `tuned` when its adjusted p
  is at most `Alpha` (default 0.05).
- **Epochs used.** Only epochs whose window `[tStart, tStop]` holds both
  test windows, since that is where `epochTable` checked the recording's
  ends and the artifact periods. The others are left out with
  `responseStats:EpochsLeftOut`: epochs flagged incomplete or artifact, and
  epochs too short for the windows. `selectUnits` builds its own epochs for
  the test: one fixed window `[min(b0,w0), max(b1,w1)]`.

`T` has one row per unit: `unit, label, nEpochs, baselineRate, responseRate,
pEvoked, qEvoked, direction, responsive` and, with `Param`, `nLevels,
pTuning, qTuning, tuned, bestLevel, bestRate`. A unit that is not tested has
NaN p and q and direction `""`. `info` records the windows, `param`,
`correction`, `alpha`, `tests`, `nEpochs`, `nEpochsLeftOut`, `nTestedEvoked`,
`nTestedTuning`, `counts`, the levels with the mean response rate and the
epochs per level and unit (`levels`, `levelRate`, `levelN`), and the toolbox
version. Without the toolbox it is `responseStats:NoToolbox`.
`Tests=false` skips the tests, so no toolbox is needed: the rates, the
per-level rates and `bestLevel` come out, with every p NaN.
`responseEpochs(src, ref, sel, Baseline=, Window=, Param=)` makes the epochs
of a test: the `epochTable` above.

## auROC

`A = aurocCurves(st, E, Window=, Baseline=, BinSec=, Measure=, Method=,
Windows=, WindowSec=, StepSec=, MaskAfterStop=, ModulationWindow=, Cutoff=,
Threshold=, Test=, NResamples=, Correction=, Alpha=, Seed=, Groups=)`
measures, per unit and group, how far the firing in each window around the
event stands apart from the firing in the baseline: the area under the ROC
curve (auROC; Cohen et al. 2012, Nature 482:85), as Macedo-Lima, Hamlette &
Caras (2024, Curr Biol 34:3354) use it. 0.5 is no difference, above 0.5
more firing than in the baseline, below less.

- **The values compared.** Spikes are counted in `BinSec` bins from the
  event (as `spikePSTH`). `Method="psth"` (default) compares the
  trial-averaged PSTH's bins inside a window with those inside the
  baseline, as the Caras lab's `calculate_auROC.py` does for the paper
  (10 ms bins, 100 ms windows). `Method="epochs"` compares each epoch's
  spike count in the window with the epochs' counts in window-long pieces
  of the baseline. `"rate"` and `"count"` give the same auROC;
  `"probability"` compares spike / no spike.
- **The auROC.** P(window value > baseline value) + P(equal) / 2 over all
  pairs: the area under the ROC curve that a criterion swept from 0 to the
  largest value draws. It is computed exactly from ranks (`tiedrank`); the
  lab's 0.1 Hz criterion sweep gives the same values (`test_Auroc` checks
  it against a port of that code).
- **Windows.** `Windows="tiled"` (default): back to back, `WindowSec` long
  (default 0.1), edged at whole multiples from the event; `"sliding"`: one
  every `StepSec`. Each is a whole number of bins
  (`aurocCurves:BadOption` otherwise); only windows wholly inside `Window`
  are used, and a window's time is its centre.
- **The call.** The windows wholly inside `ModulationWindow` give each
  unit's mean auROC and phasic modulation (mean |auROC - 0.5|) per group.
  `Cutoff="ci"` (default, the paper's): modulated up when the mean auROC is
  above 0.5 + c, down when below 0.5 - c, where c is the upper bound of the
  95% confidence interval of the mean phasic modulation over every unit
  and group (`tinv`). It depends on the units passed in and needs many;
  with few it can exceed 0.5 and call none (`aurocCurves:WideCutoff`).
  `"fixed"`: c = `Threshold`. `"test"`: a p per unit and group, adjusted
  over all of them (`pAdjust`), modulated at most `Alpha`, up or down by
  the mean auROC; `Test="bootstrap"` (the epochs resampled `NResamples`
  times; p = 2 x the share of resampled means on the far side of 0.5),
  `"ranksum"` (the call window's values against the baseline's; values
  from the same epochs are not independent, so p runs small) or
  `"shuffle"` (each epoch's bins shifted circularly over the span counted,
  `NResamples` times; p = the share whose phasic modulation reaches the
  observed). `"none"`: no call. The draws come from their own stream
  (`Seed`, default 0), so a result can be reproduced.

`A` holds `t` (window centres), `starts`, `stops`, `edges`, `window`,
`auroc` and `count` `[nWindows x nUnits x nGroups]`, `inModulation`, and per
unit and group `mean`, `phasic`, `p`, `q`, `direction` (`"increase"`,
`"decrease"`, `"none"`; `""` without a call) and `modulated`, plus
`cutoffValue`, `nModulated` / `nIncrease` / `nDecrease` per group, `nUnits`,
`baseline` (its whole bins), the options and the toolbox version.
`spikePSTH(..., BaselineMode="auroc", Auroc=)` draws on it for the psth and
heatmap plots (`Auroc.modulatedOnly` keeps only the modulated units), and
`selectUnits`' response test `"auroc"` keeps the units it calls modulated.
Needs the Statistics and Machine Learning Toolbox (`tiedrank`; `tinv` for
`"ci"`; `ranksum`).

## Population analysis

`[P, S] = populationAnalysis(cfg)` puts every unit of every dataset of an
analysis config (or of an `EphysAnalysisRunner`) into one table and sums it
up by group. `Ref`, `Window` (fixed) and `Selection` default to the config's
`Defaults`. Per dataset it makes the same calls as a plot:
`selectUnits(src, Units, Ref=, Selection=)`, `epochTable` and `spikePSTH`
for each unit's PSTH (`BinSec`, `SmoothSec`, `Measure`, `BaselineMode` over
`Baseline`), then `responseEpochs` and `responseStats` (`Baseline`,
`Response`, `Param`, `Tests`).

- **Correction family.** responseStats runs without a correction. The p
  values are then adjusted once (`Correction`, default `"bh"`) over every
  unit tested (`Family="all"`, the default) or over each dataset's units
  (`Family="dataset"`).
- **What is pooled.** The selection's `groupBy` is not used: a unit's PSTH
  pools every epoch the selection keeps, and `Param` carries the
  dependence on a trial parameter.
- **No per-dataset response filter.** `Units.response` is refused
  (`populationAnalysis:ResponseSelection`). Filter `P.units` by
  `responsive` / `tuned` instead, so every unit counts in the family.
- **Datasets left out.** A dataset that cannot be analysed is listed in
  `P.datasets` (`status`, `message`). It warns
  `populationAnalysis:DatasetSkipped` when it has nothing to analyse (no
  units, events or epochs), else `populationAnalysis:DatasetFailed`.

| `P` field | Holds |
| --- | --- |
| `units` | one row per unit: `dataset, datasetKey, subject` (the name pattern's SubjectID, else the behavior's), `selectUnits`' columns (with the quality metrics when `Units.quality` is on), `rateHz` (`nSpikes / durationSec`), `responseStats`' columns with q over the family, `psthPeak` and `psthLatency` (the highest PSTH bin whose centre lies in the response window, and its centre; NaN when every such bin is equal) |
| `psth` | `t` (bin centres), `rate [nBins x nUnits]` (the rows of `units`), `units`, `window`, `binSec`, `smoothSec`, `measure`, `baselineMode` |
| `tuning` | `param`, `levels` (every dataset's, sorted), `rate [nLevels x nUnits]` (mean response rate per level; NaN where a unit has no epoch of it), `n` |
| `datasets` | `datasetKey, dataset, subject, status, message, nUnits, nEpochs, nTestEpochs, nTestEpochsLeftOut` |
| `params`, `provenance`, `created` | every option as used; `ephysProvenance` |

`S = populationSummary(P, GroupBy=, DepthBinUm=100, TuningNormalize="peak")`
groups the units.

- **Group keys.** Any of `subject`, `dataset`, `class`, `shank`, `depth`
  (probe y in `DepthBinUm` bins), `direction`, `responsive` and `tuned`.
  The default is `["subject" "class"]`; `[]` gives one group.
- **`S.groups`.** One row per group: `nUnits`, `nDatasets`, mean and
  median `rateHz`, `nTested`, `nResponsive`, `fracResponsive`, `nExcited`,
  `nSuppressed`, `nTuningTested`, `nTuned`, `fracTuned`, `medianLatency`
  (the responsive excited units) and the medians of the quality metrics
  the units carry.
- **Per-group curves.** `S.psth` and `S.tuning` hold each group's mean and
  SEM across its units. With `TuningNormalize="peak"`, each unit's curve
  is divided by its highest level first.

`renderPopulation(P, S, kind, target)` draws `"psth"`, `"fractions"`
(excited, suppressed and tuned shares of the units tested), `"tuning"` or
`"depth"` (each unit's response against its probe y).
`writePopulation(P, S, folder)` writes the following into a folder:

- `population_units.csv`, `population_groups.csv`, `population_psth.csv`
  and `population_tuning.csv`;
- the figures (`Formats`, `Dpi`, `FigureSizeCm`);
- `population.json`, holding the parameters, the dataset table, the
  provenance and the files.

`populationAnalysis(..., Folder=)` does all of that in one call, and
returns the files as a third output.

```matlab
cfg = EphysAnalysisConfig.load("am.json");
[P, S] = populationAnalysis(cfg, Param="Freq", GroupBy=["subject" "depth"], ...
    Folder=fullfile(cfg.Source.Root, "population"));
deep = P.units(P.units.responsive & P.units.y > 400, :);
```

## Render

`h = render<Kind>(R, target, ...)` draws into `target`: an axes or uiaxes
(one panel), or a figure, uifigure, panel, tab, grid layout or tiled layout
(a compact tiled layout is made inside). Renderers never create figures, so
the app previews into a panel and the runner exports from an invisible
figure with the same code. In a grid of more than one tile (psth, raster,
tuning, evoked) the tick labels are 2 points under `Style.FontSize` (titles
and axis labels stay at it), and each automatic y axis has at most three
ticks at a round step.

| Renderer | Draws |
| --- | --- |
| `renderPSTH` | `Layout="grid"`: one tile per unit (`MaxTiles` per page, `Page=`), groups overlaid with SEM bands, a raster right on top of each, the two a 2 x 1 tiled layout in the unit's tile, so the grid's spacing falls between units (same x limits, axes not linked; `SortBy=` as `renderRaster`; ticks in a raster's bottom tenth are dropped, clear of the rate panel's top label); `"overlay"`: the mean over units. `HistStyle="bar"` (default) or `"line"`, `Fill=` (bars / area under the line, or outlines) at `FillAlpha=` (NaN: 0.5 overlaid, else 1); `Normalize="unitPeak"` or `"groupPeak"`; `Stack=true`: a row per group, first at the bottom, `Spacing=` x the tallest PSTH apart, the group values (of the selection's `groupBy` parameters) on the left axis and each row's peak rate on the right. `Style.YLim` applies to the rate panels only: the rasters always show every epoch, and a stack ignores it. An auROC result (`BaselineMode="auroc"`) is drawn from 0.5 on a 0-1 axis (unless `YLim`), the call window shaded and each group's call (up / down arrow, n.s.) by the unit's title; `Normalize` does not apply |
| `renderRaster` | one raster per unit: epochs as rows sorted by group, on pale group bands, and within a group in time order or by `SortBy=` (`"stop"`: the stop latency; else a column of `R.epochs`, such as a trial parameter); all ticks are one NaN-separated line. Every row is shown: `Style.YLim` does not apply |
| `renderEvoked` | `"stack"` (channels stacked top of the probe first; ignores `Style.YLim`, so every channel stays in view), `"butterfly"` (a tile per group, channels coloured by depth), `"grid"` (a tile per channel); `YLim` sets the amplitude axis of the last two |
| `renderRates` | units along x (by depth), groups side by side: `"bar"` (mean ± SEM), `"box"`, `"points"` (every epoch, fixed jitter) |
| `renderTuning` | rate against the parameter per unit (`"grid"`) or the mean over units (`"overlay"`) |
| `renderHeatmap` | units (psth) or channels (evoked) × time, a tile per group, one colour scale; `Order="probe"` (the style's sort options), `"peak"` or, for an auROC result, `"modulation"` (the first group's mean auROC in the call window, highest first). An auROC result is coloured on `[0 1]` (`CLim` overrides), with a bar over the call window and a triangle by each modulated row |
| `renderProbeMap(values, probe, target)` | a value per site on the probe's layout, a tile per shank; `values` is per recording channel, or a `probeMapValues` result |
| `renderCorrMap` | a `unitCorrelation` result: a square units × units matrix per group on `[-1 1]` (`CLim` overrides) in `blueWhiteRed`, titled with the epochs used and the mean r; `Order="depth"` or `"channel"` |

`renderPlot(R, spec, target, Page=)` dispatches on `spec.kind`, applies
`spec.style` ([Style](EphysAnalysisConfig.md#style)) and titles the figure
`"<Kind>: <line> <edge> (<n> epochs)"` (or `spec.title`) with the dataset and
page as a subtitle. `plotPageCount(R, spec)` is the number of pages;
`plotCaption(spec, R)` the one-sentence caption the reports print, e.g.
*PSTH, Stim onset, first per trial; window [-0.2 0.8] s; bins 10 ms, smooth
10 ms; trials: PairingFlag ok & Hit; groups by Depth (n = 4, 5); 12 sorted
unit(s) (su, mua).* A tuning caption counts the epochs of its curves instead
of the trial groups (*n = 12 epochs*, or *one curve per TrialType (n = 5, 7
epochs)*), and a PSTH caption adds *(whole bins: [a b] s)* when the bins,
counted from the event (`R.window`), span less than the window.

### Unit waveforms

`W = unitWaveforms(src, meta, Source=, MaxSpikes=)` gives each unit of a
`selectUnits` table its waveform on its peak channel: `W.timeMs`,
`W.mean` and `W.spikes` (`{nUnits x 1}`; `[nt x k]` spikes), `W.from`
(`"spikes"`, `"template"` or `"none"`), `W.units` (`"uV"`, `"bin"`,
`"whitened"`) and `W.note`. Sorted units: at most `MaxSpikes` of the
unit's spikes, picked at random (the same ones each time), cut from the
sorted `.bin` by `DatasetOutputs.readWaveforms` (`EphysDataset.readPhyWaveforms`:
as Kilosort4 saw them, referenced and high-passed, not whitened) and
kept in the outputs' cache, so a redraw does not read them again. When
the `.bin` is not there, the unit's template is its mean and the warning
`unitWaveforms:Templates` says why. Detections: the waveforms the spikes
file keeps (the Spikes step's `Waveforms` option), `MaxSpikes` of them
and the mean of all; without them none, and the warning
`unitWaveforms:NoWaveforms`.

`renderPSTH`, `renderRaster` and `renderTuning` take `Waveform=` (a plot's
[`waveform`](EphysAnalysisConfig.md#unit-waveforms)) and draw
`R.waveforms` as a box in each unit's tile (a PSTH's rate panel; not an
overlay): the mean (dark red), the spikes (thin, pale blue) or both, at
a compass point (`location`, `"northeast"` by default), with or without
its axis box (`box`), a third of the tile per side times `scale`. The box
is placed in data units on the tile's limits, which it keeps; its label
gives the mean's peak-to-peak amplitude, and "(template)" for a
template. `computePlot` adds `R.waveforms` to a raster, PSTH grid or
tuning grid of spikes whose `waveform.mode` is not `"off"`.

### Plot aesthetics

Every object a renderer draws is named by its *role* and, where it draws
one, its *group*: the PSTH line or fill, SEM band, raster ticks, group band
and stop dots, the event line, a mean or channel trace, bars, boxes, points,
a tuning curve, an image, probe sites, a unit waveform's box, spikes, mean
and amplitude label. The group is the trial group's label,
a tuning series or an evoked channel. Axes, tile titles, axis labels,
legends, colour bars and the plot's title and subtitle are components too.
`PlotAesthetics.roles()` lists the roles, `PlotAesthetics.components(target)`
what one drawing holds, and `analysis/private/tagPart.m` does the naming.

A *rule* sets one property of one role: `role`, `group` (`""` = every
group), `property` (a colour, line style or width, marker, opacity, font,
visibility or, for axes, a colormap), `value`. It applies in every tile.
`renderPlot` applies two sets after drawing, in this order, so the plot's
own rules win:

1. the user's rules for the plot's kind, `PlotAesthetics.userRules(kind)`,
   which are preferences (AppPrefs group `PlotAesthetics`) and follow the
   user, not the config;
2. the plot's rules, `spec.aesthetics`
   ([Plots](EphysAnalysisConfig.md#plots)), saved in the config, so runs,
   reports and generated scripts draw the plot the same way.

```matlab
spec = cfg.plotFor("psth_1");
spec.aesthetics = struct('role', "rate", 'group', "Depth = 0.5", 'property', "Color", 'value', [0.8 0 0.6]);
renderPlot(R, spec, figure);                                 % right-click any line, band or text
PlotAesthetics.setUserRules("psth", struct('role', "sem", 'group', "", 'property', "FaceAlpha", 'value', 0.3));
renderPlot(R, spec, fig, UserAesthetics=false);              % the plot's rules only
```

In a visible figure (`Editable="auto"`, the default; `true` / `false`
force it) a right-click on any component offers **Edit aesthetics...**,
which opens `PlotAestheticsDialog`, a modal window:

- **Components**: every component drawn, by tile, component and group, with
  its object type. Click a row to edit it. Tick rows to change several at
  once; **Tick like it** (the same role and group in every tile), **Tick its
  role**, **Tick its tile** and **Untick all** tick for you.
- **Edit**: the selected component's properties: colour (picker, or a name,
  `#rrggbb`, `r g b`, `none` / `flat` / `auto`), line style and width,
  markers, fill and edge colour and opacity, bar and box widths, fonts,
  axis colours, ticks, grid and box, legend place and columns, colormap,
  visibility. Each change shows on the plot at once.
- **Apply to**: *this one*; *the same component in every tile*; *every
  group of its role*; or *the ticked rows*. The list shades the rows a
  change goes to. Switching it moves the change in progress.
- **Remember for future plots**: on **OK** the changes become rules, kept
  with *this plot* (in the config, through `OnRemember`) or for *every plot
  of its kind* (your preferences). A rule matches by role and group, so a
  change to one tile is remembered for every tile, and the plot is redrawn
  to show that. A plot outside a config (no `OnRemember`) can only be
  remembered in the preferences.
- **Remembered** tab: the plot's and the user's rules. **Forget selected** /
  **Forget all** drop rules on OK, and the plot is redrawn without them.
  Unremembered edits made in the same window are put back after the
  redraw.
- **Reset** undoes everything since the window opened; **Cancel** (or
  closing the window) does too and closes it; **OK** keeps the changes.

`renderPlot` options: `UserAesthetics` (default `true`), `Editable`
(`"auto"`), `OnRemember` (called with the plot's new rule list; the app
keeps it in the plot's `aesthetics`). Unedited plots and runs pay for one
preference read per page. With no rules, nothing else is done.

## Export and reports

- `fig = newExportFigure(exportSection)` is an invisible classic figure of
  `FigureSizeCm`, white. Before R2025a EPS / SVG export needs a classic
  figure; `exportFigure` raises `exportFigure:UIFigure` for a uifigure there.
  `newExportFigure(exportSection, R, spec, Page=p)` sizes it for that page of
  the plot: a grid page grows taller than `FigureSizeCm(2)` when its rows
  need it, 3 cm a row (4.5 cm for PSTHs with rasters) plus 1.5 cm for the
  title. The runner, both reports and the generated scripts call it so.
- `files = exportFigure(fig, fileBase, Format=, Dpi=, Append=)`: `png` via
  `exportgraphics(Resolution=)`, `pdf` / `eps` via
  `exportgraphics(ContentType="vector")` (`Append` adds PDF pages), `svg` via
  `print -dsvg -vector`. Unknown formats are `exportFigure:BadFormat`.
- `figureFileName(pattern, tokens)` fills `{Name} {Plot} {Kind} {Group}
  {Unit} {Index} {Date}` (values sanitized to `[A-Za-z0-9_.-]`);
  `Kind="folder"` fills `{OutputFolder} {OutputRoot} {Root} {Name} {Date}`.
  `plotFileName` adds `_p<page>` to a paged plot unless the pattern tells
  the pages apart: it names `{Index}`, or `{Unit}` with a unit filled in (a
  paged evoked grid's `{Unit}` is `all` on every page). See
  [file formats](file-formats.md#exported-figure-names).
- Reports: `report = newAnalysisReport(Title=, Config=, Export=, Options=)`,
  then per dataset `addReportDataset(report, src)` (summary tables from
  `reportSummaryTables`) and per plot `addReportFigure(report, spec, R,
  Files=, Images=)`; then `writeHtmlReport(report, file)` and / or
  `writePdfReport(report, file)`. `Images` are the HTML report's pages, made
  from the figures already drawn and exported with
  `im = reportImage(fig, report, Title=, Files=)` (a PNG at the report's
  `Dpi`, or the SVG text; with `EmbedFormat="svg"` an `.svg` among `Files` is
  read instead of printing the figure again), so nothing is drawn twice.
  Without `Images` (a run with export off), an HTML-only report draws every
  page when the plot is added. The HTML is one self-contained file
  (contents, a section per dataset, PNG as `data:` URIs or inline SVG, the
  caption, the plot's parameters and the config folded). Its links to the
  exported files are relative to the report's folder (a `file://` URL on
  another drive or share), worked out from absolute paths, each path segment
  percent-encoded (UTF-8). `writeHtmlReport` draws a plot again only when its
  result was kept (a `"pdf"` / `"both"` report) and `EmbedFormat` or `Dpi` is
  given. The PDF has a title
  page, a summary page per dataset and every figure drawn again as vector
  pages with `exportgraphics(Append=true)`; the MATLAB Report Generator is
  not needed. An HTML-only report keeps images rather than results,
  so a long run does not hold every result in memory.

## Runner

```matlab
cfg = EphysAnalysisConfig.load("D:\EPHYS\am_quicklook.json");
r = EphysAnalysisRunner(cfg);      % finds the datasets
disp(r.plan())                     % dataset x plot, and why any is skipped
R = r.run();                       % Datasets=, Plots=, Export=, Report= narrow it
r.ReportFiles
```

`EphysAnalysisRunner(cfg, ProgressFcn=, LogFcn=)` finds the datasets from
`cfg.Source` (`datasets()`): in project mode `EphysProject(Root, OutputRoot=,
NamePattern=, ReaderOptions=)` only lists the recording folders (no header is
read; `Source.Recordings` says whether an Open Ephys session with several
recordings is one dataset or one per recording) and each dataset's
`outputs(CacheData=true)` finds its files; in
folders mode each folder is a `DatasetOutputs`. `source(k)` loads and caches
`loadAnalysisSource`.

- `plan()` is a table `Dataset, Plot, Kind, Source, Enabled, Reason`;
  `Reason` comes from `plotSkipReason`: *disabled*, *no sorted units*, *no
  detected spikes*, *no LFP extract*, *no probe map*, *no paired trials*, *no
  line X*, *no trial parameter X*.
- `computePlot(src, spec)` is the one compute path: `epochTable` →
  `selectUnits` / `selectChannels` → the compute function (tuning: an
  `epochTable` with the parameter columns, `firingRate`, `tuningCurve`;
  corrmap: `unitCorrelation`; probemap: `unitSummary` + `probeMapValues`).
- `renderPlotFigures(R, spec, Target=, Page=)` draws one page into a target:
  the app's preview. Without a target it is `EphysAnalysisRunner:NoTarget`.
- `runDataset(k)` is a thin sequence of these public calls per plot, page by
  page: the page's file names first (`plotFileName`), then it draws one
  `newExportFigure`, exports it (`exportFigure`), makes the HTML report's image
  from it (`reportImage`) and closes it (an `onCleanup` closes it on a failure
  too); then `addReportFigure(..., Files=, Images=)`. With
  `Export.Overwrite` off a page whose files all exist is not written again,
  nor drawn unless the HTML report needs its image. It clears the dataset's
  cache afterwards. A failing plot is an `error` row; the rest run.
- `run()` returns `Results` (`Dataset, Plot, Kind, Status, Message, Files,
  Seconds`; status `done`, `skipped`, `error` or `cancelled`) and writes the
  reports. `cancel()` makes the next `progress()` call throw
  `EphysAnalysisRunner:Cancelled`; what is left is `cancelled`.

## Scripts

`EphysAnalysisScript.compact(cfg, ConfigFile=, File=)` writes a short script
that loads the saved config and runs the runner (`plan`, then `run`).
`EphysAnalysisScript.standalone(cfg, File=)` writes every setting out: the
config JSON as a comment, the datasets (`EphysProject` or the folder list),
one fully resolved spec per plot (`ref`, `window` and `selection` expanded),
then per dataset and plot the calls `computePlot` makes, the export loop (the
runner's page loop, a page at a time with an `onCleanup` per page) and the
report calls. It never uses the runner. The test suite runs both into
separate roots and requires pixel-identical figures and equal HTML reports.

## Tests

| Suite | Covers |
| --- | --- |
| `test_EphysAnalysisCompute` | no fixture: `spikePSTH` on seeded Poisson trains (rate, SEM, half-open bins, bins that are whole multiples from the event and `R.window`, `spikePSTH:BadWindow`, a spike in the event's own sample at 0, baselines, smoothing, stop masking), `firingRate` over between windows, `tuningCurve` (and `tuningCurve:NoValues`), `evokedPotential` (event rule: the event's own row at `t = 0`; padding, drop counts, baseline), the filter compiler, `unitCorrelation` (Pearson and Spearman against `corrcoef`, peak rates and partial bins, baseline, groups, constant units), `binCounts` and `countBelow` against brute force, every renderer into axes, uiaxes, figure and uipanel, PSTH fills, normalization and stacks (row steps, value and peak axes), `renderPlot` pages and titles, unit waveform boxes (each location, on a reversed raster too; modes, box and scale; limits kept; none on an overlay; templates) |
| `test_EphysAnalysisEpochs` | the fixture: `loadAnalysisSource` against the generator's truth (`durationSec` from `info.LFP.nSamples`), `t0Continuous` and `offsetSec` on both clocks, trial / recording scope, `"Trial"`, an interval belonging to the trial holding its edge (spanning trials, touching trials, `Platform` in recording scope), `groupBy`, response and filter selection, between windows, approved cuts, `selectUnits` / `selectChannels` (every channel gives the cached signal as it is), `selectUnits`' response test (the same as `responseStats` over its own epochs; direction and alpha; `selectUnits:NoneLeft`, `selectUnits:BadResponse`; `responseStats:NoToolbox` without the toolbox) and its auROC test (the units `aurocCurves` calls modulated; no cutoff is `selectUnits:BadResponse`), error identifiers, the no-behavior fallback, `src.artifacts` and the epochs that touch one (dropped by default; a period ending at a window's start does not touch it; kept and flagged with `Artifacts="keep"`) |
| `test_ResponseStats` | no fixture: `pAdjust` against statsmodels' `multipletests` (`pipeline/testdata/padjust_golden.json` from `tools/golden/padjust_golden.py`; NaN, ties, one value), `responseStats` on hand-made epochs with known counts (rates, p against `signrank` / `kruskalwallis` called directly, direction, correction, the epochs left out, rates for windows of different lengths, the errors). The tests that call the toolbox are skipped without it |
| `test_Auroc` | no fixture: `aucOf` against counting every pair; the `"psth"` method against a port of the Caras lab's `auROC_response_curve`; the `"epochs"` method against hand counts; tiled and sliding windows, the whole-bin rules and the errors; the stop mask; the 95% CI formula, the fixed cutoff and the wide-cutoff warning; bootstrap, ranksum and shuffle tests on driven, suppressed and flat units (reproducible by seed; ranksum against `ranksum` called directly); `spikePSTH`'s auROC result, `modulatedOnly` and caption; the PSTH and heatmap marks, tagged. Skipped without the toolbox |
| `test_PopulationAnalysis` | the fixture: `populationAnalysis`' units, rates, PSTHs and per-level rates equal the per-dataset calls (the selection's groups pooled); the summary's counts and means add up; the groupings (none, dataset × shank, depth bins); the correction over every unit or each dataset; the files written; the errors |
| `test_PlotAesthetics` | no fixture: rules (decoded JSON, refused properties, merging, colours as text), every kind and layout naming everything it draws, the user's rules then the plot's (and `UserAesthetics=false`), a value an object refuses (a warning, the plot still drawn), the right-click menu only in a visible figure or with `Editable=true` (one per figure; legends find their plot), the editor (live edits, Apply to one / same / role / ticked, Reset, Cancel, OK remembering for the plot or the user, Forget and the redraw, unremembered edits put back), the config's `aesthetics` through JSON, and the script literal of a rule list |
| `test_EphysAnalysisConfig` | see [EphysAnalysisConfig](EphysAnalysisConfig.md#tests) |
| `test_EphysAnalysisRunner` | the fixture: `plan` skip reasons, `run` exports and paged names (no figure left open), HTML and PDF reports (percent-encoded and `file://` links; a `"both"` report holds the image of every exported page and each result), `Overwrite` off, rendering real results (a stack of real `epochTable` groups labelled by the `groupBy` parameter, a raster showing every epoch and an evoked stack whatever `Style.YLim`), a failing export closing its page (runner and standalone script), cancel, driven units, compact vs standalone script equivalence, unit waveforms (templates without the sorted `.bin` and the warning; the spikes cut from a planted one, at most `maxSpikes`, and kept in the cache; detections without waveforms; none with the mode off or for an overlay; the script's `unitWaveforms` line) |
| `test_EphysAnalysisApp` | see [EphysAnalysisApp](EphysAnalysisApp.md#tests) |

The fixture (`analysis/private/makeAnalysisFixture.m`) writes
`makeSyntheticProject(Preset="small")` with the clean and late-start
scenarios, approves each pairing with its scenario's cuts and runs the
generated config with the Behavior, Signals (LFP, MUA, AUX) and Spikes
(detected and sorted) steps. `pipeline/run_all_tests` runs these suites too.
