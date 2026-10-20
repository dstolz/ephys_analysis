# ephys_analysis TO DO

## Instructions for Claude

Evaluate each item below and determine if it is still relevant. If it is, then provide a brief description of what needs to be done to complete the task. If it is not relevant, explain why it can be removed from the list.

You are the managing process. First, evaluate all items in the list and process them in an efficient order determined by you. Tune subagents to use Sonnet 5.5 or Opus 5.5 as you see fit based on the item's needs. Also tune effort for each agent as you see fit. Ask questions if you need clarification or guidance on any of the items.

Provide a concise summary of the completed tasks and any remaining items that need attention. Update the TO DO list accordingly. If you have any suggestions for new tasks or improvements, please add them to the "Suggestions" section at the end of the document, but do not process unless I move them to the TO DO list.

## TO DO

_(empty: every item of the 2026-10-19 list is under Done)_

## Suggested TO DOs --- STOP READING HERE
_DO NOT PROCESS UNLESS MOVED TO THE TO DO LIST_

- **Check the new Figures-tab keys by hand.** The app tests send made-up key events, since a test MATLAB cannot take the foreground. Confirm on Windows that Alt+1/2/3 (supersections), Ctrl+F (search), Ctrl+] / Ctrl+[ and Ctrl+Alt+arrows (panels), F6 / Shift+F6 (columns) reach the window, that Enter / Up / Down / Escape work while typing in the search field, and that Tab follows the editor's order. Ctrl+Alt+arrows rotate the screen on some Intel graphics drivers (Ctrl+] / Ctrl+[ are the fallback).
- **Figure file names follow automatic ids.** A figure whose id is automatic ("Raster+PSTH units") is renamed when its content changes, and its `{Plot}` file names with it. Decide whether exports should pin the id (e.g. untick auto on the first Run).
- **Dataset unit counts before a dataset is opened.** The counts come from the units the Data tab reads when a dataset is opened; a small per-dataset count cache written by the pipeline would show them for every dataset at once.
- **`modulationWindow.m` uses `xregion`** for the auROC window shading, which MATLAB paints behind opaque patches: the same cause as the raster patch-overlay bug fixed today. Draw it as a patch if it ever has to sit over raster bands.
- **One list of baseline modes per panel type.** The modes each type takes are written in three places (`validate`, `figureEditorChoices`, `adoptPanelOptions`); one static helper would keep them in step.
- **Event traces:** sort a trace panel's per-epoch rows as a raster sorts; a minimum drawn width for zero-length intervals in bars mode; event traces in session figures (refused today); the session messages read "a eventTrace panel" (article). Translucent trace lines use MATLAB's undocumented RGBA line color, which SVG export may flatten.
- **Data tips:** per-trial tips on a continuous panel's trial traces; a heat map of more than 40 rows shows row numbers instead of names in its tips; the figure-wide data-cursor function also gives other plots in the app window (the Alignment preview) a plain X/Y tip; the figure title has no "Data tip fields..." item.
- **Layout engine:** reading the legend's size costs about 0.25 s per draw (cacheable); a note in a band beside a panel could now be listed in the aesthetics editor; the loose / compact / tight presets are fixed pixel gaps that only roughly match the old tiled-layout spacing.
- **New panel window:** remember the last type picked; richer thumbnails for the probe map and event traces (`tools/makePanelThumbnails` uses a small fixture).
- **Search hidden-row reasons** (`private/figureRowReason`) repeat `syncFigureEditor`'s visibility rules: a new option row needs an entry there for a specific message.
- **Click a panel in the preview to select it** (the outline follows keys and the schematic today). The outline's top edge also crosses the figure's subtitle when the selected panel is the top one; inset it, or draw it round the plot area only.
- **Chronux file helpers.** With the Chronux tab gone, `loadChronuxExport`, `chronuxPairs` and `chronuxSpikeTrains` serve only scripts and each other. Keep them unless the "analyze a Chronux file by script" route is retired too.
- **Wiki and screenshots** for the 2026-10-19 Figures-tab changes (supersections, New panel window, Spacing window, event traces, data tips; the Chronux tab page removed).
- **Real-data checks of the 2026-10-05 batch.** All of it ran on synthetic and test data. Still to see on real recordings: Intan's software notch on a pre-3.0 `.rhd` recorded with the notch on, and the Visualize envelope's build time and disk load on a full 2 h × 64-channel recording on the USB disk. Envelope builds are not paused while a pipeline run reads the same disk.
- **Let the Sorting step write the `.bin`'s envelope.** `EphysTraceEnvelope.build()` exists. Writing it next to the `.bin` would save the first wide Visualize view of it a full read.
- **Clean up: NWB files.** `planLocalCleanup`'s `"export"` kind does not remove `<Name>.nwb` or `<Name>_nwbinspector.json`.
- **The pipeline app's window title** still reads "Ephys preprocessing - <name>" (`buildUI`, `updateTitle`) after the rename to `EphysPipelineApp`.
- **Wiki screenshots in one run.** On 2026-10-05, `wikiScreenshots` lost the app window at the Run tab shot twice, after the earlier tabs (MATLAB's embedded browser view was killed during `exportapp`). Each shot works on its own, so the shots were taken in two MATLAB runs. The script could open a fresh app window per group of shots.
- **API pages for the remaining classes.** `AppPrefs`, `TableSort`, `KCSDExport`, `PipelineDiagram`, `PlotAesthetics` and `PlotAestheticsDialog` have no API page: `tools/wiki/gen_api.py` skips classes outside its maps. (New since: `FigureDataTips`, `DataTipFieldsDialog`.)
- **`EphysDataset.sortRunProcesses` off Windows.** Its `pgrep` path is untested, and it is not listed in `platformSupport` / `platforms.md`.
- **The standalone analysis script writes no run record**, so the compact-vs-standalone test cannot compare the runner's `analysis_runs/` record with one.

## Done

### 2026-10-19: EphysAnalysisApp, Figures tab (branch `todo-figures`)

- **Common options moved to each panel** (c2bf4ef). The figure-level `common` block and the Common options section are gone; each panel's Options hold all its rows. *Apply to all panels* copies the shared rows (bins, measure, baseline, mask, inset) to every panel that has them and the rest to panels of the same type (`sharedFieldsOf`, `adoptPanelOptions`).
- **Keys to switch panels; the active panel marked on the preview** (9e58e55). Ctrl+] / Ctrl+[ step through the panels, Ctrl+Alt+arrows move across the grid; a blue outline marks the selected panel in the preview only, without a redraw.
- **Search field for parameters** (9e58e55). *Find a setting by name* (Ctrl+F) over every row, listed as *Supersection > Section > Row*; going there opens, scrolls, focuses and highlights the row, or says why a row is hidden.
- **Box around individual panels** (412cae2). Panel field `box` (auto / on / off) in the Selected panel section; on and off win over designs and remembered looks.
- **Open the figure in a MATLAB figure window** (ea6fc4c). *Open in window* under the preview draws the previewed figure into a `figure()` with the right-click editor; it does not follow later edits.
- **Smarter figure ids; duplicates "(2)"; data and panel types in the id** (9999220). Field `autoId`: the id follows the content ("Raster+PSTH units", "Continuous LFP") until one is typed; Duplicate gives "<id> (2)"; renames are followed by what refers to the figure.
- **TTL-like event traces panel** (af0ce63). New panel type `eventTrace` (Event traces): a row per event line, bars or a logic-level line, every epoch overlaid (default) or a sub-row per epoch, baselines, full color and line control (and aesthetics roles).
- **Template drop-down removed; Arrangement renamed Panels** (9999220). Add makes a blank figure and opens the New panel window; the Panel section is now *Selected panel*.
- **New panel dialog with schematics** (9999220). *New panel...* opens a window with a small real plot of every panel type (`analysis/icons/panels`, `tools/makePanelThumbnails`), the name, title, place and key parameters.
- **Per-panel size independent of its row / column** (c7812d7). Panel `size` (% of its cell) and `align` / `valign`, drawn by renderFigure's own layout engine (no tiled layout; exact row heights and column widths).
- **Manual spacing between panels** (c7812d7). `grid.spacing` "custom" with gaps in px or %, one each way or per row / column, set in the new *Panel spacing* window (Spacing...).
- **Counts in the Dataset and Observation drop-downs** (c699d9b). *subj1_day1  (14 units)*; *su12  ch 7  -320 µm  (5,210 spikes)*.
- **Design drop-down and Save look as design... beside Dataset / Observation** (ea6fc4c; 6193784 put Preview, Generate, Auto and < > on a row of their own so the drop-downs keep their width at the default window size).
- **Patch overlays on rasters fixed** (412cae2). They were drawn with `xregion` / `yregion`, which MATLAB paints behind the raster's opaque group bands; they are real patches now, kept to the axes' limits.
- **Events drawn as a line from onset to offset** (af0ce63). Layer *Draw as* "a line from onset to offset" (`eventsAs "span"`): a line per epoch on a raster, a median-onset-to-offset line per group on PSTH, signal and heat map panels, with its own style, width and opacity.
- **Observation data types** (c699d9b). One *Observe* drop-down (`observe.data`): Sorted units, Detected spikes, LFP, MUA, SPIKE, AUX or The dataset, with what the dataset lacks marked; the rows below follow it ("auto" dropped).
- **Chronux plots as panels** (0fcf64d). The Power spectrum, Spectrogram and Coherence panels already compute from the extracts and units (the layer's Source picks the data; no Chronux file is needed), so the Chronux tab was removed.
- **Collapsible supersections with keys; keyboard navigation** (9e58e55). FIGURE / PANEL / LOOK (Alt+1/2/3), section keys Ctrl+1..0, F6 between columns, a keys window (**?**, Help → Figures tab keys).
- **Richer, customizable data tips** (0a09ce2). Tips name time, rate, trial, group, unit / channel, layer, panel, observation and dataset; *Data tip fields...* picks them (preference).
- **Raster y ticks hidden by default** (412cae2). Raster option `yTicks` (Show y ticks).
