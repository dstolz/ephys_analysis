function hk = drawTrialScatterPanel(ax, P, look)
%drawTrialScatterPanel  Draw a figure's trial scatter panel: one point per trial, its y measure against its x measure, per series, with fits and marginal histograms.
%   HK = drawTrialScatterPanel(AX, P, LOOK) draws the panel result P
%   (F.panels(k): computeTrialPanel's layers, each value paired with its
%   trial's x, and the series and stats trialPanelStats gave them) into
%   the axes AX, as renderFigure asks. Every computed layer's values are
%   drawn together (trialDrawData), a point per value (filled, options.
%   markerSize points across, options.alpha opaque), each series in its
%   color, role "scatterPoints"; the points carry appdata TrialRows
%   ([layer row] per point, as a distribution's) for their data tips. A
%   series with a fit (options.fit, trialStats' S.fit: made in the scale
%   drawn) draws its curve, role "fitLine", over its 95% band (options.
%   fitBand, a polynomial fit's), role "fitBand", drawn behind the points.
%   options.xScale / yScale "log" draw log axes (values <= 0 left out and
%   counted in a note); options.xLim, yLimMode / yLim (panelYLimits) the
%   limits. The legend offers the series when there are several, or when a
%   correlation is given (options.corr): "Hit (r = 0.42, p = 0.01)", rho
%   for Spearman's. options.testShow "text" writes the test of y across
%   the series in the top left corner (statText). x: the x measure's label,
%   y: the y measure's (HK.yName).
%   Marginals (options.marginals, in a panel of renderFigure's layout:
%   its axes carry appdata FigurePanel, and not in a probe figure's tile):
%   the panel's box becomes three axes, the main plot and two strips, a
%   share options.marginalSize (0.1-0.5) of the box wide: the x strip
%   above it (below when the panel's x axis is on top, xSide), its x
%   limits linked to the plot's, and the y strip right of it (left when
%   the y axis is on the right, ySide), its y limits linked; each holds a
%   histogram per series of x or of y (probability, on one set of edges;
%   trialBins), role "marginalBar", and shows no tick labels. The strips
%   are tagged "axes" with the panel's id, so the aesthetics editor lists
%   them as tiles of the panel. HK.extraAxes = [x strip, y strip] and
%   HK.extraLayout = struct('kind', "marginals", 'size', the share,
%   'xStrip', "top" | "bottom", 'yStrip', "right" | "left"), which
%   renderFigure passes on to figureLayout (figurePlace splits the box so
%   again at every layout). Drawn into a single axes there are none.
%
%   See also renderFigure, figurePanelRegistry, computeTrialScatterPanel, trialDrawData, trialStats, figurePlace.

style = look.style;
o = look.panel.options;
p = look.panel;
hk = figDrawResult(ax);
D = trialDrawData(P, look);
withM = D.ok && D.nS > 0 && logical(optNum(o, 'marginals', 0)) && isappdata(ax, 'FigurePanel') && ~isappdata(ax, 'ProbeTile');
f = min(max(optNum(o, 'marginalSize', 0.25), 0.1), 0.5);
xStrip = "top";
if isfield(p, 'xSide') && string(p.xSide) == "top"; xStrip = "bottom"; end   % out of the way of the x axis
yStrip = "right";
if isfield(p, 'ySide') && string(p.ySide) == "right"; yStrip = "left"; end
mx = gobjects(0);
my = gobjects(0);
if withM; [ax, mx, my] = splitMarginals(ax, f, xStrip, yStrip); end
tagPart(ax, "axes", "", look.panelId);
hk.axes = ax;
if ~D.ok || D.nS == 0
    figLayerNotes(ax, P, look, false);
    return
end
V = D.V;
nS = D.nS;
xLog = optText(o, 'xScale', "linear") == "log";
yLog = optText(o, 'yScale', "linear") == "log";
ms = optNum(o, 'markerSize', 5);
opacity = min(max(optNum(o, 'alpha', 0.7), 0), 1);
x = double(V.x);
y = double(V.value);
ok = isfinite(x) & isfinite(y) & V.series >= 1 & V.category >= 1;
bad = false(size(ok));
if xLog; bad = bad | x <= 0; end
if yLog; bad = bad | y <= 0; end
nOut = nnz(ok & bad);
ok = ok & ~bad;
Fs = D.stats.fit;
Cs = D.stats.corr;
hasFit = @(s) s <= numel(Fs) && ~isempty(Fs(s).kind) && Fs(s).kind ~= "none" && numel(Fs(s).xg) >= 2;
hold(ax, 'on');
if logical(optNum(o, 'fitBand', 1))   % the bands first, behind everything
    for s = 1:nS
        if ~hasFit(s) || ~ismember(Fs(s).kind, ["linear" "poly2" "poly3"]); continue; end
        F = Fs(s);
        xg = F.xg(:); lo = F.lo(:); hi = F.hi(:);
        in = isfinite(xg) & isfinite(lo) & isfinite(hi);
        if yLog; in = in & lo > 0; end
        if nnz(in) < 2; continue; end
        tagPart(patch(ax, [xg(in); flipud(xg(in))], [lo(in); flipud(hi(in))], D.colors(s, :), 'FaceAlpha', 0.2, ...
            'EdgeColor', 'none', 'HandleVisibility', 'off'), "fitBand", string(D.S.label(s)));
    end
end
pts = gobjects(1, nS);
for s = 1:nS
    in = ok & V.series == s;
    if ~any(in); continue; end
    sl = string(D.S.label(s));
    pts(s) = tagPart(scatter(ax, x(in), y(in), ms ^ 2, D.colors(s, :), 'filled', 'MarkerFaceAlpha', opacity, ...
        'MarkerEdgeColor', 'none'), "scatterPoints", sl);
    setappdata(pts(s), 'TrialRows', [V.lay(in) V.row(in)]);
end
for s = 1:nS
    if ~hasFit(s); continue; end
    F = Fs(s);
    tagPart(plot(ax, F.xg(:), F.yg(:), '-', 'Color', D.colors(s, :) * 0.8, 'LineWidth', style.LineWidth + 0.5, ...
        'LineStyle', char(D.lineStyles(s)), 'HandleVisibility', 'off'), "fitLine", string(D.S.label(s)));
end
hold(ax, 'off');
flat = style;
flat.XLim = [];
[ymode, yl] = panelYLimits(look);
flat.YLim = yl;
styleAxes(ax, flat);
if xLog; ax.XScale = 'log'; end
if yLog; ax.YScale = 'log'; end
if isfield(o, 'xLim') && isnumeric(o.xLim) && numel(o.xLim) == 2 && all(isfinite(o.xLim)) && o.xLim(2) > o.xLim(1) ...
        && (~xLog || o.xLim(1) > 0)
    xlim(ax, reshape(double(o.xLim), 1, 2));
end
if D.xName ~= ""; xlabel(ax, D.xName, 'Interpreter', 'none'); end
hk.yName = D.yName;
if optText(o, 'testShow', "text") == "text"
    statText(ax, D.stats, style, D.colors, string(D.S.label));
end

% the legend: the series (with their correlations)
labels = string(D.S.label).';
withR = false(1, nS);
for s = 1:nS
    if s > numel(Cs) || isempty(Cs(s).type) || ~isfinite(Cs(s).r); continue; end
    sym = "r";
    if Cs(s).type == "spearman"; sym = string(char(961)); end   % rho
    labels(s) = labels(s) + " (" + sym + " = " + sprintf('%.2f', Cs(s).r) + ", " + pText(Cs(s).p) + ")";
    withR(s) = true;
end
if nS > 1 || any(withR)
    for s = find(isgraphics(pts))
        hk.legendHandles(end+1) = pts(s);
        hk.legendLabels(end+1) = labels(s);
        hk.legendGroup(end+1) = D.legendGroup && ~withR(s);
    end
end
yv = y(ok);
if ~isempty(yv); hk.yExtent = [min(yv) max(yv)]; end
if ymode == "fixed" || ymode == "batch"; hk.yExtent = [NaN NaN]; end

if withM   % the marginal histograms, on the plot's limits
    st = style;
    st.XLim = [];
    st.YLim = [];
    ex = trialBinEdges(x(ok), Log=xLog, Limits=xlim(ax));
    ey = trialBinEdges(y(ok), Log=yLog, Limits=ylim(ax));
    hold(mx, 'on');
    hold(my, 'on');
    cx = 0;
    cy = 0;
    for s = 1:nS
        in = ok & V.series == s;
        if ~any(in); continue; end
        sl = string(D.S.label(s));
        hx = histcounts(x(in), ex, 'Normalization', 'probability');
        hy = histcounts(y(in), ey, 'Normalization', 'probability');
        trialBins(mx, ex, hx, D.colors(s, :), opacity, "marginalBar", sl, Log=xLog);
        trialBins(my, ey, hy, D.colors(s, :), opacity, "marginalBar", sl, Horizontal=true, Log=yLog);
        cx = max([cx hx]);
        cy = max([cy hy]);
    end
    hold(mx, 'off');
    hold(my, 'off');
    styleAxes(mx, st);
    styleAxes(my, st);
    mx.XScale = ax.XScale;
    my.YScale = ax.YScale;
    mx.XLim = ax.XLim;
    my.YLim = ax.YLim;
    ylim(mx, [0 max(cx, eps) * 1.05]);
    xlim(my, [0 max(cy, eps) * 1.05]);
    set([mx my], 'XTickLabel', {}, 'YTickLabel', {});
    mx.YTick = [];
    my.XTick = [];
    tagPart(mx, "axes", "", look.panelId);
    tagPart(my, "axes", "", look.panelId);
    setappdata(mx, 'MarginalLink', linkprop([ax mx], 'XLim'));   % the strips follow the plot's limits (kept: a link lives while held)
    setappdata(my, 'MarginalLink', linkprop([ax my], 'YLim'));
    hk.extraAxes = [mx my];
    hk.extraLayout = struct('kind', "marginals", 'size', f, 'xStrip', xStrip, 'yStrip', yStrip);
end
notes = strings(1, 0);
if nOut > 0; notes(end+1) = sprintf("%d point%s with a value <= 0 not drawn (log axis)", nOut, plural(nOut)); end
trialNote(ax, notes, style);
figLayerNotes(ax, P, look, true);
end


function [ax, mx, my] = splitMarginals(ax, f, xStrip, yStrip)
%splitMarginals  The panel's axes as three: the plot, the x strip over (or under) it and the y strip beside it, share F of the box.
%   (figurePlace splits the box the same way at every layout: hk.extraLayout.)
q = ax.Position;
sw = f * q(3);
sh = f * q(4);
mw = q(3) - sw;
mh = q(4) - sh;
x0 = q(1) + (yStrip == "left") * sw;
y0 = q(2) + (xStrip == "bottom") * sh;
xs = [x0, q(2), mw, sh];
if xStrip == "top"; xs(2) = y0 + mh; end
ys = [q(1), y0, sw, mh];
if yStrip == "right"; ys(1) = x0 + mw; end
mx = axes(ax.Parent, 'Units', ax.Units, 'Position', xs);
my = axes(ax.Parent, 'Units', ax.Units, 'Position', ys);
ax.Position = [x0 y0 mw mh];
end


function s = pText(p)
%pText  A p value as people read it: "p = 0.01", "p < 0.001".
if ~isfinite(p)
    s = "p = NaN";
elseif p < 0.001
    s = "p < 0.001";
else
    s = "p = " + string(sprintf('%.2g', p));
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
