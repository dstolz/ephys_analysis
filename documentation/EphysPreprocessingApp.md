# EphysPreprocessingApp

`EphysPreprocessingApp` ([source](../pipeline/@EphysPreprocessingApp/EphysPreprocessingApp.m)) is
a programmatic `uifigure` GUI (a `handle` class, not an App Designer `.mlapp`)
for the preprocessing pipeline. It edits **one pipeline config**
([`EphysPipelineConfig`](EphysPipeline.md)) and runs it with
[`EphysPipeline`](EphysPipeline.md#ephyspipeline) over an
[`EphysProject`](EphysProject.md). It is used to:

- pull a subject's sessions from the source (Intan recording + ePsych file,
  paired by name) into local session folders, verified;
- scan a folder tree for recordings (Intan, or the universal binary format);
- assign probe maps and channel exclusions;
- mark manual artifact periods and configure automatic detection;
- run SpikeInterface + Kilosort4 (optional) and associate sorted output;
- derive LFP / MUA / spike-band `.mat` files;
- detect spikes by threshold and/or collect sorted units into a `.mat`;
- export Chronux- and FieldTrip-shaped files;
- associate Epsych2 behavior sessions;
- review sorted units and open them in phy;
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
    [Synthetic test project](#synthetic-test-project)), Open analysis app...
    ([EphysAnalysisApp](EphysAnalysisApp.md) on this project), Close.
  - **Dataset**: one checkable item per scanned dataset; the checked one is
    the [active dataset](#which-dataset-does-an-action-act-on).
  - **Run**: Validate config, Plan, Run pipeline (Ctrl+R), Dry run, Cancel.
  - **Help**: opens the [GitHub wiki](https://github.com/dstolz/ephys_analysis/wiki)
    in the browser. Help for this tab (the page for the tab that is shown),
    Documentation home, Quick start, App overview, Output files,
    Troubleshooting and FAQ, Scripting guide, Pipeline configs, Developer
    reference. If no browser opens, an alert shows the address.
    Its last two items file against the
    [repository](https://github.com/dstolz/ephys_analysis/issues) instead:
    **Report an issue on GitHub...** and **Request a feature on GitHub...**
    (see [Reporting an issue](#reporting-an-issue)).
- **Title**: the config name and file; `*` in front while the config has
  unsaved changes.
- **Tabs**, in workflow order: **Copy, Project, Trials, Probe, Artifacts, Sorting,
  Signals, Spikes, Export, Diagram, Run, Visualize, Review, Clean up**. The app opens on
  Project. Each tab button is
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

There are two kinds of target. Batch work uses the **ticked** rows of the
Project table. Everything that works on one dataset uses the **active
dataset**. There is always exactly one active dataset once a project is
scanned (the first one after a scan, or the one that was active if it is
still there). You choose it in any of three places, and all of them always
show the same one:

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
the tab is open, else when you open it). A Visualize plot of the previous
dataset stays on screen, but the status line names the dataset it shows and
**Mark Artifacts** / **Clear Artifacts** are off until you press **Plot**.

| Action | Target |
| --- | --- |
| Trials: every control; Probe: Exclude channels, the channel-count check; Artifacts: Detect / Preview, manual periods table; Sorting: Use folder / Use auto / Open in phy, Optimize for probe (the default probe when the dataset has none); Spikes: Preview; Visualize: Plot; Review; Project: Associate file / Clear, Open in phy | the **active dataset** |
| Run pipeline, Run this step, Plan, Signals / Export target tables | the rows **ticked** in the Project table (`Project.Selection = "list"`), or **all** datasets when none are ticked (`"all"`) |
| Probe: Assign to selected datasets | the rows **ticked** in the Project table, or the **active dataset** when none are ticked |
| Probe: Assign to all datasets | every dataset |

## Typical workflow

0. **Copy** (when the recordings are still on the source): find the subject's
   sessions for the day, check the pairing, **Preview (dry run)**, then
   **Copy selected**. The copy runs in the background, so the rest of the app
   stays usable; the copied sessions open as the project when it finishes. If
   it is cancelled or interrupted, **Copy selected** again completes it. A
   [Scheduled copy](#scheduled-copy) does the copying by itself, at an
   interval, without MATLAB open.
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

## Copy

Copies recording sessions from the source to local session folders. Each session
is two separate artifacts, written by different software (possibly on
different PCs and clocks):

| Artifact | Source path |
| --- | --- |
| ePsych behavior file | `<ePsych root>/<SUBJ>/<SUBJ>_<yyMMdd>T<HHmmss>.mat` |
| Intan RHX recording folder | `<Intan root>/<SUBJ>/<SUBJ>_<yyMMdd>_<HHmmss>/` |

A session is copied to `<Destination>/<SUBJ>/<Intan folder name>/`: the Intan
folder's contents, the ePsych file under its original name,
`session_manifest.json` and `session_copy_robocopy.log`. Scanning the
destination as a project associates that ePsych file with the recording
(`associateFolderBehavior`), so the **Behavior** column is filled without
any behavior search folders. The tab only collects
settings and shows results. The pairing rules are in
[`findCopySessions`](../pipeline/findCopySessions.m) and the copy rules in
[`copySessions`](../pipeline/copySessions.m), which work the same from a
script:

```matlab
T = findCopySessions("SUBJ-ID-1255", "260916");                 % or [datetime datetime]
R = copySessions(T(T.Status == "paired", :));               % dry run (the default)
R = copySessions(T(T.Status == "paired", :), DryRun=false, Verify="hash");
T = stitchCopySessions(T, [2 3]);                               % one recording, two ePsych files

[R, job] = copySessions(T, DryRun=false, Background=true);   % returns at once
while ~job.Done
    [R, job] = copySessions(job);                           % poll; no waiting
end
```

| Control | Meaning |
| --- | --- |
| Subject ID, From, To | the subject (matched exactly: `SUBJ-ID-125` never matches `SUBJ-ID-1255_...`) and an inclusive range of days (To blank = one day) |
| ePsych root, Intan root, Destination | defaults `S:/RIG3_Backup_2025/epsych_files/Data`, `S:/RIG3_Backup_2025/intan_files/Data`, `D:/EPHYS` |
| Max lead (min), Max lag (min) | an ePsych file is a candidate for an Intan folder when it starts no more than *lead* before it (default 10) and no more than *lag* after it (default 2, for clock skew) |
| Ambiguity margin (s) | default 30; see below |
| Min duration (min) | default 2. An Intan recording shorter than this is never paired; see below. 0 pairs every recording |
| Find sessions | pair by name, using the **Duration** of each Intan recording (from its `.rhd` headers and `.dat` sizes) for the minimum; then read the **Trials** (elements of the ePsych file's `Data`) of the listed sessions. A header that cannot be read is logged and leaves the cell blank |
| Verify | checked once a session has been copied. `size`: every copy has its source's size; `hash`: also a SHA-256 checksum of the source and the copy (reads every file twice more, in the engine) |
| If it exists | a destination folder that exists, is not empty and does not match the source: `resume` (default) completes it, copying only the files that are missing or differ; `skip` leaves it alone; `error` reports it as `failed`. One that already matches is reported `already_present`. A file that is not in the source is never touched |
| Stitch selected rows | merges the selected rows (click, then Ctrl- or Shift-click) into one `stitched` session: they must hold exactly one Intan folder and at least two ePsych files. See [Stitching](#stitching-epsych-files) |
| Unstitch | puts the selected stitched rows back as Find sessions paired them |
| Preview (dry run) | reports what a copy would do, including a free-space check and how much of a partial copy is already there; writes nothing |
| Copy selected | copies the ticked rows **in the background**: the app stays usable, a progress panel opens above the table and the table's **Result** column tracks each row (see [Watching a copy](#watching-a-copy)). The button becomes **Cancel copy**, which stops after the file being copied (what has been copied is kept, and `resume` completes it later) |
| After copying, open the copied sessions as the project | sets the Project root to the folder holding the copied sessions, scans it and makes the first copied session the active dataset |

### Watching a copy

While a batch is in flight a progress panel sits between the options and the
table, and closes again when the batch is done:

| | |
|---|---|
| headline | what is being done to which session: `Copying session 2 of 4   SUBJ-ID-1255_260914_101756`, or `Verifying (SHA-256) ...` during the checksum pass and `Stitching ePsych files for ...` while a stitched row is written |
| bar + percentage | the whole batch, counting the checksum pass as the two extra reads it is (`Verify=hash` makes copying the first third of the work) |
| detail line | the bytes of the batch that have moved, then the file the engine is on: `4.9 GB of 11.2 GB   amplifier.dat` |
| rate + time left | measured from the bytes themselves over the last 15 s, and from the fraction and how long it has taken so far. Neither is shown until there is enough of the copy to measure |
| **Result** column | the session being copied shows its own percentage (`copying 42%`, `verifying 42%`), the sessions behind it in the batch show `waiting`, and each becomes `copied` / `already_present` / `failed` when the batch is verified |
| **Copy** tab button | goes blue (busy) for as long as a copy is running, so it is visible from whichever tab the app has moved on to |

The percentage moves inside a single large file, not just between sessions:
robocopy says nothing until it exits, so the engine sizes the session's
destination files about once a second while it runs, and reports how far each
SHA-256 has read. Closing the app stops the watching, not the copy
(see [`copySessions`](../pipeline/copySessions.m)).

**Pairing.** Names are parsed with strict, fully anchored patterns; any other
name in the two subject folders is skipped and listed in the log. Candidate
pairs are resolved one-to-one across all of them at once, nearest |Δt| first,
so a file never goes to whichever session happened to be listed first. If a
file has a second candidate whose |Δt| is within the ambiguity margin of the
best one, every file linked to it by a candidate pair is marked **ambiguous**
and none of them is paired. Rows spanning midnight appear under either day.
An Intan recording shorter than **Min duration** takes no part in the
pairing, so an aborted recording can neither claim the ePsych file nor make
the real recording ambiguous. It is listed as `intan_only` with the reason in
**Note**. A recording whose headers cannot be read has no known duration and
is paired as usual.

| Status | Row colour | Ticked after Find | Copied |
| --- | --- | --- | --- |
| `paired` | white | yes | yes |
| `stitched` | blue | yes, when stitched | yes, with its ePsych files stitched into one |
| `intan_only`, `epsych_only` | orange | no (tick by hand) | only when ticked |
| `ambiguous` | red | no; cannot be ticked | never: pair these files by hand, or stitch them |

**Copying.** Nothing in the source tree is modified, renamed, moved or deleted.
Before anything is copied, the free space under Destination is checked against
the total size, and the copy stops if there is too little.

The copying itself does not happen in MATLAB. `copySessions` plans the batch,
writes it as a job file and launches
[`copy_engine.ps1`](../pipeline/copy_engine.ps1) detached (Windows PowerShell
5.1, which ships with Windows), which runs
`robocopy <src> <dest> [files] /E /Z /MT:8 /R:3 /W:5 /NP /LOG+:<log>` **once
per source folder** rather than once per file — a folder of 200 files costs one
robocopy call instead of 200, which is worth seconds to minutes per session.
`/MIR`, `/MOV` and `/PURGE` are never used, so a file in the destination that is
not in the source is left alone; `/E` keeps empty source subfolders. Exit codes
8 and above are failures. The engine reports one JSON line per file, which the
app tails; MATLAB keeps the decisions (what may be copied, what counts as
verified, the ePsych stitching, the manifest).

Because the engine is a separate process, the copy is non-blocking: the app
polls it twice a second and everything else stays usable. A copy even survives
closing the app — it finishes on its own, and the app says so before it closes.

**Resuming.** `/Z` makes robocopy finish a partially transferred file instead of
starting again, and it skips a file that is already there with the same size and
timestamp. With `If it exists = resume` a destination that holds part of a
session is therefore completed rather than refused: the missing files are
copied, the short or mismatched ones finished, and the rest left untouched. This
is what makes a cancelled copy, a full disk or a dropped network share
recoverable — press **Copy selected** again. `skip` and `error` keep the old
behaviour and never write into such a folder.

**Verification.** A whole session is copied before any of it is checked, so a
session that fails verification keeps its complete partial copy and is marked
`failed`. MATLAB checks each destination file's size itself; with `hash` the
engine is then run a second time to take the SHA-256 of every source and
destination file. Each session is handled separately, so one failure does not
stop the others. `session_manifest.json` records the source and destination
paths, both times and Δt, the pairing status, every file's size (and hashes),
how many files were already present, `ifExists`, for a stitched session the
stitched file and each source ePsych file with its trial count
(`epsych.stitch`), the copy start and finish times, the host, the user, and the
function version and git commit.

### Stitching ePsych files

When ePsych was stopped and started again during one Intan recording, the
recording has several ePsych files, and pairing gives it at most one of them.
Select the recording's row and the rows holding its other ePsych files, and
press **Stitch selected rows**
([`stitchCopySessions`](../pipeline/stitchCopySessions.m)).
Rows of any status can be merged, including ambiguous rows and a row stitched
earlier. The files are always stitched in chronological order, whatever order
the rows are selected in. The stitched row keeps the Intan folder and its
destination. **ePsych file** lists every file joined by `+`, **ePsych time**
and **ePsych - Intan** belong to the earliest file, **Trials** is the total, and
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
copy.

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
| Subjects | subject IDs separated by spaces or commas; each is searched as **Find sessions** searches it. Blank: the Subject ID above |
| Every (min) | how often Windows starts a run, 5 to 1440 (default 60). Runs are on the clock: every 60 min is on the hour, every 15 min on the quarter hours |
| Days back | each run searches this many days, ending today (default 3; 1 = today only). A session already copied is recognised by its sizes and left alone, so looking back costs little. It is how a run missed while the computer was off, or the source unreachable, is caught up |
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
| `ambiguous` | an ambiguous pairing, never copied automatically (as on the Copy tab) |
| `unpaired` | Intan only or ePsych only |
| `needs_stitching` | a paired recording with another ePsych file that starts during it: ePsych was restarted. Stitch the files on the Copy tab and copy it from there |
| `stitched_by_hand` | a session copied by hand with stitched ePsych files (its `session_manifest.json` says so): copying its paired row would add a second behavior file to the folder |
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
moving either. MATLAB starts in the schedule's folder and runs the empty
`startup.m` kept there instead of yours. The same from a script:

```matlab
sch = CopySchedule;                        % this Windows user's schedule
s = CopySchedule.defaults();               % roots, pairing, EveryMin=60, LookBackDays=3, QuietMin=15, ...
s.Subjects = ["SUBJ-ID-1255" "SUBJ-ID-1256"];
sch.save(s);                               % write the settings, create the task
st = sch.status();                         % next run, last run, problems
sch.startNow();                            % a run now, in the background
out = CopySchedule.copyNew(s);             % one run's work, in this MATLAB
sch.remove();
```

## Project

| Control | Meaning |
| --- | --- |
| Config name, Description | `cfg.Name`, `cfg.Description` |
| Project root + Browse... + **Scan** | `Project.Root`. Scan builds `EphysProject(root)` (every folder that a registered reader claims: Intan `*.rhd` / `info.rhd`, or `recording.json`), then `P.refresh()`: header metadata, `applyManifest` (probe, exclusions, manual periods, sorting and behavior associations), `associateFolderBehavior` (a dataset with no behavior file takes the one Epsych2 file in its own folder), `writeManifest`. A progress dialog with Cancel; datasets whose headers fail keep `NaN` metadata and a warning is printed |
| Refresh metadata | re-parse all headers |
| Output root + Browse... | `Project.OutputRoot`: each dataset writes to `<root>/<Name>`; blank = next to the recording |
| Name pattern + Columns | `Project.NamePattern`: tokens parsed from each dataset name (see [`parseNameTokens`](EphysPipeline.md#dataset-name-tokens)); one checkbox per token, ticked tokens (`Project.TokenColumns`, default `SubjectID`) become table columns after Name. The label shows how many names match, or the pattern error |
| Filter | one editable dropdown per name-pattern token, listing the values found (`-` = the name does not match). Rows whose token does not match are hidden; type `*` / `?` wildcards or comma-separated alternatives (case-insensitive). Filters are a view only: they are not saved, and ticks on hidden rows stay in the selection (the label shows `showing k of n (m ticked hidden)`) |
| All / None | **All** ticks every shown row; **None** unticks every row, shown or hidden |
| Open in phy | the active dataset's associated sorted output (enabled only when it has `params.py`) |

Table columns (drag a header to reorder; the order is kept across refreshes
and saved in the app preferences): **Select**, Name, the ticked name tokens
(`-` when the name does not match the pattern), **Key** (root-relative, what the config
stores), Acq date, # chan, Fs (Hz), Duration (min), Format, Probe, Exclude,
**Sorting** (units, `curated` when phy labels exist, `auto` / `manual`),
**Behavior** (subject, trial count and the recorded pairing status). Ticks are written to
`Project.Datasets` as keys; with no ticks `Project.Selection` is `"all"`.
Clicking a row makes its dataset the active one; its row is highlighted.

**Behavior (Epsych2)** panel: **Match sessions as a pipeline step**
(`Behavior.Enabled`), search folders + **Add folder...**, match rule (`prefix,
then time` / `prefix only` / `time only`) and max start offset
(`Behavior.*`), **Find sessions for selected** (what `findEpsychSessions` sees
and what `matchEpsychSession` would pick for the active dataset),
**Re-match existing** (`Behavior.Overwrite`), **Write behavior .mat**
(`Behavior.WriteFile`), **Associate file...** (pick a
session `.mat` for the active dataset by hand) and **Clear**. Associations are
written to the manifest. Nothing is plotted here. When the behavior step runs
with **Write behavior .mat** on, each associated session is saved once as
`<Name>_behavior.mat` in the dataset's output folder; the Signals, Spikes and
Export outputs do not carry behavior data.

## Trials

Review how each Epsych2 trial is paired with the trial digital line (see
[pairing](EphysPipeline.md#pairing-trials-with-the-trial-line)).

| Control | What it does |
| --- | --- |
| Dataset + **Load** | the active dataset. Load reads its digital lines (`digitalEvents`: cached on disk after the first read, kept in memory while it stays active) and pairs the trials in order, reusing the cuts recorded in the manifest when they still match. Choosing another dataset clears the pairing shown, including cuts not yet approved |
| **Prefetch ticked** | reads and caches the digital lines of every ticked dataset (Project tab) that has an Epsych2 session, one after the other (`digitalEvents` for each), so a later Load, the pairing and the behavior step take them from `<Name>_events.mat` instead of reading the recording. A dataset whose cache is still current is only checked. With **Auto approve** on, each dataset is also paired and a pairing whose counts match is approved. The progress dialog names the dataset and the file being read; **Cancel** stops before the next file and keeps what was cached. The status bar sums it up (read, already cached, skipped for want of a session, failed; with Auto approve, approved automatically / already approved / need review), and an alert lists the pairings that need review and any failures |
| **Reset cuts** | drops the cuts (shown and recorded) and pairs every trial with every interval in order again |
| **Approve pairing** / **Mark unreviewed** | `setTrialPairing(P, "approved" / "unreviewed")`: saves the shown cuts in the manifest |
| **Write behavior .mat** | `behaviorToMat(Pairing=P)` now, without running the step |
| **Epsych2 to workspace** | loads the associated Epsych2 session file as saved (`Data`, `Info`) into the base workspace as `epsych_<Name>`; an alert and the status bar give the variable's name. A variable of that name is replaced |
| **Behavior to workspace** | loads the `behavior` struct of `<Name>_behavior.mat` (trials with the pairing columns, `info`, `meta`, `pairing`, ...) into the base workspace as `behavior_<Name>`, the same way. The file must exist: run the behavior step or press **Write behavior .mat** first |
| **Pair trials in the behavior step**, **Trial line** | `Behavior.PairTrials`, `Behavior.TrialLine` |
| **Auto approve when the counts match** | `Behavior.AutoApprove` (off by default): a pairing is approved as soon as it is paired (Load, a setting change, **Prefetch ticked**, the behavior step) when it cuts nothing and the Epsych2 trials and the trial-line intervals are equal in number (`EphysDataset.autoApproveTrialPairing`). The manifest marks the approval as automatic (`auto_approved`), the summary reads *APPROVED automatically* and the Project table *pairing approved (auto)*. A count mismatch, and a pairing whose cuts resolved one, still need **Approve**. **Reset cuts** and cut edits never approve; approving by hand replaces the automatic mark |
| Lines table (**Inverted**) | one row per digital line with its interval count; ticked lines are `Signals.InvertedLines`: on while low, so an event's onset is the falling edge and its offset the rising edge (the last low sample). This applies to the pairing and to the events the Signals step writes (and so to the exports) |
| **Resolve a count mismatch** | four spinners: Epsych2 trials and trial-line intervals to cut from the start and from the end before pairing. They belong to the dataset (its manifest), not to the config; cuts that would drop more than there is are refused |
| Trials table | trial, `TrialIndex`, interval, onset / offset (s), onset / offset sample, flag (orange = partial: the interval touches the recording start or end; grey = cut; red = unpaired), the other lines overlapping the trial. Click a header to sort, drag it to move the column. Right-click for **Parameter columns** (the session's Epsych2 parameters in alphabetical order; tick one, e.g. `TrialType` or a response code, to show it after Flag), **Remove "*name*"** (on a parameter column) and **Reset column order**. The chosen parameters and the column order are preferences, so they apply to every dataset and the next session; a parameter a session lacks is not shown there (the menu lists it as *not in this session*) and returns to its place for sessions that have it. Values that are not one number, text or date per trial are shown as text. A sort is not kept when the table refreshes (Load, a cut, a setting or a column change) |
| Plot | the digital lines over the recording: one bar per event, from its onset to its offset. A normal line's bars run from each rising edge to the next falling edge; an inverted line's (row label `(inverted)`) from each falling edge to the next rising edge. The trial line's bars are coloured by pairing state (paired, partial, cut, unpaired), and dotted lines across every row mark its onsets and offsets. Right-click the plot to show or hide those lines (shown by default) and the grid lines (hidden by default), and for **Trial labels**: the loaded session's Epsych2 parameters in alphabetical order (`TrialIndex` included). A ticked parameter writes each paired trial's value above the trial line, starting at the trial's onset; with several ticked, each label reads `name=value, name=value` in the order ticked, and the plot title names them. **No labels** clears them. Like the table's parameter columns, the choice is a preference: it applies to every dataset and the next session, and a parameter a session lacks is listed as *not in this session* and not written. Zoom and pan are horizontal only: the mouse wheel zooms time in and out about the cursor, dragging pans time |

The summary line says whether the pairing is approved (by hand or
automatically), recorded but not reviewed, or new, whether a recorded pairing went stale (the session, the
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
[`pipeline/probes`](../pipeline/probes/README.md).

- **Probe folder** + **Browse...** + **Refresh** list every probe `*.json` in
  the folder (not recursive; a probe's `<probe>.ks4.json` parameter file is not
  listed). The **probe table** shows Probe, Ch, Shanks, Depth
  (µm) and Notes; the Notes cell is editable and written back into the file.
- **Probe info** shows the file, `n_chan`, `chanMap` length, shank count,
  whether the probe has a Kilosort4 parameter file
  ([Optimize for probe](#optimize-for-probe)), and a channel-count check
  (`OK` / `MISMATCH`) against the active dataset.
- The **preview plot** shows sites by shank; excluded sites are gray `x`.
  **Show channel numbers** labels each site with its 1-based channel.
- **Design probe from probeinterface...** opens
  [`ProbeDesignerApp`](ProbeDesignerApp.md); **Import probe .json into
  folder...** (copies the probe's `.ks4.json` parameter file too, when it has
  one); **Edit probe .json...**.
- **Dataset** + **Exclude channels** (1-based, `1,5,32-40`): the exclusions
  of the active dataset, written to its manifest. How exclusions reach each step:
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
| Dataset | the active dataset: the one **Detect / Preview** analyzes and whose manual periods are listed |
| Method, Threshold, RMS window, Stitch gap, Pad, Min channels | `Artifacts.Method`, `Threshold`, `RmsWindowMs`, `MergeGapMs`, `PadMs`, `MinChannels` |
| Filter before detecting, High-pass (Hz) | `Artifacts.Filter`, `FilterCutoff` (with `FilterType`, `FilterOrder`). These now apply to runs as well as the preview |
| Apply to sorting / Apply to spike detection | `Artifacts.ApplyToSorting`, `ApplyToSpikes` |
| Cache intervals | `Artifacts.CacheIntervals` (`<Name>_artifacts.json`) |
| **Detect / Preview** | `analyzeArtifacts` over the active dataset (streamed, read-only; on the process pool when the Run tab's **Parallel** box is ticked): summary + per-channel table |
| Manual periods table, **Edit in Visualize**, **Clear** | the active dataset's `ManualArtifacts` (written to its manifest) |

The Threshold field is sent as-is for every method: with *Absolute microvolts*
/ *Common-mode* the default 9 means 9 µV.

## Sorting

Kilosort4, optional (`Sorting.Enabled`), either through SpikeInterface or
natively.

| Control | Maps to |
| --- | --- |
| Enable the Sorting step, Skip datasets already sorted | `Sorting.Enabled`, `SkipExisting` |
| Engine: *SpikeInterface + Kilosort4* / *Kilosort4 only (native, via a .bin)* | `Sorting.Engine` (`"spikeinterface"` / `"kilosort"`). The native engine writes `<Name>.bin` with the artifact periods zeroed, runs `run_ks4.py` on it, and greys out the SpikeInterface preprocessing controls, which it ignores. See [Running Kilosort4](EphysDataset.md#running-kilosort4) |
| Python exe (+ Browse), Conda env | `Sorting.PythonExe` (seeded from a `kilosort` conda env under `%LOCALAPPDATA%` / `%USERPROFILE%` when a new config is created), `CondaEnv` |
| Phy command | preference `PhyCmd` (blank = `conda run -n phy phy`) |
| Execution (background / blocking), Dry run | `Sorting.Execution`, `DryRun` |
| Bandpass filter, Common reference, Detect bad channels (+ method, action) | `Sorting.SI` ([defaults](EphysDataset.md#default-spikeinterface-configuration)); SpikeInterface engine only |
| Kilosort4 parameters (five groups, from `EphysPipelineConfig.kilosortParamSpec`), Extra settings (JSON) | `Sorting.KS4`, `KS4ExtraJSON`. Control kinds: int / float / bool as typed; `nullable` blank = omitted; `floatinf` blank / `inf` = omitted; `vector` = comma- or space-separated |
| **Optimize for probe** | loads the Kilosort4 parameters saved for the active dataset's probe (else the default probe) from `<probe>.ks4.json` next to the probe map; without that file, offers to generate it from the current parameters or from the probe layout ([details](#optimize-for-probe)) |
| **Reset to defaults** | every `Sorting.KS4` parameter back to its `kilosortParamSpec` default and `KS4ExtraJSON` cleared; the Python, execution and SpikeInterface settings stay |
| **Sorted output** panel: Dataset, label, **Use folder...**, **Use auto**, **Open in phy** | the active dataset's sorted-output association (`SortingDir`, manifest `sorting`). *auto* probes `kilosort4/si/sorter_output`; *manual* is a folder you chose (anywhere) |
| **Run this step** | `EphysPipeline.runSorting` over the selected datasets |
| progress label + log | background runs (`ks4_run.log` tail, `ks4_status.json`), see below |

Background runs are handed to a MATLAB `timer` (every 3 s): it appends new log
lines, logs `[done]` / `[error]`, rewrites the dataset's manifest and refreshes
the table. The timer stops when every tracked run has a status file. Closing
the app stops the timer but not Python processes already running. With
automatic artifact detection on, each dataset's scan runs **in MATLAB,
synchronously**, before Python is launched (and is cached afterwards).

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
  exclusions / list; reject events inside artifact periods), **Chunking**
  (chunk cap, edge pad; the parallel switch is on the Run tab), **Sorted units** (groups, include noise,
  templates), **Output** (folder, suffix `_spikes`, MAT version, overwrite).
- **Dataset** + **Preview**: detects on the first *n* seconds of the active
  dataset with the tab's settings and lists per-channel thresholds, counts and
  rates.
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

## Diagram

A diagram of what the working config does, redrawn whenever the tab is
shown and on every config edit while it is open. Each step that reads the raw
recording gets its own tree, drawn top-down from the recording to the files it
writes:

- **Artifacts**: chunked reading, the detection filter, the detector (method,
  window, threshold), channel coincidence, merge / pad, the automatic
  intervals, and where they go with the manual periods (Sorting, Spikes).
- **Sorting**: the SpikeInterface recording, crop, probe map, bandpass, bad
  channels (manifest exclusions + detection, remove / interpolate), common
  reference, silenced artifact periods, then Kilosort4's own high-pass, CAR,
  artifact threshold, whitening, drift correction, template matching and
  clustering.
- **Signals**: channel selection, then one branch each for LFP (resample,
  band filter, notch), MUA (bandpass, rectify, resample, integrate), SPIKE
  (resample, bandpass), AUX and the digital events; the amplifier branches end
  with bad-channel interpolation, the channel remap and the output file.
- **Spikes**: chunking, channels, bandpass, threshold, alignment, minimum
  period, amplitude cap, waveforms, artifact rejection and the spikes file.

The steps that read those outputs instead of the recording (sorted units for
the spikes file, Export) follow under **Downstream**. Stages the config leaves
off are dashed, disabled steps are faded, and artifact periods feeding another
step are marked orange. With an active dataset the recording node shows its
name, rate and channel count, and the Sorting tree shows its probe and
exclusions.

**Click a box to open the setting it draws**: the app switches to the tab that
holds it, scrolls it into view, focuses it and colours it blue and bold until
you leave the tab. A box usually stands for several controls (the *Threshold*
box for the method, the threshold and the polarity; *Drift correction* for
`nblocks`, `sig_interp`, `binning_depth`, `dmin` and `dminx`) — all of them are
marked, and the first one decides the tab. A step's header opens its **Enable**
box. Boxes lead where the setting lives rather than where they are drawn, so
*Silence artifact periods* in the Sorting tree opens the Artifacts tab, *Read in
chunks* opens the Run tab's parallel settings, and the recording box opens the
project root. Keyboard: tab to a box and press Enter or Space.

**Save as HTML...** writes the chart as a standalone page. Saved pages are not
clickable: the boxes only come alive when the app's HTML component calls the
page's `setup()`.

**Open in Browser** writes the chart to a temp file and opens it in your
default web browser, same as **Save as HTML...** but without the save dialog.

## Run

- **Steps** checklist: the Enabled boxes of every step (mirrored with the
  tabs), and the selection summary.
- **Parallel: chunks on the process pool** and **Max workers** (blank =
  automatic): `Parallel.Enabled` / `MaxWorkers`, used by the artifacts step,
  the Artifacts tab's **Detect / Preview** and spike detection; see
  [Parallel execution](EphysPipeline.md#parallel-execution).
- **Validate config** fills the issues table (`cfg.validate()`); **Plan** fills
  the results table with `pipe.plan()` (writes nothing).
- **Run**, **Dry run**, **Cancel**: `EphysPipeline.run` with progress bars
  (overall and per step), the results table (`Step`, `Dataset`, `Status`,
  `Message`, `Output`, `Seconds`) and a timestamped log. Cancel takes effect at
  the next progress boundary; outputs are written atomically, so a cancelled
  dataset leaves no complete-looking file.
- **Show the run diagram** (under the Run buttons) splits the right side in
  two: the progress bars, issues, results and log keep the left half and a
  diagram of the run takes the right half. It draws every step in execution
  order (Probe check, Behavior, Artifacts, Sorting, Signals, Spikes, Export),
  in the Diagram tab's step colours, each with a line saying what it does
  under the working config. The step underway is tinted, framed in its
  colour with a pulsing ring, and shows `RUNNING`, its percentage, a moving
  bar, the dataset (*Dataset 2 of 5: name*) and what it is doing; the diagram
  scrolls to it as the run moves on. Every step of the run has a percentage:
  how far it is through its datasets, (dataset − 1 + progress within the
  dataset) / datasets. Finished steps show `done` at 100 % with their result
  counts (done, dry run, skipped, to check, errors, cancelled), red when any
  row is an error; a cancel leaves its step at the percentage it reached and
  the later steps `not run`; steps outside the run are dashed. The headline
  says which step of how many is underway and for how long, or how the run
  ended. Before the first run the diagram previews the ticked steps and
  follows the checklist; afterwards it keeps the last run until the next one
  starts. The switch is remembered between sessions.
- **Monitor CPU, memory, disk and GPU** (under the run diagram switch) opens a
  **Resource use** panel under the Steps panel with a bar and figures for each:
  CPU (all cores, as Task Manager counts them), memory in use of the total,
  the busiest physical disk's active time with the read + write rate over all
  disks, and the busiest GPU's use and memory (tooltips give the detail, e.g.
  every GPU). A bar turns orange at 90 %. The sampling is done outside MATLAB
  by [`resource_monitor.ps1`](../pipeline/resource_monitor.ps1), a Windows
  PowerShell script launched at idle priority that opens the performance
  counters once, keeps one `nvidia-smi` running in loop mode for the GPU (no
  NVIDIA driver: the GPU row says `n/a`), and every 2 s overwrites one small
  JSON file in its own temporary folder; together they use well under 1 % of
  one core. The app only reads that file on a 2 s timer, and not at all while
  another tab is showing, so a busy MATLAB never stops the sampling itself.
  Unticking, or closing the app, stops the sampler (it also stops by itself
  when MATLAB exits) and it deletes its folder; if no sample comes for 15 s,
  the app starts a new one. The switch is remembered between sessions.
- Background Kilosort4 runs launched by a run are handed to the same monitor
  as the Sorting tab.

## Visualize

Display-only time-domain plots of the active dataset; the data on disk is
never modified.

| Control | Meaning |
| --- | --- |
| Dataset | the active dataset. After you choose another one, the plot still shows the previous dataset until you press **Plot**: the status line says so, and marking artifacts is off |
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

Summarizes a sorted-output folder (the folder holding `params.py`). A folder
that belongs to the active dataset (under its folder or output folder, or its
pinned sorting folder) is read with `EphysDataset.readSortedUnits`, so units
carry their full labels (`su042_1255_260908T1039`); any other folder, or a
dataset whose name does not match `Project.NamePattern`, is read with
`readPhyUnits` and its labels are only `<class><id>`.

- **Dataset**: the active dataset. Its associated sorted output (else the
  latest Kilosort4 run the `DatasetTracker` finds) loads when the tab opens
  and whenever the active dataset changes while it is open. A dataset without
  sorted output clears the tab. **Browse...** / **Load** accept any results
  folder, a dataset folder or a `kilosort4` folder (searches
  `kilosort4/si/sorter_output`, `si/sorter_output`, `sorter_output`,
  `kilosort4`). **Open folder in explorer**, **Open in phy**.
- **Summary**: the dataset key and label form (or the folder and why labels
  are short), Fs, duration, channels, shanks, unit counts by label, total
  spikes, mean rate, units per shank.
- **Units table**: Unit, Group (phy's `cluster_group.tsv` when present, else
  `cluster_KSLabel.tsv`), Shank, Ch (the peak channel's native name, else its
  recording channel number), X / Y (µm, the template centre on the probe),
  #Spk, FR (Hz), Amp, Cont%, **Notes**. Clicking a row focuses the plots, whose
  titles show the unit label; **Show all units** clears the focus. The table
  scrolls sideways.
- **Notes**: the one editable column. Typing a note saves it at once to
  `cluster_notes.tsv` next to the sort (`EphysDataset.writeUnitNotes`), the
  file phy uses for a `notes` label, so the Spikes and Export steps and
  `unitTable` carry it. A note that cannot be saved is put back, with an
  alert.
- **Plots**: units per shank; waveforms (templates × median amplitude,
  unwhitened when possible, not raw-spike averages); amplitude vs time (at most
  30,000 spikes); firing rate per unit.

Firing rates are spike count ÷ the time of the **last spike**, not the
recording duration. The units struct also carries `ksChannel` (the peak
channel among the sorted channels), `channel` (the 1-based recording channel),
the peak site (`peakX`, `peakY`) and the class and identity fields.

---

## Clean up

Frees local disk space once datasets are preprocessed. It is not a pipeline
step and nothing in the config drives it; it acts on the datasets selected on
the Project tab (the ticked rows, else all), which the top of the tab names.
The rules live in [`planLocalCleanup`](../pipeline/planLocalCleanup.m) and
[`runLocalCleanup`](../pipeline/runLocalCleanup.m), which can be called
without the app.

**What can be removed**, each with its own tick box:

| Kind | Files | Condition |
| --- | --- | --- |
| Raw recording files | the Intan files the Copy tab copied into the session folder, as listed in its `session_manifest.json` | each file's source, as recorded there, still exists **with the same size**. A recording not copied by the Copy tab has no known source and is always kept |
| Kilosort4's filtered copy of the recording | `recording.dat`, `temp_wh.dat` under the dataset's `kilosort4` folder or its sorted-output folder | none; the sorted units do not need it, phy's trace view does |
| Sorting input .bin | `<Name>.bin` + `<Name>.json` in the output folder, written by `toBin` for the native Kilosort engine | never the data file of a binary-format recording |

**Always kept**: every pipeline output (extract, spikes, behavior, events,
artifacts, Chronux, FieldTrip), the sorted output (the phy files), the dataset
manifest, the copy record (`session_manifest.json`, the robocopy log), the
Epsych2 session file and any other file. Nothing on the source is touched.

- **Preview** lists every file in the datasets' recording, output and sorting
  folders, one row each: **Action** (Remove / Keep), Dataset, What, Size,
  File and **Why** (for a raw file, where its source copy is, or why it is
  kept: not found at the source, a different size, no copy record). Remove
  rows come first, largest first, tinted red; raw files that are kept are
  tinted amber. The line above the table totals both sides: *Would remove
  N file(s), X GB, from K of M dataset(s). N file(s), Y GB, remain.* **Show
  the files that remain** hides or shows the Keep rows. Previewing reads file
  listings and the sources' sizes only.
- **Remove files...** acts on the preview as shown, after a confirmation that
  lists what goes by kind with its size, what remains, and, when raw files
  are among them, that those datasets cannot be run, viewed or scanned until
  they are copied back. Changing a tick box or the dataset selection discards
  the preview, so the button waits for a new Preview. It refuses while the
  pipeline, a copy or a Kilosort4 run is under way.
- Each file is checked again just before it is deleted: it must still have
  the size the preview saw, and a raw file's source must still have it too; a
  file that fails is **skipped** and left in place. Files are deleted outright,
  not moved to the Recycle Bin (which would free no space).
- Each dataset that had files removed gets `<Folder>/<Name>_cleanup.json`
  (see [Files on disk](file-formats.md#clean-up-record)): what was removed and,
  for raw files, where to copy them back from. The log under the table lists
  each file handled, and the preview is made again afterwards.
- After raw files are removed, **Scan** the project again: those datasets are
  no longer recordings and drop out of it. Their outputs are unaffected.

The tick boxes and Show the files that remain are preferences.

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

What is written ([`makeSyntheticProject`](../pipeline/makeSyntheticProject.m),
one recording per scenario with
[`makeSyntheticRecording`](../pipeline/makeSyntheticRecording.m)):

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
| 1 | `clean` | equal | approve as is (Auto approve does it) |
| 2 | `late-start` | the recording started 1.2 s into trial 3: trials 1-2 have no interval, interval 1 is partial (begins at sample 1) | cut 3 trials and 1 interval from the start (cutting 2 trials pairs trial 3 with the partial interval) |
| 3 | `early-stop` | the recording stopped in the middle of trial N-2: the last interval is partial, trials N-1 and N have none | cut 3 trials and 1 interval from the end |
| 4 | `spurious` | a 40 ms `InTrial` pulse before the first trial | cut 1 interval from the start |

`makeSyntheticProject` also takes `Scenarios`, `Format`
(`"one-file-per-signal"`, `"binary"`), `Fs`, `NumChannels`, `NumTrials`,
`FileSeconds`, `Seed`, `InvertedLines` (lines written active-low), `SortedOutput`,
`Artifacts` and `Overwrite`; its result holds the truth of every dataset
(events, trials, units, artifacts, the expected cuts).

## Reporting an issue

**Help → Report an issue on GitHub...** and **Help → Request a feature on
GitHub...** compose a GitHub issue from the session you are in. Both open the
same dialog: a title, a box for what happened (or what you would like the app
to do), tick boxes for what to send with it, and a preview of the whole report
exactly as it will be sent.

| Ticked | What it sends |
| --- | --- |
| System info | MATLAB release and platform, OS, compute threads, memory, GPUs, the Python interpreter (`pyenv` and the Sorting tab's), the installed toolboxes, and the repository folder with its git commit, branch and whether it has uncommitted changes |
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

## Preferences

Stored with `setpref` / `getpref` under the group `'EphysPreprocessingApp'`.
Only what is **not** part of a config lives here:

| Key | Contents |
| --- | --- |
| `FigurePosition` | window position/size (clamped to the screen on restore) |
| `ProbeFolder`, `PhyCmd`, `ReviewFolder`, `ScriptFolder` | paths |
| `LastConfigFile`, `RecentConfigs` | reopened on launch; the File → Open recent list |
| `DatasetsColumnOrder` | the Project table's column order (table variable names) |
| `TrialsParamColumns`, `TrialsColumnOrder` | the Epsych2 parameters shown in the Trials table, and its column order (table variable names; a parameter column is `Param_<name>`) |
| `TrialsLabelParams` | the Epsych2 parameters written as trial labels in the Trials plot |
| `VizOptions` | the Visualize tab's display settings |
| `CopyOptions` | the Copy tab's subject, roots, pairing and copy options (not the dates) |
| `ShowRunDiagram` | the Run tab's **Show the run diagram** switch |
| `MonitorResources` | the Run tab's **Monitor CPU, memory, disk and GPU** switch |
| `CleanupOptions` | the Clean up tab's kinds of file to remove and **Show the files that remain** |

To reset: `rmpref('EphysPreprocessingApp')` with the app closed. Older
preference groups are not read. The [scheduled copy](#scheduled-copy) is not a
preference: its settings live in its own file, which its Windows task reads.

## What the app writes to disk

| File | When |
| --- | --- |
| pipeline config `.json` | File → Save / Save as / Export copy (default folder `pipeline/pipeline_configs`) |
| generated `.m` script | File → Generate script |
| `<Folder>/<Name>_manifest.json` | scan, probe assignment, exclusion change, manual artifact edit, sorting / behavior association, each sorting launch and completion |
| `<outputFolder>/kilosort4/{si_config.json, run_si_ks4.py, ks4_run.log, ks4_status.json}` and `kilosort4/si/...` | Sorting, SpikeInterface engine (dry run writes only the first two) |
| `<outputFolder>/<Name>.bin` + `.json`, `<outputFolder>/kilosort4/{settings.json, run_ks4.py, ks4_run.log, ks4_status.json}` and the phy files | Sorting, native engine (dry run writes only `settings.json` and `run_ks4.py`) |
| `<outputFolder>/<Name>_artifacts.json` | Artifacts (cache) |
| `<Name>_extract_<TYPE>.mat` (or `<Name>_extract.mat`), `<Name>_spikes.mat`, `<Name>_chronux.mat`, `<Name>_fieldtrip.mat` | Signals, Spikes, Export |
| probe `.json` in the probe folder | Import, Designer save, Notes edit |
| `<parent>/synthetic_ephys/...` | File → Create synthetic test project (recordings, sessions, sorted output, probe, config, README) |
| `<Destination>/<SUBJ>/<Intan folder>/`: the copied files (for a stitched session, `<earliest ePsych file>_stitched.mat` instead of the ePsych files), `session_manifest.json`, `session_copy_robocopy.log` | Copy → Copy selected, in the background (Preview writes nothing); each scheduled run |
| `%LOCALAPPDATA%\ephys_analysis\copy_jobs\<batch>\`: the copy engine's job, progress and heartbeat files | while a copy batch is in flight; removed when it ends |
| `%LOCALAPPDATA%\ephys_analysis\copy_schedule\`: `schedule.json`, `task.xml`, `startup.m`; the Windows task `\ephys_analysis\Copy sessions (<user>)` | Copy → Save schedule (Remove deletes the task and the first two) |
| the same folder: `copy_schedule.log` (appended; the previous 5 MB in `copy_schedule.1.log`), `last_run.json`, `matlab.log` | each scheduled run |
| `<Folder>/<Name>_cleanup.json`; **deletes** the files the Clean up preview marks Remove | Clean up → Remove files..., after its confirmation |

Raw recording files are only read, except that Clean up deletes local copies
whose source still holds them. The source tree is only read.

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
| `onNewConfig.m`, `onOpenConfig.m`, `openConfigFile.m`, `onSaveConfig.m`, `onSaveConfigAs.m`, `onExportConfigCopy.m`, `onGenerateScript.m`, `onCreateSyntheticProject.m`, `createSyntheticProject.m`, `onOpenAnalysisApp.m`, `confirmDiscard.m`, `addRecentConfig.m`, `refreshRecentMenu.m` | File menu |
| `buildPipeline.m`, `runPipeline.m`, `onRunStep.m`, `onCancelRun.m`, `onValidate.m`, `onPlan.m`, `refreshStepPlan.m`, `onPipelineProgress.m`, `runLog.m`, `setRunBar.m`, `showIssues.m`, `onParallelControlsChanged.m` | running |
| `onRunDiagramToggled.m`, `resetRunDiagram.m`, `updateRunDiagram.m`, `finishRunDiagram.m`, `refreshRunDiagram.m`, `runDiagramHTML.m` | the Run tab's diagram of the run: show / hide, its model (start, progress events, end), what is sent to the page, the page |
| `onResourceMonitorToggled.m`, `startResourceMonitor.m`, `stopResourceMonitor.m`, `pollResourceMonitor.m`, `showResourceSample.m`, [`resource_monitor.ps1`](../pipeline/resource_monitor.ps1) | the Run tab's resource monitoring: show / hide, launching and stopping the sampler, the timer reading it, the display |
| `buildTrialsTab.m`, `onTrialsLoad.m`, `repairTrials.m`, `refreshTrialsView.m`, `refreshTrialsTable.m`, `refreshTrialsPlot.m`, `trialsColumnOrder.m`, `onTrialsTableMenu.m`, `onTrialsPlotMenu.m`, `onTrialsCutsChanged.m`, `syncTrialsCuts.m`, `onTrialsApprove.m`, `onTrialsPrefetch.m`, `onTrialsWriteBehavior.m`, `onTrialsToWorkspace.m`, `onTrialsSettingsChanged.m`, `clearTrialsView.m`, `fillTrialsLines.m`, `setTrialsLineItems.m`, `syncTrialsButtons.m` | Trials tab |
| `onScan.m`, `refreshDatasetsTable.m`, `onDatasetCellSelection.m`, `onSelectDatasets.m`, `onRefreshMetadata.m`, `onAssociateBehavior.m`, `onClearBehavior.m`, `onBrowseBehaviorDir.m` | Project tab |
| `selectDataset.m`, `currentDataset.m`, `populateDatasetPickers.m`, `refreshDatasetMenu.m`, `refreshDatasetPickers.m`, `datasetPicker.m`, `highlightDatasetRow.m` | the active dataset: Dataset menu, every tab's Dataset box, the highlighted table row |
| `refreshProbeList.m`, `onProbeSelected.m`, `onImportProbe.m`, `onDesignProbe.m`, `runProbeTool.m`, `onAssignProbe.m`, `onApplyExclude.m`, `onUseSelectedProbeAsDefault.m`, `probe_tool.py` | Probe tab |
| `onDetectArtifacts.m`, `refreshManualArtifactsTable.m`, `onClearManualArtifacts.m` | Artifacts tab |
| `onOptimizeKS4ForProbe.m`, `onResetKS4Params.m`, `onUseSortingFolder.m`, `onUseAutoSorting.m`, `refreshSortingLabel.m`, `pollKSRuns.m`, `onLaunchPhy.m`, `launchPhy.m` | Sorting tab and phy |
| `onSpikesPreview.m`, `syncSpikesEnableStates.m` | Spikes tab |
| `onPlotVisualization.m`, `onVizButtonDown/Up.m`, `drawVizArtifacts.m`, `finishVizArtDrag.m`, `applyVizChannelOrder.m`, `applyVizChannelColor.m`, `syncVizDataset.m` | Visualize tab |
| `buildFlowTab.m`, `refreshFlowChart.m`, `flowChartHTML.m`, `onSaveFlowChart.m`, `onOpenFlowChartInBrowser.m`, `onFlowNavigate.m`, `flowNavControls.m`, `clearFlowHighlight.m` | Diagram tab |
| `buildCopyTab.m`, `onCopyFind.m`, `onCopyRun.m`, `refreshCopyTable.m`, `onCopyTableEdited.m`, `onCopyStitch.m`, `onCopyUnstitch.m`, `onBrowseCopyFolder.m`, `copyLog.m`, `onCopyCancel.m`, `startCopyMonitor.m`, `stopCopyMonitor.m`, `pollCopyJob.m`, `setCopyRunning.m`, `applyCopyResult.m`, `finishCopyRun.m`, `showCopyProgress.m`, `copySummaryText.m`, `refreshCopySchedule.m`, `onCopyScheduleSave.m`, `onCopyScheduleRemove.m`, `onCopyScheduleRunNow.m`, `onCopyScheduleLog.m`; `pipeline/findCopySessions.m`, `pipeline/stitchCopySessions.m`, `pipeline/copySessions.m`, `pipeline/copy_engine.ps1`, `pipeline/stitchEpsychSessions.m`, `pipeline/CopySchedule.m` | Copy tab, the pairing / stitching / copy functions it calls, the detached copy engine, and the scheduled copy (its Windows task and what each run does) |
| `loadReviewResults.m`, `renderReviewPlots.m`, `syncReviewDataset.m` | Review tab |
| `buildCleanupTab.m`, `onCleanupPreview.m`, `onCleanupRun.m`, `onCleanupSettingsChanged.m`, `refreshCleanupScope.m`, `refreshCleanupTable.m`; `pipeline/planLocalCleanup.m`, `pipeline/runLocalCleanup.m` | Clean up tab and the functions that decide and delete |
| `load/savePreferences.m` | preferences |
| `helpURL.m`, `onHelp.m` | Help menu (wiki pages) |
| `onReportIssue.m`, `issueReport.m`, `issueURL.m` | Help menu (GitHub issue / feature request) |

## Tests

[`test_EphysPreprocessingApp.m`](../pipeline/test_EphysPreprocessingApp.m) builds
the app headlessly over a synthetic project: config → controls → config round
trip, the unsaved marker, the Diagram of the loaded config and its refresh on edits, that every box in a
chart of all the steps points at controls that exist and that clicking one opens its tab and marks
them, the Run checklist ↔ tab sync and its Parallel controls, scan + selection ticks
(and the ticked datasets in the Dataset menu),
the active dataset's highlight under the token filters, plan, the Sorting tab's Optimize for probe (each answer to the offer to generate a
missing parameter file, including a probe map without positions, loading the
file, the default-probe fallback, the Probe tab's listing and info) and Reset to defaults, one step through the pipeline,
the run diagram (its half of the right side, the last run followed while hidden, a run's steps and percentages
event by event, a cancel, the preview that follows the checklist, the preference),
resource monitoring (a sample's figures and colours, n/a readings, live samples from the sampler, the preference, the sampler
exiting and removing its folder when unticked), the Clean up tab's preview (every file listed, a raw
recording without a copy record kept, nothing deleted, the Keep rows hidden on request, a changed tick box discarding it),
save / reopen and the recent list,
the Help menu's wiki pages and its issue items (what a bug report and a
feature request carry, that an unticked section is left out, the percent-encoded
address with its label, and that a report too long for the address is cut and
says so). It
restores the user's preferences afterwards.
[`test_CopySessions.m`](../pipeline/test_CopySessions.m) (a `matlab.unittest`
class; `run_all_tests` runs it too) builds fake source trees in a temporary
folder. It checks pairing (a single session, interleaved sessions resolved
one-to-one, unpaired files on either side, exact and near ties, clock skew,
midnight, similar subject IDs, malformed names). It checks copying: a dry run
writes nothing; a hash-verified copy writes its manifest; an existing
destination is skipped, reported as an error or already present; a partial copy
is completed by `resume` (the short file finished, the missing one copied, the
rest left alone); a truncated copy fails; one missing source does not stop the
batch; unpaired rows copy only on request; Cancel works. It checks the
background form too: `Background=true` returns before the copy is done, polling
the job carries it through to `copied`, options passed with a job are
refused, and every `ProgressFcn` call carries the fraction, a message and the
`info` behind it (phase, session, sessions, bytes) with a fraction that never
steps back. It also drives the Copy tab from Find through a background copy to the
finished table. It checks that a session whose source changed within the quiet
time (a file, or a folder a file was taken out of) is left for later, and that
one another batch is writing is left alone until that batch has gone quiet,
also while a background batch of its own is in flight. For the scheduled copy
it checks what a run copies (the paired sessions of the days searched; never
ambiguous, unpaired, to-be-stitched or hand-stitched ones; nothing until the
source is quiet), what stops a run (no destination, no source), the log,
`last_run.json` and exit code of `CopySchedule.runTask`, the settings checks,
the task definition and UNC paths. It creates a real task, has Windows run it
(MATLAB, started in the background, copies the session and reports) and
removes it, and saves and removes a schedule from the Copy tab. Copy tests need
Windows (robocopy, Task Scheduler).
[`test_LocalCleanup.m`](../pipeline/test_LocalCleanup.m) (a `matlab.unittest`
class) copies a synthetic recording into a session folder as the Copy tab
would and checks what `planLocalCleanup` removes and keeps (a raw file whose
source is missing or a different size stays, as does a recording without a copy
record, and the `.bin` of a binary-format recording), that the Remove option
limits the kinds, and that `runLocalCleanup` deletes only the Remove rows,
leaves the source alone, skips files that changed since the preview, and writes
and appends to the clean-up record.
[`test_SyntheticDataset.m`](../pipeline/test_SyntheticDataset.m) checks the
synthetic project generators and, headlessly, the File-menu action: the
project is written, opened and scanned; choosing the active dataset in a
tab's Dataset box, the Dataset menu (a ticked dataset or one under All
datasets) or the Project table updates all of them, the Dataset menu and every
tab's Dataset box list only
the ticked rows,
clears the previous dataset's pairing and previews, flags a Visualize plot of
the previous dataset and loads the Review tab; the Trials tab pairs the clean
dataset, warns about the late-start one and resolves it with the expected
cuts.
