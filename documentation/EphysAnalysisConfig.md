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
| `addPlot(kindOrStruct, Id=)`, `removePlot(id)`, `plotIndex(id)`, `plotIds()`, `enabledPlots()` | the plot list. `[cfg, id] = cfg.addPlot(...)` also returns the plot's id; `removePlot` of an unknown id is `EphysAnalysisConfig:NoPlot`; `plotIndex` is 0 for one |
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
                   "minDurationSec": 0, "maxDurationSec": "Inf", "timeRange": ["-Inf", "Inf"], "offsetSec": 0 },
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
      "layout": "grid", "withRaster": true, "rasterSort": "", "histStyle": "bar", "fill": true, "fillAlpha": "NaN", "normalize": "none",
      "stack": false, "stackSpacing": 1.1, "maskAfterStop": false, "param": "", "seriesParam": "",
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
`scope` (trial, recording or auto), a duration range, a time range and
`offsetSec` (fields and rules: [`eventRef`](EphysAnalysis.md#eventref-what-each-epoch-is-aligned-to)).
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

A line whose intervals lie between trials (`Platform` in the synthetic
project) has no event in trial scope: use recording scope for it.

### EpochWindow

The span of each epoch: `"fixed"`, `[t0 + pre, t0 + post]`, or
`"between"`, `[t0 + pre, t1 + post]` where `t1` is the `stop` event, for a
variable-length period such as `RespWindow` onset to `RespWindow` offset
(the second plot of the [JSON example](#json-example)); fields and rules:
[`epochWindow`](EphysAnalysis.md#epochwindow-the-span-of-each-epoch). A
`stop` in a fixed window still sets `t1`, so PSTHs and rasters mark it and
`maskAfterStop` can drop what follows it. Only rate, tuning and corrmap
plots take a `"between"` window ([kinds](#plots)).

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
| `MaxTiles` | 16 | tiles per page in grid layouts (psth and tuning grids, rasters, evoked grids): a plot with more units or channels has several pages |
| `TileSpacing` | `"compact"` | space between the tiles of a grid, and round it: `"loose"`, `"compact"`, `"tight"`, `"none"` |
| `CornerLabelsOnly` | `false` | grids: axis labels on the bottom-left tile only (titles, ticks and colour bars stay) |
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
| `source` | `"units"` | spike kinds: `"units"` (sorted units) or `"detected"` (threshold detections); signal kinds: `"LFP"`, `"MUA"`, `"SPIKE"`, `"AUX"` |
| `units` | [UnitSelection](#unitselection) | spike sources: which units |
| `channels` | `[]` | signal sources: the extract's columns drawn (`[]` = all) |
| `ref`, `window`, `selection` | `"default"` | or the plot's own [EventRef](#eventref) / [EpochWindow](#epochwindow) / [TrialSelection](#trialselection). A probe map, which is not aligned, uses them only for a `units.response` test |
| `bins` | `BinSec` 0.01, `SmoothSec` 0.01 | psth, raster, heatmap of spikes and a corrmap's `"peak"` rate: the bin width (bins are whole multiples of `BinSec` from the event) and the Gaussian SD applied to each epoch before averaging, s (0 = no smoothing) |
| `measure` | `"rate"` | psth, heatmap of spikes, rate, tuning: `"rate"` (spikes/s), `"count"` (spikes per bin, or per epoch window) or `"probability"` (the share of epochs with a spike in the bin, or window). The baseline is measured the same way |
| `baseline` | `Mode "none"`, `Window [-0.2 0]` | see the kinds. `Mode "auroc"` (psth, heatmap of spikes): each window's auROC against the baseline window, 0 to 1, with `auroc`'s settings ([auROC](#auroc)) |
| `auroc` | [Auroc](#auroc) | psth, heatmap of spikes with `baseline.Mode "auroc"`: how the auROC is made and units are called |
| `layout` | `""` | `""` = the kind's default |
| `withRaster` | `true` | psth: a raster above each unit |
| `rasterSort` | `""` | psth, raster: the order of each group's epochs in the raster. `""` = trial (time) order; `"stop"` = by the stop event's latency; else a trial parameter, which the compute copies onto the epochs (`epochTable(..., Columns=)`). Groups stay in their own bands; missing values sort last and ties keep the trial order |
| `histStyle` | `"bar"` | psth: `"bar"` (one bar per bin) or `"line"` (a trace through the bin centres) |
| `fill` | `true` | psth: fill the bars, or the area under the line; `false` = the bars' outline, or the line alone |
| `fillAlpha` | `NaN` | psth: fill opacity 0-1; `NaN` = 0.5 where groups are overlaid, else 1 |
| `normalize` | `"none"` | psth: `"unitPeak"` divides each unit's PSTHs by their largest absolute value over every group (the groups keep their sizes); `"groupPeak"` divides each PSTH by its own. The overlay layout normalizes each unit before the mean |
| `stack` | `false` | psth: one row per group instead of overlaid (see [Stacked PSTHs](#stacked-psths)) |
| `stackSpacing` | 1.1 | psth stack: the row step, times the panel's tallest PSTH (1 = it just reaches the next row; below 1 the rows overlap) |
| `maskAfterStop` | `false` | psth, raster, heatmap of spikes: drop each epoch's bins, and its raster ticks, from its stop event on (the mean then covers the epochs still going) |
| `param`, `seriesParam` | `""` | tuning: the trial parameter on the x axis (required); one curve per value of the series parameter (`""` = one curve) |
| `value` | `"rate"` | probemap, per site, over the whole recording: `"rate"` (the units' summed rate, Hz), `"nSpikes"` (their summed spike count) or `"nUnits"` |
| `order` | `"probe"` | heatmap rows: `"probe"` (the style's `SortDepth` / `SortShank`), `"peak"` (by the time of each row's maximum) or, with the auROC baseline, `"modulation"` (by the first group's mean auROC in the call window, highest first; the other tiles keep that order, as the paper's Fig 3A). A corrmap follows the style's sort options |
| `metric` | `"mean"` | corrmap: each epoch's `"mean"` rate over its window, or its `"peak"` binned rate (`bins`) |
| `correlation` | `"pearson"` | corrmap: `"pearson"` or `"spearman"` |
| `waveform` | [Waveform](#unit-waveforms), `mode "off"` | raster, psth and tuning grids of spikes: each unit's waveform in its tile |
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
| Defaults, Plots | the event reference, window and selection are valid: known values, `n` a whole number >= 1, `0 <= minDurationSec <= maxDurationSec`, `timeRange` ordered, a finite `offsetSec`, finite `pre` and `post`, `pre <= post` in a fixed window, a stop event in a `"between"` window, known response words and pairing flags, at most 2 distinct `groupBy` parameters, `maxGroups` and `trials` whole numbers >= 1 | error |
| Defaults, Plots | a filter that does not parse | warning (it is checked against each dataset's trials when it runs) |
| Plots | at least one enabled; ids that stay distinct once `{Plot}` has sanitized them (case-blind); the kind exists; the source, layout, window mode and baseline mode fit the kind; `measure` rate / count / probability; tuning names its parameter; `BinSec > 0`, `SmoothSec >= 0` where bins are used; a baseline window `[b0 b1]` with `b0 < b1`; probemap value, psth `histStyle` bar / line, `normalize` none / unitPeak / groupPeak, `fillAlpha` 0-1 or NaN, `stackSpacing > 0`; heatmap order (`"modulation"` only with the auROC baseline); the auROC settings (method, windows, whole-bin window and step, call window, cutoff, threshold, test, `nResamples`, correction, alpha, `modulatedOnly` with a cutoff) and the toolbox they need; corrmap metric and correlation; `maxUnits >= 1`; an enabled response test of spikes: its test, `param` for tuning / either / both, `baseline` and `window` ordered, direction, correction, alpha in (0, 1], the auROC settings of a test `"auroc"` (with a cutoff) and the Statistics and Machine Learning Toolbox; a `waveform` mode off / mean / subsample / both and, when not off, its location, `scale` in (0, 3] and a whole `maxSpikes >= 1`; `MaxTiles >= 1`, `TileSpacing` loose / compact / tight / none, `FontSize`, `LineWidth`, `SiteSize` positive | error |
| Plots | a `HeatColormap` that is not a colormap function; a `Colormap` that is neither a colormap function nor a colour (the default is used); a `waveform` mode on a plot that draws no unit tiles (an overlay, a plot of signals, a kind other than raster / psth / tuning) | warning |
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
and unit-waveform settings), `plotFor`, `removePlot`, `enabledPlots`, auto
and duplicate ids, a cell of partial plots, every validate rule (ids and
patterns whose files would collide, the auROC baseline and response test
included), `LoadWarnings`, `BadSchema`, `BadValue`, `figureFileName` and
`plotFileName`'s page suffix.

<!-- wiki
## Related

- [Analysis app](EphysAnalysisApp.md): the GUI that edits a config
- [Analysis scripting](EphysAnalysis.md): running configs from scripts, generated scripts, the functions
- [Pipeline configs](Pipeline-Configs): the pipeline config, whose project settings `Source` mirrors
- API: [EphysAnalysisConfig](API-EphysAnalysisConfig), [EphysAnalysisRunner](API-EphysAnalysisRunner), [Analysis functions](API-Analysis-Functions)
-->
