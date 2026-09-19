# EphysAnalysisApp

`EphysAnalysisApp` ([source](../analysis/@EphysAnalysisApp/EphysAnalysisApp.m))
is the GUI for quick-look figures of processed datasets. It edits one
[`EphysAnalysisConfig`](EphysAnalysisConfig.md) and draws it with an
`EphysAnalysisRunner` ([Analysis](EphysAnalysis.md#runner)). It computes
nothing itself: its previews, plans and runs are the runner's
`computePlot`, `renderPlotFigures`, `plan` and `run`, so a preview is what a
run or a generated script draws.

> Written 2026-09-18 from the source. When the code and this page disagree,
> the code is authoritative.

## Quick start

```matlab
addpath_nogit('C:\src\ephys_analysis')     % pipeline + analysis (see INSTALL.md)
EphysAnalysisApp("D:\EPHYS_synthetic")     % a project processed by the pipeline
```

1. **Data**: the project is scanned; click a dataset to make it active.
2. **Alignment**: align to `Stim` onset, group by `Depth`; the count shows
   the epochs per group.
3. **Plots**: *Add* a PSTH, an evoked potential (source LFP), a rate plot
   (e.g. `Platform` onset → offset: untick *Default event* / *Default
   window*), a tuning curve (parameter `Depth`), a heatmap, a probe map and
   a unit correlation;
   each previews on the active dataset.
4. **Export**: tick png / svg / pdf, *Run*; *Open report*.
5. **File → Generate script → Standalone** to get the same figures from a
   script.

The preprocessing app opens it with **File → Open analysis app...** on its
project root and output root.

## Launching

| Call | Opens |
| --- | --- |
| `EphysAnalysisApp` | the last config (preference `LastConfigFile`), else the defaults |
| `EphysAnalysisApp("D:\EPHYS")` | a new config in project mode on that root, scanned |
| `EphysAnalysisApp("D:\EPHYS", OutputRoot="E:\out")` | the same with the project's output root |
| `EphysAnalysisApp("D:\out\subj1_day1")` | a folder holding `<Name>_manifest.json` or `<Name>_extract*.mat`: a new config in folders mode with that folder |
| `EphysAnalysisApp("am.json")` | that analysis config (its source scanned when it exists) |
| `app = EphysAnalysisApp(...)` | the same, keeping a handle |

The detection is in `openSource`.

## Tabs

### Data tab

- Config name and description.
- **Datasets from**: a pipeline project (Root, Output root, Name pattern, and
  the Open Ephys recording mode, as in the pipeline config) or
  output folders (one per line, *Add...*). **Scan** builds the runner, which
  finds the datasets (and owns the loaded data).
- The datasets table: **Run** (tick the datasets a run uses; in project mode
  the ticks are the config's selection), Name, Key, which of LFP / MUA /
  SPIKE / AUX, Units, Detected and Behavior exist, and, once the dataset has
  been loaded, Trials, Pairing status and Duration. Click a row to make it
  the **active dataset**.
- Active dataset: the size of each signal extract (one above
  `PreviewMaxMB` is previewed only with the Preview button), its files
  (`DatasetOutputs.inventory`), digital lines (count, mean length, first,
  last, inverted), behavior (subject, trials, pairing flags, responses), the
  Epsych2 parameters with their values, and sorted units by class and shank.

### Alignment tab

Edits the config's **Defaults**, used by every plot that does not set its
own:

- *Event reference*: line (the active dataset's lines plus `Trial`), edge,
  which (first / last / all / nth, n), scope (auto / trial / recording),
  offset, interval length and time range.
- *Epoch window*: fixed `[t0+pre, t0+post]` or between `[t0+pre,
  stop+post]`, with the stop event (line, edge, which, scope).
- *Trial selection*: filter (**?** lists the trial columns, the response
  words and the functions a filter may use), response words, pairing flags,
  up to two group-by parameters, order, max groups.

On the right, for the active dataset: *"N epochs from M of T trials (scope);
groups ..."* (or why there are none), a bar of epochs per group in the group
colours, and the kept trials with their group and number of epochs.

### Plots tab

- The plot list (`<id> (<kind>)`, disabled ones marked *(off)*): **Add** a
  kind, **Remove**, **Duplicate**, **Up / Down** (the run and report order).
- The editor. Its rows follow the kind and source (`syncPlotEditorEnable`):
  enabled, id, title, source, layout; unit classes, ids, max units, channels,
  shanks; bin and smoothing (ms); baseline mode and window; raster, bar or
  line PSTH, mask after the stop event; the tuning parameter and series; the probe-map value;
  the heatmap and unit-correlation row order; the unit correlation's epoch
  rate (mean or peak; bins apply to peak) and correlation (Pearson or
  Spearman); tiles per page, font size, SEM, stop marks, legend,
  grid, y limits, heat colours (*auto*: parula, or blueWhiteRed for unit
  correlations). **Default event / window / selection**:
  untick one to give the plot its own, in the panels below (the same
  controls as the Alignment tab).
- The preview: on the active dataset, through the runner. **Preview** always
  computes (also for large signals); with **Auto** on, every edit redraws it
  while a preview takes under 2 s. Paged grids have `<` / `>`. A plot the
  dataset cannot draw says why (the runner's skip reasons).

### Export tab

- *Figure files* (config `Export`): write figure files, formats (png, eps,
  svg, pdf), folder and file-name pattern with their tokens, dpi, overwrite,
  size in cm.
- *Report* (config `Report`): write a report, format (HTML, PDF, both),
  title, folder, file name, one per dataset, HTML image format, dpi, and
  whether to include the summary tables, the plot parameters and the config.
- **Validate** (the config's issues), **Plan** (which plot runs on which
  ticked dataset, and why one is skipped), **Run** (every enabled plot on
  every ticked dataset, with a cancelable progress dialog; the config is
  validated first), **Cancel**, the results table, **Open report**, **Open
  figure folder**.

### Log tab

What the scans and runs reported, time-stamped (the last 2000 lines).

## Menus

| Menu | Items |
| --- | --- |
| File | New config, Open config..., Open recent, Save config, Save config as..., Generate script ▸ Compact (loads the saved config) / Standalone (every setting written out), Open preprocessing app, Close |
| Help | Help for this tab, Documentation home, Analysis quick start, Analysis configs (wiki pages `Analysis-App`, `Analysis-Configs`) |

The title shows `*` while the config has unsaved changes; closing, opening
or starting a new config asks to save them.

## Preferences

Group `EphysAnalysisApp` (`getpref`); everything else is in the config.

| Preference | Meaning |
| --- | --- |
| `FigurePosition` | window position and size |
| `LastConfigFile` | reopened at launch |
| `RecentConfigs` | File → Open recent (8) |
| `ScriptFolder` | where Generate script offers to save |
| `AutoPreview` | the Plots tab's Auto box |
| `PreviewMaxMB` | signal extracts larger than this (default 500 MB) are previewed only with the Preview button |

## Why is my plot skipped?

The runner's `plotSkipReason`, shown by the preview, Plan and the results:

| Reason | Cause | Fix |
| --- | --- | --- |
| no sorted units | no spikes file with units and no sorting folder | run the Spikes step with sorted units, or sort |
| no detected spikes | the spikes file has no threshold detections | run the Spikes step with detection |
| no LFP extract (MUA, SPIKE, AUX) | the Signals step did not write that signal | enable it in the pipeline's Signals step |
| no paired trials | trial scope, the `Trial` line, a filter / response / group-by or a tuning plot on a dataset without paired trials | approve the pairing on the preprocessing app's Trials tab and write the behavior file; or align in recording scope without a selection |
| no line X | the event or stop line is not among the dataset's lines | check the line names on the Data tab |
| no trial parameter X | a group-by or tuning parameter the trials lack | pick one from the dataset's parameters |
| no probe map | the manifest names no probe file (probemap plots) | assign a probe in the preprocessing app |

A plot that is not skipped can still fail when it runs, e.g. *no Stim onset
event is left after the selection* or *none of the N events makes a usable
epoch (M with a window outside the recording)*: the message is in the
results and the report.

## Where the code is

| Part | Files |
| --- | --- |
| building | `buildUI`, `buildMenus`, `buildDataTab`, `buildAlignTab`, `buildPlotsTab`, `buildExportTab`, `buildLogTab`, `buildAlignControls` |
| config model | `gatherConfig` / `applyConfig`, `gather*` / `apply*Section`, `gatherAlignControls` / `applyAlignControls`, `gatherPlotEditor` / `applyPlotEditor`, `onConfigChanged`, `updateTitle`, `confirmDiscard` |
| data | `openSource`, `onScan`, `refreshDatasetsTable`, `selectDataset`, `refreshDatasetInfo` |
| previews | `refreshAlignPreview`, `refreshPreview`, `autoPreview`, `onPreviewPage` |
| running | `onValidate`, `onPlan`, `onRunExport`, `onCancelRun` |
| files | `onNewConfig`, `onOpenConfig`, `openConfigFile`, `onSaveConfig`, `onSaveConfigAs`, `onGenerateScript`, `loadPreferences`, `savePreferences` |

## Tests

`test_EphysAnalysisApp` builds the app headlessly on the analysis fixture
(a small synthetic project run through the pipeline) and drives it through
its methods: the five tabs; the scan; the active dataset's lines and
parameters; grouping by Depth from the Alignment controls; adding a PSTH and
an LFP evoked potential and previewing both; editing the bins and the
plot's own event; the gather / apply round trip; Save As, New, reopen;
generating scripts; Validate, Plan and a run of one plot writing figures
and the report; closing. The user's `EphysAnalysisApp` preferences are
restored afterwards.
