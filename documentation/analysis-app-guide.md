# Analysis app guide

The analysis app, `EphysAnalysisApp`, draws figures of recordings the
[pipeline app](pipeline-app-guide.md) has processed: rasters, PSTHs, evoked
potentials, firing rates, tuning curves, heat maps, probe maps, spectra and
more. You design a figure once, see it on one unit, and then draw it for
every unit of every recording you choose, with an HTML or PDF report that
collects them. This page is for people who use the app; it needs no
programming beyond the line that opens it. The
[app's reference](EphysAnalysisApp.md) has the details of every control.

<!-- wiki: ![The analysis app, Figures tab, previewing a unit's raster over its PSTH, grouped by Depth](images/analysis-figures-tab.png) -->

## What it does

- **Aligns** every figure to an event: any digital line the recording saw (a
  stimulus, a lever press, the trial start), its onset or offset, the first
  in each trial or all of them, or a sequence ("the first Trough onset after
  each trial ends").
- **Chooses and groups trials** by the behavior: only hits, say, grouped by
  the stimulus `Depth`.
- **Draws figures** made of panels you stack on a grid: a raster flush above
  its PSTH above the LFP of the same unit's channel is one figure. A figure
  is drawn for each sorted unit, each channel, or once for the whole
  recording, or across several recordings (one color per session, or a mean
  with an error band).
- **Writes** each figure as PNG, SVG, EPS or PDF files and collects them
  into a report.

The app only reads what the pipeline wrote; it never changes a recording or
its processed files.

## Before you start

The recordings must have been processed by the pipeline: sorted units or
detected spikes for the spike figures, the LFP or MUA signals for the signal
figures, and paired behavior trials to choose or group trials by the
behavior. A figure the data cannot support says why instead of drawing
([Why is my figure skipped?](EphysAnalysisApp.md#why-is-my-figure-skipped)).

## Open the app

```matlab
EphysAnalysisApp("D:\EPHYS")       % your project folder, the one the pipeline scanned
```

Or, from the pipeline app, **File → Open analysis app...** (it opens on the
pipeline's project). `EphysAnalysisApp` alone opens your last config.

## The five tabs

| Tab | Use it to |
| --- | --- |
| [Data](EphysAnalysisApp.md#data-tab) | choose where the recordings are, tick the ones to draw, and see the active one's lines and trial parameters |
| [Alignment](EphysAnalysisApp.md#alignment-tab) | set the event every figure aligns to, the time window around it, and which trials count and how they are grouped. The counts on the right say how many trials fall in each group |
| [Figures](EphysAnalysisApp.md#figures-tab) | design figures and preview them on one unit, channel or recording at a time |
| [Export](EphysAnalysisApp.md#export-tab) | choose the file formats and the report, then draw everything |
| [Log](EphysAnalysisApp.md#log-tab) | read what each scan, preview and run did |

**Help → Help for this tab** opens the page for the tab you are on.

## Your first figure

1. **Data.** The project is scanned when the app opens. Click a recording in
   the table to make it the *active* one: the previews show it.
2. **Alignment.** Pick the **Line** to align to (a stimulus line, say) and
   the **Edge** (onset). Set the window, for example 0.2 s before to 0.8 s
   after. Pick a trial parameter in **Group by** (`Depth`, say) to draw one
   color per value. The numbers on the right are the trials in each group.
3. **Figures.** Press **Add** under the figure list. A window asks for the
   first panel: pick *Raster*. Then **New panel...** puts another panel next
   to it: a *PSTH* **Below** the raster. The preview on the right draws the
   figure for the unit picked above it; step through the units to look at
   them one by one.
4. **Export.** Tick the formats (png, svg, pdf), press **Run**, then **Open
   report**.
5. **File → Save config** keeps it all: the alignment, the figures and the
   export settings.

## Common tasks

| ...do this | Do this |
| --- | --- |
| change how a figure looks (colors, line widths, fonts, axis labels) | right-click a part of the preview and edit it there, or pick a ready-made look in the **Design** menu (journal, talk, ...) |
| give one figure its own event or window | in the figure's panel settings, set its own event reference and epoch window; the Alignment tab is only the default |
| draw a figure across several recordings | tick **Across sessions** in the figure's Sessions section |
| draw a small figure at every unit's place on the probe | tick **On the probe** in the figure's Probe layout section |
| check one unit's figures before a long run | Export tab: **Test report** |
| undo an edit | **Edit → Undo** (Ctrl+Z) |
| copy a change to the other figures | **Edit → Apply last change to figures...** |
| mark a recording, channel or unit to find again | the **☆** star next to it; **Favorites** lists them |
| keep a note on a recording, channel or unit | the notepad (see [Notes](EphysAnalysisApp.md#notes)) |
| draw the same figures every time the pipeline runs | save the config, then choose it on the pipeline app's Analysis tab |
| draw the same figures from a script | **File → Generate script** |

## Use your tags

[Tags](pipeline-app-guide.md#tag-your-datasets) are short words put on
recordings in the pipeline app (`ofc`, `cohort-3`, `pilot`). Here, on the
Data tab, the **Tags** column shows them, and the **Tags** filter above the
table shows just the recordings with a tag (*any of* or *all of* several),
or leaves some out (**not**). **Tick shown only** then ticks exactly that
group for a run. The reports show each recording's tags in its header and
tables, so a figure is never far from what the recording was. Tag your
recordings in the pipeline app's Project tab; it takes seconds, and it is
the quickest way to draw the same figures for one group of recordings.

## Words you will see

| Word | Means |
| --- | --- |
| dataset | one recording, as the pipeline processed it |
| observation | what one copy of a figure is drawn for: a sorted unit, a channel, or the whole dataset |
| epoch | the stretch of time around one event that a figure uses |
| group | the trials that share a value of the **Group by** parameter; each group gets its own color |
| panel | one plot of a figure (a raster, a PSTH, a probe map, ...) |
| config | everything you set in the app, saved as a `.json` file |

## When something goes wrong

- **A figure says it cannot be drawn.** It says why: no sorted units, no LFP,
  no paired trials, no trials left after the filter. See
  [Why is my figure skipped?](EphysAnalysisApp.md#why-is-my-figure-skipped)
- **The Export tab's Plan** lists every recording and figure that would run,
  and why any would be skipped, before you run anything.
- **The Log tab** has the details of every run.
- **Still stuck?** **Help → Report an issue on GitHub...**

## Next

- To gather many recordings' responses into one table for your own analysis
  or statistics: the [dataset browser guide](dataset-browser-guide.md).
<!-- wiki
- To draw these figures from a script, or to use the analysis functions in your own code: [Analysis scripting](Analysis-Scripting) and [Analysis configs](Analysis-Configs).
-->
