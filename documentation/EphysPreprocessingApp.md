# EphysPreprocessingApp

`EphysPreprocessingApp` ([source](../intan/@EphysPreprocessingApp/EphysPreprocessingApp.m)) is
a programmatic `uifigure` GUI (a `handle` class, not an App Designer `.mlapp`)
for the preprocessing pipeline. It edits **one pipeline config**
([`EphysPipelineConfig`](EphysPipeline.md)) and runs it with
[`EphysPipeline`](EphysPipeline.md#ephyspipeline) over an
[`EphysProject`](EphysProject.md). It is used to:

- scan a folder tree for recordings (Intan, or the universal binary format);
- assign probe maps and channel exclusions;
- mark manual artifact periods and configure automatic detection;
- run SpikeInterface + Kilosort4 (optional) and associate sorted output;
- derive LFP / MUA / spike-band `.mat` files;
- detect spikes by threshold and/or collect sorted units into a `.mat`;
- export Chronux- and FieldTrip-shaped files;
- associate Epsych2 behavior sessions;
- review sorted units and open them in phy;
- save the config, and generate scripts that reproduce the run.

Reading, filtering, sorting, conversion and export all happen in
[`EphysDataset`](EphysDataset.md) and `EphysPipeline`; the app edits the
config, chooses datasets, shows progress, and keeps the per-dataset
associations in each dataset's manifest. Anything the app runs can be run
without it from the saved config.

Installation (MATLAB, conda environments, GPU) is covered in
[INSTALL.md](../intan/INSTALL.md).

## Launching

```matlab
EphysPreprocessingApp            % open the window
app = EphysPreprocessingApp;     % open and keep a handle (app.Config, app.Project, ...)
```

The constructor builds the UI, restores preferences, opens the last config
file if it still exists (else starts from defaults, "Untitled"), and lists the
probe folder. Closing the window asks to save an unsaved config, stops the
background monitor and saves preferences.

## Window layout

- **Menu bar**
  - **File**: New config, Open config..., Open recent, Save config (Ctrl+S),
    Save config as..., Export copy of config..., Generate script (Compact |
    Standalone), Close.
  - **Dataset**: one checkable item per scanned dataset. This picks the single
    dataset the **Visualize** tab plots and the **Spikes** preview uses.
  - **Run**: Validate config, Plan, Run pipeline (Ctrl+R), Dry run, Cancel.
- **Title**: the config name and file; `*` in front while the config has
  unsaved changes.
- **Tabs**, in workflow order: **Project, Probe, Artifacts, Sorting, Signals,
  Spikes, Export, Run, Visualize, Review**. A step tab's title reads
  `Sorting [off]` while that step is disabled.
- **Status bar** (bottom): the last action on the left, a suggested next step
  on the right.

### The config model

Every control on the Project through Export tabs is bound to a section of
`app.Config`. Editing a control re-gathers the config
(`gatherConfig`), pushes the new settings into the scanned datasets, syncs the
enable states (tab titles and the Run tab's checklist) and updates the
unsaved marker. **Open** / **New** push a config into the controls
(`applyConfig`). Each step has an **Enabled** box on its own tab; the Run
tab's checklist shows the same boxes.

Text fields that hold lists (channels, notch frequencies, KS4 vectors) are
kept as typed; they are parsed when a run starts, and a run reports the first
field it cannot parse.

### Which dataset does an action act on?

| Action | Target |
| --- | --- |
| Probe: Exclude channels; Sorting: Use folder / Use auto / Open in phy; Project: Associate file / Clear; Artifacts: manual periods table | the row **last clicked** in the Project table |
| Visualize: Plot; Spikes: Preview | the dataset checked in the **Dataset menu** (clicking a Project row also checks it) |
| Artifacts: Detect / Preview | the Artifacts tab's own **Dataset** dropdown |
| Run pipeline, Run this step, Plan, Signals / Export target tables | the rows **ticked** in the Project table (`Project.Selection = "list"`), or **all** datasets when none are ticked (`"all"`) |
| Probe: Assign to selected datasets | the rows **ticked** in the Project table, or the row **last clicked** when none are ticked |
| Probe: Assign to all datasets | every dataset |

## Typical workflow

1. **File → New** (or open a saved config). Name it on the Project tab.
2. **Project**: set the project root, press **Scan**; set an output root.
3. **Probe**: pick a probe map, **Assign to all datasets** or set it as the
   config's default probe. Enter per-recording **Exclude channels**.
4. **Artifacts** (optional): tune and preview the detector; mark manual
   periods on **Visualize**.
5. Enable the steps you want on their tabs (**Sorting**, **Signals**,
   **Spikes**, **Export**) and set their options. Each tab has **Run this
   step** for a single step over the selected datasets.
6. **Run**: **Validate**, **Plan**, then **Run** (or **Dry run**).
7. **File → Save config**, and **Generate script** if you want a script that
   reproduces the run.
8. **Review**: inspect sorted units, or open them in phy.

---

## Project

| Control | Meaning |
| --- | --- |
| Config name, Description | `cfg.Name`, `cfg.Description` |
| Project root + Browse... + **Scan** | `Project.Root`. Scan builds `EphysProject(root)` (every folder that a registered reader claims: Intan `*.rhd` / `info.rhd`, or `recording.json`), then `P.refresh()`: header metadata, `applyManifest` (probe, exclusions, manual periods, sorting and behavior associations), `writeManifest`. A progress dialog with Cancel; datasets whose headers fail keep `NaN` metadata and a warning is printed |
| Refresh metadata | re-parse all headers |
| Output root + Browse... | `Project.OutputRoot`: each dataset writes to `<root>/<Name>`; blank = next to the recording |
| All / None | tick / untick every row |
| Open in phy | the last-clicked dataset's associated sorted output (enabled only when it has `params.py`) |

Table columns: **Select**, Name, **Key** (root-relative, what the config
stores), Acq date, # chan, Fs (Hz), Duration (min), Format, Probe, Exclude,
**Sorting** (units, `curated` when phy labels exist, `auto` / `manual`),
**Behavior** (subject and trial count). Ticks are written to
`Project.Datasets` as keys; with no ticks `Project.Selection` is `"all"`.

**Behavior (Epsych2)** panel: **Match sessions as a pipeline step**
(`Behavior.Enabled`), search folders + **Add folder...**, match rule (`prefix,
then time` / `prefix only` / `time only`) and max start offset
(`Behavior.*`), **Find sessions for selected** (what `findEpsychSessions` sees
and what `matchEpsychSession` would pick for the last-clicked dataset),
**Re-match existing** (`Behavior.Overwrite`), **Associate file...** (pick a
session `.mat` for the last-clicked dataset by hand) and **Clear**. Associations are
written to the manifest. Nothing is plotted here; the session's trials are
carried into the Signals, Spikes and Export outputs as `behavior`.

## Probe

Probe maps are Kilosort4 probe `.json` files
([format](file-formats.md#kilosort4-probe-json)). The default folder is
[`intan/probes`](../intan/probes/README.md).

- **Probe folder** + **Browse...** + **Refresh** list every `*.json` in the
  folder (not recursive). The **probe table** shows Probe, Ch, Shanks, Depth
  (µm) and Notes; the Notes cell is editable and written back into the file.
- **Probe info** shows the file, `n_chan`, `chanMap` length, shank count, and a
  channel-count check (`OK` / `MISMATCH`) against the last-clicked dataset.
- The **preview plot** shows sites by shank; excluded sites are gray `x`.
  **Show channel numbers** labels each site with its 1-based channel.
- **Design probe from probeinterface...** opens
  [`ProbeDesignerApp`](ProbeDesignerApp.md); **Import probe .json into
  folder...**; **Edit probe .json...**.
- **Exclude channels** (1-based, `1,5,32-40`) applies to the last-clicked
  dataset and is written to its manifest. How exclusions reach each step:
  [EphysDataset → Channel exclusions](EphysDataset.md#channel-exclusions) for
  sorting; `Signals.ExcludeHandling` for derived signals;
  `Spikes.Channels = "excludeManifest"` for detection.
- **Assign to selected datasets** (ticked rows) / **Assign to all datasets** set `ProbeFile`
  (and, for all, the Exclude field) and write the manifests.
- **Default probe** (`Probe.DefaultProbeFile`) + **Use selected**: the probe
  the `probe` preflight assigns to datasets that have none; **Write default to
  manifest** persists that assignment.

## Artifacts

The automatic detector
([`EphysDataset.detectArtifacts`](EphysDataset.md#artifact-detection-and-blanking))
and the manual periods.

| Control | Maps to |
| --- | --- |
| **Enabled** | `Artifacts.Enabled`: run automatic detection (manual periods always apply) |
| Dataset | which dataset **Detect / Preview** analyzes |
| Method, Threshold, RMS window, Stitch gap, Pad, Min channels | `Artifacts.Method`, `Threshold`, `RmsWindowMs`, `MergeGapMs`, `PadMs`, `MinChannels` |
| Filter before detecting, High-pass (Hz) | `Artifacts.Filter`, `FilterCutoff` (with `FilterType`, `FilterOrder`). These now apply to runs as well as the preview |
| Apply to sorting / Apply to spike detection | `Artifacts.ApplyToSorting`, `ApplyToSpikes` |
| Cache intervals | `Artifacts.CacheIntervals` (`<Name>_artifacts.json`) |
| **Detect / Preview** | `analyzeArtifacts` over the chosen dataset (streamed, read-only): summary + per-channel table |
| Manual periods table, **Edit in Visualize**, **Clear** | the last-clicked dataset's `ManualArtifacts` (written to its manifest) |

The Threshold field is sent as-is for every method: with *Absolute microvolts*
/ *Common-mode* the default 9 means 9 µV.

## Sorting

SpikeInterface + Kilosort4, optional (`Sorting.Enabled`).

| Control | Maps to |
| --- | --- |
| Enable the Sorting step, Skip datasets already sorted | `Sorting.Enabled`, `SkipExisting` |
| Python exe (+ Browse), Conda env | `Sorting.PythonExe` (seeded from a `kilosort` conda env under `%LOCALAPPDATA%` / `%USERPROFILE%` when a new config is created), `CondaEnv` |
| Phy command | preference `PhyCmd` (blank = `conda run -n phy phy`) |
| Execution (background / blocking), Dry run | `Sorting.Execution`, `DryRun` |
| Bandpass filter, Common reference, Detect bad channels (+ method, action) | `Sorting.SI` ([defaults](EphysDataset.md#default-spikeinterface-configuration)) |
| Kilosort4 parameters (five groups, from `EphysPipelineConfig.kilosortParamSpec`), Extra settings (JSON) | `Sorting.KS4`, `KS4ExtraJSON`. Control kinds: int / float / bool as typed; `nullable` blank = omitted; `floatinf` blank / `inf` = omitted; `vector` = comma- or space-separated |
| **Results** panel: label, **Use folder...**, **Use auto**, **Open in phy** | the last-clicked dataset's sorted-output association (`SortingDir`, manifest `sorting`). *auto* probes `kilosort4/si/sorter_output`; *manual* is a folder you chose (anywhere) |
| **Run this step** | `EphysPipeline.runSorting` over the selected datasets |
| progress label + log | background runs (`ks4_run.log` tail, `ks4_status.json`), see below |

Background runs are handed to a MATLAB `timer` (every 3 s): it appends new log
lines, logs `[done]` / `[error]`, rewrites the dataset's manifest and refreshes
the table. The timer stops when every tracked run has a status file. Closing
the app stops the timer but not Python processes already running. With
automatic artifact detection on, each dataset's scan runs **in MATLAB,
synchronously**, before Python is launched (and is cached afterwards).

## Signals

Derived LFP / MUA / SPIKE `.mat` files with `EphysDataset.toMat`
([intan2matlab](intan2matlab.md)), `Signals.*`.

- **Output**: folder (blank = the dataset's output folder), suffix
  (`_extract`), MAT version, overwrite, **Include behavior**.
- **Signals**: LFP (`LFP_Fs`, high-pass, low-pass, notch + width), MUA
  (`MUA_Fs`, integration, band), SPIKE (keep original rate / `SPIKE_Fs`, band).
- **Channels**: label field, keep channels, bad channels (none / manual list /
  auto + threshold), channel remap, **Manifest exclusions** (`none` / `drop` /
  `interpolate`). Lists keep order and repeats; anything unparseable is an
  error. **Reset to defaults**.
- The **targets table** is `plan(Steps="signals")` for the selected datasets
  (`ready`, `exists: skip`, `exists: overwrite`, `no recording files`, ...);
  **Refresh** re-plans. **Run this step** runs `EphysPipeline.runSignals`.

## Spikes

Spike events per dataset with `EphysDataset.spikesToMat`, `Spikes.*`.

- **Source**: threshold detection, sorted units, or both.
- **Filter** (band, order), **Threshold** (method, value, polarity, max
  amplitude), **Events** (align, window, min period), **Waveforms** (on/off,
  window, source, edge handling), **Channels & artifacts** (all / manifest
  exclusions / list; reject events inside artifact periods), **Performance**
  (chunk cap, edge pad, parallel), **Sorted units** (groups, include noise,
  templates), **Output** (folder, suffix `_spikes`, MAT version, overwrite).
- **Preview**: detects on the first *n* seconds of the Dataset-menu dataset
  with the tab's settings and lists per-channel thresholds, counts and rates.
- **Run this step** runs `EphysPipeline.runSpikeDetection`.

## Export

Files for external toolboxes, `Export.*`. Nothing about spectra, tapers or
Chronux functions appears here: the app only writes files.

- **Chronux** (`<Name>_chronux.mat`, [format](file-formats.md#chronux-export))
  and **FieldTrip** (`<Name>_fieldtrip.mat`,
  [FieldTripExport](FieldTripExport.md)).
- What to include: signals (blank = every signal in the extract), sorted
  units (+ groups), detected spikes, events, behavior; **Validate with
  FieldTrip** when it is on the path.
- Output folder, overwrite, MAT version; the targets table (`no extract file`
  when the Signals output is missing); **Run this step** runs
  `EphysPipeline.runExport`.

## Run

- **Steps** checklist: the Enabled boxes of every step (mirrored with the
  tabs), and the selection summary.
- **Validate config** fills the issues table (`cfg.validate()`); **Plan** fills
  the results table with `pipe.plan()` (writes nothing).
- **Run**, **Dry run**, **Cancel**: `EphysPipeline.run` with progress bars
  (overall and per step), the results table (`Step`, `Dataset`, `Status`,
  `Message`, `Output`, `Seconds`) and a timestamped log. Cancel takes effect at
  the next progress boundary; outputs are written atomically, so a cancelled
  dataset leaves no complete-looking file.
- Background Kilosort4 runs launched by a run are handed to the same monitor
  as the Sorting tab.

## Visualize

Display-only time-domain plots of the Dataset-menu dataset; the data on disk
is never modified.

| Control | Meaning |
| --- | --- |
| File | `(all)` or one recording file (multi-file recordings only) |
| Channels | e.g. `1:16` or `1 3 5` (1-based) |
| Start (s), Window (s) | initial view |
| High-pass / Low-pass (Hz), Filter order | blank = off; both set = bandpass (`filterContinuous`) |
| Reference, Detrend | None / common average / common median; subtract each chunk's mean |
| Plot type, Trace spacing, Heatmap colors | Traces / Heatmap |
| Sort channels by probe map, Color channels by shank | from the dataset's probe |

**Plot** streams the data one chunk at a time (detrend → re-reference →
filter per chunk) into a
[`MultiChannelViewer`](../vendor/plotting/@MultiChannelViewer/MultiChannelViewer.m)
cache with a memory budget (min(2 GB, ⅓ of available memory) on Windows,
1 GB elsewhere, never below 250 MB). Longer spans are **peak-decimated** on
load; the status line reports the factor.

**Artifact overlays**: orange = automatic detections computed with the
Artifacts settings on the **cached display data** (after display processing
and decimation, so they can differ from what a run silences); red = manual
periods. **Mark Artifacts** toggles marking mode (left-drag adds a period,
click inside a red region removes it); **Clear Artifacts** removes all. Manual
periods are written to the dataset's manifest, so they survive a rescan and a
restart.

When decimation is active, the trailing samples of each chunk that do not fill
a bin are dropped, so displayed time can lag true time by up to (factor − 1)
samples per chunk. Drawing uses `xregion` (MATLAB R2023a or later).

## Review

Summarizes a sorted-output folder (the folder holding `params.py`), read with
`EphysDataset.readSortedUnits`.

- **Dataset dropdown** lists the scanned datasets that have sorted output
  (their associated folder); **Browse...** / **Load** accept any results
  folder, a dataset folder or a `kilosort4` folder (searches
  `kilosort4/si/sorter_output`, `si/sorter_output`, `sorter_output`,
  `kilosort4`). **Open folder in explorer**, **Open in phy**.
- **Summary**: Fs, duration, channels, shanks, unit counts by label, total
  spikes, mean rate, units per shank.
- **Units table**: Unit, Label (phy's `cluster_group.tsv` when present, else
  `cluster_KSLabel.tsv`), Shank, PkCh, #Spk, FR (Hz), Amp, Cont%. Clicking a
  row focuses the plots; **Show all units** clears the focus.
- **Plots**: units per shank; waveforms (templates × median amplitude,
  unwhitened when possible, not raw-spike averages); amplitude vs time (at most
  30,000 spikes); firing rate per unit.

Firing rates are spike count ÷ the time of the **last spike**, not the
recording duration. `PkCh` is the peak channel among the sorted channels; the
units struct also carries `channel`, the 1-based recording channel.

---

## Preferences

Stored with `setpref` / `getpref` under the group `'EphysPreprocessingApp'`.
Only what is **not** part of a config lives here:

| Key | Contents |
| --- | --- |
| `FigurePosition` | window position/size (clamped to the screen on restore) |
| `ProbeFolder`, `PhyCmd`, `ReviewFolder`, `ScriptFolder` | paths |
| `LastConfigFile`, `RecentConfigs` | reopened on launch; the File → Open recent list |
| `VizOptions` | the Visualize tab's display settings |

To reset: `rmpref('EphysPreprocessingApp')` with the app closed. Older
preference groups are not read.

## What the app writes to disk

| File | When |
| --- | --- |
| pipeline config `.json` | File → Save / Save as / Export copy (default folder `intan/pipeline_configs`) |
| generated `.m` script | File → Generate script |
| `<Folder>/<Name>_manifest.json` | scan, probe assignment, exclusion change, manual artifact edit, sorting / behavior association, each sorting launch and completion |
| `<outputFolder>/kilosort4/{si_config.json, run_si_ks4.py, ks4_run.log, ks4_status.json}` and `kilosort4/si/...` | Sorting (dry run writes only the first two) |
| `<outputFolder>/<Name>_artifacts.json` | Artifacts (cache) |
| `<Name>_extract.mat`, `<Name>_spikes.mat`, `<Name>_chronux.mat`, `<Name>_fieldtrip.mat` | Signals, Spikes, Export |
| probe `.json` in the probe folder | Import, Designer save, Notes edit |

Raw recording files are only read.

## Scripting against a running app

```matlab
app = EphysPreprocessingApp;
% ... scan in the GUI ...
cfg = app.Config;                 % the working EphysPipelineConfig
P   = app.Project;                % EphysProject
ds  = P.Datasets(1);              % EphysDataset (probe, exclusions, manual artifacts, SortingDir, BehaviorFile)
app.openConfigFile("D:\EPHYS\pipeline.json");
app.runPipeline(Steps="spikes");  % same as Run this step
app.KSRuns                        % background runs being monitored
```

## Source map

| File | Role |
| --- | --- |
| `EphysPreprocessingApp.m` | properties, constructor, method declarations |
| `buildUI.m`, `buildMenus.m`, `build*Tab.m` | UI construction |
| `gatherConfig.m`, `applyConfig.m`, `gather*/apply*Section.m`, `gather/applyConvertConfig.m`, `gather/applySortingSection.m`, `onConfigChanged.m`, `syncStepEnableStates.m`, `updateTitle.m` | config model |
| `onNewConfig.m`, `onOpenConfig.m`, `openConfigFile.m`, `onSaveConfig.m`, `onSaveConfigAs.m`, `onExportConfigCopy.m`, `onGenerateScript.m`, `confirmDiscard.m`, `addRecentConfig.m`, `refreshRecentMenu.m` | File menu |
| `buildPipeline.m`, `runPipeline.m`, `onRunStep.m`, `onCancelRun.m`, `onValidate.m`, `onPlan.m`, `refreshStepPlan.m`, `onPipelineProgress.m`, `runLog.m`, `setRunBar.m`, `showIssues.m` | running |
| `onScan.m`, `refreshDatasetsTable.m`, `onDatasetCellSelection.m`, `onSelectDatasets.m`, `onRefreshMetadata.m`, `onAssociateBehavior.m`, `onClearBehavior.m`, `onBrowseBehaviorDir.m` | Project tab |
| `refreshProbeList.m`, `onProbeSelected.m`, `onImportProbe.m`, `onDesignProbe.m`, `runProbeTool.m`, `onAssignProbe.m`, `onApplyExclude.m`, `onUseSelectedProbeAsDefault.m`, `probe_tool.py` | Probe tab |
| `onDetectArtifacts.m`, `refreshManualArtifactsTable.m`, `onClearManualArtifacts.m` | Artifacts tab |
| `onUseSortingFolder.m`, `onUseAutoSorting.m`, `refreshSortingLabel.m`, `pollKSRuns.m`, `onLaunchPhy.m`, `launchPhy.m` | Sorting tab and phy |
| `onSpikesPreview.m`, `syncSpikesEnableStates.m` | Spikes tab |
| `onPlotVisualization.m`, `onVizButtonDown/Up.m`, `drawVizArtifacts.m`, `finishVizArtDrag.m`, `applyVizChannelOrder.m`, `applyVizChannelColor.m` | Visualize tab |
| `loadReviewResults.m`, `renderReviewPlots.m` | Review tab |
| `load/savePreferences.m` | preferences |

## Tests

[`test_EphysPreprocessingApp.m`](../intan/test_EphysPreprocessingApp.m) builds
the app headlessly over a synthetic project: config → controls → config round
trip, the unsaved marker, the Run checklist ↔ tab sync, scan + selection ticks,
plan, one step through the pipeline, save / reopen and the recent list. It
restores the user's preferences afterwards.
