# Analysis app guide

The analysis app, `EphysFigGenApp`, draws figures of recordings the
[pipeline app](pipeline-app-guide.md) has processed: rasters, PSTHs, evoked
potentials, firing rates, tuning curves, heat maps, probe maps, spectra, a
time or a count per trial compared across groups, and more. You design a figure once, see it on one unit, and then draw it for
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
behavior. A figure the data cannot support shows a gray square with a red
cross instead; point at it to see why
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
   make it the *active* one: the previews show it. The **Dataset** list on
   the Alignment and Figures tabs offers the recordings ticked in the
   table's **Run** column (all of them when none is ticked).
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
     panel gets a box. Click a box to select its panel: its width and height
     show under it. Drag a box to move it; drag a corner or an edge to
     resize it. The box snaps to the other panels and the page (hold **Alt**
     to stop that), and magenta lines and distances show what lines up. Arrange
     needs the Image Processing Toolbox; without it, type the numbers below.
     When you let go, the panel is in its new place at once. If it parts from
     a neighbor, the time labels and ticks catch up when you switch Arrange
     off, and the badge says **Out of date** until then. If it still says
     that, press **Preview** (Ctrl+P).
   - To line panels up, or space them evenly, use the bar that appears above
     the preview while **Arrange** is on. Click one box, **Shift**+click the
     others, then press a button: left edges, centers, right edges, tops,
     middles or bottoms; **Space** across or up for equal gaps. **Align**
     picks what lines up: the *boxes*, the *axes*, or the *axes + labels*
     (equal white space). **to** picks the *selection*, the *first selected*
     panel or the *page*. Leave **Gap** blank for even gaps, or type one.
     Each press is one step of Undo.
   - To remove a panel, select it and press **Remove panel**. It leaves the
     preview at once and the other panels stay where they are.
   - To place a panel exactly, type its **Position** and **Size** in the
     **Panel** section, in the **Units** you pick in **Layout** (cm, inches,
     pixels, %). Or press **Set corners** and click two opposite corners on
     the preview.
   - The settings column, between the figure list and the preview, has three
     parts, each a color. **FIGURE** (blue) is about the whole figure: what it
     is drawn for, its alignment, its page. **PANEL** (green) is about the
     selected panel: its layers, then **Analysis** (what is computed: a change
     computes the figure again), **Display** and **Axes** (how it is drawn: a
     change only redraws it) and **Annotations**. **LOOK** (violet) is about
     every panel's style and design. To find a setting, type its name in the
     search field above the column (**Ctrl+F**).
   - The preview on the right draws the figure for the unit picked above it.
     Step through the units to look at them one by one. Right-click the plot
     to change colors, fonts and labels, or press **Edit aesthetics...** in
     **Design and looks** (LOOK, in the settings column). After a change it draws again on
     its own when that is quick enough for the **Auto** slider left of it.
4. **Export.** Tick the formats (png, svg, pdf), press **Run**, then **Open
   report**.
5. **File → Save config** keeps it all: the alignment, the figures and the
   export settings.

## Common tasks

