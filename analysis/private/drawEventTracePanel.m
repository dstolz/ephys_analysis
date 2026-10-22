function hk = drawEventTracePanel(ax, P, look)
%drawEventTracePanel  Draw a figure's event-trace panel: a row per line, its intervals as bars or a logic level.
%   HK = drawEventTracePanel(AX, P, LOOK) draws the panel result P
%   (F.panels(k) of EphysAnalysisRunner.computeFigure: each layer's R of
%   kind "eventTrace", computeEventTracePanel) into the axes AX, as
%   renderFigure asks (LOOK: style, colors, W, spec, panel, panelId, epochs,
%   groups, ...), like a logic analyzer: each computed layer (one line) is a
%   row of its own, the first on top, every rowSpacing row heights, the y
%   axis naming the rows (the layer's name, else its line). Each interval
%   runs from its onset to its offset, clipped at the window's edges (LOOK.W,
%   and a "between" epoch's own end). The panel's options:
%     display    "bars": a solid bar from onset to offset, height times the
%                row high (tagged "eventBar"), its outline edgeColor
%                ("none" | "auto" = its fill | a color) and edgeWidth; a
%                bar narrower than minWidth points as drawn (the axes'
%                width over the window when it is drawn; a zero-length
%                interval too) also gets a vertical tick minWidth wide
%                through its middle, in its color and opacity (tagged
%                "eventTick"), so it shows at any size and in exports;
%                "line": a logic-level trace, low, up at each onset and down
%                at its offset (tagged "eventLevel": a patch edge, so its
%                opacity is EdgeAlpha, which SVG and PDF keep), in
%                lineWidth and lineStyle (a layer's own lineStyle wins)
%     trials     "overlay": every epoch in the line's row, at opacity alpha
%                (NaN: 0.3), so the spread of the timing shows; "rows": a
%                sub-row per epoch inside the row, in a raster's order
%                (figEpochOrder of the first layer's result: rasterByGroup,
%                rasterSort, rasterSortOrder; first on top; alpha NaN: 1),
%                each run of a group's sub-rows on a pale band of its color
%                while groupBands (tagged "eventGroupBand")
%     colorBy    "layer": the layer's color, else a palette color per line
%                (groupPalette: the plot design's palette); "group": each
%                epoch in its trial group's color (LOOK.colors), the
%                groups in the legend
%     showBaseline  a line along each row (each sub-row in "rows"): through the
%                bars' middle, or at the trace's low level, in
%                baselineColor ("" = gray), baselineStyle and baselineWidth
%                (tagged "eventBaseline")
%   The parts are tagged with the layer's name as their group ("eventBar",
%   "eventTick", "eventLevel" colored by group: the group's label). In a
%   session figure the groups are its series and the epochs every
%   session's (combineSessions' eventTrace result). The zero line
%   follows Style.ShowZeroLine. Skipped layers are noted (figLayerNotes).
%   HK: figDrawResult's; yName "" (the ticks name the rows).
%
%   See also renderFigure, computeEventTracePanel, figurePanelRegistry.

style = look.style;
o = look.panel.options;
Ls = look.panel.layers;
hk = figDrawResult(ax);
tagPart(ax, "axes", "", look.panelId);
idx = find(arrayfun(@(l) l.skip == "" && isstruct(l.R) && isfield(l.R, 'kind') && l.R.kind == "eventTrace", P.layers));
if isempty(idx)
    figLayerNotes(ax, P, look, false);
    return
end
R1 = P.layers(idx(1)).R;
nE = R1.nEpochs;
W = look.W;
if numel(W) ~= 2 || ~(W(2) > W(1))
    W = [min([R1.window(:, 1); 0]) max([R1.window(:, 2); 1])];
end

% the trial groups (a session figure's series): each epoch's, their colors and labels
gi = ones(nE, 1);
Ep = look.epochs;
if isfield(R1, 'epochGroup') && numel(R1.epochGroup) == nE
    gi = double(R1.epochGroup(:));
elseif istable(Ep) && height(Ep) == nE && ismember("groupIndex", string(Ep.Properties.VariableNames))
    gi = double(Ep.groupIndex(:));
end
G = look.groups;
nG = 1;
gLabels = "all";
colors = look.colors;
if istable(G) && height(G) >= 1
    nG = height(G);
    gLabels = string(G.label(:)).';
    if size(colors, 1) ~= nG; colors = groupPalette(G, style); end
end
if size(colors, 1) < nG; colors = lines(nG); end
gi(~(gi >= 1 & gi <= nG)) = 1;
rows = o.trials == "rows";
Rs = R1;   % the sub-rows: a raster's order, the first on top
Rs.epochGroup = gi;
ord = figEpochOrder(Rs, o);
slot = zeros(nE, 1);
slot(ord) = 1:nE;
alpha = o.alpha;
if isnan(alpha)
    alpha = 0.3;
    if rows || nE <= 1; alpha = 1; end
end

% the lines' rows and colors
nL = numel(idx);
names = strings(1, nL);
for r = 1:nL
    names(r) = P.layers(idx(r)).name;
    if names(r) == ""; names(r) = P.layers(idx(r)).R.line; end
end
pal = groupPalette(table((1:nL).', names(:), lines(nL), ones(nL, 1), 'VariableNames', {'index', 'label', 'color', 'n'}), style);
centers = (nL - (1:nL)) * o.rowSpacing;   % the first line on top
h = o.height;
baseColor = [0.5 0.5 0.5];
if o.baselineColor ~= ""; baseColor = colorOr(o.baselineColor, baseColor); end
held = ishold(ax);
hold(ax, 'on');

% rows: each run of a group's adjacent sub-rows on a pale band of its color (one run per group by group first)
if rows && o.groupBands && nG > 1 && nE > 0
    for g = 1:nG
        s = sort(slot(gi == g));
        if isempty(s); continue; end
        brk = [0; find(diff(s) > 1); numel(s)];
        r1 = s(brk(1:end-1) + 1);   % each run's top and bottom sub-row
        r2 = s(brk(2:end));
        y1 = reshape(centers + 0.5 - (r1 - 1) / nE, 1, []);   % [runs x lines], flattened
        y0 = reshape(centers + 0.5 - r2 / nE, 1, []);
        tagPart(patch(ax, 'XData', repmat(reshape(W([1 2 2 1]), 4, 1), 1, numel(y0)), 'YData', [y0; y0; y1; y1], ...
            'FaceColor', paleColor(colors(g, :), 0.82, style), 'EdgeColor', 'none', 'HandleVisibility', 'off'), ...
            "eventGroupBand", gLabels(g));
    end
end
tick = 0;   % display "bars": the widest bar (s) that gets a tick, minWidth points at the axes' width when drawn
if o.display == "bars" && o.minWidth > 0
    u = ax.Units;
    ax.Units = 'points';
    wPt = ax.InnerPosition(3);
    ax.Units = u;
    if wPt > 0; tick = o.minWidth * diff(W) / wPt; end
end

for r = 1:nL
    j = idx(r);
    R = P.layers(j).R;
    L = Ls(j);
    c0 = centers(r);
    lineColor = pal(r, :);
    if L.color ~= ""; lineColor = colorOr(L.color, lineColor); end
    ls = o.lineStyle;
    if L.lineStyle ~= ""; ls = L.lineStyle; end
    if rows   % each epoch's middle and the half height of its bar (level)
        ym = c0 + 0.5 - (slot - 0.5) / nE;
        half = h / (2 * max(1, nE));
    else
        ym = repmat(c0, nE, 1);
        half = h / 2;
    end
    lo = max(W(1), R.window(:, 1));   % each epoch's drawn span: the window, and a "between" epoch's own end
    hi = min(W(2), R.window(:, 2));
    ep = R.epoch(:);
    x0 = max(R.on(:), lo(ep));
    x1 = min(R.off(:), hi(ep));
    keep = x1 >= x0;

    if o.showBaseline
        yb = ym;
        if o.display == "line"; yb = ym - half; end
        if rows
            X = [lo hi NaN(nE, 1)].';
            Y = [yb yb NaN(nE, 1)].';
        else
            X = W(:);
            Y = [c0; c0] - (o.display == "line") * half;
        end
        tagPart(line(ax, X(:), Y(:), 'Color', baseColor, 'LineStyle', char(o.baselineStyle), 'LineWidth', o.baselineWidth, ...
            'HandleVisibility', 'off'), "eventBaseline", names(r));
    end

    if o.colorBy == "group"   % one part per trial group, in its color
        sets = 1:nG;
        setColors = colors(1:nG, :);
        setLabels = gLabels;
    else
        sets = 0;
        setColors = lineColor;
        setLabels = names(r);
    end
    for q = 1:numel(sets)
        inSet = true(nE, 1);
        if sets(q) > 0; inSet = gi == sets(q); end
        fc = setColors(q, :);
        if o.display == "bars"
            k = keep & inSet(ep);
            n = nnz(k);
            if n == 0; continue; end
            yb = ym(ep(k)) - half;
            yt = ym(ep(k)) + half;
            V = [reshape([x0(k) x1(k) x1(k) x0(k)].', [], 1), reshape([yb yb yt yt].', [], 1)];
            ec = edgeOf(o.edgeColor, fc);
            tagPart(patch(ax, 'Faces', reshape(1:4 * n, 4, n).', 'Vertices', V, 'FaceColor', fc, 'FaceAlpha', alpha, ...
                'EdgeColor', ec, 'LineWidth', o.edgeWidth, 'HandleVisibility', 'off'), "eventBar", setLabels(q));
            short = x1(k) - x0(k) < tick;   % narrower than minWidth: a tick through its middle as well
            if any(short)
                xm = (x0(k) + x1(k)) / 2;
                ns = nnz(short);
                X = [xm(short) xm(short) NaN(ns, 1)].';
                Y = [yb(short) yt(short) NaN(ns, 1)].';
                tagPart(strokes(ax, X(:), Y(:), fc, alpha, '-', o.minWidth), "eventTick", setLabels(q));
            end
        else
            Xc = cell(1, nE); Yc = cell(1, nE);
            for e = reshape(find(inSet & lo <= hi), 1, [])
                in = keep & ep == e;
                [xe, ye] = levelTrace(x0(in), x1(in), lo(e), hi(e), ym(e) - half, ym(e) + half);
                Xc{e} = [xe NaN];
                Yc{e} = [ye NaN];
            end
            X = [Xc{:}];
            if isempty(X); continue; end
            tagPart(strokes(ax, X(:), reshape([Yc{:}], [], 1), fc, alpha, ls, o.lineWidth), "eventLevel", setLabels(q));
        end
    end
end
if style.ShowZeroLine
    tagPart(xline(ax, 0, ':', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off'), "zeroLine");
end

% the legend: the trial groups, in their colors (or their bands' paler ones)
if nG > 1 && (o.colorBy == "group" || (rows && o.groupBands))
    for g = 1:nG
        if o.colorBy == "group"
            hl = tagPart(patch(ax, 'XData', NaN, 'YData', NaN, 'FaceColor', colors(g, :), 'EdgeColor', 'none'), "eventBar", gLabels(g));
        else
            hl = tagPart(patch(ax, 'XData', NaN, 'YData', NaN, 'FaceColor', paleColor(colors(g, :), 0.82, style), ...
                'EdgeColor', 'none'), "eventGroupBand", gLabels(g));
        end
        hk.legendHandles(end+1) = hl;
        hk.legendLabels(end+1) = gLabels(g);
        hk.legendGroup(end+1) = true;
    end
end
if ~held; hold(ax, 'off'); end
flat = style;
flat.XLim = [];
flat.YLim = [];
styleAxes(ax, flat);
xlim(ax, W);
ylim(ax, [-0.5 centers(1) + 0.5] + [-0.08 0.08]);
set(ax, 'YDir', 'normal', 'YTick', fliplr(centers), 'YTickLabel', cellstr(fliplr(names)), 'TickLabelInterpreter', 'none');
figLayerNotes(ax, P, look, true);
end


function [X, Y] = levelTrace(x0, x1, a, b, low, high)
%levelTrace  One epoch's logic level over [A, B]: low, up at each onset X0 and down at its offset X1 (both clipped to [A, B]).
X = a;
up = ~isempty(x0) && x0(1) <= a;   % an interval already running at the window's start
Y = low + (high - low) * up;
for i = 1:numel(x0)
    if x0(i) > a
        X = [X x0(i) x0(i)]; %#ok<AGROW>
        Y = [Y low high]; %#ok<AGROW>
    end
    up = x1(i) >= b;
    if ~up
        X = [X x1(i) x1(i)]; %#ok<AGROW>
        Y = [Y high low]; %#ok<AGROW>
    end
end
X(end+1) = b;
Y(end+1) = low + (high - low) * up;
end


function h = strokes(ax, X, Y, color, alpha, style, width)
%strokes  NaN-separated line segments drawn as a patch's edges, so their opacity ALPHA is EdgeAlpha (SVG and PDF keep it).
%   X and Y end with NaN, so the face does not close back to its start; it
%   is not filled (FaceColor "none").
h = patch(ax, 'XData', X, 'YData', Y, 'FaceColor', 'none', 'EdgeColor', color, 'EdgeAlpha', alpha, ...
    'LineStyle', char(style), 'LineWidth', width, 'HandleVisibility', 'off');
end


function c = colorOr(name, fallback)
%colorOr  The color NAME (a name or #rrggbb), else FALLBACK.
try
    c = namedColor(name);
catch
    c = fallback;
end
end


function ec = edgeOf(edge, face)
%edgeOf  A bar's outline: "none", "auto" (its fill) or a color.
switch lower(strtrim(string(edge)))
    case {"" "none"}
        ec = 'none';
    case "auto"
        ec = face;
    otherwise
        ec = colorOr(edge, 'none');
end
end
