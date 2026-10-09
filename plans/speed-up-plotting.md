# Speed up analysis plotting: the app preview first, then batch runs

## Context

Analysis plots are slow to draw, both in the analysis app's live preview and in batch runs. Nothing has been profiled yet. Reading the code turned up costs that grow with the plot size:

**Preview (Plots tab).**
- `PlotAesthetics.enableEditing` ([PlotAesthetics.m:433-471](analysis/PlotAesthetics.m#L433-L471)) gives **every** drawn object its own `uicontextmenu` plus 2 `uimenu`s. These are web components in the app's uifigure.
  - A 16-unit PSTH-with-raster page has about 500 objects, so about 1,500 menu components are built on every redraw.
  - Before that, a `findall` over the whole app deletes the previous menus.
- Every edit, including style-only edits such as font size, fill, legend or YLim, recomputes the data. `refreshPreview` always calls `computePlot` ([refreshPreview.m:50](analysis/@EphysAnalysisApp/refreshPreview.m#L50)), even though `PreviewResult` is cached.
- The 2 s auto-preview gate ([autoPreview.m](analysis/@EphysAnalysisApp/autoPreview.m)) counts compute and draw time together. A plot that is slow to compute therefore loses live style edits too.

**Shared render path (preview and runs).**
- `tileTicks` writes FontSize, then reads automatic `TickValues`/`Limits` and writes again, for each axes in turn ([tileTicks.m](analysis/private/tileTicks.m)). On a PSTH page that is 32 axes in 16 nested tiled layouts. `clearRasterEdge` ([renderPSTH.m:207-221](analysis/renderPSTH.m#L207-L221)) and `waveformInset` (reads `xlim`/`ylim` in auto mode, [waveformInset.m:27-30](analysis/private/waveformInset.m#L27-L30)) do the same. Each read after a write forces a fresh layout pass.
- `rasterInto` repeats the same epoch `sortrows` and `defaults("Plot")` work for every unit ([rasterInto.m:33-40, 95-99](analysis/private/rasterInto.m#L33-L40)).
- `PlotAesthetics.components` grows its struct one row at a time and rebuilds the 47-row `roles()` table for every row. It runs twice per preview: once in `apply`, once in `enableEditing`.
- The evoked stack layout draws 2·nC·nG separate objects ([renderEvoked.m:61-71](analysis/renderEvoked.m#L61-L71)). That is about 512 for 64 channels and 4 groups.

**Batch runs.**
- A default run makes **3 export passes per page**, from `Export.Formats=["png" "svg"]` plus the HTML report:
  1. a PNG at 150 dpi;
  2. a vector SVG;
  3. a second PNG at 110 dpi that `reportImage` exports for the report ([reportImage.m:25-34](analysis/reportImage.m#L25-L34)), because it reuses only an SVG.
- Every page also gets a new hidden figure.

You chose to cover both, preview first, and to allow default outputs to change.

The plan:
1. Measure.
2. Fix the clear wins.
3. Do the items marked *measure-gated* only where the numbers justify them.

## Step 0: Measure (benchmark harness)

Add `tools/benchAnalysisPlots.m`, which prints a timing table.

**Data.** Build realistic-size results from the public compute functions (`spikePSTH`, `evokedPotential`) on synthetic spike trains and signals. Model the epoch table on what `epochTable` returns. Synthetic projects have few units, so do not rely on them. Cases:
- PSTH grid with raster: 32 units (2 pages of 16), 200 epochs, 4 groups.
- Raster.
- Evoked: stack and butterfly, 64 channels × 4 groups.
- Heatmap.
- Probe map.
- Waveforms grid.
- Tuning grid.

**Preview path.** Draw into a uipanel in a visible uifigure, as the app does, with a warm-up draw first. Time each part with `drawnow` included:
- the renderer;
- `PlotDesign.paint` + `PlotAesthetics.apply`;
- `enableEditing`.

Run each with the Default design and with Journal (about 50 rules). Also run `profile on` once for a function-level breakdown.

**Run path.** Use `newExportFigure`, `renderPlot`, then `exportFigure` for each format separately, then `reportImage`.

Record the baseline table, then re-run after each phase. The before/after tables are what gets reported to you.

## Phase 1: Preview

### 1a. One shared context menu per plot instead of one per object

**First, check empirically (R2025a).** Write a scratch script: a uifigure, a panel, a tiled layout, and a line, patch, text and axes that all share one `uicontextmenu`. Right-click each one by hand, and print `class(evt.ContextObject)` in `ContextMenuOpeningFcn` and in `MenuSelectedFcn`. The `ContextMenuOpeningData`/`MenuSelectedData` classes do have a `ContextObject` property. The current code comment claims a uifigure does not say which object was clicked, and that claim has not been checked.

**If `ContextObject` is the clicked object** (expected), in `PlotAesthetics.enableEditing`:
- Keep one menu per target in the target's appdata. Create it once with the same 2 items, and delete it through an `ObjectBeingDestroyed` listener on the target.
- On each redraw, attach it with one vectorized `set(objs, 'ContextMenu', cm)`. No per-redraw `findall` or deletion.
- `onMenuOpening(cm, evt)` sets `cm.UserData = evt.ContextObject`, then fills the Design submenu as now.
- `onMenuEdit` stays as it is: it reads `menu.Parent.UserData`.

**Fallback, if it reports only the axes or nothing.** Put the shared menu on the axes and layouts only. Set children to `HitTest off` so a right-click reaches their axes. "Edit aesthetics..." then opens `PlotAestheticsDialog` on that axes; its component list already reaches every part. Tell you about the small UX change.

**Tests to update.** [test_PlotAesthetics.m:229-236](analysis/test_PlotAesthetics.m#L229-L236) currently checks `o.ContextMenu.UserData == o` for each object. Change it to: every object shares the plot's one menu, and redrawing does not add menus. Also update [test_PlotDesign.m:253-256](analysis/test_PlotDesign.m#L253-L256), which calls `onMenuOpening(cm, [])`: pass a stub event or allow an empty one.

### 1b. Preview redraws without recomputing on style-only edits

- Add a static `EphysAnalysisRunner.computeSpec(spec)`, declared in the classdef. It returns the fields `computePlot` depends on.
  - It drops the render-only ones: `id`, `enabled`, `title`, `style`, `aesthetics`, `histStyle`, `fill`, `fillAlpha`, `normalize`, `stack`, `stackSpacing`, `rasterSortOrder`, `rasterByGroup`, `order`, `jitter`, `xScale`, and `rasterEvents.marker/size/color`.
  - It reduces `waveform` to `[mode ~= "off", maxSpikes]`, and `layout` to `layout == "overlay"`.
  - Being conservative, any field not listed stays in the key.
  - It lives beside `computePlot` and its help points there, so the two are kept in step.
- In `refreshPreview`, reuse `obj.PreviewResult` when `PreviewKey` matches on all three: the runner handle, `ActiveIdx` (dataset), and `isequaln(computeSpec(spec), …)`. On a hit, set `R.spec = spec` and only render.
  - The Preview button (`Force=true`) still recomputes.
  - Clear the key on a failure.
- Time compute and render separately (`PreviewComputeSeconds`, `PreviewRenderSeconds`). `autoPreview` gates a render-only edit on the render time alone, so style edits stay live even when a plot is slow to compute. Update the status-label text to match.

### 1c. One layout pass for ticks, raster edges and insets

- Rework `tileTicks` into three passes:
  1. set the fonts on every axes;
  2. read every ruler's mode, ticks and limits in one sweep (one forced update);
  3. write the thinned ticks.
- Fold `clearRasterEdge` into it as an `Edge=` option that works on the planned ticks.
- Have it return the limits it read, so `renderPSTH`/`renderRaster`/`renderTuning` can draw the waveform insets after it with known limits. `waveformInset` takes an optional `Limits` and reads them itself only when none are given (single-axes case).

## Phase 2: Shared render clean-ups

- **`rasterInto`.** Compute the row order and `rasterLook` once per page in `renderPSTH`/`renderRaster`, and pass them in. Neither depends on the unit.
- **`PlotAesthetics.components`.**
  - Build `roles()` once (persistent `containers.Map` for `roleLabel`).
  - Collect handles into preallocated arrays instead of growing `C(end+1)`.
  - `renderPlot` passes the table from `apply` on to `enableEditing` (give `apply` a second output), so it is built once.
- **Evoked stack.** Draw one NaN-joined trace line per group and one multi-face SEM patch per group. The roles and groups stay the same, so the components and rules are unchanged. Check the tests that count evoked objects.
- **Measure-gated** (only if Step 0 shows they matter):
  - Replace the per-tile `xline`s with plain `line`s where the y extent is known (raster rows).
  - Flatten PSTH's nested tiled layouts.
  - Turn the per-row heatmap auROC `text` marks into one marker line.

## Phase 3: Batch runs

- **Default `Export.Formats = "png"`** in [defaults.m:142](analysis/@EphysAnalysisConfig/defaults.m#L142). SVG/PDF/EPS remain available on request. There is no back-compat shim: saved configs keep whatever they list.
- **The HTML report embeds the PNG just written.** `reportImage` uses the page's exported `.png` when `Files` has one.
  - When `Report.Dpi` is below the export Dpi, it is downscaled with `imresize`. That is Image Processing Toolbox, which you approved; list it under Dependencies in [README.md](documentation/README.md#dependencies). It is re-encoded with `imwrite` to a temporary file.
  - It exports anew only when no PNG exists.
  - `runDataset` passes the kept files when `Overwrite=false`. That lets a kept page be skipped entirely for an HTML-only report.
  - Mirror any change to the call sequence in `EphysAnalysisScript`. Its standalone/compact pixel-equality test pins the call lines.
- **Measure-gated:** reuse one hidden export figure per dataset (`clf reset` and resize per page) instead of a new figure per page.
- **Deferred:** parallel page/plot export on a process pool. Propose it separately, with numbers, only if render and export still dominate run time after Phases 1-3. It brings issues with script-generator parity, auROC RNG streams and memory.

## Files to touch (main)

- [analysis/PlotAesthetics.m](analysis/PlotAesthetics.m): `enableEditing`, `onMenuOpening`, `components`, `roleLabel`, `apply`
- [analysis/renderPlot.m](analysis/renderPlot.m)
- [analysis/@EphysAnalysisApp/refreshPreview.m](analysis/@EphysAnalysisApp/refreshPreview.m), [autoPreview.m](analysis/@EphysAnalysisApp/autoPreview.m), [EphysAnalysisApp.m](analysis/@EphysAnalysisApp/EphysAnalysisApp.m) (new properties)
- New `analysis/@EphysAnalysisRunner/computeSpec.m`, plus its declaration in `EphysAnalysisRunner.m`
- [analysis/private/tileTicks.m](analysis/private/tileTicks.m), [waveformInset.m](analysis/private/waveformInset.m), [rasterInto.m](analysis/private/rasterInto.m)
- [analysis/renderPSTH.m](analysis/renderPSTH.m), [renderRaster.m](analysis/renderRaster.m), [renderTuning.m](analysis/renderTuning.m), [renderEvoked.m](analysis/renderEvoked.m)
- [analysis/@EphysAnalysisConfig/defaults.m](analysis/@EphysAnalysisConfig/defaults.m), [analysis/reportImage.m](analysis/reportImage.m), [@EphysAnalysisRunner/runDataset.m](analysis/@EphysAnalysisRunner/runDataset.m)
- Docs:
  - `documentation/EphysAnalysisApp.md` (auto-preview rule, right-click)
  - `EphysAnalysisConfig.md` (Formats default)
  - `README.md` (Dependencies)
  - `CHANGELOG.md`
  - The wiki is generated from `documentation/`.
- New `tools/benchAnalysisPlots.m`

**Working-tree caution.** Many of these files carry uncommitted plots-tree and waveform work in the tree right now. Use `Edit`, not whole-file `Write`, and check `git status`/`git log` before each file. Other sessions may be editing.

## Verification

- **Benchmark.** Run `tools/benchAnalysisPlots` before and after each phase, and report the tables. Target: much shorter preview redraws for PSTH grids; render-only edits skip compute; one export pass per page by default.
- **Manual check.** Open the app on the synthetic project and preview a PSTH grid. Right-click a raster tick line, a SEM band, a title and the axes, and confirm the editor opens on that component. Edit the font size and confirm the status label shows the render time only. Press Preview and confirm it recomputes.
- **Tests: only the suites that touch the change**, run once at the end, by name:
  - Phase 1a and Phase 2: `run_all_tests({'test_PlotAesthetics','test_PlotDesign'})`.
  - Phases 1b-1c: `test_EphysAnalysisApp`, which takes 1-10 min, so run it in the background.
  - Renderers: `test_EphysAnalysisCompute`.
  - Phase 3: `test_EphysAnalysisRunner`, plus `test_EphysAnalysisConfig` if it pins the default formats.
  - No full-suite run. Report which suites were run and which were left out.
