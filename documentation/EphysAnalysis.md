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
(its only link is the preprocessing app's **File → Open analysis app...**).
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
R = spikePSTH(st, E, Window=[-0.2 0.8], BinSec=0.01, SmoothSec=0.02, Groups=G, Meta=meta);
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
| `fs`, `durationSec` | recording rate and length: the manifest's `metadata.fs` / `duration_s`, else the extract. Rates divide by `durationSec`, never by the time of the last spike |
| `events` | line → `[k x 2]` `[t_on t_off]` s, **polarity applied**, from the extract (the smallest extract file's `events`) |
| `invertedLines`, `lines` | lines inverted; table `Line, Count, MeanDurationSec, First, Last, Inverted` |
| `labels` | amplifier channel labels (`info.labels`) |
| `signals`, `signalFs` | `LFP / MUA / SPIKE / AUX` → extract present, and its rate |
| `hasBehavior`, `hasTrials` | a behavior file was found; it carries the trial pairing (`TrialOnset`, `TrialEvents`, ...) |
| `trials`, `nTrials`, `pairing` | `behavior.trials` (text columns as `string`), `behavior.pairing` |
| `paramNames` | Epsych2 parameters: `behavior.info.WriteParams` that are trial columns, else every non-bookkeeping column |
| `respField` | `"RespCode"`, `"ResponseCode"` or `""` |
| `trialLine`, `subject`, `startTime` | from the pairing and the session |
| `probe`, `probeFile` | the manifest's `probe.file`, decoded (`chanMap` 0-based, `xc`, `yc` µm, `kcoords`) |
| `hasUnits`, `unitsFrom` | sorted units exist: `"spikes"` (the spikes file's `units`, preferred) or `"sorting"` (the sorting folder, `DatasetOutputs.readUnits`) |
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
| `scope` | `"auto"` | `"trial"`: the line's intervals overlapping each selected trial (`TrialEvents`); `"recording"`: every interval (`src.events`); `"auto"`: trial when the dataset has paired trials |
| `minDurationSec`, `maxDurationSec` | 0, `Inf` | keep intervals whose length is in range |
| `timeRange` | `[-Inf Inf]` | keep events in range: from the trial onset (trial scope) or the recording start |
| `offsetSec` | 0 | added to every event time |

`resolveEvents(src, ref, mask)` returns the event times `t`, the trial row of
each (`NaN` outside trials) and its rank. In trial scope `"Trial"` (or the
trial line itself) is the trial's own `[TrialOnset TrialOffset]`. In
recording scope each event is assigned the trial that contains it; with a
restrictive selection (below) events outside the kept trials are dropped.
Errors: `resolveEvents:NoTrials`, `resolveEvents:NoLine`, `resolveEvents:NoEvents`.

### `epochWindow`: the span of each epoch

| Field | Default | Meaning |
| --- | --- | --- |
| `mode` | `"fixed"` | `"fixed"`: `[t0+pre, t0+post]`; `"between"`: `[t0+pre, t1+post]` where `t1` is the stop event |
| `pre`, `post` | -0.2, 0.8 | seconds |
| `stop` | `[]` | an `eventRef` ending each epoch. Required for `"between"`. In `"fixed"` mode it still fills `t1`, so renderers mark it and `spikePSTH` can mask after it |

The stop event of an epoch is the first (`stop.which`) stop event at or
after `t0`, in the same trial when the epoch has one. Use `"between"` for a
variable-length period, e.g. `Platform` onset → `Platform` offset.

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

`[E, G] = epochTable(src, ref, Window=win, Selection=sel, Incomplete="drop", Columns=[])`
gives one row per epoch, by time: `epoch, trial, t0, t1, tStart, tStop,
duration, complete, groupIndex, group` and the `groupBy` (and `Columns`)
parameters of each epoch's trial. `complete` means the window lies inside the
recording and, in `"between"` mode, has its stop event; incomplete epochs are
dropped unless `Incomplete="keep"`. `G.n` is the number of epochs per group,
`G.nTrials` the kept trials. `E.Properties.UserData` records `ref`, `window`,
`selection`, `scope`, `nEvents`, `nDroppedNoStop`, `nDroppedEdge`, `nTrials`,
`nTrialsSelected` and `dataset`. Nothing usable is `epochTable:NoEpochs`.

### Units and channels

`[st, meta] = selectUnits(src, usel)` loads spike trains: `st` is
`{nUnits x 1}` spike times (s) and `meta` a table `label, unitId, class,
channel, channelName, shank, x, y, nSpikes`. `usel.source` is `"units"`
(sorted units, filtered by `classes`, `groups`, `ids`) or `"detected"`
(threshold detections, one "unit" per channel, class `"det"`, sites from the
probe map); both filter by `channels`, `shanks` and `maxUnits`. Everything
downstream treats the two alike.

`[Y, fs, meta] = selectChannels(src, "LFP", Channels=...)` loads one derived
signal (`LFP`, `MUA`, `SPIKE` or `AUX`) through the outputs' cache: `Y` is
`[nSamples x nChannels]` single µV (AUX volts). `meta` has `label, channel`
(extract column), `recordingChannel` (`keepAmpChannels(channelRemap(c))`),
`shank, x, y, units`. A MUA at 2 kHz × 64 channels × 1 h is about 1.8 GB, so
load one signal at a time and `clearCache()` between datasets (the runner
does).

## Time base

- Continuous signals: row `k` is at `t = (k-1)/Fs`.
- Digital events: `t = row/Fs`, one sample later for the same row.
- A signal is indexed at an event time with the **event rule**
  `round(t * Fs_sig)`: offset 0 is the sample that produced the event, as in
  `ChronuxDataset.trials` (`OnsetRule="event"`) and the pairing's
  `TrialOnsetSample_<SIG>`. `evokedPotential` uses rows
  `round(t0*fs) + (round(pre*fs):round(post*fs))`, `R.t = (s0:s1)'/fs`.
- Spike times are seconds on the same clock and compare with event times
  directly.

## Compute

Pure functions: no I/O, no graphics. Every result `R` carries `kind`,
`params`, `groups`, `labels`, `n`, `units` (the measurement unit) and
`created`; the runner adds `epochs`, `dataset` and `spec`.

| Function | Result |
| --- | --- |
| `spikePSTH(st, E, Window=, BinSec=, SmoothSec=, Baseline=, BaselineMode=, MaskAfterStop=, Raster=, Groups=, Meta=)` | `t, edges, rate / sem / count [nBins x nUnits x nGroups], nEpochs, raster, epochGroup, epochStop, stopMean, baselineRate, baselineSD`. Half-open bins `[a, b)`: a spike at `t0 + post` is not counted. Smoothing (Gaussian SD) applies to each epoch before averaging, renormalized at the edges. Baseline modes `none`, `subtract`, `zscore`, `percent` (per group, from spikes counted in the baseline window). Named `spikePSTH` so it does not shadow Chronux's `psth` |
| `evokedPotential(Y, fs, E, Window=, Channels=, Baseline=, Detrend=, Incomplete=, KeepEpochs=, Groups=, Meta=, Units=)` | `t, mean / sem [nTime x nChan x nGroups], nEpochs, data (KeepEpochs), channels, labels, fs, units, sampleOffsets, onsetRule "event", keptEpochs, droppedEdge, droppedNonFinite` |
| `firingRate(st, E, Baseline=[b0 b1], Normalize=)` | `rate / count [nEpochs x nUnits]` over each epoch's `[tStart, tStop)`, `duration`, `baseline`, `meanRate / sem / median [nUnits x nGroups]`, `baselineRate`. `Normalize`: `none`, `subtract` (per epoch), `ratio`, `zscore` (the unit's baseline over all epochs) |
| `tuningCurve(rates, x, Series=, Param=, SeriesParam=)` | `x` (sorted values), `series`, `mean / sem [nX x nUnits x nSeries]`, `n [nX x nSeries]` |
| `unitSummary(src, Source=, Units=)` | table `label, class, channel, shank, x, y, nSpikes, rateHz` with `rateHz = nSpikes / src.durationSec` |
| `probeMapValues(T, probe, Value=)` | one value per probe site: `rate` (summed Hz), `nSpikes`, `nUnits` |
| `unitCorrelation(st, E, Metric=, Type=, BinSec=, SmoothSec=, Baseline=, BaselineMode=, Groups=, Meta=)` | `r / p [nUnits x nUnits x nGroups]`, `meanR` (mean over the pairs), `nEpochs`, `response [nEpochs x nUnits]`. Each epoch's response is its `"mean"` rate over `[tStart, tStop)` or its `"peak"` binned rate (bins from `tStart`; a bin that runs past `tStop` is not used), optionally minus the epoch's baseline rate (`BaselineMode="subtract"`); every pair of units is then correlated over the epochs of each group, `Type="pearson"` or `"spearman"` (ties averaged). Fixed and `"between"` windows. Needs no toolbox; `p` is two-sided from the t distribution |

## Render

`h = render<Kind>(R, target, ...)` draws into `target`: an axes or uiaxes
(one panel), or a figure, uifigure, panel, tab, grid layout or tiled layout
(a compact tiled layout is made inside). Renderers never create figures, so
the app previews into a panel and the runner exports from an invisible
figure with the same code.

| Renderer | Draws |
| --- | --- |
| `renderPSTH` | `Layout="grid"`: one tile per unit (`MaxTiles` per page, `Page=`), groups overlaid with SEM bands, a raster above each; `HistStyle="bar"` (default) or `"line"`; `"overlay"`: the mean over units |
| `renderRaster` | one raster per unit: epochs as rows sorted by group, on pale group bands; all ticks are one NaN-separated line |
| `renderEvoked` | `"stack"` (channels stacked top of the probe first), `"butterfly"` (a tile per group, channels coloured by depth), `"grid"` (a tile per channel) |
| `renderRates` | units along x (by depth), groups side by side: `"bar"` (mean ± SEM), `"box"`, `"points"` (every epoch, fixed jitter) |
| `renderTuning` | rate against the parameter per unit (`"grid"`) or the mean over units (`"overlay"`) |
| `renderHeatmap` | units (psth) or channels (evoked) × time, a tile per group, one colour scale; `Order="depth"`, `"channel"` or `"peak"` |
| `renderProbeMap(values, probe, target)` | a value per site on the probe's layout, a tile per shank; `values` is per recording channel, or a `probeMapValues` result |
| `renderCorrMap` | a `unitCorrelation` result: a square units × units matrix per group on `[-1 1]` (`CLim` overrides) in `blueWhiteRed`, titled with the epochs used and the mean r; `Order="depth"` or `"channel"` |

`renderPlot(R, spec, target, Page=)` dispatches on `spec.kind`, applies
`spec.style` ([Style](EphysAnalysisConfig.md#style)) and titles the figure
`"<Kind>: <line> <edge> (<n> epochs)"` (or `spec.title`) with the dataset and
page as a subtitle. `plotPageCount(R, spec)` is the number of pages;
`plotCaption(spec, R)` the one-sentence caption the reports print, e.g.
*PSTH, Stim onset, first per trial; window [-0.2 0.8] s; bins 10 ms, smooth
20 ms; trials: PairingFlag ok & Hit; groups by Depth (n = 4, 5); 12 sorted
unit(s) (su, mua).*

## Export and reports

- `fig = newExportFigure(exportSection)` is an invisible classic figure of
  `FigureSizeCm`, white. Before R2025a EPS / SVG export needs a classic
  figure; `exportFigure` raises `exportFigure:UIFigure` for a uifigure there.
- `files = exportFigure(fig, fileBase, Format=, Dpi=, Append=)`: `png` via
  `exportgraphics(Resolution=)`, `pdf` / `eps` via
  `exportgraphics(ContentType="vector")` (`Append` adds PDF pages), `svg` via
  `print -dsvg -vector`. Unknown formats are `exportFigure:BadFormat`.
- `figureFileName(pattern, tokens)` fills `{Name} {Plot} {Kind} {Group}
  {Unit} {Index} {Date}` (values sanitized to `[A-Za-z0-9_.-]`);
  `Kind="folder"` fills `{OutputFolder} {OutputRoot} {Root} {Name} {Date}`.
  `plotFileName` adds `_p<page>` to a paged plot whose pattern has no page
  token. See [file formats](file-formats.md#exported-figure-names).
- Reports: `report = newAnalysisReport(Title=, Config=, Export=, Options=)`,
  then per dataset `addReportDataset(report, src)` (summary tables from
  `reportSummaryTables`) and per plot `addReportFigure(report, spec, R,
  Files=)`; then `writeHtmlReport(report, file)` and / or
  `writePdfReport(report, file)`. The HTML is one self-contained file
  (contents, a section per dataset, PNG as `data:` URIs or inline SVG, the
  caption, the plot's parameters and the config folded). The PDF has a title
  page, a summary page per dataset and every figure drawn again as vector
  pages with `exportgraphics(Append=true)`; the MATLAB Report Generator is
  not needed. An HTML-only report keeps rendered images rather than results,
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
- `renderPlotFigures(R, spec, Target=)` draws into a target (the app's
  preview) or one `newExportFigure` per page.
- `runDataset(k)` is a thin sequence of these public calls per plot, then
  `exportFigure` per page and `addReportFigure`; it clears the dataset's
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
then per dataset and plot the calls `computePlot` makes, the export loop and
the report calls. It never uses the runner. The test suite runs both into
separate roots and requires pixel-identical figures and equal HTML reports.

## Tests

| Suite | Covers |
| --- | --- |
| `test_EphysAnalysisCompute` | no fixture: `spikePSTH` on seeded Poisson trains (rate, SEM, half-open bins, baselines, smoothing, stop masking), `firingRate` over between windows, `tuningCurve`, `evokedPotential` (event rule, padding, drop counts, baseline), the filter compiler, `unitCorrelation` (Pearson and Spearman against `corrcoef`, peak rates and partial bins, baseline, groups, constant units), every renderer into axes, uiaxes, figure and uipanel, `renderPlot` pages and titles |
| `test_EphysAnalysisEpochs` | the fixture: `loadAnalysisSource` against the generator's truth, trial / recording scope, `"Trial"`, `groupBy`, response and filter selection, between windows, approved cuts, `selectUnits` / `selectChannels`, error identifiers, the no-behavior fallback |
| `test_EphysAnalysisConfig` | see [EphysAnalysisConfig](EphysAnalysisConfig.md#tests) |
| `test_EphysAnalysisRunner` | the fixture: `plan` skip reasons, `run` exports and paged names, HTML and PDF reports, cancel, driven units, compact vs standalone script equivalence |
| `test_EphysAnalysisApp` | see [EphysAnalysisApp](EphysAnalysisApp.md#tests) |

The fixture (`analysis/private/makeAnalysisFixture.m`) writes
`makeSyntheticProject(Preset="small")` with the clean and late-start
scenarios, approves each pairing with its scenario's cuts and runs the
generated config with the Behavior, Signals (LFP, MUA, AUX) and Spikes
(detected and sorted) steps. `pipeline/run_all_tests` runs these suites too.
