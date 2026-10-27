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
| `Workers` | the process workers **Compute** and `forEach` use ([Workers](#workers)). Default: the last one set, else 0 |

On opening, the ticks, filter, settings and result saved in the result file
are restored, unless the options set them. With no saved state, the first scan
ticks what the filter shows. A root that cannot be reached raises
`DatasetBrowser:NoRoot`.

## The window

The window (1380 x 860 pixels, its position remembered) has four rows:

1. **Root** (a field and **Browse...**) and **Pattern**, with **Scan**.
   **Scan** lists the root's datasets. It reads each one's outputs and tags
   but loads no dataset. The **Root** of a new scan takes that root's own
   result file, when the result file follows the root.
2. On the left, the filter, the count and the datasets table. On the right,
   the **Settings** panel.
3. The progress strip.
4. The status line.

### The filter

The filter only chooses which datasets the table shows. A hidden dataset keeps
its tick. Several terms are combined with AND. It is
[`datasetFilter`](../analysis/datasetFilter.m), the same filter as the analysis
app's [Data tab](EphysAnalysisApp.md#data-tab).

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
| **Cached** | the dataset's part for the current **Data** and settings: `✓ 62 rows` (kept and current), `skipped` (nothing to compute, kept so), `old` (kept, but either the settings or the stamp of the dataset's output files differ: computed again next time), or blank |

### The settings form

The right panel holds the settings of `epochMatrix` in a compact form. Every
edit is merged into the whole settings struct and checked by
`epochMatrixSettings`; an edit that does not fit is undone and its reason
shown in the status line. **Load...** and **Save...** read and write a
[settings file](#settings) (**Save...** writes every field, also those the
form does not show).

| Control | Sets |
| --- | --- |
| **Data** | `data`: `units`, `detected`, `LFP`, `MUA`, `SPIKE` or `AUX`. Only the block that matches is on |
| **Event**, edge, which, **n** | `ref`: the line each epoch is aligned to, its onset or offset, which interval per trial (`first`, `last`, `all`, `nth`; **n** is for `nth`) |
| **Then**, edge | one follow-up step of `ref.sequence` (an event that must follow; the epochs align to it). *(none)*: the event alone. More steps from a loaded file are kept and noted |
| **Pre (s)**, **Post (s)** | `window` (fixed) |
| **Response** | `selection.response`: keep the trials that are any of these (none picked: every trial) |
| **Group by**, **Order** | `selection.groupBy` (one trial parameter) and `groupOrder` |
| **Spikes** block | **Merge neighboring sites** (`units.merge.enabled`, `detected` only), **Shanks** (`units.shanks`, e.g. `1:4`), **Measure**, **Bin (s)**, **auROC baseline (s)** (with measure `auroc`) |
| **Signals** block | **Channels**, **Shanks** (not for AUX), **Baseline (s)**, **Statistic**, **Detrend**, **Rectify**, **Magnitude (AUX)** |

The form does not show every field (the unit classes and tests, the auROC
section, the trial filter). Load a settings file or assign `B.Settings` for
those.

The line and parameter lists come from one dataset's source: the clicked
row's, else the first ticked dataset's. A value typed or loaded that this
dataset lacks stays.

**The Data dropdown and its two blocks.** **Data** chooses what is computed,
and with it which block of the form applies:

- `units` (the sorted units of the sorting folder) and `detected` (the Spikes
  step's threshold detections, one train per channel) use the **Spikes** block.
  The result is a rate, a count or an auROC per bin.
- `LFP`, `MUA`, `SPIKE` and `AUX` (derived signals) use the **Signals**
  block. The result is the group mean or median of each channel.

The controls of the other block are off. A note beside the dropdown counts the
ticked datasets that cannot give that data (*3 of 12 ticked lack LFP
(skipped)*, *2 of 12 ticked have no sorting*). A change to a setting of the
other block leaves the kept parts of this **Data** valid.

**Compute** computes the ticked datasets with these settings. **Done** lets a
script that called `B.wait()` go on; the window stays open. The summary under
the buttons reads *812 units × 200 bins × 5 groups from 32 of 34 datasets; 1
computed, 33 reused*. When the settings or ticks changed since the result, it
begins *Out of date:* and says what differs.

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
Computing Toolbox, `parfeval`). `0`, the default, computes them here, one
after the other. With 1 or more, and two or more datasets to compute, the open
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
B.wait();          % tick, adjust, Compute, Done
R = B.Result;
```

`wait` blocks until **Done** is pressed or the window is closed (it returns
at once when the window is hidden or closed; `Timeout=` limits the wait).
`R` is [the result](#the-result). Closing the window keeps the object:
`Result`, `compute` and `forEach` still work.

### Without waiting

A script need not wait. `DatasetBrowser.open` returns the browser whose window
is already open on the root, as it is, and opens one only when none is. The
script goes on with the result the browser holds (the result file's, when the
window has just opened) and the window stays open for later changes:

```matlab
B = DatasetBrowser.open(root, NamePattern=namePattern);
if isempty(B.Result), B.wait(); end   % nothing computed yet: tick, Compute, Done
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
| `formEdit(B, CONTROL, VALUE)` | edit a control of `B.Ctl` as a click would |
| `R = compute(B, Recompute=false)` | `epochMatrix` over the ticked datasets with `B.Settings` |
| `[VALUES, T] = forEach(B, FN, ...)` | [your own per-dataset code, cached](#foreach) |
| `forget(B, NAME, KEYS)`, `forgetTicked(B)` | drop kept parts |
| `loadSettings(B, FILE)`, `saveSettings(B, FILE)` | a [settings file](#settings) (no `FILE`: a file dialog) |
| `save(B, FILE)`, `restore(B, FILE)` | the [result file](#the-cache-and-the-result-file) |
| `wait(B, Timeout=Inf)`, `done(B)`, `close(B)` | the window |
| `B = DatasetBrowser.open(ROOT, ...)` | the browser of the window open on `ROOT`, else a new one ([without waiting](#without-waiting)) |

The properties: `Settings` (the whole struct; assigning checks it with
`epochMatrixSettings`), `Filter`, `Selected` (the ticked keys), `Table` and
`Shown` (the rows shown, and their keys), `Datasets` (every dataset found),
`Result`, `ResultCurrent` (the result was computed with these settings on
these ticks), `ResultFile`, `Workers` ([Workers](#workers)), `Runs` (the `DatasetRuns` with the kept parts),
`Runner`, `Busy`, `CancelRequested`, `Fig` and `Ctl` (the window and its
controls). `OnChange(B, what)` is called with `"scan"`, `"filter"`,
`"ticks"`, `"settings"`, `"result"`, `"done"` or `"closed"`.

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
| `R.data` | double [nRows x nTime x nGroups] | The values: data(row, time, group). It holds the measure (rate, count or auROC) for spikes, and the group mean or median for signals. Wherever a row's dataset has no epochs in a group, the value is NaN. |
| `R.rows` | table, nRows rows | One row per unit (spikes) or channel (signals), in data's first-dimension order. Columns for every kind: label, Dataset (key), Subject, Date (day), Session, Tags (";"-joined). Units add unitId, class ("su", "mua", "det", ...), channel, channelName, shank, x, y, nSpikes, and nSites/sites when merged. Channels add channel, shank, x, y, units. A column that some datasets lack is missing (missing/NaN) in their rows. |
| `R.t` | double column, nTime | Times along data's second dimension, in s from the event. For spikes these are bin centers (auROC window centers for auroc); for signals, sample times. |
| `R.groupLabels` | column, nGroups | Labels along data's third dimension, in settings.selection.groupOrder. Numeric when grouped by one parameter that is numeric in every dataset (e.g. Depth), otherwise string: the value's text for one parameter, "Depth = 3, Level = 2" for several. |
| `R.rowKind` | string | "unit" or "channel". |
| `R.valueUnits` | string | The unit of data: "spikes/s", "spikes/bin", "auROC", "uV" or "V". Use it for axis labels. |
| `R.settings` | struct | The settings that made R (see [Settings](#settings)), e.g. R.settings.measure, R.settings.data, R.settings.window.pre. |
| `R.datasets` | table, one row per ticked dataset | key, name, subject, date, status ("done", "cached", "skipped" or "error"), message, nRows, nEpochs, nGroups, seconds. This table answers "why is dataset X missing". |
| `R.keys` | string column | The datasets whose rows are in R, in row order. |
| `R.created` | datetime | When the result was assembled. |
| `R.labels` | struct of strings | Axis labels, legend text and a one-line description of R, in words (see [Labels](#labels)). |

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
| `event` | the whole event reference (`eventRefLabel`) | "Stim onset then Platform offset (aligned to Stim onset)" |
| `group` | the `groupBy` parameters ("" without `groupBy`) | "Depth", "Depth, Level" |
| `groups` | a label per group of `R.groupLabels`, in its order | "Depth 3" for one parameter; the label itself ("Depth = 3, Level = 2") for several; "All trials" without `groupBy` |
| `rows` | what a row of `R.data` is, plural | "units", "detected channels", "LFP channels" |
| `trials` | the trials kept | "Hit trials", "Hit or Miss trials where Depth > 0", "all trials" |
| `window` | the epoch window | "-1 to 1 s" |
| `bins` | the bin width (spikes; "" for signals) | "10 ms bins" |
| `baseline` | the auROC's baseline, or the signal's subtracted one ("" without one) | "baseline -0.5 to 0 s", "baseline -0.2 to 0 s subtracted" |
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
`window`, `selection`, `units`, `signal`, `auroc`) is merged field by field
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
| `signal` | signals: a struct of `channels` (1-based columns of the signal; `[]` = all), `shanks` (probe shanks kept; `[]` = all; not used for AUX), `baseline` ([b0 b1] s: each epoch's mean over it is subtracted per channel; `[]` = none), `detrend` (remove each epoch's linear trend; false), `rectify` (the absolute value before the average; false), `magnitude` (the channels' vector magnitude, one row, e.g. AUX's accelerometer; false) and `statistic` (`"mean"` default, or `"median"`) |

Fields that do not apply to `data` are kept in `S`, unchecked beyond their
form, and left out of the cache identity, so a change to an LFP option keeps
the cached spike results.

**Settings files** are JSON: `{"schema": "epoch-matrix-settings", "version":
1, "settings": {...}}`, with non-finite numbers written as the strings
`"Inf"`, `"-Inf"` and `"NaN"`. Write one with
`epochMatrixSettings(S, SaveAs="ofc_hit_depth.json")`, **Save...** or
`B.saveSettings(file)`; read one with `epochMatrixSettings(file)`,
`DatasetBrowser(root, Settings=file)`, **Load...** or `B.loadSettings(file)`.
The form remembers the folder of the last file (preference `SettingsFolder`).

`[S, ID] = epochMatrixSettings(...)` also returns the cache identity `ID`:
`data`, `ref`, `window`, `selection`, the fields that apply to `data` and a
`version` of the part builders. A change to what the part builders compute
bumps that version (`PartVersion` in `epochMatrixSettings`), so results
cached by old code are computed again.

## The cache and the result file

**Per-dataset parts.** `epochMatrix` computes one part per dataset and keeps
it in a `DatasetRuns` ([source](../analysis/DatasetRuns.m), `B.Runs`) under
the name `"epochMatrix/" + data`. A part is reused only while its identity is
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
| `result` | `B.Result` (`[]` before a compute); its `labels` are made again on restore |
| `runs` | `B.Runs.toStruct()`: every kept part and `forEach` value, each with its identity, status, message, seconds and the time it was made |

It is written after a `compute` or `forEach` that added parts (a canceled one
too, so the finished parts survive), on **Done**, and on close, when the state
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

## Errors and warnings

| Id | Raised when |
| --- | --- |
| `DatasetBrowser:NoRoot` | the root cannot be reached on a scan |
| `DatasetBrowser:NotScanned` | a method needs the scan's datasets and there are none |
| `DatasetBrowser:NoneTicked` | `compute` with no dataset ticked |
| `DatasetBrowser:UnknownDataset` | a key, name or index that is no scanned dataset |
| `DatasetBrowser:BadValue` | a form control that does not exist, or a typed number or range (`1:4`) that does not parse |
| `DatasetBrowser:BadFilter` | a filter option that does not fit |
| `DatasetBrowser:NoFile` | a settings file was asked for and none was passed |
| `DatasetBrowser:Canceled` | `checkCancel` after **Cancel**; a scan canceled |
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
`DatasetRuns:OldVersion` (kept results of an older `DatasetRuns` version are
not restored) and `DatasetRuns:DatasetFailed` (a dataset failed and is left
out).

## Where the code is

| Part | File |
| --- | --- |
| the window and the handle | [`DatasetBrowser.m`](../analysis/DatasetBrowser.m) |
| the compute and its result | [`epochMatrix.m`](../analysis/epochMatrix.m) |
| the settings, their checks and cache identity | [`epochMatrixSettings.m`](../analysis/epochMatrixSettings.m) |
| the result's labels and description in words | [`epochMatrixLabels.m`](../analysis/epochMatrixLabels.m) |
| the per-dataset cache and run engine | [`DatasetRuns.m`](../analysis/DatasetRuns.m) |
| the stamp of a dataset's output files (names, sizes, times) | [`outputsStamp.m`](../analysis/outputsStamp.m) |
| the subject, tag and text filter (also the analysis app's Data tab) | [`datasetFilter.m`](../analysis/datasetFilter.m) |
| the sorted table | [`TableSort.m`](../pipeline/TableSort.m) |
| the time left | [`ProgressClock.m`](../pipeline/ProgressClock.m) |

## Tests

| Suite | Covers |
| --- | --- |
| [`test_DatasetFilter.m`](../analysis/test_DatasetFilter.m) | `datasetFilter`: subjects, wildcards and literal regex characters, tags, search, the combinations |
| [`test_DatasetRuns.m`](../analysis/test_DatasetRuns.m) | `DatasetRuns`: reuse, identity, skipped and failed datasets, cancel, `forget`, the saved struct |
| [`test_EpochMatrix.m`](../analysis/test_EpochMatrix.m) | `epochMatrixSettings` and `epochMatrix`: the parts against the per-dataset calls, assembly, groups, the result fields, the labels |
| [`test_DatasetBrowser.m`](../analysis/test_DatasetBrowser.m) | the browser, headless and with its window: scan, filter, ticks, the form, compute, `forEach`, progress and cancel, the result file |
