# Dataset browser guide

The dataset browser, `DatasetBrowser`, gathers the responses of many
recordings into one table, so you can compare sessions, subjects or
conditions and run your own statistics. You tick the recordings, say what to
measure around which event, and press **Compute**. You get one block of
numbers: a row for every unit (or channel) of every recording you ticked, a
column for every time bin, and a layer for every group of trials.

Use the [analysis app](analysis-app-guide.md) to *look* at recordings one
unit at a time; use the browser to *pool* them for analysis. This page is for
people who use the browser's window. The [window's reference](DatasetBrowser.md)
has the details of every control.

<!-- wiki: ![The dataset browser after a compute: the filtered datasets on the left, the settings on the right](images/dataset-browser.png) -->

## What it does

- **Finds** every recording of a project the pipeline has processed, and
  shows what each has: sorted units, detected spikes, behavior, signals, tags.
- **Filters** them by subject, tag or any word, so you tick just the ones you
  want (all the hits of the OFC recordings, say).
- **Computes**, for each ticked recording, every unit's firing rate (or
  spike count, or auROC) or every channel's signal around an event, averaged
  over each group of trials.
- **Remembers** each recording's part, so ticking one more recording computes
  only that one, and the result is there again the next time you open it.
- **Hands the result to a script** of yours, or to one of the scripts that
  come with it: a summary plot, FieldTrip, Chronux, neuroGLM, the mTRF
  toolbox, or a current source density estimate.

## Before you start

The recordings must have been processed by the pipeline: sorted units or
detected spikes for spike measures, derived signals (LFP, MUA, ...) for
signal measures, and paired behavior trials to choose or group trials.

## Open it

```matlab
DatasetBrowser("D:\EPHYS")      % your project folder
```

`DatasetBrowser` alone opens the project you used last, with your last
ticks, settings and result.

## The window

- **Top row:** the project folder (**Project root**), the dataset name
  **Pattern**, and **Scan** to list the recordings again.
- **Left:** the filter, and the table of recordings. Tick **Use** for each
  recording to include. **Tick shown only** ticks what the filter shows;
  **Untick all** clears the ticks. The **Cached** column says which
  recordings are already computed with these settings (green), computed
  with other settings (yellow) or gave nothing (red: *skipped* with the
  reason, such as *skipped: no sorted units*, or *error*). Right-click the
  table for more: clear the sort, forget what was computed, or see the
  details of the last run.
- **Right:** the settings, in tabs:
  - **Data**: what to measure: sorted `units`, `detected` spikes, or a
    signal (`LFP`, `MUA`, `SPIKE`, `AUX`). Tick several to get one result
    for each. **Downsample...**, at the end of the row, sets a lower rate
    for each signal. The button turns amber while a rate is set.
  - **Event**: the event to align to and the window around it, as in the
    analysis app's Alignment tab. **Epoch Diagram** draws how the epochs are
    cut on one recording.
  - **Trials**: which trials count (hits only, say) and how they are grouped
    (by `Depth`, say). **Epochs per group** counts them.
  - **Channels**: which shanks or channels to keep, picked on the probe.
  - **Measure**: firing rate, count or auROC, the bin size, and an optional
    normalization against the baseline. For sorted `units`, **Unit
    classes** picks which units count: tick **su** for single units only.
    With no box ticked, every unit counts.
- **Bottom:** **Compute**, **Details...**, the post-processing script, and a
  progress bar with **Cancel**.
- **Help → Keyboard shortcuts and right-click menus** lists the keys and what
  the right-click menu of the table does.

## A typical session

1. **Filter and tick.** Type a subject or a tag in the filter, press **Tick
   shown only**, and check the count above the table.
2. **Choose the data and the event.** On the right, tick **units** in
   **Data**, set the **Event** (the stimulus onset, say, 0.5 s before to 1 s
   after), and on **Trials** group by the parameter you care about.
3. **Check the trials.** **Epochs per group** shows how many trials each
   recording has in each group. Too few in a group? Change the filter or the
   grouping before you compute.
4. **Compute.** The line under the button sums up the result: *812 units ×
   200 bins × 5 groups from 32 of 34 recordings*. If some recordings gave
   nothing, the line at the very bottom names them and why (*2 not computed:
   recA (no sorted units), recB (error: ...)*) and **Details...** lists
   them all.
5. **Use the result.** Pick a script in the **Post-processing script** list
   (start with `S_DatasetBrowserBasicOutput`, which sorts the units and the
   groups and draws a summary), and press **Run now**; or tick **Run it after
   each Compute or Load** to run it every time.
6. **Save the settings** (**File → Save settings**) to compute the same thing
   again later, or on other recordings.

## Pick recordings by tag

