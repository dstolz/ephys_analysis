# EphysAnalysisApp

`EphysAnalysisApp` ([source](../analysis/@EphysAnalysisApp/EphysAnalysisApp.m))
is the GUI for quick-look figures of datasets the pipeline has processed:
PSTHs with rasters, rasters, evoked potentials, firing rates, tuning curves,
heatmaps, probe maps and unit-by-unit correlation matrices. Every figure can
be aligned to any digital line, and trials can be filtered and grouped by
Epsych2 parameters such as `Depth`. The figures are written as PNG / EPS /
SVG / PDF files and collected into an HTML and / or PDF report.

The app edits one [`EphysAnalysisConfig`](EphysAnalysisConfig.md) (saved as
JSON) and draws it with an `EphysAnalysisRunner`
([Analysis](EphysAnalysis.md#runner)). It computes nothing itself: its
previews, plans and runs are the runner's `computePlot`,
`renderPlotFigures`, `plan` and `run`, so a preview is what a run or a
[generated script](EphysAnalysis.md#scripts) draws. It is for quick looks:
spectra, coherence and the like belong in Chronux or FieldTrip, for which
the pipeline's [Export step](EphysPipelineApp.md#export) writes the data.

<!-- wiki: More on those exports: [Analysis toolbox exports](Analysis-Toolbox-Exports). -->

<!-- wiki: ![The analysis app, Plots tab, previewing a PSTH grouped by Depth](images/analysis-plots-tab.png) -->

## Quick start

On the [synthetic test project](EphysPipelineApp.md#synthetic-test-project)
after a pipeline run:

```matlab
addpath_nogit('C:\src\ephys_analysis')     % pipeline + analysis (see INSTALL.md)
EphysAnalysisApp("D:\EPHYS_synthetic")     % a project root processed by the pipeline
```

1. **Data**: the project is scanned when the app opens; click a row in the
   datasets table to make it the **active dataset**.
2. **Alignment**: align to `Stim` onset (first per trial) and set **Group
   by** to `Depth`. The summary on the right counts the epochs in each
   group.
3. **Plots**: pick a kind in the drop-down under the plot list and press
   **Add**: a PSTH, an evoked potential (set its **Source** to `LFP`), a
   rate plot (e.g. `RespWindow` onset → offset: set the line in its *Event
   reference* section and the stop event in its *Epoch window* section,
   which gives the plot its own), a tuning curve (parameter `Depth`), a
   heatmap, a probe map and a unit correlation. Each previews on the active
   dataset.
4. **Export**: tick png / svg / pdf, press **Run**, then **Open report**.
5. **File → Save config** keeps the setup; **File → Generate script →
   Standalone** writes a script that draws the same figures without the
   app.

A plot the dataset cannot draw says why instead of drawing (no sorted
units, no LFP extract, no paired trials, ...): see
[Why is my plot skipped?](#why-is-my-plot-skipped)

## Launching

| Call | Opens |
| --- | --- |
| `EphysAnalysisApp` | the last config (preference `LastConfigFile`), else the defaults |
| `EphysAnalysisApp("D:\EPHYS")` | a new config in project mode on that root, scanned |
| `EphysAnalysisApp("D:\EPHYS", OutputRoot="E:\out")` | the same with the project's output root. `NamePattern=` and `Recordings=` (`"concatenate"`, `"separate"`, `"single"`) are taken too |
| `EphysAnalysisApp("D:\EPHYS", Datasets=["subj1/day1" "subj1/day2"])` | the same with only those datasets selected (root-relative keys; `Source.Selection = "list"`): every dataset is listed, but only these are ticked to run, and the first of them is active; one dataset names the config. The pipeline app's Tools panel opens it this way |
| `EphysAnalysisApp("D:\out\subj1_day1")` | a folder holding `<Name>_manifest.json` or `<Name>_extract*.mat` is one dataset's output folder: a new config in folders mode with that folder, scanned |
| `EphysAnalysisApp("am.json")` | that analysis config (its source scanned when it exists) |
| `app = EphysAnalysisApp(...)` | the same, keeping a handle |

The detection is in `openSource`. A new config made from a folder is named
after it (`<folder> quick look`, or after the one dataset of `Datasets=`)
and has no plots yet.

**From the pipeline app.** Its **File → Open analysis app...** opens this
app on the project root, output root, name pattern and Open Ephys recording
mode set there; without a project root, on the analysis app's last config.
The analysis app's **File → Open pipeline app** goes the other way. The two
apps share no state: each keeps its own config.

## Tabs

### Data tab

<!-- wiki: ![Data tab: a scanned synthetic project and the active dataset's lines and parameters](images/analysis-data-tab.png) -->

The left side says where the datasets are; the right side describes the
active dataset.

| Control | Effect | Config field |
| --- | --- | --- |
| **Config name**, description | the config's name (the report's title by default) and a free-text description | `name`, `description` |
| **Datasets from** | *a pipeline project (root folder)* or *output folders* | `Source.Mode` |
| **Project root**, **Browse...** | the folder the pipeline scans (project mode) | `Source.Root` |
| **Output root**, **Browse...** | the project's output root; blank = outputs next to each recording | `Source.OutputRoot` |
| **Name pattern** | dataset-name tokens, as in the pipeline config | `Source.NamePattern` |
| Open Ephys drop-down | *join recordings*, *one dataset per recording* or *single recording*: what an Open Ephys session with several recordings is, as in the pipeline config's `Acquisition.OpenEphys.Recordings` | `Source.Recordings` |
| **Output folders**, **Add...** | one dataset output folder per line (folders mode), for a machine that holds only the processed files | `Source.Folders` |
| **Scan** | builds a new runner, which finds the datasets (and holds the data it loads) | |

Match the project settings to the pipeline config that wrote the outputs,
or the datasets' files are not found. Opening the app from the pipeline app
copies them.

**The datasets table**, one row per dataset found:

| Column | Meaning |
| --- | --- |
| **Run** | tick the datasets a run uses. In project mode the ticks are saved in the config: all ticked is `Selection = "all"`, otherwise `"list"` with the ticked keys. In folders mode every folder listed is ticked after a scan and the ticks are not saved |
| **Name**, **Key** | the dataset's name and key (the root-relative folder, or the output folder in folders mode) |
| **LFP**, **MUA**, **SPIKE**, **AUX** | ✓ when that signal's extract exists |
| **Units**, **Detected** | the sorting folder holds sorted units; the spikes file holds threshold detections |
| **Behavior** | `<Name>_behavior.mat` exists |
| **Trials**, **Pairing**, **Duration (s)** | once the dataset has been loaded (making it active loads it): the number of trials, the pairing (its recorded status, `paired`, or `not paired`) and the recording's length |

Click a row to make it the **active dataset**: the Alignment and Plots tabs
preview it. After a scan the first ticked dataset is active.

**Active dataset**, on the right:

- the size of each signal extract and the recording's length; an extract
  larger than `PreviewMaxMB` (500 MB by default) is read for a preview only
  when **Preview** is pressed on the Plots tab;
- **Files**: what `DatasetOutputs.inventory` found (kind, exists, source,
  file);
- the digital lines: each line's interval count, mean length, first and
  last onset (s) and whether it is inverted. The event lines are these, or
  `Trial`;
- the behavior: subject, trials, the trial line they are paired with and
  the pairing flags, and the responses;
- the parameters: every trial column but the pairing's times and samples,
  with their values (the first 12). These are what trials can be grouped,
  filtered and tuned by;
- the sorted units by class and shank, with their spike counts.

### Alignment tab

<!-- wiki: ![Alignment tab: Stim onset, first per trial, grouped by Depth, with the epoch count per group](images/analysis-alignment-tab.png) -->

Edits the config's **Defaults**: the event reference, epoch window and
trial selection that every plot uses unless it sets its own on the Plots
tab. [EphysAnalysisConfig](EphysAnalysisConfig.md#defaults) explains each
field; in short:

**Event reference (align to)** (`Defaults.EventRef`)

| Control | Meaning |
| --- | --- |
| **Line** | the digital line to align to: the active dataset's lines are listed, and one can be typed. `Trial` is the paired trial line (`TrialOnset` / `TrialOffset`) |
| **Edge** | `onset` or `offset` of each interval |
| **Which**, **n** | the `first`, `last`, `all` or `nth` interval: per trial in trial scope, over the whole recording in recording scope |
| **Scope** | `trial`: the line's intervals whose edge lies inside a selected trial; `recording`: every interval; `auto`: trial when the dataset has paired trials, else recording |
| **Offset (s)** | added to every event time |
| **Length (s)** | keep the intervals whose length lies in this range (`0` to `Inf`) |
| **Time range (s)** | keep the events in this range, from the trial onset (trial scope) or the recording start |
| **Shift by**, **unit** | a trial parameter whose value on each event's trial is added to the event, in ms (default, as Epsych2 stores times) or s: *RespWindow onset* shifted by *RespLatency* is the response. The trials without a value (misses) are left out, and the count says how many (`offsetParam`, `offsetParamUnit`) |

**Epoch window** (`Defaults.Window`)

| Control | Meaning |
| --- | --- |
| **Mode** | `fixed: [t0+pre, t0+post]`, or `between: [t0+pre, stop+post]` for a period of varying length that ends at a stop event |
| **Pre (s)**, **Post (s)** | the window's edges from the event (in between mode, `post` from the stop event) |
| **Stop event**, line, edge, **Stop which**, **n**, **Stop scope** | the event that ends each epoch, the first (or chosen) one after the epoch's event. Required in between mode; in fixed mode it is still marked on PSTHs and rasters and can mask a PSTH |
| **Stop shift by**, **unit** | a trial parameter added to the stop event, from the epoch's trial: with the event at Stim onset and the stop at *RespWindow onset* shifted by *RespLatency*, each raster row marks its response and can be sorted by it |

**Trial selection** (`Defaults.Selection`)

| Control | Meaning |
| --- | --- |
| **Filter**, **?** | an expression over the trials table, e.g. `Depth > 0 & RespLatency < 500` or `Hit \| Miss`. **?** lists the trial columns, the response words and the functions a filter may use. The filter is compiled from its own tokens, never passed to `eval` |
| **Response** | keep the trials that are any of the ticked response words (`Hit`, `Miss`, `CR`, `FA`, `Reward`, `Punish`, `NoResponse`, `Response`: bits of `RespCode`) |
| **Pairing** | keep the trials with these `PairingFlag` values: `ok` (default), `partial`, `cut`, `unpaired`; none ticked keeps every flag |
| **Group by**, **and** | up to two trial parameters: one group per value, or pair of values |
| **Order**, **Max groups** | the groups' order (`ascending`, `descending`, `appearance`); more groups than the maximum (12 by default) is an error |

The stop event's offset, interval length and time range, and the selection's
explicit trial rows, have no controls: they keep the config's values through
every edit.

On the right, for the active dataset (**Active dataset** picks another):
*"N epochs from M of T trials (scope); groups ..."*, with the events
dropped for lacking the **Shift by** parameter's value, and the epochs
dropped for having no stop event, leaving the recording or touching an
artifact period (*"; N touch an artifact period"*), or why there are none;
a bar of epochs per group in the group colours the plots use; and the kept
trials with their group and number of epochs.

A filter, response, group-by or trial scope needs paired trials: approve
the pairing on the pipeline app's [Trials tab](EphysPipelineApp.md#trials)
and write the behavior file. Without paired trials, align in recording
scope with no selection.

### Plots tab

<!-- wiki: ![Plots tab: the plot list, the editor for a PSTH and its preview](images/analysis-plots-tab.png) -->

Three columns: the plot list, the editor of the selected plot, and the
preview.

**The plot list.** Each entry reads `<id> (<kind>)`; disabled plots are
marked *(off)*. The list order is the run and report order.

| Control | Effect |
| --- | --- |
| kind drop-down, **Add** | adds a plot of that kind ([Plot kinds](#plot-kinds)) with the next free id (`psth_1`, `psth_2`, ...) and selects it |
| **Remove**, **Duplicate** | removes the selected plot; copies it with a new id |
| **Up**, **Down** | moves it in the list |

**The editor.** On top: the plot's kind (with a line on what it draws),
**Enabled** (a disabled plot is kept but not run; `enabled`), **Id**
(unique; it names the exported files, `{Plot}`; `id`), **Title** (blank =
automatic, `<Kind>: <line> <edge> (<n> epochs)`; `title`), **Source**
(`source`) and **Layout** (`layout`). Then sections that collapse under
their headers (**▼** / **►**; which are collapsed is remembered):

| Section | Rows |
| --- | --- |
| Units & channels (*Channels* for a signal) | unit classes (sorted units: `su`, `mua`, `uns`, `noise`; none ticked = every class; `units.classes`), **Good units only** (sorted units: `units.quality.enabled`, the units that meet the config's good-unit criteria, [UnitSelection](EphysAnalysisConfig.md#unitselection)); **Responsive only** with the test (vs baseline, tuned, either, both, or auROC: the units the auROC calls modulated over the response window, with its own *auROC from*, window, step and bin (ms) and *Modulated if* rows, and *Unit test* for a per-unit test; [auROC](EphysAnalysisConfig.md#auroc)) and direction, the test windows (baseline and response, s from the event) and the test options (tuning parameter, correction, alpha), for spike sources (`units.response`; the settings are enabled while the box is ticked; [response statistics](EphysAnalysis.md#response-statistics)); unit ids (sorted units) or channels (detected), e.g. `3 5 8:12` (`units.ids`), max units (`units.maxUnits`), shanks (`units.shanks`), channels (spike sources: the recording channels kept, `units.channels`; signals: the extract's columns drawn, `channels`) |
| Event reference, Epoch window, Trial selection | the Alignment tab's controls, for this plot (`ref`, `window`, `selection`) |
| Bins & baseline (*Baseline* without bins) | bin and smoothing (ms; smoothing is a Gaussian SD, 10 ms by default, 0 = none; `bins.BinSec`, `bins.SmoothSec`), mask after the stop event (`maskAfterStop`), **Measure** (*rate*, *count* or *probability*; `measure`), baseline mode and window (`baseline.Mode`, `baseline.Window`). Baseline *auroc* (PSTH, spike heatmap; `auroc`) adds *auROC from* (PSTH bins, each epoch) and the windows (tiled, sliding), the window and step (ms), the call window (s), *Modulated if* (95% CI as the paper, taken over the plot's units of one dataset, so it needs many of them; `populationAnalysis` pools every dataset's ([population analysis](EphysAnalysis.md#population-analysis)); a fixed threshold, a per-unit test, none) with the threshold, *Unit test* (bootstrap, ranksum, shuffle; resamples, correction, alpha) for a per-unit test, and *Calls*: **Mark them**, **Modulated units only** ([auROC](EphysAnalysisConfig.md#auroc)) |
| *Kind* options | PSTH and raster: **Sort raster by** (blank = trial order, stop latency or a trial parameter; `rasterSort`) and its direction (ascending or descending; `rasterSortOrder`), **Raster rows by group first** (unticked: every epoch sorted as one block, each row on its group's colour; `rasterByGroup`), **Mark events** (the lines whose events are marked on each row, e.g. `Trough`, several separated by spaces or commas; onset, offset or both; every event in the window or only in the epoch's trial; `rasterEvents`) and **Mark look** (marker, size, and *auto* (a colour per line and edge) or one colour; right-click a mark to style one line's marks on its own); behavior: **Y value** (a trial parameter such as RespLatency, or *stop*: the stop event's latency, ms; `yParam`), parameter and series (`param`, `seriesParam`), **X axis** (evenly spaced or at their values; `xScale`) and **Jitter points** (points layout; `jitter`); PSTH: **Raster above each PSTH** (`withRaster`), **PSTH as** bar or line (`histStyle`), normalization (none, unit peak, group peak; `normalize`), **Filled** and its opacity (blank = automatic; `fill`, `fillAlpha`), **Stack groups** and its spacing (a row per group, labelled by value on the left and by peak rate on the right; `stack`, `stackSpacing`); tuning: parameter and series (`param`, `seriesParam`); probe map: value (`value`); heatmap: row order (*probe*, *peak*, and *modulation* with the auROC baseline; `order`); unit correlation: epoch rate (mean or peak; `metric`) and correlation (Pearson or Spearman; `correlation`) |
| Appearance (`style`) | tiles per page (`MaxTiles`), grid spacing (*loose*, *compact*, *tight*, *none*; `TileSpacing`) and **Labels on corner tile only** (`CornerLabelsOnly`), font size, line width, site size (probe map), y limits (blank = automatic, or two numbers such as `0 40`), group colours (*lines*: the trial selection's colours; a colormap; or one colour such as *black* or `#1f77b4`, typed in; `Colormap`), heat colours (*auto*: parula, or blueWhiteRed for unit correlations; `HeatColormap`), **Sort by** depth and / or shank (`SortDepth`, `SortShank`: units and channels top of the probe first, by shank first), **Label with** depth and / or shank (`LabelDepth`, `LabelShank`), and **Show** SEM, stop marks, legend, grid |
| Unit waveform | rasters, and PSTH and tuning grids, of spikes: **Show** (*Off*, *Mean*, *Subsample*, *Mean + subsample*) each unit's waveform on its peak channel in its tile, and how many spikes the subsample draws (a sorted unit's mean is over them); **Location** (*North-east* by default; north is the top edge), **Axis box** (an outline on a pale ground; unticked, the waveform alone) and its size (1x = a third of the tile). Sorted units' spikes are cut from the sorted `.bin` (their templates when it is not there); detections need the Spikes step's *Waveforms* option (`waveform`; [Unit waveforms](EphysAnalysisConfig.md#unit-waveforms)) |

Only what the selected plot uses is shown (`syncPlotEditor`): its kind,
source and layout decide. A probe map has no event, window, selection or
baseline, and a raster no baseline; bins are for PSTHs, rasters, spike
heatmaps and unit correlations; the measure for PSTHs, rates, tuning curves
and spike heatmaps; y limits only where a rate or amplitude axis takes them
(PSTHs, rates, tuning curves, the evoked butterfly and grid); tiles only for
paged grids; grid spacing and corner labels for every kind but rates; sort
and label options for every kind but probe maps; line width for PSTHs,
evoked potentials and tuning curves; group colours, legend (with its place
-- inside, or north, south, east or west of the whole grid of plots -- its
orientation and its box, on while the legend is) and SEM only
where groups are drawn as lines or bars; heat colours only for heatmaps,
probe maps and unit correlations; the unit waveform for rasters and PSTH
and tuning grids of spikes. A behavior plot reads only the trials: it
shows its y value, parameter, series and x axis, the event, window and
selection, the font, line width, y limits, series colours, SEM, legend
and grid, and no unit, channel, bin, baseline or tile rows. The window modes offered are the kind's
(*between* only for rates, tuning curves and unit correlations), and so are
the baseline modes ([Plot kinds](#plot-kinds)). Rows that another option
switches off stay in place, greyed out: the opacity until *Filled*, the
spacing until *Stack groups* (a stack has no y limits or legend), the
baseline window until a baseline mode, a unit correlation's bins until its
*peak* rate, the mask and stop marks until the window has a stop event,
*n* until *nth*, the raster sort, grouping and marks until *Raster above
each PSTH*, the marks' look until a line is named to mark, the jitter
until the *points* layout, the units of a shift until a parameter is
chosen, the
waveform's spikes, location, axis box and size until **Show** is not
*Off*; under the auROC baseline the step until *sliding*, the threshold
until a fixed cutoff, the resamples for ranksum, the calls without a
cutoff, and smoothing and normalization (the auROC compares the bins as
counted, on its own 0-1 scale).

**Use default**, in the header of the Event reference, Epoch window and
Trial selection sections: ticked, the section shows the Alignment tab's
values and the plot uses them. The controls stay editable: an edit gives
the plot its own values (the defaults with the edit) and unticks the box;
ticking it again goes back to the defaults. A probe map aligns to nothing,
so it has none of the three.

**The preview** draws the selected plot on the active dataset through the
runner, so it is what a run exports.

| Control | Effect |
| --- | --- |
| **Active dataset** | the dataset previewed (the same one as on the other tabs) |
| **Preview** | computes now, also for a signal extract above `PreviewMaxMB` |
| **Auto** | redraw after every edit while a preview takes under 2 s; a slower one says so (*"slow, so edits wait for Preview"*) |
| **<**, **>** | the pages of a paged grid |

The line under the preview names the plot, the dataset and the time taken,
or says why the plot cannot be drawn (the runner's
[skip reasons](#why-is-my-plot-skipped)) or failed.

**Plot aesthetics.** Right-click any part of the preview (a line, band,
bar, text, legend or axes) and pick **Edit aesthetics...** to change
colours, line styles and widths, markers, opacity and fonts in a modal
window. It lists every component of the plot, shows each change at once,
applies it to that component, the same one in every tile, every group of
its role or the ticked rows, and has **Reset**, **Cancel** and **OK**.
**Remember for future plots** keeps the changes with this plot (its
`aesthetics`, saved with the config, so runs and reports match the preview)
or for every plot of the kind (your preferences, group `PlotAesthetics`);
its **Remembered** tab lists both sets and forgets rules. See
[Plot aesthetics](EphysAnalysis.md#plot-aesthetics).

### Export tab

<!-- wiki: ![Export tab: figure files, the report, and a finished run's results](images/analysis-export-tab.png) -->

**Figure files** (config `Export`):

| Control | Meaning | Default |
| --- | --- | --- |
| **Write figure files** | export each plot's pages (`Enabled`) | on |
| **Formats** | any of `png`, `eps`, `svg`, `pdf` | png, svg |
| **Folder**, **Browse...** | a folder pattern with `{OutputFolder}` (each dataset's output folder), `{OutputRoot}`, `{Root}`, `{Name}`, `{Date}` | `{OutputFolder}\analysis` |
| **File names** | a file-name pattern with `{Name}` `{Plot}` `{Kind}` `{Group}` `{Unit}` `{Index}` `{Date}`. A paged plot adds `_p<page>` unless the pattern tells its pages apart ([Exported figure names](file-formats.md#exported-figure-names)) | `{Name}_{Plot}` |
| **Dpi (png)** | the PNG resolution | 150 |
| **Overwrite existing** | off: a page whose files all exist is not written again | on |
| **Size (cm)** | the figure's width and height (a page of many tiles is made taller) | 18 × 12 |

**Report** (config `Report`):

| Control | Meaning | Default |
| --- | --- | --- |
| **Write a report**, format | *HTML (one self-contained file)*, *PDF (multi-page)* or *HTML and PDF* | on, HTML |
| **Title** | `{Name}` = the config's name, `{Date}` = today | `{Name}` |
| **Folder**, **Browse...** | folder tokens as above | `{OutputRoot}\analysis` |
| **File name**, **One per dataset** | `.html` / `.pdf` is added; one report per dataset is named `<FileName>_<dataset>` | `analysis_report`, off |
| **HTML images**, **Dpi** | PNG (base64) or inline SVG in the HTML; the PNG resolution | png, 110 |
| **Summary tables**, **Plot parameters**, **The config** | what the report holds besides the figures | all on |

**Running**:

| Button | Effect |
| --- | --- |
| **Validate** | lists the config's issues (Section, Field, Severity, Message) in the table; errors stop a run |
| **Plan** | one row per ticked dataset and plot (Dataset, Plot, Kind, Source, Enabled, Reason): whether it will run, and why not ([skip reasons](#why-is-my-plot-skipped)). Cheap: no signals or spikes are loaded |
| **Run** | validates, then runs every enabled plot on every ticked dataset with a cancelable progress dialog: compute, export, report. A failing plot is an error row and the rest still run |
| **Cancel** | stops before the next plot; the plots left are *cancelled* |
| **Open report**, **Open figure folder** | after a run: the report files written, and the first dataset's figure folder |

The results table has one row per dataset and plot: `Dataset`, `Plot`,
`Kind`, `Status` (`done`, `skipped`, `error`, `cancelled`), `Message`,
`Files`, `Seconds`. The label above it counts each status.

### Log tab

What the scans, previews and runs reported, one time-stamped line each
(the last 2000 lines are kept): the datasets found, each plot done with its
file count and time, the plots skipped with the reason, failures with the
error, and the report files written.

## Plot kinds

The nine kinds of `EphysAnalysisConfig.plotKinds()`; the first layout
listed is the default.

| Kind (label) | Sources | Layouts | Windows | Baseline modes |
| --- | --- | --- | --- | --- |
| `psth` (PSTH) | units, detected | grid, overlay | fixed | none, subtract, zscore, percent, auroc |
| `raster` (Raster) | units, detected | grid | fixed | none |
| `evoked` (Evoked potential) | LFP, MUA, SPIKE, AUX | stack, butterfly, grid | fixed | none, subtract |
| `rate` (Firing rate) | units, detected | bar, box, points | fixed, between | none, subtract, ratio, zscore |
| `tuning` (Tuning curve) | units, detected | grid, overlay | fixed, between | none, subtract, ratio, zscore |
| `heatmap` (Heatmap) | all six | groups | fixed | spikes: as the PSTH; signals: none, subtract |
| `probemap` (Probe map) | units, detected | shanks | no alignment | none |
| `corrmap` (Unit correlation) | units, detected | groups | fixed, between | none, subtract |
| `behavior` (Behavior) | trials | points, line, box, swarm, violin | fixed | none |

How each is computed: [Compute](EphysAnalysis.md#compute).

### PSTH

The peri-event firing rate per unit, groups overlaid, with a raster above
each unit.

<!-- wiki: ![A PSTH grid: one tile per unit, a raster above each, groups by Depth](images/analysis-example-psth.png) -->

- **Bin** (10 ms by default) is the bin width. The bins are whole
  multiples of it from the event, half-open, and the window shrinks to the
  whole bins inside it (the caption says so).
- **Smooth** is the SD of a Gaussian applied to each epoch before
  averaging, renormalized at the window's edges (10 ms by default; 0 = off).
- **PSTH as** `bar` draws one bar per bin, `line` a trace through the bin
  centres; **Filled** fills the bars or the area under the line (half
  transparent where groups overlap unless the opacity is set). The SEM band
  is drawn behind either.
- Layouts: `grid` is one tile per unit (**Tiles per page** per page);
  `overlay` is one panel with the mean over units (± SEM across units).
- **Normalize**: *unit peak* divides a unit's PSTHs by their largest
  absolute value over every group, *group peak* each PSTH by its own. **Stack groups**
  draws one row per group instead of overlaying them.
- Baseline: `subtract`, `zscore` or `percent`, per group from the spikes
  counted in the baseline window (which may lie outside the plotted
  window), or `auroc`: the curves become the auROC of each window against
  the baseline, drawn from 0.5 on a 0-1 axis, with each unit's call (up,
  down, n.s.) in its title ([auROC](EphysAnalysis.md#auroc)).
- **Mask after the stop event** drops each epoch's bins from its stop
  event on, so the mean covers only the epochs still going. **Stop marks**
  draws a dashed line at each group's mean stop time and a dot on each
  raster row.

### Raster

One raster per unit: epochs as rows, sorted by group, then by **Sort raster
by** (ascending or descending), then by time, each group on a pale band of
its colour; with **Raster rows by group first** unticked every epoch is
sorted as one block, each row on its group's colour. Paged like the PSTH
grid.

- To align the rows to the response: in the plot's *Event reference*,
  **Line** *RespWindow*, **Shift by** *RespLatency* (ms). The trials
  without a response are left out.
- To keep the rows aligned to the stimulus and sort them by response
  latency: tick **Stop event** in the *Epoch window* with *RespWindow*
  onset and **Stop shift by** *RespLatency*, then **Sort raster by**
  *stop*. **Stop marks** puts a dot at each row's response.
- **Mark events** marks every onset and / or offset of the named lines
  inside each row's epoch (*Trough* for nose pokes, a beam line for beam
  crossings: several in a trial give several marks), in **Mark look**'s
  marker, size and colour. Each line and edge is listed in the legend and
  is one component for the aesthetics editor, so a right-click restyles
  one line's marks.

<!-- wiki: ![Rasters of several units, epochs sorted by Depth](images/analysis-example-raster.png) -->

### Evoked potential

The event-locked average of an LFP / MUA / SPIKE / AUX extract (µV; AUX in
volts). Baseline `subtract` takes each epoch's mean over the baseline
window off it, per channel; the baseline is taken from the epoch's own
samples, so its window must overlap the plotted window.

- `stack`: one panel, the channels stacked in probe order, the groups in
  their colours.
- `butterfly`: one tile per group, every channel overlaid, coloured by
  that order.
- `grid`: one tile per channel (paged), the groups overlaid with SEM bands.

Time 0 of each epoch is the signal's sample nearest the event (the
`"event"` onset rule, as in the epoch export). Epochs whose window leaves
the signal, or that hold non-finite samples, are dropped.

### Firing rate

Each unit's rate in each epoch window, units along x in probe order, groups
side by side. `bar` is the mean ± SEM, `box` a box plot of the epochs,
`points` every epoch as a dot (with a fixed jitter) and the mean as a bar.
This kind takes **between** windows, e.g. `RespWindow` onset to offset:
set the line in the plot's *Event reference* and the stop event in its
*Epoch window*. The baseline modes normalize: `subtract` takes each epoch's
own baseline rate off its rate, `ratio` divides by the unit's mean baseline
rate, and `zscore` is (rate − mean baseline) / SD of the unit's baseline
over all epochs.

### Tuning curve

The rate against a trial parameter (**Parameter**), one curve per value of
**Series**. `grid` is one tile per unit, `overlay` the mean over units. A
text parameter is spaced evenly with its values as tick labels. It needs
paired trials and the parameters named.

### Behavior

One value per epoch against a trial parameter: the response latency by
the stimulus depth, say. **Y value** is a numeric trial parameter
(*RespLatency*, as recorded: Epsych2 stores ms) or *stop*, each epoch's
stop-event latency in ms (with the event at *RespWindow* onset and the
stop at *Trough* onset, both in trial scope: the time to the response on
the digital lines). **Parameter** is the x axis, **Series** splits the
values into series side by side in their colours (blank: one); the trial
selection's groups are not used. Epochs without a value (misses) are
left out and counted in the caption.

- `points`: every value as a dot (**Jitter points** spreads them
  sideways), with each x value's mean ± SEM.
- `line`: the mean ± SEM per x value, joined.
- `box`: a box plot per x value (`boxchart`).
- `swarm`: every value, spread so none overlap (`swarmchart`), with the
  mean ± SEM.
- `violin`: the values' density (`violinplot`, MATLAB R2024b or later),
  with the mean ± SEM.

**X axis** spaces the values evenly (labelled with their values) or
places them at their values. It reads no spikes or signals, only the
paired trials and the digital lines, so it needs paired trials; the
window need not lie inside the recording and artifact periods do not
matter.

### Heatmap

Units (spike sources, from a PSTH) or channels (signal sources, from an
evoked potential) by time, one tile per group, on one colour scale. **Row
order**: `probe` (as **Sort by** says), `peak` (the time of each row's
maximum), or, with the auROC baseline, `modulation` (the units by their
mean auROC in the call window in the first group, highest first; the other
tiles keep that order). An auROC heatmap is coloured on [0 1] and, with
**Mark them**, marks each unit the call finds modulated (a red up or blue
down triangle).

### Probe map

One value per probe site, on the probe's layout, all shanks on one axis
and one colour scale: the summed firing rate (`rate`: spikes over the whole
recording divided by its length), `nSpikes` or `nUnits`. Sites without a
value are open grey squares, and the units' positions are black dots. It
uses no events or trials, and needs the probe map the dataset's manifest
names.

### Unit correlation

The trial-to-trial covariation of the units' responses: every pair of
units is correlated over the epochs of each group, one square units × units
matrix per group.

<!-- wiki: ![Unit correlation matrices, one per Depth group, on the blueWhiteRed scale](images/analysis-example-corrmap.png) -->

- **Epoch rate** `mean`: each epoch's response is its spike count over
  `[tStart, tStop)` divided by the window's length. `peak`: its largest
  binned rate (bins of **Bin** from the window's start, smoothed by
  **Smooth**; a bin that runs past the window's end is not used).
- **Correlation** `Pearson`, or `Spearman` (Pearson of the ranks, ties
  averaged). No toolbox is needed.
- Baseline `subtract` takes each epoch's own baseline rate off its
  response. Fixed and between windows both work.
- The colour scale is `[-1 1]` in `blueWhiteRed` (negative blue, zero
  white, positive red) unless **Heat colours** or `style.CLim` say
  otherwise. Each tile's title gives the group, the epochs used and the
  mean pairwise r.
- A unit whose responses do not vary has NaN correlations, and so does
  every pair in a group with fewer than 3 epochs.

## Menus

| Menu | Item | Effect |
| --- | --- | --- |
| File | **New config** (Ctrl+N) | an empty default config |
| | **Open config...** (Ctrl+O), **Open recent** | an analysis config JSON; the last 8 are listed |
| | **Save config** (Ctrl+S), **Save config as...** | writes the config JSON. The first save offers `analysis/analysis_configs` when that folder exists, else the `analysis` folder |
| | **Generate script → Compact (loads the saved config)...** | a short script that loads the saved JSON and runs the runner; unsaved changes are saved first (it asks) |
| | **Generate script → Standalone (every setting written out)...** | a script that needs no config file and never uses the runner ([Scripts](EphysAnalysis.md#scripts)) |
| | **Open pipeline app** | launches `EphysPipelineApp` |
| | **Close** | asks about unsaved changes, cancels a run under way, closes |
| Help | **Help for this tab** | the wiki page of this app, at the section of the tab shown (`helpURL`) |
| | **Documentation home**, **Analysis quick start**, **Analysis configs** | the wiki's Home, [Quick start](#quick-start) on this page, the page made from [EphysAnalysisConfig.md](EphysAnalysisConfig.md) |
| | **About EphysAnalysisApp** | the version and git commit of the code, the repository folder and the MATLAB release; **Copy** puts them on the clipboard |

The title shows `*` while the config has unsaved changes; closing, opening
or starting a new config asks to save them.

## Outputs

A run writes, for each ticked dataset and enabled plot:

- **Figure files**: one file per page and format in the Export folder, by
  default `<output folder>\analysis\<Name>_<plot id>.png` (and `.svg`).
  Paged grids (more units or channels than **Tiles per page**) get `_p1`,
  `_p2`, ... Each page is drawn into an invisible classic figure of the
  export size.
- **The report**, by default `<output root>\analysis\analysis_report.html`,
  over every dataset (or one per dataset). The HTML is one self-contained
  file with a contents list, each dataset's summary tables and every plot
  with its caption, parameters and links to its files; the PDF has a title
  page, a summary page per dataset and every figure as vector pages
  ([Report files](file-formats.md#report-files)).
- **A run record**, `<report folder>/analysis_runs/<runId>_<name>.json`: the
  config, the code version, the machine and the results
  ([Run records](file-formats.md#run-records)).

Each figure's caption says what it shows, e.g. *PSTH, Stim onset, first per
trial; window [-0.2 0.8] s; bins 10 ms, smooth 10 ms; trials: PairingFlag
ok; groups by Depth (n = 6, 6); 8 sorted unit(s) (su, mua).* The reports
print it under each figure.

The app never changes the pipeline's outputs or manifests. The only file
it may write beside them is the units' quality-metrics cache
(`quality_metrics.json` in the sorting folder), when a plot keeps good
units only.

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
| `PreviewMaxMB` | signal extracts larger than this (default 500 MB) are previewed only with the Preview button. Set it with `AppPrefs.setpref('EphysAnalysisApp', 'PreviewMaxMB', 1000)` before opening the app |
| `PlotSectionsCollapsed` | the plot editor's collapsed sections |

The aesthetics editor keeps two more groups: `PlotAesthetics`, your
remembered rules, one per plot kind (`psth`, `raster`, ...), and
`PlotAestheticsDialog`, its **Remember** box and where it last remembered
(`Remember`, `Scope`).

## Why is my plot skipped?

The runner's `plotSkipReason`, shown by the preview, Plan and the results:

| Reason | Cause | Fix |
| --- | --- | --- |
| disabled | the plot's **Enabled** box is off | tick it |
| no sorted units | the sorting folder holds no sorted units | sort the dataset, or associate its sorted-output folder ([Sorting](EphysPipelineApp.md#sorting)) |
| no detected spikes | the spikes file has no threshold detections | run the Spikes step ([Spikes](EphysPipelineApp.md#spikes)) |
| no LFP extract (MUA, SPIKE, AUX) | the Signals step did not write that signal | enable it in the pipeline's Signals step and run it ([Signals](EphysPipelineApp.md#signals)) |
| no paired trials | trial scope, the `Trial` line, a filter / response / trial list / group-by, an event or stop shifted by a trial parameter, or a tuning or behavior plot, on a dataset without paired trials | approve the pairing on the pipeline app's [Trials tab](EphysPipelineApp.md#trials) and write the behavior file; or align in recording scope without a selection |
| no line X | the event or stop line, or a line the raster marks, is not among the dataset's lines (in trial scope: among the lines seen in its trials) | check the line names on the Data tab |
| no trial parameter X | a group-by, shift-by, tuning, series, behavior y value or raster sort parameter the trials lack | pick one from the dataset's parameters |
| no probe map | the manifest names no probe file (probe maps only) | assign a probe on the pipeline app's [Probe tab](EphysPipelineApp.md#probe) |

A plot that is not skipped can still fail when it runs, e.g. *no Stim onset
event is left after the selection* or *none of the N events makes a usable
epoch (M with a window outside the recording)*: the message is in the
results, on the Log tab and in the report.

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
| help | `onHelp`, `helpURL` (the wiki page and anchor of each tab; `tools/wiki/test_gen_pages.py` checks that the page made from this file has them) |

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
the plot, previewed without the box, hidden for an overlay); a raster's
sort, direction, grouping and event marks reaching the plot and the
preview; **Shift by** giving a plot its own event shifted by RespLatency
(the misses left out); a behavior plot (its rows shown, the others
hidden; the y value, parameter, jitter and layout reaching the plot; its
box-plot preview); collapsing a
section; the gather / apply
round trip, keeping the fields without a control (the stop event's offset,
length and time range, trial rows) and the stop's *n*; Save As, New, reopen;
generating scripts; Validate, Plan and a run of one plot writing figures
and the report (its lines in the Log tab); the preferences remembered (the
last config, the collapsed section); closing. It keeps the app's
preferences in a temporary file (`AppPrefs`), so the user's own are never
read or changed.

<!-- wiki
## Related

- [Analysis configs](Analysis-Configs): every field of the config the app edits
- [Analysis scripting](Analysis-Scripting): the runner, generated scripts and the compute / render functions
- [Output files](Output-Files) and [Loading outputs](Loading-Outputs): what the analysis reads
- API: [EphysAnalysisApp](API-EphysAnalysisApp), [EphysAnalysisConfig](API-EphysAnalysisConfig), [EphysAnalysisRunner](API-EphysAnalysisRunner), [EphysAnalysisScript](API-EphysAnalysisScript), [Analysis functions](API-Analysis-Functions)
-->
