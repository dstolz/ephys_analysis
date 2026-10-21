function hk = drawTuningPanel(ax, P, look)
%drawTuningPanel  Draw a figure's tuning curve panel: the rate against a trial parameter, one curve per series.
%   HK = drawTuningPanel(AX, P, LOOK) draws the panel result P (F.panels(k)
%   of EphysAnalysisRunner.computeFigure: tuningCurve results) into the
%   axes AX, as renderFigure asks (LOOK: style, colors, W, spec, panel,
%   panelId, isTop, isBottom, epochs, groups, observation, isTime). x is
%   the parameter's values (numeric at their values, text evenly spaced
%   and ticked with them), labeled with its name. Each item -- each unit
%   of a layer in probe order, or with aggregate "mean" the layer's mean
%   over its units (R.layerMean, its error bars across the units) -- draws
%   one curve per series in the series' color (the layer's color when set)
%   and the item's line style (the layer's lineStyle, else by order: -,
%   --, :, -.), markers at the values, with error bars (R.err; Style.ShowSEM),
%   role "curve". The components' group
%   is the series' label, with several items "<item> · <series>" (the item
%   alone for one series). The legend gets the series (more than one), then
%   the items (more than one). options.yLim fixes the y axis; with
%   options.waveform.mode on the first unit's waveform is an inset. Skipped
%   layers are noted (figLayerNotes). A result merged across sessions
%   (figureSessionCompute) draws its series (the sessions, subjects or all)
%   as the curves, each member session (R.members) a pale line under them
%   (memberLines), the trial groups of "combine" by line style
%   (figSeriesStyle). options.stack "groups" (with two or more series)
%   draws a row per series instead, the first on top, every item in each
%   row, in the rows of stackLayout (one scale, the row step
%   options.stackSpacing x the row height, the tallest row's reach of
%   curves and error bars), a gray line along each row (stackBaseLines),
%   the rows named by their series on the left y axis and each row's top
%   on the right (stackAxes; options.yLim is not used); y label "<series
%   parameter> (<height> <units> per row)". HK: figDrawResult's, yName =
%   the rates' unit.
%
%   See also renderFigure, tuningCurve, figurePanelRegistry.

style = look.style;
o = look.panel.options;
Ls = look.panel.layers;
hk = figDrawResult(ax);
tagPart(ax, "axes", "", look.panelId);

