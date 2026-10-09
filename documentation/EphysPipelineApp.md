# EphysPipelineApp

`EphysPipelineApp` ([source](../pipeline/@EphysPipelineApp/EphysPipelineApp.m)) is
a programmatic `uifigure` GUI (a `handle` class, not an App Designer `.mlapp`)
for the preprocessing pipeline. It edits **one pipeline config**
([`EphysPipelineConfig`](EphysPipeline.md)) and runs it with
[`EphysPipeline`](EphysPipeline.md#ephyspipeline) over an
[`EphysProject`](EphysProject.md). It is used to:

- pull a subject's sessions from the source (Intan or Open Ephys recording +
  ePsych file, paired by name) into local session folders, verified;
- scan a folder tree for recordings (Intan, Open Ephys GUI sessions, TDT
  Synapse blocks, or the universal binary format);
- assign probe maps and channel exclusions;
- mark manual artifact periods and configure automatic detection;
- run Kilosort4 (optional) and associate sorted output;
- derive LFP / MUA / spike-band `.mat` files;
- detect spikes by threshold into a `.mat` (sorted units stay in the sorting
  folder);
- export Chronux- and FieldTrip-shaped files;
- run an analysis config (plots, figure files, a report) from the
  [analysis app](EphysAnalysisApp.md) over the processed datasets;
- associate Epsych2 behavior sessions;
- review sorted units and open them in phy;
- write synthetic datasets whose spikes and LFP follow the events of the
  built-in task or of a real Epsych2 session;
- free local disk space once datasets are preprocessed (raw recordings with a
  verified copy on the source, sorter copies of the recording);
- save the config, and generate scripts that reproduce the run.

Reading, filtering, sorting, conversion and export all happen in
[`EphysDataset`](EphysDataset.md) and `EphysPipeline`; the app edits the
config, chooses datasets, shows progress, and keeps the per-dataset
associations in each dataset's manifest. Anything the app runs can be run
without it from the saved config.

Installation (MATLAB, conda environments, GPU) is covered in
[INSTALL.md](../pipeline/INSTALL.md).

## Launching

```matlab
EphysPipelineApp            % open the window
app = EphysPipelineApp;     % open and keep a handle (app.Config, app.Project, ...)
```

The constructor builds the UI, restores preferences, opens the last config
file if it still exists (else starts from defaults, "Untitled"), and lists the
probe folder. The app opens on the Project tab.

**New config**, **Open config...**, **Open recent**, **Create synthetic test
project...** and closing the window ask first when the config has unsaved
changes (**Save** / **Discard** / **Cancel**). Closing also asks before it
leaves a copy running (**Close anyway** / **Stay open**): the copy finishes on
its own, but nothing is left to verify it or write its `session_manifest.json`;
**Copy selected** again later completes and checks it. It asks the same when
Kilosort4 runs are queued and not started, because closing drops them. Then it
cancels a running pipeline, stops the app's timers (the Kilosort4 and copy
monitors, the resource monitor) and saves the preferences. Python processes
that are already sorting keep running.

## Window layout

<!-- wiki: ![The Project tab of a scanned project](images/app-project-tab.png) -->