The browser is where [tags](pipeline-app-guide.md#tag-your-datasets) pay
off most. Tag your recordings (by area, cohort, condition, training stage)
in the pipeline app or right here, and a group is one filter away:

- **Tags** *any of* `ofc`, `acx` keeps the recordings with either tag;
  *all of* `ofc`, `cohort-3` keeps those with both.
- **not** `pilot`, `exclude` leaves out every recording with either tag.
- **Tick shown only** ticks exactly what the filter shows.

**Tag recordings here.** Click a recording's **Tags** cell to change its
tags: pick from the tags in use or type new ones, then **OK**. To tag several
at once, select their rows (Shift+click, Ctrl+click) or tick them, right-click
the table and choose **Edit tags...** (the selected rows) or **Edit tags
(ticked)...**, then **Add to all** or **Remove from all**. The tags are saved
in each recording's manifest, so the pipeline app and the analysis app see
them too. After the next **Scan**, a recording you retagged is computed again.

The result is named after the filter's tags (`ofc_StimOnset_Hit_FiringRate`),
and every row of it carries its recording's tags (the Tags column), so a
script can split or check the result by tag. The browser reopens with the
same filter, so the same group can be computed again later: press **Tick
shown only** and **Compute** to take in the recordings tagged since.

## Record values on recordings

[Variables](pipeline-app-guide.md#record-values-on-your-datasets) are values
you record on a recording: a probe depth, a dose, a cohort number. Click a
recording's **Variables** cell, or select (or tick) rows, right-click the
table and choose **Edit variables...** (**Edit variables (ticked)...**). The
window has a row per recording and a column per variable: **New variable**,
type its label (the name tables use is suggested), then each recording's
value, and **OK**. Only the latest value is kept; the manifest viewer
(right-click, **Open manifest viewer**) shows when each one changed. Every
row of a result carries its recording's values, one column each
(`var_probeDepth`), so a script can sort or split the result by them.

## Common tasks

| ...do this | Do this |
| --- | --- |
| compare the same measure across two definitions of the event or trials | keep each as an **Event & trial definition** (**+**), then switch between them in one click |
| keep only single units, not multiunits | tick **units** in **Data**, then on **Measure** tick **su** under **Unit classes** (and leave **mua** unticked) before **Compute** |
| look at single trials, not just the averages | tick **Keep single trials, not just averages** before **Compute** |
| get the whole recording, not cut around events (for a model or a toolbox) | **Raw Data** (or **Trials Only** for the behavior alone) |
| use less memory, or work at a lower rate (an LFP at 250 Hz, say) | **Downsample...** beside **Data**: type a rate for each signal (blank keeps the rate on file), **OK**. The signal is filtered first, so nothing aliases. The window shows the band that passes unchanged (up to 0.38 × the new rate) |
| hand the data to FieldTrip, Chronux, neuroGLM, the mTRF toolbox or a CSD estimate | pick that script in the **Post-processing script** list and **Run now** |
| run the same computation without the window | **File → Export compute script...** |
| compute faster | set **Workers** to compute several recordings at once (needs the Parallel Computing Toolbox and memory for one recording per worker) |
| start a recording again from scratch | right-click the table: **Forget cached (ticked)** |
| tag the recordings you picked (`cohort-3`) | tick them, right-click the table: **Edit tags (ticked)...**, type the tag, **Add to all**, **OK** |
| see how a recording was processed (its manifest) | click its row, then right-click the table: **Open manifest viewer** (or **File → Open manifest viewer**) |

## When something goes wrong

- **A recording is missing from the result.** Look at its **Cached** cell
  (red: *skipped: ...* with the reason, or *error*) and at the line at the
  bottom, which names the recordings that were not computed. **Details...**
  (or right-click the table: **Details of the last run...**) lists every
  recording of the last **Compute** with its status and the whole reason.
  *Skipped* means the recording has nothing to give these settings (no
  sorted units, no LFP, ...): run the missing pipeline step, or untick it.
  *Error* means something failed: the reason says what; fix it and press
  **Compute** again (only the failed recordings are computed again).
- **An edit is undone at once.** The setting does not fit the others; the
  status line at the bottom says why.
- **A script fails.** The status line names the script and the line; the
  result is kept, so fix the script and press **Run now** again.
- More: [Errors and warnings](DatasetBrowser.md#errors-and-warnings).

<!-- wiki: ![The Details window after a Compute: a row per recording and kind of data, with its status](images/dataset-browser-details.png) -->

## Next

<!-- wiki
- To use the result in your own MATLAB code, write a post-processing script, or compute without the window: [Dataset browser scripting](Dataset-Browser-Scripting).
- To take the data into an analysis toolbox: [Toolbox connectors](Analysis-Toolbox-Exports), [neuroGLM](NeuroGLM-Connector), [mTRF](mTRF-Connector), [current source density](CSD-Connectors).
-->
- To look at the units of a recording one at a time: the
  [analysis app guide](analysis-app-guide.md).
