# EphysAnalysisConfig

`EphysAnalysisConfig` ([source](../analysis/@EphysAnalysisConfig/EphysAnalysisConfig.m))
is a value class that describes a set of quick-look figures: which datasets
to read, how to align them, which multi-panel [figures](#figures) to
design for one unit, channel or dataset (and which to draw
[across sessions](#session-figures)), and how to export and
report them. `EphysAnalysisApp` edits one, `EphysAnalysisRunner` runs one and
`EphysAnalysisScript` writes scripts from one ([Analysis](EphysAnalysis.md)).
It is saved as JSON (schema `ephys-analysis-config`, version 2) and
round-trips exactly, `Inf`, `NaN` and empty values included. A version 1
file, which held `Plots` and `SessionPlots` instead of figures, is migrated
once when it is loaded ([Loading a version 1 config](#loading-a-version-1-config)).

It is separate from the [pipeline config](EphysPipeline.md#ephyspipelineconfig):
the pipeline never reads an analysis config, and the analysis reads the
pipeline's outputs and writes only its own figures, reports and run
records, to the folders set below. The one file it may write into a sort
folder is the `quality_metrics.json` cache, for a figure that keeps good
units only ([UnitSelection](#unitselection) `quality`).

```matlab
cfg = EphysAnalysisConfig();                                % defaults: no figures yet
cfg.Name = "AM quick look";
cfg.Source.Root = "D:\EPHYS";
cfg.Defaults.EventRef.line = "Stim";
cfg.Defaults.Selection.groupBy = "Depth";
cfg = cfg.addFigure("rasterPsth", Id="unit_card");          % a unit's raster over its PSTH
cfg = cfg.addFigure("continuous", Id="lfp_stim");           % a channel's LFP
issues = cfg.validate();                                    % table: Section, Field, Severity, Message
cfg = cfg.save("D:\EPHYS\am_quicklook.json");               % sets cfg.File
cfg = EphysAnalysisConfig.load("D:\EPHYS\am_quicklook.json");
T = EphysAnalysisRunner(cfg).run();                         % one row per dataset and figure
```

As a value class, `addFigure`, `removeFigure` and `save` (which sets `File`)
return the changed config and leave the one they were called on as it was:
keep the result (`cfg = cfg.addFigure(...)`, `cfg = cfg.save(...)`).

## Class

| Member | Meaning |
| --- | --- |
| `Name`, `Description` | text; `Name` (default `"Untitled"`) fills `{Name}` in the report title |
| `Source`, `Defaults`, `Export`, `Report` | sections (structs), coerced on assignment |
| `Figures` | struct array, one entry per [figure](#figures): one observation's panels (a unit, a channel or the dataset) on a grid. Its ids are unique among figures (`EphysAnalysisConfig:DuplicateFigureId`; a figure's panel ids `EphysAnalysisConfig:DuplicatePanelId`); a cell array (what `jsondecode` gives for figures whose fields differ) is accepted too. A run draws the enabled figures, a page per observation ([Export](#export), [Report](#report)); one with `sessions.enabled` is a [session figure](#session-figures), drawn once across the datasets instead |
| `File`, `LoadWarnings` | transient: where it was loaded from / saved to; the unknown fields `load` dropped |
| `Schema`, `Version`, `Sections`, `SpikeSources`, `SignalSources`, `FigureSources`, `ObserveData`, `WaveformLocations`, `ErrorTypes`, `ListFields` | constants. `Version` is 2 (a version 1 file is [migrated](#loading-a-version-1-config) on load); `FigureSources`: what a figure's layer reads, `ObserveData`: what a figure is drawn for (`observe.data`: `units`, `detected`, `LFP`, `MUA`, `SPIKE`, `AUX`, `dataset`); `Figures` is a list, not one of the four `Sections`. The continuous panels' and notes' choices: `AuxStatistics`, `AuxTransforms`, `AuxErrorTypes`, `NotePlacements`, `OverlayLayers`, `OverlayLineStyles`. The [session figures'](#session-figures): `SessionSeries`, `SessionErrors`, `SessionTrialGroups`, `SessionFacets`, `SessionColorOrders`, `FigureSessionMatches` (`"site"`, `"mapping"`: a figure observes one matched unit, so no pooling) and `FigureSessionUnmerged` (the panel types that cannot be merged across sessions: `probemap`, `corrmap`, `spectrum`, `spectrogram`, `coherence`). There are no plot constants (`Kinds`, `AuxModes`, `AuxPlacements`, `AuxDisplays`, `AuxColorBy`, `OverlayPanels`, `SessionKinds`, `SessionMatches`, `SessionData`): the plots are gone |
| `toStruct()`, `toJson()`, `save(file)` | plain struct; the JSON `save` writes (`Inf` / `-Inf` / `NaN` as `"Inf"` / `"-Inf"` / `"NaN"`) |
| `EphysAnalysisConfig.load(file)`, `fromStruct(s)` | version 2; a version 1 file (or struct) is [migrated](#loading-a-version-1-config) first. `load` errors `EphysAnalysisConfig:BadSchema` on another schema or any other version |
| `validate(CheckPaths=true)` | issues table `Section, Field, Severity, Message` ([rules](#validation)) |
| `addFigure(templateOrStruct, Id=)`, `duplicateFigure(idOrIndex)`, `removeFigure(id)`, `figureIndex(id)`, `figureIds()`, `enabledFigures()`, `sessionFigureIds()`, `enabledSessionFigures()`, `isSessionFigure(id)` | the figure list. `enabledFigures()` is the enabled figures a run draws per dataset and leaves out the [session figures](#session-figures) (a figure whose `sessions.enabled` is true); `sessionFigureIds()` lists those, enabled or not, `enabledSessionFigures()` the enabled ones (a run draws them across the datasets, after the datasets), and `isSessionFigure(id)` (an id or an index; false for an unknown one) tells. `[cfg, id] = cfg.addFigure("rasterPsth")` (a template's name from `figureTemplates()`, or a partial figure struct) returns the new id too: an [automatic id](#figure-ids) (*Raster+PSTH units*) when none is given; `[cfg, id] = cfg.duplicateFigure(id)` copies a figure right after it as *&lt;id&gt; (n)*; `removeFigure` of an unknown id is `EphysAnalysisConfig:NoFigure`; `figureIndex` is 0 for one |
| `figureFor(idOrIndex)` | a figure with every `"default"` resolved and each panel's type facts and each layer's category added: what the compute draws ([Resolving a figure](#resolving-a-figure)). `EphysAnalysisConfig:NoFigure` for an unknown one |
| `isequalConfig(other)` | same values (NaN equal) |
| `defaults(section)`, `normalizeSection(section, s)` | static: the single source of truth for fields, types and shapes |
| `panelTypes()`, `sourceCategories()`, `figureTemplates()`, `categoryOf(source, type)`, `observeKind(fig)`, `followedData(fig)`, `autoFigureId(fig)`, `defaultLayer(type)`, `normalizeFigure(f)`, `normalizePanel(p)`, `normalizeLayer(L)` | static: the figures' tables and helpers ([Figures](#figures)). `placePanel`, `removePanel`, `movePanel` and `figureCells` are the [grid editing](#editing-the-grid) |

Values are coerced to the class and shape of their default on every
assignment: a one-element list read back from JSON is a list again, `"Inf"`
is `Inf`, `[]` is an empty list or number. String fields named in
`ListFields` (`response`, `pairingFlags`, `groupBy`, `classes`, `groups`,
`Formats`, `Datasets`, `Folders`, `datasetKeys`) stay lists even with one element. Missing
fields take their defaults. Unknown fields are dropped: `load` lists them in
`LoadWarnings` and reports them with the warning
`EphysAnalysisConfig:LoadWarnings`. Text where a number belongs is
`EphysAnalysisConfig:BadValue`.

Figure ids must be unique (`EphysAnalysisConfig:DuplicateFigureId`). A
figure's id is [automatic](#figure-ids) while its `autoId` is true (a new
figure's, until an id of its own is given): *Raster+PSTH units*, following its
panels and data, *(2)* added when another figure has it. A figure with `autoId`
false and no id gets `"figure_<n>"`. `validate` also requires them to stay
distinct as file names: `{Plot}` replaces every character outside
`A-Z a-z 0-9 _ - .` by `_`, and Windows ignores case, so `"unit card"` or
`"Unit_Card"` next to `"unit_card"` is an error.

## JSON example

```json
{
  "schema": "ephys-analysis-config", "version": 2,
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
  "Figures": [
    { "id": "unit_card", "autoId": false, "enabled": true, "title": "",
      "observe": { "data": "units", "units": { "classes": ["su"], "...": "..." }, "...": "..." },
      "grid": { "rows": 3, "cols": 1, "rowHeights": [1.5, 1, 1], "colWidths": [], "spacing": "none", "...": "..." },
      "ref": "default", "window": "default", "selection": "default",
      "sessions": { "enabled": false, "...": "..." },
      "panels": [ { "id": "raster_1", "type": "raster", "row": 1, "col": 1, "...": "..." },
                  { "id": "psth_1", "type": "psth", "row": 2, "col": 1, "...": "..." },
                  { "id": "continuous_1", "type": "continuous", "row": 3, "col": 1, "...": "..." } ],
      "style": { "...": "..." }, "aesthetics": [] } ],
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
`Export` and `Report`, and `Figures`. `save` writes every field of every
section and figure, pretty-printed (the `"..."` above stand for the rest); a
file written by hand may leave fields out, and they take their defaults
when it is loaded. Two things the JSON encoder does that a hand-written
file need not copy:

- A one-element list is written as a scalar (`"pairingFlags": "ok"`,
  `"groupBy": "Depth"`), and a config with a single figure writes `Figures` as
  one object instead of an array of one (a figure's `panels`, a panel's
  `layers`, and a session figure's `datasetKeys` the same). All read back
  correctly.
- A figure's `ref`, `window` and `selection` (a panel's `ref`
  and `window` too) are either the string
  `"default"` or an object of their own, whose missing fields take the
  [building blocks](#building-blocks)' defaults (not the config's
  `Defaults`). An empty value also means `"default"`.

A version 2 file holds no `Plots` or `SessionPlots`: if one does, they are
unknown top-level fields and `load` warns and drops them (a file that still
has plots is version 1: [below](#loading-a-version-1-config)).

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

They are used by every figure whose `ref`, `window` or `selection` is the
string `"default"`. The app's [Alignment tab](EphysAnalysisApp.md#alignment-tab)
edits them.

## Building blocks

`EphysAnalysisConfig.defaults("EventRef" | "EpochWindow" | "TrialSelection" |
"UnitSelection" | "Style" | "Auroc" | "Waveform" | "EventMark" | "Note" | "Overlay")`. The first three are described with their
constructors (`eventRef`, `epochWindow`, `trialSelection`, which build and
check one in a script) on the [Analysis page](EphysAnalysis.md#event-reference-window-selection);
what they mean in a config follows. The sections after [Style](#style) describe
the settings that figures and their panels share: stacked PSTHs, the auROC
baseline, a raster's sort and event marks, unit waveforms, aux signals, error
bands, and a panel's notes and overlays.

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
(a rate or tuning panel's window, say); fields and rules:
[`epochWindow`](EphysAnalysis.md#epochwindow-the-span-of-each-epoch). A
`stop` in a fixed window still sets `t1`, so PSTHs and rasters mark it and
`maskAfterStop` can drop what follows it. Only a rate, tuning or unit
correlation panel takes a `"between"` window ([panel types](#panel-types)). A `stop` is an
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
trials makes the runner skip the figure on that dataset (*no paired trials*).

### UnitSelection

A figure's `observe.units` and a fixed layer's `units` (the source is the figure's `observe.data`, `units` or
`detected`, or the layer's `source`). Sorted units
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
| `response` | `enabled` false, `test` `"evoked"`, `baseline` `[-0.2 0]`, `window` `[0 0.2]`, `param` `""`, `direction` `"any"`, `correction` `"bh"`, `alpha` 0.05, `auroc` (below) | with `enabled`, only the units that pass the test are kept ([response statistics](EphysAnalysis.md#response-statistics)), after the other fields and before `maxUnits`. The test runs over the figure's event reference and trial selection, on epochs of one fixed window that holds both test windows (those that leave the recording or touch an artifact period are left out). `test`: `"evoked"` (the response window's rate differs from the baseline window's, `signrank`), `"tuning"` (it differs across `param`'s levels, `kruskalwallis`), `"either"`, `"both"`, or `"auroc"`: the units the auROC calls modulated over `window` (`aurocCurves` over the same epochs, all of them one group; [auROC](#auroc)), with `auroc`'s `method`, `windows`, `windowSec`, `stepSec`, `binSec` (its own bins, 0.01), `cutoff` (`"ci"`, `"fixed"` or `"test"`; not `"none"`), `threshold`, `test` and `nResamples`. `baseline` and `window` are s from the event. `param` is needed by `"tuning"`, `"either"` and `"both"`. `direction` (every test but `"tuning"`) is `"any"`, `"excited"` or `"suppressed"` (auroc: called up or down). `correction` is `"bh"`, `"holm"`, `"bonferroni"` or `"none"`, over the units tested. A unit passes when its adjusted p is at most `alpha` (auroc: when called modulated; `correction` and `alpha` serve its `"test"` cutoff). The unit table gains the test's columns: `baselineRate`, `responseRate`, `pEvoked`, `qEvoked`, `direction`, `responsive` and, with `param`, `nLevels`, `pTuning`, `qTuning`, `tuned`, `bestLevel`, `bestRate`; for `"auroc"` instead `aurocMean`, `aurocPhasic`, `aurocP`, `aurocQ`, `aurocDirection` and `aurocModulated`. Needs the Statistics and Machine Learning Toolbox |

### Style

| Field | Default | Meaning |
| --- | --- | --- |
| `LineWidth` | 1.2 | traces, PSTH lines and bar outlines |
| `ShowSEM` | `true` | the error of the means: bands behind traces (PSTH and continuous panels, population curves), error bars on means (rate bars, tuning curves); which error is `ErrorType` ([Error bands](#error-bands)) |
| `ErrorType` | `"sem"` | `"sem"`: mean +/- SEM; `"std"`: mean +/- SD of the values; `"ci95"`: the 95% confidence interval of the mean from bootstrap resamples (`bootci`, percentile; Statistics and Machine Learning Toolbox). Over the epochs (the group's, or the x value's), as the compute function makes it (`R.err`); across the units for an overlay of several units (PSTH, tuning) |
| `ErrorResamples` | 1000 | `"ci95"`: the bootstrap resamples. They come from a stream of their own (seed 0), so a figure gives the same band every time it runs |
| `ErrorFaceColor` | `""` | bands: `""` = the trace's color; or one color (a name or `#rrggbb`) for every band, drawn as given |
| `ErrorFaceAlpha` | `NaN` | bands: `NaN` = opaque, the trace's color paled 75% towards the ground (vector exports stay vector); 0-1 = the fill at that opacity, unpaled, so what is under it shows through. |
| `ErrorEdgeColor` | `"none"` | bands: their outline: `"none"`, `"auto"` (the fill's color) or a color |
| `ErrorEdgeStyle`, `ErrorEdgeWidth` | `"-"`, 0.5 | bands: the outline's line style (`-`, `--`, `:`, `-.`) and width, points |
| `ShowStop` | `true` | stop-event marks (mean per group; a dot per raster row) |
| `ShowZeroLine` | `true` | a dotted line at the event |
| `Colormap` | `"lines"` | group colors: `"lines"` keeps selectTrials' colors; any colormap name resamples them; a color name or hex code (`"black"`, `"#1f77b4"`) gives every group that color |
| `HeatColormap` | `""` | heatmaps, probe maps and unit correlations; `""` = parula, or `blueWhiteRed` for corrmap |
| `FontSize` | 9 | |
| `SiteSize` | 8 | probe map: the sites' marker size, points |
| `YLim`, `XLim`, `CLim` | `[]` | fixed limits (`[]` = automatic); two ascending values, low then high. A figure does not use them: each panel has its own `options.yLim` / `cLim`, and the time panels show the epoch window. The automatic color limits are the range of the map, `[0 1]` for an auROC heat map and `[-1 1]` for a unit correlation |
| `Grid`, `Legend` | `true` | |
| `LegendLocation` | `"auto"` | where the legend goes: `"auto"` (east of the panels), `"inside"` (in the first panel), or `"north"`, `"south"`, `"east"`, `"west"`: outside the whole figure, on that side. A stacked PSTH has no legend |
| `LegendOrientation` | `"auto"` | `"vertical"` or `"horizontal"` entries; `"auto"` lays a legend north or south of the grid out horizontally, any other vertically |
| `LegendBox` | `false` | the legend's outline and background |
| `MaxTiles` | 16 | not used by a figure (it draws one observation per page); a version 1 plot's value is reset to the default when it is migrated |
| `TileSpacing` | `"compact"` | not used by a figure: its panels take `grid.spacing` |
| `SortDepth` | `true` | units / channels with the top of the probe first (probe `y`); applies to every panel type but the probe map (rate bars, heat map and unit correlation rows, ...) |
| `SortShank` | `false` | units / channels grouped by shank first (ascending); with `SortDepth`, top first within each shank. Neither ticked: as listed |
| `LabelDepth`, `LabelShank` | `false` | append the probe depth (`y`, µm) and / or the shank to the unit / channel labels, e.g. `su3 (sh1, 640 µm)` |
| `StackSpacing` | `NaN` | not used by a figure: a continuous panel has its own `options.stackSpacing` |

### Stacked PSTHs

With a PSTH panel's `options.stack` on, a panel with more than one trial group draws
each group in its own row, the first group at the bottom (use the selection's
`groupOrder` to turn it over), instead of overlaying them. The row step is
`stackSpacing` times the tallest PSTH, so the panel fills its height whatever the
rate. Rows are drawn top down, so where they overlap (`stackSpacing` below 1) the lower
one is in front.

- **Left axis:** a tick at each row's baseline, labeled with the group's
  value (`0.5`, or `0.5, 1` for two `groupBy` parameters); the parameter
  names the axis.
- **Right axis:** a tick at the height where each row peaks, labeled
  with that peak in spikes/s (or the baseline mode's unit). It gives the
  scale of every row, also when `normalize` scaled the rows: a
  `groupPeak` stack still shows each PSTH's peak rate.
- A thin gray line marks each baseline; each group's mean stop event is a
  dashed mark in its own row. There is no legend (the rows are labeled),
  and the panel's `yLim` is not used.
- A second layer, or a further unit of a layer, is drawn into the same rows as an
  outline; a layer with `aggregate "mean"` draws the mean over its units.
- The groups' rasters are not part of the stack: a raster panel above the PSTH
  panel shows them.
- A panel with one group is drawn unstacked.

### auROC

`baseline.Mode "auroc"` (a PSTH panel, a heat map of spikes) draws, instead of a
rate, each unit's auROC in windows along the epoch: how far the firing
in the window stands apart from the firing in the baseline window, 0 to
1, 0.5 = no difference, above = more firing (Cohen et al. 2012;
Macedo-Lima, Hamlette & Caras 2024). `aurocCurves` computes it
([auROC on the Analysis page](EphysAnalysis.md#auroc)) from the panel's bins: `measure` `"rate"` and `"count"` give the same auROC, `"probability"`
compares spike / no spike, and `maskAfterStop` leaves out the bins from
each epoch's stop event on. Smoothing is not used and a PSTH's `normalize`
does not apply. A unit with no spike in the window and the baseline over a
group's epochs has no auROC there (NaN), so it is not called. A PSTH draws
the auROC from 0.5 on a 0-1 axis, a heatmap colors it on `[0 1]`
(the panel's `yLim` / `cLim` override them). The
`auroc` settings (`EphysAnalysisConfig.defaults("Auroc")`; a panel's
`options.auroc`):

| Field | Default | Meaning |
| --- | --- | --- |
| `method` | `"psth"` | the values compared: `"psth"`, the trial-averaged PSTH's bins in each window against those in the baseline (the paper's, as the Caras lab's `calculate_auROC.py`); `"epochs"`, each epoch's spike count in the window against the epochs' counts in window-long pieces of the baseline |
| `windows` | `"tiled"` | `"tiled"`: back to back, edged at whole multiples of `windowSec` from the event; `"sliding"`: one every `stepSec` |
| `windowSec`, `stepSec` | 0.1, 0.01 | the window and the sliding step, s: each a whole number of the panel's bins |
| `modulationWindow` | `[0 0.5]` | the call window, s from the event: the auROC windows wholly inside it give each unit's mean auROC and phasic modulation (mean \|auROC - 0.5\|) per group |
| `cutoff` | `"ci"` | how a unit is called modulated (up or down, per group): `"ci"`, the paper's: its mean auROC beyond 0.5 +/- the upper bound of the 95% confidence interval of the mean phasic modulation over every unit and group (it depends on the units in the figure and needs many of them; a warning says when it is too wide to call any; `populationAnalysis`, which takes these settings as its `Auroc`, pools every dataset's units for it: [population analysis](EphysAnalysis.md#population-analysis)); `"fixed"`, beyond 0.5 +/- `threshold`; `"test"`, the adjusted p of `test` at most `alpha`; `"none"`, no call |
| `threshold` | 0.1 | `"fixed"`: the distance from 0.5, at least 0 and below 0.5 |
| `test` | `"bootstrap"` | `"test"`: `"bootstrap"` (the epochs resampled `nResamples` times; p from how often the mean auROC lands across 0.5), `"ranksum"` (the call window's values against the baseline's; they share epochs, so p runs small) or `"shuffle"` (each epoch's bins shifted circularly at random `nResamples` times; p from how often the phasic modulation reaches the observed one) |
| `nResamples` | 1000 | bootstrap, shuffle |
| `correction`, `alpha` | `"bh"`, 0.05 | `"test"`: `pAdjust` (`"bh"`, `"holm"`, `"bonferroni"`, `"none"`) over every unit and group; modulated when the adjusted p is at most `alpha`. `populationAnalysis` uses its own `Correction` and `Alpha` instead |
| `marks` | `true` | draw the calls (with a cutoff): the PSTH shades the call window and puts each group's call (up / down arrow, n.s.) by the unit's title, in the group's color (overlay: each group's count of units called up and down); the heatmap draws a bar over the call window and a red up or blue down triangle by each modulated row. The caption counts them either way |
| `modulatedOnly` | `false` | draw only the units called modulated in at least one group (needs a cutoff); when none is, the panel fails (`spikePSTH:NoneModulated`) |

The random draws come from their own stream (seed 0), so a figure gives the same p values every time it runs.

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

A raster panel can mark, on each row, the events inside the row's epoch: every
one of them, so a trial with several beam crossings or licks gets a mark for
each. A mark is an **events layer** of the panel (`source "events"`, `eventsAs
"marks"`; the same layer draws a latency line and a rug on a PSTH, signal or heat
map panel). Its `event` (`EphysAnalysisConfig.defaults("EventMark")`) is an
[event reference](#eventref) -- its `line`, `edge`, `which`, `scope`, and a
[sequence](#event-sequences) or none -- with its own look:

| Field | Default | Meaning |
| --- | --- | --- |
| the [event reference](#eventref)'s fields | `which "all"`, `scope "recording"` | the events marked, one mark per event at its `alignStep`: `{line "Trough"}` marks every Trough onset; `{line "Trial", edge "offset", sequence [{line "Trough"}]}` the first Trough onset after each trial's end. Each is resolved over every paired trial (or the recording), not only the selected ones |
| `marker` | `"diamond"` | a line marker the aesthetics editor knows (`o`, `square`, `diamond`, `^`, `v`, `>`, `<`, `+`, `*`, `.`, `x`, `_`, `\|`, `pentagram`, `hexagram`) |
| `size` | 4 | marker size, points |
| `color` | `""` | `""`: the mark's automatic color, by its place in the list (blue, green, purple, yellow, cyan, teal; never the ticks' black or the stop dots' red); or a name or `#rrggbb`. A span's line takes it too (automatic: the next color after the marks') |
| `spanStyle` | `"-"` | `eventsAs "span"`: the onset-to-offset line's style, `-`, `--`, `:` or `-.` |
| `spanWidth` | 1.5 | ... its width, points |
| `spanAlpha` | 1 | ... its opacity, 0 to 1 |

`epochEvents` finds them ([Analysis page](EphysAnalysis.md#compute)) on
the clock of each epoch's event, so a mark sits where the spikes of that
sample sit. `eventMarkRef` gives the marks' event references (their look
left out), `rasterMarkLabels` their labels and `rasterMarkLooks` how each
is drawn. Each mark is one component for the
[aesthetics editor](EphysAnalysis.md#plot-aesthetics), role `rasterEvent`,
group its `eventRefLabel` (e.g. `"Trough onset"`, `"Trial offset then
Trough onset"`). The raster's legend lists them.

**Spans.** With `eventsAs "span"` the same layer draws, instead of a mark at each
event, a line from the event's interval's onset to its offset: the interval of
the line (a sequence's: of the step `alignStep` names) whose `edge` is the event,
moved as the event is (`offsetSec`, `offsetParam`). On a raster every row gets a
horizontal line for each interval that overlaps its epoch's window, clipped to
the window; on a PSTH, continuous signal, heat map or spectrogram panel each
trial group gets one line from the median onset to the median offset over its
epochs (each epoch's first interval starting at or after the event, else its last
one before it), near the top of the axes under the rug, one level per group, in
the group's color unless the event has a `color` of its own. The line takes the
event's `color`, `spanStyle`, `spanWidth` and `spanAlpha`, is the aesthetics role
`eventSpan` (group: the label), and the legend lists it. A line whose intervals
all end where they start (single instants) has nothing to span: the layer is
skipped with that reason. The private `epochIntervals` finds the intervals.

### Unit waveforms

A raster, PSTH or tuning panel of spikes can draw the observed unit's waveform (the
first unit of its first layer) on its peak channel as a small box in the panel (in
the rate axes of a PSTH). The `waveform` settings
(`EphysAnalysisConfig.defaults("Waveform")`; a panel's
`options.waveform`):

| Field | Default | Meaning |
| --- | --- | --- |
| `mode` | `"off"` | `"mean"`, `"subsample"` (the spikes read, thin and pale), `"both"` (the mean over the spikes), or `"off"` |
| `location` | `"northeast"` | where in the tile: `"northeast"`, `"north"`, `"northwest"`, `"west"`, `"southwest"`, `"south"`, `"southeast"`, `"east"` (north is the top edge as seen, also on a raster's reversed axis) |
| `box` | `true` | the axis box: an outline on a pale ground; `false` draws the waveform alone |
| `scale` | 1 | the box's size: 1 = a third of the panel's width and height; at most 3 |
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
`waveLabel`) take [aesthetics](EphysAnalysis.md#plot-aesthetics) like any other.

### Waveforms panels

A `waveforms` panel is the unit waveforms as a panel of their own: no events, no trials,
nothing but the units of its layers and their waveforms. It uses the `waveform` settings
above (the panel's `options.waveform`), with `mode` never `"off"` (validate refuses
it), and these more:

| Field | Default | Meaning |
| --- | --- | --- |
| `showPP`, `showCount` | `true`, `false` | the label: the mean's peak-to-peak amplitude, the unit's spike count |
| `ampScale` | `"unit"` | `"unit"`: each waveform fills its tile or glyph; `"common"`: one amplitude scale for every unit whose values are of the same kind (all µV, say), so sizes compare. Units of another kind (a template beside spikes) keep their own |
| `showSites` | `true` | probe layout: the probe's sites in gray behind the waveforms |
| `showNames` | `false` | probe layout: each unit's name beside its waveform (with the p-p amplitude and spike count when `showPP` / `showCount`) |

The panel's `options.layout`:

- `"grid"` (default): the observed unit's waveform, or the means of a fixed layer's units
  overlaid: time from the spike (ms) against amplitude, the spike's time dotted, a label
  (`showPP`, `showCount`) in the corner. `ampScale "common"` gives every unit the same
  amplitude axis.
- `"probe"`: every unit of the first enabled layer at its place on the probe (µm), each
  waveform a glyph centered on its position (`meta.x`, `y`), every site where the probe
  map puts it; a shank is moved sideways only where its glyphs would overlap the one
  beside it (a site parked on a `kcoords` group of its own stays with the shank it sits
  on); a further layer's units are framed in red. `scale` sizes the glyphs (1 =
  about a twelfth of the probe's length, at least 30 µm); with `ampScale "common"` the
  largest unit fills a glyph's height, the others are in proportion, and a scale bar
  names the amplitude it spans. A unit without a position is left out, and the panel says
  so. A dataset without a probe map skips the panel ("no probe map"). Bind the first layer
  to fixed units: validate warns when it follows the observation (it then draws the one
  unit).

The parts (`waveSpikes`, `waveMean`, `waveZero`, `waveLabel`, `waveSites`, `waveName`,
`waveScale`) take [aesthetics](EphysAnalysis.md#plot-aesthetics). A raster beside the
unit's own waveform is a raster panel with a `waveform` box; a waveforms panel is for
looking at the waveforms themselves.

### Aux signals

The headstage's auxiliary inputs (`AUX`: on Intan headstages the three axes of an
accelerometer, in volts as recorded; [DatasetOutputs](DatasetOutputs.md)) show how the
animal moved around the event, next to the spikes. A figure draws them in a
**continuous panel** whose layer has `source "AUX"`: a fixed layer (an AUX channel has no
recording channel, so it cannot follow a unit observation; `channels` picks the extract's
columns, 1 = its first input, `[]` = all). The panel's options are the continuous panel's
([Panel options](#panel-options)):

| Option | Meaning for an aux signal |
| --- | --- |
| layer `aggregate` | `"each"`: a trace per channel; `"mean"`: the mean over the channels at every sample (with `transform "rectify"`, movement either way adds up instead of cancelling) |
| `baseline` | `Mode "subtract"`: each epoch's mean over `Window` is subtracted from each channel first; `"none"`: as recorded. Without a baseline the three axes of an accelerometer include their static offsets and gravity; with `"subtract"` they are the change from each epoch's baseline. The window must overlap the panel's window (the samples cut for each epoch) |
| `display` | `"lines"`: a trace per channel (and trial group); `"stacked"`: every trace in a row of its own, on one amplitude scale |
| `statistic` | what is drawn at each sample over a group's epochs: `"mean"` or `"median"` |
| `transform` | `"none"`: the signal as recorded (after the baseline); `"rectify"`: each epoch's absolute value at every sample, before the statistic; `"magnitude"`: the layer's channels as one trace, their vector magnitude √(x² + y² + z² …) at every sample of each epoch, after the baseline and before the statistic (the mean of the magnitudes, not the magnitude of the means). For a 3-axis accelerometer, fix the AUX layer to its three channels and set `baseline` to `"subtract"`, so each axis's offset (gravity) comes out first |
| `errorType` | the band over the epochs, chosen for this panel alone (not by `Style.ShowSEM` / `Style.ErrorType`): `"off"`; `"sem"`: statistic +/- SEM; `"std"`: +/- SD; `"ci95"`: the bootstrap 95% CI (of the median for `"median"`; `Style.ErrorResamples` resamples); `"iqr"`: the 25th to 75th percentile of the epochs (`"ci95"` and `"iqr"` need the Statistics and Machine Learning Toolbox; `"sem"` and `"std"` with the median are drawn around the median, and validate warns) |
| `trials` | `"faint"` or `"only"`: each epoch's own trace as well, or alone |
| `yLim` | the signal's y limits in its units (V); `[]` = from the traces (and their bands) |

The samples are cut with `evokedPotential`, as an LFP's are: offset 0 is the AUX sample
nearest the one that produced the event, at the AUX extract's own rate (Intan: a quarter
of the amplifier rate). An epoch that leaves the AUX signal or holds a missing sample is
left out of this panel only (the raster and PSTH panels keep it). `maskAfterStop` does
not apply: each epoch's aux samples cover the whole window. A dataset without an AUX
extract skips the layer with its reason (enable AUX in the pipeline's Signals step). A
panel below a raster and a PSTH shares their time axis; set `grid.spacing` `"none"` to
draw the three flush (a figure of a unit's panels and a fixed AUX panel is the usual
one), and give it half their height with `rowHeights`.

The [spectral panels](#spectral-panels) take a fixed AUX layer too: a power
spectrum or a spectrogram of each axis, or a coherence of the observed unit (or
an LFP channel) with each axis. With the layer's `aggregate "magnitude"` the axes
are one item, the accelerometer's vector magnitude, each axis's 2 s running mean
taken out first.

The traces take the trial groups' colors (or the layer's `color`) and each channel a
line style (the layer's `lineStyle`, else by order: `-`, `--`, `:`, `-.`); the bands are
`errorType`'s (their fill, opacity and edge are the Style's `ErrorFace*` / `ErrorEdge*`).
Each trace and band is a component for the
[aesthetics](EphysAnalysis.md#plot-aesthetics) editor (roles `trace`, `channelTrace` for a
channel of a layer that draws several, and `sem`, like any continuous panel's); the
version 1 roles of the retired aux panel (`auxTrace`, `auxSem`, ...) became these when a
plot was [migrated](#looks-on-retired-roles).

### Error bands

With `Style.ShowSEM` a figure draws the error of its means, of `Style.ErrorType`:

| `ErrorType` | Band / bar | Needs |
| --- | --- | --- |
| `"sem"` (default) | mean +/- SEM (std / sqrt(n)) | |
| `"std"` | mean +/- the standard deviation of the values | |
| `"ci95"` | the 95% confidence interval of the mean: `ErrorResamples` bootstrap resamples of the values, percentile method (`bootci`); asymmetric where the values are | Statistics and Machine Learning Toolbox |

A continuous panel's band is chosen in its own `errorType` (the same three,
plus `"off"` and `"iqr"`, the interquartile range, `prctile`; it needs the
same toolbox for `"ci95"` and `"iqr"`), and follows its `statistic`:
for the median `"sem"` and `"std"` are drawn around the median (Validate
warns) and `"ci95"` is the bootstrap CI of the median.

The values are each epoch's: the compute function makes the band over the
epochs of a group (`spikePSTH`, `evokedPotential`, `firingRate`,
`tuningCurve`: `ErrorType=`, `ErrorResamples=`;
`R.err` holds its type and edges, `lo` and `hi`), and `figureErrorType` says
which a panel asks for (`"sem"` where it draws none, so no bootstrap runs for
nothing). A layer of several units drawn as their mean (`aggregate "mean"`) draws
the error of the units' means, across the units, made by the drawing function. A PSTH's baseline mode
moves and scales the band's edges as it does the mean (the baseline is not
resampled); a normalized PSTH divides them by the same peak. A value seen
fewer than twice has no band. The caption names the error and what it is
across ("bands: mean +/- SEM across epochs"; "the bootstrap 95% CI of the
mean (1000 resamples, percentile)").

Bands are patches (`errorPatch`) in the bands' look: `ErrorFaceColor`,
`ErrorFaceAlpha`, `ErrorEdgeColor`, `ErrorEdgeStyle`, `ErrorEdgeWidth`
([Style](#style)); the defaults draw them as before. Each band is a
component for the [aesthetics](EphysAnalysis.md#plot-aesthetics) editor
(role `sem`, "Error band"), so a right-click
restyles one group's bands, and a design's rules reach them. Error bars (rates, tuning) are `errorbar` objects in their own look; only
`ErrorType` concerns them. `populationSummary` takes `ErrorType=` and
`ErrorResamples=` too (across the units of each group) and `renderPopulation`
draws its bands in the style's look.

### Panel notes

Any panel can carry a block of descriptive text -- a caption, a condition,
a remark -- beside or over it. The panel's `note`
(`EphysAnalysisConfig.defaults("Note")`) draws nothing until `text` has
words; the other fields are not checked until then.

| Field | Default | Meaning |
| --- | --- | --- |
| `text` | `""` | the words; a new line starts a new line of text |
| `placement` | `"below"` | outside the panel: `"below"`, `"above"`, `"right"`, `"left"` (the panel's area gives up a band for the text); over it, in the panel's whole area: `"northwest"`, `"north"`, `"northeast"`, `"west"`, `"center"`, `"east"`, `"southwest"`, `"south"`, `"southeast"`; or `"custom"`, at `x`, `y` |
| `x`, `y` | `0.5`, `0.5` | custom: the text's anchor, 0-1 across (from the left edge) and up (from the bottom edge) the panel's area; may lie outside it |
| `align` | `"left"` | `"left"`, `"center"` or `"right"`: how the lines line up; below and above the panel, also where the text sits across it; custom, the anchor's side of the text |
| `valign` | `"middle"` | `"top"`, `"middle"` or `"bottom"`: where the text sits up the panel beside it (right and left); custom, the anchor's place on the text |
| `rotation` | `0` | degrees, counter-clockwise (`90` reads upwards) |
| `fontName` | `""` | `""` = the design's font; or an installed font's name |
| `fontSize` | `NaN` | points; `NaN` = the figure's `style.FontSize` (or the design's size for notes) |
| `bold`, `italic` | `false` | |
| `color` | `""` | `""` = the design's text color; or a name or `#rrggbb` |
| `background` | `""` | `""` = none; or a name or `#rrggbb` behind the text |
| `box` | `false` | an outline round the text, in its color |
| `interpreter` | `"none"` | `"none"`: every character as typed; `"tex"`: `\mu`, `\pm`, `x^2`, `x_i`, `\bf{...}` |

`renderFigure` draws a panel's note with the panel, as a text of role `note` in a
hidden axes (`noteHost`) in the panel's area beside its axes (`drawNote`, `placeNote`; a
placement over the panel, or a figure drawn into a single axes, carries the text in the
axes), so a note is a component of the figure the [aesthetics](EphysAnalysis.md#plot-aesthetics)
editor lists and every [design](EphysAnalysis.md#plot-designs) styles
(its font and text color). The note's own `fontName`, `fontSize`, `color`
and `background` win over the design's and the user's rules; the figure's own `aesthetics` rules win over them. Text over the panel sits on top of
what is drawn there, the title included at the top. The text is sized as
drawn, after the design's rules, so a larger font makes a wider band.

### Panel overlays

Any panel can carry graphics drawn on its axes in data units: a line across
an axis, say at the event or a threshold, or a semitransparent patch
between two values, say a response window. The panel's `overlays` is a list
of any length (`EphysAnalysisConfig.defaults("Overlay")` is one entry; the
list is empty by default), each overlay with its own place and look, drawn
in list order.

| Field | Default | Meaning |
| --- | --- | --- |
| `name` | `""` | what the app's list and the aesthetics editor call it (`""` = `"Overlay <n>"`, *n* its place in the list). Keep the names of a panel's overlays different: a look remembered for a name reaches every overlay that has it |
| `enabled` | `true` | `false`: kept in the config, not drawn |
| `shape` | `"line"` | `"line"` (across the axis) or `"region"` (a patch between `from` and `to`) |
| `axis` | `"x"` | `"x"`: a vertical line, or a patch between two x values (the full height of the axis); `"y"`: a horizontal line, or a patch between two y values (the full width) |
| `value` | `0` | line: where it crosses the axis |
| `from`, `to` | `0`, `0.1` | region: its two edges, in either order; they must differ |
| `panel` | `"all"` | always `"all"`: a panel's overlays are drawn on its own axes, so `normalizePanel` sets it whatever a file says (version 1 plots chose `"data"` or `"raster"`; the migration copies an overlay to the panels it named) |
| `layer` | `"over"` | `"over"` the panel's data (drawn after its lines, points, bars and bands), or `"under"` it (behind them, so they hide it where they are opaque) |
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

`renderFigure` draws the overlays after the panel (`drawOverlays`) as
`xline` / `yline` objects of role `overlayLine` and patch objects of role
`overlayRegion` (not `xregion` / `yregion`: MATLAB draws those behind every
opaque patch, image or bar whatever the draw order, so a patch never showed over a
raster's group bands; the patch spans the axes' limits and is refitted when they
change), each with its name as its group, so the
[aesthetics](EphysAnalysis.md#plot-aesthetics) editor lists every overlay on
its own, in every tile it is drawn in. The overlay's own looks win over the
design's and the user's rules; the figure's own `aesthetics` rules win over them. A patch does not take clicks, so a right-click on the panel reaches the
data under it (the editor still lists the patch). A [design](EphysAnalysis.md#plot-designs)
saved from a figure leaves its overlays out. A color that is not one, an
opacity outside 0-1, or a style or width that is not valid is drawn with the
default's (Validate reports it); an overlay without a finite position, or a
patch with equal edges, is not drawn.

## Figures

`Figures` is a list of *figures*: panels of different types (a raster, a PSTH, a
signal trace, a probe map, ...) arranged on a grid and drawn for **one
observation** at a time. A figure puts several kinds of data side by side for one
unit, for example a raster flush above its PSTH above the LFP of its own
channel, with the stimulus offset marked on every raster row.

A figure is designed for one *observation*: a sorted unit (or a channel's
detections), a channel of a signal (`LFP`, `MUA`, `SPIKE` or `AUX`), or the
dataset. Its `observe` block says which data (`observe.data`), and which ones
there are: the unit filter and the channel list. A panel has a type and one or
more *layers*; a layer is one data source (the units, the detections, an event
line, a signal's channels). Each layer either **follows the
observation**, reading the observed unit or the channel it sits on, or is
**fixed**, naming its own units, channels or line, so one panel can draw the
observed unit's spikes beside fixed AUX channels. The figure has one
alignment, `ref`, `window` and `selection`, each `"default"` ([`Defaults`](#defaults)) or its own. A panel may override `ref`, `window` and `selection`; a panel on the
figure's selection shares its group table, palette and legend, and one with a
selection of its own has [its own](#panel-fields). The bins, measure,
baseline (with its auROC settings), mask and waveform inset are each panel's
own [options](#panel-options); the app's **Apply to all panels** copies one
panel's to the others ([Copying options between panels](#copying-options-between-panels)).

The preview draws one observation of one dataset: it reads one unit's spikes
and one extract column, not a page of units, so an edit redraws quickly.
A run draws the same figure for every observation it selects, one page each:
`EphysAnalysisRunner.run`, `runDataset` and `plan` take `Figures=` (and `SessionFigures=`), the figure files are [exported](#export) and the figures appear in the
[report](#report), the generated scripts and the pipeline's Analysis step run
them too, and the [validation](#validation) rule that something must be enabled
counts an enabled figure. The app starts that run two ways: the Export tab's
**Run** draws the enabled figures (and session figures), and the Figures tab's
**Generate** draws the selected figure alone, enabled or not, on every ticked
dataset. The pieces are the config below, `figureObservations`,
`figureCompute` (`EphysAnalysisRunner.computeFigure` wraps it) and
`renderFigure`, which the app's [Figures tab](EphysAnalysisApp.md#figures-tab), a
run and a script all call:

```matlab
cfg = EphysAnalysisConfig();
cfg.Source.Root = "D:\EPHYS";
cfg.Defaults.EventRef.line = "Stim";
[cfg, id] = cfg.addFigure("rasterPsth");                    % "Raster+PSTH units": a unit's raster flush above its PSTH
lfp = struct('type', "continuous", 'layers', EphysAnalysisConfig.defaultLayer("continuous"));   % follows the unit
cfg.Figures(1) = EphysAnalysisConfig.placePanel(cfg.Figures(1), lfp, "below", "psth_1");
id = cfg.Figures(1).id;                                     % the automatic id followed: "Raster+PSTH+Continuous units+LFP"
spec = cfg.figureFor(id);                                   % every "default" resolved
runner = EphysAnalysisRunner(cfg);
src = runner.source(1);                                     % the first dataset, loaded once
T = figureObservations(src, spec);                          % its units in probe order, one row each
F = runner.computeFigure(src, spec, Observation=T(3, :));   % the third unit: no graphics
h = renderFigure(F, spec, figure);                          % draw it
R = runner.run(Figures=id, SessionFigures=string.empty(1, 0));   % or this figure alone, every unit of every dataset, a page each
```

A figure can also be drawn **across several datasets** instead of once per
dataset: with `sessions.enabled` it is a [session figure](#session-figures), an
observation (a site, a cell of a mapping, a channel or the dataset) computed
on every session and each panel's layers merged, a color per session or
subject.

`EphysAnalysisConfig.defaults("Figure" | "FigureSessions" | "Observe" | "Panel" | "Layer")`
give the fields below; every field exists on every entry.

### Figure, grid and observe fields

| Field | Default | Meaning |
| --- | --- | --- |
| `id` | automatic | unique among figures (`EphysAnalysisConfig:DuplicateFigureId`), file-name safe and distinct once sanitized (`{Plot}` replaces characters outside `A-Z a-z 0-9 _ - .` by `_`, and Windows ignores case: a [validation](#validating-figures) error). Names the exported files (`{Plot}`). With `autoId` the content's ([Figure ids](#figure-ids)); blank with `autoId` false: `figure_<n>` |
| `autoId` | `true` | the id follows the figure's active panel types and data ([Figure ids](#figure-ids)) whenever the figure is stored (every edit, load); `false`: the id is the user's own and stays. A new figure's is `true` until an id is given (`addFigure(..., Id=)`, a struct with an id, an id typed in the app). An entry that leaves it out (a file written by hand) takes `true` for a blank id and `false` for an id it names |
| `enabled` | `true` | unticked, it stays in the config: `figureSkipReason` says "disabled", and `computeFigure` still computes it when asked, as the preview does |
| `title` | `""` | `""` = automatic: the id, the observation's label, the aligned event and the epoch count (a dataset figure names no observation, a figure with no aligned panel no event); the dataset is the subtitle. With a title of your own, the top-left panel names the observation |
| `observe` | below | what the figure is drawn for |
| `grid` | below | the arrangement of the panels |
| `panels` | none | the [panels](#panel-fields), a list of any length |
| `ref`, `window`, `selection` | `"default"` | `"default"` = [`Defaults`](#defaults), or the figure's own [EventRef](#eventref) / [EpochWindow](#epochwindow) / [TrialSelection](#trialselection). Every aligned panel starts from them |
| `sessions` | `defaults("FigureSessions")` | the [session figure](#session-figures) settings: with `sessions.enabled` the figure is drawn once across several datasets instead of once per dataset; `sessions.enabled` false keeps the block and leaves it unused. Which datasets, how the observation is matched across them and how the sessions are colored, merged and grouped |
| `style` | [Style](#style) | the figure's look: fonts, line widths, error bands, legend, colors and probe sorting apply. `XLim`, `YLim`, `CLim`, `MaxTiles` and `TileSpacing` are not used: the time panels show the window, each panel has its own `options.yLim` / `cLim`, and the spacing is `grid.spacing` |
| `aesthetics` | none | remembered looks of the figure's components, a list of rules `{role, group, property, value}` ([Plot aesthetics](EphysAnalysis.md#plot-aesthetics)) |

`grid`:

| Field | Default | Meaning |
| --- | --- | --- |
| `rows`, `cols` | 1, 1 | the grid's size; whole numbers >= 1 |
| `rowHeights`, `colWidths` | `[]` | `[]` = equal; else one positive relative size per row / column, e.g. `[1.5 1 1]`: the rows' plot areas take exactly these shares (`[1 1.37]` is 1 : 1.37), once the room the labels take and the gaps are set aside ([layout](#renderfigure)). Every panel of a row (column) has its height (width); a panel's own `size` makes it smaller in its cell |
| `spacing` | `"tight"` | the gap between the panels: the clear space between neighboring panels' labels (tick labels, axis labels, titles). `"loose"`, `"compact"`, `"tight"` or `"none"`: every gap 24, 12, 6 or 0 px (`EphysAnalysisConfig.GridSpacings`, `GridSpacingPx`); 0 makes plot areas flush where no label sits between them, so `"none"` draws stacked time panels flush. `"custom"`: the gaps below |
| `gapUnits` | `"px"` | `spacing "custom"`: `"px"` (pixels at the size drawn; an export is drawn at its own size) or `"%"`: a row gap a share of the mean row's plot height, a column gap of the mean column's plot width, so the figure keeps its look at any size |
| `rowGap`, `colGap` | 6, 6 | `spacing "custom"`: the gap between every two rows (vertical) and every two columns (horizontal), in `gapUnits`; numbers >= 0 |
| `rowGaps`, `colGaps` | `[]` | `spacing "custom"`: `[]` = `rowGap` (`colGap`) each; else one gap >= 0 between every two rows (`rows - 1` values, the first between rows 1 and 2) or columns (`cols - 1`), to set them apart. A preset leaves these four fields stored and unused |

`observe` (what the preview's picker lists and what a run repeats the figure over):

| Field | Default | Meaning |
| --- | --- | --- |
| `data` | `"units"` | what one figure is drawn for (`ObserveData`): `"units"` (each sorted unit), `"detected"` (each channel's threshold detections), `"LFP"`, `"MUA"`, `"SPIKE"` or `"AUX"` (each channel of that extract), or `"dataset"` (one figure per dataset). `EphysAnalysisConfig.observeKind(fig)` names its kind: a *unit* for `units` and `detected`, a *channel* for a signal, the *dataset* |
| `units` | [UnitSelection](#unitselection) without `source` | `units` and `detected`: the filter that picks the units the figure can be drawn for (classes, quality, response test, ids, channels, shanks, `maxUnits`; classes and quality apply to sorted units only) |
| `channels` | `[]` | a signal: the extract's columns (`[]` = all) |
| `perGroup` | `false` | `true`: each observation is drawn once per trial group of the figure's selection (its `groupBy`), a figure of that group's epochs ([One figure per trial group](#panel-types)). Validate warns while the selection groups by nothing. A [session figure's](#session-figures) trial groups follow `sessions.trialGroups` instead, and `perGroup` is ignored there |

`addFigure` takes a template's name (`EphysAnalysisConfig.figureTemplates()`) or
a partial figure struct; without an id (`Id=` or the struct's) the figure's id is
[automatic](#figure-ids), with one it is the figure's own (`autoId` false). `"rasterPsth"` (the default) is a 2 x 1 grid of equal
rows drawn flush (`spacing "none"`): `raster_1` over `psth_1`, each with one
`units` layer that follows the observation. Each panel type has a template of
its own (`"psth"`, `"raster"`, `"continuous"`, `"eventTrace"` for [event traces](#event-traces), `"heatmap"`, `"waveforms"`,
`"probemap"`, `"corrmap"`, `"rate"` for a firing rate panel, `"tuning"` for a
tuning curve, `"spectrum"`, `"spectrogram"` and `"coherence"` for the
[spectral panels](#spectral-panels)): one panel `<type>_1` holding
`defaultLayer(type)`, a layer of the first source of the type's first
[category](#source-categories) (`units`; `LFP` for continuous; an events layer of the `Stim` line for event traces) bound as the
type's `DefaultBinding` says, so a new panel draws at once, with the type's
default options. `"blank"` is an empty 1 x 1 grid. A figure given to `addFigure` without an
`observe.data` (every template) observes what its enabled following layers
read (`EphysAnalysisConfig.followedData(fig)`): `"units"` when one reads sorted
units, else `"detected"` when one reads detections, else the signal of the
first one that reads a signal, else `"dataset"`. So the unit templates observe
sorted units, `"continuous"` and `"spectrogram"` the LFP channels, and
`"heatmap"`, `"probemap"`, `"corrmap"` and `"blank"` (fixed layers, or none) the dataset. After that `observe.data`
is the figure's own: adding or rebinding layers does not change it. The app
offers no template (its **Add** makes a blank figure and asks for its first
panel); the templates stay for scripts and tests.

### Figure ids

A figure whose `autoId` is true is named by what it holds,
`EphysAnalysisConfig.autoFigureId(fig)`: *&lt;types&gt; &lt;data&gt;*.

- *&lt;types&gt;*: the `Short` name ([panel types](#panel-types)) of each active
  panel's type, a panel with an enabled layer, in grid order (by row, then
  column), each once, joined by `+`: `Raster+PSTH`. *Blank* when no panel is
  active.
- *&lt;data&gt;*: `observe.data` (unless `"dataset"`), then each source the
  active panels' enabled layers read, in that order, each once, joined by
  `+`: `units+LFP`. An events layer counts only where it is the data (an
  [event-trace](#event-traces) panel, or drawn as a spike train,
  `eventsAs "train"`), not as marks or spans. `dataset` when there is none.

So a raster over a PSTH of the observed unit is *Raster+PSTH units*, the LFP
panel of the `continuous` template *Continuous LFP*, a raster, a PSTH and the
unit's LFP below them *Raster+PSTH+Continuous units+LFP*, a heat map of fixed
units drawn for the dataset *Heatmap units*, the coherence template
*Coherence units+LFP*, a figure with no panel observing the dataset *Blank
dataset*. The id uses only letters, digits, `+` and spaces, so it is file-name
safe; `{Plot}` writes it with `_` for each `+` and space (*Raster_PSTH_units*).

The id is given whenever `Figures` is assigned (`normalizeFigures`: every
config method, `cfg.Figures(k).panels(2).type = "heatmap"` in a script, `load`),
so it follows every change of the panels, their layers' sources and enabled,
and `observe.data`. Ids are unique: an automatic id another figure already
names (compared as `{Plot}` writes them, case-blind) takes the next free
*(n)*, from 2: *PSTH units (2)*, *PSTH units (3)*
(`EphysAnalysisConfig.nextFreeId`). A figure keeps the id it has while that is
still its automatic id or *&lt;it&gt; (n)* and no figure before it (or with an id of
its own) has it, so an edit renames only the figure edited: after the first
*PSTH units* becomes a raster, the second keeps *PSTH units (2)*.

`autoId` false keeps the id whatever the figure holds; setting it true again
gives the automatic id back. In a script, set `autoId` false before (or with)
an id of your own: while `autoId` is true, an assigned id is replaced by the
automatic one.

`cfg.duplicateFigure(id)` copies a figure right after it as *&lt;base&gt; (n)*,
the smallest free n from 2: the base is its automatic id when `autoId` is true
(the copy stays automatic), else its own id without a *(n)* it ends in
(*unit_card (2)* copies as *unit_card (3)*; the copy's id is its own too).

Nothing in a config refers to a figure by its id, so an automatic rename breaks
no reference: a run (`run(Figures=)`, the Export tab, the pipeline's Analysis
step) reads the ids when it runs, and a session figure's settings are its own
`sessions` block. The app follows a rename in what it keeps by id while it is
open ([the id](EphysAnalysisApp.md#figures-tab)). The figure's file names
follow its id.

### Panel fields

| Field | Default | Meaning |
| --- | --- | --- |
| `id` | auto | unique within the figure (`EphysAnalysisConfig:DuplicatePanelId`); blank: `<type>_<n>`. The aesthetics editor names a panel's tile by it |
| `type` | `"psth"` | one of the [panel types](#panel-types) |
| `title` | `""` | `""` = none, but for the observation's label on the top-left panel under a title of the figure's own |
| `box` | `"auto"` | the frame around the panel's axes (and a coherence panel's phase axes): `"auto"` leaves it to the [design](EphysAnalysis.md#plot-designs) (Tufte and Journal turn it off) and to the looks remembered for the panel's kind; `"on"` or `"off"` is the panel's own and wins over all of them, the figure's own `aesthetics` rules included (a right-click edit of a panel's *Box* does not show while `box` is not `"auto"`: set the panel's Box row instead). Validate: `auto`, `on` or `off` |
| `row`, `col` | 1, 1 | the top-left cell |
| `rowSpan`, `colSpan` | 1, 1 | the rows and columns it covers |
| `size` | `[1 1]` | `[width height]`: its share of its cell's plot area, each over 0 and at most 1, so one panel can be narrower or shorter than the others of its column or row (`[0.5 1]`: half as wide) |
| `align`, `valign` | `"center"`, `"middle"` | where a panel smaller than its cell sits in it: `"left"`, `"center"` or `"right"`; `"top"`, `"middle"` or `"bottom"`. A panel smaller than its cell keeps its own time tick labels ([shared time axis](#shared-time-axis)) |
| `ref`, `window` | `"default"` | `"default"` = the figure's, or the panel's own [EventRef](#eventref) / [EpochWindow](#epochwindow) (aligned types only). A panel with its own cuts its own epochs, with the figure's selection or its own (next row); with the figure's, its groups must match the figure's by label, or the panel is skipped. It then no longer [shares the time axis](#shared-time-axis) |
| `selection` | `"default"` | `"default"` = the figure's, or the panel's own [TrialSelection](#trialselection) (aligned types only): its own epochs and groups, [colored apart with a legend inside the panel](#panel-types). Its groups are not matched to the figure's, and a per-group figure does not cut them. A panel with only its own `selection` still shares the time axis, which depends on `ref` and `window` alone |
| `layers` | none | the [layers](#layer-fields), a list of any length |
| `options` | the type's [options](#panel-options) | all of the options the panel draws, coerced to the type's, so changing `type` re-seeds them: fields the new type has keep their values, the others are dropped |
| `note` | `defaults("Note")` | descriptive text on or beside the panel: a [note](#panel-notes) (nothing is drawn until `text` has words), after `options`. `placement` `"below"`, `"above"`, `"right"` or `"left"` gives up a band of the panel's own area beside its axes; a compass point, `"center"` or `"custom"` (at `x`, `y`, 0-1 across and up the panel's axes) puts the text in the axes |
| `overlays` | none | a list of [overlays](#panel-overlays), lines and semitransparent patches drawn on the panel's own axes in data units, the last field of a panel. A panel's overlays are all drawn on its axes, so `panel` is always `"all"`: `normalizePanel` sets it, whatever a file says, and Validate gives no panel warning. Units are the panel's axis' own (seconds from the event on a time panel, a rate on a PSTH's y axis, an epoch number on a raster's rows) |

### Layer fields

| Field | Default | Meaning |
| --- | --- | --- |
| `name` | `""` | the legend and aesthetics label; `""` = automatic: the unit's label, `LFP ch 3`, the event's label |
| `enabled` | `true` | unticked, the layer stays in the config and is not drawn |
| `source` | `"units"` | one of `FigureSources`: `"units"`, `"detected"`, `"events"` (a digital or derived line's events), `"LFP"`, `"MUA"`, `"SPIKE"` or `"AUX"`; the panel type decides which a panel takes ([source categories](#source-categories)) |
| `binding` | `"observation"` | `"observation"`: follows the previewed or generated unit or channel ([what a layer reads](#what-a-layer-reads)); `"fixed"`: reads what `units`, `channels` or `event` name. Events layers are always fixed |
| `units` | [UnitSelection](#unitselection) without `source` | fixed point and unit layers: which units (it may keep several). A layer following the observation uses it only for the other spike source, on the observed channel. `source` is taken from the layer's |
| `channels` | `[]` | fixed signal layers: the extract's columns (`[]` = all) |
| `aggregate` | `"each"` | several units or channels in one layer: `"each"` (one trace or block per item) or `"mean"` (their mean, with a band across them: a PSTH overlay, the aux magnitude's mean) on a raster, PSTH, continuous, rate or tuning panel; `"each"` or `"magnitude"` (the channels as one item, their vector magnitude, each channel's 2 s running mean out first: an accelerometer's movement) for a fixed signal layer of a spectrum, spectrogram or coherence panel ([Spectral panels](#spectral-panels)); `EphysAnalysisConfig.aggregates(type, source)` lists them |
| `event` | [EventMark](#raster-event-marks) | source `events`: the line, edge, which / scope / [sequence](#event-sequences) and the mark's look (`marker`, `size`, `color`, and a span's `spanStyle`, `spanWidth`, `spanAlpha`) |
| `eventsAs` | `"marks"` | source `events`: `"marks"` (a mark on every raster row; a latency line and a rug on a PSTH, signal or heat map panel), `"train"` (the events as a spike train of their own: rows in a raster, a PSTH, a heat map row) or `"span"` (a line from each onset to its offset on every raster row; a line per trial group from the median onset to the median offset elsewhere: [Spans](#raster-event-marks)). Not used on an [event-trace panel](#event-traces) |
| `color` | `""` | `""` = the trial group's color (an event-trace panel: a palette color per line); else a name or `#rrggbb` for every trace of the layer |
| `lineStyle` | `""` | `""` = by order of the layer's items (`-`, `--`, `:`, `-.`; an event-trace panel: its `lineStyle` option); else one of those |

### Panel types

`EphysAnalysisConfig.panelTypes()` is the table of the panel types:

| Type | Label | Short | Categories | Aligned | SharesTime | OneGroup | MultiLayer | DefaultBinding |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `raster` | Raster | Raster | point | yes | yes | no | yes | `observation` |
| `psth` | PSTH | PSTH | point | yes | yes | no | yes | `observation` |
| `continuous` | Continuous signal | Continuous | continuous | yes | yes | no | yes | `observation` |
| `heatmap` | Heat map | Heatmap | point, continuous | yes | yes | yes | no | `fixed` |
| `waveforms` | Unit waveforms | Waveforms | unit | no | no | no | no | `observation` |
| `probemap` | Probe map | ProbeMap | unit | no | no | no | no | `fixed` |
| `corrmap` | Unit correlation | Correlation | unit | yes | no | yes | no | `fixed` |
| `rate` | Firing rate | Rate | point | yes | no | no | yes | `observation` |
| `tuning` | Tuning curve | Tuning | point | yes | no | no | yes | `observation` |
| `spectrum` | Power spectrum | Spectrum | point, continuous | yes | no | no | yes | `observation` |
| `spectrogram` | Spectrogram | Spectrogram | continuous, point | yes | yes | yes | no | `observation` |
| `coherence` | Coherence | Coherence | point, continuous | yes | no | no | yes | `observation` |
| `eventTrace` | Event traces | EventTraces | point (events layers only) | yes | yes | no | yes | `fixed` |

- `Short`: one word, the type's part of an [automatic figure id](#figure-ids).
- `Categories`: the [source categories](#source-categories) its layers draw.
- `Aligned`: cut into epochs around events, so the panel's `ref` and `window`
  apply. An unaligned panel (waveforms, probe map) must keep both `"default"`.
- `SharesTime`: its x axis is time from the event; it takes the figure's time
  axis ([below](#shared-time-axis)) and the events layers. A coherence panel
  does not share it in the table, but `figureFor` sets `sharesTime` for one
  drawn over time (`options.overTime`) on the aligned base while its `ref` and
  `window` are the figure's.
- `OneGroup`: draws one trial group, `options.group` (a 1-based number); a heat
  map of trials (`rows "trials"`) draws every group and ignores it. A coherogram
  (a coherence panel's `overTime`) has a `group` too, though the type is not
  marked.
- `MultiLayer`: draws every enabled layer. Any other type draws the first
  enabled one (validate warns of more).
- `DefaultBinding`: what a new layer of the type binds to.

What each draws:

- `raster`: a row per epoch, by trial group on pale bands, for the first point
  layer's first unit. Every further unit or layer goes in a block under it
  with a small gap, each group a band of its own, and the y axis names the
  blocks. Events layers drawn as marks put a mark on every row of every block,
  drawn as a span a line from each onset to its offset on every row; drawn as a
  train they are blocks of rows of their own.
- `psth`: the peri-event rate per trial group: a band and a trace for every
  layer and unit, each unit in a line style of its own (`-`, `--`, `:`, `-.`,
  or the layer's `lineStyle`); with several only the first is filled.
  `aggregate "mean"` draws the mean over a layer's units with a band across
  them. Events layers drawn as marks become a latency line per trial group
  (the median over its epochs) and a rug along the top edge; drawn as a span, a
  line per trial group from the median onset to the median offset near the top;
  drawn as a train, a PSTH of their own. With `options.stack` (and two or more trial groups) the
  groups are not overlaid but stacked: one row per group, the first on
  top, each row `stackSpacing` times the tallest PSTH high, the groups'
  values on the left axis and their peaks on the right, as in [Stacked PSTHs](#stacked-psths). A second layer or unit is drawn into the same rows as an outline;
  `yLim` is not used in a stack. The groups' rasters are not a stack option:
  a raster panel above the PSTH shows them. With
  baseline `Mode "auroc"` the curves are auROCs, drawn from 0.5 (a dotted
  chance line) on a 0-1 axis unless `yLim` says otherwise, the modulation
  window shaded and the first unit's call per trial group (up, down or n.s.)
  at the top right (a layer's mean: the counts of its units up and down),
  (see [auROC](#auroc)); `normalize` does not apply to it, and it can be
  stacked too. With `options.display "heatmap"` the first item (the observed
  unit, or a layer's mean) is drawn as an image instead: a row per trial
  group, the first on top, labeled with the groups' values (the y label
  names the group-by parameters), x the PSTH's bins, each bin colored by its
  rate after `measure`, smoothing, `baseline` and `normalize`. The color
  scale spans that item's rows only, never other units' (`cLim` fixes it; an
  auROC is on 0 to 1 with the modulation window as a bar over the image), in
  `colormap` (`""`: `Style.HeatColormap`, else the design's heat colormap),
  and a color bar in the measure's unit is its legend, inside the axes when
  another time panel shares the column (so the time axes line up). The zero
  line, the stop latencies, events marks and the waveform inset are drawn
  over it; `histStyle`, `fill`, `fillAlpha`, `stack`, `stackSpacing` and
  `yLim` are not used, a merged result's member sessions are not drawn, and
  further items are noted at the bottom left.
- `continuous`: the epochs' mean of each channel (LFP, MUA, SPIKE or AUX), per
  trial group, with an error band; `options.display` `lines` or `stacked` (a
  row per channel). With `options.trials` `"faint"` every epoch's trace is
  drawn too, in the group's color, paler and thinner than the mean, behind it
  and its band; with `"only"` the traces alone, without the mean or its band
  (they stand for the groups in the legend). The traces always sit under every
  band and mean, whatever the layers' order. At most `options.maxTrials`
  epochs are drawn (100 by default), picked evenly over their order (the mean
  is still over every epoch); with `aggregate "mean"` a trace is the epoch's mean over the
  layer's channels. The result `R.data` is `[nTime x nChannels x nTrials]`
  (single) with `R.trialEpochs` and `R.trialGroup`, and the traces are the
  aesthetics role `trialTrace` ("Trial traces").
- `heatmap`: units or channels (rows) by time in color, for the trial group
  `options.group`. The map is the first enabled layer that is not events marks;
  events marks become latency lines over it. With baseline `Mode "auroc"` it
  maps auROCs on a 0-1 scale in the diverging colormap, with the calls marked
  (a bar over the call window and a triangle by each modulated row, while
  `auroc.marks`); `order "modulation"` puts the rows in order of their mean
  auROC in the call window in the group drawn, highest first. With
  `options.rows "trials"` it draws one unit's epochs instead, every group: a
  row per epoch, binned as the PSTH counts them (with the panel's `bins`,
  `measure`, `maskAfterStop` and smoothing; `baseline` `subtract`, `zscore` or
  `percent` taken against the epoch's group, so a group's rows average to its
  PSTH, also under `maskAfterStop`, where a row's bins from its stop event on
  are `NaN` as the PSTH masks them; the auROC baseline is an error), sorted as a raster sorts its rows
  (`rasterSort`, `rasterSortEvent`, `rasterSortOrder`, `rasterByGroup`), a
  strip of the group's color along the left edge of the axes and the y label
  naming the sort (`Epoch (by Depth), descending`). `order` and `group` are not
  used. The layer is a spike layer (`units`, `detected` or an events train)
  that follows the observation (the only heat map layer that can) or is fixed
  to one unit (one id, or `maxUnits` 1); a signal layer is an error. The map is
  one unit's: a layer that keeps several units (one that follows the
  observation through a channel, or a layer of the other spike source, which
  reads every unit on the observed channel) is a validate error, and a layer
  that still keeps several on a dataset is skipped (`A heat map of trials draws
  one unit: this layer keeps 2`).
- `waveforms`: the observed unit's mean waveform and a sample of its spikes
  ([Unit waveforms](#unit-waveforms)); a fixed layer of several units
  overlays their means. With `options.layout "probe"` it draws every unit of
  the first enabled layer as a glyph at its place on the probe, the sites
  behind, (see [Waveforms panels](#waveforms-panels)); each further enabled layer (for example one
  that follows the observation) draws no waveforms but frames its units in red
  there. Bind the first layer to fixed units: a first layer that follows the
  observation draws the one unit, and validate warns.
- `probemap`: a per-channel value on the probe sites, the units' positions as
  dots; the observed unit's site (a channel observation: the channel's) is
  ringed.
- `corrmap`: the pairwise correlation of the layer's units' per-epoch rates for
  the trial group `options.group`.
- `rate`: a firing rate panel for the observed unit: each
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
- `tuning`: a tuning curve panel for the observed unit:
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
- `spectrum`: the multitaper power spectrum (Chronux) of each layer's
  channels or spike trains over the panel's epochs, a trace and a band for
  every item and trial group, the groups overlaid ([Spectral
  panels](#spectral-panels)).
- `spectrogram`: one channel's or unit's power over time from the event and
  frequency, as an image of the trial group `options.group`, on the figure's
  time axis.
- `coherence`: the multitaper coherence of a seed layer's first item with each
  item of a partner layer (channels or spike trains), its phase in a strip
  under it; with `overTime` an image of the first pair's coherence over time.
- `eventTrace`: digital or derived lines as a logic analyzer shows them, a row
  per events layer, each interval from its onset to its offset ([Event
  traces](#event-traces)).

**Per-panel trial selection.** An aligned panel's `selection` may be its own
[TrialSelection](#trialselection) (`groupBy`, `filter`, `groupOrder`, ...)
instead of the figure's. `figureCompute` cuts the panel its own epochs and
groups (`F.panels(k).epochs` and `groups`, with `ownSelection` true); they are
not matched to the figure's groups by label, and a per-group observation does
not cut them. `renderFigure` colors the panel's groups apart from the
figure's, lists them in a legend of its own inside the panel, and titles the
panel with its grouping, `by <parameter>` or `all trials` (no `groupBy`), when
that differs from the figure's; the figure's legend keeps the groups of the
panels on its selection. The panel still shares the time axis while its `ref`
and `window` are the figure's. `figureSkipReason` checks the panel against its
own selection (`no trial parameter X`), and Validate as the figure's
(`<figure>.<panel>.selection`; an error on a type that is not aligned).
`adoptPanelAlignment` takes a panel's own selection as the figure's and, like
`relinkPanels`, sets every panel's back to `"default"`.

**One figure per trial group.** With `observe.perGroup` and a figure selection
that groups trials (`groupBy`), `figureObservations` lists every observation
once per trial group that has epochs (`group` the group's number, `groupLabel`
its label; an observation's rows together, in group order; the label ends
`" · <group>"`), and each is one page: `figureCompute` keeps only that group's
epochs for the panels on the figure's selection (one group, with `n`
recounted), so the PSTH is the unit's PSTH of that group. A panel with a
selection of its own keeps its own groups. The title gets `" · <group>"` (unless
the label has it already), `figureCaption` says `one figure per trial group`,
and `{Group}` in a file name is the group's label; a pattern that names
neither `{Group}` nor `{Index}` gets `_<Group>` appended ([Figures in an
export](#figures-in-an-export)). Without a `groupBy` the figure is drawn once
per observation, as without `perGroup`, and Validate warns.

Not in a figure: more than one layer on a heat map, probe map or correlation
panel (a waveforms panel in the probe layout takes more, to ring units). A figure
draws one observation, so several units tiled on one page are not part of it: a
figure per unit, one page each.

### Spectral panels

Three panel types draw the multitaper analyses of
[Chronux](http://chronux.org) computed by the
[Chronux analyses](EphysAnalysis.md#chronux-analyses) functions; a figure's panels read
the dataset itself, the observed unit's channel or spikes or the fixed ones the
layers name, and take the trials from the panel's own epochs. Their options are
`chronuxSettings`' (`figureChronuxSettings` builds the settings from them, with
the panel's `[pre post]` window); none of them is a [shared
option](#copying-options-between-panels). A fixed signal layer's `aggregate`
is `"each"` (an item per channel) or `"magnitude"`: its channels as one item, their
vector magnitude (*Accelerometer magnitude* below); a spike layer's is not used.

| Type | Layers | Draws |
| --- | --- | --- |
| `spectrum` | any number, point (`units`, `detected`) and continuous (`LFP`, `MUA`, `SPIKE`, `AUX`); each may follow the observation | the power spectrum of each layer's channels (`chronuxSpectrum`) or spike trains (`chronuxSpikeSpectrum`, on the `spikeFs` grid, with the mean rate as a dotted line the spectrum tends to at high frequencies): a trace and an error band per item and trial group, the groups overlaid, a layer of several items colored along the sequential colormap with the groups told apart by line style. The x axis is frequency, so it shares no time axis |
| `spectrogram` | one continuous or point layer (`LFP`, `MUA`, `SPIKE`, `AUX`, `units`, `detected`: the first enabled one that is not events marks; a further map layer is skipped, `A spectrogram draws its first enabled layer only`); it may follow the observation | `chronuxSpecgram` of the layer's first channel, or `chronuxSpikeSpecgram` of its first spike train (on the `spikeFs` grid, in spikes/s): an image over time from the event and frequency, for the trial group `options.group`, in dB or as is, or against a baseline in the diverging colormap. It shares the figure's time axis (always the aligned time base), takes events layers (latency lines and a rug) and puts its color bar inside the axes when another time panel shares the column |
| `coherence` | exactly two enabled layers, the seed then its partner | the coherence magnitude (0 to 1) of the seed's first item with each item of the partner layer, a dashed line at the level independent signals stay under, a jackknife band, and with `showPhase` the phase in a strip under it |

**Pairing in a coherence panel.** The pair is the seed layer's first channel or
unit with each item of the partner layer, labeled `<seed> x <partner>`. A
partner item that is the seed itself is dropped (an LFP layer following the
unit's channel, paired with a seed of the same channel, leaves the other
channels only), and a panel left with nothing is skipped with the reason.

| Seed | Partner | Computed by |
| --- | --- | --- |
| signal | signal | `chronuxCoherence`; two signals at different rates (AUX is at its own rate, e.g. an Intan headstage's amplifier rate / 4, the LFP at `LFP_Fs`) are taken at the slower one's: the faster columns are resampled (`resample`, with its anti-aliasing filter; row k stays at (k-1)/fs) |
| spikes | signal | `chronuxSpikeField`, one call per partner column, the spikes cut to the field's very samples |
| signal | spikes | `chronuxSpikeField`, each partner unit with the seed's column |
| spikes | spikes | `chronuxUnitCoherence` |

**Accelerometer magnitude.** A fixed signal layer with `aggregate "magnitude"`
is one item, the vector magnitude of its channels, so a coherence panel can pair
units (or an LFP channel) with how much the animal moves, whatever the direction.
Each channel first loses its static part, its centered running mean over 2 s
(for an accelerometer axis: the input's offset and gravity's share, so the
animal's posture drops out; the dynamic body acceleration of VeDBA), then
`sqrt(x² + y² + z² ...)` is taken at every sample of the whole recording, before
the trials are cut and detrended. The item is named `magnitude of 3 AUX
channels`, a pair `u12 x magnitude of 3 AUX channels`. A magnitude is never
negative, so a movement at one frequency along an axis shows at twice it:
for the axes' own rhythm, pair with the axes (`aggregate "each"`). The same
layer draws one power spectrum or one spectrogram on those panels. For
example, the observed unit with a 3-axis accelerometer's magnitude:

```json
{ "id": "move", "type": "coherence", "layers": [
    { "source": "units", "binding": "observation" },
    { "source": "AUX", "binding": "fixed", "channels": [1, 2, 3], "aggregate": "magnitude" } ] }
```

The coherence spectra are the seed layer's result (`R.C`, `R.phi`, the
jackknife bars `R.Clo` and `R.Chi`, `R.confC`, `R.pairs`); the partner layer's
result is a marker. With `showPhase` the panel's plot area holds two axes, the
magnitude over its top two thirds and the phase (the angle where
the coherence is over its level, every frequency without one; -pi to pi) flush
under it on the one frequency axis; both axes are tagged with the panel's id.
`renderFigure` returns the phase axes as `h.panels(k).extraAxes` (the magnitude's
are `axes`). Drawn into a single axes target there is no phase strip.
With `overTime` the panel is a **coherogram**: an image of the first pair's
coherence over the moving window for the trial group `options.group`, 0 to 1
(`cLim`), of any pairing above: signal x signal (`cohgramc`), spikes x signal
or signal x spikes (`chronuxSpikeField` with `overTime`: `cohgramcpt`, the
spikes on the field's samples) or spikes x spikes (`chronuxUnitCoherence`
with `overTime`: `coherencypt` window by window on the `spikeFs` grid). On
the aligned base it shares the figure's time axis (`figureFor` sets
`sharesTime`), on the range base its x is the recording's time (each stretch
clear of artifact periods is one trial, its windows on one time grid, blank
in between).

**The range time base.** `timeBase "range"` (a spectrum or a coherence panel;
a spectrogram is always aligned) cuts the recording between `range(1)` and
`range(2)` (`Inf` = the end), on the continuous clock, into back-to-back
segments of `segmentSec` (a coherogram: its moving window) that are clear of
the dataset's artifact periods; the segments are the trials, in one group. The figure's event, window and
selection are not used: the panel computes no epochs, `figureSkipReason` asks
for no line, trial or parameter, and its window may even be a `"between"` one.

**Chronux must be on the path.** The bundled copy is `toolboxes/chronux`
(`addpath(genpath(...))`, as the [README](README.md#dependencies) says; its
`findpeaks` and `jackknife` shadow MATLAB's, as the README notes). Without it `figureSkipReason` gives the panel the
reason `Chronux is not on the path` and the rest of the figure still draws.
Other reasons a spectral panel is skipped are the layer's own (`no LFP
extract`, `no sorted units`), a moving window longer than the epoch, a result
over the 2000 MB limit (a constant: a spectrogram or coherogram of many long
epochs), no trial left on the range base, and settings `chronuxSettings`
refuses.

| Type | Option | Default | Meaning |
| --- | --- | --- | --- |
| `spectrum`, `coherence` | `timeBase` | `"aligned"` | `"aligned"` (the panel's epochs: trial e covers the panel's window around its event, one result per trial group) or `"range"` (segments of the recording, above) |
| `spectrum`, `coherence` | `range` | `[0 Inf]` | `timeBase "range"`: `[from to]` s on the continuous clock |
| `spectrum`, `coherence` | `segmentSec` | 2 | `timeBase "range"`: the length of each segment (a trial), s; positive |
| all three | `taperMode` | `"TWK"` | `"TWK"` (`TW` and `K` as given) or `"Wp"` (the half bandwidth `W` Hz and `p`, over the trial: `TW = W T`, `K = 2 TW - p`) |
| all three | `TW`, `K` | 3, 5 | `taperMode "TWK"`: the time-bandwidth product and the number of tapers (`K <= 2 TW - 1`) |
| all three | `W`, `p` | 4, 1 | `taperMode "Wp"` |
| all three | `pad` | 0 | the FFT padding (-1, 0, 1, ...) |
| all three | `fpass` | `[0 100]` | `[fmin fmax]` Hz (`fmax` `Inf` = Nyquist) |
| `spectrum`, `coherence` | `err` | `"jackknife"` | the error bars: `"none"`, `"theoretical"` or `"jackknife"` (a coherence: the jackknife gives the band and the level independent signals stay under, `"theoretical"` the level alone) |
| `spectrum`, `coherence` | `errP` | 0.05 | the error bars' p (0.05: 95%) |
| all three | `detrend` | `"constant"` | each trial's trend removed: `"none"`, `"constant"` or `"linear"` |
| `spectrum`, `spectrogram` | `scale` | `"db"` | `"db"` (10 log10), `"log"` (a log y axis; a spectrogram: dB too) or `"linear"` (as is; a spectrogram baseline then in its own units) |
| all three | `spikeFs` | 1000 | spike layers: the time grid the spike trains are analyzed on, Hz |
| `coherence` | `overTime` | `false` | a coherogram of the first pair (signals or spike trains) |
| `spectrogram`, `coherence` | `movingwin` | `[0.5 0.05]` | `[window step]` s (a coherence only with `overTime`) |
| `spectrogram` | `baseline` | `Mode "none"`, `Window [-0.5 0]` | `Mode` `"none"`, `"db"`, `"percent"`, `"zscore"` or `"ratio"` (`chronuxNormalize`'s) against the power in `Window`, which must lie inside the panel's window |
| `coherence` | `showPhase` | `true` | the phase strip under the magnitude (not over time) |
| `spectrum`, `coherence` | `yLim` | `[]` | the power or coherence axis; a coherence `[]` = `[0 1]` |
| `spectrogram`, `coherence` | `cLim` | `[]` | the color scale; a coherogram `[]` = `[0 1]` |
| `spectrogram`, `coherence` | `group` | 1 | the trial group drawn (a coherence: with `overTime`) |

`cfg.validate()` checks the options with `chronuxSettings`' own rules and
reports its message at `<figure>.<panel>.options` (the tapers, `fpass`, `err`
and `errP`, `detrend`, `scale`, `spikeFs`, the moving window, the range and
segment, a spectrogram's baseline `Mode` and its `Window` inside the panel's
window, which must therefore be a fixed one unless the panel is on the range
base), `yLim` and `cLim` `[]` or ascending, and `group` a whole number. Layers
are errors at `<figure>.<panel>.layers`: a coherence panel without exactly two
enabled layers, a spectrogram without a signal or spike layer (events marks
only). A coherence panel
whose fixed seed layer keeps several channels or units warns (only the first
is the seed). The templates `"spectrum"`, `"spectrogram"` and `"coherence"`
give a panel with the type's default layer; the coherence one holds two, the
observed unit and the LFP of its channel (a spike-field coherence).

The generated standalone script runs a figure through `figureCompute`
and `renderFigure` like any other, so a spectral panel needs Chronux on the
path of the MATLAB that runs it.

### Event traces

An `eventTrace` panel ("Event traces") draws digital or derived lines as a logic
analyzer shows them, on the figure's [time axis](#shared-time-axis), so it
stacks flush above a raster or a PSTH. Each enabled **events layer** is one line
and one row of its own, the first layer on top; the y axis names the rows (the
layer's `name`, else its line). A layer of another source is a validate error
and is skipped (`An event-trace panel draws events layers only`); the layer's
`eventsAs` is not used. The layer's `event` picks the intervals as a span does
([Spans](#raster-event-marks)): with the EventMark defaults (`which "all"`,
`scope "recording"`) every interval of the line; `which`, the durations and a
sequence narrow them. Each interval runs from its onset to its offset and
belongs to every epoch whose window it overlaps; one that starts before or ends
after the window is drawn to its edge (a `"between"` epoch: to its own end). A
line whose intervals are all single instants is skipped with the reason; a
single instant (onset = offset) among longer intervals is kept, drawn at the
`minWidth` below. A line with no interval in the epochs is an empty row. The
result, per layer, is `R.kind "eventTrace"` with `line`, `label`, `epoch`,
`on`, `off` (s from each epoch's event, not clipped), `window` (each epoch's),
`nEpochs`, and what sorts the sub-rows: `epochGroup`, `epochStop`, `groups`,
`epochs` and, sorted by an event, `rasterSortEvent`.

| Option | Default | Meaning |
| --- | --- | --- |
| `display` | `"bars"` | `"bars"`: a solid bar from each onset to its offset; `"line"`: a logic-level trace, low, rising at each onset and falling at its offset |
| `trials` | `"overlay"` | `"overlay"`: every epoch drawn in the line's row, translucent, so the spread of the timing shows; `"rows"`: a sub-row per epoch inside the line's row, sorted as a raster's rows (the four options below; by default by trial group and then time), the first on top |
| `rasterSort` | `""` | `"rows"`: the epochs' order, as a [raster's](#panel-options) and a heat map of trials': `""` (trial order), `"stop"` (the stop event's latency), `"event"` (`rasterSortEvent`'s latency) or a trial parameter; missing values last |
| `rasterSortEvent` | `[]` | `"rows"`, `rasterSort "event"`: an EventRef (Validate requires one) |
| `rasterSortOrder` | `"ascending"` | `"rows"`: `"ascending"` or `"descending"` |
| `rasterByGroup` | `true` | `"rows"`: by trial group first (each group's sub-rows together, on its band with `groupBands`); `false`: every epoch sorted as one block (a band per run of a group's sub-rows) |
| `colorBy` | `"layer"` | `"layer"`: each line in its layer's `color`, else a color of the plot design's palette (`groupPalette`); `"group"`: each epoch in its trial group's color, the groups in the figure's legend |
| `height` | 0.6 | the bars' (or the level's) height, a share of the row (with `"rows"`: of the epoch's sub-row); above 0, at most 1 |
| `alpha` | `NaN` | the bars' and traces' opacity 0 to 1; `NaN` = 0.3 overlaid, 1 in rows |
| `edgeColor` | `"none"` | `"bars"`: the outline, `"none"`, `"auto"` (the bar's own color) or a color |
| `edgeWidth` | 0.5 | the outline's width, points |
| `minWidth` | 1 | `"bars"`: a bar drawn narrower than this many points (from the axes' width over the window when drawn; a zero-length interval too) also gets a vertical tick this wide through its middle, in its color and opacity, so a short interval shows at any zoom and in exported files; 0 = none |
| `lineWidth` | 1.5 | `"line"`: the trace's width, points |
| `lineStyle` | `"-"` | `"line"`: the trace's style (`-`, `--`, `:`, `-.`); a layer's own `lineStyle` wins |
| `showBaseline` | `true` | a line along each row (each sub-row in `"rows"`): through the middle of the bars, or at the trace's low level |
| `baselineColor` | `""` | `""` = gray; or a color |
| `baselineStyle` | `":"` | the baseline's style |
| `baselineWidth` | 0.5 | the baseline's width, points |
| `rowSpacing` | 1.25 | the step from one line's row to the next, in row heights (1: the rows touch) |
| `groupBands` | `true` | `"rows"`: a pale band of each trial group's color behind its sub-rows (and the groups in the legend) |

The parts are aesthetics roles of their own, so the
[aesthetics editor](EphysAnalysis.md#plot-aesthetics) and the plot designs
reach them: `eventBar` (the bars), `eventTick` (a short bar's tick),
`eventLevel` (the logic-level traces), `eventBaseline` and `eventGroupBand`;
each part's group is its line's name (colored by group: the group's label).
The logic levels and the ticks are patch edges (`FaceColor "none"`, the
opacity as `EdgeAlpha`), not lines with a four-element color, so an SVG or PDF
export keeps their opacity (`stroke-opacity`). The zero line follows
`Style.ShowZeroLine`. None of the options is shared with other panel types ([Copying options between panels](#copying-options-between-panels)).
In a [session figure](#session-figures) an event-trace panel draws every
session's epochs, as a raster does (`combineSessions` concatenates them, each
epoch in its series): `"overlay"` overlays them all, `"rows"` gives each a
sub-row, and the series (sessions, subjects or all sessions) are its groups
for `colorBy "group"`, the bands and the sort. The template `"eventTrace"` is
one panel with one events layer of the `Stim` line.

### Panel options

A panel's `options` are the type's (`panelTypes().DefaultOptions`); a field
that is not the type's is dropped on load (and listed in `LoadWarnings`). `yLim` and `cLim` are
`[]` (automatic) or an ascending `[lo hi]` and belong to the panel, because one
figure holds different axes; the figure's `Style.YLim` and `CLim` are not used.
The options named `bins`, `measure`, `baseline`, `auroc`, `maskAfterStop` and
`waveform` (an inset) are the ones several types share: **Apply to all panels** copies
them across types ([Copying options between panels](#copying-options-between-panels)).

| Type | Option | Default | Meaning |
| --- | --- | --- | --- |
| `raster` | `rasterSort` | `""` | the order of each group's epochs: `""` (trial order), `"stop"`, `"event"` or a trial parameter |
| `raster` | `rasterSortEvent` | `[]` | `rasterSort "event"` (required then): the [event reference](#eventref) whose latency orders the rows |
| `raster` | `rasterSortOrder` | `"ascending"` | or `"descending"` |
| `raster` | `rasterByGroup` | `true` | rows by group first, each group on a band; `false`: every epoch sorted as one block |
| `raster` | `maskAfterStop` | `false` | drop each epoch's ticks from its stop event on |
| `raster` | `tickColor` | `""` | the ticks' color: `""` is black; else a color name or hex code (`"red"`, `"#ff7f0e"`). A name that is not a color is a validation warning and the ticks stay black |
| `raster` | `backColor` | `""` | the rows' background: `""` is each group's pale band (the groups show); else a color name or hex code, painted on every group's band and on the axes behind them (the legend then lists no groups, as they are not told apart) |
| `raster` | `yTicks` | `false` | show the y axis' tick marks and labels (the epoch numbers); `false` hides them and keeps the y label. A raster of several blocks keeps its blocks' names on the y axis either way. A heat map of trials has no y ticks to show |
| `raster` | `waveform` | [Waveform](#unit-waveforms), `mode "off"` | the first block's unit's waveform in a box in the panel |
| `psth` | `bins` | `BinSec` 0.01, `SmoothSec` 0.01 | the bin width (bins are whole multiples of `BinSec` from the event) and the Gaussian SD applied to each epoch before averaging, s (0 = no smoothing) |
| `psth` | `measure` | `"rate"` | `"rate"`, `"count"` or `"probability"` |
| `psth` | `baseline` | `Mode "none"`, `Window [-0.2 0]` | `Mode` `"none"`, `"subtract"`, `"zscore"`, `"percent"` or `"auroc"` (`"ratio"` is for rate and tuning panels) |
| `psth` | `auroc` | `defaults("Auroc")` | baseline `Mode "auroc"`: the [auROC](#auroc) settings (`method`, `windows`, `windowSec`, `stepSec`, the call window `modulationWindow`, `cutoff`, `threshold`, `test`, `nResamples`, `correction`, `alpha`, `marks`, `modulatedOnly`). `windowSec` and `stepSec` must be whole numbers of the panel's bins (validate checks them) |
| `psth` | `display` | `"trace"` | `"trace"` (bars or a line per trial group) or `"heatmap"`: the first item (unit or a layer's mean) as an image, a row per trial group, the first on top, colored by its PSTH on that item's own range, never across units; `histStyle`, `fill`, `fillAlpha`, `stack`, `stackSpacing` and `yLim` are not used then, and further items are noted on the panel |
| `psth` | `histStyle` | `"bar"` | `"bar"` or `"line"` |
| `psth` | `fill` | `true` | fill the bars, or the area under the line |
| `psth` | `fillAlpha` | `NaN` | fill opacity 0-1; `NaN` = 0.5 where groups overlay, else 1 |
| `psth` | `normalize` | `"none"` | `"none"`, `"unitPeak"`, `"groupPeak"` or `"allPeak"` |
| `psth` | `stack` | `false` | `true`: one row per trial group, stacked downwards (the first group on top, as a raster lists them), instead of overlaid; a single group is drawn overlaid |
| `psth` | `stackSpacing` | 1.1 | `stack`: the step between rows, times the tallest PSTH (below 1 the rows overlap); positive |
| `psth` | `maskAfterStop` | `false` | drop each epoch's bins from its stop event on |
| `psth` | `yLim` | `[]` | the rate axis; not used in a stack or a heat map |
| `psth` | `colormap` | `""` | `display "heatmap"`: `""` is the style's `HeatColormap`, else the design's heat colormap (an auROC: its diverging one); or a colormap function (`"turbo"`, `"hot"`, `"blueWhiteRed"`). A name that is no function is a validation warning and takes the default |
| `psth` | `cLim` | `[]` | `display "heatmap"`: the color limits; `[]` = the drawn item's own range (an auROC: 0 to 1) |
| `psth` | `waveform` | [Waveform](#unit-waveforms), `mode "off"` | the first unit's waveform in a box in the panel |
| `continuous` | `baseline` | `Mode "none"`, `Window [-0.2 0]` | `Mode` `"none"` or `"subtract"` (each epoch's mean over `Window`, per channel). The window must overlap the panel's window |
| `continuous` | `display` | `"lines"` | `"lines"` (a trace per channel) or `"stacked"` (a row of its own per channel) |
| `continuous` | `statistic` | `"mean"` | `"mean"` or `"median"` over the epochs at each sample |
| `continuous` | `transform` | `"none"` | `"none"`, `"rectify"` (each epoch's absolute value, before the statistic) or `"magnitude"` (the layer's channels as one: their vector magnitude in each epoch, after the baseline) |
| `continuous` | `errorType` | `"sem"` | the band over the epochs: `"off"`, `"sem"`, `"std"`, `"ci95"` or `"iqr"`; `"ci95"` and `"iqr"` need the Statistics and Machine Learning Toolbox ([Aux signals](#aux-signals)) |
| `continuous` | `stackSpacing` | `NaN` | `"stacked"`: the offset between rows; `NaN` = 1.2 x the 90th percentile of the traces' ranges |
| `continuous` | `trials` | `"off"` | each epoch's trace: `"off"`, `"faint"` (paler and thinner than the mean, behind it and its band) or `"only"` (the traces alone, no mean or band) |
| `continuous` | `maxTrials` | 100 | `trials` other than `"off"`: the most epochs drawn, picked evenly over their order; a whole number >= 1 (`Inf` = every one) |
| `continuous` | `yLim` | `[]` | the amplitude axis |
| `heatmap` | `bins`, `measure`, `baseline` | as the PSTH's | a spike layer: as the PSTH, `baseline.Mode "auroc"` included; a signal layer: `baseline.Mode` `"none"` or `"subtract"` and `bins`, `measure` unused |
| `heatmap` | `auroc` | `defaults("Auroc")` | a spike layer, baseline `Mode "auroc"`: the PSTH's `auroc` settings. A signal layer with `"auroc"` is an error |
| `heatmap` | `rows` | `"items"` | `"items"`: a row per unit or channel of the layer; `"trials"`: a row per epoch of one unit, every trial group (a spike or train layer that follows the observation or is fixed to one unit; no auROC baseline). A layer that follows the observation through a channel (a channel observation, or a layer of the other spike source) keeps every unit on it, so validate refuses it; one that still keeps several is skipped at run time |
| `heatmap` | `order` | `"probe"` | rows `"items"`: `"probe"` (the style's `SortDepth` / `SortShank`), `"peak"` (by the time of each row's maximum) or `"modulation"` (by each unit's mean auROC in the call window, highest first; only with the auROC baseline of a spike layer). Not used for `"trials"` |
| `heatmap` | `rasterSort` | `""` | rows `"trials"`: the order of the epochs, as a raster's: `""` (trial order), `"stop"`, `"event"` or a trial parameter |
| `heatmap` | `rasterSortEvent` | `[]` | rows `"trials"`, `rasterSort "event"` (required then): the [event reference](#eventref) whose latency orders the rows |
| `heatmap` | `rasterSortOrder` | `"ascending"` | rows `"trials"`: or `"descending"` |
| `heatmap` | `rasterByGroup` | `true` | rows `"trials"`: epochs by group first, else one block |
| `heatmap` | `group` | 1 | rows `"items"`: the trial group drawn (clipped to the groups there are). Not used for `"trials"` |
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
| `spectrum`, `spectrogram`, `coherence` | | | the [Chronux options](#spectral-panels), above; none is a shared option |
| `eventTrace` | | | the [event-trace options](#event-traces), above; none is a shared option |

### Copying options between panels

Each panel holds all of its own options. Several types share some of them,
so a PSTH over a heat map over a unit correlation can be binned and
baselined alike: `EphysAnalysisConfig.sharedFieldsOf(type)` lists the shared
options a type has, in order:

| Type | Shared options |
| --- | --- |
| `raster` | `maskAfterStop`, `waveform` |
| `psth` | `bins`, `measure`, `baseline`, `auroc`, `maskAfterStop`, `waveform` |
| `continuous` | `baseline` |
| `heatmap` | `bins`, `measure`, `baseline`, `auroc`, `maskAfterStop` |
| `corrmap` | `bins`, `baseline` |
| `rate` | `measure`, `baseline` |
| `tuning` | `measure`, `baseline`, `waveform` |
| `waveforms`, `probemap`, `spectrum`, `spectrogram`, `coherence`, `eventTrace` | none (a waveforms panel's `waveform` is its own settings, not an inset; a spectrogram's `baseline` is `chronuxNormalize`'s) |

Three pure functions edit a figure entry as a value (the app's **Apply to all
panels** and **Re-link all panels** buttons call them):

| Call | Does |
| --- | --- |
| `[fig, changed] = EphysAnalysisConfig.adoptPanelOptions(fig, panelId)` | the panel's values of its shared options go to every other panel whose type has them, the `baseline` (with its `auroc`) only where the type takes its `Mode` (a PSTH or a heat map of spikes: `none`, `subtract`, `zscore`, `percent`, `auroc`; a rate or tuning panel: `none`, `subtract`, `ratio`, `zscore`; a continuous, unit correlation or signal heat map panel: `none`, `subtract`); its other options go to the other panels of its own type, and panels of other types keep theirs. `changed` is a struct array, one entry per other panel that changed or kept its baseline: `id`, `fields` (the options whose values changed) and `kept` (`"baseline"` when its type does not take the `Mode`) |
| `fig = EphysAnalysisConfig.adoptPanelAlignment(fig, panelId)` | the panel's own `ref`, `window` and `selection` (the ones that are structs) become the figure's, a `"default"` part leaving the figure's as it is; every panel's `ref`, `window` and `selection` are then `"default"` |
| `fig = EphysAnalysisConfig.relinkPanels(fig)` | every panel's `ref`, `window` and `selection` are `"default"`; the panels' options stay as they are |

Each raises `EphysAnalysisConfig:NoPanel` for an id the figure does not have
(`relinkPanels` takes none).

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
that shares the time axis (raster, PSTH, continuous, heat map, spectrogram,
event traces) and nothing elsewhere (so not on a firing rate, tuning, spectrum
or coherence panel). A heat map takes `point` or `continuous` layers. An
event-trace panel takes events layers only: `units`, `detected` and the
signals are `""` there.

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
| `units` or `detected`, of the observed source (`observe.data`) | that unit alone, whatever its class, with no quality or response filter (it passed `observe.units` already) | the layer's `units` on the observed channel's recording channel (`units.channels` set to it, `units.ids` ignored) |
| `units` or `detected`, of the other spike source | the layer's `units` on the unit's recording channel | as above |
| `LFP`, `MUA`, `SPIKE` | the column of the extract whose recording channel is the unit's | the observed column when the layer's signal is the observed one (`observe.data`), else the column of its own extract that records the same channel (validate warns) |
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
- A panel narrower than its column (a note band left or right of it, or a
  `size` below 1) keeps its time tick labels, and so does the panel above it.
- Events layers go only on the panels of these types, since marks need a time
  axis. A spectrogram shares it (it is always on the aligned base). A coherogram
  (a coherence panel with `overTime`) is drawn on the figure's time axis too,
  but takes no events layers: only the types with `SharesTime` in the table do.

### Editing the grid

Four static functions edit a figure entry (`fig = cfg.Figures(k)`) as a value,
with no graphics; the app's arrangement editor calls the same ones.

| Call | Does |
| --- | --- |
| `cells = EphysAnalysisConfig.figureCells(fig)` | a `rows` x `cols` matrix: 0 for an empty cell, k for a cell that panel k covers. `[cells, overlap] = ...` also lists each pair of overlapping panels once (`[first second]`, an n x 2 matrix); the parts of a panel outside the grid are left out |
| `fig = EphysAnalysisConfig.placePanel(fig, panel, where, anchorId)` | adds `panel` (a partial panel struct, normalized; a blank id becomes `<type>_<n>`) next to the panel `anchorId`. `where` `"below"`: a new row right after the anchor's last row, its `rowHeights` entry (when given) copied from that row; `"above"`: a new row before the anchor's first row, copying its height; `"right"` and `"left"`: a new column the same way, copying `colWidths`. A gap list (`rowGaps` / `colGaps`, when given) gets the gap where the new row (column) goes on both sides of it (at the grid's edge, the outermost gap again). The panels past the new row (column) move down (right) by one, those whose span crosses it grow by one, and the new panel takes the anchor's columns (rows) and one row (column). The first panel of a figure without panels goes to (1, 1), the grid unchanged, and needs no anchor. Errors: `EphysAnalysisConfig:NoPanel` (no anchor, or none by that id), `EphysAnalysisConfig:DuplicatePanelId` |
| `fig = EphysAnalysisConfig.removePanel(fig, id)` | removes the panel, then drops every row in which no remaining panel starts and every column likewise: the panels past a dropped row (column) move up (left), the spans that crossed it shrink by one, its `rowHeights` / `colWidths` entry goes, and so does a gap list's gap under it (under the last row, the one over it). Removing the last panel leaves a 1 x 1 grid without gap lists. `EphysAnalysisConfig:NoPanel` for an unknown id |
| `[fig, moved] = EphysAnalysisConfig.movePanel(fig, id, direction)` | swaps the cells (`row`, `col`) of the panel and its neighbor in `direction` (`"up"`, `"down"`, `"left"`, `"right"`) when that neighbor has the same spans and lines up with it (the same column for up and down, the same row for left and right); else `fig` is returned unchanged and `moved` is false |

**Remove undoes Add**: `removePanel(placePanel(fig, p, where, a), p.id)` gives
back `fig`, relative sizes and gap lists included. That is why a row in which no panel starts
is dropped even when it was only crossed by a span (a "wholly empty" rule would
leave a blank cell behind). The price: a blank row or column that was there
before also closes at the next Remove.

### Resolving a figure

`spec = cfg.figureFor(id)` (a figure id or an index; `EphysAnalysisConfig:NoFigure`
for an unknown one) is the entry with every `"default"` resolved, what the
compute and the render take:

- the figure's `ref`, `window` and `selection` from [`Defaults`](#defaults) where
  `"default"`;
- `observe.kind` added (`observeKind` of `observe.data`: `"unit"`, `"channel"` or
  `"dataset"`), and `observe.units.source` set to `observe.data` for `units` or
  `detected` (else `"units"`), a complete [UnitSelection](#unitselection);
- each panel's `ref`, `window` and `selection` from the figure's (resolved) where
  `"default"`, and two fields added: `aligned` (its type's `Aligned`) and `sharesTime` (its type
  shares time, and both its `ref` and `window` were `"default"`; its `selection`
  does not matter);
- each panel's `options` completed against its type's;
- each layer's `category` added (`"point"`, `"continuous"`, `"unit"`, or
  `""` where the type does not draw the source) and its `units.source` set to its
  `source`.

A panel of an unknown type keeps empty options, with `aligned` and `sharesTime`
false (validate reports the type).

### Observations and skip reasons

`T = figureObservations(src, spec)` lists what dataset `src` (`runner.source(k)`)
offers the figure `spec`, one row each: the preview's picker, and the
observations a run draws a page for. By `spec.observe.kind` (of `observe.data`):

- `"unit"`: the sorted units (`units`) or detection channels (`detected`)
  `observe.units` keeps (`selectUnits`, with the figure's
  `ref` and `selection`; only their table is used, the spike trains stay in the
  outputs' cache);
- `"channel"`: the columns `observe.channels` names (`[]` = all) of the
  `observe.data` extract (`selectChannels`);
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
| `group` | the trial group the observation is drawn for (a row of the figure's groups, from `epochTable` over its alignment); `NaN` = every group, always so unless `observe.perGroup` |
| `groupLabel` | that group's label; `""` = every group |

With `observe.perGroup` and a selection that groups trials (`groupBy`), each
observation is listed once per trial group that has epochs, an observation's
rows together in group order, the label ending `" · <group label>"`, and
`computeFigure` keeps that group's epochs only ([One figure per trial
group](#panel-types)).

`[reason, layerReasons] = figureSkipReason(src, spec)` says why the figure, or a
panel or layer of it, cannot be computed on `src` (`""` = it can), `reason` is the figure's own: `disabled`; what it
observes is missing (`no sorted units`, `no detected spikes`, `no LFP extract`);
and, when a panel with an enabled layer is aligned, what the figure's alignment
needs (`no paired trials`, `no line X`, `no trial parameter X`). With a
figure-level reason `layerReasons` is empty. Otherwise it is a 1 x n struct array
(`panel`: the panel's id, `layer`: the layer's index, 0 for the panel itself,
`reason`), one entry per panel and then one per enabled layer: a panel's own (an
unknown type, its own `ref`, `window` or `selection` (checked against its own selection), a raster, or a heat map of trials, sorted by a parameter or event the dataset lacks, a probe
map without a probe map, a tuning curve without paired trials, without a
parameter to tune over (`no numeric trial parameter to tune over`: `param` is
`""`, the selection has no `groupBy` parameter and no trial parameter is numeric
with two or more values) or whose `param` or `seriesParam` the trials lack, `no trial parameter
X`; a spectrum, spectrogram or coherence panel without Chronux on the path,
`Chronux is not on the path`, though one on the `"range"` time base needs none
of the alignment's lines, trials or parameters) and a layer's (`no sorted units`, `no <SIGNAL> extract`,
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
alignment, when any panel with an enabled layer is aligned, an observation of one
trial group (a `perGroup` row) keeping that group's epochs only (`G` one row, `n`
recounted; a group with none left is no error, see `F.skip` below); a panel with its own `ref` or `window` has its own `epochTable` with the
figure's selection (its groups matched to `G` by label, and cut to the observation's
group likewise); a panel with a `selection` of its own has its own `epochTable` and
groups, not matched to `G` and not cut to the observation's group; then each panel's
compute through `figurePanelRegistry`.

| `F` field | Holds |
| --- | --- |
| `kind`, `id`, `spec`, `dataset`, `created` | `"figure"`, the figure's id, the spec computed, the dataset's name, a time stamp |
| `observation` | the observation as a struct (`kind`, `label`, `unitId`, `channel`, `column`, `shank`, `depth`, `meta`, `group`, `groupLabel`) |
| `epochs`, `groups` | the figure's epochs `E` and trial groups `G` (one group for a per-group observation); `[]` when no panel is aligned |
| `skip` | `""`, or why a per-group observation has no epoch left (`no epoch of trial group X here`: its group lost every epoch, say to the panels' baselines); the panels on the figure's selection are skipped with it and print it, and the figure still draws, with `epochs` empty and `G` that group with `n` 0 |
| `panels(k)` | one per panel of the spec, in order: `id`, `type`, `sharesTime`, `epochs` (the panel's own epochs; `[]` = the figure's), `groups` (`[]` for an unaligned panel), `ownSelection` (`true`: its groups are its own selection's, drawn in colors of their own with a legend inside the panel), `skip` (`""` or why the panel is not computed: every layer then carries the reason) and `layers` |
| `panels(k).layers(j)` | one per layer of the panel, same order: `name` (the layer's, or automatic), `source`, `binding`, `category`, `eventsAs`, `skip` (`""` = computed; `"disabled"`; or a reason), `R` (the result; `[]` when skipped) and `meta` (the units' or channels' table) |

A skipped layer stays in `F` with its reason and `R = []`; the panel's other layers
are drawn. `R` is the result of the compute call a layer makes: a point layer's
`spikePSTH` (an events layer drawn as marks is `R.kind "events"`, its marks from
`epochEvents`; drawn as a train, a one-unit `spikePSTH` result of the line's
events), a signal layer's `evokedPotential`, a waveforms panel's `unitWaveforms`, a
probe map's `unitSummary` and `probeMapValues`, a correlation map's
`unitCorrelation`, a spectrum's `chronuxSpectrum` (spike trains:
`chronuxSpikeSpectrum`), a spectrogram's `chronuxSpecgram` (a spike train:
`chronuxSpikeSpecgram`) and a coherence's
`chronuxCoherence`, `chronuxSpikeField` or `chronuxUnitCoherence`, the last on
the seed layer (the partner layer's `R` is a marker of `kind
"coherencePartner"`); `aggregate "mean"` adds `R.layerMean`; a continuous panel's
`trials` adds the epochs' traces (`R.data`, `R.trialEpochs`, `R.trialGroup`), and a
heat map of trials keeps the raster and adds `R.trialMatrix` (epochs by bins),
`R.trialOrder` (top row first), `R.trialGroup` and `R.trialRowsName`. The band's error type
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

`h = renderFigure(F, spec, target, Design="", UserAesthetics=true, Editable="auto", OnRemember=[], DataTips="auto")`
draws `F` as `spec` says (the spec `F` was computed with; its `aesthetics` may
differ, as when the aesthetics editor redraws). `target` is an axes (which draws
panel 1 only), uiaxes, figure, uifigure, panel, tab or grid layout;
renderers never create figures. `Design` names a [plot design](EphysAnalysis.md#plot-designs) for this drawing (default: the user's chosen one), `UserAesthetics=false` leaves the user's remembered rules out, `Editable` (`"auto"`: in a visible figure) turns the right-click editing on or off, and `OnRemember` is called with a figure's new rules ([Plot aesthetics](EphysAnalysis.md#plot-aesthetics)). `DataTips` (`"auto"`: in a visible figure, as `Editable`; `true` or `false`) gives every part drawn data tips that name what the point is (`FigureDataTips.attach`, below).

- **Layout.** renderFigure lays its panels out itself (not with MATLAB's tiled
  layout): `target`, emptied (a grid layout gets a borderless panel; `h.layout`),
  holds one axes per panel, and once everything
  is drawn and dressed (its looks final) `figureLayout` measures the room each
  panel's labels take (its axes' `TightInset`, on the sides where tick labels,
  an axis label, a title or a color bar outside sit: a tick label that only
  reaches past a corner keeps no neighbor away) and places every axes in pixels
  (`figureArrange`, pure):
  - the plot areas of the rows and columns line up across the grid, in the exact
    proportions of `rowHeights` and `colWidths` (no rounding; `[]` = equal);
  - between two rows goes the room the tallest labels there take (the bottom
    labels of the panels ending in the row above, the titles of those starting in
    the row below) and the **gap**, the clear space between neighboring panels'
    labels; columns the same with the left and right labels. A gap of 0 makes the
    plot areas flush where no label sits between them: a time stack whose inner
    tick labels are dropped. The gaps are `grid.spacing`'s: a preset (`"loose"`
    24 px, `"compact"` 12, `"tight"` 6, `"none"` 0) or `"custom"` (`rowGap`,
    `colGap`, or each gap of `rowGaps` / `colGaps`, in px or in % of the mean
    row's plot height / the mean column's plot width);
  - a panel whose `size` is below 1 takes that share of its cell's plot area,
    at its `align` and `valign`; its note's band (below) comes off its area, and
    a coherence panel's phase strip takes the bottom third of what is left;
  - the title and dataset subtitle sit in a band over the grid (a hidden axes,
    Tag `titleHost`, holds them: the editor's `plotTitle` and `plotSubtitle`),
    the figure's legend in a band beside it (below), and a margin of 6 px goes
    round it all;
  - it measures again at the new sizes (an axes' size can change its tick
    labels) and arranges again when the room changed;
  - `target` is laid out again whenever it changes size (a listener of its
    `SizeChanged` event; its `SizeChangedFcn` stays its owner's), so a figure in
    a panel or window that is resized follows it (the app's preview), and an
    export figure is laid out at its own size. The axes go straight into a figure,
    not into a panel of it: `print` writes no SVG of a figure holding UI components.
  The layout is deterministic: the same figure at the same size is drawn the
  same, pixel for pixel. Into an axes target only panel 1 is drawn.
- **Panels.** Each type's draw function (through `figurePanelRegistry`) draws its
  layers; a skipped layer says why in the panel, a panel with nothing to draw says
  so in its middle. Every object carries an aesthetics role, so the editor lists
  the components, the tiles by panel id; the figure adds the roles `eventLine`,
  `eventRug`, `eventSpan`, `layerNote` and the event-trace panel's `eventBar`,
  `eventTick`, `eventLevel`, `eventBaseline` and `eventGroupBand`, and a continuous panel's per-trial traces are the
  role `trialTrace` ("Trial traces").
- **Notes and overlays.** A panel's `overlays` are drawn on its axes after its
  layers (`drawOverlays`: every one of them, a panel having no raster / data
  choice; a coherence panel's x overlays also go on its phase strip, which shares
  its x axis), over or under the data as each says. A panel's `note` is drawn by
  `drawNote`. Placed `"below"`, `"above"`, `"left"` or `"right"`, it takes a band
  of the panel's area beside its axes: a hidden axes (Tag `noteHost`) holding
  the text, fitted to the text as drawn (its looks final) and to the axes' tick
  labels and label on that side, which sit in the band next to the axes, never
  more than half the panel's area. A band below or above leaves the axes' left
  edge and width equal to those of a plain panel in the column; a panel with a
  band left or right is narrower than its column, so it keeps its own time tick
  labels, and so does the panel above it (the shared time axis is not hidden for
  that pair). A
  band note turned a quarter (`|sin(rotation)| > 0.7`) reads along y, and its
  alignment comes from `valign`: bottom, middle or top is left, center or right
  at +90, mirrored at -90 (below and above, `align` still places it along the
  band and `valign` up it; left and right, `valign` places it up the band). Placed at a compass point, `"center"` or
  `"custom"`, the text sits in the panel's axes (`placeNote`), on top of what is
  drawn there. Into a single axes target only the first panel is drawn, and its
  note goes in that axes whatever its placement (a note below or above goes just past the axes' edge). A note in a band is not listed in the right-click
  [aesthetics](EphysAnalysis.md#plot-aesthetics) editor (the band has no tile of
  its own; the editor lists the panels' axes in the order drawn, a coherence
  panel's phase right after its magnitude); a note in the axes and every overlay are listed, by the panel's tile
  and, for an overlay, its name. The note's and the overlays' own looks are
  rules after the design's and the user's and before the figure's own
  `spec.aesthetics` (in that order), so a rule of the figure
  restyles them; a band note still takes the note rules of the design, of the
  panel's type, of the figure, its own and `spec.aesthetics`, though the editor
  does not list it.
- **Time and title.** The [shared time axis](#shared-time-axis); the title is
  `title`, else the id, the observation, the event and the epoch count, with the
  dataset as the subtitle. The title of a per-group observation names its group:
  the observation's label ends with it already, and a title of your own gets
  `" · <group>"` appended.
- **Legend.** One, in a band east of the panels (`Style.LegendLocation` `"auto"`
  or `"east"`; `"north"`, `"south"` or `"west"` put the band on that side,
  `"inside"` puts the legend in a panel): the trial groups
  once, then the layers', units', channels' and marks' entries, each label
  once; no panel keeps a legend of its own but one with a trial selection of its
  own, which lists its own groups and entries in a legend inside it.
- **Look.** The design's common rules everywhere, then on each panel's axes the
  design's rules for its panel type and the user's remembered rules for that type
  (a look remembered for PSTH panels dresses every PSTH panel), then on the
  whole figure the design's and the user's `"figure"` rules and `spec.aesthetics`,
  the later winning (a panel's note and overlays come in between, as the item above says); last of all a panel's `box`, when it is `"on"` or `"off"`, over every one of them. In a visible figure a right-click opens the
  [aesthetics editor](EphysAnalysis.md#plot-aesthetics) on the figure.
- **Data tips.** With `DataTips` on, `FigureDataTips.attach(F, spec, h)` runs once the
  figure is drawn: each part's tip names the panel's quantities with their units
  (a time panel's x as *Time from Stim onset*, in s; the y quantity and the color
  bar's from the axes' labels: rate in Hz, z-score, µV, power), and from `F` and the
  part's tags (`tagPart`'s role and group) the trial and trial group of a raster
  tick, stop dot or mark (found by its times in the panel's raster layers) or of a
  heat map row of trials, the trial's parameter values, a heat map row's label, the
  unit, channel or event the part draws, its layer, the panel's id and type, the
  observation and the dataset. Nothing is computed for it; a new panel type gets
  these tips without code of its own. A part with a `DataTipTemplate` (lines drawn
  with `plot`, scatter, bars, error bars, box charts) gets `dataTipTextRow` rows (a
  row per point only where a point has its own value, as long as the part's data);
  the others (raster ticks and other `line` objects, images, patches) are written
  by the figure's data cursor `UpdateFcn` from the same rows. The fields shown are
  the user's preference (`FigureDataTips.chosen` / `setChosen`, AppPrefs group
  `FigureDataTips`; `DataTipFieldsDialog`), and `FigureDataTips.refresh` shows a new
  choice on the figures on screen.

`h` holds `layout` (what the figure is laid out on: `target`, or the panel made in a
grid layout, holding the panels' axes, the hidden axes of the title and the note
bands and the legend; `[]` for an axes target), `axes` (the panels'
axes drawn, in panel order), `panels` (one per panel of the spec: `id`, `type`,
`axes`, empty when not drawn, and `extraAxes`, the phase axes of a coherence panel
drawn under its magnitude, dressed with the type's looks; empty for
every other panel; `note`, the text object of its note, empty without one; and
`overlays`, the lines and patches drawn on it) and `title` (the title text).
`renderFigure:Mismatch` when `F`'s panels are not the spec's, `renderFigure:BadTarget`
for a target it cannot draw into (a tiled layout, say).

### A figure in JSON

A raster flush over a PSTH over an LFP panel, all following the unit, with the
stimulus offset marked on every raster row. The `"..."` stand for the rest of a
nested block (as in the [JSON example](#json-example) above); the config's
`Defaults` give the alignment (`"default"`), the three rows' plot areas are
1.5 : 1 : 1, drawn flush (`"none"`), and the options shown are the types'
defaults. A file written by hand may leave out any field that keeps its default.

```json
"Figures": [
  { "id": "unit_card", "autoId": false, "enabled": true, "title": "",
    "observe": { "data": "units",
                 "units": { "classes": ["su"], "groups": [], "ids": [], "channels": [], "shanks": [], "maxUnits": "Inf",
                            "quality": { "enabled": false, "...": "..." }, "response": { "enabled": false, "...": "..." } },
                 "channels": [], "perGroup": false },
    "grid": { "rows": 3, "cols": 1, "rowHeights": [1.5, 1, 1], "colWidths": [], "spacing": "none",
              "gapUnits": "px", "rowGap": 6, "colGap": 6, "rowGaps": [], "colGaps": [] },
    "ref": "default", "window": "default", "selection": "default",
    "sessions": { "enabled": false, "datasets": "ticked", "datasetKeys": [], "facet": "none", "series": "session",
                  "colorOrder": "palette", "showMembers": false, "error": "sem", "match": "site", "mappingFile": "",
                  "minSessions": 1, "trialGroups": "pool" },
    "panels": [
      { "id": "raster_1", "type": "raster", "title": "", "box": "auto", "row": 1, "col": 1, "rowSpan": 1, "colSpan": 1,
        "ref": "default", "window": "default", "selection": "default",
        "layers": [
          { "name": "", "enabled": true, "source": "units", "binding": "observation", "aggregate": "each", "...": "..." },
          { "name": "Stim offset", "enabled": true, "source": "events", "binding": "fixed", "eventsAs": "marks",
            "event": { "line": "Stim", "edge": "offset", "which": "all", "n": 1, "scope": "recording",
                       "minDurationSec": 0, "maxDurationSec": "Inf", "timeRange": ["-Inf", "Inf"], "offsetSec": 0,
                       "offsetParam": "", "offsetParamUnit": "ms", "sequence": [], "alignStep": "Inf",
                       "marker": "diamond", "size": 4, "color": "" } } ],
        "options": { "rasterSort": "", "rasterSortEvent": [], "rasterSortOrder": "ascending", "rasterByGroup": true,
                     "maskAfterStop": false, "tickColor": "", "backColor": "", "yTicks": false,
                     "waveform": { "mode": "off", "...": "..." } } },
      { "id": "psth_1", "type": "psth", "title": "", "box": "auto", "row": 2, "col": 1, "rowSpan": 1, "colSpan": 1,
        "ref": "default", "window": "default", "selection": "default",
        "layers": [ { "name": "", "enabled": true, "source": "units", "binding": "observation", "aggregate": "each", "...": "..." } ],
        "options": { "bins": { "BinSec": 0.01, "SmoothSec": 0.01 }, "measure": "rate",
                     "baseline": { "Mode": "none", "Window": [-0.2, 0] }, "histStyle": "bar", "fill": true,
                     "fillAlpha": "NaN", "normalize": "none", "maskAfterStop": false, "yLim": [],
                     "waveform": { "mode": "off", "...": "..." } } },
      { "id": "continuous_1", "type": "continuous", "title": "", "box": "auto", "row": 3, "col": 1, "rowSpan": 1, "colSpan": 1,
        "ref": "default", "window": "default", "selection": "default",
        "layers": [ { "name": "", "enabled": true, "source": "LFP", "binding": "observation", "aggregate": "each", "...": "..." } ],
        "options": { "baseline": { "Mode": "none", "Window": [-0.2, 0] }, "display": "lines", "statistic": "mean",
                     "transform": "none", "errorType": "sem", "stackSpacing": "NaN", "trials": "off", "maxTrials": 100, "yLim": [] } } ],
    "style": { "LineWidth": 1.2, "...": "..." }, "aesthetics": [] } ]
```

`observe.data "units"` draws it for each sorted unit, which the units layers
follow; the LFP layer follows too, reading the column of the LFP extract that
records the unit's channel. The three panels share the time axis, so only
the bottom one is labeled. The events layer is `fixed`, as every events layer
is, and its `event` is an [EventMark](#raster-event-marks). The `sessions` block shown
is the default, a figure drawn per dataset; ticking `enabled` makes it a
[session figure](#session-figures). Each panel also holds its `size` (`[1, 1]`), `align` (`"center"`) and `valign`
(`"middle"`), a `note` and a list of `overlays` ([Panel fields](#panel-fields)), left out above: `"note"` is a
[note](#panel-notes) (`"text": ""` draws nothing) and `"overlays"` a list of [overlays](#panel-overlays), empty by default.

### Validating figures

`cfg.validate()` checks `Figures` with the section name `Figures`; a `Field` reads
`<figure>.<field>`, `<figure>.<panel>.<field>`, `<figure>.<panel>.layers(<j>).<field>`,
`<figure>.<panel>.note.<field>` or `<figure>.<panel>.overlays(<k>).<field>`.
The rules, by severity (the full list of the other sections is under
[Validation](#validation)):

Errors:

- the figure's id is not empty, has none of `\ / : * ? " < > |`, and stays distinct
    from the other figures' once `{Plot}` has sanitized it (case-blind): a figure's
  files are named with `{Plot}`. An [automatic id](#figure-ids) meets these by
  construction (`autoId` is coerced to a logical when the config is read);
- the figure's own `ref`, `window` and `selection` are valid, by the
  [Defaults](#defaults)' rules (at most 2 `groupBy` parameters);
- `observe`: `data` is one of `ObserveData` (`units`, `detected`, `LFP`, `MUA`,
  `SPIKE`, `AUX`, `dataset`; `<figure>.observe.data`); `channels` are whole
  numbers >= 1; `units.maxUnits` >= 1; on a figure that observes units, an
  enabled `units.response` test (at `<figure>.observe.units.response.<field>`: the
  test, `param` for a tuning or either / both test, ordered `baseline` and `window`,
  direction, correction, `alpha` in (0, 1], the auROC settings of the `"auroc"`
  test, and the Statistics and Machine Learning Toolbox the tests need; each spike
  layer's `units.response` likewise, at `<figure>.<panel>.layers(<j>).units.response.<field>`);
  and a layer that follows the observation does not go in a figure observed as the
  dataset;
- `sessions` (`<figure>.sessions.<field>`): the known values and, with
  `sessions.enabled`, what a figure across sessions cannot hold: the rules
  are under [Session figures](#validating-session-figures);
- `grid`: `rows` and `cols` whole numbers >= 1; `rowHeights` and `colWidths` `[]` or
  one finite positive size per row and column; `spacing` `loose`, `compact`, `tight`,
  `none` or `custom`; `gapUnits` `px` or `%`; `rowGap` and `colGap` numbers >= 0;
  `rowGaps` and `colGaps` `[]` or one gap >= 0 between every two rows (`rows - 1`)
  and columns (`cols - 1`);
- panels: an id of their own; `row`, `col`, `rowSpan` and `colSpan` whole numbers
  >= 1 inside the grid; a `size` of two numbers over 0 and at most 1; `align`
  `left`, `center` or `right` and `valign` `top`, `middle` or `bottom`; no two
  panels overlapping a cell; a known `type`;
- a panel's own `ref`, `window` and `selection` only on an aligned type, and valid
  (the selection by the figure's rules, at most 2 `groupBy` parameters, reported at
  `<figure>.<panel>.selection`); a
  `"between"` window (a panel's or the figure's) only on a unit correlation,
  firing rate or tuning curve panel;
- each enabled layer: a `source` in `FigureSources`; an events layer only on a panel
  that shares the time axis; a source the type draws (`A unit waveforms panel draws
  unit-summary layers, not LFP`); a `binding` of `observation` or `fixed`, with
  `observation` only for `units`, `detected` and the signals, never on a heat map
  (but for the spike layer of a heat map of trials), probe map or unit correlation
  panel, and AUX never following a unit
  observation; `aggregate` `each` or `mean`, or `magnitude` on a fixed signal
  layer of a spectrum, spectrogram or coherence panel; `units.maxUnits` >= 1; `channels`
  whole numbers >= 1; an events layer's `eventsAs` `marks`, `train` or `span`
  (`train` only on a raster, PSTH or heat map; not checked on an event-trace
  panel, which does not use it), the mark's event reference, a
  `marker` the aesthetics editor knows and a positive `size`, a span's
  `spanStyle` (`-`, `--`, `:`, `-.`), a positive `spanWidth` and a `spanAlpha` from 0
  to 1; only events layers on an event-trace panel (`An event traces panel draws
  events layers only (a digital or derived line each), not units.`); a `lineStyle` that is
  `""`, `-`, `--`, `:` or `-.`;
- a raster whose enabled layers are all events drawn as marks or spans (`A raster's marks
  need rows: add a units, detected or train layer`);
- options, by type: a raster's `rasterSortOrder` and, with `rasterSort "event"`, a
  valid `rasterSortEvent`; a PSTH's `bins` (`BinSec > 0`, `SmoothSec >= 0`),
  `measure`, `baseline` (`Mode` among the type's, a window `[b0 b1]` with `b0 < b1`),
  `auroc` (with baseline `Mode "auroc"`: the auROC rules ([auROC](#auroc)), its window
  and step whole numbers of the panel's bins, and the Statistics and Machine Learning
  Toolbox, at `<figure>.<panel>.options.auroc`), `histStyle`, `normalize`, `fillAlpha`,
  a positive `stackSpacing`, `display` (`trace` or `heatmap`), `colormap` (a name that
  is no colormap function is a warning), `cLim`, `yLim`; a continuous panel's `baseline`
  (`none` or `subtract`, its window overlapping the panel's window), `display`, `statistic`, `transform`, `errorType` (`ci95`
  and `iqr` need the Statistics and Machine Learning Toolbox), a positive or `NaN`
  `stackSpacing`, `trials` (`off`, `faint` or `only`), `maxTrials` (a whole number
  >= 1, or `Inf`), `yLim`; a heat map's `rows` (`items` or `trials`; with `trials`:
  the map layer a spike or train layer, not a signal, that follows the observation
  or is fixed to one unit (one id, or `maxUnits` 1; a layer that follows the
  observation through a channel, which keeps every unit on it, is refused at
  `<figure>.<panel>.layers(<j>).binding`), no auROC baseline, and the
  raster's sort rules for `rasterSortOrder` and `rasterSortEvent`), `bins`, `measure`, `baseline` and `auroc` for a
  spike layer (a signal layer with baseline `Mode "auroc"` is an error: spikes only),
  `baseline` for a signal layer, `order` (`probe`, `peak`, or `modulation` only with
  the auROC baseline of a spike layer), a whole `group` >= 1, `cLim`; a waveforms
  panel's `layout` (`grid` or `probe`); a spectral panel's options by
  `chronuxSettings`' rules (at `<figure>.<panel>.options`, with its message), its
  `yLim`, `cLim` and `group`, a coherence panel's two enabled layers and a
  spectrogram's signal or spike layer ([Spectral
  panels](#spectral-panels)); a probe map's `value` and `cLim`; a
  correlation map's `metric`, `correlation`, `bins` (for `peak`), `baseline`, `group`,
  `cLim`; a rate panel's `measure`, `baseline` (`Mode` `none`, `subtract`, `ratio` or
  `zscore`), `display` (`bar`, `box` or `points`) and `yLim`; a tuning panel's `measure`,
  `baseline` (as a rate panel's), `param` and `seriesParam` (each empty or a trial
  parameter's name, and not the same one), `yLim` and `waveform`; the `waveform`
  settings of a raster, PSTH, tuning or waveforms panel (mode, and for a waveforms
  panel never `off`; location, `scale` in (0, 3], whole `maxSpikes >= 1`, `ampScale`);
  `yLim` and `cLim` `[]` or ascending; an event-trace panel's `display` (`bars` or
  `line`), `trials` (`overlay` or `rows`), `colorBy` (`layer` or `group`), `height`
  in (0, 1], `alpha` from 0 to 1 or `NaN`, `lineStyle` and `baselineStyle`, and
  positive `edgeWidth`, `lineWidth`, `baselineWidth` and `rowSpacing`, a
  `minWidth` of 0 or more, and with `trials "rows"` its sort as a raster's
  (`rasterSortOrder`, a `rasterSortEvent` for `rasterSort "event"`) (an
  `edgeColor` or `baselineColor` that is not a color is a warning);
- each panel's text note and overlays, by one function's rules ([Panel notes](#panel-notes), [Panel overlays](#panel-overlays)): a note with no text is not
  checked (a panel of an unknown `type` has its note and overlays checked all the same; `box` is `auto`, `on` or `off`),
  else its `placement`, a finite `x` and `y` for `"custom"` (`0-1 across and up the panel`), `align`, `valign`,
  `interpreter`, a finite `rotation` and a positive (or `NaN`) `fontSize`; an overlay's
  `shape`, a finite `value` (line) or two different finite `from` and `to` (region), `axis`,
  `layer`, `lineStyle`, a positive `lineWidth` and `alpha` / `faceAlpha` from 0 to 1. A
  panel's overlay `panel` is always `"all"` (`normalizePanel`: its overlays are drawn on its
  own axes), so there is no warning that a panel of the named kind is absent;
- the figure's `style` (`MaxTiles >= 1`, `TileSpacing`, the legend settings, `ErrorType`, `ErrorResamples`, `ErrorFaceAlpha`, ...; the bootstrap CI
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
- a coherence panel whose fixed seed layer keeps several channels or units
  (`<panel>.layers(<j>)`): only the first is the seed, so fix the layer to one;
- a unit or channel observation with no layer following it (`<figure>.observe.data`:
  the figure is the same for every one);
- `observe.perGroup` while the figure's selection groups by nothing (not for a session figure; `<figure>.observe.perGroup`:
  one figure per observation, as without it);
- a session figure's warnings ([below](#validating-session-figures)): `datasets "list"` with no
  `datasetKeys`, `showMembers` with `series "session"`, `trialGroups "pool"` over a selection that
  groups, `"combine"` over PSTH bars and a heat map of trials;
- a signal layer following a channel observation of another signal (it takes the
  observed channel's number in its own extract);
- a fixed raster, PSTH, rate or tuning point layer that may keep more than 8 units, each drawn in
  the one panel (limit `units.maxUnits` or `ids`, or aggregate them with `mean`);
- a layer's or mark's `color`, or a style color, that is not a color; likewise a
  panel's note `color` or `background` (the design's is kept) and an overlay's `color`,
  `faceColor` or `edgeColor` (its default is kept);
- two overlays of a figure with the same name, on one panel or on two (`Another overlay
  of this figure is also named ...`: a look remembered for the name reaches both).

Whether a dataset can draw the figure (units, signals, lines, trial parameters, a
probe) is not a config error: `figureSkipReason` says why a figure or a layer is
skipped on a dataset ([above](#observations-and-skip-reasons)).

### Session figures

A figure with `sessions.enabled` is a *session figure*: drawn **once across
several datasets** (sessions) instead of once per dataset. One observation (a
site, a cell of a mapping, a channel or the dataset) is computed on every
session, and each panel's layers are merged with `combineSessions` into a
result of the same kind ([the merged result](EphysAnalysis.md#the-merged-result)):
a color per session, or per subject (its sessions averaged), or one mean, with
a band across the sessions. A session figure carries its own panels, layers,
alignment and look, and the cross-session settings in its `sessions` block. A run
draws session figures after the datasets, in the report's *Across sessions*
section; never per dataset, whatever `Figures=` names.

```matlab
[cfg, id] = cfg.addFigure("rasterPsth", Id="card");
k = cfg.figureIndex(id);
cfg.Figures(k).sessions.enabled = true;                  % across the datasets, not per dataset
cfg.Figures(k).sessions.series = "subject";              % a color per subject, its sessions averaged
cfg.Figures(k).sessions.minSessions = 2;                 % a site needs a unit in two sessions
r = EphysAnalysisRunner(cfg);
[T, sessions] = r.sessionFigureObservations(id);         % the sites matched across the sessions
[res, sessions] = r.computeSessionFigure(id, [], Observation=T(1, :));   % merged, no graphics
renderFigure(res(1).F, cfg.figureFor(id), figure);       % draw it
R = r.run(SessionFigures=id, Figures=string.empty(1, 0));   % or every site of it, a page each
```

`sessions` is `defaults("FigureSessions")`:

| Field | Default | Meaning |
| --- | --- | --- |
| `enabled` | `false` | `true`: a session figure. False keeps the block and leaves it unused (the figure is drawn per dataset) |
| `datasets` | `"ticked"` | `"ticked"`: the run's datasets (the Data tab's ticks, or `run(Datasets=)`); `"list"`: the datasets of `datasetKeys`, ticked or not: the app's **Generate** draws across the listed ones whatever is ticked (it says so and draws nothing when none is scanned), but the Export tab's **Run** still needs at least one ticked dataset before any session figure runs |
| `datasetKeys` | `[]` | `"list"`: the datasets' keys (the Data tab's **Key** column, e.g. `SYNTH-01/260908_103000`); a key no dataset has is left out and logged |
| `facet` | `"none"` | `"none"`: one figure over every session; `"subject"`: one figure per subject (a name pattern without `SubjectID` leaves the sessions in `(no subject)`), in date order |
| `series` | `"session"` | what gets a color: `"session"`, `"subject"` (its sessions averaged) or `"all"` (one mean over every session) |
| `colorOrder` | `"palette"` | `"palette"`: the design's palette in turn; `"sequential"`: a sequential map in date order |
| `showMembers` | `false` | series `"subject"` / `"all"`: each session drawn faintly under its summary (role `memberLine`) |
| `error` | `"sem"` | series `"subject"` / `"all"`: the band across the sessions averaged: `"sem"`, `"sd"`, `"ci95"` or `"none"`. `"ci95"` is a *t* interval: the *t* quantile (`tinv`, Statistics and Machine Learning Toolbox) times the SEM, 1.96 x SEM without the toolbox. NaN with fewer than two sessions. With series `"session"` each series keeps the panel's own error over its epochs |
| `match` | `"site"` | unit observations: how the observed unit is found in each session: `"site"` (the units on the same recording channel) or `"mapping"` (a cell of `mappingFile`). There is no `"pool"`: a figure observes one matched unit. A channel observation always matches by recording channel, and the dataset one needs no match |
| `mappingFile` | `""` | `"mapping"`: the unit-mapping CSV ([format](file-formats.md#unit-mapping-csv)); a column `cell`, then one per dataset key |
| `minSessions` | `1` | an observation is kept with data from at least this many sessions, and each merged figure (a trial group of `"each"`) and layer is drawn only when at least this many sessions contribute to it (a whole number >= 1) |
| `trialGroups` | `"pool"` | the figure's trial groups (its selection's `groupBy`): `"pool"`, `"each"` or `"combine"` ([below](#trial-groups-in-a-session-figure)) |

`observe.perGroup` is ignored in a session figure: its trial groups follow
`trialGroups`. A figure's datasets are `sessions.datasets` and
`sessions.datasetKeys`; `observe` holds no dataset list.

#### Observations across sessions

`T = figureSessionObservations(sources, spec)` lists what the figure can be
drawn for across the datasets: `sources` is a cell, one `loadAnalysisSource`
struct per session in date order (`[]` for one that cannot be read), `spec`
the figure's `figureFor` spec. Each session's own observations come from
`figureObservations` (with `perGroup` off) and are matched across the sessions
by the observation kind and `match`, one row each:

| Observation | One row per | Label |
| --- | --- | --- |
| unit, `match "site"` | recording channel that has a kept unit in at least `minSessions` sessions | `site ch 7  -320 µm` (the channel and its probe y). A session with several units on the site **draws the first in probe order**, not their average; `unitIds` lists them all |
| unit, `match "mapping"` | cell of the mapping file held by at least `minSessions` sessions | the cell's name. A session's ids are looked up in its column (its dataset key) among the units it keeps, and the first of them in probe order is drawn when a cell names several |
| channel | recording channel of the observed extract (`observe.data`, `observe.channels`) present in at least `minSessions` sessions; an AUX channel, which has none, by its label | the first session holding it labels it, as `figureObservations` does |
| dataset | one | `<n> sessions`; no `minSessions` |

Rows follow the first session's probe order, then the channels or cells that
later sessions add (with `"mapping"`, the file's order). A session whose
dataset cannot be read, or that lacks the observed source (no sorted units, no
such extract), holds no row. The columns are those of `figureObservations`
(`kind`, `label`, `channel`, `column`, `shank`, `depth`, `meta` of the first
session holding it, `group` NaN, `groupLabel` `""`; with several sessions `unitId` is NaN, since each
session draws its own unit) plus:

| Column | Holds |
| --- | --- |
| `nSessions` | how many sessions hold it |
| `unitIds` | a 1 x 1 cell holding a 1 x nSessions cell: each session's unit ids on it (`[]`: none; always `[]` for channels and the dataset) |
| `perSession` | a 1 x 1 cell holding a table of nSessions rows: the `figureObservations` row each session draws, with a logical `present` (false, `kind` `""`, where the session has none). `figureSessionCompute` hands row `k` to `figureCompute` for session `k` |

`EphysAnalysisRunner.sessionFigureObservations(fig, idx)` returns
`[T, sessions, sources]`: the table, the `sessionTable` of the datasets (by
date, with `status` and `message`, `"error"` for a dataset that cannot be
read) and their sources. With `sessions.datasets "list"` the datasets are the
listed keys (`sessionFigureIndices`).

#### Merging a session figure

`[res, sessions, Fs] = figureSessionCompute(sources, sessions, spec,
Observation=obs)` computes the figure for one row of `T` (default the first)
without a runner or graphics:

1. **Each session's figure.** `figureCompute` on every session that holds the
   observation, with the session figure's spec as `figureSessionSpec` gives it
   (the trial-group rules [below](#trial-groups-in-a-session-figure)). A session
   without the observation, or one `figureCompute` skips, is `"skipped"` with the
   reason; one that fails is `"error"`. `sessions` gains `status` and `message`,
   and `Fs{k}` is session `k`'s own figure. (A session that computed but lacks a
   trial group of the merged figure is marked `"missing"` in that figure's own
   `sessions`, [below](#merging-a-session-figure).)
2. **Facets and trial groups.** One merged figure per `sessions.facet` (`"all"` or
   a subject) and, with `trialGroups "each"`, per trial group (labels in
   first-seen order, at most the selection's `maxGroups`): `res` is a struct
   array with `facet`, `group`, `label` (`"all"`, the subject, or
   `"<facet> / <group>"`), `F`, `status` (`done`, `skipped`, `error`) and
   `message`. `minSessions` (at least 1) is applied **per merged figure and
   layer**, not once: a figure with fewer sessions that drew it is `skipped`
   (*fewer than N session(s) draw it*), and so is one that fewer sessions
   *contribute* to once it is merged, such as a trial group (`"each"`) that only
   some sessions hold (*fewer than N session(s) hold it*, then the sessions left
   out and why, and `F.mergeWhy` when no layer could be merged at all). Each layer
   is merged with `MinSessions` = `max(1, minSessions)`, and one with too few
   sessions is skipped with `combineSessions:TooFew`.
3. **Each layer merged** with `combineSessions` (`Series=`, `Error=`,
   `ShowMembers=`, `ColorOrder=` from `sessions`). A layer that holds one unit or
   channel in every session (the observed one, or an events layer drawn as a
   train) is merged into **one tile**: the units are made common through a
   one-row mapping. A layer that holds several (fixed units) **pools** them, a
   tile per session-unit, labeled `"<unit> · <session>"`. A signal layer's
   channels match by recording channel. A layer whose `aggregate` is `"mean"`
   has its mean taken again over the merged tiles (`layerMean`, the band across
   them).

`F` is shaped as `figureCompute`'s, so `renderFigure` draws it as it draws one
dataset's: `panels(k).layers(j).R` is the merged result (`R.sessions`,
`R.sessionSeries`, `R.members`; `R.groups` are the series), `epochs` and `groups`
are those of the first merged layer on the figure's selection, and the extra
fields `sessions` (the facet's rows with `status`, `message` and each session's
`nEpochs`, as the first merged layer says: a session that computed but lacks the
trial group or the observation is `"missing"`, and its epochs are not counted),
`nSessions` (how many **contributed**, status `"done"`; 0 when no layer merged,
then `mergeWhy` says why), `mergeWhy`, `perSession` (the facet's indices in the
sessions table), `sessionSeries` and `observation` say how it was made. The title
reads `<id>: <observation> — <event> (3 sessions, 112 epochs)`, N being the
sessions that contributed, and the subtitle `3 sessions (SYNTH-01)`; the legend
lists the series. A PSTH panel's stacked display (`stack`) is drawn across
sessions too, and the faint member lines and the line styles of
`trialGroups "combine"` apply to its stacked rows as to the overlaid ones.

Not merged, each with its reason in the panel (a skipped layer, as for one
dataset): events drawn as **marks** (*event marks are not drawn across
sessions*), the **rings** of a waveforms panel's probe layout (*the probe
layout's rings are not drawn across sessions*), a **heat map of trials** (*a
heat map of trials is not merged across sessions*), and a whole panel of a type
in `EphysAnalysisConfig.FigureSessionUnmerged` (*probe map panels are not merged
across sessions*, the type named by its label; likewise unit correlation, power
spectrum, spectrogram and coherence panels). An event-trace panel is merged:
every session's epochs, as a raster's ([Event traces](#event-traces)). Events drawn as spans are skipped as marks are. A merge that fails (`combineSessions:TooFew`, `:Bins`,
`:TimeBase`, ...) skips that layer with its message, and the rest of the figure
is drawn. That is what `figureSessionCompute` and so the app's preview do with
an unmerged panel type. Validate refuses such a figure, though, and so does
`figureSessionSkipReason`: `plan` lists it and a run skips the **whole figure**
with the reason (*a probemap panel is not merged across sessions*, and likewise
*an auROC baseline is not merged across sessions*), drawing none of its panels.

#### Trial groups in a session figure

A figure that groups its trials (the selection's `groupBy`) has a series per
group in each session. `trialGroups` says what the session figure does with
them, and `figureSessionSpec` applies it to the compute and the render alike:

| `trialGroups` | Result |
| --- | --- |
| `"pool"` (default) | the groups are cleared (the figure's and every panel's `selection.groupBy`, a tuning panel's `seriesParam`): every epoch of a session together, and the series are the sessions (or subjects) |
| `"each"` | the groups are kept, and one merged figure is made per group, each on its own, matched by label across the sessions. A session without a group is *missing* for that group's figure and contributes nothing to it; a group held by fewer than `minSessions` sessions is skipped (*fewer than N session(s) hold it*) while the other groups are drawn |
| `"combine"` | every group kept in one figure: a series per session (or subject, or all) and trial group, colored by the session or subject and told apart by line style; a PSTH panel's `histStyle` is drawn as `"line"` even when it is `"bar"` |

#### What a run writes

- `EphysAnalysisRunner.run(SessionFigures=)` (default
  `Config.enabledSessionFigures()`; `string.empty(1, 0)` for none) draws them
  after the datasets, in the report's *Across sessions* section, each
  with an equal share of the run's progress. A cancel marks the one running and
  the rest `canceled` (rows `"sessions: all"`). `runSessionFigure(id, idx)` is one
  figure: compute, render, export and report, per observation.
- `plan(SessionFigures=)` lists one row per session figure and facet, `Dataset`
  `"sessions: <facet>"` (`all`, or a subject), `Kind` `figure`, `Source` the
  observe kind. Its `Reason` comes from `figureSessionSkipReason`: *disabled*,
  *a probemap panel is not merged across sessions* (any type in
  `FigureSessionUnmerged`), *an auROC baseline is not merged across sessions*,
  *no mapping file* / *mapping file not found: F* (a unit observation with
  `match "mapping"`), or *fewer than N session(s) can draw it* followed, in
  parentheses, by each session left out and its own `figureSkipReason`, with
  N = `max(1, minSessions)`. A figure that
  passes can still draw nothing when it runs (*no unit is matched across the
  sessions*).
- One page per matched observation goes to `Export.SessionsFolder` (the folder
  tokens are the first session's), named by `figureOutputName` from
  `Export.FilenamePattern` with `{Name}` the facet (`all`, or the subject),
  `{Plot}` the figure's id and `{Unit}` `site_ch7` (a site), the mapping's cell,
  `ch7` (a channel; an AUX one its label) or `dataset`. When there are several
  observations and the pattern names neither `{Unit}` nor `{Index}`, `_<Unit>`
  is added, and for `trialGroups "each"` `_<group>` after it (a pattern naming
  neither `{Group}` nor `{Index}`): `all_card_site_ch7.png`,
  `all_card_site_ch12_Depth___0.5.png`. A name this run has already written
  (two mapping cells that sanitize alike, `A/1` and `A_1`) gets `_2`, `_3`, ...
  after it, compared case-blind as Windows names files. `Export.Overwrite` off
  keeps a page whose files all exist.
- One `Results` row per figure label (facet and trial group), `Dataset`
  `"sessions: <label>"`, `Kind` `figure`, `Message` `<n> observation(s)` (and
  *; not drawn:* with the observations that were not, and why). The status is
  `skipped` when no observation was drawn (the reasons), `error` when only
  failures remain. The run record lists the ids as `sessionFigures`.
- The report has one entry per label in *Across sessions*, a page per
  observation, captioned per facet by `figureCaption(spec, T, Sessions=S)` with
  `T` the observations that facet's figure drew and `S` the sessions that facet
  merged (not the whole run's):
  *card: site ch 7 across 3 sessions (1 subject); panels: ...*, or *card: 12
  observations (sorted units, matched by site) across 3 sessions (2 subjects);
  ...*, then the alignment and the series (*a color per session*, *a color per
  subject, its sessions averaged*, *all sessions averaged*), the handling of the
  trial groups (*trial groups pooled*, *one figure per trial group*, *trial
  groups by line style*) and *one figure per subject*.
- With `Export.Data.Enabled`, one `.mat` per session figure holds the merged
  and each dataset's own figures, `<Data.Folder>/<Data.FilenamePattern>.mat`
  with `{Name}` `all`, `{Plot}` the figure's id and `{Kind}` `figure`
  ([Session figure data](file-formats.md#session-figure-data-mat)); its path is
  added to the first row's `Files`, and a failure goes into its `Message`.

The standalone script carries the same calls
([Generated scripts](EphysAnalysis.md#session-figures-in-a-standalone-script)),
and the app edits the block in the Figures tab's Sessions section
([Figures tab](EphysAnalysisApp.md#figures-tab)).

#### Validating session figures

The `sessions` block is checked as `<figure>.sessions.<field>`, in the section
`Figures`.

Errors:

- `datasets`, `facet`, `series`, `colorOrder`, `error`, `match` and
  `trialGroups` known values (also while the figure is not a session figure),
  and `minSessions` a whole number >= 1;

- with `sessions.enabled`: `match "mapping"` on a channel or dataset observation
  (it names units), without a `mappingFile`, or with one that does not exist
  (with `CheckPaths`), cannot be read or has no `cell` column;
- with `sessions.enabled`: a probe map, unit correlation, power spectrum,
  spectrogram or coherence panel (`<figure>.<panel>.type`: *A session figure
  cannot hold probe map panels: combineSessions does not merge them across
  sessions.*),
  and an auROC baseline
  (`<figure>.<panel>.baseline.Mode`: auROC curves are not merged).

Warnings (with `sessions.enabled`):

- `datasets "list"` with no `datasetKeys` (it draws nothing), and a mapping
  file with no column for a listed dataset key (that session cannot be matched);
- `showMembers` with `series "session"` (each session is its own series
  already);
- `trialGroups "pool"` while the figure's selection groups its trials (the
  groups are pooled);
- `trialGroups "combine"` with a PSTH panel drawn as bars (drawn as lines);
- a heat map of trials (`options.rows "trials"`; not merged, the layer is
  skipped).

The `observe.perGroup` warning (the selection groups by nothing) does not fire
on a session figure, which ignores `perGroup`. A config whose only enabled item
is a session figure is accepted (*No figure is enabled.* counts it).

### Loading a version 1 config

Config version 1 held `Plots` (one kind of data for a page of units or channels) and
`SessionPlots` (a plot drawn across datasets). Version 2, this one, holds only
[`Figures`](#figures), so a version 1 file is converted **once, when it is loaded**:
`EphysAnalysisConfig.load(file)` does it, and so do `EphysAnalysisConfig(s)` and
`fromStruct(s)` for a struct whose `version` is 1. The result is an ordinary version 2
config; `save` writes version 2, with no `Plots` or `SessionPlots`, and from then on the
file is migrated for good. Nothing else reads a plot: the migration lives in the class's
private `legacyMigrate`, `legacyPlotToFigure`, `legacyNormalizePlot`, `legacyLooks`,
`legacyPlotKinds` and `legacyPlotDefaults`, which keep version 1's fields and defaults
only so that they can be read, and is used for nothing else. Any other version, or
another schema, is `EphysAnalysisConfig:BadSchema`; a version 2 file that still holds
`Plots` or `SessionPlots` gets the unknown-field warning (`dropped unknown top-level
field(s) Plots, SessionPlots`) and they are dropped.

```matlab
cfg = EphysAnalysisConfig.load("D:\EPHYS\old_quicklook.json");   % version 1: warns, migrated
disp(cfg.LoadWarnings.')                    % "config version 1: 3 of 4 plot(s) and 1 of 1 session plot(s) migrated ..."
cfg.save("D:\EPHYS\old_quicklook.json");    % now version 2
```

Everything the migration did, or could not do, is a line of `LoadWarnings` (and of the
`EphysAnalysisConfig:LoadWarnings` warning `load` raises); nothing is dropped silently. The
first line is `config version 1: N of M plot(s) and K of J session plot(s) migrated to
figures; saving writes version 2` (given when the file held any plot or session plot);
a plot's lines read `plot psth_1 migrated to figure psth_1: <note>` and a session
plot's `session plot psth_days migrated to session figure psth_days: <note>`, one per
note, and none for a plot that needed none. Unknown fields of a plot or session plot are
listed as before (`Plots: dropped unknown field(s) ...`).

**What becomes what.**

- **Plots first, then the file's own figures, then session figures.** The migrated plots
  come first in `Figures` (in their order), then the figures the file already had
  (which keep their ids), then the migrated session plots. A plot or session plot
  without an id first gets one (`<kind>_<n>`; `<plot>_sessions_<n>`, or `sessions_<n>`
  without a base plot).
- **Ids.** A plot's figure has the plot's own id (no suffix: the plots are gone). An id that
  names the same files as one already taken (a figure the file had, or one migrated
  earlier; case and the characters `{Plot}` replaces ignored, as in
  [validation](#validating-figures)) gets `_2`, `_3`, ... and a warning
  (`its id names the same files as another figure's, so it was renamed`). A plot and a
  session plot could share an id in version 1 (separate namespaces); the session figure is
  the one renamed.
- **A plot** becomes the figure that draws what it drew, through the converter below: its
  alignment, unit filter, bins, baseline, auROC settings and look.
- **A session plot** becomes a session figure of its own id: the panels of its base plot
  (converted as a plot is, with the session plot's `layout` when it has one), `enabled`
  and `title` (when not empty) from the session plot, and its looks (`aesthetics`) after the
  base plot's, both [remapped](#looks-on-retired-roles). Its `sessions` block is filled from
  the session plot: `enabled` true, `datasets`, `datasetKeys`, `facet`, `series`,
  `colorOrder`, `showMembers`, `error`, `match`, `mappingFile`, `minSessions` and
  `trialGroups`. Three of those can not carry over, each a note:
  - `match "pool"` (every session's units pooled, a tile each) becomes `"site"` when the figure
    observes units, since a figure observes one unit matched across the sessions (the note:
    `match "pool" ... is not available ... it became "site"`). For a channel or dataset figure
    it is simply `"site"`, with no note.
  - `match "mapping"` over a figure that observes a channel or the dataset becomes `"site"`, with
    `mappingFile` cleared (a mapping names units): the note says so.
  - a `data` list other than `"results"` (`"epochs"`, `"signals"`) is a note: a session
    figure's data file holds its merged and per-session figures only (the empty list
    gives none).
- **Not migrated, with a warning.** A `behavior` plot (figures have no panel type for it), and
  a plot of a kind version 1 did not have: `plot <id> not migrated: ...`. A session plot whose
  base plot does not exist, or is a behavior plot (or otherwise not convertible), is not
  migrated either: `session plot <id> not migrated: no base plot "<id>".` The counts in the
  first line say how many were migrated.

#### Looks on retired roles

A plot's `aesthetics` (and a session plot's) are kept as the figure's, with the roles of the
retired aux panel renamed to the continuous panel's: a rule on `auxTrace`, `auxSem` or
`auxAxes` now applies to `trace`, `sem` or `axes` (so it reaches every component of that
role in the figure), with a note each (`The look on auxTrace now applies to trace: the
aux signal is a continuous panel of the figure.`). A rule on a role no figure draws
(`auxImage`, `auxGroup`, `auxScale`, `behaviorMean`, `swarm`, `violin`) is dropped with the
note `look on <role> dropped: figures do not draw it`.

#### The converter, plot by plot

`legacyPlotToFigure` makes the figure of a plot, and the notes on what the figure could not
carry (one sentence each), by these rules. The figure keeps the plot's `id`, `enabled`,
`title`, `ref`, `window` and `selection` (`"default"` stays `"default"`).

| Figure field | Taken from the plot |
| --- | --- |
| `aesthetics` | the plot's, remapped as [above](#looks-on-retired-roles) |
| `style` | the plot's, with `MaxTiles`, `TileSpacing`, `XLim`, `YLim` and `CLim` back at their defaults (a figure does not use them). `YLim` goes to the data panel's `options.yLim` (a PSTH, continuous, waveforms, rate or tuning panel) and `CLim` to its `options.cLim` (a heat map, probe map or correlation map); one that no panel of the figure takes is a note |
| panels' `options` | the plot's `bins`, `measure`, `baseline`, `auroc`, `maskAfterStop` and `waveform`, in every panel whose type has them (a waveforms panel's `mode "off"` as `"both"`; but the aux panel and a raster under a PSTH with an inset, below). The auROC baseline is carried, with its `auroc` settings, for a PSTH or a heat map of spikes; a rate or tuning plot takes only `none`, `subtract`, `ratio` and `zscore`; a mode the panel cannot take becomes `none`, with a note |
| `observe` | below. The plot's `source` (`units` or `detected`) is the layers' source and, for a figure drawn per unit, `observe.data`; its unit filter is `observe.units` when the figure observes units, else the fixed layer's `units` |
| `grid` | one column, a row per panel top to bottom; `spacing "none"` (flush) for a unit's raster, PSTH and aux panels |

The panels, by plot kind (the second column is what the figure is drawn for,
`observe.data`'s kind; the third its panels, top to bottom, and their layers):

| Plot kind and layout | Observe | Panels and layers |
| --- | --- | --- |
| `psth`, grid | unit (`data` = the plot's `source`, the `units` filter) | a raster (when `withRaster`; its sort options; `rasterEvents` as events layers drawn as marks) over a PSTH (`histStyle`, `fill`, `fillAlpha`, `normalize`, `stack`, `stackSpacing`, `yLim`), each with a layer following the unit; equal heights (with an aux panel, the unit's panels are twice as high as it: 2 : 2 : 1) |
| `psth`, overlay | dataset | one PSTH panel with a fixed `units` layer (the filter) and `aggregate "mean"` |
| `raster` | unit | a raster panel with the marks layers |
| `evoked`, grid | channel (`data` = the plot's `source`, `channels` = the plot's) | one continuous panel following the channel |
| `evoked`, stack | dataset | a continuous panel with a fixed layer of the channels, `aggregate "each"`, `display "stacked"`, `stackSpacing` = `Style.StackSpacing` |
| `evoked`, butterfly | dataset | as the stack, `display "lines"` |
| `heatmap` | dataset | a heat map panel with a fixed layer (the units filter, or the channels), its `order` (modulation included), `group` 1, `cLim` |
| `probemap` | dataset | a probe map panel with a fixed layer, `value`, `cLim` |
| `corrmap` | dataset | a correlation map panel with a fixed layer, `metric`, `correlation`, `fisherZ`, `group` 1, `cLim` |
| `waveforms`, grid | unit | a waveforms panel with a layer following the unit, `layout "grid"`; its `waveform` = the plot's waveform settings |
| `waveforms`, probe | dataset | a waveforms panel with a fixed layer, `layout "probe"` |
| `rate` | unit | one rate panel with a layer following the unit; `display` = the plot's layout (`bar`, `box` or `points`), `measure`, `baseline`, `YLim` as `yLim` |
| `tuning`, grid | unit | a tuning panel with a layer following the unit; `param` and `seriesParam` |
| `tuning`, overlay | dataset | a tuning panel with a fixed `units` layer (the filter), `aggregate "mean"`, the waveform inset off; `param` and `seriesParam` |
| `behavior` | none | not migrated (no panel type draws it): a warning |

No plot kind drew what a [spectral panel](#spectral-panels) does, so the migration makes
none. A PSTH's or raster's **aux signal** (`aux.mode` not `off`) becomes a continuous panel
of a fixed `AUX` layer below the unit's panels (above them for `placement "above"`), half
as high as each of them: `"channels"` is `aggregate "each"`, `"magnitude"` is
`aggregate "mean"`; the aux `baseline`, `statistic`, `transform`, `errorType` and `yLim`
become that panel's options (not the plot's baseline); `channels`
and `display` carry over. A PSTH with a waveform inset keeps it in the PSTH panel (the
raster, which would otherwise draw it too, keeps its inset off and takes only the
plot's `maskAfterStop`).

**Text note and overlays.** Both go to the panels they belong to (a panel holds its own
[`note`](#panel-fields) and `overlays`). The plot's **text note** goes whole, with its
placement, to the panel it borders: `"below"` to the bottom panel, `"above"` to the top one,
and any other placement (right, left, over the plot, custom) to the data panel, the first
panel that is neither a raster nor the aux signal's panel (panel 1 when there is none). A
figure of several panels says where it went (`The text note went to panel 2 of 2
(psth): a figure's notes belong to its panels.`). The plot's **overlays** go by their
`panel`: `"raster"` to the raster panel, `"data"` to every panel but the raster and the aux
signal's, `"all"` to every panel; each copy has `panel` `"all"`, as every overlay of a panel
does, and is drawn on that panel's axes in the same units. An overlay that names a panel the
figure lacks (a `"data"` overlay on a raster plot, a `"raster"` one on a PSTH without its
raster) is not carried: one note counts them.

**Notes.** What the figure does not hold gives a note, one sentence each:

- a baseline mode the panel cannot take (`zscore` or `percent` on a continuous or
  correlation panel or a heat map of a signal; `auroc` or `percent` on a rate or
  tuning panel) becomes `none`;
- the aux magnitude became the mean of the AUX channels;
- an aux `placement "over"` (on the right y axis) becomes `below`;
- the aux heat map display becomes `lines`;
- the aux `colorBy` and `byGroup` are not carried (the panel colors its traces by
  trial group, one trace each);
- `stackRaster` (each group's raster in its PSTH row) is not available: the raster
  is a panel of its own above the stack (given only when `stack`, `stackRaster`
  and `withRaster` are all on with the grid layout);
- an overlay's `withRaster`, event marks and waveform inset are not carried (an
  overlay of several units draws none);
- a tuning overlay's waveform inset is not carried;
- event marks of a plot without a raster (`withRaster` off) are not carried;
- a butterfly's one panel per trial group is not available: the channels are lines
  in one panel;
- a heat map or correlation map draws one trial group (group 1) when the selection
  groups its trials, where the plot drew one per group: set the panel's group, or
  add a panel per group;
- `MaxTiles`, `TileSpacing` and `XLim` are not used (a figure draws one observation
  per page, takes `grid.spacing` and shows the epoch window), nor are `YLim` and
  `CLim` when no panel of the figure takes them;
- a text note of a figure of several panels went to one of them (`The text note went
  to panel 2 of 2 (psth) ...`);
- overlays that name a panel the figure lacks (`1 overlay(s) not carried: the figure
  has no panel of the kind they name.`);
- the retired roles of the looks ([above](#looks-on-retired-roles)) and, for a session plot,
  the three `sessions` notes above.

Every figure the migration makes validates (`test_ConfigMigration` checks it for each kind
and layout), apart from what the plot itself held that was invalid.

## Export

| Field | Default | Meaning |
| --- | --- | --- |
| `Enabled` | `true` | write figure files (the runner's default for `run(Export=)`) |
| `Formats` | `["png" "svg"]` | any of `png`, `eps`, `svg`, `pdf` |
| `Folder` | `{OutputFolder}\analysis` | a [folder pattern](#file-name-tokens) |
| `FilenamePattern` | `{Name}_{Plot}` | a [file-name pattern](#file-name-tokens): `{Name}` (dataset) `{Plot}` (the figure's id) `{Kind}` (`figure`) `{Group}` `{Unit}` `{Index}` `{Date}`. A [figure](#figures) writes a file set per observation: [below](#figures-in-an-export) |
| `Dpi` | 150 | PNG resolution |
| `FigureSizeCm` | `[18 12]` | figure size `[width height]`; a figure's page is made taller when its rows need it: 3.5 cm for each row of its arrangement plus 2 cm |
| `Overwrite` | `true` | `false`: an observation (a figure's page) whose files all exist is not written again, nor drawn unless the report needs its image (HTML) or page (PDF); a session figure's data file is not replaced either (a note in the row's message) |
| `SessionsFolder` | `{OutputRoot}\analysis\sessions` | where the [session figures'](#session-figures) pages go: a [folder pattern](#file-name-tokens) whose tokens are the first session's (`{OutputFolder}` is one dataset's folder, so a warning there). Named with `FilenamePattern`, `{Name}` being the facet (`all`, or the subject) and `{Plot}` the figure's id, then `_<trial group>` for `trialGroups "each"`; a session figure adds `_<Unit>` per observation (`site_ch7`, a mapping cell, `ch7`) as a figure does |
| `Data.Enabled` | `false` | write each session figure's data as a `.mat` file in a run ([format](file-formats.md#session-figure-data-mat)); the only data export: there are no per-session data or epoch tables |
| `Data.Folder` | `{OutputRoot}\analysis\data` | a folder pattern, as `SessionsFolder` |
| `Data.FilenamePattern` | `{Name}_{Plot}` | a [file-name pattern](#file-name-tokens); `{Name}` is `all`, `{Plot}` the session figure's id (`{Kind}` is `figure`); `.mat` is added. One file per session figure holds every facet, trial group and observation |
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
| `{Group}` | `all`; for a [per-group](#panel-types) figure's observation (`observe.perGroup`), the trial group's label |
| `{Unit}` | the observation's short label: a sorted unit's label before the recording suffix (`su12` of `su12_RAT1_260918T1015`), a detection's whole label (its channel's name, `Shank_1`), else `u<unitId>`; a channel `ch<N>`, `N` its recording channel (an AUX channel: its label); the dataset `dataset` |
| `{Index}` | the observation's number, 1 to the count |
| `{Date}` | today (yyyyMMdd) |

- A figure has no `_p<page>`. When it has more than one observation and the
  pattern names neither `{Unit}` nor `{Index}`, `_<Unit>` is added to the name, so
  the default `{Name}_{Plot}` writes `SYNTH-01_..._card_su12.png`,
  `..._card_su14.png`, ... A one-observation figure, such as a dataset figure,
  keeps `<Name>_<id>.png`.
- A per-group figure has an observation per unit and trial group. When the
  pattern names neither `{Group}` nor `{Index}`, `_<Group>` is added after the
  unit's: `SYNTH-01_..._card_su12_<group>.png`, ... (the group's label, with
  every character outside `A-Z a-z 0-9 _ - .` replaced by `_`, as in every
  token). A pattern that names `{Group}` but not `{Unit}` or `{Index}` gets
  `_<Unit>` after it, as any figure with several observations.
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
| `IncludeParameters` | `true` | HTML: each figure's parameters, folded |
| `IncludeConfig` | `true` | HTML: the config JSON at the end, folded |

A [figure](#figures) is one entry per dataset in the report, kind `figure`,
whatever its number of observations: its pages are the observations, one image
(HTML) and one page (PDF) each, in the order of `figureObservations`, under one
caption from `figureCaption`. The caption names the figure (and its title), how
many observations of what it was drawn for (sorted units and the classes the
filter keeps, detections, the extract's channels, or the dataset), the panel
types in order, and, when a panel with an enabled layer is aligned, the event,
the window and the trial grouping (and `one figure per trial group` for a
`perGroup` figure, whose observations are then the units and groups), for example:

> rp: 12 observations (sorted units: su, mua) of RAT1_260918; panels: raster,
> PSTH; aligned to Stim onset; window [-0.2 0.8] s; groups by Depth.

The entry links the exported files and, with `IncludeParameters`, folds the
figure's resolved spec under it. A figure the dataset cannot draw (or that fails)
is listed with its status and message. A [session
figure](#session-figures) is an entry of the *Across sessions* section instead,
one per facet and trial group, its pages the matched observations
([what a run writes](#what-a-run-writes)).

## File-name tokens

`figureFileName` fills the patterns, of two kinds:

| Pattern | Tokens |
| --- | --- |
| folder (`Export.Folder`, `Report.Folder`) | `{OutputFolder}` (the dataset's output folder), `{OutputRoot}`, `{Root}` (`Source.Root`), `{Name}` (the dataset), `{Date}` (yyyyMMdd) |
| file name (`Export.FilenamePattern`) | `{Name}` (the dataset), `{Plot}` (the figure's id), `{Kind}` (`figure`), `{Group}` (the trial group's label of a per-group observation, else `all`), `{Unit}` (the observation's short label: `su12`, `ch7`, `dataset`), `{Index}` (the observation's number), `{Date}` (yyyyMMdd): `figureOutputName` fills them |

- `{OutputRoot}` is `Source.OutputRoot`, else `Source.Root`, else the
  folder above the first dataset's output folder.
- In a file name, every character of a token's value outside
  `A-Z a-z 0-9 _ - .` becomes `_`; the path tokens of a folder are used as
  they are.
- A figure has a file set per observation and no pages: when it has several
  and the pattern names neither `{Unit}` nor `{Index}`, `_<Unit>` is appended,
  and `_<Group>` after it for an observation of one trial group when the pattern
  names neither `{Group}` nor `{Index}`
  ([Figures in an export](#figures-in-an-export)).
- An unknown token is `figureFileName:UnknownToken`; a brace without its
  pair, or a file name holding `\ / : * ? " < > |`, is
  `figureFileName:BadPattern`.
- A report over every dataset with `{OutputFolder}` in its folder goes to
  the first dataset's folder (a validation warning).
- `Export.SessionsFolder` and `Export.Data.Folder` are folder patterns too,
  with the first session's tokens. A [session figure's](#session-figures) pages are
  named as a figure's observations are (`figureOutputName`), with `{Name}` the facet
  (`all`, or the subject), `{Plot}` the figure's id and `{Unit}` the observation:
  `site_ch7`, a mapping cell's name, `ch7` or `dataset`; a trial group of `trialGroups
  "each"` is added after it as `_<group>`. Its data file is `all_<id>.mat`.

With the defaults, the figure `unit_card` of dataset `SYNTH-01_260918_101500` with
20 units is written as
`<output folder>\analysis\SYNTH-01_260918_101500_unit_card_su1.png`,
`..._su2.png`, ... (and `.svg`), and the report as
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
| Defaults, Figures | the event reference, window and selection are valid: known values, `n` a whole number >= 1, `0 <= minDurationSec <= maxDurationSec`, `timeRange` ordered, a finite `offsetSec`, `offsetParamUnit` ms or s, each sequence step's relation, line, edge, `n`, positive `maxGapSec` and lengths, an `alignStep` of 0, `Inf` or a followedBy step (the stop's and each raster-mark sequence's too), finite `pre` and `post`, `pre <= post` in a fixed window, a stop event in a `"between"` window, known response words and pairing flags, at most 2 distinct `groupBy` parameters, `maxGroups` and `trials` whole numbers >= 1 | error |
| Defaults, Figures | a filter that does not parse | warning (it is checked against each dataset's trials when it runs) |
| Figures | at least one figure or session figure enabled (`No figure is enabled.`); the figure id is not empty, file-name safe and distinct once sanitized from the other figures' (`{Plot}` fills the files' names, case-blind); the figure's alignment is valid; `observe` (`data`, channels, `maxUnits`; on a figure that observes units, an enabled `units.response` test at `<figure>.observe.units.response.<field>` and each spike layer's at `<figure>.<panel>.layers(<j>).units.response.<field>`: the test, `param` for tuning / either / both, ordered `baseline` and `window`, direction, correction, `alpha` in (0, 1], the `"auroc"` test's settings and the Statistics and Machine Learning Toolbox the tests need), `sessions` (the known values, `minSessions`; with `sessions.enabled` no probe map, unit correlation or spectral panel, no auROC baseline, a mapping file for `match "mapping"` and a unit observation for it: [rules](#validating-session-figures)) and `grid` (rows, columns, relative sizes, spacing, gap units, gaps) hold known values; each panel has an id of its own, a known type, a place inside the grid that no other panel overlaps, a size in (0, 1] each way and an alignment, and its own `ref` / `window` / `selection` only when its type is aligned; each enabled layer's source, binding, aggregate, channels, events (`eventsAs`, event reference, marker, size, a span's look; only events layers on an event-trace panel) and line style fit its panel type; a raster has rows, not marks or spans alone; each type's options; the style ([rules](#validating-figures)) | error |
| Figures | no panels; cells no panel covers; a panel with no enabled layer, or with several on a type that draws one; a unit or channel observation with no layer following it; a session figure's `datasets "list"` with no keys, `showMembers` with `series "session"`, `trialGroups "pool"` over grouped trials, `"combine"` over PSTH bars, a heat map of trials ([rules](#validating-session-figures)); `observe.perGroup` while the figure's selection groups by nothing (not on a session figure); a signal layer following another signal's channel; a waveforms panel in the probe layout whose first layer follows the observation; a fixed raster, PSTH, rate or tuning layer that may keep more than 8 units; a layer, mark, style, note or overlay color that is not a color; two overlays of a figure with one name ([rules](#validating-figures)) | warning |
| Export | formats are png / eps / svg / pdf (and at least one when enabled); `Dpi` positive; `FigureSizeCm` two positive numbers; the folder and file-name patterns use known tokens, and the file-name pattern is not empty; `SessionsFolder` and `Data.Folder` are folder patterns, `Data.FilenamePattern` a file-name pattern, and `Data.MatVersion` is `-v7.3` or `-v7` | error |
| Export | a file-name pattern without `{Plot}` while several figures are enabled (every figure's `{Kind}` is `figure`, so only `{Plot}`, the figure's id, tells their files apart); neither the folder nor the file-name pattern names the dataset (`{OutputFolder}` or `{Name}`), unless the source is a single folder: files that would overwrite each other | warning |
| Export | `{OutputFolder}` in `SessionsFolder` or `Data.Folder`: it is one dataset's folder, so the session figures' files go to the first dataset's | warning |
| Report | Format html / pdf / both, EmbedFormat png / svg, `Dpi` positive, a plain `FileName`, the folder pattern | error |
| Report | `{OutputFolder}` in a report over every dataset | warning |

Whether a dataset can draw a figure (units, signals, trials, lines,
parameters, a probe) is not a config error: the runner skips that figure on
that dataset and says why ([Observations and skip reasons](#observations-and-skip-reasons)).

## Tests

`test_EphysAnalysisConfig`, in nine sections: the defaults (config version 2: no `Plots`
or `SessionPlots`) and the JSON round trips (`Inf`, `NaN`, empty and one-item lists, the
`"default"` sentinels, a heterogeneous `Figures` array, event sequences on the defaults, in
a figure and in an events layer, the order of `toStruct`); figure ids (auto ids,
`DuplicateFigureId`); every validate rule of Source, Defaults, Export and Report (ids and
patterns whose files would collide included) and "No figure is enabled." (a session figure
counts, nothing else does); the `units.response` test on a figure's observed units and its
layers (every message, at `<figure>.observe.units.response.<field>` and the layer's, and none
for a figure that observes channels); the event sequences; the session figures' rules
(`Figure.sessions`: the default block raises nothing, each enumerated value, `minSessions`,
a mapping file missing, absent or lacking a listed key's column, `match "mapping"` on a
channel figure, a probe map panel and an auROC baseline, the warnings); `LoadWarnings`
(a version-2 file holding `Plots` or `SessionPlots`: unknown top-level fields) and
`BadSchema` (another schema, version 3, no version); a version-1 file migrated on load (its
plots and session plots as figures of the same ids, the converter's notes as
`LoadWarnings`, saved as version 2); and `figureFileName`.

`test_EphysAnalysisFigures`, in ten sections. Config (1 to 6): the defaults of
Figure, Panel, Layer and Observe (no options block in a figure, `panels` after `grid`;
`selection` after `window`, then `layers`, `options`, `note` and `overlays` last in a panel; `defaults("FigureCommon")` a `BadSection`;
the continuous `trials` and `maxTrials` (100), the heat map's `rows` and raster sort fields and `observe.perGroup`);
`panelTypes` (thirteen types, with the rate, tuning, spectral and event-trace rows' flags and the event-trace options), `sourceCategories`,
`categoryOf`, `observeKind` (of each `ObserveData` value), `followedData`, `defaultLayer` (an unknown type is a `BadValue`),
`sharedFieldsOf` (none for a waveforms panel or a spectral type); `addFigure`'s templates (the `"rate"` and `"tuning"` ones
included), ids and the data each observes (given, or its following layers'), the [automatic ids](#figure-ids)
(`Short` per type; grid order, the data after the types, inactive panels and event marks left out; following a type change and
`observe.data`; kept under `autoId` false and given back when it is true again; *(2)*, *(3)* by the next free number,
compared as `{Plot}` writes ids, and kept when an earlier figure is renamed; `duplicateFigure` of an automatic id and of one's
own; the save / load round trip) and `figureFor`'s resolution (the defaults, a panel's
own `ref` or `window`, `sharesTime`, `units.source`, the observe kind, options
completed and re-seeded by a type change, each panel's own bins, baseline,
auROC and waveform, a waveforms panel's own mode `both`, its `layout`, a panel's `"default"` selection resolved to the
figure's and its own kept, with time still shared); the JSON round trip (every panel type,
relative sizes, an events layer with a sequence, fixed and following layers, the
`"default"` sentinels, no `"common"` in the file, `perGroup`, a panel's own
selection, a continuous panel's `trials` and `maxTrials` and a heat map's `rows` and sort, a cell
`Figures` from `jsondecode`, a config without `Figures`, unknown fields in
`LoadWarnings`); `adoptPanelOptions` (the shared options across types, the rest to a panel of the
same type, a baseline mode the type does not take kept, what changed, and nothing on a second
call), `adoptPanelAlignment` (a panel's own selection becomes the figure's)
and `relinkPanels` (their results and `NoPanel`); `placePanel` in four directions, `removePanel`
(undoing each exactly), `movePanel` and `figureCells`; `DuplicateFigureId` and
`DuplicatePanelId`; every validate rule of figures (only the known layer sources and
panel types; a PSTH's baseline
mode (no `ratio`), `auroc` windows and positive `stackSpacing`; a heat map's
`modulation` order and the auROC baseline of a signal layer; a waveforms
panel's `layout` and the probe layout's warning; a rate panel's `display`,
`measure`, baseline mode and `yLim`; a tuning panel's `seriesParam`, `param`
and waveform; a `"between"` window on a rate and a tuning panel; a
PSTH's auROC windows against its bins; a continuous panel's `trials` and
`maxTrials`; a heat map of trials, which may follow the observation (but not through a channel), must hold one unit and no signal
layer or auROC baseline and needs its sort event; a panel's own selection checked as the figure's and
refused on an unaligned type; the `perGroup` warning; a panel's note (placement, alignments, interpreter,
rotation, font size, a color; a custom place's `x`; no text, no check) and overlays (a line's position, a
region's edges, axis, layer, line style and width, opacity, a color, a name shared anywhere in the figure; a
custom note's message naming the panel; a panel of an unknown type still checked) at
`<figure>.<panel>.note.<field>` and `.overlays(<k>).<field>`, and an overlay's panel forced to `"all"`
with no panel warning), a note completed from the defaults by `normalizePanel`, a panel's note and
two overlays through a save and a load,
and the style messages
(`checkStyle`). Compute (7), on the analysis
fixture: `figureObservations` (the filter's units in probe order, a tightened
filter, an LFP figure's channels, a dataset figure's one row, and with `perGroup` a row per unit and trial
group, in the unit's order, with `group` and `groupLabel`) and
`computeFigure` (the raster over PSTH of one unit, an LFP layer following the
unit, a fixed AUX layer averaged, an AUX layer following the unit skipped with
its reason, three fixed units averaged, events as marks and as a train, a
panel's own window, a channel observation, probe map, correlation map
and waveforms, a rate panel and a tuning panel equal to `firingRate`'s and
`tuningCurve`'s of the unit (the tuning parameter from `groupBy`, else the first
numeric one; a series and the waveform inset; a missing parameter skipping the
panel, in `figureSkipReason` too), a rate layer of three units' mean, an auROC PSTH equal to `spikePSTH`'s, a stacked PSTH, the waveforms probe layout with
a following layer to ring, a layer skipped while its panel is drawn, `PollFcn`
and cancel, and one observation computed faster than `spikePSTH` over every unit;
per-trial continuous traces, every epoch's with their epochs and groups and averaging to the group's
mean, and `maxTrials` (default 100) picking evenly; a heat map of trials, each row the raster binned by hand, each
group's rows averaging to its PSTH, also under `maskAfterStop` with the stop inside a bin, a layer that
keeps two units skipped with its reason, the trains the rows were binned from not kept in the result, in a raster's
sort order; a PSTH on a selection of its own, with its
own epochs and one group beside the raster on the figure's; a per-group observation keeping its group's
epochs only, equal to that group's PSTH, while a panel with a selection of its own is not cut, and one
whose group has lost every epoch drawing with `F.skip` and the panels' notes instead of failing; the
groups `perGroup` lists agreeing with those compute reads, after the panels' baseline hull).
Render (8):
`figureArrange` (exact gaps in px, % and per gap, the presets, rows and columns in exact proportion, spans, a panel's size and
alignment in its cell, a note band, a phase strip, the title's and legend's bands), the layout drawn (flush with `"none"`, a
custom gap exact in px and %, rows 1 : 2, a panel half its cell's width keeping its tick labels, the legend east of the
panels, the title over them, laid out again on a resize), a compute and a draw function for every panel type, every type
drawn into an axes, uiaxes, figure, panel and grid layout with every component
tagged, the titles, one time axis down a stack, one legend, skipped layers'
notes, events as marks, latency lines and a rug, a stacked PSTH (a row and a
baseline per group, the legend's groups once, one group overlaid, a second
layer in the rows), an auROC PSTH (a 0-1 axis, the chance line, the modulation
window, the calls; stacked too) and heat map (the diverging colormap, 0-1),
rate panels (bars, boxes of two layers, points), tuning curves (a series, the
inset), the waveforms probe layout with the observed unit framed, faint and only trial traces (a
`trialTrace` line per group, no mean or band for `only`, the legend's groups), a heat map of trials (a row
per epoch in its order, the group strip, the `Epoch (by ...)` label), a panel on a selection of its own
(titled `all trials`, its own legend inside it, the figure's legend the raster's groups), a per-group
figure's title, a panel's note and overlays (a note below a panel in a hidden `noteHost` band under
its axes, as wide, in its own color; one at `"northeast"` in its axes; a region on the raster and a line on the PSTH, the
figure's rule winning over the overlay's opacity; every one a tagged component of its panel's tile; the raster
still sharing the time axis over a note band; a band below keeping the axes' left edge and width of the plain panel
under it; a band right of a panel leaving it narrower, so both panels keep their time tick labels; a four-line note at
14 pt fitting its band; a note turned 90 degrees with `valign` top right-aligned along y at the band's top; into one
axes the first panel's note and overlays in it; a patch over the raster's opaque bands seen by its pixels, one under
them not, patches following the limits; a raster's y ticks hidden by default and back with `yTicks`; a panel's `box`
winning over a design's and the figure's own Box rule), and the
editing hooks (`Editable`, `OnRemember`, the redraw), and the data tips (`DataTips`: a PSTH line's rows, a raster tick's trial and group, heat map cells, a bar; the chosen fields followed on refresh; `DataTipFieldsDialog`; the time they add). Compute (7) also checks `figureCompute`
against `computeFigure` (equal results, `Check=` called at the checkpoints and
what it throws stopping the compute), `figureOutputName` (`{Plot}`, `{Unit}`,
`{Index}`, `{Group}`, the `_<Unit>` and `_<Group>` suffixes, the short labels of units, detections and
channels) and `figureCaption` (`one figure per trial group`). Render (8) also checks that the trial
traces of a continuous panel are drawn under each mean. Spectral (9) is in two parts. The config side needs no
Chronux: the three templates validate clean, and validate refuses a coherence panel with one layer, a
bad taper (`TW = -1`), a spectrogram baseline window outside the panel's window, a spectrogram of
events marks only and a range spectrum with a segment of 0, accepts a coherogram of spikes, a spectrogram
of units, a `zscore` spectrogram baseline and a `"between"` window on the range base, and `figureFor`
gives `sharesTime` to a spectrogram and to a coherogram only.
With Chronux on the path (`toolboxes/chronux`, added for the section; skipped with a note without it) the
section computes, on section 7's fixture, a spectrum of the observed unit's LFP channel and of the unit, a
spectrogram, coherences LFP x LFP, spike-field and unit-unit, and the range time base, draws them (dB, a
spectrogram on the raster's time axis, the phase axes, every role known, a coherence in one axes with no
phase strip), and checks the skip reason with Chronux off the path. Session
figures (10), on two synthetic sessions: the figures listed apart
(`enabledFigures` leaves them out, `sessionFigureIds`, `isSessionFigure`),
`figureSessionObservations` by site (each session's units on the channel,
`minSessions`) and by mapping file (a row per cell, `unitIds`, `present`),
`computeSessionFigure`'s raster and PSTH merged over the two sessions (a series
per session, equal to each session's own PSTH, every epoch kept) and rendered
(title, roles, legend), `series "all"` with its faint member lines,
`trialGroups "combine"` told apart by line style, a continuous figure by channel,
a facet per subject with a figure per trial group, a probe map panel (a validate
error, the panel skipped with its reason, the rest drawn), `figureSessionSkipReason`
and events drawn as marks skipped across sessions.

`test_ConfigMigration` (replaces `test_plotToFigure`), in ten sections, on hand-made version-1
configs: a PSTH grid with its raster, event marks, waveform inset and aux magnitude, field by
field (observe, panels, layers, options, style, notes); the PSTH variants (without
its raster, an overlay, stacking and an auROC baseline carried with `stackRaster` as the one
note, a raster with its aux above, and `"over"`); a raster; evoked grid, stack and
butterfly; heat maps of units and of LFP, a probe map and a correlation map; unit waveforms
in a grid and on the probe; rate (its layouts as the display, the measure, a ratio baseline,
`YLim`, a `"between"` window) and tuning (a grid, and an overlay with its inset as a note,
`param` and `seriesParam`); a behavior plot and a kind version 1 did not have not migrated
(a warning each), the ids (the plot's own; `_2` for one taken by a figure of the file or an
earlier plot, case and `{Plot}`'s sanitizing ignored), the first `LoadWarnings` line and its
counts, `"default"` sentinels kept and a plot's own alignment carried, the text note carried
to the panel it borders (below to the bottom one, above to the top one, else the data panel,
saying which) and the overlays to the panels they name (an overlay on `"raster"` to the
raster, on `"data"` to the PSTH, on `"all"` to every panel; one naming a panel the figure
lacks a note; a note placed right on a three-panel figure with an aux panel going to panel 2,
and a `"data"` overlay skipping the raster and the aux panel), `MaxTiles`, `TileSpacing`,
`XLim` and an unused `YLim` as notes, and every migrated figure validating. Session plots
become session figures: the base plot's panels with the session plot's layout, the `sessions`
block from its fields, `match "pool"` as `"site"` (a note for a unit observation), `match
"mapping"` on a channel or dataset observation as `"site"` (a note, the mapping file
cleared), a `data` list other than `"results"` a note (none for an empty list), its title and
looks; one without its base plot (an id-less one `sessions_1`) or with a behavior base not
migrated. Looks: `auxTrace` / `auxSem` / `auxAxes` become `trace` / `sem` / `axes` and rules
on roles no figure draws are dropped, a note each. Last, a version-1 file loaded from JSON and
saved as version 2 (version 3 is `BadSchema`), and, on the analysis fixture, a migrated PSTH
with its raster, Stim offset marks and aux channels computing and rendering for one unit.

`test_copyFigureSettings` (no fixture): `figureSettingParts` (the parts `observe`,
`alignment`, `arrangement`, `style`, `looks` and `sessions`, each with its fields,
label and description) and `copyFigureSettings` (the arrangement carrying the grid's gaps and a
panel's own size and alignment; each part alone with its fields copied and
the rest, the id, title and `enabled` kept; every part by default; two parts copied in the
table's order; a copy that validates; `copyFigureSettings:BadPart` for an unknown part).

`test_EphysAnalysisRunner`, in ten sections (0 to 9), runs figures through the runner on a
small synthetic project: `plan` rows (Kind `figure`, Source `unit`, `channel` or `dataset`,
`Figures=` with `string.empty(1, 0)` for none, skip reasons from cheap facts, no bulk data
loaded); `run` (a row per figure with `<n> observation(s)`, a PNG and SVG file per
observation named `<Name>_<figure>_<unit>.png` and a one-observation dataset figure
`<Name>_map.png`, no figure left open), the HTML report with embedded PNGs and the PDF
(title, summary and figure pages in order), made from the pages as they were drawn, with
percent-encoded links, and the run record (schema `ephys-analysis-run/2`: `figures` and
`sessionFigures`); `Overwrite` off; `run(Figures=)` alone; `cancel()` between a figure's
observations and from inside a compute; script equivalence (the compact and the standalone
script, `fspec<k>`, `figureCompute` and no runner, no syntax error, their PNGs pixel-identical
to the runner's and an equal HTML report and PDF pages); a failing export closing its page
in the runner and in the script; unit waveforms (templates without the sorted `.bin`, spikes
cut from a planted one, detections' saved waveforms); a `perGroup` figure (a file per unit
and trial group, `<Name>_<figure>_<unit>_<group>.png`); a report per dataset (`PerDataset`);
and a [session figure](#session-figures) the same way: a config of one validates and is no
per-dataset figure; `plan` gives one `sessions: all` row; `run` writes a page per matched
site into the sessions folder (`all_<figure>_site_ch<N>.png`), leaves no figure open, adds
the *Across sessions* entry with its caption (and its own `<FileName>_sessions` report with
`PerDataset`) and lists `sessionFigures` in the run record; `Export.Data.Enabled` writes the
data file; `run(SessionFigures=)` alone keeps the files of `Overwrite` off; `cancel()`
between observations leaves the first page and a `canceled` row; and the standalone script
(`sfspec<k>`, `figureSessionCompute`, no runner) writes PNGs pixel-identical to the runner's.

`test_PlotAesthetics` and `test_PlotDesign` draw one figure per panel type and per layout that
matters (`figureTestCases`: a stack, the auROC baseline, waveforms on the probe, stacked
signals, boxes, a heat map of trials, notes and overlays, ordered groups, one group) with
`renderFigure`: every component tagged with a role the editor knows, the user's rules for a
panel's type and then the figure's own, the editor and the designs, which each draw every
panel type without a refused value; see [Analysis](EphysAnalysis.md#plot-aesthetics).

<!-- wiki
## Related

- [Analysis app](EphysAnalysisApp.md): the GUI that edits a config
- [Analysis scripting](EphysAnalysis.md): running configs from scripts, generated scripts, the functions
- [Pipeline configs](Pipeline-Configs): the pipeline config, whose project settings `Source` mirrors
- API: [EphysAnalysisConfig](API-EphysAnalysisConfig), [EphysAnalysisRunner](API-EphysAnalysisRunner), [Analysis functions](API-Analysis-Functions)
-->
