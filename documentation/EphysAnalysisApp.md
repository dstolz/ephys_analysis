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
3. **Plots**: pick a kind in the drop-down under the plot tree and press
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

**On another computer.** The pipeline app's **File → Copy files for the
analysis app...** copies just the files this app reads (manifest, behavior,
signals, detected spikes, sorted units, probe file) for the ticked datasets
into `<folder>\<subject>\<session>`
([details](EphysPipelineApp.md#copying-files-for-the-analysis-app)). Open
that folder here as a project root: `EphysAnalysisApp("<folder>")`.

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
| **Sequence**, **Edit...** | the events that must (or must not) follow each event above, shown as e.g. *then Trough onset*; *none* by default (`sequence`, `alignStep`: [event sequences](EphysAnalysisConfig.md#event-sequences)). **Edit...** opens the *Event sequence* window (below) |

**Event sequence window.** It starts at the panel's **Line** and **Edge**
and lists the steps after it in a table: **Then** (*followed by* or *not
followed by*), **Line**, **Edge**, **n** (the nth such event), **Within
(s)** (how long after the event before; *Inf* = any time before the next
trial), **Min / Max length (s)** (count only intervals of this length).
**Add step**, **Remove step**, **Up** and **Down** edit the list (select a
row first). **Align to** picks the epoch's event: the start, a *followed
by* step, or *the last step* (default). **Apply** checks the sequence and
keeps it; **Cancel** drops it. Each step looks for its event after the event
before it: the start, or the last *followed by* step's event. With paired
trials, no step looks past the next trial's onset. An event whose sequence
does not complete is left out, and the count on the right says how many
(*"; N the sequence did not follow"*).

To plot a PSTH around the first Trough onset after each CR trial: **Line**
*Trial*, **Edge** *offset*; **Sequence** *then Trough onset* (Edit...,
**Add step**, Line *Trough*, Edge *onset*); **Response** *CR* in the trial
selection. The trial selection goes by the trial that ended, so the epochs
are the CR trials that a Trough onset follows, each aligned to that
Trough onset.

**Epoch window** (`Defaults.Window`)

| Control | Meaning |
| --- | --- |
| **Mode** | `fixed: [t0+pre, t0+post]`, or `between: [t0+pre, stop+post]` for a period of varying length that ends at a stop event |
| **Pre (s)**, **Post (s)** | the window's edges from the event (in between mode, `post` from the stop event) |
| **Stop event**, line, edge, **Stop which**, **n**, **Stop scope** | the event that ends each epoch, the first (or chosen) one after the epoch's event. Required in between mode; in fixed mode it is still marked on PSTHs and rasters and can mask a PSTH |
| **Stop shift by**, **unit** | a trial parameter added to the stop event, from the epoch's trial: with the event at Stim onset and the stop at *RespWindow onset* shifted by *RespLatency*, each raster row marks its response and can be sorted by it |
| **Stop sequence**, **Edit...** | the events that must follow the stop line's event, in the same *Event sequence* window: the stop at *RespWindow offset* then *Trough onset* is the first Trough onset after the response window |

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
dropped for lacking the **Shift by** parameter's value or because their
**Sequence** did not follow, and the epochs
dropped for having no stop event, leaving the recording or touching an
artifact period (*"; N touch an artifact period"*), or why there are none;
a bar of epochs per group in the group colours the plots use; and the kept
trials with their group and number of epochs. **Epoch Diagram**, under
the Epoch window, opens the [epoch diagram](#epoch-diagram) for these
defaults.

A filter, response, group-by or trial scope needs paired trials: approve
the pairing on the pipeline app's [Trials tab](EphysPipelineApp.md#trials)
and write the behavior file. Without paired trials, align in recording
scope with no selection.

### Plots tab

<!-- wiki: ![Plots tab: the plot list, the editor for a PSTH and its preview](images/analysis-plots-tab.png) -->

Three columns: the plot tree, the editor of the selected plot, and the
preview.

**The plot tree.** The plots sit in a tree under groups, by plot type
unless **Group by** says otherwise. A plot reads `<id> (<source>)` under
plot-type groups and `<id> (<kind>)` under the others; disabled plots are
marked *(off)*. Within a group the plots keep the run and report order. A
group collapses under its header (which are collapsed is remembered); picking
a header leaves the plots selected as they were. **Ctrl**- or
**Shift**-click selects several plots, to edit them together
([Several plots at once](#several-plots-at-once)).

| Control | Effect |
| --- | --- |
| **Group by** | *Plot type* (default), *Source* (units, detected, LFP, ...), *Layout* (the layout drawn), *Enabled / off*, or *None* (a flat list); remembered |
| kind drop-down (its own row), **Add** | adds a plot of that kind ([Plot kinds](#plot-kinds)) with the next free id (`psth_1`, `psth_2`, ...) and selects it |
| **Remove**, **Duplicate** | removes the selected plots; copies each with a new id, right after it, and selects the copies |
| **Up**, **Down** | swaps it with its neighbour in its group (the whole list when ungrouped), which changes the run order of those two; off while several plots are selected |

**The editor.** On top: the plot's kind (with a line on what it draws),
**Enabled** (a disabled plot is kept but not run; `enabled`), **Id**
(unique; it names the exported files, `{Plot}`; `id`), **Title** (blank =
automatic, `<Kind>: <line> <edge> (<n> epochs)`; `title`), **Source**
(`source`) and **Layout** (`layout`). Then sections that collapse under
their headers (**▼** / **►**; which are collapsed is remembered):

| Section | Rows |
| --- | --- |
| Units & channels (*Channels* for a signal) | unit classes (sorted units: `su`, `mua`, `uns`, `noise`; none ticked = every class; `units.classes`), **Good units only** (sorted units: `units.quality.enabled`, the units that meet the config's good-unit criteria, [UnitSelection](EphysAnalysisConfig.md#unitselection)); **Responsive only** with the test (vs baseline, tuned, either, both, or auROC: the units the auROC calls modulated over the response window, with its own *auROC from*, window, step and bin (ms) and *Modulated if* rows, and *Unit test* for a per-unit test; [auROC](EphysAnalysisConfig.md#auroc)) and direction, the test windows (baseline and response, s from the event) and the test options (tuning parameter, correction, alpha), for spike sources (`units.response`; the settings are enabled while the box is ticked; [response statistics](EphysAnalysis.md#response-statistics)); unit ids (sorted units) or channels (detected), e.g. `3 5 8:12` (`units.ids`), max units (`units.maxUnits`), shanks (`units.shanks`), channels (spike sources: the recording channels kept, `units.channels`; signals: the extract's columns drawn, `channels`) |
| Event reference, Epoch window, Trial selection | the Alignment tab's controls, for this plot (`ref`, `window`, `selection`); **Epoch Diagram** sits under the Epoch window |
| Bins & baseline (*Baseline* without bins) | bin and smoothing (ms; smoothing is a Gaussian SD, 10 ms by default, 0 = none; `bins.BinSec`, `bins.SmoothSec`), mask after the stop event (`maskAfterStop`), **Measure** (*rate*, *count* or *probability*; `measure`), baseline mode and window (`baseline.Mode`, `baseline.Window`). Baseline *auroc* (PSTH, spike heatmap; `auroc`) adds *auROC from* (PSTH bins, each epoch) and the windows (tiled, sliding), the window and step (ms), the call window (s), *Modulated if* (95% CI as the paper, taken over the plot's units of one dataset, so it needs many of them; `populationAnalysis` pools every dataset's ([population analysis](EphysAnalysis.md#population-analysis)); a fixed threshold, a per-unit test, none) with the threshold, *Unit test* (bootstrap, ranksum, shuffle; resamples, correction, alpha) for a per-unit test, and *Calls*: **Mark them**, **Modulated units only** ([auROC](EphysAnalysisConfig.md#auroc)) |
| *Kind* options | PSTH and raster: **Sort raster by** (blank = trial order, stop latency, *event* (the latency of the sort event) or a trial parameter; `rasterSort`) and its direction (ascending or descending; `rasterSortOrder`), **Sort event** and **Sort sequence** (with *event*: the line and edge, e.g. Platform offset, and the steps that must follow it; the rows go by each epoch's latency to the first such event at or after its event, in its trial, as a stop event is found, those without one last; `rasterSortEvent`), **Raster rows by group first** (unticked: every epoch sorted as one block, each row on its group's colour; `rasterByGroup`), **Mark events** (the lines whose events are marked on each row, e.g. `Trough`, several separated by spaces or commas; onset, offset or both; every event in the window or only in the epoch's trial; `rasterEvents`) and **Mark look** (marker, size, and *auto* (a colour per line and edge) or one colour; right-click a mark to style one line's marks on its own); behavior: **Y value** (a trial parameter such as RespLatency, or *stop*: the stop event's latency, ms; `yParam`), parameter and series (`param`, `seriesParam`), **X axis** (evenly spaced or at their values; `xScale`) and **Jitter points** (points layout; `jitter`); PSTH: **Raster above each PSTH** (`withRaster`), **PSTH as** bar or line (`histStyle`), normalization (none, unit peak, group peak; `normalize`), **Filled** and its opacity (blank = automatic; `fill`, `fillAlpha`), **Stack groups** and its spacing (a row per group, labelled by value on the left and by peak rate on the right; `stack`, `stackSpacing`); tuning: parameter and series (`param`, `seriesParam`); probe map: value (`value`); heatmap: row order (*probe*, *peak*, and *modulation* with the auROC baseline; `order`); unit correlation: epoch rate (mean or peak; `metric`) and correlation (Pearson or Spearman; `correlation`) |
| Appearance (`style`) | tiles per page (`MaxTiles`), grid spacing (*loose*, *compact*, *tight*, *none*; `TileSpacing`), font size, line width, site size (probe map), y limits (blank = automatic, or two numbers such as `0 40`), group colours (*lines*: the trial selection's colours; a colormap; or one colour such as *black* or `#1f77b4`, typed in; `Colormap`), heat colours (*auto*: parula, or blueWhiteRed for unit correlations; `HeatColormap`), **Sort by** depth and / or shank (`SortDepth`, `SortShank`: units and channels top of the probe first, by shank first), **Label with** depth and / or shank (`LabelDepth`, `LabelShank`), and **Show** SEM, stop marks, legend, grid |
| Unit waveform | rasters, and PSTH and tuning grids, of spikes: **Show** (*Off*, *Mean*, *Subsample*, *Mean + subsample*) each unit's waveform on its peak channel in its tile, and how many spikes the subsample draws (a sorted unit's mean is over them); **Location** (*North-east* by default; north is the top edge), **Axis box** (an outline on a pale ground; unticked, the waveform alone) and its size (1x = a third of the tile). Sorted units' spikes are cut from the sorted `.bin` (their templates when it is not there); detections need the Spikes step's *Waveforms* option (`waveform`; [Unit waveforms](EphysAnalysisConfig.md#unit-waveforms)) |
| Text note | any plot: **Text** (a block of descriptive text; each new line is a line; blank draws nothing), **Place** (*Below*, *Above*, *Right of* or *Left of* the plot, which gives up a band for it; *Over the plot* at a corner, an edge or the center; or *At x, y*, the anchor's place across and up the plot, 0-1), **Align** (left, center, right; top, middle, bottom: how the lines line up and where the text sits in its band), **Rotation**, **Font** (*auto* = the design's, or any installed font) and size (blank = the plot's font size), **Bold**, **Italic**, **Outline**, **Colours** (text and ground; *auto* and *none* leave them to the design) and **Interpreter** (*As typed* or *TeX*). Its settings wait for some text (`note`; [Plot notes](EphysAnalysisConfig.md#plot-notes)); right-click the note in the preview to restyle it like any other part of the plot |

Each of the nine headed sections has a title colour of its own and a key. The
colours are nine steps along MATLAB's `turbo` map, in the order of the table
above (blue for Units & channels, red for Text note), each darkened, keeping
its hue, only as far as it needs to read on the header bar (a contrast ratio
of 4.5). **Ctrl+1** to **Ctrl+9** (**Cmd** on a Mac; the number pad too) go
to the section of that number: Units & channels is 1, Event
reference 2, Epoch window 3, Trial selection 4, Bins & baseline 5, the kind's
options 6, Appearance 7, Unit waveform 8 and Text note 9. The key opens the
section if it is collapsed (it stays open, and is remembered like any
other collapse), scrolls the editor to it and puts the keyboard focus on its
header, so **Tab** walks into its rows. The header names its key. Keys work
with the Plots tab showing. A section keeps its number and colour whatever
the plot shows; for one the selected plot does not show, the status bar says
so and nothing moves.

Only what the selected plot uses is shown (`syncPlotEditor`): its kind,
source and layout decide. A probe map has no event, window, selection or
baseline, and a raster no baseline; bins are for PSTHs, rasters, spike
heatmaps and unit correlations; the measure for PSTHs, rates, tuning curves
and spike heatmaps; y limits only where a rate or amplitude axis takes them
(PSTHs, rates, tuning curves, the evoked butterfly and grid); tiles only for
paged grids; grid spacing for every kind but rates; sort
and label options for every kind but probe maps; line width for PSTHs,
evoked potentials and tuning curves; group colours, legend (with its place
-- inside, or north, south, east or west of the whole grid of plots -- its
orientation and its box, on while the legend is) and SEM only
where groups are drawn as lines or bars; heat colours only for heatmaps,
probe maps and unit correlations; the unit waveform for rasters and PSTH
and tuning grids of spikes; the text note for every kind. A behavior plot reads only the trials: it
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
*Off*, the note's place, alignment, font and colours until it has text
(its x and y until *At x, y*); under the auROC baseline the step until *sliding*, the threshold
until a fixed cutoff, the resamples for ranksum, the calls without a
cutoff, and smoothing and normalization (the auROC compares the bins as
counted, on its own 0-1 scale).

**Use default**, in the header of the Event reference, Epoch window and
Trial selection sections: ticked, the section shows the Alignment tab's
values and the plot uses them. The controls stay editable: an edit gives
the plot its own values (the defaults with the edit) and unticks the box;
ticking it again goes back to the defaults. A probe map aligns to nothing,
so it has none of the three.

#### Several plots at once

Select several plots in the tree (**Ctrl**-click adds or drops one,
**Shift**-click a run of them) and the editor changes them all at once:

- **What shows**: only the rows every selected plot uses, so two PSTHs
  show the PSTH rows and a PSTH with a raster only the rows they share
  (bins, the raster sort and marks, the legend, ...). The **Id** and
  **Title** are each plot's own and are hidden. **Source** and **Layout**
  show only when the plots all offer the same ones. The waveform rows hide
  when unit-waveforms plots are mixed with other kinds. A drop-down offers
  only what all of them take.
- **The values shown** are the first plot picked, the one previewed.
- **An edit** goes to every selected plot, but only the value it changed:
  set the smoothing on two PSTHs with different bins and both get the
  smoothing while each keeps its bins. An edit in an Event reference,
  Epoch window or Trial selection section gives each plot its own: the
  values it used (its own, or the defaults) with that one value changed.
  Ticking **Use default** puts them all back on the defaults. A look
  remembered from the preview's right-click editor for "this plot" goes
  to all of them too, and so does forgetting one.
- **Telling you**: the editor's panel title counts the plots. The line
  under the kind becomes an amber banner naming them and saying that a
  change goes to all of them. An amber bar over the preview says it draws
  the first plot only.

To set a value that the plots differ on to the first plot's value, change
it and change it back: an edit is what spreads, not the value shown.
Click one plot on its own to edit it alone again.

**The preview** draws the selected plot on the active dataset through the
runner, so it is what a run exports.

| Control | Effect |
| --- | --- |
| **Active dataset** | the dataset previewed (the same one as on the other tabs) |
| **Preview** | computes now, also for a signal extract above `PreviewMaxMB`; a grid of units or channels only for the page shown. **Ctrl+click** computes every page |
| **Auto** | redraw after every edit while a preview takes under 2 s; a slower one says so (*"slow, so edits wait for Preview"*) |
| **<**, **>** | the pages of a paged grid: computes the page it goes to, or only draws it after a Ctrl+click on **Preview** |
| **Design** | the look of every plot (Default, Tufte, Journal, Night, Talk, Gray panel, and yours): picking one redraws the preview, and every other plot on screen, at once; runs draw their figures in it |
| **Save look as design...** | keeps the preview's look -- every property of every component, its ground and its group colours -- as a design of yours, and picks it |

The line under the preview names the plot, the dataset and the time taken,
or says why the plot cannot be drawn (the runner's
[skip reasons](#why-is-my-plot-skipped)) or failed. A coloured badge at
its left says where the preview is, with an icon:

| Badge | Means |
| --- | --- |
| **Computing** (amber, spinning) | the plot is being computed on the active dataset |
| **Drawing** (blue, spinning) | the result is being drawn |
| **Drawn** (green) | the preview is the plot as it is now |
| **Out of date** (amber) | the plot or the defaults changed and the preview was not redrawn (Auto is off, the last preview took 2 s or more, or the edit was on another tab): press **Preview** |
| **Press Preview** (blue) | the signal extract is larger than `PreviewMaxMB`, so it waits for **Preview** |
| **Cannot draw** (grey) | the active dataset cannot draw this plot; the line says why |
| **Failed** (red) | computing or drawing it failed; the line and the Log tab say why |
| **Cancelled** (grey) | you pressed **Cancel** on the card while it computed; auto-preview leaves it until you press **Preview** |
| **No preview** (grey) | no plot is selected, or no dataset is active |

While it computes and draws, a card in the middle of the preview says
what (*"Computing psth_1 on <dataset> ..."*) over the last plot, and the
pointer is a watch; the new plot replaces both. The spinners keep turning
while MATLAB is busy. An out-of-date preview is redrawn when you come back
to the Plots tab, if Auto is on and the preview is quick.

**Cancel a preview.** While a plot computes the card has a red **Cancel**
button. The compute checks for it between its steps and for every unit
(spikes, auROC, waveforms) or sixteenth epoch (signals), so it stops within
about one unit's work; a step that is one call (reading a signal extract,
building the epoch table) finishes first, and drawing cannot be stopped.
The panel then says the plot was cancelled, and the badge says
**Cancelled**. Closing the app while a preview computes stops it the same
way. Edits you make while it computes do not start a second preview; they
leave the one that finishes **Out of date**. A run (**Run**) is cancelled
with the Export tab's **Cancel**, as before: after the plot being drawn.

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

**Plot designs.** A design is a whole look: the ground behind the plot,
the group colours, the heat maps' colours, and fonts, axes, ticks, box,
grid, lines and marks. **Tufte** follows Edward Tufte's data-ink (an
off-white page, serif type, no box or grid, quiet axes, grey data with
muted colour); **Journal** is print-ready and colour-blind safe;
**Night** is dark; **Talk** has big type and thick lines for slides;
**Gray panel** looks like ggplot2. Pick one in the **Design** list above
the preview or the **Design** menu, or right-click any plot and use its
**Design** submenu. To make your own, style the preview as you like (the
appearance settings, **Edit aesthetics...**) and press **Save look as
design...**: the design keeps everything the preview shows, and what it
does not show (a tuning curve's marks, say, when the preview is a PSTH)
comes from the design it was drawn in. Your designs are JSON files in
your designs folder (**Design → Open my designs folder**); copy one to a
colleague, who adds it with **Import a design file...**, or keep them all
in a shared folder (**Keep my designs in...**). Your rules and the plot's
own rules still win over a design, and a plot's own group or heat colours
win over the design's. The design you pick is your preference, not part
of the config. See [Plot designs](EphysAnalysis.md#plot-designs).

### Epoch diagram

**Epoch Diagram** (under the Epoch window, in the plot editor and on the
Alignment tab) opens a window that draws how the event reference, epoch
window and trial selection cut the active dataset into epochs. It gets
the epochs from `epochTable`, as the plot does, so they are exactly the
plot's epochs. The window is not modal: it stays above the app while you
edit, and redraws on every edit, on a change of plot or of the active
dataset, and when a config is opened. From the plot editor it follows the
selected plot: its own values or the defaults, its baseline, and what it
drops (a behavior plot keeps every epoch). From the Alignment tab it shows
the defaults. It closes with the app.

Top to bottom:

| Part | What it shows |
| --- | --- |
| heading | the plot and the dataset, and whether the event, window and selection are the plot's own or the defaults |
| the rule | in words, e.g. *Time 0 is the first Stim onset in each trial. Each epoch runs from 0.2 s before it to 0.8 s after it. Trials kept: pairing ok; grouped by Depth.* |
| the count | how many epochs there are, from how many trials. It also gives how many trials the selection leaves out, and how many events are dropped and why: no stop event, outside the recording, or touching an artifact period; and how many were left out before, for lacking the **Shift by** value or because their sequence did not follow. When there are no epochs, the count is red and says why |
| **The recording** | a stretch of the recording, one row per digital line involved, each drawn as its TTL trace: **Trials** (each trial in its group's colour, or blue without groups; the ones the selection leaves out grey), the event's line (**▲ event**) and the stop event's line (**▼ stop**). With an event **Sequence**, every line of it gets a row (*· sequence*), ▲ sits on the step time 0 is aligned to, and ○ marks where the sequence starts, joined to the ▲ by a dotted line. ▲ marks the edge each event is picked at. A line in the event's group colour runs through every row at time 0. An event moved by **Offset** or **Shift by** has an arrow from its edge to time 0. The stop event is ▼ with a dotted line. Each epoch's window is shaded across the rows and drawn as a bar on the **Epochs** row, numbered `#1`, `#2`, ... as the plot numbers them. An epoch the plot drops is grey and dashed, with ✕ and the reason. Under each bar is the baseline; on the event's line, the **Time range** searched (yellow); behind everything, the artifact periods (red) and the stretches outside the recording (grey). A legend under the axes names each mark |
| **Aligned to the event** | the same epochs, one row each, on the time from their event: the window, the event's line as the epoch sees it, the stop event (▼) and the baseline, with dashed lines at *pre* and *post*. This is what the plot stacks and averages |
| **◀ Previous**, **Next ▶**, **Show** | step through the events, and set how many to draw at a time (5 by default). The axes' toolbars zoom and pan |

A value that gives no epochs is reported in red, and the lines are still
drawn, so you can see why. Examples: a fixed window with *pre* after
*post*, a line the dataset lacks, or a scope it cannot use.

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

The ten kinds of `EphysAnalysisConfig.plotKinds()`; the first layout
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
| `waveforms` (Unit waveforms) | units, detected | grid, probe | no alignment | none |

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
- **Mark sequences**, **Edit...** marks events defined by a sequence: the
  *Event sequence* window lists them (**Add sequence**, **Remove
  sequence**), each with its own start (line, edge, **which**, **scope**)
  and steps. *Trial offset then Trough onset* marks the first Trough onset
  after each trial's end on its row. Each sequence is one legend entry and
  one aesthetics component. With **Mark events** scope *trial*, a
  sequence's mark shows only on the row of the trial it started in.

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

### Unit waveforms

The units' waveforms as a plot of their own. It uses no events or trials,
only the units the Units & channels rows pick, and the **Unit waveform**
rows of the editor (**Show** is never *Off* here), with three more:

- **Amplitude** *Each unit's own scale* (each waveform fills its tile or
  glyph) or *One scale for all units* (`ampScale`: sizes compare, and the
  probe layout draws a scale bar).
- **On the probe** **Sites** (the probe's sites in grey behind the
  waveforms) and **Unit names** (`showSites`, `showNames`; probe layout only).
- Layouts: *grid*, a tile per unit, or *probe*, each unit's waveform as a
  glyph at its place on the probe map (a plot of a dataset without a probe
  map is skipped). Details: [Waveforms
  plots](EphysAnalysisConfig.md#waveforms-plots).

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
| Design | the designs | Default, the built-in designs, then yours (*(mine)*); the one chosen is ticked. Picking one redraws every plot on screen in it ([Plot designs](EphysAnalysis.md#plot-designs)) |
| | **Save the preview's look as a design...** | asks for a name and a description, saves the preview's look in your designs folder and picks it (asks before replacing one of yours) |
| | **Import a design file...** | copies a design `.json` into your designs folder and picks it |
| | **Delete one of my designs** | deletes the file of the one picked (asks first); Default is chosen if it was |
| | **Open my designs folder**, **Keep my designs in...** | opens the folder; or keeps your designs in another, such as one the lab shares |
| Help | **Help for this tab** | the wiki page of this app, at the section of the tab shown (`helpURL`) |
| | **Documentation home**, **Analysis quick start**, **Analysis configs** | the wiki's Home, [Quick start](#quick-start) on this page, the page made from [EphysAnalysisConfig.md](EphysAnalysisConfig.md) |
| | **Report an issue on GitHub...**, **Request a feature on GitHub...** | compose a GitHub issue from this session and open it prefilled ([Reporting an issue](#reporting-an-issue)) |
| | **About EphysAnalysisApp** | the version and git commit of the code, the repository folder and the MATLAB release; **Copy** puts them on the clipboard |

The title shows `*` while the config has unsaved changes; closing, opening
or starting a new config asks to save them.

## Reporting an issue

**Help → Report an issue on GitHub...** and **Help → Request a feature on
GitHub...** compose a GitHub issue from the session you are in. Both open the
same dialog as in the pipeline app ([Reporting an
issue](EphysPipelineApp.md#reporting-an-issue) there says how the buttons and
the address work): a title, a box for what happened (or what you would like
the app to do), tick boxes for what to send with it, and a preview of the
whole report exactly as it will be sent.

| Ticked | What it sends |
| --- | --- |
| System info | MATLAB release and platform, OS, compute threads, memory, GPUs, the installed toolboxes, the version of the code with its git commit, branch and whether it has uncommitted changes, and the repository folder |
| Analysis config | the working config as the controls hold it now (name, file, unsaved edits, source and its roots, how many plots and of which kinds, dataset counts, active dataset, selected tab, whether a run is going) and the whole config as JSON, written the way **Save config** writes it — **this carries your file paths** |
| Log tab | the last 60 lines of the Log tab, saying how many lines it had; a failed run's message is there |

A bug report starts with all three ticked and a feature request with only the
system info; untick anything you would rather not send. Nothing is filed until
you submit the form on GitHub.

Scripted, `app.issueReport("bug")` returns the same report (name-value
`Description`, `System`, `Config`, `Logs`, `MaxLogLines`) and
`app.issueURL("bug", title, body)` the prefilled address.

## Toolbar

Under the menu bar, the most used commands as icons, each calling the same
method as its menu item or tab button. A tool's tooltip names the menu
item's shortcut, if it has one (Ctrl, or Cmd on a Mac). In groups:

| Tool | Same as |
| --- | --- |
| New config, Open config, Save config | File (Ctrl+N, Ctrl+O, Ctrl+S) |
| Scan for datasets | the Data tab's **Scan** |
| Preview the selected plot on the active dataset | the Plots tab's **Preview**; shows the Plots tab first |
| Validate config, Plan, Run, Cancel run | the Export tab's buttons; Validate, Plan and Run show the Export tab first, where they list what they find |
| Open the last run's report, Open the last run's figure folder | the Export tab's **Open report** and **Open figure folder** |
| Open pipeline app | File → **Open pipeline app** |
| Help for this tab | Help → **Help for this tab** |

Validate, Plan and Run are off while a run goes, and Cancel run is on only
then, as on the Export tab; the report and figure-folder tools come on when
a run has written a report or figures. The icons are
`analysis/icons/toolbar/<Tag>.svg`.

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
| `PlotGroupBy` | how the plot tree groups (`kind`, `source`, `layout`, `status`, `none`) |
| `PlotGroupsCollapsed` | the plot tree's collapsed groups |

The aesthetics editor keeps two more groups: `PlotAesthetics`, your
remembered rules, one per plot kind (`psth`, `raster`, ...), and
`PlotAestheticsDialog`, its **Remember** box and where it last remembered
(`Remember`, `Scope`). The plot designs keep `PlotDesign`: the design
chosen (`Design`) and your designs folder when you chose one (`Folder`).

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
| no probe map | the manifest names no probe file and the dataset has no sort whose channel map could stand in (probe maps only) | assign a probe on the pipeline app's [Probe tab](EphysPipelineApp.md#probe) |

A plot that is not skipped can still fail when it runs, e.g. *no Stim onset
event is left after the selection* or *none of the N events makes a usable
epoch (M with a window outside the recording)*: the message is in the
results, on the Log tab and in the report.

## Where the code is

| Part | Files |
| --- | --- |
| building | `buildUI`, `buildMenus`, `buildToolbar` (its icons in `analysis/icons/toolbar`), `buildDataTab`, `buildAlignTab`, `buildPlotsTab`, `buildExportTab`, `buildLogTab`, `buildAlignControls`; the editor's collapsible sections in `private/` (`formSection`, `formRow`, `formShow`, `formLayout`) |
| config model | `gatherConfig` / `applyConfig`, `gather*` / `apply*Section`, `gatherAlignControls` / `applyAlignControls`, `gatherPlotEditor` / `applyPlotEditor`, `onConfigChanged`, `updateTitle`, `confirmDiscard` |
| plot editor | `syncPlotEditor` (what shows, what is enabled, what the drop-downs offer: `private/plotEditorChoices`), `layoutPlotEditor`, `onPlotSectionToggled`, `gotoPlotSection` and `onKeyPress` (Ctrl+1 ... Ctrl+9), `onPlotAlignEdited`, `onPlotDefaultToggled`, `applyPlotEditorDefaults` |
| several plots | `onPlotTreeSelected`, `onPlotSelected` and `selectedPlots` (the selection, the editor's plot first), `showPlotSelection` (the banner and the bar over the preview), `private/spreadPlotEdit` (an edit reaching the other plots selected, only what it changed), `rememberAesthetics` (a remembered look likewise) |
| data | `openSource`, `onScan`, `refreshDatasetsTable`, `selectDataset`, `refreshDatasetInfo` |
| previews | `refreshAlignPreview`, `refreshPreview`, `autoPreview`, `onPreviewPage`, `setPreviewState` (the badge and the busy card; its icons in `analysis/icons/status`), `onCancelPreview` |
| epoch diagram | `onShowEpochs`, `refreshEpochDiagram`; the window itself is `analysis/EpochDiagram.m` |
| plot designs | `refreshDesigns` (the Design menu and list; `PlotDesign.listen` keeps them current), `onDesignChosen`, `onSaveDesign`, `onImportDesign`, `onDeleteDesign`, `onDesignsFolder`; the designs themselves: `PlotDesign`, `analysis/designs` |
| running | `onValidate`, `onPlan`, `onRunExport`, `onCancelRun` |
| files | `onNewConfig`, `onOpenConfig`, `openConfigFile`, `onSaveConfig`, `onSaveConfigAs`, `onGenerateScript`, `loadPreferences`, `savePreferences` |
| help | `onHelp`, `helpURL` (the wiki page and anchor of each tab; `tools/wiki/test_gen_pages.py` checks that the page made from this file has them) |
| issues | `onReportIssue`, `issueReport`, `issueURL`; the dialog, the address and the system lines are `pipeline/IssueReport.m`, shared with EphysPipelineApp |

## Tests

`test_EphysAnalysisApp` builds the app headlessly on the analysis fixture
(a small synthetic project run through the pipeline) and drives it through
its methods: the five tabs; the toolbar (its tools in groups with their
icons, every menu shortcut named in a tooltip, Preview and Plan clicked
from another tab, the run and results tools following the Export tab's
buttons); the scan; opening on a list of datasets
(`Datasets=`, as the pipeline app's Tools panel does); the active dataset's
lines and parameters; grouping by Depth from the Alignment controls; adding
a PSTH and an LFP evoked potential and previewing both; the response test
(*Responsive only* and its settings reaching the plot); a PSTH's stack,
normalization, fill, opacity and group colours reaching the plot and the
stacked preview; the preview's badge (Drawn after a preview, Out of date
after an edit Auto does not redraw, the busy card gone); the preview's right-click
aesthetics editor remembering rules into the plot's config entry (the
editor itself: `test_PlotAesthetics`); the Design list and menu, picking
a design redrawing the preview without touching the config, saving the
preview's look as a design and deleting it (the designs themselves:
`test_PlotDesign`); editing the bins; an edit in a
*Use default* section giving the plot its own event or window, and ticking
it again going back; the editor showing only the rows and sections a plot
uses (y limits, heat colours, a probe map's missing alignment) and greying
out the ones its options switch off; a spike heatmap with the auROC baseline
(its settings shown and reaching the plot, its preview marked) and the auROC
response test; the Unit waveform rows (greyed out while *Off*, reaching
the plot, previewed without the box, hidden for an overlay); the epoch
diagram (opened from the plot editor with exactly the plot's epochs,
redrawn at once when *pre* is edited, every epoch dropped and saying why
when the window reaches before the recording, a window `epochTable`
refuses reported, paging, the same window showing the defaults from the
Alignment tab, closing with the app); a raster's
sort, direction, grouping and event marks reaching the plot and the
preview, and its sort by an event (**Sort event** greyed out until
*event* is picked, its line and edge reaching the plot and the preview,
kept when another sort is picked); **Shift by** giving a plot its own event shifted by RespLatency
(the misses left out); a behavior plot (its rows shown, the others
hidden; the y value, parameter, jitter and layout reaching the plot; its
box-plot preview); several plots selected at once (Ctrl-click keeping the
first picked in the editor and the preview, the banner, title and bar
saying so, only the rows they share, an edit, an event edit, *Use default*,
a sort event and a remembered look reaching each plot as changed and no further,
Duplicate and Remove taking them all); collapsing a
section; the section headers' colours (distinct, readable on the bar) and
keys, Ctrl+1 to Ctrl+9 opening a collapsed section and saying so for one the
plot does not show; the gather / apply
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
