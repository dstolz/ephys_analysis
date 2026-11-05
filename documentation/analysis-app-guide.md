# Analysis app guide

The analysis app, `EphysFigGenApp`, draws figures of recordings the
[pipeline app](pipeline-app-guide.md) has processed: rasters, PSTHs, evoked
potentials, firing rates, tuning curves, heat maps, probe maps, spectra and
more. You design a figure once, see it on one unit, and then draw it for
every unit of every recording you choose, with an HTML or PDF report that
collects them. This page is for people who use the app; it needs no
programming beyond the line that opens it. The
[app's reference](EphysFigGenApp.md) has the details of every control.

<!-- wiki: ![The analysis app, Figures tab, previewing a unit's raster over its PSTH, grouped by Depth](images/analysis-figures-tab.png) -->

## What it does

- **Aligns** every figure to an event: any digital line the recording saw (a
  stimulus, a lever press, the trial start), its onset or offset, the first
  in each trial or all of them, or a sequence ("the first Trough onset after
  each trial ends").
- **Chooses and groups trials** by the behavior: only hits, say, grouped by
  the stimulus `Depth`.
- **Draws figures** made of panels you place anywhere on the page: a raster
  flush above its PSTH above the LFP of the same unit's channel is one figure. A figure
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
([Why is my figure skipped?](EphysFigGenApp.md#why-is-my-figure-skipped)).

## Open the app

```matlab
EphysFigGenApp("D:\EPHYS")       % your project folder, the one the pipeline scanned
```

Or, from the pipeline app, **File → Open analysis app...** (it opens on the
pipeline's project). `EphysFigGenApp` alone opens your last config.

## The five tabs

| Tab | Use it to |
| --- | --- |
| [Data](EphysFigGenApp.md#data-tab) | choose where the recordings are, tick the ones to draw, and see the active one's lines and trial parameters |
| [Alignment](EphysFigGenApp.md#alignment-tab) | set the event every figure aligns to, the time window around it, and which trials count and how they are grouped. The counts on the right say how many trials fall in each group |
| [Figures](EphysFigGenApp.md#figures-tab) | design figures and preview them on one unit, channel or recording at a time |
| [Export](EphysFigGenApp.md#export-tab) | choose the file formats and the report, then draw everything |
| [Log](EphysFigGenApp.md#log-tab) | read what each scan, preview and run did |

**Help → Help for this tab** opens the page for the tab you are on.

## Your first figure

1. **Data.** The project is scanned when the app opens (if not, type the
   **Project root** and press **Scan**). Click a recording in the table to
   make it the *active* one: the previews show it.
2. **Alignment.** Pick the **Line** to align to (a stimulus line, say) and
   the **Edge** (onset). Set the window, for example 0.2 s before to 0.8 s
   after. Pick a trial parameter in **Group by** (`Depth`, say) to draw one
   color per value. The numbers on the right are the trials in each group.
3. **Figures.** Press **Add** under the figure list. A window asks for the
   first panel. Pick *Raster over PSTH* under **Saved figures** for a unit's
   raster above its PSTH, or pick *Raster* to start with one panel.
   - To add a panel, press **New panel...**. **Largest empty space** puts it
     where no panel is yet. *Below*, *Above*, *Right of* or *Left of* splits
     the selected panel in two, flush: the new panel takes the half on that
     side.
   - To move or resize a panel, press **Arrange** above the preview. Every
     panel gets a box. Drag a box to move it; drag a corner or an edge to
     resize it. The box snaps to the other panels and the page (hold **Alt**
     to stop that), and magenta lines and distances show what lines up. Arrange
     needs the Image Processing Toolbox; without it, type the numbers below.
   - To place a panel exactly, type its **Position** and **Size** in the
     **Panels** section, in the **Units** you pick (cm, inches, pixels, %).
     Or press **Set corners** and click two opposite corners on the preview.
   - The preview on the right draws the figure for the unit picked above it.
     Step through the units to look at them one by one. Right-click the plot
     to change colors, fonts and labels.
4. **Export.** Tick the formats (png, svg, pdf), press **Run**, then **Open
   report**.
5. **File → Save config** keeps it all: the alignment, the figures and the
   export settings.

## Common tasks

| ...do this | Do this |
| --- | --- |
| change how a figure looks (colors, line widths, fonts, axis labels) | right-click a part of the preview and edit it there, or pick a ready-made look in the **Design** menu (journal, talk, ...) |
| write a label that follows the data, such as *Time (s) re Stim onset* or *Hit trials* | type a variable in braces in a title, an axis label, a layer's name or a note: **Time (s) re {Line} {Edge}**, **{Response} trials**. Each figure fills it in. The **{x}** button beside the field lists them, with what each means (see [Labels that follow the data](#labels-that-follow-the-data)) |
| give one figure its own event or window | in the figure's panel settings, set its own event reference and epoch window; the Alignment tab is only the default |
| draw a figure across several recordings | tick **Across datasets** in the figure's Sessions section |
| draw a small figure at every unit's place on the probe | tick **On the probe** in the figure's Probe layout section |
| check one unit's figures before a long run | Export tab: **Test report** |
| undo an edit | **Edit → Undo** (Ctrl+Z) |
| move or resize a panel | press **Arrange** above the preview and drag the panel's box (a corner or an edge resizes it); after a click on the preview the arrow keys nudge it. Or pick it (Ctrl+Click it in the preview) and type its **Position** and **Size** in the Panels section; **Units** picks cm, inches, pixels or a share of the page. **Bring forward** and **Send back** set which of two overlapping panels is on top (see [Arranging panels on the preview](EphysFigGenApp.md#arranging-panels-on-the-preview)) |
| change a setting on several panels at once | **Shift+Click** the panels in the preview: each is outlined, and the Panel header turns blue and names them. The editor shows only the settings they all have; what you change goes to all of them (one Undo takes it back). **Esc** goes back to one panel (see [Several panels at once](EphysFigGenApp.md#several-panels-at-once)) |
| move or resize several panels together | **Shift+Click** them, then press **Arrange** (or press Arrange and **Shift**+click their boxes), then drag one of them: all move by the same amount (resizing one resizes each by the same amount); the arrow keys nudge them all |
| put the legend where you want it | with **Arrange** on, drag the legend's dashed box where you want it: it becomes a legend panel there. Or **New panel...** → *Legend*: a panel of its own that holds the figure's legend; place and size it as any panel. Appearance → **Legend** picks *Auto*, *Inside* or *None*; the legend never makes a plot smaller |
| keep labels from running into the next panel, or make a rect mean the whole panel with its labels | in the **Panels** section, **Padding** is the clear space kept around labels, and **Boxes mean** says whether a rect is the plot area (labels kept clear) or the outer box (labels inside it) |
| copy a change to the other figures | **Edit → Apply last change to figures...** |
| mark a recording, channel or unit to find again | the **☆** star next to it; **Favorites** lists them |
| keep a note on a recording, channel or unit | the notepad (see [Notes](EphysFigGenApp.md#notes)) |
| reuse a figure's panels in other figures | select it and press **Save as panel type...** under the figure list. In any figure, **New panel...** then lists it under **Saved figures**: pick it, and all its panels go into the free space or beside the selected panel, arranged as they were (see [Saved figures as panel types](EphysFigGenApp.md#figures-as-panel-types)) |
| draw the same figures every time the pipeline runs | save the config, then choose it on the pipeline app's Analysis tab |
| draw the same figures from a script | **File → Generate script** |

## Labels that follow the data

A label can say what the figure shows without being retyped for every
unit or event. Type a variable in braces, and each figure fills it in:

- **Time (s) re {Line} {Edge}** shows *Time (s) re Stim onset*.
- **{Response} trials** shows *Hit trials* (*all trials* with no response
  picked).
- **{Unit}: {Response}** as a title shows *su12: Hit*, a different unit on
  every page.
- **n = {Epochs}** in a note shows how many trials were drawn.

Click the **{x}** button at the right of a title, axis label, layer name or
note to pick one from a menu; each item says what it means and what it shows
for the figure in the preview now. **Help → Label variables** lists them all.
Type the name exactly as listed (*{Line}*, not *{line}*): **Validate** on the
Export tab points out a name it does not know.

## Use your tags

[Tags](pipeline-app-guide.md#tag-your-datasets) are short words put on
recordings in the pipeline app (`ofc`, `cohort-3`, `pilot`). Here, on the
Data tab, the **Tags** column shows them, and the **Tags** filter above the
table shows just the recordings with a tag (*any of* or *all of* several),
or leaves some out (**not**). **Tick shown only** then ticks exactly that
group for a run. Save the config and the filter is saved with it: the next
time you open the config, the table shows the same group. The reports show each recording's tags in its header and
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
| panel | one plot of a figure (a raster, a PSTH, a probe map, ...), placed on the page by its own rectangle |
| config | everything you set in the app, saved as a `.json` file |

## When something goes wrong

- **A figure says it cannot be drawn.** It says why and what to do: *No LFP
  signal: switch on LFP in the pipeline's Signals tab and run it*, *No paired
  trials: approve the pairing on the pipeline's Trials tab*, and so on. See
  [Why is my figure skipped?](EphysFigGenApp.md#why-is-my-figure-skipped)
- **The Export tab's Plan** lists every recording and figure that would run,
  and why any would be skipped, with a *What to do* column, before you run
  anything. Double-click a row to see that figure.
- **Validate** lists the problems of the config on the Export tab.
  Double-click a row to go to the setting it is about. **Run** stops with a
  message that names the first problem and takes you to the tab that fixes it
  (no recording ticked, no project root, a setting that does not fit).
- **A run** shows a bar, the time left and **Cancel** at the bottom of the
  window; you can look at the other tabs meanwhile. A figure that failed is
  in the results table with its message.
- **Right-click menus and keys.** **Help → Keyboard shortcuts and
  right-click menus** lists them.
- **The Log tab** has the details of every run.
- **Still stuck?** **Help → Report an issue on GitHub...**

## Next

- To gather many recordings' responses into one table for your own analysis
  or statistics: the [dataset browser guide](dataset-browser-guide.md).
<!-- wiki
- To draw these figures from a script, or to use the analysis functions in your own code: [Analysis scripting](Analysis-Scripting) and [Analysis configs](Analysis-Configs).
-->
