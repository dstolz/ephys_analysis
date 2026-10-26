# ephys_analysis TO DO

## Instructions for Claude

Evaluate each item below and determine if it is still relevant. If it is, then provide a brief description of what needs to be done to complete the task. If it is not relevant, explain why it can be removed from the list.

You are the managing process. First, evaluate all items in the list and process them in an efficient order determined by you. Tune subagents to use Sonnet 5.5 or Opus 5.5 as you see fit based on the item's needs. Also tune effort for each agent as you see fit. Ask questions if you need clarification or guidance on any of the items.

Provide a concise summary of the completed tasks and any remaining items that need attention. Update the TO DO list accordingly.

## TO DO

- Currently, the "Out of date" 

- **Checks by hand of the 2026-10-21 work:** stacks of images with many groups and coherence stacks with the phase strip; a scroll done with the mouse restored on returning to a figure; the first-spike marks' default look (open circle in the groups' colors) on the Night design and the latency band's height with many groups.

- **Checks by hand of the 2026-10-22 work** (the tests run headless and fake keys, clicks and the color chooser): Ctrl+Click on a drawn panel (a line, an image, a raster tick) selects it, and right-click menus and data tips still work; a right-click menu gets its full items when first opened (they are now made on demand); the real `uisetcolor` from a swatch, and how the swatches sit beside their fields; Ctrl+G (File > Generate selected figure) with the focus in an edit field; Redraw All watched figure by figure; the letterboxed preview and its font scaling on a real window resize; the Copy settings window (880x640) and its tree on a figure with many panels; the Waveform section's layout (its note, the Amplitude row); the trial-count text's place (top left when overlaid) and the heat map's; the first click on the Figures, Alignment and Visualize tabs after a start (the tabs are now laid out when first shown; one test start stalled 612 s there, once); figure switches and the startup timed again on a quiet machine.

- **Checks by hand of the 2026-10-26 work:**
  - Scan dialog: a scan on the NAS project (S:): the time left, Cancel stopping mid-list (it cannot stop the first walk of the root); no dialog during startup.
  - Review tab (pipeline app): the new datasets table and the 180 px band at your window size; a header click, then a row click; the first open on S:. The wiki's `app-review-tab.png` is stale.
  - Preview vs. report: the Figures preview beside a generated HTML/PDF report (try the Talk design and a tuning or rate figure); the aesthetics editor shows exported sizes (9 pt, not 13.2); a design saved from the preview stores exported sizes.
  - Sortable tables: the Aesthetics and Apply-to-figures tables after a header click (do the gray / shaded rows follow their data? does scroll-to-row land right?); the filter rows at the dialogs' real widths.
  - Test report: the by-unit headings and contents in the browser; the Export tab's new Order row; a by-unit PDF's page ranges.
  - Label edits: right-click an axis label and edit it with Auto on (no busy card or flicker; data tips use the new name); with the aesthetics editor open; a first or cleared panel title still redraws.
  - Figure templates: the template row at narrow widths (about 11 controls); the drop-down's right-click menu. Decide: a template's remembered looks *replace* a figure's own (Copy settings adds them), and templates keep the across-sessions dataset keys and mapping path.
  - First-spike latency: the new section's layout and the onset lines on real data; the defaults (surprise 3, alpha 0.01, CUSUM 5 SD threshold, 1 SD allowance) were tuned on synthetic data only; the Poisson count rule reports the spike where significance is reached (it lags by design; the first spike of that run is a small change); per-group onset lines span the whole axes in a stack; the Night design has no rule for the `latencyOnset` role.

## Found during the 2026-10-26 batch (not started)

