function hk = drawTrialDistPanel(ax, P, look)
%drawTrialDistPanel  Draw a figure's trial distribution panel: one value per trial by category, as a swarm, boxes, violins, points or a line per series, with its group tests.
%   HK = drawTrialDistPanel(AX, P, LOOK) draws the panel result P
%   (F.panels(k): computeTrialPanel's layers, each with R.values, and the
%   categories, series and stats trialPanelStats gave them all) into the
%   axes AX, as renderFigure asks (LOOK: style, colors, panel, panelId,
%   spec, groups, ...). Every computed layer's values are drawn together
%   (trialDrawData), category c at x = c (options.ordinalX with display
%   "line" or "points": at its value, when every category has a finite
%   one), the series side by side in its slot (each 0.8 / nSeries wide,
%   as a firing rate panel's items), each in its color (trialDrawData: the
%   trial groups', a layer's own, a parameter's or session's palette).
%   options.display:
%     swarm    swarmchart, the points spread by their density
%              (XJitter "density"), role "distPoints"
%     points   the points jittered across options.jitter of the slot (a
%              fixed pattern, so a drawing is the same every time), role
%              "distPoints"
%     box      boxchart, role "distBox"
%     violin   violinplot with DensityWidth of the slot, role
%              "distViolin" (a series of fewer than 2 distinct values: its
%              points, "distPoints"); without violinplot (before R2024b)
%              boxes, and a note says so
%     line     the summary per category with its error bars, a line per
%              series (errorbar "o-", the layer's line style), role
%              "distLine"
%   With options.showSummary (swarm, points, violin) each slot's summary
%   (options.summary: mean or median; trialStats' center) is a mark with
%   its error (options.errorType) over the values, role "distSummary".
%   Points carry appdata TrialRows, [layer row] per point (the layer's
%   index in P.layers and the row of its R.values), which their data tips
%   read. x: the categories' labels (with options.showN "ticks" each
%   one's trial count, "Hit (n = 12)"), turned 45 degrees past 8; the
%   x label the grouping (the groupBy parameters, the category parameter,
%   "Session"). y: the measure's label (HK.yName), options.yLimMode /
%   yLim (panelYLimits), options.yScale "log" (values <= 0 left out and
%   counted in a note). options.testShow: "brackets" draws the pairs
%   (options.bracketPairs "significant": those under testAlpha after
%   adjustment, "all": every pair with a p) as brackets with stars over
%   the data (drawSigBrackets: a category pair in its series' slot, a
%   series pair within the one category) and the omnibus tests in the top
%   left corner (statText); "text" the tests alone; "off" neither. The y
%   axis grows to hold them unless its limits are fixed. The legend
%   offers the series when there are several (legendGroup when they are
%   the figure's trial groups). HK.yExtent: the values', error bars' and
%   brackets' reach. Skipped layers are noted (figLayerNotes).
%
%   See also renderFigure, figurePanelRegistry, computeTrialDistPanel, trialDrawData, drawSigBrackets, statText.

style = look.style;
o = look.panel.options;
hk = figDrawResult(ax);
tagPart(ax, "axes", "", look.panelId);
D = trialDrawData(P, look);
if ~D.ok || D.nC == 0 || D.nS == 0
    figLayerNotes(ax, P, look, false);
    return
end
V = D.V;
nC = D.nC;
nS = D.nS;
shape = optText(o, 'display', "swarm");
yLog = optText(o, 'yScale', "linear") == "log";
ms = optNum(o, 'markerSize', 4);
jitter = min(max(optNum(o, 'jitter', 0.3), 0), 1);
xc = (1:nC).';
if logical(optNum(o, 'ordinalX', 0)) && ismember(shape, ["line" "points"]) && all(isfinite(D.C.value)) ...
        && numel(unique(D.C.value)) == nC
    xc = double(D.C.value(:));
end
du = diff(unique(xc));
slot = 1;
if ~isempty(du); slot = min(du); end
w = 0.8 * slot / nS;
offs = ((1:nS) - (nS + 1) / 2) * w;
y = double(V.value);
ok = isfinite(y) & V.category >= 1 & V.series >= 1;
nOut = 0;
if yLog
    nOut = nnz(ok & y <= 0);
    ok = ok & y > 0;
end
haveViolin = exist('violinplot', 'file') == 2;   % R2024b and later
T = D.stats.table;
hold(ax, 'on');
first = gobjects(1, nS);
ext = [Inf -Inf];
for s = 1:nS
    c = D.colors(s, :);
    sl = string(D.S.label(s));
    if shape == "line"   % the summary per category, a line per series
        [m, lo, hi] = summaryOf(T, 1:nC, s);
        if yLog; lo(lo <= 0) = NaN; end
        x = xc + offs(s) / 2;
        h = tagPart(errorbar(ax, x, m, m - lo, hi - m, 'o-', 'Color', c, 'MarkerFaceColor', c, 'MarkerSize', ms + 1, ...
            'LineStyle', char(D.lineStyles(s)), 'LineWidth', style.LineWidth, 'CapSize', 4), "distLine", sl);
        first(s) = h;
        ext = [min([ext(1); m; lo]) max([ext(2); m; hi])];
        continue
    end
    for k = 1:nC
        in = ok & V.series == s & V.category == k;
        v = y(in);
        if isempty(v); continue; end
        rows = [V.lay(in) V.row(in)];
        x = xc(k) + offs(s);
        n = numel(v);
        h = gobjects(0);
        switch shape
            case "box"
                h = tagPart(boxchart(ax, repmat(x, n, 1), v, 'BoxWidth', w * 0.8, 'BoxFaceColor', c, 'MarkerColor', c, ...
                    'MarkerStyle', '.'), "distBox", sl);
            case "violin"
                if ~haveViolin
                    h = tagPart(boxchart(ax, repmat(x, n, 1), v, 'BoxWidth', w * 0.8, 'BoxFaceColor', c, 'MarkerColor', c, ...
                        'MarkerStyle', '.'), "distBox", sl);
                elseif numel(unique(v)) >= 2
                    h = tagPart(violinplot(ax, repmat(x, n, 1), v, 'DensityWidth', w * 0.9, 'FaceColor', c, 'EdgeColor', c), ...
                        "distViolin", sl);
                else   % no spread to draw a density of: the points
                    h = pointsAt(ax, x, v, 0, ms, c, sl, rows);
                end
            case "points"
                h = pointsAt(ax, x, v, w * jitter, ms, c, sl, rows);
            otherwise   % swarm
                h = tagPart(swarmchart(ax, repmat(x, n, 1), v, ms ^ 2, c, 'filled', 'XJitter', 'density', ...
                    'XJitterWidth', w * 0.8), "distPoints", sl);
                setappdata(h, 'TrialRows', rows);
        end
        if ~isgraphics(first(s)); first(s) = h; end
        ext = [min(ext(1), min(v)) max(ext(2), max(v))];
        if isa(h, 'matlab.graphics.chart.primitive.ViolinPlot')   % its density reaches past the values: the brackets go over it
            e = double(h.EvaluationPoints(:));
            if yLog; e = e(e > 0); end
            if ~isempty(e); ext = [min(ext(1), min(e)) max(ext(2), max(e))]; end
        end
        if logical(optNum(o, 'showSummary', 1)) && shape ~= "box"   % the summary mark over the values
            [m, lo, hi] = summaryOf(T, k, s);
            if isfinite(m)
                if yLog && ~(lo > 0); lo = NaN; end
                tagPart(errorbar(ax, x, m, m - lo, hi - m, 'o', 'Color', c * 0.45, 'MarkerFaceColor', paleColor(c, 1, style), ...
                    'MarkerSize', ms + 2, 'LineWidth', 1.2, 'CapSize', 0, 'HandleVisibility', 'off'), "distSummary", sl);
                ext = [min([ext(1) m lo]) max([ext(2) m hi])];
            end
        end
    end
end
hold(ax, 'off');
if ~all(isfinite(ext)); ext = [0 1]; if yLog; ext = [1 10]; end; end

% the categories along x
[xs, xo] = sort(xc);
labels = string(D.C.label(xo));
if optText(o, 'showN', "off") == "ticks"
    for i = 1:nC
        k = xo(i);
        labels(i) = labels(i) + " (n = " + numel(unique(V.trial(V.category == k & isfinite(V.trial)))) + ")";
    end
end
set(ax, 'XTick', xs, 'XTickLabel', labels, 'TickLabelInterpreter', 'none');
if nC > 8; ax.XTickLabelRotation = 45; end
xlim(ax, [xs(1) - 0.6 * slot, xs(end) + 0.6 * slot]);
flat = style;
flat.XLim = [];
[ymode, yl] = panelYLimits(look);
flat.YLim = yl;
styleAxes(ax, flat);
if yLog; ax.YScale = 'log'; end
name = categoryName(o, D);
if name ~= ""; xlabel(ax, name, 'Interpreter', 'none'); end

% the tests: brackets over the data and the omnibus p in the corner
show = optText(o, 'testShow', "brackets");
yTop = ext(2);
nLines = 0;
hold(ax, 'on');
if show == "brackets"
    [B, xOf, bc] = bracketPairs(D, o, xc, offs);
    if yLog
        r = max(1.08, (ext(2) / max(ext(1), eps)) ^ 0.08);
        yBase = ext(2) * r ^ 0.6;
        stepY = r;
    else
        stepY = 0.08 * max([ext(2) - ext(1), 0.1 * abs(ext(2)), eps]);
        yBase = ext(2) + 0.6 * stepY;
    end
    [~, yTop] = drawSigBrackets(ax, B, xOf, yBase, stepY, style, bc, Log=yLog, Adjust=adjustOf(D));
end
if ismember(show, ["brackets" "text"])
    t = statText(ax, D.stats, style, D.colors, string(D.S.label));
    if ~isempty(t); nLines = numel(t.String); end
end
hold(ax, 'off');
if isempty(yl)   % automatic limits: room for the brackets and the corner's text
    lim = ylim(ax);
    top = max(lim(2), yTop);
    if nLines > 0
        if yLog
            top = top * (top / max(lim(1), eps)) ^ (0.08 * nLines);
        else
            top = top + 0.08 * nLines * (top - lim(1));
        end
    end
    if top > lim(2); ylim(ax, [lim(1) top]); end
end
hk.yExtent = [ext(1) max(ext(2), yTop)];

% the legend: the series, when there are several
if nS > 1
    for s = find(isgraphics(first))
        hk.legendHandles(end+1) = first(s);
        hk.legendLabels(end+1) = string(D.S.label(s));
        hk.legendGroup(end+1) = D.legendGroup;
    end
end
notes = strings(1, 0);
if nOut > 0; notes(end+1) = sprintf("%d value%s <= 0 not drawn (log axis)", nOut, plural(nOut)); end
if shape == "violin" && ~haveViolin; notes(end+1) = "violins need MATLAB R2024b or later: drawn as boxes"; end
trialNote(ax, notes, style);
figLayerNotes(ax, P, look, true);
hk.yName = D.yName;
if ymode == "fixed" || ymode == "batch"; hk.yExtent = [ext(1) ext(2)]; end
end


function h = pointsAt(ax, x, v, width, ms, c, group, rows)
%pointsAt  The values at X, jittered over WIDTH (a fixed pattern: the golden ratio's), role "distPoints", with their TrialRows.
n = numel(v);
jit = (mod((1:n).' * 0.6180339887, 1) - 0.5) * width;
h = tagPart(plot(ax, x + jit, v(:), 'o', 'LineStyle', 'none', 'Color', c, 'MarkerFaceColor', c, 'MarkerEdgeColor', 'none', ...
    'MarkerSize', ms), "distPoints", group);
setappdata(h, 'TrialRows', rows);
end


function [m, lo, hi] = summaryOf(T, cats, s)
%summaryOf  The summary (center) and its error's edges of the categories CATS in series S, from trialStats' table.
m = NaN(numel(cats), 1);
lo = m;
hi = m;
for i = 1:numel(cats)
    r = find(T.category == cats(i) & T.series == s, 1);
    if isempty(r); continue; end
    m(i) = T.center(r);
    lo(i) = T.lo(r);
    hi(i) = T.hi(r);
end
end


function [B, xOf, colors] = bracketPairs(D, o, xc, offs)
%bracketPairs  The pairs to bracket (bracketPairs "significant": under testAlpha after adjustment; "all": every pair with a p), their x ends and colors.
P = D.stats.pairs;
if isempty(P) || height(P) == 0
    B = table(strings(0, 1), strings(0, 1), strings(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
        'VariableNames', {'label', 'stars', 'test', 'p', 'pAdj', 'n1', 'n2'});
    xOf = zeros(0, 2);
    colors = zeros(0, 3);
    return
end
if optText(o, 'bracketPairs', "significant") == "all"
    keep = isfinite(P.p);
else
    keep = logical(P.sig) & isfinite(P.pAdj);
end
P = P(keep, :);
n = height(P);
xOf = zeros(n, 2);
labels = strings(n, 1);
colors = repmat([0.25 0.25 0.25], n, 1);
cl = string(D.C.label);
sl = string(D.S.label);
for i = 1:n
    a = P.a(i);
    b = P.b(i);
    if P.per(i) >= 1   % two categories of one series
        s = P.per(i);
        xOf(i, :) = [xc(a) xc(b)] + offs(s);
        labels(i) = cl(a) + " vs " + cl(b);
        if D.nS > 1
            labels(i) = labels(i) + " · " + sl(s);
            colors(i, :) = D.colors(s, :);
        end
    else   % two series within the one category
        xOf(i, :) = xc(1) + offs([a b]);
        labels(i) = sl(a) + " vs " + sl(b);
    end
end
B = table(labels, string(P.stars), string(P.test), P.p, P.pAdj, P.n1, P.n2, ...
    'VariableNames', {'label', 'stars', 'test', 'p', 'pAdj', 'n1', 'n2'});
end


function a = adjustOf(D)
%adjustOf  The adjustment the pairs' p values took (trialStats' options).
a = "holm";
if isfield(D.stats, 'options') && isfield(D.stats.options, 'Adjust'); a = string(D.stats.options.Adjust); end
end


function name = categoryName(o, D)
%categoryName  The x axis' name: what the categories are.
name = "";
switch optText(o, 'categories', "groups")
    case "groups"
        g = strings(1, 0);
        if isfield(D.R, 'params') && isfield(D.R.params, 'selection') && isstruct(D.R.params.selection) ...
                && isfield(D.R.params.selection, 'groupBy')
            g = string(D.R.params.selection.groupBy);
        end
        if ~isempty(g); name = strjoin(g, ", "); end
    case "param"
        name = optText(o, 'categoryParam', "");
    case "session"
        name = "Session";
end
end


function v = optText(o, name, default)
v = default;
if isfield(o, name) && ~isempty(o.(name)); v = string(o.(name)); end
end


function v = optNum(o, name, default)
v = default;
if isfield(o, name) && ~isempty(o.(name)) && (isnumeric(o.(name)) || islogical(o.(name))); v = double(o.(name)); end
end


function s = plural(n)
s = "";
if n ~= 1; s = "s"; end
end
