# Paint first: figure edits that compute nothing show at once

## Context

Removing a panel in the analysis app (`EphysFigGenApp`, Figures tab) takes about 10 s before the preview changes. A profile of Remove panel on the test fixture (4-panel figure, Auto on, 3 runs: 9.7–10.2 s each; script `C:\Users\dstolz\AppData\Local\Temp\claude\e5ed913e4724913d\ea945d35-e6f4-4e15-82ae-1111936f6d71\scratchpad\prof_remove.m`) showed:

| Step (run 1, 9.8 s in all) | s | Needed? |
|---|---|---|
| `EphysAnalysisConfig.removePanel` | 0.005 | yes |
| `gatherConfig` (whole editor read back) | 0.85 | before the edit |
| `applyFigureEditor` (editor refilled) | 1.5 | yes, after the paint |
| status bar, its `drawnow`, list, undo step | 0.9 | yes, after the paint |
| busy card "Computing" + its paints | 1.6 | no |
| `computeFigure`: every step a cache hit; 7 checkpoint `drawnow("limitrate")` | 1.1 | no |
| `renderFigure`: all 3 remaining panels drawn again | 2.0 | mostly no |
| final paint | 0.9 | yes |

The removed panel stays on screen the whole time. With Auto off, or after a slow preview, it stays until Preview is pressed.

Why:
- `commitFigureEdit` refreshes the whole editor before it touches the preview.
- `previewNow` always shows the busy card and polls, even when everything comes from the cache.
- `renderFigure`'s Reuse keeps panels only by index, and only when the global key matches. That key holds every panel's place, the neighbor relations and the top-left panel, so any removal or reorder draws everything again.

Owner's decisions (2026-11-05):
- Work in a separate worktree.
- "Paint first" for every structural edit that computes nothing.
- Implement the settle pass in `renderFigure` (no redraw of kept panels).
- Review of 2026-11-05 folded in: branch after the multi-select work lands; two timing targets; phase 2 bail-outs for a run going and a probe figure; one `Applying` guard over the whole commit; Reorder's phase 1 optional and last; the two standalone fixes as their own commits; the dressing snapshot shared by both drawing paths; a busy-card counter for the tests.
- Main moved to dcba240 the same day (auto-redraw branch): the Auto box is a 0-1 slider (`FigureAutoSlider`, `autoRedrawLimit`, `previewCost`); `FigureAutoCheckBox`, `FigureAutoPreviewSeconds` and `AutoPreviewSeconds` are gone. `figureDataSpec` is public now (`analysis/figureDataSpec.m`); do not recreate the private one.

Intended outcome:
- A removed panel disappears in about 0.2 s, with Auto on or off.
- With Auto on, the preview is current again about 2 s after the click (after `gatherConfig`), with no busy card and no recompute.
- A reorder restacks within the same 2 s (about 0.2 s if its optional phase 1 is done).
- The editor and list update after the paint.

## Facts the design rests on (from reading the code)

- **What computes.** `commitFigureEdit` callers that reuse the cache are Remove panel(s) (`onRemovePanel`, `private/arrangeMenu.m` removeSelected) and Reorder (`onPanelOrder`).
  - Their "skip" key always misses (`figureCompute.m:141-151`), but that check is cheap.
  - The "epochs" key misses only if the removed panel widened the baseline hull or added a sort/tuning column (`private/figureEpochPlan.m`). Then every panel misses.
  - Undo of a removal is a full hit unless the entries were evicted.
- **Layer edits compute.** Remove, Move and Add layer, and the layer Enabled box, recompute their panel: the panel key holds all of its layers. They keep the busy path, but gain the no-card path when the cache does hold them.
- **No dressing step resets what it set** (`renderFigure` after the panel loop):
  - `figureTimeStack` (`XTickLabel=[]` leaves `XTickLabelMode` manual; raster `clearRasterEdge` sets `TickValues`)
  - `tileTicks` (FontSizes; thinned y `TickValues`)
  - the top-left observation title
  - the uncommitted `blankAxes` in the main tree

  A kept panel whose neighbor was removed would keep stale hidden tick labels. A reset is needed. Today the global key pins the neighbors, which hides this.