- **Ctrl stays "held".** Any key pressed with Ctrl sets the app's Ctrl-held flag (`onKeyPress`); if its release is missed (e.g. after Ctrl+Z) the next edit opens Apply to figures uninvited. It hung a test run once.
- **Flaky check:** test_EphysAnalysisFigures section 7, "figureCompute equals computeFigure's result", fails when the two results straddle a second (`spikePSTH` stamps `R.created` to the second). Compare without `created`.
- **Faster edits, measured but not done:** the busy card is built and painted twice on every Auto redraw even when the compute is a cache hit (0.58 s); `applyFigureEditor`/`syncFigureEditor` refresh the whole editor (0.25–0.45 s); `set.Figures` normalizes every figure on any assignment; `FigureDataTips` `colorbarQty` still searches the whole figure (`-depth 1` would do); axis sides could be set in place for simple panels.
- **Test runs under memory pressure:** with ~2.5 GB free a run slowed to a crawl (test_EphysPipelineApp 3c: 91 min; test_EphysAnalysisApp 5o's size checks failed, then passed alone). `tools\Run-Tests.ps1` could refuse to start a second slot below a free-RAM floor.

## Done

### 2026-10-26 (on main; branches todo/scn, rvw, rft, tbl, rpt, fst, tpl, lat2 merged in todo/merge26)

- **Scan progress** (scn). A scan after startup opens a modal "Scanning for datasets" dialog: indeterminate while the root is walked, then dataset i/n with the name and time left (`ProgressClock`), then the first dataset opening; Cancel while the datasets are read keeps the previous list. `EphysAnalysisRunner` gains `ProgressFcn`.
- **Review tab datasets table** (rvw). The Dataset drop-down is a sortable table (Dataset, Sorter, Units, Good, MUA, phy saved, Sorts) that picks the active dataset everywhere, in any sort order; rows read lazily from the sort in use (no recursive walk), refreshed after Use this sort, Open in phy and sorting runs. New `EphysDataset.labelCounts`.
- **Report vs. preview** (rft). The report was right: it shows the exported page. The preview scaled only the base font, line width and site size to its width, so markers, caps, tick widths, design sizes, derived fonts (ticks −2, legend −1) and the layout's gaps were off (140 of 166 sizes more than 2% off on 15 test figures). `renderFigure(Scale=)` now lays out on the export page, draws at export sizes and scales everything by one factor; the aesthetics editor reads and stores export sizes. No report scaling option was needed.
- **Sortable, filterable tables** (tbl). The Aesthetics dialog's list (text filter; title, component and type drop-downs) and the Apply-to-figures table (text filter; panel type, figure type and Show: all / will change / has it). Ticks survive sorting and filtering; All / None act on the rows shown.
- **Test report; report order** (rpt). Unit report is now **Test report** (`onTestReport`, `test_report.html`, Ctrl+U): figures of the dataset are drawn for the active dataset beside the unit's; across-session figures are listed as skipped with why. New `Report.Order` "figure" (default) | "unit" with an **Order** drop-down in the Export tab; HTML and PDF reports group by observation when "unit".
- **Text edits without a redraw** (fst). Why: a label edit redrew its panel, rebuilt menus and data tips (each searching the whole window) and painted the busy card twice. Now an edit of text alone (x/y label, panel title, figure title) is set on the drawn handles and laid out again: 1.57 s → 0.5–0.65 s. Menu searches are `-depth 1`, which speeds every redraw. Side changes and first titles still redraw.
- **Figure templates; Apply last change button** (tpl). A template row above the preview: drop-down, Apply..., Save as..., Update, Remove, Import..., Export..., Report issue. Templates are JSON files in `EphysFigureTemplates` beside MATLAB's preferences (`FigureTemplate`), normalized through the current config when read; applying copies settings (copy only, your choice) onto one or many figures, or as a new figure, as one undo step. The blue **Apply last change...** button sits at the row's right, enabled and tooltipped as the Edit menu item.
- **First-spike latency per figure** (lat2). One `latency` block per figure: per-trial methods "first" (as before), "surprise" (Legendy & Salcman 1985) and "poisson" (after Chase & Young 2007), and a per-unit response onset by CUSUM of the PSTH (Ellaway 1978; raster/PSTH `onsetLine`). Computed once per unit and alignment and shared by every panel; an edit of the block recomputes only the latencies. On synthetic trains with a known onset: first-spike took a spontaneous spike in >40% of epochs, surprise erred by a median <1 ms, CUSUM within 5 ms with no false onsets.
- **Merge fixes:** an in-place text edit on a drawing a canceled preview had cleared left the preview empty while it said Drawn (`renderFigure` now checks the handles); a stale "no template drop-down" check in test 5d.add.
- **Tests after the merge:** test_EphysAnalysisApp (every section, over two runs), test_EphysAnalysisFigures, test_EphysAnalysisRunner, test_EphysPipelineApp, test_SyntheticDataset, test_ConfigMigration, test_PlotAesthetics, test_PlotDesign, test_TableSort, test_FirstSpikeLatency, test_FigureTemplate, test_copyFigureSettings, test_EphysAnalysisConfig, test_ClassdefDeclarations and test_RepositoryMetadata pass. This also covers the sections and suites left out after the 2026-10-22 merge.
