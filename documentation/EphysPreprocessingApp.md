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
    Standalone), Create synthetic test project... (see
    [Synthetic test project](#synthetic-test-project)), Close.
  - **Dataset**: one checkable item per scanned dataset. This picks the single
    dataset the **Visualize** tab plots and the **Spikes** preview uses.
  - **Run**: Validate config, Plan, Run pipeline (Ctrl+R), Dry run, Cancel.
- **Title**: the config name and file; `*` in front while the config has
  unsaved changes.
- **Tabs**, in workflow order: **Project, Trials, Probe, Artifacts, Sorting,
  Signals, Spikes, Export, Run, Visualize, Review**. Each tab button is
  coloured by its status, and its tooltip says why: grey = step disabled,
  green = ready, amber = needs attention (config warnings, selected datasets
  without a probe, trial pairings not approved, no datasets scanned), red =
  config errors, blue = pipeline running, white = nothing to judge. A blue
  underline marks the open tab.
- **Status bar** (bottom): the last action on the left, a suggested next step
  on the right.

### The config model

Every control on the Project through Export tabs is bound to a section of
`app.Config`. Editing a control re-gathers the config
(`gatherConfig`), pushes the new settings into the scanned datasets, syncs the
enable states (tab strip colours and the Run tab's checklist) and updates the
unsaved marker. **Open** / **New** push a config into the controls
(`applyConfig`). Each step has an **Enabled** box on its own tab; the Run
tab's checklist shows the same boxes.

Text fields that hold lists (channels, notch frequencies, KS4 vectors) are
kept as typed; they are parsed when a run starts, and a run reports the first
field it cannot parse.

### Which dataset does an action act on?

| Action | Target |
| --- | --- |
| Probe: Exclude channels; Sorting: Use folder / Use auto / Open in phy, Optimize for probe (the default probe when that row has none); Project: Associate file / Clear; Artifacts: manual periods table | the row **last clicked** in the Project table |
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

No data at hand? **File → Create synthetic test project...** writes a
complete test project (recordings, Epsych2 sessions, sorted output, a
config) and opens it; see [Synthetic test project](#synthetic-test-project).

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
**Behavior** (subject, trial count and the recorded pairing status). Ticks are written to
`Project.Datasets` as keys; with no ticks `Project.Selection` is `"all"`.

**Behavior (Epsych2)** panel: **Match sessions as a pipeline step**
(`Behavior.Enabled`), search folders + **Add folder...**, match rule (`prefix,
then time` / `prefix only` / `time only`) and max start offset
(`Behavior.*`), **Find sessions for selected** (what `findEpsychSessions` sees
and what `matchEpsychSession` would pick for the last-clicked dataset),
**Re-match existing** (`Behavior.Overwrite`), **Write behavior .mat**
(`Behavior.WriteFile`), **Associate file...** (pick a
session `.mat` for the last-clicked dataset by hand) and **Clear**. Associations are
written to the manifest. Nothing is plotted here. When the behavior step runs
with **Write behavior .mat** on, each associated session is saved once as
`<Name>_behavior.mat` in the dataset's output folder; the Signals, Spikes and
Export outputs do not carry behavior data.

## Trials

Review how each Epsych2 trial is paired with the trial digital line (see
[pairing](EphysPipeline.md#pairing-trials-with-the-trial-line)).

| Control | What it does |
| --- | --- |
| Dataset + **Load** | reads the dataset's digital lines (`digitalEvents`: cached on disk after the first read, kept in memory while the tab shows this dataset) and pairs the trials in order, reusing the cuts recorded in the manifest when they still match |
| **Reset cuts** | drops the cuts (shown and recorded) and pairs every trial with every interval in order again |
| **Approve pairing** / **Mark unreviewed** | `setTrialPairing(P, "approved" / "unreviewed")`: saves the shown cuts in the manifest |
| **Write behavior .mat** | `behaviorToMat(Pairing=P)` now, without running the step |
| **Pair trials in the behavior step**, **Trial line** | `Behavior.PairTrials`, `Behavior.TrialLine` |
| Lines table (**Inverted**) | one row per digital line with its interval count; ticked lines are `Signals.InvertedLines`: on while low, onset = falling edge. This applies to the pairing and to the events the Signals step writes (and so to the exports) |
| **Resolve a count mismatch** | four spinners: Epsych2 trials and trial-line intervals to cut from the start and from the end before pairing. They belong to the dataset (its manifest), not to the config; cuts that would drop more than there is are refused |
| Trials table | trial, `TrialIndex`, interval, onset / offset (s), onset / offset sample, flag (orange = partial: the interval touches the recording start or end; grey = cut; red = unpaired), the other lines overlapping the trial |
| Plot | the digital lines over the recording, the trial line coloured by pairing state (paired, partial, cut, unpaired). Zoom and pan are horizontal only: the mouse wheel zooms time in and out about the cursor, dragging pans time |

The summary line says whether the pairing is approved, recorded but not
reviewed, or new, whether a recorded pairing went stale (the session, the
trial line, its polarity or its intervals changed: its cuts are dropped), and
warns when the numbers of trials and intervals differ. The Epsych2 timestamps
are not used: trial 1 is the first interval, and the only thing to check is
the count. A recording started after the session began has fewer intervals
(cut the first trials; a first interval that begins at the recording start is
the trial the recording started in), one stopped early has fewer intervals at
the end (cut the last trials), and an inverted line that was still at its
active level before Epsych2 started adds a partial first interval (cut it).
Changing a setting or a cut re-pairs at once. Setting a line's polarity back
brings the approved pairing back. Cuts are not saved until you press
**Approve** (or **Mark unreviewed**).

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
| **Optimize for probe** | sets the probe-dependent Kilosort4 parameters from a probe map ([rules](#optimize-for-probe)); a dialog lists what changed and the log gives the reason for every value |
| **Reset to defaults** | every `Sorting.KS4` parameter back to its `kilosortParamSpec` default and `KS4ExtraJSON` cleared; the Python, execution and SpikeInterface settings stay |
| **Results** panel: label, **Use folder...**, **Use auto**, **Open in phy** | the last-clicked dataset's sorted-output association (`SortingDir`, manifest `sorting`). *auto* probes `kilosort4/si/sorter_output`; *manual* is a folder you chose (anywhere) |
| **Run this step** | `EphysPipeline.runSorting` over the selected datasets |
| progress label + log | background runs (`ks4_run.log` tail, `ks4_status.json`), see below |

Background runs are handed to a MATLAB `timer` (every 3 s): it appends new log
lines, logs `[done]` / `[error]`, rewrites the dataset's manifest and refreshes
the table. The timer stops when every tracked run has a status file. Closing
the app stops the timer but not Python processes already running. With
automatic artifact detection on, each dataset's scan runs **in MATLAB,
synchronously**, before Python is launched (and is cached afterwards).

### Optimize for probe

**Optimize for probe** applies `EphysPipelineConfig.ks4ForProbe`, which sets
the Kilosort4 parameters that depend on the probe layout. It follows
Kilosort4's [parameter guide](https://kilosort.readthedocs.io/en/latest/parameters.html).
The probe is the last-clicked dataset's. When that dataset has no probe, or no
row is clicked, it is the config's default probe. The dataset's excluded
channels are left out first. Shanks are the probe's `kcoords` groups, because
Kilosort4 places templates per `kcoords` value. Every rule starts from the
`kilosortParamSpec` default, so the values depend only on the probe: pressing
the button again, or after tuning for another probe, gives the same result.

| Parameter | Rule |
| --- | --- |
| `nblocks` | `0` (no drift correction) with 64 sites or fewer, or rows 50 µm or more apart; `5` for a single shank spanning 2 mm or more (Neuropixels-like); otherwise `1` (rigid) |
| `dmin` | median spacing of the contact rows within a shank; blank (Kilosort's own estimate) when no shank has two rows |
| `dminx` | median lateral distance to the nearest contact in the same row, when at least half the contacts have one nearby; otherwise to the nearest contact in another column. Single-column shanks keep the default, which has no effect there |
| `nearest_chans` | the default, at most the number of sites |
| `nearest_templates` | the default, at most the number of sites when there are 64 or fewer |
| `min_template_size` | half the median distance to the nearest contact, never below the default |
| `x_centers` | one per shank, or one per 200 µm of a wider shank (2-D arrays) |

Every other parameter and the extra settings JSON are left alone. The dialog
warns when the extra JSON sets a tuned parameter (it overrides the tuned
value). It also warns when groups of columns 100 µm or more apart share one
`kcoords` value, which suggests a multi-shank map without per-shank `kcoords`.

## Signals

Derived LFP / MUA / SPIKE `.mat` files with `EphysDataset.toMat`
([intan2matlab](intan2matlab.md)), `Signals.*`.

- **Output**: folder (blank = the dataset's output folder), suffix
  (`_extract`), MAT version, overwrite, **one file per
  signal type** (on by default: `<Name>_extract_LFP.mat`, `_MUA.mat`,
  `_SPIKE.mat`; one plan / result row per file).
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
  units (+ groups), detected spikes, events; **Validate with
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

## Synthetic test project

**File → Create synthetic test project...** writes a project that exercises
every step without real data or Python, then opens its config and scans it.
It asks for a parent folder (the project goes into a `synthetic_ephys`
subfolder there; an existing one is replaced only after confirmation, and
only when this tool wrote it) and a size: **Standard** (30 kHz, 16 channels,
12 trials per session, about 250 MB) or **Small** (20 kHz, 8 channels, 6
trials, about 40 MB). The same thing from the command line:

```matlab
S = makeSyntheticProject("D:\scratch\synthetic_ephys");          % Preset="small" for the small one
app.createSyntheticProject("D:\scratch\synthetic_ephys");        % write, open the config and scan, in an app
```

What is written ([`makeSyntheticProject`](../intan/makeSyntheticProject.m),
one recording per scenario with
[`makeSyntheticRecording`](../intan/makeSyntheticRecording.m)):

| Item | Contents |
| --- | --- |
| recordings `SYNTH-01/SYNTH-01_<yymmdd>_<HHMMSS>/` | Intan RHX-style `*.rhd` files (30 s each) on consecutive days: LFP rhythms with a depth profile, noise, 60 Hz, a stimulus-evoked potential, spiking units with waveforms spread over neighbouring sites, two artifacts (one saturating the ADC); the lab's six digital lines `Trough`, `Platform`, `Stim`, `InTrial`, `RespWindow`, `Commutator`; three accelerometer inputs at Fs/4 |
| Epsych2 session `SYNTH-01_<yymmdd>T<HHMMSS>.mat` | in the recording folder, starting 65 s before the recording as in the lab: `Data` (one trial per `InTrial` interval, with `TrialType`, `Depth`, `StimDelay`, `RespCode`, `RespLatency`, `TrialIndex`, `computerTimestamp`, ...) and `Info` |
| `kilosort4/si/sorter_output/` | the ground-truth units as Kilosort4 / phy files (plus a noise cluster), where the SpikeInterface engine would put them, so the Spikes (sorted), Export (units) and Review steps work |
| `<Name>_manifest.json` | the session and the probe already associated |
| `SYNTH-01_probe.json`, `synthetic_pipeline.json`, `README.txt` | a probe map for the channel count; a config with behavior (matching + pairing), artifacts, signals (LFP, MUA, AUX), spikes (detected + sorted) and export (Chronux + FieldTrip) enabled, outputs next to each recording, sorting off; what each dataset should show |

The four recordings differ in how they cover their session, so the
**Trials** tab has one case of each kind to review:

| Dataset | Scenario | Trials vs `InTrial` intervals | Resolution on the Trials tab |
| --- | --- | --- | --- |
| 1 | `clean` | equal | approve as is |
| 2 | `late-start` | the recording started 1.2 s into trial 3: trials 1-2 have no interval, interval 1 is partial (begins at sample 1) | cut 3 trials and 1 interval from the start (cutting 2 trials pairs trial 3 with the partial interval) |
| 3 | `early-stop` | the recording stopped in the middle of trial N-2: the last interval is partial, trials N-1 and N have none | cut 3 trials and 1 interval from the end |
| 4 | `spurious` | a 40 ms `InTrial` pulse before the first trial | cut 1 interval from the start |

`makeSyntheticProject` also takes `Scenarios`, `Format`
(`"one-file-per-signal"`, `"binary"`), `Fs`, `NumChannels`, `NumTrials`,
`FileSeconds`, `Seed`, `InvertedLines` (lines written active-low), `SortedOutput`,
`Artifacts` and `Overwrite`; its result holds the truth of every dataset
(events, trials, units, artifacts, the expected cuts).

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
| `<Name>_extract_<TYPE>.mat` (or `<Name>_extract.mat`), `<Name>_spikes.mat`, `<Name>_chronux.mat`, `<Name>_fieldtrip.mat` | Signals, Spikes, Export |
| probe `.json` in the probe folder | Import, Designer save, Notes edit |
| `<parent>/synthetic_ephys/...` | File → Create synthetic test project (recordings, sessions, sorted output, probe, config, README) |

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
| `onNewConfig.m`, `onOpenConfig.m`, `openConfigFile.m`, `onSaveConfig.m`, `onSaveConfigAs.m`, `onExportConfigCopy.m`, `onGenerateScript.m`, `onCreateSyntheticProject.m`, `createSyntheticProject.m`, `confirmDiscard.m`, `addRecentConfig.m`, `refreshRecentMenu.m` | File menu |
| `buildPipeline.m`, `runPipeline.m`, `onRunStep.m`, `onCancelRun.m`, `onValidate.m`, `onPlan.m`, `refreshStepPlan.m`, `onPipelineProgress.m`, `runLog.m`, `setRunBar.m`, `showIssues.m` | running |
| `buildTrialsTab.m`, `onTrialsLoad.m`, `repairTrials.m`, `refreshTrialsView.m`, `onTrialsCutsChanged.m`, `syncTrialsCuts.m`, `onTrialsApprove.m`, `onTrialsWriteBehavior.m`, `onTrialsSettingsChanged.m`, `populateTrialsDatasets.m`, `clearTrialsView.m`, `currentTrialsDataset.m`, `fillTrialsLines.m`, `setTrialsLineItems.m`, `syncTrialsButtons.m` | Trials tab |
| `onScan.m`, `refreshDatasetsTable.m`, `onDatasetCellSelection.m`, `onSelectDatasets.m`, `onRefreshMetadata.m`, `onAssociateBehavior.m`, `onClearBehavior.m`, `onBrowseBehaviorDir.m` | Project tab |
| `refreshProbeList.m`, `onProbeSelected.m`, `onImportProbe.m`, `onDesignProbe.m`, `runProbeTool.m`, `onAssignProbe.m`, `onApplyExclude.m`, `onUseSelectedProbeAsDefault.m`, `probe_tool.py` | Probe tab |
| `onDetectArtifacts.m`, `refreshManualArtifactsTable.m`, `onClearManualArtifacts.m` | Artifacts tab |
| `onOptimizeKS4ForProbe.m`, `onResetKS4Params.m`, `onUseSortingFolder.m`, `onUseAutoSorting.m`, `refreshSortingLabel.m`, `pollKSRuns.m`, `onLaunchPhy.m`, `launchPhy.m` | Sorting tab and phy |
| `onSpikesPreview.m`, `syncSpikesEnableStates.m` | Spikes tab |
| `onPlotVisualization.m`, `onVizButtonDown/Up.m`, `drawVizArtifacts.m`, `finishVizArtDrag.m`, `applyVizChannelOrder.m`, `applyVizChannelColor.m` | Visualize tab |
| `loadReviewResults.m`, `renderReviewPlots.m` | Review tab |
| `load/savePreferences.m` | preferences |

## Tests

[`test_EphysPreprocessingApp.m`](../intan/test_EphysPreprocessingApp.m) builds
the app headlessly over a synthetic project: config → controls → config round
trip, the unsaved marker, the Run checklist ↔ tab sync, scan + selection ticks,
plan, the Sorting tab's Optimize for probe (dataset probe with exclusions,
default-probe fallback) and Reset to defaults, one step through the pipeline,
save / reopen and the recent list. It
restores the user's preferences afterwards.
[`test_SyntheticDataset.m`](../intan/test_SyntheticDataset.m) checks the
synthetic project generators and, headlessly, the File-menu action: the
project is written, opened and scanned, the Trials tab pairs the clean
dataset, warns about the late-start one and resolves it with the expected
cuts.