- **Colorbar placement.** `inTimeColumn(look)` (`private/inTimeColumn.m`) is the one place a draw function reads the other panels (confirmed: `drawHeatmapPanel`, `drawPsthPanel`, `drawSpectrogramPanel`; `figureLayout`, `figurePlace` and `figureTimeStack` read the neighbors too, but they rerun on every drawing). It places the colorbar, so it must go into the per-panel key.
- **Menus.** `enableEditing` keeps existing menus and finds panels by id at click time. `markFigurePanel` and `figurePickable` work by id. `FigureDataTips.attach` stores self-contained info per object, but returns before `addMenus` when no panel was drawn (`FigureDataTips.m:139-141`), so a rebuilt legend would lack "Data tip fields...".
- **Layout and order.** `figureLayout`'s S can be rebuilt from kept handles. The kept branch already restores z-order to panel order (`renderFigure.m:490-498`). `firstPanel` is by rect (`EphysAnalysisConfig.panelOrder`), not by drawing order, so a reorder never moves the observation title.
- **Re-entrancy.** Today the busy state guards re-entrancy (`refreshFigurePreview.m:60-63`, `syncFigureView`, `syncArrangeOverlay`). If the editor is refilled after the paint, a callback run in between would `gatherConfig` stale editor values into the config (`gatherFigureEditor.m:40-44`). `drawnow nocallbacks` defers callbacks, it does not drop them: they run at the next plain `drawnow`, and `refreshFigureList` or `refreshFigureObservations` may issue one before `applyFigureEditor` refills the editor. So the whole commit, phase 1 through `applyFigureEditor`, runs under one `obj.Applying = true` with `onCleanup` (as `applyFigureEditor.m:24-26` does), and the paints use `drawnow nocallbacks`.
- **What previewNow refuses.** It does nothing while a run goes (`obj.Running`), and a probe figure (`spec.probe.enabled`) goes through `computeProbeFigure` and `renderProbeFigure` (no Reuse). Phase 2 must bail on both; session figures are already turned away by `autoFigurePreview`.
- **The Auto gate (since dcba240).** `auto = Figures tab shown && autoRedrawLimit(obj) > 0` (slider 0 = off, 1 = Inf = always, between = `AutoRedrawScale * t/(1-t)` s); the gate is open when `previewCost(obj) < limit`. `previewCost` is the last drawing's time alone when the data key (`previewDataKey`) is unchanged, else compute + draw. `keepCost` (`refreshFigurePreview.m:423`) keeps the compute part when the data were reused and always takes the last drawing's time. "Auto on", "the gate" and "Auto off" below mean these.
- **Observation list.** `trackFigureIds` renames FigureObservation, FigureEditorStates and FigureViews, but not `FigurePickers`. An automatic id that follows the edit re-lists the observations (`refreshFigureObservations.m:68-82`).
- **The main tree.** As of 2026-11-05 (main dcba240) it holds another session's uncommitted multi-select work (24 files), including `renderFigure.m` (`blankAxes` after `figureTimeStack`, lines ~500-512) and both test files this plan extends. Branching from today's `main` guarantees a merge in exactly those places.

## Approach

Every structural edit runs in this order, under one `Applying` guard. Phases 1 and 2 are new.

1. **Phase 1, instant (Remove; Reorder optional, last).** Before `gatherConfig`, build the edited figure from `obj.Config` and call `renderFigure(F, spec, P, LayoutOnly=true)`, extended so the spec may drop (and, optionally, reorder) panels by id:
   - delete the dropped panels' parts;
   - restack the rest in the new panel order;
   - lay them out at their rects.

   Then `markFigurePanel` and `drawnow nocallbacks`. This runs whatever the Auto and time-gate settings.
2. **Config.** `gatherConfig`, the edit, `trackFigureIds`, `recordFigureEdit`, `obj.Config`, `Runner.Config`, as today.
3. **Phase 2, settle (any edit, when the preview shows this figure).** Compute with `CacheOnly=true`: no busy card, no polling. On a full hit, `renderFigure(..., Reuse=true)` keeps every panel whose own key is unchanged (matched by id), draws only the rest, and re-dresses the figure from a reset baseline. Then the preview tail as `previewNow` does it, and `drawnow nocallbacks`. It runs:
   - with the slider above 0 and `previewCost < autoRedrawLimit`;
   - with the slider above 0 whatever the limit, when Remove or Reorder left every panel kept (`KeptOnly=true`, as text-only edits already do in place).

   It bails, drawing nothing, when: a run goes (`obj.Running`); the figure is a probe or session figure; the preview does not show this figure; the compute misses the cache; `KeptOnly` finds a panel to draw.
   Its cost record: `keepCost(key, secsCompute, secsDraw)` as previewNow, but only when it drew a panel (`how == "drawn"`); a `"kept"` settle leaves `FigurePreviewCost` alone, since its near-zero draw time would make the next look edit's redraw look free.
