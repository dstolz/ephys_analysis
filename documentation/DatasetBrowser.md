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
one more dataset computes only that one, and the data a **Compute** reads stay
in memory ([Loaded data](#loaded-data)), so another event, window or trial
selection (Hit, then Miss) reads no file again.

This page is the reference for every control and for scripts. New to the
browser? Start with the [dataset browser guide](dataset-browser-guide.md).

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

While the window opens, a small startup window (the name, the version with the
commit's date and time, and a progress bar) shows the steps: the window is built hidden, the last session restored and
the root scanned, then the browser appears. `Splash=false` starts without it
(the default with `Visible=false` and under `-batch`).

`B.OnTop` (the **Keep on top** checkbox) is settable at any time; its default is the last one set, else `false`.

On opening, the ticks, filter, settings and result saved in the result file
are restored, unless the options set them. With no saved state, the first scan
ticks what the filter shows. A root that cannot be reached raises
`DatasetBrowser:NoRoot`.

## The window

The window (1380 x 860 pixels, its position remembered) has a **File** menu,
a **Cache** menu, a **Help** menu and four rows.

The **File** menu holds the [settings files](#settings):

| Item | Does |
| --- | --- |
| **Load settings...** (Ctrl+O) | reads a settings file (`B.loadSettings()`) |
| **Recent settings** | the last 10 settings files loaded or saved, newest first (`B.RecentSettings`, preference `RecentSettings`); one that no longer exists stays listed, grayed, with *(not found)*. **Remove from list** drops one file from the list (`B.removeRecent(file)`), **Clear list** drops them all (`B.clearRecent()`); the files themselves stay |
| **Save settings** (Ctrl+S) | writes the settings to the settings file (`B.SettingsFile`, the one last loaded or saved, named above the form); with none yet, it asks for one as **Save settings as...** does (`B.saveSettings()`) |
| **Save settings as...** | writes the settings to a file picked in a dialog (`B.saveSettingsAs()`) |
| **Export compute script...** | writes a script that computes these settings on the ticked datasets without the window ([Export a script](#export-a-script); `B.exportScript()`) |
| **Close** | closes the window, as its close button does |

The **Cache** menu says what is kept between runs, so a change of settings
reads and computes as little as it can ([Caching](#caching); `B.Caching`,
preference `Caching`). Each item with a check mark is on or off; all are on
but **Keep data loaded by Raw Data**:

| Item | When on | `B.Caching` field |
| --- | --- | --- |
| **Reuse computed results** | a dataset whose results for these settings are kept is not computed again. Off: every **Compute** (and `forEach`) computes every ticked dataset again | `Results` |
| **Keep results of earlier settings** | each dataset keeps the results of its last 5 settings, so going back (Hit, Miss, then Hit again) computes nothing. Off: only the last settings' results are kept | `Earlier` |
| **Save computed results in the result file** | the results go into the [result file](#the-cache-and-the-result-file), so they are there after a restart. Off: a smaller file, and the results are computed again after a restart | `SaveResults` |
| **Keep loaded spike data in memory** | the spike times and units read from disk stay in memory | `Spikes` |
| **Keep loaded signals in memory** | the LFP, MUA, SPIKE and AUX signals read from disk stay in memory (up to GBs per dataset) | `Signals` |
| **Memory for loaded data** | a submenu: 1, 2, 4, 8, 16, 32 or 64 GB, the most the loaded data may take (default: a quarter of the computer's memory) | `LimitGB` |
| **Keep data loaded by Compute** | **Compute** keeps what it reads | `Compute` |
| **Keep data loaded by Raw Data** | **Raw Data** and **Trials Only** keep what they read (off by default: `B.Sessions` holds those data already) | `RawData` |
| **Keep data loaded by scripts (forEach)** | a script's `B.forEach` keeps what it reads | `Scripts` |
| **Compute here while the data fit (not on workers)** | with [Workers](#workers), **Compute** and **Raw Data** read the datasets here until the memory is full, so the data stay for the next run | `Here` |
| **Loaded: 1.2 GB in 12 datasets** | (grayed) what the loaded data take now | |
| **Clear loaded data** | frees that memory; the next run reads from disk (`B.clearLoadedData()`) | |
| **Forget all computed results** | drops every dataset's kept results, for every setting (`B.forget()`) | |

The **Help** menu:

| Item | Does |
| --- | --- |
| **Help for DatasetBrowser** | opens this page's wiki page (`Dataset-Browser`) in the browser |
| **Keyboard shortcuts and right-click menus** | a small window that lists the keys (Ctrl+O, Ctrl+S), what a click on the table does and what its right-click menu does (`B.showShortcuts()`) |
| **Documentation home** | opens the wiki's front page |
| **About DatasetBrowser** | shows the version of the code (release number, git commit, branch, date, uncommitted changes), the MATLAB release, the last commit of `DatasetBrowser.m`, `epochMatrix.m` and `DatasetRuns.m`, the versions of the result file and of the cache, and the root, the number of datasets found and the settings file. **Copy** puts the text on the clipboard, for an issue; `B.aboutText()` returns the part particular to the browser |

The rows:

1. **Project root** (a field and **Browse...**) and **Pattern**, with **Scan**.
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
[`datasetFilter`](../pipeline/datasetFilter.m), the same filter, with the same
controls, as the analysis app's [Data tab](EphysFigGenApp.md#data-tab). (There
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
right-click menu has **Open manifest viewer**, **Edit tags...**, **Edit tags
(ticked)...**, **Clear sort**, **Forget cached (ticked)** and **Details of the
last run...** (a one-line hint under the table says so). Clicking a row makes
it the dataset the form's lists are read from; clicking its **Tags** cell
edits its tags ([Editing tags](#editing-tags)).
**Open manifest viewer** (also **File → Open manifest viewer**) shows that
dataset's manifest in a `ManifestViewerApp` window; `B.viewManifest(KEY)` does
the same for the dataset with that key and returns the viewer. A dataset
without a manifest on disk is named in the status line.

| Column | Shows |
| --- | --- |
| **Use** | tick to include the dataset in **Compute**; the only column you can edit |
| **Name**, **Key** | the dataset's name and its project key |
| **Subject**, **Date** | from `subjectAndDate`, the same function and inputs `epochMatrix` uses, so the table and `R.rows` agree: the subject from the name pattern; the date is the acquisition date (the day the recording started) when known, else the date in the name |
| **Tags** | the manifest's tags; click the cell to edit them |
| **Units**, **Detected**, **Behavior** | a check mark when the sorting, the spikes file or the behavior file exists |
| **Signals** | the derived signals the dataset has (`LFP`, `MUA`, `SPIKE`, `AUX`) |
| **Cached** | the dataset's part for the current **Data** and settings: `✓ 62 units` (kept and current; the units, or for signals the channels, the dataset adds to the result: one matrix row each, so `✓ 8 channels` for signals), `skipped: no sorted units` (nothing to compute, with the reason; kept so), `error` (the last **Compute** failed on it with these settings and outputs: tried again next time), `old` (kept, but either the settings or the stamp of the dataset's output files differ: computed again next time), or blank. A `skipped` or `error` cell is in red text; **Details...** has the whole message. With several kinds of **Data** ticked: `✓ 62 units, 32 LFP` once every kind is kept and current (a kind the dataset lacks reads `AUX skipped`), `old` when one kind is, `skipped: <reason>` when all are, else blank. The whole row is tinted to match: pale green (cached), pale yellow (`old`), pale red (`skipped` or `error`), none (blank) |

#### Editing tags

The browser edits the tags it filters by, so a group can be tagged where it
is picked. The tag window is the pipeline app's (`TagDialog`):

| To tag | Do this |
| --- | --- |
| one dataset | click its **Tags** cell: the window shows its tags; pick from the tags in use or type new ones (`cohort-3, pilot`), **OK** |
| several | select their rows (click, Shift+click, Ctrl+click), right-click the table: **Edit tags...**; then **Add to all** or **Remove from all** |
| the ticked datasets | right-click the table: **Edit tags (ticked)...** (filter, **Tick shown only**, then tag them all) |

**OK** writes each new set into the dataset's manifest (`<Name>_manifest.json`,
the one the Tags column reads; for outputs copied to another disk, the copy
beside them) with [`writeManifestTags`](EphysDataset.md#dataset-manifest):
only the manifest's `tags` and `updated` change, and no recording is needed.
The table, the tag filter's lists and the sources already loaded follow at
once, and the status line says what was done (*Tagged 3 datasets: added
cohort-3.*). **Cancel** writes nothing. A dataset an **Add** would take past 12
tags either cancels the whole edit or is left out, as the window's policy
says (kept for the session). The pipeline app, open on the same datasets,
reads the new tags back the next time it writes their manifests.

`B.editTags(KEYS)` opens the window on those datasets and returns it (no
`KEYS`: the rows selected, else the clicked row's dataset); its methods
(`pick`, `addTyped`, `setMode`, `setPolicy`, `ok`, `cancel`) drive it as the
clicks do. From a script, `B.setTags(KEYS, Set=, Add=, Remove=)` changes them
without a window:

```matlab
B.setFilter(Search="SUBJ-ID-1255");
B.setTags(B.Shown, Add="cohort-3");               % add to each
B.setTags("SUBJ-ID-1255_260101", Remove="pilot");  % by key or name
B.setTags(B.Selected, Set=["ofc" "perceptual_training"]);   % the whole set
```

`Set` (the whole set; `""` for none), then `Add`, then `Remove`; tags are a
string array, a cellstr or text separated by commas. Every new set is checked
first and nothing is written unless all fit (`TagSet:Invalid`,
`TagSet:TooMany`, the dataset named); a manifest that cannot be written is
named in `DatasetBrowser:TagsNotWritten` after the others are written.
`OnChange` gets `"tags"`.

A tag edit changes the manifest, which counts in each dataset's stamp
(`outputsStamp`): until the next **Scan** the retagged datasets stay cached;
after it their parts read `old` and **Compute** works them out again, as after
a tag edit in the pipeline app (from the [loaded data](#loaded-data), which a
tag edit keeps). **Compute** takes the new tags into `R.rows`
and `R.name` at once.

#### Editing variables

A dataset's [variables](EphysDataset.md#variables) (a probe depth, a dose)
show in the **Variables** column. A click on a cell opens the variable
window (`VariableDialog`) on that dataset; right-click the table, **Edit
variables...** for the rows selected (else the clicked one) or **Edit
variables (ticked)...**. The window has a row per dataset and a column per
variable (see the [pipeline app](EphysPipelineApp.md#dataset-variables));
**OK** writes each changed dataset's set to its manifest
(`writeManifestVariables`), the table and the sources loaded follow, and the
status line says what changed. Only the latest values are kept; the
manifest notes when each variable changed. Every row of `R.rows` carries its
dataset's values, a `var_<name>` column each.

`B.editVariables(KEYS)` opens the window and returns it; its methods
(`newVariable`, `setLabel`, `setValue`, `fillColumn`, `ok`, `cancel`, ...)
drive it as the clicks do. From a script:

```matlab
B.setVariables(B.Shown, Name="probeDepth", Value=1200, Label="Probe Depth", Units="µm");
B.setVariables("SUBJ-ID-1255_260101", Name="probeDepth", Value=1350);   % by key or name
B.setVariables(B.Selected, Remove="probeDepth");
```

A request that changes nothing writes nothing; a bad name or value errors
before anything is written (`DatasetVariables:BadName`, `:BadValue`); a
manifest that cannot be written is named in
`DatasetBrowser:VariablesNotWritten`. `OnChange` gets `"variables"`. As a
tag edit, a variable edit changes the manifest and so each dataset's stamp.

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
the [Alignment tab](EphysFigGenApp.md#alignment-tab) for each one. The window is always
fixed (`epochMatrix` takes no other mode), so the browser hides the window's
mode and its stop event.

| Control | Sets |
| --- | --- |
| **Data** | `data`: a box per kind, `units`, `detected`, `LFP`, `MUA`, `SPIKE` and `AUX`; tick one or more ([Several kinds of data](#several-kinds-of-data)). Only the blocks of the **Measure** tab that apply are on |
| **Data**: **Downsample...** | `signal.downsample`: a rate per signal in the *Downsample signals* window (also `B.editDownsample()`); see [Downsampling the signals](#downsampling-the-signals). Amber while any signal has a rate |
| **Event** tab: **Event reference** | `ref`: **Line**, **Edge**, **Which** and **n**, **Scope**, **Offset (s)**, **Length (s)**, **Stitch gaps (s)** and **Refractory** (`stitchGapSec`, `refractorySec`: [stitching and the refractory period](EphysAnalysisConfig.md#stitching-and-the-refractory-period)), **Time range (s)**, **Shift by** and its unit, and **Sequence** |
| **Event** tab: **Sequence** **Edit...** | `ref.sequence` and `ref.alignStep` in the *Event sequence* window: any number of steps, each *followed by* or *not followed by* a line's onset or offset (its **n**, **Within (s)**, **Min / Max length (s)**, **Stitch gaps (s)**, **Refractory (s)**), and **Align to** the start or any *followed by* step (aligned to the start, the steps are conditions only). For example *Trial offset then Trough onset*: the first Trough onset after each trial ends. **Apply** checks the steps |
| **Event** tab: **Epoch window** | `window`: **Pre (s)**, **Post (s)**, seconds from the event (a negative **Pre** is before it; a hint under the two says so) |
| **Event** tab: **Epoch Diagram** | opens the *How the epochs are cut* window (`EpochDiagram`, also `B.showEpochs()`) for the dataset the lists come from: the lines, each event picked, the sequence, the windows and the trials kept or dropped. It is redrawn on every settings edit and row click until closed, and closes with the browser |
| **Trials** tab | `selection`: **Filter** (an expression over the trial columns, e.g. `Depth > 0 & ~FA`; **?** lists the columns, words and functions), **Response**, **Pairing** (`pairingFlags`), **Group by** and **and** (one or two trial parameters), **Order**, **Max groups**, **Artifacts** (`excludeArtifacts`, at least `minArtifactSec`) |
| **Trials** tab: **Epochs per group** | opens the *Epochs per group* window (`EpochGroupCounts`, also `B.showGroupCounts()`) for the dataset the lists come from: see [Epochs per group](#epochs-per-group). It is redrawn on every settings edit and row click until closed, and closes with the browser |
| **Measure** tab: **Normalize**, **Baseline (s)**, scope | `normalize`: `method`, `baseline` and `scope` (*per row* or *per group*); see [Normalization](#normalization). A change normalizes the result again in place and computes nothing. Off for measure `auroc` (unless a signal is ticked too); **Baseline (s)** only for the methods that use it |
| **Channels** tab | **Shanks** and **Channels**: `units.shanks` and `units.channels` for `units` and `detected`, `signal.shanks` and `signal.channels` for a signal (blank = all; both with several kinds), also picked by clicking the probe; see [Shanks and channels](#shanks-and-channels) |
| **Measure** tab: **Spikes** block | **Merge neighboring sites** (`units.merge.enabled`, `detected` only), **Measure**, **Bin (ms)** (`binSec`, in seconds, in a script), **auROC baseline (s)** (with measure `auroc`), **Unit classes** (`units.classes`, `units` only: a box each for `su`, `mua`, `uns` and `noise`, `EphysAnalysisConfig.UnitClasses`; tick `su` alone for single units only; none ticked, or all, is every class, `[]`. A class the settings hold that has no box, such as `other`, is named beside the boxes and kept when a box is ticked or unticked; detected channels are all `det` and have no classes) |
| **Measure** tab: **Signals** block | **Baseline (s)**, **Statistic**, **Detrend**, **Rectify**, **Magnitude (AUX)** |
| Above **Compute**: **Keep single trials, not just averages** | `keepEpochs`: the result also keeps every epoch before the average ([Each epoch](#each-epoch-repochs)), which `B.showRasters` draws ([Trial rasters](#trial-rasters)). Every kind of **Data** |

The form does not show every field (the unit quality and response tests, the auROC
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

- the count, as the analysis app's [Alignment tab](EphysFigGenApp.md#alignment-tab)
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

**The Data boxes and the two blocks.** **Data** chooses what is computed,
and with it which block of the **Measure** tab applies:

- `units` (the sorted units of the sorting folder) and `detected` (the Spikes
  step's threshold detections, one train per channel) use the **Spikes** block.
  The result is a rate, a count or an auROC per bin.
- `LFP`, `MUA`, `SPIKE` and `AUX` (derived signals) use the **Signals**
  block. The result is the group mean or median of each channel.

The controls of a block no ticked kind uses are off. A note above the boxes
counts, for each kind ticked, the ticked datasets that cannot give it (*3 of
12 ticked lack LFP (skipped)*, *2 of 12 ticked have no sorting*). A change to
a setting of the other block leaves the kept parts of this **Data** valid.

**Several kinds of data.** Tick more than one box (`B.Settings.data` is then a
string row, e.g. `["units" "LFP"]`, kept in that order) to compute or load
them together, with one event, window, trial selection and normalization:

- **Compute** computes each kind on its own, as `epochMatrix` computes one
  kind at a time (`epochMatrixSettings(S, Kind="LFP")` gives that kind's
  settings), each with its own kept parts. `B.Results` holds a result per
  kind, by kind (`B.Results.units`, `B.Results.LFP`); `B.Result` is the first
  kind's, so a script that reads `B.Result` goes on working. The summary has
  a line per kind (*LFP: 64 channels × 701 samples × 5 groups ...*). A kind
  that no ticked dataset has stops the compute with `epochMatrix:NoData`, its
  kind named (*SPIKE: ...*), and leaves `B.Results` as it was; the kinds
  computed before it stay cached.
- **Raw Data** gives an entry per dataset and kind (see
  [Raw Data](#raw-data)).
- The **Measure** tab's **Spikes** block applies to `units` and `detected`,
  its **Signals** block to the signals.
- The [Channels tab](#shanks-and-channels) is one pick for every probe kind.
  `AUX`, which has no probe, keeps all its columns, and **Magnitude (AUX)**
  applies to `AUX` only.

### Downsampling the signals

**Downsample...**, at the end of the **Data** row, opens the *Downsample
signals* window ([`DownsampleDialog.m`](../analysis/DownsampleDialog.m)). It
has a row per signal, `LFP`, `MUA`, `SPIKE` and `AUX`, each with its own rate:

| Column | Shows |
| --- | --- |
| **Signal** | the signal; bold when its **Data** box is ticked, *(not ticked)* otherwise |
| **On file** | its rate on file in the dataset the lists come from (the clicked row's, else the first ticked); *—* when that dataset lacks it or the root is not scanned |
| **Downsample to (Hz)** | the rate to bring it to; blank keeps the rate on file. A rate at or above the one on file changes nothing |
| **Passes unchanged** | the band that comes through: 0 to 0.38 × the new rate. When the rates on file and the one typed have no small ratio, the rate actually reached is named too |

**OK** puts the rates in the settings (`signal.downsample`, a field per
signal, `[]` = the rate on file) and turns the button amber; its tooltip and
the status line list them (*LFP 250 Hz, MUA 500 Hz*). **Rates on file** blanks
every field, **Cancel** changes nothing, and a field that is not a rate keeps
the window open with the reason. From a script, set the rates in the
settings; signals left out keep their rate on file:

```matlab
B.Settings = epochMatrixSettings(B.Settings, signal=struct('downsample', struct('LFP', 250, 'AUX', 100)));
```

**Compute** and **Raw Data** bring each signal to its rate before anything
else is done with it (the baseline, detrend, rectify, magnitude, the epochs):
`resampleSignal` ([source](../pipeline/resampleSignal.m)) resamples the
channels used with the Signal Processing Toolbox's `resample`. Its
anti-aliasing filter is a linear-phase FIR low-pass (a Kaiser window, n = 10,
β = 8) with its delay taken out, so nothing shifts in time, and the signal
is mirrored past both ends so the first and last samples are not pulled
toward zero. Against the new rate *f*: content up to 0.38 *f* passes within
0.1%, the response is −3 dB at 0.475 *f* and −6 dB at the new Nyquist
frequency *f*/2, and everything above 0.62 *f* is at least 60 dB down. So the
band from 0 to 0.38 *f* is flat and free of aliases: pick a rate at least 2.6
times the highest frequency you study (an LFP studied up to 100 Hz: 260 Hz or
more). Mind a band-passed signal: a `SPIKE` signal of 300–5000 Hz needs
13 kHz or more.

The rate is part of that signal's cache identity, and only that signal's: a
new `MUA` rate keeps the cached `LFP` parts, and a signal with no rate keeps
the parts computed before. The summary names a signal result's rate (*LFP: 16
channels × 176 samples (250 Hz) × 3 groups ...*), and every dataset's parts
are at the same rate when their rates on file are the same (datasets at
different rates on file stop the assembly with `epochMatrix:TimeBase`, as
they would without downsampling).

### Shanks and channels

The **Channels** tab picks the shanks and channels computed with. Its two
fields are the settings of the **Data** chosen: for `units` and `detected`,
`units.shanks` and `units.channels`; for `LFP`, `MUA` and `SPIKE`,
`signal.shanks` and `signal.channels`. Each kind keeps its own picks, so
switching **Data** shows the other kind's. With spikes and a probe signal
ticked together, the fields are one pick for both: an edit sets `units.*` and
`signal.*` alike (they show the first probe kind's). `AUX` ticked with other
kinds keeps all its columns (`epochMatrixSettings(S, Kind="AUX")` clears
`signal.channels` and `signal.shanks` for it).

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

**Compute** computes the ticked datasets with these settings, once per kind
of **Data** ticked. The summary under the button reads *812 units × 200 bins
× 5 groups from 32 of 34 datasets; 1 computed, 33 reused* (a line per kind,
each starting with its kind, when several are ticked). When the settings or
ticks changed since the result, it begins *Out of date:* and says what
differs.

### Raw Data

**Raw Data**, beside **Compute**, computes nothing: it uses the
browser as a way in to the data. Each ticked dataset comes on its own clock,
not cut into epochs, into `B.Sessions` for your script to use as it likes
(`B.loadSessions()` from a script). What comes depends on **Data**, each
kind ticked:

- **units**, **detected**: the spike times of the units **Compute** would use
  (classes, shanks, channels, merge, quality and response filters).
- **LFP**, **MUA**, **SPIKE**, **AUX**: the whole signal, of the channels the
  [Channels tab](#shanks-and-channels) keeps, at the rate
  [Downsample...](#downsampling-the-signals) sets for it (else its rate on
  file). A MUA at 2 kHz × 64 channels × 1 h is about 1.8 GB (0.45 GB at
  500 Hz), and every ticked dataset is held at once.

Every dataset also brings every trial and every digital line. The **Trials**
tab's selection marks the trials (`kept`, `group`, `groups`) but drops none.
The event, the window, the measure and normalization are not used.

**Trials Only**, beside it, brings the same without the spikes or the
signal: only the trials and the digital lines, whatever **Data** is (`data` is
`"trials"`; `spikes`, `units`, `signal` and `channels` are empty). From a
script: `B.loadSessions(TrialsOnly=true)`.

`B.Sessions` is a struct column, one per dataset loaded and kind of
**Data** (dataset by dataset, the kinds in **Data**'s order; pair a dataset's
kinds by `key`), made by [`sessionData.m`](../analysis/sessionData.m). A
dataset that lacks one of the kinds ticked (no sort, no such signal) has no
entry for it; the strip's message counts each kind (*12 session(s) loaded in
B.Sessions (units 12, LFP 11), ...*). **Trials Only** gives one entry per
dataset.

| Field | Holds |
| --- | --- |
| `key`, `name`, `folder`, `subject`, `startTime`, `tags` | which dataset. `subject` is the behavior file's, else the table's Subject (from the name pattern) |
| `fs`, `durationSec` | the recording's rate and length |
| `data` | the entry's kind of **Data**; `"trials"` from **Trials Only** |
| `spikes`, `units` | `{nUnits x 1}` spike times, s, on the continuous clock, and one row per unit (`selectUnits`' table); `{}` and `table()` for a signal |
| `signal`, `signalFs`, `channels` | `[nSamples x nChannels]` single (µV; AUX: V), row `k` at `(k-1)/signalFs`, its rate (the **Downsample...** rate when one is set below the rate on file) and one row per column (`selectChannels`' table); `[]`, `NaN` and `table()` for spikes |
| `signalFsFile` | the signal's rate on file: `signalFs` unless downsampled; `NaN` for spikes |
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
B.wait();                       % tick, then Raw Data
for D = B.Sessions.'
    on = D.toContinuous(D.trials.TrialOnset(D.kept));
    % ... D.spikes{u} against on, D.events.Lick, ...
end
```

With units and LFP ticked, each dataset's two entries side by side:

```matlab
S = B.Sessions;
for U = S([S.data] == "units").'
    L = S([S.data] == "LFP" & [S.key] == U.key);   % empty when the dataset has no LFP
    % ... U.spikes against L.signal (at L.signalFs) ...
end
```

No result is kept or written to the result file. The data come from memory
when a **Compute** left them there ([Loaded data](#loaded-data)), else from
disk (on the [workers](#workers) when set), and stay in memory for the next
run only with **Cache > Keep data loaded by Raw Data**. A dataset without the
data asked for (no sort, no spikes file, no such signal; with several kinds,
none of them) is skipped; the strip's message counts them. `[D, T] = B.loadSessions()` also returns each
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
| **Run it after each Compute or Load** | **Compute** and **Raw Data** run the script once the data are in (`B.ScriptAfterCompute`) |
| **Run now** | runs the script on the result or the sessions as they are (`B.runScript()`); off before either |

The script runs in the base workspace, as `run` runs it, with the browser put
there as `B` first (a `B` already there is replaced). It reads the result
with `R = B.Result` (or `S = B.Sessions`) and may use anything of the browser (`B.ResultCurrent`,
`B.progressStart`, `B.forEach`, ...). Everything it makes stays in the
workspace. An error in it is shown on the status line, naming the script and
its line (`DatasetBrowser:ScriptFailed`, the script's error as its cause);
the result is kept.

Every script in [`analysis/browser_scripts`](../analysis/browser_scripts) is
always listed, first: the folder is read again each time the browser opens,
so a script saved there appears at the next start, and **−** is off for
these (`removeScript` raises `DatasetBrowser:BundledScript`). **+** and **−**
add and remove scripts from anywhere else; only those are kept in the
`Scripts` preference. The folder holds
[`S_DatasetBrowserBasicOutput.m`](../analysis/browser_scripts/S_DatasetBrowserBasicOutput.m):
it keeps the `su` units (or every channel of a signal), sorts them by date
and the groups by label, and leaves `R`, `units_`, `data_`, `groupLabels_`,
`groupTexts_`, `cmap`, `nU`, `nB`, `nG` and a summary of `R` in the
workspace. It also holds
[`S_DatasetBrowserToFieldTrip.m`](../analysis/browser_scripts/S_DatasetBrowserToFieldTrip.m),
which turns a signal into FieldTrip raw structures (`ft_datatype_raw`) and
spikes into spike structures (`ft_datatype_spike`), one per dataset:
`ftEpochs` from `R.epochs` (`epochMatrixFieldTrip`: a trial per epoch,
`trialinfo` = `[resultGroup trial]`; spikes cut as `ft_spike_maketrials`
leaves them, on the recording's timestamps) and `ftSessions` from
`B.Sessions` (`sessionDataFieldTrip`: the whole signal or every spike, with
its events, a `trl` for `ft_redefinetrial` / `ft_spike_maketrials` and the
erased periods), then draws the evoked responses at the probe sites
(`ft_multiplotER`) or a unit's raster and PSTH per group
(`ft_spike_plot_raster`, `ft_spike_psth`);
see [FieldTripExport](FieldTripExport.md#from-the-analysis-results).
[`S_DatasetBrowserToChronux.m`](../analysis/browser_scripts/S_DatasetBrowserToChronux.m)
does the same for Chronux, and
[`S_DatasetBrowserToNeuroGLM.m`](../analysis/browser_scripts/S_DatasetBrowserToNeuroGLM.m)
hands the whole sessions' spike trains to the neuroGLM toolbox
(`sessionDataNeuroGLM`: one neuroGLM trial per kept trial, every line's
edges as events, the trial parameters as values) and fits Park et al. 2014's
Poisson GLM for every unit of each dataset, with the kernels, held-out trials and
PSTHs drawn; see [NeuroGLMExport](NeuroGLMExport.md).
[`S_DatasetBrowserToMTRF.m`](../analysis/browser_scripts/S_DatasetBrowserToMTRF.m)
turns a signal (or spike trains) and a stimulus into the stimulus / response
pairs the mTRF-Toolbox fits, one package per dataset: `mtEpochs` from
`R.epochs` (`epochMatrixMTRF`: an impulse on each epoch's event) and
`mtSessions` / `mtTrials` from `B.Sessions` (`sessionDataMTRF`: the whole
signal resampled, with the pulses of a digital line, a trial parameter or an
AUX channel's envelope as the stimulus, cut into artifact-free pieces or the
kept trials), then cross-validates, trains and plots a TRF and a decoder when
the toolbox is on the path; see [mTRFExport](mTRFExport.md).
[`S_DatasetBrowserToICSD.m`](../analysis/browser_scripts/S_DatasetBrowserToICSD.m)
and [`S_DatasetBrowserToKCSD.m`](../analysis/browser_scripts/S_DatasetBrowserToKCSD.m)
estimate the current source density of a signal along each shank: the
evoked potential of every group per laminar profile (`epochMatrixCSD` from
`R.epochs`, `sessionDataCSD` from `B.Sessions` with the kept trials cut in
the browser's window), then the iCSD toolbox's spline, delta, step and
standard methods (`icsdEstimate`, `csdEpochs` / `csdSessions` with
`csd.<method>`) or kCSD-python's kernel CSD with `R` and `lambda`
cross-validated (`kcsdEstimate`, run in a Python with `kcsd`), and draw the
CSD images with the potentials overlaid; see
[CSDEstimate](CSDEstimate.md). The
list, the script picked and the box are preferences.

Each of these scripts ends by noting what it did in the manifest of every
dataset it processed (`B.noteInManifest`, below): the field
`custom.browser_<tool>` -- `browser_fieldtrip`, `browser_chronux`,
`browser_neuroglm`, `browser_mtrf`, `browser_icsd`, `browser_kcsd` -- holds
the time, whether the epochs or the whole sessions were converted, and the
script's settings: everything in its `opts` struct. The neuroGLM script adds
the file it wrote and the number of units fitted. A second run
replaces the field. Because the manifest counts in a dataset's cache stamp
([The cache](#the-cache-and-the-result-file)), the next **Compute** works those
datasets out again.

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

### When a dataset gives nothing

A dataset that cannot give what the settings ask for is said so, in three
places:

- its **Cached** cell reads `skipped: no sorted units` (nothing to compute) or
  `error` (the computation failed), in red;
- when a **Compute**, `forEach` or **Raw Data** ends, the status
  line names them: *"2 not computed: recA (no sorted units), recB (error: ...)."*
  (the first three, then *and N more*; red when one failed). The summary adds
  *", 2 not computed (Details...)"*;
- **Details...** (beside **Trials Only**, and **Details of the last run...**
  in the table's right-click menu) opens a window with a row per dataset and
  kind of **Data** the last run covered: **Dataset**, **Data**, **Status**
  (`error`, `skipped`, `no rows`, `done`, `cached`), **Reason** (the whole
  message the run kept) and **Seconds**. The datasets that gave nothing come
  first.

In a script, `B.notComputedText()` is the status text, `B.runDetails()` the
table and `B.showDetails()` the window. For a **Compute**, `B.Result.datasets`
(`R.datasets`) holds the same status and message per dataset, with the rows
each gave.

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

What a worker reads stays on the worker, not in this MATLAB's
[loaded data](#loaded-data). So **Compute** and **Raw Data** compute a dataset
whose data are held here, here (no file read), and send only the others; with
**Cache > Compute here while the data fit**, they read the others here too
until the memory for loaded data is full, so the next run finds them in
memory. The first **Compute** then takes about as long as with no workers,
and the next ones read nothing. `forEach` keeps its workers: a script's own
work may need them.

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

`wait` blocks until a **Compute** or **Raw Data** from the window finishes (and the
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
| `runDetails(B)`, `notComputedText(B)`, `showDetails(B)` | what the last compute, `forEach` or load did for each dataset (Dataset, Data, Status, Reason, Seconds), the status-line text that names the datasets that gave nothing, and the **Details...** window ([When a dataset gives nothing](#when-a-dataset-gives-nothing)) |
| `showProbe(B)`, `pickProbe(B, KIND, VALUE)` | the **Channels** tab with the lists' dataset's probe; a click on it: `KIND` `"site"` (a recording channel) or `"shank"`, toggled and applied ([Shanks and channels](#shanks-and-channels)) |
| `showRasters(B, ROW)`, `X = raster(B, ROW, Order=)` | the **Trial rasters** window on row `ROW` of the result; that row trial by trial ([Trial rasters](#trial-rasters)) |
| `[R, Rs] = compute(B, Recompute=false)` | `epochMatrix` over the ticked datasets with `B.Settings`, once per kind of data: `R` is `B.Result`, `Rs` is `B.Results` ([Several kinds of data](#several-kinds-of-data)) |
| `[D, T] = loadSessions(B, TrialsOnly=false)` | the ticked datasets whole, in `B.Sessions` ([Raw Data](#raw-data)) |
| `[VALUES, T] = forEach(B, FN, ...)` | [your own per-dataset code, cached](#foreach) |
| `forget(B, NAME, KEYS)`, `forgetTicked(B)` | drop kept parts (`forget(B)`: all of them) |
| `B.Caching = struct(...)`, `clearLoadedData(B)` | what is kept between runs, as the **Cache** menu sets it (a struct of some of its fields; the others stay); free the data held in memory, `B.LoadedData` ([Caching](#caching)) |
| `DLG = editTags(B, KEYS)`, `setTags(B, KEYS, Set=, Add=, Remove=)` | the tag window on datasets (no `KEYS`: the rows selected, else the clicked one); the same edit from a script, written to the manifests ([Editing tags](#editing-tags)) |
| `DLG = editVariables(B, KEYS)`, `setVariables(B, KEYS, Name=, Value=, Label=, Units=, Description=, Remove=)` | the variable window on datasets (a row per dataset, a column per variable); the same edit from a script, written to the manifests ([Editing variables](#editing-variables)) |
| `DLG = editDownsample(B)` | the *Downsample signals* window (**Downsample...**): a rate per signal into `Settings.signal.downsample`; its methods `setRate`, `clearRates`, `ok` and `cancel` drive it ([Downsampling the signals](#downsampling-the-signals)) |
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
`Result` (the first kind's), `Results` (a result per kind of data, by
kind), `Sessions`, `ResultCurrent` (the results were computed with these
settings on these ticks), `Computed` (when the result was computed, a `datetime`: the
last Compute, or the one the result file holds; `NaT` before a result; a
change of `Normalize` alone does not move it), `ResultName` (read-only: the
result's default name, `R.name`; `""` before a result), `Definitions` (read-only: the [event & trial definitions](#event--trial-definitions)), `ResultFile`, `Workers` ([Workers](#workers)), `Runs` (the `DatasetRuns` with the kept parts),
`Runner`, `Busy`, `CancelRequested`, `Fig` and `Ctl` (the window and its
controls). `OnChange(B, what)` is called with `"scan"`, `"filter"`,
`"ticks"`, `"tags"`, `"settings"`, `"definitions"`, `"result"`, `"sessions"`, `"script"`, `"done"` or `"closed"`.

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

With several kinds of **Data** ticked, `data=["units" "LFP"]` and one
`epochMatrix` per kind:

```matlab
Results = struct();
for kind = S.data
    Results.(kind) = epochMatrix(cfg, epochMatrixSettings(S, Kind=kind));
end
R = Results.(S.data(1));
```

A struct setting lists only its fields that differ (`epochMatrixSettings`
merges them over the defaults), and settings that do not apply to the data
(`signal` for spikes; `units`, `measure`, `binSec`, `baseline`, `auroc` for
a signal; with several kinds, only those no kind uses) are left out. The filter is a comment: the keys are the
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

### Noting a script's work in the manifests

`B.noteInManifest(keys, tool, details)` records in the manifest of each
dataset in `keys` that a script processed it: it adds the field
`browser_<tool>` (`tool` lower-cased) to the manifest's `custom` block with
[`addToManifest`](EphysDataset.md#dataset-manifest). The field holds
`processed` (the time) and the fields of the scalar struct `details`, e.g.
the settings used. `Name=Value` pairs after it add to those fields, e.g. the
file written, and win over a field of `details` with their name. A second
call replaces the field; a dataset whose manifest cannot be written warns
(`DatasetBrowser:noteInManifest`) and the others go on.

Keep a script's settings in one struct, so that noting them takes one word.
The bundled scripts call it `opts`. Start it with `opts = struct();`, because
a script runs in the base workspace, where an earlier script's `opts` would
otherwise still hold its fields.

```matlab
opts = struct();
opts.binMs = 5;
opts.window = [-0.5 1];
% ... the fit, using opts.binMs and opts.window ...
B.noteInManifest(D.key, "myfit", opts, file=savedTo);
m = EphysDataset.readManifest(B.Runner.Outputs(B.Runner.index(D.key)).ManifestFile);
m.custom.browser_myfit
```

## The result

`B.compute()` returns, and `B.Result` holds, the result `R`. With several
kinds of **Data**, `B.Results` holds one such `R` per kind, by kind
(`B.Results.LFP`; `R.settings.data` is its kind), and `B.Result` is the
first kind's.
`size(R.data) = [height(R.rows), numel(R.t), numel(R.groupLabels)]`. Scripts
use the fields in place (`R.data`, `R.rows`, `R.t`, `R.groupLabels`,
`R.settings`) and need not copy them out. `imagesc(R.t, 1:height(R.rows),
R.data(:, :, 1))` draws the first group of every row, and `R.labels`
([Labels](#labels)) gives its axis labels and caption in words.

| Field | Type | Holds |
| --- | --- | --- |
| `R.data` | double [nRows x nTime x nGroups] | The values: data(row, time, group). It holds the measure (rate, count or auROC) for spikes, and the group mean or median for signals. Wherever a row's dataset has no epochs in a group, the value is NaN. With `settings.normalize.method` other than `"none"` the values are normalized ([Normalization](#normalization)). |
| `R.rows` | table, nRows rows | One row per unit (spikes) or channel (signals), in data's first-dimension order. Columns for every kind: label, Dataset (key), Subject, Date (day), Tags (";"-joined), then a `var_<name>` column per [variable](#editing-variables) (its label and units in `VariableDescriptions` and `VariableUnits`; NaN or missing where a dataset lacks it). Units add unitId, class ("su", "mua", "det", ...), channel, channelName, shank, x, y, nSpikes, and nSites/sites when merged. Channels add channel, shank, x, y, units. A column that some datasets lack is missing (missing/NaN) in their rows. |
| `R.t` | double column, nTime | Times along data's second dimension, in s from the event. For spikes these are bin centers (auROC window centers for auroc); for signals, sample times. |
| `R.groupLabels` | column, nGroups | Labels along data's third dimension, in settings.selection.groupOrder. Numeric when grouped by one parameter that is numeric in every dataset (e.g. Depth), otherwise string: the value's text for one parameter, "Depth = 3, Level = 2" for several. |
| `R.rowKind` | string | "unit" or "channel". |
| `R.valueUnits` | string | The unit of data: "spikes/s", "spikes/bin", "auROC", "uV" or "V"; normalized: "z", "%", "x baseline" or "0-1" ("subtract" keeps the unit). Use it for axis labels. |
| `R.settings` | struct | The settings that made R (see [Settings](#settings)), e.g. R.settings.measure, R.settings.data, R.settings.window.pre. |
| `R.datasets` | table, one row per ticked dataset | key, name, subject, date, tags, the `var_<name>` columns, status ("done", "cached", "skipped" or "error"), message, nRows, nEpochs, nGroups, seconds. This table answers "why is dataset X missing". |
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
variability, your own statistics), tick **Keep single trials, not just averages** above
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
  the analysis app's PSTH panels use, takes the same mean and SD (over the
  baseline's whole bins of the group's trial-averaged PSTH), so with scope
  `"group"` the two give the same z.
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
| `data` | what is computed, one kind or several (a string row, each kind once, in the order given; the fields of every kind are checked): `"units"` (default; the sorted units of the sorting folder), `"detected"` (the Spikes step's threshold detections, one train per channel), `"LFP"`, `"MUA"`, `"SPIKE"` or `"AUX"` (a derived signal) |
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
| `signal` | signals: a struct of `channels` (recording channels kept, 1-based: the probe map's `chanMap` + 1, as `units.channels`; for AUX its 1-based columns; `[]` = all), `shanks` (probe shanks kept; `[]` = all; not used for AUX), `baseline` ([b0 b1] s: each epoch's mean over it is subtracted per channel; `[]` = none), `detrend` (remove each epoch's linear trend; false), `rectify` (the absolute value before the average; false), `magnitude` (the channels' vector magnitude, one row, e.g. AUX's accelerometer; false), `statistic` (`"mean"` default, or `"median"`) and `downsample` (a struct with a field per signal, `LFP`, `MUA`, `SPIKE` and `AUX`: the rate in Hz that signal is brought to first, anti-aliased, or `[]` for the rate on file, the default; fields left out are `[]`; see [Downsampling the signals](#downsampling-the-signals)) |

Fields that do not apply to `data` are kept in `S`, unchecked beyond their
form, and left out of the cache identity, so a change to an LFP option keeps
the cached spike results. `normalize` is left out of it too.

**One kind of several.** `epochMatrix` computes one kind at a time.
`[S1, ID, NAME] = epochMatrixSettings(S, Kind="LFP")` gives the settings of
that kind of `S.data` alone (`data` = the kind; `units.source` = the kind for
spikes), with its cache identity and parts' name. Among other kinds, `AUX`
takes all its columns (its `signal.channels` and `signal.shanks` are cleared:
they are the probe's pick), and `signal.magnitude` is `AUX`'s (cleared for a
probe signal when `AUX` is in `data`). A signal keeps only its own
`signal.downsample` rate (the others become `[]`), and its cache identity
holds that rate only when it is set. Asking for `ID` or `NAME` with several
kinds and no `Kind` raises `epochMatrixSettings:SeveralData`.

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

**Earlier settings.** With **Cache > Keep results of earlier settings** (on by
default) each dataset keeps the parts of its last 5 settings
(`B.Runs.MaxIds`; `DatasetBrowser.EarlierSettings`), not only the last
one's: going back to settings computed before (Hit, Miss, then Hit again)
reuses their parts. The one used least recently goes first. A changed stamp
drops every settings' part of that dataset when it is computed again. Off,
a new settings' part replaces the old one.

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
| `results` | `B.Results` (`[]` before a compute): a result per kind of data, by kind; their `labels` are made again on restore, and their `epochs` are left out and assembled again from `runs`. A version 1 file's `result` is not read |
| `runs` | `B.Runs.toStruct()`: every kept part and `forEach` value, each with its identity, status, message, seconds and the time it was made. With **Cache > Save computed results in the result file** off, none (an empty `DatasetRuns`): a restored result then has no `epochs`, and its datasets are computed again |

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

## Caching

Two things are kept between runs, each set from the **Cache** menu
([The window](#the-window)) or from a script with `B.Caching`, a struct:

```matlab
B.Caching                                     % every field
B.Caching = struct('LimitGB', 16);            % some fields; the others stay
B.Caching = struct('Signals', false, 'RawData', true);
```

| Field | Menu item | Default |
| --- | --- | --- |
| `Results` | Reuse computed results | `true` |
| `Earlier` | Keep results of earlier settings | `true` |
| `SaveResults` | Save computed results in the result file | `true` |
| `Spikes` | Keep loaded spike data in memory | `true` |
| `Signals` | Keep loaded signals in memory | `true` |
| `LimitGB` | Memory for loaded data | a quarter of the computer's memory, among 1 to 64 GB (4 when unknown) |
| `Compute` | Keep data loaded by Compute | `true` |
| `RawData` | Keep data loaded by Raw Data | `false` |
| `Scripts` | Keep data loaded by scripts (forEach) | `true` |
| `Here` | Compute here while the data fit (not on workers) | `true` |

A field it has not, or a value that is not true or false (`LimitGB`: a
number of GB above 0), raises `DatasetBrowser:BadValue`. The fields are the
preference `Caching`.

**Computed results** are the per-dataset parts of [the cache](#the-cache-and-the-result-file):
`Results`, `Earlier` and `SaveResults` say whether they are reused, whether
those of earlier settings are kept beside the last ones, and whether they go
into the result file.

### Loaded data

What a run reads from disk for a dataset (the spikes file, the sorting, the
signal files, with the signals' resampled and filtered columns) stays in
memory in `B.LoadedData`, a [`DatasetCache`](../analysis/DatasetCache.m) that
holds each dataset's `DatasetOutputs` cache. The next run on that dataset reads
nothing from disk, so a **Compute** with another event, window, trial
selection (Hit, then Miss), bin, measure or channel pick works on the data in
memory. The parts are still computed again (their settings changed); only the
reading is saved, which over a network share or a USB disk is most of the
time.

- **Which data.** `Spikes` keeps the spike data (the spikes file, the
  sorting), `Signals` the signals (and a whole extract file). Turning one off
  drops those data from memory at once.
- **How much.** Beyond `LimitGB` the datasets used least recently are freed; a
  dataset larger than the limit is not kept. Sizes are those `whos` counts.
  A lower limit frees datasets at once.
- **Which runs keep what they read.** `Compute`, `RawData` (**Raw Data** and
  **Trials Only**), `Scripts` (`forEach`). A run that does not keep still uses
  the data held, and a dataset held stays held (with what that run read).
- **Workers.** What a worker reads stays on the worker. A dataset held here
  is computed here by **Compute** and **Raw Data**; with `Here` they read the
  others here too until `LimitGB` is reached ([Workers](#workers)).
- **Scan, root, close.** A new **Scan** keeps the data of each dataset whose
  data files did not change (a tag or variable edit, which rewrites only the
  manifest, keeps them; the manifest is read again), and the loaded sources of
  those whose files are all the same. Another root, **Cache > Clear loaded
  data** (`B.clearLoadedData()`) and closing the window free them.

`B.LoadedData.summary()` says what is held ("1.2 GB in 12 datasets"; also in
the menu and in **Help > About**), `B.LoadedData.Keys` which datasets.

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
| `Scripts`, `Script` | the [post-processing scripts](#the-post-processing-script) listed and the one picked (the scripts of `analysis/browser_scripts`, always, then those added with **+**) |
| `ScriptAfterCompute` | **Run it after each Compute or Load** |
| `ScriptFolder` | the folder of the last script added (where **+** opens) |
| `Caching` | the **Cache** menu: what is kept between runs ([Caching](#caching)) |

## Errors and warnings

| Id | Raised when |
| --- | --- |
| `DatasetBrowser:NoRoot` | the root cannot be reached on a scan |
| `DatasetBrowser:NotScanned` | a method needs the scan's datasets and there are none |
| `DatasetBrowser:NoneTicked` | `compute` or `loadSessions` with no dataset ticked |
| `DatasetBrowser:UnknownDataset` | a key, name or index that is no scanned dataset |
| `DatasetBrowser:BadValue` | a form control that does not exist, a typed number or range (`1:4`) that does not parse, or a `Caching` field it has not or a value that does not fit |
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
| `epochMatrix:NoData` | no dataset gave rows (the message lists why; with several kinds, it starts with the kind) |
| `epochMatrix:TimeBase` | the datasets' `t` differ |
| `epochMatrix:UnknownDataset`, `:BadSource`, `:BadPart` | a dataset not in the runner; a source that is not a runner, config or list of parts; a malformed part |
| `epochMatrixSettings:UnknownField` | a setting that has no place |
| `epochMatrixSettings:BadValue` | a value that does not fit, a `Kind` not in `data`, or a file that is no settings file |
| `epochMatrixSettings:SeveralData` | the cache identity asked for with several kinds in `data` and no `Kind` (so `epochMatrix` given several kinds) |
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
| one dataset on its own clock (**Raw Data**) | [`sessionData.m`](../analysis/sessionData.m) |
| the settings, their checks and cache identity | [`epochMatrixSettings.m`](../analysis/epochMatrixSettings.m) |
| the *Downsample signals* window; the anti-aliased resampling | [`DownsampleDialog.m`](../analysis/DownsampleDialog.m); [`resampleSignal.m`](../pipeline/resampleSignal.m) |
| the result's labels and description in words | [`epochMatrixLabels.m`](../analysis/epochMatrixLabels.m) |
| the normalization of a result | [`epochMatrixNormalize.m`](../analysis/epochMatrixNormalize.m) |
| one row of a result trial by trial; its window | [`epochMatrixRaster.m`](../analysis/epochMatrixRaster.m), [`TrialRaster.m`](../analysis/TrialRaster.m) |
| the **Epochs per group** window (also the analysis app's Alignment tab bars) | [`EpochGroupCounts.m`](../analysis/EpochGroupCounts.m) |
| the per-dataset cache and run engine | [`DatasetRuns.m`](../analysis/DatasetRuns.m) |
| the loaded data kept in memory between runs (**Cache** menu) | [`DatasetCache.m`](../analysis/DatasetCache.m); a dataset's own cache of them in [`DatasetOutputs.m`](../pipeline/@DatasetOutputs/DatasetOutputs.m) |
| the stamp of a dataset's output files (names, sizes, times) | [`outputsStamp.m`](../analysis/outputsStamp.m) |
| the subject, tag and text filter (also the analysis app's Data tab) | [`datasetFilter.m`](../pipeline/datasetFilter.m) |
| the tag window and the tag rules; writing a manifest's tags | [`TagDialog.m`](../pipeline/TagDialog.m), [`TagSet.m`](../pipeline/TagSet.m); [`writeManifestTags.m`](../pipeline/writeManifestTags.m) |
| the sorted table | [`TableSort.m`](../pipeline/TableSort.m) |
| the clickable probe of the Channels tab | [`ProbePicker.m`](../analysis/ProbePicker.m) |
| the time left | [`ProgressClock.m`](../pipeline/ProgressClock.m) |
| the buttons' icons (drawn by [`makeButtonIcons.py`](../tools/makeButtonIcons.py), shared with the analysis app); their look | [`buttonIcon.m`](../analysis/buttonIcon.m); [`styleButton.m`](../pipeline/styleButton.m) |

## Tests

| Suite | Covers |
| --- | --- |
| [`test_DatasetFilter.m`](../pipeline/test_DatasetFilter.m) | `datasetFilter`: subjects, wildcards and literal regex characters, tags, search, the combinations |
| [`test_DatasetRuns.m`](../analysis/test_DatasetRuns.m) | `DatasetRuns`: reuse, identity, skipped and failed datasets, cancel, `forget`, the saved struct, the results of earlier ids (`MaxIds`), `LocalFcn` |
| [`test_DatasetOutputs.m`](../pipeline/test_DatasetOutputs.m) | among the rest, what `CacheData` keeps: by kind (`cacheBytes`, `clearCache(KINDS)`), taken by a new object (`adoptCache`), detached and put back |
| [`test_EpochMatrix.m`](../analysis/test_EpochMatrix.m) | `epochMatrixSettings` and `epochMatrix`: the parts against the per-dataset calls, assembly, groups, the result fields, the labels, the normalization (`epochMatrixNormalize`), `signal.downsample` (its checks and cache identity, a downsampled LFP against `resampleSignal` and `evokedPotential` by hand, `sessionData` at the new rate) |
| [`test_MTRFExport.m`](../pipeline/test_MTRFExport.m) | `resampleSignal` under `mTRFExport.resample`: the rate reached, t = 0 kept, single kept, the passband and an alias removed |
| [`test_DatasetBrowser.m`](../analysis/test_DatasetBrowser.m) | the browser, headless and with its window: scan, filter, ticks, the form, compute, `forEach`, progress and cancel, the result file, the trial rasters (`raster`, `epochMatrixRaster`, the window), the exported script (`exportScript`), the whole sessions (`loadSessions`, `sessionData`), the Channels tab (`ProbePicker`: clicks and fields yoked), the event & trial definitions, `noteInManifest` (the `custom.browser_<tool>` field written, replaced and left off other datasets, a bad key warning), tags (`setTags`: Add, Remove and Set written to the manifests with nothing else changed, the table and the tag filter following, the refusals writing nothing, a loaded source's tags and `R.rows`; the tag window from a Tags cell, the selected rows and the ticked ones, OK, Cancel and closing the browser), variables (`setVariables` written with nothing else changed, an unchanged value not written, a loaded source and `R.rows`' `var_` column following; the window from a Variables cell and the selected rows, closing the browser), **Downsample...** (`DownsampleDialog`: the rates on file, a bad rate refused, OK, Cancel, **Rates on file**; the rates reaching **Compute** and **Raw Data**, a new MUA rate keeping the LFP parts), the **Epochs per group** window (`EpochGroupCounts`: its groups, epochs and trials against `epochTable`, the excluded epochs, a settings edit and a row click redraw it), the **Cache** menu (`Caching`, `DatasetCache`: another window and trial order computed from memory with the spikes files away, earlier settings' results reused, each menu item's effect, a new scan keeping the loaded data, the preference, closing freeing the data) |
