# DatasetBrowser

`DatasetBrowser` ([source](../analysis/DatasetBrowser.m)) is a `handle` class
that opens a window over a project's datasets. In it you filter and tick the
datasets, set what to compute around an event, and press **Compute**. The
result is one matrix over every ticked dataset, `data(row, time, group)`, with
one row per unit (or channel). A script waits for the window, or goes on
with the window left open, and reads the result from the handle, so the part of an analysis script that picks datasets
and loops over them shrinks to three lines. The compute itself is
[`epochMatrix`](../analysis/epochMatrix.m), which also runs without a window.

The browser scans a project and reads each dataset's outputs (which files
exist, the manifest's tags). It loads no recording. A dataset's source is
loaded only when it is computed, or once for the form's lists of lines and
trial parameters. Every dataset's part of the result is kept
([The cache and the result file](#the-cache-and-the-result-file)), so ticking
one more dataset computes only that one.

## Opening it

```matlab
B = DatasetBrowser("D:\EPHYS");           % scans the project and shows the window
B = DatasetBrowser();                     % the root of the last session (preference Root)
B = DatasetBrowser(root, Settings="ofc_hit_depth.json", Filter=struct('Tags', "ofc"));
B = DatasetBrowser(root, Visible=false);  % no window (scripts, tests)
B = DatasetBrowser(root, Scan=false);     % only read the result file: B.Result, no scan
```

`root` is an `EphysProject` root, or a copy of its output root. The options:

| Option | Meaning |
| --- | --- |
| `NamePattern` | the project's name pattern, from which each dataset's subject and date come. Default: the result file's, else the last one used, else `EphysDataset.DefaultNamePattern` |
| `OutputRoot` | the project's output root (`""`: outputs beside the recordings) |
| `Recordings` | Open Ephys sessions with several recordings: `"concatenate"` (default), `"separate"` or `"single"` |
| `Settings` | the settings of `epochMatrix`: a struct, or a `.json` settings file ([Settings](#settings)) |
| `Filter` | a struct of `setFilter`'s options |
| `ResultFile` | default `<root>\DatasetBrowser_results.mat` |
| `Visible` | `false`: no window shows |
| `Scan` | `false`: only restore the result file, without touching the share |
| `Workers` | the process workers **Compute** and `forEach` use ([Workers](#workers)). Default: all workers of a process pool already open, else the last one set, else 0 |

While the window opens, a small startup window (the name, version and a progress
bar) shows the steps: the window is built hidden, the last session restored and
the root scanned, then the browser appears. `Splash=false` starts without it
(the default with `Visible=false` and under `-batch`).

`B.OnTop` (the **Keep on top** checkbox) is settable at any time; its default is the last one set, else `false`.

On opening, the ticks, filter, settings and result saved in the result file
are restored, unless the options set them. With no saved state, the first scan
ticks what the filter shows. A root that cannot be reached raises
`DatasetBrowser:NoRoot`.

## The window

The window (1380 x 860 pixels, its position remembered) has a **File** menu,
a **Help** menu and four rows.

The **File** menu holds the [settings files](#settings):

| Item | Does |
| --- | --- |
| **Load settings...** (Ctrl+O) | reads a settings file (`B.loadSettings()`) |
| **Recent settings** | the last 10 settings files loaded or saved, newest first (`B.RecentSettings`, preference `RecentSettings`); one that no longer exists stays listed, grayed, with *(not found)*. **Remove from list** drops one file from the list (`B.removeRecent(file)`), **Clear list** drops them all (`B.clearRecent()`); the files themselves stay |
| **Save settings** (Ctrl+S) | writes the settings to the settings file (`B.SettingsFile`, the one last loaded or saved, named above the form); with none yet, it asks for one as **Save settings as...** does (`B.saveSettings()`) |
| **Save settings as...** | writes the settings to a file picked in a dialog (`B.saveSettingsAs()`) |
| **Export compute script...** | writes a script that computes these settings on the ticked datasets without the window ([Export a script](#export-a-script); `B.exportScript()`) |
| **Close** | closes the window, as its close button does |

The **Help** menu:

| Item | Does |
| --- | --- |
| **Help for DatasetBrowser** | opens this page's wiki page (`Dataset-Browser`) in the browser |
| **Documentation home** | opens the wiki's front page |
| **About DatasetBrowser** | shows the version of the code (release number, git commit, branch, date, uncommitted changes), the MATLAB release, the last commit of `DatasetBrowser.m`, `epochMatrix.m` and `DatasetRuns.m`, the versions of the result file and of the cache, and the root, the number of datasets found and the settings file. **Copy** puts the text on the clipboard, for an issue; `B.aboutText()` returns the part particular to the browser |

The rows:

1. **Root** (a field and **Browse...**) and **Pattern**, with **Scan**.
   **Scan** lists the root's datasets. It reads each one's outputs and tags
   but loads no dataset. The **Root** of a new scan takes that root's own
   result file, when the result file follows the root. **Keep on top**
   (`B.OnTop`, preference `OnTop`) holds the window above the other windows.
2. On the left, the filter, the count and the datasets table. On the right,
   the **Settings** panel.
3. The progress strip.
4. The status line.

### The filter

The filter only chooses which datasets the table shows. A hidden dataset keeps
its tick. Several terms are combined with AND. It is
[`datasetFilter`](../analysis/datasetFilter.m), the same filter, with the same
controls, as the analysis app's [Data tab](EphysAnalysisApp.md#data-tab). (There
**Search** is applied on Enter or leaving the field, not as you type.)

| Control | Effect |
| --- | --- |
| **Subject** | *(any)*, a subject from the list (the subjects in use), or several typed, comma-separated. `*` and `?` are wildcards; case is ignored; a term must match the whole subject. Any other character, a regular-expression one such as `.` or `(`, stands for itself |
| **not** (after Subject) | leave these subjects out (the same matching) |
| **Search** | words separated by spaces. Every word must appear, case ignored, in the dataset's name, key, subject or tags. The table follows as you type |
| **Tags**, *any of* / *all of* | *(any)*, a tag from the list (the tags in use), or several typed, comma-separated: the datasets with at least one of them, or with every one. A term that is no valid tag matches nothing |
| **not** (after Tags) | leave out the datasets holding any of these tags. A dataset with no tags is never left out by it |
| **Tick shown only** | tick the datasets shown and untick those the filter hides |
| **Untick all** | untick every dataset, shown or hidden |

The line above the table reads *showing 12 of 34 (3 ticked hidden) · 9 ticked*.

### The table

Click a header to sort; the sort is remembered (preference `Sort`). The
context menu has **Clear sort** and **Forget cached (ticked)**. Clicking a
row makes it the dataset the form's lists are read from.

| Column | Shows |
| --- | --- |
| **Use** | tick to include the dataset in **Compute**; the only column you can edit |
| **Name**, **Key** | the dataset's name and its project key |
| **Subject**, **Date** | from `subjectAndDate`, the same function and inputs `epochMatrix` uses, so the table and `R.rows` agree: the subject from the name pattern; the date is the acquisition date (the day the recording started) when known, else the date in the name |
| **Session** | each subject's datasets numbered 1, 2, ... by date; datasets on the same day share a number |
| **Tags** | the manifest's tags |
| **Units**, **Detected**, **Behavior** | a check mark when the sorting, the spikes file or the behavior file exists |
| **Signals** | the derived signals the dataset has (`LFP`, `MUA`, `SPIKE`, `AUX`) |
| **Cached** | the dataset's part for the current **Data** and settings: `✓ 62 units` (kept and current; the units, or for signals the channels, the dataset adds to the result: one matrix row each, so `✓ 8 channels` for signals), `skipped` (nothing to compute, kept so), `old` (kept, but either the settings or the stamp of the dataset's output files differ: computed again next time), or blank. The whole row is tinted to match: pale green (cached), pale yellow (`old`), pale red (`skipped`), none (blank) |

### The settings form

The right panel holds the settings of `epochMatrix`: **Data** above three
tabs, **Event**, **Trials** and **Measure**. Every edit is merged into the
whole settings struct and checked by `epochMatrixSettings`; an edit that does
not fit is undone and its reason shown in the status line. Above **Data**,
*Settings file* names the file **File > Save settings** writes (its full path
in the tooltip). A [settings file](#settings) holds every field, also those
the form does not show.

The **Event** and **Trials** tabs are the analysis app's own controls
(`AlignControls`, the Alignment tab's Event reference, Epoch window and Trial
selection), so they offer the same fields and behave the same; see
the [Alignment tab](EphysAnalysisApp.md#alignment-tab) for each one. The window is always
fixed (`epochMatrix` takes no other mode), so the browser hides the window's
mode and its stop event.

| Control | Sets |
| --- | --- |
| **Data** | `data`: `units`, `detected`, `LFP`, `MUA`, `SPIKE` or `AUX`. Only the matching block of the **Measure** tab is on |
| **Event** tab: **Event reference** | `ref`: **Line**, **Edge**, **Which** and **n**, **Scope**, **Offset (s)**, **Length (s)**, **Time range (s)**, **Shift by** and its unit, and **Sequence** |
| **Event** tab: **Sequence** **Edit...** | `ref.sequence` and `ref.alignStep` in the *Event sequence* window: any number of steps, each *followed by* or *not followed by* a line's onset or offset (its **n**, **Within (s)**, **Min / Max length (s)**), and **Align to** the start or any *followed by* step (aligned to the start, the steps are conditions only). For example *Trial offset then Trough onset*: the first Trough onset after each trial ends. **Apply** checks the steps |
| **Event** tab: **Epoch window** | `window`: **Pre (s)**, **Post (s)** |
| **Event** tab: **Epoch Diagram** | opens the *How the epochs are cut* window (`EpochDiagram`, also `B.showEpochs()`) for the dataset the lists come from: the lines, each event picked, the sequence, the windows and the trials kept or dropped. It is redrawn on every settings edit and row click until closed, and closes with the browser |
| **Trials** tab | `selection`: **Filter** (an expression over the trial columns, e.g. `Depth > 0 & ~FA`; **?** lists the columns, words and functions), **Response**, **Pairing** (`pairingFlags`), **Group by** and **and** (one or two trial parameters), **Order**, **Max groups**, **Artifacts** (`excludeArtifacts`, at least `minArtifactSec`) |
| **Trials** tab: **Epochs per group** | opens the *Epochs per group* window (`EpochGroupCounts`, also `B.showGroupCounts()`) for the dataset the lists come from: see [Epochs per group](#epochs-per-group). It is redrawn on every settings edit and row click until closed, and closes with the browser |
| **Measure** tab: **Normalize**, **Baseline (s)**, scope | `normalize`: `method`, `baseline` and `scope` (*per row* or *per group*); see [Normalization](#normalization). A change normalizes the result again in place and computes nothing. Off for measure `auroc`; **Baseline (s)** only for the methods that use it |
| **Channels** tab | **Shanks** and **Channels**: `units.shanks` and `units.channels` for `units` and `detected`, `signal.shanks` and `signal.channels` for a signal (blank = all), also picked by clicking the probe; see [Shanks and channels](#shanks-and-channels) |
| **Measure** tab: **Spikes** block | **Merge neighboring sites** (`units.merge.enabled`, `detected` only), **Measure**, **Bin (s)**, **auROC baseline (s)** (with measure `auroc`) |
| **Measure** tab: **Signals** block | **Baseline (s)**, **Statistic**, **Detrend**, **Rectify**, **Magnitude (AUX)** |
| Above **Compute**: **Keep single trials, not just averages (R.epochs)** | `keepEpochs`: the result also keeps every epoch before the average ([Each epoch](#each-epoch-repochs)), which `B.showRasters` draws ([Trial rasters](#trial-rasters)). Every kind of **Data** |

The form does not show every field (the unit classes and tests, the auROC
section, the selection's explicit trial rows, and an interval length or time
range of a stop event). Load a settings file or assign `B.Settings` for
those; an edit in the form keeps them.

The line and parameter lists (**Line**, **Shift by**, **Group by**, and the
lines the *Event sequence* window offers) come from one dataset's source: the
clicked row's, else the first ticked dataset's. A value typed or loaded that
this dataset lacks stays.

#### Epochs per group

**Epochs per group**, under the **Trials** tab, opens a window that counts
the epochs of one dataset (the clicked row's, else the first ticked) by
group, cut as **Compute** cuts them (`epochTable` with the **Event** and
**Trials** tabs' settings). With **Group by** *Depth*, it shows how many
epochs, and trials, each depth gives. Top to bottom:

- the count, as the analysis app's [Alignment tab](EphysAnalysisApp.md#alignment-tab)
  words it: *"N epochs from M of T trials in G groups (scope)"*, with the
  events dropped and why; or, in red, why there are none;
- **Show the epochs Pairing and Artifacts exclude** (off by default): each
  bar then counts the epochs of every pairing flag, with or without an
  artifact, and stacks on the kept epochs those the **Pairing** selection
  leaves out (gray) and those an artifact period excludes (red);
- a bar per group in the group colors the figures use, in the selection's
  group order, its count on top (the Alignment tab's bars);
- a table, a row per bar: **Trials** (the trials the selection keeps in the
  group), **Epochs** (the epochs they give, the ones **Compute** averages)
  and, with the excluded shown, **Pairing excludes** and **Artifacts
  exclude**.

The window stays above the browser, follows every settings edit and row
click, and closes with the browser. What it drew is on the window object
(`B.CountsWindow`): `Counts` (the table), `Groups` (`epochTable`'s groups),
`Summary`, `Message`.

**The Data dropdown and its two blocks.** **Data** chooses what is computed,
and with it which block of the **Measure** tab applies:

- `units` (the sorted units of the sorting folder) and `detected` (the Spikes
  step's threshold detections, one train per channel) use the **Spikes** block.
  The result is a rate, a count or an auROC per bin.
- `LFP`, `MUA`, `SPIKE` and `AUX` (derived signals) use the **Signals**
  block. The result is the group mean or median of each channel.

The controls of the other block are off. A note beside the dropdown counts the
ticked datasets that cannot give that data (*3 of 12 ticked lack LFP
(skipped)*, *2 of 12 ticked have no sorting*). A change to a setting of the
other block leaves the kept parts of this **Data** valid.

### Shanks and channels

The **Channels** tab picks the shanks and channels computed with. Its two
fields are the settings of the **Data** chosen: for `units` and `detected`,
`units.shanks` and `units.channels`; for `LFP`, `MUA` and `SPIKE`,
`signal.shanks` and `signal.channels`. Each kind keeps its own picks, so
switching **Data** shows the other kind's.

- **Shanks**: the probe map's `kcoords` values, e.g. `1:4` or `1 3`.
- **Channels**: recording channels, 1-based (the probe map's `chanMap` + 1,
  the numbers drawn beside the sites), e.g. `1:16` or `3 7 12`. For `AUX`,
  which has no probe, they are the AUX columns, and **Shanks** and the probe
  are off.
- **All** clears both fields: every shank and every channel.

A site is computed with when both fields hold it (blank = all). This is how
`selectUnits` and `epochMatrix` select: a unit by its own channel and shank, a
signal's column by its recording channel and shank.

Under the fields, the probe of one dataset is drawn at its true site
positions (`ProbePicker`). The dataset is the clicked row's, else the first
ticked one, and its probe is read when the tab is shown (`B.showProbe()`).
Each physical shank is drawn as a body with a tip, named under it by its
`kcoords` group, and each site as a dot, with its channel beside it when the
labels fit. The sites computed with are filled blue. A site in **Channels** on
a shank that **Shanks** leaves out is ringed. The rest are gray. With
**Shanks** set, the bodies of its shanks are tinted.

The probe and the fields are yoked:

- A click on a site picks its channel, or drops it when it is picked. With
  **Channels** blank (all), the first click starts the list with that one
  channel. Dropping the last one leaves the field blank (all again).
- A click on a shank's body or name picks or drops the shank in the same
  way.
- A value typed in a field recolors the probe.

`B.pickProbe("site", 17)` and `B.pickProbe("shank", 2)` do what a click
does. For a dataset without a probe map the tab says so; type the numbers
instead.

### Event & trial definitions

The **Event & trial definitions** panel under the tabs (above **Keep single
trials**) keeps named sets of
the **Event** and **Trials** tabs' settings, to switch between them in one
click: each holds the event (with its sequence), the epoch window and the
trial selection (`ref`, `window`, `selection`). **Data**, the channels, the
measure and the normalization are not part of it.

- **+** adds the tabs' settings as a new definition, named from the event
  and trials part of [`ResultName`](#from-a-script) (`StimOnset_Hit`,
  `TrialOnset_AllTrials`), numbered when taken. With a name typed in the
  drop-down's box, it
  keeps them under that name, replacing a definition of that name
  (`B.addDefinition(name)`; no name: a new one).
- Picking a name from the drop-down puts its event, window and trials in the
  settings, checked as any edit is (`B.useDefinition(name)`); typing a name
  only names the next **+**.
- **−** drops the definition shown; the settings stay
  (`B.removeDefinition(name)`).

The drop-down shows the definition the settings match (also after **File >
Load settings**), and *changed* beside it once the event, window or trials
differ from the one shown; **+** then adds them as a new definition (type
the shown name to replace it instead).

The definitions (`B.Definitions`: `name`, `ref`, `window`, `selection`) are
saved in the [settings file](#settings) by **File > Save settings**, and
**File > Load settings** replaces them with the file's (none when the file
holds none). The result file keeps them with the rest of the browser's
state.

### Compute

**Compute** computes the ticked datasets with these settings. The summary under
the button reads *812 units × 200 bins × 5 groups from 32 of 34 datasets; 1
computed, 33 reused*. When the settings or ticks changed since the result, it
begins *Out of date:* and says what differs.

### Load whole sessions

**Load whole sessions**, beside **Compute**, computes nothing: it uses the
browser as a way in to the data. Each ticked dataset comes on its own clock,
not cut into epochs, into `B.Sessions` for your script to use as it likes
(`B.loadSessions()` from a script). What comes depends on **Data**:

- **units**, **detected**: the spike times of the units **Compute** would use
  (classes, shanks, channels, merge, quality and response filters).
- **LFP**, **MUA**, **SPIKE**, **AUX**: the whole signal, of the channels the
  [Channels tab](#shanks-and-channels) keeps. A MUA at 2 kHz × 64 channels ×
  1 h is about 1.8 GB, and every ticked dataset is held at once.

Every dataset also brings every trial and every digital line. The **Trials**
tab's selection marks the trials (`kept`, `group`, `groups`) but drops none.
The event, the window, the measure and normalization are not used.

**Load trials only**, beside it, brings the same without the spikes or the
signal: only the trials and the digital lines, whatever **Data** is (`data` is
`"trials"`; `spikes`, `units`, `signal` and `channels` are empty). From a
script: `B.loadSessions(TrialsOnly=true)`.

`B.Sessions` is a struct column, one per dataset loaded, made by
[`sessionData.m`](../analysis/sessionData.m):

| Field | Holds |
| --- | --- |
| `key`, `name`, `folder`, `subject`, `startTime`, `tags` | which dataset |
| `fs`, `durationSec` | the recording's rate and length |
| `data` | **Data**; `"trials"` from **Load trials only** |
| `spikes`, `units` | `{nUnits x 1}` spike times, s, on the continuous clock, and one row per unit (`selectUnits`' table); `{}` and `table()` for a signal |
| `signal`, `signalFs`, `channels` | `[nSamples x nChannels]` single (µV; AUX: V), row `k` at `(k-1)/signalFs`, its rate and one row per column (`selectChannels`' table); `[]`, `NaN` and `table()` for spikes |
| `events` | line → `[k x 2]` `[t_on t_off]` s on the digital clock (polarity applied, derived events included) |
| `eventsContinuous` | the same on the continuous clock |
| `toContinuous` | a function moving any digital-clock time (a trial column) to the continuous clock |
| `lines` | Line, Count, MeanDurationSec, First, Last, Inverted, Derived |
| `trials` | every paired trial (`table()` without a pairing) |
| `kept`, `group`, `groups` | the trials the **Trials** tab keeps, each trial's group (0 = not kept), the groups table |
| `hasTrials`, `trialLine`, `respField`, `paramNames`, `pairing`, `derivedEvents`, `invertedLines` | the pairing and the behavior |
| `artifacts` | `[k x 2]` s, continuous clock: the periods the Signals step erased |
| `probe`, `labels` | the probe map and the amplifier channel labels |

**Two clocks.** Spike times and signal samples are on the continuous clock
(sample `k` at `(k-1)/fs`); digital events and the trials' times
(`TrialOnset`, `TrialEvents`, ...) are on the digital clock (`t = row/fs`).
One recording sample is `1/fs` apart on the two. Align spikes to
`eventsContinuous`, or to `D.toContinuous(D.trials.TrialOnset)`, never to the
raw trial times.

```matlab
B = DatasetBrowser.open(root);
B.wait();                       % tick, then Load whole sessions
for D = B.Sessions.'
    on = D.toContinuous(D.trials.TrialOnset(D.kept));
    % ... D.spikes{u} against on, D.events.Lick, ...
end
```

Nothing is cached or written to the result file: each press reads the
datasets again (on the [workers](#workers) when set). A dataset without the
data asked for (no sort, no spikes file, no such signal) is skipped; the
strip's message counts them. `[D, T] = B.loadSessions()` also returns each
ticked dataset's status. Like **Compute**, the button lets `wait` return and
runs the post-processing script when ticked.

### The post-processing script

The **Post-processing script** box under **Compute** runs a script of yours
on the result, so its variables (the data sorted, split and labeled for the
plots) are in the workspace as soon as a compute finishes:

| Control | Does |
| --- | --- |
| the drop-down | picks the script (`B.Script`) from the list (`B.Scripts`, full paths); its tooltip is the path. A file that no longer exists stays listed, with *(not found)* |
| **+** | adds a `.m` file picked in a dialog to the list and picks it (`B.addScript()`, or `B.addScript(file)`) |
| **−** | takes the script shown off the list; the file stays (`B.removeScript()`) |
| **Edit** | opens the script in the MATLAB editor (`B.editScript()`) |
| **Run it after each Compute or Load** | **Compute** and **Load whole sessions** run the script once the data are in (`B.ScriptAfterCompute`) |
| **Run now** | runs the script on the result or the sessions as they are (`B.runScript()`); off before either |

The script runs in the base workspace, as `run` runs it, with the browser put
there as `B` first (a `B` already there is replaced). It reads the result
with `R = B.Result` (or `S = B.Sessions`) and may use anything of the browser (`B.ResultCurrent`,
`B.progressStart`, `B.forEach`, ...). Everything it makes stays in the
workspace. An error in it is shown on the status line, naming the script and
its line (`DatasetBrowser:ScriptFailed`, the script's error as its cause);
the result is kept.

The first list is the scripts in [`analysis/scripts`](../analysis/scripts),
which holds
[`S_PrepareDatasetBrowserOutputForPlots.m`](../analysis/scripts/S_PrepareDatasetBrowserOutputForPlots.m):
it keeps the `su` units (or every channel of a signal), sorts them by session
and the groups by label, and leaves `R`, `units_`, `data_`, `groupLabels_`,
`groupTexts_`, `cmap`, `nS`, `nU`, `nB`, `nG` and a summary of `R` in the
workspace. It also holds
[`S_DatasetBrowserLFPToFieldTrip.m`](../analysis/scripts/S_DatasetBrowserLFPToFieldTrip.m),
which turns a signal into FieldTrip raw structures (`ft_datatype_raw`), one
per dataset: `ftEpochs` from `R.epochs` (`epochMatrixFieldTrip`: a trial per
epoch, `trialinfo` = `[resultGroup trial]`) and `ftSessions` from
`B.Sessions` (`sessionDataFieldTrip`: the whole signal, with its events, a
`trl` for `ft_redefinetrial` and the erased periods as an artifact matrix);
see [FieldTripExport](FieldTripExport.md#from-the-analysis-results). The
list, the script picked and the box are preferences.

From a script, `B.compute(RunScript=true)` computes and then runs `B.Script`;
`B.compute()` runs none. `B.loadSessions(RunScript=true)` likewise.

### The progress strip

The strip at the bottom has a message, a bar, the elapsed time with the time
left (`ProgressClock`), the **Workers** field and a **Cancel** button. The
scan, **Compute**, `forEach` and a script's own loop all drive it. While it
is running (`Busy`), every control but **Cancel** is off. **Cancel** takes
effect at the next check: between datasets and between units (on workers:
at once, for every dataset not finished). With `Visible=false`, or once the
window is closed, the same calls print a line to the command window at most
every 2 s, and one at the finish.

### Workers

**Workers** (`B.Workers`, preference `Workers`) is how many datasets
**Compute** and `forEach` compute at once on process workers (Parallel
Computing Toolbox, `parfeval`). When a process pool is already open as the
browser opens, Workers starts at that pool's size. Otherwise it starts at the
last value set, else `0`, which computes the datasets here, one after the
other. With 1 or more, and two or more datasets to compute, the open
process pool is used, or one of that many workers is started (`parpool
"Processes"`; it stays open until its idle timeout, so the next **Compute**
starts at once). Each worker loads its dataset's source, computes its part and
sends it back; the cache, the **Cached** column and the result are the same
as when computed here. Datasets already cached are not sent. Without the
toolbox, or when no pool can be started, the datasets are computed here with
the warning `DatasetRuns:Serial`.

Each worker holds one dataset in memory (its spikes, or its signal for LFP,
MUA, SPIKE and AUX), so the number that fits depends on the machine's memory
and the size of the recordings. A `forEach` function, and whatever it
captures, is copied to the workers: a handle object it captures is a copy
there, and changes made to it on a worker are not seen here. The functions it
calls must be on the path the workers start with.

## From a script

The owner's main use: sections 2 to 4 of an analysis script (pick the
datasets, set the options, compute) become

```matlab
B = DatasetBrowser(root, Settings="ofc_hit_depth.json");
B.wait();          % tick, adjust, Compute
R = B.Result;
```

`wait` blocks until a **Compute** or **Load whole sessions** from the window finishes (and the
post-processing script, when ticked, has run), `B.done()` is called, or the
window is closed (it returns at once when the window is hidden or closed;
`Timeout=` limits the wait). The window stays open after Compute.
`R` is [the result](#the-result). Closing the window keeps the object:
`Result`, `compute` and `forEach` still work.

### Without waiting

A script need not wait. `DatasetBrowser.open` returns the browser whose window
is already open on the root, as it is, and opens one only when none is. The
script goes on with the result the browser holds (the result file's, when the
window has just opened) and the window stays open for later changes:

```matlab
B = DatasetBrowser.open(root, NamePattern=namePattern);
if isempty(B.Result), B.wait(); end   % nothing computed yet: tick, Compute
R = B.Result;
```

To use other datasets or settings, change them in the window, press
**Compute** and run the script again: it finds the same window and reads the
new result. `B.ResultCurrent` is false while the window's settings or ticks
differ from the result's. The options are only for a new browser; an open
one keeps its own. A root of `""` takes any open window, and a hidden browser
(`Visible=false`) is never returned. The script's variables do not matter: a
`clear` leaves the window, and its browser, open.

### Without a window

Every control's action is a method, so the same steps run headless:

```matlab
B = DatasetBrowser(root, Visible=false);
B.setFilter(ExcludeSubjects="SUBJ-ID-1255", Tags=["ofc" "perceptual_training"], TagMode="all");
B.tickShown();
B.Settings = epochMatrixSettings(B.Settings, data="detected", binSec=0.01);
R = B.compute();
```

| Method | Does |
| --- | --- |
| `scan(B, Root=, NamePattern=)` | find the datasets (the **Scan** button) |
| `setFilter(B, Subjects=, ExcludeSubjects=, Tags=, TagMode=, ExcludeTags=, Search=)` | set some of the filter's terms; the others stay. `clearFilter(B)` shows every dataset |
| `tick(B, KEYS, TF)`, `tickShown(B)`, `untickAll(B)` | tick or untick datasets by key, name or index; or set `B.Selected` |
| `sortBy(B, COLUMN, DIRECTION)`, `clearSort(B)` | sort the table |
| `setListSource(B, KEY)`, `fillLists(B)`, `source(B, KEY)` | the dataset the form's lists come from; fill them; its analysis source |
| `formEdit(B, CONTROL, VALUE)` | edit a control of `B.Ctl` (or of `B.Ctl.Align`, the Event and Trials tabs: `Line`, `Filter`, `Group1`, ...) as a click would |
| `showEpochs(B)` | the **Epoch Diagram** window of the lists' dataset |
| `showGroupCounts(B)` | the **Epochs per group** window of the lists' dataset ([Epochs per group](#epochs-per-group)) |
| `showProbe(B)`, `pickProbe(B, KIND, VALUE)` | the **Channels** tab with the lists' dataset's probe; a click on it: `KIND` `"site"` (a recording channel) or `"shank"`, toggled and applied ([Shanks and channels](#shanks-and-channels)) |
| `showRasters(B, ROW)`, `X = raster(B, ROW, Order=)` | the **Trial rasters** window on row `ROW` of the result; that row trial by trial ([Trial rasters](#trial-rasters)) |
| `R = compute(B, Recompute=false)` | `epochMatrix` over the ticked datasets with `B.Settings` |
| `[VALUES, T] = forEach(B, FN, ...)` | [your own per-dataset code, cached](#foreach) |
| `forget(B, NAME, KEYS)`, `forgetTicked(B)` | drop kept parts |
| `loadSettings(B, FILE)` | read a [settings file](#settings) (no `FILE`: a file dialog) |
| `saveSettings(B, FILE)`, `saveSettingsAs(B)` | write one (no `FILE`: `B.SettingsFile`, else a file dialog; `saveSettingsAs`: always a dialog) |
| `TXT = exportScript(B, FILE)` | [a script](#export-a-script) that computes `B.Settings` on the ticked datasets without the browser (no `FILE`: a file dialog; `""`: the text only) |
| `removeRecent(B, FILE)`, `clearRecent(B)` | drop files from `B.RecentSettings` (**File > Recent settings**) |
| `addDefinition(B, NAME)`, `useDefinition(B, NAME)`, `removeDefinition(B, NAME)` | keep the settings' event, window and trials under `NAME` (blank: a name from them), put a definition's in the settings, drop one ([Event & trial definitions](#event--trial-definitions)) |
| `save(B, FILE)`, `restore(B, FILE)` | the [result file](#the-cache-and-the-result-file) |
| `wait(B, Timeout=Inf)`, `done(B)`, `close(B)` | the window |
| `B = DatasetBrowser.open(ROOT, ...)` | the browser of the window open on `ROOT`, else a new one ([without waiting](#without-waiting)) |

The properties: `Settings` (the whole struct; assigning checks it with
`epochMatrixSettings`), `Filter`, `Selected` (the ticked keys), `Table` and
`Shown` (the rows shown, and their keys), `Datasets` (every dataset found),
`Result`, `ResultCurrent` (the result was computed with these settings on
these ticks), `Computed` (when the result was computed, a `datetime`: the
last Compute, or the one the result file holds; `NaT` before a result; a
change of `Normalize` alone does not move it), `ResultName` (read-only: the
result's default name, `R.name`; `""` before a result), `Definitions` (read-only: the [event & trial definitions](#event--trial-definitions)), `ResultFile`, `Workers` ([Workers](#workers)), `Runs` (the `DatasetRuns` with the kept parts),
`Runner`, `Busy`, `CancelRequested`, `Fig` and `Ctl` (the window and its
controls). `OnChange(B, what)` is called with `"scan"`, `"filter"`,
`"ticks"`, `"settings"`, `"definitions"`, `"result"`, `"done"` or `"closed"`.

### Export a script

**File > Export compute script...** (`B.exportScript(file)`) writes the
least code that gives the window's Compute without the window or the
browser: the project and the ticked datasets' keys, the settings that
differ from the defaults (the trials kept and grouped are `selection`),
and `epochMatrix`:

```matlab
% The datasets: those ticked in the browser.
% (The browser's filter: Tags="ofc, perceptual_training", TagMode="all".)
cfg = EphysAnalysisConfig();
cfg.Source.Root = "D:\EPHYS";
cfg.Source.Selection = "list";
cfg.Source.Datasets = [
    "SUBJ-ID-1301/SUBJ-ID-1301_260302_101512"
    "SUBJ-ID-1302/SUBJ-ID-1302_260304_094730"
    ];

% The settings that differ from the defaults (epochMatrixSettings); the trials are selection.
S = epochMatrixSettings([], ...
    data="detected", ...
    ref=struct('line', "Stim"), ...
    selection=struct('response', "Hit", 'groupBy', "Depth"));

R = epochMatrix(cfg, S);
```

A struct setting lists only its fields that differ (`epochMatrixSettings`
merges them over the defaults), and settings that do not apply to the data
(`signal` for spikes; `units`, `measure`, `binSec`, `baseline`, `auroc` for
a signal) are left out. The filter is a comment: the keys are the
selection. `R` is what Compute gives, but for `R.name`, and nothing is
cached: each run computes every dataset (pass `Runs=` a `DatasetRuns` to
keep the parts between calls). With [Workers](#workers) set, the call
passes `Workers=`.

### A script's own progress

The progress strip is the browser's and the script's. A loop of your own can
drive it and be canceled from it:

```matlab
B.progressStart("Histograms", Total=nS);
for si = 1:nS
    B.progressStep(si, sprintf("Session %d", si));   % "3/12 Session 3", bar at 3/12
    if B.CancelRequested, break, end                 % or B.checkCancel()
    % ... the work
end
B.progressFinish("Histograms done");
```

`progressStart(title, Total=)` resets the clock and turns **Cancel** on.
`progressStep(i, message)` shows step `i` of `Total`; `progress(fraction,
message)` shows a fraction. `CancelRequested` becomes true when **Cancel** is
pressed (or `B.cancel()` is called) since `progressStart`; `checkCancel()`
ends the run first (the message *Canceled*, the bar as it was, the controls
on again) and then raises `DatasetBrowser:Canceled`, which a `try` can catch.
If the script stopped on an error and left its run open, a second press of
**Cancel** ends it. Neither applies to the browser's own scan, **Compute** and
`forEach`, which end their runs themselves.
`progressFinish(message)` ends the run. A `compute` inside the loop takes the
strip over for its time.

## The result

`B.compute()` returns, and `B.Result` holds, the result `R`.
`size(R.data) = [height(R.rows), numel(R.t), numel(R.groupLabels)]`. Scripts
use the fields in place (`R.data`, `R.rows`, `R.t`, `R.groupLabels`,
`R.settings`) and need not copy them out. `imagesc(R.t, 1:height(R.rows),
R.data(:, :, 1))` draws the first group of every row, and `R.labels`
([Labels](#labels)) gives its axis labels and caption in words.

| Field | Type | Holds |
| --- | --- | --- |
| `R.data` | double [nRows x nTime x nGroups] | The values: data(row, time, group). It holds the measure (rate, count or auROC) for spikes, and the group mean or median for signals. Wherever a row's dataset has no epochs in a group, the value is NaN. With `settings.normalize.method` other than `"none"` the values are normalized ([Normalization](#normalization)). |
| `R.rows` | table, nRows rows | One row per unit (spikes) or channel (signals), in data's first-dimension order. Columns for every kind: label, Dataset (key), Subject, Date (day), Session, Tags (";"-joined). Units add unitId, class ("su", "mua", "det", ...), channel, channelName, shank, x, y, nSpikes, and nSites/sites when merged. Channels add channel, shank, x, y, units. A column that some datasets lack is missing (missing/NaN) in their rows. |
| `R.t` | double column, nTime | Times along data's second dimension, in s from the event. For spikes these are bin centers (auROC window centers for auroc); for signals, sample times. |
| `R.groupLabels` | column, nGroups | Labels along data's third dimension, in settings.selection.groupOrder. Numeric when grouped by one parameter that is numeric in every dataset (e.g. Depth), otherwise string: the value's text for one parameter, "Depth = 3, Level = 2" for several. |
| `R.rowKind` | string | "unit" or "channel". |
| `R.valueUnits` | string | The unit of data: "spikes/s", "spikes/bin", "auROC", "uV" or "V"; normalized: "z", "%", "x baseline" or "0-1" ("subtract" keeps the unit). Use it for axis labels. |
| `R.settings` | struct | The settings that made R (see [Settings](#settings)), e.g. R.settings.measure, R.settings.data, R.settings.window.pre. |
| `R.datasets` | table, one row per ticked dataset | key, name, subject, date, status ("done", "cached", "skipped" or "error"), message, nRows, nEpochs, nGroups, seconds. This table answers "why is dataset X missing". |
| `R.keys` | string column | The datasets whose rows are in R, in row order. |
| `R.created` | datetime | When the result was assembled. |
| `R.name` | string | A default name for the result (`B.ResultName`), one identifier made by Compute and kept in the result file: the filter's tags (joined by `_`, by `_or_` with tag mode "any"; without filter tags, the tags every dataset of `R.keys` holds), the event the epochs are aligned to, the responses kept (`AllTrials` without any) and the measure, e.g. `ofc_perceptual_training_StimOnset_Hit_FiringRate`. |
| `R.raw` | double, the size of `R.data`, or `[]` | The values before normalization (`[]` when `settings.normalize.method` is `"none"`). |
| `R.normalization` | struct | How `R.data` was normalized: `method` (the one applied), `baseline`, `scope`, `rawUnits`, `center` and `scale` (`R.data = (R.raw - center) ./ scale`), `undefined` (logical [nRows x nGroups]: NaN for a zero or flat baseline), `nBaseline` (the times of `R.t` in the baseline). |
| `R.labels` | struct of strings | Axis labels, legend text and a one-line description of R, in words (see [Labels](#labels)). |
| `R.epochs` | struct column, one per dataset of `R.keys`, or `[]` | Each epoch before any average, with `settings.keepEpochs` (see [Each epoch](#each-epoch-repochs)); `[]` without. |

Notes on the fields:

- `Subject` and `Date` come from `subjectAndDate`: the subject from the
  dataset's name (the project's name pattern); the date is the day the
  recording started (the project's `AcqDate`) when that is known, else the
  date in the name. The browser's table gives the same.
- `Session` is each subject's datasets numbered 1, 2, ... by date, counting
  only the datasets that contribute rows (as the script does): the rank of
  the dataset's date among them, so two datasets of one day share a number.
  A NaT date gives NaN.
- Group labels: NaN is treated as one label. The groups are ordered by
  `selection.groupOrder`: `"ascending"`, `"descending"` (reverses it) or
  `"appearance"` (as first met, dataset by dataset).
  - With one `groupBy` parameter, groups are matched by label, and the label
    is the bare value. It is numeric only when every dataset's values are
    numeric (ascending: up, NaN last). Otherwise every label is text,
    `string(value)` for a number (`"3"`, `"0.5"`, `"NaN"`), so a dataset
    whose Depth is numeric and one whose Depth is text line up. Text sorts
    alphabetically; with numbers and text mixed, the labels that read as
    numbers come first, by value.
  - With several parameters, groups are matched by their values and ordered
    parameter by parameter, the first parameter first (Depth 9 before Depth
    10, ascending). The labels are text, `"Depth = 9, Level = 2"`.
- `R.datasets` lists every ticked dataset, including those that gave no rows.
  A dataset with nothing to compute is `"skipped"` (no sorting, no such
  signal, no epochs, no modulated unit) and its `message` says why; any other
  error is `"error"`.
- A time base that differs between datasets (different bins or signal rates)
  raises `epochMatrix:TimeBase`, naming the datasets.

### Each epoch (`R.epochs`)

`R.data` holds averages. To work with single trials (decoding, trial-by-trial
variability, your own statistics), tick **Keep single trials, not just averages (R.epochs)** above
**Compute**, or set `keepEpochs=true`, and compute. `R.epochs(k)` is
dataset `R.keys(k)`'s:

| Field | Holds |
| --- | --- |
| `key`, `name` | the dataset |
| `rows` | its rows of `R.rows` and `R.data` (indices) |
| `E` | its epochs: `epochTable`'s table (`trial`, `t0`, `t0Continuous`, `groupIndex`, `group`, the `groupBy` parameters, ...), plus `resultGroup`, the epoch's group in `R.groupLabels` (data's third dimension) |
| `spikes` | spikes: `spikes(i)` for the dataset's i-th row has `times` (s from the event, inside the window's whole bins) and `epoch` (each spike's row of `E`). `[]` for signals |
| `data` | signals: single `[nRows x nTime x nEpochs]`, `data(row, time, epoch)` at `R.t`, each epoch after **Detrend**, **Baseline**, **Magnitude** and **Rectify** (what is averaged). Its third dimension follows `E`'s rows; the epochs off the signal or not finite are left out of both. `[]` for spikes |

The values are never normalized. The mean of a group's epochs is `R.data` for
signals, and for measure `count` the spike counts binned per epoch average to
`R.data`:

```matlab
B.Settings = epochMatrixSettings(B.Settings, keepEpochs=true);
R = B.compute();
e = R.epochs(1);                               % the first dataset
% LFP: the epochs of the first group, rows x time x epochs
X = e.data(:, :, e.E.resultGroup == 1);
% spikes: a trials x bins count matrix of the dataset's first unit
edges = [R.t - R.settings.binSec/2; R.t(end) + R.settings.binSec/2];
sp = e.spikes(1);
C = zeros(height(e.E), numel(R.t));
for j = 1:height(e.E)
    C(j, :) = histcounts(sp.times(sp.epoch == j), edges);
end
```

### Trial rasters

With epochs kept, the result can be looked at row by row, trial by trial.
`B.showRasters(row)` opens a window on one row of the result:

| Part | Shows |
| --- | --- |
| the heading | the row's label and its dataset, the result in words (`R.labels.description`) and the epochs per group |
| **◀ Previous**, the row list, **Next ▶** | the row drawn: every row of `R.rows`, as *12  u37  (dataset name)* |
| **Order** | *by group* (default): each group's epochs together, in `R.groupLabels`' order, each group labeled at the left and banded in its color; *by time*: every epoch in time order, each one in its group's color |
| the upper axes | a unit: its raster, a tick for each spike on its epoch's line. A channel: its epochs as an image, one line per epoch, the raw unit on the color bar (the epochs are never normalized). Time 0 is dotted |
| the lower axes | the row's trace in each group, `R.data(row, :, g)`, in the groups' colors (normalized when the result is) |

The axes zoom and pan with their toolbar. The window follows every new result
(a **Compute**, a **Normalize** change, a restore) and keeps its row while the
result has it; a result without epochs is said in red. It closes with the
browser. Before a result it raises `DatasetBrowser:NoResult`; with a result that
keeps no epochs, it says to tick **Keep single trials** and compute.

A script gets the same, one row at a time, with `X = B.raster(row)`
(`epochMatrixRaster(R, row)`, [source](../analysis/epochMatrixRaster.m); the
window is [`TrialRaster`](../analysis/TrialRaster.m)):

| Field of `X` | Holds |
| --- | --- |
| `row`, `label`, `key`, `name`, `rowKind` | the row, its dataset, `"unit"` or `"channel"` |
| `order` | `"group"` (default) or `"time"` (`B.raster(row, Order="time")`) |
| `t`, `window` | `R.t`; `[pre post]` s |
| `groupLabels`, `groupNames` | `R.groupLabels`; a label per group as text (`R.labels.groups`) |
| `E` | the dataset's epochs (`R.epochs(k).E`, with `resultGroup`) in `X`'s order, plus `epochRow`, the epoch's row of `R.epochs(k).E`. Row `j` of `E` is line `j` of the raster |
| `nPerGroup` | the epochs in each group |
| `times`, `trial` | spikes: each spike's time from the event and its row of `X.E` |
| `counts` | spikes: `[nEpochs x nTime]` spike counts in the bins of `R.t`, binned as `spikePSTH` bins them (whole `binSec` bins with an edge at the event); for measure `count`, a group's mean is its trace in `R.data` (before normalization). `[]` for measure `auroc` |
| `data` | signals: `[nEpochs x nTime]`, each epoch's trace at `R.t`, what is averaged (for statistic `mean`, a group's mean is its trace in `R.data` before normalization) |
| `units` | the unit of `data` (`"s"` for spikes) |

```matlab
X = B.raster(12);                     % row 12 of B.Result
plot([X.times X.times].', [X.trial - 0.4 X.trial + 0.4].', 'k');
set(gca, 'YDir', 'reverse'); xlabel(B.Result.labels.time); ylabel("Epoch")
```

Parts with epochs are kept under their own cache name
(`"epochMatrix/<data>/epochs"`), so turning the option on computes every
dataset once more, and turning it off again reuses the parts without epochs.
Signal epochs are large (2 s at 1 kHz over 32 channels and 300 trials is
about 77 MB per dataset) and go into the result file with the kept parts.
`R.epochs` itself is left out of the file's `result`, and a restore assembles
it again from the kept parts. If the parts are gone (`forget`), the result
comes back without its epochs, with the warning
`DatasetBrowser:BadResultFile`: compute again.

### Normalization

`settings.normalize` normalizes each row's trace in `R.data` against its own
values. It is applied after the parts are assembled, by
`epochMatrixNormalize` ([source](../analysis/epochMatrixNormalize.m)), so
it is not in the cache identity: a change to it computes no dataset again,
and the browser normalizes its result again in place. In the formulas, `b`
and `SD` are the mean and standard deviation of the trace's values at the
times of `R.t` inside `normalize.baseline` (default [-0.5 0] s; missing
values ignored).

| `method` | `R.data` | `R.valueUnits` |
| --- | --- | --- |
| `"none"` (default) | the values as computed | the measure's |
| `"subtract"` | x - b | the measure's |
| `"ratio"` | x / b | "x baseline" |
| `"percent"` | 100 (x - b) / \|b\| | "%" |
| `"zscore"` | (x - b) / SD | "z" |
| `"minmax"` | (x - min) / (max - min), over the whole window | "0-1" |

`normalize.scope` is `"row"` (default: one baseline, or one range, per row
from all its groups, so the groups keep their differences) or `"group"` (each
group its own).

- The SD is over the baseline's bins (spikes) or samples (signals) of the
  group's mean trace, not over the epochs: it shrinks with more epochs and
  grows with narrower bins. `spikePSTH`'s `BaselineMode` `"zscore"`, which
  the analysis app's PSTH panels use, takes the SD over the epochs instead.
- Where `b` is 0 (ratio, percent), the SD is 0 (zscore), the trace is flat
  (minmax) or no baseline value is finite, the row is NaN in that group (with
  scope `"row"`, in every group) and `R.normalization.undefined` marks it.
  The browser's summary counts these rows.
- A result of measure `"auroc"` is not normalized: `R.normalization.method`
  is `"none"`, while `R.settings.normalize` keeps what was asked.
- `R.raw` holds the values before normalization, so normalizing again never
  stacks. A script can normalize any result itself:

```matlab
Rz = epochMatrixNormalize(B.Result, struct('method', "zscore", 'baseline', [-1 0]));
Rn = epochMatrixNormalize(Rz, struct('method', "none"));   % the raw values again
```

### Labels

`R.labels = epochMatrixLabels(R)`
([source](../analysis/epochMatrixLabels.m)) describes the result from its
settings, group labels and value unit, so a script need not spell them out.
`epochMatrix` stores it on every result; the browser makes it again for a
result it restores from the [result file](#the-cache-and-the-result-file), so
a restored result has the current wording. Every field is a string; `groups`
is a column.

| Field | Holds | Example |
| --- | --- | --- |
| `value` | the axis or color-bar label of `R.data`. For signals, "Rectified " or " magnitude" is added when those options are on | "Firing rate (spikes/s)", "Spike count (spikes/bin)", "auROC vs. baseline", "LFP, mean over epochs (uV)" |
| `measure` | the quantity without its unit, for titles | "Firing rate", "auROC", "LFP mean" |
| `time` | the label of `R.t`, from the event the epochs are aligned to (`eventRef.alignStep`) | "Time from Stim onset (s)" |
| `aligned` | that event alone | "Stim onset" |
| `event` | the whole event reference (`eventRefLabel`) | "Stim onset then Platform offset (aligned to Stim onset)" |
| `group` | the `groupBy` parameters ("" without `groupBy`) | "Depth", "Depth, Level" |
| `groups` | a label per group of `R.groupLabels`, in its order | "Depth 3" for one parameter; the label itself ("Depth = 3, Level = 2") for several; "All trials" without `groupBy` |
| `rows` | what a row of `R.data` is, plural | "units", "detected channels", "LFP channels" |
| `trials` | the trials kept | "Hit trials", "Hit or Miss trials where Depth > 0", "all trials" |
| `window` | the epoch window | "-1 to 1 s" |
| `bins` | the bin width (spikes; "" for signals) | "10 ms bins" |
| `baseline` | the auROC's baseline, or the signal's subtracted one ("" without one) | "baseline -0.5 to 0 s", "baseline -0.2 to 0 s subtracted" |
| `normalization` | the [normalization](#normalization) in words, with ", per group" for scope `"group"` ("" without one). `value` then names it too: "Firing rate (z-score vs. baseline)", "Firing rate - baseline (spikes/s)", "Firing rate / baseline", "Firing rate (% change from baseline)", "Firing rate (min-max normalized)" | "z-scored against the baseline -0.5 to 0 s", "scaled 0 to 1 over the window" |
| `description` | one line of the above, for a subtitle or a caption | "Firing rate of units in 10 ms bins, -1 to 1 s from Stim onset; Hit trials by Depth (descending)" |

```matlab
R = B.Result;
imagesc(R.t, 1:height(R.rows), R.data(:, :, 1));
xlabel(R.labels.time); title(R.labels.groups(1)); subtitle(R.labels.description)
cb = colorbar; cb.Label.String = R.labels.value;
```

## Settings

`epochMatrixSettings` ([source](../analysis/epochMatrixSettings.m)) holds the
defaults, overlays a struct or a file on them, checks the result and gives
its cache identity. `S = epochMatrixSettings()` gives the defaults;
`S = epochMatrixSettings(S0, Name=Value)` overlays the struct `S0` (or `[]`,
or the path of a settings file) and then the options. A struct option (`ref`,
`window`, `selection`, `units`, `signal`, `auroc`, `normalize`) is merged field by field
over the value it replaces, so `units=struct('shanks', 1:2)` keeps the other
unit fields; any other option replaces its field.

| Field | Meaning |
| --- | --- |
| `data` | what is computed: `"units"` (default; the sorted units of the sorting folder), `"detected"` (the Spikes step's threshold detections, one train per channel), `"LFP"`, `"MUA"`, `"SPIKE"` or `"AUX"` (a derived signal) |
| `ref` | `eventRef`: the event each epoch is aligned to |
| `window` | `epochWindow`; its mode must be `"fixed"` (default [-1 1] s) |
| `selection` | `trialSelection`: the trials kept and their groups |
| `units` | spikes: `UnitSelection` (`selectUnits`); its source is set from `data`; `classes` defaults to empty, meaning every class (not `UnitSelection`'s `["su" "mua"]`) |
| `measure` | spikes: `"rate"` (default; spikes/s), `"count"` (spikes per bin per epoch) or `"auroc"` (each auROC window against the baseline) |
| `binSec` | spikes: the bin width, s (default 0.01); at least one whole bin, edged at the event, must fit in [pre post] (`spikePSTH`) |
| `baseline` | spikes: [b0 b1] s from the event, the auROC's baseline (default [-0.5 0]; b0 < b1 with measure `"auroc"`) |
| `auroc` | spikes: the Auroc section (`aurocCurves`' settings), with `cutoff` `"none"` by default |
| `normalize` | every kind: a struct of `method` (`"none"` default, `"subtract"`, `"ratio"`, `"percent"`, `"zscore"` or `"minmax"`), `baseline` ([b0 b1] s, b0 < b1; default [-0.5 0]; must overlap the window for a method that uses it) and `scope` (`"row"` default, or `"group"`). Applied after assembly, so not in the cache identity; see [Normalization](#normalization) |
| `keepEpochs` | every kind: `false` (default) or `true`, keep every epoch in `R.epochs` ([Each epoch](#each-epoch-repochs)). In the cache identity only when `true`, with parts kept under `"epochMatrix/<data>/epochs"` |
| `signal` | signals: a struct of `channels` (recording channels kept, 1-based: the probe map's `chanMap` + 1, as `units.channels`; for AUX its 1-based columns; `[]` = all), `shanks` (probe shanks kept; `[]` = all; not used for AUX), `baseline` ([b0 b1] s: each epoch's mean over it is subtracted per channel; `[]` = none), `detrend` (remove each epoch's linear trend; false), `rectify` (the absolute value before the average; false), `magnitude` (the channels' vector magnitude, one row, e.g. AUX's accelerometer; false) and `statistic` (`"mean"` default, or `"median"`) |

Fields that do not apply to `data` are kept in `S`, unchecked beyond their
form, and left out of the cache identity, so a change to an LFP option keeps
the cached spike results. `normalize` is left out of it too.

**Settings files** are JSON: `{"schema": "epoch-matrix-settings", "version":
1, "settings": {...}}`, with non-finite numbers written as the strings
`"Inf"`, `"-Inf"` and `"NaN"`. The browser's files also hold its
[event & trial definitions](#event--trial-definitions) as `"definitions"`
beside `"settings"`, a list of `{name, ref, window, selection}`;
`epochMatrixSettings` reads the settings and leaves them alone. A definition
that does not check is left out with the warning
`DatasetBrowser:BadDefinition`. Write one with
`epochMatrixSettings(S, SaveAs="ofc_hit_depth.json")`, **File > Save
settings** or `B.saveSettings(file)`; read one with `epochMatrixSettings(file)`,
`DatasetBrowser(root, Settings=file)`, **File > Load settings** or
`B.loadSettings(file)`. The last file loaded or saved is `B.SettingsFile`
(kept in the result file); its folder is where the file dialogs open
(preference `SettingsFolder`), and it heads **File > Recent settings**.

`[S, ID] = epochMatrixSettings(...)` also returns the cache identity `ID`:
`data`, `ref`, `window`, `selection`, the fields that apply to `data` and a
`version` of the part builders. A change to what the part builders compute
bumps that version (`PartVersion` in `epochMatrixSettings`), so results
cached by old code are computed again.

## The cache and the result file

**Per-dataset parts.** `epochMatrix` computes one part per dataset and keeps
it in a `DatasetRuns` ([source](../analysis/DatasetRuns.m), `B.Runs`) under
the name `"epochMatrix/" + data` (`+ "/epochs"` with `keepEpochs`; the third
output of `epochMatrixSettings`). A part is reused only while its identity is
unchanged. The identity is

- the settings: the cache identity above, so a dataset is computed again when
  a setting that applies to `data` changes; and
- a stamp of the dataset's output files, [`outputsStamp`](../analysis/outputsStamp.m):
  one line per file, "kind, name, size, modification time". It covers the
  files `DatasetOutputs.refresh` found of the kinds extract (the signal
  files), spikes, behavior, manifest and artifacts, the names of the spikes
  and extract files in effect, and, from one listing of the sorting folder,
  `params.py`, `spike_times.npy`, `spike_clusters.npy`, `spike_templates.npy`,
  `channel_map.npy`, `channel_positions.npy`, `channel_shanks.npy` and every
  `cluster_*.tsv`. Only file names go in, not folders, so copying or moving
  the outputs with their times keeps the stamp. Re-sorting a dataset or
  curating it in phy invalidates its cached parts. The pipeline rewrites the
  manifest after each output, so any step run again does too, and so does a
  tag edit (the manifest is rewritten): that dataset is computed again.

A part (or a "skipped" result) is reused only while both the settings and the
stamp are unchanged. If either differs, the **Cached** column shows `old` and
the dataset is computed again (a "skipped" one is tried again).

**The browser takes the stamps at Scan.** Press **Scan** again after
re-sorting or phy curation, or the browser does not see the change. The
stamp does not see a file rewritten with the same size and modification
time, or a file outside the outputs, such as a probe `.json` edited in place
(processing the dataset again with a new map rewrites the manifest, which is
seen).

A new dataset is computed; a ticked dataset already current is reused
(status `"cached"` in `R.datasets`, with no I/O). A dataset with nothing to
compute is kept as `"skipped"`. Any other error is not kept: the dataset
shows `"error"` with the warning `DatasetRuns:DatasetFailed`, and is tried
again next time.

**Recompute and Forget.**

- `B.compute(Recompute=true)` computes every ticked dataset again. It drops
  the old entries first, so a canceled or failed recompute never leaves old
  results to be reused.
- `B.forget(NAME, KEYS)` drops the kept parts of those datasets under that
  name; `B.forget(NAME)` all of a name; `B.forget()` everything. A call with
  an empty key list drops nothing. `B.forgetTicked()` (the table's context
  menu, **Forget cached (ticked)**) drops the ticked datasets' parts for the
  current **Data**; with nothing ticked it does nothing and the status line
  says so.

**The result file.** `<root>\DatasetBrowser_results.mat` (or `ResultFile=`).
It is a `-v7.3` MAT-file, written through a temporary file and then moved over
the old one. It holds

| Variable | Contents |
| --- | --- |
| `schema`, `version` | `"dataset-browser-results"`, 1 |
| `browser` | the browser's state: `root`, `outputRoot`, `namePattern`, `recordings`, `ticked` (keys), `filter` and `settings` |
| `result` | `B.Result` (`[]` before a compute); its `labels` are made again on restore, and its `epochs` are left out and assembled again from `runs` |
| `runs` | `B.Runs.toStruct()`: every kept part and `forEach` value, each with its identity, status, message, seconds and the time it was made |

It is written after a `compute` or `forEach` that added parts (a canceled one
too, so the finished parts survive), on `done`, and on close, when the state
changed. A root that cannot be written keeps everything in memory, with the
warning `DatasetBrowser:NotSaved` (once). A file that cannot be read, or a
part of it that does not check, warns `DatasetBrowser:BadResultFile` and
leaves that part at its default. A result file whose cache is from an older
`DatasetRuns` version restores with an empty cache and the warning
`DatasetRuns:OldVersion`: the parts are computed again.

`DatasetBrowser(root, Scan=false)` reads only this file, so `B.Result` is
available without the share being reachable. `B.restore(file)` takes the
state of another result file.

## `forEach`

`forEach` runs your own per-dataset function with the browser's progress,
cancel and cache:

```matlab
[values, T] = B.forEach(@(src) height(src.trials));
[values, T] = B.forEach(@(src, info) nnz(src.units.class == "su"), Name="nSU", Datasets=B.Shown);
```

`FN(SRC)` or `FN(SRC, INFO)` gets the dataset's analysis source (and its row
of the datasets table). `values` is a cell array, one value per dataset (`[]`
where skipped, failed or canceled); `T` has `key`, `name`, `status`
(`"done"`, `"cached"`, `"skipped"`, `"error"` or `"canceled"`), `message` and
`seconds`. The options:

| Option | Meaning |
| --- | --- |
| `Name` | the cache name (default `"forEach/" + func2str(FN)`) |
| `Id` | the identity of what `FN` computes |
| `Datasets` | keys (default: the ticked ones) |
| `Recompute` | true: compute every dataset again |
| `SkipIds` | error ids that mean "nothing to compute"; such a dataset is kept as skipped |

- **Caching.** A dataset's value is reused while the name and the identity
  are the same, as for the parts above. The values go into the result file.
- **When `Id=` is needed.** The default identity is `FN`'s text and, for an
  anonymous function, the values it captured. If `FN` captured a value that
  `jsonencode` cannot write (a handle, another function), the call raises
  `DatasetRuns:NeedId`: pass `Id=` (anything `jsonencode` takes), and change
  it when what `FN` computes changes.
- **After code edits.** Edits to code that `FN` calls do not change the
  identity. Pass `Recompute=true` once after such an edit.
- A cancel raises `DatasetRuns:Canceled`; the values finished stay.

## Preferences

Saved on close under the `AppPrefs` group `DatasetBrowser`:

| Name | Holds |
| --- | --- |
| `Root` | the last project root (used when `DatasetBrowser()` is called without one) |
| `NamePattern` | the last name pattern |
| `Position` | the window's position and size |
| `Sort` | the table's sort (column and direction) |
| `SettingsFolder` | the folder of the last settings file loaded or saved |
| `RecentSettings` | **File > Recent settings**: the last 10 settings files loaded or saved |
| `Workers` | the process workers **Compute** and `forEach` use |
| `OnTop` | **Keep on top** |
| `Scripts`, `Script` | the [post-processing scripts](#the-post-processing-script) listed and the one picked (with none saved yet: the scripts in `analysis/scripts`) |
| `ScriptAfterCompute` | **Run it after each Compute or Load** |
| `ScriptFolder` | the folder of the last script added (where **+** opens) |

## Errors and warnings

| Id | Raised when |
| --- | --- |
| `DatasetBrowser:NoRoot` | the root cannot be reached on a scan |
| `DatasetBrowser:NotScanned` | a method needs the scan's datasets and there are none |
| `DatasetBrowser:NoneTicked` | `compute` or `loadSessions` with no dataset ticked |
| `DatasetBrowser:UnknownDataset` | a key, name or index that is no scanned dataset |
| `DatasetBrowser:BadValue` | a form control that does not exist, or a typed number or range (`1:4`) that does not parse |
| `DatasetBrowser:BadFilter` | a filter option that does not fit |
| `DatasetBrowser:NoFile` | a settings file was asked for and none was passed |
| `DatasetBrowser:NoDefinition` | `useDefinition` or `removeDefinition` with a name that is no definition |
| `DatasetBrowser:Canceled` | `checkCancel` after **Cancel**; a scan canceled |
| `DatasetBrowser:NoScript` | `runScript` or `editScript` with no script picked, a script file not found, or `addScript` given a file that is no `.m` file |
| `DatasetBrowser:ScriptFailed` | the post-processing script raised an error (the message names the script and its line) |
| `DatasetBrowser:NoResult` | `showRasters` or `raster` before a result |
| `epochMatrixRaster:NoEpochs` | `showRasters`, `raster` or `epochMatrixRaster` on a result computed without **Keep single trials** |
| `epochMatrixRaster:BadRow`, `:BadResult` | a row that is not a row of the result; a result that is not `epochMatrix`'s |
| `epochMatrix:Canceled` | `compute` after **Cancel** (the finished parts stay in `Runs`) |
| `DatasetRuns:Canceled` | `forEach` after **Cancel** (the finished values stay) |
| `epochMatrix:NoData` | no dataset gave rows (the message lists why) |
| `epochMatrix:TimeBase` | the datasets' `t` differ |
| `epochMatrix:UnknownDataset`, `:BadSource`, `:BadPart` | a dataset not in the runner; a source that is not a runner, config or list of parts; a malformed part |
| `epochMatrixSettings:UnknownField` | a setting that has no place |
| `epochMatrixSettings:BadValue` | a value that does not fit, or a file that is no settings file |
| `DatasetRuns:NeedId` | `forEach` without `Id=` over a value `jsonencode` cannot write |
| `DatasetRuns:BadSource`, `:BadStruct` | a bad run source; a bad saved struct |
| `datasetFilter:BadSize` | the filter's inputs differ in length |
| `TagSet:BadMode` | a `TagMode` that is neither `"any"` nor `"all"` |

Warnings: `DatasetBrowser:NotSaved` (the result file cannot be written),
`DatasetBrowser:BadResultFile` (a result file or a part of it is not used),
`DatasetBrowser:BadDefinition` (a definition in a settings or result file
that does not check is left out),
`DatasetRuns:OldVersion` (kept results of an older `DatasetRuns` version are
not restored) and `DatasetRuns:DatasetFailed` (a dataset failed and is left
out).

## Where the code is

| Part | File |
| --- | --- |
| the window and the handle | [`DatasetBrowser.m`](../analysis/DatasetBrowser.m) |
| the compute and its result | [`epochMatrix.m`](../analysis/epochMatrix.m) |
| one dataset on its own clock (**Load whole sessions**) | [`sessionData.m`](../analysis/sessionData.m) |
| the settings, their checks and cache identity | [`epochMatrixSettings.m`](../analysis/epochMatrixSettings.m) |
| the result's labels and description in words | [`epochMatrixLabels.m`](../analysis/epochMatrixLabels.m) |
| the normalization of a result | [`epochMatrixNormalize.m`](../analysis/epochMatrixNormalize.m) |
| one row of a result trial by trial; its window | [`epochMatrixRaster.m`](../analysis/epochMatrixRaster.m), [`TrialRaster.m`](../analysis/TrialRaster.m) |
| the **Epochs per group** window (also the analysis app's Alignment tab bars) | [`EpochGroupCounts.m`](../analysis/EpochGroupCounts.m) |
| the per-dataset cache and run engine | [`DatasetRuns.m`](../analysis/DatasetRuns.m) |
| the stamp of a dataset's output files (names, sizes, times) | [`outputsStamp.m`](../analysis/outputsStamp.m) |
| the subject, tag and text filter (also the analysis app's Data tab) | [`datasetFilter.m`](../analysis/datasetFilter.m) |
| the sorted table | [`TableSort.m`](../pipeline/TableSort.m) |
| the clickable probe of the Channels tab | [`ProbePicker.m`](../analysis/ProbePicker.m) |
| the time left | [`ProgressClock.m`](../pipeline/ProgressClock.m) |

## Tests

| Suite | Covers |
| --- | --- |
| [`test_DatasetFilter.m`](../analysis/test_DatasetFilter.m) | `datasetFilter`: subjects, wildcards and literal regex characters, tags, search, the combinations |
| [`test_DatasetRuns.m`](../analysis/test_DatasetRuns.m) | `DatasetRuns`: reuse, identity, skipped and failed datasets, cancel, `forget`, the saved struct |
| [`test_EpochMatrix.m`](../analysis/test_EpochMatrix.m) | `epochMatrixSettings` and `epochMatrix`: the parts against the per-dataset calls, assembly, groups, the result fields, the labels, the normalization (`epochMatrixNormalize`) |
| [`test_DatasetBrowser.m`](../analysis/test_DatasetBrowser.m) | the browser, headless and with its window: scan, filter, ticks, the form, compute, `forEach`, progress and cancel, the result file, the trial rasters (`raster`, `epochMatrixRaster`, the window), the exported script (`exportScript`), the whole sessions (`loadSessions`, `sessionData`), the Channels tab (`ProbePicker`: clicks and fields yoked), the event & trial definitions, the **Epochs per group** window (`EpochGroupCounts`: its groups, epochs and trials against `epochTable`, the excluded epochs, a settings edit and a row click redraw it) |
