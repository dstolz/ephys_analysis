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
%   role "curve", as renderTuning draws a unit's tile. The components' group
%   is the series' label, with several items "<item> · <series>" (the item
%   alone for one series). The legend gets the series (more than one), then
%   the items (more than one). options.yLim fixes the y axis; with
%   options.waveform.mode on the first unit's waveform is an inset. Skipped
%   layers are noted (figLayerNotes). HK: figDrawResult's, yName = the
%   rates' unit.
%
%   See also renderFigure, renderTuning, tuningCurve, figurePanelRegistry.

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
hold(ax, 'on');
lss = strings(1, nI);
names = strings(1, nI);
xAll = [];
for i = 1:nI
    j = items(i, 1);
    u = items(i, 2);
    R = P.layers(j).R;
    [nX, ~, nS] = size(R.mean);
    if R.xIsNumeric; xv = double(R.x(:)); else; xv = (1:nX).'; end
    xAll = [xAll; xv]; %#ok<AGROW>
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
    colors = groupPalette(R.groups, style);
    for k = 1:nS
        sl = string(R.series(k));
        [c, ls] = figLayerLook(Ls(j), i, colors(k, :));
        lss(i) = ls;
        tg = sl;
        if nI > 1
            tg = names(i);
            if nS > 1; tg = names(i) + " · " + sl; end
        end
        if style.ShowSEM
            h = errorbar(ax, xv, m(:, k), m(:, k) - lo(:, k), hi(:, k) - m(:, k), 'o', 'LineStyle', ls, 'Color', c, ...
                'LineWidth', style.LineWidth, 'MarkerSize', 4, 'MarkerFaceColor', c, 'CapSize', 3);
        else
            h = plot(ax, xv, m(:, k), 'o', 'LineStyle', ls, 'Color', c, 'LineWidth', style.LineWidth, ...
                'MarkerSize', 4, 'MarkerFaceColor', c);
        end
        tagPart(h, "curve", tg);
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
styleAxes(ax, flat);
xlabel(ax, R0.param, 'Interpreter', 'none');
wave = EphysAnalysisConfig.normalizeSection("Waveform", o.waveform);
first = find(items(:, 2) > 0, 1);
if wave.mode ~= "off" && ~isempty(first) && isfield(P.layers(items(first, 1)).R, 'waveforms')
    waveformInset(ax, P.layers(items(first, 1)).R.waveforms, items(first, 2), wave, style);
end
figLayerNotes(ax, P, look, true);
hk.yName = R0.units;
end
