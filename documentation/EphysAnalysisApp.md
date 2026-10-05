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
3. **Plots**: *Add* a PSTH, an evoked potential (it reads LFP), a rate plot
   (e.g. `RespWindow` onset → offset: set the line in its *Event reference*
   section and the stop event in its *Epoch window* section, which gives the
   plot its own), a tuning curve (parameter `Depth`), a heatmap, a probe map
   and a unit correlation;
   each previews on the active dataset.
4. **Export**: tick png / svg / pdf, *Run*; *Open report*.
5. **File → Generate script → Standalone** to get the same figures from a
   script.

The pipeline app opens it with **File → Open analysis app...** on its
project root and output root.

## Launching

| Call | Opens |
| --- | --- |
| `EphysAnalysisApp` | the last config (preference `LastConfigFile`), else the defaults |
| `EphysAnalysisApp("D:\EPHYS")` | a new config in project mode on that root, scanned |
| `EphysAnalysisApp("D:\EPHYS", OutputRoot="E:\out")` | the same with the project's output root |
| `EphysAnalysisApp("D:\EPHYS", Datasets=["subj1/day1" "subj1/day2"])` | the same with only those datasets selected (root-relative keys; `Source.Selection = "list"`): every dataset is listed, but only these are ticked to run, and the first of them is active; one dataset names the config. The pipeline app's Tools panel opens it this way |
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
  stop+post]`, with the stop event (line, edge, which with its *n* for
  `"nth"`, scope).
- *Trial selection*: filter (**?** lists the trial columns, the response
  words and the functions a filter may use), response words, pairing flags,
  up to two group-by parameters, order, max groups.

The stop event's offset, interval length and time range, and the selection's
explicit trial rows, have no controls: they keep the config's values through
every edit.

On the right, for the active dataset: *"N epochs from M of T trials (scope);
groups ..."*, with the epochs dropped for having no stop event, leaving the
recording or touching an artifact period (*"; N touch an artifact period"*),
or why there are none, a bar of epochs per group in the group
colours, and the kept trials with their group and number of epochs.

### Plots tab

- The plot list (`<id> (<kind>)`, disabled ones marked *(off)*): **Add** a
  kind, **Remove**, **Duplicate**, **Up / Down** (the run and report order).
- The editor: the plot's kind (with a line on what it draws), **Enabled**,
  id, title, source and layout on top, then sections that collapse under
  their headers (**▼** / **►**; which are collapsed is remembered):

  | Section | Rows |
  | --- | --- |
  | Units & channels (*Channels* for a signal) | unit classes (sorted units), **Good units only** (sorted units: `units.quality.enabled`, the units that meet the config's good-unit criteria, [UnitSelection](EphysAnalysisConfig.md#unitselection)); **Responsive only** with the test (vs baseline, tuned, either, both, or auROC: the units the auROC calls modulated over the response window, with its own *auROC from*, window, step and bin (ms) and *Modulated if* rows, and *Unit test* for a per-unit test; [auROC](EphysAnalysisConfig.md#auroc)) and direction, the test windows (baseline and response, s from the event) and the test options (tuning parameter, correction, alpha), for spike sources (`units.response`; the settings are enabled while the box is ticked; [response statistics](EphysAnalysis.md#response-statistics)); ids, max units, shanks, channels |
  | Event reference, Epoch window, Trial selection | the Alignment tab's controls, for this plot |
  | Bins & baseline (*Baseline* without bins) | bin and smoothing (ms), mask after the stop event, baseline mode and window. Baseline *auroc* (PSTH, spike heatmap) adds *auROC from* (PSTH bins, each epoch) and the windows (tiled, sliding), the window and step (ms), the call window (s), *Modulated if* (95% CI as the paper, taken over the plot's units of one dataset, so it needs many of them; `populationAnalysis` pools every dataset's ([population analysis](EphysAnalysis.md#population-analysis)); a fixed threshold, a per-unit test, none) with the threshold, *Unit test* (bootstrap, ranksum, shuffle; resamples, correction, alpha) for a per-unit test, and *Calls*: **Mark them**, **Modulated units only** ([auROC](EphysAnalysisConfig.md#auroc)) |
  | *Kind* options | PSTH and raster: **Sort raster by** (blank = trial order, stop latency or a trial parameter); PSTH: raster above, bar or line, normalization (none, unit peak, group peak), **Filled** and its opacity (blank = automatic), **Stack groups** and its spacing (a row per group, labelled by value on the left and by peak rate on the right); tuning: parameter and series; probe map: value; heatmap: row order (*modulation* too with the auROC baseline); unit correlation: row order, epoch rate (mean or peak) and correlation (Pearson or Spearman) |
  | Appearance | tiles per page, font size, line width, y limits, group colours (*lines*: the trial selection's colours; a colormap; or one colour such as *black* or `#1f77b4`, typed in), heat colours (*auto*: parula, or blueWhiteRed for unit correlations), SEM, stop marks, legend, grid |
  | Unit waveform | rasters, and PSTH and tuning grids, of spikes: **Show** (*Off*, *Mean*, *Subsample*, *Mean + subsample*) each unit's waveform on its peak channel in its tile, and how many spikes the subsample draws (a sorted unit's mean is over them); **Location** (*North-east* by default; north is the top edge), **Axis box** (an outline on a pale ground; unticked, the waveform alone) and its size (1x = a third of the tile). Sorted units' spikes are cut from the sorted `.bin` (their templates when it is not there); detections need the Spikes step's *Waveforms* option ([Unit waveforms](EphysAnalysisConfig.md#unit-waveforms)) |

  Only what the selected plot uses is shown (`syncPlotEditor`): its kind,
  source and layout decide. A probe map has no event, window, selection or
  baseline; bins are for PSTHs, rasters, spike heatmaps and unit
  correlations; y limits only where a rate or amplitude axis takes them
  (PSTHs, rates, tuning curves, the evoked butterfly and grid); tiles only
  for paged grids; group colours, legend and SEM only where groups are drawn
  as lines or bars; heat colours only for heatmaps, probe maps and unit
  correlations. The window modes offered are the kind's (*between* only for
  rates, tuning curves and unit correlations). Rows that another option
  switches off stay in place, greyed out: the opacity until *Filled*, the
  spacing until *Stack groups* (a stack has no y limits or legend), the
  baseline window until a baseline mode, a unit correlation's bins until
  its *peak* rate, the mask and stop marks until the window has a stop
  event, *n* until *nth*, the waveform's spikes, location, axis box and
  size until **Show** is not *Off*; under the auROC baseline the step until
  *sliding*, the threshold until a fixed cutoff, the resamples for
  ranksum, the calls without a cutoff, and smoothing and normalization
  (the auROC compares the bins as counted, on its own 0-1 scale).

  **Use default**, in the header of the Event reference, Epoch window and
  Trial selection sections: ticked, the section shows the Alignment tab's
  values and the plot uses them. The controls stay editable: an edit gives
  the plot its own values (the defaults with the edit) and unticks the box;
  ticking it again goes back to the defaults.
- The preview: on the active dataset, through the runner. **Preview** always
  computes (also for large signals); with **Auto** on, every edit redraws it
  while a preview takes under 2 s. Paged grids have `<` / `>`. A plot the
  dataset cannot draw says why (the runner's skip reasons).
- Right-click any part of the preview (a line, band, bar, text, legend or
  axes) and pick **Edit aesthetics...** to change colours, line styles and
  widths, markers, opacity and fonts in a modal window. It lists every
  component of the plot, shows each change at once, applies it to that
  component, the same one in every tile, every group of its role or the
  ticked rows, and has **Reset**, **Cancel** and **OK**. **Remember for
  future plots** keeps the changes with this plot (its `aesthetics`, saved
  with the config, so runs and reports match the preview) or for every plot
  of the kind (your preferences, group `PlotAesthetics`). See
  [Plot aesthetics](EphysAnalysis.md#plot-aesthetics).

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
| File | New config, Open config..., Open recent, Save config, Save config as..., Generate script ▸ Compact (loads the saved config) / Standalone (every setting written out), Open pipeline app, Close |
| Help | Help for this tab, Documentation home, Analysis quick start, Analysis configs (wiki pages `Analysis-App`, `Analysis-Configs`), About EphysAnalysisApp (the version and git commit of the code, the repository folder and the MATLAB release; **Copy** puts them on the clipboard) |

The title shows `*` while the config has unsaved changes; closing, opening
or starting a new config asks to save them.

## Preferences

Group `EphysAnalysisApp`, kept through [`AppPrefs`](../pipeline/AppPrefs.m): MATLAB preferences, or the file
named by the environment variable `EPHYS_APP_PREFS_FILE` (the tests' temporary store). Everything else
is in the config.

| Preference | Meaning |
| --- | --- |
| `FigurePosition` | window position and size |
| `LastConfigFile` | reopened at launch |
| `RecentConfigs` | File → Open recent (8) |
| `ScriptFolder` | where Generate script offers to save |
| `AutoPreview` | the Plots tab's Auto box |
| `PreviewMaxMB` | signal extracts larger than this (default 500 MB) are previewed only with the Preview button |
| `PlotSectionsCollapsed` | the plot editor's collapsed sections |

The aesthetics editor keeps two more groups: `PlotAesthetics`, your
remembered rules, one per plot kind (`psth`, `raster`, ...), and
`PlotAestheticsDialog`, its **Remember** box and where it last remembered
(`Remember`, `Scope`).

## Why is my plot skipped?

The runner's `plotSkipReason`, shown by the preview, Plan and the results:

| Reason | Cause | Fix |
| --- | --- | --- |
| no sorted units | no sorting folder | sort the dataset, or associate its sorted-output folder |
| no detected spikes | the spikes file has no threshold detections | run the Spikes step with detection |
| no LFP extract (MUA, SPIKE, AUX) | the Signals step did not write that signal | enable it in the pipeline's Signals step |
| no paired trials | trial scope, the `Trial` line, a filter / response / group-by or a tuning plot on a dataset without paired trials | approve the pairing on the pipeline app's Trials tab and write the behavior file; or align in recording scope without a selection |
| no line X | the event or stop line is not among the dataset's lines | check the line names on the Data tab |
| no trial parameter X | a group-by or tuning parameter the trials lack | pick one from the dataset's parameters |
| no probe map | the manifest names no probe file (probemap plots) | assign a probe in the pipeline app |

A plot that is not skipped can still fail when it runs, e.g. *no Stim onset
event is left after the selection* or *none of the N events makes a usable
epoch (M with a window outside the recording)*: the message is in the
results and the report.

## Where the code is

| Part | Files |
| --- | --- |
| building | `buildUI`, `buildMenus`, `buildDataTab`, `buildAlignTab`, `buildPlotsTab`, `buildExportTab`, `buildLogTab`, `buildAlignControls`; the editor's collapsible sections in `private/` (`formSection`, `formRow`, `formShow`, `formLayout`) |
| config model | `gatherConfig` / `applyConfig`, `gather*` / `apply*Section`, `gatherAlignControls` / `applyAlignControls`, `gatherPlotEditor` / `applyPlotEditor`, `onConfigChanged`, `updateTitle`, `confirmDiscard` |
| plot editor | `syncPlotEditor` (what shows, what is enabled, what the drop-downs offer: `private/plotEditorChoices`), `layoutPlotEditor`, `onPlotSectionToggled`, `onPlotAlignEdited`, `onPlotDefaultToggled`, `applyPlotEditorDefaults` |
| data | `openSource`, `onScan`, `refreshDatasetsTable`, `selectDataset`, `refreshDatasetInfo` |
| previews | `refreshAlignPreview`, `refreshPreview`, `autoPreview`, `onPreviewPage` |
| running | `onValidate`, `onPlan`, `onRunExport`, `onCancelRun` |
| files | `onNewConfig`, `onOpenConfig`, `openConfigFile`, `onSaveConfig`, `onSaveConfigAs`, `onGenerateScript`, `loadPreferences`, `savePreferences` |

## Tests

`test_EphysAnalysisApp` builds the app headlessly on the analysis fixture
(a small synthetic project run through the pipeline) and drives it through
its methods: the five tabs; the scan; opening on a list of datasets
(`Datasets=`, as the pipeline app's Tools panel does); the active dataset's
lines and parameters; grouping by Depth from the Alignment controls; adding
a PSTH and an LFP evoked potential and previewing both; the response test
(*Responsive only* and its settings reaching the plot); a PSTH's stack,
normalization, fill, opacity and group colours reaching the plot and the
stacked preview; the preview's right-click
aesthetics editor remembering rules into the plot's config entry (the
editor itself: `test_PlotAesthetics`); editing the bins; an edit in a
*Use default* section giving the plot its own event or window, and ticking
it again going back; the editor showing only the rows and sections a plot
uses (y limits, heat colours, a probe map's missing alignment) and greying
out the ones its options switch off; a spike heatmap with the auROC baseline
(its settings shown and reaching the plot, its preview marked) and the auROC
response test; the Unit waveform rows (greyed out while *Off*, reaching
the plot, previewed without the box, hidden for an overlay); collapsing a
section; the gather / apply
round trip, keeping the fields without a control (the stop event's offset,
length and time range, trial rows) and the stop's *n*; Save As, New, reopen;
generating scripts; Validate, Plan and a run of one plot writing figures
and the report (its lines in the Log tab); the preferences remembered (the
last config, the collapsed section); closing. It keeps the app's
preferences in a temporary file (`AppPrefs`), so the user's own are never
read or changed.
