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

- **Top row:** the project folder (**Root**), the dataset name **Pattern**,
  and **Scan** to list the recordings again.
- **Left:** the filter, and the table of recordings. Tick **Use** for each
  recording to include. **Tick shown only** ticks what the filter shows;
  **Untick all** clears the ticks. The **Cached** column says which
  recordings are already computed with these settings (green), computed
  with other settings (yellow) or have nothing to compute (red).
- **Right:** the settings, in tabs:
  - **Data**: what to measure: sorted `units`, `detected` spikes, or a
    signal (`LFP`, `MUA`, `SPIKE`, `AUX`). Tick several to get one result
    for each.
  - **Event**: the event to align to and the window around it, as in the
    analysis app's Alignment tab. **Epoch Diagram** draws how the epochs are
    cut on one recording.
  - **Trials**: which trials count (hits only, say) and how they are grouped
    (by `Depth`, say). **Epochs per group** counts them.
  - **Channels**: which shanks or channels to keep, picked on the probe.
  - **Measure**: firing rate, count or auROC, the bin size, and an optional
    normalization against the baseline.
- **Bottom:** **Compute**, the post-processing script, and a progress bar
  with **Cancel**.

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
   200 bins × 5 groups from 32 of 34 recordings*.
5. **Use the result.** Pick a script in the **Post-processing script** list
   (start with `S_DatasetBrowserBasicOutput`, which sorts the units and the
   groups and draws a summary), and press **Run now**; or tick **Run it after
   each Compute or Load** to run it every time.
6. **Save the settings** (**File → Save settings**) to compute the same thing
   again later, or on other recordings.

## Pick recordings by tag

The browser is where [tags](pipeline-app-guide.md#tag-your-datasets) pay
off most. Tag your recordings in the pipeline app (by area, cohort,
condition, training stage), and here a group is one filter away:

- **Tags** *any of* `ofc`, `acx` keeps the recordings with either tag;
  *all of* `ofc`, `cohort-3` keeps those with both.
- **not** `pilot`, `exclude` leaves out every recording with either tag.
- **Tick shown only** ticks exactly what the filter shows.

The result is named after the filter's tags (`ofc_StimOnset_Hit_FiringRate`),
and every row of it carries its recording's tags (the Tags column), so a
script can split or check the result by tag. The browser reopens with the
same filter, so the same group can be computed again later: press **Tick
shown only** and **Compute** to take in the recordings tagged since.

## Common tasks

| ...do this | Do this |
| --- | --- |
| compare the same measure across two definitions of the event or trials | keep each as an **Event & trial definition** (**+**), then switch between them in one click |
| look at single trials, not just the averages | tick **Keep single trials, not just averages** before **Compute** |
| get the whole recording, not cut around events (for a model or a toolbox) | **Load whole sessions** (or **Load trials only** for the behavior alone) |
| hand the data to FieldTrip, Chronux, neuroGLM, the mTRF toolbox or a CSD estimate | pick that script in the **Post-processing script** list and **Run now** |
| run the same computation without the window | **File → Export compute script...** |
| compute faster | set **Workers** to compute several recordings at once (needs the Parallel Computing Toolbox and memory for one recording per worker) |
| start a recording again from scratch | right-click the table: **Forget cached (ticked)** |

## When something goes wrong

- **A recording is missing from the result.** The result lists every ticked
  recording with its status (done, cached, skipped or error) and the reason.
- **An edit is undone at once.** The setting does not fit the others; the
  status line at the bottom says why.
- **A script fails.** The status line names the script and the line; the
  result is kept, so fix the script and press **Run now** again.
- More: [Errors and warnings](DatasetBrowser.md#errors-and-warnings).

## Next

<!-- wiki
- To use the result in your own MATLAB code, write a post-processing script, or compute without the window: [Dataset browser scripting](Dataset-Browser-Scripting).
- To take the data into an analysis toolbox: [Toolbox connectors](Analysis-Toolbox-Exports), [neuroGLM](NeuroGLM-Connector), [mTRF](mTRF-Connector), [current source density](CSD-Connectors).
-->
- To look at the units of a recording one at a time: the
  [analysis app guide](analysis-app-guide.md).
