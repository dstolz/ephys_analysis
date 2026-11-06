# EphysAnalysisConfig

`EphysAnalysisConfig` ([source](../analysis/@EphysAnalysisConfig/EphysAnalysisConfig.m))
is a value class that describes a set of quick-look figures: which datasets
to read, how to align them, which multi-panel [figures](#figures) to
design for one unit, channel or dataset (and which to draw
[across sessions](#session-figures)), and how to export and
report them. `EphysFigGenApp` edits one, `EphysAnalysisRunner` runs one and
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
| `Figures` | struct array, one entry per [figure](#figures): one observation's panels (a unit, a channel or the dataset), each placed freely on the page. Its ids are unique among figures (`EphysAnalysisConfig:DuplicateFigureId`; a figure's panel ids `EphysAnalysisConfig:DuplicatePanelId`); a cell array (what `jsondecode` gives for figures whose fields differ) is accepted too. A run draws the enabled figures, a page per observation ([Export](#export), [Report](#report)); one with `sessions.enabled` is a [session figure](#session-figures), drawn once across the datasets instead |
| `File`, `LoadWarnings` | transient: where it was loaded from / saved to; the unknown fields `load` dropped |
| `Schema`, `Version`, `Sections`, `SpikeSources`, `SignalSources`, `FigureSources`, `ObserveData`, `WaveformLocations`, `PanelErrorTypes`, `ListFields` | constants. `Version` is 2 (a version 1 file is [migrated](#loading-a-version-1-config) on load); `FigureSources`: what a figure's layer reads, `ObserveData`: what a figure is drawn for (`observe.data`: `units`, `detected`, `LFP`, `MUA`, `SPIKE`, `AUX`, `dataset`); `Figures` is a list, not one of the four `Sections`. A PSTH's, rate and tuning panel's error (`PanelErrorTypes`: `off`, `sem`, `std`, `ci95`). The continuous panels' and notes' choices: `AuxStatistics`, `AuxTransforms`, `AuxErrorTypes`, `NotePlacements`, `OverlayLayers`, `OverlayLineStyles`. The [session figures'](#session-figures): `SessionSeries`, `SessionErrors`, `SessionTrialGroups`, `SessionFacets`, `SessionColorOrders`, `FigureSessionMatches` (`"site"`, `"mapping"`: a figure observes one matched unit, so no pooling) and `FigureSessionUnmerged` (the panel types that cannot be merged across sessions: `probemap`, `corrmap`, `spectrum`, `spectrogram`, `coherence`). The [probe figures'](#probe-figures): `ProbeLayouts` (`schematic`, `physical`), `ProbeOverlaps` (`nudge`, `lanes`, `shrink`, `allow`) and `ProbeTileLabels` (`short`, `full`, `none`). There are no plot constants (`Kinds`, `AuxModes`, `AuxPlacements`, `AuxDisplays`, `AuxColorBy`, `OverlayPanels`, `SessionKinds`, `SessionMatches`, `SessionData`): the plots are gone |
| `toStruct()`, `toJson()`, `save(file)` | plain struct; the JSON `save` writes (`Inf` / `-Inf` / `NaN` as `"Inf"` / `"-Inf"` / `"NaN"`) |
| `EphysAnalysisConfig.load(file)`, `fromStruct(s)` | version 2; a version 1 file (or struct) is [migrated](#loading-a-version-1-config) first. `load` errors `EphysAnalysisConfig:BadSchema` on another schema or any other version |
| `validate(CheckPaths=true)` | issues table `Section, Field, Severity, Message` ([rules](#validation)) |
| `addFigure(templateOrStruct, Id=)`, `duplicateFigure(idOrIndex)`, `removeFigure(id)`, `figureIndex(id)`, `figureIds()`, `enabledFigures()`, `sessionFigureIds()`, `enabledSessionFigures()`, `isSessionFigure(id)`, `probeFigureIds()`, `isProbeFigure(id)` | the figure list. `enabledFigures()` is the enabled figures a run draws per dataset and leaves out the [session figures](#session-figures) (a figure whose `sessions.enabled` is true); `sessionFigureIds()` lists those, enabled or not, `enabledSessionFigures()` the enabled ones (a run draws them across the datasets, after the datasets), and `isSessionFigure(id)` (an id or an index; false for an unknown one) tells. `probeFigureIds()` lists the [probe figures](#probe-figures) (`probe.enabled`), enabled or not, and `isProbeFigure(id)` tells likewise; `enabledFigures()` keeps them (a run draws them per dataset, a page each). `[cfg, id] = cfg.addFigure("rasterPsth")` (a template's name from `figureTemplates()`, or a partial figure struct) returns the new id too: an [automatic id](#figure-ids) (*Raster+PSTH units*) when none is given; `[cfg, id] = cfg.duplicateFigure(id)` copies a figure right after it as *&lt;id&gt; (n)*; `removeFigure` of an unknown id is `EphysAnalysisConfig:NoFigure`; `figureIndex` is 0 for one |
| `figureFor(idOrIndex)` | a figure with every `"default"` resolved and each panel's type facts and each layer's category added: what the compute draws ([Resolving a figure](#resolving-a-figure)). `EphysAnalysisConfig:NoFigure` for an unknown one |
| `isequalConfig(other)` | same values (NaN equal) |
| `defaults(section)`, `normalizeSection(section, s)` | static: the single source of truth for fields, types and shapes |
| `panelTypes()`, `sourceCategories()`, `figureTemplates()`, `categoryOf(source, type)`, `observeKind(fig)`, `followedData(fig)`, `autoFigureId(fig)`, `defaultLayer(type)`, `normalizeFigure(f)`, `normalizePanel(p)`, `normalizeLayer(L)` | static: the figures' tables and helpers ([Figures](#figures)). `placePanel`, `placeBlock`, `removePanel`, `orderPanel`, `freeRect`, `rectOverlaps` and `panelOrder` [place the panels](#placing-panels) |

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
              "Selection": "all", "Datasets": [], "Folders": [],
              "Filter": { "Subjects": "", "ExcludeSubjects": "", "Tags": "ofc", "TagMode": "any",
                          "ExcludeTags": "pilot", "Search": "" } },
  "Defaults": {
    "EventRef":  { "line": "Stim", "edge": "onset", "which": "first", "n": 1, "scope": "auto",
                   "minDurationSec": 0, "maxDurationSec": "Inf", "timeRange": ["-Inf", "Inf"], "offsetSec": 0,
                   "offsetParam": "", "offsetParamUnit": "ms" },
    "Window":    { "mode": "fixed", "pre": -0.2, "post": 0.8, "stop": [] },
    "Selection": { "filter": "", "response": [], "pairingFlags": "ok", "trials": [],
                   "groupBy": "Depth", "groupOrder": "ascending", "maxGroups": 100,
                   "excludeArtifacts": true, "minArtifactSec": 0 } },
  "Figures": [
    { "id": "unit_card", "autoId": false, "enabled": true, "title": "",
      "observe": { "data": "units", "units": { "classes": ["su"], "...": "..." }, "...": "..." },
      "layout": { "boxesMean": "plot", "padding": 0.15 },
      "ref": "default", "window": "default", "selection": "default",
      "sessions": { "enabled": false, "...": "..." },
      "probe": { "enabled": false, "layout": "schematic", "...": "..." },
      "latency": { "method": "first", "minSec": 0, "maxSec": "Inf", "...": "..." },
      "panels": [ { "id": "raster_1", "type": "raster", "rect": [0, 0.6, 1, 0.4], "...": "..." },
                  { "id": "psth_1", "type": "psth", "rect": [0, 0.3, 1, 0.3], "...": "..." },
                  { "id": "continuous_1", "type": "continuous", "rect": [0, 0, 1, 0.3], "...": "..." } ],
      "style": { "...": "..." }, "aesthetics": [] } ],
  "Export": { "Enabled": true, "Formats": ["png", "svg"], "Folder": "{OutputFolder}\\analysis",
              "FilenamePattern": "{Name}_{Plot}", "Dpi": 150, "FigureSizeCm": [18, 12], "Overwrite": true,
              "SessionsFolder": "{OutputRoot}\\analysis\\sessions",
              "Data": { "Enabled": false, "Folder": "{OutputRoot}\\analysis\\data",
                        "FilenamePattern": "{Name}_{Plot}", "MatVersion": "-v7.3" } },
  "Report": { "Enabled": true, "Format": "html", "Title": "{Name}",
              "Folder": "{OutputRoot}\\analysis", "FileName": "analysis_report", "PerDataset": false, "Order": "figure",
              "FiguresPerPage": 1, "PageSize": "letter", "PageOrientation": "auto",
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
| `Filter` | off | the analysis app's [Data tab filter](EphysFigGenApp.md#data-tab), saved so the config opens with it: `Subjects`, `ExcludeSubjects`, `Tags`, `TagMode` (`"any"` or `"all"` of `Tags`), `ExcludeTags` and `Search`, each text as typed (several values comma-separated; `""` = off), the options of [`datasetFilter`](../pipeline/datasetFilter.m). It only chooses which datasets the app's table shows: what runs is `Selection` and `Datasets`, and the runner and scripts ignore it |

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
string `"default"`. The app's [Alignment tab](EphysFigGenApp.md#alignment-tab)
edits them.

## Building blocks

`EphysAnalysisConfig.defaults("EventRef" | "EpochWindow" | "TrialSelection" |
"UnitSelection" | "Style" | "Auroc" | "Waveform" | "Latency" | "FirstSpike" | "LatencyBox" | "EventMark" | "Note" | "Overlay")`. The first three are described with their
constructors (`eventRef`, `epochWindow`, `trialSelection`, which build and
check one in a script) on the [Analysis page](EphysAnalysis.md#event-reference-window-selection);
what they mean in a config follows. The sections after [Style](#style) describe
the settings that figures and their panels share: stacks, y limits, the auROC
baseline, a raster's sort and event marks, the first-spike latency and
response onset (the figure's block; a raster's marks, a PSTH's box plot, the
onset lines), unit waveforms, aux signals, error bands, and a
panel's notes and overlays.

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
`groupBy` (0-2 trial parameters) with `groupOrder` and `maxGroups`, and
whether the epochs that touch an artifact period are left out
(`excludeArtifacts`, default true; only periods at least `minArtifactSec`
long count)
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
| `merge` | `enabled` false, `radiusUm` 50, `refractoryMs` 1.5, `flankMs` `[5 30]`, `minExpected` 20, `maxRatio` 0.25, `alpha` 0.001 | detected spikes only. With `enabled`, the channels of neighboring sites that hold one neuron's spikes are joined into one "unit" ([`groupDetected`](../analysis/groupDetected.m)); the Spikes step keeps a spike once (Coincidence) but the deepest site changes from spike to spike, so a neuron's spikes are cut between channels. Two sites within `radiusUm` are joined when the events of one that follow an event of the other by more than the Coincidence jitter and at most `refractoryMs` are fewer than `maxRatio` of the number the `flankMs` lags predict (the rates set that count), with at least `minExpected` expected and a Poisson p of at most `alpha`: a neuron has no two spikes that close, two neurons fire that close by chance. A joined group is one unit named for its channel with the largest mean waveform (`channel`, `unitId`, `label` with `+n` for the `n` channels joined) holding every spike of the group once; `ids`, `channels` and `shanks` see that channel. The unit table gains `nSites` and `sites` (`"3,4,12"`). Needs the Spikes step's `Coincidence` `"remove"` or `"tag"` (with `"tag"` the copies are left out first) and the Statistics and Machine Learning Toolbox |
| `quality` | `enabled` false, and [`unitQualityCriteria`](../pipeline/unitQualityCriteria.m)'s thresholds (`isiViolationsRatioMax` 0.5, `presenceRatioMin` 0.9, `amplitudeCutoffMax` 0.1; `snrMin`, `driftPtpMax`, `firingRateMin` off; `unknown` `"pass"`) | with `enabled`, only the sorted units that meet the criteria are kept: their quality metrics come from the dataset (`EphysDataset.unitQuality`; the recording's noise only when `snrMin` is set) or, without it, from the recording's length the source knows (no SNR), through the sort folder's `quality_metrics.json` when current. The units' metrics and `qualityPass` / `qualityFails` / `qualityUnknown` are added to the unit table ([Unit quality metrics](EphysDataset.md#unit-quality-metrics)) |
| `response` | `enabled` false, `test` `"evoked"`, `baseline` `[-0.2 0]`, `window` `[0 0.2]`, `param` `""`, `direction` `"any"`, `correction` `"bh"`, `alpha` 0.05, `auroc` (below) | with `enabled`, only the units that pass the test are kept ([response statistics](EphysAnalysis.md#response-statistics)), after the other fields and before `maxUnits`. The test runs over the figure's event reference and trial selection, on epochs of one fixed window that holds both test windows (those that leave the recording or touch an artifact period are left out). `test`: `"evoked"` (the response window's rate differs from the baseline window's, `signrank`), `"tuning"` (it differs across `param`'s levels, `kruskalwallis`), `"either"`, `"both"`, or `"auroc"`: the units the auROC calls modulated over `window` (`aurocCurves` over the same epochs, all of them one group; [auROC](#auroc)), with `auroc`'s `method`, `windows`, `windowSec`, `stepSec`, `binSec` (its own bins, 0.01), `cutoff` (`"ci"`, `"fixed"`, `"shuffle"` or `"test"`; not `"none"`), `threshold`, `test` and `nResamples`. `baseline` and `window` are s from the event. `param` is needed by `"tuning"`, `"either"` and `"both"`. `direction` (every test but `"tuning"`) is `"any"`, `"excited"` or `"suppressed"` (auroc: called up or down). `correction` is `"bh"`, `"holm"`, `"bonferroni"` or `"none"`, over the units tested. A unit passes when its adjusted p is at most `alpha` (auroc: when called modulated; `correction` and `alpha` serve its `"test"` cutoff). The unit table gains the test's columns: `baselineRate`, `responseRate`, `pEvoked`, `qEvoked`, `direction`, `responsive` and, with `param`, `nLevels`, `pTuning`, `qTuning`, `tuned`, `bestLevel`, `bestRate`; for `"auroc"` instead `aurocMean`, `aurocPhasic`, `aurocP`, `aurocQ`, `aurocDirection` and `aurocModulated`. Needs the Statistics and Machine Learning Toolbox |

### Style

| Field | Default | Meaning |
| --- | --- | --- |
| `LineWidth` | 1.2 | traces, PSTH lines and bar outlines |
| `ShowStop` | `true` | stop-event marks (mean per group; a dot per raster row) |
| `ShowZeroLine` | `true` | a dotted line at the event |
| `ShowArtifactNote` | `true` | a line under the figure's title when some of the drawn epochs touch an artifact period, which happens only with the trial selection's `excludeArtifacts` off: *"3 of 40 epochs touch an artifact period"*. When panels with epochs of their own count differently, each count names its panels (*"Epochs that touch an artifact period: 3 of 40 (raster_1, psth_1); 5 of 38 (psth_2)"*). Only the periods the selection counts (at least `minArtifactSec` long) are noted |
| `Colormap` | `"lines"` | group colors: `"lines"` keeps selectTrials' colors; any colormap name resamples them; a color name or hex code (`"black"`, `"#1f77b4"`) gives every group that color |
| `HeatColormap` | `""` | heatmaps, probe maps and unit correlations; `""` = parula, or `blueWhiteRed` for corrmap |
| `FontSize` | 9 | |
| `SiteSize` | 8 | probe map: the sites' marker size, points |
| `YLim`, `XLim`, `CLim` | `[]` | fixed limits (`[]` = automatic); two ascending values, low then high. A figure does not use them: each panel has its own `options.yLim` / `cLim`, and the time panels show the epoch window. The automatic color limits are the range of the map, `[0 1]` for an auROC heat map and `[-1 1]` for a unit correlation |
| `Grid`, `Legend` | `true` | |
| `LegendLocation` | `"auto"` | where the legend goes; it never shrinks a plot area. `"auto"`: in the figure's [legend panel](#panel-types) when it has one, else floating in the page's largest free space (`freeRect`) when the legend fits there, else inside the first panel; `"inside"`: in the first panel; `"none"`: no legend. A stacked PSTH has no legend |
| `LegendOrientation` | `"auto"` | the legend inside a panel or floating: `"vertical"` or `"horizontal"` entries (`"auto"`: vertical). A legend panel has its own `options.orientation` |
| `LegendBox` | `false` | the legend's outline and background |
| `MaxTiles` | 16 | not used by a figure (it draws one observation per page); a version 1 plot's value is reset to the default when it is migrated |
| `TileSpacing` | `"compact"` | not used by a figure: its panels are placed by their `rect` |
| `SortDepth` | `true` | units / channels with the top of the probe first (probe `y`); applies to every panel type but the probe map (rate bars, heat map and unit correlation rows, ...) |
| `SortShank` | `false` | units / channels grouped by shank first (ascending); with `SortDepth`, top first within each shank. Neither ticked: as listed |
| `LabelDepth`, `LabelShank` | `false` | append the probe depth (`y`, µm) and / or the shank to the unit / channel labels, e.g. `su3 (sh1, 640 µm)` |
| `StackSpacing` | `NaN` | not used by a figure: a panel that stacks has its own `options.stackSpacing` ([Stacks](#stacks)) |

### Stacks

<a name="stacked-psths"></a>

Every panel type that draws trial groups over one shared axis can draw them
stacked instead: one row per group, the first on top (as a raster lists its
groups), on the panel's one x axis. One vocabulary serves every such type
(`EphysAnalysisConfig.stackModes(type)`):

| Option | Default | Meaning |
| --- | --- | --- |
| `stack` | `"off"` | `"off"`: the groups overlaid (a heat map, spectrogram or coherogram: the one group `options.group` names); `"groups"`: a row per trial group, the first on top (a tuning panel: a row per series); a continuous panel also takes `"items"`: a row per channel (or layer mean), the groups overlaid in each row |
| `stackSpacing` | 1.1 | the row step as a multiple of the row height, the tallest row's reach (1: the rows touch; below 1 they overlap, the lower row in front); positive. An image row never overlaps: below 1 counts as 1 |

| Type | Stacks | How |
| --- | --- | --- |
| `psth` | `groups` | each group's PSTH from its own zero (bars or a line, its band); the groups' values on the left axis, each row's peak on the right. With `display "heatmap"` the stack is not used (the image has a row per group already) |
| `continuous` | `groups`, `items` | line rows: each row's traces, bands and (with `trials`) epochs; the rows named on the left axis, each row's top value on the right; y label `Channel (<height> <unit> per row)` (a stack of groups: the group-by parameters) |
| `spectrum`, `coherence` | `groups` | line rows, every item or pair overlaid in each; a spectrum's `scale "log"` draws log10 of the power in a stack (a log axis holds no offset rows); a coherence panel's phase strip stays overlaid |
| `tuning` | `groups` | a row per series (`seriesParam`), every item in each |
| `heatmap` | `groups` (rows `"items"`) | a block of the layer's units or channels per group, every block in the same row order and on one color scale; not used for rows `"trials"` (they list the groups in blocks already: a validation warning) |
| `spectrogram`, `coherence` over time | `groups` | an image row per group sharing the time axis, one color scale and one color bar for all, y label `<parameters> (<f1>-<f2> Hz per row)` |
| `raster`, `rate`, `waveforms`, `probemap`, `corrmap`, `eventTrace` | — | none: a raster lists its groups in blocks already and an event trace has a row per line; a rate panel puts its groups along x; waveforms and the probe map have no trial groups, and a unit correlation map is a units-by-units matrix (draw one panel per group with `options.group`) |

- **Line rows** (PSTH, continuous, spectrum, coherence, tuning): a thin gray line
  along each row (role `stackBase`; at the row's zero, else its bottom), the
  rows' names on the left axis (the group's value, `0.5` or `0.5, 1` for two
  `groupBy` parameters, the parameters naming the axis), each row's top value
  (a PSTH: its peak, also when `normalize` scaled the rows) on the right axis.
  A stacked line panel has a y axis on each side, so its `ySide` is not used;
  its rows' scale is its `yLimMode` ([Y limits](#y-limits): by default each row
  fits itself, *rows* puts them on one scale). Each group's mean
  stop event is a dashed mark in its own row; a second layer or unit is drawn
  into the same rows (a PSTH's as an outline).
- **Image rows** (heat map, spectrogram, coherogram): every group's image in a
  block of its own, each with a thin strip of its group's color at its left edge
  (role `rasterBand`, the groups in the legend), its name on the y axis and one
  color bar for all; `options.group` is not used.
- The groups' rasters are not part of a PSTH's stack: a raster panel above it
  shows them. A panel with one group is drawn unstacked.
- **Apply to all panels** copies `stack` and `stackSpacing` to every panel whose
  type takes them; a value a type does not take (a continuous panel's `"items"`)
  is kept out, that panel keeping its own. A panel type change keeps them where
  the new type takes the value.

### Y limits

Every panel type with a y axis of values (PSTH, continuous, waveforms, rate,
tuning, spectrum, coherence) takes `options.yLimMode`, one vocabulary
(`EphysAnalysisConfig.YLimModes`), with `options.yLim` the limits it uses when
`"fixed"`:

| `yLimMode` | Overlaid groups (one axis) | Stacked rows ([Stacks](#stacks)) |
| --- | --- | --- |
| `"auto"` (default) | the axis fits the data (the type's own range: an auROC and a coherence 0 to 1) | each row fits itself: scaled to its own reach, its top value on the right axis; y label `... (each row on its own scale)` |
| `"rows"` | as `"auto"` (the groups share the one axis already) | every row on one scale, the reach of them all; y label `... (<height> <unit> per row)` |
| `"batch"` | one range for every observation of a run of the figure | every row on that one range |
| `"fixed"` | `yLim` (`[lo hi]`, required) | every row's range is `yLim` |

**Batch.** A run of the figure (the Export tab's **Run**, the app's
**Generate selected figure**: `EphysAnalysisRunner.run`) measures a figure with a `"batch"`
panel before drawing it: every observation it draws, on every dataset of the
run, is computed and drawn hidden (`figureYExtents`: the panel's y extent, its
axes' automatic limits or a stack's reach), and the union of them
(`figureBatchYLim`, kept in `r.BatchYLim`: figure, panel id, `lim`, `n`) is the
range every page is drawn at (`renderFigure(..., BatchYLim=)`), so each unit or
channel is on the same scale across the whole run. A figure computed while
measuring is kept for its page while the kept ones stay under 512 MB, else it
is computed again. `runDataset` called alone measures its own dataset; a
session figure measures its matched observations (`runSessionFigure`). The
report's caption says `y shared across <n> observations` (`figureCaption`
`YShared=`). Drawn alone (the app's preview, `renderFigure` without
`BatchYLim`) a batch panel takes its own range, as `"rows"`, and the preview's
status line says the run shares it. Panels of the same figure are not put on
one scale with each other: they hold different units, channels or
quantities. **Apply to all panels** copies `yLimMode` to every panel that has
one (`yLim`, in the type's units, only to panels of the same type; a
`"fixed"` mode is kept out of a panel with no `yLim` of its own). Validate:
`yLimMode` one of the four; `"fixed"` needs `yLim`.

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
| `cutoff` | `"ci"` | how a unit is called modulated (up or down, per group): `"ci"`, the paper's: its mean auROC beyond 0.5 +/- the upper bound of the 95% confidence interval of the mean phasic modulation over every unit and group (it depends on the units in the figure and needs many of them; a warning says when it is too wide to call any; `populationAnalysis`, which takes these settings as its `Auroc`, pools every dataset's units for it: [population analysis](EphysAnalysis.md#population-analysis)); `"fixed"`, beyond 0.5 +/- `threshold`; `"shuffle"`, the rule of `"ci"` with a cutoff calibrated by shuffling: the `1 - alpha` quantile (the 95th percentile at `alpha` 0.05) of the phasic modulation of the shuffled data (each epoch's bins shifted circularly, `nResamples` draws per unit and group) pooled over every unit and group, because the `"ci"` cutoff sits barely above the mean phasic modulation, so many units with no response exceed it, while about `alpha` of them exceed the shuffle cutoff (it also depends on the units in the figure; `populationAnalysis` pools every dataset's draws; the unit's `p` is the share of shuffles reaching its phasic modulation); `"test"`, the adjusted p of `test` at most `alpha`; `"none"`, no call |
| `threshold` | 0.1 | `"fixed"`: the distance from 0.5, at least 0 and below 0.5 |
| `test` | `"bootstrap"` | `"test"`: `"bootstrap"` (the epochs resampled `nResamples` times; p from how often the mean auROC lands across 0.5), `"ranksum"` (the call window's values against the baseline's; they share epochs, so p runs small) or `"shuffle"` (each epoch's bins shifted circularly at random `nResamples` times; p from how often the phasic modulation reaches the observed one) |
| `nResamples` | 1000 | bootstrap, shuffle (the `test`, or the `"shuffle"` cutoff) |
| `correction`, `alpha` | `"bh"`, 0.05 | `"test"`: `pAdjust` (`"bh"`, `"holm"`, `"bonferroni"`, `"none"`) over every unit and group; modulated when the adjusted p is at most `alpha`; `"shuffle"`: the cutoff is the `1 - alpha` quantile. `populationAnalysis` uses its own `Correction` and `Alpha` instead |
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

### First-spike latency

A figure's first-spike latencies and response onsets are the **figure's**: one
block, `Figure.latency` (`EphysAnalysisConfig.defaults("Latency")`), says how
they are found, for every panel that reads them, and the panels keep only how
they are drawn. Once the panels are computed, `figureCompute` takes them once
per unit and alignment -- per unit of a layer's raster rows, so a raster and a
PSTH of one unit on the same epochs share one -- and hands them to each panel
layer on those rows (`R.latency`, `R.onset`; the private `figureLatencies`).
They are kept in the preview's cache keyed by the rows and the settings each
rule reads: an edit of the block computes them again and nothing else (no
panel's layers), an edit of a look none of them, and only the panels that read
them are drawn again. `F.latency` sums them up for the figure's data and its
exports: the block, and one entry per unit with the panels that read it, its
latencies and onsets. A [session figure](#session-figures) takes them once, on
the rows merged across the sessions.

**Each epoch's first-spike latency** (`firstSpikeLatency`,
[Analysis page](EphysAnalysis.md#compute)) is the time, from the epoch's aligned event, of
its first response spike in the window `[minSec, maxSec]` (both ends included,
to the sample; `maxSec` `Inf`, the default, is each panel's window's end); an
epoch with none has NaN. It reads the raster's own rows: the very spike times
the raster draws, on the clock of each epoch's event (a spike in the event's own
sample is at 0), with the stop mask when the panel masks after the stop event,
and only the epochs the panel draws. Three rules (`method`):

- **`"first"`**: the first spike in the window. Exact on a clean unit; a
  spontaneous spike before the response is taken for the latency.
- **`"surprise"`**: the first spike of the first burst in the window whose
  **Poisson surprise** against the baseline rate reaches `surprise` (Legendy &
  Salcman 1985, *J Neurophysiol* 53:926-939). The surprise of n spikes in the
  time T from the first to the last is S = -log10 P(N >= n), N Poisson with mean
  r T at the baseline rate r. A burst starts as `minSpikes` consecutive spikes
  whose intervals are each under half the baseline's mean interval (1/(2r)),
  takes the following spikes on while that raises S (looking up to 10 spikes
  ahead), then sheds spikes from its start while that raises S; every spike of
  the window is a possible start, and the first burst with S >= `surprise` gives
  the latency, its first spike.
- **`"poisson"`**: the spike at which the spikes counted since the window's
  start first become improbable at the baseline rate, in the manner of Chase &
  Young 2007 (*PNAS* 104:5175-5180): the k-th spike, at t_k, is the latency
  when P(N >= k) < `alpha`, N Poisson with mean r (t_k - `minSec`). The latency
  (`lat`) is this **significance spike**, not the response's first spike: it
  lags that by the few spikes the count needs. `firstSpikeLatency` also returns
  `latFirst`, the first spike of the run that made the count improbable: from
  the significance spike back, each earlier spike joins while the interval after
  it is under half the baseline's mean interval, 1/(2r), as in a surprise burst
  (at r = 0 the run reaches the window's first spike). For the other rules
  `latFirst` is the latency itself.

The baseline rate r of the Poisson rules is the spike count in the baseline
window over its length: `baseline "pre"` the part of the panel's window before
the event, `"window"` the window `baselineWindow` (s from the event), clipped to
the panel's; counted over every epoch together (`baselineRate "unit"`) or in
each epoch alone (`"trial"`: an epoch with no baseline spike has r = 0, and then
any spike, or any `minSpikes` spikes, are improbable). A window with no time
before the event has no baseline: those rules then find nothing and the panels
say why.

On synthetic Poisson trains (a 20 Hz baseline, 250 Hz for 30 ms from 50 ms with
2 ms of jitter; `test_FirstSpikeLatency`) the first-spike rule takes a
spontaneous spike in most epochs, the Poisson surprise finds the response's
first spike in about two epochs of three (its median error under 1 ms), and
the Poisson count takes a spontaneous spike in a few percent, about 10 ms after
the response's first spike.

**The unit's response onset** (`responseOnset`) is found from its PSTH by
CUSUM: the spikes of every epoch (and of each trial group's epochs) in bins of
`cusumBinSec` on a grid through the event, as a rate; the baseline bins' mean m
and SD s (the same baseline window); then over the bins of the window, Page's
one-sided cumulative sum (Page 1954, *Biometrika* 41:100-115), as Ellaway (1978,
*Electroencephalogr Clin Neurophysiol* 45:302-304) applied the cumulative sum to
a PSTH: C_i = max(0, C_(i-1) + z_i - `cusumDrift`), z_i = (x_i - m) / s
(`cusumDirection "down"`: (m - x_i) / s, a fall; `"both"`: |x_i - m| / s, the
first departure either way). The onset is where
C first reaches `cusumThreshold` and stays up and rising for `cusumSustainSec`
(never under the threshold, and higher at the end; a crossing that does not
last is passed over), placed at the start of the rise: the bin after the last
bin where C was 0. On a synthetic baseline the default allowance of 1 SD keeps
C at zero (none of 40 runs found an onset), and the onset falls within a few ms
of the true one. The CUSUM alone finds a crossing in a unit that does not
respond, most easily in a sparse one, whose baseline SD is tiny (a clustered
pair of spontaneous spikes in one epoch is many SDs), so an onset is kept only
for a unit that responds (`cusumGate "evoked"`, the default): across the
epochs (all of them for the unit's onset, each group's for its own), each
epoch's rate in the window against its rate in the baseline, Wilcoxon's signed
rank test (`signrank`, the test of `responseStats`' evoked response), two-sided,
p at most `cusumGateAlpha`, and the rate moving the way `cusumDirection` says;
the curve is drawn either way. `cusumGate "none"` gives the CUSUM's onset alone.

| Field | Default | Meaning |
| --- | --- | --- |
| `method` | `"first"` | the per-trial rule: `"first"`, `"surprise"` or `"poisson"` |
| `minSec`, `maxSec` | 0, `Inf` | the window searched, s from the event (included; `Inf`: each panel's window's end); the onset's too |
| `baseline` | `"pre"` | where the baseline rate is counted: `"pre"` (before the event) or `"window"` |
| `baselineWindow` | `[-0.1 0]` | `baseline "window"`: [lo hi] s from the event |
| `baselineRate` | `"unit"` | the Poisson rules' rate: `"unit"` (every epoch's baseline together) or `"trial"` (each epoch's own) |
| `alpha` | 0.01 | `"poisson"`: the count's improbability |
| `surprise` | 3 | `"surprise"`: the least surprise of a burst, -log10 P |
| `minSpikes` | 3 | `"surprise"`: the fewest spikes a burst starts with (at least 2) |
| `cusumBinSec` | 0.002 | the onset: the PSTH's bins, s |
| `cusumThreshold` | 5 | the onset: the CUSUM's threshold, baseline SDs |
| `cusumDrift` | 1 | the onset: the allowance each bin takes off, baseline SDs (0: the plain excess, floored at zero) |
| `cusumSustainSec` | 0.005 | the onset: how long the CUSUM stays over the threshold and rising, s (0: the crossing alone) |
| `cusumDirection` | `"up"` | the onset: `"up"` (the rate rises above the baseline), `"down"` (falls below it; a baseline near zero leaves no room to fall) or `"both"` (the first departure either way) |
| `cusumGate` | `"evoked"` | the onset: `"evoked"` keeps it only for a unit that responds (the signed rank test above; needs the Statistics and Machine Learning Toolbox), `"none"` the CUSUM's alone |
| `cusumGateAlpha` | 0.05 | the onset, gate `"evoked"`: the test's p value, above 0 and below 1 |

The panels that read them:

- a **raster**'s `options.firstSpike` (`EphysAnalysisConfig.defaults("FirstSpike")`)
  puts a mark on each epoch's first-spike latency, on that epoch's row --
  wherever the sort, `rasterByGroup` or a further block's band put the row --
  over the ticks, in every block (each block's own unit). Aesthetics role
  `firstSpike`, a line per trial group (group: its label); the legend lists
  "First spike"; a mark's data tip names its trial.
- a **PSTH**'s `options.latencyBox` (`EphysAnalysisConfig.defaults("LatencyBox")`)
  draws a horizontal box plot of those latencies along the time axis, one box
  per trial group: the box from the first to the third quartile, a line at the
  median (`prctile`), whiskers to the most extreme latencies within 1.5 IQR of
  the box (Tukey) and the latencies beyond them as outliers. It reads the first
  item (the observed unit; a layer's mean pools its units' epochs, one latency
  per unit and epoch). Overlaid, the boxes sit in a band of their own above the
  traces: the y range grows by a small gap and a lane of `boxHeight` times its
  height per group (the first group's on top), so no box covers a trace
  (whatever `yLimMode` sets the range to: `yLim`'s, a run's batch range), and
  the y ticks stay on the traces' range; the panel's y extent for a batch range
  is the traces', not the band's. With `stack "groups"` each row holds its
  group's box in a lane above its range (`stackLayout`'s `Above`: a gap and
  `boxHeight` times the row height), and the row step grows to take it, so the
  box stays outside the row's values in every `yLimMode` ([Y limits](#y-limits)).
  Roles `latencyBox`, `latencyMedian`, `latencyWhisker` and `latencyOutlier`
  (group: the trial group); each part's data tip gives the median, the
  quartiles, the whiskers, the outliers, n (the epochs with a latency, of the
  group's) and the rule. Not drawn with `display "heatmap"`. A PSTH with it on
  keeps its raster's rows (spikePSTH's `Raster`).
- a **raster**'s or **PSTH**'s `options.onsetLine` draws the unit's response
  onset as a dashed line: `"unit"` one over every epoch (on a raster, over the
  block's rows; on a PSTH, across the axes; in the plot's ink), `"groups"` each
  trial group's at its own onset in the group's color (on a raster, over that
  group's rows); `"off"` (the default) none. Role `latencyOnset` (group: the
  trial group, `""` for the unit's), "Response onset" in the legend; its data
  tip gives the onset and the CUSUM's settings. A PSTH with it on keeps its
  raster's rows; a layer's mean has no one unit's onset (noted).
- **`rasterSort "latency"`** orders the rows of a raster (and of a heat map of
  trials) by each epoch's first-spike latency, ascending or, with
  `rasterSortOrder "descending"`, descending, within each trial group (or across
  them with `rasterByGroup false`), whether or not the marks are on. An epoch
  with no latency sorts last in either direction, ties keep the time order, and
  the y label reads "Epoch (by first-spike latency)". Turning it off is setting
  the sort back to `""`. The order is the one `figEpochOrder` gives every
  raster-like display, so the first-spike marks stay on their epochs' rows.

A latency or onset the block cannot find (no baseline before the event, a
window with no whole bin) is noted in the panel with why.

| Field | `FirstSpike` default | `LatencyBox` default | Meaning |
| --- | --- | --- | --- |
| `enabled` | `false` | `false` | draw the marks / the box plot |
| `color` | `"groups"` | `"groups"` | `"groups"`: each trial group's color; or a color name or `#rrggbb` for every one |
| `marker`, `size` | `"o"`, 5 | | the mark: a line marker the aesthetics editor knows (as an [event mark](#raster-event-marks)'s), its size in points |
| `filled` | `false` | | a filled mark; `false`: its outline, the tick showing through |
| `lineStyle`, `lineWidth` | | `"-"`, 1 | the box's outline and whiskers (`-`, `--`, `:`, `-.`; points); the median is twice as wide |
| `boxHeight` | | 0.1 | each box's lane, a share of the PSTH's height (0.02 to 0.5) |
| `fillAlpha` | | 0.3 | the box's fill opacity, 0 (an outline) to 1 (the median then pale) |
| `outlierMarker`, `outlierSize` | | `"o"`, 3 | the outliers' marker (`"none"`: not drawn) and size |

The looks are checked only while `enabled`, the block always
([Validating figures](#validating-figures)). The figure's caption names the marks,
the box plot and the onset lines with the block's rule, window and baseline
(`latencyMethodText`). The analysis app edits the block in the figure editor's
**First-spike latency** section, and the looks in a window of their own: the
raster's **First-spike marks...** and the PSTH's **Latency box plot...**, with
an **Onset line** row on both ([Figures tab](EphysFigGenApp.md#figures-tab));
**Copy settings** lists the block setting by setting.

### Trial counts

A PSTH panel's `options.trialCount` says how many trials each trial group has, the
epochs its rate averages (`R.nEpochs`; in a [session figure](#session-figures), the
series' epochs summed over the sessions), read when the figure is drawn, so it
follows the selection, the grouping and the artifact periods:

| Value | Overlaid | Stacked (`stack "groups"`) | `display "heatmap"` |
| --- | --- | --- | --- |
| `"off"` (default) | | | |
| `"text"` | `n = 24` per group, in the group's color, down the top left corner of the axes, the first group on top | at the right end of each row's range | at the right end of each row |
| `"legend"` | the group's legend entry reads `<group> (n = 24)`; a single group has no legend entry and gets the text | the same | in the row's y tick label |

Role `trialCount` (group: the trial group's label), one text object per group, which
the aesthetics editor can restyle or hide; the right-click menu goes to **Trial count**
in the PSTH's options. The Figures tab's **Trial count** row is a drop-down of the three
values.

### Smoothed line

A PSTH panel's `options.smoothLine` draws a line over each trial group's trace: the
PSTH smoothed on its own. `bins.SmoothSec` smooths the histogram, `smoothLine.smoothSec`
the line, and neither changes the other:

| Field | Default | Meaning |
| --- | --- | --- |
| `enabled` | `false` | draw the line |
| `smoothSec` | 0.025 | the line's Gaussian SD, s, over the PSTH's bins (0: the unsmoothed PSTH as a line); 0 or more |
| `legend` | `true` | give the line a legend entry, *Smoothed (SD 25 ms)*; `false` leaves it out |

The line starts from the rates without the histogram's smoothing (`spikePSTH`'s
`R.rateUnsmoothed`: each group's mean over its unsmoothed epochs, after the baseline),
so with `bins.SmoothSec` 0.01 and `smoothSec` 0.05 the bars are smoothed by 10 ms and
the line by 50 ms, not by both. It is smoothed on the bins (renormalized at the window's
edges and next to masked bins, as the histogram is), divided as the rates are
(`normalize`), and for a layer's mean taken over its units. It is the drawing's alone:
changing it redraws the preview without computing the figure again.

It is drawn on top of every trace, in the trial group's color (a darker shade over the
group's own fill, so it shows), the item's line style, 1.5 times the design's line
width; stacked (`stack "groups"`), in each row on the row's scale, and the rows make
room for it. The legend gets an entry *Smoothed (SD 25 ms)*, unless `legend` is `false`. Role `smoothLine` (group:
the trace's), which the aesthetics editor can restyle or hide; the right-click menu
goes to **Smoothed line** in the PSTH's options. Not drawn with `display "heatmap"`,
nor for the member sessions of a [session figure](#session-figures). A result computed
before `R.rateUnsmoothed` existed draws no line and its "cannot draw" sign says so (preview it
again).

### Unit waveforms

A raster, PSTH, firing rate or tuning panel of spikes
(`EphysAnalysisConfig.WaveformInsetTypes`) can draw the observed unit's waveform (the
first unit of its first layer) on its peak channel as a small box in the panel (in
the rate axes of a PSTH). The `waveform` settings
(`EphysAnalysisConfig.defaults("Waveform")`; a panel's
`options.waveform`; the app's **Waveform** section,
[The Waveform section](EphysFigGenApp.md#the-waveform-section)):

| Field | Default | Meaning |
| --- | --- | --- |
| `mode` | `"off"` | `"mean"`, `"subsample"` (the individual spikes read, thin and pale), `"both"` (the mean over the spikes), `"template"` (a sorted unit's template, `units.templateWaveform`: no spikes read; detections have none), or `"off"` |
| `band` | `"off"` | an error band round the mean: `"std"` (the SD of the spikes the mean is over: `maxSpikes` of a sorted unit's, all of a detection channel's), `"sem"` (that SD over the square root of their number), or `"off"`; none on a template. Role `waveBand`, drawn as every [error band](#error-bands) is, in the panel's `band` look |
| `maxSpikes` | 100 | the spikes drawn per unit, picked at random (the same ones each run) |
| `timeMs` | `[]` | the x scale: the span drawn, `[from to]` ms from the spike (`-Inf` / `Inf`: the cut's edge); `[]` = the whole cut. A span holding fewer than two samples draws the whole cut |
| `width` | 1 | the box's width: 1 = a third of the panel's; at most 3 |
| `ampScale` | `"unit"` | the y scale: `"unit"` (the waveform fills the box), `"common"` (a waveforms panel: below; in a box the same as `"unit"`, which draws one unit) or `"fixed"` (`ampLim`; what lies beyond it is drawn at its edge) |
| `ampLim` | `[]` | `ampScale "fixed"`: `[lo hi]`, in the waveform's units (`unitWaveforms`' `units`: µV for detections and most sorts) |
| `height` | 1 | the box's height: 1 = a third of the panel's; at most 3 |
| `location` | `"northeast"` | where in the tile: `"northeast"`, `"north"`, `"northwest"`, `"west"`, `"southwest"`, `"south"`, `"southeast"`, `"east"` (north is the top edge as seen, also on a raster's reversed axis) |
| `box` | `true` | the axis box: an outline on a pale ground; `false` draws the waveform alone |
| `showPP`, `showCount` | `true`, `false` | the label: the mean's peak-to-peak amplitude (over the whole cut, whatever `timeMs` draws), the unit's spike count |

The waveforms come from `unitWaveforms` ([Analysis page](EphysAnalysis.md#unit-waveforms)):
for sorted units, `maxSpikes` of the unit's spikes cut from the sorted
`.bin` as Kilosort4 saw them (referenced and high-passed, not whitened),
and their mean; when the `.bin` is not there, the unit's template is
drawn as its mean, labeled "(template)", and a warning says why. For
detections, the waveforms the spikes file keeps (the Spikes step's
`Waveforms` option; none without it, and a warning) and the mean of them
all. Each box is on its own amplitude scale unless `ampScale` is `"fixed"`; its label gives the mean's
peak-to-peak amplitude. The box keeps the tile's limits, stays out of
the legend and its parts (`waveBox`, `waveBand`, `waveSpikes`, `waveMean`,
`waveLabel`) take [aesthetics](EphysAnalysis.md#plot-aesthetics) like any other.

### Waveforms panels

A `waveforms` panel is the unit waveforms as a panel of their own: no events, no trials,
nothing but the units of its layers and their waveforms. It uses the `waveform` settings
above (the panel's `options.waveform`), with `mode` never `"off"` (validate refuses
it); `location` and `box` are not used, `width` and `height` size the probe layout's
glyphs, and these mean more:

| Field | Default | Meaning |
| --- | --- | --- |
| `ampScale` | `"unit"` | `"unit"`: each waveform fills its tile or glyph; `"common"`: one amplitude scale for every unit whose values are of the same kind (all µV, say), so sizes compare. Units of another kind (a template beside spikes) keep their own; `"fixed"`: `ampLim` for every unit (the grid's y limits; a glyph cut at its edge) |
| `showSites` | `true` | probe layout: the probe's sites in gray behind the waveforms |
| `showNames` | `false` | probe layout: each unit's name beside its waveform (with the p-p amplitude and spike count when `showPP` / `showCount`) |

The panel's `options.layout`:

- `"grid"` (default): the observed unit's waveform, or the means of a fixed layer's units
  overlaid: time from the spike (ms) against amplitude, the spike's time dotted, a label
  (`showPP`, `showCount`) in the corner, over the span `timeMs`. `ampScale "common"` gives every unit the same
  amplitude axis, `"fixed"` the axis `ampLim` (the panel's `yLimMode` other than `"auto"`
  wins: its `yLim`).
- `"probe"`: every unit of the first enabled layer at its place on the probe (µm), each
  waveform a glyph centered on its position (`meta.x`, `y`), every site where the probe
  map puts it; a shank is moved sideways only where its glyphs would overlap the one
  beside it (a site parked on a `kcoords` group of its own stays with the shank it sits
  on); a further layer's units are framed in red. `height` sizes the glyphs (1 =
  about a twelfth of the probe's length, at least 30 µm) and `width` their width (1 =
  1.6 times that); with `ampScale "common"` the
  largest unit fills a glyph's height, the others are in proportion, and a scale bar
  names the amplitude it spans; with `"fixed"` `ampLim` fills it, and the bar too. A unit without a position is left out, and the panel says
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
| `stack` | `"off"`: a trace per channel (and trial group); `"items"`: every channel in a row of its own, on one amplitude scale; `"groups"`: every trial group in a row of its own ([Stacks](#stacks)) |
| `statistic` | what is drawn at each sample over a group's epochs: `"mean"` or `"median"` |
| `transform` | `"none"`: the signal as recorded (after the baseline); `"rectify"`: each epoch's absolute value at every sample, before the statistic; `"magnitude"`: the layer's channels as one trace, their vector magnitude √(x² + y² + z² …) at every sample of each epoch, after the baseline and before the statistic (the mean of the magnitudes, not the magnitude of the means). For a 3-axis accelerometer, fix the AUX layer to its three channels and set `baseline` to `"subtract"`, so each axis's offset (gravity) comes out first |
| `errorType` | the band over the epochs, chosen for this panel alone ([Error bands](#error-bands)): `"off"`; `"sem"`: statistic +/- SEM; `"std"`: +/- SD; `"ci95"`: the bootstrap 95% CI (of the median for `"median"`; `errorResamples` resamples); `"iqr"`: the 25th to 75th percentile of the epochs (`"ci95"` and `"iqr"` need the Statistics and Machine Learning Toolbox; `"sem"` and `"std"` with the median are drawn around the median, and validate warns) |
| `trials` | `"faint"` or `"only"`: each epoch's own trace as well, or alone |
| `yLimMode`, `yLim` | the signal's y limits in its units (V): `"auto"` from the traces (and their bands), `"fixed"` at `yLim`, `"batch"` one range over a run ([Y limits](#y-limits)) |

The samples are cut with `evokedPotential`, as an LFP's are: offset 0 is the AUX sample
nearest the one that produced the event, at the AUX extract's own rate (Intan: a quarter
of the amplifier rate). An epoch that leaves the AUX signal or holds a missing sample is
left out of this panel only (the raster and PSTH panels keep it). `maskAfterStop` does
not apply: each epoch's aux samples cover the whole window. A dataset without an AUX
extract skips the layer with its reason (enable AUX in the pipeline's Signals step). A
panel below a raster and a PSTH shares their time axis; put the three flush (`placePanel`
`"below"` the PSTH: a figure of a unit's panels and a fixed AUX panel is the usual
one), and give it half their height with its `rect`.

The [spectral panels](#spectral-panels) take a fixed AUX layer too: a power
spectrum or a spectrogram of each axis, or a coherence of the observed unit (or
an LFP channel) with each axis. With the layer's `aggregate "magnitude"` the axes
are one item, the accelerometer's vector magnitude, each axis's 2 s running mean
taken out first.

The traces take the trial groups' colors (or the layer's `color`) and each channel a
line style (the layer's `lineStyle`, else by order: `-`, `--`, `:`, `-.`); the bands are
`errorType`'s (their fill, opacity and edge are the panel's `band`).
Each trace and band is a component for the
[aesthetics](EphysAnalysis.md#plot-aesthetics) editor (roles `trace`, `channelTrace` for a
channel of a layer that draws several, and `sem`, like any continuous panel's); the
version 1 roles of the retired aux panel (`auxTrace`, `auxSem`, ...) became these when a
plot was [migrated](#looks-on-retired-roles).

### Error bands

Each panel that draws the error of its means chooses it in its own options:
a PSTH its band, a firing rate panel its error bars (`display "bar"`), a
tuning curve its error bars, in `errorType` (`EphysAnalysisConfig.PanelErrorTypes`;
`"off"` draws none), with `errorResamples` for the bootstrap:

| `errorType` | Band / bar | Needs |
| --- | --- | --- |
| `"sem"` (default) | mean +/- SEM (std / sqrt(n)) | |
| `"std"` | mean +/- the standard deviation of the values | |
| `"ci95"` | the 95% confidence interval of the mean: `errorResamples` bootstrap resamples (default 1000, from a stream of their own, seed 0, so a figure gives the same band every time it runs) of the values, percentile method (`bootci`); asymmetric where the values are | Statistics and Machine Learning Toolbox |

A continuous panel's `errorType` takes the same values (plus `"iqr"`, the interquartile range, `prctile`; it needs the
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

Bands are patches (`errorPatch`) in the look of the panel's `band`
(`EphysAnalysisConfig.defaults("ErrorBand")`), which a PSTH, continuous,
spectrum, coherence, unit waveforms and probe map panel each have, and a
waveform inset takes from its panel:

| `band` field | Default | Meaning |
| --- | --- | --- |
| `faceColor` | `""` | `""` = the trace's color; or one color (a name or `#rrggbb`) for every band, drawn as given |
| `faceAlpha` | `NaN` | `NaN` = opaque, the trace's color paled 75% towards the ground (vector exports stay vector); 0-1 = the fill at that opacity, unpaled, so what is under it shows through |
| `edgeColor` | `"none"` | the outline: `"none"`, `"auto"` (the fill's color) or a color |
| `edgeStyle`, `edgeWidth` | `"-"`, 0.5 | the outline's line style (`-`, `--`, `:`, `-.`) and width, points |

Each band is a
component for the [aesthetics](EphysAnalysis.md#plot-aesthetics) editor
(role `sem`, "Error band"), so a right-click
restyles one group's bands, and a design's rules reach them. Error bars (rates, tuning) are `errorbar` objects in their own look; only
`errorType` concerns them. `populationSummary` takes `ErrorType=` and
`ErrorResamples=` too (across the units of each group) and `renderPopulation`
draws its bands (`ShowError`, default true) in the look of its `Band`, as
`renderWaveforms`, `renderProbeMap` and `renderChronux` do.

### Panel notes

Any panel can carry a block of descriptive text -- a caption, a condition,
a remark -- beside or over it. The panel's `note`
(`EphysAnalysisConfig.defaults("Note")`) draws nothing until `text` has
words; the other fields are not checked until then.

| Field | Default | Meaning |
| --- | --- | --- |
| `text` | `""` | the words; a new line starts a new line of text; [label variables](#label-variables) are filled in (escaped for TeX with `interpreter` `"tex"`) |
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
signal trace, a probe map, ...), each placed freely on the page, and drawn for **one
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
**Run** draws the enabled figures (and session figures), and the File menu's
**Generate selected figure** draws the Figures tab's selected figure alone, enabled or not, on every ticked
dataset. The pieces are the config below, `figureObservations`,
`figureCompute` (`EphysAnalysisRunner.computeFigure` wraps it) and
`renderFigure`, which the app's [Figures tab](EphysFigGenApp.md#figures-tab), a
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
subject. With `probe.enabled` it is a [probe figure](#probe-figures): the whole
figure drawn once per unit or channel as a tile at its site on the probe, one
page per dataset.

`EphysAnalysisConfig.defaults("Figure" | "FigureSessions" | "FigureProbe" | "Observe" | "Panel" | "Layer")`
give the fields below; every field exists on every entry.

### Figure, layout and observe fields

| Field | Default | Meaning |
| --- | --- | --- |
| `id` | automatic | unique among figures (`EphysAnalysisConfig:DuplicateFigureId`), file-name safe and distinct once sanitized (`{Plot}` replaces characters outside `A-Z a-z 0-9 _ - .` by `_`, and Windows ignores case: a [validation](#validating-figures) error). Names the exported files (`{Plot}`). With `autoId` the content's ([Figure ids](#figure-ids)); blank with `autoId` false: `figure_<n>` |
| `autoId` | `true` | the id follows the figure's active panel types and data ([Figure ids](#figure-ids)) whenever the figure is stored (every edit, load); `false`: the id is the user's own and stays. A new figure's is `true` until an id is given (`addFigure(..., Id=)`, a struct with an id, an id typed in the app). An entry that leaves it out (a file written by hand) takes `true` for a blank id and `false` for an id it names |
| `enabled` | `true` | unticked, it stays in the config: `figureSkipReason` says "disabled", and `computeFigure` still computes it when asked, as the preview does |
| `title` | `""` | `""` = automatic: the id, the observation's label, the aligned event and the epoch count (a dataset figure names no observation, a figure with no aligned panel no event); the dataset is the subtitle. With a title of your own, the top-left panel names the observation (unless the title names `{Unit}` or `{Observation}`). It may use [label variables](#label-variables) |
| `size` | below | the page the figure is exported on, and the shape of its preview |
| `observe` | below | what the figure is drawn for |
| `layout` | below | how the panels' rects are read: what a rect is (`boxesMean`) and the clear space kept around the panels' labels (`padding`). The places themselves are each panel's [`rect`](#panel-fields) |
| `panels` | none | the [panels](#panel-fields), a list of any length |
| `ref`, `window`, `selection` | `"default"` | `"default"` = [`Defaults`](#defaults), or the figure's own [EventRef](#eventref) / [EpochWindow](#epochwindow) / [TrialSelection](#trialselection). Every aligned panel starts from them |
| `latency` | `defaults("Latency")` | how the first-spike latencies and response onsets its panels read are found, once per unit and alignment for every panel ([First-spike latency](#first-spike-latency)): the method, the window, the baseline and the CUSUM's settings. The panels keep only their looks |
| `sessions` | `defaults("FigureSessions")` | the [session figure](#session-figures) settings: with `sessions.enabled` the figure is drawn once across several datasets instead of once per dataset; `sessions.enabled` false keeps the block and leaves it unused. Which datasets, how the observation is matched across them and how the sessions are colored, merged and grouped |
| `probe` | `defaults("FigureProbe")` | the [probe figure](#probe-figures) settings: with `probe.enabled` the whole figure is drawn once per unit or channel as a tile at its site on the probe, every tile on one page per dataset; `probe.enabled` false keeps the block and leaves it unused. The layout (schematic or physical), how tiles are kept apart, which shanks, channels and depths, how many tiles and their look |
| `style` | [Style](#style) | the figure's look: fonts, line widths, legend, colors and probe sorting apply (the error a panel draws and its bands' look are the panel's options: [Error bands](#error-bands)). `XLim`, `YLim`, `CLim`, `MaxTiles` and `TileSpacing` are not used: the time panels show the window, each panel has its own `options.yLim` / `cLim`, and the panels are placed by their `rect` |
| `aesthetics` | none | remembered looks of the figure's components, a list of rules `{role, group, property, value}` ([Plot aesthetics](EphysAnalysis.md#plot-aesthetics)) |

`size` (the page the figure is exported on, `figureExportSize` ([Export and reports](EphysAnalysis.md#export-and-reports)); the app's **Page size** row, which also shapes the preview):

| Field | Default | Meaning |
| --- | --- | --- |
| `source` | `"export"` | `"export"`: the Export section's `FigureSizeCm` as it is, however many panels the page holds (their rects are parts of it); `"own"`: `width` x `height` in `units` as they are |
| `width`, `height` | 18, 12 | `source "own"`: the page, in `units` (> 0); kept, unused, while `source` is `"export"` |
| `units` | `"cm"` | `"px"` (pixels of the exported PNG, so inches at the Export `Dpi`), `"in"` or `"cm"` (`FigureSizeUnits`); also the units the app shows the Export size in |
| `lock` | `false` | the app keeps the aspect ratio when one side is edited (a setting of the editor; the page is `width` x `height`) |

`layout`:

| Field | Default | Meaning |
| --- | --- | --- |
| `boxesMean` | `"plot"` | what a panel's `rect` is (`EphysAnalysisConfig.BoxesMeans`). `"plot"`: the panel's plot area; its tick labels, axis labels and title are kept clear of its neighbors and the page edge by shrinking the plot area as little as they need. `"outer"`: the panel with its labels; the plot area is the rect less the labels and the padding |
| `padding` | 0.15 | cm, a finite number >= 0: the clear space kept between a panel's labels and its neighbors or the page edge (`"outer"`: between the rect's edge and the labels). Two panels put flush (a raster over its PSTH) stay flush: no padding between them |

`observe` (what the preview's picker lists and what a run repeats the figure over):

| Field | Default | Meaning |
| --- | --- | --- |
| `data` | `"units"` | what one figure is drawn for (`ObserveData`): `"units"` (each sorted unit), `"detected"` (each channel's threshold detections), `"LFP"`, `"MUA"`, `"SPIKE"` or `"AUX"` (each channel of that extract), or `"dataset"` (one figure per dataset). `EphysAnalysisConfig.observeKind(fig)` names its kind: a *unit* for `units` and `detected`, a *channel* for a signal, the *dataset* |
| `units` | [UnitSelection](#unitselection) without `source` | `units` and `detected`: the filter that picks the units the figure can be drawn for (classes, quality, response test, ids, channels, shanks, `maxUnits`; classes and quality apply to sorted units only) |
| `channels` | `[]` | a signal: the extract's columns (`[]` = all) |
| `starred` | `false` | `true` (*Starred only*): only the starred observations ([favorites](EphysAnalysis.md#favorites-stars), read from `<Name>_favorites.json` beside the data): the starred units of the sort in use, the starred channels (a detection channel by its recording channel), the dataset only when it is starred. Applied after the other filters, everywhere the observations are listed: the preview's picker and **<** **>**, Generate, a run and its scripts. A dataset with no starred observation is skipped with `no starred observation`. A [session figure](#observations-across-sessions) keeps a matched observation starred on any of its sessions, drawn on every session that holds it |
| `perGroup` | `false` | `true`: each observation is drawn once per trial group of the figure's selection (its `groupBy`), a figure of that group's epochs ([One figure per trial group](#panel-types)). Validate warns while the selection groups by nothing. A [session figure's](#session-figures) trial groups follow `sessions.trialGroups` instead, and `perGroup` is ignored there |

`addFigure` takes a template's name (`EphysAnalysisConfig.figureTemplates()`) or
a partial figure struct; without an id (`Id=` or the struct's) the figure's id is
[automatic](#figure-ids), with one it is the figure's own (`autoId` false). `"rasterPsth"` (the default) is
`raster_1` on the page's top half (`rect [0 0.5 1 0.5]`) flush over `psth_1` on its bottom half (`[0 0 1 0.5]`), each with one
`units` layer that follows the observation. Each panel type that draws data has a template of
its own (`"psth"`, `"raster"`, `"continuous"`, `"eventTrace"` for [event traces](#event-traces), `"trialDist"`,
`"trialHist"` and `"trialScatter"` for the [trial panels](#trial-measures), `"heatmap"`, `"waveforms"`,
`"probemap"`, `"corrmap"`, `"rate"` for a firing rate panel, `"tuning"` for a
tuning curve, `"spectrum"`, `"spectrogram"` and `"coherence"` for the
[spectral panels](#spectral-panels)): one panel `<type>_1` over the whole page (`[0 0 1 1]`) holding
`defaultLayer(type)`, a layer of the first source of the type's first
[category](#source-categories) (`units`; `LFP` for continuous; an events layer of the `Stim` line for event traces; a
`trials` layer measuring Stim onset to Trial offset for the trial panels, a scatter's x Trial onset to Stim onset) bound as the
type's `DefaultBinding` says, so a new panel draws at once, with the type's
default options; a [legend panel](#panel-types) has none. `"blank"` has no panels. A figure given to `addFigure` without an
`observe.data` (every template) observes what its enabled following layers
read (`EphysAnalysisConfig.followedData(fig)`): `"units"` when one reads sorted
units, else `"detected"` when one reads detections, else the signal of the
first one that reads a signal, else `"dataset"`. So the unit templates observe
sorted units, `"continuous"` and `"spectrogram"` the LFP channels, and
`"heatmap"`, `"probemap"`, `"corrmap"`, the trial panels' and `"blank"` (fixed layers, or none) the dataset. After that `observe.data`
is the figure's own: adding or rebinding layers does not change it. The app
offers no template (its **Add** makes a blank figure and asks for its first
panel); the templates stay for scripts and tests.

### Label variables

A figure's `title`, a panel's `title`, `xLabel`, `yLabel` and `note.text` and a
layer's `name` may name variables in braces, which `renderFigure` (and
`renderProbeFigure`) fill in for each figure drawn: `"Time (s) re {Line} {Edge}"`
draws *Time (s) re Stim onset*, `"{Response} trials"` *Hit trials*. The config
keeps the text as typed. `figureLabelVariables()` lists them (a table of `Name`,
`Topic`, `Meaning`, `Example`):

| Topic | Variables |
| --- | --- |
| Alignment | `{Line}`, `{Edge}` (the event aligned to; with a sequence, the step `alignStep` names), `{Event}` (`eventRefLabel`), `{Window}` (`"-1 to 1 s"`; a `between` window `"-0.2 s to Lick onset +0.5 s"`) |
| Trials | `{Response}` (the selection's response words joined by `" or "`; `"all"` without), `{Filter}`, `{GroupBy}` (blank without), `{Group}` (a perGroup observation's group, else `"all"`), `{Epochs}` (the panel's epochs, else the figure's) |
| Observation | `{Unit}` (the short label of the files' `{Unit}`: `su12`, `ch7`, `dataset`, `probe`), `{Observation}` (its label), `{Channel}`, `{Shank}`, `{Depth}` (blank where unknown) |
| Data | `{Name}` (`F.dataset`), `{Subject}` (`F.subject`, the subjects merged for a session figure), `{Sessions}` (`F.nSessions`, else 1) |
| Figure | `{Figure}`, `{Panel}` (ids), `{Bin}`, `{Smooth}` (the panel's `options.bins` in ms; blank without), `{Measure}` (a [trial panel's](#trial-measures) measure: `trialMeasureLabel` of its first enabled trials layer's, *Stim onset → Platform offset (ms)*; the figure's own text: its first trial panel's; blank without), `{MeasureX}` (a trial scatter's x measure; blank elsewhere), `{Date}` (today, `yyyy-MM-dd`) |

`[T, V] = figureLabelVariables(spec, F, Panel=k)` gives each one's value for
panel `k` of `spec` (a `figureFor` spec; `0`, the default, is the figure's own:
its title) as computed in `F` (`[]`: the observation's, the dataset's and the
epochs' are `"<Name>"`; `PerObservation=false` keeps the observation's so even
with `F`); `figureFileName(text, V, Kind="label")` fills a text with them. Each
panel's texts take its own values (its own `ref`, `window` and `selection`
after `figureFor`), the figure's title the figure's. Names are case-sensitive;
a brace that names no variable is left as typed (so TeX's `x^{2}` is safe), and
a note drawn with `interpreter` `"tex"` gets its values escaped. A title of the
figure's own that names `{Unit}` or `{Observation}` keeps the top-left panel
from naming the observation; one that names `{Group}` gets no `· <group>`. The
report's heading and caption of a figure fill its title with
`PerObservation=false`: one heading serves every observation. Validate warns of
a name in braces that is no variable ([Validating figures](#validating-figures)).

### Figure ids

A figure whose `autoId` is true is named by what it holds,
`EphysAnalysisConfig.autoFigureId(fig)`: *&lt;types&gt; &lt;data&gt;*.

- *&lt;types&gt;*: the `Short` name ([panel types](#panel-types)) of each active
  panel's type, a panel with an enabled layer, in reading order
  (`panelOrder`: the top edge highest first, then left to right), each once,
  joined by `+`: `Raster+PSTH`. *Blank* when no panel is active (a legend
  panel never is: it has no layers).
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
open ([the id](EphysFigGenApp.md#figures-tab)). The figure's file names
follow its id.

### Panel fields

| Field | Default | Meaning |
| --- | --- | --- |
| `id` | auto | unique within the figure (`EphysAnalysisConfig:DuplicatePanelId`); blank: `<type>_<n>`. The aesthetics editor names a panel's tile by it |
| `type` | `"psth"` | one of the [panel types](#panel-types) |
| `title` | `""` | `""` = none, but for the observation's label on the top-left panel under a title of the figure's own. It may use [label variables](#label-variables) |
| `box` | `"auto"` | the frame around the panel's axes (and a coherence panel's phase axes): `"auto"` leaves it to the [design](EphysAnalysis.md#plot-designs) (Tufte and Journal turn it off) and to the looks remembered for the panel's kind; `"on"` or `"off"` is the panel's own and wins over all of them, the figure's own `aesthetics` rules included (a right-click edit of a panel's *Box* does not show while `box` is not `"auto"`: set the panel's Box row instead). Validate: `auto`, `on` or `off` |
| `xLabel`, `yLabel` | `""`, `""` | the panel's own x and y axis labels, any text (no TeX; [label variables](#label-variables) filled in); `""` = automatic: the label the panel type draws (`"Time (s)"` on a time axis, the rate's unit, `"Frequency (Hz)"`, ...). A stack of time panels tells the time once ([shared time axis](#shared-time-axis)): `xLabel` shows where the panel tells it. On a coherence panel with its phase strip the y label is the magnitude's; on a stacked PSTH, its left axis' |
| `xSide`, `ySide` | `"bottom"`, `"left"` | where the panel's x axis' ticks and label go, `"bottom"` or `"top"`, and its y axis', `"left"` or `"right"`; drawn once the type has drawn, for every type. A coherence panel's x axis on top goes on its magnitude, its phase strip dropping its tick labels; a stacked PSTH keeps its two y axes (left: the groups, right: the peaks) whatever `ySide` says. A color bar outside on the side an axis moves to goes to the opposite side. Validate: `bottom` or `top`, `left` or `right` |
| `xShow`, `yShow` | `"all"`, `"all"` | what the panel's x and y axes show (`PanelAxisShows`): `"all"` its label and ticks, `"ticks"` its ticks with the label blanked, `"label"` its label with the ticks (marks and numbers) blanked, `"none"` neither (the axis line alone). Applied last, after the [shared time axis](#shared-time-axis) has hidden or named the stack's labels; a blanked part leaves its room to the plot. Every y axis of a stacked line panel goes alike; a coherence panel's phase strip goes with its magnitude. A panel's own `xLabel` is kept while its label is blanked. Not copied by **Apply to all panels** (`adoptPanelOptions`). Validate: one of `PanelAxisShows` |
| `rect` | `[0 0 1 1]` | the panel's place on the page, `[x y width height]`, normalized 0-1 of the page with the origin at its bottom-left corner (as a MATLAB `Position`): `[0 0.5 1 0.5]` is the top half. It is the panel's plot area or its outer box, as the figure's `layout.boxesMean` says. Panels may overlap; the later one in `panels` is drawn on top (`orderPanel`). The app shows and takes it in `RectUnits` (`figureRectConvert`). [Placing panels](#placing-panels) |
| `ref`, `window` | `"default"` | `"default"` = the figure's, or the panel's own [EventRef](#eventref) / [EpochWindow](#epochwindow) (aligned types only). A panel with its own cuts its own epochs, with the figure's selection or its own (next row); with the figure's, its groups must match the figure's by label, or the panel is skipped. It then no longer [shares the time axis](#shared-time-axis) |
| `selection` | `"default"` | `"default"` = the figure's, or the panel's own [TrialSelection](#trialselection) (aligned types and the [trial panels](#trial-measures), which select trials but cut no epochs): its own epochs and groups, [colored apart with a legend inside the panel](#panel-types). Its groups are not matched to the figure's, and a per-group figure does not cut them. A panel with only its own `selection` still shares the time axis, which depends on `ref` and `window` alone |
| `layers` | none | the [layers](#layer-fields), a list of any length |
| `options` | the type's [options](#panel-options) | all of the options the panel draws, coerced to the type's, so changing `type` re-seeds them: fields the new type has keep their values, the others are dropped |
| `note` | `defaults("Note")` | descriptive text on or beside the panel: a [note](#panel-notes) (nothing is drawn until `text` has words), after `options`. `placement` `"below"`, `"above"`, `"right"` or `"left"` gives up a band of the panel's own area beside its axes; a compass point, `"center"` or `"custom"` (at `x`, `y`, 0-1 across and up the panel's axes) puts the text in the axes |
| `overlays` | none | a list of [overlays](#panel-overlays), lines and semitransparent patches drawn on the panel's own axes in data units, the last field of a panel. A panel's overlays are all drawn on its axes, so `panel` is always `"all"`: `normalizePanel` sets it, whatever a file says, and Validate gives no panel warning. Units are the panel's axis' own (seconds from the event on a time panel, a rate on a PSTH's y axis, an epoch number on a raster's rows) |

### Layer fields

| Field | Default | Meaning |
| --- | --- | --- |
| `name` | `""` | the legend and aesthetics label; `""` = automatic: the unit's label, `LFP ch 3`, the event's label. It may use [label variables](#label-variables) |
| `enabled` | `true` | unticked, the layer stays in the config and is not drawn |
| `source` | `"units"` | one of `FigureSources`: `"units"`, `"detected"`, `"events"` (a digital or derived line's events), `"LFP"`, `"MUA"`, `"SPIKE"`, `"AUX"` or `"trials"` (one number per trial: `measure`); the panel type decides which a panel takes ([source categories](#source-categories)) |
| `binding` | `"observation"` | `"observation"`: follows the previewed or generated unit or channel ([what a layer reads](#what-a-layer-reads)); `"fixed"`: reads what `units`, `channels`, `event` or `measure` name. Events and trials layers are always fixed |
| `units` | [UnitSelection](#unitselection) without `source` | fixed point and unit layers: which units (it may keep several). A layer following the observation uses it only for the other spike source, on the observed channel. `source` is taken from the layer's |
| `channels` | `[]` | fixed signal layers: the extract's columns (`[]` = all) |
| `aggregate` | `"each"` | several units or channels in one layer: `"each"` (one trace or block per item) or `"mean"` (their mean, with a band across them: a PSTH overlay, the aux magnitude's mean) on a raster, PSTH, continuous, rate or tuning panel; `"each"` or `"magnitude"` (the channels as one item, their vector magnitude, each channel's 2 s running mean out first: an accelerometer's movement) for a fixed signal layer of a spectrum, spectrogram or coherence panel ([Spectral panels](#spectral-panels)); `EphysAnalysisConfig.aggregates(type, source)` lists them |
| `event` | [EventMark](#raster-event-marks) | source `events`: the line, edge, which / scope / [sequence](#event-sequences) and the mark's look (`marker`, `size`, `color`, and a span's `spanStyle`, `spanWidth`, `spanAlpha`) |
| `eventsAs` | `"marks"` | source `events`: `"marks"` (a mark on every raster row; a latency line and a rug on a PSTH, signal or heat map panel), `"train"` (the events as a spike train of their own: rows in a raster, a PSTH, a heat map row) or `"span"` (a line from each onset to its offset on every raster row; a line per trial group from the median onset to the median offset elsewhere: [Spans](#raster-event-marks)). Not used on an [event-trace panel](#event-traces) |
| `measure` | [TrialMeasure](#trial-measures), Stim onset → Trial offset | source `trials`: the value each trial gives, a delay, a duration, a count or a trial parameter (a scatter's y) |
| `xMeasure` | [TrialMeasure](#trial-measures), Trial onset → Stim onset | source `trials` on a trial scatter: the x value each trial gives; unused elsewhere |
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
| `trialDist` | Trial distribution | Dist | trial | no | no | no | yes | `fixed` |
| `trialHist` | Trial histogram | Hist | trial | no | no | no | yes | `fixed` |
| `trialScatter` | Trial scatter | Scatter | trial | no | no | no | yes | `fixed` |
| `legend` | Legend | Legend | none (no layers) | no | no | no | no | `""` |

- `Short`: one word, the type's part of an [automatic figure id](#figure-ids).
- `Categories`: the [source categories](#source-categories) its layers draw.
- `Aligned`: cut into epochs around events, so the panel's `ref` and `window`
  apply. An unaligned panel (waveforms, probe map, the trial panels) must keep both `"default"`;
  a trial panel may still take a `selection` of its own.
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
- `DefaultBinding`: what a new layer of the type binds to (`""`: a legend
  panel takes none; `defaultLayer("legend")` is an empty list).

What each draws:

- `legend`: the figure's legend in a panel of its own, where
  `Style.LegendLocation` `"auto"` puts it: the figure's one legend, its
  entries at their natural size, aligned in the panel's `rect` (never scaled
  to fill it) by `align` and `valign`; `orientation` `"auto"` lays it out
  horizontally when the rect is wider than tall, and `columns` `0` puts every
  entry in one row (horizontal) or column (vertical), with more columns
  (vertical) or fewer (horizontal) when that would run out of the rect. The
  panel's axes are hidden (Tag `legendHost`: no tile of the aesthetics editor;
  the legend is the figure's own component), it has no labels, and no panel is
  moved for it (a neighbor's labels are kept clear of it). Without a legend to
  hold (no entries, `LegendLocation` `"inside"` or `"none"`) it shows why in
  small light gray text in a preview, nothing in an export. It draws no data and takes no layers (validate warns of any),
  and a figure holds one at most (validate: an error at the second one's
  `type`). There is no `"legend"` figure template.

- `raster`: a row per epoch, by trial group, each group's ticks in its color (as
  the PSTH's traces; `backColor` adds bands), for the first point layer's first unit. Every further unit or layer goes in a block under it
  with a small gap, each group a band of its own, and the y axis names the
  blocks. Events layers drawn as marks put a mark on every row of every block,
  drawn as a span a line from each onset to its offset on every row; drawn as a
  train they are blocks of rows of their own. `options.firstSpike` marks each
  epoch's first-spike latency and `options.onsetLine` draws the unit's response
  onset ([First-spike latency](#first-spike-latency)).
- `psth`: the peri-event rate per trial group: a band and a trace for every
  layer and unit, each unit in a line style of its own (`-`, `--`, `:`, `-.`,
  or the layer's `lineStyle`); with several only the first is filled.
  `aggregate "mean"` draws the mean over a layer's units with a band across
  them. Events layers drawn as marks become a latency line per trial group
  (the median over its epochs) and a rug along the top edge; drawn as a span, a
  line per trial group from the median onset to the median offset near the top;
  drawn as a train, a PSTH of their own. With `options.stack "groups"` (and two or more trial groups) the
  groups are not overlaid but stacked: one row per group, the first on
  top, the row step `stackSpacing` times the row height, the groups'
  values on the left axis and their peaks on the right, as in [Stacks](#stacks). A second layer or unit is drawn into the same rows as an outline;
  `yLimMode` sets the rows' scale in a stack ([Y limits](#y-limits)). The groups' rasters are not a stack option:
  a raster panel above the PSTH shows them. `options.latencyBox` adds a box
  plot of the first-spike latencies per group, in a band above the traces or,
  stacked, in a lane above each row's range ([First-spike latency](#first-spike-latency)). With
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
  trial group, with an error band; `options.stack` `"off"`, `"groups"` (a row
  per trial group) or `"items"` (a row per channel; [Stacks](#stacks)). With `options.trials` `"faint"` every epoch's trace is
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
- `probemap`: the layer's units on the probe, each at its own position and
  colored by its rate or spike count (`options.value` `nUnits`: the sites
  colored by their units, the units as dots); the observed unit (a channel
  observation: the channel's site) is ringed. With a `waveform.mode` other
  than `"off"` each unit is its waveform instead, a glyph centered on its
  position as a waveforms panel's probe layout draws it (`mode`, `band`,
  `timeMs`, `ampScale`, `ampLim`, `width`, `height`; the values then color
  no unit and there is no color bar), the observed unit's glyph framed in
  red. `options.unitLabels` writes each unit's name in a column beside its
  shank, clear of the units, with a leader and an arrowhead stopping short
  of the unit (dot or glyph): one shank, the units right of its middle
  labeled on its right, the others on its left; several, the first shank's
  on its left and every other one's on its right, so each gap between
  shanks holds one column. The labels keep their units' heights where they
  can and spread apart where they would overlap (at the size drawn); the
  channel numbers are left off then.
- `corrmap`: the pairwise correlation of the layer's units' per-epoch rates for
  the trial group `options.group`, each unit's rates first losing their moving
  mean over about 20% of the group's epochs in time order (`unitCorrelation`'s
  `Detrend`), so that two units drifting together over the session do not
  correlate through the drift; with `metric "peak"` and `between` windows only
  the first bins of every window, the shortest's, are searched.
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
  draws the mean over a layer's units, with the error bar across the units.
  `options.waveform.mode` other than `"off"` puts the first unit's waveform in an
  inset. A rate panel does not share the time axis, and its `window` may be a
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
- `trialDist`: one value per trial (a trials layer's measure: a delay, a
  duration, a count or a trial parameter) by category along x (the trial
  groups, a parameter's levels, the session or the layer), as a swarm, boxes,
  violins, jittered points or a line of the summary, colored by series, with
  the summary ± its error and group tests drawn as brackets ([Trial
  measures](#trial-measures)).
- `trialHist`: the distribution of each series' values, as bars, an outline or
  the empirical cumulative distribution, with each series' summary as a dotted
  line.
- `trialScatter`: each trial's y measure against its x measure, per series,
  with a fit and its band, a correlation, logarithmic axes and marginal
  histograms.

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
(`<figure>.<panel>.selection`; an error on a type that is not aligned, but for
the trial panels, whose values come from the trials it selects).
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
| `spectrum`, `coherence` | `band` | `defaults("ErrorBand")` | the band's look, as the PSTH's ([Error bands](#error-bands)) |
| all three | `detrend` | `"constant"` | each trial's trend removed: `"none"`, `"constant"` or `"linear"` |
| `spectrum`, `spectrogram` | `scale` | `"db"` | `"db"` (10 log10), `"log"` (a log y axis; a spectrogram: dB too) or `"linear"` (as is; a spectrogram baseline then in its own units) |
| all three | `spikeFs` | 1000 | spike layers: the time grid the spike trains are analyzed on, Hz |
| `coherence` | `overTime` | `false` | a coherogram of the first pair (signals or spike trains) |
| `spectrogram`, `coherence` | `movingwin` | `[0.5 0.05]` | `[window step]` s (a coherence only with `overTime`) |
| `spectrogram` | `baseline` | `Mode "none"`, `Window [-0.5 0]` | `Mode` `"none"`, `"db"`, `"percent"`, `"zscore"` or `"ratio"` (`chronuxNormalize`'s) against the power of the moving windows that lie wholly inside `Window` (a window reaching past its end would hold post-event power), which must lie inside the panel's window and be at least one moving window long |
| `coherence` | `showPhase` | `true` | the phase strip under the magnitude (not over time) |
| `spectrum`, `coherence` | `yLimMode`, `yLim` | `"auto"`, `[]` | the power or coherence axis ([Y limits](#y-limits)); a coherence's automatic axis is `[0 1]` |
| `spectrogram`, `coherence` | `cLim` | `[]` | the color scale; a coherogram `[]` = `[0 1]` |
| `spectrogram`, `coherence` | `group` | 1 | the trial group drawn (a coherence: with `overTime`); not used in a stack |
| all three | `stack`, `stackSpacing` | `"off"`, 1.1 | `"groups"`: a row per trial group, the first on top: line rows for a spectrum or coherence, image rows for a spectrogram or coherogram ([Stacks](#stacks)) |

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
| `rasterSort` | `""` | `"rows"`: the epochs' order, as a [raster's](#panel-options) and a heat map of trials': `""` (trial order), `"stop"` (the stop event's latency), `"event"` (`rasterSortEvent`'s latency) or a trial parameter; missing values last (`"latency"` has no spikes to read here: time order, and Validate warns) |
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

### Trial measures

Three panel types draw one number per trial instead of activity around an
event: `trialDist` (*Trial distribution*), `trialHist` (*Trial histogram*) and
`trialScatter` (*Trial scatter*), `EphysAnalysisConfig.TrialPanelTypes`. They
answer questions such as how long after Stim onset the animal left the
platform, how long it stayed off, how many trough pokes a trial had, or how
those relate to a trial parameter. Each takes **trials layers** only (source
`"trials"`, category `trial`), and a trials layer goes on no other panel.
A trials layer is always fixed: its `measure`, a **TrialMeasure**, names the
events or the parameter it reads. One measure per layer, so several layers
give several measures in one panel, and the layer is a grouping of its own. The
panels are not aligned to events: their `ref` and `window` stay `"default"`,
and they read the figure's trial selection, or a `selection` of their own.
A figure of trial panels alone is drawn for the dataset. A dataset without
paired trials skips a trial panel (`no paired trials`). A script that wants the
numbers without a figure calls
[`trialMeasure`](EphysAnalysis.md#trial-measures) and reads a figure's values
with [`TrialDataExport`](#the-data-table).

#### What a measure is

`EphysAnalysisConfig.defaults("TrialMeasure")`, a layer's `measure` (a
scatter's y) and `xMeasure` (a scatter's x; default Trial onset → Stim onset;
not used on the other types):

| Field | Default | Meaning |
| --- | --- | --- |
| `kind` | `"delay"` | `"delay"`: from event A to event B; `"duration"`: A's interval, from its onset to its offset; `"count"`: how many B events follow A; `"param"`: a numeric trial parameter's value (`EphysAnalysisConfig.TrialMeasureKinds`) |
| `from` | an [EventRef](#eventref), Stim onset | A: the event each value starts from; its `which`, `n`, [sequence](#event-sequences) and shifts pick it in each trial |
| `to` | an EventRef, Trial offset | B (delay, count): its `which` picks among the B events after A: `"first"` (the nearest), `"last"`, `"nth"`, or `"all"` (a value per B, so several per trial) |
| `direction` | `"after"` | a delay: `"after"` (the first B at or after A, as a stop event is found) or `"before"` (the last B at or before A, a negative value) |
| `maxGapSec` | `Inf` | a delay: a B farther than this from A is dropped and counted; a count: the window ends at A + `maxGapSec` at the latest (and at the trial's end) |
| `param` | `""` | `kind "param"`: the numeric trial parameter, e.g. `RespLatency` |
| `unit` | `"ms"` | a delay's or duration's unit, `"ms"` or `"s"` (a count has none, a parameter keeps its own) |
| `label` | `""` | the measure's name in labels and legends; `""` = automatic, `trialMeasureLabel` |

The kinds in short (the rules in full, and the `trialMeasure` result, are on
[the scripting page](EphysAnalysis.md#trial-measures)). A **delay** is B's time
minus A's, B found among the intervals of A's own trial (in trial or auto
scope; else over the recording); with `"after"` and `"first"` it is
`eventLatency`'s delay exactly. A **duration** is the interval's offset minus
its onset (`"Trial"` is the trial itself). A **count** counts the B events from
A up to the trial's end (the first low row after the trial is still the
trial's own) or to `maxGapSec`; a line with no event counts 0. A **param** is
the trial column's value, a trial without a finite value left out.

`trialMeasureLabel(m)` names a measure: its `label` when set, else *Stim onset →
Platform offset (ms)* (a delay after), *Platform offset before Stim onset (ms)*
(before), *Platform duration (ms)*, *Trough onsets after Stim onset* (a count),
*RespLatency* (a parameter); an event picked by `which` reads *last Platform
offset* or *2nd Trough onset*, as `eventLatency` names it, and an event with a
sequence reads as `eventRefLabel` writes it. The layer's automatic name, the
[label variables](#label-variables) `{Measure}` and `{MeasureX}` and the app use
it.

#### The distribution panel

`trialDist` puts its categories along x, each labeled (with `showN "ticks"` its
trial count, *Hit (n = 12)*; past 8 categories the labels turn 45 degrees; with
`ordinalX` a line's or points' numeric categories at their values), and the
series side by side in each category's slot. `display`: `"swarm"` (the points
spread by their density, `swarmchart`), `"points"` (jittered over `jitter` of
the slot, the same pattern every time), `"box"` (`boxchart`), `"violin"`
(`violinplot`, MATLAB R2024b or later; an older MATLAB draws boxes and says so
in the panel; a series without spread draws its points) or `"line"` (each
series' summary per category with its error bars, joined, in the layer's line
style). With `showSummary` the swarm, points and violins get a mark at each
slot's summary with its error.

`opts.trialDist` (look: options only the drawing reads, so changing one
recomputes nothing):

| Option | Default | Meaning |
| --- | --- | --- |
| `categories` | `"groups"` | the x axis: `"groups"`, `"param"`, `"session"` or `"layer"` ([grouping](#grouping-the-values)) |
| `categoryParam`, `categoryBins` | `""`, `[]` | categories `"param"`: the trial parameter, and its bins (`[]`, a count or edges) |
| `series` | `"layer"` | the colors: `"layer"`, `"groups"`, `"param"` or `"session"` |
| `seriesParam`, `seriesBins` | `""`, `[]` | series `"param"`: as above |
| `display` | `"swarm"` | `"swarm"`, `"box"`, `"violin"`, `"points"` (jittered) or `"line"` (the summary per category, a line per series) |
| `ordinalX` | `false` | look; `"line"` and `"points"`: numeric categories at their values instead of evenly spaced |
| `summary` | `"mean"` | `"mean"` or `"median"`: the summary mark, the line's points and the caption |
| `errorType`, `errorResamples` | `"sem"`, 1000 | the summary's error |
| `showSummary` | `true` | look; swarm, points and violin: the summary mark ± its error over the values |
| `test` | `"auto"` | the group test across the categories in each series ([tests](#summaries-tests-and-brackets)) |
| `testPairs` | `"all"` | `"all"` pairs, or `"first"` (each category against the first) |
| `adjust`, `testAlpha` | `"holm"`, 0.05 | the pairs' p adjustment (`pAdjust`) and the tests' significance level, in (0, 1) |
| `testShow` | `"brackets"` | look; `"brackets"` (the significant pairs bracketed with stars, the overall p in a corner), `"text"` (the overall p alone) or `"off"` (the caption only) |
| `bracketPairs` | `"significant"` | look; `"significant"` or `"all"` (n.s. brackets too) |
| `markerSize`, `jitter` | 4, 0.3 | look; the points' size, and `"points"`' jitter as a share of the category's slot (0 to 1) |
| `showN` | `"off"` | look; `"ticks"`: each category's trial count in its tick label (*Hit (n = 12)*) |
| `yScale` | `"linear"` | or `"log"` ([scales and limits](#scales-and-limits)) |
| `yLimMode`, `yLim` | `"auto"`, `[]` | the value axis ([Y limits](#y-limits)) |

#### The histogram panel

`trialHist` counts every series on one set of edges (`binMode`: `histcounts`'
rule, `binCount` bins or `binWidth`; log-spaced with `xScale "log"`, the values
at or below 0 left out; covering `xLim` when set) and draws bars at `alpha` (as
`normalization` says: counts, probabilities or a density), a stair outline, or
the empirical cumulative distribution (`ecdf`, 0 to 1). `showSummary` draws a
dotted line at each series' summary. Its y axis reads *Count*, *Probability*,
*Density (1/unit)* or *Cumulative probability*.

`opts.trialHist`:

| Option | Default | Meaning |
| --- | --- | --- |
| `series`, `seriesParam`, `seriesBins` | `"layer"`, `""`, `[]` | a histogram per series, as a distribution's |
| `display` | `"bars"` | `"bars"`, `"outline"` (a stair line) or `"ecdf"` (the empirical cumulative distribution) |
| `normalization` | `"count"` | look; bars and outline: `"count"`, `"probability"` or `"pdf"` |
| `binMode` | `"auto"` | look; `"auto"` (`histcounts`' rule, one set of edges for every series), `"count"` (`binCount` bins) or `"width"` (`binWidth`, in the measure's unit) |
| `binCount`, `binWidth` | 20, 10 | look; a whole number >= 1; a positive width |
| `alpha` | 0.5 | look; the bars' opacity, 0 to 1 |
| `showSummary` | `true` | look; a dotted line at each series' summary |
| `summary`, `errorType`, `errorResamples` | `"mean"`, `"sem"`, 1000 | as a distribution's (the error goes into the caption) |
| `test`, `testPairs`, `adjust`, `testAlpha` | `"auto"`, `"all"`, `"holm"`, 0.05 | across the series |
| `testShow` | `"text"` | look; `"text"` (the overall p in the top right corner, the top left over an ECDF) or `"off"` |
| `xScale` | `"linear"` | look; or `"log"` (log-spaced bins) |
| `xLim` | `[]` | look; `[]` (automatic) or `[lo hi]` in the measure's unit |

#### The scatter panel

`trialScatter` draws a point per trial, its y measure against its x
(`markerSize`, `alpha`), each series' fit over its 95% band (behind the
points), and lists each series in the legend with its correlation, *Hit (r =
0.42, p = 0.01)* (ρ for Spearman's). x and y are paired by trial: a measure
with several values per trial (a delay to every B) pairs its first, and values
without a partner are counted (`drops.nUnpaired`).

`opts.trialScatter`:

| Option | Default | Meaning |
| --- | --- | --- |
| `series`, `seriesParam`, `seriesBins` | `"layer"`, `""`, `[]` | the colors, as a distribution's |
| `fit` | `"none"` | per series: `"linear"`, `"poly2"`, `"poly3"`, `"movmean"` or `"movmedian"` ([fits](#fits-and-correlations)) |
| `fitBand` | `true` | a polynomial fit's 95% confidence band |
| `fitWindow` | 10 | a moving fit's window, a whole number of points >= 2 |
| `corr` | `"pearson"` | each series' correlation: `"pearson"`, `"spearman"` or `"none"` |
| `marginals` | `false` | look; a histogram of x above the plot and of y beside it ([layout](#marginal-histograms-and-the-layout)) |
| `marginalSize` | 0.25 | look; the strips' share of the panel's box, 0.1 to 0.5 |
| `markerSize`, `alpha` | 5, 0.7 | look; the points' size and opacity |
| `summary`, `errorType`, `errorResamples` | `"mean"`, `"sem"`, 1000 | each series' y summary (the caption) |
| `test`, `testPairs`, `adjust`, `testAlpha` | `"auto"`, `"all"`, `"holm"`, 0.05 | y across the series |
| `testShow` | `"text"` | look; `"text"` (the overall p in the top left corner) or `"off"` |
| `xScale`, `yScale` | `"linear"` | or `"log"`; the fits are made in the scale drawn |
| `xLim` | `[]` | look; the x axis' limits |
| `yLimMode`, `yLim` | `"auto"`, `[]` | the y axis ([Y limits](#y-limits)) |

The three types share their series, summary, error, tests and scales ([Copying
options between panels](#copying-options-between-panels)); a distribution's
categories are its own. `alpha` is the opacity on the histogram and the scatter
(as an event-trace panel's is), and `testAlpha` the significance level on all
three.

#### Grouping the values

The values are grouped twice: by `categories` (a distribution's x axis; a
histogram and a scatter have one category) and by `series` (the colors in every
type). Each is one of `EphysAnalysisConfig.TrialGroupings`:

| Grouping | Levels |
| --- | --- |
| `"groups"` | the figure's trial groups, or those of the panel's own selection |
| `"param"` | the values of the trial parameter `categoryParam` / `seriesParam`: with `categoryBins` / `seriesBins` `[]` each value is a level, a whole number n makes n equal-width bins (*Depth 0.25-0.5*), two or more ascending numbers are the bins' edges (values outside them are left out); a text parameter has a level per string |
| `"session"` | a [session figure's](#session-figures) sessions |
| `"layer"` | each trials layer (the layer's name is the level's label) |

The categories and the series may not group alike (two different parameters
may). The series take the trial groups' colors for `"groups"`, the layer's own
`color` (else the palette's) for `"layer"`, and the palette for `"param"` and
`"session"`, a [plot design's](EphysAnalysis.md#plot-designs) sequential colors
for a numeric parameter's ordered levels.

#### Summaries, tests and brackets

Each category and series gets its `summary` (`"mean"` or `"median"`) with its
error (`errorType`, as a continuous panel's: `"off"`, `"sem"`, `"std"`,
`"ci95"` with `errorResamples` bootstrap resamples, or `"iqr"`).

A group `test` compares the categories within each series (one category: the
series): `"auto"` takes the rank sum test (`ranksum`) for two levels and
Kruskal-Wallis (`kruskalwallis`) for more; `"ranksum"`, `"ttest2"`,
`"kruskalwallis"` and `"anova1"` name one (`ranksum` with more than two levels
runs `kruskalwallis`, `ttest2` runs `anova1`); `"none"` tests nothing
(`EphysAnalysisConfig.TrialTests`). Only levels with at least two values take
part, and too few give no p, never an error. The pairs (`testPairs` `"all"`, or
`"first"`: each against the first level) are compared by `ranksum` (`ttest2`
under a parametric choice) and their p values adjusted per series by `pAdjust`
(`adjust` `"holm"`, `"bh"`, `"bonferroni"` or `"none"`). Stars follow the
adjusted p at fixed levels (`*` below 0.05, `**` 0.01, `***` 0.001; `n.s.`
above); `testAlpha` decides which pairs count as significant: the ones
`bracketPairs "significant"` draws, and the overall p drawn in bold. The tests
need the Statistics and Machine Learning Toolbox.

With `testShow "brackets"` the pairs (`bracketPairs "significant"`: those below
`testAlpha` after the adjustment; `"all"`: every pair with a p) are drawn as
brackets over the data, each with its stars (`n.s.` a point smaller): two
categories of one series in that series' slot (in its color when there are
several series), two series side by side when there is one category. A bracket
takes the lowest level free of the others, the shortest pairs first (pairs
that only share an end share a level), the levels stepped by a factor on a log
axis; the y axis grows to hold them unless its limits are fixed (`yLimMode
"fixed"` or `"batch"`). The overall tests go in a corner (top left on a
distribution and a scatter, top right on a histogram), a line per series in its
color (*Depth 0-0.5: Kruskal-Wallis p = 0.003*; *p < 0.001* below that; a p
below `testAlpha` in bold; a test across the series in dark gray). `testShow
"text"` writes those lines alone, `"off"` neither; the report's
[caption](#the-caption) says what was tested and what it found either way.

#### Fits and correlations

A scatter fits each series (`fit`, `EphysAnalysisConfig.TrialFits`): `"linear"`,
`"poly2"` or `"poly3"` (`polyfit`: a polynomial of degree 1 to 3, a curve over
the x range with its 95% band from `fitlm` and `predict`, drawn behind the
points when `fitBand` is on), or a moving mean or median (`"movmean"`,
`"movmedian"`) over `fitWindow` points in x order (no band). Each series' `corr`
is Pearson's or Spearman's coefficient with its p (`corr`, from three points). On a log axis the
fit and the correlation are made in log10 units, values at or below 0 left out
and counted; the curve is drawn back in data units. Their numbers go into the
caption (*Pearson r = 0.61, p = 0.004; linear fit R² = 0.37*).

#### Scales and limits

`yScale "log"` (a distribution, a scatter) and `xScale "log"` (a histogram, a
scatter) draw a log axis; values at or below 0 are left out and a note in the
panel counts them. A histogram's bins are then log-spaced. `yLimMode` and `yLim`
(a distribution, a scatter) and `xLim` (a histogram, a scatter) fix the axes;
`yLimMode` is as a PSTH's ([Y limits](#y-limits)), and with `"batch"` every
observation of a run shares the range. A histogram's `xLim` is also the range
its bins cover.

#### Marginal histograms and the layout

With `marginals` a scatter's box holds three axes: the plot, a strip of x
histograms over it and a strip of y histograms right of it, flush, each
`marginalSize` of the box, the strips' limits linked to the plot's and showing no
tick labels (a histogram per series, as probabilities, on one set of edges).
With the panel's x axis on top (`xSide`) the x strip goes under the plot, with
its y axis on the right (`ySide`) the y strip goes to its left. The layout
splits the panel's box so at every layout ([renderFigure](#renderfigure)), the
panel's title sits over the top strip, and **Arrange** moves the three together.
A scatter drawn into a single axes (a probe figure's tile) has no strips.

#### Roles and data tips

The parts' [aesthetics roles](EphysAnalysis.md#plot-aesthetics) are
`distPoints`, `distBox`, `distViolin`, `distSummary`, `distLine`,
`sigBracket`, `sigText` (a bracket's stars), `statText` (the corner's tests),
`histBar`, `histLine` (an outline or an ECDF), `histSummary`, `scatterPoints`,
`fitLine`, `fitBand` and `marginalBar`; their group is the series' label (a
bracket's "a vs b", with the series when there are several). A design captures
its palette from the points, boxes and bars. A point's
[data tip](EphysFigGenApp.md#figures-tab) names its trial, trial group,
category and the trial's parameters; a bracket's its pair's test (*ranksum p =
0.004 (holm 0.012), n = 30 vs 12*).

#### The data table

In the analysis app's preview, and in any visible figure `renderFigure` draws, a
right-click on a trial panel (its axes, a point, a bar, a strip) offers **Copy
data table** (tab-separated text with a header, to paste into a spreadsheet) and
**Export data (CSV)...** (a save dialog, then `writetable`). From a script
`TrialDataExport` gives the same table
([an example script](EphysAnalysis.md#trial-measures)):

```matlab
F = runner.computeFigure(src, cfg.figureFor("Dist trials"));
T = TrialDataExport.valuesTable(F);          % every trial panel; (F, "trialDist_1") one, by id or index
TrialDataExport.export(F, [], "delays.csv");  % writetable; "" opens a save dialog
txt = TrialDataExport.tableText(T);          % what Copy data table puts on the clipboard (TrialDataExport.copy)
```

One row per value, a layer's rows after another's, with the columns `figure`,
`panel`, `layer`, `measure` (the label, with its unit), `dataset`, `session`,
`sessionKey`, `trial` (the row of the dataset's trials), `group` and
`groupLabel` (the trial group), `category` and `categoryLabel`, `series` and
`seriesLabel`, `value` (in the measure's unit), `x` (a scatter's x measure;
NaN elsewhere), `tA` and `tB` (the events' times, s), then the trial
parameters the values carry (the selection's `groupBy`, a category or series
parameter). `TrialDataExport:NoPanel` for a panel the figure lacks,
`TrialDataExport:NotTrialPanel` for one that is no trial panel.

#### Trial measures across sessions

In a [session figure](#session-figures) a trial panel's layers are merged like
an event trace's: no units or channels to match, every session's per-trial values
in one table (`R.values` with `session`, the row of `R.sessions`, and
`sessionKey`), each value in the merged series of its session and trial group
(a value in none is left out and counted, `drops.nNoSeries`). Under
`trialGroups "pool"` the series are the sessions (or subjects, or all), under
`"each"` one figure per trial group with the sessions as its series, under
`"combine"` a series per session and trial group ([Trial groups in a session
figure](#trial-groups-in-a-session-figure)). The grouping `"groups"` then groups
by those series (Validate warns under `"pool"`). The categories, series and
tests are made again over the merged values, so `"session"` has the sessions as
its levels (labeled as the sessions are) and a test compares the sessions'
values. The drop counts are summed over the sessions. A session figure's data
file (`Export.Data.Enabled`) holds the merged figures with their `R.values` and a
`values` table of every trial panel's values, an `observation` column first
(`TrialDataExport.resultsTable`; [file
formats](file-formats.md#session-figure-data-mat)).

#### The caption

A figure with trial panels says in its report caption what each measures and how
it groups, summarizes and tests: *trial measure: Stim onset → Platform offset
(ms); categories by Depth; mean ± SEM; rank-sum or Kruskal-Wallis test (all
pairs, holm, alpha 0.05)*, and on a scatter *linear fit, Pearson correlation*.
Then come the numbers, a line per trial panel (`trialStatsText`, appended by
`figureCaption`'s `Results=`): each category's center ± error with its unit and
n, the overall p, each pair's adjusted p with its stars, a scatter's r and fit
R², and what was left out (*3 trials without a Platform offset*, *2
unpaired*), e.g. *td: Hit 412 ± 18.3 ms (n = 12), Miss 655 ± 40.1 ms (n = 9);
Rank-sum p = 0.000123; Hit vs Miss p = 0.000123 (holm)\*\*\**. Numbers have
three significant digits.

#### Validating trial panels

[Validate](#validating-figures) checks a trials layer's measure (`kind`, the
events, `direction`, a `maxGapSec` above 0, the parameter's name, `unit`, the
label's variables; a scatter's delay to every B warns) and each trial panel's
options (the enumerations, a parameter named where `"param"` groups, the bins,
categories and series not alike, the numbers' ranges, the toolbox for the tests
and for the bootstrap or IQR error); in a session figure it warns of a
`"groups"` grouping under `trialGroups "pool"`. A layer whose compute fails is
skipped with the reason (`no paired trials`, `trialMeasure:NoParam`, `no trial
parameter X`), as other panels are ([Observations and skip
reasons](#observations-and-skip-reasons)).

#### Trial panel templates

The templates `"trialDist"`, `"trialHist"` and `"trialScatter"` are one panel
with one trials layer (Stim onset → Trial offset; a scatter's x Trial onset →
Stim onset), and their figures' automatic ids read *Dist trials*, *Hist trials*
and *Scatter trials*.

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
| `raster` | `rasterSort` | `""` | the order of each group's epochs: `""` (trial order), `"stop"`, `"event"`, `"latency"` ([first spike](#first-spike-latency)) or a trial parameter |
| `raster` | `rasterSortEvent` | `[]` | `rasterSort "event"` (required then): the [event reference](#eventref) whose latency orders the rows |
| `raster` | `rasterSortOrder` | `"ascending"` | or `"descending"` |
| `raster` | `rasterByGroup` | `true` | rows by group first; `false`: every epoch sorted as one block |
| `raster` | `maskAfterStop` | `false` | drop each epoch's ticks from its stop event on |
| `raster` | `tickColor` | `"groups"` | the ticks' color: `"groups"` is each trial group's color (as the PSTH colors its traces; each group's ticks are one line object, tagged `rasterTicks` with the group's label); else a color name or hex code (`"red"`, `"#ff7f0e"`) for every tick. A raster layer's own `color` overrides it for that layer's block. A name that is not a color is a validation warning and the ticks keep the groups' colors |
| `raster` | `tickWidth` | `0` | the ticks' line width, points; `0` is the plot design's width (`rasterTicks` `LineWidth`). A value above 0 wins over the design's and the user's per-kind rules (the figure's own aesthetics rules still win); not a width of 0 or more is a validation error |
| `raster` | `backColor` | `"none"` | bands behind the rows: `"none"` (the default), `"groups"` (a pale band of each group's color behind its rows; the legend then also names the groups when every tick is one color) or a color name or hex code, painted on every group's band and on the axes behind them. Anything else is a validation warning and no bands |
| `raster` | `yTicks` | `false` | show the y axis' tick marks and labels (the epoch numbers); `false` hides them and keeps the y label. A raster of several blocks keeps its blocks' names on the y axis either way. A heat map of trials has no y ticks to show |
| `raster` | `firstSpike` | [FirstSpike](#first-spike-latency), `enabled false` | a mark on each epoch's first-spike latency (the figure's `latency` block finds it), on its row; its `marker`, `size`, `color` (`"groups"` or a color) and `filled` |
| `raster` | `onsetLine` | `"off"` | the unit's [response onset](#first-spike-latency) (the figure's CUSUM onset): `"unit"` a dashed line over every row, `"groups"` each trial group's over its rows in its color |
| `raster` | `waveform` | [Waveform](#unit-waveforms), `mode "off"` | the first block's unit's waveform in a box in the panel |
| `psth` | `bins` | `BinSec` 0.01, `SmoothSec` 0.01 | the bin width (bins are whole multiples of `BinSec` from the event) and the Gaussian SD applied to each epoch before averaging, s (0 = no smoothing) |
| `psth` | `measure` | `"rate"` | `"rate"`, `"count"` or `"probability"` |
| `psth` | `baseline` | `Mode "none"`, `Window [-0.2 0]` | `Mode` `"none"`, `"subtract"`, `"zscore"`, `"percent"` or `"auroc"` (`"ratio"` is for rate and tuning panels) |
| `psth` | `auroc` | `defaults("Auroc")` | baseline `Mode "auroc"`: the [auROC](#auroc) settings (`method`, `windows`, `windowSec`, `stepSec`, the call window `modulationWindow`, `cutoff`, `threshold`, `test`, `nResamples`, `correction`, `alpha`, `marks`, `modulatedOnly`). `windowSec` and `stepSec` must be whole numbers of the panel's bins (validate checks them) |
| `psth` | `errorType` | `"sem"` | the band over the epochs: `"off"`, `"sem"`, `"std"` or `"ci95"` ([Error bands](#error-bands)); not drawn with `display "heatmap"` |
| `psth` | `errorResamples` | 1000 | `errorType "ci95"`: the bootstrap resamples |
| `psth` | `band` | `defaults("ErrorBand")` | the band's look: `faceColor`, `faceAlpha`, `edgeColor`, `edgeStyle`, `edgeWidth` ([Error bands](#error-bands)) |
| `psth` | `histStyle` | `"bar"` | `"bar"` or `"line"` |
| `psth` | `fill` | `true` | fill the bars, or the area under the line |
| `psth` | `fillAlpha` | `NaN` | fill opacity 0-1; `NaN` = 0.5 where groups overlay, else 1 |
| `psth` | `smoothLine` | `enabled false`, `smoothSec` 0.025, `legend true` | a line over each trace, the PSTH smoothed on its own by a Gaussian of SD `smoothSec` (s), independent of `bins.SmoothSec` ([Smoothed line](#smoothed-line)). Not with `display "heatmap"` |
| `psth` | `normalize` | `"none"` | `"none"`, `"unitPeak"`, `"groupPeak"` or `"allPeak"` |
| `psth` | `stack` | `"off"` | `"groups"`: one row per trial group, stacked downwards (the first group on top, as a raster lists them), instead of overlaid; a single group is drawn overlaid ([Stacks](#stacks)) |
| `psth` | `stackSpacing` | 1.1 | `stack`: the step between rows, times the row height (below 1 the rows overlap); positive |
| `psth` | `onsetLine` | `"off"` | the first item's unit's [response onset](#first-spike-latency): `"unit"` a dashed line across the axes, `"groups"` each trial group's in its color. A PSTH with it keeps its raster's rows |
| `psth` | `latencyBox` | [LatencyBox](#first-spike-latency), `enabled false` | a box plot of the figure's first-spike latencies per trial group, in a band above the traces (`stack "groups"`: in a lane above each row); `color`, `lineStyle`, `lineWidth`, `boxHeight`, `fillAlpha`, `outlierMarker`, `outlierSize`. Not with `display "heatmap"` |
| `psth` | `trialCount` | `"off"` | the trials each group has ([Trial counts](#trial-counts)): `"text"` writes `n = 24` per group in the group's color, `"legend"` appends ` (n = 24)` to the group's legend entry |
| `psth` | `maskAfterStop` | `false` | drop each epoch's bins from its stop event on |
| `psth` | `yLimMode`, `yLim` | `"auto"`, `[]` | the rate axis ([Y limits](#y-limits): auto, rows, batch or fixed at `yLim`); in a stack the rows' scale; not used by a heat map |
| `psth` | `colormap` | `""` | `display "heatmap"`: `""` is the style's `HeatColormap`, else the design's heat colormap (an auROC: its diverging one); or a colormap function (`"turbo"`, `"hot"`, `"blueWhiteRed"`). A name that is no function is a validation warning and takes the default |
| `psth` | `cLim` | `[]` | `display "heatmap"`: the color limits; `[]` = the drawn item's own range (an auROC: 0 to 1) |
| `psth` | `waveform` | [Waveform](#unit-waveforms), `mode "off"` | the first unit's waveform in a box in the panel |
| `continuous` | `baseline` | `Mode "none"`, `Window [-0.2 0]` | `Mode` `"none"` or `"subtract"` (each epoch's mean over `Window`, per channel). The window must overlap the panel's window |
| `continuous` | `statistic` | `"mean"` | `"mean"` or `"median"` over the epochs at each sample |
| `continuous` | `transform` | `"none"` | `"none"`, `"rectify"` (each epoch's absolute value, before the statistic) or `"magnitude"` (the layer's channels as one: their vector magnitude in each epoch, after the baseline) |
| `continuous` | `errorResamples`, `band` | 1000, `defaults("ErrorBand")` | as the PSTH's |
| `continuous` | `stack` | `"off"` | `"off"` (overlaid), `"groups"` (a row per trial group, the items overlaid in it) or `"items"` (a row per channel or layer mean, the groups overlaid in it) ([Stacks](#stacks)) |
| `continuous` | `stackSpacing` | 1.1 | `stack`: the step between rows, times the row height; positive |
| `continuous` | `trials` | `"off"` | each epoch's trace: `"off"`, `"faint"` (paler and thinner than the mean, behind it and its band) or `"only"` (the traces alone, no mean or band) |
| `continuous` | `maxTrials` | 100 | `trials` other than `"off"`: the most epochs drawn, picked evenly over their order; a whole number >= 1 (`Inf` = every one) |
| `continuous` | `yLimMode`, `yLim` | `"auto"`, `[]` | the amplitude axis, or a stack's rows' scale ([Y limits](#y-limits)) |
| `heatmap` | `bins`, `measure`, `baseline` | as the PSTH's | a spike layer: as the PSTH, `baseline.Mode "auroc"` included; a signal layer: `baseline.Mode` `"none"` or `"subtract"` and `bins`, `measure` unused |
| `heatmap` | `auroc` | `defaults("Auroc")` | a spike layer, baseline `Mode "auroc"`: the PSTH's `auroc` settings. A signal layer with `"auroc"` is an error |
| `heatmap` | `rows` | `"items"` | `"items"`: a row per unit or channel of the layer; `"trials"`: a row per epoch of one unit, every trial group (a spike or train layer that follows the observation or is fixed to one unit; no auROC baseline). A layer that follows the observation through a channel (a channel observation, or a layer of the other spike source) keeps every unit on it, so validate refuses it; one that still keeps several is skipped at run time |
| `heatmap` | `order` | `"probe"` | rows `"items"`: `"probe"` (the style's `SortDepth` / `SortShank`), `"peak"` (by the time of each row's maximum) or `"modulation"` (by each unit's mean auROC in the call window, highest first; only with the auROC baseline of a spike layer). Not used for `"trials"` |
| `heatmap` | `rasterSort` | `""` | rows `"trials"`: the order of the epochs, as a raster's: `""` (trial order), `"stop"`, `"event"`, `"latency"` (the unit's first-spike latency: the figure's `latency` block) or a trial parameter |
| `heatmap` | `rasterSortEvent` | `[]` | rows `"trials"`, `rasterSort "event"` (required then): the [event reference](#eventref) whose latency orders the rows |
| `heatmap` | `rasterSortOrder` | `"ascending"` | rows `"trials"`: or `"descending"` |
| `heatmap` | `rasterByGroup` | `true` | rows `"trials"`: epochs by group first, else one block |
| `heatmap` | `group` | 1 | rows `"items"`: the trial group drawn (clipped to the groups there are). Not used for `"trials"` or a stack |
| `heatmap` | `stack`, `stackSpacing` | `"off"`, 1.1 | rows `"items"`: `"groups"` draws a block of rows per trial group, the first on top, on one color scale ([Stacks](#stacks)) |
| `heatmap` | `cLim` | `[]` | the color scale |
| `heatmap` | `maskAfterStop` | `false` | spike layers: as the PSTH's |
| `waveforms` | `layout` | `"grid"` | `"grid"`: the observed unit's waveform, or the means of a fixed layer's units overlaid; `"probe"`: every unit of the first enabled layer at its place on the probe, a further layer's units framed in red (bind the first layer to fixed units: validate warns when it follows the observation, which draws one glyph). Several enabled layers are not a warning in the probe layout |
| `waveforms` | `band` | `defaults("ErrorBand")` | the look of the means' bands (`waveform.band`), as the PSTH's |
| `waveforms` | `yLimMode`, `yLim` | `"auto"`, `[]` | the amplitude axis ([Y limits](#y-limits); not the probe layout's) |
| `probemap` | `value` | `"rate"` | `"rate"`, `"nSpikes"` or `"nUnits"` |
| `probemap` | `cLim` | `[]` | the color scale |
| `probemap` | `unitLabels` | `false` | each unit's name beside its shank, with an arrow to the unit (roles `unitLabels`, `unitLeaders`, `unitArrows`) |
| `probemap` | `waveColor` | `false` | with a `waveform` mode other than `"off"` and `value` `"rate"` or `"nSpikes"`: each unit's glyph (mean, band, spikes) in the color of its value in the color scale, with a color bar |
| `probemap` | `band` | `defaults("ErrorBand")` | the look of the glyphs' bands (`waveform.band`), as the PSTH's |
| `corrmap` | `metric` | `"mean"` | each epoch's `"mean"` rate over its window, or its `"peak"` binned rate |
| `corrmap` | `correlation` | `"pearson"` | or `"spearman"` |
| `corrmap` | `fisherZ` | `false` | draw Fisher's z and average the pairwise r in z |
| `corrmap` | `detrend` | `true` | `unitCorrelation`'s `Detrend`: each unit's responses less their moving mean over about a fifth of the group's epochs (in time order) before correlating |
| `corrmap` | `bins` | `BinSec` 0.01, `SmoothSec` 0.01 | `metric "peak"` |
| `corrmap` | `baseline` | `Mode "none"`, `Window [-0.2 0]` | `Mode` `"none"` or `"subtract"` |
| `corrmap` | `group` | 1 | the trial group drawn |
| `corrmap` | `cLim` | `[]` | the color scale |
| `rate` | `measure` | `"rate"` | `"rate"` (spikes/s), `"count"` (spikes per window) or `"probability"` (the share of epochs with a spike) |
| `rate` | `baseline` | `Mode "none"`, `Window [-0.2 0]` | `Mode` `"none"`, `"subtract"`, `"ratio"` or `"zscore"`, as `firingRate`'s `Normalize`: `"subtract"` (that epoch's baseline value), `"ratio"` (over the unit's mean baseline) or `"zscore"` (against the baseline's mean and SD over all epochs) |
| `rate` | `errorType`, `errorResamples` | `"sem"`, 1000 | `display "bar"`: the error bars over the epochs, as the PSTH's band (`"off"`: none) |
| `rate` | `yLimMode`, `yLim` | `"auto"`, `[]` | the rate axis ([Y limits](#y-limits)) |
| `rate` | `waveform` | [Waveform](#unit-waveforms), `mode "off"` | the first unit's waveform in a box in the panel |
| `tuning` | `param` | `""` | the x axis, a trial parameter; `""` = the figure's first `groupBy` parameter, else the first numeric trial parameter with two or more values |
| `tuning` | `seriesParam` | `""` | one curve per value of this trial parameter; `""` = one curve; not the same as `param` |
| `tuning` | `stack`, `stackSpacing` | `"off"`, 1.1 | `"groups"`: a row per series, the first on top ([Stacks](#stacks)) |
| `tuning` | `measure` | `"rate"` | as the rate panel's |
| `tuning` | `errorType`, `errorResamples` | `"sem"`, 1000 | the error bars over the epochs of each value, as the PSTH's band (`"off"`: none) |
| `tuning` | `yLimMode`, `yLim` | `"auto"`, `[]` | the rate axis, or a stack's rows' scale ([Y limits](#y-limits)) |
| `tuning` | `waveform` | [Waveform](#unit-waveforms), `mode "off"` | the first unit's waveform in a box in the panel |
| `spectrum`, `spectrogram`, `coherence` | | | the [Chronux options](#spectral-panels), above; none but `stack` and `stackSpacing` is a shared option |
| `eventTrace` | | | the [event-trace options](#event-traces), above; none is a shared option |
| `trialDist`, `trialHist`, `trialScatter` | | | the [trial-measure options](#trial-measures), above; the series, summary, error, tests and scales are shared among the three |
| `legend` | `orientation` | `"auto"` | `"auto"` (horizontal when the rect is wider than tall, else vertical), `"vertical"` or `"horizontal"` |
| `legend` | `align`, `valign` | `"center"`, `"middle"` | where the legend sits in its rect when smaller: `"left"`, `"center"` or `"right"`; `"top"`, `"middle"` or `"bottom"` |
| `legend` | `columns` | 0 | 0 = automatic (from the rect's shape), else that many columns; a whole number >= 0 |

### Copying options between panels

Each panel holds all of its own options. Several types share some of them,
so a PSTH over a heat map over a unit correlation can be binned and
baselined alike: `EphysAnalysisConfig.sharedFieldsOf(type)` lists the shared
options a type has, in order:

| Type | Shared options |
| --- | --- |
| `raster` | `maskAfterStop`, `waveform` |
| `psth` | `bins`, `measure`, `baseline`, `auroc`, `maskAfterStop`, `waveform`, `stack`, `stackSpacing` |
| `continuous` | `baseline`, `stack`, `stackSpacing` |
| `heatmap` | `bins`, `measure`, `baseline`, `auroc`, `maskAfterStop`, `stack`, `stackSpacing` |
| `corrmap` | `bins`, `baseline` |
| `rate` | `measure`, `baseline`, `waveform` |
| `tuning` | `measure`, `baseline`, `waveform`, `stack`, `stackSpacing` |
| `spectrum`, `spectrogram`, `coherence` | `stack`, `stackSpacing` (a spectrogram's `baseline` is `chronuxNormalize`'s) |
| `trialDist` | `series`, `seriesParam`, `seriesBins`, `summary`, `errorType`, `errorResamples`, `test`, `testPairs`, `adjust`, `testAlpha`, `testShow`, `yScale`, `yLimMode` |
| `trialHist` | the same but `yScale` and `yLimMode`, with `xScale` |
| `trialScatter` | the same with `xScale`, `yScale` and `yLimMode` |
| `waveforms`, `probemap`, `eventTrace` | none (a waveforms panel's `waveform` is its own settings, not an inset) |

Three pure functions edit a figure entry as a value (the app's **Apply to all
panels** and **Re-link all panels** buttons call them):

| Call | Does |
| --- | --- |
| `[fig, changed] = EphysAnalysisConfig.adoptPanelOptions(fig, panelId, Fields=names)` | `Fields` (a string array of option names, and the pseudo-names `"xSide"` and `"ySide"` for the axis sides) limits what is copied to those names, each still going where this call's rules send it (a section of the Figures tab passes the names of its rows); left out it is everything this call copies, `Fields=["xSide" "ySide"]` the sides alone, `Fields=string.empty` nothing. The panel's values of its shared options go to every other panel whose type has them, the `baseline` (with its `auroc`) only where the type takes its `Mode` (a PSTH or a heat map of spikes: `none`, `subtract`, `zscore`, `percent`, `auroc`; a rate or tuning panel: `none`, `subtract`, `ratio`, `zscore`; a continuous, unit correlation or signal heat map panel: `none`, `subtract`); its other options go to the other panels of its own type, and panels of other types keep theirs; its axis sides (`xSide`, `ySide`) go to every other panel, while its label texts (`xLabel`, `yLabel`), like its `title`, stay its own. `changed` is a struct array, one entry per other panel that changed or kept its baseline: `id`, `fields` (the options, and `xSide` / `ySide`, whose values changed) and `kept` (`"baseline"` when its type does not take the `Mode`, `"stack"` when it does not take the `stack` value, e.g. a continuous panel's `"items"`) |
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
| `trial` | Trial measure | `trials` | no | one number per trial from its events or parameters ([Trial measures](#trial-measures)) |

`units` and `detected` are in two categories: the panel type decides which
(`EphysAnalysisConfig.categoryOf(source, type)` is the category the type
accepts for the source, or `""`). An `events` layer is `point` on every panel
that shares the time axis (raster, PSTH, continuous, heat map, spectrogram,
event traces) and nothing elsewhere (so not on a firing rate, tuning, spectrum
or coherence panel). A heat map takes `point` or `continuous` layers. An
event-trace panel takes events layers only: `units`, `detected` and the
signals are `""` there. A `trials` layer is `trial` on a trial distribution,
histogram or scatter panel, which take nothing else, and `""` elsewhere.

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
with its reason, which a small "cannot draw" sign at the panel's bottom left
holds (point at it or click it to read it); the panel's other layers are still
drawn. The reasons: `the observed unit has no recording
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
- Time panels stacked flush, one on the other, are labeled once; the stacks
  are read from the rects (`figureNeighbors` at `RectTol`). A time panel's x
  tick labels and label are hidden when the panels that touch its bottom edge
  (an edge within `RectTol` of it, sharing at least half the narrower one's
  width) are all time panels with the same limits. Otherwise (nothing touching
  it there -- two time panels with a gap between them both keep their labels
  --, a panel with another kind of x axis such as waveforms or a legend panel,
  or other limits) it keeps its ticks and is labeled `Time (s)` (its `xLabel`, when set): the bottom of a stack is
  always labeled. A raster also drops its y ticks in its bottom tenth where it
  meets the panel below, unless its ticks name its blocks.
- A time panel whose x axis is on top (`xSide "top"`) looks up instead: it
  hides its tick labels and label when the panels touching its top edge are
  all time panels with the same limits whose x axis is on top too. So a
  stack with every x axis on top is labeled once, at its top (a raster then
  drops its y ticks in its top tenth). A panel with its x axis at the bottom
  over one with its x axis on top hides its own: the lower one tells the time,
  between them. Axes facing away from each other (the upper one's on top, the
  lower one's at the bottom) both keep theirs.
- A time panel with a `ref` or `window` of its own keeps its own x axis and
  label, and the stack above it is labeled at its own bottom.
- A panel narrower than its rect (a note band left or right of it) keeps its
  time tick labels, and so does the panel it sits on.
- Events layers go only on the panels of these types, since marks need a time
  axis. A spectrogram shares it (it is always on the aligned base). A coherogram
  (a coherence panel with `overTime`) is drawn on the figure's time axis too,
  but takes no events layers: only the types with `SharesTime` in the table do.

### Placing panels

Each panel's place is its `rect`, `[x y width height]` in 0-1 of the page
from its bottom-left corner. Static functions edit a figure entry (`fig =
cfg.Figures(k)`) as a value, with no graphics; the app's Panel and Layout sections call
the same ones. None of them moves a panel it does not name: a panel keeps its
rect until it is placed again.

| Call | Does |
| --- | --- |
| `fig = EphysAnalysisConfig.placePanel(fig, panel, where, anchorId, rect)` | adds `panel` (a partial panel struct, normalized; a blank id becomes `<type>_<n>`; a rect it gives is not used) by `where`: `"free"` (the default): the largest empty rectangle of the page (`freeRect`); with none, as `"below"` `anchorId`, and with no anchor either `EphysAnalysisConfig:NoRoom`. `"below"`, `"above"`, `"left"`, `"right"`: the anchor's rect is cut in two flush halves, the anchor keeps the half next to that side and the new panel takes the half on it (below: the anchor the top half). `"rect"`: at `rect`, clipped to the page. The first panel of a figure without panels fills the page, `[0 0 1 1]`, whatever `where`. The new panel goes last: on top of any panel it overlaps. Errors: `EphysAnalysisConfig:NoPanel` (no anchor, or none by that id), `EphysAnalysisConfig:DuplicatePanelId`, `EphysAnalysisConfig:BadRect` (not 4 finite numbers, or nothing left on the page), `EphysAnalysisConfig:NoRoom` |
| `[fig, ids] = EphysAnalysisConfig.placeBlock(fig, block, where, anchorId, rect, Alignment=)` | adds every panel of `block`, another figure entry (a figure saved as a [panel type](EphysAnalysis.md#figure-templates), `FigureTemplate.panelFigure`), as one block: the target rect is chosen as `placePanel` chooses a new panel's (an empty figure: the whole page), and every block panel's rect is mapped from the block's page into it (`x' = x0 + x w0`, `y' = y0 + y h0`, the sizes scaled by `w0` and `h0`), so a raster flush over its PSTH stays flush. A panel id the figure has becomes `<type>_<n>`; `ids` are the block's ids in the figure, in its order (the last `numel(ids)` panels). `Alignment="own"` gives each block panel that takes the figure's `ref`, `window` or `selection` (`"default"`) the block's own, where the block has one; `"figure"` (the default) leaves them following the figure. The block's other fields (observe, size, layout, latency, style, aesthetics, sessions, probe) are not used. Errors as `placePanel`; `EphysAnalysisConfig:NoPanel` also for a block without panels |
| `fig = EphysAnalysisConfig.removePanel(fig, id)` | removes the panel; nothing else moves (its space is free again). `EphysAnalysisConfig:NoPanel` for an unknown id |
| `[fig, k] = EphysAnalysisConfig.orderPanel(fig, id, step)` | moves the panel `step` places in `fig.panels`, the drawing order: +1 brings it forward, -1 sends it back, `Inf` / `-Inf` to the front / back, stopping at the ends; `k` is its index after. The rects stay. `EphysAnalysisConfig:NoPanel` |
| `rect = EphysAnalysisConfig.freeRect(fig, MinSize=0.08)` | the largest axis-aligned rectangle of the page that covers no panel (it may touch one), its edges among the page's and the panels'; of equal areas the lowest, then the leftmost. Rectangles narrower or lower than `MinSize` are left out; `[]` when none is left |
| `pairs = EphysAnalysisConfig.rectOverlaps(fig)` | the panels whose rects overlap by more than `RectTol` (0.005 of the page) both across and up, as `[j k]` index pairs (`j < k`; `zeros(0, 2)` for none). Panels put flush do not overlap |
| `order = EphysAnalysisConfig.panelOrder(fig)` | the panels in reading order: the top edge highest first, then left to right (`sortrows(round([-(y+h) x], 3))`); `order(1)` is the top-left panel |

Three helpers outside the class read or move the rects:

- `figureRectConvert(v, from, to, pageCm, dpi, axis)` converts places on the
  page between `RectUnits`: `"normalized"` (0-1), `"%"`, and `"cm"`, `"in"`
  or `"px"` on a page of `pageCm` (`[width height]` cm; a pixel 1 / `dpi`
  inch, `figureSizeConvert`). `axis` `"x"` or `"y"` measures every value
  along the width or the height; `"rect"` takes rects (`[x y w h]` per row),
  x and w along the width, y and h along the height.
- `N = figureNeighbors(rects, tol)` (rects n x 4, `tol` default `RectTol`)
  says how the rects lie to one another, each field n x n: `xShare` /
  `yShare` (the share of the narrower width / lower height two rects have in
  common), `gapX` / `gapY` (> 0 apart, 0 flush, < 0 overlapping), `below(j,
  k)` (k's top within `tol` of j's bottom and `xShare` >= 0.5: k is under
  j), `above`, `left`, `right` likewise, `inColumn` (`xShare` >= 0.5),
  `flushV` / `flushH` (stacked or side by side within `tol`, sharing more
  than `tol` the other way).
- `[rects, info] = figureAlign(rects, which, how, Feature=, To=, Gap=, Layout=)`
  lines up the panels `which` (rows of `rects`, the first the one others can
  be lined up with) or spaces them evenly, as the app's Arrange bar does:
  `how` `"left"`, `"center"`, `"right"`, `"top"`, `"middle"`, `"bottom"`,
  `"spaceX"` or `"spaceY"`. They only move, along one axis, and stay on the
  page. `Feature` `"box"` (the rects, the default), `"axes"` or `"labels"`
  (the plot areas, or the axes with their labels, as laid out: give `Layout`,
  the drawing's `getappdata(canvas, 'FigureLayoutResult')` with its panels
  in the order of `rects`). `To` `"selection"` (default), `"first"` or
  `"page"`. `Gap` `[]` (even gaps; the outermost stay) or the gap, 0-1 of the
  page along that axis (`figureRectConvert` turns a length into it). For
  spacing, panels overlapping across move as one column (rows for
  `"spaceY"`). `info`: `moved` and `held` (a rect that could not get where it
  should) per panel, `groups`, `room` and the `gap` left.

```matlab
f = cfg.Figures(1);                                                   % raster_1 over psth_1
f = EphysAnalysisConfig.placePanel(f, struct('type', "continuous"), "below", "psth_1");   % psth_1's bottom half
f = EphysAnalysisConfig.placePanel(f, struct('type', "legend"), "rect", "", [0.8 0.8 0.2 0.2]);   % over the raster's corner, drawn on top
T = EphysAnalysisConfig.figureTemplates();
block = EphysAnalysisConfig.normalizeFigure(T.Figure{T.Template == "rasterPsth"});
[f, ids] = EphysAnalysisConfig.placeBlock(f, block, "right", "continuous_1");
% ids = ["raster_2" "psth_2"]: the right half of continuous_1's rect, the raster flush over the PSTH
cfg.Figures(1) = f;
```

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
| `starred` | the observation is starred ([favorites](EphysAnalysis.md#favorites-stars): a sorted unit on the sort in use, a detection channel or a channel by its recording channel, the dataset by its own star). `observe.starred` keeps only these rows; `figureCaption` counts them. `figureObservations(src, spec, Favorites=fav)` takes the stars from a `DatasetFavorites` in memory instead of reading the file |

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

`[h, how] = renderFigure(F, spec, target, Design="", UserAesthetics=true, Editable="auto", OnRemember=[], DataTips="auto", Reuse=false, InPlaceOnly=false, KeptOnly=false, LayoutOnly=false, PlaceMoved=false, RectsOnly=false, Scale=1)`
draws `F` as `spec` says (the spec `F` was computed with; its `aesthetics` may
differ, as when the aesthetics editor redraws). `target` is an axes (which draws
panel 1 only), uiaxes, figure, uifigure, panel, tab or grid layout;
renderers never create figures. `Design` names a [plot design](EphysAnalysis.md#plot-designs) for this drawing (default: the user's chosen one), `UserAesthetics=false` leaves the user's remembered rules out, `Editable` (`"auto"`: in a visible figure) turns the right-click editing on or off, and `OnRemember` is called with a figure's new rules ([Plot aesthetics](EphysAnalysis.md#plot-aesthetics)). `OnSelect` is called with a panel's id and whether Ctrl was down when a drawn panel (its axes, labels and what is drawn in them) is clicked with Ctrl or the right button; the app selects that panel in its editor on a Ctrl+Click. `DataTips` (`"auto"`: in a visible figure, as `Editable`; `true` or `false`) gives every part drawn data tips that name what the point is (`FigureDataTips.attach`, below). `Reuse=true` (the app's preview) keeps the panels of the target's last drawing that would be drawn alike, found by their ids (a panel removed or moved up the list leaves the others kept; a renamed figure keeps its panels), and draws only the others, the kept ones dressed again from how they were drawn, so the figure is the same as a whole drawing ([Render](EphysAnalysis.md#render) says when a panel is kept); an edit of text alone (a panel's `xLabel`, `yLabel` or `title`, the figure's `title`) draws nothing: the text is set on what is drawn; nor does an edit of the panels' `rect`s or the figure's `layout` alone (with or without such text): what is drawn is laid out again at the new places, unless the edit changes which panels touch which (a time stack's labels), the top-left panel, or the panels or their order, which draws as above. `InPlaceOnly=true` makes only such an edit and draws nothing otherwise. `KeptOnly=true` makes only a drawing that keeps every panel (or such an edit) and does nothing otherwise. `LayoutOnly=true` lays the drawing the target keeps out at `spec`'s rects and `layout` whatever else differs, and draws and sets nothing (a time stack's labels stay as drawn; the drawing kept is unchanged, so the next `Reuse` drawing compares with what it shows); `spec` may leave panels of the drawing out or give them in another order (by id): those left out are deleted, the rest stacked in the new order, and the drawing kept keeps only them, so the next `Reuse` drawing keeps them by id; only when every panel of `spec` is in the drawing, else nothing. `PlaceMoved=true` (with `InPlaceOnly` or `LayoutOnly`, for an edit of the panels' `rect`s alone) lays out only the panels whose rects changed since the last layout: their parts alone are put back where a new drawing starts and measured, and the others keep their places and last measures unless `figurePlace` moves them (a neighbor flush with a moved panel, whose shared edge moved); anything else, or a layout that does not fit the last one, is laid out whole. It is `figureLayout`'s `Moved=` (which panels) and `Reset=` (puts their parts back). `RectsOnly=true` (with `InPlaceOnly`; implies `PlaceMoved`) is for a caller that knows `spec` differs from the drawing in its panels' rects alone: nothing else is compared, and when which panels touch which and the top-left panel are as drawn the moved panels are laid out, else nothing is done. `how` says what was done: `"drawn"`, `"kept"` (`Reuse` kept every panel), `"inplace"`, `"layout"` (`LayoutOnly`), or `""` (`InPlaceOnly`, `KeptOnly` or `LayoutOnly` and nothing done; `h` is then `[]`). `Scale=S` draws a figure shown `S` times as wide as its export page at 96 dpi (the app's preview and *Open in window*): it is drawn as the export is (on the export page's size first, so the automatic ticks and limits are the export's), then every font size, line width, marker size, error bar cap and legend token is multiplied by `S` (a scatter's marker area by `S`²; `PlotAesthetics.scaleSizes`), whatever set it -- the style, the panel type's own markers, the design, the remembered looks, the figure's own -- and so are the layout's margin and padding, so the drawing has the proportions of the exported file (and of the report, which shows the exported pages). The target keeps `S` (`PlotAesthetics.drawScale`): `PlotAesthetics.getValue` and `setValue`, and so the aesthetics editor and `PlotDesign.capture`, read and set the sizes as exported.

- **Layout.** renderFigure lays its panels out itself (not with MATLAB's tiled
  layout): `target`, emptied (a grid layout gets a borderless panel; `h.layout`),
  holds one axes per panel (no panel shows MATLAB's axes toolbar, the icons
  that appear over a plot on hover; a probe figure's tiles neither), and once everything
  is drawn and dressed (its looks final) `figureLayout` measures the room each
  panel's labels take (its axes' `TightInset`, on the sides where tick labels,
  an axis label, a title or a color bar outside sit: a tick label that only
  reaches past a corner keeps no neighbor away) and places every axes in pixels
  (`figureArea` and `figurePlace`, both pure):
  - the page is the target inside a margin of 6 px; the title and dataset
    subtitle sit in a band at its top (a hidden axes, Tag `titleHost`, holds
    them: the editor's `plotTitle` and `plotSubtitle`), and the area under it
    is where the panels go. Each panel's `rect` is read in the page, so its
    place in cm never moves when the title changes;
  - with `layout.boxesMean` `"plot"` (the default) a rect is the panel's plot
    area, moved in only as far as its labels need: a side with labels at the
    area's edge (the margin, the title band) moves in by its labels' room and
    `layout.padding` (cm, at 96 dpi); two panels apart (their extents across
    sharing more than 2 px) get between their plot areas the room their facing
    labels take and the padding, the shortfall split between them in
    proportion to their labels' room; edges that line up (within 2 px) all
    move as far as the furthest of them, so plot edges that lined up still do
    (a panel can move in for a neighbor it merely lines up with). Boxes only
    shrink, never shift or grow, and never below 12 px a side (the labels may
    then overlap). Two panels put **flush** (facing edges within 2 px) stay
    flush: their shared edge is snapped and nothing moves there, whatever
    labels face each other (a time stack has none there; a panel that keeps
    labels on that side draws them over its neighbor). Overlapping rects are
    left alone, the later panel on top. With `"outer"` a rect holds the panel
    with its labels: the plot area is the rect, kept in the area, less the
    labels' room and the padding on each side with labels;
  - a panel's note's band (below) comes off its plot area, and a coherence
    panel's phase strip takes the bottom third of what is left; a trial
    scatter's marginal strips (its draw's `extraLayout`, kind `"marginals"`)
    split it instead: the plot `1 - marginalSize` of it each way, the x strip
    over it (under it with the x axis on top) and the y strip right of it
    (left with the y axis on the right), flush, its labels' room the largest
    of the three axes' on each side; a legend panel has no labels and is never
    moved for any;
  - it measures again at the new sizes (an axes' size can change its tick
    labels) and places again when the room changed; then the legend (below)
    and the notes;
  - the target keeps where everything went (appdata `FigureLayoutResult`: the
    page, area and title band, each panel's rect in px (`outer`), plot area
    (`box`), axes, band, how far each side moved in (`nudged`) and whether
    the 12 px floor stopped it (`clipped`), `figureNeighbors` of the rects in
    px, and the legend's box and mode), for the app's overlay;
  - `target` is laid out again whenever it changes size (a listener of its
    `SizeChanged` event; its `SizeChangedFcn` stays its owner's), so a figure in
    a panel or window that is resized follows it (the app's preview), and an
    export figure is laid out at its own size. The axes go straight into a figure,
    not into a panel of it: `print` writes no SVG of a figure holding UI components.
  The layout is deterministic: the same figure at the same size is drawn the
  same, pixel for pixel. Into an axes target only panel 1 is drawn.
- **Panels.** Each type's draw function (through `figurePanelRegistry`) draws its
  layers. No reason is written in a panel, where a long one would run over its
  neighbors: a panel with nothing to draw shows a "cannot draw" sign in its
  middle (`brokenGraphic`: a light gray square struck through by a red cross,
  two marker lines of role `layerNote` that keep their size in pixels and
  their place as the axes change), a panel that skipped some layers a small
  one at its bottom left. The sign keeps the reasons (appdata `LayerNote`, a
  line each), which are its data tip and show in a window (`uialert`) on a
  click; in a visible figure drawn in a panel or tab (the analysis app's
  preview), `brokenGraphicTips` lays a clear image over each sign whose
  tooltip is the reasons, so pointing at it shows them. A figure window and
  an export get no image (print writes no SVG of a figure holding UI
  components). Every object carries an aesthetics role, so the editor lists
  the components, the tiles by panel id; the figure adds the roles `eventLine`,
  `eventRug`, `eventSpan`, `layerNote` and the event-trace panel's `eventBar`,
  `eventTick`, `eventLevel`, `eventBaseline` and `eventGroupBand`, and a continuous panel's per-trial traces are the
  role `trialTrace` ("Trial traces"); the trial panels' roles are listed under [Trial measures](#trial-measures).
- **Notes and overlays.** A panel's `overlays` are drawn on its axes after its
  layers (`drawOverlays`: every one of them, a panel having no raster / data
  choice; a coherence panel's x overlays also go on its phase strip, which shares
  its x axis), over or under the data as each says. A panel's `note` is drawn by
  `drawNote`. Placed `"below"`, `"above"`, `"left"` or `"right"`, it takes a band
  of the panel's area beside its axes: a hidden axes (Tag `noteHost`) holding
  the text, fitted to the text as drawn (its looks final) and to the axes' tick
  labels and label on that side, which sit in the band next to the axes, never
  more than half the panel's area. A band below or above leaves the axes' left
  edge and width equal to those of a plain panel of that rect; a panel with a
  band left or right is narrower than its rect, so it keeps its own time tick
  labels, and so does the panel it sits on (the shared time axis is not hidden
  for that pair). A
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
- **Legend.** One (none with `Style.LegendLocation` `"none"`): the trial groups
  once, then the layers', units', channels' and marks' entries, each label
  once. It never shrinks a plot area. `"auto"`: in the figure's
  [legend panel](#panel-types) when it has one (at its natural size, aligned
  in the panel's box by its options); else floating, centered in the page's
  largest free space (`freeRect` over the panels' rects and their plot areas
  with their labels) when it fits there with the padding round it; else inside
  the first panel (Location `"best"`). Laid out again with the panels, so a
  floating legend follows them. `"inside"`: inside the first panel. No panel
  keeps a legend of its own but one with a trial selection of its own, which
  lists its own groups and entries in a legend inside it.
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
drawn under its magnitude, or a trial scatter's marginal strips (the x strip, then
the y strip), dressed with the type's looks; empty for
every other panel; `note`, the text object of its note, empty without one; and
`overlays`, the lines and patches drawn on it) and `title` (the title text).
`renderFigure:Mismatch` when `F`'s panels are not the spec's, `renderFigure:BadTarget`
for a target it cannot draw into (a tiled layout, say).

A probe figure's result (`figureProbeCompute`'s `PF`, `kind` `"probeFigure"`: see
[Probe figures](#probe-figures)) is drawn by `renderProbeFigure` (the figure's
panels as a small tile at every unit's or channel's site on one page,
[Render](EphysAnalysis.md#render)): `renderFigure(PF, spec, target, ...)` hands it
over with the same options before anything is cleared and returns its `h` and
`how`. Its target is a figure, panel, tab or grid layout (an axes is refused,
`renderProbeFigure:BadTarget`); `DataTips` is off unless `true`, `Reuse` is ignored
(the page is drawn whole) and `InPlaceOnly` draws nothing.

### A figure in JSON

A raster flush over a PSTH over an LFP panel, all following the unit, with the
stimulus offset marked on every raster row. The `"..."` stand for the rest of a
nested block (as in the [JSON example](#json-example) above); the config's
`Defaults` give the alignment (`"default"`), the three panels are stacked
flush over the page, the raster's plot area 1.5 times as tall as each of the
others (its `rect` 0.43 of the page, theirs 0.285), and the options shown are the types'
defaults. A file written by hand may leave out any field that keeps its default.

```json
"Figures": [
  { "id": "unit_card", "autoId": false, "enabled": true, "title": "",
    "observe": { "data": "units",
                 "units": { "classes": ["su"], "groups": [], "ids": [], "channels": [], "shanks": [], "maxUnits": "Inf",
                            "merge": { "enabled": false, "...": "..." },
                            "quality": { "enabled": false, "...": "..." }, "response": { "enabled": false, "...": "..." } },
                 "channels": [], "starred": false, "perGroup": false },
    "layout": { "boxesMean": "plot", "padding": 0.15 },
    "ref": "default", "window": "default", "selection": "default",
    "sessions": { "enabled": false, "datasets": "ticked", "datasetKeys": [], "facet": "none", "series": "session",
                  "colorOrder": "palette", "showMembers": false, "error": "sem", "match": "site", "mappingFile": "",
                  "minSessions": 1, "trialGroups": "pool" },
    "probe": { "enabled": false, "layout": "schematic", "overlap": "nudge", "lanes": 2, "shanks": [], "channels": [],
               "depthRange": [], "maxTiles": 64, "maxPerSite": 3, "tileWidth": 0.9, "tileHeight": 0.9, "tileScale": 1,
               "labels": "short", "sharedY": true, "scaleTile": true, "showSites": true, "leaders": true },
    "latency": { "method": "first", "minSec": 0, "maxSec": "Inf", "baseline": "pre", "baselineWindow": [-0.1, 0],
                 "baselineRate": "unit", "alpha": 0.01, "surprise": 3, "minSpikes": 3, "cusumBinSec": 0.002,
                 "cusumThreshold": 5, "cusumDrift": 1, "cusumSustainSec": 0.005 },
    "panels": [
      { "id": "raster_1", "type": "raster", "title": "", "box": "auto", "rect": [0, 0.57, 1, 0.43],
        "ref": "default", "window": "default", "selection": "default",
        "layers": [
          { "name": "", "enabled": true, "source": "units", "binding": "observation", "aggregate": "each", "...": "..." },
          { "name": "Stim offset", "enabled": true, "source": "events", "binding": "fixed", "eventsAs": "marks",
            "event": { "line": "Stim", "edge": "offset", "which": "all", "n": 1, "scope": "recording",
                       "minDurationSec": 0, "maxDurationSec": "Inf", "timeRange": ["-Inf", "Inf"], "offsetSec": 0,
                       "offsetParam": "", "offsetParamUnit": "ms", "sequence": [], "alignStep": "Inf",
                       "marker": "diamond", "size": 4, "color": "" } } ],
        "options": { "rasterSort": "", "rasterSortEvent": [], "rasterSortOrder": "ascending", "rasterByGroup": true,
                     "maskAfterStop": false, "tickColor": "groups", "tickWidth": 0, "backColor": "none", "yTicks": false,
                     "firstSpike": { "enabled": false, "marker": "o", "...": "..." }, "onsetLine": "off",
                     "waveform": { "mode": "off", "...": "..." } } },
      { "id": "psth_1", "type": "psth", "title": "", "box": "auto", "rect": [0, 0.285, 1, 0.285],
        "ref": "default", "window": "default", "selection": "default",
        "layers": [ { "name": "", "enabled": true, "source": "units", "binding": "observation", "aggregate": "each", "...": "..." } ],
        "options": { "bins": { "BinSec": 0.01, "SmoothSec": 0.01 }, "measure": "rate",
                     "baseline": { "Mode": "none", "Window": [-0.2, 0] }, "histStyle": "bar", "fill": true,
                     "fillAlpha": "NaN", "smoothLine": { "enabled": false, "smoothSec": 0.025, "legend": true },
                     "normalize": "none", "maskAfterStop": false, "yLim": [],
                     "latencyBox": { "enabled": false, "color": "groups", "...": "..." }, "onsetLine": "off", "trialCount": "off",
                     "waveform": { "mode": "off", "...": "..." } } },
      { "id": "continuous_1", "type": "continuous", "title": "", "box": "auto", "rect": [0, 0, 1, 0.285],
        "ref": "default", "window": "default", "selection": "default",
        "layers": [ { "name": "", "enabled": true, "source": "LFP", "binding": "observation", "aggregate": "each", "...": "..." } ],
        "options": { "baseline": { "Mode": "none", "Window": [-0.2, 0] }, "statistic": "mean",
                     "transform": "none", "errorType": "sem", "stack": "off", "stackSpacing": 1.1, "trials": "off", "maxTrials": 100, "yLim": [] } } ],
    "style": { "LineWidth": 1.2, "...": "..." }, "aesthetics": [] } ]
```

`observe.data "units"` draws it for each sorted unit, which the units layers
follow; the LFP layer follows too, reading the column of the LFP extract that
records the unit's channel. The three panels share the time axis, so only
the bottom one is labeled. The events layer is `fixed`, as every events layer
is, and its `event` is an [EventMark](#raster-event-marks). The `sessions` block shown
is the default, a figure drawn per dataset; ticking `enabled` makes it a
[session figure](#session-figures). Each panel also holds its `xLabel`, `yLabel`, `xSide`,
`ySide`, `xShow` and `yShow`, a `note` and a list of `overlays` ([Panel fields](#panel-fields)), left out above: `"note"` is a
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
- `probe` (`<figure>.probe.<field>`): the known values, whole numbers and shares
  and, with `probe.enabled`, neither `sessions.enabled` nor a `dataset`
  observation: the rules are under [Probe figures](#probe-figures);
- `layout`: `boxesMean` `plot` or `outer` (`<figure>.layout.boxesMean`); `padding`
  a finite number >= 0 (`<figure>.layout.padding`);
- panels: an id of their own; a `rect` of 4 finite numbers inside the page, `x`
  and `y` >= 0, a width and height > 0, `x + width` and `y + height` <= 1
  (`A panel's rect is [x y width height], inside 0-1 of the page, with a positive
  width and height.`, at `<figure>.<panel>.rect`); a known `type`; one legend
  panel at most (`A figure has one legend panel at most (legend_1, legend_2).`,
  at the second one's `type`); a legend panel's `orientation` (`auto`,
  `vertical`, `horizontal`), `align`, `valign` and whole `columns` >= 0;
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
  events layers only (a digital or derived line each), not units.`); only trials
  layers on a trial panel (`A trial distribution panel draws trials layers only (a
  trial measure each), not units.`) and a trials layer only there, always fixed
  (`A trials layer is always fixed: its measure names its events or parameter.`);
  a trials layer's `measure` (a scatter's `xMeasure` too), at
  `<figure>.<panel>.layers(<j>).measure.<field>`: `kind`, `from` and (delay,
  count) `to` as event references, `direction`, `maxGapSec` above 0, a `param`
  kind's parameter name, `unit` `ms` or `s`, and the `label`'s label variables (a
  warning); a `lineStyle` that is
  `""`, `-`, `--`, `:` or `-.`;
- a raster whose enabled layers are all events drawn as marks or spans (`A raster's marks
  need rows: add a units, detected or train layer`);
- options, by type: a raster's `rasterSortOrder` and, with `rasterSort "event"`, a
  valid `rasterSortEvent`; a PSTH's `trialCount` (`off`, `text` or `legend`) and
  `smoothLine.smoothSec` (0 or more); an
  event trace's sub-rows with `rasterSort "latency"` (a warning: no spikes); a raster's `firstSpike` and a PSTH's `latencyBox` while
  `enabled` (the marker and a positive size;
  the box's `lineStyle`, a positive `lineWidth`, `boxHeight` from 0.02 to 0.5,
  `fillAlpha` from 0 to 1, the outliers' marker and a positive size; a `color`
  that is not `groups` or a color is a warning); a raster's or PSTH's
  `onsetLine` (`off`, `unit` or `groups`); the figure's `latency` block, at
  `<figure>.latency.<field>` (`method`, `baseline` and `baselineRate` known
  values, `minSec <= maxSec`, a `baselineWindow` [lo hi] with lo < hi, `alpha`
  in (0, 1), `surprise > 0`, a whole `minSpikes >= 2`, `cusumBinSec` and
  `cusumThreshold` above 0, `cusumDrift` and `cusumSustainSec` 0 or more; on a
  figure with a raster, PSTH or heat map and a fixed window, warnings for a
  window that misses the figure's, a Poisson rule or an onset line taking its
  baseline from before the event when the window starts at or after it, and a
  baseline window off the figure's); a PSTH's `bins` (`BinSec > 0`, `SmoothSec >= 0`),
  `measure`, `baseline` (`Mode` among the type's, a window `[b0 b1]` with `b0 < b1`),
  `auroc` (with baseline `Mode "auroc"`: the auROC rules ([auROC](#auroc)), its window
  and step whole numbers of the panel's bins, and the Statistics and Machine Learning
  Toolbox, at `<figure>.<panel>.options.auroc`), `histStyle`, `normalize`, `fillAlpha`,
  `display` (`trace` or `heatmap`), `colormap` (a name that
  is no colormap function is a warning), `cLim`, `yLim`; a continuous panel's `baseline`
  (`none` or `subtract`, its window overlapping the panel's window), `statistic`, `transform`, `errorType` (`ci95`
  and `iqr` need the Statistics and Machine Learning Toolbox),
  `trials` (`off`, `faint` or `only`), `maxTrials` (a whole number
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
  settings of a raster, PSTH, rate, tuning or waveforms panel (mode, and for a waveforms
  panel never `off`; `ampScale` `unit`, `common` or `fixed`; while drawn: location,
  `width` and `height` in (0, 3], whole `maxSpikes >= 1`, `timeMs` `[]` or ascending
  (`-Inf` / `Inf` allowed), and with `fixed` an ascending `ampLim`);
  `yLim` and `cLim` `[]` or ascending; `yLimMode` one of `auto`, `rows`, `batch`,
  `fixed`, and `fixed` with a `yLim`; on every type that stacks ([Stacks](#stacks))
  a `stack` the type takes (`stackModes`: `off` or `groups`, a continuous panel's
  `items` too) and a positive `stackSpacing` (a heat map of trials' `stack` other
  than `off` is a warning: not used); an event-trace panel's `display` (`bars` or
  `line`), `trials` (`overlay` or `rows`), `colorBy` (`layer` or `group`), `height`
  in (0, 1], `alpha` from 0 to 1 or `NaN`, `lineStyle` and `baselineStyle`, and
  positive `edgeWidth`, `lineWidth`, `baselineWidth` and `rowSpacing`, a
  `minWidth` of 0 or more, and with `trials "rows"` its sort as a raster's
  (`rasterSortOrder`, a `rasterSortEvent` for `rasterSort "event"`) (an
  `edgeColor` or `baselineColor` that is not a color is a warning); a [trial
  panel's](#trial-measures) `categories` and `series` (`TrialGroupings`; a
  `"param"` one with its parameter named; not grouping alike), the bins (`[]`, a
  whole count or ascending edges), `display`, `summary`, `errorType`
  (`AuxErrorTypes`), `test` (`TrialTests`; the Statistics and Machine Learning
  Toolbox unless `none`), `testPairs`, `adjust`, `testShow` (`brackets` on a
  distribution only), `bracketPairs`, `showN`, `normalization`, `binMode`, `fit`
  (`TrialFits`), `corr`, `xScale` and `yScale`, `testAlpha` in (0, 1), `alpha`
  (an opacity) and `jitter` from 0 to 1, a positive `markerSize` and `binWidth`, a whole
  `binCount` >= 1 and `fitWindow` >= 2, `marginalSize` from 0.1 to 0.5, and `xLim`
  / `yLim` `[]` or ascending; a scatter's delay to every B (`to.which "all"`)
  is a warning at `<...>.measure.to.which` (the first value per trial is paired);
- a name in braces in the figure's `title`, a panel's `title`, `xLabel`, `yLabel`
  or `note.text`, or a layer's `name`, that is no [label variable](#label-variables)
  is a warning at that field (it is drawn as typed), naming the variable it likely
  meant when one differs only in case (*{line} ... did you mean {Line}?*); in a
  TeX note only such a near miss is reported (its braces group);
- each panel's text note and overlays, by one function's rules ([Panel notes](#panel-notes), [Panel overlays](#panel-overlays)): a note with no text is not
  checked (a panel of an unknown `type` has its note and overlays checked all the same; `box` is `auto`, `on` or `off`,
  `xSide` `bottom` or `top`, `ySide` `left` or `right`, `xShow` and `yShow` `all`, `ticks`, `label` or `none`),
  else its `placement`, a finite `x` and `y` for `"custom"` (`0-1 across and up the panel`), `align`, `valign`,
  `interpreter`, a finite `rotation` and a positive (or `NaN`) `fontSize`; an overlay's
  `shape`, a finite `value` (line) or two different finite `from` and `to` (region), `axis`,
  `layer`, `lineStyle`, a positive `lineWidth` and `alpha` / `faceAlpha` from 0 to 1. A
  panel's overlay `panel` is always `"all"` (`normalizePanel`: its overlays are drawn on its
  own axes), so there is no warning that a panel of the named kind is absent;
- each panel's own error: a PSTH's, rate or tuning panel's `errorType` (`PanelErrorTypes`;
  `"ci95"` needs the Statistics and Machine Learning Toolbox), `errorResamples` (a whole
  number >= 1) and `band` (`faceAlpha` 0-1 or `NaN`, `edgeStyle`, `edgeWidth` > 0);
- the figure's `style` (`MaxTiles >= 1`, `TileSpacing`, the legend settings, the font size,
  line width and site size, the colormaps).

Warnings:

- a figure with no panels; two panels whose rects overlap by more than `RectTol`
  both ways (`Panels "a" and "b" overlap: the later one is drawn on top.`, at the
  later one's `rect`; panels put flush, or a hair into each other, do not);
- a panel with no enabled layer (not a legend panel: it draws none, and any
  layer on it is a warning); several enabled layers on a type that draws one
  (only the first enabled one is drawn; not for a waveforms panel in the probe
  layout, whose further layers ring their units);
- a waveforms panel in the probe layout whose first enabled layer follows the
  observation (`<panel>.options.layout`): it draws the one unit, not the probe's
  units, so bind it to fixed units and ring the observed unit with a following layer;
- a coherence panel whose fixed seed layer keeps several channels or units
  (`<panel>.layers(<j>)`): only the first is the seed, so fix the layer to one;
- a unit or channel observation with no layer following it (`<figure>.observe.data`:
  the figure is the same for every one);
- `observe.perGroup` while the figure's selection groups by nothing (not for a session or probe figure; `<figure>.observe.perGroup`:
  one figure per observation, as without it);
- a probe figure's warnings ([Probe figures](#probe-figures)): `observe.perGroup` (ignored),
  a probe map panel and a waveforms panel in the probe layout (a probe inside each tile);
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

### Probe figures

A figure with `probe.enabled` is a *probe figure*: the whole figure (all its
panels, at its grid) drawn once per unit or channel as a small *tile* at that
observation's site on the probe, every tile on **one page per dataset**. The
observation kind stays `observe.data` (`units`, `detected`, or a signal's
channels; not `dataset`), and `observe.units` and `observe.starred` filter the
units as for every figure. A figure never refers to another one, so to lay an
existing figure out on the probe, duplicate it (**Duplicate** in the Figures tab,
`cfg.duplicateFigure`) and tick **On the probe** on the copy, or tick it on the
figure itself. A probe figure runs per dataset, as any figure (`enabledFigures`
lists it); it is not also a [session figure](#session-figures).

```matlab
[cfg, id] = cfg.addFigure("rasterPsth", Id="probe_rp");
k = cfg.figureIndex(id);
cfg.Figures(k).probe.enabled = true;                     % a tile per unit, at its site, one page
cfg.Figures(k).probe.maxPerSite = 2;                     % at most two units on one recording channel
spec = cfg.figureFor(id);
r = EphysAnalysisRunner(cfg);
src = r.source(1);
[T, left] = figureProbeTiles(src, spec);                 % the units with a site, as laid out; left: how many were left out
PF = figureProbeCompute(src, spec);                      % the whole figure for every tile, no graphics
renderFigure(PF, spec, newExportFigure(cfg.Export, PF, spec));   % draw the page (renderProbeFigure)
R = r.run(Figures=id, SessionFigures=string.empty(1, 0));   % or the page of every dataset
```

`probe` is `defaults("FigureProbe")`:

| Field | Default | Meaning |
| --- | --- | --- |
| `enabled` | `false` | `true`: a probe figure. False keeps the block and leaves it unused |
| `layout` | `"schematic"` | `"schematic"`: each shank a column band, the sites clustered into rows by y (a tolerance of half the median pitch), the rows equally spaced, the depth in µm written at the rows, so tiles never overlap; `"physical"`: y in proportion to the sites' µm, x by the shanks' µm, tiles sized from the median site pitch, kept apart by `overlap` (`ProbeLayouts`) |
| `overlap` | `"nudge"` | physical: `"nudge"` (the tiles of a column slide apart along the shank, keeping their order and the column's extent), `"lanes"` (the column's tiles alternate across `lanes` lanes beside the shank, then nudge within a lane), `"shrink"` (every tile shrinks, aspect kept, to the largest size that clears) or `"allow"` (drawn as they fall) (`ProbeOverlaps`) |
| `lanes` | `2` | overlap `"lanes"`: the lanes beside each shank (a whole number >= 1) |
| `shanks` | `[]` | `[]` = all; else the `kcoords` shank numbers whose sites are laid out |
| `channels` | `[]` | `[]` = all; else the recording channels (1-based) whose sites are laid out |
| `depthRange` | `[]` | `[]` = all; else `[lo hi]` µm of probe y kept (lo < hi) |
| `maxTiles` | `64` | the most tiles on the page (a whole number >= 1): more observations keep every k-th in probe order (`round(linspace(1, n, maxTiles))`), and the page says how many were left out |
| `maxPerSite` | `3` | the most units drawn on one recording channel (a whole number >= 1): the first in probe order; several on a site share its band side by side |
| `tileWidth` | `0.9` | a tile's share (0, 1] of its column band's width |
| `tileHeight` | `0.9` | schematic: a tile's share (0, 1] of its row's height; physical: of the median site pitch (then times `tileScale`) |
| `tileScale` | `1` | physical: multiplies the tiles' size (> 0, finite) |
| `labels` | `"short"` | each tile's label: `"short"` (the unit's short label, `ch 7`), `"full"` (the observation's label) or `"none"` (`ProbeTileLabels`) |
| `sharedY` | `true` | each panel on one y range across the tiles (the union of their extents) |
| `scaleTile` | `true` | the bottom-left tile keeps its tick and axis labels: the page's scale, valid for every tile while `sharedY` |
| `showSites` | `true` | the shank bodies and sites drawn pale behind the tiles |
| `leaders` | `true` | physical: a line from a moved tile to its site |

`cfg.isProbeFigure(id)` (an id or an index) and `cfg.probeFigureIds()` (enabled or
not) tell them apart; `EphysAnalysisConfig.ProbeLayouts`, `ProbeOverlaps` and
`ProbeTileLabels` are the choices.

`[T, left, sites] = figureProbeTiles(src, spec)` picks the tiles:
`figureObservations(src, spec)` with `perGroup` off; the rows with a finite
position (a unit's `meta{1}.x` / `.y` from the probe map, a channel's); those
`shanks`, `channels` and `depthRange` keep; at most `maxPerSite` per recording
channel; then at most `maxTiles`. `T` gains `x` and `y` (µm); `left` counts
`total`, `noPosition`, `filtered`, `overSite`, `overMax` and `kept` (the first is
the sum of the others); `sites` is every site of the probe map (`channel`, `x`,
`y`, `shank`, `included`). `[PF, K] = figureProbeCompute(src, spec, Check=,
Reuse=, ProgressFcn=)` computes each tile with `figureCompute(...,
Observation=T(i, :), Reuse=)`, the steps the tiles share (the figure's epochs, the
skip reasons) computed once; `PF` holds `kind` `"probeFigure"`, `id`, `spec`,
`dataset`, `observation` (kind `"probe"`, label *23 units at their sites*),
`probe` (the map), `sites`, `tiles` (one per row of `T`: `observation`, `x`, `y`,
`shank`, `channel`, `F`, `skip`, a tile that fails being kept with its message),
`left`, `nTiles`, `epochs` and `groups` (the first computed tile's, for the
legend). `EphysAnalysisRunner.computeProbeFigure(src, spec, Reuse=, ProgressFcn=)`
wraps it with the runner's checkpoint and `FigureCache`, so the preview's look
edits, and edits of the probe block (it counts only as on or off in each step's
key: `figureDataSpec`), compute nothing again. `renderFigure` draws a `PF` with
`renderProbeFigure`.

Validation, at `<figure>.probe.<field>`: `layout`, `overlap` and `labels` known
values; `lanes`, `maxTiles` and `maxPerSite` whole numbers >= 1; `tileWidth` and
`tileHeight` in (0, 1]; `tileScale` finite and > 0; `shanks` whole numbers and
`channels` whole numbers >= 1 (`[]` = all); `depthRange` `[]` or `[lo hi]` with
lo < hi. With `probe.enabled`, errors at `<figure>.probe.enabled`: `sessions.enabled`
too (*laid out on the probe or drawn across sessions, not both*), and an
`observe.data` of `dataset`. Warnings: `observe.perGroup` (`<figure>.observe.perGroup`:
ignored, each observation is one tile), a probe map panel (`<figure>.<panel>.type`)
and a waveforms panel in the probe layout (`<figure>.<panel>.options.layout`): a
probe drawn inside each tile. The default block raises nothing. `figureSkipReason`
skips a probe figure on a dataset without a probe map (*no probe map*) and one
observing the dataset (*a probe figure observes units or channels, not the
dataset*); a dataset with no observation that has a site is skipped with *no
observation with a probe position*.

A run (`runDataset`) draws one page per dataset: its file is
`figureOutputName`'s with `{Unit}` `probe` (an observation of kind `"probe"`), its
caption *probe_rp: 23 units laid out at their sites on the probe (2 shanks) of
RAT1_260918; panels: raster, PSTH; aligned to Stim onset; ...; each panel's y
shared across the tiles* (`figureCaption` with `spec.probe.enabled`), its
`Results` message *23 tile(s)*. With the Export section's size
(`size.source "export"`) the page is `FigureSizeCm(1)` wide and
`max(FigureSizeCm(2), min(80, 2 + nRows * nLevels * 1.5))` cm tall, `nRows`
the rows of tiles `probeTileLayout` lays out and `nLevels` the levels of
panels in a tile (the distinct top edges of their rects, to 0.01 of the page:
2 for a raster over a PSTH) (`figureExportSize`,
`newExportFigure`). A probe figure takes no `"batch"` y range (`batchYLimits`
skips it: `sharedY` shares y across its tiles) and ignores `observe.perGroup`.
`Observation=` of a run draws the probe whatever is picked, as a figure of the
dataset does. The page is drawn in this MATLAB, never on the page workers.

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
| `datasets` | `"ticked"` | `"ticked"`: the run's datasets (the Data tab's ticks, or `run(Datasets=)`); `"list"`: the datasets of `datasetKeys`, ticked or not: the app's **Generate selected figure** draws across the listed ones whatever is ticked (it says so and draws nothing when none is scanned), but the Export tab's **Run** still needs at least one ticked dataset before any session figure runs |
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

`starred` is true for a match starred on **any** of its sessions (for a site,
any of the units on it in any session). With `observe.starred` the sessions
are matched on all their observations first and only then are the starred
matches kept, each drawn on every session that holds it: a unit starred on
its first day is followed to the later days without being starred there.

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
lists the series. A stacked panel ([Stacks](#stacks): a PSTH, continuous, heat
map or tuning panel) is drawn across sessions too, its series as its rows, and
the faint member lines (each in its series' row) and the line styles of
`trialGroups "combine"` apply to its stacked rows as to the overlaid ones.

Not merged, each with its reason in the panel (a skipped layer, as for one
dataset): events drawn as **marks** (*event marks are not drawn across
sessions*), the **rings** of a waveforms panel's probe layout (*the probe
layout's rings are not drawn across sessions*), a **heat map of trials** (*a
heat map of trials is not merged across sessions*), and a whole panel of a type
in `EphysAnalysisConfig.FigureSessionUnmerged` (*probe map panels are not merged
across sessions*, the type named by its label; likewise unit correlation, power
spectrum, spectrogram and coherence panels). An event-trace panel is merged:
every session's epochs, as a raster's ([Event traces](#event-traces)). A trial
panel is merged too: every session's per-trial values, each in its series, its
statistics made again over them ([Trial measures](#trial-measures)). Events drawn as spans are skipped as marks are. A merge that fails (`combineSessions:TooFew`, `:Bins`,
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
  groups by line style*) and *one figure per subject*. A figure with trial
  panels adds their statistics ([Trial measures](#trial-measures)).
- With `Export.Data.Enabled`, one `.mat` per session figure holds the merged
  and each dataset's own figures, `<Data.Folder>/<Data.FilenamePattern>.mat`
  with `{Name}` `all`, `{Plot}` the figure's id and `{Kind}` `figure`
  ([Session figure data](file-formats.md#session-figure-data-mat)); its path is
  added to the first row's `Files`, and a failure goes into its `Message`.

The standalone script carries the same calls
([Generated scripts](EphysAnalysis.md#session-figures-in-a-standalone-script)),
and the app edits the block in the Figures tab's Sessions section (shown with Pages set to Across datasets)
([Figures tab](EphysFigGenApp.md#figures-tab)).

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
  skipped);
- a trial panel grouped by `"groups"` (`categories` or `series`, at
  `<figure>.<panel>.options.<field>`) under `trialGroups "pool"`: the pooled
  groups are the sessions' series.

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
| `panels`' `rect` | stacked flush over the page, top to bottom, each as tall as its share of the plot's rows (a unit's raster and PSTH twice the aux panel's height) |

The panels, by plot kind (the second column is what the figure is drawn for,
`observe.data`'s kind; the third its panels, top to bottom, and their layers):

| Plot kind and layout | Observe | Panels and layers |
| --- | --- | --- |
| `psth`, grid | unit (`data` = the plot's `source`, the `units` filter) | a raster (when `withRaster`; its sort options; `rasterEvents` as events layers drawn as marks) over a PSTH (`histStyle`, `fill`, `fillAlpha`, `normalize`, `stack`, `stackSpacing`, `yLim`), each with a layer following the unit; equal heights (with an aux panel, the unit's panels are twice as high as it: 2 : 2 : 1) |
| `psth`, overlay | dataset | one PSTH panel with a fixed `units` layer (the filter) and `aggregate "mean"` |
| `raster` | unit | a raster panel with the marks layers |
| `evoked`, grid | channel (`data` = the plot's `source`, `channels` = the plot's) | one continuous panel following the channel |
| `evoked`, stack | dataset | a continuous panel with a fixed layer of the channels, `aggregate "each"`, `stack "items"` (`Style.StackSpacing`, an offset in the signal's units, is not carried: a stack's step is a multiple of its row height) |
| `evoked`, butterfly | dataset | as the stack, `stack "off"` |
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
  per page, places its panels by their `rect` and shows the epoch window), nor are `YLim` and
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
| `FigureSizeCm` | `[18 12]` | figure size `[width height]`: a figure's page (its panels' rects are parts of it), unless the figure has a size of its own; a probe figure's page is made taller for its rows of tiles |
| `Overwrite` | `true` | `false`: an observation (a figure's page) whose files all exist is not written again, nor drawn unless the report needs its image (HTML) or page (PDF); a session figure's data file is not replaced either (a note in the row's message) |
| `SessionsFolder` | `{OutputRoot}\analysis\sessions` | where the [session figures'](#session-figures) pages go: a [folder pattern](#file-name-tokens) whose tokens are the first session's (`{OutputFolder}` is one dataset's folder, so a warning there). Named with `FilenamePattern`, `{Name}` being the facet (`all`, or the subject) and `{Plot}` the figure's id, then `_<trial group>` for `trialGroups "each"`; a session figure adds `_<Unit>` per observation (`site_ch7`, a mapping cell, `ch7`) as a figure does |
| `Data.Enabled` | `false` | write each session figure's data as a `.mat` file in a run ([format](file-formats.md#session-figure-data-mat)); the only data export: there are no per-session data or epoch tables |
| `Data.Folder` | `{OutputRoot}\analysis\data` | a folder pattern, as `SessionsFolder` |
| `Data.FilenamePattern` | `{Name}_{Plot}` | a [file-name pattern](#file-name-tokens); `{Name}` is `all`, `{Plot}` the session figure's id (`{Kind}` is `figure`); `.mat` is added. One file per session figure holds every facet, trial group and observation |
| `Data.MatVersion` | `"-v7.3"` | `"-v7.3"` (HDF5, no 2 GB limit, readable with `h5read` and from Python) or `"-v7"` |

`exportFigure` writes PNG with `exportgraphics` at `Dpi`, PDF with
`print -dpdf -vector` on a page the figure's size (a third faster than
`exportgraphics`; `exportgraphics` when appending a page), EPS as vector
graphics (`exportgraphics`, `ContentType="vector"`) and SVG with
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
- A figure's page is `FigureSizeCm` (or the figure's own `size`), however
  many panels it holds.
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
| `Order` | `"figure"` | the order within a dataset: `"figure"`, a figure at a time with all its observations' pages together; `"unit"`, an observation at a time (a unit, a channel, or the dataset for a figure of the dataset) under a heading of its own, with its pages of every figure in the figures' order ([below](#report-order)) |
| `FiguresPerPage` | 1 | figure pages on one sheet, 1 to 16: 1 gives each page its own, at the size it was drawn; more tiles them ([below](#figures-per-page)) |
| `PageSize` | `"letter"` | the sheet the pages are tiled on when `FiguresPerPage` is above 1: `"letter"` (21.59 x 27.94 cm) or `"a4"` (21.0 x 29.7 cm) |
| `PageOrientation` | `"auto"` | `"auto"` (portrait or landscape, whichever draws a sheet's pages larger), `"portrait"` or `"landscape"` |
| `EmbedFormat` | `"png"` | HTML images: `"png"` (base64) or `"svg"` (inline) |
| `Dpi` | 110 | report PNG resolution, for a page the Export writes no PNG of: when it does (or one is kept on disk), the HTML embeds that PNG, at the Export `Dpi`, rather than write the page again |
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

When some observations are starred the count says how many
(*12 observations (sorted units: su, mua; 3 starred)*), and a figure with
`observe.starred` says *starred only*; one observation of a session figure that
is starred reads *site ch 7 (starred) across 3 sessions*.

The entry links the exported files and, with `IncludeParameters`, folds the
figure's resolved spec under it. A figure the dataset cannot draw (or that fails)
is listed with its status and message. A [session
figure](#session-figures) is an entry of the *Across sessions* section instead,
one per facet and trial group, its pages the matched observations
([what a run writes](#what-a-run-writes)).

### Report order

`Order` arranges each dataset's part of the report:

- `"figure"` (the default): the entries above, one figure after another, each
  with every observation's pages together.
- `"unit"`: one group per observation, in the order the observations first
  appear (the first figure's in probe order, then what later figures add), each
  under a heading with its label (*su12  ch 5  300 µm*, *LFP ch 5  300 µm*, or
  the dataset's name for the figures of the dataset). Under it, every figure that
  drew that observation, in the figures' order: its pages of it (every trial
  group of a `perGroup` figure) and the caption; the figure's file links and
  parameters come with its first appearance. A unit and the channel it was
  recorded on are separate groups (a unit figure and an LFP figure observe
  different things), as are a sorted unit and its detection channel. The
  HTML contents list the observations, each with its count of figures; the PDF
  has the pages in that order and its dataset summary page lists each
  observation's pages (*su12  ch 5  300 µm: pages 4-6 (rp, wf)*). Figures not
  drawn (skipped, failed) follow the groups with their reason, as do the
  session figures, which are always in figure order.

### Figures per page

`FiguresPerPage` above 1 puts up to that many figure pages on one sheet of
`PageSize`. The title and summary pages are unchanged.

- **Which pages share a sheet.** The pages fill sheets in their order (the
  order `Order` sets). A figure's pages (with `Order "unit"`, an
  observation's) stay on one sheet: when they do not fit in what is left of
  the current sheet they start the next one. A figure with more pages than
  a sheet holds starts a sheet of its own and is spread evenly over as few
  sheets as hold it: 7 pages at 4 a sheet are 4 and 3, 5 are 3 and 2.
- **How a sheet is laid out** (`reportPageLayout`). The pages go in rows,
  in reading order. Every number of pages a row is tried, on both
  orientations with `PageOrientation "auto"`, and the arrangement that
  draws the pages largest is kept. Arrangements within 2% of the largest
  count as equal; of those, portrait wins, then the fewest rows. Every page
  of a sheet is drawn at one scale, so the text keeps the same size from
  page to page, and no page is drawn larger than it was. Pages of different
  sizes share rows: a row is as tall as its tallest page, each page is
  centred in its row, and the rows are centred across and down the sheet. The margins are 1 cm, and the gap between pages
  is 0.5 cm.
- **PDF.** Each sheet is one page, with its figure pages placed whole, so
  they stay vector (PDFBox `LayerUtility`). The summary page's *Pages by
  observation* counts sheets.
- **HTML.** The HTML has no pages, so it tiles on screen what the PDF tiles
  on paper: with `Order "figure"` a figure's pages sit side by side, and
  with `Order "unit"` an observation's figures do (or a figure's pages,
  when it is the observation's only figure). The tiles come in sheets of
  up to `FiguresPerPage`, laid out by the same rule. Each tile is as wide,
  as a share of the row, as its page would be on the sheet. Printed, no
  sheet is split across two pages.

Four 18 x 12 cm pages go two by two on landscape letter, at 0.71 of their
size. Two 8 x 6 cm pages sit side by side on portrait letter, at their own
size.

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
| Figures | at least one figure or session figure enabled (`No figure is enabled.`); the figure id is not empty, file-name safe and distinct once sanitized from the other figures' (`{Plot}` fills the files' names, case-blind); the figure's alignment is valid; `observe` (`data`, channels, `maxUnits`; on a figure that observes units, an enabled `units.response` test at `<figure>.observe.units.response.<field>` and each spike layer's at `<figure>.<panel>.layers(<j>).units.response.<field>`: the test, `param` for tuning / either / both, ordered `baseline` and `window`, direction, correction, `alpha` in (0, 1], the `"auroc"` test's settings and the Statistics and Machine Learning Toolbox the tests need), `sessions` (the known values, `minSessions`; with `sessions.enabled` no probe map, unit correlation or spectral panel, no auROC baseline, a mapping file for `match "mapping"` and a unit observation for it: [rules](#validating-session-figures)), `probe` (`layout`, `overlap`, `labels` known values, `lanes` / `maxTiles` / `maxPerSite` whole >= 1, `tileWidth` / `tileHeight` in (0, 1], `tileScale` > 0, whole `shanks` and `channels`, `depthRange` `[]` or `[lo hi]`; with `probe.enabled` not a session figure too and not observing the dataset: [rules](#probe-figures)) and `layout` (`boxesMean`, `padding`) hold known values; each panel has an id of its own, a known type and a `rect` inside the page with a width and height (overlapping rects: a warning), a figure one legend panel at most, and each panel its own `ref` / `window` / `selection` only when its type is aligned; each enabled layer's source, binding, aggregate, channels, events (`eventsAs`, event reference, marker, size, a span's look; only events layers on an event-trace panel) and line style fit its panel type; a raster has rows, not marks or spans alone; each type's options; the style ([rules](#validating-figures)) | error |
| Figures | no panels; a panel's rect outside the page or without a size, a panel id used twice, more than one legend panel (errors); two panels whose rects overlap (the later is drawn on top); a panel with no enabled layer, or with several on a type that draws one; a unit or channel observation with no layer following it; a session figure's `datasets "list"` with no keys, `showMembers` with `series "session"`, `trialGroups "pool"` over grouped trials, `"combine"` over PSTH bars, a heat map of trials ([rules](#validating-session-figures)); `observe.perGroup` while the figure's selection groups by nothing (not on a session or probe figure); a probe figure's `observe.perGroup` (ignored), probe map panel or waveforms panel in the probe layout ([rules](#probe-figures)); a signal layer following another signal's channel; a waveforms panel in the probe layout whose first layer follows the observation; a fixed raster, PSTH, rate or tuning layer that may keep more than 8 units; a layer, mark, style, note or overlay color that is not a color; two overlays of a figure with one name ([rules](#validating-figures)) | warning |
| Export | formats are png / eps / svg / pdf (and at least one when enabled); `Dpi` positive; `FigureSizeCm` two positive numbers; the folder and file-name patterns use known tokens, and the file-name pattern is not empty; `SessionsFolder` and `Data.Folder` are folder patterns, `Data.FilenamePattern` a file-name pattern, and `Data.MatVersion` is `-v7.3` or `-v7` | error |
| Export | a file-name pattern without `{Plot}` while several figures are enabled (every figure's `{Kind}` is `figure`, so only `{Plot}`, the figure's id, tells their files apart); neither the folder nor the file-name pattern names the dataset (`{OutputFolder}` or `{Name}`), unless the source is a single folder: files that would overwrite each other | warning |
| Export | `{OutputFolder}` in `SessionsFolder` or `Data.Folder`: it is one dataset's folder, so the session figures' files go to the first dataset's | warning |
| Report | Format html / pdf / both, EmbedFormat png / svg, Order figure / unit, `FiguresPerPage` a whole number from 1 to 16, PageSize letter / a4, PageOrientation auto / portrait / landscape, `Dpi` positive, a plain `FileName`, the folder pattern | error |
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

`test_EphysAnalysisFigures`, in sixteen sections. Config (1 to 6): the defaults of
Figure (its `layout`), Panel (its `rect`), Layer and Observe (no options block in a figure, `panels` after `layout`;
`selection` after `window`, then `layers`, `options`, `note` and `overlays` last in a panel; `defaults("FigureCommon")` a `BadSection`;
the continuous `trials` and `maxTrials` (100), the heat map's `rows` and raster sort fields and `observe.perGroup`);
`panelTypes` (seventeen types, with the rate, tuning, spectral, event-trace, trial and legend rows' flags and the event-trace, trial and legend options), `defaults("TrialMeasure")`, the Layer's `measure` and `xMeasure`, `trialMeasureLabel`, `sourceCategories` (the trial category),
`categoryOf`, `observeKind` (of each `ObserveData` value), `followedData`, `defaultLayer` (an unknown type is a `BadValue`),
`sharedFieldsOf` (none for a waveforms panel or a spectral type); `addFigure`'s templates (the `"rate"` and `"tuning"` ones
included), ids and the data each observes (given, or its following layers'), the [automatic ids](#figure-ids)
(`Short` per type; reading order, the data after the types, inactive panels and event marks left out; following a type change and
`observe.data`; kept under `autoId` false and given back when it is true again; *(2)*, *(3)* by the next free number,
compared as `{Plot}` writes ids, and kept when an earlier figure is renamed; `duplicateFigure` of an automatic id and of one's
own; the save / load round trip) and `figureFor`'s resolution (the defaults, a panel's
own `ref` or `window`, `sharesTime`, `units.source`, the observe kind, options
completed and re-seeded by a type change, each panel's own bins, baseline,
auROC and waveform, a waveforms panel's own mode `both`, its `layout`, a panel's `"default"` selection resolved to the
figure's and its own kept, with time still shared); the JSON round trip (every panel type,
rects of their own, a layout of its own, an events layer with a sequence, fixed and following layers, the
`"default"` sentinels, no `"common"` in the file, `perGroup`, a panel's own
selection, a continuous panel's `trials` and `maxTrials` and a heat map's `rows` and sort, a cell
`Figures` from `jsondecode`, a config without `Figures`, unknown fields in
`LoadWarnings`); `adoptPanelOptions` (the shared options across types, the rest to a panel of the
same type, a baseline mode the type does not take kept, what changed, and nothing on a second
call; the axis sides to every panel, the label texts not), `adoptPanelAlignment` (a panel's own selection becomes the figure's)
and `relinkPanels` (their results and `NoPanel`); `placePanel` (the first panel, the free space,
beside an anchor in four directions, at a rect, the errors), `removePanel`; `placeBlock` (the
block mapped into the free space, beside an anchor and at a rect, ids made free, `Alignment`, a
figure without panels, `NoPanel`, `NoRoom`); `freeRect`, `rectOverlaps`, `panelOrder`, `orderPanel`,
`figureNeighbors`, `figureRectConvert` and `figureAlign` (by the boxes, the axes and the labels through a layout, to the selection, the first and the page, held panels, Space with even gaps, a Gap, columns of a grid); `DuplicateFigureId` and
`DuplicatePanelId`; every validate rule of figures (only the known layer sources and
panel types; a PSTH's baseline
mode (no `ratio`), `auroc` windows, its `stack` and a positive `stackSpacing`; a raster's `firstSpike` and a PSTH's
`latencyBox` (off by default; while on, a color, the marker, the box's height, line style and
opacity), a raster's or PSTH's `onsetLine`, and the figure's `latency` block (the method, the window and
a window past the figure's, the baseline window and rate, alpha, surprise, minSpikes, the CUSUM's settings;
a Poisson rule with no time before the event warns, the first-spike rule does not); a heat map's
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
groups `perGroup` lists agreeing with those compute reads, after the panels' baseline hull; the
first-spike latency: the figure's block, a PSTH with `latencyBox` on keeping the raster's rows, its rates
unchanged, one latency per unit for the raster and the PSTH (`R.latency`, one `F.latency` entry) equal to
`firstSpikeLatency` of the raster and to the first spike in the window taken from the unit's own train;
kept in the cache, so an edit of the method takes the latencies again and no panel, a look edit nothing
and an onset line the onset alone; the caption naming the marks, the box plot and the onset with the
block's rule and window).
Render (8):
`figureArea` (the page, the title band, the area) and `figurePlace` (a labeled side at the page's edge moved in by its
inset and the padding; two panels apart given the room their facing labels need, split by their insets; a flush pair kept
flush and edges within 2 px snapped; edges in line taking the largest move; `"outer"` boxes; overlapping rects left alone;
the 12 px floor; a note band and a phase strip under the title band; the panels' order not mattering; a legend panel never
moved), the layout drawn (a flush raster over a PSTH, a gap keeping the raster's labels clear, outer boxes, the legend
inside the first panel, floating in free space with every plot area as without it, in a legend panel vertical and
centered or horizontal at its left, its note in a preview only; the title over the panels, laid out again on a resize),
new rects and a new padding or `boxesMean` laid out in place with `Reuse` (the lines kept) and a move that breaks a stack
drawn, `Reuse` keeping panels by id when one is removed or moved up the list (the time labels, the observation's title, the
legend, the tick sizes and a heat map's color bar as a whole drawing's; `KeptOnly`; `LayoutOnly` dropping a panel), a compute and a draw function for every panel type (the legend panel's too), every type
drawn into an axes, uiaxes, figure, panel and grid layout with every component
tagged, the titles, one time axis down a stack, one legend, skipped layers' signs
(their reasons on hover in a panel), events as marks, latency lines and a rug, a stacked PSTH (a row and a
baseline per group, the legend's groups once, one group overlaid, a second
layer in the rows), an auROC PSTH (a 0-1 axis, the chance line, the modulation
window, the calls; stacked too) and heat map (the diverging colormap, 0-1),
rate panels (bars, boxes of two layers, points), tuning curves (a series, the
inset), the waveforms probe layout with the observed unit framed, the trial panels (a swarm by Depth with
brackets, an ECDF, a scatter with marginal histograms and a linear fit among the targets; `figurePlace`'s marginal
split, mirrored with the axes on top and right; the plot and its strips inside its box, flush, a share each, linked,
without tick labels, the title over the top strip, at a new size, at `Scale` 0.5 and in place with `Reuse`; as many
brackets as the significant pairs or all, none overlapping on a level, over the data; `testShow`'s corner text; a log
y axis; the five displays' roles and `TrialRows`; `TrialDataExport`'s columns, text, CSV round trip and errors; the
right-click items once; a point's and a bracket's data tips), faint and only trial traces (a
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
winning over a design's and the figure's own Box rule; the first-spike marks, one per epoch with a spike in
the window, each at its latency on a tick of its own row, by group and time and then descending with the groups
mixed, in the options' marker, size, color and fill, "First spike" in the legend, and in a raster of five blocks
on every block's own ticks; the PSTH's latency box plot, each group's box, median and whiskers `prctile`'s
quartiles and Tukey's 1.5 IQR, in a band above every trace with the y ticks under it, and stacked one box per
row above its own PSTH and under the next row up; the response onset's lines, the unit's over the
raster's rows and each group's across the PSTH at `responseOnset`'s onsets, "Response onset" in the
legend), and the
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
Probe figures (15 and 16): `defaults("FigureProbe")`, the constants, `isProbeFigure` / `probeFigureIds`, every validate rule at `<figure>.probe.<field>` (and a session figure or a dataset observation too, the `perGroup` and probe-panel warnings), a JSON round trip; on the fixture `figureProbeTiles` (the positions, the counts, `channels`, `maxPerSite`, `maxTiles`, `depthRange`, `shanks`, a channel figure), `figureProbeCompute` (each tile `figureCompute`'s result, the shared steps once, Reuse, a look or layout edit computing nothing), `computeProbeFigure` (the cache, `ProgressFcn`, cancel), `figureSkipReason`, `figureOutputName`, `figureCaption`, `figureExportSize`, `runDataset` writing one page, `plan` and the scripts; `probeTileLayout` on synthetic probes (a 4 x 8 probe's columns and rows, a staggered shank, two units on a site, physical `allow`, `nudge`, `lanes` and `shrink`, no tile, one tile) and `renderProbeFigure` on the fixture (the tiles' axes inside the canvas and apart, the probe axes, one legend and title, the scale tile, `sharedY`, the labels, a skipped tile, `renderFigure`'s dispatch, a resize, every role known, a panel and a grid layout, Scale 0.5).

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
`alignment`, `arrangement`, `panel`, `style`, `looks` and `sessions`, each with its
label and description), `figureSettingItems` (a raster + PSTH figure's settings, each
with its part, groups, paths, value, generic key and whether a design holds it; the
Style fields a figure does not use left out), `copyFigureSettings` (one setting with
the rest of its part kept; a part; a panel's options to the panel of its type only, a
continuous panel not taking a PSTH's fixed y limits; one figure onto two; the layout;
remembered looks one by one; panels matched by id, then type; a copy that changes
nothing; every setting by default with the id, title and `enabled` kept, and it
validates; `BadSetting`, `BadFigure`; the time of every setting onto ten figures) and
`figureLookToDesign` (a colormap's name, the heat colors and the looks into a design;
one color; what a design does not hold left out; `BadSetting`).

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

- [Analysis app](EphysFigGenApp.md): the GUI that edits a config
- [Analysis scripting](EphysAnalysis.md): running configs from scripts, generated scripts, the functions
- [Pipeline configs](Pipeline-Configs): the pipeline config, whose project settings `Source` mirrors
- API: [EphysAnalysisConfig](API-EphysAnalysisConfig), [EphysAnalysisRunner](API-EphysAnalysisRunner), [Analysis functions](API-Analysis-Functions)
-->
