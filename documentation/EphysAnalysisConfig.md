# EphysAnalysisConfig

`EphysAnalysisConfig` ([source](../analysis/@EphysAnalysisConfig/EphysAnalysisConfig.m))
is a value class that describes a set of quick-look figures: which datasets
to read, how to align them, which plots to draw, and how to export and
report them. `EphysAnalysisApp` edits one, `EphysAnalysisRunner` runs one and
`EphysAnalysisScript` writes scripts from one ([Analysis](EphysAnalysis.md)).
It is saved as JSON (schema `ephys-analysis-config`, version 1) and
round-trips exactly, `Inf`, `NaN` and empty values included.

It is separate from the [pipeline config](EphysPipeline.md#ephyspipelineconfig):
the pipeline never reads an analysis config, and the analysis reads the
pipeline's outputs and writes only its own figures, reports and run
records, to the folders set below. The one file it may write into a sort
folder is the `quality_metrics.json` cache, for a plot that keeps good
units only ([UnitSelection](#unitselection) `quality`).

```matlab
cfg = EphysAnalysisConfig();                                % defaults: no plots yet
cfg.Name = "AM quick look";
cfg.Source.Root = "D:\EPHYS";
cfg.Defaults.EventRef.line = "Stim";
cfg.Defaults.Selection.groupBy = "Depth";
cfg = cfg.addPlot("psth");                                  % id "psth_1"
cfg = cfg.addPlot(struct('kind', "evoked", 'source', "LFP"), Id="lfp_stim");
issues = cfg.validate();                                    % table: Section, Field, Severity, Message
cfg = cfg.save("D:\EPHYS\am_quicklook.json");               % sets cfg.File
cfg = EphysAnalysisConfig.load("D:\EPHYS\am_quicklook.json");
T = EphysAnalysisRunner(cfg).run();                         % one row per dataset and plot
```

As a value class, `addPlot`, `removePlot` and `save` (which sets `File`)
return the changed config and leave the one they were called on as it was:
keep the result (`cfg = cfg.addPlot(...)`, `cfg = cfg.save(...)`).

## Class

| Member | Meaning |
| --- | --- |
| `Name`, `Description` | text; `Name` (default `"Untitled"`) fills `{Name}` in the report title |
| `Source`, `Defaults`, `Export`, `Report` | sections (structs), coerced on assignment |
| `Plots` | struct array, one entry per plot, in run and report order; a cell array (what `jsondecode` gives for plots whose fields differ) is accepted too |
| `File`, `LoadWarnings` | transient: where it was loaded from / saved to; the unknown fields `load` dropped |
| `Schema`, `Version`, `Sections`, `Kinds`, `SpikeSources`, `SignalSources`, `WaveformLocations`, `ListFields` | constants |
| `toStruct()`, `toJson()`, `save(file)` | plain struct; the JSON `save` writes (`Inf` / `-Inf` / `NaN` as `"Inf"` / `"-Inf"` / `"NaN"`) |
| `EphysAnalysisConfig.load(file)`, `fromStruct(s)` | errors `EphysAnalysisConfig:BadSchema` on another schema or version |
| `validate(CheckPaths=true)` | issues table `Section, Field, Severity, Message` ([rules](#validation)) |
| `addPlot(kindOrStruct, Id=)`, `removePlot(id)`, `plotIndex(id)`, `plotIds()`, `enabledPlots()` | the plot list. `[cfg, id] = cfg.addPlot(...)` also returns the plot's id; a plot added without a `source` reads its kind's first (`units`; `LFP` for evoked, `trials` for behavior); `removePlot` of an unknown id is `EphysAnalysisConfig:NoPlot`; `plotIndex` is 0 for one |
| `plotFor(id)` | a plot (by id or index) with every `"default"` resolved from `Defaults`, `units.source` set to the plot's `source` and an empty layout replaced by the kind's default: what the runner draws |
| `isequalConfig(other)` | same values (NaN equal) |
| `defaults(section)`, `normalizeSection(section, s)`, `normalizePlot(p)`, `plotKinds()` | static: the single source of truth for fields, types and shapes |

Values are coerced to the class and shape of their default on every
assignment: a one-element list read back from JSON is a list again, `"Inf"`
is `Inf`, `[]` is an empty list or number. String fields named in
`ListFields` (`response`, `pairingFlags`, `groupBy`, `classes`, `groups`,
`Formats`, `Datasets`, `Folders`) stay lists even with one element. Missing
fields take their defaults. Unknown fields are dropped: `load` lists them in
`LoadWarnings` and reports them with the warning
`EphysAnalysisConfig:LoadWarnings`. Text where a number belongs is
`EphysAnalysisConfig:BadValue`.

Plot ids must be unique (`EphysAnalysisConfig:DuplicatePlotId`); a plot
without one gets `"<kind>_<n>"`. `validate` also requires them to stay
distinct as file names: `{Plot}` replaces every character outside
`A-Z a-z 0-9 _ - .` by `_`, and Windows ignores case, so `"psth 1"` or
`"PSTH_1"` next to `"psth_1"` is an error.

## JSON example

```json
{
  "schema": "ephys-analysis-config", "version": 1,
  "name": "AM quick look", "description": "",
  "Source": { "Mode": "project", "Root": "D:\\EPHYS", "OutputRoot": "",
              "NamePattern": "{SubjectID}_{Date:yyMMdd}_{Time:HHmmss}", "Recordings": "concatenate",
              "Selection": "all", "Datasets": [], "Folders": [] },
  "Defaults": {
    "EventRef":  { "line": "Stim", "edge": "onset", "which": "first", "n": 1, "scope": "auto",
                   "minDurationSec": 0, "maxDurationSec": "Inf", "timeRange": ["-Inf", "Inf"], "offsetSec": 0,
                   "offsetParam": "", "offsetParamUnit": "ms" },
    "Window":    { "mode": "fixed", "pre": -0.2, "post": 0.8, "stop": [] },
    "Selection": { "filter": "", "response": [], "pairingFlags": "ok", "trials": [],
                   "groupBy": "Depth", "groupOrder": "ascending", "maxGroups": 12 } },
  "Plots": [
    { "id": "psth_stim", "kind": "psth", "enabled": true, "title": "", "source": "units",
      "units": { "classes": ["su", "mua"], "groups": [], "ids": [], "channels": [], "shanks": [], "maxUnits": "Inf",
                 "quality": { "enabled": false, "...": "..." }, "response": { "enabled": false, "...": "..." } },
      "channels": [], "ref": "default", "window": "default", "selection": "default",
      "bins": { "BinSec": 0.01, "SmoothSec": 0.01 }, "measure": "rate",
      "baseline": { "Mode": "none", "Window": [-0.2, 0] }, "auroc": { "method": "psth", "...": "..." },
      "layout": "grid", "withRaster": true, "rasterSort": "", "rasterSortEvent": [], "rasterSortOrder": "ascending", "rasterByGroup": true,
      "rasterEvents": { "lines": [], "edge": "onset", "scope": "window", "marker": "diamond", "size": 4, "color": "" },
      "histStyle": "bar", "fill": true, "fillAlpha": "NaN", "normalize": "none",
      "stack": false, "stackSpacing": 1.1, "maskAfterStop": false, "param": "", "seriesParam": "",
      "yParam": "", "jitter": true, "xScale": "category",
      "value": "rate", "order": "probe", "metric": "mean", "correlation": "pearson",
      "waveform": { "mode": "both", "location": "northeast", "box": true, "scale": 1, "maxSpikes": 100 },
      "style": { "MaxTiles": 16, "...": "..." }, "aesthetics": [] },
    { "id": "rate_resp", "kind": "rate", "source": "units",
      "ref": { "line": "RespWindow", "edge": "onset", "which": "first", "scope": "trial", "...": "..." },
      "window": { "mode": "between", "pre": 0, "post": 0,
                  "stop": { "line": "RespWindow", "edge": "offset", "which": "first", "scope": "trial", "...": "..." } },
      "selection": { "filter": "Hit | Miss", "groupBy": "Depth", "...": "..." },
      "baseline": { "Mode": "subtract", "Window": [-0.5, 0] }, "...": "..." } ],
  "Export": { "Enabled": true, "Formats": ["png", "svg"], "Folder": "{OutputFolder}\\analysis",
              "FilenamePattern": "{Name}_{Plot}", "Dpi": 150, "FigureSizeCm": [18, 12], "Overwrite": true },
  "Report": { "Enabled": true, "Format": "html", "Title": "{Name}",
              "Folder": "{OutputRoot}\\analysis", "FileName": "analysis_report", "PerDataset": false,
              "EmbedFormat": "png", "Dpi": 110, "IncludeSummary": true, "IncludeParameters": true,
              "IncludeConfig": true }
}
```

The top level holds `schema` and `version`, `name` and `description` (the
class's `Name` and `Description`), the sections `Source`, `Defaults`,
`Export` and `Report`, and `Plots`. `save` writes every field of every
section and plot, pretty-printed (the `"..."` above stand for the rest); a
file written by hand may leave fields out, and they take their defaults
when it is loaded. Two things the JSON encoder does that a hand-written
file need not copy:

- A one-element list is written as a scalar (`"pairingFlags": "ok"`,
  `"groupBy": "Depth"`), and a config with a single plot writes `Plots` as
  one object instead of an array of one. Both read back correctly.
- A plot's `ref`, `window` and `selection` are either the string
  `"default"` or an object of their own, whose missing fields take the
  [building blocks](#building-blocks)' defaults (not the config's
  `Defaults`). An empty value also means `"default"`.

## Source

| Field | Default | Meaning |
| --- | --- | --- |
| `Mode` | `"project"` | `"project"`: a pipeline project; `"folders"`: the listed output folders |
| `Root` | `""` | project root (the folder the pipeline app scans) |
| `OutputRoot` | `""` | the project's output root; `""` = outputs next to each recording |
| `NamePattern` | `EphysDataset.DefaultNamePattern` (`"{SubjectID}_{Date:yyMMdd}_{Time:HHmmss}"`) | [dataset-name tokens](EphysPipeline.md#dataset-name-tokens), as in the pipeline config |
| `Recordings` | `"concatenate"` | what an Open Ephys session with several recordings is (`"concatenate"`, `"separate"`, `"single"`), as in the pipeline config's `Acquisition.OpenEphys.Recordings`: with `"separate"` the datasets are the part folders |
| `Selection` | `"all"` | project mode: `"all"` datasets under the root, or the `"list"` in `Datasets` |
| `Datasets` | none | root-relative [dataset keys](EphysPipeline.md#dataset-keys) for `"list"`. A key not found is warned about (`EphysAnalysisRunner:UnknownDataset`) and skipped |
| `Folders` | none | dataset output folders (`"folders"` mode) |

Project mode only lists the recording folders (`EphysProject`, no header
read, nothing written); each dataset's files are found under its output
folder and recording folder ([`DatasetOutputs`](DatasetOutputs.md)). Use
the `Root`, `OutputRoot`, `NamePattern` and `Recordings` of the pipeline
config that wrote the outputs. Folders mode suits a machine that holds only
processed files: each folder holds one dataset's files, named after the
folder (`<Name>_*`, `<Name>` the folder's last part).

<!-- wiki: More on finding a dataset's files: [Loading outputs](Loading-Outputs). -->

## Defaults

| Field | Building block | Meaning |
| --- | --- | --- |
| `EventRef` | [EventRef](#eventref) | what each epoch is aligned to |
| `Window` | [EpochWindow](#epochwindow) | the span of each epoch |
| `Selection` | [TrialSelection](#trialselection) | which trials take part, in which groups |

They are used by every plot whose `ref`, `window` or `selection` is the
string `"default"`. The app's [Alignment tab](EphysAnalysisApp.md#alignment-tab)
edits them.

## Building blocks

`EphysAnalysisConfig.defaults("EventRef" | "EpochWindow" | "TrialSelection" |
"UnitSelection" | "Style" | "Auroc" | "Waveform")`. The first three are described with their
constructors (`eventRef`, `epochWindow`, `trialSelection`, which build and
check one in a script) on the [Analysis page](EphysAnalysis.md#event-reference-window-selection);
what they mean in a config follows.

### EventRef

<a name="event-references"></a>

Which event of which digital line each epoch is aligned to: `line`, `edge`
(onset or offset), `which` interval (first, last, all, nth, with `n`),
`scope` (trial, recording or auto), a duration range, a time range,
`offsetSec`, and `offsetParam` with `offsetParamUnit`: a trial parameter
whose value on each event's trial is added to the event (fields and rules:
[`eventRef`](EphysAnalysis.md#eventref-what-each-epoch-is-aligned-to)).
Event times are seconds on the recording's clock, with each line's
polarity ([`Signals.InvertedLines`](EphysPipeline.md#digital-line-polarity))
already applied. `"Trial"` is the paired trial line: each trial's own
`[TrialOnset TrialOffset]`.

| To align to | Set |
| --- | --- |
| the first stimulus of each trial | `line "Stim"`, `edge "onset"`, `which "first"` |
| every stimulus in the recording, with or without trials | `line "Stim"`, `which "all"`, `scope "recording"` |
| the trial start | `line "Trial"` |
| the end of the response window | `line "RespWindow"`, `edge "offset"` |
| 50 ms before each platform entry | `line "Platform"`, `which "all"`, `scope "recording"`, `offsetSec -0.05` |
| only long platform visits | `line "Platform"`, `which "all"`, `scope "recording"`, `minDurationSec 1` |
| the response (Epsych2's `RespLatency`, ms after the response window opens) | `line "RespWindow"`, `edge "onset"`, `offsetParam "RespLatency"`, `offsetParamUnit "ms"` |

An event shifted by `offsetParam` keeps its trial (the one holding the
unshifted edge); an event whose trial has no finite value (a miss has no
`RespLatency`), or that lies outside the trials, is left out and counted
(`epochTable`'s `nDroppedNoValue`, the caption, the app's Alignment tab).
It needs paired trials. A [stop event](#epochwindow) with `offsetParam`
is moved by the epoch's trial's value: a stimulus-aligned raster with the
stop at `RespWindow onset + RespLatency` marks each response on its row,
and `rasterSort "stop"` sorts the rows by it (`rasterSort "event"` sorts
them by another event's latency without making it the stop:
[Raster sort by an event](#raster-sort-by-an-event)).

A line whose intervals lie between trials (`Platform` in the synthetic
project) has no event in trial scope: use recording scope for it.

#### Event sequences

An event can be a sequence of events: the line's event, then steps that
must (or must not) follow it. `sequence` is a list of steps
(`EphysAnalysisConfig.defaults("SequenceStep")`), and `alignStep` says
which event of the sequence each epoch is aligned to.

| Step field | Default | Meaning |
| --- | --- | --- |
| `relation` | `"followedBy"` | `"followedBy"`: the step's event must come; `"notFollowedBy"`: it must not |
| `line`, `edge` | `""`, `"onset"` | the step's line (`"Trial"` = the trial line) and edge |
| `n` | 1 | followedBy: the nth such event after the event before |
| `maxGapSec` | `Inf` | within this long after the event before |
| `minDurationSec`, `maxDurationSec` | 0, `Inf` | count only intervals of this length |

- Each step looks for its event after the event before it: the line's
  own event, or the last followedBy step's. A step on the same line and
  edge as the event before starts after it, so "Poke onset then Poke onset
  within 0.5 s" finds the next poke, not the same one.
- Steps read the whole recording's intervals, so a step after the trial's
  end is found. With paired trials no step looks past the onset of the
  next trial (an event on that onset still counts).
- An event whose sequence does not complete is left out before `which`
  picks: `which "first"` is the first event that the sequence follows.
  What the sequence cost is counted (`epochTable`'s
  `nDroppedNoSequence`, the caption, the app's Alignment tab): per trial
  (trial scope) or over the recording, the picks `which` would have made
  without the sequence less those it made; with `which "all"`, every event
  the sequence does not follow.
- `alignStep`: `Inf` (default) aligns each epoch to the last followedBy
  step's event, `k` to step `k`'s (a followedBy step), `0` to the line's
  own event (the steps are then conditions only). The epoch's trial is
  always the one holding the line's own event, so the trial selection,
  groups and `offsetParam` go by it.
- A stop event can have a sequence too: it is then the first of its
  line's events at or after the epoch's event whose sequence follows, at
  its `alignStep`. So can a raster mark ([Raster event marks](#raster-event-marks)).

| To align to | Set |
| --- | --- |
| the first Trough onset after each CR trial ends | `line "Trial"`, `edge "offset"`, `sequence [{line "Trough"}]`; selection `response ["CR"]` |
| the second Trough onset after the trial ends, within 3 s | `sequence [{line "Trough", n 2, maxGapSec 3}]` |
| the end of the first long Trough visit after the response window | `line "RespWindow"`, `edge "offset"`, `sequence [{line "Trough", edge "offset", minDurationSec 0.5}]` |
| stimuli that a Trough onset follows within 1 s, at the stimulus | `line "Stim"`, `sequence [{line "Trough", maxGapSec 1}]`, `alignStep 0` |
| trial ends with no Trough onset before the next trial | `line "Trial"`, `edge "offset"`, `sequence [{relation "notFollowedBy", line "Trough"}]` |

```json
"ref": { "line": "Trial", "edge": "offset", "which": "first", "scope": "trial",
         "sequence": [ { "relation": "followedBy", "line": "Trough", "edge": "onset", "n": 1,
                         "maxGapSec": "Inf", "minDurationSec": 0, "maxDurationSec": "Inf" } ],
         "alignStep": "Inf" },
"selection": { "response": ["CR"] }
```

`eventRefLabel` names a sequence step by step ("Trial offset then Trough
onset"); titles, captions and raster-mark legends use it.

### EpochWindow

The span of each epoch: `"fixed"`, `[t0 + pre, t0 + post]`, or
`"between"`, `[t0 + pre, t1 + post]` where `t1` is the `stop` event, for a
variable-length period such as `RespWindow` onset to `RespWindow` offset
(the second plot of the [JSON example](#json-example)); fields and rules:
[`epochWindow`](EphysAnalysis.md#epochwindow-the-span-of-each-epoch). A
`stop` in a fixed window still sets `t1`, so PSTHs and rasters mark it and
`maskAfterStop` can drop what follows it. Only rate, tuning and corrmap
plots take a `"between"` window ([kinds](#plots)). A `stop` is an
[EventRef](#eventref), `offsetParam` included.

Epochs without a stop event, epochs whose window leaves the recording and
epochs whose window or baseline window touches an artifact period are
dropped; the app's Alignment tab counts each.

### TrialSelection

Which trials take part and how they are grouped, from the paired trials of
`<Name>_behavior.mat`: a `filter` expression over the trials table,
`response` words (`Hit`, `Miss`, `CR`, `FA`, ...), `pairingFlags` (`ok`,
`partial`, `cut`, `unpaired`; `[]` keeps every flag), explicit `trials`,
and `groupBy` (0-2 trial parameters) with `groupOrder` and `maxGroups`
(fields, filter syntax and group colours:
[`trialSelection`](EphysAnalysis.md#trialselection-which-trials-in-which-groups)).
A filter is checked for syntax when the config is validated (a warning)
and against each dataset's trial columns when it runs. Without paired
trials there is one group, `all`, and a selection that filters or groups
trials makes the runner skip the plot on that dataset (*no paired trials*).

### UnitSelection

A plot's `units` (its `source` is the plot's `source`). Sorted units
(`"units"`) come from the sorting folder, threshold detections
(`"detected"`, one "unit" per channel) from the spikes file; `classes`,
`groups` and `quality` apply to sorted units only.

| Field | Default | Meaning |
| --- | --- | --- |
| `classes` | `["su" "mua"]` | sorted-unit classes kept: `su` (phy's good), `mua`, `uns` (unsorted), `other` (any other phy label); noise clusters are never read. `[]` = all |
| `groups` | none | phy groups kept (`[]` = all) |
| `ids` | `[]` | unit ids (sorted) or channels (detected) |
| `channels` | `[]` | 1-based recording channels |
| `shanks` | `[]` | shanks, as the probe map's `kcoords` values for both sources (a sorted unit on a mapped channel takes its channel's shank; single-shank maps usually use 0) |
| `maxUnits` | `Inf` | at most this many, in order (at least 1) |
| `quality` | `enabled` false, and [`unitQualityCriteria`](../pipeline/unitQualityCriteria.m)'s thresholds (`isiViolationsRatioMax` 0.5, `presenceRatioMin` 0.9, `amplitudeCutoffMax` 0.1; `snrMin`, `driftPtpMax`, `firingRateMin` off; `unknown` `"pass"`) | with `enabled`, only the sorted units that meet the criteria are kept: their quality metrics come from the dataset (`EphysDataset.unitQuality`; the recording's noise only when `snrMin` is set) or, without it, from the recording's length the source knows (no SNR), through the sort folder's `quality_metrics.json` when current. The units' metrics and `qualityPass` / `qualityFails` / `qualityUnknown` are added to the unit table ([Unit quality metrics](EphysDataset.md#unit-quality-metrics)) |
| `response` | `enabled` false, `test` `"evoked"`, `baseline` `[-0.2 0]`, `window` `[0 0.2]`, `param` `""`, `direction` `"any"`, `correction` `"bh"`, `alpha` 0.05, `auroc` (below) | with `enabled`, only the units that pass the test are kept ([response statistics](EphysAnalysis.md#response-statistics)), after the other fields and before `maxUnits`. The test runs over the plot's event reference and trial selection, on epochs of one fixed window that holds both test windows (those that leave the recording or touch an artifact period are left out). `test`: `"evoked"` (the response window's rate differs from the baseline window's, `signrank`), `"tuning"` (it differs across `param`'s levels, `kruskalwallis`), `"either"`, `"both"`, or `"auroc"`: the units the auROC calls modulated over `window` (`aurocCurves` over the same epochs, all of them one group; [auROC](#auroc)), with `auroc`'s `method`, `windows`, `windowSec`, `stepSec`, `binSec` (its own bins, 0.01), `cutoff` (`"ci"`, `"fixed"` or `"test"`; not `"none"`), `threshold`, `test` and `nResamples`. `baseline` and `window` are s from the event. `param` is needed by `"tuning"`, `"either"` and `"both"`. `direction` (every test but `"tuning"`) is `"any"`, `"excited"` or `"suppressed"` (auroc: called up or down). `correction` is `"bh"`, `"holm"`, `"bonferroni"` or `"none"`, over the units tested. A unit passes when its adjusted p is at most `alpha` (auroc: when called modulated; `correction` and `alpha` serve its `"test"` cutoff). The unit table gains the test's columns: `baselineRate`, `responseRate`, `pEvoked`, `qEvoked`, `direction`, `responsive` and, with `param`, `nLevels`, `pTuning`, `qTuning`, `tuned`, `bestLevel`, `bestRate`; for `"auroc"` instead `aurocMean`, `aurocPhasic`, `aurocP`, `aurocQ`, `aurocDirection` and `aurocModulated`. Needs the Statistics and Machine Learning Toolbox |

### Style

| Field | Default | Meaning |
| --- | --- | --- |
| `LineWidth` | 1.2 | traces, PSTH lines and bar outlines |
| `ShowSEM` | `true` | SEM bands / error bars |
| `ShowStop` | `true` | stop-event marks (mean per group; a dot per raster row) |
| `ShowZeroLine` | `true` | a dotted line at the event |
| `Colormap` | `"lines"` | group colours: `"lines"` keeps selectTrials' colours; any colormap name resamples them; a colour name or hex code (`"black"`, `"#1f77b4"`) gives every group that colour |
| `HeatColormap` | `""` | heatmaps, probe maps and unit correlations; `""` = parula, or `blueWhiteRed` for corrmap |
| `FontSize` | 9 | |
| `SiteSize` | 8 | probe map: the sites' marker size, points |
| `YLim`, `XLim`, `CLim` | `[]` | fixed limits (`[]` = automatic). `YLim` is used by the unstacked PSTH rate panels, the evoked butterfly and grid layouts, and the rate and tuning plots only: rasters show every epoch, and a stacked PSTH and an evoked stack ignore it. The automatic `CLim` is the range of every tile, `[0 1]` for an auROC heatmap and `[-1 1]` for a corrmap |
| `Grid`, `Legend` | `true` | |
| `LegendLocation` | `"auto"` | where the legend goes: `"auto"` (a grid's east of the grid, a single plot's in its own place), `"inside"` (in the first tile), or `"north"`, `"south"`, `"east"`, `"west"`: outside the whole grid of plots, on that side (beside the axes when the plot is a single axes). A stacked PSTH has no legend |
| `LegendOrientation` | `"auto"` | `"vertical"` or `"horizontal"` entries; `"auto"` lays a legend north or south of the grid out horizontally, any other vertically |
| `LegendBox` | `false` | the legend's outline and background |
| `MaxTiles` | 16 | tiles per page in grid layouts (psth and tuning grids, rasters, evoked grids): a plot with more units or channels has several pages |
| `TileSpacing` | `"compact"` | space between the tiles of a grid, and round it: `"loose"`, `"compact"`, `"tight"`, `"none"` |
| `SortDepth` | `true` | units / channels with the top of the probe first (probe `y`); applies to every kind but probemap (psth, raster, tuning tiles, rate bars, evoked, heatmap and corrmap rows) |
| `SortShank` | `false` | units / channels grouped by shank first (ascending); with `SortDepth`, top first within each shank. Neither ticked: as listed |
| `LabelDepth`, `LabelShank` | `false` | append the probe depth (`y`, µm) and / or the shank to the unit / channel labels, e.g. `su3 (sh1, 640 µm)` |
| `StackSpacing` | `NaN` | evoked `"stack"` offset (NaN = 1.2 x the 90th percentile of the channels' ranges) |

## Plots

`Plots` is a list of plot entries (`EphysAnalysisConfig.defaults("Plot")`).
Every field exists on every entry; a kind ignores the fields it does not
use.

| Field | Default | Meaning |
| --- | --- | --- |
| `id` | auto | unique, also as a file name (sanitized, case-blind: see above); names exported files (`{Plot}`) |
| `kind` | `"psth"` | one of the kinds below |
| `enabled` | `true` | a disabled plot is kept but not run |
| `title` | `""` | `""` = automatic: `<Label>: <line> <edge> (<n> epochs)` (a probe map: its value and the number of units or channels) |
| `source` | `"units"` | spike kinds: `"units"` (sorted units) or `"detected"` (threshold detections); signal kinds: `"LFP"`, `"MUA"`, `"SPIKE"`, `"AUX"`; behavior: `"trials"` |
| `units` | [UnitSelection](#unitselection) | spike sources: which units |
| `channels` | `[]` | signal sources: the extract's columns drawn (`[]` = all) |
| `ref`, `window`, `selection` | `"default"` | or the plot's own [EventRef](#eventref) / [EpochWindow](#epochwindow) / [TrialSelection](#trialselection). A probe map, which is not aligned, uses them only for a `units.response` test |
| `bins` | `BinSec` 0.01, `SmoothSec` 0.01 | psth, raster, heatmap of spikes and a corrmap's `"peak"` rate: the bin width (bins are whole multiples of `BinSec` from the event) and the Gaussian SD applied to each epoch before averaging, s (0 = no smoothing) |
| `measure` | `"rate"` | psth, heatmap of spikes, rate, tuning: `"rate"` (spikes/s), `"count"` (spikes per bin, or per epoch window) or `"probability"` (the share of epochs with a spike in the bin, or window). The baseline is measured the same way |
| `baseline` | `Mode "none"`, `Window [-0.2 0]` | see the kinds. `Mode "auroc"` (psth, heatmap of spikes): each window's auROC against the baseline window, 0 to 1, with `auroc`'s settings ([auROC](#auroc)) |
| `auroc` | [Auroc](#auroc) | psth, heatmap of spikes with `baseline.Mode "auroc"`: how the auROC is made and units are called |
| `layout` | `""` | `""` = the kind's default |
| `withRaster` | `true` | psth: a raster above each unit |
| `rasterSort` | `""` | psth, raster: the order of each group's epochs in the raster. `""` = trial (time) order; `"stop"` = by the stop event's latency; `"event"` = by the latency of `rasterSortEvent` ([Raster sort by an event](#raster-sort-by-an-event)); else a trial parameter, which the compute copies onto the epochs (`epochTable(..., Columns=)`). Groups stay in their own bands (see `rasterByGroup`); missing values sort last and ties keep the trial order |
| `rasterSortEvent` | `[]` | psth, raster with `rasterSort "event"` (required then): the [event reference](#eventref) whose latency from each epoch's event orders the rows, e.g. `{ "line": "Platform", "edge": "offset" }` (a line name alone is short for its onset). Ignored by the other sorts |
| `rasterSortOrder` | `"ascending"` | psth, raster: the direction of `rasterSort`: `"ascending"` or `"descending"` (with `rasterSort ""`, the last trial first). Missing values stay last either way; ties keep the trial order |
| `rasterByGroup` | `true` | psth, raster: the rows go by group first, each group on a band of its colour; `false`: every epoch sorted by `rasterSort` as one block, each row on its group's colour (the y label adds "groups mixed") |
| `rasterEvents` | none | psth, raster: marks on each raster row at digital-line events inside its epoch ([Raster event marks](#raster-event-marks)) |
| `histStyle` | `"bar"` | psth: `"bar"` (one bar per bin) or `"line"` (a trace through the bin centres) |
| `fill` | `true` | psth: fill the bars, or the area under the line; `false` = the bars' outline, or the line alone |
| `fillAlpha` | `NaN` | psth: fill opacity 0-1; `NaN` = 0.5 where groups are overlaid, else 1 |
| `normalize` | `"none"` | psth: `"unitPeak"` divides each unit's PSTHs by their largest absolute value over every group (the groups keep their sizes); `"groupPeak"` divides each PSTH by its own. The overlay layout normalizes each unit before the mean |
| `stack` | `false` | psth: one row per group instead of overlaid (see [Stacked PSTHs](#stacked-psths)) |
| `stackSpacing` | 1.1 | psth stack: the row step, times the panel's tallest PSTH (1 = it just reaches the next row; below 1 the rows overlap) |
| `maskAfterStop` | `false` | psth, raster, heatmap of spikes: drop each epoch's bins, and its raster ticks, from its stop event on (the mean then covers the epochs still going) |
| `param`, `seriesParam` | `""` | tuning, behavior: the trial parameter on the x axis (required); one curve (series) per value of the series parameter (`""` = one) |
| `yParam` | `""` | behavior: what each epoch shows (required): a numeric trial parameter, e.g. `"RespLatency"` (as recorded; Epsych2 stores ms), or `"stop"`: the epoch's stop-event latency from its event, ms (needs a stop event) |
| `jitter` | `true` | behavior `"points"`: spread the points sideways, a fixed, repeatable pattern up to 0.3 of the series' slot either way; `false`: each point on its x value |
| `xScale` | `"category"` | behavior: `"category"` (the x values evenly spaced, labelled with their values) or `"linear"` (at their values, numeric x only; text values are spaced evenly) |
| `value` | `"rate"` | probemap, per site, over the whole recording: `"rate"` (the units' summed rate, Hz), `"nSpikes"` (their summed spike count) or `"nUnits"` |
| `order` | `"probe"` | heatmap rows: `"probe"` (the style's `SortDepth` / `SortShank`), `"peak"` (by the time of each row's maximum) or, with the auROC baseline, `"modulation"` (by the first group's mean auROC in the call window, highest first; the other tiles keep that order, as the paper's Fig 3A). A corrmap follows the style's sort options |
| `metric` | `"mean"` | corrmap: each epoch's `"mean"` rate over its window, or its `"peak"` binned rate (`bins`) |
| `correlation` | `"pearson"` | corrmap: `"pearson"` or `"spearman"` |
| `waveform` | [Waveform](#unit-waveforms), `mode "off"` | raster, psth and tuning grids of spikes: each unit's waveform in its tile; a `waveforms` plot: its settings (mode `"both"` for a plot added by `addPlot` or the app) |
| `note` | [Note](#plot-notes), no text | descriptive text on the plot: its words, where it goes and how it looks (every kind) |
| `overlays` | none | [lines and semitransparent patches](#plot-overlays) drawn on the plot's axes in data units, over or under its data: a list, any number, each with its own place and look (every kind) |
| `style` | [Style](#style) | |
| `aesthetics` | none | remembered looks of the plot's components: a list of rules `{role, group, property, value}` (`group` `""` = every group; `value` a number, an `[r g b]` colour or text), applied after drawing, over the user's own rules for the kind. The preview's right-click editor writes them ([Plot aesthetics](EphysAnalysis.md#plot-aesthetics)); a rule with a property the editor does not know is refused (`EphysAnalysisConfig:BadValue`) |

The kinds, from `EphysAnalysisConfig.plotKinds()`; the app's
[Plot kinds](EphysAnalysisApp.md#plot-kinds) shows each.

| Kind | Label | Sources | Layouts (first = default) | Windows | Baseline modes | Draws |
| --- | --- | --- | --- | --- | --- | --- |
| `psth` | PSTH | units, detected | grid, overlay | fixed | none, subtract, zscore, percent, auroc | peri-event firing rate per unit (with a raster), groups overlaid |
| `raster` | Raster | units, detected | grid | fixed | none | spike rasters per unit, epochs sorted by group |
| `evoked` | Evoked potential | LFP, MUA, SPIKE, AUX | stack, butterfly, grid | fixed | none, subtract | event-locked average of the channels |
| `rate` | Firing rate | units, detected | bar, box, points | fixed, between | none, subtract, ratio, zscore | mean rate per unit and group in each epoch window |
| `tuning` | Tuning curve | units, detected | grid, overlay | fixed, between | none, subtract, ratio, zscore | rate against a trial parameter, one curve per series |
| `heatmap` | Heatmap | all six | groups | fixed | spikes: as psth (auroc too); signals: none, subtract | units or channels by time, one tile per group |
| `probemap` | Probe map | units, detected | shanks | (no alignment) | none | a per-channel value on the probe sites |
| `corrmap` | Unit correlation | units, detected | groups | fixed, between | none, subtract | pairwise correlation of the units' per-epoch mean or peak rates, one matrix per group |
| `behavior` | Behavior | trials | points, line, box, swarm, violin | fixed | none | a per-trial value (`yParam`) against a trial parameter, one series per value of another ([Behavior plots](#behavior-plots)) |
| `waveforms` | Unit waveforms | units, detected | grid, probe | (no alignment) | none | each unit's mean waveform and a sample of its spikes, a tile per unit or at the unit's place on the probe ([Waveforms plots](#waveforms-plots)) |

What the baseline modes do (`baseline.Window` `[b0 b1]`, s from the event):

| Kind | `subtract` | `zscore` | `percent` / `ratio` |
| --- | --- | --- | --- |
| psth, heatmap of spikes | the measure minus the baseline's mean over the group's epochs | (measure − that mean) / the baseline's SD over the group's epochs | `percent`: 100 (measure − mean) / mean |
| rate, tuning | each epoch's value minus its own baseline | (value − the unit's mean baseline) / the SD of its baseline over every epoch | `ratio`: value / the unit's mean baseline |
| evoked, heatmap of a signal | each epoch's mean over the baseline window, per channel | | |
| corrmap | each epoch's response minus its own baseline rate | | |

`auroc` (psth, heatmap of spikes) is described [below](#auroc). A spike
baseline is counted directly from the spikes in `[t0 + b0, t0 + b1)`, so it
may lie outside the plotted window; epochs whose baseline window touches an
artifact period are dropped with the others. A signal baseline must hold
samples of the plotted window.

### Stacked PSTHs

With `stack` on, a PSTH plot with more than one group draws each group in
its own row, the first group at the bottom (use the selection's
`groupOrder` to turn it over), instead of overlaying them. Each panel's
row step is `stackSpacing` times its tallest PSTH, so every unit's tile
fills its height whatever its rate. Rows are drawn top down, so where
they overlap (`stackSpacing` below 1) the lower one is in front.

- **Left axis:** a tick at each row's baseline, labelled with the group's
  value (`0.5`, or `0.5, 1` for two `groupBy` parameters); the parameter
  names the axis.
- **Right axis:** a tick at the height where each row peaks, labelled
  with that peak in spikes/s (or the baseline mode's unit). It gives the
  scale of every row, also when `normalize` scaled the rows: a
  `groupPeak` stack still shows each PSTH's peak rate. The overlay layout
  labels the peaks of its mean, in the units of the mean (normalized when
  `normalize` is set).
- A thin grey line marks each baseline; each group's mean stop event is a
  dashed mark in its own row. There is no legend (the rows are labelled),
  and `Style.YLim` is not used.
- The raster above each tile is flipped to match, its first group at the
  bottom; like every raster it ignores `Style.YLim`.
- A plot with one group is drawn unstacked.

### auROC

`baseline.Mode "auroc"` (psth, heatmap of spikes) draws, instead of a
rate, each unit's auROC in windows along the epoch: how far the firing
in the window stands apart from the firing in the baseline window, 0 to
1, 0.5 = no difference, above = more firing (Cohen et al. 2012;
Macedo-Lima, Hamlette & Caras 2024). `aurocCurves` computes it
([auROC on the Analysis page](EphysAnalysis.md#auroc)) from the plot's
bins: `measure` `"rate"` and `"count"` give the same auROC, `"probability"`
compares spike / no spike, and `maskAfterStop` leaves out the bins from
each epoch's stop event on. Smoothing is not used and a PSTH's `normalize`
does not apply. A unit with no spike in the window and the baseline over a
group's epochs has no auROC there (NaN), so it is not called. A PSTH draws
the auROC from 0.5 on a 0-1 axis, a heatmap colours it on `[0 1]`
(`Style.YLim` / `Style.CLim` override them). The plot's `auroc`
(`EphysAnalysisConfig.defaults("Auroc")`):

| Field | Default | Meaning |
| --- | --- | --- |
| `method` | `"psth"` | the values compared: `"psth"`, the trial-averaged PSTH's bins in each window against those in the baseline (the paper's, as the Caras lab's `calculate_auROC.py`); `"epochs"`, each epoch's spike count in the window against the epochs' counts in window-long pieces of the baseline |
| `windows` | `"tiled"` | `"tiled"`: back to back, edged at whole multiples of `windowSec` from the event; `"sliding"`: one every `stepSec` |
| `windowSec`, `stepSec` | 0.1, 0.01 | the window and the sliding step, s: each a whole number of the plot's bins |
| `modulationWindow` | `[0 0.5]` | the call window, s from the event: the auROC windows wholly inside it give each unit's mean auROC and phasic modulation (mean \|auROC - 0.5\|) per group |
| `cutoff` | `"ci"` | how a unit is called modulated (up or down, per group): `"ci"`, the paper's: its mean auROC beyond 0.5 +/- the upper bound of the 95% confidence interval of the mean phasic modulation over every unit and group (it depends on the units in the plot and needs many of them; a warning says when it is too wide to call any; `populationAnalysis`, which takes these settings as its `Auroc`, pools every dataset's units for it: [population analysis](EphysAnalysis.md#population-analysis)); `"fixed"`, beyond 0.5 +/- `threshold`; `"test"`, the adjusted p of `test` at most `alpha`; `"none"`, no call |
| `threshold` | 0.1 | `"fixed"`: the distance from 0.5, at least 0 and below 0.5 |
| `test` | `"bootstrap"` | `"test"`: `"bootstrap"` (the epochs resampled `nResamples` times; p from how often the mean auROC lands across 0.5), `"ranksum"` (the call window's values against the baseline's; they share epochs, so p runs small) or `"shuffle"` (each epoch's bins shifted circularly at random `nResamples` times; p from how often the phasic modulation reaches the observed one) |
| `nResamples` | 1000 | bootstrap, shuffle |
| `correction`, `alpha` | `"bh"`, 0.05 | `"test"`: `pAdjust` (`"bh"`, `"holm"`, `"bonferroni"`, `"none"`) over every unit and group; modulated when the adjusted p is at most `alpha`. `populationAnalysis` uses its own `Correction` and `Alpha` instead |
| `marks` | `true` | draw the calls (with a cutoff): the PSTH shades the call window and puts each group's call (up / down arrow, n.s.) by the unit's title, in the group's colour (overlay: each group's count of units called up and down); the heatmap draws a bar over the call window and a red up or blue down triangle by each modulated row. The caption counts them either way |
| `modulatedOnly` | `false` | draw only the units called modulated in at least one group (needs a cutoff); when none is, the plot fails (`spikePSTH:NoneModulated`) |

The random draws come from their own stream (seed 0), so a plot gives
the same p values every time it runs.

### Raster sort by an event

`rasterSort "event"` orders a raster's rows (within each group, or across
groups with `rasterByGroup false`) by each epoch's latency to the event
`rasterSortEvent`, an [event reference](#eventref) of its own: the epoch
window and its stop event are not changed. With the epochs aligned to
`Stim onset`,

```json
"rasterSort": "event", "rasterSortEvent": { "line": "Platform", "edge": "offset" }
```

puts the trials in the order the animal left the platform after the
stimulus. The event is found as a [stop event](#epochwindow) is: the
first (`which`) event at or after the epoch's event, among the intervals
overlapping the epoch's own trial when it has one (scope `"trial"` or
`"auto"`; an interval that runs on past the trial still counts), else
over the recording; `offsetSec`, `offsetParam` and a
[sequence](#event-sequences) apply too. An epoch with no such event sorts
last in either direction, and the caption counts those epochs.
`eventLatency` computes the latencies ([Analysis page](EphysAnalysis.md#compute));
the result holds them as `R.rasterSortEvent` (`label`, `t`), and the
raster's y label reads e.g. "Epoch (by Platform offset latency)". To see
the event on each row too, mark it ([Raster event marks](#raster-event-marks)).

### Raster event marks

A raster (the raster kind, or a PSTH's raster) can mark, on each row, the
onsets and / or offsets of digital lines inside the row's epoch: every
one of them, so a trial with several beam crossings or licks gets a mark
for each. The plot's `rasterEvents`:

| Field | Default | Meaning |
| --- | --- | --- |
| `lines` | none | the lines whose events are marked (`"Trial"` = the trial line); none = no marks |
| `sequences` | none | [event references](#eventref), usually with a [sequence](#event-sequences), whose events are marked too, one mark per event at its `alignStep` (e.g. `{line "Trial", edge "offset", which "all", sequence [{line "Trough"}]}`: the first Trough onset after each trial's end). Each is resolved over every paired trial (or the recording), not only the selected ones |
| `edge` | `"onset"` | `"onset"`, `"offset"` or `"both"` (each edge is its own mark) of `lines` |
| `scope` | `"window"` | `"window"`: every event inside the epoch's window; `"trial"`: only those inside the epoch's own trial (a sequence's: those whose own trial, the one holding its first event, is the epoch's) |
| `marker` | `"diamond"` | a line marker the aesthetics editor knows (`o`, `square`, `diamond`, `^`, `v`, `>`, `<`, `+`, `*`, `.`, `x`, `_`, `\|`, `pentagram`, `hexagram`) |
| `size` | 4 | marker size, points |
| `color` | `""` | `""`: a colour per line and edge (blue, green, purple, yellow, cyan, teal; never the ticks' black or the stop dots' red); or one colour for every mark (a name or `#rrggbb`) |

`epochEvents` finds them ([Analysis page](EphysAnalysis.md#compute)) on
the clock of each epoch's event, so a mark sits where the spikes of that
sample sit. Each line and edge, and each sequence, is one component for the
[aesthetics editor](EphysAnalysis.md#plot-aesthetics), role `rasterEvent`,
group `"<line> <edge>"` (e.g. `"Trough onset"`; a sequence's
`eventRefLabel`, e.g. `"Trial offset then Trough onset"`): right-click a mark to give
one line's marks their own marker, size or colour. The raster kind's
legend lists them; the caption names them.

### Behavior plots

A `behavior` plot draws one value per epoch against a trial parameter:
behavioral time points such as the response latency over the stimulus's
depth. It reads no spikes or signals (`source "trials"`), only the paired
trials and the digital lines, so it needs paired trials. It is aligned
like the other kinds: the plot's event reference, epoch window and trial
selection give its epochs (one per trial with `which "first"`), but the
window need not lie inside the recording and artifact periods are
ignored (they concern the signals). The trial selection's groups are not
used: the series are `seriesParam`'s values.

- `yParam` a trial parameter: each epoch's trial's value, as recorded
  (the axis is labelled with the parameter's name).
- `yParam "stop"`: each epoch's stop-event latency, `t1 - t0`, in ms
  (labelled e.g. "Trough onset latency (ms)"): with the event at
  `RespWindow onset` and the stop at `Trough onset` (trial scope), the
  time from the window's opening to the response measured on the digital
  lines.

Epochs whose value is not finite (a miss's `RespLatency`; an epoch without
a stop event), or whose x or series value is missing, are left out; the
caption counts them. `behaviorValues` computes each x value's mean, SEM,
median and count per series and keeps every value; `renderBehavior`
draws them:

| Layout | Draws |
| --- | --- |
| `points` | every epoch's value as a dot (jittered with `jitter`), with each x value's mean +/- SEM |
| `line` | the mean +/- SEM at each x value, joined, one line per series |
| `box` | a box plot per x value and series (`boxchart`: median, quartiles, whiskers to 1.5 IQR, outliers as dots) |
| `swarm` | every value as a dot, spread so none overlap (`swarmchart`), with the mean +/- SEM |
| `violin` | the values' density per x value and series (`violinplot`, MATLAB R2024b or later), with the mean +/- SEM |

The series sit side by side within each x value (but for `line`), in
`Style.Colormap`'s colours; `Style.ShowSEM` turns the error bars off.
The parts are named `points`, `swarm`, `box`, `violin` and `behaviorMean`
for the aesthetics editor.

### Unit waveforms

A raster, or a PSTH or tuning curve in its `"grid"` layout, of spikes
can draw each unit's waveform on its peak channel as a small box in the
unit's tile (in the rate panel under a PSTH's raster). The plot's
`waveform` (`EphysAnalysisConfig.defaults("Waveform")`):

| Field | Default | Meaning |
| --- | --- | --- |
| `mode` | `"off"` | `"mean"`, `"subsample"` (the spikes read, thin and pale), `"both"` (the mean over the spikes), or `"off"` |
| `location` | `"northeast"` | where in the tile: `"northeast"`, `"north"`, `"northwest"`, `"west"`, `"southwest"`, `"south"`, `"southeast"`, `"east"` (north is the top edge as seen, also on a raster's reversed axis) |
| `box` | `true` | the axis box: an outline on a pale ground; `false` draws the waveform alone |
| `scale` | 1 | the box's size: 1 = a third of the tile's width and height; at most 3 |
| `maxSpikes` | 100 | the spikes drawn per unit, picked at random (the same ones each run) |

The waveforms come from `unitWaveforms` ([Analysis page](EphysAnalysis.md#unit-waveforms)):
for sorted units, `maxSpikes` of the unit's spikes cut from the sorted
`.bin` as Kilosort4 saw them (referenced and high-passed, not whitened),
and their mean; when the `.bin` is not there, the unit's template is
drawn as its mean, labelled "(template)", and a warning says why. For
detections, the waveforms the spikes file keeps (the Spikes step's
`Waveforms` option; none without it, and a warning) and the mean of them
all. Each box is on its own amplitude scale; its label gives the mean's
peak-to-peak amplitude. The box keeps the tile's limits, stays out of
the legend and its parts (`waveBox`, `waveSpikes`, `waveMean`,
`waveLabel`) take [aesthetics](EphysAnalysis.md#plot-aesthetics) like any
other. An overlay of units draws none.

### Waveforms plots

A `waveforms` plot is the unit waveforms as a plot of their own: no
events, no trials, nothing but the units (the Units & channels rows pick
which) and their waveforms. It uses the `waveform` settings above, with
`mode` never `"off"` (Validate refuses it), and three more:

| Field | Default | Meaning |
| --- | --- | --- |
| `ampScale` | `"unit"` | `"unit"`: each waveform fills its tile or glyph; `"common"`: one amplitude scale for every unit whose values are of the same kind (all µV, say), so sizes compare. Units of another kind (a template beside spikes) keep their own |
| `showSites` | `true` | probe layout: the probe's sites in grey behind the waveforms |
| `showNames` | `false` | probe layout: each unit's name beside its waveform (with the p-p amplitude and spike count when `showPP` / `showCount`) |

Layouts:

- `"grid"` (default): a tile per unit (`style.MaxTiles` per page, ordered
  and titled like the other grids by `SortDepth`, `SortShank`,
  `LabelDepth`, `LabelShank`): time from the spike (ms) against amplitude,
  the spike's time dotted, a label (`showPP`, `showCount`) in the corner.
  `ampScale "common"` gives every tile the same amplitude axis.
- `"probe"`: one panel in the probe's x and y (µm): each unit's waveform
  is a glyph centred on its position (`meta.x`, `y`), shanks side by side
  as in the probe map. `scale` sizes the glyphs (1 = about a twelfth of
  the probe's length, at least 30 µm); with `ampScale "common"` the
  largest unit fills a glyph's height, the others are in proportion, and a
  scale bar names the amplitude it spans. A unit without a position is
  left out, and the panel says so. The plot is skipped for a dataset
  without a probe map ("no probe map").

The parts (`waveSpikes`, `waveMean`, `waveZero`, `waveLabel`, `waveSites`,
`waveName`, `waveScale`) take [aesthetics](EphysAnalysis.md#plot-aesthetics).
A raster of one unit's own spikes beside its waveform is a raster with a
`waveform` box; this plot is for looking at the waveforms themselves.

### Plot notes

Any plot can carry a block of descriptive text -- a caption, a condition,
a remark -- beside or over it. The plot's `note`
(`EphysAnalysisConfig.defaults("Note")`) draws nothing until `text` has
words; the other fields are not checked until then.

| Field | Default | Meaning |
| --- | --- | --- |
| `text` | `""` | the words; a new line starts a new line of text |
| `placement` | `"below"` | outside the plot: `"below"`, `"above"`, `"right"`, `"left"` (the plot gives up a band for the text); over it, in the plot's whole area: `"northwest"`, `"north"`, `"northeast"`, `"west"`, `"center"`, `"east"`, `"southwest"`, `"south"`, `"southeast"`; or `"custom"`, at `x`, `y` |
| `x`, `y` | `0.5`, `0.5` | custom: the text's anchor, 0-1 across (from the left edge) and up (from the bottom edge) the plot's area; may lie outside it |
| `align` | `"left"` | `"left"`, `"center"` or `"right"`: how the lines line up; below and above the plot, also where the text sits across it; custom, the anchor's side of the text |
| `valign` | `"middle"` | `"top"`, `"middle"` or `"bottom"`: where the text sits up the plot beside it (right and left); custom, the anchor's place on the text |
| `rotation` | `0` | degrees, counter-clockwise (`90` reads upwards) |
| `fontName` | `""` | `""` = the design's font; or an installed font's name |
| `fontSize` | `NaN` | points; `NaN` = the plot's `style.FontSize` (or the design's size for notes) |
| `bold`, `italic` | `false` | |
| `color` | `""` | `""` = the design's text colour; or a name or `#rrggbb` |
| `background` | `""` | `""` = none; or a name or `#rrggbb` behind the text |
| `box` | `false` | an outline round the text, in its colour |
| `interpreter` | `"none"` | `"none"`: every character as typed; `"tex"`: `\mu`, `\pm`, `x^2`, `x_i`, `\bf{...}` |

`renderPlot` draws the note after the title, as a text of role `note` in a
hidden axes beside the plot's tiled layout (`drawNote`, `placeNote`; a plot
that is a single axes carries the text in the axes), so a note is a
component of the plot the [aesthetics](EphysAnalysis.md#plot-aesthetics)
editor lists and every [design](EphysAnalysis.md#plot-designs) styles
(its font and text colour). The note's own `fontName`, `fontSize`, `color`
and `background` win over the design's and the user's rules; the plot's
own `aesthetics` rules win over them. Text over the plot sits on top of
what is drawn there, the title included at the top. The text is sized as
drawn, after the design's rules, so a larger font makes a wider band.

### Plot overlays

Any plot can carry graphics drawn on its axes in data units: a line across
an axis, say at the event or a threshold, or a semitransparent patch
between two values, say a response window. The plot's `overlays` is a list
of any length (`EphysAnalysisConfig.defaults("Overlay")` is one entry; the
list is empty by default), each overlay with its own place and look, drawn
in list order.

| Field | Default | Meaning |
| --- | --- | --- |
| `name` | `""` | what the app's list and the aesthetics editor call it (`""` = `"Overlay <n>"`, *n* its place in the list). Keep the names of a plot's overlays different: a look remembered for a name reaches every overlay that has it |
| `enabled` | `true` | `false`: kept in the config, not drawn |
| `shape` | `"line"` | `"line"` (across the axis) or `"region"` (a patch between `from` and `to`) |
| `axis` | `"x"` | `"x"`: a vertical line, or a patch between two x values (the full height of the axis); `"y"`: a horizontal line, or a patch between two y values (the full width) |
| `value` | `0` | line: where it crosses the axis |
| `from`, `to` | `0`, `0.1` | region: its two edges, in either order; they must differ |
| `panel` | `"all"` | the axes it goes on, in every tile: `"all"`, `"data"` (a PSTH's rate panel, an evoked trace, a heat map, a tuning curve, ...) or `"raster"` (a PSTH's raster above its rate panel; a raster plot's own axes are raster panels) |
| `layer` | `"over"` | `"over"` the plot's data (drawn after its lines, points, bars and bands), or `"under"` it (behind them, so they hide it where they are opaque) |
| `color`, `alpha` | `"#d62728"`, `1` | line: its colour (a name or `#rrggbb`) and opacity (0-1) |
| `lineStyle`, `lineWidth` | `"--"`, `1.5` | line, and a patch's outline: `"-"`, `"--"`, `":"` or `"-."`; width in points |
| `faceColor`, `faceAlpha` | `"#808080"`, `0.25` | region: its fill colour and opacity (0-1) |
| `edgeColor` | `"none"` | region: its outline colour, `"none"` for no outline (drawn in `lineStyle` and `lineWidth`) |

The values are the axis' own units: seconds from the event on a time axis, a
PSTH's rate on its y axis, an epoch number on a raster's rows, the x value of
a tuning curve, a distance in um on a probe map. An overlay does not widen
the axis, so one outside its limits is not seen; lines and patches follow the
axis when it is zoomed. A y overlay on a stacked PSTH goes on its left axis.
A partial overlay (say only `value`) is filled from the defaults.

`renderPlot` draws the overlays after the plot (`drawOverlays`) as
`xline` / `yline` objects of role `overlayLine` and `xregion` / `yregion`
objects of role `overlayRegion`, each with its name as its group, so the
[aesthetics](EphysAnalysis.md#plot-aesthetics) editor lists every overlay on
its own, in every tile it is drawn in. The overlay's own looks win over the
design's and the user's rules; the plot's own `aesthetics` rules win over
them. A patch does not take clicks, so a right-click on the plot reaches the
data under it (the editor still lists the patch). A [design](EphysAnalysis.md#plot-designs)
saved from a plot leaves its overlays out. A colour that is not one, an
opacity outside 0-1, or a style or width that is not valid is drawn with the
default's (Validate reports it); an overlay without a finite position, or a
patch with equal edges, is not drawn.

## Export

| Field | Default | Meaning |
| --- | --- | --- |
| `Enabled` | `true` | write figure files (the runner's default for `run(Export=)`) |
| `Formats` | `["png" "svg"]` | any of `png`, `eps`, `svg`, `pdf` |
| `Folder` | `{OutputFolder}\analysis` | a [folder pattern](#file-name-tokens) |
| `FilenamePattern` | `{Name}_{Plot}` | a [file-name pattern](#file-name-tokens): `{Name}` (dataset) `{Plot}` `{Kind}` `{Group}` `{Unit}` `{Index}` `{Date}`; a paged plot adds `_p<page>` unless the pattern tells its pages apart: `{Index}`, or `{Unit}` with a unit filled in (a paged evoked grid's `{Unit}` is `all` on every page) |
| `Dpi` | 150 | PNG resolution |
| `FigureSizeCm` | `[18 12]` | figure size `[width height]`; a grid page is made taller when its rows need it: 3 cm a row of tiles (4.5 cm for PSTHs with rasters) plus 1.5 cm |
| `Overwrite` | `true` | `false`: a page whose files all exist is not written again, nor drawn unless the report needs its image (HTML) or page (PDF) |

`exportFigure` writes PNG with `exportgraphics` at `Dpi`, PDF and EPS as
vector graphics (`exportgraphics`, `ContentType="vector"`) and SVG with
`print -dsvg -vector`, creating the folder.

## Report

| Field | Default | Meaning |
| --- | --- | --- |
| `Enabled` | `true` | write a report (the runner's default for `run(Report=)`) |
| `Format` | `"html"` | `"html"`, `"pdf"` or `"both"` |
| `Title` | `"{Name}"` | `{Name}` = the config's name, `{Date}` = today (yyyy-MM-dd) |
| `Folder` | `{OutputRoot}\analysis` | a [folder pattern](#file-name-tokens). Each run also writes its run record there, under `analysis_runs`, whether or not a report is written |
| `FileName` | `"analysis_report"` | a plain file name; `.html` / `.pdf` added |
| `PerDataset` | `false` | one report per dataset, named `<FileName>_<dataset>` (the folder may then use `{OutputFolder}`) |
| `EmbedFormat` | `"png"` | HTML images: `"png"` (base64) or `"svg"` (inline) |
| `Dpi` | 110 | report PNG resolution |
| `IncludeSummary` | `true` | summary tables per dataset (in the PDF, a summary page per dataset) |
| `IncludeParameters` | `true` | HTML: each plot's parameters, folded |
| `IncludeConfig` | `true` | HTML: the config JSON at the end, folded |

## File-name tokens

`figureFileName` fills the patterns, of two kinds:

| Pattern | Tokens |
| --- | --- |
| folder (`Export.Folder`, `Report.Folder`) | `{OutputFolder}` (the dataset's output folder), `{OutputRoot}`, `{Root}` (`Source.Root`), `{Name}` (the dataset), `{Date}` (yyyyMMdd) |
| file name (`Export.FilenamePattern`) | `{Name}` (the dataset), `{Plot}` (the plot id), `{Kind}`, `{Group}` (`all`: a page holds every group), `{Unit}` (the first unit on a page of a paged psth, raster or tuning grid, else `all`), `{Index}` (the page), `{Date}` (yyyyMMdd) |

- `{OutputRoot}` is `Source.OutputRoot`, else `Source.Root`, else the
  folder above the first dataset's output folder.
- In a file name, every character of a token's value outside
  `A-Z a-z 0-9 _ - .` becomes `_`; the path tokens of a folder are used as
  they are.
- A plot with several pages (a grid with more units or channels than
  `Style.MaxTiles`) gets `_p<page>` added, unless the pattern tells its
  pages apart (`Export` above).
- An unknown token is `figureFileName:UnknownToken`; a brace without its
  pair, or a file name holding `\ / : * ? " < > |`, is
  `figureFileName:BadPattern`.
- A report over every dataset with `{OutputFolder}` in its folder goes to
  the first dataset's folder (a validation warning).

With the defaults, a PSTH `psth_stim` of dataset `SYNTH-01_260918_101500`
with 20 units and 16 tiles per page is written as
`<output folder>\analysis\SYNTH-01_260918_101500_psth_stim_p1.png` and
`..._p2.png` (and `.svg`), and the report as
`<output root>\analysis\analysis_report.html`.

## Validation

`issues = cfg.validate()` returns a table `Section`, `Field`, `Severity`,
`Message`; empty means clean. The app refuses to run a config with errors
(warnings do not stop it); `EphysAnalysisRunner.run` does not validate.
`CheckPaths=false` skips the checks that folders exist.

| Section | Rule | Severity |
| --- | --- | --- |
| Source | Mode is project / folders. Project mode: Root set and existing (CheckPaths), Selection all / list, NamePattern parses, Recordings is one of the three modes. Folders mode: at least one folder, and each exists (CheckPaths) | error |
| Source | a "list" selection with no datasets; an OutputRoot that does not exist | warning |
| Defaults, Plots | the event reference, window and selection are valid: known values, `n` a whole number >= 1, `0 <= minDurationSec <= maxDurationSec`, `timeRange` ordered, a finite `offsetSec`, `offsetParamUnit` ms or s, each sequence step's relation, line, edge, `n`, positive `maxGapSec` and lengths, an `alignStep` of 0, `Inf` or a followedBy step (the stop's and each raster-mark sequence's too), finite `pre` and `post`, `pre <= post` in a fixed window, a stop event in a `"between"` window, known response words and pairing flags, at most 2 distinct `groupBy` parameters, `maxGroups` and `trials` whole numbers >= 1 | error |
| Defaults, Plots | a filter that does not parse | warning (it is checked against each dataset's trials when it runs) |
| Plots | at least one enabled; ids that stay distinct once `{Plot}` has sanitized them (case-blind); the kind exists; the source, layout, window mode and baseline mode fit the kind; `measure` rate / count / probability; tuning names its parameter; behavior names `param` and `yParam` (`"stop"` with a stop event), its `xScale` is category / linear and the violin layout has `violinplot`; a psth / raster `rasterSortOrder` ascending / descending, a `rasterSortEvent` (a valid event reference) with `rasterSort "event"`, and `rasterEvents` edge, scope, marker and a positive size; `BinSec > 0`, `SmoothSec >= 0` where bins are used; a baseline window `[b0 b1]` with `b0 < b1`; probemap value, psth `histStyle` bar / line, `normalize` none / unitPeak / groupPeak, `fillAlpha` 0-1 or NaN, `stackSpacing > 0`; heatmap order (`"modulation"` only with the auROC baseline); the auROC settings (method, windows, whole-bin window and step, call window, cutoff, threshold, test, `nResamples`, correction, alpha, `modulatedOnly` with a cutoff) and the toolbox they need; corrmap metric and correlation; `maxUnits >= 1`; an enabled response test of spikes: its test, `param` for tuning / either / both, `baseline` and `window` ordered, direction, correction, alpha in (0, 1], the auROC settings of a test `"auroc"` (with a cutoff) and the Statistics and Machine Learning Toolbox; a `waveform` mode off / mean / subsample / both and, when not off, its location, `scale` in (0, 3] and a whole `maxSpikes >= 1`; for a note with text, its `placement`, `align`, `valign`, `interpreter`, a numeric `rotation`, a positive or `NaN` `fontSize`, and `x` and `y` for `"custom"`; for each overlay, its `shape` line / region, `axis` x / y, a finite `value` (line) or two finite, different `from` and `to` (region), `panel` all / data / raster, `layer` over / under, a `lineStyle` among `-` `--` `:` `-.`, a positive `lineWidth` and `alpha` and `faceAlpha` within 0-1; `MaxTiles >= 1`, `TileSpacing` loose / compact / tight / none, `FontSize`, `LineWidth`, `SiteSize` positive | error |
| Plots | a `HeatColormap` that is not a colormap function; a `Colormap` that is neither a colormap function nor a colour (the default is used); a `rasterEvents.color` that is not a colour (each mark gets its own); a `waveform` mode on a plot that draws no unit tiles (an overlay, a plot of signals, a kind other than raster / psth / tuning / waveforms); a note's `color` or `background` that is not a colour (left to the design); an overlay's `color`, `faceColor` or `edgeColor` that is not a colour (its default is drawn); an overlay's raster or data `panel` on a plot that draws no such panel (nothing is drawn); two overlays of a plot with one `name` | warning |
| Export | formats are png / eps / svg / pdf (and at least one when enabled); `Dpi` positive; `FigureSizeCm` two positive numbers; the folder and file-name patterns use known tokens, and the file-name pattern is not empty | error |
| Export | a file-name pattern without `{Plot}` while several plots are enabled (`{Kind}` is enough when the enabled plots all differ in kind); neither the folder nor the file-name pattern names the dataset (`{OutputFolder}` or `{Name}`), unless the source is a single folder: files that would overwrite each other | warning |
| Report | Format html / pdf / both, EmbedFormat png / svg, `Dpi` positive, a plain `FileName`, the folder pattern | error |
| Report | `{OutputFolder}` in a report over every dataset | warning |

Whether a dataset can draw a plot (units, signals, trials, lines,
parameters, a probe) is not a config error: the runner skips that plot on
that dataset and says why ([Why is my plot skipped?](EphysAnalysisApp.md#why-is-my-plot-skipped)).

## Tests

`test_EphysAnalysisConfig`: defaults, save / load round trips (Inf, NaN,
one- and two-item lists, `"default"` sentinels, stop events, the PSTH stack
and unit-waveform settings, the raster's sort (its sort event too, and a
line name as one) and event marks, behavior fields, events shifted by a
parameter), `plotFor`, `removePlot`,
`enabledPlots`, auto and duplicate ids, `addPlot`'s source by kind, a cell
of partial plots, every validate rule (ids and patterns whose files would
collide, the auROC baseline and response test, behavior plots, the
raster's sort event and raster marks included), `LoadWarnings`, `BadSchema`, `BadValue`,
`figureFileName` and `plotFileName`'s page suffix.

<!-- wiki
## Related

- [Analysis app](EphysAnalysisApp.md): the GUI that edits a config
- [Analysis scripting](EphysAnalysis.md): running configs from scripts, generated scripts, the functions
- [Pipeline configs](Pipeline-Configs): the pipeline config, whose project settings `Source` mirrors
- API: [EphysAnalysisConfig](API-EphysAnalysisConfig), [EphysAnalysisRunner](API-EphysAnalysisRunner), [Analysis functions](API-Analysis-Functions)
-->