- **Menu bar**
  - **File**: New config (Ctrl+N), Open config... (Ctrl+O), Open recent (the
    last 8 files), Save config (Ctrl+S), Save config as..., Export copy of
    config..., Generate script (Compact (loads the saved config)... |
    Standalone (every parameter written out)...), Create synthetic test
    project... (see [Synthetic test project](#synthetic-test-project)), Open
    analysis app... (see [The analysis app](#the-analysis-app)), Channel
    mapper... ([`ChannelMapperApp`](ChannelMapperApp.md), as the Probe tab's
    **Map channels...**), Close.
  - **Dataset**: one checkable item per scanned dataset; the checked one is
    the [active dataset](#which-dataset-does-an-action-act-on). **View
    manifest...** at the bottom opens the active dataset's manifest in the
    [manifest viewer](ManifestViewerApp.md).
  - **Run**: Validate config, Plan, Run pipeline (Ctrl+R), Dry run, Cancel.
  - **Help**: opens the [GitHub wiki](https://github.com/dstolz/ephys_analysis/wiki)
    in the browser. Help for this tab (the page for the tab that is shown),
    Documentation home, Quick start, App overview, Output files,
    Troubleshooting and FAQ, Scripting guide, Pipeline configs, Developer
    reference. If no browser opens, an alert shows the address.
    Its last two items file against the
    [repository](https://github.com/dstolz/ephys_analysis/issues) instead:
    **Report an issue on GitHub...** and **Request a feature on GitHub...**
    (see [Reporting an issue](#reporting-an-issue)). The very last,
    **About EphysPipelineApp**, shows the version and git commit of the
    code, the repository folder and the MATLAB release; **Copy** puts them
    on the clipboard.
- **Toolbar**, under the menu bar: the menus' most used commands as icons,
  each calling the same method as its menu item. Its tooltip names the
  item's shortcut, if it has one (Ctrl, or Cmd on a Mac). In groups:

  | Tool | Menu item |
  | --- | --- |
  | New config, Open config, Save config | File (Ctrl+N, Ctrl+O, Ctrl+S) |
  | Validate config, Plan (writes nothing), Run pipeline, Dry run, Cancel run | Run (Run pipeline: Ctrl+R) |
  | View the active dataset's manifest | Dataset → View manifest... |
  | Open analysis app, Copy files for the analysis app, Channel mapper | File |
  | Help for this tab | Help |

  Run pipeline and Dry run are off while a Run goes, and Cancel run is on
  only then, as on the Run tab. The icons are
  `pipeline/icons/toolbar/<Tag>.svg`.
- **Title**: `Ephys preprocessing - <config name>  [<file>]`, with `*` in
  front while the config has unsaved changes.
- **Tab strip**: one button per tab, coloured by the tab's state
  ([The tab strip](#the-tab-strip)), with a short bar between groups of tabs.
  The open tab's title is bold, with a blue underline.
- **Status bar** (bottom): the last action on the left, a suggested next step
  on the right ([The status bar](#the-status-bar)).

### The tab strip

The tabs, in workflow order:

| Tab | Use it to |
| --- | --- |
| [Copy](#copy) | copy subjects' sessions (a recording and its Epsych2 file) from the source to local session folders, by hand or at an interval ([scheduled copy](#scheduled-copy)); stitch restarted ePsych sessions |
| [Project](#project) | name the config, scan a folder for recordings, tick the datasets to process, set the output root and the source settings, associate Epsych2 sessions |
| [Trials](#trials) | review and approve how the trials pair with the trial digital line, name the digital lines, prefetch the lines of many datasets |
| [Probe](#probe) | pick probe maps, assign them, exclude bad channels |
| [Artifacts](#artifacts) | set the common reference, set up and preview automatic artifact detection, mark manual periods |
| [Sorting](#sorting) | configure Kilosort4, associate sorted output, open phy |
| [Signals](#signals) | derive LFP / MUA / SPIKE / AUX signals |
| [Spikes](#spikes) | detect spikes by threshold |
| [Export](#export) | write files for other tools (Chronux, FieldTrip, event epochs, kCSD-python, NWB) |
| [Analysis](#analysis) | run an analysis config from the analysis app over the selected datasets: its figures and report |
| [Diagram](#diagram) | see a diagram of what the config does; click a box to open its settings |
| [Run](#run) | validate, plan and run; watch progress, results and the computer's load |
| [Review](#review) | inspect sorted units and their quality metrics, add notes, open phy |
| [Visualize](#visualize) | plot the recording, the sorting `.bin` or a derived signal, with sorted units and detected spikes over it; open the Artifacts tab's plot to mark periods by hand |
| [Synthetic](#synthetic) | design, preview and write a synthetic dataset |
| [Clean up](#clean-up) | free local disk space once datasets are preprocessed, or remove what chosen steps wrote |

Each tab button shows an icon above its title
(`pipeline/icons/tabs/<title>.svg`, lower case without spaces) and is coloured
by the tab's state. Its tooltip says why. A short vertical bar separates the
groups: Copy | Project to Analysis | Diagram, Run | Review, Visualize |
Synthetic | Clean up.

| Colour | State | When |
| --- | --- | --- |
| grey | disabled | Artifacts, Sorting, Signals, Spikes, Export, Analysis: the step is switched off. The Artifacts tab still turns amber or red for the common reference's (`Reference` section's) problems, since every step reads it |
| green | ready | the step is enabled and its settings raise no issue. Project: datasets are scanned. Trials: every selected pairing is approved. Probe: every selected dataset has a probe, its own or the default |
| amber | needs attention | config warnings for the tab. Project: no datasets scanned. Trials: some selected pairings are not approved. Probe: selected datasets without a probe, or whose probe file is not there |
| red | error | config errors for the tab; a run refuses to start |
| blue | busy | Run while the pipeline runs; Copy while a copy runs in the background |
| white | neutral | Copy, Diagram, Run, Review, Visualize, Synthetic and Clean up otherwise; Probe and Trials when there is nothing to judge |

### The status bar

The left side of the status bar shows the last action. The right side
suggests the next one from the project's state: scan a project; assign probes
(while some datasets have none, their own or the default); enable steps; run
the pipeline (with the count of sorted datasets); once every dataset has
sorted output, run the remaining steps or open Review. Tabs post their own
hints there too.

### The analysis app

**File → Open analysis app...** opens [`EphysAnalysisApp`](EphysAnalysisApp.md),
a separate window for quick-look figures of this project's outputs (PSTHs,
rasters, evoked potentials, rates, tuning, probe maps). With a project root
set it opens on that root, output root, name pattern and Open Ephys recording
mode; otherwise with its own last config. The Project tab's **Tools**
panel opens it on chosen datasets. It reads the files the pipeline wrote and
changes nothing here. It lives in the repository's `analysis` folder: when
that folder is not on the path, an alert says so.

### Copying files for the analysis app

**File → Copy files for the analysis app...** (the folder-arrow tool on the
toolbar) copies just the files [`EphysAnalysisApp`](EphysAnalysisApp.md)
reads, for the ticked datasets (every dataset when none is ticked), to
another folder, so the analysis runs on another computer without the
recordings or the rest of the pipeline's outputs. The window
([`AnalysisCopyDialog`](../pipeline/AnalysisCopyDialog.m)) has the
destination, the choices below, and a table with a row per dataset (untick a
row to leave it out) showing its file count and size, the progress of the
copy and what is missing (no behavior file, no sorted units, ...).

| Choice | Copies |
| --- | --- |
| always | `<Name>_manifest.json`, `<Name>_behavior.mat`, and the smallest extract file (the digital events are in it) |
| Signal files | the extract files holding LFP, MUA, SPIKE and / or AUX (a file with several is copied once). Default: LFP, MUA and AUX |
| Detected spikes | `<Name>_spikes.mat`, for plots with Source "detected" |
| Sorted units | *Essential files* (default): spike times, clusters and templates, the channel files, `params.py`, `settings.json` and the `cluster_*.tsv` tables, without the large feature files; *Whole folder*; or *None* |
| Sorted binary | the `.bin` / `temp_wh.dat` the sort read (large). Without it the unit waveforms are drawn from the templates |
| Probe file | the probe `.json` the manifest names, put beside the manifest |
| If the folder has files | *Replace changed files* (default), *Keep existing files* (copy only the missing ones) or *Make a new `_v2` folder* |

Each dataset goes to `<folder>\<subject>\<session>` (its key, as the
[Transfer section](#copying-the-outputs-elsewhere) lays out), copied in the
background by `OutputTransfer` (robocopy, Windows only), so the window can
stay open while the copy runs; **Stop** ends it and keeps what is copied.
**Check the copies by checksum** adds a SHA-256 pass. The choices and the
destination are remembered (preference group `AnalysisCopyDialog`).

On the other computer, `EphysAnalysisApp("<folder>")` finds the datasets
(a root of outputs without recordings is read as its datasets). The manifest
names the probe file by its path on the pipeline computer; the analysis uses
the file of the same name beside the manifest when that path is not there
(`DatasetOutputs.probeFile`), so probe maps and depth order work from the
copy. The list of files for a dataset is
[`DatasetOutputs.analysisFiles`](DatasetOutputs.md#files-for-the-analysis-app).

### The config model

Every control on the Project through Analysis tabs is bound to a section of
`app.Config`. Editing a control re-gathers the config
(`gatherConfig`), pushes the new settings into the scanned datasets, syncs the
enable states (tab strip colours and the Run tab's checklist) and updates the
unsaved marker. **Open** / **New** push a config into the controls
(`applyConfig`). Each step has an **Enabled** box on its own tab; the Run
tab's checklist shows the same boxes.

What the app holds lives in one of three places:

| Where | What | Saved |
| --- | --- | --- |
| the pipeline config (a `.json` file) | every step's settings and which steps are enabled, the project root, output root and name pattern, the source settings, the digital-line names and polarity, the dataset selection | by **File → Save config**; `*` in the title marks unsaved changes |
| each dataset's manifest (`<Name>_manifest.json` in its recording folder) | what belongs to one recording: its probe, excluded channels, manual artifact periods, sorted-output folder, Epsych2 session and trial-pairing cuts | at once, when they change; a config never holds them |
| the app preferences ([Preferences](#preferences)) | what belongs to neither: the window, the probe folder, the phy command, recent configs, table layouts and sorts, display options, the Copy, Synthetic and Clean up tabs' settings | on close, and when some of them change |

So one config can run on another project, and what was decided about one
recording survives a rescan, a new config and a script that runs the same
recordings.

Opening a config whose values some fields cannot show (a number outside a
field's limits, an unknown dropdown value) lists them in an alert: those
fields show another value, the working config is what the controls show, and
the title marks it unsaved. A config the controls cannot show at all is
refused, and the one shown before stays (at startup: the defaults). A config
for another project root drops the scanned project, whose ticks do not become
the config's selection: **Run** and **Plan** then need a **Scan** of the
config's root (`EphysPipelineApp:NoProject` /
`EphysPipelineApp:OtherProject`).

Text fields that hold channel lists and notch frequencies are kept as typed;
they are parsed when a run starts, and a run reports the first field it
cannot parse. The Kilosort4 parameter fields are parsed on every edit: while
one does not parse, the working config keeps its last good values, the status
bar says why (`EphysPipelineApp:SortingNumber`), and **Run**, **Save**,
**Save as**, **Export copy**, **Validate** and **Generate script** refuse.

While a run is under way, config edits are not pushed onto the datasets it is
processing (they are when it ends), **Scan** and **Refresh metadata** are
off, and the edits that change the datasets are refused: probe, exclusions,
**Left out** and **Suggest**, **Detect / Preview**, behavior **Associate
file** / **Clear**, manual periods, the sorted-output folder, the Trials
tab's approve, prefetch and write, and the Source settings (a rescan).

### Which dataset does an action act on?

There are two kinds of target. Batch work uses the **ticked** rows of the
Project table. Everything that works on one dataset uses the **active
dataset**. There is always exactly one active dataset once a project is
scanned (after a rescan, the one that was active, found again by its folder
when it is still there; else the first). You choose it in any of three
places, and all of them always show the same one:

- the **Dataset menu** (the active dataset is checked). It lists the datasets
  ticked in the Project table, including ticked rows the token filters hide;
  every dataset, ticked or not, is under its **All datasets** submenu;
- a **Dataset** box on the Trials, Probe, Artifacts, Sorting, Spikes,
  Visualize and Review tabs. It lists the same ticked datasets (every dataset
  when none is ticked), plus the active dataset if it is not ticked;
- a click on a row of the **Project table** (the active row is bold on light
  blue; no row is highlighted while the token filters hide it, but it stays
  active).

When the active dataset changes, results shown for the previous one are
cleared: a loaded trial pairing, the Artifacts preview and the Spikes
preview. The Review tab loads the new dataset's sorted output (at once when
the tab is open, else when you open it), and so does the Visualize tab. Until
it does, a Visualize plot of the previous dataset stays on screen, the status
line names the dataset it shows. A plot stays tied to the dataset it was drawn from: a rescan finds
that recording again by its folder.

| Action | Target |
| --- | --- |
| Trials: every control but Prefetch ticked; Probe: Exclude channels, the channel-count check; Artifacts: Detect / Preview, manual periods table; Sorting: Use folder / Use auto / Open in phy, Optimize for probe (the default probe when the dataset has none); Spikes: Preview; Export: Epochs to workspace; Analysis: Open report / Open figures folder (the active dataset's first); Visualize; Review; Project: Associate file / Clear, the Tools panel set to **Active dataset** | the **active dataset** |
| Run pipeline, Dry run, Run this step, Plan, Signals / Export / Analysis target tables; Project: Find sessions for selected, the Tools panel set to **Ticked datasets**; Clean up: Preview and the files it lists | the rows **ticked** in the Project table (`Project.Selection = "list"`), or **all** datasets when none are ticked (`"all"`) |
| Trials: Prefetch ticked | the rows **ticked** in the Project table; with none ticked it asks you to tick some |
| Probe: Assign to selected datasets | the rows **ticked** in the Project table, or the **active dataset** when none are ticked |
| Probe: Assign to all datasets | every dataset |

## Typical workflow

0. **Copy** (when the recordings are still on the source): find the subjects'
   sessions for the day, check the pairing, **Preview (dry run)**, then
   **Copy selected**. The copy runs in the background, so the rest of the app
   stays usable; the copied sessions open as the project when it finishes. If
   it is cancelled or interrupted, **Copy selected** again completes it. A
   [Scheduled copy](#scheduled-copy) does the copying by itself, at an
   interval, without MATLAB open.
1. **File → New** (or open a saved config). Name it on the Project tab.
2. **Project**: set the project root, press **Scan**; set an output root and
   the name pattern (and the source settings, for Open Ephys or TDT
   recordings). Tick the datasets to process.
3. **Behavior** and **Trials**: a copied session's Epsych2 file is associated
   at the scan; otherwise point the Project tab's **Behavior** panel at the
   Epsych2 files. On the Trials tab, name the digital lines if needed (Open
   Ephys `TTL4` → `InTrial`), then review and approve each dataset's pairing,
   or let **Auto approve when the counts match** approve the clean ones.
4. **Probe**: pick a probe map, **Assign to all datasets** or set it as the
   config's default probe. Enter per-recording **Exclude channels**.
5. **Artifacts** (optional): set the common reference; tune and preview the
   detector; mark manual periods on its plot.
6. Enable the steps you want on their tabs (**Sorting**, **Signals**,
   **Spikes**, **Export**, **Analysis**) and set their options. Each tab has **Run this
   step** for a single step over the selected datasets. For **Analysis**,
   make an analysis config in the analysis app first (**Open in the
   analysis app**) and choose it. The **Diagram** tab shows what the config
   does.
7. **Run**: **Validate**, **Plan**, then **Run** (or **Dry run**).
8. **File → Save config**. Each run has already saved its standalone script
   in the project root (**Save the pipeline script on each run**, Project
   tab); **Generate script** writes either form wherever you choose.
9. **Review**: inspect sorted units, or open them in phy. After curating in
   phy, run **Export** again (with **Overwrite**) so its files carry the
   curated labels.
10. **Clean up** (optional): once the outputs are written, free the local
    disk space the raw recordings, the sorting copies of them and the
    Visualize tab's envelopes take.

No data at hand? **File → Create synthetic test project...** writes a
complete test project (recordings, Epsych2 sessions, sorted output, a
config) and opens it; see [Synthetic test project](#synthetic-test-project).

---

## Copy

Copies recording sessions from the source to local session folders: by hand,
or at an interval with a [scheduled copy](#scheduled-copy). Recordings that
are already local need no copy: start on the [Project](#project) tab. Each
session is two separate artifacts, written by different software (possibly on
different PCs and clocks):

| Artifact | Source path |
| --- | --- |
| ePsych behavior file | `<ePsych root>/<SUBJ>/<SUBJ>_<yyMMdd>T<HHmmss>.mat` |
| Intan RHX recording folder | `<recording root>/<SUBJ>/<SUBJ>_<yyMMdd>_<HHmmss>/` |
| Open Ephys GUI session folder | `<recording root>/<SUBJ>/<SUBJ>_<yyyy-MM-dd>_<HH-mm-ss>[<appended text>]/` (holding `Record Node <id>`) |
| TDT Synapse block | `<recording root>/<SUBJ>/<SUBJ>-<yyMMdd>-<HHmmss>/` (a tank named by the subject, holding the block's `.tsq` / `.tev`) |

A recording folder is recognised by its name (the name patterns
`{SubjectID}_{Date:yyMMdd}_{Time:HHmmss}`,
`{SubjectID}_{Date:yyyy-MM-dd}_{Time:HH-mm-ss}*` and
`{SubjectID}-{Date:yyMMdd}-{Time:HHmmss}` (TDT), with the subject ID matched
exactly), and read by whichever reader claims it. A session is copied to
`<Destination>/<SUBJ>/<recording folder name>/`: the recording folder's
whole contents (for Open Ephys, the Record Nodes and everything under them),
the ePsych file under its original name,
`session_manifest.json` and `session_copy_robocopy.log`. Scanning the
destination as a project associates that ePsych file with the recording
(`associateFolderBehavior`), so the **Behavior** column is filled without
any behavior search folders.

<!-- wiki: ![The Copy tab after Find sessions and Preview](images/app-copy-tab.png) -->

The tab only collects
settings and shows results. The pairing rules are in
[`findCopySessions`](../pipeline/findCopySessions.m) and the copy rules in
[`copySessions`](../pipeline/copySessions.m), which work the same from a
script:

```matlab
T = findCopySessions("SUBJ-ID-1255", "260916");                 % or [datetime datetime]
T = findCopySessions("SUBJ-ID-12*", "260916");                  % every subject whose folder matches
T = findCopySessions("", "260916");                             % every subject
R = copySessions(T(T.Status == "paired", :));               % dry run (the default)
R = copySessions(T(T.Status == "paired", :), DryRun=false, Verify="hash");
T = stitchCopySessions(T, [2 3]);                               % one recording, two ePsych files

[R, job] = copySessions(T, DryRun=false, Background=true);   % returns at once
while ~job.Done
    [R, job] = copySessions(job);                           % poll; no waiting
end
```

`findCopySessions` errors with `findCopySessions:RootNotFound` when a root is
not a folder (the source drive is not mounted, say). `copySessions` is a dry
run unless `DryRun=false`. It copies `recording_only` and `epsych_only` rows
only with `IncludeUnpaired=true`, never copies an ambiguous row, and with
`MinQuietTime` skips a row whose source changed less than that long ago.

| Control | Meaning |
| --- | --- |
| Subject ID, From, To | the subjects and an inclusive range of days (To blank = one day). **Subject ID** takes one or more IDs and patterns separated by spaces or commas. An ID is matched exactly: `SUBJ-ID-125` never matches `SUBJ-ID-1255_...`. In a pattern `*` stands for any run of characters and `?` for any one character, matched against the whole names of the subject folders under the roots (case sensitive, as the file names are): `SUBJ-ID-12*` is `SUBJ-ID-120`, `SUBJ-ID-1255`, ..., `SUBJ-ID-12?` only the 10-character ones. Blank (or `*`) is every subject, i.e. every folder directly under the ePsych root and the recording roots. Each subject is paired on its own, and the table lists one subject after another |
| ePsych root, Recording roots, Destination | defaults `S:/RIG3_Backup_2025/epsych_files/Data`, `S:/RIG3_Backup_2025/intan_files/Data`, `D:/EPHYS`. **Recording roots** is a list separated by `;` (e.g. an Intan share and an Open Ephys share); its **Browse...** adds a folder to the list. Each box is an editable drop-down: type a folder or pick one of the last 10 entered in that box (typed, picked or browsed to; newest first, each folder once whatever its case or slashes; for Recording roots, whole `;` lists). **Forget...** opens that box's list to remove entries from it (the box keeps what it shows, and no folder is touched). The lists are kept with the other Copy tab preferences |
| Max lead (min), Max lag (min) | an ePsych file is a candidate for a recording when it starts no more than *lead* before it (default 10) and no more than *lag* after it (default 2, for clock skew) |
| Ambiguity margin (s) | default 30; see below |
| Min duration (min) | default 2. A recording shorter than this is never paired; see below. 0 pairs every recording |
| Find sessions | pair by name, using the **Duration** of each recording (from its headers: Intan `.rhd` headers and `.dat` sizes, the Open Ephys sample counts of every recording in the session) for the minimum; then read the **Trials** (elements of the ePsych file's `Data`) of the listed sessions. A header that cannot be read is logged and leaves the cell blank. **Format** says which reader reads the folder (Intan, Open Ephys, Binary; blank when none does) |
| Verify | checked once a session has been copied. `size`: every copy has its source's size and modified time (to 2 s): robocopy gives a file its full size as soon as it starts it and the source's time only once it has finished it, so the size alone would pass a file stopped part way; `hash`: also a SHA-256 checksum of the source and the copy (reads every file twice more, in the engine), not read again for a session whose manifest already records matching checksums |
| If it exists | a destination folder that exists, is not empty and does not match the source (by size and time): `resume` (default) completes it, copying only the files that are missing or differ; `skip` leaves it alone; `error` reports it as `failed`. One that already matches is reported `already_present`. A file that is not in the source is never touched. A row whose session folder already holds another behavior file (the other pairing's: stitched against not stitched) fails whatever this says: remove that file by hand to copy the row |
| Stitch selected rows | merges the selected rows (click, then Ctrl- or Shift-click) into one `stitched` session: they must hold exactly one recording folder and at least two ePsych files. See [Stitching](#stitching-epsych-files) |
| Unstitch | puts the selected stitched rows back as Find sessions paired them |
| Preview (dry run) | reports what a copy would do, including a free-space check, how much of a partial copy is already there and how much is left to copy; writes nothing |
| Copy selected | copies the ticked rows **in the background**: the app stays usable, a progress panel opens above the table and the table's **Result** column tracks each row (see [Watching a copy](#watching-a-copy)). The button becomes **Cancel copy**, which stops at once: robocopy is ended, or the SHA-256 being taken stops part way, and the row becomes `cancelled`. The file being copied or checksummed is left part way; what has been copied is kept, and **Copy selected** (`resume`) completes it later |
| After copying, open the copied sessions as the project | after a batch in which no session failed, sets the Project root to the folder holding the copied (and already present) sessions, scans it and makes the first copied session the active dataset (for an Open Ephys session split into one dataset per recording, its first part folder) |

The table lists one row per recording, and one per ePsych file that has no
recording, one subject after another, each by time. The line above it counts
the rows:
`2 paired, 0 stitched, 1 recording only, 1 ePsych only, 3 ambiguous; 2 ticked.`
The log under the table records every step, including
the names in the subject folders that did not parse: those are skipped,
never guessed at.

| Column | Meaning |
| --- | --- |
| Copy | tick to include the row in **Preview** and **Copy selected** |
| Status | `paired`, `stitched`, `recording_only`, `epsych_only` or `ambiguous` (see **Pairing** below) |
| Recording folder, Format | the recording folder, and which reader reads it (`Intan`, `Open Ephys`, `Binary`; blank when none does) |
| Recording time, Duration | the start time in the folder name, and the length read from the headers |
| ePsych file, ePsych time, Trials | the behavior file, the start time in its name, and its number of trials (for a stitched row every file, joined by `+`, and the total) |
| ePsych - recording | the time between the two starts (negative: the behavior started first, which is normal) |
| Destination | the local session folder |
| Result, Message | what Preview or the copy did with the row: `planned` (Preview), `copying`, `copied`, `already_present`, `skipped`, `failed` or `cancelled` |
| Note | why a row is unpaired or ambiguous; for a stitched row, each file's start |

### Watching a copy

While a batch is in flight a progress panel sits between the options and the
table, and closes again when the batch is done:

| | |
|---|---|
| headline | what is being done to which session: `Copying session 2 of 4   SUBJ-ID-1255_260914_101756`, or `Verifying (SHA-256) ...` during the checksum pass and `Stitching ePsych files for ...` while a stitched row is written |
| bar + percentage | the whole batch, counting the checksum pass as the two extra reads it is (`Verify=hash` makes copying the first third of the work) |
| detail line | the bytes of the batch that have moved, then the file the engine is on: `4.9 GB of 11.2 GB   amplifier.dat` |
| rate + time left | measured from the bytes themselves over the last 15 s, and from the fraction and how long it has taken so far. Neither is shown until there is enough of the copy to measure |
| **Result** column | the session being copied shows its own percentage (`copying 42%`, `verifying 42%`), the sessions behind it in the batch show `waiting`, and each becomes `copied` / `already_present` / `failed` when the batch is verified, or `cancelled` |
| **Copy** tab button | goes blue (busy) for as long as a copy is running, so it is visible from whichever tab the app has moved on to |

The copy percentage moves file by file, never ahead of what has been
copied: robocopy says nothing until it exits, so while it runs the engine
looks at the session's destination files about once a second and counts the
ones that are finished (the source's size and modified time). A large file
counts only once it is finished. The checksum percentage moves within a file,
as far as each SHA-256 has read. Closing the app stops the watching, not the
copy (see [`copySessions`](../pipeline/copySessions.m)).

**Pairing.** Names are parsed with strict, fully anchored patterns; any other
name in the subject folders is skipped and listed in the log. Candidate
pairs are resolved one-to-one across all of them at once, nearest |Δt| first,
so a file never goes to whichever session happened to be listed first. If a
file has a second candidate whose |Δt| is within the ambiguity margin of the
best one, every file linked to it by a candidate pair is marked **ambiguous**
and none of them is paired. Rows spanning midnight appear under either day.
A recording shorter than **Min duration** takes no part in the
pairing, so an aborted recording can neither claim the ePsych file nor make
the real recording ambiguous. It is listed as `recording_only` with the reason in
**Note**. A recording whose headers cannot be read has no known duration and
is paired as usual. An Open Ephys session is one row whatever its number of
recordings: it is copied whole, and its duration is that of all of them.

| Status | Row colour | Ticked after Find | Copied |
| --- | --- | --- | --- |
| `paired` | white | yes | yes |
| `stitched` | blue | yes, when stitched | yes, with its ePsych files stitched into one |
| `recording_only`, `epsych_only` | orange | no (tick by hand) | only when ticked |
| `ambiguous` | red | no; cannot be ticked | never: pair these files by hand, or stitch them |

**Copying.** Nothing in the source tree is modified, renamed, moved or deleted.
Before anything is copied, the free space under Destination is checked against
what is left to copy (the whole size of each missing or unfinished file,
nothing for a finished one), and the copy stops if there is too little.

The copying itself does not happen in MATLAB. `copySessions` plans the batch,
writes it as a job file and launches
[`copy_engine.ps1`](../pipeline/copy_engine.ps1) detached (Windows PowerShell
5.1, which ships with Windows), which runs
`robocopy <src> <dest> [files] /E /Z /MT:8 /R:3 /W:5 /NP /LOG+:<log>` **once
per source folder** rather than once per file — a folder of 200 files costs one
robocopy call instead of 200, which is worth seconds to minutes per session.
`/MIR`, `/MOV` and `/PURGE` are never used, so a file in the destination that is
not in the source is left alone; `/E` keeps empty source subfolders. Exit codes
8 and above, and negative ones, are failures. A robocopy ended from Task
Manager or `taskkill` exits with code 1 as if all went well, so after each
session the engine checks every file whose source has not changed since
robocopy started: one that is not finished fails the session. The engine reports one JSON line per file, which the
app tails; MATLAB keeps the decisions (what may be copied, what counts as
verified, the ePsych stitching, the manifest).

Because the engine is a separate process, the copy is non-blocking: the app
polls it twice a second and everything else stays usable. A copy even survives
closing the app — it finishes on its own, and the app says so before it closes.

**Resuming.** `/Z` makes robocopy finish a partially transferred file instead of
starting again, and it skips a file that is already there with the same size and
timestamp. With `If it exists = resume` a destination that holds part of a
session is therefore completed rather than refused: the missing files are
copied, the short or mismatched ones finished, and the rest left untouched. A
file robocopy was stopped in has its full size but not the source's time, so
it is copied again. This
is what makes a cancelled copy, a full disk or a dropped network share
recoverable — press **Copy selected** again. `skip` and `error` keep the old
behaviour and never write into such a folder.

**Verification.** A whole session is copied before any of it is checked, so a
session that fails verification keeps its complete partial copy and is marked
`failed`. MATLAB checks each destination file's size and modified time itself;
with `hash` the
engine is then run a second time to take the SHA-256 of every source and
destination file, except for a session found complete whose manifest records a
finished copy with matching checksums: it is `already_present` and its files
are not read again. Each session is handled separately, so one failure does not
stop the others. The failed sessions of a batch are listed, with the reason,
in one alert. `session_manifest.json` is written for every session copied
or found present (not by **Preview**); one that records a finished copy is kept
while the session is found complete, and one left by a cancelled or failed
copy is replaced. The manifest
([schema](file-formats.md#copy-manifest-session_manifestjson)) records the
source and destination paths, the reader of the recording, both times and Δt,
the pairing status, every file's size (and hashes),
how many files were already present, `ifExists`, for a stitched session the
stitched file and each source ePsych file with its trial count
(`epsych.stitch`), the copy start and finish times, the host, the user, and the
function version and git commit.

### Stitching ePsych files

When ePsych was stopped and started again during one recording, the
recording has several ePsych files, and pairing gives it at most one of them.
Select the recording's row and the rows holding its other ePsych files, and
press **Stitch selected rows**
([`stitchCopySessions`](../pipeline/stitchCopySessions.m)).
Rows of any status can be merged, including ambiguous rows and a row stitched
earlier. The files are always stitched in chronological order, whatever order
the rows are selected in. The stitched row keeps the recording folder and its
destination. **ePsych file** lists every file joined by `+`, **ePsych time**
and **ePsych - recording** belong to the earliest file, **Trials** is the total, and
**Note** gives each file's start relative to the recording. Stitching and
unstitching only change the table. **Preview** stitches the files in memory, so
files that cannot be stitched (different subjects, a session that starts
before the previous one's last trial, no start time) fail the row there,
before anything is copied.

The copy writes the ePsych files as one Epsych2 session,
`<earliest file name>_stitched.mat`, in place of the individual files
([`stitchEpsychSessions`](EphysPipeline.md#epsych2-sessions)). The session folder
therefore holds a single behavior file, which Scan associates with the recording
and the Trials tab pairs like any other. That file is checked right after it is
written. It must list the same source file names and sizes and hold as many
trials as they do. With `hash`, its `Data` and `Info` must also equal a fresh
stitch of the sources, and the SHA-256 of every source and of the file are
recorded. A destination that already holds a stitched file made from other
versions of the sources is `skipped` (or `failed`), like any other differing
copy. A session folder copied earlier with the other pairing (its ePsych file
unstitched, or stitched when this row is not) fails the row: remove that
behavior file by hand first.

### Scheduled copy

The **Scheduled copy** panel sets up a Windows Task Scheduler task that copies
new sessions at an interval ([`CopySchedule`](../pipeline/CopySchedule.m)). The
task starts MATLAB in the background (`MATLAB.exe -batch`: no desktop, no
window), which finds and copies the new sessions and exits. Neither the app nor
MATLAB has to be open, so sessions keep arriving in the destination for as long
as the computer is on.

A schedule copies with the roots, destination, pairing options, **Verify** and
**If it exists** above, as they are when it is saved. The panel holds only what
is its own:

| Control | Meaning |
| --- | --- |
| Subjects | subject IDs and patterns separated by spaces or commas, searched as **Find sessions** searches them; `*` alone is every subject. Each run looks at the subject folders on the source again, so a subject that matches is copied from the first run after its folder appears. Blank: the Subject ID above; blank there too: `*` |
| Every (min) | how often Windows starts a run, 5 to 1440 (default 60). Runs are on the clock: every 60 min is on the hour, every 15 min on the quarter hours |
| Days back | each run searches this many days, ending today (default 3; 1 = today only). A session already copied (its `session_manifest.json` records a finished copy, or Clean up has removed files from it) is left alone, so looking back costs little, and a run never copies files back; a recording copied on its own that now pairs still gains its ePsych file. It is how a run missed while the computer was off, or the source unreachable, is caught up |
| Quiet (min) | a session whose source changed within this many minutes is left for a later run (default 15), so a recording that is still being written, or still being synced to the source, is never copied half way. Every file and folder of the session counts |
| Run | **while I am signed in** (default): whenever you are signed in to Windows, with the screen locked too; no password. **even when I am signed out**: also after a restart or a sign-out. Windows asks for your password once, in a console window of its own, and keeps it with the task; the app never sees it. Save again after a password change. Some accounts are not allowed to run tasks while signed out: Windows then refuses, and the status line says so. Mapped drive letters do not exist outside a sign-in, so in this mode their paths are saved as UNC paths (`S:/...` becomes `\\server\share\...`) |
| Save schedule | saves the settings and creates (or replaces) the task |
| Remove | deletes the task. Copies already made, the log and the last run's summary are kept |
| Run now | has Windows start a run at once, in the background |
| Open log | the schedule's log: every run, every session |

The line under the controls says when the next run is and how the last one
went, e.g. `Every 60 min, while you are signed in: SUBJ-ID-1255 to D:/EPHYS.
Next run 15:00. Last run 14:00: 1 copied, 3 already present.` Its tooltip lists
the settings and what the last run did with each session it did not find
already copied. It is refreshed when the Copy tab is shown and, while a run is
under way, every few seconds. Problems are shown in red: a failed run, a
password Windows no longer accepts, a task disabled in Task Scheduler, or code
or a MATLAB that has moved.

**What a run copies**: the paired sessions of the days searched, with the same
checks as **Copy selected**. A run leaves these alone, and reports them in the
log and on the status line:

| Status | Session |
| --- | --- |
| `already_present` | a session copied before: its `session_manifest.json` records a finished copy, or Clean up removed files from it (`<Name>_cleanup.json`). It is left as it is even when files are missing from it: copying files back is done on the Copy tab. A recording copied on its own before its ePsych file existed is the exception: once it pairs, the run adds the ePsych file |
| `ambiguous` | an ambiguous pairing, never copied automatically (as on the Copy tab) |
| `unpaired` | recording only or ePsych only |
| `needs_stitching` | a paired recording with another ePsych file that starts during it: ePsych was restarted. Stitch the files on the Copy tab and copy it from there |
| `stitched_by_hand` | a session copied by hand with stitched ePsych files (its `session_manifest.json` says so), also when a later ePsych file starts during the recording: copying its paired row would add a second behavior file to the folder |
| `skipped` | its source changed within the quiet time, or another copy is writing it at that moment. A later run takes it |

**Two copies never write one session.** Every copy batch in flight (from the
app, a script or a scheduled run) keeps a job folder under
`%LOCALAPPDATA%\ephys_analysis\copy_jobs`, and a batch skips a session that
another batch is writing at that moment, saying so in its **Message**. This
matters when **Copy selected** runs while a scheduled run copies the same
session: copy it again once the other batch has finished.

**The task** is `\ephys_analysis\Copy sessions (<user>)` in Task Scheduler. It
never runs twice at once, runs on battery, starts a run missed while the
computer was off or asleep as soon as it is back, and stops a run after 12 h. It
runs the code and the MATLAB it was saved from, so save the schedule again after
moving either. MATLAB starts in the schedule's folder,
`%LOCALAPPDATA%\ephys_analysis\copy_schedule`, and runs the empty `startup.m`
kept there instead of yours. That folder also holds the settings, the log, the
last run's summary and MATLAB's own output of the last run (see
[What the app writes to disk](#what-the-app-writes-to-disk)). The same from a
script:

```matlab
sch = CopySchedule;                        % this Windows user's schedule
s = CopySchedule.defaults();               % roots, pairing, EveryMin=60, LookBackDays=3, QuietMin=15, ...
s.Subjects = ["SUBJ-ID-1255" "SUBJ-ID-13*"];   % or "*": every subject
sch.save(s);                               % write the settings, create the task
st = sch.status();                         % next run, last run, problems
sch.startNow();                            % a run now, in the background
out = CopySchedule.copyNew(s);             % one run's work, in this MATLAB
sch.remove();
```

### After copying

A copied session folder is an ordinary recording folder: scan it on the
[Project](#project) tab (**After copying, open the copied sessions as the
project** does that). An Open Ephys session needs the Open Ephys name pattern
there ([Open Ephys sessions](#open-ephys-sessions)). Because
`session_manifest.json` records where each file came from and its size, the
[Clean up](#clean-up) tab can later remove the local raw recording of a
preprocessed session while the source still holds every file with the same
size, and the clean-up record says where to copy it back from. Copying it
again with **If it exists** = `resume` copies only the missing files.

The tab's settings (the subjects, roots, pairing and copy options, not the
dates) are preferences. The scheduled copy keeps its own settings file, which
its task reads.

## Project

The Project tab is where a config starts: name it, point it at a folder of
recordings and scan it, choose where the outputs go and how dataset names
split into tokens, tick the datasets to process, and associate each recording
with its Epsych2 session.

<!-- wiki: ![The Project tab of a scanned project](images/app-project-tab.png) -->

| Control | Meaning |
| --- | --- |
| Config name, Description | `cfg.Name`, `cfg.Description`. The name is in the title bar and in the name of the script a run saves |
| Project root + Browse... + Recursive + **Scan** | `Project.Root`, `Project.Recursive` (on by default: every subfolder of the root is searched; off: only the root and the folders directly in it, for a flat project or to keep deeper folders out). **Scan** finds the recordings and reads them ([What Scan does](#what-scan-does)). Off while a run is under way |
| Refresh metadata | re-parse all headers, after files changed on disk (off while a run is under way) |
| Save the pipeline script on each run | `Project.SaveScript` (default on): each run, not a dry run, saves the config's standalone script as `<project root>\pipeline_<config name>.m`, replacing the one the previous run saved; a file of that name that no run saved is left as it is ([details](EphysPipeline.md#run)) |
| Output root + Browse... | `Project.OutputRoot`: each dataset writes to `<root>/<Name>`, its **output folder**; blank = next to the recording, in the recording folder |
| Name pattern + Columns | `Project.NamePattern`: how each dataset name splits into tokens ([Name pattern and token columns](#name-pattern-and-token-columns)); one checkbox per token, ticked tokens (`Project.TokenColumns`, default `SubjectID`) become table columns after Name. The label shows how many names match, or the pattern error. After a scan that found Open Ephys sessions whose names do not match, the status bar suggests `{SubjectID}_{Date:yyyy-MM-dd}_{Time:HH-mm-ss}*` |
| Filter | one editable dropdown per name-pattern token, listing the values found (`-` = the name does not match). Rows whose token does not match are hidden; type `*` / `?` wildcards or comma-separated alternatives (case-insensitive). Filters are a view only: they are not saved, and ticks on hidden rows stay in the selection (the label shows `showing k of n (m ticked hidden)`) |
| All / None | **All** ticks every shown row; **None** unticks every row, shown or hidden |
| **Source settings** panel (under the table) | the reader options of the **active dataset's** recording system (the [`Acquisition` section](EphysPipeline.md#acquisition)); the panel's title names the system and only its controls show. They are the config's, so they apply to every dataset of that system in the project, and a change rescans the project. **Open Ephys** ([Open Ephys sessions](#open-ephys-sessions)): what a session with several recordings is (**join recordings** = one dataset, **one dataset per recording** = part folders created in the session folder, **single recording only** = refused), **Record node** and **Stream** (blank = automatic). **TDT (Synapse)**: **Stream** (`Acquisition.TDT.Stream`: an editable list of the active block's stream stores, or a typed name; **automatic** = the stream with the most channels, the highest rate among those) and **Gain (µV per unit)** (`Acquisition.TDT.GainToMicrovolts`: blank = 1e6 for float streams, which TDT stores in volts; needed for a stream stored as integers; a value that is not a number is refused in the status bar), and a line saying what the active block reads (its tooltip lists the block's streams). Intan and binary recordings have no source settings; without an active dataset the panel says so. The Open Ephys options therefore show only once an Open Ephys dataset is scanned and active (a config file can set them before a scan) |
| **Tools** panel (beside the table) | opens datasets in another program. The box on top chooses which: **Active dataset** (the highlighted row) or **Ticked datasets** (the ticked rows, or every dataset when none is ticked, as a run takes them); the label under it names them, and how many of several have sorted output. **Manifest viewer**: each one's `<Name>_manifest.json` in a [manifest viewer](ManifestViewerApp.md), a window each, cascaded (the same as Dataset → View manifest...). **Analysis app**: one [analysis app](EphysAnalysisApp.md) on the project with those datasets selected (a new config in project mode with `Source.Selection = "list"` and their keys: it lists every dataset but ticks only these to run, the first of them active; `"all"` when they are every dataset); needs the repository's `analysis` folder on the path. **phy**: phy's template-gui on each one's associated sorted output, a window each (on only when one of them has `params.py`; the others are skipped). **Output folder**: each one's output folder in the file browser (an alert names those not written yet). Opening more than four windows at once asks first |

### What Scan does

1. It builds `EphysProject(root, Recursive=, ReaderOptions=)`: one dataset
   for every folder under the root that a registered reader
   ([readers](EphysDataset.md#acquisition-readers)) claims. That is a folder holding Intan
   `*.rhd` files (or `info.rhd` with its `.dat` files); an Open Ephys GUI
   session folder, the one holding `Record Node <id>` folders, in any of the
   GUI's record engines (Binary, Open Ephys format, NWB); a TDT Synapse block
   (a `*.tsq` file); or a folder with a `recording.json` descriptor (the
   [universal binary format](file-formats.md#universal-recording-format-recordingjson)).
   A dataset is named by its folder. An Open Ephys session read as **one
   dataset per recording** gives one dataset per recording instead
   ([Open Ephys sessions](#open-ephys-sessions)).
2. `P.refresh()` reads each dataset's header metadata (sample rate, channels,
   duration, files; no samples are read) and restores what its manifest,
   `<Name>_manifest.json`, records (`applyManifest`): its probe, excluded
   channels, manual artifact periods, sorted-output folder and Epsych2
   session.
3. A dataset with no Epsych2 session takes the one Epsych2 file (a `.mat`
   holding `Data` and `Info`) at the top of its own folder, when there is
   exactly one (`associateFolderBehavior`). That is where the [Copy](#copy)
   tab puts a session's behavior file, so copied sessions fill the
   **Behavior** column without any search folders. With none, or several,
   nothing is associated.
4. It rewrites each manifest with the fresh metadata (`writeManifest`).

A progress dialog with **Cancel** follows the scan. A dataset whose headers
cannot be read stays in the table with `NaN` metadata, and an alert lists the
datasets whose headers or manifest could not be read (a manifest that cannot
be read is left as it is).

### Open Ephys sessions

A dataset can be a session folder written by the Open Ephys GUI, named from the
GUI's prepend text, start time and append text
(`SUBJ-ID-1219_2026-07-07_16-35-39`, or with a suffix such as `_active`). The
session folder is the dataset; the Record Node, experiment and recording
folders inside it never are ([details](EphysDataset.md#open-ephys-sessions)).
The **Source settings** panel shows the Open Ephys options while an Open
Ephys dataset is active:

- **Recordings**: a session with several recordings (recording stopped and
  restarted, or acquisition restarted) is one dataset, its recordings joined
  end to end with a warning at each join (**join recordings**, the default);
  one dataset per recording (**one dataset per recording**: the scan creates
  a part folder per recording inside the session folder, named from the
  recording's own start time); or refused, reported per dataset (**single
  recording only**). `Acquisition.OpenEphys.Recordings`.
- **Record node**: the Record Node id to read (`101`); blank = the only one,
  or the lowest id when there are several. `Acquisition.OpenEphys.RecordNode`.
- **Stream**: the continuous stream to read, by name (`Rhythm Data`); blank =
  the stream with the most headstage channels. `Acquisition.OpenEphys.Stream`.

Changing any of them rescans the project, because it changes which folders
are datasets. Things to know about Open Ephys datasets:

- **Name pattern.** The default pattern does not match Open Ephys names. Use
  `{SubjectID}_{Date:yyyy-MM-dd}_{Time:HH-mm-ss}*` (the `*` takes an appended
  suffix), which the status bar suggests after such a scan.
- **Digital lines** are `TTL1`, `TTL2`, ... Name the trial line on the
  [Trials](#naming-digital-lines) tab (`TTL4` → `InTrial`).
- **Part folders.** With **one dataset per recording**, the session's Epsych2
  file is in the session folder, not in the part folder, so the behavior step
  finds it through the **Behavior** search folders, by start time. Two parts
  that start in the same minute would get the same unit labels: use **join
  recordings** for those.
- The **Format** column reads `openephys-binary`, `openephys-legacy` (the
  Open Ephys format) or `openephys-nwb`.

### Name pattern and token columns

Dataset names usually hold the subject and the recording's start, e.g.
`SUBJ-ID-1255_260908_103949`. **Name pattern** (`Project.NamePattern`) says
how a name splits into tokens; the default is
`{SubjectID}_{Date:yyMMdd}_{Time:HHmmss}`. A `{Token}` matches any text, a
`{Token:yyMMdd}` that many digits, `*` any text that is not kept, and anything
else itself; the whole name must match
([syntax](EphysPipeline.md#dataset-name-tokens)). Fixed text belongs in the
pattern: `SUBJ-ID-{SubjectID}_{Date:yyMMdd}_{Time:HHmmss}` gives
`SubjectID = 1255` for that name, the default `SUBJ-ID-1255`.

The tokens are used in two places:

- **Unit labels.** The `SubjectID`, `Date` and `Time` tokens label every
  sorted unit, e.g. `su042_1255_260908T1039` ([Unit labels](#unit-labels)).
  The Export step refuses to write units for a dataset whose name does not
  match.
- **The table.** Each token can be a column (**Columns**) and a filter
  (**Filter**).

### The Datasets table

Table columns (drag a header to reorder; the order is kept across refreshes
and saved in the app preferences; click a header to sort, and the sort is kept
the same way, see [Sorted tables](#sorted-tables)): **Select**, Name, the ticked name tokens
(`-` when the name does not match the pattern), **Key** (the folder relative to
the project root, e.g. `SYNTH-01/SYNTH-01_260914_131653`: what the config
stores, since folder names need not be unique), Acq date, Ch, Fs (Hz),
Dur (min), Format (`traditional`, `one-file-per-signal`,
`one-file-per-channel`, `openephys-binary`, `openephys-legacy`,
`openephys-nwb`, `tdt` or `binary`), Probe
(`default: <file>` when the dataset has none of its own and the config's
default probe applies), Exclude,
**Sorting** (units, `modified in phy` when phy saved a label, merge or split
there, see [What phy changed](#what-phy-changed); `auto` = found where
Kilosort4 writes it / `manual` = a folder chosen on the Sorting tab),
**Behavior** (subject, trial count and the recorded pairing status:
`pairing approved`, `pairing approved (auto)`, `pairing unreviewed`). A probe,
hand-picked sorted-output folder or Epsych2 session that is associated but not
there now (a disk or share not connected) reads `missing: <file>`
(`missing: manual` for the sorted-output folder). Ticks are written to
`Project.Datasets` as keys; with no ticks `Project.Selection` is `"all"`.
Clicking a row makes its dataset the active one; its row is highlighted.

### Behavior (Epsych2) sessions

The **Behavior (Epsych2)** panel associates each recording with its Epsych2
session file, a `.mat` holding `Data` (one element per trial) and `Info` (the
session snapshot). The association is saved in the dataset's manifest, and
the [Trials](#trials) tab reviews the trial-by-trial pairing. A recording
folder that holds exactly one Epsych2 file, as a folder the Copy tab wrote
does, is associated with it at the scan ([What Scan does](#what-scan-does)).
Nothing is plotted here.

| Control | Meaning |
| --- | --- |
| Behavior as a pipeline step | `Behavior.Enabled`: the run's behavior step |
| Search | `Behavior.Search` (on by default): look in the search folders for a session for each dataset that has none |
| search folders + **Add folder...** | `Behavior.SearchDirs`: folders searched recursively for Epsych2 `.mat` files, separated by `;` |
| Match | `Behavior.Match`: `prefix, then time` (default), `prefix only` or `time only` (below) |
| offset (min) | `Behavior.MaxStartOffsetMin` (default 30): the largest start-time difference the time rule accepts |
| **Find sessions for selected** | runs the behavior step now on the ticked datasets (all when none are ticked) |
| Associate file... / Clear | picks a session `.mat` for the active dataset by hand, or removes its association |
| Write behavior .mat | `Behavior.WriteFile` (default on): the step saves each associated session once as `<Name>_behavior.mat` in the dataset's output folder |
| Re-match existing | `Behavior.Overwrite`: the step also matches the datasets that already have a session |

The match rules ([`matchEpsychSession`](EphysPipeline.md#epsych2-sessions)):
**prefix**: the recording folder name, or one of its file names, starts with
the session file's name, which is how Epsych2 names Intan RHX recordings when
it controls the recorder; the longest name wins, and a tie is ambiguous.
**time**: the session whose start is nearest the recording's, within the
offset. **prefix, then time**: prefix first, then time.

What the behavior step does for each ticked dataset:

1. **Matches a session.** A dataset that has one keeps it unless **Re-match
   existing** is ticked. Result statuses: `associated`, `matched (prefix)`,
   `matched (time)`, `ambiguous`, `unmatched`, and `behavior file missing`
   for an association whose file is not there now (it is kept).
2. **Pairs the trials** with the trial line, when **Pair trials in the
   behavior step** is ticked on the Trials tab. A recorded pairing that still
   fits is reused; otherwise a new one is recorded as unreviewed, or as
   approved when **Auto approve when the counts match** is on and the counts
   match without cuts.
3. **Writes `<Name>_behavior.mat`**, when **Write behavior .mat** is ticked,
   on every run.

`<Name>_behavior.mat` is the only output that holds behavior data: the
Signals, Spikes and Export outputs do not carry it.

With **Search** off the step searches no folder and matches nothing: it pairs
and writes only the sessions already associated (by hand, or the one session
file in the recording folder that a scan associates), and reports a dataset
without one as `no session`. The search folders, match rule, offset and
**Re-match existing** are greyed out, and the step button reads **Write
behavior for selected**.

## Trials

Review how each trial is paired with an interval of the trial digital line,
and approve it ([How trials are paired](#how-trials-are-paired)). The
approved pairing gives every trial its onset and offset on the recording's
clock, in seconds and in samples, which `<Name>_behavior.mat` holds. The
trials come from the dataset's trial source: its Epsych2 session
([Behavior (Epsych2) sessions](#behavior-epsych2-sessions)), or, for a TDT
block without one, the epocs of the store named as the trial line
(`EphysDataset.behaviorSource`; those pair one to one with their own line and
are approved as paired). A dataset with neither has nothing to load.

With many datasets, **Prefetch ticked** reads the digital lines of every
ticked dataset in one go, and with **Auto approve when the counts match** on,
every pairing that needs no cuts is approved on the way. Only the ones left
need a look here.

<!-- wiki: ![The Trials tab with an approved pairing: 12 trials, 12 intervals](images/app-trials-clean.png) -->

| Control | What it does |
| --- | --- |
| Dataset + **Load** | the active dataset. Load reads its digital lines (`digitalEvents`: cached on disk after the first read, kept in memory while it stays active) and pairs the trials in order, reusing the cuts recorded in the manifest when they still match. Choosing another dataset clears the pairing shown, including cuts not yet approved |
| **Prefetch ticked** | reads and caches the digital lines of every ticked dataset that has a trial source ([Prefetching many datasets](#prefetching-many-datasets)) |
| **Reset cuts** | shows the pairing without cuts: every trial with every interval in order. It writes nothing: the recorded cuts stay in the manifest until **Approve pairing** or **Mark unreviewed** |
| **Approve pairing** / **Mark unreviewed** | `setTrialPairing(P, "approved" / "unreviewed")`: saves the shown cuts in the manifest, and rewrites an existing `<Name>_behavior.mat` with them (the status bar says so). Without that file, run the behavior step or press **Write behavior .mat** |
| **Write behavior .mat** | `behaviorToMat(Pairing=P)` now, without running the step |
| **Trial source to workspace** | loads the trial source into the base workspace: the associated Epsych2 session file as saved (`Data`, `Info`) as `epsych_<Name>`, or a TDT block's epoc stores (`TDTReader.readEpocs`, one element per store) as `epocs_<Name>`; an alert and the status bar give the variable's name. A variable of that name is replaced |
| **Behavior to workspace** | loads the `behavior` struct of `<Name>_behavior.mat` (trials with the pairing columns, `info`, `meta`, `pairing`, ...) into the base workspace as `behavior_<Name>`, the same way. The file must exist: run the behavior step or press **Write behavior .mat** first |
| **Pair trials in the behavior step**, **Trial line** | `Behavior.PairTrials`, `Behavior.TrialLine` |
| **Auto approve when the counts match** | `Behavior.AutoApprove` (off by default): approve a pairing as soon as it is paired, when it needs no cuts ([Auto approval](#auto-approval)) |
| Lines table (**Native**, **Name**, **Intervals**, **Inverted**) | one row per digital line: its native name (`DIGITAL-IN-04`, Open Ephys `TTL4`), its name, and its interval count. Edit **Name** to rename a line ([Naming digital lines](#naming-digital-lines)); tick **Inverted** for a line whose TTL logic is inverted ([Line polarity](#line-polarity)) |
| **Resolve a count mismatch** | four spinners: trials and trial-line intervals to cut from the start and from the end before pairing. They belong to the dataset (its manifest), not to the config; cuts that would drop more than there is are refused. They are enabled once a pairing is loaded |
| Trials table | trial, `TrialIndex`, interval, onset / offset (s), onset / offset sample, flag (orange = partial: the interval touches the recording start or end; grey = cut; red = unpaired), the other lines overlapping the trial. Click a header to sort, drag it to move the column. Right-click for **Parameter columns** (the loaded trials' parameters in alphabetical order: Epsych2 parameters, or the other epoc stores' values at each trial onset; tick one, e.g. `TrialType` or a response code, to show it after Flag), **Remove "*name*"** (on a parameter column) and **Reset column order**. The chosen parameters and the column order are preferences, so they apply to every dataset and the next session; a parameter a session lacks is not shown there (the menu lists it as *not in these trials*) and returns to its place for sessions that have it. Values that are not one number, text or date per trial are shown as text. A header click's sort is kept when the table refreshes (Load, a cut, a setting or a column change), for every dataset and the next session; the flag colours follow their rows, and right-click → **Clear sort** returns to trial order ([Sorted tables](#sorted-tables)) |
| Plot | the digital lines over the recording: one bar per event, from its onset to its offset. A normal line's bars run from each rising edge to the next falling edge; an inverted line's (row label `(inverted)`) from each falling edge to the next rising edge. The trial line's bars are coloured by pairing state (paired, partial, cut, unpaired), and dotted lines across every row mark its onsets and offsets. Right-click the plot to show or hide those lines (shown by default) and the grid lines (hidden by default), and for **Trial labels**: the loaded trials' parameters in alphabetical order (`TrialIndex` included). A ticked parameter writes each paired trial's value above the trial line, starting at the trial's onset; with several ticked, each label reads `name=value, name=value` in the order ticked, and the plot title names them. **No labels** clears them. Like the table's parameter columns, the choice is a preference: it applies to every dataset and the next session, and a parameter a session lacks is listed as *not in these trials* and not written. Zoom and pan are horizontal only: the mouse wheel zooms time in and out about the cursor, dragging pans time |

The summary line under the buttons says whether the pairing is
**APPROVED**, **APPROVED automatically (the counts match)**, **recorded, NOT
REVIEWED** or **NOT RECORDED - review, then Approve**; whether a recorded
pairing went stale (the session, the trial line, its polarity or its
intervals changed: its cuts are dropped); and, with a **WARNING**, when the
numbers of trials and intervals differ, naming any partial intervals.
Changing a setting or a cut re-pairs at once. Cuts are not saved until you
press **Approve pairing** (or **Mark unreviewed**).

<!-- wiki: ![The Trials tab with a count mismatch: 12 trials, 10 intervals, the first partial](images/app-trials-mismatch.png) -->

### How trials are paired

Epsych2 holds a digital line on for the duration of every trial: `InTrial` by
default, recorded as an Intan digital input of that name (on Open Ephys, a TTL
line you [name](#naming-digital-lines) `InTrial`). The rule
([details](EphysPipeline.md#pairing-trials-with-the-trial-line)):

- **In order.** Trial 1 pairs with the first interval of the trial line,
  trial 2 with the second, and so on. The Epsych2 timestamps are not used:
  every interval is taken to be one trial.
- **Count check.** The only thing to check is that the numbers of trials and
  intervals are equal. When they differ, the first `min(trials, intervals)`
  still pair in order, and the summary warns.
- **Cuts resolve a mismatch.** Trials or intervals are dropped from the start
  or the end before pairing (**Resolve a count mismatch**). Cuts belong to the
  dataset: they are saved in its manifest, not in the config.
- **Edge intervals.** An interval that begins at the first sample of the
  recording, or ends at the last, is partial: the line was already on when
  the recording started, or still on when it stopped. Partial intervals are
  flagged, and the warning names them, because they are usually what has to
  be cut.

| What happened | What you see | Cut |
| --- | --- | --- |
| the recording started after the session began | fewer intervals; the first may be partial | the trials that ran before the recording, from the start. A partial first interval is the trial the recording started in: cut it as well, or keep it paired with its trial |
| the recording stopped before the session ended | fewer intervals; the last may be partial | the last trials, and a partial last interval, from the end |
| the line pulsed once before the first trial | one extra short interval | one interval from the start |
| an inverted line was at its active level before Epsych2 started | an extra partial first interval | one interval from the start |

The [synthetic test project](#synthetic-test-project) has one dataset of each
of the first three kinds, and a clean one.

<!-- wiki: ![The Trials tab after cutting three trials and one interval from the start](images/app-trials-resolved.png) -->

### Auto approval

With **Auto approve when the counts match** ticked (`Behavior.AutoApprove`,
off by default), a pairing is approved as soon as it is paired (**Load**, a
setting change, **Prefetch ticked**, the behavior step) when it is not
approved yet, it cuts nothing, and the trials and the trial-line intervals
are equal in number, at least one
(`EphysDataset.autoApproveTrialPairing`). The manifest marks the approval as
automatic (`auto_approved`), the summary reads *APPROVED automatically (the
counts match)* and the Project table *pairing approved (auto)*; an existing
`<Name>_behavior.mat` is rewritten with the approved pairing. A count
mismatch, and a pairing whose cuts resolved one, still need **Approve
pairing**: those cuts are yours to approve. **Reset cuts** and cut edits never
approve; approving by hand replaces the automatic mark.

Equal counts do not prove the pairing right: a missing trial at one end and a
spurious pulse at the other also give equal counts. Leave the box off to look
at every dataset.

### Naming digital lines

Every digital line has a native name, from the hardware (Intan
`DIGITAL-IN-04`, Open Ephys `TTL4`), and a name it goes by. Intan RHX names
the lines at acquisition (`InTrial`); Open Ephys does not, so its lines are
`TTL1`, `TTL2`, ... until you name them. Editing a line's **Name** in the
lines table writes a `Signals.LineNames` entry `native=name` (`TTL4=InTrial`),
which is part of the config, so it applies to every dataset. A name equal to
the line's default, or a blank cell, removes the entry. A name must be a valid
MATLAB name, and two lines cannot share one. The pairing is redone at once
from the lines already read, without reading the recording again, and the
trial line and the inverted lines follow the new name
([Digital-line names](EphysPipeline.md#digital-line-names)). Names apply to
the pairing and to the events the Signals step writes, and so to the exports.

### Line polarity

Readers return every digital line as its high runs. A line ticked
**Inverted** (`Signals.InvertedLines`) is on while low:

| Polarity | On while | Onset | Offset |
| --- | --- | --- | --- |
| normal (default) | high | rising edge | last high sample |
| inverted | low | falling edge | last low sample |

An inverted line's intervals are the complement of its high runs, so a low
stretch at either end of the recording counts as a (partial) interval. The
plot labels the line `(inverted)`. Polarity applies to the pairing and to the
events the Signals step writes, and so to the exports
([Digital-line polarity](EphysPipeline.md#digital-line-polarity)). Setting a
line's polarity back brings its approved pairing back.

### Prefetching many datasets

**Prefetch ticked** reads and caches the digital lines of every ticked
dataset (Project tab) that has a trial source (an Epsych2 session or TDT
epocs), one after the other (`digitalEvents` for each), so a later **Load**,
the pairing and the behavior step take them from `<Name>_events.mat` instead
of reading the recording. A dataset whose cache is still current is only
checked. With nothing ticked, it asks you to tick some.

- The progress dialog names the dataset and the file being read; **Cancel**
  stops before the next file and keeps what was cached.
- With **Auto approve when the counts match** on, each dataset is also paired,
  and a pairing that qualifies is approved.
- The status bar sums it up: read, already cached, skipped for want of a trial
  source, failed; with auto approval, approved automatically, already
  approved, need review. An alert lists the pairings that need review (with
  the reason, e.g. `12 trial(s) vs 10 interval(s)`) and any failures.

Reading the lines is the slow part of the Trials tab, so prefetching a day's
recordings first makes the review itself quick.

### What gets written

| Action | Writes |
| --- | --- |
| **Load**, **Prefetch ticked** | `<output folder>/<Name>_events.mat`: a cache of the raw digital lines |
| **Approve pairing** / **Mark unreviewed**, or an automatic approval | the dataset's manifest: the status, the cuts, whether the approval was automatic, a fingerprint of the session and the trial line, a summary |
| editing a line's **Name** or **Inverted** | the config (`Signals.LineNames`, `Signals.InvertedLines`): save it to keep the change |
| **Write behavior .mat**, or the behavior step with **Write behavior .mat** on | `<output folder>/<Name>_behavior.mat`: the trials with the pairing columns (`TrialOnset`, `TrialOffset`, sample columns at the recording rate and at each derived signal's rate, `PairingFlag`, `TrialEvents`, ...) and a `pairing` summary ([format](file-formats.md#behavior-mat-ephysdatasetbehaviortomat-the-behavior-step)) |

In a run, the behavior step reuses a recorded pairing that still matches
(result `approved` or `needs review`) and records any other as unreviewed, or
approves it (`auto-approved`) when **Auto approve when the counts match** is
on and it qualifies. A mismatch is a `count mismatch` result row and a
`WARNING` log line. Exports are never blocked by an unreviewed pairing: the
review is yours to do.

## Probe

The Probe tab manages Kilosort4 probe maps: it picks the probe of each
recording, sets the config's default probe and probe rules, and marks the bad
channels to leave out.

<!-- wiki: ![The Probe tab with the synthetic project's probe and one excluded channel](images/app-probe-tab.png) -->

### Probe maps

A probe map is a Kilosort4 probe `.json`
([format](file-formats.md#kilosort4-probe-json)): the site of every channel.
`chanMap` holds the 0-based recording channel of each site (a row of the
`.bin` Kilosort4 sorts), `xc` / `yc` its position in µm, `kcoords` its shank
(Kilosort4 places templates per shank), `n_chan` the channel count and
`notes` free text. The default folder,
[`pipeline/probes`](../pipeline/probes/README.md), holds
`H64LP_4x16lin_probemap.json` (64 channels, 4 shanks),
`Buzsaki64_5x12-H64LP_30mm.json` (64 channels, 5 shanks) and
`linear16_example.json` (16 channels, 1 shank), each with a
`<probe>.ks4.json` of Kilosort4 parameters for its layout
([Optimize for probe](#optimize-for-probe)).

### The probe list

- **Probe folder** + **Browse...** + **Refresh** list every probe `*.json` in
  the folder (not recursive; a probe's `<probe>.ks4.json` parameter file and
  `<probe>.chanmap.json` channel-map sidecar are not listed). The folder is a
  preference (`ProbeFolder`). The **probe table** shows Probe, Ch, Shanks,
  Depth (µm, the span of `yc`) and Notes; the Notes cell is editable and
  written back into the file, where only the `notes` text changes.
- **Probe info** shows the file, `n_chan`, `chanMap` length, shank count,
  whether the probe has a Kilosort4 parameter file
  ([Optimize for probe](#optimize-for-probe)), and a channel-count check
  (`OK` / `MISMATCH`) against the active dataset. When Kilosort4 could not
  read the probe (`probeMapProblems`: no `kcoords`, an extra list, ...), the
  check line says why in red instead; `runKilosort` refuses the probe with the
  same reasons.
- The **preview plot** shows sites by shank; excluded sites are gray `x`.
  **Show channel numbers** labels each site with its 1-based channel.
  **Show kcoords** labels each site with its `kcoords` group (`k1`), or
  `12 (k1)` with the channel number when both are ticked.
- **Design probe (probeinterface)...** opens the
  [probe designer](#the-probe-designer); **Import probe .json into
  folder...** copies a probe map into the folder, and its `.ks4.json`
  parameter file and `.chanmap.json` sidecar too, when it has them (it asks
  before overwriting); **Edit probe .json...** opens the selected map in the
  MATLAB editor.
- **Map channels...** (also **File → Channel mapper...**) opens
  [`ChannelMapperApp`](ChannelMapperApp.md). It follows each site of a probe
  design through its package (NeuroNexus H32, H64LP ...) and headstage (Intan
  RHD2132, RHD2164 ...) to its recording row. It shows the map as a table you
  can copy and as pictures of the mated connectors, and exports the Kilosort4
  probe `.json` into this folder. Recording rows can come from the active
  dataset's channel numbers.

### Assigning probes

- **Assign to selected datasets** (the ticked rows, else the active dataset)
  / **Assign to all datasets** set `ProbeFile` (and, for all, the Exclude
  field) and write the manifests at once, so the assignments survive a rescan
  and apply to scripts that run the same recordings. A channel-count mismatch
  is reported but never blocks.
- **Default probe** (`Probe.DefaultProbeFile`) + **Use selected probe**: the
  probe used for every dataset that has none of its own (the probe check,
  sorting, the derived signals' bad-channel geometry, the Artifacts viewer's
  lanes); it is not assigned to them. **Save to manifests**
  (`Probe.WriteDefaultToManifest`) makes the run's probe check assign it and
  save it in their manifests.
- **Probe rules (by subject)**: a table of *Subject* pattern → *Probe file*
  (`Probe.RuleSubjects` / `Probe.RuleProbes`). The subject is the `SubjectID`
  token of the dataset name (Project → Name pattern); the pattern takes `*`
  and `?`, is not case sensitive, and `*` matches every dataset in the project.
  The first matching rule gives a dataset its probe. **Add rule (selected
  probe)** adds a row for the active dataset's subject and the probe selected
  above; edit the cells for a group of subjects (`su04*`). **Apply rules now**
  assigns the probe of the matching rule to every dataset that has none of its
  own and saves it in the manifest. With **Assign automatically**
  (`Probe.AutoAssign`) the rules are applied on every Scan and in the run's
  probe check. A dataset's own probe is never replaced, and a rule whose probe
  file is missing assigns nothing (the probe check reports it). Rules go
  before the default probe, which still covers the datasets no rule matches.
  **Remove rule** deletes the selected row.

One probe for the whole project: make it the default probe. Different probes
per recording: assign them per dataset, or by rules. A dataset's own probe
always wins. The Probe button in the tab strip turns amber while a selected
dataset has no probe, or a probe file that is not there.

### Excluding channels

**Dataset** + **Exclude channels** (1-based recording channels, `1,5,32-40`)
holds the exclusions of the active dataset, written to its manifest when the
field is committed (Enter, or a click elsewhere). The list is parsed
strictly: text that does not parse changes nothing, an alert says why and
the field shows the list in force again. Channels beyond the dataset's
channel count are dropped, and the status bar says so. How exclusions reach
each step:

| Step | Excluded channels |
| --- | --- |
| Sorting | stay in the `.bin`; their sites are taken out of a copy of the probe map, `<probe>_excluded.json` in the run folder, and the probe map itself is never changed ([EphysDataset → Channel exclusions](EphysDataset.md#channel-exclusions)) |
| Signals | follow **Manifest exclusions** on the [Signals](#signals) tab (`Signals.ExcludeHandling`: `none`, `drop` or `interpolate`) |
| Spikes | are skipped when **Channels** is *all except manifest exclusions* on the [Spikes](#spikes) tab (`Spikes.Channels = "excludeManifest"`) |

### The probe designer

**Design probe (probeinterface)...** opens
[`ProbeDesignerApp`](ProbeDesignerApp.md), which builds a probe map from
[probeinterface](https://github.com/SpikeInterface/probeinterface): from a
manufactured probe in its library, or from a generated geometry (linear,
multi-column, tetrode). You wire each contact to an amplifier channel and
save a plain Kilosort4 probe `.json` into the probe folder, so nothing
downstream depends on probeinterface. The designer runs
[`probe_tool.py`](python-drivers.md#probe_toolpy) with the Sorting tab's
**Python exe** (the `kilosort` environment has probeinterface).

<!-- wiki: ![The probe designer with a generated two-column probe](images/probe-designer.png) -->

## Artifacts

Artifact periods are stretches of a recording that the steps leave out:
Sorting erases them in the `.bin` Kilosort4 sorts, Signals in the data it
derives LFP / MUA / SPIKE from, and Spikes rejects the events inside them or
erases them before detection ([In a run](#in-a-run)). The recording files are
never changed. A period comes from one of two sources:

| Source | Where it comes from | Applies |
| --- | --- | --- |
| manual periods | marked by hand on this tab's plot (**Mark artifacts**); saved in the dataset's manifest | always |
| automatic detections | the detector set up here, run over the whole recording by the pipeline's `artifacts` step | while **Enable automatic detection** is ticked, to the steps ticked under it |

<!-- wiki: ![The Artifacts tab after Detect / Preview](images/app-artifacts-tab.png) -->

The tab holds the automatic detector
([`EphysDataset.detectArtifacts`](EphysDataset.md#artifact-detection-and-blanking))
and the manual periods, after the common reference, in three columns: the
common reference and the detection settings with the active
dataset's manual periods below them, the artifact viewer at full height (one
plot, where the detected artifacts are reviewed and the manual periods
marked), and two tabs on the right: **Preview** (the preview's summary with
its per-channel table) and **Selection** (a stretch measured with **Measure**,
below).

The first panel, *Common reference, for every step (config: Reference)*, is
the config's `Reference` section, not part of `Artifacts`: every step that
reads the recording takes the reference, whether or not detection is on, and
a problem with it colours this tab even while detection is off. It sits here
because detection is the first of those reads, and the viewer shows the
referenced signal. The Signals tab picks which derived signals take it.

| Control | Maps to |
| --- | --- |
| Reference: *None (as recorded)* / *CAR: common average* / *CMR: common median* | `Reference.Mode` (`"none"` / `"car"` / `"cmr"`), a setting for the whole pipeline: subtract, sample by sample, the mean or median of the good channels from every channel, once, as each step reads the recording - artifact detection, the noise level of the fill, the Kilosort4 `.bin` (Kilosort4's own `do_CAR` is then turned off, so it is not referenced twice), spike detection, the derived signals ticked on the Signals tab (MUA and SPIKE by default, not the LFP), and the Visualize tab's *As the pipeline*. The preview and the viewer show the referenced signal. See [Common reference](EphysDataset.md#common-reference-car--cmr) |
| Good noise (x median): *low* to *high* | `Reference.BadLow`, `BadHigh` (0.3 and 2, Ludwig et al. 2009): a channel whose noise floor lies outside this band, relative to the median across channels, is suggested to stay out of the reference |
| Left out, **Suggest** | the active dataset's `ReferenceExclude` (written to its manifest): channels kept out of the average, though still referenced. **Suggest** measures each channel's noise floor on a sample of the recording and fills the field (each channel's ratio goes to the log); typing a list marks it set by hand. A list that does not parse changes nothing (an alert says why). A dataset whose list was never set gets the suggestion on its first referenced run or preview. Channels excluded on the Probe tab stay out of the reference too |
| **Enable automatic detection** | `Artifacts.Enabled`: run automatic detection (manual periods always apply) |
| Dataset | the active dataset: the one **Detect / Preview** analyzes and whose manual periods are listed |
| Method, Threshold, RMS window, Stitch gap, Pad, Min channels | `Artifacts.Method`, `Threshold`, `RmsWindowMs`, `MergeGapMs`, `PadMs`, `MinChannels` |
| High-pass before detecting, High-pass (Hz) | `Artifacts.Filter`, and `FilterCutoff`: a high-pass filter's cut-off, or a band-pass filter's lower edge. `FilterType`, `FilterOrder` and a band's upper edge have no control and keep the config's values; with a low-pass filter (a config written by hand or by a script) the field is off. They apply to runs as well as the preview |
| Erase with: *Gaussian noise (recording level)* / *Zeros* | `Artifacts.Fill` (`"noise"` / `"zero"`): what replaces the artifact samples, manual periods included. Noise by default - Kilosort4 reads a block of zeros across every channel as a signal discontinuity. Each period becomes a straight line between the signal's levels on either side plus that noise; its level is measured on up to 16 chunks spread over the recording, above `Artifacts.NoiseBandHz` (300 Hz), and `Artifacts.NoiseSeed` makes a rerun repeat; neither has a control here |
| Erase in sorting (in the .bin the selected sorter sorts) / Apply in spike detection (reject or erase: Spikes tab) / Erase in the signals (LFP / MUA / SPIKE, before filtering) | `Artifacts.ApplyToSorting`, `ApplyToSpikes`, `ApplyToSignals`: whether the detected artifacts reach those steps (manual periods always do). The signals take any periods only while the Signals tab's *Erase the artifact periods first* is ticked, and spike detection only while the Spikes tab's *Artifact periods* does not ignore them |
| Cache intervals | `Artifacts.CacheIntervals` (`<Name>_artifacts.json`) |
| Order channels by probe layout | display only, not saved: the viewer's lanes and the per-channel table in probe order (below). Needs a probe (the dataset's, else the config's default probe), and is ticked by default when there is one |
| **Detect / Preview** | `analyzeArtifacts` over the active dataset (streamed, read-only; on the process pool when the Run tab's **Parallel** box is ticked): summary + per-channel table, and the detected artifacts in the viewer |
| Detected artifacts: ◀ / number / ▶, Go to (s), Context (ms), Channels, Shank, Colour by shank, Scale, **Shade artifacts**, **Reset view** | the artifact viewer (display only, below) |
| **Measure**, the **Selection** tab | display only: a stretch dragged over the plot, scored by every detection method (*Measuring a stretch*, below) |
| Ctrl+drag on the viewer, **Restore bounds** | the active dataset's `ArtifactAdjustments`: detected artifacts with their onset or offset moved by hand (written to its manifest; *Moving a detected artifact's bounds*, below) |
| Manual periods table, **Mark artifacts**, **Clear** | the active dataset's `ManualArtifacts` (written to its manifest); **Mark artifacts** marks them on the viewer's plot (*Marking manual periods*, below), **Clear** removes them all |

Changing **Method** replaces the threshold with the new method's default
(*Running RMS* 9, *MAD* 8, *Absolute microvolts* / *Common-mode* 1500 µV) when the
field still holds the previous method's default; a threshold typed for the
previous method stays. `validate` warns about an *Absolute microvolts* or
*Common-mode* threshold below 50 µV.

**Detection methods.** Each method flags samples one channel at a time:

| Method | A sample is flagged on a channel when | Threshold in |
| --- | --- | --- |
| *Running RMS (per-channel SD)* (default) | its running RMS (over **RMS window**; 0 = about 1 ms) is more than *Threshold* robust SDs (1.4826 × MAD of the RMS) above the channel's median RMS | robust SDs |
| *MAD (per-channel SD)* | \|x − median\| / (1.4826 × MAD) > *Threshold* | robust SDs |
| *Absolute microvolts* | \|x\| > *Threshold* | µV |
| *Common-mode (mean)* | \|mean over the channels\| > *Threshold*, on every channel at once. It is measured on the signal as recorded, since a common reference subtracts that very mean | µV |

A sample is an artifact when at least **Min channels** channels flag it at
once (common mode aside). Runs of artifact samples separated by at most
**Stitch gap** of clean signal are joined, and each run is widened by **Pad**
on both sides. The channels excluded on the Probe tab take no part. The
detector works chunk by chunk as it streams the recording: each chunk has its
own median and MAD, and runs are not joined across chunk boundaries (the
periods a run uses merge them again). See
[Artifact detection and blanking](EphysDataset.md#artifact-detection-and-blanking).

**The preview.** **Detect / Preview** fills the **Preview** tab on the right.
Its summary gives the settings (method and threshold, RMS window, stitch gap
and pad, min channels), what was read (duration, channels, samples, rate),
the samples flagged and their share of the recording, the number of
intervals, the worst channel, and whether a run applies the detection
(*applied* while **Enable automatic detection** is ticked). The per-channel
table lists **Ch**, **Name** (and **Shank** with a probe), **#Samples**
flagged on that channel and **% of duration**. Those counts come before the
**Min channels** combination, so they show which channels drive the
detections. The preview writes nothing.

**Artifact viewer.** After a preview, the middle plot shows one
detected artifact at a time (◀ / ▶ or type its number), with **Context** ms of
signal either side (0 = auto: twice the artifact's length, 25 ms to 5 s). It
draws the signal the detector saw (high-passed when *High-pass before
detecting* is ticked) for the **Channels** the artifact is largest on, one lane
each, against recording time (s). Samples a run would remove are
**red** and those it keeps are **black** (red is what gets replaced: in the
`.bin` by noise or by zeros as *Erase with* says, in the signals by a straight
line). The two kinds of period are told apart by colour: detected (automatic)
artifacts are shaded **orange** and manual periods **purple**, as on the
Visualize tab, and the one shown has dashed lines at its onset and offset.
**Shade artifacts** (amber while on) or **S** over the plot turns the shading
off to show the signal under it; the dashed bounds stay. What counts as removed follows the controls as they are set:
manual periods always, and detected artifacts only when **Enable automatic
detection** is ticked together with *Erase in sorting*, *Apply in spike detection* or *Erase in the
signals*. The line above the plot says which of them apply, and it warns when a detection setting has changed
since the preview. **Scale** fits the lanes to the whole window, or to the
kept signal: six robust SDs of the signal outside the artifacts (at most the whole
window's fit), so the artifact and any leftover of it are clipped and you can
check that none of it is left on either side. **Manual** takes the lane spacing typed in **Lanes
(uV)**; otherwise that field shows the spacing drawn, and typing in it switches
to Manual (0 goes back to fitting). Every built-in reader reads just the
window shown (an Intan traditional file block by block); a third-party reader
without random access reads the chunk that holds the artifact once and keeps
it while you step through that chunk's artifacts. A new active dataset clears
the viewer.

**Go to (s)** shows a stretch of the recording instead of an artifact: from
the time typed, 2 s long (or as wide as the stretch already shown), at most
10 s and kept inside the recording, drawn as the detector sees it (filtered
as the last preview, else as the detection settings say). No artifact is
chosen, so there are no dashed bounds; every detected artifact and manual
period in it is shaded, and the channels drawn are the ones largest in it.
It works before any preview, so manual periods can be marked anywhere. On a
stretch, PgDn / PgUp page to the next / previous stretch as wide and End /
Home go to the recording's end / start; ◀ / ▶ go back to the detected
artifacts (the last before the stretch, the first after its start).

**Probe layout.** With a probe (the dataset's, assigned on the Probe tab, else
the config's default probe), *Order channels by probe layout* is ticked by
default. The lanes are then drawn as
the channels sit on the probe: shank by shank, from the top of each shank down
(larger `yc` first, as the Probe tab draws the probe), with a dotted line
between shanks. The per-channel table follows the same order and gains a Shank
column. **Shank** limits the lanes to one shank's channels, and **Channels**
still picks the ones the artifact is largest on. **Colour by shank** (on by
default) draws each shank's kept signal in its own colour, named in the
legend. Removed samples stay red. The probe's `chanMap` values are `.bin`
rows, as for sorting: recording channel `c` sits at the site whose `chanMap`
value is `c − 1`
([`EphysDataset.channelLayout`](EphysDataset.md#probe-layout)). The detectors
treat every channel alike, so the order only changes the display. Changing the
active dataset, assigning it a probe, or, for a dataset without one, changing
the default probe (an edit, or an opened config) resets the checkbox to its
default.

**Scaling and stepping.** The plot's x axis is recording time (s). Keep the pointer over the plot:

| Input | Does |
| --- | --- |
| wheel (or Shift+wheel) | zoom time about the pointer |
| Ctrl+wheel (or Ctrl+Shift+wheel) | scale the voltage |
| drag, ← / → | pan time |
| Shift+← / Shift+→ | zoom time out / in |
| ↑ / ↓, + / − | scale the voltage up / down |
| PgDn or N, PgUp or P | next / previous artifact (with Shift, ten on); on a stretch, the next / previous stretch |
| End, Home | last / first artifact; on a stretch, the recording's end / start |
| S, **Shade artifacts** | shading on / off |
| R, **Reset view** | show the whole window at the Scale fit |
| Ctrl+drag | move the artifact's onset or offset (below) |
| drag, click (with **Mark artifacts** on) | mark a manual period; remove the one clicked (below) |
| M, **Measure** | Measure on / off |
| drag, click (with **Measure** on) | select a stretch and score it; clear the selection (below) |
| Esc | turn **Mark artifacts** or **Measure** off |

The voltage scale carries over from one artifact to the next until **Reset
view** or a new **Scale**; with Manual the voltage keys change **Lanes**.
The time zoom is kept while the same artifact is
shown, and a long window is redrawn in finer detail as you zoom in. The
y-axis label gives the lane spacing in µV and says when larger values are
clipped. On other tabs the wheel and keys work
as before (on the Visualize tab, its own shortcuts).

**Moving a detected artifact's bounds.** Hold **Ctrl** with the pointer over
the plot: it turns into a left or right
resize arrow for the shown artifact's bound nearer to it (onset or offset),
and the plot's own drag-to-pan pauses. Drag with Ctrl held to move that bound.
The dashed line (and the shading) follow the pointer, on the sample grid and at
least a sample from the other bound. Letting go of the button records the new
bounds for the active dataset (`EphysDataset.setArtifactAdjustment`, saved in
its manifest as `artifact_adjustments`), and the plot redraws what a run would
remove with them. The title says *bounds moved by hand*, the count says how
many are moved, dotted grey lines mark where the detector put the bounds, and
time stays measured from the detected start. **Restore bounds** puts the
shown artifact back as detected. Moving is refused while a run is under way.

A moved artifact is found again by its detected bounds
(`EphysDataset.adjustArtifacts`). Every step that uses the automatic
detection takes it with the moved bounds: `artifactIntervals`, the
pipeline's cached detection (`EphysPipeline.artifactIntervalsFor`; no new
detection is needed) and the Visualize overlay. When other detection settings
no longer find the artifact, the adjustment is not applied. It stays in the
manifest and applies again if those settings come back. `toBin`'s own
chunk-by-chunk detection (a direct call without `ArtifactIntervals`) cannot
apply them and warns (`EphysDataset:toBin:AdjustmentsIgnored`).

**Marking manual periods.** Manual periods are marked on the same plot. Turn
on **Mark artifacts** (left column, under the periods table; amber while on,
and the pointer is a crosshair) and the left button marks: drag over the plot
to add the period dragged over (a purple band follows the pointer; it merges
with the periods it touches and is kept inside the window shown), or click a
purple period to remove it. A drag shorter than four pixels counts as a
click. The plot's own drag-to-pan pauses while marking is on; the wheel and
the arrows still move the view, and Ctrl+drag still moves a detected
artifact's bound. Mark on an artifact's window, or anywhere with **Go to
(s)**. The periods go to the dataset's manifest at once, and the table, the
plot and a Visualize plot of the dataset follow; **Clear** removes them all.
Marking needs a window drawn, stops by itself when you leave the tab or the
dataset, and with **Esc**. It is refused while a run is under way. The
periods table, titled `Manual periods of <Name> (N, saved in its manifest)`,
lists them in recording seconds: **Start (s)**, **End (s)**, **Duration (s)**.
Kept in the manifest, they survive a rescan, a new config and a script that
runs the same recording. The Visualize tab's **Mark manual periods
(Artifacts tab)** opens this plot on the stretch it shows, with **Mark
artifacts** on.

**Measuring a stretch.** **Measure** (beside *Shade artifacts*, or **M** over
the plot; amber while on) turns the same drag into a selection: the stretch
dragged over is shaded **blue** and scored by every detection method at once
([`EphysDataset.measureArtifacts`](EphysDataset.md#artifact-detection-and-blanking)).
The **Selection** tab on the right comes to the front. It shows:

- a summary: the stretch's span, length and samples, the window it was
  measured against, and which methods would flag it;
- one row per method (*Running RMS* with its window, *MAD*, *Absolute*,
  *Common mode*) giving its peak statistic (robust SDs or µV), its threshold,
  the channels over it, and the share of the stretch it would flag
  (*Min channels* applied, no stitching or padding). Rows that would flag are
  shaded;
- one row per channel giving RMS z, MAD z, peak, RMS and peak-to-peak µV,
  sorted by the method chosen on the left. Any column sorts on a click, and
  that sort is kept for every selection and the next session; right-click →
  **Clear sort** returns to the method's order ([Sorted tables](#sorted-tables)).
  The channels over its threshold are shaded.

The baselines (median / MAD) are those of the whole window shown, as
detection takes them over its chunk, so measure on a window with enough clean
signal around the stretch (a wider **Context**, or **Go to (s)**). The method
chosen on the left is held to its **Threshold** (marked *(set)*), and the
others to their defaults. *Min channels*, the RMS window and the channels
excluded on the Probe tab come from the left too. Editing them re-scores the
selection. *Common mode* is scored on the signal as recorded, as its detector
reads it: with a common reference the window is read again unreferenced. A
reader that cannot read a window leaves it out and the summary says so. A
click clears the selection, and another window (stepping, paging, a new
dataset) drops it. **Mark artifacts** and **Measure** are one drag in two
modes: turning one on turns the other off. Measuring writes nothing, so it
works during a run too.

### In a run

While **Enable automatic detection** is ticked, the pipeline's `artifacts`
step runs the detector over each ticked dataset's whole recording and, with
**Cache intervals**, keeps what it found in
`<output folder>/<Name>_artifacts.json`. Later steps and runs reuse that
detection while what decides it is unchanged: the detection settings, the
common reference, the excluded channels and the recording's files. Otherwise
they detect again. The manual periods and the bounds moved by hand are
applied each time the periods are used, so marking a period or moving a bound
needs no new detection ([artifact cache](EphysPipeline.md#run)). The step
runs its chunks on the process pool when the Run tab's **Parallel** box is
ticked; the periods are the same either way.

Each step that reads the recording then takes the manual periods, plus the
automatic ones when its box above (*Erase in sorting*, *Apply in spike
detection*, *Erase in the signals*) is ticked:

- **Sorting** erases them in the `.bin`, as **Erase with** says. Periods
  that cover more than half of the recording refuse the dataset, because
  Kilosort4 would find no spikes. The detection runs in MATLAB before
  Kilosort4 starts, even for a background run, unless the `artifacts` step
  or the cache has it already.
- **Signals** draws a straight line across each before LFP / MUA / SPIKE are
  derived, and records them in every file, while the Signals tab's *Erase the
  artifact periods first* is ticked ([Signals](#signals)). The analysis and
  Export's epochs (with *Artifact periods: drop*) then leave out the epochs
  that touch one.
- **Spikes** rejects the events inside them, or erases them before
  detection, as the Spikes tab's *Artifact periods* says; with *Ignore them*
  it detects as though there were none ([Spikes](#spikes)).

The [Diagram](#diagram) tab draws this path: the detector's stages, the
automatic and manual periods, and the steps they reach (orange). A click on
one of those boxes there opens its setting here.

### Artifacts from a script

```matlab
ds = EphysDataset("D:\EPHYS\SUBJ-ID-1255\SUBJ-ID-1255_260908_103949");
cfg = ds.ArtifactConfig;  cfg.Enabled = true;  cfg.Method = "rms";  cfg.Threshold = 9;
ds.ArtifactConfig = cfg;
S  = ds.analyzeArtifacts();          % the preview: per-channel counts, share of the recording; writes nothing
ds.addArtifact(120.5, 121.2);        % a manual period, in seconds
ds.writeManifest();                  % save it in the manifest
iv = ds.artifactIntervals();         % [k x 2] seconds: manual + automatic, merged
```

`ds.ArtifactConfig.Reference` (`"none"`, `"car"`, `"cmr"`) sets the common
reference. See
[Artifact detection and blanking](EphysDataset.md#artifact-detection-and-blanking)
and [Common reference](EphysDataset.md#common-reference-car--cmr).

<!-- wiki: More in [Working with datasets](Working-with-Datasets#artifacts) and [API: EphysDataset](API-EphysDataset). -->

## Sorting

Kilosort4, or a SpikeInterface sorter, optional (`Sorting.Enabled`). The
step writes `<Name>.bin` with the artifact periods erased (noise by default,
see the Artifacts tab) and runs `run_ks4.py` on it, or, with a
[SpikeInterface sorter](#spikeinterface-sorters) chosen in **Sorter**,
`run_si.py`. See [Running Kilosort4](EphysDataset.md#running-kilosort4) and
[Running a SpikeInterface sorter](EphysDataset.md#running-a-spikeinterface-sorter).
The tab also associates each dataset with its sorted output and opens it in
phy. Sorting runs in a Python environment of its own
([installation](../pipeline/INSTALL.md)); everything else in the pipeline
works without it.

<!-- wiki: ![The Sorting tab](images/app-sorting-tab.png) -->

### What a sorting run does

For each ticked dataset, the Sorting step:

1. works out the artifact periods to erase: the manual periods always, the
   automatic ones when they are on (Artifacts tab). Periods that cover more
   than half of the recording refuse the dataset, because Kilosort4 would
   find no spikes in it and fail;
2. writes the recording to `<output folder>/<Name>.bin` (with its `.json`
   sidecar), or to `<Bin folder>/<Name>.bin` when the **Bin folder** is set,
   with those periods erased and, when the Artifacts tab sets one, the common
   reference subtracted (Kilosort4's own `do_CAR` is then off);
3. writes `settings.json` and a copy of `run_ks4.py` into
   `<output folder>/kilosort4/`, with the probe map Kilosort4 sorts with: a
   copy without the excluded channels' sites (`<probe>_excluded.json`) or with
   the shanks moved apart (`<probe>_spaced.json`, see `shank_spacing` below)
   when needed;
4. starts Python, `"<Python exe>" run_ks4.py settings.json`, or through
   `conda run -n <env>` when **Conda env** is set, in the background or
   blocking (**Execution**).

Kilosort4 writes its phy-format output into `kilosort4/`. Every run writes
`ks4_run.log` and, when it finishes, `ks4_status.json` (`done` or `error`).
A dataset needs a probe (its own, a rule's or the default) and a Python
executable to be sorted.

### Settings

| Control | Maps to |
| --- | --- |
| Enable the Sorting step, Skip datasets already sorted | `Sorting.Enabled`, `SkipExisting` |
| Sorter, **Find SpikeInterface sorters** | `Sorting.Sorter`: Kilosort4 (`"kilosort4"`, the default), or a SpikeInterface sorter the button found in the Python env ([SpikeInterface sorters](#spikeinterface-sorters)) |
| Python exe (+ Browse), Conda env | `Sorting.PythonExe`, `CondaEnv` (optional: when set, commands run as `conda run -n <env> "<Python exe>" ...`). A new config starts with the Python exe last set in the app (the `PythonExe` preference), else the `kilosort` conda env's `python.exe` found under `CONDA_EXE` or a `miniconda3`, `anaconda3`, `miniforge3` or `mambaforge` folder in `%LOCALAPPDATA%`, `%USERPROFILE%`, `%ProgramData%` or `C:\` |
| Phy command | preference `PhyCmd`, not part of the config. Blank = the `phy` executable of the `phy` conda env, found in the conda install that holds the Python exe, the one `CONDA_EXE` names, or `%LOCALAPPDATA%\miniconda3`, `%USERPROFILE%\miniconda3` or `%USERPROFILE%\anaconda3`; else `conda run -n phy phy`. phy is started in the sorted-output folder with `pushd` and delayed expansion, so a folder whose path holds `&` or spaces, or a UNC folder, works |
| Execution (background / blocking), Dry run | `Sorting.Execution`, `DryRun`. How many background runs go at once is set on the [Run](#run) tab |
| Bin folder (+ Browse) | `Sorting.BinDir`: the folder the sorting `.bin` and its `.json` sidecar are written to, as `<Bin folder>/<Name>.bin`. The `.bin` is as large as the recording, so this keeps it out of the per-dataset output folders you copy. Blank (the default) = the dataset's output folder, `<output root>/<Name>`. Only the `.bin` moves: the `kilosort4` folder and every other output stay under the output root. Kilosort4 is given the `.bin`'s full path. Two recordings with the same name would write the same `.bin`, so the plan refuses the second (`error: .bin shared with <key>`) |
| note about artifact periods | read-only: the periods set on the Artifacts tab are erased in the `.bin` Kilosort4 sorts |
| Kilosort4 parameters (five groups, from `EphysPipelineConfig.kilosortParamSpec`), Extra settings (JSON), Kilosort4 parameter docs link | `Sorting.KS4`, `KS4ExtraJSON` ([Kilosort4 parameters](#kilosort4-parameters)) |
| **Optimize for probe** | loads the Kilosort4 parameters saved for the active dataset's probe (else the default probe) from `<probe>.ks4.json` next to the probe map; without that file, offers to generate it from the current parameters or from the probe layout ([details](#optimize-for-probe)) |
| **Reset to defaults** | every `Sorting.KS4` parameter back to its `kilosortParamSpec` default and `KS4ExtraJSON` cleared; the Python and execution settings stay |
| a SpikeInterface sorter's parameters (JSON), their descriptions, **Reset to defaults**, SpikeInterface sorter docs link | in place of the Kilosort4 parameters when a SpikeInterface sorter is chosen: `Sorting.SIParams.<sorter>` ([SpikeInterface sorters](#spikeinterface-sorters)) |
| **Sorted output** panel: Dataset, label, **Use folder...**, **Use auto**, **Open in phy** | the active dataset's sorted-output association ([Sorted output](#sorted-output)) |
| **Run this step** | `EphysPipeline.runSorting` over the selected datasets |
| progress label + **<sorter> log** (named for the selected sorter) | background runs (`ks4_run.log` or `si_run.log` tail, `ks4_status.json` or `si_status.json`), see [Watching background runs](#watching-background-runs) |

### SpikeInterface sorters

**Sorter** picks what sorts: Kilosort4, run as it always is (the rest of
this section's Kilosort4 controls), or a sorter that
[SpikeInterface](https://spikeinterface.readthedocs.io) runs. **Find
SpikeInterface sorters** asks the Python exe (and Conda env) which sorters
its SpikeInterface has installed (`EphysDataset.spikeInterfaceSorters`): the
ones that need nothing else, such as `spykingcircus2`, `tridesclous2`,
`lupin` and `simple`, and any other whose package is installed there
(`pip install mountainsort5`, ...). The list is kept in the preference
`SISorters`, so it is there when the app next opens. SpikeInterface's own
`kilosort4` is left out: Kilosort4 runs natively.

With a SpikeInterface sorter chosen, its parameters take the Kilosort4
parameters' place on the tab: a JSON text on the left, seeded with
SpikeInterface's defaults for that sorter, and each parameter's default and
description on the right. What you edit is saved per sorter in
`Sorting.SIParams.<sorter>` (the defaults, or `{}`, are saved as `""`), and
goes over SpikeInterface's defaults when the sorter runs (nested objects key
by key); a name the sorter does not have is dropped, and the run's log says
so. **Reset to defaults** puts the defaults back. Switching the sorter keeps
each sorter's parameters, and Kilosort4's settings stay as they were.

The run (`EphysDataset.runSpikeInterface`, `run_si.py`):

1. the same `.bin` Kilosort4 would sort: the artifact periods erased and the
   common reference applied once. When the `.bin` carries the common
   reference, the sorter's own is kept out: SpikeInterface's internal sorters
   (`spykingcircus2`, `tridesclous2`, `lupin`) subtract a median reference on
   32 channels or more, which is skipped, and a `do_CAR` / `car` parameter is
   set false, as Kilosort4's `do_CAR` is. The sorter's other preprocessing
   (filtering, whitening, drift correction) is its own;
2. the probe map attached (its `kcoords` are the channel groups), the
   excluded channels' sites left out;
3. templates, amplitudes, spike positions and quality metrics computed on a
   300 Hz high-pass of the `.bin`;
4. each unit labelled `good` or `mua` by the good-unit criteria
   (`Sorting.Quality`, set on the [Review](#review) tab), with
   SpikeInterface's quality metrics and `unitQualityPass`'s rules: these
   sorters give no labels of their own. phy or the Review tab can change
   them as for Kilosort4;
5. phy files written to `<output folder>/si_<sorter>/`, in the layout
   Kilosort4 leaves, so **Open in phy**, the Review tab, the QC report, the
   exports and the analysis read them as they read a Kilosort4 sort.

The sorted output the other tabs read follows the sorter: the
`si_<sorter>` folder when a SpikeInterface sorter is chosen, `kilosort4`
for Kilosort4 (a folder picked with **Use folder...** still wins). Runs of
both kinds share the background slots (**Runs at once** on the Run tab); the
GPUs listed there are Kilosort4's. A dataset with a run of either kind
queued or going is not sorted again, since both sort its `.bin`.
SpikeInterface needs its own install in the Python env (it is in the
`kilosort` env of [INSTALL.md](../pipeline/INSTALL.md)).

### Kilosort4 parameters

The parameters are grouped as in Kilosort4's documentation: **Data**,
**Preprocessing**, **Drift correction**, **Spike detection** and
**Clustering & postproc**. Their defaults are a new config's
([All Kilosort4 parameters](#all-kilosort4-parameters)). The control kinds:
int / float / bool fields are sent as typed; a `nullable` field left blank is
left out, so Kilosort4 uses its own default; a `floatinf` field left blank or
`inf` is left out too (Kilosort4's "off"); a `vector` field takes comma- or
space-separated numbers. A field that does not parse keeps the last good
values in the working config, and the status bar says why
([The config model](#the-config-model)).

**Extra settings (JSON)** takes any other Kilosort4 setting as a JSON
object, e.g. `{"save_preprocessed_copy": false}`. It is merged last and
overrides the fields. `run_ks4.py` drops, and logs, any setting Kilosort4 does
not accept. One entry is not a Kilosort4 setting: `shank_spacing` (µm, 0 =
off) moves the shanks apart in the probe Kilosort4 sorts with, and only there.
For choosing `whitening_range` and `shank_spacing`, see the
[Kilosort4 notes](kilosort4-notes.md#shank_spacing).

### Optimize for probe

Each probe map keeps its Kilosort4 parameters in a parameter file next to it:
`<probe>.ks4.json` for `<probe>.json`
([format](file-formats.md#kilosort4-probe-parameters-probeks4json)).
**Optimize for probe** loads that file with `EphysPipelineConfig.ks4ForProbe`.
The probe is the active dataset's. When that dataset has no probe, or no
project is scanned, it is the config's default probe. The parameters the file
lists are set; every other parameter and the extra settings JSON are left
alone. The dialog lists what changed, with the file's reasons, and warns when
the extra settings JSON sets a loaded parameter (the JSON overrides it). The
log lists every value.

When the probe has no parameter file, an alert says so and offers to generate
`<probe>.ks4.json` with the probe-dependent parameters
(`EphysPipelineConfig.KS4ProbeParams`: `nblocks`, `dmin`, `dminx`,
`nearest_chans`, `nearest_templates`, `min_template_size`, `x_centers`). The
alert lists both sets of values:

| Button | Writes | Then |
| --- | --- | --- |
| **From current parameters** (default) | the Sorting tab's current values | nothing else changes |
| **From probe layout** | the defaults `EphysPipelineConfig.ks4ProbeDefaults` derives from the layout, with their reasons (the button is missing when the probe map has no usable `xc` / `yc`) | the file is loaded, as above |
| **Cancel** | nothing | nothing |

From then on the button loads that file. To change the values, edit the file;
it can also list any other Kilosort4 parameter. The Probe tab's **Probe info**
says whether the selected probe has a parameter file.

The probes in [`pipeline/probes`](../pipeline/probes/README.md) come with parameter
files holding good defaults, derived from each layout by
`EphysPipelineConfig.ks4ProbeDefaults`. The rules follow Kilosort4's
[parameter guide](https://kilosort.readthedocs.io/en/latest/parameters.html),
and each file's `reasons` says why a value was chosen. To derive defaults for
another probe map `pf`:

```matlab
[v, r] = EphysPipelineConfig.ks4ProbeDefaults(pf);
EphysPipelineConfig.writeKS4Params(pf, v, Description=r.Summary, Reasons=r.Reasons);
```

Shanks are the probe's `kcoords` groups, because Kilosort4 places templates
per `kcoords` value. Every rule starts from the `kilosortParamSpec` default, so
the values depend only on the probe.

| Parameter | Rule |
| --- | --- |
| `nblocks` | `0` (no drift correction) with 64 sites or fewer, or rows 50 µm or more apart; `5` for a single shank spanning 2 mm or more (Neuropixels-like); otherwise `1` (rigid) |
| `dmin` | median spacing of the contact rows within a shank; blank (Kilosort's own estimate) when no shank has two rows |
| `dminx` | median lateral distance to the nearest contact in the same row, when at least half the contacts have one nearby; otherwise to the nearest contact in another column. Single-column shanks keep the default, which has no effect there |
| `nearest_chans` | the default, at most the number of sites |
| `nearest_templates` | the default, at most the number of sites when there are 64 or fewer |
| `min_template_size` | half the median distance to the nearest contact, never below the default |
| `x_centers` | one per shank, or one per 200 µm of a wider shank (2-D arrays) |

`ks4ProbeDefaults` also notes when groups of columns 100 µm or more apart share
one `kcoords` value, which suggests a multi-shank map without per-shank
`kcoords`.

### Sorted output

The **Sorted output** panel shows and changes which sorted-output folder
belongs to the active dataset (`SortingDir`, manifest `sorting`). The Export
step, the Review tab, phy and the analysis read the units from there.

| Control | Effect |
| --- | --- |
| Dataset + label | the active dataset, its association (`auto` or `manual`) and folder, its cluster count, and whether it is phy-curated (`cluster_group.tsv`) or not (`cluster_KSLabel.tsv`) |
| phy lamp + line, **Refresh** | what phy did in that folder ([What phy changed](#what-phy-changed)). **Refresh** reads the folder again, for instance after you save in phy |
| **Use folder...** | pick any folder holding sorted (phy) output (`params.py`), or a folder whose `kilosort4` subfolder holds it. Saved as `manual`, and kept while that folder is not there (a disk not connected): the steps then report it missing, and no other sort stands in for it. The [Review](#review) tab's **Use this sort** does the same for the sort it shows |
| **Use auto** | back to automatic: `kilosort4/` in the dataset's output folder, where the step writes |
| **Open in phy** | opens the associated output in phy with the **Phy command**. Once the sort is curated in phy (the green state of [What phy changed](#what-phy-changed)) the button is green and reads **Open in phy (curated)**, with the save time in its tooltip |

### Watching background runs

Each background run is handed to a MATLAB `timer` (every 3 s) as soon as it
starts: it appends new lines of `ks4_run.log` (`si_run.log`) to the **<sorter> log**, logs
`[done]` / `[error]` when `ks4_status.json` appears (a run whose
process exits without a status file is an error: it leaves `ks4_exit.txt`,
so a missing Python or conda env never looks like a run still going),
rewrites the dataset's manifest, refreshes the Project table rows of the
datasets whose run started or ended (only those) and restates the run's row
on the Run tab. An error in the monitor is logged as
`[error]`, and the monitor restarts itself. The progress label reads *Background
Kilosort4: F of T finished (R running, W waiting to start)*, where *waiting*
counts the datasets the run has not started yet for want of a free slot. How
many runs go at once, the GPUs they share and whether waiting runs are queued
are set on the [Run](#run) tab. The
timer stops when every tracked run has finished and none is waiting. A re-sort
moves the earlier sort's curation aside first
(`previous_<yyyyMMdd_HHmmss>` in the results folder, see
[launchSorting](EphysDataset.md#result--launchsortingresult-wait-device)), and
its result row and log line say where it went. A dataset with a Kilosort4 run
queued or still going is skipped (`skip: Kilosort4 queued` /
`skip: Kilosort4 running` in the plan) and never queued twice.

Closing the app stops the timer but not the Python processes already
running: the next launch follows those runs again, and their
`ks4_status.json` and `ks4_run.log` say how they ended. Queued runs that have
not started can be kept for the next launch or dropped (the app asks first;
see [Run](#run)). The Run tab's **Stop runs...** ends runs that are going.

A background run cannot feed the Export step's units in the same run: the
units do not exist yet when the step starts, and **Validate config** reports
it as an error. Use **Blocking (wait)** for an all-in-one run, or sort first
and export later.

### Dry runs and checking the environment

With **Dry run** ticked, the step writes `settings.json` and `run_ks4.py`
into `kilosort4/dryrun/` and stops: no `.bin` is written and Python is not
started. Check the settings, the probe and the paths there. The files of a
run already in `kilosort4/`, the record of how its results were made, are not
touched.

### Curating in phy

1. **Open in phy** (here, in the Project tab's **Tools** panel, or on the
   Review tab).
2. Label clusters `good`, `mua` or `noise` in phy and save. phy writes
   `cluster_group.tsv`, whose labels win over Kilosort4's `cluster_KSLabel.tsv`
   wherever units are read. A note per unit is a cluster label named `notes`
   (`cluster_notes.tsv`), which the [Review](#review) tab edits too.
3. Run **Export** again with **Overwrite** so its files carry the curated
   labels. The Review tab and the analysis read them from the sort folder.

### What phy changed

The phy line of the **Sorted output** panel reads the dataset's sort folder
([EphysDataset.phyStatus](EphysDataset.md#other-helpers)). Its lamp shows
one of these states:

| Lamp | Line | Read from |
| --- | --- | --- |
| grey | *Not opened in phy.* | no `phy.log` or `.phy/` cache in the folder |
| amber | *Opened in phy, nothing saved* | `phy.log` or `.phy/`, but no file that phy saved |
| amber | *Saved in phy … with no change* | phy saved, but no cluster is labelled and none was merged or split |
| green | *Modified in phy (saved …)*: the labels set in phy (`12 good, 30 mua, 5 noise`), clusters from merges / splits, clusters now | `cluster_info.tsv`, which phy writes on every save and no sorter writes, or phy's `cluster_group.tsv` (header `group`) |

The save time is when `cluster_info.tsv` was last modified, so a copy that
keeps file times (robocopy, the Copy tab) still shows it. phy numbers each
cluster it makes by merging or splitting from the largest id on. The count of
those clusters is therefore the ids in `cluster_info.tsv` beyond the sorter's
(the rows of `templates.npy`). The Project table's **Sorting** column says
`modified in phy` for the same green state.

### Things to know

- **Channel mapping.** The probe's `chanMap` values are `.bin` rows
  (positions), not hardware channel numbers. They agree when the channel
  numbers have no gaps; when channels were disabled at acquisition, the probe
  map must allow for the gap
  ([Python drivers](python-drivers.md#channel-numbering-caveat)).
- **Artifact scan before launch.** With automatic artifact detection on, each
  dataset's scan runs **in MATLAB, synchronously**, before Python is launched,
  even for a background run (and is cached afterwards). Running the
  `artifacts` step first fills the cache.
- **Disk space.** `<Name>.bin` is as large as the recording, and Kilosort4
  leaves its own filtered copy (`temp_wh.dat`). The sorted units need neither;
  the [Clean up](#clean-up) tab removes them. To keep the `.bin` out of the
  output folders (say, to copy those without it), give the **Bin folder** a
  place of its own, on a scratch disk for example.
- **From a script.** `ds.runKilosort()` writes the `.bin` and runs
  Kilosort4; `Launch=false` writes a run's files and `ds.launchSorting(result)`
  starts it later, on a chosen GPU ([Running Kilosort4](EphysDataset.md#running-kilosort4)).

### All Kilosort4 parameters

The parameters of `EphysPipelineConfig.kilosortParamSpec`, with a new
config's defaults and the controls' tooltips. Kind says how the field is
parsed ([Kilosort4 parameters](#kilosort4-parameters)).

| Group | Parameter | Kind | Default | Meaning |
| --- | --- | --- | --- | --- |
| Data | `n_chan_bin` | nullable | blank | Channels in the .bin (blank = auto from data/probe). |
| | `fs` | nullable | blank | Sample rate, Hz (blank = auto from recording). |
| | `tmin` | float | `0` | Start time, s, of data to analyze. |
| | `tmax` | floatinf | `Infinity` | End time, s (Infinity = end of recording). |
| Preprocessing | `highpass_cutoff` | float | `300` | Kilosort4 high-pass cutoff, Hz (Kilosort4 filters internally). |
| | `whitening_range` | int | `32` | Number of nearby channels for whitening. |
| | `shank_spacing` | float | `0` | Extra distance, µm, between neighbouring shanks, for sorting only (0 = the probe as it is). Not a Kilosort4 setting: Kilosort4 sorts with a copy of the probe whose shanks are that much further apart |
| | `artifact_threshold` | floatinf | `Infinity` | Zero out any batch with an absolute value at or above this amplitude (Infinity = off). Units are raw ADC counts, not volts: Kilosort4 applies it after its own high-pass filter and CAR, before whitening. For Intan and Open Ephys headstage data 1 count = 0.195 µV, so 5000 is about 1 mV. |
| | `nskip` | int | `25` | Batch stride for computing whitening/drift. |
| | `batch_size` | int | `120000` | Samples per processing batch. |
| | `batch_downsampling` | int | `1` | Downsampling factor across batches for drift. |
| | `nt` | int | `61` | Spike template width, samples. Must be a positive odd integer. |
| | `nt0min` | nullable | blank | Sample index of template peak (blank = auto). |
| | `shift` | nullable | blank | Additive offset applied to data (blank = none). |
| | `scale` | nullable | blank | Multiplicative scale applied to data (blank = none). |
| Drift correction | `nblocks` | int | `0` | Drift-correction blocks (0 = no drift correction). |
| | `binning_depth` | float | `5` | Depth bin size, µm, for drift estimation. |
| | `sig_interp` | float | `20` | Interpolation sigma, µm, for drift correction. |
| | `drift_smoothing` | vector | `0.5, 0.5, 0.5` | Gaussian smoothing [t, x, depth] for drift. |
| | `dmin` | nullable | blank | Vertical channel spacing, µm (blank = auto). |
| | `dminx` | float | `32` | Horizontal channel spacing, µm. |
| Spike detection | `Th_universal` | float | `7` | Threshold for universal (detection) templates. |
| | `Th_learned` | float | `8` | Threshold for learned templates. |
| | `Th_single_ch` | float | `6` | Single-channel detection threshold. |
| | `nearest_chans` | int | `10` | Nearest channels used per template. |
| | `nearest_templates` | int | `58` | Nearest templates considered per spike. |
| | `max_channel_distance` | float | `32` | Max channel distance, µm, for a template. |
| | `max_peels` | int | `100` | Max matching-pursuit iterations per batch. |
| | `templates_from_data` | bool | on | Learn templates from data (vs. fixed bank). |
| | `n_templates` | int | `6` | Number of universal templates. |
| | `n_pcs` | int | `6` | PCs per channel for template features. |
| | `template_sizes` | int | `5` | Number of template spatial scales. |
| | `min_template_size` | float | `15` | Smallest template spatial scale, µm. |
| Clustering & postproc | `acg_threshold` | float | `0.2` | Refractory ACG threshold for splits. |
| | `ccg_threshold` | float | `0.25` | CCG threshold for merges. |
| | `cluster_neighbors` | int | `10` | Neighbors used during clustering. |
| | `cluster_downsampling` | int | `20` | Spike downsampling for clustering. |
| | `max_cluster_subset` | int | `25000` | Max spikes used per clustering pass. |
| | `x_centers` | int | `4` | Number of horizontal cluster centers. |
| | `cluster_init_seed` | int | `5` | RNG seed for cluster initialization. |
| | `duplicate_spike_ms` | float | `0.25` | Window, ms, for removing duplicate spikes. |
| | `position_limit` | float | `100` | Max distance, µm, for spike position estimate. |

## Signals

Derived LFP / MUA / SPIKE / AUX `.mat` files with `EphysDataset.toMat`
([intan2matlab](intan2matlab.md)), `Signals.*`:

- **LFP**: the local field potential, resampled to a low rate;
- **MUA**: the multi-unit activity envelope;
- **SPIKE**: the spike band;
- **AUX**: the headstage's auxiliary (accelerometer) inputs, as recorded.

Every file also holds the digital-input events. The [Export](#export) step
reads these files.

<!-- wiki: ![The Signals tab](images/app-signals-tab.png) -->

- **Output**: folder (blank = the dataset's output folder), suffix
  (`_extract`), MAT version (`-v7.3`, any size, or `-v7`, under 2 GB per
  variable), overwrite (off: an existing file is skipped), **one file per
  signal type** (on by default: `<Name>_extract_LFP.mat`, `_MUA.mat`,
  `_SPIKE.mat`, `_AUX.mat`; one plan / result row per file. Off: one
  `<Name>_extract.mat` holding every signal).
- **Signals to compute**: LFP (`LFP_Fs`, high-pass, low-pass, notch +
  width), MUA (`MUA_Fs`, integration, band), SPIKE (keep original rate /
  `SPIKE_Fs`, band), AUX (no settings). LFP is ticked by default. A signal's
  fields are on only while it is ticked ([Processing](#processing)).
- **Erase the artifact periods first (a line across each), and record them in
  every file**, under the signal-type row: `Signals.BlankArtifacts` (on by
  default). Before LFP / MUA / SPIKE are derived, the dataset's artifact
  periods (the manual ones, plus the automatic detection when the Artifacts
  tab's *Erase in the signals* is ticked) become a straight line between the
  levels on either side, so no filter or resampler spreads an artifact into
  the samples around it. Every file records them (`info.artifacts`), and the
  analysis and Export's epochs (with *Artifact periods: drop*) leave out the
  epochs that touch one. AUX is not changed.
- **Common reference: LFP / MUA / SPIKE**, the row below it:
  `Signals.LFP_Reference` / `MUA_Reference` / `SPIKE_Reference` (off / on /
  on by default), which signals the common reference (the config's
  `Reference` section, set in the Artifacts tab's common-reference panel)
  is subtracted from, once, before they are derived. It suits MUA and SPIKE,
  which it rids of the noise every channel shares; the LFP is usually kept as
  recorded, since the reference would take out the LFP the channels share.
  Each box is on only while its signal is ticked, and nothing is subtracted
  while the reference is *None*. Every file records what its signal took
  (`info.<TYPE>.reference`). The tab's note gives the order: keep channels →
  common reference (the signals ticked for it; taken over every channel) →
  erase artifact periods → LFP (resample, then filters) / MUA / SPIKE →
  interpolate bad channels → remap.
- **Channels**: label field (`custom` / `native` names for channels, aux
  inputs and digital lines; lines renamed on the Trials tab keep their
  names), keep amp channels (1-based recording channels to read, in the
  order given; blank = all), bad channels (*None* / *Manual list* of
  recording channels, like keep channels, those not kept being ignored /
  *Auto*: channels whose |z-score of the LFP's RMS| exceeds **Auto
  threshold**, default 3), channel remap (the final column order, 1-based
  into the kept channels: `32-1` reverses 32 channels),
  **Manifest exclusions** (what to do with the dataset's channels excluded
  on the Probe tab: *ignore* (`none`), *drop* them from the kept channels,
  or *interpolate* them as bad channels). Lists keep order and repeats;
  anything unparseable stops the run with a message naming the field.
  **Reset to defaults** puts every Signals setting back but the step's
  **Enable** box.
- Bad channels are interpolated from the probe geometry (the dataset's
  probe, else the config's default): each is replaced by the
  1/distance-weighted mean of the 4 nearest good sites on its shank. Without
  a probe layout, or for a site with no good site on its shank, it is
  interpolated across the neighbouring columns instead (with a warning).
  *Auto* needs LFP ticked and the Statistics and Machine Learning Toolbox
  (`zscore`), and cannot be combined with *interpolate* for the manifest
  exclusions.
- The targets table on the right, *This step for the selected datasets*, is
  `plan(Steps="signals")` for the datasets ticked on the Project tab (all
  when none is ticked), one row per file: **Dataset**, **Output file**,
  **Status** (`ready`, `exists: skip`, `exists: overwrite`,
  `no recording files`, `error: ...` for a setting that cannot apply to the
  dataset, which blocks the run) and **Note**. It is planned again on every edit while the
  tab is shown; **Refresh plan** does it by hand. **Run this step** runs
  `EphysPipeline.runSignals` on the Run tab.

### Processing

| Signal | Defaults | Processing |
| --- | --- | --- |
| LFP | `LFP_Fs` 1000 Hz; high-pass 1 Hz, low-pass 300 Hz and notch 60 Hz (width 2 Hz), each off | resampled to `LFP_Fs`; then, at that rate, a 4th-order Butterworth high-, low- or band-pass and a 2nd-order band-stop per notch, all zero-phase (`filtfilt`) |
| MUA | `MUA_Fs` 2000 Hz, integration 1000 Hz, band 300–5000 Hz | after Lakatos et al. (2005): 4th-order Butterworth band-pass, rectified, then a 4th-order Butterworth low-pass at the integration frequency (at most `MUA_Fs / 2`), both zero-phase at the recording rate, then resampled to `MUA_Fs` |
| SPIKE | the recording rate kept (else `SPIKE_Fs`, 20000 Hz), band 300–5000 Hz | resampled to `SPIKE_Fs` unless the rate is kept, then a 4th-order Butterworth band-pass (zero-phase) |
| AUX | none | the auxiliary inputs as recorded, in volts at their own rate. A recording without them writes none, with a warning |

- **Notch** takes a list, such as `60, 120, 180`. Each notch must fit inside
  (0, `LFP_Fs`/2): `f − width/2 > 0` and `f + width/2 < LFP_Fs/2`. The width
  is between the design's −3 dB points (−6 dB after the zero-phase filter).
- Every filter edge must lie below half the rate it is applied at. **Plan**
  reports a setting that cannot apply to a dataset (`LFP_Fs` above its sample
  rate, say) as `error: ...`, and that blocks the run.
- Zero-phase IIR filters leave edge transients at the start and end of the
  recording: up to about 2 s at each end for a 1 Hz high-pass, longer for
  lower cut-offs.
- The whole recording is read into memory in single precision. Expect a peak
  of about twice its size.
- The digital-input events are taken at the recording rate. Lines ticked
  **Inverted** on the [Trials](#line-polarity) tab have their onsets at the
  falling edge.

The full processing order and options are in [intan2matlab](intan2matlab.md).

### The files

Each `<Name>_extract_<TYPE>.mat` holds `Y` (the signal,
`[nSamples x nChannels]` single, as `Y.LFP`, `Y.MUA`, ...), `events` (one
field per digital line: `[k x 2]` onset / offset times, seconds), `info` (the channel
labels, the recording rate, each signal's rate, filters, sample count and
common reference, and `info.artifacts`, the periods erased) and `conversion`
(provenance). Row k of a signal is at `(k − 1) / Fs`. See the
[file format](file-formats.md#derived-signal-mat-ephysdatasettomat-the-signals-step).

<!-- wiki: Load them with [`DatasetOutputs`](Loading-Outputs): `out.LFP`, `out.MUA`, `out.AUX`. -->

### Signals from a script

```matlab
ds  = EphysDataset("D:\EPHYS\SUBJ-ID-1255\SUBJ-ID-1255_260908_103949");
[Y, events, info] = ds.deriveSignals(dataTypeOut=["LFP" "MUA"], LFP_Fs=1000, LFP_NotchHz=60);
out = ds.toMat(SeparateFiles=true, SignalOptions=struct('dataTypeOut', ["LFP" "AUX"]));
```

`intan2matlab(folder, ...)` runs the same processing as a function of its
own.

<!-- wiki: More in [Working with datasets](Working-with-Datasets#derived-signals). -->

## Spikes

Threshold-detected spike events per dataset with `EphysDataset.spikesToMat`,
`Spikes.*`, written to `<Name>_spikes.mat`
([format](file-formats.md#spikes-mat-ephysdatasetspikestomat-the-spikes-step)).
This step does not read the sorted units: they stay in the
sorting folder, where Export and the analysis read them.

Detection streams the whole recording one chunk at a time. For each channel
it filters the chunk, takes a threshold from the filtered noise, finds the
threshold crossings, aligns each to its extremum, keeps a minimum period
between events, drops events above the maximum amplitude and, when asked,
cuts the waveforms ([Spike detection](EphysDataset.md#spike-detection)). It
is a detector, not a sorter: a spike seen on several channels is detected
once on each. Chunk joins are not detection boundaries, so no event is lost
or counted twice at a join.

<!-- wiki: ![The Spikes tab with a detection preview](images/app-spikes-tab.png) -->

- **Filter** (band-pass on, 500–5000 Hz, order 4), **Threshold** (method
  `mad` (a robust SD, median(|x − median(x)|)/0.6745, times the value),
  `std`, `rms`, `percentile` (of |x|) or `absolute` (µV); value blank = the
  method's default, 4, or 99.9 for `percentile`, none for `absolute`;
  polarity `negative` / `positive` / `both`; max amplitude `Inf`;
  **Noise measured over**, `Spikes.ThresholdScope`: *each chunk*
  (default) or *the whole recording*, one threshold per channel from a first
  pass over the recording, see
  [detectSpikes](EphysDataset.md#whole-recording-mode); off for *absolute*),
  **Events** (align `trough` / `peak` / `extremum` / `none` within 1 ms; min
  period 1 ms, keeping the earlier of two closer events), **Waveforms** (off;
  window −0.5 to 1.5 ms, source `filtered` / `raw`, edge handling `nan`
  (pad) / `drop`), **Channels & artifacts** (all / manifest
  exclusions / list; **Artifact periods**, `Spikes.ArtifactMode`: *Reject the
  events inside them* (default), *Erase them before detection (the cleaned
  recording)*, whose samples then stay out of the thresholds and are bridged
  by a line for the band-pass, so an artifact neither rings into the samples
  around it nor raises the threshold, or *Ignore them*; the periods are the
  manual ones, plus the automatic detection while it is enabled and the
  Artifacts tab's *Apply in spike detection* is ticked, see
  [In a run](#in-a-run)), **Chunking**
  (chunk cap, edge pad; the parallel switch is on the Run tab), **Output**
  (folder, suffix `_spikes`, MAT version, overwrite).
- **Dataset** + **Preview**: detects on the first *n* seconds (10 by
  default, the field beside the button) of the active dataset with the tab's
  settings, and lists per channel **Ch**, **Name**, **Threshold (uV)**,
  **Events** and **Rate (Hz)**, to tune the threshold before a run. It writes
  nothing, and neither rejects nor erases the artifact periods, whatever
  *Artifact periods* says. The preview's thresholds are always its window's own; with *the
  whole recording* its label says so.
- **Run this step** runs `EphysPipeline.runSpikeDetection`.

## Export

Files for external toolboxes, and the same data organized by event,
`Export.*`: one file per format ticked (`Export.Formats`). Nothing about
spectra, tapers or Chronux functions appears here: the app only writes files,
and no toolbox is needed to write them. The exports are independent: none is
built from another. They read the Signals step's extract files
(`<Name>_extract_<TYPE>.mat`, or one `<Name>_extract.mat`), so run **Signals**
first; detected spikes come from the Spikes step's file, and units from the
dataset's [sorted output](#sorted-output), which need a dataset name that
matches the [name pattern](#name-pattern-and-token-columns).

<!-- wiki: ![The Export tab with its formats and its plan](images/app-export-tab.png) -->

- **Chronux** (`<Name>_chronux.mat`, [format](file-formats.md#chronux-export-ephysdatasetexportchronux-the-export-step)),
  **FieldTrip** (`<Name>_fieldtrip.mat`,
  [FieldTripExport](FieldTripExport.md)), **Event epochs**
  (`<Name>_epochs.mat`, the same data organized by event —
  [`EphysDataset.eventEpochs`](EphysDataset.md#event-organized-epoched-data))
  and **kCSD-python** (`<Name>_kcsd.npz`, the LFP in mV and its channels'
  probe positions in mm as `ele_pos` / `pots` for kCSD-python's `KCSD1D` /
  `KCSD2D`, [format](file-formats.md#kcsd-export-ephysdatasetexportkcsd-the-export-step)).
  kCSD needs a probe (the dataset's own, a rule's or the default) and leaves
  out the interpolated bad channels; units and detected spikes are not part
  of it. **NWB 2** (`<Name>.nwb`, [EphysDataset → NWB](EphysDataset.md#neurodata-without-borders-nwb))
  holds the electrodes on the probe, the signals, the sorted units with
  their quality metrics, the paired trials, the digital lines and the erased
  periods. It is written by Python (pynwb) and checked with nwbinspector.
- **NWB** (`Export.NWB`): the electrode location; the subject's species,
  sex and age; the time zone the recording was made in; experimenter, lab
  and institution; the Python and conda env (blank = the Sorting tab's); and
  **Check with nwbinspector**. Anything left blank is not written, and
  nwbinspector reports a subject without species, sex or age.
- What to include: signals (`Export.Signals`, e.g. `LFP, MUA`; blank = every
  signal in the extract: LFP, MUA, SPIKE, AUX), sorted units (+ groups, `good,
  mua` by default), detected spikes (from the Spikes step's file), digital-input
  events; **Validate with FieldTrip** (FieldTrip's own `ft_datatype_*` checks)
  when it is on the path. These choices apply to every format, the epoch file
  included.
- **Event epochs**: where the onsets come from (`Export.EpochSource`: the
  pulses of a digital-input line, or the trials paired on the
  [Trials](#trials) tab, which bring their session columns with them; a
  pairing that is not approved gives a warning), the line (blank = the trial
  line, else the only line), the window around each onset (default −0.2 to
  0.5 s), what to do with a window that runs past the recording (*pad with
  NaN*, the default, which flags the row `EpochComplete = false`; *drop the
  epoch*; *error*) or holds `NaN` / `Inf` samples (*keep the epoch*, the
  default; *drop*; *error*), what to do with an epoch that
  touches an artifact period the Signals step erased (**Artifact periods:**
  *touching one: drop the epoch*, the default, leaves it out of the signals as
  the analysis does; *touching one: keep it (flagged)*; the trials table flags
  it either way, `Export.EpochArtifacts`), how the per-epoch spike
  times are stamped (*0 at the onset*, the default; *0 at the window start*;
  *recording clock*), the class of the epoched samples (*double*, the
  default; *single*; *as recorded*: the values never change) and the onset
  rule (*event*, the default, for digital-input times `t = row / origFs`:
  `round((t − 1/origFs) × Fs) + 1`, the signal row nearest the event's
  recording row, which at the recording rate is that row, `round(t × Fs)`;
  *sample*: `round(t × Fs) + 1`, for times on a continuous time base).
  Nothing is averaged, smoothed or resampled.
  **Epochs to workspace** builds that struct for the active dataset with
  these settings and puts it in the base workspace as `epochs_<name>`
  (replacing a variable of that name); an alert says what was built. Nothing
  is written to disk. It needs the dataset's Signals output.
- Output folder, overwrite, MAT version; **Run this step** runs
  `EphysPipeline.runExport`.
- The targets table lists one row per format and dataset (steps
  `export:chronux`, `export:fieldtrip`, `export:epochs`, `export:kcsd`,
  `export:nwb`) with the output file and a status: `ready`; `exists: skip` /
  `exists: overwrite` (**Overwrite** decides); `no extract file` (no Signals
  output yet: fine when the Signals step runs first in the same run);
  `error: unit identity` (units are asked for but the dataset name cannot
  label them). It is refreshed when the tab opens; **Refresh plan** redoes
  it.

### What is in the files

Every variable and field is in [Files on disk](file-formats.md):

- `<Name>_chronux.mat`: one struct per signal (`data`
  `[nSamples x nChannels]`, Chronux `params` with the signal's `Fs`, `t`,
  `labels`, `info`), the sorted units as `sp` (a struct array with `times`, the input
  of `mtspectrumpt`), the detections as `spDetected`, the events, and
  `export` (provenance and time conventions)
  ([format](file-formats.md#chronux-export-ephysdatasetexportchronux-the-export-step)).
- `<Name>_fieldtrip.mat`: `data_<SIG>` raw structures (`ft_datatype_raw`),
  `spike` / `spikeDetected` (`ft_datatype_spike`), `event`, and `export` with
  the validation result ([format](file-formats.md#fieldtrip-export-ephysdatasetexportfieldtrip-the-export-step)).
- `<Name>_epochs.mat`: `epochs` with the event, a trials table (one row per
  epoch), the signals as `[nTime x nEpochs x nChan]`, the units' and
  detections' spike times per epoch, and `export`
  ([format](file-formats.md#epoch-export-ephysdatasetexportepochs-the-export-step)).
- `<Name>_kcsd.npz` and `<Name>.nwb`: see their formats above.

For quick-look figures (PSTHs, evoked potentials, tuning) of the same data,
use the [analysis app](EphysAnalysisApp.md).

<!-- wiki: Worked examples of the toolbox formats (trial-aligned spectra, spike-field coherence, FieldTrip trials) are on [Analysis toolbox exports](Analysis-Toolbox-Exports). -->

## Analysis

The Analysis step (`Analysis.*`) runs an analysis config made in the
[analysis app](EphysAnalysisApp.md) over the selected datasets. It draws the
config's plots, writes their figure files and writes its HTML / PDF report,
as **Run** does in the analysis app. It is the last step, because it reads
what the others write: each dataset's extract (the events and the signals),
its spikes file, its sorted units and its behavior file. It needs the
repository's `analysis` folder on the path (`addpath_nogit` adds it); without
it, validation says so.

<!-- wiki: ![The Analysis tab with an analysis config chosen and its plan](images/app-analysis-tab.png) -->

- **Config file** (`Analysis.ConfigFile`): an analysis config (`.json`). The
  file is read when the step runs, so changes saved in the analysis app apply
  to the next run. The step runs it over the datasets ticked on the Project
  tab, not over the source saved in it
  (`EphysPipelineConfig.analysisSource`). Each dataset's outputs are also
  looked for in the Signals / Spikes / Export output folders when those are
  set.
- **Open in the analysis app** opens the config in
  [EphysAnalysisApp](EphysAnalysisApp.md), to edit its plots. Save it there,
  then press **Reload** here. With no config chosen, the button opens the
  analysis app on this project's selected datasets, to make one.
- The summary under the buttons shows what the config holds: its name and
  description, the event the plots align to and their window, where its
  figure files and report go, and what its own checks find (red for an
  error). The table lists its plots (id, kind, source, enabled). The plots
  themselves are edited in the analysis app.
- **Write the figure files** (`Analysis.Figures`) and **Write the report**
  (`Analysis.Report`): the step writes these whatever the analysis config's
  own Export / Report **Enabled** says. Where they go, their formats and
  file names come from its Export and Report settings, for example
  `{OutputFolder}\analysis\{Name}_{Plot}.png` and
  `{OutputRoot}\analysis\analysis_report.html`. With both off, the plots are
  only drawn.
- The targets table lists one row per dataset and enabled plot
  (`analysis:<plot id>`, with its figure folder) and one row per report
  (`analysis:report`; no dataset for one report over every dataset).
  **Run this step** runs `EphysPipeline.runAnalysis`. **Open report** opens
  the report in the browser: the active dataset's own report with
  `Report.PerDataset`, else the one over every dataset. **Open figures
  folder** shows the active dataset's figure folder.

A plot a dataset cannot have (no sorted units, no paired trials, no LFP
extract, ...) is a *skipped* result row, with the reason, and the other
plots still run. A dataset whose outputs cannot be read is an *error* row;
the others still run. **Cancel** stops before the next plot. After a cancel,
a report over every dataset is not written. The analysis writes its own run
record next to the report (`analysis_runs/`), as in the analysis app.

## Diagram

A diagram of what the working config does, redrawn whenever the tab is
shown and on every config edit while it is open. **View** picks one of two
drawings, and the choice is kept as a preference:

- **Every parameter**: every step's stages with their parameters, described
  next.
- **Data-flow overview** (the default): only the steps and the data passing
  between them (see [Data-flow overview](#data-flow-overview)).

**Hide unused** (also kept as a preference) leaves out what the working config does
not use, in either view: disabled steps (the Artifacts step stays while its manual
periods are read), stages and files switched off, arrows not read, and inputs
nothing then reads. The overview closes the empty rows up and routes the arrows
afresh; the summary line counts what is hidden. In a script:
`PipelineDiagram.overview(cfg, [], HideUnused=true)`.

**Refresh** draws it again. The summary line beside the buttons counts the
steps enabled and, with an active dataset, names the recording drawn
(`| recording: <name>`). **Save as HTML...** and **Open in Browser** write
the drawing out ([below](#data-flow-overview)).

Both are drawn by `PipelineDiagram`, which needs no app, so a script can
write a config's diagram too:
`writelines(PipelineDiagram.overview(cfg, []), "overview.html")`
(`PipelineDiagram.detail(cfg, ds, Layout="steps")` for the other).

Either drawing sits in a frame you can zoom and pan. The buttons at its top
right zoom out (**−**), back to actual size (the percentage shown), in
(**+**) and **Fit** the whole diagram in the frame. The mouse wheel zooms
about the pointer, and dragging the diagram pans it (a drag never opens a
box; a click still does). The overview opens fitted to the frame and
follows it as the window resizes; Every parameter opens at 100% from the
top. Once zoomed or panned, a view keeps its place until you close the app,
even as the diagram is redrawn (on a config edit, or on leaving and coming
back to the tab); each view, and each layout of Every parameter, keeps its
own.

<!-- wiki: ![The Diagram tab, Every parameter view](images/app-diagram-tab.png) -->

**Every parameter** is one tree: the raw
recording at the top, then the common reference, drawn once, and under it
the steps that read the recording, each drawn top-down from its own coloured
step box to the files it writes:

- **Common reference** (`Reference.Mode`, set on the Artifacts tab): the one box for the
  whole pipeline, since every step subtracts it once from its own read of the
  recording. It lists what leaves it out: the Signals not ticked for it
  (*not Signals' LFP* by default) and the common-mode artifact detector,
  which looks for the very mean it subtracts. Dashed *none (as recorded)*
  when it is off.
- **Artifacts**: chunked reading, the detection
  filter, the detector (method, window, threshold), channel coincidence,
  merge / pad, the automatic intervals, and the artifact periods
  (automatic and manual) that Sorting, Signals and Spikes read. Its boxes
  below the periods are Sorting, Signals and then Spikes when they hang
  there, else *Reject in Spikes* (or a dashed *Spikes: ignores the periods*).
- **Sorting**, **Signals** and **Spikes** hang from those artifact periods
  when they erase them from the recording before reading it: Sorting always
  (the `.bin`), Signals while `Signals.BlankArtifacts` is on (the amplifier
  data LFP / MUA / SPIKE are derived from), Spikes while
  `Spikes.ArtifactMode` is `"erase"` (the trace it detects on). Otherwise
  they hang from the common reference. Sorting: the blanked artifact
  periods (noise-filled or zeroed), the `.bin` write, the probe map
  (`chanMap` indexes `.bin` rows; manifest exclusions), then Kilosort4
  (`run_kilosort`): crop, its own high-pass, CAR (dashed *off (do_CAR =
  false)* while the `.bin` carries the common reference, so the recording is
  referenced once), artifact threshold,
  whitening, drift correction, template matching and clustering, ending in
  the phy-ready sorted units in `kilosort4/`.
- **Signals**: channel selection,
  then an *Erase artifact periods* box
  (orange: *manual + automatic* or *manual periods only*, *a line across each,
  before any filter*, *recorded in every file*; dashed *off (as recorded)*
  when `Signals.BlankArtifacts` is off) over the LFP (resample, band filter,
  notch), MUA (bandpass, rectify, resample, integrate) and SPIKE (resample,
  bandpass) branches, each of whose first box says whether it takes the
  common reference (*common CMR referenced*) or not (*as recorded (no common
  reference)*); the AUX and digital-event branches hang from the read
  beside the channel selection, since neither is referenced or
  channel-selected. The amplifier branches end with bad-channel
  interpolation, the channel remap and the output file. Export and Analysis
  hang from the first signal file (from the digital events when no amplifier
  signal is computed). Export shows its inputs, then one branch per format;
  the *Event epochs* box says whether epochs touching an artifact period are
  dropped or kept, flagged. Analysis shows what it reads, the analysis
  config's plots and alignment, and its figure files and report.
- **Spikes**: chunking, channels, the erased artifact periods (with
  `ArtifactMode` `"erase"`: *NaN: out of the thresholds, a line across each
  for the filter*), bandpass, threshold, alignment, minimum period, amplitude
  cap, waveforms, artifact rejection (with `"reject"`; dashed *ignored* with
  `"none"`) and the spikes file.

Stages the config leaves off are dashed, a disabled step's branch is faded (a step hanging from it keeps its
own state, and so do the artifact periods: the manual ones apply with
detection off), and artifact periods feeding another step are marked orange.

**Layout** (this view only; it is off in the overview) switches to **Tree per step**: a tree of its own for Artifacts and
Spikes (Spikes only while it does not erase the periods, and Signals too
while `Signals.BlankArtifacts` is off), each from the recording box and its
common reference, then the steps hung from another step's output (Sorting,
Signals and Spikes from the artifact periods, Export and Analysis) under
**Downstream**, each under a box for what it reads (*Artifact periods, from
Artifacts*). The choice is kept as a preference. In either layout the tab's
summary line (`N of 4 raw-data step(s) enabled`) counts Artifacts, Sorting,
Signals and Spikes, wherever they hang.

With an active dataset the recording node shows its name, rate and channel
count, and the Sorting branch shows its probe and exclusions.

**Click a box to open the setting it draws**: the app switches to the tab that
holds it, scrolls it into view, focuses it and colours it blue and bold until
you leave the tab. A box usually stands for several controls (the *Threshold*
box for the method, the threshold and the polarity; *Drift correction* for
`nblocks`, `sig_interp`, `binning_depth`, `dmin` and `dminx`) — all of them are
marked, and the first one decides the tab. A step box opens its **Enable**
box. Boxes lead where the setting lives rather than where they are drawn, so
*Blank artifact periods* in the Sorting tree opens the Artifacts tab,
*Erase artifact periods* in the Signals tree the Signals tab, *Read in
chunks* opens the Run tab's parallel settings, and the recording box opens the
project root. Keyboard: tab to a box and press Enter or Space.

### Data-flow overview

<!-- wiki: ![The Diagram tab, Data-flow overview](images/app-diagram-overview.png) -->

Every pipeline step as one box in its colour, with the files it writes hung
under it. The three inputs are above them: the raw recording, the Epsych2
sessions (their search folders and how they are matched, or, with
`Behavior.Search` off, the active dataset's associated session) and the probe map
(the active dataset's own, else the default). The recording box also stands
for the dataset's manifest (probe, channel exclusions, manual artifact
periods) and names the common reference. An arrow runs from each input or
written file to every step that reads it, in the colour of whatever wrote
it:

| Step | Reads | Writes |
| --- | --- | --- |
| Probe check (always runs) | the recording's channel count, the probe map | nothing, a probe rule's probe (`Probe.AutoAssign`) or the default probe (`Probe.WriteDefaultToManifest`) into the manifest |
| Behavior | the Epsych2 sessions; the recording's trial line (`PairTrials`) | the trial pairing (in the manifest; reviewed on the Trials tab), `<Name>_behavior.mat` (`WriteFile`) |
| Artifacts | the recording, and the manual periods in its manifest | the artifact periods: automatic (cached in `<Name>_artifacts.json`) + manual |
| Sorting | the recording, the artifact periods (always blanked), the probe map | `kilosort4/`, the sorted units |
| Signals | the recording; the artifact periods (`BlankArtifacts`) | the signal files, `<Name>_extract_<TYPE>.mat` |
| Spikes | the recording and the artifact periods (threshold detection; the periods rejected or erased first, unless `ArtifactMode` is none) | `<Name>_spikes.mat` |
| Export | the signal files; the sorted units (`IncludeUnits`); the spikes file (`IncludeDetected`); the behavior file (epochs around the paired trials) | one file per format |
| Analysis | the signal files; the behavior file; the sorted units and the spikes file (dashed when no enabled plot of the analysis config reads them) | the figure files (`Figures`), the report (`Report`) |
| Copy outputs (not a step: the Run tab's **Copy outputs to**) | every file a step writes: the behavior file, the artifact cache, the sort folder, the signal and spikes files, the exports, the figure files (each dashed while the config does not write it) | the copies, in `<folder>\<subject>\<session>` (a new `<session>_v2` when it is there, or as **If it is there** says) |

A read the config leaves off is drawn dashed and grey, and a file the config
does not write is a dashed box. A disabled step and the arrows into it are
faded. The arrows out of its files keep their colour, since a file written
by an earlier run still feeds the steps after it. The artifact periods never
fade, because the manual ones apply with detection off. Copy outputs sits
alone in the last row, each arrow into it down a lane of its own; it is
faded, with its arrows, while copying is off. The summary line counts the
eight steps (`N of 8 steps enabled`), not Copy outputs.

The arrows run at right angles through the gaps between the boxes, never
through one. The arrows from one source share their first stretch, like the
branches of a tree, and two different sources never share a line (a few
arrows cross). Hover over a box (or tab to it) to light up its arrows and
the boxes at their other ends. In a browser (**Open in Browser**), hovering
over an arrow shows what it carries, or why it is off. As in the other view,
a click on a box opens the setting behind it. Use **Every parameter** for
the parameters themselves.

**Save as HTML...** writes the chart shown, in the view picked, as a
standalone page. Saved pages are not clickable: the boxes only come alive
when the app's HTML component calls the page's `setup()`. The overview's
hover highlighting, and the zoom and pan, work in a saved page too; a
printed page shows the whole diagram at 100%.

**Open in Browser** writes the chart to a temp file and opens it in your
default web browser, same as **Save as HTML...** but without the save dialog.

<!-- wiki
The synthetic project's config, every parameter, as **Save as HTML...** writes it:

![Every parameter of the synthetic project's config](images/flow-full.png)
-->

## Run

The Run tab validates the config, shows what a run would do, runs it and
reports the results, step by step.

<!-- wiki: ![The Run tab after a run](images/app-run-results.png) -->

### Steps and selection

The **Steps (same switches as on each tab)** panel lists the steps in the
order they run. Each box is the same switch as the **Enable** box on the
step's own tab.

| Step | Box | Does |
| --- | --- | --- |
| `probe` | *Probe check (always)* (a label: it always runs) | checks each dataset's probe against its channel count; with **Assign automatically**, first gives a dataset without one its probe rule's ([Probe](#probe)) |
| `behavior` | *Behavior: match Epsych2 sessions* | matches the Epsych2 sessions, pairs the trials, writes `<Name>_behavior.mat` ([Behavior (Epsych2) sessions](#behavior-epsych2-sessions), [Trials](#trials)) |
| `artifacts` | *Artifacts: automatic detection* | detects the artifact periods and caches them ([Artifacts](#in-a-run)) |
| `sorting` | *Sorting: Kilosort4* | writes the `.bin` and runs Kilosort4 ([Sorting](#sorting)) |
| `signals` | *Signals: LFP / MUA / SPIKE / AUX .mat* | the derived signals ([Signals](#signals)) |
| `spikes` | *Spikes: detected spikes .mat* | threshold spike detection ([Spikes](#spikes)) |
| `export` | *Export: analysis-toolbox files* | the files for other tools ([Export](#export)) |

The line under the panel's switches gives the selection:
`Selection: 2 of 4 dataset(s) ticked.` (the rows ticked on the Project tab)
or `Selection: all 4 dataset(s).` (none ticked).

- **<sorter> runs at once** (under the Sorting box, named for the sorter the Sorting tab picks; default 1):
  `Sorting.MaxConcurrent`. With background execution, a run sorts this many
  datasets at a time and starts the next as one finishes. It writes each
  dataset's run files first (the `.bin` included), so the next
  one is ready to go. The run stays busy until the last dataset has started;
  **Cancel** stops the wait (runs already started carry on). The current-step
  line says how many are running, finished and still to start. Runs from an
  earlier Run that are still going count too. With two or more at once and
  no more than one GPU listed under it, every run goes on the same GPU, where
  several can run out of memory on a small card; **Validate config** (and the
  Run's own check) warns. Greyed out when Execution
  (Sorting tab) is blocking, which always goes one at a time. See
  [Background Kilosort4 runs](EphysPipeline.md#background-kilosort4-runs).
- **GPUs** (under it, blank by default): `Sorting.Devices`, torch devices
  separated by commas, such as `cuda:0, cuda:1`. Each background run gets the
  GPU the fewest running runs use, so on a two-GPU machine with two runs at
  once each run has its own. Blocking runs use the first. Blank leaves the
  choice to Kilosort4, which takes the first GPU. SpikeInterface sorters do
  not take a device.
- **Queue the waiting runs; the Run goes on** (a preference, off by
  default): see [Queued sorting runs](#queued-sorting-runs). Greyed out
  when Execution is blocking.
- **Parallel: chunks on the process pool** and **Max workers** (blank =
  automatic): `Parallel.Enabled` / `MaxWorkers`, used by the artifacts step,
  the Artifacts tab's **Detect / Preview** and spike detection. The results
  are the same with and without the pool, and the number of chunks in flight
  is capped by free memory. Without the Parallel Computing Toolbox, or when
  memory allows fewer than two workers, the steps run serially and warn; see
  [Parallel execution](EphysPipeline.md#parallel-execution).
- **Copy outputs to** (off by default) and its folder: the config's
  `Transfer` section. A Run copies, or moves, each dataset's outputs to
  `<folder>\<subject>\<session>` in the background; see
  [Copying the outputs elsewhere](#copying-the-outputs-elsewhere).

### Validate, plan, run

| Button | Does |
| --- | --- |
| **Validate config** | checks the config (`cfg.validate()`) and fills **Issues (Validate)**, one row per problem: **Step**, **Field**, **Severity**, **Message**. Errors stop a run; warnings do not. The project, source, parallel, probe and reference settings are always checked, a step's own only while it is enabled |
| **Plan (writes nothing)** | fills the results table with `pipe.plan()`: what each step would do for each selected dataset ([The plan](#the-plan)) |
| **Run pipeline** | validates, plans, then runs every enabled step in order over the selected datasets (`EphysPipeline.run`) |
| **Dry run** | the same, writing nothing: each step reports what it would do in `dry run` rows. Sorting writes only its `settings.json` and `run_ks4.py`, into `kilosort4\dryrun` |
| **Cancel** | stops the run at the next progress point ([Progress and results](#progress-and-results)) |

The tab also always shows a diagram of the run beside the progress bars
([The run diagram](#the-run-diagram)) and the computer's load under the Steps
panel ([Resource use](#resource-use)).

The **Run** menu and the toolbar have the same commands, and **Run
pipeline** is Ctrl+R. Each step tab's **Run this step** runs just that step
over the selected datasets, even when it is switched off, here on the Run
tab.

A config with validation errors, or a plan with blocking rows (`checkRun`:
duplicate outputs, `error: ...`), stops the Run before it starts, with an
alert. **Scan** and **Refresh metadata** are off while it runs.

### The plan

**Plan** puts one row per step and dataset in the results table (one per
file for Signals, one per format for Export, as `export:chronux`): **Step**,
**Dataset**, **Key**, **Output** (the file or folder the step writes),
**Status** and **Note**. The status bar sums it up:
`Plan: N row(s), K blocking.`

| Status | Meaning |
| --- | --- |
| `ready` | will run; the note may say more, such as `cache present (reused when the settings match)` |
| `ok`, `associated` | nothing to do: the probe fits; the Epsych2 session is already associated |
| `exists: skip`, `exists: overwrite` | the output exists; the step's **Overwrite** decides |
| `exists: skip (SkipExisting)`, `exists: will re-sort` | sorted output exists; **Skip datasets already sorted** decides |
| `skip: Kilosort4 queued`, `skip: Kilosort4 running` | a Kilosort4 run of the dataset waits in the queue or is going |
| `no recording files` | the folder holds no readable recording |
| `no probe`, `probe file missing`, `probe-channel mismatch` | the probe check (a mismatch: the probe has more sites than the recording has channels) |
| `behavior file missing`, `no session` | the associated session file is not there; none is associated and **Search** is off |
| `no extract file` | Export needs the Signals files, which are not there, and Signals is not part of this run |
| `duplicate output` | another dataset of the project writes the same file |
| `exists: new version` (transfer) | with **Copy outputs to** on, the dataset's folder at the destination already holds a copy: this Run's go to the version folder **Output** names (`<session>_v2`, ...). `exists: overwrite` and `exists: skip` say what happens to the files already there; `ready`: the folder is not there yet |
| `error: ...` | the dataset cannot run: a setting that cannot apply to it (`error: LFP_Fs above the recording rate`), an output folder shared with another dataset, its sorted-output folder missing, a name that gives no unit identity, unit labels that would clash with another recording's, a copy destination that is the dataset's own folder |

Rows whose status starts with `duplicate` or `error` block the run. The full
list is in [Plan](EphysPipeline.md#plan).

<!-- wiki: ![The Run tab after Validate and Plan, with the run diagram and the resource monitor](images/app-run-plan.png) -->

### Progress and results

During a run:

- **Overall** shows how far the step underway is through its datasets
  (`spikes 2/3`: dataset 2 of 3), and **Current** how far it is on the
  dataset in hand. The line under them names the step, the dataset and what
  is being done. The artifact detection a Sorting, Signals or Spikes step
  needs reports as that step, and the export formats as one `export` step.
- The **Log** gets one timestamped line per event.
- The results table fills as the Run goes, one row per step and dataset:
  **Step**, **Dataset**, **Status**, **Message**, **Output**, **Seconds**. A
  row shows at the pipeline's next progress event after it is recorded (the
  table is only touched when a row was added), and a row the Kilosort4
  monitor restates during the Run shows at once. Signals gives a row per
  file, Export one per format, and Behavior up to three: `behavior` (the
  match), `behavior:pairing` and `behavior:file`. The last Run's results stay
  in the table: the monitor goes on restating its background runs there.

| Status | Meaning |
| --- | --- |
| `done` | written |
| `skipped` | nothing to do: the output exists and **Overwrite** is off, the dataset has no recording files, or (sorting) it has no probe, a Kilosort4 run of it is queued or going, or it is already sorted with **Skip datasets already sorted** |
| `dry run` | what a dry run would have written |
| `launched` | a background Kilosort4 run started. The monitor turns the row into `done` or `error` when the run ends, adding the time it ran to **Seconds** |
| `queued` | a background sorting run handed to the monitor ([below](#queued-sorting-runs)); it turns `launched`, then `done` or `error` |
| `error` | failed on this dataset; the message says why. The run goes on with the next dataset |
| `cancelled` | stopped by **Cancel**; for sorting also a run stopped with **Stop runs...** or dropped from the queue by **Stop queue** |

The probe and behavior rows carry their own statuses: `ok`, `no probe`,
`probe file missing`, `probe-channel mismatch` (probe); `associated`,
`matched (prefix)`, `matched (time)`, `ambiguous`, `unmatched` (behavior);
`approved`, `auto-approved`, `needs review`, `count mismatch`, `no trial line`
(behavior:pairing; `auto-approved`: approved just now by
[auto approval](#auto-approval)).

**Cancel** takes effect at the next progress boundary. The dataset in hand
is marked `cancelled`, and nothing is written for it: every output is
written to a temporary file and renamed only when complete. The rest of that
step's datasets are marked `cancelled` (`not run`), and the later steps do not
run. Cancelling does not stop the background sorting runs already
launched; while the sorting step waits for a free slot, it stops the wait.

**Background sorting runs** launched by a Run are handed to the same
monitor as the Sorting tab's
([Watching background runs](#watching-background-runs)) as each one starts.
The label under the log counts them, as in
`Background Kilosort4: 1 of 3 finished (1 running, 1 waiting to start).`,
where waiting to start means queued, or still in the Run's sorting step.
The label names the runs' sorter (`Background sorting: ...` when they are
by different sorters; the Sorting tab's sorter while none is followed).

### Queued sorting runs

With **Queue the waiting runs; the Run goes on** ticked, the sorting step
does not wait for a free slot. It writes each dataset's run files and hands
the run to the background monitor; its result row says `queued`. The Run
goes straight on to its next step and ends without waiting, which leaves the
app free. The monitor starts each queued run, in order, as a slot frees
(with the working config's runs at once and GPUs, so raising **<sorter>
runs at once** drains the queue faster), and the row turns `launched`.
While a Run that waits for its own slots is under way, the queue waits until
it ends. **Stop queue** (beside the background-runs label under the log) drops the
queued runs that have not started (their rows turn `cancelled`; their run
files stay); the runs already going carry on. Clean up refuses to delete
files while runs are queued.

**Closing with background runs.** With runs queued, closing the app asks:
**Keep the queue for next time**, **Drop the queue** (running the Sorting
step again writes and starts them) or **Cancel**. A kept queue is stored
per project root (the `KeptSortingQueue` preference: each run's dataset key
and the prepared run `launchSorting` starts). Once that root is next
scanned, the app lists the kept runs: those that can go back in the queue,
and those that cannot, with why (the dataset is no longer in the project, a
run file such as the `.bin` is gone, or its sorter is already queued or
going in its folder). **Queue them again** puts the first back in the queue,
where the monitor starts them as slots free; **Drop them** does not. When
none can go back, an alert says why instead. Either way the kept queue of
that root is then forgotten; the log names each run. Runs that are going
when the app closes carry on as processes, and the next launch follows them
again (the `KeptSortingRuns` preference): their log streams on, they take
slots, and one that ended meanwhile is logged as done or failed. A run that
has not ended but has no process left (the computer restarted under it,
`EphysDataset.sortRunProcesses`) is not followed; the log says so, and
sorting its dataset again finishes it.

### Stopping a run

**Stop runs...** (beside **Stop queue**, on while background runs are
going) stops runs that are going. With one run it asks for a confirmation;
with several it lists them (dataset, GPU, minutes running), all selected,
to pick from. Each chosen run's `ks4_status.json` (`si_status.json` for a
SpikeInterface sorter) is set to `cancelled`
(`stopped by the user`) and then its processes are ended
(`EphysDataset.stopSortRun`: Python, conda and the launcher, found by the run
folder in their command line); the log says `[stopped]` and its row turns
`cancelled` ("stopped before it finished"). What the sorter wrote so far
stays in the run folder. The freed slot goes to the next queued run, so
press **Stop queue** too to stop everything. Blocking runs cannot be
stopped: MATLAB waits for them.

### Copying the outputs elsewhere

**Copy outputs to** (under the steps) copies each dataset's outputs to
another folder while the pipeline runs, such as a share where the analysis
happens. The copies are laid out as the raw data is:
`<folder>\<subject>\<session>`, the dataset's recording folder below the
project root (its key), with each file's path below the dataset's output
folder kept (`kilosort4\params.py`). It is the config's `Transfer` section,
saved with it; see
[Copying the outputs elsewhere](EphysPipeline.md#copying-the-outputs-elsewhere).

| Control | Setting | Choices |
| --- | --- | --- |
| **Copy outputs to:** box and folder (**...** browses) | `Enabled`, `Destination` | a full path; it is created when needed |
| first list | `Method` | **copy** (the outputs stay here too), **move** (once copied and checked, the outputs are removed here when the Run is over) |
| second list | `When` | **after each step**: each output as soon as its step has written it, while the next steps run; **after the run**: all of them once the Run is over |
| **If it is there:** | `IfExists` | **new version**: when the dataset's folder at the destination already holds anything, this Run's copies go to a new `<session>_v2` (`_v3`, ...), so the earlier copy stays whole; **overwrite**: the files already there are replaced; **skip**: they are left as they are and only the missing ones are copied |
| **Check each copy by SHA-256** | `Verify` | check each copy by its checksum (both files are read once more); off: by size and modified time |

What is copied: the files and folders each step recorded for a dataset (its
result rows' **Output**): the behavior file, the artifact cache, the sort
folder (without its hidden `.phy` cache; never the `.bin`), the derived
signals, the spikes file, the exports and the analysis figures, also when a
step kept an output that was already there (**Overwrite** off). The
dataset's manifest goes with them and is never removed. A background sort
is copied once it has finished (one that fails is not). The analysis report
over every dataset and the run record stay where they are.

The copying runs outside MATLAB, in the copy engine the Copy tab uses
(robocopy), so the Run never waits for it: it ends when its steps are done,
and the copies go on while the app is used. Each dataset has a `transfer`
row in the results, whose **Output** is its folder at the destination and
whose status follows the copies: `waiting` (for a background sort),
`queued`, `copying`, `copied` (a move, removed here once the Run is over),
`done`, `error`, `cancelled`. The last row of the tab shows them all: a bar,
how much is copied, the rate and the time left, and the batch in flight, as
in `Copying outputs: 45%, 1.2 GB of 2.6 GB, 3 of 8 batch(es), 40.1 MB/s,
about 1 min left   SUBJ-1/SUBJ-1_260916_110907: signals (2 of 3 file(s))`.
The Run tab's button turns blue while they go.

**Stop copying...** (beside it) stops them after a confirmation: the files
being copied stop where they are, what is copied stays at the destination,
the rest is not copied and a move removes nothing more. While a move is
still going, a new Run is refused: the move would remove what the new Run
reads. Closing the app while copies go asks first: the files being copied
finish on their own, but nothing checks them or copies the rest. Running
again with **Copy outputs to** on copies what is missing.

With **move**, the outputs are removed here only once the Run is over and
only if they have not changed since they were copied. A sort folder moved
this way becomes the dataset's sorting folder (saved in its manifest), so
the Review tab, Export and the analysis read its units at the destination.

### The run diagram

The right side of the tab is split in two, 3:1: the progress bars, issues,
results and log keep the left three quarters and a diagram of the run takes
the right quarter. It draws every
step in execution order (Probe check, Behavior, Artifacts, Sorting, Signals,
Spikes, Export), in the Diagram tab's step colours, each with a line saying
what it does under the working config.

- The step underway is tinted, framed in its colour with a pulsing ring, and
  shows `RUNNING`, its percentage, a moving bar, the dataset (*Dataset 2 of
  5: name*) and what it is doing; the diagram scrolls to it as the run moves
  on.
- Every step of the run has a percentage: how far it is through its
  datasets, (dataset − 1 + progress within the dataset) / datasets. Finished
  steps show `done` at 100 % with their result counts (done, in the
  background, dry run, skipped, to check, errors, cancelled; a background
  Kilosort4 run moves from "in the background" to done or errors when the
  monitor sees it end), red when any row is an error.
- A cancel leaves its step at the percentage it reached and the later steps
  `not run`. Steps outside the run are dashed.
- The headline says which step of how many is underway and for how long, or
  how the run ended.

Before the first run the diagram previews the ticked steps and follows the
checklist; afterwards it keeps the last run until the next one starts.

### Resource use

The **Resource use** panel under the Steps panel has a bar and figures for
each of:

| Row | Shows |
| --- | --- |
| CPU | all cores, as Task Manager counts them |
| Memory | memory in use, of the total |
| Disk | the busiest physical disk's active time, with the read + write rate over all disks |
| GPU | the busiest GPU's use and memory; `n/a` without an NVIDIA driver |

Tooltips give the detail (every GPU, say). A bar turns orange at 90 %. It
shows what limits a run: with a disk at 100 %, more workers will not help.
The sampling is done outside MATLAB by
[`resource_monitor.ps1`](../pipeline/resource_monitor.ps1), a Windows
PowerShell script launched at idle priority that opens the performance
counters once, keeps one `nvidia-smi` running in loop mode for the GPU, and
every 2 s overwrites one small JSON file in its own temporary folder;
together they use well under 1 % of one core. The app only reads that file
on a 2 s timer, and not at all while another tab is showing, so a busy
MATLAB never stops the sampling itself. The sampler starts the first time the
Run tab is shown (also by **Validate config**, **Plan** and **Run pipeline**)
and runs until the app closes, which stops it (it also stops by itself when
MATLAB exits) and it deletes its folder; if no sample comes for 15 s, the app
starts a new one.

## Visualize

Any signal of the active dataset, with its spikes over it, read a window at a
time. Nothing on disk is changed: the artifact periods are only shaded here
(the manual ones are marked on the [Artifacts](#artifacts) tab's plot;
**Mark manual periods** opens it on the stretch shown here).

The tab loads the active dataset when it opens, and again whenever the active
dataset changes while it is open (`onPlotVisualization`). It finds what the
dataset has on disk with `EphysDataset.outputs`: the recording (when its files
can be read), the Sorting `.bin`, the Signals step's LFP / MUA / SPIKE / AUX,
the associated sorted units and the Spikes step's detected spikes. **Reload
data** finds them again after a run has written new files. While the tab is
hidden the plot keeps the dataset it shows; the status line then names both
datasets.

<!-- wiki: ![The Visualize tab: the recording around a manual and an automatic artifact period, with sorted units, detected spikes and TTL rows](images/app-visualize-traces.png) -->

| Control | Meaning |
| --- | --- |
| Show | the continuous signal drawn, from the files this dataset has: *Recording* (as every step reads it), *Sorting .bin* (what Kilosort4 sorted: artifact periods filled, the common reference subtracted when one was on, from its JSON sidecar), *LFP* / *MUA* / *SPIKE* / *AUX* (the extract files), or *None (spikes only)*. The line under it says what the signal is (its band, its reference, the periods erased). The kind shown is kept from one dataset to the next |
| Channels, Lanes | recording channels to draw (`all`, or e.g. `1:16`, `1 3 5`; for a signal whose columns were kept or reordered, its columns are matched to recording channels through its `importOptions`); lanes shown at once |
| Reference | the recording only: *As the pipeline (Artifacts tab)* (the config's common reference, `Reference.Mode`, over its good channels, as every step reads the recording) / *None (as recorded)* / *Common average (mean)* / *Common median* across the channels shown, taken on the recording as stored, so one reference at most is ever applied. The other signals carry their own |
| High-pass / Low-pass, Filter order | a display filter on any signal (`filterContinuous`, zero phase); blank = off, both = band-pass. Each window is read with a margin so the filter settles. A new filter or reference rescales the traces |
| Remove offset | centre each lane on its median in the window drawn |
| Sorted units | ticks or waveforms, one colour per unit (twelve colours, in probe order); *Units*: all but noise / good + MUA / good only, by phy's labels (else Kilosort4's) |
| Detected spikes | ticks or waveforms, one colour per channel |
| Draw on | *Their channel's lane* (a unit on its peak channel) or *Lanes of their own* (a raster lane per unit / channel after the traces). With *None* they always get their own lanes |
| Events: Draw, Lines | the digital-input events: *Over the traces* (a solid line at each onset, a dotted one at each offset, across the lanes), *Above the traces (TTL)* (each line as a TTL trace in a 16-pixel row of its own above the top lane), *Both* or *Off*; *Lines* picks the lines drawn (at first every line with an event). **Read events** reads them from the recording when nothing else has them, see below |
| Start, Window, Spacing | the view, which follows every pan and zoom; type to jump. Spacing is the voltage between neighbouring lanes (the scale bar at the top right) |
| Plot, Colours | traces, or a heatmap of each bin's extreme per lane (colour range ± Spacing) |
| Order by probe | lanes by shank, top of the shank first, with a dotted line between shanks (`channelLayout` on the dataset's probe, else the config's default probe); the units' and channels' own lanes follow the same order |
| Traces | trace colour: a solid colour (black, blue, red, green, magenta, orange, grey), **By shank** (needs a probe), or **By depth** (position on the probe, top first) / **By channel** (lane order) in the Colours colormap |
| Shade artifact periods | orange (detected) and purple (manual), see below |

The display settings are kept between sessions (the `VizOptions`
preference), all but the dataset, **Start**, **Spacing** and the event
**Lines**.

<!-- wiki: ![The same window as a heatmap, high-passed](images/app-visualize-heatmap.png) -->

**Reading.** The viewer ([`EphysTraceViewer`](../pipeline/EphysTraceViewer.m)
over an [`EphysTraceSource`](../pipeline/EphysTraceSource.m)) reads only the
window shown, with up to one window of margin on each side, and reduces each
lane to the min and max of every bin of about one pixel column. A draw
therefore costs about the same at any zoom and never scales with the
recording's length. The recording readers (Intan, Open Ephys, binary) all read
just those rows (`readWindowUV`); a reader without random access would be read a
`streamPlan` chunk at a time, the last chunks kept (up to 1.5 GB). A `.bin` is read with `fread`
and its min / max are taken on the stored integers; a `-v7.3` extract is read a
window of rows at a time with `h5read`, and a `-v7` one is loaded once. No file
is held open between reads. A view read at full rate is at most
`MaxReadSamples` (2^27 samples × channels, about 70 s of 64 channels at
30 kHz) wide; a wider one, up to the whole recording, is drawn from the
signal's envelope (below).

**Envelope.** For each signal it shows, the tab keeps an envelope
([`EphysTraceEnvelope`](../pipeline/EphysTraceEnvelope.m)): the min and max of
every channel over blocks of samples, at block sizes growing 4 times level by
level, down to a level of at most 4096 blocks. It is cached next to the
dataset's outputs, one file per signal (`<Name>_envelope_<what>.dat`: the
recording as stored or with the common reference, the `.bin`, each derived
signal; [file-formats.md](file-formats.md#signal-envelope-name_envelope_whatdat)),
and built the first time the tab shows the signal, in the background: a span of
the recording or `.bin` at a time on a thread of MATLAB's `backgroundPool`, a
derived signal (which `h5read` cannot read on a thread) a span per tick of a
timer. Each span is read through the same reader as the full-rate view, so the
reference and the `.bin`'s filled periods match, in pieces of at most 2^23
samples × channels. The status line says how far it is ("building the envelope
of Recording for wider views: 35%"); the plot can be used meanwhile. Another
signal or dataset stops the build (its partial file is deleted), and so does
closing the app; the next time the signal is shown the build starts again. Once
built, a view wider than one full-rate read is drawn from the coarsest level
with a block per pixel column or less (the status line says "drawn from the
envelope"), and the overview strip shows the signal. The envelope holds the
samples as stored, so a view wider than one read needs the display filter off
and the reference *As the pipeline* or *None*; with either set, the view stays
within one read and the status line says why. The cache is used only while its
fingerprint matches: the files read (sizes and modified times), the rows,
channels and rate, the reference and its channels, the `.bin`'s scale, and the
block sizes. A `.bin` or extract written again is noticed within a second and
its envelope built again; a stale file is never shown. For 2 h of 64 channels at
30 kHz the file is about 140 MB (level 1: blocks of 1,024 samples; 2^24 blocks ×
channels at most, so no file passes about 170 MB), and its build reads the
recording once. The files are display caches: the [Clean up](#clean-up) tab
removes them (**Visualize's envelopes**, ticked by default), and an envelope the
tab is showing whose file goes is noticed within a second and built again when
the tab next draws.

**Timing.** Row k of every signal is drawn at (k − 1)/Fs seconds on the
recording's clock, as sorted spike times and the artifact periods are; a bin is
drawn at its first sample. Zoomed in to one sample per bin, every sample is
exact.

**Speed.** A pan inside the margin only moves the axes limits. A zoom or a pan
past it draws again from the samples kept in memory (up to 2^26 samples ×
channels) and reads the disk only for rows it does not hold. Lanes of one colour
are one line and each spike colour is one line, so the graphics stay small
whatever the channel or unit count. Wheel turns faster than a draw are merged.
On the workstation (64 channels at 30 kHz, `.bin`), a pan inside the margin
takes about 40 ms, a voltage scale or lane scroll 40–90 ms, a zoom out to 60 s
about 0.3 s.

**Spikes.** *Ticks*: one per spike, drawn in the top half of its channel's lane
for sorted units and in the bottom half for detected spikes (so the two stay
apart), or across its own lane; ticks that would fall on one pixel column of one
lane are drawn once. Ticks are 2 points wide, edged in the plot's background
colour and drawn in front of the traces, so they show on a dense trace.
*Waveforms*: on a trace lane the trace itself is recoloured
over each spike's window, as phy's trace view does (a unit's template window,
at most −1 to 1.5 ms; a detected spike's `windowMs`). On its own lane (or with
no trace) the stored waveform is drawn: the detected snippet in µV, or the
unit's template (in µV when the sort has `bin_scale`, else scaled to the lane).
Waveforms in µV on their own lanes have a scale of their own, not Spacing:
twice the median of the units' template peaks (a channel's peak is the median
of its snippets' peaks), rounded up to 1, 2 or 5 × 10ⁿ µV between lanes, so
the median peak reaches 0.2 to 0.5 of the way to the next lane. The status
line gives it; Ctrl+wheel and **Taller** / **Shorter** scale it with the
traces, and **Auto scale** / **Reset view** pick it again. A template or
snippet spans about 2 ms, so its shape shows only zoomed in (about 20 pixels
in a 0.1 s window on a 1,000-pixel plot); in a wider window it is a vertical
stroke as tall as the spike.
With more than 4,000 spikes in view, or on a trace below 10 kHz, waveforms fall
back to ticks and the status line says so.

**Events.** The events come from the Signals step's extract (lines named and
their polarity applied as when the step ran), else from the dataset's events
file `<Name>_events.mat` (written by the Trials tab, a Signals run or **Read
events**), which gets the polarity of the dataset's `InvertedLines`. With
neither, **Read events** reads the digital inputs from the recording (for
some formats the whole recording) and keeps them in that file. An onset at
row r (t = r/Fs on the events' clock) is drawn at (r − 1)/Fs, on the sample the
line turned on; an offset at the first row after the last on row. Markers that
would fall on one pixel column are drawn once.

**Interaction.** The **?** button at the right end of the toolbar opens a
small window listing these; it can stay open beside the plot. With the pointer
over the plot:

| Input | Action |
| --- | --- |
| wheel | zoom time about the pointer |
| Ctrl+wheel | scale the voltage |
| Shift+wheel | scroll the lanes |
| drag | pan time and lanes |
| ← / → | pan a quarter window; Ctrl: a whole window |
| Shift+← / → | zoom time out / in |
| Page Up / Page Down | a whole window |
| ↑ / ↓, + / − | scale the voltage |
| Shift+↑ / ↓ | scroll the lanes |
| Home / End | the recording's start / end |
| A, R | auto scale; reset the view (2 s from the current start, top lane, auto scale) |

The toolbar above the plot does the same with buttons (**< Page**, **Page >**,
**Zoom in / out**, **Taller / Shorter**, **Auto scale**, **Reset view**). The
strip under the plot shows the whole recording, the view as a blue box, the
spike rate of the layers shown and the artifact periods, and, once the envelope
is built, the signal itself: for each pixel column the median, over the lanes'
channels, of each channel's min and max about its own median, scaled so a
typical column spans 40% of the strip (a large excursion, such as an artifact,
reaches its edge). Click or drag in it to centre the plot there.

**Stepping through events.** At the right end of the toolbar, before the
**?**, a box picks an event line (each listed with its number of onsets; at
first the dataset's trial line, else the first line with an onset), and
◀ / ▶ show its previous / next onset, a quarter of the way into the window,
the window keeping its width. The status line then says which onset it is
(`InTrial onset 12 of 240 at 95.3121 s`), or that there is none that way.

**Artifact overlays**: orange = the Artifacts tab's **Detect / Preview**
intervals of the plotted dataset (the detector a run uses, over the whole
recording), while its detection settings are still the ones the preview ran
with; otherwise the automatic detection the last run used
(`<Name>_artifacts.json`, read with the plot: what was erased from the
processed files), and the status line says which. For the last run's periods
it also says whether the current settings would detect the same ones
(`EphysPipeline.cachedDetection`: the file's fingerprint against the one the
current settings give, nothing detected): *with the current settings*, or
*with other settings* (Detect / Preview shows what the current ones find).
It cannot tell while automatic detection is off (a run then erases none of
them) or while a common reference is on whose left-out channels were never set
(the first referenced read suggests them). With neither, none is
shaded and the status line says why. Nothing is detected on the displayed
data. Purple = manual periods. The artifact status line counts both and says where a run
erases the manual periods: in the `.bin`, and in the signals too while the
Signals tab's *Erase the artifact periods first* is ticked. **Mark manual
periods (Artifacts tab)** opens the Artifacts tab's plot on the stretch shown
here (from its start, at most 10 s; *Go to (s)* there) with **Mark artifacts**
on, where the periods are added, removed and cleared; with a plot of another
dataset than the active one it just opens the tab. Manual periods are written to
the dataset's manifest, so they survive a rescan and a restart.

## Review

Summarizes a sorted-output folder (the folder holding `params.py`): its units
per shank and label, their spike counts, rates, quality metrics, positions and
waveforms. Any sorter's output reads, as long as it is in phy's files:
Kilosort4's, a SpikeInterface sorter's (written in Kilosort4's layout, see
[Sorting](#sorting)) or a phy-curated copy of either. It reads the output as
saved and changes nothing but the unit notes. Every cluster is shown,
`noise` included. A folder
that belongs to the active dataset (under its folder or output folder, or its
pinned sorting folder) is read with `EphysDataset.readSortedUnits`, so units
carry their full labels (`su042_1255_260908T1039`, see
[Unit labels](#unit-labels)); any other folder, or a
dataset whose name does not match `Project.NamePattern`, is read with
`readPhyUnits` and its labels are only `<class><id>`.

<!-- wiki: ![The Review tab with a unit selected](images/app-review-tab.png) -->

- **Dataset**: the active dataset. Its own sorted output loads when the tab
  opens and whenever the active dataset changes while it is open: the
  folder pinned with **Use folder...** on the Sorting tab, else the run
  folder of the config's **Sorter** (`kilosort4`, or `si_<sorter>`), else
  its most recently changed sort. A dataset without sorted output clears
  the tab, and so does one whose hand-picked sorted-output folder is not
  there now: the tab says so, and no other sort stands in for it (the
  folder field is emptied, or names the missing folder).
- **Sort**: every sort the active dataset has, to review any of them. Its
  own comes first, marked **in use** (the one Export and the analysis
  read), then each other folder under its output folder that holds a sort
  (`spike_clusters.npy`): `kilosort4`, `si_<sorter>` for each
  SpikeInterface sorter run, a [sort sweep](EphysDataset.md#unit-quality-metrics)'s variants, a
  copy. Each item names the folder (relative to the output folder;
  **pinned** and the full path for a pinned folder elsewhere), its sorter
  (the run's `settings.json`, else the folder's name) and its number of
  units. Choosing one loads it for review only: it changes nothing the
  other steps read. With a pinned folder that is not there, the list still
  offers the others.
- **Use this sort** (beside Sort): makes the sort shown the active
  dataset's sorted output, as **Use folder...** on the Sorting tab does,
  so Export, the analysis, Visualize's units and phy from the Sorting tab
  read it, and the list marks it **in use**. The folder is pinned to the
  dataset (saved in its manifest), except the run folder of the config's
  **Sorter**, which is the auto association: for it the pin is cleared, as
  **Use auto** does. A folder from **Browse...** / **Load** that is not one
  of the dataset's sorts is used only after you confirm. The button is off
  while no sort is shown or the one shown is already in use.
- **Browse...** / **Load** accept any sorted-output folder, a dataset
  folder or a `kilosort4` folder (the folder itself, else its `kilosort4`
  subfolder); one that is not among the dataset's sorts is added to
  **Sort** as **other**. **Open folder in explorer**, **Open in phy** (green, **Open in phy (curated)**, for a sort curated in phy).
- **Summary**: the dataset key and label form (or the folder and why labels
  are short), the sorter and where the groups come from (curated in phy,
  Kilosort4's `KSLabel`, or a SpikeInterface sort's `SILabel`: good / mua by
  the good-unit criteria), Fs, the sorted time (**Sorted:** its length and
  span), channels, shanks, unit counts by label, total spikes, mean rate
  over the sorted time, units per shank.
- **Units table**: Unit, Group (phy's `cluster_group.tsv` when present, else
  `cluster_KSLabel.tsv`, or a SpikeInterface sort's `cluster_SILabel.tsv`), Shank, Ch (the peak channel's native name, else its
  recording channel number), X / Y (µm, the template centre on the probe),
  #Spk, FR (Hz), Amp, Cont%, **QC** (meets the criteria: yes / no), the
  metrics it judges (ISIv: ISI violations ratio, Pres: presence ratio,
  Cutoff: amplitude cutoff, SNR), **Notes**. The quality metrics are
  computed when the sort loads ([`EphysDataset.unitQuality`](EphysDataset.md#unit-quality-metrics):
  the active dataset's sort with SNR from the recording's noise; any other
  folder without SNR, from the length of the `.bin` its `settings.json`
  names) and cached in the sort folder's `quality_metrics.json`; the
  Summary says how many units meet the criteria, or why the metrics could
  not be computed. Clicking a row focuses the plots, whose titles show the
  unit label; **Show all units** clears the focus. The table scrolls
  sideways. Click a header to sort: the sort is kept for every sort loaded
  and the next session, and right-click → **Clear sort** returns to cluster
  order ([Sorted tables](#sorted-tables)). Rows are matched to units by the
  cluster id, so a click, a note and the selected row reach the right unit
  in any order.
- **Good-unit criteria** (above the table): ISI ratio <, Presence >, Cutoff <,
  SNR >, Drift <, Rate > (blank = not applied), the config's
  `Sorting.Quality` (default 0.5, 0.9 and 0.1 for the first three, the
  Allen Institute's thresholds). Editing one judges the loaded units again at
  once, without computing their metrics again.
- **QC report**: writes the loaded sort's unit-quality page,
  `quality_report.html` in the results folder ([`writeUnitQualityReport`](EphysDataset.md#unit-quality-metrics):
  the criteria, a histogram per metric, a row per unit with its failed
  metrics marked, the good units first, each good unit's mean waveform),
  and opens it in the browser. Click a column header on the page to sort
  the table by it.
- **Notes**: the one editable column. Typing a note saves it at once to
  `cluster_notes.tsv` next to the sort (`EphysDataset.writeUnitNotes`), the
  file phy uses for a `notes` label, so the Chronux export's `units`, the
  FieldTrip export's `spike.hdr.orig` and `unitTable` carry it. A note that
  cannot be saved is put back, with an alert.
- **Plots**: the selected unit's inter-spike interval histogram (intervals up
  to 50 ms in 0.5 ms bins; those under the 1.5 ms refractory period in red,
  and the subtitle gives their share of all intervals) and autocorrelogram
  (±50 ms in 0.5 ms bins, as the rate in Hz of the unit's other spikes at each
  lag from one of its spikes; the refractory period is shaded and a dashed
  line marks the unit's mean firing rate, the level of no correlation); both
  ask for a unit when none is selected. Below them, amplitude vs time (at
  most 30,000 spikes, over the sorted time). Under the unit on its shank,
  smaller: units per shank and firing rate per unit.
- **Waveform on plots** (the row above the interval and autocorrelogram
  plots): lays the selected unit's waveform on its peak channel over the
  interval, autocorrelogram and amplitude plots, in a box over a pale ground.
  It is **Off** by default.
  - **Mean** draws the mean (red), **Subsample** the spikes (thin blue lines;
    as many as the count beside Spikes under the shank plot, the same ones),
    **Mean + subsample** both. The box is captioned with the channel and the
    mean's peak-to-peak amplitude.
  - **at** puts the box at a compass point of each plot: North is the top edge,
    East the right, and so on round to North-west, with **Centre**.
  - **scale** sizes the box: 1x is a third of the plot's width and height,
    0.25x to 3x.
  - It draws from the spikes the shank plot read, so changing it never reads
    again. Without the sorted `.bin` the template is drawn instead, whatever
    the mode.
- **Unit on its shank** (the large plot on the right): the selected
  unit's spikes at every site of the shank it was detected on (its peak
  channel's). Each site is drawn where it sits on the probe
  (`channel_positions.npy`) and labelled with its channel. The peak channel
  is drawn in red, and a scale bar gives amplitude and time.
  - **Spikes** draws the spikes as thin lines. The number beside it is how
    many to read, picked at random (the same ones each time).
  - **Mean ±** adds their mean with an error band: **SD**, **SEM** or
    **none**.
  - The spikes are cut from the sorted `.bin` (`params.py`'s `dat_path`) by
    [`EphysDataset.readPhyWaveforms`](EphysDataset.md#reading-sorted-units).
    They are prepared as Kilosort4 saw them, referenced and high-passed but
    not whitened, in the templates' units (µV when `settings.json` has
    `bin_scale`).
  - A unit's spikes are read once. Changing Spikes, Mean or the band redraws
    without reading again; changing the count reads again.
  - When the `.bin` is not there (a Clean up removed it, or its disk is not
    connected), the unit's template is drawn in its place. The subtitle says
    so, and the status bar names the file.

<!-- wiki: ![The units table scrolled to Notes](images/app-review-notes.png) -->

Firing rates are spike counts over the **sorted time**: from Kilosort4's
`tmin` to `min(tmax, the recording's end)` (the run's `settings.json`; 0 and
the end by default). The recording's length is the active dataset's when the
folder is its sort, else that of the `.bin` the settings name; only when
neither is known does the last spike end the span, and the summary says so.
The units struct also carries `ksChannel` (the peak
channel among the sorted channels), `channel` (the 1-based recording channel),
the peak site (`peakX`, `peakY`) and the class and identity fields.

### Unit labels

Every sorted unit read through a dataset carries a label that names its
recording as well as its cluster, so a unit taken out of its file still leads
back to the recording ([details](EphysPipeline.md#unit-labels)):

```text
su042_1255_260908T1039
|  |   |    `------- recording start, to the minute (yyMMdd T HHmm)
|  |   `------------ subject
|  `---------------- cluster id, at least 3 digits
`------------------- class: su (phy "good") | mua | noise | uns (unsorted) | other
```

The subject and the start come from the dataset name through the
[name pattern](#name-pattern-and-token-columns): with the default pattern,
`SUBJ-ID-1255_260908_103949` gives the subject `SUBJ-ID-1255`; with
`SUBJ-ID-{SubjectID}_{Date:yyMMdd}_{Time:HHmmss}` it gives `1255`, and the
label above.

- A dataset whose name does not match the pattern cannot label its units:
  the Export step refuses to write them (plan status `error: unit identity`).
- Two recordings of one subject that start in the same minute would share
  labels: the plan marks them `error: unit label collision`.
- A folder browsed to here that does not belong to the active dataset, or a
  dataset whose name does not match the pattern, gets short labels (`su042`)
  on this tab.

<!-- wiki: To gather units across recordings into one table, see [Loading outputs](Loading-Outputs#all-units-in-one-table). -->

## Synthetic

Designs, previews and writes one synthetic dataset with
[`makeSyntheticRecording`](../pipeline/makeSyntheticRecording.m): a
recording, a copy of its Epsych2 session, ground-truth sorted output and a
manifest. The neural signals are a [`SyntheticDesign`](../pipeline/SyntheticDesign.m);
the events they follow come from a schedule. It is not a pipeline step.
**File → Create synthetic test project...** writes a whole project instead
([Synthetic test project](#synthetic-test-project)).

<!-- wiki: ![The Synthetic tab after Preview, with the built-in task](images/app-synthetic-tab.png) -->

**Timing from** picks the schedule:

| Choice | Events | Session written |
| --- | --- | --- |
| Built-in task | the AM-detection task drawn from the seed (six lines as on the lab's rig; **Task trials**, **Scenario** as in [Synthetic test project](#synthetic-test-project)) | a synthetic one |
| Active dataset: recorded lines + Epsych2 session | the active dataset's own digital lines (read once with `digitalEvents`, cached next to its outputs), with its line polarity applied, at the same rows over the same length; its trials from its pairing, with the reviewed cuts | a copy of the dataset's session |
| Active dataset: Epsych2 session only | rebuilt from the session: each trial ends at its `computerTimestamp` and lasts **Trial (ms)**; the trial line is on for it, and each row of the lines table (**Line**, **Onset (ms)**, **Duration (ms)**) adds a line that goes on Onset ms after the trial starts (**Add line**, **Remove line**). All three are expressions over the trial's numeric parameters (`StimDelay + RespWinDelay`); blank = automatic: Stim, RespWindow and a Trough poke per response when the session has those parameters | a copy of the dataset's session |

The session copy keeps `Data` as saved; `Info` gets the tab's **Subject**, its
new file name and `Info.Synthetic` (the source file, subject and dataset). The
source is only read. **Load source** reads the schedule (a dataset source also
sets **Fs**, **Channels** and **Subject**, the session's subject + `-SYN`, to
the dataset's, and fills in the automatic lines); **Preview** and
**Generate...** load it first when needed. Choosing another active dataset
drops a loaded dataset schedule.

**Recording**: format (the Intan layouts, the binary format, or an Open Ephys
session in the Binary, Open Ephys or NWB format), **Fs**, **Channels**,
**Seed** (the same seed and settings give the same data), **Subject**, **File
(s)** per `.rhd` file, **Max (s)** (dataset sources: stop the recording early;
lines still on end at the last sample, so the pairing has a mismatch to
resolve, as when a recording is stopped early), **Sorted output** and
**Artifacts**. The sites are the dataset's probe (its own, else the config's
default) when it has enough of them, and that probe goes into the new
manifest; otherwise a synthetic probe is written as `<Name>_probe.json`. The
line under the fields says which.

**Units (spikes)**, one row per unit. A unit fires at **Baseline (Hz)**; when
**Event** names a line, its rate around every **Edge** (onset or offset) of
that line, from **Latency (ms)** for **Duration (ms)**, is baseline × (1 +
(**Gain** − 1) × envelope). **Shape** sets the envelope: sustained (flat), transient
(a raised-cosine bump) or phasic-tonic (a bump over the first 30 % on a 40 %
plateau). Gain above 1 excites, below 1 suppresses. **Jitter (ms)** is the SD
of the latency from event to event. **Parameter** scales the response by an
Epsych2 trial parameter, normalized to 0..1 over the session, rising or
falling with it (**Tuning**). Events outside any trial respond fully. **Channel**, **Amplitude (uV)**
and **Width (ms)** shape the waveform, spread over the neighbouring sites.
NaN means random (channel: spread the units evenly), drawn from the seed.
**Add unit**, **Remove** (the selected rows), **Built-in design**
(makeSyntheticRecording's default for the channel count: random units, half
driven by Stim, one suppressed, and an evoked potential) and **Clear**.

**Event-linked LFP**, one row per component, each locked to a line's edges:
an **oscillation** (**Freq (Hz)**, **Amplitude (uV)**, a Tukey envelope with
**Rise (ms)** ramps over **Duration (ms)**; **Locked** = the same phase on
every event, so it survives averaging; unticked, a random phase each time,
so only its power is event-locked) or an **evoked** potential (an alpha
function peaking **Rise (ms)** after the latency, signed amplitude). **Profile**
spreads it over the probe's depth (site `yc`): uniform, superficial, middle,
deep, or reversal (the sign flips at mid depth). **Parameter** / **Tuning**
scale the amplitude as for units. **Add oscillation**, **Add evoked** and
**Remove** (the selected rows) edit the list.

**Background**: the ongoing 1.7 / 7.3 / 12.5 Hz rhythms (× **Rhythms**),
the slow 1/f-like noise, the white noise and line noise (50 or 60 Hz).
**Output**: **Folder** (blank: `<project root>_synthetic` next to the
project), **Load design...** / **Save design...** (JSON,
`SyntheticDesign.save` / `load`).

**Preview** runs `makeSyntheticRecording` with `PreviewOnly=true`, the same
options Generate passes, so it shows the spikes that are then written:

- the lines and every unit's spikes over **From (s)** for **Span** s,
  artifacts shaded, a linked unit's ticks in its line's colour;
- the **Unit** box's unit: a raster around its event's edges (up to 150
  events, sorted by its parameter), and a PSTH split by that parameter's
  values, the model's rate dashed. A unit with no event is shown around the
  trial line's onsets;
- the **LFP** box's component on its peak channel around up to 20 of its
  events: single events grey, their mean black, the model's mean dashed and
  an oscillation's envelope dotted (an induced one averages away while its
  envelope does not). The grey single events are drawn with fresh noise
  each time, so only their mean and the model match what is written;
- the probe's sites coloured by the component's gain, the peak ringed.

The generator seeds MATLAB's random numbers with **Seed** and puts the
caller's generator back afterwards. A source whose config inverts a line
(`Trials.InvertedLines`) has that line written inverted too (not for the
Open Ephys formats), so the synthetic dataset reads the same under that config.

**Generate...** checks the design against the source's lines and parameters,
confirms the folder and the size, and writes
`<Folder>\<Subject>\<Subject>_<yymmdd>_<HHmmss>` (Open Ephys formats:
`<Subject>_<yyyy-MM-dd>_<HH-mm-ss>`), named from the recording's start: the
source dataset's, or two minutes ago for the task. A folder that already
holds a synthetic dataset is replaced only after a second confirmation;
another non-empty one is refused. A dataset written under the project root is
scanned in at once and made active. Every dataset also holds
`<Name>_synthetic.json`: the seed, the schedule's source and the design.

The same from the command line:

```matlab
ds = app.currentDataset();                               % or any EphysDataset with a BehaviorFile
S = syntheticSessionSchedule(ds);                        % its recorded lines + session (Timing="session": rebuilt)
D = SyntheticDesign();
u = SyntheticDesign.newUnit("tone", "Stim");             % phasic-tonic, gain 4, 15 ms latency
u.Parameter = "Depth";                                   % grows with the AM depth
D.Units = u;
D.LFP = SyntheticDesign.newLFP("oscillation", "Stim");   % 40 Hz, phase-locked
T = makeSyntheticRecording("D:\scratch\SYN-01_260101_120000", Subject="SYN-01", Session=S, Design=D);
```

The settings and the design are preferences.

---

## Clean up

Frees local disk space once datasets are preprocessed, or removes what chosen
preprocessing steps wrote so they can be run again. It is not a pipeline
step and nothing in the config drives it; it acts on the datasets selected on
the Project tab (the ticked rows, else all), which the top of the tab names:
`Acts on the 3 dataset(s) ticked on the Project tab (of 12).` A raw
recording, Kilosort4's filtered copy of it and the `.bin` Kilosort4 sorts are
each about the size of the recording, the Visualize tab's envelopes up to about
170 MB per signal shown, and the outputs need none of them. The
tab lists every local file of the datasets, says which could go and why, and
removes the ones left ticked, after a confirmation.
The rules live in [`planLocalCleanup`](../pipeline/planLocalCleanup.m) and
[`runLocalCleanup`](../pipeline/runLocalCleanup.m), which can be called
without the app:

```matlab
P = EphysProject("D:\EPHYS\SUBJ-ID-1255");  P.refresh();
T = planLocalCleanup(P.Datasets, Remove=["sorter_copy" "bin"]);   % the preview: nothing is changed
T(T.Action == "remove", ["Dataset" "What" "Bytes" "File"])
R = runLocalCleanup(T);                                            % deletes the "remove" rows
R(R.Status ~= "removed", ["File" "Status" "Message"])              % anything left in place
```

`Remove` takes `"raw"`, `"sorter_copy"`, `"bin"` and `"envelope"` (the
default) and the step names below. Set a row's `Action` to `"keep"` to leave its file in
place; `Method="recycle"` or `Method="move", Destination=` choose how the
files go. For a move, [`cleanupMoveTargets`](../pipeline/cleanupMoveTargets.m)
previews where each file would land and what is already there, and
`IfExists=` (`"skip"`, `"overwrite"` or `"version"`) says what to do then:

```matlab
M = cleanupMoveTargets(T, "E:\removed", IfExists="version");   % nothing is changed
[T.File(M.Taken ~= "") M.Taken(M.Taken ~= "")]                    % the files already there
R = runLocalCleanup(T, Method="move", Destination="E:\removed", IfExists="version");
```

<!-- wiki: ![The Clean up tab after Preview](images/app-cleanup-tab.png) -->

**Free space (the outputs stay)**, each with its own tick box, all ticked by default:

| Kind | Files | Condition |
| --- | --- | --- |
| Raw recording files | the recording files the Copy tab copied into the session folder (for Open Ephys, everything under its Record Nodes), as listed in its `session_manifest.json` | each file's source, as recorded there, still exists **with the same size**. A recording not copied by the Copy tab has no known source and is always kept, as are the session files of an Open Ephys dataset that is one part folder of several |
| Kilosort4's filtered copy of the recording | `temp_wh.dat` under the dataset's `kilosort4` folder or its sorted-output folder | none; the sorted units do not need it, phy's trace view does |
| Sorting input .bin | the dataset's `BinFile` (`<Name>.bin`, or `<Name>_ks4.bin` beside a binary-format recording's own `<Name>.bin`) + its `.json` in the output folder (or in the Sorting tab's **Bin folder**, `Sorting.BinDir`, when one is set; only these two files are listed there, not the folder), written by `toBin` for Kilosort4 to sort | never the data file of a binary-format recording |
| Visualize's envelopes | `<Name>_envelope_<what>.dat` in the output folder: the min / max of each signal the [Visualize](#visualize) tab has shown ([Signal envelope](file-formats.md#signal-envelope-name_envelope_whatdat)), and a build's leftover `<Name>_envelope_<what>.dat.<token>.partial` | none for a finished one: a display cache, built again when the tab next shows the signal. A partial file goes only once it is an hour old (a build MATLAB left); a newer one may be being written, by this app or another MATLAB, and is kept |

**Remove what a preprocessing step wrote**: one tick box per step that writes
files, none ticked by default. Everything the step wrote goes, to run it again
or drop it:

| Step | Files |
| --- | --- |
| Sorting | the whole sort run folders, `kilosort4` and `si_<sorter>` for each SpikeInterface sorter (the sorted units with their phy curation and unit notes, run files, logs, the sorter's copy of the recording) and `<Name>.bin` + `.json`. A sorted-output folder chosen by hand (Sorting tab, **Use folder...**) was not written by the step and is kept |
| Signals | the derived-signal `.mat` files (`<Name>_extract*.mat`) |
| Spikes | the spikes `.mat` (`<Name>_spikes.mat`) |
| Behavior | `<Name>_behavior.mat` and the digital events cache `<Name>_events.mat` |
| Artifacts | the artifact-interval cache `<Name>_artifacts.json` |
| Export | the Chronux, FieldTrip and epochs `.mat` files and the kCSD `.npz` |

A `.mat` output is recognised by the variables it holds (as `DatasetOutputs`
does), so outputs with a configured suffix count too, and the config's
Signals, Spikes and Export output folders are searched for the datasets'
outputs. Unfinished outputs that a failed write left (`~<name>.partial.mat`)
go with their step. The probe step writes no file. What the dataset manifest
records (probe, exclusions, manual artifact periods, trial pairing) is not a
file and stays.

**Always kept**: the outputs of the steps not ticked, the dataset manifest,
the copy record (`session_manifest.json`, the robocopy log), the Epsych2
session file, the clean-up record, the files another recording wrote into a
shared output folder (a `.mat` whose provenance names another dataset or
recording folder, see [DatasetOutputs](DatasetOutputs.md#discovery); the
`.bin` and the `kilosort4` folder when the `.bin`'s sidecar names another
recording folder) and any other file. Nothing on the source is touched.

**Removed files go**, a choice that applies to the preview as it is
(changing it keeps the preview):

| Choice | What happens |
| --- | --- |
| Delete permanently (default) | deleted for good: the space is free at once |
| Move to the Recycle Bin | each file goes to the Recycle Bin of its drive, from where it can be restored; the space is freed only when the bin is emptied. Windows keeps a file there only on a local fixed drive whose bin is not set to remove files at once, and only when the file fits the bin's **Maximum size** (the bin's Properties; by default about 5% of the drive); otherwise it would delete the file for good without asking, so such a file is **skipped** instead. Afterwards each file is looked up in the bin, and one not found there is reported. Windows only |
| Move to a folder | each file goes to `<folder>\<dataset key>\<its path in the dataset's recording or output folder>`, so a dataset keeps its layout (the `kilosort4` folder included). **If a file is already there** decides what happens when that place already holds a file (below). Between drives a file is copied, the copy's size checked, and only then the local file deleted. The folder may not be inside the project or output root, where a scan would find the files again |

For a move, the preview checks the folder: the files already there are
listed in an extra **In the folder** column (with the size and date of the
file there) and counted in the line above the table. **If a file is already
there** says what the move does with them:

| Choice | What happens |
| --- | --- |
| Skip it (it stays here) (default) | the file is not moved: it stays where it is, and the one in the folder is left as it is |
| Overwrite the one there | the file replaces the one in the folder. The one there is first renamed aside and deleted only once the new one is in place; if the move fails it is put back. A folder of the file's name is never replaced: that file is skipped |
| Keep both: new version folder | every file of that dataset goes to a new folder `<folder>\<dataset key>_v2` (or `_v3`, ..., the first that does not exist) instead, keeping its path, so a set of files such as a `kilosort4` folder stays whole and nothing in the folder is touched. Only the datasets with a file already there get a version folder; it depends on the files ticked, so unticking the files that are there sends the rest to `<dataset key>` again |

Of two files that would land on the same place only the first goes. The
folder is checked when you press **Preview**, change the method, the folder
or this choice, and again just before the confirmation; the move itself
checks it once more as it starts (`cleanupMoveTargets`).

- **Preview** lists every file in the datasets' recording, output and sorting
  folders, one row each: **Include** (ticked: the file goes; every Remove row
  starts ticked, and Keep rows cannot be ticked), **Action** (Remove / Keep),
  Dataset, Subject (its `SubjectID` from the
  [name pattern](#name-pattern-and-token-columns)), What, Size (MB),
  File and **Why** (for a raw file, where its source copy is, or why it is
  kept: not found at the source, a different size, no copy record; for a
  step's file, that the step's output is selected). Remove rows come first,
  largest first; ticked ones are tinted red and unticked ones grey, and raw
  files that are kept are tinted amber. For a move, the **In the folder**
  column says what the folder holds at each file's place (*Already there
  (1.2 GB, 2026-10-01 14:03)*, or a folder of that name) and what the move
  would do: *skipped, it stays here*, *overwritten*, or *this one goes to the
  new version folder `<dataset key>_v2`*; the other files of a dataset that
  gets a version folder say *Goes to the new version folder ...*. The ticked
  files that would not simply land in their place are tinted lavender. A
  click on a header sorts the rows instead, and that sort is kept for every
  preview and the next session; right-click → **Clear sort** returns to this
  order ([Sorted tables](#sorted-tables)). Each row is mapped to its file
  in the plan, so a tick reaches its own file in any order. The
  line above the table totals both sides: *Would remove N file(s), X GB,
  from K of M dataset(s). N file(s), Y GB, remain.*, and adds how many
  removable files are unticked, how many datasets keep their raw
  recording (see **Why**) and, for a move, how many of the files are
  already in the folder and what happens to them (or *None of them is in
  the folder yet*). Previewing reads file listings, the
  outputs' variable names and the sources' sizes only.
- The filters change only what the table shows; a hidden row keeps its tick.
  **Search (regexp)** shows the files whose full path matches a regular
  expression, ignoring case (`\.rhd$`, `kilosort4`, `260914`; the field
  turns red when nothing matches), **Subject ID** one subject's files, and
  **Show the files that remain** hides or shows the Keep rows. **All
  visible** ticks every Remove row shown, **None visible** unticks every row
  shown, **Only visible** ticks every Remove row shown and unticks every
  hidden one (what you see is what goes), and **Invert visible** flips the
  ticks of the Remove rows shown. The line beside them counts the rows:
  `Showing 40 of 271 file(s); 38 ticked.` To remove one day's raw
  recordings, say: search for the date, press **Only visible**, then the
  button below.
- **Delete files...** / **Recycle files...** / **Move files...** (the button
  follows the choice) acts on the ticked Remove rows of the preview, after a
  confirmation that says how the files go (for a move, after checking the
  folder again: how many are already there and what happens to them), lists what goes by kind or step
  with its size and what remains, says how many of them are ticked but
  hidden by the filters, and warns when phy curation or unit notes go with a sorting
  (curation only when phy wrote the labels: a `cluster_group.tsv` with the
  header `cluster_id<TAB>group`, not Kilosort4's copy of its own) and, when
  raw files are among them, that those datasets cannot be run,
  viewed or scanned until they are copied back. Changing a tick box or the
  dataset selection discards the preview, so the button waits for a new
  Preview. It refuses while the pipeline, a copy or a Kilosort4 run is under
  way. A progress dialog follows the files; its **Cancel** leaves the files
  not yet handled in place.
- Each file is checked again just before it is removed: it must still have
  the size the preview saw, and a raw file's source must still have it too; a
  file that fails is **skipped** and left in place.
- Folders that the removal leaves empty go too, up to the dataset's recording
  or output folder, so removing the Sorting step's output leaves no
  `kilosort4` folder behind.
- Each dataset that had files removed gets `<Folder>/<Name>_cleanup.json`
  (see [Files on disk](file-formats.md#clean-up-record)): what was removed,
  how, where it went and, for raw files, where to copy them back from. The
  log under the table lists each file handled. The datasets' manifests are
  rewritten (they record the sorting and `.bin` on disk), the Datasets table
  and the Review tab follow, and the preview is made again.
- After raw files are removed, **Scan** the project again: those datasets are
  no longer recordings and drop out of it. Their outputs are unaffected, so
  the Review tab, the analysis app and anything else that reads the output
  files keep working. To bring a recording back, copy it again on the
  [Copy](#copy) tab: with **If it exists** = `resume` only the missing files
  are copied.

The tick boxes, **Removed files go** with its folder and **If a file is
already there**, and Show the files that remain are preferences.

---

## Synthetic test project

**File → Create synthetic test project...** writes a project that exercises
every step without real data or Python, then opens its config and scans it.
It asks for a parent folder (the project goes into a `synthetic_ephys`
subfolder there; an existing one is replaced only after confirmation, and
only when this tool wrote it), a size: **Standard** (30 kHz, 16 channels,
12 trials per session, about 250 MB) or **Small** (20 kHz, 8 channels, 6
trials, about 40 MB), and a recording format: **Intan RHX**, or an Open Ephys
GUI session in the **Binary**, **Open Ephys** or **NWB** format (session
folders `SYNTH-01_<yyyy-MM-dd>_<HH-mm-ss>` holding `Record Node 101`, channels
`CH1..`, TTL lines named by the config's `Signals.LineNames`). The same thing
from the command line:

```matlab
S = makeSyntheticProject("D:\scratch\synthetic_ephys");          % Preset="small" for the small one
app.createSyntheticProject("D:\scratch\synthetic_ephys");        % write, open the config and scan, in an app
```

What is written ([`makeSyntheticProject`](../pipeline/makeSyntheticProject.m),
one recording per scenario with
[`makeSyntheticRecording`](../pipeline/makeSyntheticRecording.m)):

| Item | Contents |
| --- | --- |
| recordings `SYNTH-01/SYNTH-01_<yymmdd>_<HHMMSS>/` | Intan RHX-style `*.rhd` files (30 s each) on consecutive days: LFP rhythms with a depth profile, noise, 60 Hz, a stimulus-evoked potential, spiking units with waveforms spread over neighbouring sites, two artifacts (one saturating the ADC); the lab's six digital lines `Trough`, `Platform`, `Stim`, `InTrial`, `RespWindow`, `Commutator`; three accelerometer inputs at Fs/4 |
| Epsych2 session `SYNTH-01_<yymmdd>T<HHMMSS>.mat` | in the recording folder, starting 65 s before the recording as in the lab: `Data` (one trial per `InTrial` interval, with `TrialType`, `Depth`, `StimDelay`, `RespCode`, `RespLatency`, `TrialIndex`, `computerTimestamp`, ...) and `Info` |
| `kilosort4/` | the ground-truth units as Kilosort4 / phy files (plus a noise cluster), where a sorting run would put them, so Export (units), the Review tab and the analysis of sorted units work without a sorting run |
| `<Name>_manifest.json` | the session and the probe already associated |
| `SYNTH-01_probe.json`, `synthetic_pipeline.json`, `README.txt` | a probe map for the channel count; a config with behavior (matching + pairing), artifacts, signals (LFP, MUA, AUX), spikes (threshold detection, with waveforms) and export (Chronux + FieldTrip, with the units and the detections) enabled, outputs next to each recording, sorting off; what each dataset should show |

The four recordings differ in how they cover their session, so the
**Trials** tab has one case of each kind to review:

| Dataset | Scenario | Trials vs `InTrial` intervals | Resolution on the Trials tab |
| --- | --- | --- | --- |
| 1 | `clean` | equal | approve as is (Auto approve does it) |
| 2 | `late-start` | the recording started 1.2 s into trial 3: trials 1-2 have no interval, interval 1 is partial (begins at sample 1) | cut 3 trials and 1 interval from the start (cutting 2 trials pairs trial 3 with the partial interval) |
| 3 | `early-stop` | the recording stopped in the middle of trial N-2: the last interval is partial, trials N-1 and N have none | cut 3 trials and 1 interval from the end |
| 4 | `spurious` | a 40 ms `InTrial` pulse before the first trial | cut 1 interval from the start |

`makeSyntheticProject` also takes `Scenarios`, `Format`
(`"one-file-per-signal"`, `"binary"`, `"openephys-binary"`,
`"openephys-legacy"`, `"openephys-nwb"`, `"tdt"`: TDT Synapse blocks
`<Subject>-<yyMMdd>-<HHmmss>` at 24414.0625 Hz, or 12207.03125 Hz for the small
preset, the lines as epoc stores `PC0_`, `PC1_`, ... named by
`Signals.LineNames`, no AUX; function only, not offered by the app's menu), `Parts` (Open Ephys: recordings per
session, each boundary in an inter-trial interval), `Fs`, `NumChannels`, `NumTrials`,
`FileSeconds`, `Seed`, `InvertedLines` (lines written active-low), `SortedOutput`,
`Artifacts` and `Overwrite`; its result holds the truth of every dataset
(events, trials, units, artifacts, the expected cuts).

<!-- wiki: Using synthetic data from scripts and in tests: [Synthetic test data](Synthetic-Test-Data). -->

## Reporting an issue

**Help → Report an issue on GitHub...** and **Help → Request a feature on
GitHub...** compose a GitHub issue from the session you are in. Both open the
same dialog: a title, a box for what happened (or what you would like the app
to do), tick boxes for what to send with it, and a preview of the whole report
exactly as it will be sent.

| Ticked | What it sends |
| --- | --- |
| System info | MATLAB release and platform, OS, compute threads, memory, GPUs, the Python interpreter (`pyenv` and the Sorting tab's), the installed toolboxes, the version of the code with its git commit, branch and whether it has uncommitted changes, and the repository folder |
| Pipeline options | the working config as the controls hold it now (name, file, unsaved edits, enabled steps, roots, dataset counts, active dataset, selected tab, whether a run is going) and the whole config as JSON, written the way **Save config** writes it — **this carries your file paths** |
| Logs and last error | the last 60 lines of the Run, Kilosort and Copy logs, each saying how many lines it had, and the error the last run stopped on with its stack |

A bug report starts with all three ticked and a feature request with only the
system info; untick anything you would rather not send. Nothing leaves the app
until you press a button:

- **Open on GitHub** puts the whole report on the clipboard and opens the
  repository's new-issue form with the title, the report and the label (`bug`
  or `enhancement`) filled in. Nothing is filed until you submit it there, and
  you can edit it further on the page. A report longer than the address bar
  holds is cut at a line boundary and says so in the body: paste the whole of
  it from the clipboard. If no browser opens, an alert shows the address.
- **Copy report** puts the report on the clipboard and leaves the dialog open,
  for filing it somewhere else (email, an existing issue).

Scripted, `app.issueReport("bug")` returns the same report (name-value
`Description`, `System`, `Config`, `Logs`, `MaxLogLines`) and
`app.issueURL("bug", title, body)` the prefilled address.

The dialog, the address and the system lines are
[`IssueReport`](../pipeline/IssueReport.m), which the analysis app's Help menu
uses too ([Reporting an issue](EphysAnalysisApp.md#reporting-an-issue) there);
each app writes only its own report.

## Sorted tables

Five tables sort on a header click: the Project table, the Trials table, the
Review units table, the Clean up preview and the Artifacts tab's per-channel
Selection table. A uitable sorts only what it shows, and the app fills a table
again whenever its data changes (another dataset, a reload, an edit, a new
preview). So the app keeps the click itself, the column and the direction the
rows show ([`TableSort`](../pipeline/TableSort.m)), puts every new set of rows
in that order, and saves it as the `TableSorts` preference at once: the sort
holds for every dataset and the next session. Right-click a table for
**Clear sort**, which names the sort it clears and returns the rows to the
app's own order (the project's datasets, trial order, cluster id, Remove rows
first and largest first, the chosen method's statistic). A column the rows
do not have (a trial parameter another session lacks) leaves them in that
order, and the sort applies again where the column is.

The rows are sorted by that column alone, ties in the app's order. Numbers,
dates and categories sort by value and text ignoring case; empty cells, NaN
and missing values go last in either direction. Until the next refresh the
rows are in the uitable's own sort, which may order missing values or
mixed-case text differently. Every row keeps its link to its data in any order:
datasets through their index, units through the cluster id, files through
the plan row, trials and the flag colours through the trial number.

## Preferences

Stored under the group `'EphysPipelineApp'` through [`AppPrefs`](../pipeline/AppPrefs.m), which keeps
them as MATLAB preferences unless the environment variable `EPHYS_APP_PREFS_FILE` names a file (the test
suites and screenshot scripts use a temporary one, so they never change yours). Only what is **not** part
of a config lives here:

| Key | Contents |
| --- | --- |
| `FigurePosition` | window position/size (clamped to the screen on restore) |
| `ProbeFolder`, `PhyCmd`, `ReviewFolder`, `ScriptFolder` | paths |
| `PythonExe` | the Python exe last set on the Sorting tab, which a new config starts with |
| `LastConfigFile`, `RecentConfigs` | reopened on launch; the File → Open recent list |
| `DatasetsColumnOrder` | the Project table's column order (table variable names) |
| `TableSorts` | the sort of each [sorted table](#sorted-tables): one field per table (`Datasets`, `Trials`, `Review`, `Cleanup`, `ArtSelection`), each the column last clicked (a table variable name; the header for the Review and Clean up tables) and its direction (`ascend` / `descend`) |
| `TrialsParamColumns`, `TrialsColumnOrder` | the trial parameters shown in the Trials table, and its column order (table variable names; a parameter column is `Param_<name>`) |
| `TrialsLabelParams` | the trial parameters written as trial labels in the Trials plot |
| `VizOptions` | the Visualize tab's display settings |
| `ArtifactViewOptions` | the Artifacts tab's viewer options: Context, Channels, Scale (and Lanes when Manual), Colour by shank, Shade artifacts. The detection settings and the reference are the config's; Order by probe and Shank follow the dataset's probe |
| `CopyOptions` | the Copy tab's subject, roots, pairing and copy options (not the dates) |
| `SynthOptions` | the Synthetic tab's settings and its design (as `SyntheticDesign` JSON in `design`) |
| `DiagramView`, `DiagramLayout` | the Diagram tab's **View** (`detail` \| `overview`) and **Layout** (`tree` \| `steps`) |
| `QueueSortingRuns` | the Run tab's **Queue the waiting runs; the Run goes on** switch |
| `KeptSortingQueue` | the sorting queues kept at Close (**Keep the queue for next time**), one element per project root: `root`, `saved` (when), `runs` (`Name`, `key`: the dataset's folder relative to the root, `prepared`: the run `launchSorting` starts). Offered back, then removed, once that root is scanned ([Run](#run)) |
| `KeptSortingRuns` | the background Kilosort4 runs going at Close (`EphysPipeline.emptyRuns` shape), followed again, then removed, at the next launch |
| `CleanupOptions` | the Clean up tab's kinds of file and steps to remove, **Removed files go** and its folder, and **Show the files that remain** |

To reset: `AppPrefs.rmpref('EphysPipelineApp')` with the app closed. Older
preference groups are not read. The [scheduled copy](#scheduled-copy) is not a
preference: its settings live in its own file, which its Windows task reads.

## What the app writes to disk

| File | When |
| --- | --- |
| pipeline config `.json` | File → Save / Save as / Export copy (default folder `pipeline/pipeline_configs`) |
| generated `.m` script | File → Generate script |
| `<project root>/pipeline_<config name>.m` | each run with **Save the pipeline script on each run** ticked (not a dry run) |
| `<output root, else project root>/pipeline_runs/<runId>_<config name>.json` | each run (not a dry run): its run record |
| `<Folder>/<Name>_manifest.json` | scan, probe assignment, exclusion change, manual artifact edit, sorting / behavior association, **Approve pairing** / **Mark unreviewed** (and an automatic approval), each sorting launch and completion |
| Open Ephys part folders (`openephys-part.json`) inside a session folder | a scan with **one dataset per recording** |
| `<outputFolder>/<Name>_events.mat` | Trials **Load** or **Prefetch ticked** (a cache of the digital lines) |
| `<outputFolder>/<Name>_behavior.mat` | the behavior step, or Trials **Write behavior .mat** |
| `<outputFolder>/<Name>.bin` (or `<Name>_ks4.bin`; in `Sorting.BinDir` instead of the output folder when that is set) + `.json`, `<outputFolder>/kilosort4/{settings.json, run_ks4.py, ks4_launch.cmd, ks4_run.log, ks4_status.json, ks4_exit.txt}` and the phy files (plus `<probe>_excluded.json` with excluded channels, `<probe>_spaced.json` with `shank_spacing`, and `previous_<yyyyMMdd_HHmmss>/` holding an earlier sort's curation) | Sorting (a dry run writes only `settings.json` and `run_ks4.py`, into `kilosort4/dryrun/`) |
| `<outputFolder>/<Name>_artifacts.json` | Artifacts (cache) |
| `<outputFolder>/<Name>_envelope_<what>.dat` (a `.partial` file while it is built) | Visualize, in the background, the first time it shows a signal: the min / max that wide views and the overview strip draw ([format](file-formats.md#signal-envelope-name_envelope_whatdat)) |
| `<Name>_extract_<TYPE>.mat` (or `<Name>_extract.mat`), `<Name>_spikes.mat`, `<Name>_chronux.mat`, `<Name>_fieldtrip.mat`, `<Name>_epochs.mat`, `<Name>_kcsd.npz`, `<Name>.nwb` (+ `<Name>_nwbinspector.json`) | Signals, Spikes, Export |
| the analysis config's figure files (by default `<outputFolder>/analysis/<Name>_<Plot>.png` / `.svg`), its report (by default `<output root, else project root>/analysis/analysis_report.html`) and `<report folder>/analysis_runs/<runId>_<name>.json` | Analysis (a dry run writes nothing) |
| `cluster_notes.tsv`, `quality_metrics.json`, `quality_report.html` in the sorted-output folder | a Review **Notes** edit; loading a sort on the Review tab (the metrics' cache); Review **QC report** |
| probe `.json` in the probe folder | Import, Designer save, Notes edit |
| `<probe>.ks4.json` next to a probe map | **Optimize for probe**, when it generates the file |
| a diagram `.html` | Diagram **Save as HTML...**; **Open in Browser** writes one to a temporary file |
| `<parent>/synthetic_ephys/...` | File → Create synthetic test project (recordings, sessions, sorted output, probe, config, README) |
| `<Folder>/<Subject>/<Subject>_<start>/`: the recording, the session copy, `kilosort4/` (ground truth), `<Name>_manifest.json`, `<Name>_synthetic.json` and, with a synthetic probe, `<Name>_probe.json`; a design `.json` | Synthetic → Generate... (Preview writes nothing); Save design... |
| `<Destination>/<SUBJ>/<recording folder>/`: the copied files (for a stitched session, `<earliest ePsych file>_stitched.mat` instead of the ePsych files), `session_manifest.json`, `session_copy_robocopy.log` | Copy → Copy selected, in the background (Preview writes nothing); each scheduled run |
| `%LOCALAPPDATA%\ephys_analysis\copy_jobs\<batch>\`: the copy engine's job, progress and heartbeat files | while a copy batch is in flight; removed when it ends |
| `%LOCALAPPDATA%\ephys_analysis\copy_schedule\`: `schedule.json`, `task.xml`, `startup.m`; the Windows task `\ephys_analysis\Copy sessions (<user>)` | Copy → Save schedule (Remove deletes the task and the first two) |
| the same folder: `copy_schedule.log` (appended; the previous 5 MB in `copy_schedule.1.log`), `last_run.json`, `matlab.log` | each scheduled run |
| `<Folder>/<Name>_cleanup.json`; **deletes**, recycles or moves (to `<folder>\<dataset key>\...`) the files the Clean up preview marks Remove | Clean up → Delete / Recycle / Move files..., after its confirmation |

A dataset's output folder (`<outputFolder>`) is `<Output root>/<Name>` when an
output root is set, else the recording folder (`<Folder>`). Raw recording
files are only read, except that Clean up removes local copies whose source
still holds them. The source tree is only read.

## Scripting against a running app

```matlab
app = EphysPipelineApp;
% ... scan in the GUI ...
cfg = app.Config;                 % the working EphysPipelineConfig
P   = app.Project;                % EphysProject
ds  = P.Datasets(1);              % EphysDataset (probe, exclusions, manual artifacts, SortingDir, BehaviorFile)
app.openConfigFile("D:\EPHYS\pipeline.json");
app.onScan();                     % same as the Scan button
app.selectDataset(2);             % make dataset 2 the active dataset
app.runPipeline(Steps="spikes");  % same as Run this step
app.KSRuns                        % background runs being monitored
app.KSQueue                       % prepared runs waiting for a slot (Queue the waiting runs)
```

## Source map

| File | Role |
| --- | --- |
| `EphysPipelineApp.m` | properties, constructor, method declarations |
| `buildUI.m`, `buildMenus.m`, `buildToolbar.m`, `build*Tab.m` | UI construction (`buildToolbar`: the toolbar, its icons in `pipeline/icons/toolbar`) |
| `gatherConfig.m`, `applyConfig.m`, `gather*/apply*Section.m`, `gather/applyConvertConfig.m`, `gather/applySortingSection.m`, `setControlValue.m`, `onConfigChanged.m`, `syncStepEnableStates.m`, `updateTitle.m` | config model (`setControlValue`: a config value into a control, noting one it cannot show; numbers in text fields are written with `EphysPipelineConfig.numberText`) |
| `onNewConfig.m`, `onOpenConfig.m`, `openConfigFile.m`, `onSaveConfig.m`, `onSaveConfigAs.m`, `onExportConfigCopy.m`, `onGenerateScript.m`, `onCreateSyntheticProject.m`, `createSyntheticProject.m`, `onOpenAnalysisApp.m`, `onCopyForAnalysis.m`; `pipeline/AnalysisCopyDialog.m`, `confirmDiscard.m`, `addRecentConfig.m`, `refreshRecentMenu.m` | File menu |
| `buildPipeline.m`, `runPipeline.m`, `onRunStep.m`, `onCancelRun.m`, `onValidate.m`, `onPlan.m`, `refreshStepPlan.m`, `onPipelineProgress.m`, `runLog.m`, `setRunBar.m`, `showIssues.m`, `onParallelControlsChanged.m`, `projectAtRoot.m`, `refuseWhileRunning.m` | running (`projectAtRoot`: whether the scanned project is the config's; `refuseWhileRunning`: the alert that refuses a dataset edit during a run) |
| `resetRunDiagram.m`, `updateRunDiagram.m`, `finishRunDiagram.m`, `refreshRunDiagram.m`, `runDiagramHTML.m` | the Run tab's diagram of the run: its model (start, progress events, end), what is sent to the page, the page |
| `startResourceMonitor.m`, `stopResourceMonitor.m`, `pollResourceMonitor.m`, `showResourceSample.m`, [`resource_monitor.ps1`](../pipeline/resource_monitor.ps1) | the Run tab's resource monitoring: launching and stopping the sampler, the timer reading it, the display |
| `buildTrialsTab.m`, `onTrialsLoad.m`, `repairTrials.m`, `refreshTrialsView.m`, `refreshTrialsTable.m`, `refreshTrialsPlot.m`, `trialsColumnOrder.m`, `onTrialsTableMenu.m`, `onTrialsPlotMenu.m`, `onTrialsCutsChanged.m`, `syncTrialsCuts.m`, `onTrialsApprove.m`, `onTrialsPrefetch.m`, `onTrialsWriteBehavior.m`, `onTrialsToWorkspace.m`, `onTrialsSettingsChanged.m`, `clearTrialsView.m`, `fillTrialsLines.m`, `setTrialsLineItems.m`, `syncTrialsButtons.m` | Trials tab |
| `onScan.m`, `refreshDatasetsTable.m`, `onDatasetCellSelection.m`, `onSelectDatasets.m`, `onRefreshMetadata.m`, `onAssociateBehavior.m`, `onClearBehavior.m`, `onBrowseBehaviorDir.m`, `saveManifests.m` | Project tab (`saveManifests`: the manifests after a per-dataset edit, with an alert for one that could not be written) |
| `selectDataset.m`, `currentDataset.m`, `populateDatasetPickers.m`, `refreshDatasetMenu.m`, `refreshDatasetPickers.m`, `datasetPicker.m`, `highlightDatasetRow.m` | the active dataset: Dataset menu, every tab's Dataset box, the highlighted table row |
| `onViewManifest.m`; `pipeline/ManifestViewerApp.m` | Dataset menu → View manifest... and the viewer it opens |
| `toolTargets.m`, `syncToolsPanel.m`, `onOpenTool.m`, `onOpenOutputFolder.m` | the Project tab's Tools panel: which datasets it opens, its label and buttons, the dispatch to `onViewManifest` / `onOpenAnalysisApp` / `onLaunchPhy`, the output folders |
| `refreshProbeList.m`, `onProbeSelected.m`, `onImportProbe.m`, `onDesignProbe.m`, `runProbeTool.m`, `onAssignProbe.m`, `onApplyExclude.m`, `onUseSelectedProbeAsDefault.m`, `probe_tool.py` | Probe tab |
| `onDetectArtifacts.m`, `showArtifactView.m`, `drawArtifactView.m`, `onArtViewInput.m`, `syncArtProbeControls.m`, `refreshArtChannelTable.m`, `refreshManualArtifactsTable.m`, `onClearManualArtifacts.m`, `private/artifactColors.m` | Artifacts tab: the detector's preview and the viewer, where detected artifacts are reviewed and manual periods marked (`onArtViewInput`); the orange / purple of the two kinds, shared with Visualize (`artifactColors`) |
| `routeFigureInput.m` | shares the figure's wheel, key and button callbacks between the Artifacts tab's plot and the Visualize viewer |
| `onOptimizeKS4ForProbe.m`, `onResetKS4Params.m`, `onUseSortingFolder.m`, `onUseAutoSorting.m`, `refreshSortingLabel.m`, `pollKSRuns.m`, `onLaunchPhy.m`, `launchPhy.m` | Sorting tab and phy |
| `queueKSRun.m`, `onStopKSQueue.m`, `onStopKSRuns.m`, `stopKSRuns.m`, `markKSResult.m` | background sorting runs: the queue the monitor starts from, Stop queue, Stop runs..., restating a run's result row |
| `keepKSRuns.m`, `followKeptKSRuns.m`, `offerKeptKSQueue.m`, `restoreKSQueue.m`, `private/keptSortingQueue.m`, `private/keptSortingRuns.m` | the background runs kept at Close: storing them, following the runs going again at launch, offering a kept queue back after its root's scan and putting it back in the queue (or dropping it), reading the two preferences |
| `onSpikesPreview.m`, `syncSpikesEnableStates.m` | Spikes tab |
| `onBrowseExportOutput.m`, `onExportEpochsToWorkspace.m` | Export tab (output folder, Epochs to workspace) |
| `buildAnalysisTab.m`, `gatherAnalysisSection.m`, `applyAnalysisSection.m`, `onAnalysisControlsChanged.m`, `onBrowseAnalysisConfig.m`, `onOpenAnalysisConfig.m`, `refreshAnalysisSummary.m`, `onOpenAnalysisOutput.m` | Analysis tab (the analysis config, its summary, Open in the analysis app, Open report / figures folder) |
| `onPlotVisualization.m`, `applyVizSettings.m`, `onVizControlsChanged.m`, `onVizViewChanged.m`, `onVizInput.m`, `onVizButtonDown/Up.m`, `refreshVizShading.m`, `vizDetectedIntervals.m`, `updateVizArtStatus.m`, `syncVizDataset.m`, `loadVizEvents.m`, `onVizReadEvents.m`, `showVizHelp.m`; `pipeline/EphysTraceViewer.m`, `pipeline/EphysTraceSource.m`, `pipeline/EphysTraceEnvelope.m` | Visualize tab: loading the active dataset's signals and spikes, the controls, the wheel / keys / drags, the shading (`vizDetectedIntervals`: the Artifacts preview's intervals the plot shades, or why none; `updateVizArtStatus`: their counts, and whether the last run's match the current settings); the digital-input events and Read events; the "?" window of mouse and key controls; the viewer, the windowed sources behind it and their envelopes (min / max cached on disk, built in the background) |
| `buildFlowTab.m`, `refreshFlowChart.m`, `flowChartHTML.m`, `flowOverviewHTML.m`, `onFlowViewChanged.m`, `onFlowLayoutChanged.m`, `onSaveFlowChart.m`, `onOpenFlowChartInBrowser.m`, `onFlowNavigate.m`, `flowNavControls.m`, `clearFlowHighlight.m` | Diagram tab: the page in the view picked, drawn by [`PipelineDiagram`](../pipeline/@PipelineDiagram/PipelineDiagram.m), a plain class the app calls (`detail`: every parameter; `overview`: the data flow, laid out and routed there; `zoomFrame`: the zoom and pan, kept per view by the app), save / open, a box's click |
| `buildCopyTab.m`, `onCopyFind.m`, `onCopyRun.m`, `refreshCopyTable.m`, `onCopyTableEdited.m`, `onCopyStitch.m`, `onCopyUnstitch.m`, `onBrowseCopyFolder.m`, `copyLog.m`, `onCopyCancel.m`, `startCopyMonitor.m`, `stopCopyMonitor.m`, `pollCopyJob.m`, `setCopyRunning.m`, `applyCopyResult.m`, `finishCopyRun.m`, `showCopyProgress.m`, `copySummaryText.m`, `refreshCopySchedule.m`, `onCopyScheduleSave.m`, `onCopyScheduleRemove.m`, `onCopyScheduleRunNow.m`, `onCopyScheduleLog.m`; `pipeline/findCopySessions.m`, `pipeline/stitchCopySessions.m`, `pipeline/copySessions.m`, `pipeline/copy_engine.ps1`, `pipeline/stitchEpsychSessions.m`, `pipeline/CopySchedule.m` | Copy tab, the pairing / stitching / copy functions it calls, the detached copy engine, and the scheduled copy (its Windows task and what each run does) |
| `loadReviewResults.m`, `renderReviewPlots.m`, `syncReviewDataset.m`, `showReviewSorts.m`, `onReviewSortChanged.m`, `onReviewUseSort.m`, `private/reviewSorts.m`, `private/sorterOfSort.m`, `showReviewUnits.m` | Review tab (`reviewSorts`: the active dataset's sorts and the one to show; `showReviewSorts`: the Sort list and whether Use this sort is on; `onReviewUseSort`: the sort shown made the dataset's own; `showReviewUnits`: the units table in its sort, the selected unit's row kept) |
| `buildSyntheticTab.m`, `onSynthLoadSource.m`, `onSynthPreview.m`, `renderSynthPreview.m`, `onSynthGenerate.m`, `generateSynthetic.m`, `onSynthDesign.m`, `onSynthControlsChanged.m`, `onSynthSourceChanged.m`, `syncSynthControls.m`, `gather/applySynthDesign.m`, `synthColumns.m`, `synthSourceLists.m`, `synthSourceKey.m`, `synthGeneratorArgs.m`, `synthOutputRoot.m`, `synthOutputFolder.m`; `pipeline/SyntheticDesign.m`, `pipeline/syntheticModel.m`, `pipeline/syntheticTaskSchedule.m`, `pipeline/syntheticSessionSchedule.m`, `pipeline/makeSyntheticRecording.m` | Synthetic tab (`generateSynthetic`: Generate without its questions; `synthGeneratorArgs`: the options Preview and Generate share) and the generator |
| `buildCleanupTab.m`, `onCleanupPreview.m`, `onCleanupRun.m`, `runCleanup.m`, `onCleanupMethodChanged.m`, `onCleanupBrowseDest.m`, `onCleanupSettingsChanged.m`, `refreshCleanupScope.m`, `refreshCleanupTable.m`, `refreshCleanupMove.m`, `private/cleanupMoveSentence.m`; `pipeline/planLocalCleanup.m`, `pipeline/cleanupMoveTargets.m`, `pipeline/runLocalCleanup.m` | Clean up tab and the functions that decide and remove |
| `load/savePreferences.m` | preferences |
| `tableSort.m`, `onTableSorted.m`, `onTableSortMenu.m`, `clearTableSort.m`, `private/sortMenuItem.m`, `private/sortableTable.m`, `private/saveTableSorts.m`; `pipeline/TableSort.m` | [sorted tables](#sorted-tables): a header click remembered and saved, applied whenever a table is filled, Clear sort |
| `stopTimers.m` | stops the app's timers (Kilosort4, copy and resource monitors, the scheduled copy's refresh) on close, and when the figure is deleted any other way |
| `helpURL.m`, `onHelp.m` | Help menu (wiki pages) |
| `onReportIssue.m`, `issueReport.m`, `issueURL.m`; `pipeline/IssueReport.m` | Help menu (GitHub issue / feature request; the dialog, address and system lines are shared with EphysAnalysisApp) |
| `pipeline/showAbout.m`, `pipeline/ephysVersion.m` | Help menu (About; shared with EphysAnalysisApp). The release number is the repository's `VERSION` file, which `ephysVersion` reads |

## Tests

[`test_EphysPipelineApp.m`](../pipeline/test_EphysPipelineApp.m) builds
the app headlessly over a synthetic project: config → controls → config round
trip, the unsaved marker, the Diagram of the loaded config and its refresh on edits, that every box in a
chart of all the steps points at controls that exist and that clicking one opens its tab and marks
them, the data-flow overview (its boxes and arrows, that no arrow runs through a box or shares a line
with another source's and at most five cross, the reads a config leaves off, the arrows into a disabled
step, the View preference and Layout turned off), the Run checklist ↔ tab sync and its Parallel controls, scan + selection ticks (the Sorting tab's phy lamp, its green **Open in phy (curated)** and the table's `modified in phy` for a phy-curated sort)
(and the ticked datasets in the Dataset menu),
the active dataset's highlight under the token filters, the Source settings panel (the active dataset's system: Intan's
note, the Open Ephys and TDT options saved and pushed to the datasets, a TDT gain that is not a number refused, a TDT
block's stream list and status, an integer stream asking for a gain), plan, the Sorting tab's Optimize for probe (each answer to the offer to generate a
missing parameter file, including a probe map without positions, loading the
file, the default-probe fallback, the Probe tab's listing and info) and Reset to defaults, one step through the pipeline,
the run diagram (always shown, its quarter of the right side, the last run, a run's steps and percentages
event by event, a cancel, the preview that follows the checklist),
resource monitoring (the panel always shown, a sample's figures and colours, n/a readings, the sampler starting when the Run tab is shown, live samples from it, the sampler
exiting and removing its folder when stopped), the Clean up tab's preview (every file listed, a raw
recording without a copy record kept, nothing deleted, the Keep rows hidden on request, a changed tick box discarding it,
a Visualize envelope going by default and staying unticked, the Sorting step's box marking its whole folder), a move into the project refused, a move out of it (layout, record, preview again) and the preferences,
the Analysis tab (an analysis config's summary and plots, the Run checklist box, its plan with and without the
report, the Diagram naming the config, a missing config shown in red and stopping the plan),
save / reopen and the recent list,
the Help menu's wiki pages and its issue items (what a bug report and a
feature request carry, that an unticked section is left out, the percent-encoded
address with its label, and that a report too long for the address is cut and
says so), a config with values its fields cannot show (listed, the config
marked unsaved), a Kilosort4 field that does not parse (the value in force
kept and reported, Save refused), numbers written in full, a new Method's own
default threshold, the filter settings without a control kept, the Behavior
column's session summaries read once, channel lists that do not parse
changing nothing, a dataset without a probe laid out on the default probe,
firing rates over the sorted time, a config for another root and a rescan
(the active dataset and a Visualize plot followed by their folder; the
Visualize tab loading the active dataset when it opens, a multi-file recording
drawn across its files with the spike at its bin's first sample and, zoomed in,
at its own sample, the arrow keys, wheel and Page button acting only with the
pointer over the plot, the orange overlay from the Artifacts preview only while
its settings hold), a hand-picked sorted-output folder that is not there
(`missing`, and the Review tab says so), the default probe in the Project
table, edits, scans and per-dataset changes during a run, an unreadable
manifest reported after a scan, a Plan while a background run is going, the
results table filling as a Run goes (a row at the next progress event, the
table left alone when no row was added, a row the monitor restates at once), the
queue (each dataset once; a plan skips a queued one), the runs kept at Close
(the queue under its project root, another root's left alone; the runs going
followed again by the next window, one with no process left out; which kept
runs can go back in the queue and why not; queued again with the scanned
dataset; an alert when none can), phy started in a folder
whose path holds `&` and spaces, the timers stopped when the figure is
deleted, and the [sorted tables](#sorted-tables) (a kept sort applied to the
Project, Review and Clean up tables, with row clicks, notes, ticks and the
highlight still reaching their dataset, unit or file; a header click
remembered and saved at once; Clear sort; a new window recalling a sort). It
keeps the app's preferences in a temporary file
([`AppPrefs`](../pipeline/AppPrefs.m)), so the user's own are never read or
changed.

The same suite covers the rest of the app too: the tab strip and the Diagram's
viewport and zoom; probe rules, the name tokens' columns and filters, a
recursive scan, **Dataset → View manifest** and the Tools panel (manifest
viewer, analysis app, phy); the Artifacts tab (a preview's detections and
what a run removes for each use and erase setting, a stale preview, Ctrl+drag
moving an artifact's bounds into the manifest and Restore bounds, the keys
that step through the artifacts, the shading, Context, Channels and Lanes,
the probe order, shanks and colours, the voltage and time keys and wheel,
Reset view, Go to (s), marking manual periods on the plot, Clear and
Measure); the Trials tab (Load, the cut spinners, the table's parameter
columns and their order, Approve, the line polarity, the onset / offset
lines, grid and trial labels, renamed lines and the label field, the
workspace and **Write behavior .mat** items, Prefetch and Auto approve); Map
channels; the run saving the pipeline script and the issue report's Run log;
the Review tab (unit labels, location and Notes, the quality metrics, QC
column, criteria and report, the shank, ISI and autocorrelogram plots, the
waveform overlay, the template without the sorted `.bin`; the Sort list:
the dataset's own sort and every other, a SpikeInterface sort, a browsed
folder, a pinned folder that is not there; Use this sort pinning a sort,
or going back to auto for the config sorter's run folder); background
Kilosort4 runs N at a time (the slot wait, the monitor streaming each run's
log), the GPUs field, the queue, Stop queue and Stop runs; the Clean up tab's
search, Subject ID list and tick buttons; and the Visualize tab's "?" window,
Read events, the event markers and TTL rows, the event box's next-onset arrow,
the last run's detected periods shaded, and Mark manual periods.

[`test_SyntheticGenerator.m`](../pipeline/test_SyntheticGenerator.m) checks the
generator behind the Synthetic tab, then drives the tab headlessly: the built-in
design with an added unit and oscillation, Preview (every plot drawn, the Unit
and LFP boxes), Generate writing exactly the previewed spikes and refusing an
existing folder, a dataset source (its rate, channels, subject and own probe
taken over), a dataset written under the project root scanned in and made
active, the rebuilt lines filled in and editable, and the preferences.

[`test_CopySessions.m`](../pipeline/test_CopySessions.m) (a `matlab.unittest`
class; `run_all_tests` runs it too) builds fake source trees in a temporary
folder. It checks pairing (a single session, interleaved sessions resolved
one-to-one, unpaired files on either side, exact and near ties, clock skew
and the lead limit, midnight, durations and trial counts from the headers, a
recording shorter than the minimum, similar subject IDs, subject patterns and
every subject, malformed names, Open Ephys sessions under a second root, TDT
blocks, and the errors for a missing root, a bad date and a bad pattern) and
stitching (`stitchCopySessions` joining rows in time order and refusing bad
rows). It checks copying: a dry run writes nothing; a hash-verified copy
writes its manifest; an Open Ephys session is copied whole; an existing
destination is skipped, reported as an error or already present; a partial
copy is completed by `resume` (the short file finished, the missing one
copied, the rest left alone); a copy stopped part way (its full size, the
wrong time) is completed, never taken as present; a truncated copy fails; a
same-size corruption fails the SHA-256 checksum; robocopy ended from outside
fails the session; a heartbeat that looks stale after the computer slept is
not a dead engine; the free-space check counts only what is left to copy;
one missing source does not stop the batch; unpaired rows copy only on
request; Cancel works, also during the checksum pass. A stitched session is
copied as one `<first>_stitched.mat` (verified, rebuilt by `resume` after its
source changed), files that cannot be stitched fail in the preview, and a
session folder never gets a second behavior file. Manifests are written for
sessions found complete and kept for finished copies. It checks the
background form too: `Background=true` returns before the copy is done,
polling the job carries it through to `copied`, options passed with a job
are refused, and every `ProgressFcn` call carries the fraction, a message and
the `info` behind it (phase, session, sessions, bytes) with a fraction that
never steps back. It also drives the Copy tab from Find through a background
copy to the finished table, Stitch and Unstitch, and the recent-folder
lists. It checks that a session whose source changed within the quiet time
(a file, or a folder a file was taken out of) is left for later, and that
one another batch is writing is left alone until that batch has gone quiet,
also while a background batch of its own is in flight. For the scheduled
copy it checks what a run copies (the paired sessions of the days searched,
subjects whose folders appear later included; never ambiguous, unpaired or
to-be-stitched ones; nothing until the source is quiet), what it leaves as it
is (a hand-stitched copy; a session missing files removed since it was
copied, while an unfinished copy is completed), a recording copied alone
gaining its ePsych file once it pairs, what stops a run (no destination, no
source), the log, `last_run.json` and exit code of `CopySchedule.runTask`,
the settings checks, the task definition and UNC paths. It creates a real
task, has Windows run it (MATLAB, started in the background, copies the
session and reports) and removes it, and saves and removes a schedule from
the Copy tab. Copy tests need Windows (robocopy, Task Scheduler).

[`test_LocalCleanup.m`](../pipeline/test_LocalCleanup.m) (a `matlab.unittest`
class) copies a synthetic recording into a session folder as the Copy tab
would and checks what `planLocalCleanup` removes and keeps (planning changes
nothing; a raw file whose source is missing or a different size stays, as
does a recording without a copy record, the data file of a binary-format
recording, which is raw and not `.bin` output, and what another recording
with the same name wrote into the shared output folder; an Open Ephys
session's files below its Record Node; an empty plan when there is nothing
to clean), that the Remove option limits the kinds, what each step's removal
takes (the whole `kilosort4` folder and the `.bin` with its sidecar; outputs
found by their variables, with configured suffixes, in a search folder but
not another dataset's, a kCSD `.npz` by its meta member, and unfinished
ones; a hand-picked sorted-output folder kept), and that `runLocalCleanup`
removes only the Remove rows, leaves the source alone, skips files that
changed since the preview, removes emptied folders, moves files into a folder
keeping their layout without overwriting, refuses a destination inside a
dataset, a relative one or none, stops on cancel, sends files to the Recycle
Bin and finds them there (then empties its own items from the bin), and
writes and appends to the clean-up record.

[`test_SyntheticDataset.m`](../pipeline/test_SyntheticDataset.m) checks the
synthetic project generators and, headlessly, the File-menu action: the
project is written, opened and scanned; choosing the active dataset in a
tab's Dataset box, the Dataset menu (a ticked dataset or one under All
datasets) or the Project table updates all of them; the Dataset menu and
every tab's Dataset box list only the ticked rows; a new active dataset
clears the previous one's pairing and previews, flags a Visualize plot of the
previous dataset (and, with the tab open, loads the new one at once; opening
it loads the recording with its sorted units drawn) and loads the Review tab;
the Spikes preview runs; the Trials tab pairs the clean dataset, warns about
the late-start one, resolves it with the expected cuts and records them on
Approve; and a non-empty folder is refused unless `Overwrite` is passed.

[`test_EphysTraceViewer.m`](../pipeline/test_EphysTraceViewer.m) checks the
Visualize tab's viewer without the app, on a small universal-format recording
with a `.bin`, a `-v7.3` LFP extract (columns reordered) and a `-v7` MUA
extract: which sources a dataset has and that each reads exactly the rows
asked for (the `.bin` through its scale, its min / max on the stored integers,
HDF5 windows, a loaded `-v7` signal, the recording channel of each column);
samples at (row − 1)/Fs and a binned spike at its bin's first sample; a zoom in
drawn from memory, a pan inside the margin moving only the limits; the voltage
scale, auto scale, lanes, heatmap and shading; sorted units and detected spikes
as ticks, as the recoloured trace and as stored waveforms on their own lanes,
spikes only, the read limit, the wheel, keys, drags and the overview; the
events: onset and offset lines over the traces (an onset on its own sample,
offsets dotted), a TTL row per line above them, and `jumpToEvent` stepping
from onset to onset; and the
envelope: block sizes, one cache file per signal, every level's min / max equal
to those of the full-rate samples block by block, a `.bin` written again never
shown from its old envelope and built again, builds on a thread, on a timer and
cancelled, a removed cache file noticed (as after Clean up), a whole-recording view drawn from it without a full-rate read (with
the recording's file moved away), the overview's signal, and a display filter
keeping the view within one read.