| ...do this | Do this |
| --- | --- |
| change how a figure looks (colors, line widths, fonts, axis labels) | right-click a part of the preview and edit it there, or open **Design and looks** under LOOK in the settings column: pick a ready-made look in **Design** (journal, talk, ...; the **Design** menu and the list beside **Dataset** are the same choice), press **Edit aesthetics...** to edit the selected panel's colors, lines and fonts (or right-click the preview), and **Save look as design...** to keep the preview's look as a design of your own. Fonts, line widths, colors and the legend are under **Style** |
| draw a smooth line over a PSTH's bars | select the PSTH and, in its **Display** section, tick **Smoothed line: Draw**. **SD (ms)** sets how smooth the line is; clear **Legend** to leave the line out of the legend; **Smooth SD (ms)** in **Analysis** still sets the bars' own smoothing, apart from the line's |
| write a label that follows the data, such as *Time (s) re Stim onset* or *Hit trials* | type a variable in braces in a title, an axis label, a layer's name or a note: **Time (s) re {Line} {Edge}**, **{Response} trials**. Each figure fills it in. The **{x}** button beside the field lists them, with what each means (see [Labels that follow the data](#labels-that-follow-the-data)) |
| put µ, ±, Δ, ° or another symbol in a label | type a backslash and its name: **Amplitude (\muV)** shows *Amplitude (µV)*; **\pm**, **\Delta** and **^\circ** show ±, Δ and °. It works in every title, axis label, legend name and note (see [Symbols and Greek letters](#symbols-and-greek-letters)) |
| give one figure its own event or window | for the whole figure, untick **Use default** under the event reference or epoch window in its **Alignment** section; for one panel, untick **Same as the figure** in its **Panel alignment** section. The Alignment tab is only the default |
| stop a sensor's brief blips from counting as new events (the animal touches the platform again as it leaves, or the beam drops out for a moment) | in the event reference, set **Refractory** to a time in seconds, such as 0.5: an interval that starts sooner than that after the one before ended is ignored. Or set **Stitch gaps (s)** to join intervals that close together into one visit, which then ends at the last offset. For a step of a sequence, the **Event sequence** window has the same two columns. The event rows above the plot are drawn the same way |
| draw a figure across several recordings | in the figure's Observations section, set **Pages** to *Across datasets*; its settings are in the Sessions section that appears |
| draw a small figure at every unit's place on the probe | in the figure's Observations section, set **Pages** to *On the probe*; its settings are in the Probe layout section that appears |
| keep only the units that respond to the event | in the figure's Observations section, tick **Responsive only**. Its settings (windows, correction, auROC) are in the **Response test** group under it: click **▸ Response test** to open it. The section colors tell the scope: blue sections are about the whole figure, green about the selected panel, violet about the look of every panel. Can't find a setting? Type its name in the search field above the editor |
| draw a figure for some channels or shanks only | in the figure's Observations section, press **Probe...** beside **On channels** (for units) or **Signal channels** (for an LFP or another signal). The probe of the active recording appears. Click a site to pick or drop its channel, or click a shank to pick or drop the whole shank. The filled sites are the ones kept; **All** keeps every one. Press **OK**. The same button is beside a fixed layer's channels and in the Probe layout section. You can also type the numbers, such as *1:16* (see [Picking channels on the probe](EphysFigGenApp.md#picking-channels-on-the-probe)) |
| check one unit's figures before a long run | Export tab: **Test report** |
| make previews faster and figure files smaller by lowering a signal's sampling rate (an AUX recorded at 30 kHz, say) | Data tab: press **Downsample...** and type a rate for that signal, such as *250* for the LFP or *100* for the AUX; leave a field blank to keep the rate on file. Press **OK**: every figure now reads that signal at the lower rate, and the button turns amber. The signal is filtered first, so no false low frequencies appear. The window shows the band each rate keeps unchanged: choose a rate at least 2.6 times the highest frequency you look at (see [Downsampling signals](EphysFigGenApp.md#downsampling-signals)) |
| see whether the LFP's phase lines up with the event from trial to trial (inter-trial phase coherence, ITPC) | **New panel...** → *Phase coherence (ITPC)*. Set **Frequency (Hz)**. Under **View**, pick *ITPC by frequency* for one line per trial group, or *time/frequency coherogram* for an image over time and frequency. The value runs from 0 (the phase is random from trial to trial) to 1 (every trial has the same phase). The dashed line is the level that random phases stay under, so values above it are locked to the event. To switch views later, tick or clear **Over time** in the panel's **Analysis** section. Fewer tapers (**TW, K** of *1, 1*) give the classic single-taper ITPC (see [Phase coherence panels](EphysAnalysisConfig.md#phase-coherence-panels)) |
| look at one EEG band of the LFP, such as theta or gamma | select the panel (a continuous signal, heat map, spectrum, spectrogram, coherence or phase coherence panel) and press **Filter...**, the first row of its **Analysis** section. Pick a band under **Start from**: *Theta*, *Alpha*, *Beta*, *Low gamma*, *High gamma* and others. The plots show what the filter keeps. Press **OK**: the panel now shows that band. The whole recording is filtered first and then cut into trials, so the trial edges are clean. To compare, draw the same channel in a second panel with no filter (see [A panel's filter](EphysFigGenApp.md#a-panels-filter)) |
| make your own filter and use it again later | in the **Filter** window, set **Cutoffs (Hz)**, **Design** and **Order**, type a name under **Save the settings as one of yours** and press **Save**. Your filter is now listed under **Start from**, in every config. *Zero-phase* (the default) shifts nothing in time; choose *Causal* to filter as a recording system would, with its delay |
| remove line noise, or filter a signal for every figure | Data tab: press **Filter...**, pick the signal (**Signal**, such as *LFP*) and a filter, such as *60 Hz line noise*. Press **OK**: every figure now reads that signal filtered, and the button turns amber. A panel's own filter runs after it (see [Filtering signals](EphysFigGenApp.md#filtering-signals)) |
| choose when the preview redraws after a change | drag the **Auto** slider left of the preview. Left end: never, press **Preview**. Right end: after every change, however slow. In between, the further right, the slower a redraw it starts on its own (the middle: under 2 s; point at the slider to see its limit). A change of colors, fonts or labels only redraws, so it is quick even when computing the figure is slow. **Ctrl+T** turns Auto off and on |
| undo an edit | **Edit → Undo** (Ctrl+Z) |
| move or resize a panel | press **Arrange** above the preview and drag the panel's box (a corner or an edge resizes it); after a click on the preview the arrow keys nudge it. Or pick it (Ctrl+Click it in the preview) and type its **Position** and **Size** in the Panel section; **Units** (in Layout) picks cm, inches, pixels or a share of the page. **Bring forward** and **Send back** set which of two overlapping panels is on top (see [Arranging panels on the preview](EphysFigGenApp.md#arranging-panels-on-the-preview)) |
| change a setting on several panels at once | **Shift+Click** the panels in the preview: each is outlined, and the Panel header turns blue and names them. The editor shows only the settings they all have; what you change goes to all of them (one Undo takes it back). **Esc** goes back to one panel (see [Several panels at once](EphysFigGenApp.md#several-panels-at-once)) |
| line panels up, or space them evenly | press **Arrange**, click one panel's box and **Shift**+click the others, then use the bar above the preview: the six align buttons, or **Space** across or up. Pick *axes* in **Align** to line up the plots themselves, *axes + labels* for equal white space; type a **Gap** for a set space between them (see [Lining panels up](EphysFigGenApp.md#lining-panels-up-and-spacing-them-evenly)) |
| move or resize several panels together | **Shift+Click** them, then press **Arrange** (or press Arrange and **Shift**+click their boxes), then drag one of them: all move by the same amount (resizing one resizes each by the same amount); the arrow keys nudge them all |
| put the legend where you want it | with **Arrange** on, drag the legend's dashed box where you want it: it becomes a legend panel there. Or **New panel...** → *Legend*: a panel of its own that holds the figure's legend; place and size it as any panel. Style → **Legend** picks *Auto*, *Inside* or *None*; the legend never makes a plot smaller |
| keep labels from running into the next panel, or make a rect mean the whole panel with its labels | in the **Layout** section (under **Page**), **Padding** is the clear space kept around labels, and **Boxes mean** says whether a rect is the plot area (labels kept clear) or the outer box (labels inside it) |
| hide a panel's axis label or tick numbers (say, on the inner panels of a grid) | select the panel, and in **Axes** set **Show (x, y)** to *ticks, no label*, *label, no ticks* or *neither* for that axis |
| see the low frequencies of a spectrogram, coherence or phase coherence panel better (a logarithmic frequency axis) | select the panel, and in **Axes** set **Frequency axis** to *logarithmic*. The low frequencies get more room, the ticks read 2, 5, 10, 20, 50 ... Hz, and the 0 Hz bin is left out. Nothing is computed again, so the preview redraws quickly |
| copy a change to the other figures | **Edit → Apply last change to figures...** |
| mark a recording, channel or unit to find again | the **☆** star next to it; **Favorites** lists them |
| keep a note on a recording, channel or unit | the notepad (see [Notes](EphysFigGenApp.md#notes)) |
| reuse a figure's panels in other figures | select it and press **Save as panel type...** under the figure list. In any figure, **New panel...** then lists it under **Saved figures**: pick it, and all its panels go into the free space or beside the selected panel, arranged as they were (see [Saved figures as panel types](EphysFigGenApp.md#figures-as-panel-types)) |
| plot the time between two events per trial and compare groups | see [Compare a time per trial across groups](#compare-a-time-per-trial-across-groups) below |
| draw the same figures every time the pipeline runs | save the config, then choose it on the pipeline app's Analysis tab |
| draw the same figures from a script | **File → Generate script** |

### Compare a time per trial across groups

To plot, for example, how long each trial took from the stimulus to the
animal leaving the platform, and whether that differs between trial groups:

1. In the Figures tab, press **Add** (or **New panel...** in a figure you
   have). Pick **Trial distribution**. Under **Key parameters**, set
   **Trial measure** to *Delay from an event to another*, **From (A)** to *Stim
   onset* and **To (B)** to *Platform offset*. Press **OK**: the panel
   draws one dot per trial.
2. To change the measure later, find the **Layers** section and press
   **Edit...** beside **Trial measure**. The *Trial measure* window shows both events
   with every option the Alignment tab has (which one, its scope, a sequence).
   The gray line at the bottom shows the name the measure will get. Press
   **OK**.
3. In **Analysis**, pick what goes along the x axis in **Categories**: *trial
   groups* (the groups of the figure's trial selection, such as *Depth*), *a
   trial parameter* (type its name, and the number of bins beside it), or
   *measure (layer)* to put several measures side by side. In **Display**, **Draw as** draws
   the values as a swarm, boxes, violins, points or a line.
4. The group test is drawn with the panel: brackets with stars over the pairs
   that differ, and the overall p in a corner. **Test** picks the test (*auto*
   chooses for you), **Show tests** how much is drawn. The same numbers are in
   the figure's caption and the report.
5. Right-click the plot and choose **Copy data table** to paste the
   per-trial numbers into a spreadsheet, or **Export data (CSV)...** to save
   them.

For one measure against another, pick **Trial scatter** instead (its **Trial
measure (x)** is the x axis); for the shape of one measure, **Trial histogram**.
Every option is in [Trial measures](EphysAnalysisConfig.md#trial-measures) and
the [Trial measure window](EphysFigGenApp.md#the-trial-measure-window).

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

## Symbols and Greek letters

To put a symbol in a label, type a backslash and the symbol's name. The
field keeps what you typed; the figure shows the symbol.

- **Amplitude (\muV)** shows *Amplitude (µV)*.
- **mean \pm SEM** shows *mean ± SEM*.
- **\Deltat (ms)** shows *Δt (ms)*.
- **Phase (^\circ)** shows *Phase (°)*.

Other names: **\alpha** α, **\beta** β, **\theta** θ, **\sigma** σ,
**\times** ×, **\leq** ≤, **\geq** ≥, **\approx** ≈, **\rightarrow** →,
**\infty** ∞. Greek letters work small (**\gamma**) and capital
(**\Gamma**). This works in a figure's title, a panel's title, the axis
labels, a layer's name in the legend, a text note and a trial measure's
label. More are listed in
[Special characters](EphysFigGenApp.md#special-characters).

Only the names change. An underscore or a caret stays as it is, so unit and
dataset names print correctly.

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

## Record values on your recordings

[Variables](pipeline-app-guide.md#record-values-on-your-datasets) are values
you record on a recording: a probe depth, a dose, a cohort number. Click a
recording's **Variables** cell on the Data tab, or select rows and
right-click the table, **Variables...**: a window shows a row per
recording and a column per variable. **New variable**, type its label (the
name tables use is suggested for you), then each recording's value; **OK**
saves them in the recordings' manifests. Change a value whenever you like:
only the latest is kept, and **View manifest...** (same right-click menu)
shows when each one changed. The values come with the data into the tables
the app writes (a `var_probeDepth` column) and the reports. They do not
change any figure yet.

## Words you will see

| Word | Means |
| --- | --- |
| dataset | one recording, as the pipeline processed it |
| observation | what one copy of a figure is drawn for: a sorted unit, a channel, or the whole dataset |
| epoch | the stretch of time around one event that a figure uses |
| group | the trials that share a value of the **Group by** parameter; each group gets its own color |
| panel | one plot of a figure (a raster, a PSTH, a probe map, ...), placed on the page by its own rectangle |
| FIGURE, PANEL, LOOK | the three parts of the settings column: the whole figure, the selected panel, and the style every panel shares |
| pages | how a figure is paged (**Pages**, in Observations): one per observation, across datasets, or on the probe |
| config | everything you set in the app, saved as a `.json` file |

## When something goes wrong

- **A figure or a panel shows a gray square with a red cross.** It cannot be
  drawn. Point at the square to see why, or click it to read why in a window.
  The reason says what to do: *No LFP signal: switch on LFP in the pipeline's
  Signals tab and run it*, *No paired trials: approve the pairing on the
  pipeline's Trials tab*, and so on. A small square in a panel's bottom left
  corner means some of its layers were left out. See
  [Why is my figure skipped?](EphysFigGenApp.md#why-is-my-figure-skipped)
- **The preview says *Out of date*.** The figure changed and was not drawn
  again: **Auto** is off, or the redraw would take longer than Auto allows
  (the line under the preview says *slow*). Press **Preview**, or drag the
  **Auto** slider to the right.
- **A spectrum drops off at its top end, or Validate warns about *fpass*.**
  The signal was downsampled (Data tab, **Downsample...**), and the filter
  that keeps the lower rate clean also lowers the highest frequencies. Lower
  the panel's top frequency (**fpass**) to the value the warning names, or
  give that signal a higher rate.
- **A filtered panel is skipped with *reaches the Nyquist frequency*.** The
  filter's top cutoff is too high for the signal's sampling rate (a 60-150 Hz
  band on an LFP downsampled to 250 Hz, say). Lower the cutoffs in
  **Filter...**, or give the signal a higher rate (Data tab,
  **Downsample...**).
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
