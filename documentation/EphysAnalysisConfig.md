# EphysAnalysisConfig

`EphysAnalysisConfig` ([source](../analysis/@EphysAnalysisConfig/EphysAnalysisConfig.m))
is a value class that describes a set of quick-look figures: which datasets
to read, how to align them, which plots to draw, and how to export and
report them. `EphysAnalysisApp` edits one, `EphysAnalysisRunner` runs one and
`EphysAnalysisScript` writes scripts from one ([Analysis](EphysAnalysis.md)).
It is saved as JSON (schema `ephys-analysis-config`, version 1) and
round-trips exactly, `Inf`, `NaN` and empty values included.

```matlab
cfg = EphysAnalysisConfig();
cfg.Name = "AM quick look";
cfg.Source.Root = "D:\EPHYS";
cfg.Defaults.EventRef.line = "Stim";
cfg.Defaults.Selection.groupBy = "Depth";
cfg = cfg.addPlot("psth");                                  % id "psth_1"
cfg = cfg.addPlot(struct('kind', "evoked", 'source', "LFP"), Id="lfp_stim");
issues = cfg.validate();
cfg = cfg.save("D:\EPHYS\am_quicklook.json");
cfg = EphysAnalysisConfig.load("D:\EPHYS\am_quicklook.json");
R = EphysAnalysisRunner(cfg).run();
```

> Written 2026-09-18 from the source. When the code and this page disagree,
> the code is authoritative.

## Class

