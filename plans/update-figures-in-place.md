# Update figures in place: an edit costs the panel it changes, not the figure

## Context

The owner asked on 2026-11-06 why `hline.XData = x; hline.YData = y` updates a plot at once in MATLAB, while a similar edit in the analysis app (`EphysFigGenApp`, Figures tab) is sluggish. The plain update sets one property on an object that already exists. The app does much more for one edit of one panel. Take a PSTH panel's Smooth SD, its y-limit mode or a layer's color:

1. **Before the preview.** [onConfigChanged.m](analysis/@EphysFigGenApp/onConfigChanged.m) reads the whole editor back (`gatherConfig`, line 47; 0.85 s in the paint-first profile) and records the undo step. It then refreshes the figure list, the editor rows, the observations and the epoch diagram (lines 85-89), and only then calls `autoFigurePreview` (line 97).
2. **The data.** `quickFigurePreview` draws from the runner's cache when the edit is a look edit (`figureDataSpec`), else `refreshFigurePreview` computes with the busy card.
3. **The changed panel is drawn from scratch.** `renderFigure` with `Reuse` keeps each panel whose key is unchanged (`priorDrawing`). The changed panel gets a new axes ([renderFigure.m:506](analysis/renderFigure.m#L506)), and its draw function creates every line, patch, text and color bar again. No path sets `XData`/`YData` on the parts that exist. Only text edits (labels, titles) are set in place (`inPlace`).
4. **Everything drawn across the panels is redone over every panel, kept ones included** ([renderFigure.m:462-754](analysis/renderFigure.m#L462-L754)):
   - `keepOnly` deletes the title host and the legend; both are made again (lines 612, 628-650).
   - Every kept panel is scaled to the export sizes (`scaleSizes(…, 1/was)`, line 467), restored to its undressed state (`restoreDress`, line 501), dressed again, and scaled back to the preview's size (line 721). Each of those is a real property change on every object of every kept panel.
   - `tileTicks` (line 587), `figureTimeStack` (592) and `blankAxes` (593-595) run over all axes.
   - The design's, kinds' and figure's aesthetics rules are applied over the whole root (669-719).
   - `figureLayout` lays out the whole figure: it measures every axes' `TightInset` twice ([figureLayout.m:145-148](analysis/private/figureLayout.m#L145-L148)). In a uifigure each such read sends the pending changes to the browser and waits for its layout.
   - `enableEditing` walks every component of the root (`PlotAesthetics.components(menuRoot)`, [PlotAesthetics.m:639](analysis/PlotAesthetics.m#L639)), although it keeps the menus it made. `brokenGraphicTips` and `FigureDataTips` run `findall` over the root. `figurePickable` loops over `find(drawn)`, which includes the kept panels (737-741).
5. **The keys are coarse.** The global key holds the whole `style` and `design` ([renderFigure.m:1381](analysis/renderFigure.m#L1381)). A figure-wide look edit (font size, line width, legend location) therefore draws every panel again. The panel key holds the panel's whole spec but its rect (line 1396), so any option of a panel, even its color, draws it whole.
6. **The browser.** The app is a uifigure. Every object created is serialized to the browser, and every property change is a message to it. A classic `figure()` repaints locally, which is why the plain update is cheap.

**What was measured.** The UI speed work of 2026-11-05 (memory `ephys-ui-speed`, `tools/benchFigGenUI.m`) measured, on the owner's S: project, 12-panel HIT figure: a full redraw takes about 10 s (figure switch), "spread over many parts, no single big item". A select takes 0.4 s after that work.

**Not measured yet:**

- how a one-panel edit's time splits between the panel's own draw and the figure-wide redo in step 4;
- how much cheaper setting properties on an existing object is than creating it, in an R2025a uifigure.

Phase 0 measures both before anything else is built.

**Intended outcome** (targets to confirm after Phase 0), on the 12-panel figure, data in the cache:

- An edit of one panel's looks or data paints in under 0.5 s plus that panel's compute, whatever the number of panels.
- A figure-wide look edit (font size, line width) paints in under 2 s.
- The preview is identical to a fresh drawing: pixel-equal export, as the repository's other equivalence tests require.

## Facts the design rests on (from reading the code)

- **The draw functions are registered per type.** [figurePanelRegistry.m](analysis/figurePanelRegistry.m) lists 17 types, each `draw(ax, P, look) -> hk` ([figDrawResult.m](analysis/private/figDrawResult.m)). renderFigure is the only caller in the preview.
- **Nearly every part is tagged.** `tagPart(h, role, group)` ([tagPart.m](analysis/private/tagPart.m)) sets `Tag` = role and appdata `PlotGroup`; 123 calls across `analysis/private/draw*.m`. The graphics constructors called on `ax` in the draw code and its helpers: line 37, patch 16, xline 15, plot 13, text 5+, imagesc 5, errorbar 4, colorbar 4, yline 2, stairs 2, bar 2, scatter 1. So a reuse layer has about ten kinds of constructor to handle.
- **Kept panels are already at the preview's scale and fully dressed.** What forces the redo in step 4 is that the dressing and the rules are applied to the root, not to the panels drawn. `tileTicks` is per axes ([tileTicks.m](analysis/private/tileTicks.m): each axes' own fonts and thinned ticks), and so are `blankAxes` and the kind rules. `figureTimeStack` reads the neighbors but sets each axes on its own. `PlotDesign.paint` sets one color on the canvas.
- **The rules a kept panel carries cannot have changed.** `spec.aesthetics` and `spec.style` are in the global key (`Sg` keeps them), and a kind's remembered rules are in the panel key. A change to any of them draws every panel or that panel.
- **`figureLayout` already lays out part of a figure.** `Moved=` ([figureLayout.m:74-90](analysis/private/figureLayout.m#L74-L90), `placeMoved` at line 187) measures and places the moved panels and places the others only where their place changes, using their last measures. Arrange uses it (`PlaceMoved`).
- **Data tips and menus are already per object.** `FigureDataTips.attach` skips kept panels (`hT`, lines 744-751). `enableEditing` keeps a component's menu when it has one (the `Reuse` note in its help). `figurePickable` is wired once per axes (ui-speed work).
- **Equal values are free.** R2025a drops a property set to the value it has (ui-speed finding), so resetting the many properties that did not change costs nothing in the browser.
- **yyaxis.** `drawPsthPanel` (stacked rows: peaks on the right axis) and `drawStack`/`drawOverlays` use `yyaxis`. An axes with two y rulers is the hardest to reset to a new axes' state.
- **Export never uses `Reuse`.** Runs and the Export tab draw fresh (`Reuse=false`, `Scale=1`), so anything this plan does applies to the preview only, and an export stays a fresh drawing.
- **The main tree.** As of 2026-11-06 (main 63d06331) it holds another session's uncommitted edits, among them `analysis/private/drawPsthPanel.m`, `analysis/@EphysFigGenApp/applyFigureEditor.m`, `gatherFigureEditor.m`, `syncFigureEditor.m` and both figure test files. Branch after they land, in a worktree with a short name (MAX_PATH).

## Phase 0: Measure

1. **Stage timing in renderFigure.** An opt-in `Timing` output (a struct of seconds per stage, kept in the drawing's appdata) with `drawnow` excluded. The stages:
   - keys and `priorDrawing`;
   - `keepOnly`;
   - each panel's draw;
   - `scaleSizes` (both);
   - `restoreDress` and the dressing (`tileTicks`, `figureTimeStack`, `blankAxes`, the observation title);
   - the title host and the legend;
   - the rules and `paint`;
   - `figureLayout`;
   - `enableEditing`, the tips, pickable and trial-export menus.

   The app's paint after it is timed by the bench, as now.
2. **New bench actions in [tools/benchFigGenUI.m](tools/benchFigGenUI.m)**, each with its call and paint seconds, unprofiled and profiled:
   - one panel's look edit (PSTH y-limit mode, then a layer's color);
   - one panel's data edit (PSTH Smooth SD: compute plus draw);
   - a figure-wide look edit (the style's font size);
   - the same three on a 2-panel figure, to separate the per-panel cost from the per-figure cost.

   The `onConfigChanged` bookkeeping before the preview is timed as its own row.
3. **Micro-benchmark `tools/benchGraphicsUpdate.m`.** A uipanel in a uifigure (hidden desktop, as `Run-Tests.ps1` runs MATLAB). For N = 20, 200 and 2000 lines and patches, each followed by `drawnow`, time:
   - create versus set `XData`/`YData` versus set `Color`;
   - delete-and-create a whole axes with N lines versus reuse it;
   - one `TightInset` read after a change versus none.
4. **Report to the owner:** the tables, and a go or no-go for Phase 2. Go when setting data on existing lines and patches is at least 3x cheaper than creating them at N = 200.

## Phase 1: Draw again only what changed (every panel type, no draw function touched)

All in [renderFigure.m](analysis/renderFigure.m), behind `Reuse`:

1. **Leave the kept panels alone.**
   - No `scaleSizes` round trip: drop the `1/was` scale on kept parts (line 467). Scale only the drawn panels' parts and the new title and legend (line 721 on them, not the root).
   - No `restoreDress` on a kept panel when the arrange key is unchanged (its neighbors, sides and time axes are as drawn). When the arrange key changed, restore and dress it as today.
2. **Dress and style only the drawn panels.**
   - `tileTicks` and `blankAxes` on the drawn axes.
   - `figureTimeStack` computes over all panels as now, but sets only the drawn ones, unless the arrange key changed.
   - The observation title only when the top-left panel is drawn.
   - Rules: design, kind and figure rules applied to each drawn panel's axes, extra axes and band (`PlotAesthetics.apply(ax, rules)`), and to the new title host and legend, not the root.
3. **Keep the title host and the legend when nothing they show changed.** The title host is kept when the title text, the subtitle lines and the style are the same; it is then not deleted by `keepOnly`. The legend is made again only when its entries' handles changed. A legend follows its lines' looks by itself, and with Phase 2 the handles survive a redraw.
4. **Lay out only the drawn panels.** `figureLayout(canvas, S, Moved=~kept)` when the last layout fits (`fitsLast`), else the whole layout. A redrawn panel whose labels changed width moves its flush neighbors through `figurePlace`, as Arrange's moves do.
5. **Menus and tips over the drawn panels only.** Run `enableEditing` with `context.menuRoot` set to the drawn panels' axes plus the title and legend; the edits still go to the root. `brokenGraphicTips` and `figurePickable` loop over the drawn panels; the tips already do.
6. **Split the global key.** Move the style fields that only the dressing across panels reads into the arrange-like "dress" key, so editing them keeps every panel (`how = "kept"`). Candidates: `Legend`, `LegendLocation`, `ShowArtifactNote`, the title's font. A field moves only when `grep` shows no draw function reads it (`look.style.<Field>`). The fields a draw function reads (`FontSize`, `LineWidth`, colors) stay global: Phase 2 makes that full redraw cheaper.
7. **Paint before the bookkeeping** (only if Phase 0 shows it matters). In `onConfigChanged`, for a `"figure"` edit that leaves the observe block, alignment and sorting unchanged, call `autoFigurePreview` before `refreshFigureList`, `syncFigureEditor`, `refreshFigureObservations` and `refreshEpochDiagram`. The whole edit stays under one `Applying` guard, with `drawnow nocallbacks` for the paint, as paint-first did.

After Phase 1, a one-panel edit costs that panel's draw, its rules and its layout. No other panel is touched.

## Phase 2: Reuse a panel's graphics objects when it is drawn again (measure-gated)

When a panel is drawn again with the same type, draw into its existing axes, and let its draw function's constructor calls take the old objects instead of creating new ones. The draw functions stay as they are, apart from a mechanical change of their constructor calls, so no per-type update logic duplicates them.

1. **A helper `figPart`** (new, `analysis/private/figPart.m`):
   - It replaces `tagPart(line(ax, args{:}), role, group)` with `figPart("line", ax, role, group, args{:})`, and likewise for patch, xline, yline, plot (made as a line), text and imagesc (an image).
   - On a hit in the axes' pool (appdata, keyed by kind, role, group and the order of the call within that key), it turns the positional arguments into name-value pairs, one rule per kind:
     - line and plot: x, y and a line spec;
     - patch: x, y, c, or `Faces`/`Vertices`;
     - text: x, y, string;
     - xline and yline: value, line spec, label;
     - imagesc: x, y, C, plus `CDataMapping` `scaled`.
   - It then resets to their defaults the properties its last call on that object set but this call does not (recorded in appdata), and sets the rest.
   - On a miss, it creates as today.
   - Kinds it does not handle (errorbar, bar, stairs, scatter, colorbar) pass through and are always created. The leftovers of every kind are deleted after the draw.
2. **The pool.** Before the draw, renderFigure collects the old axes' tagged children, and those of its extra axes, into the pool, then resets the axes to a new axes' state:
   - the limit and tick modes, `YDir`, `Colormap`, `NextPlot`, `Box`, the label and title strings;
   - from a per-canvas snapshot of a new axes, taken once.

   Equal values are free.
   - After the draw, it restores the creation order of `ax.Children` in one set.
   - A panel with `yyaxis`, or any panel the reset cannot bring back, gets a new axes as today. The pool marks such axes with appdata `FigureNoReuse`.
3. **Rules.** `PlotAesthetics.apply` records on each object the properties it set (appdata). `figPart`'s reset covers those too, so a rule that no longer applies leaves nothing behind. The rules are then applied after the draw as now.
4. **Menus, tips and the legend.** The reused objects keep their context menus (`enableEditing` keeps a menu made with the same `onGoto`/`onAxisEdit`). `FigureDataTips.attach` must overwrite a reused object's tip rows, not add to them: check, and fix if needed. The figure's legend keeps its entries when their handles survived (Phase 1.3).
5. **Order of conversion.**
   - First the types on the owner's OFC figures: psth (its line modes; heat map display through `imagesc`), raster, continuous, heatmap.
   - Then rate, tuning, spectrum, spectrogram, eventTrace, waveforms, corrmap, probemap.
   - Last the trial panels and coherence, whose extra axes come with them.

   A type not yet converted still benefits from Phase 1.
6. **A switch.** renderFigure option `ReuseParts` (true in the app's preview, false elsewhere), so a reuse bug can be ruled out from the command line, and the export path never takes it.

## Phase 3: Direct setters for the commonest edits (measure-gated, after Phase 2)

Only if Phase 2's numbers leave the draw function's own MATLAB time as the main cost of a common edit. For a short list of option fields per type (a layer's color, `lineWidth`, `fillAlpha`, `yLimMode`/`yLim`, `cLim`), an optional registry entry `restyle(hk, P, look, oldPanel, newPanel) -> handled` sets the few properties on the drawn parts. It returns false for anything else, which then draws as in Phase 2. This is the equivalent of `inPlace` for text. It adds per-type code, so it needs the owner's go.

## Out of scope

- Compute time (Smooth SD recomputes its panel); Phase 0 reports its share.
- Probe figures (`renderProbeFigure`: no Reuse).
- Session figures (they wait for Preview).
- Exports and runs (fresh drawings, unchanged).
- The editor refill after an edit (`applyFigureEditor`, scoped by the ui-speed work).

## Files to touch

- [analysis/renderFigure.m](analysis/renderFigure.m): stage timing; `keepOnly`; the kept path; dressing, rules, scaling and layout scoped to the drawn panels; title host and legend kept; split keys; the pool and `ReuseParts`; its help (the `Reuse` paragraph).
- [analysis/private/figureLayout.m](analysis/private/figureLayout.m): `Moved` from a drawing (expected: no change, only its use).
- [analysis/PlotAesthetics.m](analysis/PlotAesthetics.m): `apply` records what it set; `enableEditing` with `menuRoot` from renderFigure.
- [analysis/FigureDataTips.m](analysis/FigureDataTips.m): overwrite a reused object's rows (if needed).
- New `analysis/private/figPart.m`; `analysis/private/draw*.m` and the helpers they call (`histTrace`, `errorPatch`, `rasterInto`, `drawStack`, `drawOverlays`…): the constructor calls, one type per commit.
- [analysis/@EphysFigGenApp/onConfigChanged.m](analysis/@EphysFigGenApp/onConfigChanged.m) (step 1.7 only).
- [tools/benchFigGenUI.m](tools/benchFigGenUI.m), new `tools/benchGraphicsUpdate.m`.
- Docs: `documentation/EphysFigGenApp.md` (Auto slider: what an edit redraws), `CHANGELOG.md`. No wiki change unless the owner asks (no control is added or renamed).

## Verification

- **Equivalence (the main risk is a stale property).** A new section in `test_EphysAnalysisFigures`. For every panel type in the fixture and a list of edits per type, covering options that change which parts are drawn (display, stack, errorType, histStyle, latencyBox), draw with `Reuse` and apply the edit:
  1. Redraw with `Reuse` (and `ReuseParts`), and draw fresh.
  2. Compare a snapshot of every part: class, Tag, PlotGroup, and the visible properties per kind.
  3. Compare an export of both (`exportgraphics`, pixel-equal, not byte-equal).
- **Untouched panels.** After a one-panel edit, every other panel's axes and children are the same handles, and a `PostSet` listener on their `FontSize`, `Position` and `LineWidth` sees no set.
- **Bench.** Run `tools/benchFigGenUI.m` and `tools/benchGraphicsUpdate.m` (via `tools/Bench-FigGen.ps1`) before each phase and after it, and report the tables. Timings are reported, not asserted: the 5h.arrange timing test already fails under machine load.
- **Tests.** Only the suites and sections the change reaches, once at the end, through `tools\Run-Tests.ps1 -Select` (`python .github/scripts/select_suites.py --worktree --sections --why --expect`). Expected: `test_EphysAnalysisFigures`, and the `test_EphysFigGenApp` sections on figure edits and the preview. The selector over-selects through `panelTypes`; trim to the sections that draw. Report the suites run and those left out. Ask before any full run: after Phase 2 converts every draw function, one full `test_EphysFigGenApp` run (about 35-40 min) is probably warranted.

## Decisions for the owner

1. **Phase 2's gate.** Go when Phase 0 shows setting data on existing parts at least 3x cheaper than creating them (recommended). Or build Phase 1 only.
2. **Equivalence bar.** Pixel-equal export of a pooled redraw versus a fresh one (recommended), or the part snapshot alone.
3. **Phase 2 rollout.** OFC types first (psth, raster, continuous, heatmap), then the rest (recommended), or all 17 types in one branch.
4. **Phase 1.7 (paint before bookkeeping).** Only if Phase 0 shows the bookkeeping is a large share (recommended), or always.