4. **Bookkeeping.** `refreshFigureList`, `applyFigureEditor`, `refreshFigureObservations`, `refreshEpochDiagram`, `setStatus`, `updateTitle`.
5. **Fallback.** If phase 2 didn't draw: `autoFigurePreview` (busy path) or `arrangedPreview`, as today. After a phase 1 with Auto off, the badge says Out of date.

`autoFigurePreview` itself tries phase 2 before `refreshFigurePreview`. Undo/Redo (`previewFigureView` → `autoFigurePreview`) and the cached `onConfigChanged("figure")` edits (axis sides, overlays) then also skip the busy card. `Force=true` (the Preview button, Redraw All, tests 5d.stale and 5m that cancel during "computing") keeps the busy path unchanged.

Reorder's phase 1 is optional: its only visible effect is z-order where panels overlap, and phase 2 with `KeptOnly` restacks within about 1 s. Do it only after everything else passes (subagent C's last item).

## Steps

### 0. Worktree and plan
- **Wait for the multi-select work to land on `main`** (the 24 uncommitted files; `git status` clean of `renderFigure.m` and the two test files). Then `git worktree add <scratchpad>\wt\pfe -b paint-first main`. Keep the path short (MAX_PATH).
- Copy this plan to `plans/paint-first-figure-edits.md` in the worktree and commit it first.
- If the owner says not to wait: branch from today's `main` and expect a merge around `renderFigure.m:500-512` and in both test files; the reset snapshot below already covers what `blankAxes` sets.

### 1. Standalone fixes (two commits of their own, first)
- **`private/trackFigureIds.m`:** rename the `FigurePickers` key as it does `FigureObservation`. Commit: "Figures: an automatic id that follows an edit renames its observation picker".
- **`FigureDataTips.attach`** (`analysis/FigureDataTips.m`): add "Data tip fields..." to the figure's menus even when every panel was kept (n == 0). Commit on its own.

  Each lands on its own even if the paint-first branch is delayed.

### 2. Cache-only compute
- **`analysis/figureCompute.m`:** add `opts.CacheOnly` (false); carry it in `C`. On a miss of "epochs" (before `epochTable`, ~391) or "panel" (before `reg.(type).compute`, ~235), throw `figureCompute:CacheMiss` naming the kind and panel. A "skip" miss stays allowed, since it is cheap.
- **`analysis/private/figureLatencies.m`:** same for the "latency" and "onset" misses (~89, ~100). Its fallback `C` lacks the field, so use `isfield`.
- **`analysis/@EphysAnalysisRunner/computeFigure.m`:** pass `CacheOnly` through. No `Check` when CacheOnly is set. The cache (`FigureCache`) is not updated on a CacheMiss.

### 3. `renderFigure` keeps panels by id and re-dresses from a reset (`analysis/renderFigure.m`)
- **`drawingKeys`**:
  - Split `place`, `neighbors` and `first` out of `global` into `keys.arrange`.
  - Move each type's user rules from global into that panel's key; keep "figure" rules global.
  - Add the panel's `inTimeColumn` result to its key.
- **`priorDrawing`**:
  - Match each new panel to the drawn one with the same id.
  - `same(k)` = parts valid and per-panel key equal.
  - Return `prior` re-indexed to the new order: axes, extra, hks, notes, bands, ovls, yExt, parts, pos, labels, pre.
  - Keep the `ownTime` guard.
  - Global key still must match.
- **`inPlace`**: also require equal ids in order and `isequaln(D.keys.arrange, keys.arrange)`. It must not take a change of neighbors, since it doesn't redo the time stack.
- **Dressing snapshot, in both paths**:
  - After each panel is drawn (before `tileTicks`), in the whole-drawing path as in the kept one, record `pre{k} = dressState([ax extra])`: `FontSize`; `XTick`/`XTickMode`; `XTickLabel`/`XTickLabelMode`; Title and XLabel `String`/`FontSize`/`FontWeight`/`Interpreter`; each `YAxis` `TickValues`/`TickValuesMode` and Label `String`/`FontSize`/`Interpreter`. Store it in D. Record it at export size (before the scale), which is where the kept branch restores it.
  - In the kept branch, after the scale-back to export size (~379), apply `restoreDress(prior.parts{k}, prior.pre{k})`, putting modes back to `auto` where they were.
  - The time stack, `tileTicks`, `blankAxes`, the top-left title, the legend, the title host, aesthetics, scale and layout then run as in a whole drawing.
  - One pair of local functions, `dressState` and `restoreDress`, used by both paths, so a dressing step added later that sets an unlisted property fails the section-8 checks instead of going stale silently.