items = zeros(0, 2);   % [layer, unit] (unit 0: the layer's mean)
for j = 1:numel(P.layers)
    R = P.layers(j).R;
    if P.layers(j).skip ~= "" || ~isstruct(R) || ~isfield(R, 'kind') || R.kind ~= "tuning"; continue; end
    if j <= numel(Ls) && Ls(j).aggregate == "mean" && isfield(R, 'layerMean')
        items(end+1, :) = [j 0]; %#ok<AGROW>
    else
        nU = size(R.mean, 2);
        items = [items; repmat(j, nU, 1) probeOrder(R.meta, nU, style)]; %#ok<AGROW>
    end
end
nI = size(items, 1);
if nI == 0
    figLayerNotes(ax, P, look, false);
    return
end

R0 = P.layers(items(1, 1)).R;
% each item's curves [nX x nSeries]: mean and error edges, its name and x
C = struct('xv', {}, 'm', {}, 'lo', {}, 'hi', {}, 'M', {});
names = strings(1, nI);
for i = 1:nI
    j = items(i, 1);
    u = items(i, 2);
    R = P.layers(j).R;
    [nX, ~, nS] = size(R.mean);
    if R.xIsNumeric; xv = double(R.x(:)); else; xv = (1:nX).'; end
    if u == 0
        M = R.layerMean;
        m = reshape(M.mean, nX, nS); lo = reshape(M.lo, nX, nS); hi = reshape(M.hi, nX, nS);
        names(i) = P.layers(j).name;
    else
        [eLo, eHi] = resultBounds(R, 'mean');
        m = reshape(R.mean(:, u, :), nX, nS); lo = reshape(eLo(:, u, :), nX, nS); hi = reshape(eHi(:, u, :), nX, nS);
        nm = shortUnitLabels(R.labels);
        names(i) = nm(u);
        if size(R.mean, 2) == 1 && P.layers(j).name ~= ""; names(i) = P.layers(j).name; end
    end
    Mm = [];
    if isfield(R, 'members') && isstruct(R.members) && isfield(R.members, 'mean') && ~isempty(R.members.mean)
        Mm = R.members.mean;   % [nX x nTiles x nMembers]: the member sessions (merged across sessions, ShowMembers)
        if u == 0
            Mm = reshape(mean(Mm, 2, 'omitnan'), nX, []);
        else
            Mm = reshape(Mm(:, u, :), nX, []);
        end
    end
    C(i) = struct('xv', xv, 'm', m, 'lo', lo, 'hi', hi, 'M', Mm);
end
% a stack: a row per series, the first on top, every item in each
nSmax = 0;
for i = 1:nI; nSmax = max(nSmax, size(C(i).m, 2)); end
stacked = isfield(o, 'stack') && o.stack == "groups" && nSmax > 1;
L = [];
rowNames = strings(1, 0);
if stacked
    rowNames = reshape(string(R0.series), 1, []);
    rowNames(end+1:nSmax) = "";
    rowNames = rowNames(1:nSmax);
    rlo = NaN(1, nSmax);
    rhi = NaN(1, nSmax);
    for i = 1:nI
        for k = 1:size(C(i).m, 2)
            v = C(i).m(:, k);
            if style.ShowSEM; v = [v; C(i).lo(:, k); C(i).hi(:, k)]; end %#ok<AGROW>
            v = double(v(isfinite(v)));
            if isempty(v); continue; end
            rlo(k) = min([rlo(k); v]);
            rhi(k) = max([rhi(k); v]);
        end
    end
    L = stackLayout(rlo, rhi, o.stackSpacing);
end
hold(ax, 'on');
lss = strings(1, nI);
xAll = [];
for i = 1:nI
    j = items(i, 1);
    R = P.layers(j).R;
    xv = C(i).xv;
    m = C(i).m; lo = C(i).lo; hi = C(i).hi;
    nS = size(m, 2);
    xAll = [xAll; xv]; %#ok<AGROW>
    if stacked && i == 1 && numel(xv) > 0
        xr = [min(xv) max(xv)];
        if xr(2) > xr(1); xr = xr + [-1 1] * 0.08 * diff(xr); end
        stackBaseLines(ax, xr, L, rowNames);
    end
    colors = groupPalette(R.groups, style);
    if ~isempty(C(i).M)
        if stacked
            sr = double(R.members.series(:)).';
            memberLines(ax, xv, C(i).M .* L.scale(sr) + L.offset(sr), R, colors, style, R.series);
        else
            memberLines(ax, xv, C(i).M, R, colors, style, R.series);
        end
    end
    for k = 1:nS
        off = 0; sc = 1;
        if stacked; off = L.offset(k); sc = L.scale(k); end
        sl = string(R.series(k));
        [c, ls] = figLayerLook(Ls(j), i, colors(k, :));
        ls = figSeriesStyle(R, k, ls, Ls(j));
        lss(i) = ls;
        tg = sl;
        if nI > 1
            tg = names(i);
            if nS > 1; tg = names(i) + " · " + sl; end
        end
        if style.ShowSEM
            h = errorbar(ax, xv, sc * m(:, k) + off, sc * (m(:, k) - lo(:, k)), sc * (hi(:, k) - m(:, k)), 'o', 'LineStyle', ls, 'Color', c, ...
                'LineWidth', style.LineWidth, 'MarkerSize', 4, 'MarkerFaceColor', c, 'CapSize', 3);
        else
            h = plot(ax, xv, sc * m(:, k) + off, 'o', 'LineStyle', ls, 'Color', c, 'LineWidth', style.LineWidth, ...
                'MarkerSize', 4, 'MarkerFaceColor', c);
        end
        stackMark(tagPart(h, "curve", tg), off, sc);
        if i == 1 && nS > 1
            hk.legendHandles(end+1) = h;
            hk.legendLabels(end+1) = sl;
            hk.legendGroup(end+1) = false;
        end
    end
end
if nI > 1   % the items, by line style (in the series' color when there is one series)
    for i = 1:nI
        j = items(i, 1);
        R = P.layers(j).R;
        c = [0.25 0.25 0.25];
        if height(R.groups) == 1; c = groupPalette(R.groups, style); c = c(1, :); end
        c = figLayerLook(Ls(j), i, c);
        hk.legendHandles(end+1) = tagPart(line(ax, NaN, NaN, 'Color', c, 'LineStyle', lss(i), 'LineWidth', style.LineWidth, ...
            'Marker', 'o', 'MarkerSize', 4, 'MarkerFaceColor', c), "curve", names(i));
        hk.legendLabels(end+1) = names(i);
        hk.legendGroup(end+1) = false;
    end
end
hold(ax, 'off');
if ~R0.xIsNumeric
    set(ax, 'XTick', 1:numel(R0.x), 'XTickLabel', string(R0.x), 'TickLabelInterpreter', 'none');
end
xAll = xAll(isfinite(xAll));
if numel(unique(xAll)) > 1
    pad = 0.08 * (max(xAll) - min(xAll));
    xlim(ax, [min(xAll) - pad, max(xAll) + pad]);
end
flat = style;
flat.XLim = [];
flat.YLim = o.yLim;
if stacked; flat.YLim = []; end
styleAxes(ax, flat);
xlabel(ax, R0.param, 'Interpreter', 'none');
if stacked
    rightName = "Row top";
    if R0.units ~= ""; rightName = "Row top (" + R0.units + ")"; end
    stackAxes(ax, L, rowNames, rightName);
end
wave = EphysAnalysisConfig.normalizeSection("Waveform", o.waveform);
first = find(items(:, 2) > 0, 1);
if wave.mode ~= "off" && ~isempty(first) && isfield(P.layers(items(first, 1)).R, 'waveforms')
    waveformInset(ax, P.layers(items(first, 1)).R.waveforms, items(first, 2), wave, style);
end
figLayerNotes(ax, P, look, true);
hk.yName = R0.units;
if stacked
    what = "Series";
    if isfield(R0, 'seriesParam') && string(R0.seriesParam) ~= ""; what = string(R0.seriesParam); end
    hk.yName = strip(sprintf("%s (%s %s", what, sprintf('%.3g', L.height), R0.units)) + " per row)";
end
end
