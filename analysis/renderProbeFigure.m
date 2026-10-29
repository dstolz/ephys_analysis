function [h, how] = renderProbeFigure(PF, spec, target, opts)
%renderProbeFigure  Draw a probe figure: the figure's panels as a small tile at every unit's (or channel's) site on the probe, one page.
%   [H, HOW] = renderProbeFigure(PF, SPEC, TARGET, Name=Value) draws PF
%   (figureProbeCompute's result: PF.tiles, one figureCompute result per
%   unit or channel with its site; PF.sites, the probe map) as SPEC says
%   (Config.figureFor(id) of a figure with probe.enabled; SPEC.probe is
%   the layout, probeOptions filling what it lacks). TARGET is a figure,
%   uifigure, panel, tab or grid layout (figureCanvas: emptied; a grid
%   layout gets a panel); an axes is refused. renderFigure forwards a PF
%   here.
%
%   Layout   probeTileLayout (pure): "schematic" rows of sites or
%            "physical" µm, with the overlap strategy (nudge, lanes,
%            shrink, allow), in normalized units over the drawing area,
%            which figureArrange gives (a 1 x 1 grid: the title over it, the
%            legend beside it, room for the scale tile's labels left of and
%            under it and for the depth ticks right of it). Every position
%            is arithmetic: no TightInset is read, no drawnow made.
%   Title    the figure's (figureAutoTitle: SPEC.title, else "<id>: <n>
%            units at their sites — <event> (<n> epochs)") on a hidden
%            titleHost axes; the dataset as its subtitle, and a line
%            "<k> of <n> drawn; left out: ..." when PF.left counts any.
%   Probe    the probe axes (Tag and role "probeAxes", appdata ProbeAxes
%            true) fill the area, x and y 0 to 1, no x axis; the depth
%            ticks (L.depthTicks) on the right, labeled "Probe y (µm)".
%            With probe.showSites each column a pale body (role
%            "probeBody") with a pointed tip, every site a dot (role
%            "probeSites", group "included" darker, "excluded" paler: a
%            site outside the shanks, channels or depth range kept), "Shank
%            k" over each column (role "shankLabels"); with probe.leaders
%            (physical) a line from each moved tile's nearest edge to its
%            site (role "tileLeaders"). They take no clicks (HitTest off,
%            PickableParts none); the tiles' axes are made after the probe
%            axes, so they are on top.
%   Tiles    tile i at L.box(i, :) of the area; its panels where
%            figureArrange puts them in the tile (SPEC.grid, panels of zero
%            inset, no margin). One axes per panel (appdata FigurePanel:
%            its id; ProbeTile: i; role "axes", or its type's axes role,
%            named by panel id as renderFigure's), drawn by the type's draw
%            function (figurePanelRegistry) with figureLookFor's LOOK; a
%            time panel shows the window. Then stripped: no ticks, tick
%            labels, axis labels, panel title or color bar. A panel's own
%            box is set last. Each tile's label (role "tileLabels", one
%            text per tile, at the top left of its top-left panel, Style.
%            FontSize - 2): probe.labels "short" (the observation label's
%            first part: the unit, "LFP ch 7"), "full" (its label), "none".
%            A tile whose compute was skipped (PF.tiles(i).skip) or whose
%            every panel is skipped is one empty axes saying why (role
%            "note"). A tile without a position is not drawn. The panels'
%            notes and overlays and their own legends are not drawn in
%            tiles.
%   Shared y with probe.sharedY (default), each panel id whose y is a
%            value axis -- every type but raster, heatmap, eventTrace,
%            waveforms, probemap, corrmap and spectrogram; not a PSTH drawn
%            as a heat map, a coherogram, a panel with options.yLimMode
%            "fixed", nor a stack (a yyaxis, or a draw function's own
%            yExtent: its rows are drawn on each tile's own scale) -- is set
%            to one y range on every tile: BatchYLim's range for that id
%            (figureBatchYLim; it wins), else the union of the tiles' y
%            limits as drawn. So one tile's axes tell every tile's.
%   Scale tile with probe.scaleTile (default), the drawn tile lowest on
%            the page (leftmost of those) keeps its ticks (tileTicks'
%            sizes), color bars, its time panels' x label where
%            figureTimeStack puts it ("Time (s)" or the panel's xLabel; a
%            panel of another x axis keeps its own), each panel's y name
%            (the type's, or the panel's yLabel), in Style.FontSize - 1.
%   Legend   one, from the first drawn tile's panels (figureLegendEntries),
%            in a band beside the area (Style.LegendLocation; "inside" and
%            "none" take the east band) on a hidden legendHost axes.
%   Aesthetics  the design's common rules once over the page; each panel's
%            kind rules (figureKindRules, the user's PlotAesthetics.
%            userRules of the type, a raster's tickWidth) applied once per
%            panel id to every tile's axes of that panel in one call
%            (PlotAesthetics.apply takes an array of axes as its target:
%            one components pass per panel, not per tile); PlotDesign.
%            paint; then the "figure" rules and SPEC.aesthetics over the
%            page; the panels' own box; Scale through PlotAesthetics.
%            scaleSizes, the root keeping it (drawScale).
%   Resize   the canvas keeps what places everything (appdata
%            ProbeFigureLayout: L, the grid, the parts) and figureLayout
%            chains its SizeChangedFcn as for any figure (appdata
%            FigureLayout's layoutFcn): a new size places the probe axes,
%            the tiles' axes, the title and the legend again. Nothing is
%            redrawn.
%
%   Options: renderFigure's -- Design, UserAesthetics, Editable,
%   OnRemember, OnGoto, OnAxisEdit, OnSelect, BatchYLim, Reuse, InPlaceOnly,
%   Scale -- and DataTips, here false by default ("auto" too: a page of
%   tiles gets data tips only when asked with true). Reuse is accepted and
%   ignored (every drawing is whole); InPlaceOnly draws nothing (HOW "", H
%   []). Editable puts the aesthetics editor on the page (figureEditContext:
%   its redraw draws PF again through renderFigure), its right-click menus
%   on the probe axes, one tile (the scale tile, else the first drawn), the
%   title and the legend only (context.menuRoot: a menu is a web component
%   each in a uifigure, and a page of tiles has many parts); an edit made
%   there applies to every tile. OnSelect is called
%   with a panel's id when any tile's axes of that panel is Ctrl+Clicked.
%
%   H fields
%     canvas     what the page is drawn on (TARGET, or the panel made in a
%                grid layout)
%     title      the title's text; titleHost its hidden axes
%     legend     the legend ([] = none)
%     probeAxes  the probe axes
%     axes       every tile's panel axes, in tile and panel order
%     tiles      one per PF.tiles: axes (1 x np, not drawn: no graphics
%                object), note (a skipped tile's axes), box (px on the
%                canvas, [x y w h]; NaN without a position), observation,
%                skipped
%     layout     probeTileLayout's L
%     how        "drawn"
%   Errors: renderProbeFigure:BadTarget, renderProbeFigure:Mismatch (a
%   tile's panels are not SPEC's).
%
%   See also renderFigure, probeTileLayout, figureProbeCompute, figureArrange,
%   figureLayout, PlotAesthetics.

arguments
    PF (1,1) struct
    spec (1,1) struct
    target
    opts.Design = ""
    opts.UserAesthetics (1,1) logical = true
    opts.Editable = "auto"
    opts.OnRemember = []
    opts.OnGoto = []
    opts.OnAxisEdit = []
    opts.OnSelect = []
    opts.DataTips = false
    opts.BatchYLim = []
    opts.Reuse (1,1) logical = false
    opts.InPlaceOnly (1,1) logical = false
    opts.Scale (1,1) double {mustBePositive, mustBeFinite} = 1
end
h = [];
how = "";
if opts.InPlaceOnly; return; end   % nothing a drawing of the page can set in place
how = "drawn";
if ~(isa(target, 'matlab.ui.Figure') || isa(target, 'matlab.ui.container.Panel') || isa(target, 'matlab.ui.container.Tab') ...
        || isa(target, 'matlab.ui.container.GridLayout'))
    error('renderProbeFigure:BadTarget', 'Draw a probe figure into a figure, a panel, a tab or a grid layout, not an axes.');
end

popts = struct();
if isfield(spec, 'probe'); popts = spec.probe; end
o = probeOptions(popts);
[design, follows] = figureDesignFor(opts.Design, opts.UserAesthetics);
s = spec.style;
s.Design = design;
style = renderStyle(s);
style.XLim = [];
style.YLim = [];
style.CLim = [];
panels = spec.panels;
np = numel(panels);
types = strings(1, np);
sIds = strings(1, np);
for k = 1:np
    types(k) = panels(k).type;
    sIds(k) = panels(k).id;
end
PT = EphysAnalysisConfig.panelTypes();
reg = figurePanelRegistry();
isTime = false(1, np);
for k = 1:np
    row = PT.Type == types(k);
    isTime(k) = any(row) && (PT.SharesTime(row) || figureOverEpochs(panels(k)));
end
G = [];
if isfield(PF, 'groups'); G = PF.groups; end
colors = zeros(0, 3);
if istable(G) && height(G) > 0; colors = groupPalette(G, style); end

% the tiles: which are drawn, which say why not
tiles = struct('F', {}, 'skip', {}, 'observation', {});
if isfield(PF, 'tiles') && isstruct(PF.tiles); tiles = PF.tiles; end
n = numel(tiles);
L = probeTileLayout(PF, o);
placed = reshape(all(isfinite(L.box), 2), 1, []);
why = strings(1, n);   % "" = drawn
for i = 1:n
    t = tiles(i);
    if isfield(t, 'skip') && string(t.skip) ~= ""
        why(i) = string(t.skip);
    elseif ~isfield(t, 'F') || ~isstruct(t.F) || isempty(t.F)
        why(i) = "not computed";
    else
        fIds = strings(1, numel(t.F.panels));
        for k = 1:numel(t.F.panels); fIds(k) = t.F.panels(k).id; end
        if ~isequal(fIds, sIds)
            error('renderProbeFigure:Mismatch', 'Tile %d holds the panels [%s], the spec [%s]: draw PF with the spec it was computed with.', ...
                i, strjoin(fIds, ", "), strjoin(sIds, ", "));
        end
        sk = strings(1, np);
        for k = 1:np; sk(k) = string(t.F.panels(k).skip); end
        if np > 0 && all(sk ~= ""); why(i) = "Nothing to draw: " + sk(1); end
    end
end
drawable = placed & why == "";
scaleI = 0;   % the scale tile: the lowest drawn tile, leftmost of those
if o.scaleTile && any(drawable)
    cand = find(drawable);
    b = L.box(cand, :);
    low = cand(abs(b(:, 2) - min(b(:, 2))) < 1e-9);
    [~, j] = min(L.box(low, 1));
    scaleI = low(j);
end

[canvas, ~] = figureCanvas(target);
scaleKey = char(PlotAesthetics.ScaleKey);
if isappdata(canvas, scaleKey); rmappdata(canvas, scaleKey); end
if isappdata(target, 'FigureDrawing'); rmappdata(target, 'FigureDrawing'); end   % renderFigure's Reuse keeps nothing of a probe page
sz = [700 500];   % the export page's size the parts are drawn at (TARGET's over Scale): as renderFigure's first layout
try
    q = getpixelposition(canvas);
    if all(q(3:4) > 40); sz = q(3:4) / opts.Scale; end
catch
end

% the title's lines (the band they take, until they are drawn)
[txt, ~] = figureAutoTitle(PF, spec);
sub = "";
if isfield(PF, 'dataset'); sub = string(PF.dataset); end
lines = [sub; leftLine(PF, o)];
lines = lines(lines ~= "");
pt = 96 / 72;
px = pt * style.FontSize;
inset = [4, 8, 6, 0];   % [left bottom right top] px: the scale tile's labels left and under, the depth ticks right, the shank labels over
if o.scaleTile; inset(1:2) = [4.5 3] * px; end
if ~isempty(L.depthTicks.label)
    inset(3) = (max(strlength(L.depthTicks.label)) * 0.6 * max(6, style.FontSize - 2) + 1.6 * style.FontSize) * pt + 8;
end
if o.showSites && L.nCols > 0; inset(4) = 1.6 * style.FontSize * pt; end
cells = struct('r1', {}, 'r2', {}, 'c1', {}, 'c2', {}, 'size', {}, 'align', {}, 'valign', {}, 'inset', {}, ...
    'band', {}, 'need', {}, 'shares', {});
C0 = figurePanelCells(spec.grid, panels);
for k = 1:np
    c = C0(k);
    cells(k) = struct('r1', c.r1, 'r2', c.r2, 'c1', c.c1, 'c2', c.c2, 'size', c.size, 'align', c.align, 'valign', c.valign, ...
        'inset', [0 0 0 0], 'band', "", 'need', 0, 'shares', 1);
end
D = struct('L', L, 'grid', spec.grid, 'cells', {cells}, 'inset', inset, 'top', pt * 1.3 * ((style.FontSize + 1) + numel(lines) * style.FontSize) + 4, ...
    'scale', 1, 'probeAxes', [], 'titleHost', [], 'legend', [], 'side', "", 'parts', {cell(n, np)}, 'notes', {cell(1, n)}, ...
    'placed', placed, 'px', NaN(n, 4));
area = pageArea(D, sz, 1);

% the probe axes, first: the tiles' axes go on top of it
pax = axes(canvas, 'Units', 'pixels', 'Position', [area(1:2) max(area(3:4), 1)], 'Tag', 'probeAxes');
setappdata(pax, 'ProbeAxes', true);
drawProbe(pax, L, o, style);
tagPart(pax, "probeAxes", "", "probe");
D.probeAxes = pax;

% the tiles: each panel drawn by its type, then stripped of its labels (the scale tile keeps them)
k1 = 0;   % the top-left panel: it holds the tile's label
if np > 0
    [~, k1] = min([panels.row] * 1e6 + [panels.col]);
end
axsOf = repmat({gobjects(1, 0)}, 1, np);   % each panel's axes on every tile (and their further axes): its looks
hks1 = {};   % the first drawn tile's draw results: the legend
stacked = false(n, np);
tileAxes = repmat({gobjects(1, np)}, 1, n);
hkOf = cell(n, np);
for i = find(placed)
    tb = tileBox(area, L.box(i, :));
    D.px(i, :) = tb;   % (placeProbe places it at TARGET's size)
    lab = tileLabel(tiles(i), o.labels);
    if ~drawable(i)   % one empty axes saying why
        na = axes(canvas, 'Units', 'pixels', 'Position', [tb(1:2) max(tb(3:4), 1)], 'XTick', [], 'YTick', [], 'Box', 'on', ...
            'XLim', [0 1], 'YLim', [0 1], 'Color', 'none', 'XColor', [0.8 0.8 0.8], 'YColor', [0.8 0.8 0.8]);
        setappdata(na, 'ProbeTile', i);
        tagPart(na, "axes", "", "skipped");
        tagPart(text(na, 0.5, 0.5, why(i), 'Units', 'normalized', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontSize', max(6, style.FontSize - 3), 'Interpreter', 'none', 'Color', [0.45 0.45 0.45], 'Clipping', 'on'), "note");
        if lab ~= ""; labelTile(na, lab, style); end
        D.notes{i} = na;
        continue
    end
    F = tiles(i).F;
    A = figureArrange(max(tb(3:4), 1), spec.grid, cells, Margin=0, Scale=1);
    for k = 1:np
        p = panels(k);
        P = F.panels(k);
        bx = A.panels(k).box;
        ax = axes(canvas, 'Units', 'pixels', 'Position', [tb(1:2) + bx(1:2), max(bx(3:4), 1)]);
        setappdata(ax, 'FigurePanel', p.id);
        setappdata(ax, 'ProbeTile', i);
        cl = colors;
        own = isfield(P, 'ownSelection') && P.ownSelection && istable(P.groups) && height(P.groups) > 0;
        if own; cl = groupPalette(P.groups, style); end
        look = figureLookFor(F, spec, p, P, style, cl, isTime(k));
        look.batchYLim = figureBatchFor(opts.BatchYLim, p.id);
        if isfield(reg, p.type)
            hk = reg.(p.type).draw(ax, P, look);
        else
            hk = figDrawResult(ax);
            figLayerNotes(ax, P, look, false, "Unknown panel type """ + p.type + """");
        end
        ax = hk.axes;
        setappdata(ax, 'FigurePanel', p.id);
        setappdata(ax, 'ProbeTile', i);
        role = string(ax.Tag);
        if ~ismember(role, ["axes" "rasterAxes"]); role = "axes"; end
        tagPart(ax, role, "", p.id);
        if p.sharesTime && ~isempty(look.W)
            xlim(ax, [spec.window.pre spec.window.post]);
        end
        if own   % its groups are not the figure's: not in the page's legend
            hk.legendHandles = gobjects(1, 0);
            hk.legendLabels = strings(1, 0);
            hk.legendGroup = false(1, 0);
        end
        extra = gobjects(1, 0);
        if isfield(hk, 'extraAxes'); extra = reshape(hk.extraAxes(isgraphics(hk.extraAxes)), 1, []); end
        parts = [ax extra];
        D.parts{i, k} = parts;
        tileAxes{i}(k) = ax;
        hkOf{i, k} = hk;
        stacked(i, k) = numel(ax.YAxis) > 1 || (isfield(hk, 'yExtent') && numel(hk.yExtent) == 2 && all(isfinite(hk.yExtent)));
        axsOf{k} = [axsOf{k} parts];
        if i ~= scaleI; stripAxes(parts); end
        clearTitle(parts);
    end
    if isempty(hks1); hks1 = hkOf(i, :); end
    if lab ~= "" && k1 > 0; labelTile(tileAxes{i}(k1), lab, style); end
end

% one y range per panel across the tiles
if o.sharedY
    for k = 1:np
        if ~sharesY(panels(k)); continue; end
        A = gobjects(1, 0);
        for i = find(drawable)
            if ~stacked(i, k) && isgraphics(tileAxes{i}(k)); A(end+1) = tileAxes{i}(k); end %#ok<AGROW>
        end
        if isempty(A); continue; end
        lim = figureBatchFor(opts.BatchYLim, panels(k).id);
        if ~(isnumeric(lim) && numel(lim) == 2 && all(isfinite(lim)) && lim(2) > lim(1))
            Y = get(A, 'YLim');
            if iscell(Y); Y = vertcat(Y{:}); end
            lim = [min(Y(:, 1)) max(Y(:, 2))];
        end
        if lim(2) > lim(1); set(A, 'YLim', double(reshape(lim, 1, 2))); end
    end
end

% the scale tile: its ticks and labels, small
labelSize = max(6, style.FontSize - 1);
if scaleI > 0
    As = tileAxes{scaleI};
    for k = find(isgraphics(As))
        ax = As(k);
        hk = hkOf{scaleI, k};
        if hk.yName ~= ""; ylabel(ax, hk.yName, 'Interpreter', 'none'); end
        if panels(k).yLabel ~= ""; set(ax.YAxis(1).Label, 'String', panels(k).yLabel, 'Interpreter', 'none'); end
        if ~isTime(k) && panels(k).xLabel ~= ""; xlabel(ax, panels(k).xLabel, 'Interpreter', 'none'); end
    end
    figureTimeStack(As, panels, isTime, labelSize);
    all1 = [D.parts{scaleI, :}];
    tileTicks(all1, style);
    for ax = all1
        set([ax.XAxis(1).Label reshape([ax.YAxis.Label], 1, [])], 'FontSize', labelSize);
    end
end

% the title, and one legend
th = axes(canvas, 'Units', 'pixels', 'Position', [1 1 1 1], 'Visible', 'off', 'HitTest', 'off', 'Tag', 'titleHost');
title(th, txt, 'FontSize', style.FontSize + 1, 'FontWeight', 'bold', 'Interpreter', 'none', 'Visible', 'on');
if ~isempty(lines); subtitle(th, lines, 'FontSize', style.FontSize, 'Interpreter', 'none', 'Visible', 'on'); end
D.titleHost = th;
lgd = [];
lhost = gobjects(1, 0);
if style.Legend && ~isempty(hks1)
    [lh, ll] = figureLegendEntries(hks1, types, G);
    if ~isempty(lh)
        side = figureLegendSide(style);
        if side == ""; side = "east"; end
        ls = style;
        ls.LegendLocation = "none";
        if string(ls.LegendOrientation) == "auto" && ismember(side, ["north" "south"]); ls.LegendOrientation = "horizontal"; end
        host = axes(canvas, 'Units', 'pixels', 'Position', [1 1 1 1], 'Visible', 'off', 'HitTest', 'off', ...
            'PickableParts', 'none', 'Tag', 'legendHost');
        lgd = placeLegend(host, lh, ll, ls, [], "east");
        lhost = host;
        D.legend = lgd;
        D.side = side;
    end
end

% aesthetics: the design's common rules, each panel's kind (once over all its tiles), then the figure's
specRules = PlotAesthetics.normalizeRules(spec.aesthetics);
PlotAesthetics.apply(canvas, design.rules);
for k = 1:np
    if isempty(axsOf{k}); continue; end
    r = figureKindRules(design, types(k));
    if opts.UserAesthetics && isvarname(types(k)); r = [r PlotAesthetics.userRules(types(k))]; end %#ok<AGROW>
    if types(k) == "raster" && isfield(panels(k).options, 'tickWidth') && panels(k).options.tickWidth > 0
        r = [r PlotAesthetics.normalizeRules(struct('role', "rasterTicks", 'group', "", 'property', "LineWidth", ...
            'value', panels(k).options.tickWidth))]; %#ok<AGROW>
    end
    PlotAesthetics.apply(axsOf{k}, r);
end
PlotDesign.paint(canvas, design);
r = figureKindRules(design, "figure");
if opts.UserAesthetics; r = [r PlotAesthetics.userRules("figure")]; end
PlotAesthetics.apply(canvas, [r specRules]);
for k = 1:np   % a panel's own box wins
    if panels(k).box ~= "auto" && ~isempty(axsOf{k}); set(axsOf{k}, 'Box', char(panels(k).box)); end
end
if opts.Scale ~= 1
    PlotAesthetics.scaleSizes(canvas, opts.Scale);
    setappdata(canvas, scaleKey, opts.Scale);
end

% the layout at TARGET's size, again whenever it changes (figureLayout chains the callback)
D.scale = opts.Scale;
setappdata(canvas, 'ProbeFigureLayout', D);
figureLayout(canvas, struct('layoutFcn', @placeProbe));
D = getappdata(canvas, 'ProbeFigureLayout');

if figureEditable(opts.Editable, target)
    % the right-click editor: its menus on the probe axes, one tile (the scale tile, else the first drawn), the title and the
    % legend, not on every part of every tile (a web component each in a uifigure); its edits apply to the whole page
    menuTile = scaleI;
    if menuTile == 0 && any(drawable); menuTile = find(drawable, 1); end
    menuAxes = gobjects(1, 0);
    if menuTile > 0; menuAxes = [D.parts{menuTile, :}]; end
    ctx = figureEditContext(PF, spec, target, opts, canvas, design, follows, txt);
    ctx.menuRoot = [pax reshape(menuAxes, 1, []) th lhost];
    PlotAesthetics.enableEditing(target, ctx);
end
if ~isempty(opts.OnSelect)
    for k = 1:np
        if ~isempty(axsOf{k}); figurePickable(axsOf{k}, @(ctrl) opts.OnSelect(panels(k).id, ctrl)); end
    end
end
tips = opts.DataTips;
if (isstring(tips) || ischar(tips)) && string(tips) == "auto"; tips = false; end
if figureEditable(tips, target)
    for i = find(drawable)
        hp = repmat(struct('id', "", 'type', "", 'axes', gobjects(0), 'extraAxes', gobjects(0), 'note', gobjects(0), ...
            'overlays', gobjects(1, 0), 'yExtent', [NaN NaN]), 1, np);
        for k = 1:np
            hp(k).id = sIds(k);
            hp(k).type = types(k);
            parts = D.parts{i, k};
            if ~isempty(parts); hp(k).axes = parts(1); hp(k).extraAxes = parts(2:end); end
        end
        FigureDataTips.attach(tiles(i).F, spec, struct('panels', {hp}));
    end
end

% H
T = repmat(struct('axes', gobjects(1, np), 'note', gobjects(0), 'box', NaN(1, 4), 'observation', struct(), 'skipped', false), 1, n);
allAxes = gobjects(1, 0);
for i = 1:n
    T(i).axes = tileAxes{i};
    if ~isempty(D.notes{i}); T(i).note = D.notes{i}; end
    T(i).box = D.px(i, :);
    if isfield(tiles(i), 'observation') && isstruct(tiles(i).observation); T(i).observation = tiles(i).observation; end
    T(i).skipped = why(i) ~= "";
    allAxes = [allAxes tileAxes{i}(isgraphics(tileAxes{i}))]; %#ok<AGROW>
end
h = struct('canvas', canvas, 'title', txt, 'titleHost', th, 'legend', [], 'probeAxes', pax, 'axes', allAxes, ...
    'tiles', {T}, 'layout', L, 'how', how);
h.legend = lgd;
end


function placeProbe(canvas)
%placeProbe  Place a probe page on CANVAS at its size: the probe axes, every tile's axes, the title and the legend (appdata ProbeFigureLayout).
%   figureLayout calls it (FigureLayout's layoutFcn), when drawn and
%   whenever CANVAS changes size. Pure arithmetic: probeTileLayout's
%   normalized boxes over the area, figureArrange inside each tile. The
%   tiles' px boxes are kept (D.px). A canvas under 40 px a side, or a page
%   drawn over since, is left as it is.
if ~isvalid(canvas) || ~isappdata(canvas, 'ProbeFigureLayout'); return; end
D = getappdata(canvas, 'ProbeFigureLayout');
if ~isstruct(D) || isempty(D.probeAxes) || ~isgraphics(D.probeAxes); return; end
q = getpixelposition(canvas);
sz = q(3:4);
if any(sz < 40); return; end
[area, A] = pageArea(D, sz, D.scale);
set(D.probeAxes, 'Units', 'pixels', 'Position', [area(1:2) max(area(3:4), 1)]);
[n, np] = size(D.parts);
for i = find(D.placed)
    tb = tileBox(area, D.L.box(i, :));
    D.px(i, :) = tb;
    if ~isempty(D.notes{i}) && isgraphics(D.notes{i})
        set(D.notes{i}, 'Units', 'pixels', 'Position', [tb(1:2) max(tb(3:4), 1)]);
        continue
    end
    cells = D.cells;
    any1 = false;
    for k = 1:np
        m = numel(D.parts{i, k});
        any1 = any1 || m > 0;
        if m > 1; cells(k).shares = [2 ones(1, m - 1)]; end
    end
    if ~any1; continue; end
    C = figureArrange(max(tb(3:4), 1), D.grid, cells, Margin=0, Scale=D.scale);
    for k = 1:np
        P = D.parts{i, k};
        Ak = C.panels(k).axes;
        for j = 1:min(numel(P), size(Ak, 1))
            if isgraphics(P(j)); set(P(j), 'Units', 'pixels', 'Position', [tb(1:2) + Ak(j, 1:2), max(Ak(j, 3:4), 1)]); end
        end
    end
end
if n == 0; D.px = zeros(0, 4); end
if ~isempty(D.legend) && isgraphics(D.legend) && ~isempty(A.legend)
    D.legend.Position = A.legend;
end
if ~isempty(D.titleHost) && isgraphics(D.titleHost)
    if isempty(A.title)
        set(D.titleHost, 'Units', 'pixels', 'Position', [A.area(1), A.area(2) + A.area(4), A.area(3), 1]);
    else
        set(D.titleHost, 'Units', 'pixels', 'Position', [A.title(1:3) 1]);
    end
end
setappdata(canvas, 'ProbeFigureLayout', D);
end


function [area, A] = pageArea(D, sz, scale)
%pageArea  The drawing area of a probe page of SZ px (figureArrange: one cell, the title's band over it, the legend's beside it).
%   The title's band from its fonts (no TightInset read: a line 1.3 times
%   its font), the legend's from its size; SCALE multiplies the insets
%   (the labels' room, at the export's sizes) as the fonts are.
top = D.top * scale;
if ~isempty(D.titleHost) && isgraphics(D.titleHost)
    t = D.titleHost.Title;
    st = D.titleHost.Subtitle;
    nT = nnz(strlength(string(t.String)) > 0);
    nS = nnz(strlength(string(st.String)) > 0);
    top = 0;
    if nT + nS > 0; top = 96 / 72 * 1.3 * (nT * t.FontSize + nS * st.FontSize) + 4 * scale; end
end
leg = struct('side', "", 'size', [0 0]);
if ~isempty(D.legend) && isgraphics(D.legend) && D.side ~= ""
    if ~strcmp(D.legend.Units, 'pixels'); D.legend.Units = 'pixels'; end
    p = D.legend.Position;
    leg = struct('side', D.side, 'size', p(3:4));
end
one = struct('r1', 1, 'r2', 1, 'c1', 1, 'c2', 1, 'size', [1 1], 'align', "center", 'valign', "middle", ...
    'inset', D.inset * scale, 'band', "", 'need', 0, 'shares', 1);
g1 = struct('rows', 1, 'cols', 1, 'rowHeights', [], 'colWidths', [], 'spacing', "none", 'gapUnits', "px", ...
    'rowGap', 0, 'colGap', 0, 'rowGaps', [], 'colGaps', []);
A = figureArrange(sz, g1, one, Top=top, Legend=leg, Margin=6, Scale=scale);
area = A.panels(1).box;
end


function tb = tileBox(area, b)
%tileBox  A tile's box in px: its normalized box B over the drawing area AREA.
tb = [area(1) + b(1) * area(3), area(2) + b(2) * area(4), b(3) * area(3), b(4) * area(4)];
end


function drawProbe(pax, L, o, style)
%drawProbe  The probe behind the tiles: the shanks' bodies, the sites, the shank labels, the depth ticks, the leaders.
fs = style.FontSize;
set(pax, 'XLim', [0 1], 'YLim', [0 1], 'Color', 'none', 'Box', 'off', 'XTick', [], 'YAxisLocation', 'right', ...
    'FontSize', max(6, fs - 2), 'TickDir', 'out', 'Layer', 'bottom');
pax.XAxis.Visible = 'off';
quiet = {'HitTest', 'off', 'PickableParts', 'none'};
C = L.cols;
nC = numel(C.center);
if o.showSites && nC > 0
    V = zeros(0, 2);
    Fc = zeros(0, 5);
    for c = 1:nC
        tip = min(0.02, max(0.005, 0.05 * (C.yHi(c) - C.yLo(c))));
        V = [V; C.bodyLo(c) C.yHi(c); C.bodyHi(c) C.yHi(c); C.bodyHi(c) C.yLo(c); C.center(c) C.yLo(c) - tip; ...
            C.bodyLo(c) C.yLo(c)]; %#ok<AGROW>
        Fc(end+1, :) = size(V, 1) - 4:size(V, 1); %#ok<AGROW>
    end
    tagPart(patch(pax, 'Faces', Fc, 'Vertices', V, 'FaceColor', [0.94 0.94 0.94], 'EdgeColor', [0.82 0.82 0.82], ...
        'LineWidth', 0.5, 'Clipping', 'off', quiet{:}), "probeBody");
    S = L.sites;
    ok = isfinite(S.x) & isfinite(S.y);
    shades = {"excluded", ok & ~S.included, [0.82 0.82 0.82]; "included", ok & S.included, [0.55 0.55 0.55]};
    for j = 1:2
        on = shades{j, 2};
        if ~any(on); continue; end
        tagPart(line(pax, S.x(on), S.y(on), 'LineStyle', 'none', 'Marker', '.', 'MarkerSize', 6, 'Color', shades{j, 3}, ...
            'Clipping', 'off', quiet{:}), "probeSites", shades{j, 1});
    end
    sl = gobjects(1, nC);
    for c = 1:nC
        sl(c) = text(pax, C.center(c), 1, "Shank " + C.shank(c), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
            'FontSize', max(6, fs - 1), 'Interpreter', 'none', 'Clipping', 'off', quiet{:});
    end
    tagPart(sl, "shankLabels");
end
if ~isempty(L.depthTicks.y)
    pax.YTick = L.depthTicks.y;
    pax.YTickLabel = cellstr(L.depthTicks.label);
    ylabel(pax, "Probe y (µm)", 'Interpreter', 'none', 'FontSize', fs);
else
    pax.YTick = [];
end
if string(o.layout) == "physical" && o.leaders && any(L.moved)
    X = zeros(1, 0);
    Y = zeros(1, 0);
    for i = reshape(find(L.moved), 1, [])
        b = L.box(i, :);
        a = L.anchor(i, :);
        e = [min(max(a(1), b(1)), b(1) + b(3)), min(max(a(2), b(2)), b(2) + b(4))];   % the box's point nearest the site
        X = [X e(1) a(1) NaN]; %#ok<AGROW>
        Y = [Y e(2) a(2) NaN]; %#ok<AGROW>
    end
    tagPart(line(pax, X, Y, 'Color', [0.55 0.55 0.55], 'LineWidth', 0.5, 'Clipping', 'off', quiet{:}), "tileLeaders");
end
if L.n == 0 || ~any(all(isfinite(L.box), 2))
    tagPart(text(pax, 0.5, 0.5, "No unit or channel with a probe position", 'HorizontalAlignment', 'center', ...
        'FontSize', fs, 'Color', [0.45 0.45 0.45], 'Interpreter', 'none', quiet{:}), "note");
end
end


function stripAxes(A)
%stripAxes  A tile's axes without ticks, tick labels, axis labels or color bar (the scale tile tells them).
for a = reshape(A, 1, [])
    if ~isgraphics(a); continue; end
    a.XTick = [];
    a.XTickLabel = {};
    a.XLabel.String = '';
    for r = reshape(a.YAxis, 1, [])
        r.TickValues = [];
        r.TickLabels = {};
        r.Label.String = '';
    end
    cb = a.Colorbar;
    if ~isempty(cb) && isvalid(cb); delete(cb); end
end
end


function clearTitle(A)
%clearTitle  No panel title on a tile's axes (the page's title and the tile's label tell what it is).
for a = reshape(A, 1, [])
    if ~isgraphics(a); continue; end
    if ~isempty(a.Title.String); a.Title.String = ''; end
    if ~isempty(a.Subtitle.String); a.Subtitle.String = ''; end
end
end


function labelTile(ax, lab, style)
%labelTile  The tile's label at the top left of its top-left panel's axes (one text per tile, role "tileLabels").
tagPart(text(ax, 0.03, 0.97, lab, 'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
    'FontSize', max(6, style.FontSize - 2), 'Interpreter', 'none', 'Clipping', 'off', 'Color', [0.2 0.2 0.2], ...
    'HitTest', 'off', 'PickableParts', 'none'), "tileLabels");
end


function lab = tileLabel(t, mode)
%tileLabel  A tile's label: "short" the observation label's first part, "full" all of it, "none" "".
lab = "";
if mode == "none" || ~isfield(t, 'observation') || ~isstruct(t.observation) || ~isfield(t.observation, 'label'); return; end
lab = string(t.observation.label);
if mode == "short"
    parts = split(strtrim(lab), "  ");
    lab = parts(1);
end
end


function tf = sharesY(p)
%sharesY  A panel whose y is a value axis the tiles can share (sharedY): not a map, a raster, an event trace or waveforms, nor a fixed range.
o = p.options;
t = string(p.type);
tf = ~ismember(t, ["raster" "heatmap" "eventTrace" "waveforms" "probemap" "corrmap" "spectrogram"]) ...
    && ~(t == "psth" && isfield(o, 'display') && string(o.display) == "heatmap") ...
    && ~(t == "coherence" && isfield(o, 'overTime') && isequal(o.overTime, true)) ...
    && ~(isfield(o, 'yLimMode') && string(o.yLimMode) == "fixed");
end


function s = leftLine(PF, o)
%leftLine  "<k> of <n> drawn; left out: ..." when figureProbeTiles left any observation out ("" otherwise).
s = "";
if ~isfield(PF, 'left') || ~isstruct(PF.left); return; end
c = PF.left;
get1 = @(f) countOf(c, f);
parts = strings(1, 0);
if get1('noPosition') > 0; parts(end+1) = get1('noPosition') + " without a position"; end
if get1('filtered') > 0; parts(end+1) = get1('filtered') + " outside the shanks, channels or depth range"; end
if get1('overSite') > 0; parts(end+1) = get1('overSite') + " over " + o.maxPerSite + " per site"; end
if get1('overMax') > 0; parts(end+1) = get1('overMax') + " over the " + o.maxTiles + " tiles"; end
if isempty(parts); return; end
s = sprintf("%d of %d drawn; left out: %s", get1('kept'), get1('total'), strjoin(parts, ", "));
end


function v = countOf(c, f)
%countOf  Count F of PF.left, 0 when it has none.
v = 0;
if isfield(c, f) && isnumeric(c.(f)) && isscalar(c.(f)) && isfinite(c.(f)); v = double(c.(f)); end
end