- **New option `KeptOnly`** (implies Reuse): proceed only when every panel is kept. Otherwise `h=[]`, `how=""`. A drawing that keeps all panels returns `how="kept"`.
- **`layoutOnly`** accepts a spec whose ids are a subset of the drawn ones (a reordering too, if Reorder's phase 1 is done):
  - delete the dropped parts and the old legend if its host went;
  - restack;
  - rebuild S in the new order (`S.legend.panel` re-indexed, or `[]`);
  - lay out;
  - store D trimmed and re-indexed, so the next Reuse matches by id.
- Update the header docs of these options (Reuse: by id; `KeptOnly`; LayoutOnly with dropped panels).

### 4. App: the paint-first phases (`analysis/@EphysFigGenApp/`)
- **New `private/paintEditFirst.m`** (phase 1): given the edited figure, if `previewShowsFigure` and not a session or probe figure, call `renderFigure(FigurePreviewResult, spec, FigurePreviewPanel, LayoutOnly=true)`, then `markFigurePanel` and `drawnow nocallbacks`. It returns whether it painted.
  - Reuse arrangedPreview's local `layoutOnly`: move it to `private/layoutPreview.m` and use it from both.
- **New `private/quickFigurePreview.m`** (phase 2): the gates and bail-outs above (`obj.Running`, probe, session, preview shows another figure); `computeFigure(..., Reuse=true, CacheOnly=true)` with no `PollFcn`; `renderFigure(..., Reuse=true, KeptOnly=opts.KeptOnly)`.
  - It holds a busy guard without the card: the state is set without painting, and restored with `onCleanup`. It paints with `drawnow nocallbacks`.
  - On a CacheMiss or `how==""` it returns false and changes nothing.
  - On success it runs the same tail as `previewNow`: `FigurePreviewResult`, `FigurePreviewSeconds`, `keepCost` (only when `how == "drawn"`), `FigurePreviewDrawn = figureViewKey`, `setFigurePreviewState("drawn")`, label with `slowNote`, `markFigurePanel`.
  - Factor that tail out of `refreshFigurePreview.m` (a local `finishPreview`, shared; `keepCost` and `slowNote` move with it or become private functions).
- **`onRemovePanel.m`, `private/arrangeMenu.m` removeSelected (and `onPanelOrder.m`, optional):** call `paintEditFirst` with the figure edited from `obj.Config` before `gatherConfig`.
- **`private/commitFigureEdit.m`:**
  - One `Applying` guard (`wasApplying`/`onCleanup`, as `applyFigureEditor` does) from entry through `applyFigureEditor`. `paintEditFirst` runs before `commitFigureEdit` in the callers, so it sets the same guard itself.
  - Reorder to: config and history → `quickFigurePreview` (not for `Arrange=true`, which keeps `arrangedPreview`) → bookkeeping → `autoFigurePreview` only if nothing was drawn.
  - `KeptOnly` is true when the new panel ids are a subset or reordering of the old ones.
- **`autoFigurePreview.m`:** after `inPlaceFigurePreview`, with `auto` and `previewCost < limit`, try `quickFigurePreview` before `refreshFigurePreview`.
- **Busy-card counter:** a property (`FigurePreviewBusyCount`) incremented in `setFigurePreviewState` when the state becomes "computing". A synchronous edit cannot be watched from outside; the tests read the counter.
- **`EphysFigGenApp.m`:** the classdef declarations for the new property and methods.

### 5. Docs
- `documentation/EphysFigGenApp.md`: the preview after an edit (no busy card when nothing computes; a removal shows at once, Out of date with Auto off).
- `documentation/EphysAnalysis.md`: renderFigure's Reuse by id, `KeptOnly`, and LayoutOnly with removed panels.
- `documentation/analysis-app-guide.md`: one line under the Figures tab, if it says what Remove panel shows.

## Verification

1. **Timing:** rerun `prof_remove.m` from the worktree, adding an `ObjectBeingDestroyed` listener on the removed panel's axes for the time to deletion.
   - Targets, both from the click: removal visible ≤ 0.3 s; preview Drawn ≤ 2 s (it follows `gatherConfig`, 0.85 s); no busy card (counter unchanged). The edit as a whole still ends after the editor refill (about 4.5 s): report it, it is not a target.
   - Report the before/after table.
2. **`test_EphysAnalysisFigures`**, section 8, new checks against a whole drawing (`sameDrawing`, `sameTexts`, kept axes the same handles):
   - Remove the bottom time panel: the panel above shows its tick labels and "Time (s)".
   - Remove the top-left panel: the observation title moves.
   - Remove the panel that carried the group legend entries.
   - Remove down to one panel: `tileTicks` undone.
   - Reorder: same handles, children in panel order.
   - Heat map left alone in its column: drawn again (colorbar).
   - `KeptOnly` returns `""` when a panel must be drawn.
   - LayoutOnly with a dropped panel: parts gone, `how=="layout"`.
   - The existing Reuse, InPlace and scale checks (3896-4021, 5173-5187) still pass.
3. **`test_EphysFigGenApp`**, new section `5d.quick` (`app.FigureAutoSlider.Value = 1`, always; restore with the suite's `resetAutoLimit`):
   - Remove panel: state Drawn, the other panels' axes the same handles (`findPanelAxes`), `FigurePreviewBusyCount` unchanged.
   - Undo brings it back with the others kept.
   - Reorder keeps the handles.
   - Slider at 0 (off): the axes are gone at once and the badge says Out of date.
   - Slider between (a limit under the last compute + draw, above the draw alone): Remove settles with `KeptOnly` all the same.
   - Removing the panel that widened the baseline hull falls back to the busy path and ends Drawn (counter +1).
   - Rerun the touched sections: 5d.remove, 5d.multi, 5d.arrange, 5d.layers, 5d.stale, 5h.arrange, 5k, 5m, 5s, 5u.
4. **Selection:** use `python .github/scripts/select_suites.py --worktree --sections --why --expect` in the worktree and add what it names (e.g. a runner suite for `computeFigure`). Run through the worktree's `tools\Run-Tests.ps1` (hidden desktop). No full suite.

## Subagents

Six agents. D first (independent), then A and B in parallel, then C, then E and F in parallel. Each works in the worktree, commits its own step, and reports the worktree path and branch.

| Agent | Step | Depends on | Model | Effort | Why |
|---|---|---|---|---|---|
| D | 1: the two standalone fixes | none | sonnet | low | two small, well-located edits; each its own commit |
| A | 2: cache-only compute | none | sonnet | medium | mechanical option threading; the miss points are named |
| B | 3: `renderFigure` keys, snapshot, `KeptOnly`, `layoutOnly`; `test_EphysAnalysisFigures` section 8 | none (reads A's option name only) | opus | high | the riskiest piece: keys by id and the dressing reset must match a whole drawing pixel for pixel; it writes and runs its own section-8 checks |
| C | 4: the app phases, `Applying` guard, counter, classdef; `test_EphysFigGenApp` 5d.quick | A, B | opus | high | re-entrancy, four gates and the fallback order; it runs 5d.quick and the touched sections |
| E | 5: docs | C | sonnet | medium | three pages, the wiki rules in CLAUDE.md (two audiences, American spelling) |
| F | Verification 1 and 4: timing profile, suite selection, final run, before/after table | C | sonnet | medium | runs `prof_remove.m` and `Run-Tests.ps1 -Select`; reports numbers, fixes nothing |

Give B and C the plan and the facts section verbatim; give A and D only their step. Tell C the Auto box is a slider (`FigureAutoSlider`, `autoRedrawLimit`, `previewCost`, `keepCost`; the Figures tab's button column is 110 px), and that `figureDataSpec` is public, so it re-reads `buildFiguresTab.m`, `test_EphysFigGenApp.m` and the two docs pages before any whole-file write. If B's section-8 checks turn up a dressing property the snapshot misses, B extends `dressState`, not the key. If C finds phase 2 drawing when a run goes or on a probe figure, that is a missing bail-out, not a renderFigure bug.

## Left as is
- The editor refill (`gatherConfig` + `applyFigureEditor` + `setStatus`, about 3 s) still runs after the paint and keeps the app busy for that time. **Next step after this plan:** check whether every editor field already commits through `onConfigChanged`; if so, `gatherConfig` is redundant for structural edits and the 0.85 s goes.
- Layer edits still recompute their panel; the panel key holds all of its layers.
