# EphysAnalysisConfig

`EphysAnalysisConfig` ([source](../analysis/@EphysAnalysisConfig/EphysAnalysisConfig.m))
is a value class that describes a set of quick-look figures: which datasets
to read, how to align them, which plots to draw (and which to draw
[across sessions](#session-plots)), which multi-panel [figures](#figures) to
design for one unit or channel, and how to export and
report the plots. `EphysAnalysisApp` edits one, `EphysAnalysisRunner` runs one and
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
| `Figures` | struct array, one entry per [figure](#figures): one observation's panels (a unit, a channel or the dataset) on a grid. Its ids are unique among figures (`EphysAnalysisConfig:DuplicateFigureId`; a figure's panel ids `EphysAnalysisConfig:DuplicatePanelId`) and, as `{Plot}` writes them, distinct from the plots' ids, as both name files; a cell array is accepted as for `Plots`. A run draws the enabled figures, a page per observation ([Export](#export), [Report](#report)) |
| `SessionPlots` | struct array, one entry per [session plot](#session-plots): one plot drawn over several datasets and merged. Its ids are a namespace of their own (`EphysAnalysisConfig:DuplicateSessionPlotId`); a cell array is accepted as for `Plots` |
| `File`, `LoadWarnings` | transient: where it was loaded from / saved to; the unknown fields `load` dropped |
| `Schema`, `Version`, `Sections`, `Kinds`, `SpikeSources`, `SignalSources`, `FigureSources`, `ObserveKinds`, `WaveformLocations`, `ListFields` | constants (`FigureSources`: what a figure's layer reads, `ObserveKinds`: what a figure is drawn for; `Figures` is a list like `Plots`, not one of the four `Sections`). The session plots' choices: `SessionKinds` (the plot kinds that can be merged: `psth`, `raster`, `evoked`, `rate`, `tuning`, `behavior`, `heatmap`, `waveforms`), `SessionSeries`, `SessionMatches`, `SessionErrors`, `SessionData`, `SessionTrialGroups`, `SessionFacets`, `SessionColorOrders` |
| `toStruct()`, `toJson()`, `save(file)` | plain struct; the JSON `save` writes (`Inf` / `-Inf` / `NaN` as `"Inf"` / `"-Inf"` / `"NaN"`) |
| `EphysAnalysisConfig.load(file)`, `fromStruct(s)` | errors `EphysAnalysisConfig:BadSchema` on another schema or version |
| `validate(CheckPaths=true)` | issues table `Section, Field, Severity, Message` ([rules](#validation)) |
| `addPlot(kindOrStruct, Id=)`, `removePlot(id)`, `plotIndex(id)`, `plotIds()`, `enabledPlots()` | the plot list. `[cfg, id] = cfg.addPlot(...)` also returns the plot's id; a plot added without a `source` reads its kind's first (`units`; `LFP` for evoked, `trials` for behavior); `removePlot` of an unknown id is `EphysAnalysisConfig:NoPlot`; `plotIndex` is 0 for one |
| `plotFor(id)` | a plot (by id or index) with every `"default"` resolved from `Defaults`, `units.source` set to the plot's `source` and an empty layout replaced by the kind's default: what the runner draws |
| `addFigure(templateOrStruct, Id=)`, `removeFigure(id)`, `figureIndex(id)`, `figureIds()`, `enabledFigures()` | the figure list. `[cfg, id] = cfg.addFigure("rasterPsth")` (a template's name from `figureTemplates()`, or a partial figure struct) returns the new id too, `"figure_<n>"` when none is given; `removeFigure` of an unknown id is `EphysAnalysisConfig:NoFigure`; `figureIndex` is 0 for one |
| `figureFor(idOrIndex)` | a figure with every `"default"` resolved and each panel's type facts and each layer's category added: what the compute draws ([Resolving a figure](#resolving-a-figure)). `EphysAnalysisConfig:NoFigure` for an unknown one |
| `EphysAnalysisConfig.plotToFigure(cfg, plotId)`, `cfg.convertPlotToFigure(plotId)` | the figure that draws what a plot draws, and the notes on what it could not carry; `convertPlotToFigure` appends it as `<plot>_fig` and returns `[cfg, id, notes]` ([Converting a plot](#converting-a-plot)) |
| `addSessionPlot(plotIdOrStruct, Id=)`, `removeSessionPlot(id)`, `sessionPlotIndex(id)`, `sessionPlotIds()`, `enabledSessionPlots()` | the session plot list. `[cfg, id] = cfg.addSessionPlot("psth_stim")` (a base plot's id, or a partial session plot struct) returns the new id too, `"<plot>_sessions_<n>"` when none is given; `removeSessionPlot` of an unknown id is `EphysAnalysisConfig:NoSessionPlot`; `sessionPlotIndex` is 0 for one |
| `sessionPlotFor(idOrIndexOrStruct)` | the *effective spec* of a session plot: `plotFor(sp.plot)` with `enabled = true`, `id = sp.id`, `title` and `layout` replaced when the session plot sets them, and with `trialGroups "pool"` the trial groups cleared (`selection.groupBy = []`, and a tuning or behavior plot's `seriesParam = ""`: the sessions are the series). The session plot's own look travels as `spec.sessionAesthetics`, which `renderPlot` applies after the base plot's `aesthetics`. `EphysAnalysisConfig:NoSessionPlot` for an unknown session plot, `EphysAnalysisConfig:NoPlot` when its base plot does not exist |
| `isequalConfig(other)` | same values (NaN equal) |
| `defaults(section)`, `normalizeSection(section, s)`, `normalizePlot(p)`, `plotKinds()` | static: the single source of truth for fields, types and shapes |
| `panelTypes()`, `sourceCategories()`, `figureTemplates()`, `categoryOf(source, type)`, `observeKind(fig)`, `defaultLayer(type)`, `normalizeFigure(f)`, `normalizePanel(p)`, `normalizeLayer(L)` | static: the figures' tables and helpers ([Figures](#figures)). `placePanel`, `removePanel`, `movePanel` and `figureCells` are the [grid editing](#editing-the-grid) |

Values are coerced to the class and shape of their default on every
assignment: a one-element list read back from JSON is a list again, `"Inf"`
is `Inf`, `[]` is an empty list or number. String fields named in
`ListFields` (`response`, `pairingFlags`, `groupBy`, `classes`, `groups`,
`Formats`, `Datasets`, `Folders`, `datasetKeys`, `data`) stay lists even with one element. Missing
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
      "rasterEvents": [],
      "histStyle": "bar", "fill": true, "fillAlpha": "NaN", "normalize": "none",
      "stack": false, "stackSpacing": 1.1, "stackRaster": false, "stackRasterEqual": false, "stackRasterTrials": "Inf", "maskAfterStop": false, "param": "", "seriesParam": "",
      "yParam": "", "jitter": true, "xScale": "category",
      "value": "rate", "order": "probe", "metric": "mean", "correlation": "pearson", "fisherZ": false,
      "waveform": { "mode": "both", "location": "northeast", "box": true, "scale": 1, "maxSpikes": 100 },
      "aux": { "mode": "magnitude", "channels": [1, 2, 3], "placement": "below", "baseline": "subtract",
               "baselineWindow": [-0.2, 0], "byGroup": true },
      "style": { "MaxTiles": 16, "...": "..." }, "aesthetics": [] },
    { "id": "rate_resp", "kind": "rate", "source": "units",
      "ref": { "line": "RespWindow", "edge": "onset", "which": "first", "scope": "trial", "...": "..." },
      "window": { "mode": "between", "pre": 0, "post": 0,
                  "stop": { "line": "RespWindow", "edge": "offset", "which": "first", "scope": "trial", "...": "..." } },
      "selection": { "filter": "Hit | Miss", "groupBy": "Depth", "...": "..." },
      "baseline": { "Mode": "subtract", "Window": [-0.5, 0] }, "...": "..." } ],
  "Figures": [
    { "id": "unit_card", "enabled": true, "title": "",
      "observe": { "kind": "auto", "source": "units", "units": { "classes": ["su"], "...": "..." }, "...": "..." },
      "grid": { "rows": 3, "cols": 1, "rowHeights": [1.5, 1, 1], "colWidths": [], "spacing": "none" },
      "common": { "bins": { "BinSec": 0.01, "SmoothSec": 0.01 }, "measure": "rate", "...": "..." },
      "ref": "default", "window": "default", "selection": "default",
      "panels": [ { "id": "raster_1", "type": "raster", "row": 1, "col": 1, "common": true, "...": "..." },
                  { "id": "psth_1", "type": "psth", "row": 2, "col": 1, "common": true, "...": "..." },
                  { "id": "continuous_1", "type": "continuous", "row": 3, "col": 1, "common": true, "...": "..." } ],
      "style": { "...": "..." }, "aesthetics": [] } ],
  "SessionPlots": [
    { "id": "psth_days", "enabled": true, "title": "", "plot": "psth_stim", "layout": "overlay",
      "datasets": "ticked", "datasetKeys": [], "facet": "none", "series": "subject", "colorOrder": "palette",
      "showMembers": true, "error": "ci95", "match": "site", "mappingFile": "", "minSessions": 2,
      "trialGroups": "pool", "data": ["results", "epochs"], "aesthetics": [] } ],
  "Export": { "Enabled": true, "Formats": ["png", "svg"], "Folder": "{OutputFolder}\\analysis",
              "FilenamePattern": "{Name}_{Plot}", "Dpi": 150, "FigureSizeCm": [18, 12], "Overwrite": true,
              "SessionsFolder": "{OutputRoot}\\analysis\\sessions",
              "Data": { "Enabled": false, "Folder": "{OutputRoot}\\analysis\\data",
                        "FilenamePattern": "{Name}_{Plot}", "MatVersion": "-v7.3" } },
  "Report": { "Enabled": true, "Format": "html", "Title": "{Name}",
              "Folder": "{OutputRoot}\\analysis", "FileName": "analysis_report", "PerDataset": false,
              "EmbedFormat": "png", "Dpi": 110, "IncludeSummary": true, "IncludeParameters": true,
              "IncludeConfig": true }
}
```

The top level holds `schema` and `version`, `name` and `description` (the
class's `Name` and `Description`), the sections `Source`, `Defaults`,
`Export` and `Report`, `Plots`, `Figures` and `SessionPlots`. `save` writes every field of every
section, plot, figure and session plot, pretty-printed (the `"..."` above stand for the rest); a
file written by hand may leave fields out, and they take their defaults
when it is loaded. Two things the JSON encoder does that a hand-written
file need not copy:

- A one-element list is written as a scalar (`"pairingFlags": "ok"`,
  `"groupBy": "Depth"`), and a config with a single plot writes `Plots` as
  one object instead of an array of one (`SessionPlots`, `Figures`, a figure's
  `panels`, a panel's `layers`, and a session plot's `datasetKeys` and `data`
  the same). All read back correctly.
- A plot's `ref`, `window` and `selection` (a figure's too, and a panel's `ref`
  and `window`) are either the string
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
"UnitSelection" | "Style" | "Auroc" | "Waveform" | "Aux")`. The first three are described with their
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
(fields, filter syntax and group colors:
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
| `ShowSEM` | `true` | the error of the means: bands behind traces (PSTH, evoked stack and grid, aux signal, population curves), error bars on means (rate bars, tuning curves, behavior means); which error is `ErrorType` ([Error bands](#error-bands)) |
| `ErrorType` | `"sem"` | `"sem"`: mean +/- SEM; `"std"`: mean +/- SD of the values; `"ci95"`: the 95% confidence interval of the mean from bootstrap resamples (`bootci`, percentile; Statistics and Machine Learning Toolbox). Over the epochs (the group's, or the x value's), as the compute function makes it (`R.err`); across the units for an overlay of several units (PSTH, tuning) |
| `ErrorResamples` | 1000 | `"ci95"`: the bootstrap resamples. They come from a stream of their own (seed 0), so a plot gives the same band every time it runs |
| `ErrorFaceColor` | `""` | bands: `""` = the trace's color; or one color (a name or `#rrggbb`) for every band, drawn as given |
| `ErrorFaceAlpha` | `NaN` | bands: `NaN` = opaque, the trace's color paled 75% towards the ground (vector exports stay vector); 0-1 = the fill at that opacity, unpaled, so what is under it shows through. An aux signal drawn `"over"` a plot is 0.2 unless this is set |
| `ErrorEdgeColor` | `"none"` | bands: their outline: `"none"`, `"auto"` (the fill's color) or a color |
| `ErrorEdgeStyle`, `ErrorEdgeWidth` | `"-"`, 0.5 | bands: the outline's line style (`-`, `--`, `:`, `-.`) and width, points |
| `ShowStop` | `true` | stop-event marks (mean per group; a dot per raster row) |
| `ShowZeroLine` | `true` | a dotted line at the event |
| `Colormap` | `"lines"` | group colors: `"lines"` keeps selectTrials' colors; any colormap name resamples them; a color name or hex code (`"black"`, `"#1f77b4"`) gives every group that color |
| `HeatColormap` | `""` | heatmaps, probe maps and unit correlations; `""` = parula, or `blueWhiteRed` for corrmap |
| `FontSize` | 9 | |
| `SiteSize` | 8 | probe map: the sites' marker size, points |
| `YLim`, `XLim`, `CLim` | `[]` | fixed limits (`[]` = automatic); two ascending values, low then high. The plot editor sets `YLim` (**Y limits**) and `CLim` (**Color limits**, for heatmap, probe map and corrmap plots). `YLim` is used by the unstacked PSTH rate panels, the evoked butterfly and grid layouts, and the rate and tuning plots only: rasters show every epoch, and a stacked PSTH and an evoked stack ignore it. The automatic `CLim` is the range of every tile, `[0 1]` for an auROC heatmap and `[-1 1]` for a corrmap |
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
use. To combine panels of different types for one unit or channel (a raster
over a PSTH over an LFP trace, say), design a [figure](#figures) instead; **Convert to
figure** in the app (`convertPlotToFigure`) starts one from a plot
([Converting a plot](#converting-a-plot)).

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
| `rasterByGroup` | `true` | psth, raster: the rows go by group first, each group on a band of its color; `false`: every epoch sorted by `rasterSort` as one block, each row on its group's color (the y label adds "groups mixed") |
| `rasterEvents` | none | psth, raster: the marks on each raster row, a list of event references (with or without a sequence), each with its own look ([Raster event marks](#raster-event-marks)) |
| `histStyle` | `"bar"` | psth: `"bar"` (one bar per bin) or `"line"` (a trace through the bin centers) |
| `fill` | `true` | psth: fill the bars, or the area under the line; `false` = the bars' outline, or the line alone |
| `fillAlpha` | `NaN` | psth: fill opacity 0-1; `NaN` = 0.5 where groups are overlaid, else 1 |
| `normalize` | `"none"` | psth: `"unitPeak"` divides each unit's PSTHs by their largest absolute value over every group (the groups keep their sizes); `"groupPeak"` divides each PSTH by its own. The overlay layout normalizes each unit before the mean |
| `stack` | `false` | psth: one row per group instead of overlaid (see [Stacked PSTHs](#stacked-psths)) |
| `stackSpacing` | 1.1 | psth stack: the row step, times the panel's tallest PSTH (1 = it just reaches the next row; below 1 the rows overlap); with `stackRaster`, times a row's height |
| `stackRaster` | false | psth stack with `withRaster`: each group's raster in its own row, just above its PSTH, instead of a raster panel above the stack ([Stacked PSTHs](#stacked-psths)) |
| `stackRasterEqual` | false | `stackRaster`: every row's raster ticks one height, that of the row showing the most epochs (a row with fewer is filled from the bottom); false: each row's epochs fill its raster |
| `stackRasterTrials` | Inf | `stackRaster`: the most epochs a row's raster shows, picked evenly over its sort order (Inf = all); the PSTHs still average every epoch |
| `maskAfterStop` | `false` | psth, raster, heatmap of spikes: drop each epoch's bins, and its raster ticks, from its stop event on (the mean then covers the epochs still going) |
| `param`, `seriesParam` | `""` | tuning, behavior: the trial parameter on the x axis (required); one curve (series) per value of the series parameter (`""` = one) |
| `yParam` | `""` | behavior: what each epoch shows (required): a numeric trial parameter, e.g. `"RespLatency"` (as recorded; Epsych2 stores ms), or `"stop"`: the epoch's stop-event latency from its event, ms (needs a stop event) |
| `jitter` | `true` | behavior `"points"`: spread the points sideways, a fixed, repeatable pattern up to 0.3 of the series' slot either way; `false`: each point on its x value |
| `xScale` | `"category"` | behavior: `"category"` (the x values evenly spaced, labeled with their values) or `"linear"` (at their values, numeric x only; text values are spaced evenly) |
| `value` | `"rate"` | probemap, per site, over the whole recording: `"rate"` (the units' summed rate, Hz), `"nSpikes"` (their summed spike count) or `"nUnits"` |
| `order` | `"probe"` | heatmap rows: `"probe"` (the style's `SortDepth` / `SortShank`), `"peak"` (by the time of each row's maximum) or, with the auROC baseline, `"modulation"` (by the first group's mean auROC in the call window, highest first; the other tiles keep that order, as the paper's Fig 3A). A corrmap follows the style's sort options |
| `metric` | `"mean"` | corrmap: each epoch's `"mean"` rate over its window, or its `"peak"` binned rate (`bins`) |
| `correlation` | `"pearson"` | corrmap: `"pearson"` or `"spearman"` |
| `fisherZ` | `false` | corrmap: draw Fisher's z (`atanh r`) instead of r, and average the pairwise r in z |
| `waveform` | [Waveform](#unit-waveforms), `mode "off"` | raster, psth and tuning grids of spikes: each unit's waveform in its tile; a `waveforms` plot: its settings (mode `"both"` for a plot added by `addPlot` or the app) |
| `aux` | [Aux](#aux-signals), `mode "off"` | psth, raster of spikes: the mean aux (accelerometer) signal over the plot's epochs, each channel or their vector magnitude, in a panel below or above each unit's, or over it on a right axis |
| `note` | [Note](#plot-notes), no text | descriptive text on the plot: its words, where it goes and how it looks (every kind) |
| `overlays` | none | [lines and semitransparent patches](#plot-overlays) drawn on the plot's axes in data units, over or under its data: a list, any number, each with its own place and look (every kind) |
| `style` | [Style](#style) | |
| `aesthetics` | none | remembered looks of the plot's components: a list of rules `{role, group, property, value}` (`group` `""` = every group; `value` a number, an `[r g b]` color or text), applied after drawing, over the user's own rules for the kind. The preview's right-click editor writes them ([Plot aesthetics](EphysAnalysis.md#plot-aesthetics)); a rule with a property the editor does not know is refused (`EphysAnalysisConfig:BadValue`) |

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

- **Left axis:** a tick at each row's baseline, labeled with the group's
  value (`0.5`, or `0.5, 1` for two `groupBy` parameters); the parameter
  names the axis.
- **Right axis:** a tick at the height where each row peaks, labeled
  with that peak in spikes/s (or the baseline mode's unit). It gives the
  scale of every row, also when `normalize` scaled the rows: a
  `groupPeak` stack still shows each PSTH's peak rate. The overlay layout
  labels the peaks of its mean, in the units of the mean (normalized when
  `normalize` is set).
- A thin gray line marks each baseline; each group's mean stop event is a
  dashed mark in its own row. There is no legend (the rows are labeled),
  and `Style.YLim` is not used.
- The raster above each tile is flipped to match, its first group at the
  bottom; like every raster it ignores `Style.YLim`.
- With `stackRaster` (and `withRaster`) there is no raster panel: each
  group's raster sits in its own row, just above its PSTH and its error
  band, on its pale band as tall as the tile's tallest PSTH, its epochs
  sorted as `rasterSort` says and the first at the bottom. A row is then
  the PSTH, a small gap and the raster, and the step is `stackSpacing`
  times that. The rows go by group whatever `rasterByGroup` says, and an
  overlay on the `raster` panel has none to go on. The overlay layout's
  mean of several units has no raster.
- Each row's epochs fill its raster, so a group with few trials gets tall
  ticks. `stackRasterEqual` gives every row ticks of one height (the
  fullest row's), the rows with fewer epochs filled from the bottom, and
  `stackRasterTrials` caps the epochs a raster shows: that many, picked
  evenly from the first to the last in the row's sort order (so a raster
  sorted by latency keeps its spread). With both, every row with that
  many epochs shows the same rows; the caption says so. The PSTHs use
  every epoch either way.
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
the auROC from 0.5 on a 0-1 axis, a heatmap colors it on `[0 1]`
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
| `marks` | `true` | draw the calls (with a cutoff): the PSTH shades the call window and puts each group's call (up / down arrow, n.s.) by the unit's title, in the group's color (overlay: each group's count of units called up and down); the heatmap draws a bar over the call window and a red up or blue down triangle by each modulated row. The caption counts them either way |
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
events inside the row's epoch: every one of them, so a trial with several
beam crossings or licks gets a mark for each. The plot's `rasterEvents` is
a list of marks. Each is an [event reference](#eventref) -- its `line`,
`edge`, `which`, `scope`, and a [sequence](#event-sequences) or none --
with its own look:

| Field | Default | Meaning |
| --- | --- | --- |
| the [event reference](#eventref)'s fields | `which "all"`, `scope "recording"` | the events marked, one mark per event at its `alignStep`: `{line "Trough"}` marks every Trough onset; `{line "Trial", edge "offset", sequence [{line "Trough"}]}` the first Trough onset after each trial's end. Each is resolved over every paired trial (or the recording), not only the selected ones |
| `marker` | `"diamond"` | a line marker the aesthetics editor knows (`o`, `square`, `diamond`, `^`, `v`, `>`, `<`, `+`, `*`, `.`, `x`, `_`, `\|`, `pentagram`, `hexagram`) |
| `size` | 4 | marker size, points |
| `color` | `""` | `""`: the mark's automatic color, by its place in the list (blue, green, purple, yellow, cyan, teal; never the ticks' black or the stop dots' red); or a name or `#rrggbb` |

`epochEvents` finds them ([Analysis page](EphysAnalysis.md#compute)) on
the clock of each epoch's event, so a mark sits where the spikes of that
sample sit. `eventMarkRef` gives the marks' event references (their look
left out), `rasterMarkLabels` their labels and `rasterMarkLooks` how each
is drawn. Each mark is one component for the
[aesthetics editor](EphysAnalysis.md#plot-aesthetics), role `rasterEvent`,
group its `eventRefLabel` (e.g. `"Trough onset"`, `"Trial offset then
Trough onset"`). The raster kind's legend lists them; the caption names
them.

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
  (the axis is labeled with the parameter's name).
- `yParam "stop"`: each epoch's stop-event latency, `t1 - t0`, in ms
  (labeled e.g. "Trough onset latency (ms)"): with the event at
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
`Style.Colormap`'s colors; `Style.ShowSEM` turns the error bars off.
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
drawn as its mean, labeled "(template)", and a warning says why. For
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
| `showSites` | `true` | probe layout: the probe's sites in gray behind the waveforms |
| `showNames` | `false` | probe layout: each unit's name beside its waveform (with the p-p amplitude and spike count when `showPP` / `showCount`) |

Layouts:

- `"grid"` (default): a tile per unit (`style.MaxTiles` per page, ordered
  and titled like the other grids by `SortDepth`, `SortShank`,
  `LabelDepth`, `LabelShank`): time from the spike (ms) against amplitude,
  the spike's time dotted, a label (`showPP`, `showCount`) in the corner.
  `ampScale "common"` gives every tile the same amplitude axis.
- `"probe"`: one panel in the probe's x and y (µm): each unit's waveform
  is a glyph centerd on its position (`meta.x`, `y`), shanks side by side
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

### Aux signals

A PSTH or raster of spikes can draw, with every unit, the mean of the
dataset's AUX extract over the plot's own epochs: the headstage's
auxiliary inputs, which on Intan headstages are the three axes of an
accelerometer, in volts as recorded ([DatasetOutputs](DatasetOutputs.md)).
It shows how the animal moved around the event next to the spikes. The
plot's `aux` (`EphysAnalysisConfig.defaults("Aux")`):

| Field | Default | Meaning |
| --- | --- | --- |
| `mode` | `"off"` | `"channels"`: each channel's mean, one trace per channel; `"magnitude"`: the mean of each epoch's vector magnitude, `sqrt(x^2 + y^2 + z^2)` over the channels at every sample (the mean of the magnitudes, not the magnitude of the means); `"off"`: none |
| `channels` | `[]` | the AUX extract's columns used (1 = its first input), `[]` = all; the magnitude combines these |
| `placement` | `"below"` | `"below"`: a panel of its own under the unit's PSTH (a raster's: under the raster); `"above"`: one over the unit's raster (a PSTH without a raster: over the PSTH); `"over"`: on the PSTH's (a raster plot's: the raster's) own axes, on a right y axis |
| `baseline` | `"none"` | `"subtract"`: each epoch's mean over `baselineWindow` is subtracted from each channel first, before the magnitude; `"none"`: as recorded |
| `baselineWindow` | `[-0.2 0]` | s from the event; it must overlap the epoch window (the samples cut for each epoch) |
| `byGroup` | `true` | one trace per trial group; `false`: one mean over every epoch |
| `display` | `"lines"` | `"lines"`: a line per trace (a channel, or the magnitude, per group); `"stacked"`: every trace in a row of its own, on one amplitude scale; `"heatmap"`: an image, a row per trace in color, on one color scale (a panel of its own: `"over"` goes below, and it has no band) |
| `statistic` | `"mean"` | what is drawn at each sample over the epochs of a group: `"mean"` or `"median"` |
| `transform` | `"none"` | `"none"`: the signal as recorded (after the baseline); `"rectify"`: each epoch's absolute value at every sample, after the baseline and the magnitude and before the statistic, so movement either way adds up instead of cancelling |
| `errorType` | `"sem"` | the band around each trace, over the epochs, chosen for the aux signal alone (not by `Style.ShowSEM` / `Style.ErrorType`): `"off"`; `"sem"`: statistic +/- SEM; `"std"`: +/- SD; `"ci95"`: the bootstrap 95% CI (of the median for `"median"`; `Style.ErrorResamples` resamples); `"iqr"`: the 25th to 75th percentile of the epochs |
| `colorBy` | `"auto"` | `"group"`: each trial selection group's color (several channels differ by line style; a heat map marks each row's group at its left edge); `"channel"`: a color per channel (several groups differ by line style); `"auto"`: the group's color with several groups or one channel, else the channel's |
| `yLim` | `[]` | the signal's y limits `[lo hi]`, in its units (V): a panel's y axis, or (`"over"`) the part of the right axis the signal spans; the same scale on every plot. `[]` = from the traces (and their bands, when drawn) inside the time window, padded 5% each way. Stacked: the span each row has. Heat map: the color scale |
| `overPosition` | `[0 1]` | `"over"`: where the signal sits on the plot, `[bottom top]` as fractions of its height (0 = the bottom edge, 1 = the top): `[0 0.3]` puts it in the bottom three tenths, `[0.7 1]` along the top. The right axis' limits are set so that `yLim` (or the traces' range) falls exactly there, and its ticks (at most three, at round values) stay along that span. `[0 1]` with `yLim` `[]` leaves the right axis automatic |

`auxMean` computes it ([Analysis page](EphysAnalysis.md#compute)) with
`evokedPotential`, so the samples are cut as an evoked potential's are:
offset 0 is the AUX sample nearest the one that produced the event, at
the AUX extract's own rate (Intan: a quarter of the amplifier rate). It
uses the plot's epochs, but an epoch that leaves the AUX signal or holds
a missing sample is left out of the aux mean only (the PSTH and raster
keep it); the caption says how many. `maskAfterStop` does not apply to it:
each epoch's aux samples cover the whole window. Without a baseline the magnitude of
three accelerometer axes includes their static offsets and gravity; with
`"subtract"` it is the size of the change in acceleration from each
epoch's baseline. A dataset without an AUX extract skips the plot ("no
AUX extract": enable AUX in the pipeline's Signals step).

How it is drawn:

- A panel below or above is half a rate panel (or half the raster) high,
  flush on the same time axis; the tile's x tick labels go under its
  bottom panel. In a grid its y label joins the grid's, read from the
  bottom up (`|AUX| (V)  ·  spikes/s  ·  Epoch`); in one panel (an
  overlay of units) it has its own. A plot drawn into a single axes has
  no room for a panel and draws no aux signal unless it is `"over"`.
- `"over"` uses the panel's right y axis, named on the right column of a
  grid, placed and scaled by `overPosition` and `yLim`: a real axis, so
  its ticks are the signal's values. A value beyond `yLim` is still drawn
  at its place on the scale, past the span (clipped only at the axes'
  edge). The error bands are semitransparent there (0.2, unless `ErrorFaceAlpha` sets an opacity) so the data under them
  shows. A stacked PSTH's right axis labels its rows' peaks, so `"over"`
  goes below a stack (Validate warns).
- With `colorBy "auto"` the traces are the groups' colors (a group per
  trace with `byGroup`, a single group's color). Several channels of one
  group (or of every epoch) get colors of their own (orange, green,
  purple, ...); several channels of several groups keep the groups' colors
  and differ by line style (solid, dashed, dotted, dash-dot), and the
  legend lists each channel's style. `colorBy "channel"` colors by channel
  whatever the groups (the groups then differ by line style, and the
  legend lists them). One trace over every epoch is gray (light gray on a
  dark design). The bands are `errorType`'s (their fill, opacity and edge
  are the Style's `ErrorFace*` / `ErrorEdge*`); `Style.YLim` is not used
  (it is the rate's). The y label is `AUX (V)`, `AUX - baseline (V)`,
  `|AUX| (V)` (the magnitude, or a rectified signal) or
  `|AUX - baseline| (V)`, with "median" in front for the median.
- Stacked rows run from the first channel down, a channel's groups
  together, each labeled at its tick (`AUX1 · group`; at most six labels),
  centered on its own median over the time window; all rows share one
  amplitude scale (the tallest trace and band, or `yLim`), and a scale bar
  at the right of the bottom row is half a row's spacing at most. The rows
  are the same lines, bands and colors as `"lines"`. A heat map draws one
  image (rows as in a stack) on a color scale from `yLim`, else from the
  range of the traces in the time window (symmetric about zero, with the
  design's diverging colormap, when they run both ways; else the design's
  heat colormap, or `Style.HeatColormap`); a bar of each row's group or
  channel color sits at its left edge and the scale is written in its
  corner.
- The traces and bands are components of their own for the
  [aesthetics](EphysAnalysis.md#plot-aesthetics) editor (`auxTrace`,
  `auxSem`, grouped by channel, or by group when there is one trace per
  group; a heat map's `auxImage`, `auxGroup` marks and the `auxScale` bar or
  range text); an aux panel is styled as a data panel (role `axes`). An
  overlay whose panel is `"all"` is drawn on the aux panels too; `"data"`
  and `"raster"` leave them out.
- An exported grid page is 1.5 cm taller per row of tiles for a panel
  below or above (2 cm for stacked rows or a heat map).

### Error bands

With `Style.ShowSEM` a plot draws the error of its means, of `Style.ErrorType`:

| `ErrorType` | Band / bar | Needs |
| --- | --- | --- |
| `"sem"` (default) | mean +/- SEM (std / sqrt(n)) | |
| `"std"` | mean +/- the standard deviation of the values | |
| `"ci95"` | the 95% confidence interval of the mean: `ErrorResamples` bootstrap resamples of the values, percentile method (`bootci`); asymmetric where the values are | Statistics and Machine Learning Toolbox |

An aux signal's band is chosen in its own `aux.errorType` (the same three,
plus `"off"` and `"iqr"`, the interquartile range, `prctile`; it needs the
same toolbox for `"ci95"` and `"iqr"`), and follows its `aux.statistic`:
for the median `"sem"` and `"std"` are drawn around the median (Validate
warns) and `"ci95"` is the bootstrap CI of the median.

The values are each epoch's: the compute function makes the band over the
epochs of a group (`spikePSTH`, `evokedPotential`, `firingRate`,
`tuningCurve`, `behaviorValues`, `auxMean`: `ErrorType=`, `ErrorResamples=`;
`R.err` holds its type and edges, `lo` and `hi`), and `plotErrorType` says
which a plot asks for (`"sem"` where it draws none, so no bootstrap runs for
nothing). An overlay of several units (PSTH, tuning) draws the error of the
units' means, across the units, made by the renderer. A PSTH's baseline mode
moves and scales the band's edges as it does the mean (the baseline is not
resampled); a normalized PSTH divides them by the same peak. A value seen
fewer than twice has no band. The caption names the error and what it is
across ("bands: mean +/- SEM across epochs"; "the bootstrap 95% CI of the
mean (1000 resamples, percentile)").

Bands are patches (`errorPatch`) in the bands' look: `ErrorFaceColor`,
`ErrorFaceAlpha`, `ErrorEdgeColor`, `ErrorEdgeStyle`, `ErrorEdgeWidth`
([Style](#style)); the defaults draw them as before. Each band is a
component for the [aesthetics](EphysAnalysis.md#plot-aesthetics) editor
(role `sem`, "Error band", or `auxSem` for an aux signal's), so a right-click
restyles one group's bands, and a design's rules reach them. Error bars
(rates, tuning, behavior) are `errorbar` objects in their own look; only
`ErrorType` concerns them. `populationSummary` takes `ErrorType=` and
`ErrorResamples=` too (across the units of each group) and `renderPopulation`
draws its bands in the style's look.

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
| `color` | `""` | `""` = the design's text color; or a name or `#rrggbb` |
| `background` | `""` | `""` = none; or a name or `#rrggbb` behind the text |
| `box` | `false` | an outline round the text, in its color |
| `interpreter` | `"none"` | `"none"`: every character as typed; `"tex"`: `\mu`, `\pm`, `x^2`, `x_i`, `\bf{...}` |

`renderPlot` draws the note after the title, as a text of role `note` in a
hidden axes beside the plot's tiled layout (`drawNote`, `placeNote`; a plot
that is a single axes carries the text in the axes), so a note is a
component of the plot the [aesthetics](EphysAnalysis.md#plot-aesthetics)
editor lists and every [design](EphysAnalysis.md#plot-designs) styles
(its font and text color). The note's own `fontName`, `fontSize`, `color`
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
| `color`, `alpha` | `"#d62728"`, `1` | line: its color (a name or `#rrggbb`) and opacity (0-1) |
| `lineStyle`, `lineWidth` | `"--"`, `1.5` | line, and a patch's outline: `"-"`, `"--"`, `":"` or `"-."`; width in points |
| `faceColor`, `faceAlpha` | `"#808080"`, `0.25` | region: its fill color and opacity (0-1) |
| `edgeColor` | `"none"` | region: its outline color, `"none"` for no outline (drawn in `lineStyle` and `lineWidth`) |

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
saved from a plot leaves its overlays out. A color that is not one, an
opacity outside 0-1, or a style or width that is not valid is drawn with the
default's (Validate reports it); an overlay without a finite position, or a
patch with equal edges, is not drawn.

## Session plots

A *session plot* draws one plot of [`Plots`](#plots) over several datasets
(sessions) at once and merges the results
([Across sessions](EphysAnalysis.md#across-sessions)): the sessions as colors,
or a mean with an error band across them, or one color per subject. It
**references** a plot, its *base plot*, and keeps the base plot's event,
window, trial selection, units, bins, baseline and look; it adds only the
cross-session settings below. Edit the base plot and every session plot on it
follows. Session plots are drawn after the datasets' own plots, in a run, and
have their own tab in the app ([Sessions tab](EphysAnalysisApp.md#sessions-tab)).

```matlab
[cfg, id] = cfg.addSessionPlot("psth_stim");              % id "psth_stim_sessions_1"
k = cfg.sessionPlotIndex(id);
cfg.SessionPlots(k).series = "subject";                   % a color per subject, its sessions averaged
cfg.SessionPlots(k).showMembers = true;                   % each session faintly under its subject's mean
cfg.SessionPlots(k).match = "site";                       % units meet on their recording channel
cfg.SessionPlots(k).data = ["results" "epochs"];          % what Export.Data writes
```

| Field | Default | Meaning |
| --- | --- | --- |
| `id` | `""` | names the session plot's figure and data files (`{Plot}`); unique among session plots (a namespace of their own: it may equal a plot's id), file-name safe, distinct as a file name once sanitized. Blank: `<plot>_sessions_<n>` |
| `enabled` | `true` | unticked, it stays in the config but runs do not draw it |
| `title` | `""` | blank = automatic: the base plot's title with the number of sessions, e.g. *PSTH: Stim onset (3 sessions, 112 epochs)* |
| `plot` | `""` | the base plot's id. It must exist, be a `psth`, `raster`, `evoked`, `rate`, `tuning`, `behavior`, `heatmap` or `waveforms` plot (not `probemap` or `corrmap`) and not have the auROC baseline (curves are not merged). The base plot's own `enabled` does not gate the session plot |
| `layout` | `""` | blank = the base plot's layout; else one of its kind's layouts |
| `datasets` | `"ticked"` | `"ticked"`: the run's datasets (the Data tab's ticks, or `run(Datasets=)`); `"list"`: the datasets of `datasetKeys` |
| `datasetKeys` | `[]` | `"list"`: the datasets' keys (the Data tab's **Key** column, e.g. `SYNTH-01/260908_103000`); a key no dataset has is left out and logged |
| `facet` | `"none"` | `"none"`: one figure over every session; `"subject"`: one figure per subject (a name pattern without `SubjectID` leaves the sessions in `(no subject)`), in date order |
| `series` | `"session"` | what gets a color: `"session"` (a series per session), `"subject"` (a series per subject, its sessions averaged) or `"all"` (one series, every session averaged) |
| `colorOrder` | `"palette"` | `"palette"`: the design's palette in turn; `"sequential"`: a sequential map in date order (the design's sequential colors), so the days read as a progression |
| `showMembers` | `false` | series `"subject"` / `"all"`: draw each session faintly under its summary (role `memberLine`). Needs a summary: a warning with series `"session"` |
| `error` | `"sem"` | series `"subject"` / `"all"`: the band across the sessions averaged: `"sem"`, `"sd"`, `"ci95"` (a *t* interval: the *t* quantile, `tinv`, Statistics and Machine Learning Toolbox, times the SEM; 1.96 × SEM without the toolbox) or `"none"`. NaN with fewer than two sessions. With series `"session"` each series keeps the base plot's own error over its epochs |
| `match` | `"pool"` | spike sources: how units meet across sessions: `"pool"`, `"site"` or `"mapping"` ([below](#matching-units-across-sessions)). Signals match channels by recording channel; heatmaps and waveforms pool; behavior has no units (a warning when set) |
| `mappingFile` | `""` | `"mapping"`: the unit-mapping CSV ([format](file-formats.md#unit-mapping-csv)) |
| `minSessions` | `1` | a tile (site, cell or channel) is drawn only when at least this many sessions have data for it; for pool and behavior, the number of sessions with a result. Fewer is *skipped* (`combineSessions:TooFew`). A whole number >= 1 |
| `trialGroups` | `"pool"` | the base plot's trial groups (its `groupBy`): `"pool"`, `"each"` or `"combine"` ([below](#trial-groups-across-sessions)) |
| `data` | `"results"` | what [`Export.Data`](#export) and the app's data buttons hold, a list of `"results"` (each session's own result of the base plot, besides the merged one), `"epochs"` (each session's `epochData`: the epoch table, spike times and binned counts per unit) and `"signals"` (with `"epochs"`, a signal base plot's epoched samples too, which can be large) |
| `aesthetics` | `[]` | the session plot's own remembered looks (role, group, property, value), applied after the base plot's, so a session figure's edits never change the per-dataset figures |

### Matching units across sessions

`match` decides what a tile of a spike plot (a PSTH or raster unit, a tuning
curve, a rate-plot unit) is:

| `match` | One tile per | Notes |
| --- | --- | --- |
| `"pool"` | session-unit | every session's units, each on a tile of its own, labeled `"<unit> · <session>"`; a tile has values for its own session's series only, NaN for the others. Needs no matching |
| `"site"` | recording channel with a unit in at least `minSessions` sessions | a session's units on the channel are averaged (their SEM combined as `sqrt(sum(sem.^2))/k`) and, in a raster, their spikes pooled. Assumes the probe sat on the same channels: sites are matched by channel number, and a session whose probe channel map differs from the first's is logged |
| `"mapping"` | row of the mapping file | the same cell by name; each session's value is its unit id(s) from its column |

Signals (evoked, a signal heatmap, an aux or LFP rate) always match by
recording channel, and `minSessions` then counts the sessions that hold the
channel; unit heatmaps and unit waveforms always pool.

The mapping file is a CSV with one row per cell: a column `cell` (its
name), then one column per dataset key holding that dataset's unit id(s) for
the cell (`meta.unitId`, the number in the unit's label, `su12`). An id is
a number, or text such as `3 7` for two units that are averaged; an empty
field means the cell was not found in that session, which then contributes
NaN to the tile. A session the file has no column for is
`combineSessions:Mapping`; Validate warns of it for a session plot that
lists its datasets.

```text
cell,SYNTH-01/260908_103000,SYNTH-01/260909_101500
cellA,42,17
cellB,8,
cellC,3 7,5
```

`readUnitMapping` and `writeUnitMapping` read and write it; the app's
**Edit...** button opens it in a table ([Sessions tab](EphysAnalysisApp.md#sessions-tab)).

### Trial groups across sessions

A base plot that groups its trials (`groupBy`, e.g. `Depth`) has one series
per group in each session. `trialGroups` says what the session plot does
with them:

| `trialGroups` | Result |
| --- | --- |
| `"pool"` (default) | the groups are cleared (`sessionPlotFor` sets `selection.groupBy = []`; a tuning or behavior plot's `seriesParam` too): every epoch of a session together, and the series are the sessions (or subjects). Because that spec differs from the base plot's, a run computes the base plot twice per dataset (logged) |
| `"each"` | the groups are kept, and one figure is made per group, each group merged across the sessions on its own (at most the selection's `maxGroups`). The groups are matched by label (`Depth = 0.5`), not by position, so sessions whose depth sets differ still line up; a session without a group contributes nothing to it. A heatmap keeps the groups as its tiles in one figure |
| `"combine"` | every group kept in one figure: a series per session (or subject, or all) and trial group, labeled `"<session> · <group>"`, colored by the session or subject and told apart by a line style (`-` `--` `:` `-.` by group), drawn as lines even for a bar PSTH (`sessionPlotFor` sets the effective spec's `histStyle` to `"line"`; a warning for `histStyle "bar"`) |

## Figures

`Figures` is a list of *figures*: panels of different types (a raster, a PSTH, a
signal trace, a probe map, ...) arranged on a grid and drawn for **one
observation** at a time. (Here a figure is an entry of `Figures`; the figure
files that [`Export`](#export) writes hold the pages of [plots](#plots) and of figures.) A plot
draws one kind of data for a page of units or channels; a figure puts several
kinds side by side for one unit, for example a raster flush above its PSTH
above the LFP of its own channel, with the stimulus offset marked on every
raster row.

A figure is designed for one *observation*: a sorted unit (or a channel's
detections), a channel of a signal (`LFP`, `MUA`, `SPIKE` or `AUX`), or the
dataset. Its `observe` block says which kind, and which ones there are: the
unit filter, the channel list and the datasets. A panel has a type and one or
more *layers*; a layer is one data source (the units, the detections, an event
line, a signal's channels). Each layer either **follows the
observation**, reading the observed unit or the channel it sits on, or is
**fixed**, naming its own units, channels or line, so one panel can draw the
observed unit's spikes beside fixed AUX channels. The figure has one
alignment, `ref`, `window` and `selection`, each `"default"` or its own as in a
plot. A panel may override `ref` and `window` but not the trial selection, so a
figure has one group table, one palette and one legend. The bins, measure,
baseline (with its auROC settings), mask and waveform inset are the figure's
too, in its `common` block, which every panel linked to it draws
([Common options](#common-options)).

The preview draws one observation of one dataset: it reads one unit's spikes
and one extract column, not a page of units, so an edit redraws quickly.
A run draws the same figure for every observation it selects, one page each:
`EphysAnalysisRunner.run`, `runDataset` and `plan` take `Figures=` beside
`Plots=`, the figure files are [exported](#export) and the figures appear in the
[report](#report), the generated scripts and the pipeline's Analysis step run
them too, and the [validation](#validation) rule that something must be enabled
counts an enabled figure. The app starts that run two ways: the Export tab's
**Run** draws the enabled figures (with the plots), and the Figures tab's
**Generate** draws the selected figure alone, enabled or not, on every ticked
dataset. The pieces are the config below, `figureObservations`,
`figureCompute` (`EphysAnalysisRunner.computeFigure` wraps it) and
`renderFigure`, which the app's [Figures tab](EphysAnalysisApp.md#figures-tab), a
run and a script all call:

```matlab
cfg = EphysAnalysisConfig();
cfg.Source.Root = "D:\EPHYS";
cfg.Defaults.EventRef.line = "Stim";
[cfg, id] = cfg.addFigure("rasterPsth");                    % "figure_1": a unit's raster flush above its PSTH
lfp = struct('type', "continuous", 'layers', EphysAnalysisConfig.defaultLayer("continuous"));   % follows the unit
cfg.Figures(1) = EphysAnalysisConfig.placePanel(cfg.Figures(1), lfp, "below", "psth_1");
spec = cfg.figureFor(id);                                   % every "default" resolved
runner = EphysAnalysisRunner(cfg);
src = runner.source(1);                                     % the first dataset, loaded once
T = figureObservations(src, spec);                          % its units in probe order, one row each
F = runner.computeFigure(src, spec, Observation=T(3, :));   % the third unit: no graphics
h = renderFigure(F, spec, figure);                          % draw it
R = runner.run(Figures=id, Plots=string.empty(1, 0));       % or this figure alone, every unit of every dataset, a page each
```

`EphysAnalysisConfig.defaults("Figure" | "FigureCommon" | "Observe" | "Panel" | "Layer")`
give the fields below; every field exists on every entry.

### Figure, grid and observe fields

| Field | Default | Meaning |
| --- | --- | --- |
| `id` | auto | unique among figures (`EphysAnalysisConfig:DuplicateFigureId`), file-name safe and distinct once sanitized, as a plot's; it may not equal a plot's id either, since both fill `{Plot}` (a [validation](#validating-figures) error). Names the exported files (`{Plot}`). Blank: `figure_<n>` |
| `enabled` | `true` | unticked, it stays in the config: `figureSkipReason` says "disabled", and `computeFigure` still computes it when asked, as the preview does |
| `title` | `""` | `""` = automatic: the id, the observation's label, the aligned event and the epoch count (a dataset figure names no observation, a figure with no aligned panel no event); the dataset is the subtitle. With a title of your own, the top-left panel names the observation |
| `observe` | below | what the figure is drawn for |
| `grid` | below | the arrangement of the panels |
| `common` | `defaults("FigureCommon")` | the options every panel linked to the figure draws: `bins`, `measure`, `baseline`, `auroc`, `maskAfterStop`, `waveform` ([Common options](#common-options)) |
| `panels` | none | the [panels](#panel-fields), a list of any length |
| `ref`, `window`, `selection` | `"default"` | `"default"` = [`Defaults`](#defaults), or the figure's own [EventRef](#eventref) / [EpochWindow](#epochwindow) / [TrialSelection](#trialselection). Every aligned panel starts from them |
| `style` | [Style](#style) | the figure's look: fonts, line widths, error bands, legend, colors and probe sorting apply. `XLim`, `YLim`, `CLim`, `MaxTiles` and `TileSpacing` are not used: the time panels show the window, each panel has its own `options.yLim` / `cLim`, and the spacing is `grid.spacing` |
| `aesthetics` | none | remembered looks of the figure's components, a list of rules as a plot's ([Plot aesthetics](EphysAnalysis.md#plot-aesthetics)) |

`grid`:

| Field | Default | Meaning |
| --- | --- | --- |
| `rows`, `cols` | 1, 1 | the grid's size; whole numbers >= 1 |
| `rowHeights`, `colWidths` | `[]` | `[]` = equal; else one positive relative size per row / column, e.g. `[1.5 1 1]`. The drawing is a tiled layout of equal tiles, so a size is rounded to quarter steps of the smallest, and at most 32 tiles are used a side: `[1.5 1 1]` is 3 : 2 : 2 tiles, `[1 1.37]` draws as `[1 1.25]` |
| `spacing` | `"tight"` | the tiled layout's `TileSpacing`: `"loose"`, `"compact"`, `"tight"` or `"none"` (`"none"` draws stacked time panels flush) |

`observe` (what the preview's picker lists and what a run repeats the figure over):

| Field | Default | Meaning |
| --- | --- | --- |
| `kind` | `"auto"` | `"unit"`, `"channel"` or `"dataset"`; `"auto"` = a unit when an enabled layer that follows the observation reads spikes (`units`, `detected`), else a channel when one reads a signal (`LFP`, `MUA`, `SPIKE`, `AUX`), else the dataset (`EphysAnalysisConfig.observeKind`) |
| `source` | `"units"` | unit observations: `"units"` (sorted) or `"detected"` (one per channel) |
| `units` | [UnitSelection](#unitselection) without `source` | unit observations: the filter that picks the units the figure can be drawn for (classes, quality, response test, ids, channels, shanks, `maxUnits`) |
| `signal` | `"LFP"` | channel observations: which extract (`"LFP"`, `"MUA"`, `"SPIKE"`, `"AUX"`) |
| `channels` | `[]` | channel observations: the extract's columns (`[]` = all) |
| `datasets` | `"ticked"` | the datasets the figure is meant to be drawn for: `"ticked"` (the run's) or `"list"` (`datasetKeys`). Neither the Figures tab's Generate nor Run uses the list yet: a preview draws the dataset it is given, and `EphysAnalysisRunner.run` the datasets it is given (`Datasets=`), which the app takes from the ticked ones, whatever this says |
| `datasetKeys` | none | `"list"`: the datasets' keys (the Data tab's **Key** column) |

`addFigure` takes a template's name (`EphysAnalysisConfig.figureTemplates()`) or
a partial figure struct. `"rasterPsth"` (the default) is a 2 x 1 grid of equal
rows drawn flush (`spacing "none"`): `raster_1` over `psth_1`, each with one
`units` layer that follows the observation. Each panel type has a template of
its own (`"psth"`, `"raster"`, `"continuous"`, `"heatmap"`, `"waveforms"`,
`"probemap"`, `"corrmap"`, `"rate"` for a firing rate panel, `"tuning"` for a
tuning curve): one panel `<type>_1` holding
`defaultLayer(type)`, a layer of the first source of the type's first
[category](#source-categories) (`units`; `LFP` for continuous) bound as the
type's `DefaultBinding` says, so a new panel draws at once. A new figure takes
`defaults("FigureCommon")` as its `common` block, and its panels are linked to
it. `"blank"` is an empty 1 x 1 grid.

### Panel fields

| Field | Default | Meaning |
| --- | --- | --- |
| `id` | auto | unique within the figure (`EphysAnalysisConfig:DuplicatePanelId`); blank: `<type>_<n>`. The aesthetics editor names a panel's tile by it |
| `type` | `"psth"` | one of the [panel types](#panel-types) |
| `title` | `""` | `""` = none, but for the observation's label on the top-left panel under a title of the figure's own |
| `row`, `col` | 1, 1 | the top-left cell |
| `rowSpan`, `colSpan` | 1, 1 | the rows and columns it covers |
| `ref`, `window` | `"default"` | `"default"` = the figure's, or the panel's own [EventRef](#eventref) / [EpochWindow](#epochwindow) (aligned types only). A panel with its own cuts its own epochs, with the figure's selection; its groups must match the figure's by label, or the panel is skipped. It then no longer [shares the time axis](#shared-time-axis) |
| `common` | `true` | `true`: the panel draws the figure's [common options](#common-options) for every common field its type has (`commonFieldsOf`); `false`: all of its own `options` |
| `layers` | none | the [layers](#layer-fields), a list of any length |
| `options` | the type's [options](#panel-options) | coerced to the type's, so changing `type` re-seeds them: fields the new type has keep their values, the others are dropped. While `common` is true the type's common fields are stored but not drawn: the figure's are |

### Layer fields

| Field | Default | Meaning |
| --- | --- | --- |
| `name` | `""` | the legend and aesthetics label; `""` = automatic: the unit's label, `LFP ch 3`, the event's label |
| `enabled` | `true` | unticked, the layer stays in the config and is not drawn |
| `source` | `"units"` | one of `FigureSources`: `"units"`, `"detected"`, `"events"` (a digital or derived line's events), `"LFP"`, `"MUA"`, `"SPIKE"` or `"AUX"`; the panel type decides which a panel takes ([source categories](#source-categories)) |
| `binding` | `"observation"` | `"observation"`: follows the previewed or generated unit or channel ([what a layer reads](#what-a-layer-reads)); `"fixed"`: reads what `units`, `channels` or `event` name. Events layers are always fixed |
| `units` | [UnitSelection](#unitselection) without `source` | fixed point and unit layers: which units (it may keep several). A layer following the observation uses it only for the other spike source, on the observed channel. `source` is taken from the layer's |
| `channels` | `[]` | fixed signal layers: the extract's columns (`[]` = all) |
| `aggregate` | `"each"` | several units or channels in one layer: `"each"` (one trace or block per item) or `"mean"` (their mean, with a band across them: a PSTH overlay, the aux magnitude's mean) |
| `event` | [EventMark](#raster-event-marks) | source `events`: the line, edge, which / scope / [sequence](#event-sequences) and the mark's look (`marker`, `size`, `color`) |
| `eventsAs` | `"marks"` | source `events`: `"marks"` (a mark on every raster row; a latency line and a rug on a PSTH, signal or heat map panel) or `"train"` (the events as a spike train of their own: rows in a raster, a PSTH, a heat map row) |
| `color` | `""` | `""` = the trial group's color; else a name or `#rrggbb` for every trace of the layer |
| `lineStyle` | `""` | `""` = by order of the layer's items (`-`, `--`, `:`, `-.`); else one of those |

### Panel types

`EphysAnalysisConfig.panelTypes()` is the table of types, the analog of
[`plotKinds`](#plots):

| Type | Label | Categories | Aligned | SharesTime | OneGroup | MultiLayer | DefaultBinding |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `raster` | Raster | point | yes | yes | no | yes | `observation` |
| `psth` | PSTH | point | yes | yes | no | yes | `observation` |
| `continuous` | Continuous signal | continuous | yes | yes | no | yes | `observation` |
| `heatmap` | Heat map | point, continuous | yes | yes | yes | no | `fixed` |
| `waveforms` | Unit waveforms | unit | no | no | no | no | `observation` |
| `probemap` | Probe map | unit | no | no | no | no | `fixed` |
| `corrmap` | Unit correlation | unit | yes | no | yes | no | `fixed` |
| `rate` | Firing rate | point | yes | no | no | yes | `observation` |
| `tuning` | Tuning curve | point | yes | no | no | yes | `observation` |

- `Categories`: the [source categories](#source-categories) its layers draw.
- `Aligned`: cut into epochs around events, so the panel's `ref` and `window`
  apply. An unaligned panel (waveforms, probe map) must keep both `"default"`.
- `SharesTime`: its x axis is time from the event; it takes the figure's time
  axis ([below](#shared-time-axis)) and the events layers.
- `OneGroup`: draws one trial group, `options.group` (a 1-based number).
- `MultiLayer`: draws every enabled layer. Any other type draws the first
  enabled one (validate warns of more).
- `DefaultBinding`: what a new layer of the type binds to.

What each draws:

- `raster`: a row per epoch, by trial group on pale bands, for the first point
  layer's first unit. Every further unit or layer goes in a block under it
  with a small gap, each group a band of its own, and the y axis names the
  blocks. Events layers drawn as marks put a mark on every row of every block;
  drawn as a train they are blocks of rows of their own.
- `psth`: the peri-event rate per trial group: a band and a trace for every
  layer and unit, each unit in a line style of its own (`-`, `--`, `:`, `-.`,
  or the layer's `lineStyle`); with several only the first is filled.
  `aggregate "mean"` draws the mean over a layer's units with a band across
  them. Events layers drawn as marks become a latency line per trial group
  (the median over its epochs) and a rug along the top edge; drawn as a train,
  a PSTH of their own. With `options.stack` (and two or more trial groups) the
  groups are not overlaid but stacked: one row per group, the first at the
  bottom, each row `stackSpacing` times the tallest PSTH high, the groups'
  values on the left axis and their peaks on the right, as a plot's stacked
  PSTH. A second layer or unit is drawn into the same rows as an outline;
  `yLim` is not used in a stack. The groups' rasters are not a stack option
  (a plot's `stackRaster`): a raster panel above the PSTH shows them. With
  baseline `Mode "auroc"` the curves are auROCs, drawn from 0.5 (a dotted
  chance line) on a 0-1 axis unless `yLim` says otherwise, the modulation
  window shaded and the first unit's call per trial group (up, down or n.s.)
  at the top right (a layer's mean: the counts of its units up and down),
  as a plot's auROC PSTH; `normalize` does not apply to it, and it can be
  stacked too.
- `continuous`: the epochs' mean of each channel (LFP, MUA, SPIKE or AUX), per
  trial group, with an error band; `options.display` `lines` or `stacked` (a
  row per channel). Epoch means, not per-trial traces.
- `heatmap`: units or channels (rows) by time in color, for the trial group
  `options.group`. The map is the first enabled layer that is not events marks;
  events marks become latency lines over it. With baseline `Mode "auroc"` it
  maps auROCs on a 0-1 scale in the diverging colormap, with the calls marked
  (a bar over the call window and a triangle by each modulated row, while
  `auroc.marks`); `order "modulation"` puts the rows in order of their mean
  auROC in the call window in the group drawn, highest first.
- `waveforms`: the observed unit's mean waveform and a sample of its spikes
  ([Unit waveforms](#unit-waveforms)); a fixed layer of several units
  overlays their means. With `options.layout "probe"` it draws every unit of
  the first enabled layer as a glyph at its place on the probe, the sites
  behind, as a plot's probe layout; each further enabled layer (for example one
  that follows the observation) draws no waveforms but frames its units in red
  there. Bind the first layer to fixed units: a first layer that follows the
  observation draws the one unit, and validate warns.
- `probemap`: a per-channel value on the probe sites, the units' positions as
  dots; the observed unit's site (a channel observation: the channel's) is
  ringed.
- `corrmap`: the pairwise correlation of the layer's units' per-epoch rates for
  the trial group `options.group`.
- `rate`: a firing rate panel, the plots' rate kind for the observed unit: each
  epoch window's rate (`firingRate`, in the `measure` and `baseline`) per
  trial group, the groups along x (ticked with their values, the group-by
  parameters naming the axis). `options.display` draws each group as `bar` (the
  mean over its epochs with an error bar), `box` (a box of the epochs' rates)
  or `points` (each epoch's rate as a dot over a pale bar of their mean). Each
  unit of a layer is one item, in probe order, in the groups' colors for one
  item; several items (more layers, or a fixed layer of several units drawn
  `each`) sit side by side in each group's slot, each in a color of its own
  (the layer's `color` when set) and named in the legend. `aggregate "mean"`
  draws the mean over a layer's units, with the error bar across the units. A
  rate panel does not share the time axis, and its `window` may be a
  `"between"` window.
- `tuning`: a tuning curve panel, the plots' tuning kind for the observed unit:
  the rate against a trial parameter (`tuningCurve`), x being the parameter's
  values (numeric at their values; text evenly spaced and ticked with them),
  labeled with its name. One curve per series (`options.seriesParam`, `""` =
  one curve) in the series' color, a unit in the layer's line style (else by
  order), markers at the values and error bars. `aggregate "mean"` draws the
  mean over a layer's units, with error bars across the units. The legend names
  the series, then the items, when there are several. `options.waveform.mode`
  other than `"off"` puts the first unit's waveform in an inset. The
  parameter `options.param` is, when `""`, the first `groupBy` parameter of the
  figure's selection, else the first numeric trial parameter with two or more
  values; the panel is skipped (`no trial parameter X`, or `no numeric trial
  parameter to tune over`) when the trials lack it.

Not in a figure, in this release: the trial selection of a panel of its own (the
selection is the figure's); more than one layer on a heat map, probe map or
correlation panel (a waveforms panel in the probe layout takes more, to ring
units); per-trial traces in a continuous panel (it draws epoch means); a plot's
`stackRaster` (put a raster panel above the stacked PSTH); a plot's `aux`
sub-struct (an AUX layer in a continuous panel does it), `note` and `overlays`.
A figure draws one observation: several units tiled on one page, as a plot's
grid does, is not part of it.

### Panel options

A panel's `options` are the type's (`panelTypes().DefaultOptions`); a field
that is not the type's is dropped on load (and listed in `LoadWarnings`). The
names repeat a plot's where the meaning is the same. `yLim` and `cLim` are
`[]` (automatic) or an ascending `[lo hi]` and belong to the panel, because one
figure holds different axes; the figure's `Style.YLim` and `CLim` are not used.
The options named `bins`, `measure`, `baseline`, `auroc`, `maskAfterStop` and
`waveform` are the type's *common fields*: a panel linked to its figure draws the figure's
[common options](#common-options) for them, whatever its `options` hold.

| Type | Option | Default | Meaning |
| --- | --- | --- | --- |
| `raster` | `rasterSort` | `""` | the order of each group's epochs, as a plot's: `""` (trial order), `"stop"`, `"event"` or a trial parameter |
| `raster` | `rasterSortEvent` | `[]` | `rasterSort "event"` (required then): the [event reference](#eventref) whose latency orders the rows |
| `raster` | `rasterSortOrder` | `"ascending"` | or `"descending"` |
| `raster` | `rasterByGroup` | `true` | rows by group first, each group on a band; `false`: every epoch sorted as one block |
| `raster` | `maskAfterStop` | `false` | drop each epoch's ticks from its stop event on |
| `raster` | `waveform` | [Waveform](#unit-waveforms), `mode "off"` | the first block's unit's waveform in a box in the panel |
| `psth` | `bins` | `BinSec` 0.01, `SmoothSec` 0.01 | as a plot's |
| `psth` | `measure` | `"rate"` | `"rate"`, `"count"` or `"probability"` |
| `psth` | `baseline` | `Mode "none"`, `Window [-0.2 0]` | `Mode` `"none"`, `"subtract"`, `"zscore"`, `"percent"` or `"auroc"`, as the plot's baseline modes (`"ratio"` is for rate and tuning panels) |
| `psth` | `auroc` | `defaults("Auroc")` | baseline `Mode "auroc"`: the [auROC](#auroc) settings (`method`, `windows`, `windowSec`, `stepSec`, the call window `modulationWindow`, `cutoff`, `threshold`, `test`, `nResamples`, `correction`, `alpha`, `marks`, `modulatedOnly`), as a plot's. `windowSec` and `stepSec` must be whole numbers of the panel's bins (validate checks them) |
| `psth` | `histStyle` | `"bar"` | `"bar"` or `"line"` |
| `psth` | `fill` | `true` | fill the bars, or the area under the line |
| `psth` | `fillAlpha` | `NaN` | fill opacity 0-1; `NaN` = 0.5 where groups overlay, else 1 |
| `psth` | `normalize` | `"none"` | `"none"`, `"unitPeak"`, `"groupPeak"` or `"allPeak"` |
| `psth` | `stack` | `false` | `true`: one row per trial group, stacked upwards (the first group at the bottom), instead of overlaid; a single group is drawn overlaid |
| `psth` | `stackSpacing` | 1.1 | `stack`: the step between rows, times the tallest PSTH (below 1 the rows overlap); positive |
| `psth` | `maskAfterStop` | `false` | drop each epoch's bins from its stop event on |
| `psth` | `yLim` | `[]` | the rate axis; not used in a stack |
| `psth` | `waveform` | [Waveform](#unit-waveforms), `mode "off"` | the first unit's waveform in a box in the panel |
| `continuous` | `baseline` | `Mode "none"`, `Window [-0.2 0]` | `Mode` `"none"` or `"subtract"` (each epoch's mean over `Window`, per channel). The window must overlap the panel's window |
| `continuous` | `display` | `"lines"` | `"lines"` (a trace per channel) or `"stacked"` (a row of its own per channel) |
| `continuous` | `statistic` | `"mean"` | `"mean"` or `"median"` over the epochs at each sample |
| `continuous` | `transform` | `"none"` | `"none"` or `"rectify"` (each epoch's absolute value, before the statistic) |
| `continuous` | `errorType` | `"sem"` | the band over the epochs: `"off"`, `"sem"`, `"std"`, `"ci95"` or `"iqr"`; `"ci95"` and `"iqr"` need the Statistics and Machine Learning Toolbox ([Aux signals](#aux-signals)) |
| `continuous` | `stackSpacing` | `NaN` | `"stacked"`: the offset between rows; `NaN` = 1.2 x the 90th percentile of the traces' ranges |
| `continuous` | `yLim` | `[]` | the amplitude axis |
| `heatmap` | `bins`, `measure`, `baseline` | as the PSTH's | a spike layer: as the PSTH, `baseline.Mode "auroc"` included; a signal layer: `baseline.Mode` `"none"` or `"subtract"` and `bins`, `measure` unused |
| `heatmap` | `auroc` | `defaults("Auroc")` | a spike layer, baseline `Mode "auroc"`: the PSTH's `auroc` settings. A signal layer with `"auroc"` is an error |
| `heatmap` | `order` | `"probe"` | the rows: `"probe"` (the style's `SortDepth` / `SortShank`), `"peak"` (by the time of each row's maximum) or `"modulation"` (by each unit's mean auROC in the call window, highest first; only with the auROC baseline of a spike layer) |
| `heatmap` | `group` | 1 | the trial group drawn (clipped to the groups there are) |
| `heatmap` | `cLim` | `[]` | the color scale |
| `heatmap` | `maskAfterStop` | `false` | spike layers: as the PSTH's |
| `waveforms` | `layout` | `"grid"` | `"grid"`: the observed unit's waveform, or the means of a fixed layer's units overlaid; `"probe"`: every unit of the first enabled layer at its place on the probe, a further layer's units framed in red (bind the first layer to fixed units: validate warns when it follows the observation, which draws one glyph). Several enabled layers are not a warning in the probe layout |
| `waveforms` | `waveform` | [Waveform](#unit-waveforms), `mode "both"` | `mode` `"mean"`, `"subsample"` or `"both"` (never `"off"`), `maxSpikes` (the spikes drawn), `ampScale`, and `showPP` / `showCount` (the label). `scale` (the glyphs' size), `showSites` and `showNames` are for the probe layout |
| `waveforms` | `yLim` | `[]` | the amplitude axis |
| `probemap` | `value` | `"rate"` | `"rate"`, `"nSpikes"` or `"nUnits"` |
| `probemap` | `cLim` | `[]` | the color scale |
| `corrmap` | `metric` | `"mean"` | each epoch's `"mean"` rate over its window, or its `"peak"` binned rate |
| `corrmap` | `correlation` | `"pearson"` | or `"spearman"` |
| `corrmap` | `fisherZ` | `false` | draw Fisher's z and average the pairwise r in z |
| `corrmap` | `bins` | `BinSec` 0.01, `SmoothSec` 0.01 | `metric "peak"` |
| `corrmap` | `baseline` | `Mode "none"`, `Window [-0.2 0]` | `Mode` `"none"` or `"subtract"` |
| `corrmap` | `group` | 1 | the trial group drawn |
| `corrmap` | `cLim` | `[]` | the color scale |
| `rate` | `measure` | `"rate"` | `"rate"` (spikes/s), `"count"` (spikes per window) or `"probability"` (the share of epochs with a spike) |
| `rate` | `baseline` | `Mode "none"`, `Window [-0.2 0]` | `Mode` `"none"`, `"subtract"`, `"ratio"` or `"zscore"`, as `firingRate`'s `Normalize`: `"subtract"` (that epoch's baseline value), `"ratio"` (over the unit's mean baseline) or `"zscore"` (against the baseline's mean and SD over all epochs) |
| `rate` | `display` | `"bar"` | `"bar"` (the mean, with an error bar), `"box"` or `"points"` (each epoch's rate, over a bar of their mean) |
| `rate` | `yLim` | `[]` | the rate axis |
| `tuning` | `param` | `""` | the x axis, a trial parameter; `""` = the figure's first `groupBy` parameter, else the first numeric trial parameter with two or more values |
| `tuning` | `seriesParam` | `""` | one curve per value of this trial parameter; `""` = one curve; not the same as `param` |
| `tuning` | `measure` | `"rate"` | as the rate panel's |
| `tuning` | `baseline` | `Mode "none"`, `Window [-0.2 0]` | as the rate panel's |
| `tuning` | `yLim` | `[]` | the rate axis |
| `tuning` | `waveform` | [Waveform](#unit-waveforms), `mode "off"` | the first unit's waveform in a box in the panel |

### Common options

A figure's panels usually agree on the bins, the baseline (with its auROC
settings) and the waveform inset: a PSTH over a heat map over a unit
correlation is binned and baselined once, not three times. The figure's `common` block
(`EphysAnalysisConfig.defaults("FigureCommon")`) holds those options, and a
panel draws them while its `common` flag is `true` (the default), so one change
reaches every linked panel.

| Common field | Default | Meaning |
| --- | --- | --- |
| `bins` | `BinSec` 0.01, `SmoothSec` 0.01 | as the [panel options](#panel-options)' |
| `measure` | `"rate"` | `"rate"`, `"count"` or `"probability"` (a PSTH, a heat map, a rate or a tuning panel) |
| `baseline` | `Mode "none"`, `Window [-0.2 0]` | `Mode` one of `"none"`, `"subtract"`, `"zscore"`, `"percent"`, `"ratio"` and `"auroc"`; each type takes its own: a PSTH and a heat map of spikes `"none"`, `"subtract"`, `"zscore"`, `"percent"` and `"auroc"`; a rate and a tuning panel `"none"`, `"subtract"`, `"ratio"` and `"zscore"`; a continuous or unit correlation panel (and a heat map of a signal) only `"none"` and `"subtract"` |
| `auroc` | [`defaults("Auroc")`](#auroc) | the [auROC](#auroc) settings, used with baseline `Mode "auroc"` (a PSTH and a heat map of spikes) |
| `maskAfterStop` | `false` | drop what follows each epoch's stop event |
| `waveform` | [Waveform](#unit-waveforms), `mode "off"` | the inset of a raster, PSTH or tuning panel; for a waveforms panel its settings, where `mode "off"` is drawn as `"both"` |

A type takes the common fields among its own options
(`EphysAnalysisConfig.commonFieldsOf(type)`; `commonFields()` lists all six,
in order):

| Type | Common fields it takes |
| --- | --- |
| `raster` | `maskAfterStop`, `waveform` |
| `psth` | `bins`, `measure`, `baseline`, `auroc`, `maskAfterStop`, `waveform` |
| `continuous` | `baseline` |
| `heatmap` | `bins`, `measure`, `baseline`, `auroc`, `maskAfterStop` |
| `waveforms` | `waveform` |
| `corrmap` | `bins`, `baseline` |
| `rate` | `measure`, `baseline` |
| `tuning` | `measure`, `baseline`, `waveform` |
| `probemap` | none |

- **Linking.** `panel.common` is `true` (linked) or `false` (the panel draws its
  own `options`). Every other option of a linked panel (a PSTH's `histStyle`,
  `fill`, `normalize` and `yLim`, a raster's sort, ...) stays its own. The
  panel's stored values of the common fields are kept but unused while it is
  linked, so unlinking and relinking loses nothing.
- **`panelOptions`.** `op = EphysAnalysisConfig.panelOptions(fig, panel)` is the
  options the panel draws: `panel.options`, and, when `panel.common` is true,
  each field of `commonFieldsOf(panel.type)` taken from `fig.common`; a waveforms
  panel's `waveform.mode "off"` becomes `"both"`. `figureFor` resolves every
  panel's `options` through it, so a spec holds the effective values (and the
  `common` flag as the link state), and the compute and the render never read
  `fig.common` themselves.
- **Loading.** `common` is coerced to its defaults as `observe` and `grid` are,
  and a panel's `common` is a logical. A hand-written file may leave either out:
  they keep their defaults (the defaults above, the panel linked).

Three pure functions edit a figure entry as a value (the app's **Apply to all
panels** and **Re-link all panels** buttons call them):

| Call | Does |
| --- | --- |
| `fig = EphysAnalysisConfig.adoptPanelOptions(fig, panelId)` | the panel's values of its type's common fields, as it draws them, become the figure's `common` (nothing changes when the panel is linked: they already are); every panel is then linked (`common = true`); the panel's other options (the type-specific ones) are copied onto the other panels of the same type, and panels of other types keep theirs |
| `fig = EphysAnalysisConfig.adoptPanelAlignment(fig, panelId)` | the panel's own `ref` and `window` (the ones that are structs) become the figure's, a `"default"` part leaving the figure's as it is; every panel's `ref` and `window` are then `"default"` |
| `fig = EphysAnalysisConfig.relinkPanels(fig)` | every panel's `ref` and `window` are `"default"` and its `common` is `true`; the panels' own option values stay stored |

Each raises `EphysAnalysisConfig:NoPanel` for an id the figure does not have
(`relinkPanels` takes none).

`cfg.validate()` checks the common block once, at `<figure>.common`, rather than
once per linked panel: `bins` (`BinSec > 0`, `SmoothSec >= 0`), `measure`, the
baseline `Mode` (among the six above) and, with a `Mode` other than `none`, a
window `[b0 b1]` with `b0 < b1`, the `auroc` settings when the `Mode` is
`auroc` (at `<figure>.common.auroc`, as a plot's: the method, windows, cutoff,
call window and so on, its `windowSec` and `stepSec` whole numbers of the
common bins, and the Statistics and Machine Learning Toolbox it needs), and the
`waveform` settings (the mode `off` allowed). A linked panel is checked for the
one thing its type can fail: a common baseline `Mode` the type does not take
(`zscore`, `percent`, `ratio` or `auroc` on a continuous or unit correlation
panel or a heat map of a signal; `ratio` on a PSTH or a heat map of spikes;
`percent` or `auroc` on a rate or tuning panel) is an error at
`<figure>.<panel>.common`, with the way out: untick the panel's common options
or change the figure's baseline. A continuous panel's or a signal heat map's
baseline window must still overlap the panel's window, reported at the panel's
`common` when the baseline is the figure's. A panel with `common` false is
checked for its own values, field by field, as before.

### Source categories

A layer's `source` belongs to a category, and a panel type draws the categories
it accepts. `EphysAnalysisConfig.sourceCategories()`:

| Category | Label | Sources | Aligned | Meaning |
| --- | --- | --- | --- | --- |
| `point` | Point process | `units`, `detected`, `events` | yes | event times: sorted units, threshold detections, a digital or derived line's events |
| `continuous` | Continuous signal | `LFP`, `MUA`, `SPIKE`, `AUX` | yes | sampled signals cut around each event |
| `unit` | Unit summary | `units`, `detected` | no | one summary per unit over the recording: its waveform, its place on the probe, its rate |

`units` and `detected` are in two categories: the panel type decides which
(`EphysAnalysisConfig.categoryOf(source, type)` is the category the type
accepts for the source, or `""`). An `events` layer is `point` on every panel
that shares the time axis (raster, PSTH, continuous, heat map) and nothing
elsewhere. A heat map takes `point` or `continuous` layers.

### What a layer reads

A **fixed** layer reads what it names: a point or unit layer its `units`, a
signal layer its `channels` (`[]` = every column of the extract), an `events`
layer its `event`. Events layers are always fixed. A fixed layer does not
change with the observation: a panel of fixed layers only (a probe map, a unit
correlation) is the same for every observation, and a figure with no following
layer is observed as the dataset.

A layer that **follows the observation** reads (the private
`analysis/private/figureLayerItems.m` resolves it for each observation):

| Layer | Under a unit observation | Under a channel observation |
| --- | --- | --- |
| `units` or `detected`, of the observed source (`observe.source`) | that unit alone, whatever its class, with no quality or response filter (it passed `observe.units` already) | the layer's `units` on the observed channel's recording channel (`units.channels` set to it, `units.ids` ignored) |
| `units` or `detected`, of the other spike source | the layer's `units` on the unit's recording channel | as above |
| `LFP`, `MUA`, `SPIKE` | the column of the extract whose recording channel is the unit's | the observed column when the layer's signal is the observed one (`observe.signal`), else the column of its own extract that records the same channel (validate warns) |
| `AUX` | skipped: `AUX has no recording channel: bind it to fixed channels` | the observed column when AUX is the observed signal, else skipped with the same reason |

Under a dataset observation there is nothing to follow: a following point or
signal layer is skipped (`no unit or channel observed`), and validate refuses
the combination. A layer that cannot be resolved for an observation is skipped
with its reason, which the panel prints in small gray text; the panel's other
layers are still drawn. The reasons: `the observed unit has no recording
channel` (a unit on no mapped channel; a channel observation says `the observed
channel ...`), `no LFP column records channel 7`, `the observed AUX channel has
no recording channel for LFP to follow`, and the AUX one above. A layer that finds
no unit, no event or no usable epoch for the observation is skipped the same
way.

### Shared time axis

A panel shares the figure's time axis when its type does (`SharesTime`) and its
`ref` and `window` are both `"default"`; `figureFor` sets `panel.sharesTime`.

- Such a panel shows the figure's `[window.pre window.post]` (set on each axes;
  there is no `linkaxes`).
- Time panels stacked in a column are labeled once. A time panel's x tick labels
  and label are hidden when the panel directly below it, in every column it
  covers, is a time panel with the same limits. Otherwise (nothing below it, a
  panel with another kind of x axis such as waveforms, or other limits) it keeps its ticks and is labeled `Time (s)`: the bottom of a stack is
  always labeled. A raster also drops its y ticks in its bottom tenth where it
  meets the panel below, unless its ticks name its blocks.
- A time panel with a `ref` or `window` of its own keeps its own x axis and
  label, and the stack above it is labeled at its own bottom.
- Events layers go only on the panels of these types, since marks need a time
  axis.

### Editing the grid

Four static functions edit a figure entry (`fig = cfg.Figures(k)`) as a value,
with no graphics; the app's arrangement editor calls the same ones.

| Call | Does |
| --- | --- |
| `cells = EphysAnalysisConfig.figureCells(fig)` | a `rows` x `cols` matrix: 0 for an empty cell, k for a cell that panel k covers. `[cells, overlap] = ...` also lists each pair of overlapping panels once (`[first second]`, an n x 2 matrix); the parts of a panel outside the grid are left out |
| `fig = EphysAnalysisConfig.placePanel(fig, panel, where, anchorId)` | adds `panel` (a partial panel struct, normalized; a blank id becomes `<type>_<n>`) next to the panel `anchorId`. `where` `"below"`: a new row right after the anchor's last row, its `rowHeights` entry (when given) copied from that row; `"above"`: a new row before the anchor's first row, copying its height; `"right"` and `"left"`: a new column the same way, copying `colWidths`. The panels past the new row (column) move down (right) by one, those whose span crosses it grow by one, and the new panel takes the anchor's columns (rows) and one row (column). The first panel of a figure without panels goes to (1, 1), the grid unchanged, and needs no anchor. Errors: `EphysAnalysisConfig:NoPanel` (no anchor, or none by that id), `EphysAnalysisConfig:DuplicatePanelId` |
| `fig = EphysAnalysisConfig.removePanel(fig, id)` | removes the panel, then drops every row in which no remaining panel starts and every column likewise: the panels past a dropped row (column) move up (left), the spans that crossed it shrink by one, and its `rowHeights` / `colWidths` entry goes. Removing the last panel leaves a 1 x 1 grid. `EphysAnalysisConfig:NoPanel` for an unknown id |
| `[fig, moved] = EphysAnalysisConfig.movePanel(fig, id, direction)` | swaps the cells (`row`, `col`) of the panel and its neighbor in `direction` (`"up"`, `"down"`, `"left"`, `"right"`) when that neighbor has the same spans and lines up with it (the same column for up and down, the same row for left and right); else `fig` is returned unchanged and `moved` is false |

**Remove undoes Add**: `removePanel(placePanel(fig, p, where, a), p.id)` gives
back `fig`, relative sizes included. That is why a row in which no panel starts
is dropped even when it was only crossed by a span (a "wholly empty" rule would
leave a blank cell behind). The price: a blank row or column that was there
before also closes at the next Remove.

### Resolving a figure

`spec = cfg.figureFor(id)` (a figure id or an index; `EphysAnalysisConfig:NoFigure`
for an unknown one) is the entry with every `"default"` resolved, what the
compute and the render take:

- the figure's `ref`, `window` and `selection` from [`Defaults`](#defaults) where
  `"default"`;
- `observe.kind` resolved from `"auto"` (`observeKind`), and `observe.units.source`
  set to `observe.source`, a complete [UnitSelection](#unitselection);
- each panel's `ref` and `window` from the figure's (resolved) where `"default"`,
  and two fields added: `aligned` (its type's `Aligned`) and `sharesTime` (its type
  shares time, and both its `ref` and `window` were `"default"`);
- each panel's `options` completed against its type's and, where the panel's
  `common` is true, the figure's [common options](#common-options) put in for the
  type's common fields (`panelOptions`); `common` stays in the spec as the link
  state;
- each layer's `category` added (`"point"`, `"continuous"`, `"unit"`, or
  `""` where the type does not draw the source) and its `units.source` set to its
  `source`.

A panel of an unknown type keeps empty options, with `aligned` and `sharesTime`
false (validate reports the type).

### Observations and skip reasons

`T = figureObservations(src, spec)` lists what dataset `src` (`runner.source(k)`)
offers the figure `spec`, one row each: the preview's picker, and the
observations a run draws a page for. By `spec.observe.kind`:

- `"unit"`: the units `observe.units` keeps (`selectUnits`, with the figure's
  `ref` and `selection`; only their table is used, the spike trains stay in the
  outputs' cache);
- `"channel"`: the columns `observe.channels` names (`[]` = all) of the
  `observe.signal` extract (`selectChannels`);
- `"dataset"`: one row, the dataset itself.

Units and channels are in probe order (the figure's `SortShank` and `SortDepth`),
so stepping through them walks the probe. A dataset that lacks what is observed
(no sorted units, no detections, no such extract), or whose filter keeps nothing,
gives an empty table with the same columns.

| Column | Meaning |
| --- | --- |
| `kind` | `"unit"`, `"channel"` or `"dataset"` |
| `label` | the picker's text: `su12  ch 7  -320 µm` for a unit (its short label, its class unless the label starts with it, its recording channel, its probe y), `LFP ch 7  -320 µm` for a channel (an AUX channel: `AUX <label>`), the dataset's name for the dataset |
| `unitId` | the unit's id (the sorter's, or a detection's channel); `NaN` for a channel or the dataset |
| `channel` | the 1-based recording channel (`NaN`: none, such as an AUX channel, or the dataset) |
| `column` | the extract's column (channel observations; `NaN` otherwise) |
| `shank`, `depth` | the probe shank and y, µm (`NaN` when unknown) |
| `meta` | a 1 x 1 cell: the unit's `selectUnits` row, the channel's `selectChannels` row, or a one-row table with the dataset's name |

`[reason, layerReasons] = figureSkipReason(src, spec)` says why the figure, or a
panel or layer of it, cannot be computed on `src` (`""` = it can), with
`plotSkipReason`'s rules. `reason` is the figure's own: `disabled`; what it
observes is missing (`no sorted units`, `no detected spikes`, `no LFP extract`);
and, when a panel with an enabled layer is aligned, what the figure's alignment
needs (`no paired trials`, `no line X`, `no trial parameter X`). With a
figure-level reason `layerReasons` is empty. Otherwise it is a 1 x n struct array
(`panel`: the panel's id, `layer`: the layer's index, 0 for the panel itself,
`reason`), one entry per panel and then one per enabled layer: a panel's own (an
unknown type, its own `ref` or `window`, a raster sorted by a parameter or event the dataset lacks, a probe
map without a probe map, a tuning curve without paired trials, without a
parameter to tune over (`no numeric trial parameter to tune over`: `param` is
`""`, the selection has no `groupBy` parameter and no trial parameter is numeric
with two or more values) or whose `param` or `seriesParam` the trials lack, `no trial parameter
X`) and a layer's (`no sorted units`, `no <SIGNAL> extract`,
a missing line, `no paired trials`, a missing trial parameter, `no stop event in
the window`, a following layer that cannot follow, a source the panel type does
not draw). A figure that passes may still fail for one observation: `computeFigure`
keeps such a layer with its reason.

### computeFigure

`F = runner.computeFigure(src, spec, Observation=obs)`: `src` from
`runner.source(k)`, `spec` from `cfg.figureFor(id)`, `obs` one row of
`figureObservations(src, spec)` (a table row or a struct with `kind`, `unitId`,
`channel`, `column`; default: the first). It is pure, no graphics, and reads only
what a following layer needs: the observed unit's spike train, the observed
channel's column. The steps: `figureSkipReason` (a figure-level reason throws
`EphysAnalysisRunner:FigureSkipped`; a panel's or layer's is kept); the figure's
epochs, `[E, G] = epochTable(src, spec.ref, Window=, Selection=)`, with the hull of
the baseline windows and the raster sort parameters of the panels on the figure's
alignment, when any panel with an enabled layer is aligned; a panel with its own
`ref` or `window` has its own `epochTable` with the figure's selection (its groups
matched to `G` by label); then each panel's compute through `figurePanelRegistry`.

| `F` field | Holds |
| --- | --- |
| `kind`, `id`, `spec`, `dataset`, `created` | `"figure"`, the figure's id, the spec computed, the dataset's name, a time stamp |
| `observation` | the observation as a struct (`kind`, `label`, `unitId`, `channel`, `column`, `shank`, `depth`, `meta`) |
| `epochs`, `groups` | the figure's epochs `E` and trial groups `G`; `[]` when no panel is aligned |
| `panels(k)` | one per panel of the spec, in order: `id`, `type`, `sharesTime`, `epochs` (the panel's own epochs; `[]` = the figure's), `groups` (`[]` for an unaligned panel), `skip` (`""` or why the panel is not computed: every layer then carries the reason) and `layers` |
| `panels(k).layers(j)` | one per layer of the panel, same order: `name` (the layer's, or automatic), `source`, `binding`, `category`, `eventsAs`, `skip` (`""` = computed; `"disabled"`; or a reason), `R` (the result; `[]` when skipped) and `meta` (the units' or channels' table) |

A skipped layer stays in `F` with its reason and `R = []`; the panel's other layers
are drawn. `R` is the result of the call the plots make: a point layer's
`spikePSTH` (an events layer drawn as marks is `R.kind "events"`, its marks from
`epochEvents`; drawn as a train, a one-unit `spikePSTH` result of the line's
events), a signal layer's `evokedPotential`, a waveforms panel's `unitWaveforms`, a
probe map's `unitSummary` and `probeMapValues`, a correlation map's
`unitCorrelation`; `aggregate "mean"` adds `R.layerMean`. The band's error type
follows the panel (a PSTH's from the style, a continuous panel's from its
`errorType`; the others draw none). While the runner's `PollFcn` is set (the app's preview) the compute stops at
its checkpoints, between steps, panels and layers and inside the long calls; after
`cancel()` the next one throws `EphysAnalysisRunner:Canceled`. Other errors:
`EphysAnalysisRunner:NoObservation` (no `Observation` given and the dataset offers
none).

`F = figureCompute(src, spec, Observation=obs, Check=chk)` is the same compute as
a free function, with no runner: `runner.computeFigure` calls it, adding the
checkpoint while `PollFcn` is set, and the generated standalone script calls it
directly ([Generated scripts](EphysAnalysis.md#generated-scripts)). Its errors
are `computeFigure`'s.

### renderFigure

`h = renderFigure(F, spec, target, Design="", UserAesthetics=true, Editable="auto", OnRemember=[])`
draws `F` as `spec` says (the spec `F` was computed with; its `aesthetics` may
differ, as when the aesthetics editor redraws). `target` is an axes (which draws
panel 1 only), uiaxes, figure, uifigure, panel, tab, grid layout or tiled layout;
renderers never create figures. The `Design`, `UserAesthetics`, `Editable` and
`OnRemember` options are `renderPlot`'s.

- **Layout.** One tiled layout (`TileSpacing` from `grid.spacing`) whose rows and
  columns are the grid expanded into equal tiles, one axes per panel at its cell
  and span.
- **Panels.** Each type's draw function (through `figurePanelRegistry`) draws its
  layers; a skipped layer says why in the panel, a panel with nothing to draw says
  so in its middle. Every object carries an aesthetics role, so the editor lists
  the components, the tiles by panel id; the figure adds the roles `eventLine`,
  `eventRug` and `layerNote`.
- **Time and title.** The [shared time axis](#shared-time-axis); the title is
  `title`, else the id, the observation, the event and the epoch count, with the
  dataset as the subtitle.
- **Legend.** One, east of the panels (`Style.LegendLocation`): the trial groups
  once, then the layers', units', channels' and marks' entries, each label
  once; no panel keeps a legend of its own.
- **Look.** The design's common rules everywhere, then on each panel's axes the
  design's rules for its panel type and the user's remembered rules for that kind
  of plot (a look remembered for PSTH plots also dresses PSTH panels), then on the
  whole figure the design's and the user's `"figure"` rules and `spec.aesthetics`,
  the later winning. In a visible figure a right-click opens the
  [aesthetics editor](EphysAnalysis.md#plot-aesthetics) on the figure.

`h` holds `layout` (the tiled layout; `[]` for an axes target), `axes` (the panels'
axes drawn, in panel order), `panels` (one per panel of the spec: `id`, `type`,
`axes`, empty when not drawn) and `title` (the title text). `renderFigure:Mismatch`
when `F`'s panels are not the spec's.

### A figure in JSON

A raster flush over a PSTH over an LFP panel, all following the unit, with the
stimulus offset marked on every raster row. The `"..."` stand for the rest of a
nested block (as in the [JSON example](#json-example) above); the config's
`Defaults` give the alignment (`"default"`), the three rows are
1.5 : 1 : 1 and drawn as 3 : 2 : 2 tiles, and the options shown are the types'
defaults. All three panels are linked (`"common": true`), so the raster's and
PSTH's `maskAfterStop` and `waveform`, the PSTH's `bins`, `measure` and
`baseline` and the continuous panel's `baseline` stored in their `options` are
not drawn: the figure's `common` block is. A file written by hand may leave out any field that keeps its default.

```json
"Figures": [
  { "id": "unit_card", "enabled": true, "title": "",
    "observe": { "kind": "auto", "source": "units",
                 "units": { "classes": ["su"], "groups": [], "ids": [], "channels": [], "shanks": [], "maxUnits": "Inf",
                            "quality": { "enabled": false, "...": "..." }, "response": { "enabled": false, "...": "..." } },
                 "signal": "LFP", "channels": [], "datasets": "ticked", "datasetKeys": [] },
    "grid": { "rows": 3, "cols": 1, "rowHeights": [1.5, 1, 1], "colWidths": [], "spacing": "none" },
    "common": { "bins": { "BinSec": 0.01, "SmoothSec": 0.01 }, "measure": "rate",
                "baseline": { "Mode": "none", "Window": [-0.2, 0] }, "maskAfterStop": false,
                "waveform": { "mode": "off", "...": "..." } },
    "ref": "default", "window": "default", "selection": "default",
    "panels": [
      { "id": "raster_1", "type": "raster", "title": "", "row": 1, "col": 1, "rowSpan": 1, "colSpan": 1,
        "ref": "default", "window": "default", "common": true,
        "layers": [
          { "name": "", "enabled": true, "source": "units", "binding": "observation", "aggregate": "each", "...": "..." },
          { "name": "Stim offset", "enabled": true, "source": "events", "binding": "fixed", "eventsAs": "marks",
            "event": { "line": "Stim", "edge": "offset", "which": "all", "n": 1, "scope": "recording",
                       "minDurationSec": 0, "maxDurationSec": "Inf", "timeRange": ["-Inf", "Inf"], "offsetSec": 0,
                       "offsetParam": "", "offsetParamUnit": "ms", "sequence": [], "alignStep": "Inf",
                       "marker": "diamond", "size": 4, "color": "" } } ],
        "options": { "rasterSort": "", "rasterSortEvent": [], "rasterSortOrder": "ascending", "rasterByGroup": true,
                     "maskAfterStop": false, "waveform": { "mode": "off", "...": "..." } } },
      { "id": "psth_1", "type": "psth", "title": "", "row": 2, "col": 1, "rowSpan": 1, "colSpan": 1,
        "ref": "default", "window": "default", "common": true,
        "layers": [ { "name": "", "enabled": true, "source": "units", "binding": "observation", "aggregate": "each", "...": "..." } ],
        "options": { "bins": { "BinSec": 0.01, "SmoothSec": 0.01 }, "measure": "rate",
                     "baseline": { "Mode": "none", "Window": [-0.2, 0] }, "histStyle": "bar", "fill": true,
                     "fillAlpha": "NaN", "normalize": "none", "maskAfterStop": false, "yLim": [],
                     "waveform": { "mode": "off", "...": "..." } } },
      { "id": "continuous_1", "type": "continuous", "title": "", "row": 3, "col": 1, "rowSpan": 1, "colSpan": 1,
        "ref": "default", "window": "default", "common": true,
        "layers": [ { "name": "", "enabled": true, "source": "LFP", "binding": "observation", "aggregate": "each", "...": "..." } ],
        "options": { "baseline": { "Mode": "none", "Window": [-0.2, 0] }, "display": "lines", "statistic": "mean",
                     "transform": "none", "errorType": "sem", "stackSpacing": "NaN", "yLim": [] } } ],
    "style": { "LineWidth": 1.2, "...": "..." }, "aesthetics": [] } ]
```

`observe.kind "auto"` resolves to a unit here, since the units layers follow the
observation; the LFP layer follows too, reading the column of the LFP extract
that records the unit's channel. The three panels share the time axis, so only
the bottom one is labeled. The events layer is `fixed`, as every events layer
is, and its `event` is an [EventMark](#raster-event-marks).

### Validating figures

`cfg.validate()` checks `Figures` with the section name `Figures`; a `Field` reads
`<figure>.<field>`, `<figure>.<panel>.<field>` or `<figure>.<panel>.layers(<j>).<field>`.
The rules, by severity (the full list of the other sections is under
[Validation](#validation)):

Errors:

- the figure's id is not empty, has none of `\ / : * ? " < > |`, and stays distinct
  from the other figures' and from the plots' once `{Plot}` has sanitized it
  (case-blind): a figure's files are named with `{Plot}` as a plot's are;
- the figure's own `ref`, `window` and `selection` are valid, by the plots' rules
  (at most 2 `groupBy` parameters);
- `observe`: `kind` is `auto`, `unit`, `channel` or `dataset`; `source` is `units` or
  `detected`; `signal` is `LFP`, `MUA`, `SPIKE` or `AUX`; `channels` are whole
  numbers >= 1; `units.maxUnits` >= 1; `datasets` is `ticked` or `list`; and a
  layer that follows the observation does not go in a figure observed as the
  dataset;
- `grid`: `rows` and `cols` whole numbers >= 1; `rowHeights` and `colWidths` `[]` or
  one finite positive size per row and column; `spacing` `loose`, `compact`, `tight`
  or `none`;
- panels: an id of their own; `row`, `col`, `rowSpan` and `colSpan` whole numbers
  >= 1 inside the grid; no two panels overlapping a cell; a known `type`;
- a panel's own `ref` and `window` only on an aligned type, and valid; a
  `"between"` window (a panel's or the figure's) only on a unit correlation,
  firing rate or tuning curve panel;
- each enabled layer: a `source` in `FigureSources`; an events layer only on a panel
  that shares the time axis; a source the type draws (`A unit waveforms panel draws
  unit-summary layers, not LFP`); a `binding` of `observation` or `fixed`, with
  `observation` only for `units`, `detected` and the signals, never on a heat map,
  probe map or unit correlation panel, and AUX never following a unit
  observation; `aggregate` `each` or `mean`; `units.maxUnits` >= 1; `channels`
  whole numbers >= 1; an events layer's `eventsAs` `marks` or `train`
  (`train` only on a raster, PSTH or heat map), the mark's event reference, a
  `marker` the aesthetics editor knows and a positive `size`; a `lineStyle` that is
  `""`, `-`, `--`, `:` or `-.`;
- a raster whose enabled layers are all events drawn as marks (`A raster's marks
  need rows: add a units, detected or train layer`);
- the figure's [common options](#common-options), once: `common.bins`
  (`BinSec > 0`, `SmoothSec >= 0`), `common.measure`, `common.baseline` (`Mode` one
  of `none`, `subtract`, `zscore`, `percent`, `ratio`, `auroc`; with another Mode than
  `none`, a window `[b0 b1]` with `b0 < b1`), `common.auroc` (with the Mode `auroc`:
  the plots' auROC rules, its window and step whole numbers of `common.bins`, and the
  Statistics and Machine Learning Toolbox) and `common.waveform` (mode, location,
  `scale` in (0, 3], whole `maxSpikes >= 1`, `ampScale`; `off` allowed). A linked panel
  (`common` true) is not checked for these fields again, except that its type must
  take the common baseline `Mode`: a continuous, unit correlation or signal heat map
  panel with a common `zscore`, `percent`, `ratio` or `auroc`, a PSTH or spike heat
  map with `ratio`, and a rate or tuning panel with `percent` or `auroc`, is an error
  at `<figure>.<panel>.common`;
- options, by type, as drawn (`panelOptions`; the common fields only for a panel with
  `common` false): a raster's `rasterSortOrder` and, with `rasterSort "event"`, a
  valid `rasterSortEvent`; a PSTH's `bins` (`BinSec > 0`, `SmoothSec >= 0`),
  `measure`, `baseline` (`Mode` among the type's, a window `[b0 b1]` with `b0 < b1`),
  `auroc` (with baseline `Mode "auroc"`, as the common ones, against the panel's own
  bins, at `<figure>.<panel>.options.auroc`), `histStyle`, `normalize`, `fillAlpha`,
  a positive `stackSpacing`, `yLim`; a continuous panel's `baseline`
  (`none` or `subtract`, its window overlapping the panel's window, also when the
  baseline is the figure's), `display`, `statistic`, `transform`, `errorType` (`ci95`
  and `iqr` need the Statistics and Machine Learning Toolbox), a positive or `NaN`
  `stackSpacing`, `yLim`; a heat map's `bins`, `measure`, `baseline` and `auroc` for a
  spike layer (a signal layer with baseline `Mode "auroc"` is an error: spikes only),
  `baseline` for a signal layer, `order` (`probe`, `peak`, or `modulation` only with
  the auROC baseline of a spike layer), a whole `group` >= 1, `cLim`; a waveforms
  panel's `layout` (`grid` or `probe`); a probe map's `value` and `cLim`; a
  correlation map's `metric`, `correlation`, `bins` (for `peak`), `baseline`, `group`,
  `cLim`; a rate panel's `measure`, `baseline` (`Mode` `none`, `subtract`, `ratio` or
  `zscore`), `display` (`bar`, `box` or `points`) and `yLim`; a tuning panel's `measure`,
  `baseline` (as a rate panel's), `param` and `seriesParam` (each empty or a trial
  parameter's name, and not the same one), `yLim` and `waveform`; the `waveform`
  settings of a raster, PSTH, tuning or waveforms panel (mode, and for a waveforms
  panel never `off`; location, `scale` in (0, 3], whole `maxSpikes >= 1`, `ampScale`);
  `yLim` and `cLim` `[]` or ascending;
- the figure's `style`, by the plots' rules (`MaxTiles >= 1`, `TileSpacing`, the legend
  settings, `ErrorType`, `ErrorResamples`, `ErrorFaceAlpha`, ...; the bootstrap CI
  needs the Statistics and Machine Learning Toolbox where a PSTH band, a rate
  panel's error bar or a tuning curve's error bar draws it).

Warnings:

- a figure with no panels; cells that no panel covers (they stay blank);
- a panel with no enabled layer; several enabled layers on a type that draws one
  (only the first enabled one is drawn; not for a waveforms panel in the probe
  layout, whose further layers ring their units);
- a waveforms panel in the probe layout whose first enabled layer follows the
  observation (`<panel>.options.layout`): it draws the one unit, not the probe's
  units, so bind it to fixed units and ring the observed unit with a following layer;
- an explicit `unit` or `channel` observation with no layer following it (the figure
  is the same for every one); `datasets "list"` with no `datasetKeys`;
- a signal layer following a channel observation of another signal (it takes the
  observed channel's number in its own extract);
- a fixed raster, PSTH, rate or tuning point layer that may keep more than 8 units, each drawn in
  the one panel (limit `units.maxUnits` or `ids`, or aggregate them with `mean`);
- a layer's or mark's `color`, or a style color, that is not a color.

Whether a dataset can draw the figure (units, signals, lines, trial parameters, a
probe) is not a config error: `figureSkipReason` says why a figure or a layer is
skipped on a dataset ([above](#observations-and-skip-reasons)).

### Converting a plot

`[fig, notes] = EphysAnalysisConfig.plotToFigure(cfg, plotId)` makes the figure
that draws what a plot of `Plots` draws, with the plot's alignment, unit filter,
bins, baseline and look, and `notes`, a string row of what the figure could not
carry (one sentence each; nothing is dropped silently). `[cfg, id, notes] =
cfg.convertPlotToFigure(plotId)` appends the figure to `Figures`; the plot stays.
The app's **Convert to figure** button calls it
([Plots tab](EphysAnalysisApp.md#plots-tab)).

```matlab
[cfg, id, notes] = cfg.convertPlotToFigure("psth_stim");   % id = "psth_stim_fig"
disp(notes.')                                              % e.g. "PSTH stacking (stack) is not available in figures yet: ..."
any(cfg.validate(CheckPaths=false).Severity == "error")    % false: the figure validates
```

**Figure level.** The id is `<plot>_fig`, or `<plot>_fig2`, `_fig3`, ... when a
plot or figure already has it (case ignored): a figure may not share a plot's id,
as both name files through `{Plot}` ([validation](#validating-figures)).

| Figure field | Taken from the plot |
| --- | --- |
| `enabled`, `title`, `aesthetics` | the plot's |
| `ref`, `window`, `selection` | the plot's; `"default"` stays `"default"` |
| `style` | the plot's, with `MaxTiles`, `TileSpacing`, `XLim`, `YLim` and `CLim` back at their defaults (a figure does not use them). `YLim` goes to the data panel's `options.yLim` and `CLim` to its `options.cLim` |
| `common` | the plot's `bins`, `measure`, `baseline`, `maskAfterStop` and `waveform`; every panel is linked to them ([Common options](#common-options)) |
| `observe` | below. The plot's `source` (`units` or `detected`) is the layers' source and, for a figure drawn per unit, `observe.source`; its unit filter is `observe.units` when the figure observes units, else the fixed layer's `units` |
| `grid` | one column, a row per panel top to bottom; `spacing "none"` (flush) for a unit's raster, PSTH and aux panels |

**By plot kind.** The second column is what the figure is drawn for
(`observe.kind`), the third its panels, top to bottom, and their layers.

| Plot kind and layout | Observe | Panels and layers |
| --- | --- | --- |
| `psth`, grid | unit (`source`, the `units` filter) | a raster (when `withRaster`; its sort options; `rasterEvents` as events layers drawn as marks) over a PSTH (`histStyle`, `fill`, `fillAlpha`, `normalize`, `yLim`), each with a layer following the unit; equal heights (with an aux panel, the unit's panels are twice as high as it: 2 : 2 : 1) |
| `psth`, overlay | dataset | one PSTH panel with a fixed `units` layer (the filter) and `aggregate "mean"` |
| `raster` | unit | a raster panel with the marks layers |
| `evoked`, grid | channel (`signal` = the plot's `source`, `channels` = the plot's) | one continuous panel following the channel |
| `evoked`, stack | dataset | a continuous panel with a fixed layer of the channels, `aggregate "each"`, `display "stacked"`, `stackSpacing` = `Style.StackSpacing` |
| `evoked`, butterfly | dataset | as the stack, `display "lines"` |
| `heatmap` | dataset | a heat map panel with a fixed layer (the units filter, or the channels), `order`, `group` 1, `cLim` |
| `probemap` | dataset | a probe map panel with a fixed layer, `value`, `cLim` |
| `corrmap` | dataset | a correlation map panel with a fixed layer, `metric`, `correlation`, `fisherZ`, `group` 1, `cLim` |
| `waveforms`, grid | unit | a waveforms panel following the unit; `common.waveform` = the plot's waveform settings |
| `waveforms`, probe | dataset | a waveforms panel with a fixed layer |
| `rate`, `tuning`, `behavior` | none | not converted: `EphysAnalysisConfig:NotConvertible` (no panel type draws them yet) |

An unknown plot id is `EphysAnalysisConfig:NoPlot`. A PSTH's or raster's **aux
signal** (`aux.mode` not `off`) becomes a continuous panel of a fixed `AUX` layer
below the unit's panels (above them for `placement "above"`), half as high as
each of them: `"channels"` is `aggregate "each"`, `"magnitude"` is
`aggregate "mean"`; the aux `baseline`, `statistic`, `transform`, `errorType` and
`yLim` become that panel's own options (it is not linked to the common
baseline); `channels` and `display` carry over. A PSTH with a waveform inset keeps
it in the PSTH panel (the raster, which would otherwise draw it too, is unlinked
from the common options and keeps the plot's `maskAfterStop`).

**Notes.** What the figure does not hold gives a note, one sentence each:

- an auROC baseline becomes `none` (its `auroc` settings are not carried);
- a baseline mode the panel cannot take (`zscore` or `percent` on a continuous or
  correlation panel or a heat map of a signal) becomes `none`;
- the aux magnitude became the mean of the AUX channels;
- an aux `placement "over"` (on the right y axis) becomes `below`;
- the aux heat map display becomes `lines`;
- the aux `colorBy` and `byGroup` are not carried (the panel colors its traces by
  trial group, one trace each);
- `stack` and `stackRaster` are not carried (the groups are overlaid);
- an overlay's `withRaster`, event marks and waveform inset are not carried (an
  overlay of several units draws none);
- event marks of a plot without a raster (`withRaster` off) are not carried;
- a butterfly's one panel per trial group is not available: the channels are lines
  in one panel;
- a heat map's `modulation` order (auROC) becomes `probe`;
- a heat map or correlation map draws one trial group (group 1) when the selection
  groups its trials, where the plot drew one per group: set the panel's group, or
  add a panel per group;
- the waveforms probe layout is not available: the units' waveforms are drawn in
  one panel;
- `MaxTiles`, `TileSpacing` and `XLim` are not used (a figure draws one observation
  per page, takes `grid.spacing` and shows the epoch window), nor are `YLim` and
  `CLim` when no panel of the figure takes them;
- the plot's text note and overlays are not carried yet (figures have none).

## Export

| Field | Default | Meaning |
| --- | --- | --- |
| `Enabled` | `true` | write figure files (the runner's default for `run(Export=)`) |
| `Formats` | `["png" "svg"]` | any of `png`, `eps`, `svg`, `pdf` |
| `Folder` | `{OutputFolder}\analysis` | a [folder pattern](#file-name-tokens) |
| `FilenamePattern` | `{Name}_{Plot}` | a [file-name pattern](#file-name-tokens): `{Name}` (dataset) `{Plot}` `{Kind}` `{Group}` `{Unit}` `{Index}` `{Date}`; a paged plot adds `_p<page>` unless the pattern tells its pages apart: `{Index}`, or `{Unit}` with a unit filled in (a paged evoked grid's `{Unit}` is `all` on every page). A [figure](#figures) writes a file set per observation instead of pages: [below](#figures-in-an-export) |
| `Dpi` | 150 | PNG resolution |
| `FigureSizeCm` | `[18 12]` | figure size `[width height]`; a grid page is made taller when its rows need it: 3 cm a row of tiles (4.5 cm for PSTHs with rasters) plus 1.5 cm; a figure's page, 3.5 cm for each row of its arrangement plus 2 cm |
| `Overwrite` | `true` | `false`: a page (a figure's observation) whose files all exist is not written again, nor drawn unless the report needs its image (HTML) or page (PDF); a session plot's data file is not replaced either (a note in the row's message) |
| `SessionsFolder` | `{OutputRoot}\analysis\sessions` | where the [session plots'](#session-plots) figures go: a [folder pattern](#file-name-tokens) whose tokens are the first session's (`{OutputFolder}` is one dataset's folder, so a warning there). Named with `FilenamePattern`, `{Name}` being the facet (`all`, or the subject) and `{Plot}` the session plot's id, then `_<trial group>` for `trialGroups "each"` |
| `Data.Enabled` | `false` | write each session plot's data as a `.mat` file in a run ([format](file-formats.md#session-data-mat)); the app's **To workspace** and **Save .mat...** work either way |
| `Data.Folder` | `{OutputRoot}\analysis\data` | a folder pattern, as `SessionsFolder` |
| `Data.FilenamePattern` | `{Name}_{Plot}` | a [file-name pattern](#file-name-tokens); `{Name}` is `all`, `{Plot}` the session plot's id; `.mat` is added. One file per session plot holds every facet and trial group |
| `Data.MatVersion` | `"-v7.3"` | `"-v7.3"` (HDF5, no 2 GB limit, readable with `h5read` and from Python) or `"-v7"` |

`exportFigure` writes PNG with `exportgraphics` at `Dpi`, PDF and EPS as
vector graphics (`exportgraphics`, `ContentType="vector"`) and SVG with
`print -dsvg -vector`, creating the folder.

### Figures in an export

A [figure](#figures) is drawn once per observation (a sorted unit, a channel of
a signal, or the dataset), and each observation is one page and one file set
(`Formats`), named by `figureOutputName` from `FilenamePattern` with these
token values (the folder pattern is the plots'):

| Token | Value for a figure's observation |
| --- | --- |
| `{Name}` | the dataset |
| `{Plot}` | the figure's id |
| `{Kind}` | `figure` |
| `{Group}` | `all` |
| `{Unit}` | the observation's short label: a sorted unit's label before the recording suffix (`su12` of `su12_RAT1_260918T1015`), a detection's whole label (its channel's name, `Shank_1`), else `u<unitId>`; a channel `ch<N>`, `N` its recording channel (an AUX channel: its label); the dataset `dataset` |
| `{Index}` | the observation's number, 1 to the count |
| `{Date}` | today (yyyyMMdd) |

- A figure has no `_p<page>`. When it has more than one observation and the
  pattern names neither `{Unit}` nor `{Index}`, `_<Unit>` is added to the name, so
  the default `{Name}_{Plot}` writes `SYNTH-01_..._card_su12.png`,
  `..._card_su14.png`, ... A one-observation figure, such as a dataset figure,
  keeps `<Name>_<id>.png`.
- A figure's page is `FigureSizeCm(1)` wide and 3.5 cm tall for each row of its
  arrangement (`grid.rows`) plus 2 cm for the title and x label, never below
  `FigureSizeCm(2)`.
- With `Overwrite` off an observation whose files all exist is neither computed
  nor drawn again, unless the report needs its image or page.
- A layer or panel that cannot be computed for one observation (no sorted unit
  left, no event in the window) is drawn as a note in the page, not as a failure;
  a figure that fails is an `error` row and the others still run.

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

A [figure](#figures) is one entry per dataset in the report, kind `figure`,
whatever its number of observations: its pages are the observations, one image
(HTML) and one page (PDF) each, in the order of `figureObservations`, under one
caption from `figureCaption`. The caption names the figure (and its title), how
many observations of what it was drawn for (sorted units and the classes the
filter keeps, detections, the extract's channels, or the dataset), the panel
types in order, and, when a panel with an enabled layer is aligned, the event,
the window and the trial grouping, for example:

> rp: 12 observations (sorted units: su, mua) of RAT1_260918; panels: raster,
> PSTH; aligned to Stim onset; window [-0.2 0.8] s; groups by Depth.

The entry links the exported files and, with `IncludeParameters`, folds the
figure's resolved spec under it. A figure the dataset cannot draw (or that fails)
is listed with its status and message, as a plot is.

## File-name tokens

`figureFileName` fills the patterns, of two kinds:

| Pattern | Tokens |
| --- | --- |
| folder (`Export.Folder`, `Report.Folder`) | `{OutputFolder}` (the dataset's output folder), `{OutputRoot}`, `{Root}` (`Source.Root`), `{Name}` (the dataset), `{Date}` (yyyyMMdd) |
| file name (`Export.FilenamePattern`) | `{Name}` (the dataset), `{Plot}` (the plot id), `{Kind}`, `{Group}` (`all`: a page holds every group), `{Unit}` (the first unit on a page of a paged psth, raster or tuning grid, else `all`), `{Index}` (the page), `{Date}` (yyyyMMdd). For a figure's observation (`figureOutputName`): `{Plot}` is the figure's id, `{Kind}` is `figure`, `{Unit}` the observation's short label (`su12`, `ch7`, `dataset`) and `{Index}` its number |

- `{OutputRoot}` is `Source.OutputRoot`, else `Source.Root`, else the
  folder above the first dataset's output folder.
- In a file name, every character of a token's value outside
  `A-Z a-z 0-9 _ - .` becomes `_`; the path tokens of a folder are used as
  they are.
- A plot with several pages (a grid with more units or channels than
  `Style.MaxTiles`) gets `_p<page>` added, unless the pattern tells its
  pages apart (`Export` above).
- A figure has a file set per observation and no `_p<page>`: when it has several
  and the pattern names neither `{Unit}` nor `{Index}`, `_<Unit>` is appended
  ([Figures in an export](#figures-in-an-export)).
- An unknown token is `figureFileName:UnknownToken`; a brace without its
  pair, or a file name holding `\ / : * ? " < > |`, is
  `figureFileName:BadPattern`.
- A report over every dataset with `{OutputFolder}` in its folder goes to
  the first dataset's folder (a validation warning).
- `Export.SessionsFolder` and `Export.Data.Folder` are folder patterns too,
  with the first session's tokens. In a session plot's figure or data file
  name, `{Name}` is the facet (`all`, or the subject) and `{Plot}` the session
  plot's id; `{Group}` and `{Index}` are as for a plot, and a trial group of
  `trialGroups "each"` is added after the page as `_<group>`.

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
| Plots | at least one plot, figure or session plot enabled (`No plot, figure or session plot is enabled.`); ids that stay distinct once `{Plot}` has sanitized them (case-blind); the kind exists; the source, layout, window mode and baseline mode fit the kind; `measure` rate / count / probability; tuning names its parameter; behavior names `param` and `yParam` (`"stop"` with a stop event), its `xScale` is category / linear and the violin layout has `violinplot`; a psth / raster `rasterSortOrder` ascending / descending, a `rasterSortEvent` (a valid event reference) with `rasterSort "event"`, and each of its `rasterEvents` a valid event reference with a known marker and a positive size; `BinSec > 0`, `SmoothSec >= 0` where bins are used; a baseline window `[b0 b1]` with `b0 < b1`; probemap value, psth `histStyle` bar / line, `normalize` none / unitPeak / groupPeak / allPeak, `fillAlpha` 0-1 or NaN, `stackSpacing > 0`; heatmap order (`"modulation"` only with the auROC baseline); the auROC settings (method, windows, whole-bin window and step, call window, cutoff, threshold, test, `nResamples`, correction, alpha, `modulatedOnly` with a cutoff) and the toolbox they need; corrmap metric and correlation; `maxUnits >= 1`; an enabled response test of spikes: its test, `param` for tuning / either / both, `baseline` and `window` ordered, direction, correction, alpha in (0, 1], the auROC settings of a test `"auroc"` (with a cutoff) and the Statistics and Machine Learning Toolbox; a `waveform` mode off / mean / subsample / both and, when not off, its location, `scale` in (0, 3] and a whole `maxSpikes >= 1`; an `aux` mode off / channels / magnitude and, when not off, its `placement` below / above / over, `display` lines / stacked / heatmap, `statistic` mean / median, `transform` none / rectify, `colorBy` auto / group / channel, `errorType` off / sem / std / ci95 / iqr (`ci95` and `iqr` need the Statistics and Machine Learning Toolbox), whole `channels >= 1`, `baseline` none / subtract and, when subtracting, a `baselineWindow` `[b0 b1]` with `b0 < b1` that overlaps the epoch window; for a note with text, its `placement`, `align`, `valign`, `interpreter`, a numeric `rotation`, a positive or `NaN` `fontSize`, and `x` and `y` for `"custom"`; for each overlay, its `shape` line / region, `axis` x / y, a finite `value` (line) or two finite, different `from` and `to` (region), `panel` all / data / raster, `layer` over / under, a `lineStyle` among `-` `--` `:` `-.`, a positive `lineWidth` and `alpha` and `faceAlpha` within 0-1; `MaxTiles >= 1`, `TileSpacing` loose / compact / tight / none, `FontSize`, `LineWidth`, `SiteSize` positive; `ErrorType` sem / std / ci95 (`ci95` needs the Statistics and Machine Learning Toolbox where the plot draws it), a whole `ErrorResamples >= 1`, `ErrorFaceAlpha` 0-1 or NaN, `ErrorEdgeStyle` among `-` `--` `:` `-.`, a positive `ErrorEdgeWidth` | error |
| Plots | a `HeatColormap` that is not a colormap function; a `Colormap` that is neither a colormap function nor a color (the default is used); a raster mark's `color` that is not a color (it gets its automatic one); a `waveform` mode on a plot that draws no unit tiles (an overlay, a plot of signals, a kind other than raster / psth / tuning / waveforms); an `aux` mode on a plot other than a psth or raster of spikes; `aux.placement "over"` on a stacked PSTH or with a heat map (drawn below); an `aux.errorType` other than off with a heat map (no band is drawn), or `"sem"` / `"std"` with the median; a note's `color` or `background` that is not a color (left to the design); an overlay's `color`, `faceColor` or `edgeColor` that is not a color (its default is drawn); an overlay's raster or data `panel` on a plot that draws no such panel (nothing is drawn); two overlays of a plot with one `name`; an `ErrorFaceColor` or `ErrorEdgeColor` that is not a color | warning |
| SessionPlots | the id is not empty, has no `\ / : * ? " < > \|`, and stays distinct from the other session plots' once sanitized (case-blind); `datasets`, `facet`, `series`, `colorOrder`, `error`, `match` and `trialGroups` are known values and `data` holds only `results`, `epochs` and `signals`; `minSessions` a whole number >= 1; `match "mapping"` has a mapping file that exists (with `CheckPaths`), that reads and has a `cell` column; the base plot exists, is a kind that can be merged (`SessionKinds`) and has no auROC baseline; the `layout` fits its kind | error |
| SessionPlots | `datasets "list"` with no `datasetKeys`; a mapping file with no column for a listed dataset key; `match` other than `"pool"` on a plot of signals, a heatmap, a waveforms or a behavior plot (ignored); a tuning or behavior plot's `seriesParam` with `trialGroups "pool"` (replaced by the sessions); `showMembers` with `series "session"`; `"combine"` on a PSTH drawn as bars (drawn as lines); a heatmap with `series` other than `"all"` (its rows are the session-units, or the channels averaged: ignored) | warning |
| Figures | the figure id is not empty, file-name safe and distinct once sanitized from the other figures' and from the plots' ids (both fill `{Plot}`: `Figure id "x" names the same files as a plot's id`); the figure's alignment is valid; `observe` (kind, source, signal, channels, `maxUnits`, datasets) and `grid` (rows, columns, relative sizes, spacing) hold known values; each panel has an id of its own, a known type, a place inside the grid that no other panel overlaps, and its own `ref` / `window` only when its type is aligned; the figure's common options (bins, measure, baseline, auROC, waveform), checked once, and a linked panel's type taking the common baseline mode; each enabled layer's source, binding, aggregate, channels, events (`eventsAs`, event reference, marker, size) and line style fit its panel type; a raster has rows, not marks alone; each type's options as drawn (a linked panel's common fields are the common options'); the style ([rules](#validating-figures)) | error |
| Figures | no panels; cells no panel covers; a panel with no enabled layer, or with several on a type that draws one; an explicit unit or channel observation with no layer following it; `datasets "list"` with no keys; a signal layer following another signal's channel; a waveforms panel in the probe layout whose first layer follows the observation; a fixed raster, PSTH, rate or tuning layer that may keep more than 8 units; a layer, mark or style color that is not a color ([rules](#validating-figures)) | warning |
| Export | formats are png / eps / svg / pdf (and at least one when enabled); `Dpi` positive; `FigureSizeCm` two positive numbers; the folder and file-name patterns use known tokens, and the file-name pattern is not empty; `SessionsFolder` and `Data.Folder` are folder patterns, `Data.FilenamePattern` a file-name pattern, and `Data.MatVersion` is `-v7.3` or `-v7` | error |
| Export | a file-name pattern without `{Plot}` while several plots and figures are enabled (`{Kind}` is enough when the enabled plots and figures all differ in kind, a figure's kind being `figure`); neither the folder nor the file-name pattern names the dataset (`{OutputFolder}` or `{Name}`), unless the source is a single folder: files that would overwrite each other | warning |
| Export | `{OutputFolder}` in `SessionsFolder` or `Data.Folder`: it is one dataset's folder, so the session plots' files go to the first dataset's | warning |
| Report | Format html / pdf / both, EmbedFormat png / svg, `Dpi` positive, a plain `FileName`, the folder pattern | error |
| Report | `{OutputFolder}` in a report over every dataset | warning |

Whether a dataset can draw a plot (units, signals, trials, lines,
parameters, a probe) is not a config error: the runner skips that plot on
that dataset and says why ([Why is my plot skipped?](EphysAnalysisApp.md#why-is-my-plot-skipped)).

## Tests

`test_EphysAnalysisConfig`: defaults, save / load round trips (Inf, NaN,
one- and two-item lists, `"default"` sentinels, stop events, the PSTH stack
and unit-waveform settings, the mean aux signal's settings, the raster's
sort (its sort event too, and a line name as one) and event marks, behavior
fields, events shifted by a parameter, the error settings), `plotFor`, `removePlot`,
`enabledPlots`, auto and duplicate ids, `addPlot`'s source by kind, a cell
of partial plots, every validate rule (ids and patterns whose files would
collide, the auROC baseline and response test, behavior plots, the
raster's sort event and raster marks, the aux signal and the error settings included), `LoadWarnings`, `BadSchema`, `BadValue`,
`figureFileName` and `plotFileName`'s page suffix; and session plots: the defaults
(none; `Export.SessionsFolder`, `Export.Data` off, `-v7.3`), `addSessionPlot`'s
ids, `removeSessionPlot`, `enabledSessionPlots`, `DuplicateSessionPlotId`, a cell
of partial session plots, the JSON round trip (a one-key list stays a list; a
config file without `SessionPlots` loads with none and no warning), `sessionPlotFor`
(the overrides, `"pool"` clearing the groups and a tuning plot's series, `"each"`
keeping them, `sessionAesthetics`) and every session-plot validate rule; and the
rules that count figures: "No plot, figure or session plot is enabled." (an enabled
figure alone is enough), a figure id that names a plot's files (`PSTH_1`, `psth 1`
beside the plot `psth_1`), and the `{Plot}` warning counting enabled figures
(their `{Kind}` is `figure`).

`test_EphysAnalysisFigures`, in eight sections. Config (1 to 6): the defaults of
Figure, FigureCommon, Panel, Layer and Observe (`common` after `grid` in a
figure, after `window` in a panel; `FigureCommon` with its `auroc` block);
`panelTypes` (nine types, with the rate and tuning rows' flags), `sourceCategories`,
`categoryOf`, `observeKind`, `defaultLayer` (an unknown type is a `BadValue`),
`commonFields` (six, `auroc` among them) and `commonFieldsOf` (the rate and
tuning rows); `addFigure`'s templates (the `"rate"` and `"tuning"` ones
included) and ids and `figureFor`'s resolution (the defaults, a panel's
own `ref` or `window`, `sharesTime`, `units.source`, the observe kind, options
completed and re-seeded by a type change, a linked panel taking the common
bins, baseline, auROC and waveform and an unlinked one its own, a waveforms
panel's common mode `off` drawn as `both`, its `layout`); the JSON round trip (every panel type,
relative sizes, an events layer with a sequence, fixed and following layers, the
`"default"` sentinels, the common options and a panel's `common = false`, a cell
`Figures` from `jsondecode`, a config without `Figures`, unknown fields in
`LoadWarnings`); `adoptPanelOptions`, `adoptPanelAlignment` and `relinkPanels`
(their results and `NoPanel`); `placePanel` in four directions, `removePanel`
(undoing each exactly), `movePanel` and `figureCells`; `DuplicateFigureId` and
`DuplicatePanelId`; every validate rule of figures (only the known layer sources and
panel types; the common block's bins, measure, baseline, auROC and waveform
checked once; a common baseline mode a linked continuous panel does not take,
and a common auROC baseline a linked continuous one does not; a PSTH's baseline
mode (no `ratio`), `auroc` windows and positive `stackSpacing`; a heat map's
`modulation` order and the auROC baseline of a signal layer; a waveforms
panel's `layout` and the probe layout's warning; a rate panel's `display`,
`measure`, baseline mode and `yLim`; a tuning panel's `seriesParam`, `param`
and waveform; a `"between"` window on a rate and a tuning panel; an unlinked
PSTH's own auROC windows against its own bins),
and the Plots style messages
unchanged by the style check the two share. Compute (7), on the analysis
fixture: `figureObservations` (the filter's units in probe order, a tightened
filter, an LFP figure's channels, a dataset figure's one row) and
`computeFigure` (the raster over PSTH of one unit, an LFP layer following the
unit, a fixed AUX layer averaged, an AUX layer following the unit skipped with
its reason, three fixed units averaged, events as marks and as a train, a
panel's own window, a channel observation, probe map, correlation map
and waveforms, a rate panel and a tuning panel equal to `computePlot`'s rate
and tuning of the unit (the tuning parameter from `groupBy`, else the first
numeric one; a series and the waveform inset; a missing parameter skipping the
panel, in `figureSkipReason` too), a rate layer of three units' mean, an auROC
PSTH equal to `computePlot`'s, a stacked PSTH, the waveforms probe layout with
a following layer to ring, a layer skipped while its panel is drawn, `PollFcn`
and cancel, and one observation computed faster than the plot over every unit).
Render (8):
`figureTiles`, a compute and a draw function for every panel type, every type
drawn into an axes, uiaxes, figure, panel and grid layout with every component
tagged, the titles, one time axis down a stack, one legend, skipped layers'
notes, events as marks, latency lines and a rug, a stacked PSTH (a row and a
baseline per group, the legend's groups once, one group overlaid, a second
layer in the rows), an auROC PSTH (a 0-1 axis, the chance line, the modulation
window, the calls; stacked too) and heat map (the diverging colormap, 0-1),
rate panels (bars, boxes of two layers, points), tuning curves (a series, the
inset), the waveforms probe layout with the observed unit framed, and the
editing hooks (`Editable`, `OnRemember`, the redraw). Compute (7) also checks `figureCompute`
against `computeFigure` (equal results, `Check=` called at the checkpoints and
what it throws stopping the compute), `figureOutputName` (`{Plot}`, `{Unit}`,
`{Index}`, the `_<Unit>` suffix, the short labels of units, detections and
channels) and `figureCaption`.

`test_plotToFigure`, in eight sections, on hand-made configs: a PSTH grid with its
raster, event marks, waveform inset and aux magnitude, field by field (observe,
panels, layers, options, common, style, notes); the PSTH variants (without its
raster, an overlay, stacking and an auROC baseline as notes, a raster with its aux
above, and `"over"`); a raster; evoked grid, stack and butterfly; heat maps of
units and of LFP, a probe map and a correlation map; unit waveforms in a grid and
on the probe; `NotConvertible` for rate, tuning and behavior, `NoPlot`, the ids
(`<plot>_fig`, `_fig2`, ... free among plots and figures), `"default"` sentinels
kept and a plot's own alignment carried, the text note, overlays, `MaxTiles`,
`TileSpacing`, `XLim` and an unused `YLim` as notes, and `convertPlotToFigure`
appending; every converted figure validates. On the analysis fixture a converted
PSTH with its raster, Stim offset marks and aux channels computes and renders for
one unit.

`test_EphysAnalysisRunner`'s section 11 runs figures through the runner on the
fixture: `plan` rows (Kind `figure`, Source `unit`, `channel` or `dataset`,
`Figures=` and `Plots=` with `string.empty(1, 0)` for none, no bulk data loaded),
`run` (a row per figure with `<n> observation(s)`, a file per observation named
`<Name>_<figure>_<unit>.png` and a one-observation dataset figure `<Name>_map.png`,
no figure left open), the report (one entry per figure and dataset, an image and
a PDF page per observation, `figureCaption`'s caption, the HTML's kind, caption
and file links), the run record's `figures`, one figure alone with `Overwrite` off,
`cancel()` between a figure's observations and during a plot, and the standalone
script (`fspec<k>`, `figureCompute` and no runner, no syntax error, run, its PNGs
pixel-identical to the runner's and an equal HTML report).

<!-- wiki
## Related

- [Analysis app](EphysAnalysisApp.md): the GUI that edits a config
- [Analysis scripting](EphysAnalysis.md): running configs from scripts, generated scripts, the functions
- [Pipeline configs](Pipeline-Configs): the pipeline config, whose project settings `Source` mirrors
- API: [EphysAnalysisConfig](API-EphysAnalysisConfig), [EphysAnalysisRunner](API-EphysAnalysisRunner), [Analysis functions](API-Analysis-Functions)
-->