| Member | Meaning |
| --- | --- |
| `Name`, `Description` | text |
| `Source`, `Defaults`, `Export`, `Report` | sections (structs), coerced on assignment |
| `Plots` | struct array, one entry per plot; a cell array (what `jsondecode` gives for plots whose fields differ) is accepted too |
| `File`, `LoadWarnings` | transient: where it was loaded from / saved to; the unknown fields `load` dropped |
| `Schema`, `Version`, `Sections`, `Kinds`, `SpikeSources`, `SignalSources`, `ListFields` | constants |
| `toStruct()`, `toJson()`, `save(file)` | plain struct; the JSON `save` writes (`Inf` / `NaN` as `"Inf"` / `"NaN"`) |
| `EphysAnalysisConfig.load(file)`, `fromStruct(s)` | errors `EphysAnalysisConfig:BadSchema` on another schema or version |
| `validate(CheckPaths=true)` | issues table `Section, Field, Severity, Message` ([rules](#validation)) |
| `addPlot(kindOrStruct, Id=)`, `removePlot(id)`, `plotIndex(id)`, `plotIds()`, `enabledPlots()` | the plot list |
| `plotFor(id)` | a plot with every `"default"` resolved from `Defaults`, `units.source` set and an empty layout replaced by the kind's default: what the runner draws |
| `isequalConfig(other)` | same values (NaN equal) |
| `defaults(section)`, `normalizeSection(section, s)`, `normalizePlot(p)`, `plotKinds()` | static: the single source of truth for fields, types and shapes |

Values are coerced to the class and shape of their default on every
assignment: a one-element list read back from JSON is a list again, `"Inf"`
is `Inf`, `[]` is an empty list or number. String fields named in
`ListFields` (`response`, `pairingFlags`, `groupBy`, `classes`, `groups`,
`Formats`, `Datasets`, `Folders`) stay lists even with one element. Unknown
fields are dropped (listed in `LoadWarnings` after `load`). Text where a
number belongs is `EphysAnalysisConfig:BadValue`.

Plot ids must be unique (`EphysAnalysisConfig:DuplicatePlotId`); a plot
without one gets `"<kind>_<n>"`.

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
      "units": { "classes": ["su", "mua"], "groups": [], "ids": [], "channels": [], "shanks": [], "maxUnits": "Inf" },
      "channels": [], "ref": "default", "window": "default", "selection": "default",
      "bins": { "BinSec": 0.01, "SmoothSec": 0.02 }, "baseline": { "Mode": "none", "Window": [-0.2, 0] },
      "layout": "grid", "withRaster": true, "histStyle": "bar", "maskAfterStop": false, "param": "", "seriesParam": "",
      "value": "rate", "order": "depth", "metric": "mean", "correlation": "pearson", "style": { "MaxTiles": 16, "...": "..." } },
    { "id": "rate_platform", "kind": "rate", "source": "units",
      "ref": { "line": "Platform", "edge": "onset", "which": "first", "scope": "trial", "...": "..." },
      "window": { "mode": "between", "pre": 0, "post": 0,
                  "stop": { "line": "Platform", "edge": "offset", "which": "first", "scope": "trial", "...": "..." } },
      "selection": { "filter": "Hit | Miss", "groupBy": "Depth", "...": "..." },
      "baseline": { "Mode": "subtract", "Window": [-0.5, 0] }, "...": "..." } ],
  "Export": { "Enabled": true, "Formats": ["png", "svg"], "Folder": "{OutputFolder}\\analysis",
              "FilenamePattern": "{Name}_{Plot}", "Dpi": 150, "FigureSizeCm": [18, 12], "Overwrite": true },
  "Report": { "Enabled": true, "Format": "html", "Title": "{Name} quick look",
              "Folder": "{OutputRoot}\\analysis", "FileName": "analysis_report", "PerDataset": false,
              "EmbedFormat": "png", "Dpi": 110, "IncludeSummary": true, "IncludeParameters": true,
              "IncludeConfig": true }
}
```

`save` writes every field of every section and plot (the `"..."` above
stand for the rest); a file written by hand may leave fields out.

## Source

| Field | Default | Meaning |
| --- | --- | --- |
| `Mode` | `"project"` | `"project"`: a pipeline project; `"folders"`: the listed output folders |
| `Root` | `""` | project root (the folder the preprocessing app scans) |
| `OutputRoot` | `""` | the project's output root; `""` = outputs next to each recording |
| `NamePattern` | `EphysDataset.DefaultNamePattern` | dataset-name tokens, as in the pipeline config |
| `Recordings` | `"concatenate"` | what an Open Ephys session with several recordings is (`"concatenate"`, `"separate"`, `"single"`), as in the pipeline config's `Acquisition.OpenEphys.Recordings`: with `"separate"` the datasets are the part folders |
| `Selection` | `"all"` | `"all"` or `"list"` |
| `Datasets` | none | root-relative dataset keys for `"list"` |
| `Folders` | none | dataset output folders (`"folders"` mode) |

Project mode only lists the recording folders (`EphysProject`, no header
read, nothing written); each dataset's files are found under its output
folder and recording folder. Folders mode suits a machine that holds only
processed files.

## Defaults

`Defaults.EventRef`, `Defaults.Window` and `Defaults.Selection` are used by
every plot whose `ref`, `window` or `selection` is the string `"default"`.

## Building blocks

`EphysAnalysisConfig.defaults("EventRef" | "EpochWindow" | "TrialSelection" |
"UnitSelection" | "Style")`. The first three are described with their
constructors on the [Analysis page](EphysAnalysis.md#event-reference-window-selection).

### UnitSelection

A plot's `units` (its `source` is the plot's `source`):

| Field | Default | Meaning |
| --- | --- | --- |
| `classes` | `["su" "mua"]` | sorted-unit classes kept (`[]` = all) |
| `groups` | none | phy groups kept |
| `ids` | `[]` | unit ids (sorted) or channels (detected) |
| `channels` | `[]` | 1-based recording channels |
| `shanks` | `[]` | shanks |
| `maxUnits` | `Inf` | at most this many, in order |

### Style

| Field | Default | Meaning |
| --- | --- | --- |
| `LineWidth` | 1.2 | traces |
| `ShowSEM` | `true` | SEM bands / error bars |
| `ShowStop` | `true` | stop-event marks (mean per group; a dot per raster row) |
| `ShowZeroLine` | `true` | a dotted line at the event |
| `Colormap` | `"lines"` | group colours: `"lines"` keeps selectTrials' colours; any colormap name resamples them |
| `HeatColormap` | `""` | heatmaps, probe maps and unit correlations; `""` = parula, or `blueWhiteRed` for corrmap |
| `FontSize` | 9 | |
| `YLim`, `XLim`, `CLim` | `[]` | fixed limits (`[]` = automatic) |
| `Grid`, `Legend` | `true` | |
| `MaxTiles` | 16 | tiles per page in grid layouts |
| `StackSpacing` | `NaN` | evoked `"stack"` offset (NaN = 1.2 x the 90th percentile of the channels' ranges) |

## Plots

| Field | Default | Meaning |
| --- | --- | --- |
| `id` | auto | unique; names exported files (`{Plot}`) |
| `kind` | `"psth"` | one of the kinds below |
| `enabled` | `true` | |
| `title` | `""` | `""` = automatic |
| `source` | `"units"` | `"units"`, `"detected"` (spike kinds) or `"LFP"`, `"MUA"`, `"SPIKE"`, `"AUX"` (signal kinds) |
| `units` | UnitSelection | spike sources |
| `channels` | `[]` | signal columns drawn |
| `ref`, `window`, `selection` | `"default"` | or the plot's own EventRef / EpochWindow / TrialSelection |
| `bins` | `BinSec` 0.01, `SmoothSec` 0.01 | PSTH bins and Gaussian SD, s (0 = no smoothing); also a corrmap's `"peak"` rate |
| `baseline` | `Mode "none"`, `Window [-0.2 0]` | see the kinds |
| `layout` | `""` | `""` = the kind's default |
| `withRaster` | `true` | psth: a raster above each unit |
| `histStyle` | `"bar"` | psth: `"bar"` (one bar per bin; half-transparent when groups overlap) or `"line"` |
| `maskAfterStop` | `false` | psth: drop bins after each epoch's stop event |
| `param`, `seriesParam` | `""` | tuning: x axis parameter; one curve per value of the series parameter |
| `value` | `"rate"` | probemap: `"rate"`, `"nSpikes"`, `"nUnits"` |
| `order` | `"depth"` | heatmap rows: `"depth"`, `"channel"`, `"peak"`; corrmap rows and columns: `"depth"`, `"channel"` |
| `metric` | `"mean"` | corrmap: each epoch's `"mean"` rate over its window, or its `"peak"` binned rate (`bins`) |
| `correlation` | `"pearson"` | corrmap: `"pearson"` or `"spearman"` |
| `style` | Style | |

| Kind | Sources | Layouts (first = default) | Windows | Baseline modes |
| --- | --- | --- | --- | --- |
| `psth` | units, detected | grid, overlay | fixed | none, subtract, zscore, percent |
| `raster` | units, detected | grid | fixed | none |
| `evoked` | LFP, MUA, SPIKE, AUX | stack, butterfly, grid | fixed | none, subtract |
| `rate` | units, detected | bar, box, points | fixed, between | none, subtract, ratio, zscore |
| `tuning` | units, detected | grid, overlay | fixed, between | none, subtract, ratio, zscore |
| `heatmap` | all six | groups | fixed | spikes: as psth; signals: none, subtract |
| `probemap` | units, detected | shanks | (no alignment) | none |
| `corrmap` | units, detected | groups | fixed, between | none, subtract |

## Export

| Field | Default | Meaning |
| --- | --- | --- |
| `Enabled` | `true` | write figure files |
| `Formats` | `["png" "svg"]` | any of `png`, `eps`, `svg`, `pdf` |
| `Folder` | `{OutputFolder}\analysis` | folder tokens (below) |
| `FilenamePattern` | `{Name}_{Plot}` | `{Name}` (dataset) `{Plot}` `{Kind}` `{Group}` `{Unit}` `{Index}` `{Date}`; a paged plot adds `_p<page>` unless `{Index}` or `{Unit}` is used |
| `Dpi` | 150 | PNG resolution |
| `FigureSizeCm` | `[18 12]` | figure size |
| `Overwrite` | `true` | `false`: pages whose files all exist are not written again |

## Report

| Field | Default | Meaning |
| --- | --- | --- |
| `Enabled` | `true` | |
| `Format` | `"html"` | `"html"`, `"pdf"` or `"both"` |
| `Title` | `"{Name} quick look"` | `{Name}` = the config's name, `{Date}` = today |
| `Folder` | `{OutputRoot}\analysis` | folder tokens |
| `FileName` | `"analysis_report"` | `.html` / `.pdf` added |
| `PerDataset` | `false` | one report per dataset, named `<FileName>_<dataset>` |
| `EmbedFormat` | `"png"` | HTML images: `"png"` (base64) or `"svg"` (inline) |
| `Dpi` | 110 | report PNG resolution |
| `IncludeSummary`, `IncludeParameters`, `IncludeConfig` | `true` | summary tables per dataset, each plot's parameters, the config JSON |

### Folder tokens

`{OutputFolder}` (the dataset's output folder), `{OutputRoot}`
(`Source.OutputRoot`, else `Source.Root`, else the folder above the first
dataset's output folder), `{Root}`, `{Name}` (the dataset), `{Date}`
(yyyyMMdd). Unknown tokens are `figureFileName:UnknownToken`.

## Validation

`validate` reports:

| Section | Rule | Severity |
| --- | --- | --- |
| Source | Mode is project / folders; Root set and existing (CheckPaths); every folder exists; NamePattern parses; Recordings is one of the three modes | error |
| Source | a "list" selection with no datasets; an OutputRoot that does not exist | warning |
| Defaults, Plots | the event reference, window and selection are valid (`pre <= post`, a `"between"` window has a stop, `groupBy` has at most 2 parameters, ...) | error |
| Defaults, Plots | a filter that does not parse | warning (it is checked against each dataset's trials when it runs) |
| Plots | at least one enabled; the kind exists; the source, layout, window mode and baseline mode fit the kind; tuning names its parameter; `BinSec > 0`, `SmoothSec >= 0`; a baseline window `[b0 b1]` with `b0 < b1`; probemap value, psth `histStyle` bar / line; heatmap order; corrmap order, metric and correlation; `maxUnits >= 1`; `MaxTiles`, `FontSize`, `LineWidth` positive | error |
| Plots | a colormap that is not a function | warning |
| Export | formats are png / eps / svg / pdf (and at least one when enabled); `Dpi`, `FigureSizeCm`; the folder and file-name patterns use known tokens | error |
| Report | Format, EmbedFormat, `Dpi`, a plain `FileName`, the folder pattern | error |
| Report | `{OutputFolder}` in a report over every dataset | warning |

## Tests

`test_EphysAnalysisConfig`: defaults, save / load round trips (Inf, NaN,
one- and two-item lists, `"default"` sentinels, stop events), `plotFor`,
auto and duplicate ids, a cell of partial plots, every validate rule,
`LoadWarnings`, `BadSchema`, `BadValue` and `figureFileName`.
