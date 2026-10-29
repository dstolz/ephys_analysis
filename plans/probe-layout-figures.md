# Plan: probe-layout figures (any figure replicated at every site of the probe)

## Context

A figure (`EphysAnalysisConfig.Figures`) is panels on a grid drawn for **one
observation** (a unit, a channel, the dataset): `figureObservations` lists them,
`figureCompute` computes one, `renderFigure` draws it, a run writes a page per
observation (`EphysAnalysisRunner.runDataset`). A *session figure*
(`Figure.sessions.enabled`) is the precedent for a figure-level mode that
changes how the figure is observed, computed, drawn and run, with its own
editor section, picker, preview branch and runner path.

The owner wants a **new figure type: any existing figure replicated in the
spatial configuration of the electrode probe**: the whole arrangement drawn
once per unit (or channel), each copy a small *tile* at that unit's site on
the probe, all on one page per dataset. With strategies to avoid tiles
overlapping, options for which shanks / channels / units are included, and
attention to rendering time.

## Decisions

| Question | Decision |
| --- | --- |
| Shape | A figure-level block `Figure.probe` (`defaults("FigureProbe")`), like `sessions`. `probe.enabled` makes the figure a *probe figure*. Nothing refers to another figure by id (the codebase's rule), so "replicate an existing figure" is: duplicate it (**Duplicate** in the Figures tab, `cfg.duplicateFigure`) and tick **On the probe** on the copy, or tick it on the figure itself. |
| What is tiled | The figure's own panels, all of them, at the figure's grid. The observation kind stays `observe.data` (`units`, `detected`, a signal's channels). A dataset observation cannot be laid out (validate error). |
| Page | One page per dataset (like a dataset figure): the figure runs per dataset in `runDataset`, `enabledFigures` unchanged. The observation picker lists one entry, "the probe". |
| Positions | A unit's `meta.x`, `meta.y` (selectUnits: the probe map, `probeSites`), a channel's (selectChannels). Shanks / columns by `probeColumns` (the physical shanks whatever `kcoords` says). |
| Layouts | `schematic` (default): each shank a column band, sites clustered into **rows** by y (a tolerance of half the median pitch), rows equally spaced, so it never overlaps and dense probes stay readable; depth in µm written at the rows. `physical`: y in proportion to the sites' µm, x by the shanks' µm, tiles sized from the median site pitch, with an overlap strategy. |
| Overlap strategies (physical) | `nudge` (default): tiles sorted by y within a column slide apart along the shank to clear each other, keeping their order and the column's extent; a leader line from a moved tile to its site. `lanes`: the column's tiles alternate across `lanes` lanes beside the shank, then nudge within a lane. `shrink`: every tile shrinks (aspect kept) to the largest size that clears. `allow`: drawn as they fall. |
| Too many tiles | `maxTiles` (64): more observations than that keep every k-th in probe order (`round(linspace(1, n, maxTiles))`), and the page says how many were left out. `maxPerSite` (3): units on one recording channel beyond it are left out and counted; several on a site share the column band side by side. |
| Which sites | `probe.shanks` (kcoords), `probe.channels` (recording channels), `probe.depthRange` ([lo hi] µm) narrow the sites laid out; `observe.units` (ids, classes, quality, response test, ...) keeps filtering the units as it does for every figure. |
| Rendering time | (1) compute reuse: `figureCompute(..., Reuse=)` across the tiles (the figure's epochs are one step shared by every tile; the runner's FigureCache keeps every tile's steps so a look-only edit computes nothing); (2) tiles are drawn **without labels** (no tick labels, axis labels, titles, legends, notes; one legend and one title for the page) by the panel types' own draw functions into axes placed by pure arithmetic (`figureArrange` with zero insets: no `TightInset` measuring, no `figureLayout` pass per tile); (3) one bottom-left *scale tile* keeps its tick and axis labels, valid for every tile because `sharedY` (default on) puts each panel on one y range across the tiles, read from the drawn axes (no extra drawing); (4) aesthetics applied once per kind over the page, not per tile; data tips off unless asked; (5) the app previews a probe figure with progress per tile and Cancel at the runner's checkpoints, and the auto-preview rule (seconds) decides whether edits redraw it. No data is decimated: every spike, every sample the figure would draw is drawn. |
| Not in v1 | `observe.perGroup` on a probe figure (ignored, validate warns); a probe figure that is also a session figure (error); SVG size (left to Export.Formats). |

## Schema

`Figure.probe = EphysAnalysisConfig.defaults("FigureProbe")` (after `sessions`, before `latency`):

| Field | Default | Meaning |
| --- | --- | --- |
| `enabled` | `false` | a probe figure |
| `layout` | `"schematic"` | `"schematic"` or `"physical"` (`EphysAnalysisConfig.ProbeLayouts`) |
| `overlap` | `"nudge"` | physical: `"nudge"`, `"lanes"`, `"shrink"`, `"allow"` (`ProbeOverlaps`) |
| `lanes` | `2` | overlap `"lanes"`: lanes beside each shank (whole, >= 1) |
| `shanks` | `[]` | `[]` = all; else the kcoords shank numbers whose sites are laid out |
| `channels` | `[]` | `[]` = all; else the recording channels (1-based) whose sites are laid out |
| `depthRange` | `[]` | `[]` = all; else `[lo hi]` µm of probe y kept (lo < hi) |
| `maxTiles` | `64` | the most tiles on the page (whole, >= 1) |
| `maxPerSite` | `3` | the most units drawn on one site (whole, >= 1): the first in probe order |
| `tileWidth` | `0.9` | a tile's share (0, 1] of its column band's width |
| `tileHeight` | `0.9` | schematic: a tile's share (0, 1] of its row's height; physical: of the median site pitch (then times `tileScale`) |
| `tileScale` | `1` | physical: multiplies the tiles' size (> 0, finite) |
| `labels` | `"short"` | each tile's label: `"short"` (the unit's short label, `ch 7`), `"full"` (the observation's label), `"none"` (`ProbeTileLabels`) |
| `sharedY` | `true` | every tile's panel on one y range per panel (the union of the tiles' extents) |
| `scaleTile` | `true` | the bottom-left tile keeps its tick labels and axis labels, as the page's scale |
| `showSites` | `true` | the shank bodies and sites drawn pale behind the tiles |
| `leaders` | `true` | physical: a line from a moved tile to its site |

Config methods: `cfg.isProbeFigure(id)`, `cfg.probeFigureIds()`.
Validation (`checkFigureProbe`, field `<figure>.probe.<field>`): the enumerations;
`lanes`, `maxTiles`, `maxPerSite` whole >= 1; `tileWidth`, `tileHeight` in (0, 1];
`tileScale` > 0 finite; `shanks`, `channels` whole numbers; `depthRange` `[]` or
`[lo hi]`, lo < hi. With `enabled`: `sessions.enabled` too is an error ("laid out on the
probe or drawn across sessions, not both"); an observe kind `dataset` is an error;
`observe.perGroup` a warning (ignored); a `probemap` panel or a `waveforms` panel
with `layout "probe"` a warning (a probe inside the probe layout). The default block
raises nothing.

## Pieces and who owns them

### WP1: config, tiles, compute, runner, scripts (worktree A)

Files: `@EphysAnalysisConfig/{defaults,validate,EphysAnalysisConfig}.m`,
`figureSettingItems.m`, `figureSettingParts.m` (part `"probe"`, "On the probe"),
new `analysis/figureProbeTiles.m`, new `analysis/figureProbeCompute.m`,
`figureSkipReason.m`, `figureCaption.m`, `figureOutputName.m`, `figureExportSize.m`,
`newExportFigure.m`, `addReportFigure.m` (if it reads F), `@EphysAnalysisRunner/{computeProbeFigure (new),runDataset,plan}.m`,
`@EphysAnalysisScript/EphysAnalysisScript.m`, `documentation/EphysAnalysisConfig.md`
(a `### Probe figures` section under Figures, the field table, validate rules in the
rules table), `documentation/EphysAnalysis.md` (the Figures table rows for the new
functions), `CHANGELOG.md` (one Added entry for the whole feature),
`test_EphysAnalysisFigures.m` section 15.

`[T, left] = figureProbeTiles(src, spec)`: `figureObservations(src, spec)` with
`perGroup` off; rows with a finite position (a unit's `meta{1}.x / .y`, a channel's;
`T.shank`, `T.depth` as given), filtered by `probe.shanks`, `channels`, `depthRange`;
then at most `maxPerSite` rows per recording channel (the first in probe order);
then `maxTiles` by `round(linspace(1, n, maxTiles))`. `T` gains columns `x`, `y`
(µm). `left` is a struct of counts: `total` (the figure's observations),
`noPosition`, `filtered`, `overSite`, `overMax`, `kept`.

`[PF, K] = figureProbeCompute(src, spec, Check=, Reuse=, ProgressFcn=)`:
```
PF.kind        "probeFigure"
PF.id, PF.spec, PF.dataset (src.name), PF.created
PF.observation struct as figureCompute's F.observation: kind "probe", label
               "<n> units at their sites" / "<n> LFP channels at their sites" (what the
               tiles are), unitId NaN, channel NaN, column NaN, shank NaN, depth NaN,
               meta {}, group NaN, groupLabel ""
PF.probe       src.probe (chanMap, xc, yc, kcoords)
PF.sites       table of every site of the probe map: channel (1-based), x, y, shank
               (kcoords), included (passes shanks / channels / depthRange)
PF.tiles       struct array, one per row of T, in T's order: observation (the tile's
               figureCompute F.observation), x, y, shank, channel, F (figureCompute's
               result; [] when skip is set), skip ("" | the error's message)
PF.left        figureProbeTiles' left
PF.nTiles      numel(PF.tiles)
PF.epochs, PF.groups   the first computed tile's F.epochs / F.groups ([] when none):
               the figure's groups, for the one legend
```
Per tile: `Check` (the runner's checkpoint) between tiles, `ProgressFcn(i, n, label)`
before each, `[F, K] = figureCompute(src, spec, Observation=T(i, :), Check=, Reuse=pool)`
with `pool` = `Reuse` plus the Ks made so far (the figure's epochs are one step every tile
takes from the first). A tile whose compute throws a non-cancel error is kept with `skip`
= the message (`EphysAnalysisRunner:Canceled` rethrown). `K` out: every tile's steps.
A figure-level `figureSkipReason` throws `EphysAnalysisRunner:FigureSkipped` as
figureCompute does. No observation with a position: `PF.tiles` empty, no error.

`PF = r.computeProbeFigure(src, spec, Reuse=, ProgressFcn=)`: as `computeFigure`
(checkpoint while PollFcn, FigureCache in and out via `keepFigureCache(K)`).

`figureSkipReason`: a probe figure without `src.probe` -> `"no probe map"`; observing
the dataset -> `"a probe figure observes units or channels, not the dataset"`.
`figureOutputName`: an observation row of kind `"probe"` -> `{Unit}` `"probe"`.
`figureCaption(spec, T, Dataset=)` with `spec.probe.enabled`: *"<id>: <n> units laid
out at their sites on the probe (<k> shank(s)) of <dataset>; panels: ...; aligned to
..."*. `figureExportSize(EXPORT, PF, SPEC)` with `PF.kind "probeFigure"` and
`size.source "export"`: width `FigureSizeCm(1)`, height
`max(FigureSizeCm(2), min(80, 2 + L.nRows * spec.grid.rows * 1.5))` cm where
`L = probeTileLayout(PF, spec.probe)` (WP2's; call it, it is pure). `newExportFigure`
follows. `runDataset` on a probe figure: `T = figureProbeTiles` (none: a "skipped"
row, "no observation with a probe position"), `PF = r.computeProbeFigure`, one page
through `drawExportPage(PF, spec, Base=<folder>/<figureOutputName(..., obsProbe, 1, 1)>, ...)`
(obsProbe: a one-row table with kind "probe", label "probe"), the report entry with
`Observations=T` and the probe caption, `Message "<n> tile(s)"`. `plan`: Source
`"probe"`. `EphysAnalysisScript` (Export code, standalone scripts): for a probe figure
emit `PF = figureProbeCompute(src, fspec); fig = newExportFigure(cfg.Export, PF, fspec);
renderFigure(PF, fspec, fig)` in place of the observation loop.

### WP2: layout and renderer (worktree B)

Files: new `analysis/private/probeTileLayout.m` (pure), new `analysis/renderProbeFigure.m`,
`analysis/renderFigure.m` (dispatch and shared helpers), new `analysis/private/figureLookFor.m`,
`figurePanelCells.m`, `figureLegendEntries.m`, `figureDesignFor.m`, `figureKindRules.m`
(the local functions `lookFor`, `panelCells`, `legendEntries`, `designFor`, `kindRules`
moved out of renderFigure verbatim; renderFigure calls them), `documentation/EphysAnalysis.md`
(the Render table: a `renderProbeFigure` row; nothing else in that file),
`documentation/EphysAnalysisConfig.md` only under `### renderFigure` (one paragraph:
a probe figure's result is drawn by renderProbeFigure), `test_EphysAnalysisFigures.m` section 16.

`L = probeTileLayout(PF, popts)` (popts = `spec.probe`; PF needs `tiles` (x, y, shank,
channel) and `sites` (x, y, shank, included) only). Everything in **normalized page
units** (0-1 across and up the drawing area; x and y scaled apart: a probe is tall and
thin, so µm aspect is never kept). Fields:
```
L.n          tiles laid out (numel(PF.tiles))
L.box        [n x 4] each tile's [x y w h], bottom-left origin
L.anchor     [n x 2] the tile's site, normalized
L.moved      [n x 1] the tile is not centered on its anchor (a leader is drawn)
L.cols       struct (one entry per column in each field): lo, hi, center (the band,
             normalized x), shank (kcoords by probeColumns), n (sites), yLo, yHi (the
             body's extent, normalized)
L.rows       schematic: struct with y (normalized centers), um (the row's mean µm),
             n (tiles); physical: empty struct
L.nRows, L.nCols
L.depthTicks struct y (normalized), label (µm as text): schematic every row (thinned
             to ~12 when more), physical ~6 round-number ticks over the depth range
L.shrink     the factor overlap "shrink" applied (1 otherwise)
L.yRange     [lo hi] µm the page spans
```
Columns: `probeColumns` over the included sites' x and shank; a tile's column by its
x (`probeColumns`' third output). Column bands: schematic, equal widths `1 / nCols`;
physical, centers in proportion to the columns' µm centers, each band at least as wide
as the widest tile (the bands spread evenly when the probe is narrower than that).
Schematic rows: cluster the tiles' and included sites' y values (sorted; a new row when
the gap exceeds half the median pitch of the included sites, 1 µm when the pitch is 0);
row height `1 / nRows`, tiles `tileHeight` of it tall and `tileWidth` of the band wide;
tiles of one row and column side by side (sharing the band; beyond what fits they
share the width equally). Physical: y linear over the included sites' µm range padded
by half a tile; tile height `tileHeight * tileScale * medianPitchNormalized`; width
`tileWidth` of the band; then `overlap`. `nudge`: per column (per lane with `lanes`),
tiles sorted by y, pushed apart to `>= h` keeping order (forward pass from the bottom,
then clamp into [0, 1] and a backward pass), `moved` where the center left the
anchor by more than 1e-6. `lanes`: tile i of the column goes to lane
`mod(i - 1, lanes) + 1`, each lane `1 / lanes` of the band, then nudge. `shrink`: the
largest factor `<= 1` for which no two tiles of a column overlap (binary search or
the min gap / h), applied to w and h alike. `allow`: nothing. No tile: `L.n` 0,
empty fields, `nRows` 0. Deterministic and covered by tests on synthetic positions:
a 4 x 8 probe, a staggered (Buzsaki-like) shank, two units on one site, one unit
only, zero tiles.

`[h, how] = renderProbeFigure(PF, spec, target, Name=Value)`: the options renderFigure
takes (Design, UserAesthetics, Editable, DataTips (default false here), OnRemember, OnGoto,
OnAxisEdit, OnSelect, BatchYLim, Reuse, InPlaceOnly, Scale); `Reuse` is accepted and
ignored (every drawing is whole; `how` "drawn"); `InPlaceOnly` draws nothing (`how` "").
TARGET: a figure, uifigure, panel, tab or grid layout (`figureCanvas`); an axes is
refused (`renderProbeFigure:BadTarget`). Draws:
1. the page's title (as renderFigure's `figureTitle` / `autoTitle`: the id, PF.observation.label,
   the aligned event and epoch count) and the dataset subtitle on a hidden `titleHost`
   axes; one legend east (or where `Style.LegendLocation` says) from the first drawn
   tile's draw results (`figureLegendEntries`); the drawing area from
   `figureArrange(sz, 1x1 grid, one cell of zero inset, Top=, Legend=, Margin=, Scale=)`.
2. the **probe axes** (tag/role `probeAxes`, appdata `ProbeAxes` true) filling the area:
   x and y normalized [0 1], ticks off on x; with `showSites`, each column a pale body
   (role `probeBody`) over its yLo..yHi with a small pointed tip below, every site a
   small gray dot at its anchor (role `probeSites`; included sites darker), *Shank k*
   over each column (role `shankLabels`); the depth ticks on the y axis
   (`L.depthTicks`, y label "Probe y (µm)"); leaders (role `tileLeaders`) from each
   moved tile's nearest edge to its anchor when `leaders`.
3. the **tiles**: tile i's box in pixels (the area's origin plus `L.box(i, :)` times the
   area's size); the panels' boxes inside it by `figureArrange([w h], spec.grid, cells
   of zero inset (figurePanelCells), Margin=0, Scale=)`; one axes per panel
   (`axes(canvas, 'Units', 'pixels', 'Position', ...)`, appdata `FigurePanel` = the panel
   id, `ProbeTile` = i), drawn by `figurePanelRegistry().(type).draw(ax, P, look)` with
   `look = figureLookFor(F, spec, p, P, style, colors, isTime)`; `xlim` to the window on
   a `sharesTime` panel; then stripped: `XTickLabel` / `YTickLabel` `{}`, `XTick` / `YTick`
   `[]` (a color bar removed), no axis labels, no panel title, the panel's own `box`
   applied; the tile's label (role `tileLabels`, `labels` option, font `FontSize - 2`)
   at its top-left, over the tile. A tile with `skip` set, or an F whose every panel is
   skipped, is one empty axes with the text (role `note`), small. Overlays and notes of
   the panels are **not** drawn in tiles (documented).
4. **sharedY**: once every tile is drawn, for each panel id whose drawn axes' y is a
   value axis (every type but raster, heatmap, eventTrace, waveforms; a stacked PSTH /
   continuous panel by renderFigure's `extentOf` rule) the union of the tiles' y limits
   (or `BatchYLim` for that id, which wins) is set on every tile's axes of that panel.
5. the **scale tile**: the drawn tile lowest on the page, leftmost among those, keeps
   its tick labels (`tileTicks` sizes), the x label on its `sharesTime` panels where
   `figureTimeStack` would put it ("Time (s)" or the panel's xLabel), and each panel's
   y name (`hk.yName` or the panel's yLabel), in a small font. Off with `scaleTile` false.
6. aesthetics: `design.rules` on the canvas once; each kind's rules
   (`figureKindRules(design, type)` plus `PlotAesthetics.userRules(type)` with
   UserAesthetics) applied to that type's axes (check whether `PlotAesthetics.apply`
   takes an array of roots; else loop over axes); `PlotDesign.paint`; the figure's own
   `spec.aesthetics`; `Scale` through `PlotAesthetics.scaleSizes` as renderFigure does;
   Editable as renderFigure's rule; data tips only with `DataTips=true`.
7. resize: the positions are arithmetic, so a `SizeChangedFcn` on the canvas (chained
   as `figureLayout` chains, appdata `FigureLayoutFcn`) places the probe axes, the tiles'
   axes, the title and the legend again from what is kept in appdata (`ProbeFigureLayout`:
   the boxes, the axes, the grid). No redraw.
8. `h`: `canvas`, `title`, `legend`, `probeAxes`, `tiles` (struct array: `axes` [1 x np],
   `box` px, `observation`, `skipped`), `layout` (L), `how` "drawn".

`renderFigure(F, spec, target, ...)`: when `F.kind == "probeFigure"`, forward to
`renderProbeFigure` with the same options and return (first thing, before anything is
cleared). Everything else in renderFigure unchanged but the five helpers moved out.

### WP3: the app (worktree C)

Files: `@EphysAnalysisApp/*` and its `private/`, `documentation/EphysAnalysisApp.md`,
`test_EphysAnalysisApp.m` (section 5m). Rely on the contracts above (field names,
`r.computeProbeFigure`, `figureProbeTiles`, `renderFigure` dispatching a PF,
`cfg.isProbeFigure`).

- `buildFiguresTab`: a **Probe layout** section (key `"probe"`, in the FIGURE supersection
  right after Sessions, collapsed, no Ctrl key; search rows follow as the Sessions rows
  do). Rows: **On the probe (every unit or channel at its site, one page per dataset)**
  (`probe.enabled`); **Layout** (`layout`: *Schematic (rows of sites)*, *Physical (µm)*);
  **Overlap** (`overlap`: *Slide apart along the shank*, *Lanes beside the shank*, *Shrink
  the tiles*, *Allow*); **Lanes** (`lanes`, spinner); **Shanks** (`shanks`, comma list,
  blank = all, as the Observations section's shanks row parses); **Channels** (`channels`,
  likewise); **Depth range (µm)** (`depthRange`, "lo hi", blank = all); **Max tiles**
  (`maxTiles`); **Per site** (`maxPerSite`); **Tile width** / **Tile height** (spinners
  0.1-1, step 0.05); **Tile scale** (`tileScale`); **Labels** (`labels`: *Short*, *Full*,
  *None*); **Shared y** (`sharedY`); **Scale tile** (`scaleTile`); **Show sites**
  (`showSites`); **Leaders** (`leaders`); and a gray note (a label) saying what the
  active dataset gives: *"23 tiles: 23 units on 2 shanks; 3 left out (1 without a
  position, 2 over 3 per site)"* from `figureProbeTiles` when a source is open, else
  *"Scan and pick a dataset to count the tiles."*
- `syncFigureEditor`: every row shows once **On the probe** is ticked (Overlap, Lanes,
  Tile scale, Leaders enabled only with *Physical*; Lanes only with *Lanes*); the
  Observations section's **Per trial group** row hides; the Sessions **Across sessions**
  box is disabled while **On the probe** is ticked and the reverse.
- `gatherFigureEditor` / `applyFigureEditor`: the round trip; `figureEditLabel`
  (`private/`) names a `probe.*` edit *Probe layout* (its field for one).
- `refreshFigureObservations`: a probe figure lists one entry, *"the probe: 23 units on
  2 shanks"*, the count line *"Laid out on the probe: 23 tiles; 3 left out (...)"*; **<**
  **>** disabled; starred marks not applied.
- `refreshFigurePreview`: a probe branch like a plain figure's but
  `PF = rn.computeProbeFigure(src, spec, Reuse=true, ProgressFcn=@(i, n, lab)
  obj.setFigurePreviewState("computing", Message=sprintf("Computing tile %d/%d (%s) on
  %s ...", i, n, lab, src.name)))`, Cancel through the same PollFcn / checkpoint, then
  `renderFigure(PF, spec, obj.FigurePreviewPanel, Scale=previewScale(obj, spec), Reuse=false,
  OnRemember=..., OnGoto=..., OnAxisEdit=..., OnSelect=...)`. `FigurePreviewResult = PF`.
  Status line *"<id> on <dataset>: 23 tiles, 3 left out (4.2 s); right-click to change
  colors, lines and fonts"*. The auto-preview seconds rule applies as for any figure.
  Check `onOpenFigureWindow`, `onExportPreview`, Export code (`EphysAnalysisScript` via
  WP1) draw a PF (renderFigure dispatches; `newExportFigure(Export, PF, spec)` sizes it).
- `private/figureGroups` and `markFigureTree`: probe figures grouped *"on the probe"*
  as session figures are *"across sessions"*.
- `onGenerateFigure`: a probe figure generates per dataset as any figure (one page
  each); the status text says *"... 1 page (23 tiles) ..."* where it counts observations
  if that text is per-observation.
- `documentation/EphysAnalysisApp.md`: a `#### Probe layout in the Figures tab`
  subsection after the Sessions one (the rows table, the preview, Generate), the
  **Panel types** / **Where the code is** / **Tests** entries; `helpURL` anchors must be
  headings (`tools/wiki/test_gen_pages.py` checks).
- `test_EphysAnalysisApp` section 5m: the section's rows wired to the config (gather /
  apply, enabled toggling the rows, Physical enabling Overlap), the picker's one entry
  and count line, the preview drawing tiles (axes with appdata `ProbeTile`) and its
  status line, Undo of a probe edit named *Probe layout*, Generate writing one page.

### WP4: integration (the orchestrator)

Merge A, B, C; make section 16's tests use `figureProbeCompute`; `python
.github/scripts/select_suites.py --worktree --sections --why`; push; PR; CI; fixes.

## Facts verified in the code that shape the design

- `figureCompute(..., Reuse=K0)` keys every step by its inputs; the figure's epochs key
  does not include the observation, so every tile reuses the first tile's epochs; the
  runner's `FigureCache` keeps 256 MB, most recent first (`keepFigureCache`).
- `renderFigure` draws a panel through `figurePanelRegistry().(type).draw(ax, P, look)`;
  `look` is built by its local `lookFor` (style, colors, W, spec, panel, panelId, isTop,
  isBottom, epochs, groups, observation, isTime). The draw functions read `look.panel`,
  `panelId`, `W`, `style`, `colors`, `spec`, `observation`, `groups`, `epochs`.
- `figureArrange(sz, grid, cells, Top=, Legend=, Margin=, Scale=)` is pure: with zero
  insets it is the arithmetic of the grid; `L.panels(k).box` the plot box.
- `figureCanvas(target)` empties a figure / panel / tab / grid layout and returns the
  canvas; `figureLayout` chains `SizeChangedFcn` through appdata `FigureLayoutFcn`.
- `probeColumns(x, shank, xq)` groups sites into physical shanks and gives each query
  point's column; `probeSites(probe, ch)` a channel's shank and position.
- `selectUnits`' table has `shank`, `x`, `y`; `selectChannels`' has `shank`, `x`, `y`;
  `figureObservations` carries them as `shank`, `depth` and in `meta{1}`.
- `makeAnalysisFixture` (test data): `makeSyntheticProbe(8)`: one shank of 8 sites, 25 µm
  pitch, x staggered by 8 µm (one `probeColumns` column). Multi-shank layouts are tested on
  synthetic positions.
- The session figure is the pattern for every seam: `defaults("FigureSessions")`,
  `checkFigureSessions`, `isSessionFigure`, the Sessions editor section
  (`buildFiguresTab` ~line 473), `gatherFigureEditor` ~74, `applyFigureEditor` ~65,
  `syncFigureEditor` ~180, `refreshFigureObservations` ~47, `refreshFigurePreview` ~79,
  `figureGroups`, `figureSettingItems` ~116, `figureSettingParts`, `runDataset` /
  `runSessionFigure`, `EphysAnalysisScript` ~319.
- No MATLAB on the development machine: the suites run in CI
  (`.github/workflows/matlab-tests.yml`, R2025a on Windows; `select_suites.py` picks them).
