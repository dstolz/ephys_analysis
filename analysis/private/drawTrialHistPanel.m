function hk = drawTrialHistPanel(ax, P, look)
%drawTrialHistPanel  Draw a figure's trial histogram panel: the distribution of one value per trial, per series, as bars, an outline or the cumulative distribution.
%   HK = drawTrialHistPanel(AX, P, LOOK) draws the panel result P
%   (F.panels(k): computeTrialPanel's layers, the series and stats
%   trialPanelStats gave them) into the axes AX, as renderFigure asks.
%   Every computed layer's values are drawn together (trialDrawData), a
%   histogram per series in its color, on one set of bin edges for all
%   (trialBinEdges: options.binMode "auto", histcounts' rule; "count",
%   options.binCount bins; "width", options.binWidth in the measure's
%   unit; options.xScale "log": log-spaced, the values <= 0 left out and
%   counted in a note; options.xLim: the bins cover it). options.display:
%     bars     the counts (options.normalization "count", "probability"
%              or "pdf") as bars of the bins' width at options.alpha
%              (trialBins: bar, rectangles on a log axis), role "histBar"
%     outline  the same as a stair line closed to 0, role "histLine"
%     ecdf     the empirical cumulative distribution (ecdf, stairs), role
%              "histLine", y 0 to 1
%   With options.showSummary a dotted vertical line at each series'
%   summary (options.summary: mean or median), role "histSummary".
%   options.testShow "text" writes the test across the series in a corner
%   (statText: the top right over bars, the top left over an ECDF). x: the
%   measure's label (several layers' alike, else "Value (<unit>)"); y:
%   "Count", "Probability", "Density (1/<unit>)" or "Cumulative
%   probability" (HK.yName). The legend offers the series when there are
%   several. Skipped layers are noted (figLayerNotes).
%
%   See also renderFigure, figurePanelRegistry, computeTrialHistPanel, trialDrawData, trialBinEdges, trialBins.

style = look.style;
o = look.panel.options;
hk = figDrawResult(ax);
tagPart(ax, "axes", "", look.panelId);
D = trialDrawData(P, look);
if ~D.ok || D.nS == 0
    figLayerNotes(ax, P, look, false);
    return
end
V = D.V;
nS = D.nS;
shape = optText(o, 'display', "bars");
nrm = optText(o, 'normalization', "count");
xLog = optText(o, 'xScale', "linear") == "log";
opacity = min(max(optNum(o, 'alpha', 0.5), 0), 1);
xl = [];
if isfield(o, 'xLim') && isnumeric(o.xLim) && numel(o.xLim) == 2 && all(isfinite(o.xLim)) && o.xLim(2) > o.xLim(1)
    xl = reshape(double(o.xLim), 1, 2);
end
v = double(V.value);
ok = isfinite(v) & V.series >= 1 & V.category >= 1;
nOut = 0;
if xLog
    nOut = nnz(ok & v <= 0);
    ok = ok & v > 0;
end
edges = trialBinEdges(v(ok), Mode=optText(o, 'binMode', "auto"), Count=optNum(o, 'binCount', 20), ...
    Width=optNum(o, 'binWidth', 10), Log=xLog, Limits=xl);
T = D.stats.table;
hold(ax, 'on');
first = gobjects(1, nS);
top = 0;
for s = 1:nS
    vs = v(ok & V.series == s);
    if isempty(vs); continue; end
    c = D.colors(s, :);
    sl = string(D.S.label(s));
    ls = char(D.lineStyles(s));
    switch shape
        case "ecdf"
            [Fv, xv] = ecdf(vs);
            h = tagPart(stairs(ax, xv, Fv, 'Color', c, 'LineWidth', style.LineWidth, 'LineStyle', ls), "histLine", sl);
            top = 1;
        case "outline"
            cnt = histcounts(vs, edges, 'Normalization', nrm);
            h = tagPart(stairs(ax, [edges(1) edges], [0 cnt 0], 'Color', c, 'LineWidth', style.LineWidth, 'LineStyle', ls), ...
                "histLine", sl);
            top = max([top cnt]);
        otherwise   % bars
            cnt = histcounts(vs, edges, 'Normalization', nrm);
            h = trialBins(ax, edges, cnt, c, opacity, "histBar", sl, Log=xLog);
            top = max([top cnt]);
    end
    first(s) = h;
    if logical(optNum(o, 'showSummary', 1))
        r = find(T.series == s & T.category == 1, 1);
        if ~isempty(r) && isfinite(T.center(r)) && (~xLog || T.center(r) > 0)
            tagPart(xline(ax, T.center(r), ':', 'Color', c, 'LineWidth', 1.5, 'HandleVisibility', 'off'), "histSummary", sl);
        end
    end
end
hold(ax, 'off');
flat = style;
flat.XLim = [];
flat.YLim = [];
styleAxes(ax, flat);
if xLog; ax.XScale = 'log'; end
if ~isempty(xl) && (~xLog || xl(1) > 0)
    xlim(ax, xl);
elseif shape ~= "ecdf" && numel(edges) >= 2
    xlim(ax, edges([1 end]));
end
if D.yName ~= ""; xlabel(ax, D.yName, 'Interpreter', 'none'); end
switch shape
    case "ecdf"
        yName = "Cumulative probability";
    otherwise
        switch nrm
            case "probability", yName = "Probability";
            case "pdf"
                yName = "Density";
                if D.unit ~= ""; yName = "Density (1/" + D.unit + ")"; end
            otherwise, yName = "Count";
        end
end
hk.yName = yName;
if optText(o, 'testShow', "text") == "text"
    corner = "northeast";
    if shape == "ecdf"; corner = "northwest"; end
    t = statText(ax, D.stats, style, D.colors, string(D.S.label), Corner=corner);
    if ~isempty(t) && top > 0 && shape ~= "ecdf"
        ylim(ax, [0 top * (1 + 0.1 * (1 + numel(t.String)))]);
    end
end
if shape == "ecdf"; ylim(ax, [0 1]); end
if nS > 1
    for s = find(isgraphics(first))
        hk.legendHandles(end+1) = first(s);
        hk.legendLabels(end+1) = string(D.S.label(s));
        hk.legendGroup(end+1) = D.legendGroup;
    end
end
notes = strings(1, 0);
if nOut > 0; notes(end+1) = sprintf("%d value%s <= 0 not drawn (log axis)", nOut, plural(nOut)); end
trialNote(ax, notes, style);
figLayerNotes(ax, P, look, true);
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
