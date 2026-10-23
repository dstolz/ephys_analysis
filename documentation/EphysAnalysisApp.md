# EphysAnalysisApp

`EphysAnalysisApp` ([source](../analysis/@EphysAnalysisApp/EphysAnalysisApp.m))
is the GUI for quick-look figures of datasets the pipeline has processed.
A *figure* puts panels of different types (a raster flush above its PSTH
above the LFP of the same unit, a heat map, a probe map, a unit-by-unit
correlation matrix, ...) on a grid for one unit, a channel or the dataset.
Every figure can be aligned to any digital line, and trials can be filtered
and grouped by Epsych2 parameters such as `Depth`. The app previews a figure
one observation at a time (`figureCompute` and `renderFigure`), then
generates it for every observation of the ticked datasets, or once across
several datasets (a color per session or per subject, or a mean with an
error band across sessions): the [Figures tab](#figures-tab). The figures are
written as PNG / EPS / SVG / PDF files and collected into an HTML and / or
PDF report.

The app edits one [`EphysAnalysisConfig`](EphysAnalysisConfig.md) (saved as
JSON) and draws it with an `EphysAnalysisRunner`
([Analysis](EphysAnalysis.md#runner)). It computes nothing itself: its
previews, plans and runs are the runner's `computeFigure`,
`computeSessionFigure`, `plan` and `run`, so a preview is what a run or a
[generated script](EphysAnalysis.md#scripts) draws. Its
[spectral panels](EphysAnalysisConfig.md#spectral-panels) (power spectrum,
spectrogram, coherence) compute multitaper spectra and coherence of signals and
spike trains straight from the extracts and units, with no Chronux file. For anything further, Chronux and FieldTrip take the files the
pipeline's [Export step](EphysPipelineApp.md#export) writes. There are five
tabs: Data, Alignment, Figures, Export and Log.

<!-- wiki: More on those exports: [Analysis toolbox exports](Analysis-Toolbox-Exports). -->

<!-- wiki: ![The analysis app, Figures tab, previewing a unit's raster over its PSTH grouped by Depth](images/analysis-figures-tab.png) -->

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
   group, and the epoch diagram beside it draws how they are cut.
3. **Figures**: press **Add** under the figure tree: a blank figure, and the
   **New panel** window to pick its first panel (a *Raster*, say, following
   the observed unit). **New panel...** in the Panels section puts another
   panel next to the selected one (a *PSTH* **Below** the raster, an LFP
   trace of the unit's channel below that), the figure's id following what
   it holds (*Raster+PSTH+Continuous units+LFP*), and a
   panel's rows change what it draws: a firing rate panel over the response
   window (`RespWindow` onset → offset, set in the panel's own event
   reference and epoch window), a tuning curve (parameter `Depth`), a heat
   map, a probe map or a unit correlation. The preview draws the
   observation picked over it on the active dataset.
4. **Export**: tick png / svg / pdf, press **Run**, then **Open report**.
5. **File → Save config** keeps the setup; **File → Generate script →
   Standalone** writes a script that draws the same figures without the
   app.

A figure the dataset cannot draw says why instead of drawing (no sorted
units, no LFP extract, no paired trials, ...): see
[Why is my figure skipped?](#why-is-my-figure-skipped)

## Launching

| Call | Opens |
| --- | --- |
| `EphysAnalysisApp` | the last config (preference `LastConfigFile`), else the defaults |
| `EphysAnalysisApp("D:\EPHYS")` | the last config with its source switched to project mode on that root, scanned (with no last config, a new quick look config) |
| `EphysAnalysisApp("D:\EPHYS", OutputRoot="E:\out")` | the same with the project's output root. `NamePattern=` and `Recordings=` (`"concatenate"`, `"separate"`, `"single"`) are taken too |
| `EphysAnalysisApp("D:\EPHYS", Datasets=["subj1/day1" "subj1/day2"])` | the same with only those datasets selected (root-relative keys; `Source.Selection = "list"`): every dataset is listed, but only these are ticked to run, and the first of them is active; one dataset names the config. The pipeline app's Tools panel opens it this way |
| `EphysAnalysisApp("D:\out\subj1_day1")` | a folder holding `<Name>_manifest.json` or `<Name>_extract*.mat` is one dataset's output folder: the last config with its source switched to folders mode with that folder, scanned (with no last config, a new quick look config) |
| `EphysAnalysisApp("am.json")` | that analysis config as it is (its source scanned when it exists) |
| `app = EphysAnalysisApp(...)` | the same, keeping a handle |
| `EphysAnalysisApp(..., Splash=false)` | the same without the startup window |

The detection is in `openSource`. Opened on a folder, the app takes its
last config again (preference `LastConfigFile`), its figures, defaults and
export settings as they are, and puts the folder's source in place of the
config's own: the title marks the config unsaved and the status bar says
so, since **Save** would write the new source to that file (**Save As**
leaves the file as it was). With no last config, or one that cannot be
read (the status bar and the Log say why), it makes a new config named
after the folder (`<folder> quick look`, or after the one dataset of
`Datasets=`) with no figures yet.

**Startup window.** While the app starts, a small window in the middle of
the screen shows its name, its version, the step under way (each tab
built, the preferences, the config opened, the scan, the first dataset
loaded) and a progress bar; the main window is built hidden and shows when
it is ready, and alerts raised meanwhile show on it then. `Splash=false`
starts without the small window, the default under `matlab -batch`. Most of
a start is MATLAB making the window's components (the Figures tab holds
three quarters of them), so the hidden window is laid out once, when it
shows, with the Data tab's contents alone: each other tab is laid out the
first time it is shown (the Figures tab takes a few seconds then), and the
Alignment tab's epoch count and diagram are drawn then too. A
config's project root on a network share that does not answer within 5 s
is not scanned when the config opens (the status bar says so): **Scan** it
once it can be reached.

**From the pipeline app.** Its **File → Open analysis app...** opens this
app on the project root, output root, name pattern and Open Ephys recording
mode set there (its Tools panel, on the datasets chosen), with this app's
last config and figures as above; without a project root, on the last
config as it is.
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
| **★** | the dataset is starred: tick it to star the dataset, clear it to unstar it ([Favorites](#favorites)). Written at once beside the data, never into the config |
| **✎** | the dataset has a note. Click it to make the dataset active and open its note in the notepad ([Notes](#notes)) |
| **Name**, **Key** | the dataset's name and key (the root-relative folder, or the output folder in folders mode) |
| **Subject**, **Date** | the dataset's `SubjectID` from the name pattern, and the day it was recorded (a project's recording start, else the date in the name) |
| **LFP**, **MUA**, **SPIKE**, **AUX** | ✓ when that signal's extract exists |
| **Units**, **Detected** | the sorting folder holds sorted units; the spikes file holds threshold detections |
| **Behavior** | `<Name>_behavior.mat` exists |
| **Trials**, **Pairing**, **Duration (s)** | once the dataset has been loaded (making it active loads it): the number of trials, the pairing (its recorded status, `paired`, or `not paired`) and the recording's length |

Click a row to make it the **active dataset**: the Alignment and Figures tabs
preview it. After a scan the first ticked dataset is active. Click a header to
sort the rows (by Subject or Date, say); the sort is kept as the table is filled
again, for a tick or a new active dataset, until the app closes, and right-click
→ **Clear sort** returns to the scan order. Ticks and clicks go to the row's own
dataset in any order. Every other table in the app (the active dataset's
inventory, lines, parameters and units, the alignment's trials, the issues and
the results) sorts on a header click too.

**Active dataset**, on the right:

- the size of each signal extract and the recording's length; an extract
  larger than `PreviewMaxMB` (500 MB by default) is read for a preview only
  when **Preview** is pressed on the Figures tab;
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
trial selection that every figure uses unless it sets its own on the Figures
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

To draw a PSTH around the first Trough onset after each CR trial: **Line**
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
| **Response** | keep the trials that are any of the selected response words, in a list (Ctrl or Shift selects several; none selected keeps every response) (`Hit`, `Miss`, `CR`, `FA`, `Abort`, `Reward`, `Punish`, `NoResponse`, `Response`: bits of `RespCode`) |
| **Pairing** | keep the trials with the selected `PairingFlag` values, in a list: `ok` (default), `partial`, `cut`, `unpaired`; none selected keeps every flag |
| **Group by**, **and** | up to two trial parameters: one group per value, or pair of values |
| **Order**, **Max groups** | the groups' order (`ascending`, `descending`, `appearance`); more groups than the maximum (12 by default) is an error |
| **Artifacts**: **Exclude epochs**, **at least (s)** | ticked (default): leave out the epochs whose window (or a panel's baseline) touches an artifact period, the stretches the Signals step erased; unticked: keep them (their signal is the erased stretch). Only periods at least **at least (s)** long count (0 = every one); the [epoch diagram](#epoch-diagram) draws the shorter ones paler |

The stop event's offset, interval length and time range, and the selection's
explicit trial rows, have no controls: they keep the config's values through
every edit.

On the right, for the active dataset (**Active dataset** picks another, the
**☆** beside it stars it, the **✎** opens its [note](#notes), and
**Favorites** under it goes to any [star](#favorites)):
*"N epochs from M of T trials in G groups (scope)"*, with the events
dropped for lacking the **Shift by** parameter's value or because their
**Sequence** did not follow, and the epochs
dropped for having no stop event, leaving the recording or touching an
artifact period (*"; N touch an artifact period"*), or why there are none;
a bar of epochs per group in the group colors the figures use, its count on
top of it; and the kept trials with their group and number of epochs.
**Show the epochs Pairing and Artifacts exclude** (off by default) counts
the epochs of every pairing flag, with or without an artifact, and stacks
on each group's kept epochs those the **Pairing** selection leaves out (gray) and
those an artifact period excludes (red), with a legend; the count on top is
then the whole bar. Right of them, the
[epoch diagram](#epoch-diagram) draws how these defaults cut the active
dataset into epochs, and follows every edit.

A filter, response, group-by or trial scope needs paired trials: approve
the pairing on the pipeline app's [Trials tab](EphysPipelineApp.md#trials)
and write the behavior file. Without paired trials, align in recording
scope with no selection.

### Figures tab

A *figure* is a grid of panels of different types (a raster, a PSTH, a
signal trace, a probe map, ...) designed for **one observation**, a sorted
unit, a channel of a signal or the dataset, and drawn for it: each panel
holds *layers* of data that follow the observation or name fixed items, so a
raster flush above its PSTH above the LFP of the same unit's channel is one
figure. The tab edits the config's `Figures` list
([every field and the model](EphysAnalysisConfig.md#figures)) and previews
the figure for the observation you pick, reading only that unit's spikes or
that channel's column, so an edit redraws quickly. A figure with no panel (a
new one, before its first panel) previews without failing, so panels can be
added to it one by one. The three spectral panel types (*Power spectrum*, *Spectrogram* and
*Coherence*) call Chronux, which must be on the MATLAB path
(`toolboxes/chronux`); without it the panel says
*Chronux is not on the path* and the rest of the figure still draws
([Spectral panels](EphysAnalysisConfig.md#spectral-panels)).

The preview draws one observation. The Export tab's **Plan** and **Run**
draw every enabled figure for every observation of every ticked dataset, a
page each, exported and reported ([Export tab](#export-tab)), and so do the
generated scripts and the pipeline's Analysis step; Validate counts an enabled
figure as something to run, so a config that holds figures and nothing else is
accepted, and checks the figures themselves
([Validating figures](EphysAnalysisConfig.md#validating-figures)).
**File → Generate selected figure** (**Ctrl+G**) draws the selected figure
alone, from here (below), and the tab's **Redraw All** brings every enabled
figure's preview up to date.
A figure can be drawn **across several datasets** instead of once per
dataset: tick **Across sessions** in its Sessions section ([below](#sessions-in-the-figures-tab)),
and Generate selected figure and Run draw it once over the ticked (or listed) datasets, a
page per matched site, cell or channel, and the preview does the same.
**File → Save config**
keeps the figures, and **Help → Help for this tab** opens this section.

Three columns: the figures, the editor of the selected one, and the preview.

**The figure tree.** The figures are a tree under groups, headed *Figures (ticked = enabled)*. **Group by** (below) sorts
them by what each is drawn for, by enabled or off, or not at all. A group
header reads `Per unit  (2)` (*Per unit*, *Per channel* or *Per dataset*, the
kind of data its Observe row names, with a figure across sessions grouped by its
observation too; or *Enabled* and *Off*, with the number of figures in it);
only groups with a figure are listed, in that order. A figure reads
`<id>  (<n> panels)`, with `, per <kind>` added unless the groups are by what
the figures observe (the group says it) and *(off)* after it for a disabled
figure unless the groups are by status. Within a group the figures keep the
run order. A group collapses under its header (which are collapsed is
remembered), and the selected figure's group is always open: it opens when the
selection moves to a figure in it and when the tree is rebuilt. A gray hint
under the buttons says that File → Generate selected figure draws the figure for each observation and
that Run (Export tab) draws the enabled ones.

Every node has a check box, ticked while the figure is **Enabled** (`enabled`)
and, for a group, ticked when all its figures are, half-filled when some are,
empty when none. **Click the box** to tick or untick a figure; a click on a
group's box ticks all its figures, or unticks them when all are ticked. A click
anywhere else on a node only selects it: a figure opens in the editor, and a
group's header leaves the selected figure selected. (The boxes are icons: MATLAB's check-box tree selects one node at a time, and the
click's place is tested against where MATLAB draws a node's icon.) A change of
the box is a change of `enabled`: the editor's **Enabled** box follows, the
status bar says *"2 of 3 figures enabled."*, and the preview is not redrawn,
since being enabled changes the run, not what a figure draws. Under **Group by**
*Enabled / off* the figure moves to the other group.

The tree drives the preview: the figure selected in it is the one the editor
and the preview show, and a figure selected any other way (a favorite, **Go to
setting**, Undo or Redo, Add, Duplicate, Remove, a config opened) is selected in
the tree. The nodes are marked (`markFigureTree`): the figure shown is **bold**;
a figure whose kept preview is out of date is *amber and italic* (its figure,
the defaults it uses, the active dataset or its observation changed since it was
drawn, or it waits for **Preview**); one whose preview failed is red; one not
drawn is gray (not shown yet, dropped from the kept previews, or the dataset
cannot draw it). An edit of one figure marks only that figure; another dataset,
or a scan, marks every figure, and the dataset chosen back makes the previews
drawn on it current again.

**Each figure keeps its preview.** The preview has a container per figure
(`syncFigureView`), so a figure you switch away from keeps its drawing, badge,
status line and *Figure:* pick, and switching back shows it at once, without
computing or drawing it again, unless it is out of date: then it is drawn as
after an edit (at once with **Auto**, else marked *Out of date*). The eight
figures shown last keep theirs (`EphysAnalysisApp.MaxFigureViews`, a constant:
each holds its computed result and its graphics); a figure beyond them is drawn
again when it is shown. Removing a figure frees its container, and another
config drops them all. Choosing a design redraws every kept preview in it (no
computing). The editor too comes back as the figure left it: which sections and
supersections are open or collapsed, how far it is scrolled, and the selected
panel and layer (`saveFigureEditorState`). A figure shown for the first time
gets its first panel and the sections as they are; the collapsed sections the
app starts with are still the preferences `FigureSectionsCollapsed` and
`FigureSupersectionsCollapsed`, and the editor states last until the app
closes. The observation picker comes back as the figure left it as well (its
list, count line and pick, `keepFigurePicker`): the list is not made again
unless what it is made from changed (the figure's observe block, event, trial
selection or sorting, the dataset or the ticked ones). A scan, another config
or a star or note set or cleared forgets the kept lists, so each is made again
when its figure is shown. The editor sets only what changes between the two
figures (its rows' places, lists and heights are compared first), so a switch
is mostly the rows that differ. While a preview computes, selecting another
figure shows it in the editor at once and in the preview once the running one
is drawn.

| Control | Effect |
| --- | --- |
| **Group by** | how the tree sorts the figures: *What it observes* (the default: per unit, per channel, per dataset), *Enabled / off* or *None* (one flat list). The choice is remembered (`FigureGroupBy`), and the selected figure stays selected |
| **All**, **None**, **Invert** | above the tree: tick every figure (enable them all), untick every figure (they stay in the config) or flip each. They act on every figure, whatever the groups; the status bar says how many are enabled |
| **Add** | adds a blank figure (one empty cell, observing the dataset) with an automatic id (*Blank dataset*), selects it and opens the [New panel window](#the-new-panel-window) on it: **OK** adds its first panel, which its id and its **Observe** choice then follow (*PSTH units*); **Cancel** leaves it blank, to fill with **New panel...** later. The app offers no template (scripts still have `addFigure`'s, [EphysAnalysisConfig](EphysAnalysisConfig.md#figure-ids)) |
| **Remove**, **Duplicate** | removes the selected figure; copies it, with its remembered looks and its observation, right after it as *&lt;id&gt; (2)* (the next free number: *PSTH units (3)* when *(2)* is taken), and selects the copy. An automatic id copies as automatic (the copy's id follows its own panels from then on), an id of your own as your own; a *(n)* the id ends in is not doubled (*unit_card (2)* copies as *unit_card (3)*) |
| **Up**, **Down** | swaps it with its neighbor in its group of the tree (the whole list when ungrouped), which shows as one step and moves it in the config's run order; a figure of another group between the two keeps its place. Off for a figure with no neighbor in its group |
| **Copy settings...** | under the list, on with a figure selected: copies a figure's settings, one by one, onto other figures (one or many) or into a plot design ([Copy settings to other figures or a design](#copy-settings-to-other-figures-or-a-design)). Each figure copied onto keeps its id (an automatic one follows), title and enabled, and every setting left unticked |

**The editor.** On top, always open: **Id** with **auto** beside it (unique among figures; it names the figure's files, `{Plot}`; `id`, `autoId`; below), **Title** (blank = automatic: the id, the
observation, the event and the epoch count; a title of your own names no
observation, so the top-left panel names it; `title`), **Size** (the page the figure
is exported on, below; `size`), **Enabled** (a
disabled figure stays in the config and is still drawn by the preview and by
**Generate selected figure**, but the Export tab's **Run** and **Redraw All** skip it; `enabled`) and a gray summary (*"2 rows x 1
column, 2 panels; per unit"*).

**The id.** A new figure's id is *automatic* (**auto** ticked, the id in
gray): it names the figure's active panel types in grid order and the data it
draws, *Raster+PSTH units*, *Continuous LFP*, *Raster+PSTH+Continuous
units+LFP* ([the rule](EphysAnalysisConfig.md#figure-ids)), and follows every
edit of them: a panel added, removed or of another type, a layer's source, the
**Observe** choice. A second figure of the same content gets *(2)*, a third
*(3)*. Typing an id makes it yours (**auto** unticks, the id turns black): it
stays whatever the panels; ticking **auto** goes back to the automatic id
(the status bar names it). A typed id another figure has, or a blank one, is
refused. What refers to a figure by its id follows an automatic rename: the
observation it last showed, the right-click editor of its preview or of its
**Open in window** figure (looks remembered there reach it), and the Spacing
window opened on it; runs, the Export tab, the pipeline's Analysis step and
**Copy settings...** read the ids when they run, and the tree and the editor hold
the figure itself, so none of them can point at a stale id. The figure's file
names (`{Plot}`) follow the id.

Then sections that collapse under their
colored headers (**▼** / **►**), grouped under three **supersections**, each a
dark full-width header in capitals that collapses all its sections at once:
**FIGURE** (what the figure is drawn for and how its epochs are cut, and its
grid), **PANEL** (the selected panel; its header names it, *PANEL  psth_1
(PSTH)*, or says none is picked) and **LOOK**. The sections, in this order,
with the key of each in brackets:

| Section | Rows |
| --- | --- |
| **FIGURE** (Alt+1) | the sections below, down to Panels, indented under it |
| Observations (1) | what the figure is drawn for. **Observe** (`observe.data`): *Sorted units* (each sorted unit), *Detected spikes (per channel)* (each channel's threshold detections), *LFP*, *MUA*, *SPIKE*, *AUX* (each channel of that extract) or *The dataset* (one figure per dataset). The data types the active dataset holds come first, then *The dataset*, then the ones it lacks, each marked *(not in subj1_day1)*: those can still be picked (the figure is meant for other datasets too), and switching datasets never changes a figure's choice. A new figure (**Add**: blank) observes the dataset; a figure that observes the dataset and gets its first layer that follows the observation (its first panel from the New panel window, a heat map made a PSTH) observes what that layer reads from then on (when the active dataset holds it, else the first type the dataset holds, in the order above), since a following layer has nothing to follow in a dataset figure (the status bar says so; *The dataset* picked while layers already follow is kept). **Starred only** (`observe.starred`, under it, for every kind) keeps only what is [starred](#favorites): the starred units of the sort in use, the starred channels (a detection channel by its channel) or, for a figure of the dataset, a starred dataset; the picker, **<** **>**, Generate and Export runs then draw just the favorites, and a star set or cleared lists them again at once. Across sessions it keeps a matched observation starred on any of its sessions, still drawn on every session. The rows under it follow the choice. For sorted units: unit classes, **Unit ids**, **Good units only**, **Responsive only** with its test (*vs baseline*, *tuned*, *either*, *both* or *auROC*), direction, windows and options, **Max units**, **Shanks** and **Channels**: the unit filter ([UnitSelection](EphysAnalysisConfig.md#unitselection)), the response test run over the figure's epochs (`observe.units`); for detected spikes the same rows without classes and quality. For a signal: **Channels** (the extract's columns, blank = all). For the dataset: nothing more. **Per trial group (one figure per group)** (`observe.perGroup`; hidden for a figure across sessions, whose trial groups follow its **Trial groups** row) draws each observation once per trial group of the figure's trial selection (its **Group by**): the picker lists every observation and group (the observation's label, a middle dot, the group's label), and each figure keeps that group's epochs only, with the group in its title, its caption and its file name (`{Group}`); it needs a **Group by**, and a panel with a trial selection of its own keeps its own groups ([One figure per trial group](EphysAnalysisConfig.md#panel-types)). A count line ends it (*"14 units on subj1_day1."*; with Per trial group, *"14 units x 3 trial groups on subj1_day1."*; with Starred only, *"3 units on subj1_day1, starred only."*, or *"subj1_day1 is not starred: no figure (Starred only)."* for a figure of the dataset) |
| Event reference (2), Epoch window (3), Trial selection (4) | the figure's alignment: the [Alignment tab](#alignment-tab)'s controls, for this figure (`ref`, `window`, `selection`), each with **Use default** in its header; **Epoch Diagram** sits under the Epoch window. Hidden when every panel of the figure is of a type that is not aligned to events (probe map, unit waveforms) |
| Sessions | **Across sessions**, and with it ticked which datasets, how the sessions are colored, the error band, how the observed unit is matched, the minimum sessions and the trial groups: the figure drawn once over several datasets instead of once per dataset ([Sessions in the Figures tab](#sessions-in-the-figures-tab)); no key; collapsed until opened. Its place in the Figure supersection, above the Panels section: it decides what the figure is drawn over |
| Panels (5) | the schematic of the grid, **New panel...** (the [New panel window](#the-new-panel-window)), the selected panel's **Row span**, **Column span**, **Row height**, **Column width**, **Panel size** and **Align in cell**, **Spacing** with **Spacing...**, **Remove panel** and **Move** (below) |
| **PANEL** (Alt+2) | the sections below, down to Overlays: the selected panel's. Its header names the panel and its type |
| Selected panel (6) | **Type** (a change starts the panel afresh: below), **Title** (blank = none), **Box** (*auto (the design's)*, *on* or *off*: the frame around the panel's axes; *on* and *off* win over the design, the remembered looks and the figure's own rules; `box`), **X axis** and **Y axis** (every type: the axis' label, blank = the type's own, and its side, *bottom* or *top*, *left* or *right*; `xLabel`, `yLabel`, `xSide`, `ySide`; the y side grayed out on a stacked line panel (PSTH, continuous, spectrum, coherence, tuning), which has a y axis on each side; a stack of time panels with its x axes on top tells the time once, at its top; the sides, not the label texts, go to every panel with Options' **Apply to all panels**, or from the right-click menu's **Move every panel's X axis to top** (*Axis labels*, below)) and **Group shown** (heat map, unit correlation and spectrogram panels, and a coherence panel drawn over time: which of the figure's trial groups they draw, 1 = the first; `options.group`; a heat map of trials and a stacked panel draw every group, so the row hides) |
| Panel alignment (7) | the selected panel's own event reference and epoch window (an aligned type only), with **Same as the figure** in the header, and the panel's trial selection, the [Trial selection](#alignment-tab) rows under the **Trial selection as the figure** box (an aligned type only). **Apply to all panels** and **Re-link all panels** (below) |
| Layers (8) | the selected panel's layers: the list with **Add** (a source the type draws), **Remove**, **Up** and **Down**, and the rows of the layer picked (below) |
| Options (9) | all of the panel's own options: its type's rows, under the type's name (*Raster options*, *PSTH options*, ...; below), and **Apply to all panels** |
| Waveform | the selected panel's unit waveform (`options.waveform`), titled *Waveform on psth_1*: the inset of a raster, PSTH, firing rate or tuning curve panel, or the drawing of a unit waveforms panel ([The Waveform section](#the-waveform-section), below). Shown for every panel type whose layers may be spikes; on a heat map, probe map, unit correlation or spectral panel it holds only a note saying why that type draws no waveform. No key |
| Text note (0) | the selected panel's `note`, titled *Text note on psth_1*: a block of descriptive text on the panel ([Panel notes](EphysAnalysisConfig.md#panel-notes)). **Text** (a new line starts a new line; blank draws nothing), **Place** (*Below*, *Above*, *Right of* or *Left of the panel*, which give up a band of the panel's tile beside its axes; nine places *Over the panel*, in its axes; or *At x, y*), **At x, y** (0-1 across and up the panel's axes; on with *At x, y*), **Align** (across and up), **Rotation**, **Font** and its size, **Style** (*Bold*, *Italic*, *Outline*), **Colors** (text and ground) and **Interpreter** (*As typed* or *TeX*). Every row but the text is grayed out until the text has words. In the preview a note over the panel is a component the right-click editor lists; one in a band beside it is not (its looks still apply, and the figure's rules still reach it). Collapsed until opened |
| Overlays | the selected panel's `overlays`, titled *Overlays (2) on psth_1* once it has some ([Panel overlays](EphysAnalysisConfig.md#panel-overlays)). A list of the panel's lines and semitransparent patches, with **Add line**, **Add patch**, **Duplicate** (the picked one, look and all, named *name copy*) and **Remove**. A new or duplicated overlay gets a name no overlay of the figure has, on this panel or any other (*Line 1*, *Line 2*, ...: a look remembered for a name reaches every overlay of that name). The rows of the one picked: **Name** and **Enabled**; **Draw** (a vertical or horizontal line, a patch between two x or two y values); **At** or **From / to**; the **Layer** (*Over* or *Under the data*); a line's **Color** and opacity, or a patch's **Fill** color and opacity and **Outline**; the **Line** style and width. There is no *Show on* row: a panel's overlays are all drawn on its own axes, in its axis' units. No key; collapsed until opened |
| **LOOK** (Alt+3) | the two sections below: how the figure looks |
| Appearance | the figure's `style` (below); no key; collapsed until opened |
| Looks | how many looks are remembered for the figure (*"1 remembered look(s); right-click the preview to edit."*) and **Forget**, which drops them and redraws; no key; collapsed until opened |

Each of the fifteen headed sections has a title color of its own (steps along
`turbo`; Waveform's lies between Options' and Text note's) and ten a key: **Ctrl+1** to **Ctrl+9** and **Ctrl+0**
(**Cmd** on a Mac; the number pad too) go to the section of that number, in
the order above: Observations is 1, Event reference 2, Epoch window 3, Trial
selection 4, Panels 5, Selected panel 6, Panel alignment 7, Layers 8, Options 9
and Text note 0. Sessions, Waveform, Overlays, Appearance and Looks have no key (the
search finds them). The key opens the section, and its supersection, if
collapsed, scrolls the editor to it and puts the keyboard focus on its
header. **Alt+1**, **Alt+2** and **Alt+3** (**Option** on a Mac) go the same
way to the FIGURE, PANEL and LOOK supersections. A click on a supersection's
header (or Space or Enter on it) collapses or expands every section under it;
each section keeps its own state inside. Keys work with the Figures tab
showing; for a section the figure does not show (no panel is picked, say) the
status bar says so and nothing moves. Which sections and supersections are
collapsed is remembered.

**Finding a setting.** Over the editor, **Find a setting by name** (**Ctrl+F**
goes there) searches the editor's rows as you type: each word typed, in any
order and case, must be part of a row's label, its other words (a check box's
text, *opacity*, *resamples*) or its controls' tooltips; the supersections and
the sections' titles are found too, so *layers* finds the Layers section. The
matches are listed under the field as *Supersection > Section > Row*, the
section named as its header reads now (*Panel > PSTH options > Bin (ms)*): first
the labels that start with the text as a word (*bin* lists **Bin (ms)** before
**Binding**), then those that start with it, then labels with every word, then
tooltip matches; within each, what the figure shows before what it hides, in
the editor's order (at most 40; the status bar counts them all). **Enter** goes
to the first match (**Down** and **Up** pick another while you type; **Tab**
moves into the list, where the arrows show each match in the editor and
**Enter** goes there), and so does a click on a match: its supersection and
section open, the editor scrolls to it, its control takes the keyboard focus
and its label is highlighted in yellow for a moment; the status bar names it,
adding *grayed out* when another setting switches it off. A row the figure,
the selected panel or the picked layer does not show is listed too, but going
there leaves the editor as it is and the status bar says why: *Bin (ms) is an
option of PSTH, heat map and unit correlation panels, not of raster panels:
pick such a panel.*, *Unit classes is for sorted units: pick Sorted units in
Observe.*, *Marker is for an events layer drawn as marks.*, or for a panel's
section with no panel picked *... is a panel's: pick a panel in the schematic
(Ctrl+] steps through them).* **Escape** clears the search. The list is made
from the rows as the editor builds them, so a new row is found without more
work.

**Keyboard.** The Figures tab can be worked with the keyboard alone. **Tab**
and **Shift+Tab** move through the controls top to bottom: the figure list and
its buttons, the search field, then the editor in its order (the supersections'
and sections' headers among them; what is collapsed or hidden is skipped), then
the preview's controls. **F6** and **Shift+F6** jump to the next or previous
column (the figure list, the editor, the preview's Observation drop-down); the
section and supersection keys, **Ctrl+F**, and the panel and observation keys
below move within them. The **?** button right of the search field (also
**Help → Figures tab keys**) lists every key in a window that stays on top;
**Escape** or **Close** closes it.

| Key | Does |
| --- | --- |
| **Alt+1**, **Alt+2**, **Alt+3** | the FIGURE, PANEL or LOOK supersection |
| **Ctrl+1** ... **Ctrl+9**, **Ctrl+0** | a section (above) |
| **Ctrl+F** | the search field; then **Enter**, **Down** / **Up**, **Escape** |
| **F6**, **Shift+F6** | the next or previous column |
| **Ctrl+]**, **Ctrl+[** | the next or previous panel of the figure, in its panel order (round at the ends) |
| **Ctrl+Alt+arrows** | the panel above, below, left or right of the selected one: the nearest wholly on that side whose columns (rows) overlap it, the one overlapping most when several are as near; with none there the status bar says so (*No panel below continuous_1.*). A graphics driver that turns the screen with Ctrl+Alt+arrows takes these keys: use Ctrl+] and Ctrl+[ |
| **Page Up**, **Page Down** | the previous or next observation (**<**, **>**) |
| **Ctrl+P**, **Ctrl+R** | **Preview**, **Redraw All** |
| **Ctrl+G** | **File → Generate selected figure** (the menu's accelerator, on any tab) |
| **Ctrl+U** | **Unit report** |
| **Ctrl+T** | **Auto**, ticked or unticked |
| **Ctrl+K** | **Export preview** |
| **Ctrl+E**, **Ctrl+W** | **Export code**, **Open in window** |
| **Escape** | cancels a panel drag in the schematic; clears the search |
| **Ctrl+Z** | undo the last edit of the figures (**Edit → Undo**: [Undo and redo](#undo-and-redo)) |
| **Ctrl+Y**, **Ctrl+Shift+Z** | redo the last edit undone |
| **Ctrl** held while you edit | the edit is made, then **Apply to figures** offers it to the other figures ([Apply a change to other figures](#apply-a-change-to-other-figures)) |
| **Ctrl+Shift+A** | the same for the last edit (**Edit → Apply last change to figures...**) |

A panel picked with the keys is picked as a click in the schematic picks it:
the editor shows it, and the preview outlines it (below) without computing or
drawing the figure again.

**What shows.** Only what the figure, the selected panel and the picked layer
use is shown (`syncFigureEditor`). The Observations rows follow the data
the figure observes; the sections from Selected panel to Options, and Waveform, Text note and
Overlays, need a panel picked (Waveform one whose type draws spikes); Panel alignment is grayed out, with a note, for a type that is not
aligned to events, and its trial selection rows are too while **Trial selection
as the figure** is ticked; a layer's rows follow its source and binding; the
Options rows follow the panel's type. A section left with no row is hidden.
A linked panel's Panel alignment rows are locked and show the figure's
values while **Same as the figure** is ticked. The Options rows are always the
panel's own.
Rows that another option switches off stay in place, grayed out: the binding
until the layer's source and the panel's type let it follow the observation,
*Draw as* on an event-trace panel (which draws its lines its own way; elsewhere
it offers a spike train only on a raster, PSTH or heat map), a span's line
until *Draw as* is a line from onset to offset, an event-trace panel's bar
outline until bars, its level line until a line, its group bands until a
sub-row per epoch and its baseline's look until **Draw** is ticked, the
response test's rows until *Responsive only*, the baseline window until a
baseline mode, the fill's opacity until *Filled*, the sort event until the
sort is *event*, the jitter until the *points* display, the waveform's rows
until its mode is not *Off*, a unit correlation's bins until its *peak*
rate, the mask until the window has a stop event, the stack spacing while
**Stack** is *Off*, the auROC
step until *sliding* windows, its threshold until the *fixed threshold* cutoff,
its resamples until the test is not *ranksum*, its **Calls** boxes until a
cutoff, and the error and legend rows until their boxes. The auROC rows show only
with the *auroc* baseline (the **Unit test** row only with the *per-unit test*
cutoff), in a PSTH's or heat map's Options.

**The arrangement.** The schematic in the Panels section draws the grid
in proportion (each row's relative height, each column's relative width, and
the gaps between them as **Spacing** sets them, px against the export figure's
size, at least a sliver): a box per panel at its own size in its cell and where
**Align in cell** puts it there, tinted by its type and naming it and how many layers it has;
the selected panel has a dark edge and its id; cells no panel covers are
dotted. Click a box to pick the panel; the sections from Selected panel to Options
then show it, and the preview outlines it. **Drag** a box to move the panel (press on it, move, release):
a dashed outline follows the pointer and the place it would go is shaded.

| Drop on | Effect |
| --- | --- |
| an empty (dotted) cell | the panel moves there, to that row and column; its spans are clipped to the grid, and the status bar says so (*"Moved psth_1 to row 3, column 1. Its spans became 1 x 1 to fit the grid."*). A cell the panel would not fit in, its clipped spans still overlapping another panel, is not shaded and is no target: releasing there moves nothing and the status bar says why (*"... does not fit at row 2, column 2: it would overlap raster_1. Shrink its spans first, or drop it beside a panel."*) |
| the middle of another panel's edge | the outer third of the panel, along the middle third of its top, bottom, left or right edge, shades the edge band: the panel is taken from its place (as **Remove panel** does, closing a row or column it leaves empty) and put *above*, *below*, *left* or *right* of that panel (as **New panel...** places one, in a new row or column). The moved panel keeps its id, type, options and layers and its place in the figure's panel order (so the draw order, and which panel the legend takes its first entries from, are unchanged), and is selected. Taking it away first drops any row or column no other panel starts in, so a panel that spanned such a row loses that span: with *A* over rows 1-2 beside *C* over *B*, dragging *B* above *C* drops row 2 and *A* spans one row |
| anywhere else (the panel itself, another panel's middle or corners) | no target: the release only picks the panel |

**Escape**, or a release outside the schematic, cancels the drag, and nothing
moves (the status bar says *"Drag canceled."*, or *"... released outside the
arrangement."*); a right or double click only picks the panel, and a release
over another panel's middle or corner leaves it where it was and says where a panel
can be dropped. The drag follows the pointer however
the editor was scrolled before the press (the schematic's scale is read again at
every move), but not a scroll during the drag; Escape works on any tab. A move ends like any
structural edit: the schematic, the editor and the preview follow, and the config is
unsaved. The buttons below still work: a drop beside a panel is a **Remove panel**
and a **New panel...** placement in one, and a drop in an empty cell moves a panel where **Move**
cannot (it only swaps with a same-shaped neighbor).

| Control | Effect |
| --- | --- |
| **New panel...** | opens the [New panel window](#the-new-panel-window): the new panel's type, name, title, place next to the selected panel and key parameters. *Above* and *Below* make a new row of the grid, as high as the selected panel's row, and the new panel takes the selected panel's columns; *Left* and *Right* make a new column, as wide as its column, and the new panel takes its rows. Panels past the new row (column) move down (right) by one, and those whose span crosses it grow by one. The first panel of a figure goes to row 1, column 1. The new panel holds the type's default layer, so it draws at once (a *Coherence* panel two, the observed unit and its channel's LFP, a spike-field coherence), and is selected ([Editing the grid](EphysAnalysisConfig.md#editing-the-grid)) |
| **Row span**, **Column span** | how many rows and columns the panel covers, from its own cell; refused, with the reason in the status bar, past the grid's edge or over another panel (`rowSpan`, `colSpan`) |
| **Row height**, **Column width** | the relative height of the panel's first row and width of its first column against the others (1 = equal; steps of 0.25), for every panel of that row or column: the rows' plot areas take exactly these shares (`grid.rowHeights`, `grid.colWidths`) |
| **Panel size** | the selected panel's own width and height, % of its cell (1 to 100; `size`): this panel only, not the others of its row or column. A panel narrower than its column keeps its own time tick labels |
| **Align in cell** | where a panel smaller than its cell sits in it: *left*, *center* or *right* (on while it is under 100 % wide), *top*, *middle* or *bottom* (on while under 100 % high) (`align`, `valign`) |
| **Spacing**, **Spacing...** | the gap between the panels, the clear space between neighboring panels' labels: *loose*, *compact* or *tight* (24, 12, 6 px), *none (flush)* (0: stacked time panels share their edges) or *custom* (`grid.spacing`). **Spacing...** opens the Spacing window (below) for the gaps themselves |
| **Remove panel** | removes the panel, then every row and column in which no remaining panel starts, so it exactly undoes the Add that made them (a blank row or column that was there before closes too) |
| **Move** (arrows) | swaps the panel with the panel of the same shape above, below, left or right of it; an arrow is off when there is none |

<a name="the-new-panel-window"></a>

**The New panel window** (**New panel...**, and **Add** after it makes a blank
figure; *New panel*, modal) adds one panel to the selected figure. On the left a
tile per [panel type](EphysAnalysisConfig.md#panel-types), all thirteen
(`EphysAnalysisConfig.panelTypes()`: a type added there shows here too), each a
small representative plot of the type over its label (the type's description is
its tooltip): the type drawn by its real draw function on a small synthetic
dataset, its text stripped (`analysis/icons/panels/<type>.png`, made by
`tools/makePanelThumbnails`; a type without one shows a gray placeholder).
Click a tile to pick the type (it turns amber; *PSTH* is picked when the window opens); the
right side follows it:

| Control | Effect |
| --- | --- |
| the type's label and description | what the type draws |
| **Name** | the panel's id (`<type>_<n>`, the first free, until you type one; another panel of the figure's name is refused with a red line, the window staying open) |
| **Title** | the panel's own title (blank = none) |
| **Place** | *Below*, *Above*, *Right of* or *Left of* the selected panel (named); off for a figure's first panel, which goes to row 1, column 1 |
| **Key parameters** | **Reads** (the first layer's source, among the sources the type draws; a *Coherence* panel's **Seed** and **Partner**) and **Binding** (*Follows the observation* or *Fixed*; fixed and grayed out where the layer cannot follow), for every type but *Event traces*; then the type's own: *Raster* **Sort rows by** (trial order, the stop event or a trial parameter); *PSTH* **Bin (ms)**, **Smooth (ms)**, **Measure**, **Display** (trace or heat map); *Continuous signal* **Display** (lines or stacked rows), **Error band**; *Heat map* **Rows** (the layer's units or channels, or one unit's epochs: the binding then follows the observation), **Bin (ms)**; *Unit waveforms* **Layout**; *Probe map* **Value**; *Unit correlation* **Epoch rate**, **Correlation**; *Firing rate* **Measure**, **Display**; *Tuning curve* **Parameter**, **Series**; *Power spectrum* **Frequency (Hz)**, **Scale**; *Spectrogram* **Frequency (Hz)**, **Moving window (s)**; *Coherence* **Frequency (Hz)**; *Event traces* **Lines** (the active dataset's lines, several picked with Ctrl+click: an events layer and a row each) and **Draw as**. Every other option keeps the type's default and is in the editor's sections |
| **OK**, **Cancel** | **OK** adds the panel (`onNewPanel`, `EphysAnalysisConfig.placePanel`) and selects it: the schematic, the editor and the preview follow, a figure that observed the dataset observes what a following layer reads, and an automatic id follows the panel; the status bar says what was added (*"Added psth_1 (PSTH) below raster_1 with units, follows the observation."*). **Cancel**, or closing the window, adds nothing |

The key parameters, and the panel's other options, start from the
[options you last set on a panel of the type](#remembered-panel-options)
rather than the type's defaults, when you have set some; the status bar
then names them.

**The Spacing window** (**Spacing...**; *Panel spacing: figure_1*) sets the gaps
between the selected figure's panels. A gap is the clear space between
neighboring panels' labels: 0 makes them touch, so stacked time panels whose
inner tick labels are dropped are flush ([the layout](EphysAnalysisConfig.md#renderfigure)).

| Control | Effect |
| --- | --- |
| **Spacing** | a preset (*loose*, *compact*, *tight*: 24, 12, 6 px; *none (flush, 0 px)*), every gap the same, or *custom*; the rows below are on with *custom* (`grid.spacing`) |
| **Units** | *px* (pixels at the size drawn; an export is drawn at its own size) or *% of the panels' size*: a row gap is a share of the mean row's plot height, a column gap of the mean column's plot width, so the figure keeps its look at any size (`grid.gapUnits`) |
| **Between rows**, **columns** | one gap each way (vertical and horizontal); a change fills every gap of the table that way (`grid.rowGap`, `grid.colGap`) |
| the table | every gap of the grid, *rows 1 and 2*, ..., *columns 1 and 2*, ...: edit one to set it apart from the others (a value under 0 or not a number is refused). The gaps are kept as lists only when they differ from the one gap each way (`grid.rowGaps`, `grid.colGaps`); a preset shows its value, read-only |
| **Apply**, **OK**, **Cancel** | **Apply** gives the figure the gaps (the editor, the schematic and the preview follow) and keeps the window open; **OK** applies and closes it; **Cancel** closes it, what was applied staying. The gaps go to the figure the window was opened on (named in its title), whichever is selected by then |

Adding a panel in a new row or column gives a gap list the gap where the new
row or column goes, on both sides of it; removing a panel takes its row's (or
column's) gap away ([Editing the grid](EphysAnalysisConfig.md#editing-the-grid)).

**Changing a panel's type** (Selected panel → **Type**) starts its options afresh from
the new type's ([Panel options](EphysAnalysisConfig.md#panel-options)),
keeping the values both types have (bins, the baseline when the new type
takes its mode, measure, the mask after the stop event, y and color limits,
the group shown, and the waveform inset from a raster, PSTH, firing rate or
tuning curve panel to another of them); a unit waveforms panel's waveform, or
an inset from or to one, starts over. It drops the
layers the new type cannot draw (a unit waveforms panel draws no LFP layer), makes the
layers it keeps fixed where the new type draws only fixed ones, and adds the
type's default layer when none is left. A type that is not aligned to events
(unit waveforms, probe map) goes back to the figure's event reference, epoch
window and trial selection. The status bar says what changed (*"psth_2 is now a heat map
panel (was a PSTH panel): options reset; ..."*).

**Panel alignment.** With **Same as the figure** ticked the panel uses the
figure's event reference and epoch window and shares its time axis, so time
panels stacked in a column are labeled once, at the bottom
([shared time axis](EphysAnalysisConfig.md#shared-time-axis)). The rows then
show the figure's event and window, locked (grayed out). Unticking the box
copies the figure's current event reference and window into the panel as its
own, both, and opens the rows to edit: its own epochs, cut with its trial
selection (the figure's, unless the next box says otherwise), and an x axis of
its own; ticking the box goes back and drops the panel's own. With the figure's
selection the panel's groups must match the figure's by label, or it is
skipped.

Under the event and window rows, the **Trial selection as the figure** box (an
aligned type only) does the same for the panel's trial selection, with the
Alignment tab's selection rows under it (**Group by**, **Filter**, the order,
...). Ticked, the panel uses the figure's groups, colors and legend, and the
rows show the figure's, locked. Unticking it copies the figure's selection (its
own, else the defaults') into the panel and opens the rows: the panel then cuts
its own epochs and groups, which are not matched to the figure's (and not cut by
**Per trial group**), colors them apart from the figure's and lists them in a
legend of its own inside the panel, titled with its grouping (*by Depth*, *all
trials* when it groups by nothing) when that differs from the figure's. It still
shares the time axis while **Same as the figure** is ticked: the selection does
not change the event or window. Ticking the box again drops the panel's own;
an edit in the rows while it is ticked is not taken. Two buttons sit above the
rows: **Apply to all panels** (on while **Same as the figure** or **Trial
selection as the figure** is unticked) makes this panel's event reference, window
and trial selection the figure's and links every panel to them
(`adoptPanelAlignment`); **Re-link all panels** (on while any panel has its own
event, window or selection) sets every panel back to the figure's event,
window and trial selection; the panels' options stay their own
(`relinkPanels`). The status bar says what changed. A unit
correlation, firing rate or tuning curve panel's own window may also be a
*between* window (a fixed window is the only other mode).

**Layers.** The list names the panel's layers (*units, follows the
observation*, *LFP, fixed: ch 3 5*, *events: Stim offset (marks)*; a name of
your own comes first, *(off)* ends an unticked one).
**Add** adds a layer of the source in the drop-down beside it, which offers
only what the panel's type draws
([source categories](EphysAnalysisConfig.md#source-categories), and *events
(a line)* only on a panel that shares the time axis: a raster, PSTH, continuous
signal, heat map or spectrogram, no longer a firing rate, tuning curve, power
spectrum or coherence panel); the layer is bound as the
type binds a new one, and fixed where it cannot follow the observation. **Remove**, **Up**
and **Down** edit the list; the order is the drawing order (the first
layer's first unit is a raster's top rows). A type that draws one layer
(heat map, unit waveforms, probe map, unit correlation) says in
red when it has more: only the first enabled one is drawn (a unit waveforms
panel in the *probe* layout takes more: the first layer is drawn, the others
frame their units in red). A *Spectrogram* is a one-layer type too (its first
signal or spike layer: LFP, MUA, SPIKE, AUX, sorted units or detected spikes).
A *Coherence* panel takes exactly two layers, the seed first and
its partner second (Validate refuses any other number): the seed's first
channel or unit is paired with each item of the partner, so *Up* and *Down*
swap their roles. A *probe* layout whose first layer follows the
observation draws one unit, and Validate warns: bind the first layer to fixed
units and add a layer that follows the unit to frame it. The rows below the
list edit the layer picked:

| Row | Effect |
| --- | --- |
| **Name**, **Enabled** | the legend and aesthetics label (blank = the unit's, channel's or event's own); unticked, the layer is kept and not drawn (`name`, `enabled`) |
| **Source** | what the layer reads: only the sources the type draws (`source`) |
| **Binding** | *Follows the observation*: reads the unit or channel picked over the preview (for the other spike source, the detections or units on its channel; for a signal, the column that records the unit's channel, or the observed column; AUX has no recording channel, so it can follow only a figure that observes AUX). *Fixed*: reads the items named below (a signal's **Channels** blank: every column, so an AUX layer fixed with no channels draws every AUX channel beside the unit's panels). Only spike and signal layers on a raster, PSTH, continuous signal, unit waveforms, firing rate or tuning curve panel (and a heat map's spike layer while its **Rows** are the unit's epochs) may follow; events layers, and any layer of the other types, are fixed, and so is an AUX layer under a figure that observes units or another signal (and any other layer under a figure that observes AUX): the editor sets it to *Fixed* and grays the binding out. A gray line says what the layer draws for the figure's observation ([What a layer reads](EphysAnalysisConfig.md#what-a-layer-reads); `binding`) |
| fixed units or detected spikes | unit classes (units), **Unit ids**, **Good units only**, **Responsive only**, **Max units**, **Shanks** and **Channels** (the recording channels kept): the Observations rows, for the layer's own units (`units`) |
| fixed LFP, MUA, SPIKE or AUX | **Channels**: the extract's columns drawn, blank = all (`channels`) |
| **Aggregate** | a fixed layer of a raster, PSTH, continuous signal, firing rate or tuning curve panel with several units or channels: *each* one on its own, or *their mean* with a band across them; a fixed LFP, MUA, SPIKE or AUX layer of a power spectrum, spectrogram or coherence panel: *each channel*, or *their vector magnitude* as one item (each channel's 2 s running mean out first: e.g. a 3-axis accelerometer's movement, for a unit's coherence with it; [Spectral panels](EphysAnalysisConfig.md#spectral-panels)). Changing the panel's type sets an aggregate the new type does not offer to *each* (`aggregate`) |
| events | **Line** and **Edge** (the dataset's lines are listed; one can be typed), **Sequence** with **Edit...** (the *Event sequence* window), **Draw as** (*marks*: a mark at each event on a raster's rows, a line at each trial group's median latency on a PSTH or signal panel; *a spike train of its own*: the events drawn as a unit would be, on a raster, PSTH or heat map only; *a line from onset to offset*: on each raster row a line from each interval's onset to its offset, elsewhere a line per trial group from the median onset to the median offset, near the top; grayed out on an event-trace panel), for marks the **Marker**, its size and **Mark color**, and for a span **Mark color** (the line's color) and **Span line** (its style, width and opacity) (`event`, `eventsAs`; [Raster event marks](EphysAnalysisConfig.md#raster-event-marks)) |
| **Color**, **Line style** | *auto*: each trial group's color, and the line style by the layer's order (solid, dashed, dotted, dash-dot); or one color and line style for the layer's traces. On an event-trace panel, *auto* is a palette color per line and the panel's level line style. Event marks and spans have their own (`color`, `lineStyle`) |

**Options** are the panel type's rows (`options`; the fields are in
[Panel options](EphysAnalysisConfig.md#panel-options)):

| Panel type | Rows |
| --- | --- |
| Raster | **Sort rows by** (blank = trial order, *stop*, *event*, *latency* = the first spike's latency in the **First spike** window, none last, or a trial parameter) and its direction, **Sort event** and **Sort sequence** (with *event*), **Rows by group first**, **Colors** (the ticks' color: *groups* = each trial group's color, as the PSTH colors its traces, or one color for every tick, which a layer's own **Color** overrides; and **bands** behind the rows: *none* (the default), *groups* (a pale band of each group's color) or one color for every group), **Tick width** (points; 0 = the plot design's width; `options.tickWidth`), **First spike** (a summary beside **First-spike latency...**, below), **Show y ticks** (off by default: the y axis has no tick marks or epoch numbers, only its label; `options.yTicks`), **Mask after the stop event**; its waveform inset: the [Waveform section](#the-waveform-section) |
| PSTH | **Bin**, **Smooth**, **Measure**, **Baseline** (with *auroc*) and its window, the auROC rows (with the *auroc* baseline), **Mask after the stop event**, **Display** (*trace* or *heat map*), **PSTH as**, **Fill** and its opacity, **Normalize**, **Stack** (*Off (overlaid)* or *One row per group*, with its **spacing**, the row step in row heights), **Latency box** (a summary beside **Latency box plot...**, below), **Trial count** (*Off*, *Text in the plot (n = 24)* or *In the legend entries*: the trials each group has, [Trial counts](EphysAnalysisConfig.md#trial-counts)), **Y limits** (the mode, and in a stack the rows' scale); its waveform inset: the [Waveform section](#the-waveform-section); as a heat map, **Colormap** and **Color limits** instead of **PSTH as**, **Fill**, **Stack**, **Latency box** and **Y limits** |
| Event traces | **Draw as** (*solid bars (onset to offset)* or *a logic level (a line)*), **Trials** (*every epoch overlaid in the line's row*, translucent, or *a sub-row per epoch*, with **group bands**), the sub-rows sorted as a raster's rows by the raster's **Sort rows by** (and its order), **Sort event**, **Sort sequence** and **Rows by group first** (grayed out while overlaid), **Color by** (*line*: the layer's Color, else a palette color; or *trial group*), **Height** (a share of the row) with its **opacity** (blank: 0.3 overlaid, 1 in sub-rows), **Bar outline** and its width (bars), **Narrowest bar** (bars: points; a bar drawn narrower, a zero-length interval too, also gets a tick this wide through its middle; 0: none), **Level line** style and width (a line; a layer's own Line style wins), **Baseline** (**Draw**, its color) and **Baseline line** (style, width), **Row spacing**. Its layers are events layers only, one line each, a row each ([Event traces](EphysAnalysisConfig.md#event-traces)) |
| Continuous signal | **Baseline** and its window, **Stack** (*Off (overlaid)*, *One row per group* or *One row per channel*, with its **spacing**), **Signal** (mean or median; as recorded, rectified, or *Vector magnitude*: the layer's channels as one trace, √(x² + y² + z²) in each epoch after the baseline, e.g. a 3-axis accelerometer's AUX channels with Baseline *subtract*), **Error band** (off, mean ± SEM, mean ± SD, bootstrap 95% CI or interquartile range), **Trials** (*Off*, *Faint, behind the mean* or *Only the trials*) with **at most** (the most epochs drawn, 100 by default, picked evenly over their order; the traces sit under every band and mean; grayed out while *Off*), **Y limits** |
| Heat map | **Bin**, **Smooth**, **Measure** and **Mask after the stop event** (a spike layer), **Baseline** (*auroc* for a spike layer, with the auROC rows; the map is then of auROCs in the diverging colormap), **Rows** (*the layer's units or channels*, or *one unit's epochs (trials)*), **Row order** (*probe*, *peak* or *modulation*, the last only with the auROC baseline), **Stack** (*One image row per group*: a block of rows per group, **Group shown** hidden), **Color limits**; the group drawn is in the Selected panel section. With *one unit's epochs (trials)* a row is an epoch of one unit, every group at once, sorted as a raster's rows: the raster's **Sort rows by** and its direction, **Sort event** and **Sort sequence** (with *event*) and **Rows by group first** show, **Row order** and **Group shown** hide, and the layer may follow the observation (its Binding row opens for a spike layer; otherwise fix it to one unit). The map is one unit's epochs: a layer that follows the observation through a channel (a channel observation, or the other spike source) keeps every unit on it, which Validate refuses, and a layer that still keeps several is skipped with *A heat map of trials draws one unit: this layer keeps n*. The groups are a color strip along the left edge, the y label names the sort, and the auROC baseline is refused |
| Unit waveforms | **Layout** (*grid*: the unit, or several overlaid; *probe*: every unit of the first layer at its place on the probe, with the units of a further layer framed in red), **Y limits** (what is drawn, its scales and label: the [Waveform section](#the-waveform-section)) |
| Probe map | **Value** (*rate*, *nSpikes* or *nUnits*), **Color limits** |
| Unit correlation | **Epoch rate**, **Correlation**, **Fisher z transform**, **Baseline**, **Bin** and **Smooth** (for the *peak* rate), **Color limits** |
| Firing rate | **Measure**, **Baseline** (*none*, *subtract*, *ratio* or *zscore*) and its window, **Display** (*bars (mean, error bar)*, *boxes* or *points (each epoch)*), **Y limits** (its waveform inset: the [Waveform section](#the-waveform-section)) |
| Tuning curve | **Measure**, **Baseline** (as the firing rate panel's) and its window, **Parameter** (the trial parameter on the x axis; blank: the figure's first group-by parameter, else the first numeric one) with **series** (one curve per value of another trial parameter; blank: one curve), **Stack** (*One row per series*), **Y limits** (its waveform inset: the [Waveform section](#the-waveform-section)) |
| Power spectrum | the Chronux rows: **Time base** (*the panel's epochs* or *segments of the recording*, with **Range (s)** and **Segment (s)**), **Tapers** (*TW and K* or *W (Hz) and p*, with **TW, K** or **W (Hz), p**), **Pad**, **Frequency range**, **Error** (*none*, *theoretical* or *jackknife*) with its p-value, **Detrend**, **Scale** (*dB*, *log axis* or *linear*), **Spike rate (Hz)** (with a spike layer), **Stack** (*One row per group*) and **Y limits** |
| Spectrogram | **Tapers** (as above), **Pad**, **Frequency range**, **Detrend**, **Scale** (*dB* or *linear*), **Spike rate (Hz)** (with a spike layer), **Moving window (s)** with its step, **Baseline** (*none*, *db*, *percent*, *zscore* or *ratio*) with **Baseline (s)**, whose window must lie inside the panel's window, **Stack** (*One image row per group*, **Group shown** hidden) and **Color limits**; the group drawn is **Group shown** in the Selected panel section |
| Coherence | **Time base** with **Range (s)** and **Segment (s)**, the tapers, **Pad**, **Frequency range**, **Error** with its p-value (*jackknife* gives the band and the confidence level, *theoretical* the level), **Detrend**, **Spike rate (Hz)**, **Show phase (under the magnitude)**, **Stack** (*One row per group*: the magnitude's rows, or over time an image row each) and **Y limits** (blank: 0 to 1); **Over time (a coherogram)** swaps the error, phase and y limits for **Moving window (s)** and **Color limits**, adds **Group shown** and, on the panel's epochs, puts the image on the figure's time axis; it takes spike layers as well as signals (spike-field and unit-unit coherograms). Its two layers may be signals at different rates (an AUX layer and an LFP layer): the faster one is resampled to the slower one's rate |

#### The Waveform section

The **Waveform** section (in the PANEL supersection, under Options) holds the
selected panel's unit waveform, `options.waveform`
([Panel options](EphysAnalysisConfig.md#panel-options)): on a raster, PSTH,
firing rate or tuning curve panel an inset, the panel's first unit's waveform
on its peak channel drawn in a corner of the panel, in the panel's data units
as the Review tab draws it (a layer drawn as its units' mean has none); on a
unit waveforms panel the panel itself. It shows for every panel type whose
layers may be spikes, titled with the panel's id, and starts with a note on
what it sets there. A heat map, probe map, unit correlation or spectral panel
draws no waveform: the section holds only the note, which says why and
suggests a Unit waveforms panel beside it (the search, asked for one of its
rows, says the same). A panel of signals or events only (continuous, event
traces) has no Waveform section.

| Row | What it sets |
| --- | --- |
| Show | *Off* (no inset; a unit waveforms panel cannot be off), *Mean*, *Individual spikes* (thin, pale) or *Mean + individual spikes* (`mode`: `off`, `mean`, `subsample`, `both`). A unit whose spikes cannot be read draws its template as the mean, and says so |
| Spikes drawn | how many of the unit's spikes are drawn one by one, at random but the same each time; a sorted unit's mean is over them, so it counts for *Mean* too (`maxSpikes`) |
| Time (x, ms) | the x scale: the span drawn, from and to, ms from the spike; a blank field is the cut's edge, both blank the whole cut (`timeMs`: `[]`, or `[from to]` with `-Inf` / `Inf`). A span that misses the waveform draws all of it |
| Amplitude (y) | the y scale: *Each unit's own range* (the waveform fills its box or tile), *One range for the units drawn* (a unit waveforms panel: the units' sizes can be compared, with a scale bar on the probe), or *Fixed range* with the range at its right in the waveform's units, µV for most (`ampScale`: `unit`, `common`, `fixed`; `ampLim`); a fixed range is the same for every observation, and an inset or probe glyph cuts what lies beyond it at its edge. On a unit waveforms panel in the grid layout the panel's own **Y limits** (Options), when not *Auto*, win |
| Size | the inset's **width** and **height**, each a factor of its default, a third of the panel's (0.25 to 3); on a unit waveforms panel in the probe layout each glyph's (`width`, `height`) |
| Inset location | where the inset sits (a compass point; `location`) and **Axis box** (its outline and pale ground; `box`): an inset only |
| Label | **Peak-to-peak** (the mean's, over the whole cut; `showPP`) and **Spike count** (the unit's spikes in the whole recording; `showCount`) |
| On the probe | **Sites** (the probe's sites behind the waveforms; `showSites`) and **Unit names** (`showNames`): a unit waveforms panel in the probe layout only |

Every row but **Show** is grayed out while it is *Off*. **Apply to all panels**
(Options) copies the inset to every raster, PSTH, firing rate and tuning
curve panel of the figure, and a type change from one of these to another
keeps it. The inset's mean and spikes take their colors and line widths from
the right-click editor's looks (`waveMean`, `waveSpikes`).

**Y limits** (every panel with a y axis of values) is a drop-down beside the
limits' field, which is open only for *Fixed*: *Auto* (the axis fits the data;
in a stack each row fits itself), *Shared by rows* (a stack's rows on one
scale), *Shared by batch* (every observation of a **Generate selected figure** or Export
**Run** of the figure on one range, the union over the run's datasets: the
preview draws its own range, and its status line says so) or *Fixed* (the two
values typed: `yLimMode`, `yLim`; [Y limits](EphysAnalysisConfig.md#y-limits)).

**Stack** draws a panel's trial groups in rows of their own instead of
overlaid, the first on top (as a raster lists them): a PSTH's, a continuous
panel's (or its channels: *One row per channel*), a heat map's, a tuning
curve's series, a spectrum's, a spectrogram's and a coherence panel's. Line rows
name their groups on the left axis and each row's top (a PSTH's peak) on the
right, so their **Y axis** side grays out; image rows (heat map, spectrogram,
coherogram) share the time axis and one color bar, each with its group's color
strip, and **Group shown** hides. The **spacing** is the row step in row heights
(1: the rows touch). A single group is not stacked, a second layer is drawn into
the rows, and a raster panel above a PSTH shows the groups' rasters. A raster
(its groups are blocks already), a firing rate panel (its groups along x), and
waveforms, probe map, unit correlation and event-trace panels show no **Stack**
row; going to it from the search says why ([Stacks](EphysAnalysisConfig.md#stacks)).

**First-spike latency...** (a raster's **First spike** row) and **Latency box
plot...** (a PSTH's **Latency box** row) open a modal window on the selected
panel's [first-spike latency](EphysAnalysisConfig.md#first-spike-latency)
settings; the row beside each button sums them up (*off*, or e.g. *on, 5-50 ms,
◆ red*; *end* is the window's end). Both windows have the on box (*Mark each
epoch's first spike*, *Draw the box plot of the first-spike latencies*), **Detect
from** and **to** (the latency window in ms from the aligned event, both ends
included; **to** blank: the panel's window's end) and the look: the raster's
**Marker** and its size, **Color** (*groups*: each trial group's color, or a
color name or #RRGGBB; its swatch opens the [color chooser](#picking-a-color)) and **Filled**; the PSTH's **Color**, **Line** (style and
width of the box's outline and whiskers), **Box height** (each box's lane, a
share of the PSTH's height), **Fill opacity** and **Outliers** (marker and size;
*none* hides them). The rows under the on box are grayed while it is off. **OK**
gives the panel the settings as one edit, named in the Edit menu (*Undo
First-spike latency*, *Undo Latency box plot*); a window that ends before it
starts is refused, said in the window, which stays open. **Cancel** changes
nothing. The raster then marks each epoch's first spike on its row, over the
ticks, in every block; the PSTH draws a box plot of the latencies per trial
group in a band above its traces, or with **Stack** in each row. **Apply to all
panels** takes them to the other panels of the same type.

**Display** *heat map* draws a PSTH panel's unit as an image instead: a row
per trial group, the first on top, labeled with the groups' values, each bin
colored by its rate (after measure, smoothing, baseline and normalize). The
colors span that unit's rows only, not the other units', so each unit's
preview fills the scale; **Color limits** fixes the scale (an auROC is on 0
to 1) and **Colormap** picks the colors (*auto*: **Heat colors** in
Appearance, else the design's; or a colormap function's name). A color bar
in the measure's unit is the legend. With several units or layers the first
is drawn and the others are noted on the panel. Switch back to *trace* to
see the bars or lines again; every other option is kept. A firing rate
panel draws the trial groups along x; a tuning curve draws the parameter's
values along x, a curve per series with error bars, and takes a
*between* window in Panel alignment as a unit correlation panel does. A
firing rate or tuning panel's layers may follow the observation, as a PSTH's
do, and a fixed layer may *aggregate* to its mean.

Every Options row is the panel's own. The **Baseline** modes a type offers are
its own: a PSTH and a heat map of spikes *none*, *subtract*, *zscore*, *percent*
and *auroc*; a firing rate and a tuning panel *none*, *subtract*, *ratio* and
*zscore*; a continuous or unit correlation panel (and a heat map of a signal)
only *none* and *subtract*. With the *auroc* baseline the auROC rows show:
**auROC from** (the PSTH's bins or each epoch) with the windows (*tiled* or
*sliding*), the window, step, **Call window (s)** and **Modulated if** (the 95%
CI, a fixed threshold, a per-unit test or none; **Unit test** with its
resamples, correction and alpha for the test), and **Calls** (*Mark them*,
*Modulated units only*); the windows must be whole numbers of the panel's bins,
which Validate checks.

**Apply to all panels**, at the top of Options, copies this panel's values of
the rows several types share -- **Bin** and **Smooth**, **Measure**, **Baseline**
with its window and auROC rows, **Mask after the stop event** and the waveform
inset -- to every other panel whose type has them, the baseline only where that
type takes the mode (a PSTH's *zscore* does not reach a continuous panel, which
keeps its own); and the panel's other options (a PSTH's *PSTH as*, *Fill*,
*Normalize* and *Y limits*, a raster's sort, a waveforms panel's waveform, ...)
onto the other panels of its own type; and the panel's **X axis** and **Y axis**
sides onto every other panel, of any type (its label texts stay its own, like its
title; `adoptPanelOptions`;
[Copying options between panels](EphysAnalysisConfig.md#copying-options-between-panels)).
The status bar names each panel that changed and the options (and `xSide`,
`ySide`) it took, and the panels that kept their baseline (*"psth_1's options went to raster_1 (waveform),
heatmap_1 (bins, baseline); continuous_1 kept their own baseline (their type
does not take "zscore")."*), or says that the others have the values already.
It is on when the figure has another panel. So a stack's time axis goes to the
top in one step: set the X axis side to *top* on one panel and apply it (or use
**Move every panel's X axis to top**, below).

**Appearance** is the figure's `style`: font size, line width, site size
(probe maps), group colors, heat colors (heat map, probe map and unit
correlation panels, a PSTH drawn as a heat map), **Sort by** and **Label with** depth and shank (they
order and label the observation picker too), **Show** error, stop marks,
the artifact note (under the title, how many of the drawn epochs touch an
artifact period when **Artifacts: Exclude epochs** is off), legend and grid, the legend's place, orientation and box, **Error** (its type
and the bootstrap's resamples), **Band fill** and **Band edge** ([Error bands](EphysAnalysisConfig.md#error-bands)). It has no tiles per page, grid spacing
or y and color limits: a figure is one observation, the spacing is the
Panels section's, and each panel has its own y and color limits among its
Options.

**The preview** draws the selected figure for the observation picked, on the
active dataset: `figureObservations` lists the observations,
`EphysAnalysisRunner.computeFigure` computes the one picked (no graphics;
only that unit's spikes or that channel's column are read) and
`renderFigure` draws it, so it is what a script calling them draws.

| Control | Effect |
| --- | --- |
| **Dataset** | the active dataset (the same one as on the other tabs, which list it the same way), with what it holds of spikes: *subj1_day1  (14 units)* (its sorted units, counted the first time it is opened in the session: they are read for the Data tab then, so nothing more is read and a share's folders are never walked for the counts; until then the name alone), *(detected only)* (no sort, a spikes file) or *(no sorting)*. Grayed out for a figure across sessions, which is drawn over the ticked (or listed) datasets, not the active one |
| **Observation** | what the figure is drawn for: the units, channels or dataset the Observations section keeps, in probe order (*su12  ch 7  -320 µm  (5,210 spikes)*: a sorted unit ends in its number of spikes, a detection channel in its number of detections; a signal's channel and the dataset have no count). With **Per trial group** it lists a row for each unit and trial group (the unit's rows together, in group order, the label ending in a middle dot and the group's label, then the unit's count), the preview draws that group's epochs only, and **>** steps from a unit's group to its next one. Each figure remembers its pick until the app closes, by label (without the count), so it stays through a filter change or another dataset while that label is in the list, else the first is picked. Picking one draws it, whether or not Auto is on. For a figure across sessions it lists the sites, cells or channels matched across the sessions, each ending *(across 3 sessions)* ([below](#sessions-in-the-figures-tab)) |
| **Open in window** | (**Ctrl+W**) at the right of the status line under the preview, right of **Export code**: draws the figure as previewed into a new regular MATLAB figure window (`figure`), named *figure id: observation (dataset)* and the shape of the figure's export page at its true size on screen ([the page](#the-page-a-figure-is-exported-on); Ctrl+Click on a panel selects it in the editor), with the right-click aesthetics editor and its Design submenu (what it remembers for the figure reaches the config while the app is open). A drawn preview is used as it is; an *Out of date*, canceled or missing one is previewed first, and the status bar says why when that draws nothing. The window is independent of the app: later edits do not follow into it, and closing the app leaves it. Off with no figure selected |
| **Redraw All** | (**Ctrl+R**) computes and draws again the preview of every enabled figure (and the shown one, enabled or not), each for its own observation on the active dataset, so that every figure's kept preview is current after an edit of the defaults, a dataset or a scan (see **Redraw All** below). It sits under **Preview**, in the same colors, and is off with no figure selected, while a run goes and while it goes itself. Writing the selected figure's files for every observation is **File → Generate selected figure** (**Ctrl+G**, see **Generate selected figure** below) |
| **Unit report** | (**Ctrl+U**) a spot check of one unit (or channel): every enabled figure of the active dataset, drawn for the unit or channel picked in **Observation** only, as an HTML report that opens in the browser (see **Unit report** below). It sits under **Redraw All**; off without a dataset or a unit or channel picked, for a figure of the dataset or across sessions, and while a run goes |
| **<**, **>** | the previous and next observation (**Page Up**, **Page Down**: a figure has no pages), side by side at the bottom of the column of buttons; off at either end of the list |
| **☆** / **★** | right of **Dataset**: stars the active dataset. Right of **Observation**: stars what the preview shows -- the sorted unit (with its sort), the channel (a detection channel's star is its channel's) or, for a figure of the dataset, the dataset; off for a figure across sessions. A starred dataset, unit or channel starts with **★** in its drop-down; the pick is still remembered by its label without the mark ([Favorites](#favorites)) |
| **✎** | right of each star: opens the notepad on the same thing, the active dataset or what the preview shows, and the notepad then follows it as you pick or step. Yellow when it has a note (its first line in the tooltip); a dataset, unit or channel with a note shows **✎** in its drop-down, after any **★** ([Notes](#notes)) |
| **Favorites** | under **Observation**: a filter field and a drop-down of every starred dataset, channel and unit of the scanned datasets. Picking one makes its dataset active and, when the selected figure observes units (for a unit) or channels or detection channels (for a channel), picks and draws it ([Favorites](#favorites)) |
| **Export code** | (**Ctrl+E**) left of **Open in window**, at the right of the status line under the preview: opens the code behind the preview in the MATLAB editor, as a new unsaved script (`EphysAnalysisScript.preview`, [Generated scripts](EphysAnalysis.md#a-previewed-figure-as-a-script)). It names the active dataset (a figure across sessions: the ticked or listed datasets), writes the figure's settings out as `spec` (`figureFor`'s, every *default* resolved), finds the observation picked again in `figureObservations` (by its unit id or the extract's column; with **Per trial group**, its group too; across sessions, by its label), loads the data as plain variables to analyze -- every event line, the trials, every spike train, the preview's epochs (`E`, `G`: `figureEpochs`), each unit's spikes and each line's onsets and offsets in every epoch (`spikesIn`, `onsets`, `offsets`), a figure of channels its signal cut into the epochs too; across sessions one `data(j)` per session -- then calls `figureCompute` (`figureSessionCompute` across sessions, keeping the **Figure:** pick) and `renderFigure` into a figure window the size of the preview, in the design chosen. Run it to load the data and draw the figure without the app; change `spec` or pick another row of `obsT` to make it your own. Nothing is computed when you press it, so the preview need not be drawn; the code holds the figure as the editor shows it then, and later edits do not follow into it. Without the desktop's editor (`matlab -batch`) it writes the script to `tempdir` and the status bar names the file. Off with no figure selected |
| **Export preview** | (**Ctrl+K**) left of **Export code**, at the right of the status line under the preview; the Export tab has it too, between **Plan** and **Run**. A spot check of the [Export tab](#export-tab)'s settings before a run: the selected figure, for the observation picked (a figure across sessions: the **Figure:** pick too), drawn as a run draws it -- the page at the export size, in the design chosen -- and written in each format ticked, at its dpi, under the name the file-name pattern gives it, but into a preview folder (`ExportPreviewFolder`, `tempdir\ephys_export_preview`, emptied each time), never the figure folder. The Export controls count as they are, saved or not, and **Write figure files** need not be ticked. An *Out of date* preview is computed first. The *Export preview* window shows the PNG as written (one at the dpi is written for it alone when png is not ticked), under the files' names, the page's size in cm, the dpi and the pixels, and the folder a run writes them to (and whether files are there already: kept or replaced, as **Overwrite existing** says); **Open the files** opens each in its own program, **Open the folder** the preview folder. One window, reused by the next preview. Off with no figure selected and while a run goes |
| **Preview** | (**Ctrl+P**) computes now, also for a signal extract above `PreviewMaxMB`, which otherwise waits for it. It is the button at the top left, heading a column of buttons (**Preview**, **Redraw All**, **Unit report**, **Auto**, **<** **>**) left of **Dataset**, **Observation** and **Favorites**, and turns orange while the figure is *Out of date* |
| **Auto** | (**Ctrl+T**) redraw after every edit while a preview takes under 2 s; a slower one says so (*"slow, so edits wait for Preview"*). On by default, because one observation is quick; remembered. It does not apply to a figure across sessions, which computes every session: an edit leaves its preview *Out of date* until **Preview** (or a pick in the observation list) draws it. The first figure drawn after the app starts is not timed, since it also loads the graphics, so that warm-up does not make the edits after it wait. The 2 s is the app's `FigureAutoPreviewSeconds` property (a public property, not a preference; set it on the app object before editing, for example to `Inf` to redraw however long a preview takes, which the app's tests do so a loaded machine cannot leave a preview out of date) |
| **Design:** | the look every figure is drawn in (Default, Tufte, Journal, Night, Talk, Gray panel, and yours; the Design menu offers the same): picking one redraws the preview, and every other figure on screen, at once; runs draw their figures in it. It sits right of the **Dataset** drop-down, with **Save look as design...** under it, right of **Observation** |
| **Save look as design...** | keeps the preview's look -- every property of every component, its ground and its group colors -- as a design of yours, and picks it. The look is read per panel type, from the panels as the preview drew them (not the config, which may have changed since): the rules of a heat map, probe map, unit correlation or spectrogram panel's tile (those axes are drawn their own way) go under the design's `kinds` for that panel type, and those of the figure's other panels are common rules (the same attribution as the preview's right-click **Save this look as a design...**). It saves nothing while the preview is *Out of date* (the status bar says *Preview first: the drawing is out of date*) |

**The selected panel** is outlined in the preview: a blue frame, 3 px wide,
round its axes and the room their tick labels, axis labels and title take (a
coherence panel's phase strip too), a few pixels out. It moves at once when
another panel is picked (in the schematic, with **Ctrl+]** / **Ctrl+[** or
**Ctrl+Alt+arrows**), with nothing computed or drawn again, follows the figure
when it is laid out again (the window resized), and is hidden while the
preview shows another figure or an older drawing without that panel. It
belongs to the app, not the figure: **Open in window**, Generate selected figure, Run and the
exports never have it, and the aesthetics editor, **Save look as design...**
and the data tips do not see it. A redraw by the aesthetics editor leaves it
out until the next pick or preview.

**Ctrl+Click a panel** in the preview (or in an **Open in window** figure) to
select it: the figure editor picks that panel (as a click on it in the
schematic does), the Panel supersection and its **Selected panel** section open
if they were collapsed, the editor scrolls to the section and the outline moves.
Cmd+Click on a Mac. A right-click still opens the aesthetics menu: MATLAB reports
a Ctrl+Click as the same button, so the click is told apart by the Ctrl key
(the figure's `CurrentModifier`, and the app's own record of the key). Picking a
panel is not an edit: no undo step is made, and the Ctrl held for the click does not
open **Apply to figures** (that follows an edit made with Ctrl down). In a
window of its own the click also brings the app forward on the Figures tab.

#### The page a figure is exported on

The **Size** row under **Title** sets the page the figure is exported on and
the shape of the preview. Its drop-down is editable: pick a suggestion or type
a size.

| Entry | Page |
| --- | --- |
| *Export tab size* (the default) | the Export tab's **Size (cm)**, taller when the figure's rows need it (`size.source` `"export"`) |
| *700 x 800 px* | the page the shared y range of a run is measured on |
| *Journal 1 column (3.5 x 3 in)*, *1.5 column (5 x 4 in)*, *2 column (7 x 4.5 in)* | common journal widths |
| *Slide 16:9 (13.33 x 7.5 in)*, *Square (4 x 4 in)* | |
| *Fit preview* | the preview area's shape and size as it is now (an own size in the units shown) |
| typed: `6 x 4 in`, `1200x800 px`, `15 x 10 cm`, `150 x 100 mm` | that size; with no unit, the units shown. Text that is no size is refused, and the status bar says so |

The **Width x height** row shows the page in **px**, **in** or **cm**, whichever
the units box says: **px** are pixels of the exported PNG (so inches at the
Export tab's **Dpi**: a *1200 x 800 px* page is 8 x 5.33 in at 150 dpi and its
PNG is exactly 1200 x 800), **in** and **cm** are print sizes. Editing the width
or the height gives the figure a size of its own (`size.source` `"own"`); with
**Lock ratio** ticked the other side follows, keeping the aspect ratio.
Changing the units converts the numbers and keeps the page the same size. A
figure with the Export tab size shows that page in the units, and follows the
Export tab when it changes. Every export of the figure -- a run, Generate,
**Export preview**, the generated scripts -- draws on that page
(`figureExportSize`, `newExportFigure`).

The preview represents the page: it is drawn at the page's aspect ratio, as
large as fits the preview area and centered in it (the gray round it is the
ground), and its fonts, line widths and probe-map sites are scaled by the same
factor as the page (the width drawn over the page's width at 96 dpi, kept
between 0.35 and 3), so text and lines have the proportion to the page they
have in the export. Sizes the looks (the aesthetics editor's rules) set are not
scaled. A size edit is one undo step (*Undo Size*): the preview takes the new shape
at once and, when it was current, is drawn again from the figure it holds without
computing anything; an out-of-date one waits as after any edit. Edited with Ctrl
held it also offers **Apply to figures**. **Open in window** opens a figure of
the page's shape at its true size on screen (96 dpi; scaled down to fit when it is
larger than the screen). The y range a run shares (*Y limits: Shared by batch*) is
still measured on a 700 x 800 px page.

An edit draws only what it changed: what an earlier preview computed on the
same data is taken again (an edit of the looks -- titles, labels, places,
notes, colors, fonts, the grid -- computes nothing; an edit of one panel's data
computes that panel), and the panels the edit leaves as they were stay drawn,
the others drawn again around them (`EphysAnalysisRunner.computeFigure`
`Reuse=true`, `renderFigure` `Reuse=true`). A scan forgets what was computed.

The line under the preview names the figure, the observation, the dataset and
the time taken (*"figure_1, su12  ch 7  -320 µm on subj1_day1 (0.4 s);
right-click to change colors, lines and fonts"*), or says why the figure
cannot be drawn: the runner's [skip reasons](#why-is-my-figure-skipped) (no
sorted units, no LFP extract, no paired trials, ...), or that no unit or
channel passes the Observations filter. A layer that cannot be drawn for the
observation is kept: its panel draws the other layers and prints the reason
in small gray text. A colored badge at its left says where the preview is:

| Badge | Means |
| --- | --- |
| **Computing** (amber, spinning) | the figure is being computed for the observation picked on the active dataset |
| **Drawing** (blue, spinning) | the result is being drawn |
| **Drawn** (green) | the preview is the figure as it is now, for the observation picked |
| **Out of date** (amber) | the figure, the defaults or the dataset changed and the preview was not redrawn (Auto is off, the last preview took 2 s or more, the edit was on another tab, or another tab's preview was computing): press **Preview** |
| **Press Preview** (blue) | a layer, or the observed signal, reads an extract larger than `PreviewMaxMB` |
| **Cannot draw** (gray) | the active dataset cannot draw the figure, or no observation passes the filter; the line says why |
| **Failed** (red) | computing or drawing it failed; the line and the Log tab say why |
| **Canceled** (gray) | you pressed **Cancel** on the card while it computed; auto-preview leaves it until you press **Preview** |
| **No preview** (gray) | no figure is selected, or nothing is scanned or active |

While it computes, a card over the last drawing says what (*"Computing
figure_1 (su12 ...) on subj1_day1 ..."*) and has a red **Cancel** button. The
compute stops at its next checkpoint, within about one unit's or one
channel's work; reading an extract finishes first, and drawing cannot be
stopped. Edits made while it computes do not start a second preview; they
leave the one that finishes *Out of date*. Closing the app stops it too.
A preview and a run share the runner's computing and refuse each other (see
**Generate selected figure** below). The toolbar's **Preview** shows this tab first, lists the
selected figure's observations and previews it with **Preview** pressed (so a
slow preview is seen computing), whichever tab was showing.

**Redraw All** (**Ctrl+R**) makes every enabled figure's preview current in
one press: the shown figure first, then the others in the list's order, each
selected in turn (the editor and the observation picker follow it) and
computed for its own observation as **Preview** computes it (a large signal
extract is read too). A figure whose kept preview is still current (the tree
shows it plain, not *Out of date*) is left as it is, nothing computed, so a
second press costs next to nothing. The status bar counts it (*"Redrawing 3
of 7: figure_3 ..."*) and then sums it up (*"Redraw All: 4 drawn, 2 already
current, 1 not drawn (figure_5: the preview says why) (6.2 s)"*); the shown
figure is selected again at the end. Changing the **Design** needs no Redraw
All: it redraws every drawn preview in place. At most eight previews are kept
(`MaxFigureViews`), so with more enabled figures it draws the shown one and
those shown most recently (then the list's order) up to eight, and the status
bar adds *"; 2 more enabled figure(s) are drawn when shown (8 previews are
kept)"*. The toolbar's **Cancel** (and the Export tab's, or the card's
**Cancel** over the preview) stops it: the figure computing is canceled and no
other is drawn (*"Redraw All canceled: ..."*); picking another figure
meanwhile stops it too, and that figure stays shown.

**Generate selected figure** (**File** menu, **Ctrl+G**) draws the selected figure once per observation on every dataset
ticked on the Data tab, as the Export tab's **Run** would for this figure
alone: the same validation (errors in the config stop it, and the table on the
Export tab lists them), the same progress dialog and the same files, in the
Export tab's folder with its file-name pattern, a file set per observation
([Export tab](#export-tab)). It makes no report. A file that exists is kept unless **Overwrite existing** is on. It
reads the controls as they are, so unsaved edits are drawn. A figure that is
off (its **Enabled** box unticked) is drawn all the same, for that run only:
the config keeps it off and the status bar says so. **Cancel** on the
progress dialog, the Export tab's **Cancel** and the toolbar's **Cancel run**
stop it before the next observation; the observations left are *canceled*. One
run goes at a time: while Generate runs, Validate, Plan, Run, Generate selected figure, Redraw All and
Export preview are off, and the previews compute nothing and mark a drawn preview *Out of date*;
a preview that is computing (or Redraw All going) makes Generate wait too (the status bar says so).
When it ends, the Export tab's results table holds the
figure's rows (one per dataset, `Kind` `figure`, `<n> observation(s)` as the
`Message`, every file in `Files`), **Open figure folder** (also the
toolbar's) is on, and **Open report** is off, since no report was written.
The status bar then reads *"Generated figure_1: 12 observation(s) on 2
dataset(s), 24 file(s) in D:\EPHYS\...\analysis"* (with *"in 2 folders (the first: ...)"*
when the datasets' folders differ), or *"Generating figure_1 was canceled:
..."* with what was drawn before it stopped. After it come, when they apply,
*"; 1 dataset(s) skipped (no sorted units)"* (or no LFP extract, no
observation, ...), *"; n dataset(s) failed (the Export tab's results say
why)"* and *"; figure_1 is off, so it was switched on for this run only"*. With
no dataset ticked it says so and draws nothing. A figure across sessions is
the exception: Generate selected figure runs it as `run(SessionFigures=<id>)`, once across the
ticked (or listed) datasets rather than on each, into `Export.SessionsFolder`
([Sessions in the Figures tab](#sessions-in-the-figures-tab)).

**Unit report** is a spot check: the report for one unit without generating
the full report. It runs as the Export tab's **Run** does (the same
validation, progress dialog and **Cancel**, one run at a time), but on the
active dataset only, for the unit or channel picked over the preview only
(`run(Observation=)`), with no figure files and no session figures. Each
enabled figure (and the selected one, even when it is off, for this report
only) draws what matches the pick: on a figure of the same data, the unit
itself (with **Per trial group**, each of its groups); on a figure of a
signal's channels or of detection channels, or of sorted units when a
detection or a channel is picked, what is on the same recording channel. A
figure of the dataset, or one with nothing on that channel, is left out: the
report lists it as skipped with the reason (*"it observes the dataset, not
one unit"*, *"no LFP channel on channel 7 (...)"*), and so does the status
bar. The report is HTML whatever **Format** says, titled *<config name>:
<unit> on <dataset>*, and written to a new temporary folder (`tempname`, its
run record too), so the output folder is not touched. It opens in the browser
when it is written; the Export tab's results table then shows its rows and
**Open report** reopens it until the next run. The status bar reads *"Unit
report for su12  ch 7  -320 µm: 3 figure(s) drawn; left out: heat (it
observes the dataset, not one unit). C:\...\unit_report.html"*. With a figure
across sessions selected the button is off (its observations are matched
across the datasets): pick a figure drawn per dataset.

**Go to setting.** Right-click a part of the preview and pick **Go to setting** to
find what controls it: the error band goes to **Show > Error**, the stop dots to
**Stop marks**, a tile's title to the panel's **Title**, the legend to **Legend**,
the colorbar to **Heat colors** (on a PSTH drawn as a heat map, to its **Colormap**). The part's panel is selected, its supersection and
section open, the editor scrolls to the row, the control takes the keyboard focus
and its label is highlighted for a moment. A part with no setting of its own goes
to the Appearance section; a setting the panel does not show (an option of another
panel type) is named in the status bar. A figure opened with **Open in window**
does the same while the app is open. On a panel's x or y label it goes to the
panel's **X axis** or **Y axis** row.

**Axis labels.** Right-click a panel's x or y label in the preview for its own
items: **Edit label text...** asks for the panel's own label (blank: the type's
automatic one; `xLabel`, `yLabel`), and **Move to top** / **Move to bottom** (an
x label) or **Move to right** / **Move to left** (a y label) puts that axis'
ticks and label on the other side (`xSide`, `ySide`; a stacked line panel's y label has
no side to move to). Each edit goes into the config as the editor's own do: the
panel is selected, its rows follow and the preview is drawn again (or marked out
of date), and it is a step of the Edit menu's undo (**Undo Label text**, **Undo
Axis side**). In a figure opened with **Open in window** the
window is drawn again with the edit, and while the app is open the edit reaches
its config too.

Each label's menu also has **Move every panel's X axis to top** (or *bottom*;
**Move every panel's Y axis to right** or *left* on a y label): that axis of every
panel of the figure goes to that side in one step (**Undo Every panel's axis
side**); the status bar names the panels that moved, or says they were there
already. A stack of time panels whose x axes all go on top tells the time once,
at its top.

The same items are on the menu of a panel's axes itself (right-click the plot
area, off any line), beside **Edit aesthetics...**, **Go to setting** and
**Design**: **Edit X label text...**, **Edit Y label text...**, **Move X axis to
top** / *bottom*, **Move Y axis to right** / *left* (not on a stacked line panel, which
has a y axis on each side) and the two every-panel moves. So a label that shows
nothing can be set too: a label the time stack hides (an inner panel's x label,
which has no menu of its own) keeps the text you give it, and the status bar says
the stack does not show it (the panel that tells the time is labeled with its own
text, *Time (s)* when that is blank). The axes' items work in a figure opened with
**Open in window** as the labels' do.

**Aesthetics.** Right-click any part of the preview (a line, band, bar, text,
legend or axes) and pick **Edit aesthetics...** to change colors, line styles and
widths, markers, opacity and fonts in a modal window, *Figure aesthetics*: it
lists every component of the figure (a panel's by its id, `raster_1`, `psth_1`),
shows each change at once, applies it to that component, the same one in every
tile, every group of its role or the ticked rows, and has **Reset**, **Cancel** and
**OK**. **Remember for future figures** keeps the changes with *This figure
(saved in the config)* (its `aesthetics`, saved with the config so runs and reports
match the preview, and counted by the Looks section) or for *Every figure (my
preferences)* (group `PlotAesthetics`, one rule set per panel type and one for
`"figure"`); its **Remembered** tab lists both sets, *This figure* and *My figures*,
and forgets rules. A look remembered for PSTH panels dresses every PSTH panel of
every figure. See [Plot aesthetics](EphysAnalysis.md#plot-aesthetics).

**Data tips.** Click a point of the preview (a PSTH line, a raster tick, a bar, a
heat map cell) for a data tip that says what it is, not a bare X and Y: the time
from the event (*Time from Stim onset: 0.125 s*), the panel's quantity in its unit
(*Rate: 42.1 Hz*, a z-score, µV, power), a heat map cell's value and its row (the
unit, channel or epoch), a raster tick's trial and trial group, the unit or channel
the trace draws, the layer, the panel (*psth_1 (PSTH)*), the observation and the
dataset. Right-click the preview and pick **Data tip fields...** (also at the end of
the **Design** menu) to choose what the tips show: a check box per field, grouped as
*Point* (X value, Y value, Cell value, Row), *Trial* (Trial, Trial group, Trial
parameters: the trial's values) and *Source* (Unit / channel, Layer, Panel,
Observation, Dataset, Part: what was drawn), with **All**, **None** (MATLAB's X and Y
only), **Reset** (the defaults: all but Trial parameters and Part), **Cancel** and
**OK**. OK keeps the choice as your preference (group `FigureDataTips`) and shows it
at once on the preview and every other figure on screen; figures drawn after use it
too. The figures a run draws (invisible, for the files) have no tips; a figure you
draw yourself with `renderFigure` into a visible window has them.

**Plot designs.** A design is a whole look: the ground behind the figure, the
group colors, the heat maps' colors, and fonts, axes, ticks, box, grid, lines and
marks. **Tufte** follows Edward Tufte's data-ink (an off-white page, serif type, no
box or grid, quiet axes, gray data with muted color); **Journal** is print-ready and
color-blind safe; **Night** is dark; **Talk** has big type and thick lines for slides;
**Gray panel** looks like ggplot2. Pick one in the **Design:** list above, the
**Design** menu, or the right-click **Design** submenu of any figure. To make your
own, style the preview as you like (the Appearance rows, **Edit aesthetics...**) and
press **Save look as design...**: the design keeps everything the preview shows, and
what it does not show (a tuning curve's marks, say, when the preview is a PSTH) comes
from the design it was drawn in. Your designs are JSON files in your designs folder
(**Design → Open my designs folder**); copy one to a colleague, who adds it with
**Import a design file...**, or keep them all in a shared folder (**Keep my designs
in...**). Your rules and the figure's own rules still win over a design, and a figure's
own group or heat colors win over the design's. The design you pick is your
preference, not part of the config. See [Plot designs](EphysAnalysis.md#plot-designs).

**Epoch Diagram**, under the figure's Epoch window, opens the
[epoch diagram](#epoch-diagram) in its figure mode: the figure's event reference,
epoch window and trial selection (its own or the defaults), cut as the
compute cuts the figure's epochs, with the incomplete ones and those that
touch an artifact period dropped and the baseline windows of the panels on
the figure's alignment tested too. A figure with no panel aligned to events
says it has no epochs. The window follows the selected figure and redraws on
every edit.

#### Undo and redo

**Edit → Undo** (**Ctrl+Z**) takes back the last edit of the figures, and
**Edit → Redo** (**Ctrl+Y** or **Ctrl+Shift+Z**) does it again. The items
name the edit: **Undo Add panel**, **Undo Remove figure**, **Undo Move
panel**, **Undo Spacing**, and for a control of the editor its row's label
(**Undo Bin (ms)**, **Undo Title**). Every edit of the figures counts: the
editor's controls, the arrangement (New panel, Remove panel, Move, a drag in
the schematic, spans, Spacing...), the panel type, the layers, Apply to all
panels and Re-link all panels, the figure list (Add, Remove, Duplicate, Up /
Down, Copy settings..., the tree's check boxes), a look remembered or forgotten
from the preview, and Pick... for a session figure. A quick run of edits of
one field (each under a second after the last) is one step; one typed back
to where it started is none. The toolbar's **Undo** and **Redo** tools do the
same, with the step in their tooltips. Every path names its step: the dialogs
and buttons that edit the figure outside a labeled row say what they did
(**Undo Event sequence**, **Undo Sort sequence**, **Undo Add overlay**,
**Undo Pick datasets**, **Undo Panel span**, **Undo Figure id**); a plain
**Undo Edit** is only the last resort.

Only the figures are kept (the config's `Figures`), so undoing a figure edit
leaves the Data tab's source, the Alignment tab's defaults, the Export tab
and the config's name and description as they are now. The editor goes back
to the figure, panel and layer the edit was made in (a figure or panel that
an undo brings back is selected), and the list, the observation picker, the
epoch diagram and, with Auto on, the preview follow, as after the edit
itself. Undone back to the figures as saved, the title loses its `*` (when
nothing else changed). A new edit after an undo drops what was undone; at most
100 steps are kept. Opening a config or starting a new one clears the
history; saving keeps it.

The items work with the Figures tab showing: on another tab they are grayed,
so Ctrl+Z there does nothing in the app. Undo acts on edits entered: a value
typed in a field becomes a step once Enter, or leaving the field, enters it.

#### Apply a change to other figures

An edit of the editor changes the figure (and panel) it is made in, nothing
else. Hold **Ctrl** (**Cmd** on a Mac) while you make it, for example while
you pick *One row per group* in a PSTH's **Stack**, and the edit is made and
then the **Apply to figures** window opens: the other figures, or panels,
that can take the change, each with its value now, as the control shows it
(*Off (overlaid)*). Tick the ones to change and press **Apply**.

| Part | What it does |
| --- | --- |
| the table | one row per figure for a figure's setting (Appearance, Observations, the figure's event, window and selection, Sessions, the spacing); one row per panel for a panel's (an Option, the box, the axis sides, the panel's own alignment, the text note's look), with the panel's id and type. Only those that can take it are listed: a panel whose type has the option and takes the value (a stack of *One row per channel* only on continuous panels; a baseline mode only where the type offers it; a type's own option, a PSTH's **PSTH as**, only on panels of that type), the selected figure's other panels too. A row that has the value already is gray, marked *(has it)*, and cannot be ticked |
| **All**, **None** | tick every row that can change, or none; the count says how many will |
| **Replot the changed figures now** | unticked (the default), nothing is drawn again: the changed figures, and the one shown, are marked out of date in the tree (amber), and each is drawn when you show it or press Preview. Ticked, the figure shown and the changed figures that have a kept drawing are drawn again at once, one after the other (each shown in turn, then the figure you were on); a session figure still waits for Preview |
| **Apply** | gives the ticked rows the value, as one step of the undo history (**Undo Stack to 3 panels**), its own apart from the edit itself; the status bar names each panel or figure changed |
| **Cancel** | the edit stays with its own figure, which is drawn as after any edit |

The ticks are remembered for the next time, with the Replot box (and kept
with the app's preferences): a figure or panel ticked last time is ticked
again, one unticked stays unticked, and one never listed before is ticked.

What stays with each figure is never offered: its id, title and enabled, a
panel's title, axis label texts, place and size, its layers, overlays and
note text, the grid's rows, columns and their sizes, and the looks
remembered from the preview. An edit of one of those made with Ctrl held
opens no window; the status bar says it stays with its figure. A field of an
event reference, window or selection given to a figure (or panel) that uses
the Defaults' (or its figure's) makes it its own, the one it used with that
field changed, as editing the row in that figure would.

**Edit → Apply last change to figures...** (**Ctrl+Shift+A**) opens the same
window for the last edit of the figures, so you can decide after the edit,
for a value typed in a field, or to give an edit already applied to more
figures (an Apply is skipped back over to the edit it gave). It says so on
the status bar when that edit was changed again since.

`onApplyToFigures` does it: `EphysAnalysisConfig.figureEditChanges` names
what the edit changed, `changeTargets` lists the figures and panels that can
take it (`panelTakes`, the rule **Apply to all panels** follows too) and
`applyChanges` gives it to those ticked.

#### Copy settings to other figures or a design

**Copy settings...** under the figure list copies a figure's settings, as
many or as few as you tick, onto other figures, or its look into a plot
design. Where [Apply to figures](#apply-a-change-to-other-figures) gives one
edit to others, this gives a figure's settings as they are now.

| Part | What it does |
| --- | --- |
| **From** | the figure copied from, any of them (the one selected first), by id and panel count. Another one lists its settings and the other figures |
| **Copy to** | *The figures ticked* (the list at the right), a design of yours (*Design: Lab look*) or *A new design*, named in **New design's name** (one of yours of that name is replaced) |
| the settings | a tree of check boxes, one per setting, each with its value now (*Font size = 9*), under the parts: *Observations* (each field: the data observed, the unit filter, the channels, starred only, once per trial group), *Alignment* (event reference, epoch window, trial selection), *Arrangement and panels* (*Grid and panels*: the grid with every panel, its type, options, own alignment and layers, panel ids too; *Spacing between panels*: the spacing and custom gaps), *Panel settings* (per panel of the figure, its settings in groups: *Axes and limits*, the box, axis sides, y-limits mode, y and color limits, y ticks, scale; *Colors and lines*; *Display and stacks*; *Marks and insets*, first spike, latency box, unit waveform; *Data and analysis*, every other option; *Size and alignment*, its size and place in its cell, its own event, window and selection, its note's look), *Appearance* (the Style fields in groups: *Lines and error bands*, *Colors*, *Text and legend*, *Marks*, *Sorting and labels*), *Remembered looks* (each look, one by one) and *Across sessions* (each field). Ticking a part or a group ticks everything under it. Into a design only what a design holds is shown: the group colors (unless *lines*), the heat colors (when set) and each remembered look |
| **Find** | shows only the settings whose name, group or value holds the text (*limits*, *color*); the ticks of those it hides stay, and copy |
| **All**, **None**, **Expand**, **Collapse** | tick every setting shown or none; open or shut every part and group |
| **Copy onto** | a check box per other figure (the one selected is marked *shown*), with **All** and **None**: one or many. The count says how many settings go onto how many figures |
| **Copy** | gives the figures ticked the settings ticked, as one step of the undo history (**Undo Copy settings from PSTH units to 3 figures**); the status bar names them. Only the figure shown is drawn again, when it changed, as after any edit (Auto); the other figures changed are marked out of date in the tree (amber) and drawn when you show them |

A setting goes where it fits. The figure's settings go to each figure as
they are (an event reference the figure uses from the Defaults becomes its
own when one field of it is copied, as with Apply to figures). A remembered
look is added to the figure's own, replacing the look it covers. A panel's
setting goes to the panels of each figure that take it, as Apply to figures
decides it (an option the panel's type has and takes the value of: a PSTH's
y limits only to PSTHs; *fixed* y limits to another type only when it has
limits of its own): a panel takes the settings of the panel copied from
with its id and type, else of the first panel of its type, else of the
first panel that gives it one. With *Grid and panels* ticked too, the
panels are copied first and the panel settings then have nothing left to
change.

Into a design, the figure's group colors become the design's (a colormap's
name: its sequential colors and a palette of 7 sampled from it; one color:
its single color and palette), its heat colors the design's heat colors,
and each remembered look ticked a rule of the design's, for every plot. A
new design starts from the design chosen now. Nothing is drawn again unless
it is the design chosen; choose it in the Design list to draw in it.

The ticks are remembered while the app is open: a setting left unticked
starts unticked next time (a panel's setting by its panel type), and the
figures ticked are ticked again.

`onCopyFigureSettings` does it, with the window `private/copySettingsDialog`:
`analysis/figureSettingItems` lists a figure's settings (under
`figureSettingParts`), `analysis/copyFigureSettings` copies them over Apply
to figures' `changeTargets` and `applyChanges`, and
`analysis/figureLookToDesign` puts a figure's look into a design.

<a name="remembered-panel-options"></a>

#### Remembered panel options

The app remembers the options you set on a panel, per panel type: a PSTH's
**Y limits** *Shared by rows*, its stack spacing, a raster's **Tick width**,
every option of the Options section (and the first-spike and latency box
windows). A new panel of that type starts from them, over the type's
defaults: one from **New panel...** (its window's key parameters show them)
and so the first panel of a figure from **Add**. They are a preference of
yours, kept with the app's (`PanelOptions`), not part of any config: the
panels you have keep their options, and a config opened elsewhere is drawn
as saved. Only what you set is remembered (the other options keep the
type's defaults), and only by editing a panel: a panel added, removed or
given another type, Undo and Redo remember nothing, and a panel whose type
changes (**Type**) keeps its own values, not the remembered ones (it is not
new).

Options that name things of one dataset or one figure are left out: a
raster's sort by an event (and that event), the trial group shown (**Group
shown**) and a spectrum's or coherence's recording range. A sort by a trial
parameter (**Sort rows by**) and a tuning curve's **Parameter** and
**Series** are remembered, but a new panel takes them only when the active
dataset has that parameter; elsewhere they start blank. A remembered value
the type no longer has, or of another kind (a preference written by older
code), is not used.

**Edit → Reset panel options to defaults** gives the selected panel its
type's default options (its layers, place, title and note stay), as one
step of the undo history (*Undo Reset panel options*), and forgets what is
remembered for its type, so the next new panel of the type starts from the
defaults too. **Edit → Forget remembered panel options** forgets every
type's at once; it changes no panel. A script's `onNewPanel(Type=...)` uses
the type's defaults unless it passes `Remembered=true`.

<a name="picking-a-color"></a>

#### Picking a color

Every color field of the editor has a swatch at its right: a layer's
**Color** and an event's **Mark color**, a raster's **Colors** (ticks,
bands), an event-trace panel's **Bar outline** and **Baseline**, a text
note's **Colors** (text, ground), an overlay's **Color**, **Fill** and
**Outline**, the Appearance's **Group colors** and the error band's **Band
fill** and **Band edge**, and the **Color** of the First-spike latency and
Latency box plot windows. The swatch shows the field's color (a word such as
*groups*, *auto* or *none*, which names no one color, shows *...*) and is
grayed with the field. Click it to open MATLAB's color chooser
(`uisetcolor`) on that color: the color picked goes into the field as
`#rrggbb`, as if typed, one step of the undo history named after the row
(*Undo Colors*); Cancel changes nothing. The field still takes a name
(*red*, *gray*), a code or a word typed. The swatch is `private/colorSwatch`
(`syncColorSwatches` keeps it in step); the chooser is the app's
`ColorPicker` property (`@uisetcolor`; the tests put a function of their
own in its place, as the chooser is modal).

#### Sessions in the Figures tab

The **Sessions** section of the editor (in the FIGURE supersection, above the Arrangement; collapsed until opened, no key)
makes the selected figure a *session figure*: drawn **once across several
datasets** instead of once per dataset, an observation computed on every
session and each panel's layers merged, a color per session or subject. The model, the
matching and the merge are under
[Session figures](EphysAnalysisConfig.md#session-figures). The rows:

| Row | Effect | Config field |
| --- | --- | --- |
| **Across sessions (one figure over several datasets)** | ticked, the figure is a session figure: Generate and Run draw it once across the datasets and write it to the sessions folder; the Export tab's Run no longer draws it per dataset | `sessions.enabled` |
| **Datasets** | *The ticked datasets* (those ticked to run on the Data tab) or *These datasets*, a list of their own. **Generate selected figure** draws across the listed datasets whether or not they are ticked; the Export tab's **Run** still needs at least one ticked dataset before any session figure runs | `datasets` |
| **Keys**, **Pick...** | with *These datasets*: the keys (read-only), and the window that picks them from the scanned datasets (**Use**, **Name**, **Subject**, **Date**, **Key**, pre-ticked from the figure's keys: [Picking the datasets](#picking-the-datasets-and-editing-the-mapping)). **OK** writes the keys, and the observation list and the preview follow; **Cancel** changes nothing | `datasetKeys` |
| **Figures** | *One for all the sessions* or *One per subject* | `facet` |
| **A color per** | *Session*, *Subject (its sessions averaged)* or *Nothing (all sessions averaged)* | `series` |
| **Colors** | *The design's palette*, or *By date (sequential)* | `colorOrder` |
| **Show each session faintly under its mean** | with a color per subject or one mean: each session's own trace, pale | `showMembers` |
| **Error band** | with a color per subject or one mean: *mean ± SEM*, *mean ± SD*, *95% CI* (Student's *t*; Statistics and Machine Learning Toolbox, else 1.96 × SEM) or *None* | `error` |
| **Units matched by** | for a unit observation: *Site* (the unit's recording channel; a session with several units on it draws the first in probe order) or *Mapping* (a table names each cell's units). A channel observation matches by recording channel and the dataset one needs no match, so the row hides | `match` |
| **Mapping file**, **Browse...**, **Edit...** | with *Mapping*: the CSV, the file dialog and the table editor ([below](#picking-the-datasets-and-editing-the-mapping)), for the figure (its columns are the keys the figure lists, or the ticked datasets'; saving sets the box and sends the preview *Out of date*) | `mappingFile` |
| **Min. sessions** | an observation is drawn only when at least this many sessions hold it, and each figure of a trial group only when at least this many hold that group | `minSessions` |
| **Trial groups** | *Pool them (a color per session)*, *A figure per group* or *Combine (a line style per group)* ([trial groups](EphysAnalysisConfig.md#trial-groups-in-a-session-figure)) | `trialGroups` |

A gray note under the rows says what Generate and Run draw it for (*each
recording channel with a unit (a site)*, *each cell of the mapping file*, *each
recording channel* or *the datasets together*) and which of the figure's panels
are not merged across sessions. With **Across sessions** unticked only the box
shows; ticked, every row does (the keys with *These datasets*, **Units matched
by** for a unit observation, the mapping rows with *Mapping*), the error band
and the faint sessions are enabled unless there is a color per session, and
the Observations section's **Per trial group** row hides (the trial groups
follow **Trial groups**).

**The preview.** A session figure ignores the active dataset: the **Dataset**
drop-down is grayed out and the figure is drawn over the ticked (or listed)
datasets.

- The **Observation** list holds what is matched across them, each entry ending
  *(across 3 sessions)*, and the count line says how many (*"12 sites matched
  across 2 sessions (at least 1 each)"*; for a dataset figure *"The datasets
  together: one figure across 2 sessions."*; with no dataset ticked or listed, it
  asks you to tick some). A list that cannot be matched (an unreadable mapping
  file) says why there and in the preview.
- **Preview**, or a pick in the list, computes that observation on every
  session and merges it (`EphysAnalysisRunner.computeSessionFigure`), with the
  card and its **Cancel** as for any preview. An **edit does not recompute** it
  (the sessions are all read): the preview goes *Out of date* and says *"A
  figure across sessions computes every session: press Preview to draw it."*
  The Auto box does not apply to it. Unticking (or ticking) a dataset on the Data tab,
  when the figure draws across *The ticked datasets*, builds its observation list
  again for the datasets ticked now and marks a drawn preview *Out of date* (it was
  drawn over the old datasets, and the kept figures are forgotten).
- **Figure:** a drop-down at the right end of the line under the preview, shown
  when the observation makes several figures (one per subject, or per trial
  group), picks which of them is drawn. They are all kept, so picking another
  draws it without computing; the pick is kept by its label through the next
  Preview. The kept figures are forgotten, and the drop-down hidden, when
  another figure is selected or this one is edited, so an entry never redraws
  a result that is no longer current (press **Preview** again). A figure that
  could not be made (too few sessions drew it, or hold the trial group) is
  *Cannot draw*, with the reason.
- The line under the preview reads *"card, site ch 7 -320 µm across sessions: 3
  merged, 1 skipped (SYNTH-02 2026-09-09: no site ch 7  -320 µm here) (4.2 s);
  right-click to change colors, lines and fonts"*. The right-click editor
  works as for any figure.
- A panel type that cannot be merged (probe map, unit correlation map, power
  spectrum, spectrogram, coherence) is noted in the preview and the rest of the
  figure is drawn; Validate refuses such a figure and Plan and Run skip it as a whole.
  An event-trace panel is merged: it draws every session's epochs (overlaid, or
  a sub-row each), the sessions (or subjects) as its groups.

**Generate and Run.** **File → Generate selected figure** draws the selected session figure as
`run(SessionFigures=<id>)`, with no per-dataset figures or report: a
page per matched observation (or per figure of a facet and trial group) into
`Export.SessionsFolder`, named as a figure's observations are, with `{Name}`
the facet (a name this run already wrote gets `_2`, `_3`, ...). With *These
datasets* it draws across the listed ones whether or not they are ticked (it
says so when none is scanned). The status bar reads *"Generated card across the
sessions: all: 12 observation(s); 24 file(s) in D:\EPHYS\...\sessions"*, with an
entry per facet (and trial group), such as *"SYNTH-01: 12 observation(s),
SYNTH-02: 9 observation(s); 36 file(s) in ..."*, followed by
*"; not drawn: ..."* with what was skipped or failed and *"; card is off, so it
was switched on for this run only"* when it was. The Export tab's results table
gets a row per figure (`Dataset` `sessions: all`, a subject, or a subject and
trial group; `Kind` `figure`; `<n> observation(s)`), and **Open figure
folder**'s tooltip names the sessions folder. The Export tab's **Plan** lists a
row per session figure and facet, and **Run** draws the enabled session figures
after the datasets' own figures.

#### Picking the datasets and editing the mapping

**Pick...** opens a window over the scanned datasets in date order: a table
of **Use**, **Name**, **Subject**, **Date** and **Key**, pre-ticked from the
figure's keys, with **All** and **None**. **OK** writes the keys (and
the **Keys** box) and the figure goes *Out of date*; keys the scan
lacks are dropped, and the window says how many. **Cancel** leaves them.

**Browse...** picks the mapping file; **Edit...** opens it in a table, a
row per cell. The window's columns are `cell` and one column per included
dataset, headed by its key: the keys the figure lists, or, with *The
ticked datasets*, the ticked ones in date order. Type a cell's name and,
under each dataset, the unit id(s) it has there (a number, or `3 7` for two
units that are averaged; blank when the cell was not found). **Add row**
adds an empty cell, **Remove row** drops the rows of the selected fields,
**Save** writes the CSV and **Cancel** discards the edits. **Save** refuses a
row with ids but no name, and two rows of one name, and leaves the window
open. Columns of other datasets that the file already holds are kept, matched
to the rows by cell name (a cell renamed here loses its ids in those
columns). An empty **Mapping file** box asks for a path first
(`unit_mapping.csv` beside the config is offered). Saving sets the box and
sends the preview out of date. The format:
[Unit mapping CSV](file-formats.md#unit-mapping-csv).

### Epoch diagram

The epoch diagram draws how an event reference, epoch window and trial
selection cut the active dataset into epochs. It gets the epochs from
`epochTable`, as `figureCompute` does, so they are exactly the figure's
epochs. It redraws on every edit, on a change of the active dataset, and
when a config is opened. It shows in two places:

- the [Alignment tab](#alignment-tab) draws it right of the epoch count,
  for the defaults;
- **Epoch Diagram**, under the Epoch window in the figure editor, opens it
  in a window for the selected figure (`onShowEpochs`): the figure's own
  values or the defaults, the baseline windows of its panels, and what it
  drops; a figure with no panel aligned to events says it has no epochs.
  The window is not modal: it stays above the app while you edit, follows
  a change of figure, and closes with the app.
Top to bottom:

| Part | What it shows |
| --- | --- |
| heading | the figure and the dataset, and whether the event, window and selection are the figure's own or the defaults |
| the rule | in words, e.g. *Time 0 is the first Stim onset in each trial. Each epoch runs from 0.2 s before it to 0.8 s after it. Trials kept: pairing ok; grouped by Depth.* |
| the count | how many epochs there are, from how many trials. It also gives how many trials the selection leaves out, and how many events are dropped and why: no stop event, outside the recording, or touching an artifact period; and how many were left out before, for lacking the **Shift by** value or because their sequence did not follow. When there are no epochs, the count is red and says why |
| **The recording** | a stretch of the recording, one row per digital line involved, each drawn as its TTL trace: **Trials** (each trial in its group's color, or blue without groups; the ones the selection leaves out gray), the event's line (**▲ event**) and the stop event's line (**▼ stop**). With an event **Sequence**, every line of it gets a row (*· sequence*), ▲ sits on the step time 0 is aligned to, and ○ marks where the sequence starts, joined to the ▲ by a dotted line. ▲ marks the edge each event is picked at. A line in the event's group color runs through every row at time 0. An event moved by **Offset** or **Shift by** has an arrow from its edge to time 0. The stop event is ▼ with a dotted line. Each epoch's window is shaded across the rows and drawn as a bar on the **Epochs** row, numbered `#1`, `#2`, ... as the figure numbers them. An epoch the figure drops is gray and dashed, with ✕ and the reason. Under each bar is the baseline; on the event's line, the **Time range** searched (yellow); behind everything, the artifact periods (red; paler when shorter than the selection's **at least (s)**, so they exclude nothing) and the stretches outside the recording (gray). A legend under the axes names each mark |
| **Aligned to the event** | the same epochs, one row each, on the time from their event: the window, the event's line as the epoch sees it, the stop event (▼) and the baseline, with dashed lines at *pre* and *post*. This is what the figure stacks and averages |
| **◀ Previous**, **Next ▶**, **Show** | step through the events, and set how many to draw at a time (5 by default). The axes' toolbars zoom and pan |

A value that gives no epochs is reported in red, and the lines are still
drawn, so you can see why. Examples: a fixed window with *pre* after
*post*, a line the dataset lacks, or a scope it cannot use.

### Export tab

<!-- wiki: ![Export tab: figure files, the report, and a finished run's results](images/analysis-export-tab.png) -->

**Figure files** (config `Export`):

| Control | Meaning | Default |
| --- | --- | --- |
| **Write figure files** | export each [figure's](#figures-tab) observations (`Enabled`) | on |
| **Formats** | any of `png`, `eps`, `svg`, `pdf` | png, svg |
| **Folder**, **Browse...** | a folder pattern with `{OutputFolder}` (each dataset's output folder), `{OutputRoot}`, `{Root}`, `{Name}`, `{Date}` | `{OutputFolder}\analysis` |
| **File names** | a file-name pattern with `{Name}` `{Plot}` `{Kind}` `{Group}` `{Unit}` `{Index}` `{Date}`. A figure writes a file set per observation ([Exported figure names](file-formats.md#exported-figure-names)): `{Plot}` is its id, `{Unit}` the observation's short label (`su12`, `ch7`, `dataset`), `{Index}` its number, and `_<Unit>` is added when the pattern names neither ([Figures in an export](EphysAnalysisConfig.md#figures-in-an-export)) | `{Name}_{Plot}` |
| **Dpi (png)** | the PNG resolution | 150 |
| **Overwrite existing** | off: a page whose files all exist is not written again | on |
| **Size (cm)** | the figure's width and height (a page of many tiles is made taller, and a figure's page grows with its rows: 3.5 cm each plus 2 cm); a figure with a [size of its own](#the-page-a-figure-is-exported-on) keeps that | 18 × 12 |

**Report** (config `Report`):

| Control | Meaning | Default |
| --- | --- | --- |
| **Write a report**, format | *HTML (one self-contained file)*, *PDF (multi-page)* or *HTML and PDF* | on, HTML |
| **Title** | `{Name}` = the config's name, `{Date}` = today | `{Name}` |
| **Folder**, **Browse...** | folder tokens as above | `{OutputRoot}\analysis` |
| **File name**, **One per dataset** | `.html` / `.pdf` is added; one report per dataset is named `<FileName>_<dataset>` | `analysis_report`, off |
| **HTML images**, **Dpi** | PNG (base64) or inline SVG in the HTML; the PNG resolution | png, 110 |
| **Summary tables**, **Figure parameters**, **The config** | what the report holds besides the figures | all on |

**Running**:

| Button | Effect |
| --- | --- |
| **Validate** | lists the config's issues (Section, Field, Severity, Message) in the table; errors stop a run |
| **Plan** | one row per ticked dataset and [figure](#figures-tab) (Dataset, Subject, Date, Plot, Kind, Source, Enabled, Reason): `Plot` its id, Kind `figure`, Source what it is drawn for (`unit`, `channel` or `dataset`), Enabled whether it will run, and the Reason, why not ([skip reasons](#why-is-my-figure-skipped): no sorted units, no LFP extract, no line X, ...); then one row per [session figure](#sessions-in-the-figures-tab) (Dataset `sessions: all`, or `sessions: <subject>`; a figure with *Across sessions* ticked is listed there and not per dataset). Every figure is listed, enabled or not. Cheap: no signals or spikes are loaded, so a unit filter or channel list that leaves nothing to draw shows only when the figure runs. The status bar counts the rows that will draw: *"Plan: 4 of 6 figure run(s) and 2 of 2 session figure run(s) will draw."* (a row whose Dataset starts `sessions: ` is a session figure run; the session part is left out when the plan lists none) |
| **Export preview** | the Figures tab's selected figure, for the observation picked there, written as **Run** writes it (size, formats, dpi, file name) into a preview folder and shown in a window: a spot check of these settings before a run, without writing to the figure folder ([Figures tab](#figures-tab), **Export preview**) |
| **Run** | validates, then runs every enabled figure on every ticked dataset, and then every enabled [session figure](#sessions-in-the-figures-tab) over them, with a cancelable progress dialog: compute, export, report. A figure is drawn once per observation (a unit, a channel or the dataset), a page each, and the dialog names the observation (`<dataset>: <figure> (3/12)`) and, once 1% of the run is done and 5 s have passed, the time left (`<dataset>: <figure> (3/12) · about 4 min left`); writing the report shows its sections and pages (*Writing the report: page 3/12*) in a share of the run of its own. A failing figure is an error row and the rest still run. **File → Generate selected figure** is this run for one figure alone, with no report ([Figures tab](#figures-tab)); its rows land in this table |
| **Cancel** | stops before the next figure observation; what is left (the rest of that figure's observations too) is *canceled*. It also stops a Generate selected figure, which is a run, and the Figures tab's **Redraw All** |
| **Open report**, **Open figure folder** | after a run: the report files written, and the first dataset's figure folder. After a run with session figures the button's tooltip names the sessions folder (`Export.SessionsFolder`) too; the button itself still opens the first dataset's folder |

The results table has one row per dataset and figure: `Dataset`, `Subject`,
`Date`, `Plot`, `Kind`, `Status` (`done`, `skipped`, `error`, `canceled`), `Message`,
`Files`, `Seconds`. A figure's row has `Kind` `figure` and, when it is done,
`<n> observation(s)` as its `Message` and every observation's files in `Files`;
it is `skipped` with the reason, or with `no observation` when its unit filter or
channel list leaves nothing. The label above it counts each status. A session figure's
rows read `sessions: all` (or `sessions: <subject>`, or `sessions: <subject> /
<trial group>`) in the `Dataset` column, with the Subject and Date blank, and
list its figure files and, with `Export.Data.Enabled`, its data file.

### Log tab

What the scans, previews and runs reported, one time-stamped line each
(the last 2000 lines are kept): the datasets found, each figure done with its
file count and time, the figures skipped with the reason, a version 1 config's migration notes, failures with the
error, and the report files written.

### Favorites

A plain star (on or off) marks a dataset, a channel or a sorted unit you want
to find again. Stars are kept **beside the data**, one small file per dataset,
`<Name>_favorites.json` in its output folder (where its `<Name>_*.mat` outputs
are; [the file](file-formats.md#favorites-name_favoritesjson)), so they travel
with the data to the lab's share, another PC or another user, and the config
holds none. **Scan** reads them; each toggle writes its file at once.

| Where | What it stars |
| --- | --- |
| Data tab, **★** column | the dataset of that row |
| **☆** right of **Dataset** (Alignment and Figures tabs) | the active dataset |
| **☆** right of **Observation** (Figures tab) | what the preview shows: a sorted unit, a channel (a detection channel is starred as its recording channel, so the star shows on its LFP, MUA and SPIKE channels and on its detections alike), or the dataset for a figure of the dataset |

A unit's star belongs to the **sort** it was set on: the file records the
sorting folder (relative to the output folder) and the size of its
`spike_times.npy` with the cluster ids. When the dataset is sorted again --
into another folder, or over the same one with other spike times -- the old
stars stay in the file but mark none of the new sort's units, so a star never
jumps to another unit; curating in phy keeps `spike_times.npy`, so units it
leaves alone keep their stars (merged or split units get new ids and none).

Starred items start with **★** in the Dataset and Observation drop-downs and
are ticked in the Data tab's **★** column. **Favorites** (Alignment and Figures
tabs) lists every star of the scanned datasets, in dataset order: *subj1_day1*,
*subj1_day1 · channel 5 · 850 µm*, *subj1_day1 · unit 12 · su · ch 5 · 850 µm*.
A unit's class, channel and depth and a channel's depth show once its dataset
has been opened this session (its units and probe map are then in memory;
nothing is read just to label the list), so a dataset not opened yet lists
*subj1_day1 · unit 12* until you open it. Type in the filter field
left of it to narrow the list as you type (every word must appear, in any
case: *day2 unit*). Picking an entry makes its dataset active; a unit or
channel is then picked in the Figures tab's **Observation** list when the
selected figure observes that kind -- drawn at once on the Figures tab, waiting
for it from the Alignment tab -- otherwise the status bar says why it is not
(the figure observes something else, or its Observations filter leaves it out).

A figure across sessions marks a matched observation **★** when it is starred
on any of its sessions (for a site, any unit on it). **Starred only** in the
Observations section draws a figure for the favorites alone, and the report
captions say how many observations are starred (*12 observations (sorted
units; 3 starred)*) or that the figure keeps the starred only.

A dataset whose output folder cannot be written (a read-only share, a folder
that is gone) keeps its stars as they were: the toggle goes back and the status
bar and the Log say why. A favorites file that cannot be read gives no stars
and is never written over (the Log names it). Reports and data exports carry
the stars ([Favorites in exports](EphysAnalysis.md#favorites-stars)). Scripts
read and set them with `DatasetFavorites`. The pipeline app does not show them
yet.

### Notes

A note is free text you keep with a dataset, a channel or a sorted unit: what
went wrong in the session, why a channel is noisy, what a unit looked like.
Like the stars, notes are kept **beside the data**, one small file per dataset,
`<Name>_notes.json` in its output folder
([the file](file-formats.md#notes-name_notesjson)), so they travel with the
data and the config holds none. **Scan** reads them; the notepad writes them.
They are not phy's notes: the pipeline app's Review tab writes those into
`cluster_notes.tsv`, a file of the sort's own.

| Where | What it opens |
| --- | --- |
| Data tab, **✎** column | the note of that row's dataset (the row becomes the active dataset) |
| **✎** right of the **☆** of **Dataset** (Alignment and Figures tabs) | the active dataset's note |
| **✎** right of the **☆** of **Observation** (Figures tab) | the note on what the preview shows: a sorted unit, a channel (a detection channel's note is its recording channel's), or the dataset for a figure of the dataset |

Each opens the **notepad**, a small window that stays above the app. It names
what the note is on (*subj1_day1 · unit 12*), holds the note in a text box and
says under it where the note is kept and when it was last written. It follows
the button that opened it: pick another dataset, or another observation (with
**<** and **>** too), and it moves there, so you can step through the units of a
dataset writing a line on each. The note is written when you leave the box,
press **Save** (or Ctrl+S), move to another note or close the window (or Esc):
nothing is lost by moving on. Empty the box to remove a note.

A unit's note belongs to the **sort** it was written on, as a star does: a new
sort shows none of the old notes on its units, but keeps them in the file, and
**Search notes** still finds them. A button with a note is **yellow**, with the
note's first line in its tooltip; datasets, units and channels with a note
show **✎** in the Dataset and Observation drop-downs (after any **★**), and the
Data tab's **✎** column marks the datasets.

**Search notes** (the toolbar) opens a window over every note of the scanned
datasets: on them, their channels and the units of their sorts. Type in its
search field and the list keeps the notes holding every word, in any case, in
the dataset's name, what the note is on (*unit 12*) or its text, as you type.
The **Note** column shows the line holding the first word; pick a row to read
the whole note under the list. **Go to** (or a double-click) opens the note's
dataset: it becomes the active dataset, and a unit's or channel's note picks
that unit or channel in the Figures tab's **Observation** list when the figure
selected there observes that kind (as **Favorites** does; the status bar says
why not, otherwise). A note on a unit of an older sort goes to its dataset only.
**Edit note** opens the note picked in the notepad, which then stays on it.

A note that cannot be written (a read-only share, a folder that is gone) stays
in the notepad's box, and the line under it says why; closing the window then
asks for a second close before the text is dropped. A notes file that cannot be
read cannot be edited (the Log names it) and is never written over. Scripts
read and write notes with `DatasetNotes`.

## Panel types

A figure's panels are of the thirteen types of `EphysAnalysisConfig.panelTypes()`;
the Figures tab's **New panel** window offers all of them, each with a small
representative plot, and the Options
section shows the rows of the selected panel's type
([Options](#figures-tab) above).

| Type (label) | Draws |
| --- | --- |
| `raster` (Raster) | a row per epoch for the observed unit, by trial group, with event marks |
| `psth` (PSTH) | the peri-event rate per trial group, overlaid or stacked, with an auROC baseline option |
| `continuous` (Continuous signal) | the epochs' mean of each LFP, MUA, SPIKE or AUX channel, with an error band |
| `heatmap` (Heat map) | units or channels (or one unit's epochs) by time in color |
| `waveforms` (Unit waveforms) | the observed unit's waveform, or every unit at its place on the probe |
| `probemap` (Probe map) | a value per probe site |
| `corrmap` (Unit correlation) | the pairwise correlation of the units' per-epoch rates |
| `rate` (Firing rate) | the rate in each epoch window per trial group: bars, boxes or points |
| `tuning` (Tuning curve) | the rate against a trial parameter, a curve per series |
| `spectrum`, `spectrogram`, `coherence` | multitaper power, spectrogram and coherence (Chronux) |
| `eventTrace` (Event traces) | digital or derived lines as a logic analyzer shows them: a row per line, bars or a logic level from each onset to its offset, epochs overlaid or a sub-row each |

What each draws, its layers and its options are on the config page
([Panel types](EphysAnalysisConfig.md#panel-types), [Panel
options](EphysAnalysisConfig.md#panel-options)); how the numbers are computed:
[Compute](EphysAnalysis.md#compute).

<!-- wiki: ![A unit's raster over its PSTH, groups by Depth](images/analysis-example-unit-card.png) -->

<!-- wiki: ![A heat map of the units' response, one tile per Depth group](images/analysis-example-heatmap.png) -->

<!-- wiki: ![Unit correlation matrices, one per Depth group, on the blueWhiteRed scale](images/analysis-example-corrmap.png) -->

## Menus

| Menu | Item | Effect |
| --- | --- | --- |
| File | **New config** (Ctrl+N) | an empty default config |
| | **Open config...** (Ctrl+O), **Open recent** | an analysis config JSON; the last 8 are listed. The config's load warnings (dropped unknown fields; for a version 1 file, the notes of its migration to figures) go to the status bar and, one line each, to the Log tab; the status bar's first line then reads *config version 1: N of M plot(s) and ... migrated to figures; saving writes version 2*, and saving writes version 2 ([Loading a version 1 config](EphysAnalysisConfig.md#loading-a-version-1-config)) |
| | **Save config** (Ctrl+S), **Save config as...** | writes the config JSON. The first save offers `analysis/analysis_configs` when that folder exists, else the `analysis` folder |
| | **Generate script → Compact (loads the saved config)...** | a short script that loads the saved JSON and runs the runner; unsaved changes are saved first (it asks) |
| | **Generate script → Standalone (every setting written out)...** | a script that needs no config file and never uses the runner ([Scripts](EphysAnalysis.md#scripts)) |
| | **Open pipeline app** | launches `EphysPipelineApp` |
| | **Close** | asks about unsaved changes, cancels a run under way, closes |
| Edit | **Undo** *edit* (Ctrl+Z) | takes back the last edit of the figures ([Undo and redo](#undo-and-redo)); the item names it (**Undo Add panel**, **Undo Bin (ms)**) and is grayed with nothing to undo, or off the Figures tab |
| | **Redo** *edit* (Ctrl+Y, Ctrl+Shift+Z) | does the last edit undone again; grayed with none |
| | **Apply last change to figures...** (Ctrl+Shift+A) | offers the last edit of the figures to the other figures or panels that can take it ([Apply a change to other figures](#apply-a-change-to-other-figures)); on with Undo |
| | **Reset panel options to defaults** | the selected panel takes its type's default options, as one undo step, and the options remembered for its type are forgotten ([Remembered panel options](#remembered-panel-options)) |
| | **Forget remembered panel options** | new panels start from their types' defaults again; no panel changes |
| Design | the designs | Default, the built-in designs, then yours (*(mine)*); the one chosen is ticked. Picking one redraws every figure on screen in it ([Plot designs](EphysAnalysis.md#plot-designs)); the Figures tab's **Design:** list is the same choice |
| | **Save the preview's look as a design...** | asks for a name and a description, saves the Figures tab's figure preview's look in your designs folder (read per panel type) and picks it (asks before replacing one of yours) |
| | **Import a design file...** | copies a design `.json` into your designs folder and picks it |
| | **Delete one of my designs** | deletes the file of the one picked (asks first); Default is chosen if it was |
| | **Open my designs folder**, **Keep my designs in...** | opens the folder; or keeps your designs in another, such as one the lab shares |
| | **Data tip fields...** | what the data tips of every figure show ([Data tips](#figures-tab)): a check box per field; your preference |
| Help | **Help for this tab** | the wiki page of this app, at the section of the tab shown (`helpURL`) |
| | **Figures tab keys** | a window listing every key of the Figures tab, as the **?** button over its editor does ([Keyboard](#figures-tab)) |
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
| Analysis config | the working config as the controls hold it now (name, file, unsaved edits, source and its roots, how many figures, how many enabled and how many across sessions, dataset counts, active dataset, selected tab, whether a run is going) and the whole config as JSON, written the way **Save config** writes it — **this carries your file paths** |
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
| Undo, Redo | Edit → **Undo** (Ctrl+Z) and **Redo** (Ctrl+Y) of the figure editor ([Undo and redo](#undo-and-redo)): the tooltip names the step (**Undo Add panel (Ctrl+Z)**), and a tool is on and off as its menu item, so on the Figures tab with a step to take |
| Scan for datasets | the Data tab's **Scan** |
| Search notes | opens the **Search notes** window over the notes of every scanned dataset ([Notes](#notes)) |
| Preview the selected figure | the Figures tab's **Preview**: shows the Figures tab first and lists the selected figure's observations, then previews the observation picked on the active dataset (a session figure over its datasets) with the preview forced, as **Preview** does; on the Figures tab it only redraws |
| Validate config, Plan, Run, Cancel run | the Export tab's buttons; Validate, Plan and Run show the Export tab first, where they list what they find. Cancel run also stops **File → Generate selected figure** and the Figures tab's **Redraw All** |
| Open the last run's report, Open the last run's figure folder | the Export tab's **Open report** and **Open figure folder** |
| Open pipeline app | File → **Open pipeline app** |
| Help for this tab | Help → **Help for this tab** |

Validate, Plan and Run are off while a run goes (a Generate selected figure included), and
Cancel run is on only then (and while Redraw All goes), as on the Export tab; the report and figure-folder tools come on when
a run has written a report or figures. The icons are
`analysis/icons/toolbar/<Tag>.svg`.

## Outputs

A run writes, for each ticked dataset and enabled figure:

- **Figure files**: one file per observation and format in the Export folder, by
  default `<output folder>\analysis\<Name>_<figure id>_<unit>.png` (and `.svg`);
  a figure with one observation, such as a dataset's heat map, is
  `<Name>_<figure id>.png`. Each page is drawn into an invisible classic figure of
  the export size, as tall as the figure's rows need.
- **The report**, by default `<output root>\analysis\analysis_report.html`,
  over every dataset (or one per dataset). The HTML is one self-contained
  file with a contents list, each dataset's summary tables and every figure
  with its caption, parameters and links to its files; the PDF has a title
  page, a summary page per dataset and every figure as vector pages
  ([Report files](file-formats.md#report-files)).
- **Session figures**, for each enabled [session figure](#sessions-in-the-figures-tab): one
  file per matched observation and format in the sessions folder
  (`Export.SessionsFolder`, by default `<output root>\analysis\sessions`), named with
  the file-name pattern, `{Name}` being the facet (`all`, or the subject), by default
  `all_<figure id>_site_ch7.png`, plus `_<trial group>` for a figure per trial group
  ([Exported figure names](file-formats.md#exported-figure-names)). The report gets an
  *Across sessions* section after the datasets: a table of the sessions and these
  figures.
- **Session figure data**, when `Export.Data.Enabled` is on: one `.mat` file per
  session figure in `Export.Data.Folder` (by default
  `<output root>\analysis\data\all_<id>.mat`; [format](file-formats.md#session-figure-data-mat)).
- **A run record**, `<report folder>/analysis_runs/<runId>_<name>.json`: the
  config, the code version, the machine and the results
  ([Run records](file-formats.md#run-records)).

Each figure's caption says what it shows, e.g. *unit_card: 12 observations (sorted
units: su, mua) of RAT1_260918; panels: raster, PSTH; aligned to Stim onset; window
[-0.2 0.8] s; groups by Depth.* The reports print it under each figure.

The app never changes the pipeline's outputs or manifests. The only file
it may write beside them is the units' quality-metrics cache
(`quality_metrics.json` in the sorting folder), when a figure keeps good
units only.

## Preferences

Group `EphysAnalysisApp`, kept through [`AppPrefs`](../pipeline/AppPrefs.m): MATLAB preferences, or the file
named by the environment variable `EPHYS_APP_PREFS_FILE` (the tests' temporary store). Everything else
is in the config.

| Preference | Meaning |
| --- | --- |
| `FigurePosition` | window position and size |
| `LastConfigFile` | the last config file opened or saved (**New config** leaves it): reopened at launch, and the config the app starts from when opened on a folder |
| `RecentConfigs` | File → Open recent (8) |
| `ScriptFolder` | where Generate script offers to save |
| `PreviewMaxMB` | signal extracts larger than this (default 500 MB) are previewed only with the Preview button. Set it with `AppPrefs.setpref('EphysAnalysisApp', 'PreviewMaxMB', 1000)` before opening the app |
| `FigureAutoPreview` | the Figures tab's Auto box (on by default: one observation is quick to compute). The time limit it applies, 2 s, is not a preference but the app's `FigureAutoPreviewSeconds` property |
| `FigureGroupBy` | how the figure tree groups (`observe`, the default; `status`; `none`) |
| `FigureGroupsCollapsed` | the figure tree's collapsed groups, by key (`observe:unit`, `status:Off`, ...); the selected figure's group opens whatever is kept |
| `FigureSectionsCollapsed` | the figure editor's collapsed sections (Text note, Overlays, Appearance, Looks and Sessions start collapsed) |
| `FigureSupersectionsCollapsed` | the figure editor's collapsed supersections (`figure`, `panel`, `look`; all start open) |
| `ApplyTicked`, `ApplySeen` | **Apply to figures**: the figures and panels ticked when it was last shown, and every one it has listed (`<figure id>`, `<figure id>/<panel id>`; one never listed is ticked) |
| `ApplyReplot` | **Apply to figures**: its **Replot the changed figures now** box (off by default) |
| `PanelOptions` | the options last set on a panel of each type, a struct by type (`psth`, `raster`, ...) of the options set: what a new panel starts from ([Remembered panel options](#remembered-panel-options)) |

The aesthetics editor keeps two more groups: `PlotAesthetics`, your
remembered rules, one per panel type (`psth`, `raster`, ...), one for `figure` and one per Chronux result kind, and
`PlotAestheticsDialog`, its **Remember** box and where it last remembered
(`Remember`, `Scope`). The plot designs keep `PlotDesign`: the design
chosen (`Design`) and your designs folder when you chose one (`Folder`). The data
tips keep `FigureDataTips`: the fields they show (`Fields`, the keys of
`FigureDataTips.fields`; missing = the defaults).

## Why is my figure skipped?

The runner's `figureSkipReason`, shown by the preview, Plan and the results (it
checks the figure, then each panel and enabled layer; a layer that cannot be drawn
is noted in its panel and the rest is drawn):

| Reason | Cause | Fix |
| --- | --- | --- |
| disabled | the figure's **Enabled** box is off (Generate selected figure and the preview still draw it) | tick it |
| no sorted units | the sorting folder holds no sorted units | sort the dataset, or associate its sorted-output folder ([Sorting](EphysPipelineApp.md#sorting)) |
| no detected spikes | the spikes file has no threshold detections | run the Spikes step ([Spikes](EphysPipelineApp.md#spikes)) |
| no LFP extract (MUA, SPIKE, AUX) | the Signals step did not write that signal | enable it in the pipeline's Signals step and run it ([Signals](EphysPipelineApp.md#signals)) |
| no paired trials | trial scope, the `Trial` line, a filter / response / trial list / group-by, an event or stop shifted by a trial parameter, or a tuning panel, on a dataset without paired trials | approve the pairing on the pipeline app's [Trials tab](EphysPipelineApp.md#trials) and write the behavior file; or align in recording scope without a selection |
| no line X | the event or stop line, or a line a raster or events layer marks, is not among the dataset's lines (in trial scope: among the lines seen in its trials) | check the line names on the Data tab |
| no trial parameter X | a group-by, shift-by, tuning, series or raster-sort parameter the trials lack | pick one from the dataset's parameters |
| no probe map | the manifest names no probe file and the dataset has no sort whose channel map could stand in (probe map and unit waveforms in the probe layout) | assign a probe on the pipeline app's [Probe tab](EphysPipelineApp.md#probe) |
| AUX has no recording channel: bind it to fixed channels | an AUX layer follows a unit, or a channel of another signal | make the layer fixed (the editor does so when the layer's source or the panel is edited) and name its channels, or leave them blank for every AUX channel |
| Chronux is not on the path | a spectrum, spectrogram or coherence panel | put `toolboxes/chronux` on the path |
| no observation | the figure's unit filter or channel list leaves nothing on this dataset | loosen the Observations section |

A [session figure](#sessions-in-the-figures-tab) is skipped, in Plan and the preview, when
(`figureSessionSkipReason`): it is *disabled*; *X panels are not merged across
sessions* (probe map, unit correlation, power spectrum, spectrogram or coherence);
*an auROC baseline is not merged across sessions*; with *Mapping*, there is
*no mapping file* or the *mapping file is not found*; or *fewer than N
session(s) can draw it*, followed by each session that cannot and its own
reason from the table above (`session label: no sorted units`). A session
figure that passes can still draw nothing when no site or cell reaches
**Min. sessions**.

A figure that is not skipped can still fail when it runs, e.g. *no Stim onset
event is left after the selection* or *none of the N events makes a usable
epoch (M with a window outside the recording)*: the message is in the
results, on the Log tab and in the report.

## Where the code is

| Part | Files |
| --- | --- |
| building | `buildUI`, `buildMenus`, `buildToolbar` (its icons in `analysis/icons/toolbar`), `buildDataTab`, `buildAlignTab`, `buildFiguresTab`, `buildExportTab`, `buildLogTab`, `buildAlignControls`; the editor's collapsible sections in `private/` (`formSection`, `formRow`, `formShow`, `formLayout`) |
| config model | `gatherConfig` / `applyConfig`, `gather*` / `apply*Section`, `gatherAlignControls` / `applyAlignControls`, `gatherFigureEditor` / `applyFigureEditor`, `onConfigChanged`, `updateTitle`, `confirmDiscard`; the undo history `onUndoRedo` (the Edit menu) over `analysis/FigureEditHistory`, fed by `private/recordFigureEdit` at each path that edits the figures, its labels `private/figureEditLabel`, its menu `private/refreshEditMenu` |
| data | `openSource`, `onScan`, `refreshDatasetsTable`, `selectDataset`, `refreshDatasetInfo` |
| favorites | `refreshFavorites`, `onStarToggled`, `onFavoritePicked`, `onFavoritesFilter`, `onDatasetsTableEdited` (the ★ column); `private/loadFavorites` (on Scan), `private/starItem`, `private/starButton`, `private/syncStarButtons`, `private/observedItem`, `private/buildFavorites`, `private/fillFavorites`, `private/favoriteMarks`, `private/markObservations`, `private/listFavorites` (the entries and their labels), `private/datasetSortKey`; the files: `analysis/DatasetFavorites.m` |
| notes | `refreshNotes`, `onNoteButton`, `onSearchNotes`, `onDatasetNoteClicked` (the ✎ column); `private/loadNotes` (on Scan), `private/noteButton`, `private/noteTip`, `private/syncNoteButtons` (from `syncStarButtons`; the notepad follows here), `private/openNotePad`, `private/noteMarks`, `private/noteEntries`, `private/goToNote` (over `goToFavorite`); the notepad `analysis/NotePad.m`, the search window `analysis/NoteSearch.m`, the files `analysis/DatasetNotes.m` (the sort a unit's note and star record: `analysis/private/sortIdentity.m`) |
| previews | `refreshAlignPreview` (the Alignment tab); the Figures tab's under its row below; `private/showPreviewState` (the badge and the busy card; its icons in `analysis/icons/status`) |
| epoch diagram | the window `onShowEpochs`, `refreshEpochDiagram`; the Alignment tab's `refreshAlignPreview`; the diagram itself is `analysis/EpochDiagram.m` (in a window, or `Parent=` a container) |
| Figures tab | `buildFiguresTab`; the tree `refreshFigureList` (over `private/figureGroups`), `onFigureSelected`, `onFigureTreeSelected`, `onFigureTreeClicked` (the check boxes), `onFigureGroupToggled`, `onFigureCheck` (All / None / Invert), `setFiguresEnabled`, `onAddFigure`, `onRemoveFigure`, `onDuplicateFigure`, `onMoveFigure` (Up / Down within a group); the Id row's automatic id `private/showFigureId`, and the renames followed by `private/trackFigureIds` and `private/followedFigureId`; a panel's text note and overlays `onAddFigureOverlay`, `onDuplicateFigureOverlay`, `onRemoveFigureOverlay`, `onFigureOverlayPicked` (the rows are `applyFigureEditor`'s and `gatherFigureEditor`'s); dragging a panel in the schematic `onSchematicPress` (with the pointer callbacks it installs), `cancelSchematicDrag` (also `onKeyPress`'s Escape) and `schematicPixel` (the tests');  the editor `gatherFigureEditor` / `applyFigureEditor`, `applyFigureEditorDefaults`, `syncFigureEditor` (what shows and what is enabled; what the drop-downs offer: `private/figureEditorChoices`), `layoutFigureEditor`, `onFigureSectionToggled`, `gotoFigureSection`, `onFigureSuperToggled`, `gotoFigureSuper` and `onKeyPress` (Alt+1 ... Alt+3, Ctrl+1 ... Ctrl+0, F6: `focusFigurePane`), the search `onFigureSearch` and `gotoFigureRow` (over `private/figureSearchIndex`, `private/figureSearchPath`, `private/figureRowReason`), the keys window `onFigureKeys`, the panel keys `stepFigurePanel` and the preview's outline `markFigurePanel`, `onFigureAlignEdited`, `onFigureDefaultToggled`, `onPanelAlignEdited`, `onPanelDefaultToggled`, `onPanelSelectionToggled` (the Trial selection as the figure box; local to `buildFiguresTab`); the arrangement `drawFigureSchematic`, `onPanelSelected`, `onNewPanel` (the New panel window `private/newPanelDialog`, its pictures `analysis/icons/panels`, made by `tools/makePanelThumbnails`), `onRemovePanel`, `onMovePanel`, `onPanelTypeChanged` (over `EphysAnalysisConfig.placePanel`, `removePanel` and `movePanel`; a structural edit ends in `private/commitFigureEdit`), the Spacing window `private/figureSpacingDialog`; the layers `onLayerSelected`, `onAddLayer`, `onRemoveLayer`, `onMoveLayer` (`private/layerLabel`); the preview `refreshFigureObservations`, `onFigureObservationChanged`, `onFigureObservationStep` (and `onKeyPress`: Page Up, Page Down), `refreshFigurePreview`, `autoFigurePreview`, `onFigureAutoPreviewToggled`, `onCancelFigurePreview`, `onOpenFigureWindow`, the page size `onFigureSizeEdited`, `showFigureSize`, `fitFigureViews` (over `private/figureViewBox`), `redrawFigurePreview` and `private/previewSpec` (over `figureExportSize`, `figureSizePresets`, `figureSizeParse`, `figureSizeText`, `figureSizeConvert`), a Ctrl+Click on a panel `onFigurePanelClicked`, `rememberFigureAesthetics`, `setFigurePreviewState` (over `private/showPreviewState`); each figure's own preview container `syncFigureView` (`private/newFigureView`, `private/previewFigureView`, `private/figureViewKey`, `private/figureViewFresh`, `private/clearFigureViews`, `private/showSessionPicker`), the tree's marks `private/markFigureTree`, the editor as each figure left it `private/saveFigureEditorState`, `private/restoreFigureEditorState`, `private/scrollFigureEditor`, its observation list `private/keepFigurePicker`, `private/takeFigurePicker`, `private/forgetFigurePickers`; the Sessions section `onPickFigureDatasets`, `onBrowseFigureMapping`, `onEditUnitMapping` (`private/editUnitMapping`, `private/unitMappingTable`), `private/pickSessionDatasets` and `onFigureSessionPicked` (its preview is `refreshFigurePreview`'s session branch over `EphysAnalysisRunner.computeSessionFigure`, its picker `refreshFigureObservations`'s over `sessionFigureObservations`); the Design row `onDesignChosen` and `onSaveDesign` (below); the epoch diagram window is `onShowEpochs` (the Alignment tab's diagram is `refreshAlignPreview`'s); the figures themselves are `analysis/` functions and `EphysAnalysisConfig` / `EphysAnalysisRunner` methods (`figureObservations`, `figureSkipReason`, `computeFigure`, `renderFigure`: [Figures](EphysAnalysisConfig.md#figures)) |
| copying figures | `onCopyFigureSettings` (the Figures tab's **Copy settings...**: `private/copySettingsDialog`, then `analysis/copyFigureSettings` over `analysis/figureSettingItems` and `analysis/figureSettingParts`, or `analysis/figureLookToDesign` into a design) |
| remembered panel options, color swatches | `private/rememberPanelOptions` (called by `private/recordFigureEdit`), `private/rememberedPanelOptions` (read by `onNewPanel` and the New panel window), `onResetPanelOptions`, `onForgetPanelOptions`; `private/colorSwatch`, `private/syncColorSwatches` (`buildFiguresTab`, `syncFigureEditor`, `private/latencyDialog`) |
| one edit to other figures | `onApplyToFigures` (Ctrl held: `onKeyPress` / `onKeyRelease` and `onConfigChanged`; Edit → Apply last change: the undo history), its window `private/applyToFiguresDialog`, over `EphysAnalysisConfig.figureEditChanges`, `changeTargets`, `panelTakes` and `applyChanges` |
| plot designs | `refreshDesigns` (the Design menu and list; `PlotDesign.listen` keeps them current), `onDesignChosen`, `onSaveDesign`, `onImportDesign`, `onDeleteDesign`, `onDesignsFolder`; the designs themselves: `PlotDesign`, `analysis/designs` |
| running | `onValidate`, `onPlan`, `onRunExport`, `onGenerateFigure` (**File → Generate selected figure**: `onRunExport` for the selected figure alone, then the status bar's text), `onCancelRun` (also stops a Generate and Redraw All) |
| files | `onNewConfig`, `onOpenConfig`, `openConfigFile`, `onSaveConfig`, `onSaveConfigAs`, `onGenerateScript`, `loadPreferences`, `savePreferences` |
| help | `onHelp`, `helpURL` (the wiki page and anchor of each tab; `tools/wiki/test_gen_pages.py` checks that the page made from this file has them) |
| issues | `onReportIssue`, `issueReport`, `issueURL`; the dialog, the address and the system lines are `pipeline/IssueReport.m`, shared with EphysPipelineApp |

## Tests

`test_EphysAnalysisApp` builds the app headlessly on the analysis fixture
(a small synthetic project run through the pipeline) and drives it through
its methods, in sections 0 to 6: the startup (1: built hidden, each tab, the
scan and the first dataset a step of the splash, which `-batch` leaves
unshown); the five tabs (Data, Alignment, Figures,
Export, Log); the toolbar (1b: its tools in groups with their icons, Undo and Redo following the Edit menu (5k),
every File menu shortcut named in a tooltip, Preview and Plan clicked from another
tab, the run and results tools following the Export tab's buttons); the scan;
opening on a list of datasets (`Datasets=`, as the pipeline app's Tools panel
does); the active dataset's lines and parameters, and its sorted units counted
in the Dataset drop-downs (the same items on the three tabs); the Help menu's GitHub issue
and feature request (1c); grouping by Depth from the Alignment controls, with the tab's epoch diagram (2);
and section 3, the Figures tab: the toolbar's Preview, pressed from another
tab, showing the Figures tab and drawing the selected figure; the header (the
buttons in a column at the left, a row each -- Preview, Redraw All, Unit report,
Auto, **<** **>** -- beside the Dataset, Observation and Favorites rows, Design
and Save look as design... right of Dataset and Observation; every button's
key named in its tooltip, and Ctrl+W, Ctrl+T and Ctrl+P pressing theirs); **Export code**
(left of Open in window under the preview: its script, run in a workspace of its
own, computes the same result as the preview, but for the time it was made,
and draws the same panels in a window of its own); the Design row
(the list and the menu, a design chosen redrawing the figure preview without
touching the config, **Save look as design...** from the figure preview, a
heat map figure's axes rules kept under the design's heat map kind, deleting a
design); the epoch diagram window (opened for the figure, redrawn on an
edit of its pre, *Use default* again, an edit of the defaults, closing);
and an event sequence for the figure's own event from the Event sequence
window (a bad step refused). Section 4 is the gather / apply round trip,
keeping the fields without a control (the stop event's offset, length and time
range, trial rows) and the stop's *n*; Save As, New (`LastConfigFile` kept),
reopen; a version 1 config opened (its plot migrated to a figure, the status
bar and the Log saying so); opened on a folder (a project with `Datasets=`, one
output folder: the last config, its source switched, unsaved; a quick look
when the last config cannot be read); and generating scripts. Section 5 is Validate, Plan and a run of one figure
writing its pages and the report (its lines in the Log tab). Sections 5d to 5h are
the Figures tab again, below. Section 5i is the [favorites](#favorites): the
star toggles beside Dataset (writing `<Name>_favorites.json` in the output
folder) and the observation (a unit, with its sort in the file; an LFP channel; a
detection channel, starred as its channel; the dataset), the Data tab's **★**
column, a new scan reading the stars back, the **★** marks in the drop-downs
(the pick kept by label, **<** and **>** following), the Favorites lists (a
unit's class, channel and depth once its dataset is opened, the short label
before) and their filter, **Starred only** (the starred unit alone, listed
again as stars change; an unstarred dataset; across sessions the starred
site marked and kept), picking a unit from the Figures and the Alignment tabs, the last
star removing the file, and an output folder denied writing (`icacls`): no star,
the toggle back off, the status bar saying why. Section 5j is the
[notes](#notes): the notepad from the **✎** beside Dataset (writing
`<Name>_notes.json`) and following the active dataset, the note typed written
when it moves on, the **✎** beside the observation on a unit (with its sort)
following **<** and **>**, an LFP channel's note, the yellow buttons and **✎**
marks, **Search notes** with **Go to** on a unit's and a dataset's note and
**Edit note** (the notepad then staying), a note written showing in the open
search at once, the Data tab's **✎** column, an emptied note removing the file,
and a scan reading the notes back. Section 5k is
[undo and redo](#undo-and-redo): the Edit menu between File and Design, its
items grayed off the Figures tab and named after the edit (**Undo Add
figure**, **Undo Title**), two quick edits of one field one step, a
description edit no step and kept by an undo, a removed panel undone (back
and selected) and redone with Ctrl+Shift+Z, a new edit dropping the redo, the
figures undone back to the saved ones leaving the title saved, the history
cleared by another config, and `FigureEditHistory`'s depth. Section 5l is the
first-spike latency windows: a raster's **First spike** row (not a PSTH's) and a
PSTH's **Latency box** row, **First-spike latency...** opening a modal window with
its rows grayed while off, **OK** giving the raster its window and look as one
step (*Undo First-spike latency*, undone and redone), the row's summary, the
window opening on the panel's settings, a window ending before it starts refused,
**Cancel** changing nothing, **Latency box plot...** likewise (*Undo Latency box
plot*), and the preview drawing the marks and the boxes, then the PSTH's **Trial count**
row (*Undo Trial count*, the texts drawn in the preview) and the raster's **Sort rows by**
offering *latency*. Section 5m is
[each figure's own preview](#figures-tab): a figure added gets a container
of its own, a switch back shows the same axes (not drawn again) with its badge
and status line, the tree selects the figure shown and makes it bold, an edit
of one figure marks only its preview out of date, another dataset marks every
one and the dataset back makes the hidden one current again, the editor's
sections and panel come back as each figure left them, so does the
observation picker (its list taken back, not made again, with its pick; a star
forgets the other figures' lists; an edit of the unit filter lists it again and
keeps that list), Remove frees the
container, the cap drops the container shown least recently (the figure drawn
again when shown), Redraw All draws the enabled figures out of date up to the
cap (the shown one kept, the one shown least recently left, the status bar
saying so), Ctrl+R then finds every one current, and the toolbar's Cancel
stops it while it computes, and Undo and Redo of an Add keep the tree, the containers
and the selection together. Section 5n is
[Apply to figures](#apply-a-change-to-other-figures): a PSTH's Stack edited
with Ctrl held opens the window with the other figures' PSTH and continuous
panels (not the raster), all ticked the first time; Apply gives it to the one
ticked as a step of its own, draws nothing again (with Auto on) and remembers
the ticks; Edit → Apply last change offers the same edit again (the panel
that has it gray, the ticks as left; All ticks the one that can change) and
Replot draws the figures changed; a figure setting (Font size) lists the
figures, and Cancel leaves it to its own; Ctrl+Shift+A and Undo; a title
edited with Ctrl opens no window. Section 5o is
a figure's page size and Ctrl+Click on a panel. Section 5p is
[remembered panel options](#remembered-panel-options) and the
[color swatches](#picking-a-color): the options set on a raster and a PSTH
remembered by type, only those set; a new panel made with `Remembered=true`
starting from them and one without from the defaults; a remembered sort by
a trial parameter the dataset lacks and a value of the wrong class not
taken; the New panel window's Measure starting at the remembered value;
Reset panel options to defaults as one named step forgetting its type's
only, and Undo; the preference written and Forget emptying it; a swatch
beside each color field, the search going to the field; a color picked
(the chooser replaced by a function) as one named step, Cancel, a color
typed and Undo followed by the swatch; and the First-spike latency
window's swatch. Section 6 is the preferences remembered (the last
config, the collapsed sections and supersections of the figure editor; none of the retired plot
or session preferences is written) and closing. The test keeps the app's
preferences in a temporary file (`AppPrefs`), so the user's own are never read
or changed.

Its section 5d drives the Figures tab on the same fixture. With no figure
the editor shows only a hint, the preview is *No preview*, no template is
offered, the sections are titled *Panels* and *Selected panel*, and Help goes to
`#figures-tab`; a figure from the `rasterPsth` template (`onAddFigure("rasterPsth")`)
is *Raster+PSTH units* (**auto** ticked), listed *(2 panels, per unit)*, with
two boxes in the schematic and the config unsaved. The picker lists the
fixture's units in the order `figureObservations` gives, each with its
number of spikes, and the preview draws the first at once, in two axes; **>**
and Page Up step to the next and previous unit (the title names it, and the
figure remembers its pick). **Observe** lists the data types, what the
dataset holds first and a type it lacks marked; picking LFP shows the
channel rows only and lists the LFP channels (no counts), detected spikes
the filter without classes or quality and each channel's detections, the
dataset nothing more and one observation, and sorted units the units again. A
Continuous signal panel added **Below** the PSTH makes a 3 x 1 stack whose
LFP layer follows the unit and draws at once; the editor then shows that
type's rows only (and the raster's rows when the raster is picked, with the
binding grayed out for an events layer, which is always fixed); **Add** of an
events layer to the raster draws its marks. Ctrl+1 opens the collapsed
Observations section; Event reference is Ctrl+2, Arrangement Ctrl+5, Panel
alignment Ctrl+7, Options Ctrl+9, Text note Ctrl+0, and Appearance and
Sessions have no key. The three supersections head their sections in order
(Figure, Panel naming the raster, Look); collapsing Panel hides its sections,
Ctrl+8 opens it again with Layers, Alt+2 opens it and Ctrl+Alt+2 (AltGr) does
nothing. Ctrl+F and *bin* list *Panel > Raster options > Bin (ms)* first, and
the alignment rows are indexed too; Enter there leaves the editor alone and
the status bar says Bin (ms) is an option of PSTH, heat map and unit
correlation panels, not of raster panels. The preview outlines raster_1 with
four strips round its axes and labels; Ctrl+Alt+Down picks psth_1, then
continuous_1 (none below it), the outline following with the same axes (no
redraw); Ctrl+Alt+Left finds no panel, Ctrl+Alt+Up goes back, and Ctrl+[ and
Ctrl+] step round the panel order. The app made 160 px wider and the preview
laid out again, the outline follows psth_1's moved axes; **Open in window**
has none. With the PSTH picked and the Panel supersection and Options
collapsed, Enter on *Bin (ms)* opens both and highlights its label; Down picks
the next match of *line*, Escape clears the search, *layers* finds the Layers
section, and the **?** window lists the keys (once). With Auto off an edit leaves
the preview *Out of date* until **Preview**, and **Cancel** on the busy card
(clicked from a timer) leaves it *Canceled* with the
card and the polling gone. An edit in the figure's Event reference gives it
an event of its own (the Alignment tab's unchanged) that the title and the
panel alignment follow, and **Use default** goes back; an edit in Panel
alignment gives that panel a window of its own and its own time axis, and
**Same as the figure** goes back. While the box is ticked the panel's rows are
locked and show the figure's (an edit there is not taken); unticking copies the
figure's event and window into the panel and opens its rows, and **Apply to all
panels** and **Re-link all panels** make the panel's window the figure's and
link every panel again. A PSTH's bins row is its own: an edit reaches its
options and redraws the preview. **Apply to all panels** (Options) copies the
PSTH's waveform inset to the raster while the continuous panel keeps its
baseline (it takes no *zscore*), the status bar says both, applying the
values back restores the raster and a second press finds nothing to copy;
own options leave **Re-link all panels** off; Ctrl+7 and Ctrl+9 go to Panel
alignment and Options. *Max units* shrinks the picker and *Inf*
restores it. Changing a PSTH panel to a heat map keeps its units layer
(fixed) and the shared bins, shows the heat map's rows and says so in the
status bar, shows its Waveform section with only the note on why a heat map
draws no inset (the search, asked for *Show*, says the same), and changing it back lets the layer follow the unit again. A PSTH
shows its **Stack** row (*Off* or *One row per group*, the spacing grayed out
while *Off*) and no auROC rows without the auROC baseline; *One row per group*
and the spacing reach the panel's options and the preview stacks its groups (a
row baseline per group). Choosing the PSTH's *auroc* baseline shows its auROC rows;
editing the window and the cutoff reaches its options and the preview draws
auROC curves (the result holds `auroc`). The panel-type drop-down offers
*Firing rate* and *Tuning curve*; a *Firing rate*
panel added **Below** follows the unit, draws its bars at once and shows its
rows only (*Display*, *Measure*, *Baseline* with the rate modes, no bins or
stack), and *Display* *points* reaches the options and the drawing. Its
Waveform section (in Panel, no key) shows its note, Show, Time, Amplitude,
Size and place rows, grayed out while *Off*; *Mean*, a time span from -0.5 ms
(a blank end: `Inf`), a fixed range and a width reach `options.waveform` and
the preview reads the waveforms. A
continuous panel (no spikes) has no Waveform section. A *Tuning
curve* panel added **Below** draws at once over the figure's group-by parameter
(*Depth* on the fixture) and shows its **Parameter** rows and the Waveform
section's; its **Parameter** and **series** reach the options and the
drawing. Both are removed again with **Remove panel**. The gather / apply
round trip keeps the figure and the panel picked; a look
remembered from the preview's editor lands in the figure's `aesthetics` (and
the runner's config), and **Forget** drops it. **Remove panel** takes the
continuous panel and its row away (the automatic id follows back to
*Raster+PSTH units*), **Duplicate** copies the figure as *Raster+PSTH units (2)*
and **Remove** takes the copy away. On a blank figure **New panel** at each
place, spans, sizes and spacing reach the grid; **Panel size** and **Align in cell**
reach the selected panel alone (its vertical alignment off while it is 100 % high);
the **Spacing...** window lists every gap, filled by the one gap each way, refuses a
gap under 0, sets one apart, applies custom gaps (the window staying open) and then a
preset with **OK** (the custom gaps kept unused, the window closed). **Add** makes a
blank figure (*Blank dataset*, automatic) and opens the New panel window, answered from a
timer: **Cancel** leaves the figure blank; then **New panel...** shows a tile with its
picture for every panel type, picks *Continuous signal*, names it, titles it, sets its
display, and **OK** adds it (the id becomes *Continuous LFP* and **Observe** *LFP*). Every
panel type is then added at every place (below, right, above, left) and removed again; every
type has its picture under `analysis/icons/panels`. An id typed sticks (**auto** unticked)
through a panel added; ticking **auto** gives the automatic id back, and the observation
picked and a look remembered under the old id follow the figure. After a save and a reopen the
config keeps the figure, and a new app restores the Auto box, the collapsed
section and the collapsed Look supersection; the last **Remove** leaves the
editor (no supersection header) and preview (no outline) empty. The grid
editing (`placePanel`, `removePanel`, `movePanel`), the compute and the
render are `test_EphysAnalysisFigures`
([Tests](EphysAnalysisConfig.md#tests)).

Section 5d also sets `app.FigureAutoPreviewSeconds` to `Inf` for its length
(back to the default after 5f), so a preview slowed by a loaded machine cannot
leave the next one *Out of date*. With **Per trial group** ticked the picker
lists every unit and trial group (the units times the groups, each label ending
in its group), the count line says *"N units x G trial groups"*, the preview
draws the first group's epochs alone (one group in the result, the group in the
title), **>** steps to the unit's next group, and unticked, the picker has one
observation per unit again. With the PSTH picked, **Trial selection as the
figure** is ticked and its rows locked (an edit in them is not taken); unticking
it copies the figure's selection into the panel, opens the rows and says so in
the status bar; **Group by** *(none)* then makes the preview draw the PSTH on its
own single group, titled *all trials*, beside the raster on the figure's groups;
**Re-link all panels** drops the panel's own selection and locks the rows again;
and with a selection of its own in the order *descending*, **Apply to all
panels** makes it the figure's and links every panel to it, until the figure is
set back to the default. On the continuous panel the **Trials** row shows (the
heat map's **Rows** does not) and **at most** is off until a mode is picked;
*Faint* with 4 reaches the options and the preview draws at most four trial
traces behind the mean. On a heat map, **Rows** *one unit's epochs (trials)*
shows the raster-sort rows, hides **Row order** and **Group shown** and opens
the layer's Binding; following the unit with a descending sort reaches the
config and the preview draws an image with a row per epoch; back to *the
layer's units or channels* the layer is fixed again. Its spectral block
(with the bundled Chronux on the path for the checks only; skipped with a note
without it) starts from a *Blank* figure, which previews without failing, adds a
*Power spectrum* panel from the drop-down (the observed unit's spike spectrum,
previewed at once, its x axis *Frequency (Hz)*), checks that the Chronux rows
show (tapers, error, scale, time base, spike rate) and the range and moving-window
rows do not, and sets **TW, K**, the frequency range, the scale and the
*segments of the recording* time base, which reach the config and the preview.

Its section 5e drives the figures' **Copy settings...**. It is on with one
figure. With three, `From=` and `Settings="style.FontSize"` copy the font size
alone onto the figure selected (the panels and the rest stay, one undo step,
the preview follows); `To=` copies from the figure shown onto two others, one
of which has the value already: the other's kept preview is marked out of
date and nothing is drawn, and Undo takes it back. The window, answered from
a timer, picks the heat map figure in **From** (the figure selected is then
ticked to copy onto), ticks the Alignment part and *Grid and panels* after
**None**, shows the font size alone for **Find** *font*, and copies: the first
figure holds the heat map's panel, its bins included, its automatic id
follows, and the ticks are remembered. `Design=` copies the figure's group
colors into a new design of yours. Converting a version 1 config's plots is `test_ConfigMigration`
([Tests](EphysAnalysisConfig.md#tests)); figures in plans, runs, exports and
reports are `test_EphysAnalysisRunner`'s.

Its section 5f drives **File → Generate selected figure** and the figures on the
Export tab. With no figure, Redraw All sits under Preview in the same colors
and is off, as are Unit report under it (Ctrl+U then does nothing) and the
File menu's Generate selected figure (accelerator G); a figure from the `rasterPsth` template turns them on. `onGenerateFigure`
then draws the figure for every observation on both ticked datasets: one done
`figure` row per dataset in the results table (the observation counts add up to
the number `figureObservations` lists), every file `figureOutputName` names in
the Export folder, the status bar `Generated <id>: <n> observation(s) on <m>
dataset(s), <k> file(s) in ...`, **Open figure folder** and the toolbar's on, **Open
report** off, the buttons back, the tab unchanged and the figure still enabled.
A timer cancels a Generate while it draws (the files are deleted first):
Generate, Redraw All and Run are off, Cancel is on and the preview computes nothing (its
status says a run is going) while it runs, and afterwards every row is
*canceled*, the status bar says `Generating <id> was canceled`, and Generate
is on again. **Plan** lists the figure on each ticked dataset (`Kind`
`figure`, `Source` `unit`, enabled) and the status bar ends *and 2 of 2 figure
run(s) will draw*; **Run** draws the figure, a row per dataset, and the label counts them. Last, with the figure
switched off, Generate still draws it (every row done), the status bar says it
was switched on for this run only, the tree keeps *(off)* and the runner's
config keeps it off. **Unit report** then, with a continuous and a heat map
figure added and the second unit picked (the button on): three rows, all on
the active dataset -- the selected figure done with one observation though
off, a figure of the dataset skipped (*it observes the dataset, not one
unit*), the continuous one drawn on the unit's channel or skipped with why --
an HTML report `unit_report.html` under `tempdir`, holding the figure's id,
nothing written under the output root, **Open report** pointing at it, the
figure still off and the ticks unchanged; the status bar names the unit, what
was left out and the figure that is off, and the buttons are back. The
figures are then removed and the config saved.

Its section 5g drives a figure across sessions on the same two datasets. In
the Sessions section only **Across sessions** shows until it is ticked, and
**Per trial group** and the Dataset drop-down are as usual; ticked, the config
holds `sessions.enabled`, the rows show (the keys and the mapping file not yet,
the error band off for a color per session), **Per trial group** hides, the
Dataset drop-down is off, the note says it is drawn once across the datasets
and the figure is a session figure, not a per-dataset one
(`enabledSessionFigures`). A color for all sessions, the faint sessions and
*Mapping* reach the config and open the error band and the mapping file row.
**Browse...** (given a file) and **Edit...** (given a table) set and write the
mapping file; **Pick...** (given keys) writes `datasetKeys` and the Keys box.
The observation list then holds the sites matched across both datasets, each
*(across 2 sessions)*, and its count line says so; **Preview** draws the
merged figure (a `nSessions` result over both sessions, the status line *"...
across sessions: 2 merged"*, the PSTH drawn, the "Figure:" drop-down hidden for
one figure). An edit (a figure per subject, a figure per trial group) leaves the
preview *Out of date* with the *press Preview* line; after **Preview** the
"Figure:" drop-down picks which figure is drawn without computing, and the
script of **Export code**, run, merges the observation over both datasets and
gives the figure picked there. **Generate selected figure**
then writes a page per matched site into the sessions folder
(`<facet>_<id>_site_ch<N>.png`), one `sessions: all` results row, and the status
bar reads `Generated <id> across the sessions: <n> observation(s), ...`.

Its section 5h drives the figure tree, a panel's note and overlays, and the
schematic's drag, from no figure (it, too, sets `FigureAutoPreviewSeconds` to
`Inf` for its length). Three figures (two rasters over PSTHs, one continuous
panel) are grouped *Per unit (2)* and *Per channel (1)*, then *Enabled (3)*, then
flat, each leaf reading as the grouping says, and picking a leaf edits that
figure while picking a header leaves it selected. The check boxes are clicked at
the pixel where MATLAB draws a box (a click on a name changes nothing): a figure's
box unticks it in the config, the editor's **Enabled** box and the group's
half-filled box following, and a group's box ticks, then unticks, its figures
without touching the other group's. **All**, **Invert** and **None** act on every
figure. **Up** moves a unit figure past its group's other, not past the channel
figure between them; a figure alone in its group has neither button, and ungrouped
both go over the whole list. A new app restores **Group by** and a collapsed
group from the preferences, and expanding the group forgets it. On the PSTH
panel the Text note (Ctrl+0) and Overlays (no key) sections show, the note's look rows
grayed out until it has text; text, a place and a color reach the panel's `note`
and the preview draws it (a `note` text in that color); **Add patch**, its edges,
**Add line**, **Duplicate** and **Remove** reach the panel's `overlays` (each with
`panel` `"all"`), the preview draws the patch, and the section titles count them;
the raster panel has none of its own, going back to the PSTH loses nothing, and
`gatherConfig` after the apply gives the panel's note and overlays back unchanged.
The **X axis** and **Y axis** rows set the PSTH's y label and side (the preview
draws them; the side is grayed out on a stacked PSTH), and `onFigureAxisEdited`
(the label's right-click menu) sets them through the editor's path, each edit a
step of the undo history (**Undo Label text**, **Undo Axis side**). The PSTH's
axes' own menu holds both labels' text, both sides and the every-panel moves;
**Move every panel's X axis to top** puts the raster's and the PSTH's x axes on
top (one time axis, on the raster) as one undo step; the raster's hidden x label
keeps a text given to it, the status bar saying the stack does not show it; an
every-panel move that changes nothing says so.
The drag runs on the window's pointer callbacks, which the press installs: over
`psth_1`'s bottom band the outline follows and *below psth_1* is shaded, the
release moves `raster_1` below it (a second row, the callbacks cleared, the
schematic and preview redrawn); with a column added, a drop on the empty cell moves
it there; a release outside the schematic and **Escape** both leave the config
unchanged and the callbacks cleared. The drag's scale is checked against the
schematic's limits over its plot box, read independently, with the press point
mapping to the pointer. On a 3 x 2 grid with a panel over two rows, a drop on an
empty cell it would not fit in (rows 2-3 would cover another panel) is not shaded
and moves nothing, the status bar saying *"psth_1 does not fit at row 2, column 2:
it would overlap raster_1"*; a drop on the bottom row moves it there with its span
clipped (*"Its spans became 1 x 1 to fit the grid."*); a release over another
panel's middle moves nothing and says *"Nothing to drop psth_1 on there"*; and an
edge drop (below `raster_1`) leaves the panels in their order in the figure.

<!-- wiki
## Related

- [Analysis configs](Analysis-Configs): every field of the config the app edits
- [Analysis scripting](Analysis-Scripting): the runner, generated scripts and the compute / render functions
- [Output files](Output-Files) and [Loading outputs](Loading-Outputs): what the analysis reads
- API: [EphysAnalysisApp](API-EphysAnalysisApp), [EphysAnalysisConfig](API-EphysAnalysisConfig), [EphysAnalysisRunner](API-EphysAnalysisRunner), [EphysAnalysisScript](API-EphysAnalysisScript), [Analysis functions](API-Analysis-Functions)
-->
