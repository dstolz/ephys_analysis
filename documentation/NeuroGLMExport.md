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
| `[expt, keep] = NeuroGLMExport.experiment(spans, ...)` | neuroGLM's experiment struct, one trial per row of `spans` (`[start stop]`, s on the continuous clock). `Spikes=` (struct: label → spike times, s) registers spike trains, `Events=` (label → event times) timing variables, `Values=` (a table, a row per span) per-trial values, `Intervals=` (label → `[k x 2]` `[start stop]` s) the periods something is on, each a value holding per trial the `[m x 2]` periods inside it in ms from its start, cut at its edges, `Continuous=` (label → `struct(data=[N x d], fs=)`) continuous variables resampled to the bin rate and cut. `BinMs` (1), `Id`, `Param` (kept in `expt.param`), `Describe` (label → description). `keep` marks the spans that became trials |
| `dspec = NeuroGLMExport.designSpec(expt, ...)` | a design: a raised-cosine kernel per timing variable (`Events=`, all by default; `KernelMs` 500, `NBases` 8, `Shape`), `Boxcars=` the interval variables given a kernel on their boxcar (1 in the bins the period covers, convolved with the kernel; none by default), `KernelMsOf=` a struct of the kernels with a length of their own (`struct('Stim_box', 800, 'Trial_on', 2000)`; `round(NBases * span / KernelMs)` raised cosines, so they keep their width), `Acausal=` events whose kernel spans `[-AcausalMs, KernelMs]` (`AcausalMs` = `KernelMs` by default), `AcausalMsOf=` a struct of the events with their own reach before them (`struct('response_time', 2500)`; they are acausal without being in `Acausal`), `GroupBy=` a value variable and `GroupEvents=` the events that get one kernel per value (included only on the trials with it, the paper's coherence-dependent kernels; labels `<event>__<value>`; a value of `""` gets none; several variables split different events: `GroupBy=["group" "response"], GroupEvents={"Stim_on", "RespWindow_on"}`, and an event takes one split; a name of `Boxcars` splits that boxcar's kernel), `History` (true; `HistoryMs` 200, the filter's reach: it covers the lags from one bin to `HistoryMs` after a spike at any bin size; `HistoryBases` 10 log-stretched raised cosines, fewer with the warning `NeuroGLMExport:HistoryBases` when the lags cannot tell that many apart), `Coupling` (false; a filter from every other spike train, `coupling_<label>`), `Continuous=` (all; instantaneous). `Response=` the spike train modeled (label or index, 1); kept in `dspec.response`. `dspec.covariates` is a table with a row per covariate: `label`, `source` (the experiment's variable), `kind` (`"event"`, `"boxcar"`, `"history"`, `"coupling"`, `"continuous"`), `by` and `level` (the `GroupBy` variable and its value) |
| `F = NeuroGLMExport.fit(dspec, Trials=, Response=, Method=, Ridge=, RidgeGrid=)` | the design matrix (`F.dm`, constant columns removed), the binned response `F.y` and a Poisson GLM. `Method="glmfit"` (default): maximum likelihood by `glmfit`, `stats` its stats. `Method="matRegress"`: neuroGLM's route, `glms.neglog.poisson` with its gradient and Hessian minimized by `fminunc` (trust-region) under a ridge prior of precision `Ridge` on every weight but the bias (the penalty `Ridge/2 · ‖w‖²`; 1 by default, 0 = maximum likelihood), or `Ridge="evidence"`: the precision on `RidgeGrid` (`logspace(-2, 4, 13)`) with the largest Laplace approximation of the log marginal likelihood, the paper's evidence optimization (`F.ridge` the value used, `F.evidence` the grid's log evidence); standard errors from the Hessian at the optimum, `stats.hessian` / `stats.covb`. Either way: `bias`, `w`, `se`, `kernels` (`buildGLM.combineWeights`: `kernels.<covariate>.tr` ms from the event, `.data` the log-rate change, so `exp(data)` is the gain), `kernelSE` (the same shape: the standard error of the kernel itself, from the weights' full covariance; NaN where the data say nothing), `converged` (false when `glmfit` stopped at its iteration limit or `fminunc`'s exit flag was not positive), `rate` (spikes/s per bin), `deviance`, `logLik`, `logLikNull` (a constant rate), `bitsPerSpike` (their difference per spike in bits, the paper's single-trial prediction measure), `nSpikes`, `nBins`, `method`, `ridge` |
| `P = NeuroGLMExport.predict(F, trials)` | the model's rate on any trials (held-out ones give the cross-validated prediction): `t{k}` (ms from the trial's start), `rate{k}` (spikes/s), `counts{k}` (the response's spikes per bin), `logLik`, `logLikNull`, `bitsPerSpike`. With a history or coupling filter the rate of a bin is the model's given the spikes observed before it |
| `T = NeuroGLMExport.lockedEvents(expt, Events=, Trials=, WithinMs=1000, ToleranceMs=, MinFraction=0.95)` | the pairs of timing variables a fixed time apart: a table with `first`, `second`, `lagMs` (the median), `fractionFirst`, `fractionSecond` (of each one's events with its partner at that lag, give or take `ToleranceMs`, one bin by default), `nFirst`, `nSecond`. Each event is paired with the nearest event of the other variable in its trial; a pair is listed when both fractions reach `MinFraction` and the lag is shorter than `WithinMs`. See [Events a fixed time apart](#events-a-fixed-time-apart) |
| `fits = NeuroGLMExport.fitUnits(expt, units, Design=, Trials=, Test=, Method=, Ridge=, Workers=, ProgressFcn=, LogFcn=, CheckFcn=)` | a design fitted and tested per row of `units` (`info.units`), on process workers (`Workers=`, 0 = here): `fits(j).unit`, `.dspec`, `.F`, `.P` in the rows' order. `ProgressFcn(fraction, message)` and `LogFcn(message)` report each unit as it finishes; an error from `CheckFcn` (e.g. `@() B.checkCancel()`) stops the workers and is raised |
| `[train, test] = NeuroGLMExport.split(expt, TestFraction=0.2, Blocked=true, Seed=0)` | the trials to fit and to hold out (indices into `expt.trial`, for `fit`'s `Trials` and `fitUnits`'s `Trials` / `Test`), by [`splitTrials`](../analysis/splitTrials.m) on the trials' spans: the held-out trials are the last block of the session holding about `TestFraction` of them, not trials picked from all over it (trials next to each other share drift and spike history, so scattered held-out trials are predicted from their own neighbors), and trials whose spans overlap are never split between the two. `Blocked=false` picks whole groups at random (`Seed`). `TestFraction=0`, a single trial or spans that all overlap hold nothing out: `test` is `train` (the last two with the warning `NeuroGLMExport:NoHoldOut`) |
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
  dropped (`keep` false). With a continuous signal each trial's start is
  **snapped once to the bin grid**, `round(start · fsBin) / fsBin` with
  `fsBin = 1000 / BinMs` Hz, before the spikes and events are binned, so they
  start from the same edge as the signal's rows (they would otherwise sit up
  to half a bin apart); the duration stays the span's whole bins and
  `expt.trial(k).span` is the snapped span. Without a continuous signal the
  start is kept as given.
- Spike and event times are found in each trial by binary search on the sorted
  times (not by testing every time against every trial), then rounded to 1 ns
  and nudged by 1 ns into the bin that starts on a bin edge.
- Labels are MATLAB field names (`matlab.lang.makeValidName`, made unique);
  `sessionDataNeuroGLM` keeps the originals in `info` and `expt.param`.
- A **boxcar** (`Boxcars=`) is 1 from the bin its period starts in to the bin
  before the one its stop falls in: the bins from the line's onset event to
  the one before its offset event, `(stop - start) / BinMs` of them when both
  are on bin edges, and never fewer than one. A period that begins before
  the trial or ends after it is cut at the trial's edge.
- neuroGLM builds the design matrix **one trial at a time**: a kernel stops
  at its trial's end (an acausal one starts at its start), and the spike
  history starts empty in every trial, also when the trials tile the
  session.

## `sessionDataNeuroGLM`

```matlab
D = B.Sessions;                                   % Raw Data, Data = units or detected
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
(`info.nDroppedArtifact`); `MinArtifactSec=` counts only the periods at least
that long (0: every one). With `Signal=`, the trials the signal does not
cover are dropped too (`info.nDroppedSignal`).

| Registered | From | Label |
| --- | --- | --- |
| spike trains | every element of `D.spikes` (`Units=` a subset) | `sp_<unit label>` |
| timing | every digital line's pulses (`Lines=` a subset), onsets and offsets apart | `<line>_on`, `<line>_off` |
| timing | with `ResponseLine=`, the moment of the response, from the digital lines alone: the first `ResponseEdge` (`"onset"` or `"offset"`) of that line after each onset of `ResponseAfter=` (`"Trial"`: the trial's onset; e.g. `"RespWindow"`), before the next trial's onset. A trial without one has none; no trial column is read | `response_time` |
| periods | every digital line's pulses (`Lines=` a subset), whole: the `[m x 2]` `[start stop]` ms the line is on inside the trial, for a kernel on the line's boxcar (`designSpec`'s `Boxcars=`) | `<line>_box` |
| values | the trial's row of `D.trials`, its group (its row of `D.groups`, 0 when not kept), the response code (`D.respField`), every trial parameter (`D.paramNames`) | `trialIndex`, `group`, the column names |
| values | with a response code, the trial's response word: the first of `Responses=` (`["Hit" "Miss" "CR" "FA" "Abort"]`) that it is, `""` when none | `response` |
| continuous | `Signal=`, a `sessionData` struct of the **same dataset** holding a signal, every channel | the signal's name (`LFP`, `MUA`, `AUX`) |

`info` holds `trialIndex` (the row of `D.trials` of each `expt.trial`),
`spans`, `units` (the rows of `D.units` plus `variable`), `lines` (`line`,
`on`, `off`, `box`), `values` (`column`, `variable`), `signal`, `response` and
`responseTime` (the variables' names, `""` without them); `expt.param` holds
the same tables with `key`, `name`, `variables` (the dataset's recorded
variables as a struct of values), `fs`, `binMs`, `window`, `align`,
`trialLine` and `groups`.

## From the DatasetBrowser

[`S_DatasetBrowserToNeuroGLM.m`](../analysis/browser_scripts/S_DatasetBrowserToNeuroGLM.m)
is in the browser's post-processing script list. Tick datasets, set **Data**
to *units* or *detected*, **Raw Data**, pick the script and **Run
now** (or tick *Run it after each Compute or Load*). For each dataset it
builds the experiment, with trials that tile the session (`opts.window = [-0.5 Inf]`:
from 0.5 s before each trial's onset to 0.5 s before the next one's), so an event
between trials, such as `Trough_on`, is in a trial and has its kernel; a finite
`opts.window(2)` leaves out every event after it. It prints where the trials went: how many the
browser's trial selection keeps, how many fall off the recording, on erased periods
or off the signal, and how many are fitted and held out. A trial is left out for an
erased period only when the trial selection's **Artifacts: Exclude epochs** is ticked,
and only for periods at least its **at least (s)** long; a dataset with no trial left
is passed over with a line printed. A dataset with fewer than
`opts.minTrials` (20) trials fitted is passed over, and so is a unit with fewer than
`opts.minSpikes` (100) spikes in those trials, each with a line printed. For every
other unit it fits the GLM on the
same first 80% of the trials (`opts.trainFraction`; the last block of consecutive
trials is held out, `NeuroGLMExport.split`) with a kernel per line edge (one per trial group for the
browser's event line when `opts.groupKernels` is on), the trial's response (below), a
spike-history filter and,
with `opts.withSignal = "LFP"`, the LFP as a covariate, predicts the held-out
trials and prints bits per spike for both, a line per unit; the line says so when the
fit did not converge, or when the ridge the evidence picked is at an end of its grid. The fit is the paper's by default
(`opts.fitMethod = "matRegress"`, `opts.ridge = "evidence"`); `opts.fitMethod = "glmfit"`
is the quick maximum-likelihood alternative. The workspace gets `glm{k}` per dataset fitted (`expt`,
`info`, the train/test split, `lockedEvents`, and `fits`, one element per unit: `unit`,
`dspec`, `F`, `P`) and, with `opts.plots`, three figures of the first dataset's unit
with the most spikes (not the one predicted best):

1. the **kernels** as gains on a logarithmic axis over time from each event, with
   the gain a standard error either side as thin lines, grouped kernels on one
   tile in the groups' colors; the spike-history filter, the coupling filters
   and the signal's weights have tiles of their own;
2. four **held-out trials**, evenly spaced through the held-out block: the
   spikes, their rate under a 100-ms boxcar and the model's rate under the same
   boxcar, with each line's onsets marked (the paper's Fig. 4);
3. the **held-out PSTH per trial group**, spikes against model, aligned to the
   trial's start (Fig. 2c).

With a spike-history filter, the model's rate in figures 2 and 3 is the rate
given the spikes observed before each bin, not a simulation from the events
alone. For another dataset or unit, set `kPlot` and `jPlot` in the script's
last section and run that section again.

The trial's response enters the model as the paper's choice-dependent saccade
kernels do:

- **A kernel per response word.** `opts.responseEvents` (`"response_time"`) get
  one kernel per word of `opts.responses` (`Hit`, `Miss`, `CR`, `FA`), each on
  the trials with that word: `F.kernels.response_time__Hit`, and so on. A trial
  with another word (an abort) has no kernel on that event. Avoid splitting an
  event a fixed time from the response on some word's trials, such as
  `RespWindow_on` (`RespWindow_off` follows it by the window's length): the
  fit cannot tell the two kernels apart, and predicting a trial under another
  word then gives wrong rates. An event takes one split, so an event in `opts.responseEvents` cannot also be
  the browser's event line while `opts.groupKernels` is on; the script stops with
  `NeuroGLMExport:BadGroupEvents` when it is. Set `opts.responses = string.empty`
  for none.
- **The moment of the response.** With `opts.responseTime`, the event
  `response_time` is the first `opts.responseEdge` of `opts.responseLine` after
  each onset of `opts.responseAfter`, before the next trial: the first Platform
  offset after the response window opens (`"Platform"`, `"offset"`,
  `"RespWindow"`). It is read from the digital lines alone, on every trial
  whatever its response word, so a Miss or CR has it where the animal leaves the
  platform. Its kernels reach `opts.acausalMs` (500) before it and
  `opts.kernelMs` after it. A dataset without those lines is fitted without it,
  with a line printed.

Each trial's word is `glm{k}.expt.trial(j).response`, to sort the predictions
by response.

You choose the covariates in the GLM with these settings:

| Covariate | Setting |
| --- | --- |
| event kernels | `opts.events`: the events given a kernel, named as the kernels are, `"<line>_on"`, `"<line>_off"` and `"response_time"`, e.g. `["Stim_on" "RespWindow_on" "response_time"]`. Empty (the default) gives every line edge and `response_time` a kernel. An event a dataset lacks is left out of that dataset's fit, with a line printed that lists the events it has |
| boxcar kernels | `opts.boxcars`: the lines given a kernel on their boxcar, 1 while the line is on, as the paper's motion stimulus: the kernel `<line>_box`. `""` (the default) is the browser's event line, `string.empty` none, else line names (`["Stim" "RespWindow"]`). A line a dataset lacks is left out, with a line printed |
| kernel lengths | `opts.kernelMs` (500) for every kernel, and `opts.kernelMsOf`, a struct of the kernels with a length of their own, by name: `struct('Stim_box', 800, 'Platform_off', 2000)`. `opts.acausalMsOf`, likewise, gives events their own reach before them (`struct('response_time', 1500)`). The raised cosines keep their width: `opts.nBases` per `opts.kernelMs`. A name that is no kernel of a dataset is left out there, with a line printed |
| kernels per trial group | `opts.groupKernels`, on the browser's event line: its boxcar when the line is in `opts.boxcars` (the paper's coherence-dependent kernels), else its onset when that is in `opts.events` |
| kernels per response word | `opts.responses` on `opts.responseEvents`, only those in `opts.events` |
| spike history | `opts.history` |
| coupling | `opts.coupling` |
| spike history | `opts.historyMs` (500), its reach after a spike, and `opts.historyBases` (10) |
| a signal | `opts.withSignal` (`"LFP"`, `"MUA"`, `"AUX"`, or `""` for none); for `"AUX"`, `opts.auxParts` picks the columns, each z-scored: `"magnitude"` (the vector magnitude of the axes less their 2-s running mean), `"axes"` (those axes, signed) and `"slow"` (the 2-s running means). `glm{k}.expt.param.channels` names the columns in the order of the covariate's weights. LFP and MUA go in as they are, in microvolts |

Every line stays in `glm{k}.expt` whatever `opts.events` holds, so the plots
can still mark it. Decoding in a plot script needs the response kernels it
swaps, e.g. `response_time` split by `Hit` and `Miss`.

The fields of `opts` at the top of the script (`binMs`, `window`, `minTrials`, `minSpikes`, `events`, `boxcars`, `kernelMs`,
`kernelMsOf`, `acausal`, `acausalMs`, `acausalMsOf`, `groupKernels`, `responses`, `responseEvents`, `responseTime`,
`responseLine`, `responseEdge`, `responseAfter`, `history`, `historyMs`, `historyBases`, `coupling`, `withSignal`,
`auxParts`, `fitMethod`, `ridge`, `workers`, `plots`, `outDir`) are the knobs; `opts.workers` (4; 0 =
one unit after the other in MATLAB itself) fits the units on process workers
(`fitUnits`), fewer when memory is short, so the per-unit lines print as the fits
finish while `fits` stays in unit order. The browser's progress strip follows
the units, and **Cancel** stops the fits: the datasets finished stay in `glm`
(and in `opts.outDir`, saved as each one finishes); `opts.outDir` saves `<dataset>_neuroglm.mat` per dataset. From there,
neuroGLM's own API applies to `glm{k}.expt` and `glm{k}.fits(j).dspec`
(`buildGLM.addCovariate`, `addCovariateBoxcar`, ... as in its `tutorial.m`),
and `NeuroGLMExport.fit` / `predict` take any design built on the experiment.

### Events a fixed time apart

The model tells two kernels apart only through the trials on which the time
between their events differs. The paper: "if the interval between the onset
of the choice targets and the saccade were constant, we could not
differentiate spikes time-locked to the targets from those time-locked to
the saccade"; neuroGLM's documentation: of two perfectly correlated timings,
include one. A digital line's onset and offset are such a pair whenever its
pulse has one length, and `opts.events` empty gives both a kernel.

For each dataset the script prints the pairs of `opts.events` that sit a fixed
time apart on the trials fitted, closer than their kernels reach
(`NeuroGLMExport.lockedEvents`; `glm{k}.lockedEvents`), a line per pair that
names the two events, the lag between them, and the share of each one's
events that have the other at that lag.

The prediction and bits per spike are unharmed. What is not determined is
the split between the two kernels over the lags they share, which the ridge
prior makes for you: read the two together, or name one of the pair in
`opts.events`.

A boxcar is in the same position when every pulse of its line has one
length: it is then the line's onset smeared over that length, and tells
nothing the onset kernel could not (the paper's stimulus varied from 500 to
1000 ms). The script prints a line when such a line is in `opts.boxcars`
while its onset or offset is in `opts.events`.

## Notes

- **Against the paper.** As the paper, the script bins at 1 ms
  (`opts.binMs`), gives a kernel its own length (`opts.kernelMsOf`,
  `opts.acausalMsOf`; the paper's run from 0.5 to 5.3 s by event, and the
  lengths are yours to set: every kernel is `opts.kernelMs` long until you
  do) and models a line as a boxcar of its duration (`opts.boxcars`; the
  paper's motion stimulus, with an 800-ms kernel per coherence). It still
  differs in the spike-history filter, `opts.historyBases` log-stretched
  raised cosines over `opts.historyMs` (the paper ten 1-ms steps and ten such
  cosines over 265 ms), and in the test: one split with the last block of
  trials held out (the paper five random folds). Decoding is not implemented.
- **A boxcar's kernel** is not read as an event's. The boxcar is 1 in every
  bin its line is on, so the kernel at lag t is the log gain that one bin of
  the line being on adds t later. While the line stays on, the gains of the
  bins behind add up: the sustained gain is the sum of the kernel, in log
  units per bin, and the kernel's shape is how that gain builds up after the
  onset and dies away after the offset. neuroGLM's own `addCovariateBoxcar`
  takes one onset and one offset per trial; `designSpec` builds the boxcar
  from every pulse that reaches into the trial instead.
- **Bins and memory.** `fit` makes the design matrix full for the
  regression: bins × columns doubles. At 1 ms, 300 trials of 3 s and 100 columns are
  720 MB, and an hour of trials that tile the session with 60 columns is
  1.7 GB, for each unit being fitted (`fitWorkers` counts four of them per
  worker). The script bins at 1 ms, as the paper; `opts.binMs = 5` or `10`
  is usually plenty for event kernels, several times faster, and a fraction
  of the memory.
- **The spike-history filter** covers the lags from one bin to `HistoryMs`
  after a spike, whatever the bin: its first raised cosine peaks one bin
  after the spike, so the refractory period and bursts are resolved only
  down to the bin, and at 5 ms a bin can hold more than one spike. neuroGLM's
  `makeNonlinearRaisedCos` lays its lattice out in bins but reads its end
  points as if a bin were 1 ms; `designSpec` calls it with the end points in
  bins, so the filter ends at `HistoryMs` at any bin size.
- **Bits per spike** compares the fit's Poisson log-likelihood with a
  constant rate's, per spike, in bits (the paper's Fig. 5a); a held-out
  `predict` gives the cross-validated value. Above 0 the model predicts
  better than the mean rate. The constant rate is the mean rate of the
  trials the value is computed on: on held-out trials the constant-rate
  model is given their own rate and the GLM is not, so the held-out value
  leans low when the rate drifts between the trials fitted and the block
  held out.
- **Standard errors of the kernels.** A kernel is its basis times its
  weights, `B * w`, so `F.kernelSE` is `sqrt(diag(B * C * B'))` with `C` the
  weights' covariance (`F.stats.covb`), the covariances between neighboring
  weights included. With a ridge prior it is the posterior standard
  deviation of the Laplace approximation. It is NaN at the lags of a basis
  function that was left out of the fit as a constant column (an event that
  never came up in the trials fitted): there the kernel is 0 by
  construction and the data say nothing.
- **Convergence.** `F.converged` is false when `glmfit` stopped at its
  iteration limit (its warning is not shown) or `fminunc` ended with an exit
  flag of 0 or less. Under maximum likelihood a basis function with no spike
  under it has no optimum (its weight runs to minus infinity); the ridge
  prior gives it one.
- **Ridge and evidence.** With few trials, maximum likelihood (`glmfit`, or
  `Ridge=0`) leaves rarely-occurring events' kernels unconstrained (huge
  error bands, gains clamped in the script's plot). The ridge prior shrinks
  them toward no effect; `Ridge="evidence"` lets the data set how much, as
  the paper did, at the cost of one fit per grid value.
- **Decoding** (the paper's second half) is not implemented: the saccade
  kernels' difference as linear decoding weights, and model-based choice
  probability, build directly on `F.kernels` when a design has one kernel
  per choice (`GroupBy` on `response`).
