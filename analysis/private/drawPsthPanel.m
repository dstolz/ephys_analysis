function hk = drawPsthPanel(ax, P, look)
%drawPsthPanel  Draw a figure's PSTH panel: each layer's peri-event rate per trial group, events as latency lines.
%   HK = drawPsthPanel(AX, P, LOOK) draws the panel result P (F.panels(k)
%   of EphysAnalysisRunner.computeFigure) into the axes AX, as renderFigure
%   asks (LOOK: style, colors, W, spec, panel, panelId, isTop, isBottom,
%   epochs, groups, observation, isTime). Each point layer (units,
%   detected, an events train: a spikePSTH result) gives its items: each
%   unit in probe order, or with aggregate "mean" the mean over its units
%   (R.layerMean, its band across the units; recomputed from the
%   normalized rates when options.normalize is not "none"). Each item and
%   trial group is
%     a band   the error R.err holds (Style.ShowSEM), errorPatch, role "sem"
%     a trace  bars or a line (options.histStyle, fill, fillAlpha:
%              histTrace), roles "rate" / "rateFill"
%   in the group's color (or the layer's color) and the item's line style
%   (the layer's lineStyle, else by order: -, --, :, -.); with several
%   items only the first is filled, the others are outlines, so each stays
%   visible. The components' group is the trial group's label, with
%   several items "<item> · <group>" (or the item alone for one group).
%   options.normalize divides the rates as renderPSTH does
%   (normalizeRates); options.yLim fixes the y axis. Style.ShowZeroLine
%   draws the event's line, Style.ShowStop each group's mean stop latency
%   (R.stopMean, role "stopLine").
%   options.stack (with two or more groups) draws one row per group, the
%   first at the bottom, as renderPSTH's Stack does (drawStack: the row
%   step options.stackSpacing x the tallest PSTH, the rows' values on the
%   left axis, their peaks on the right; options.yLim is not used); a
%   further item is drawn into the same rows as an outline. The groups are
%   still offered to the figure's legend.
%   An auROC result (baseline Mode "auroc") is drawn from 0.5 (a dotted
%   chance line, role "chanceLine") on a 0-1 axis unless options.yLim says
%   otherwise, the modulation window shaded (modulationWindow) and the first
%   item's call per group at the top right (callMarks; a layer's mean: its
%   units' counts up and down), as renderPSTH draws it; normalize does not
%   apply.
%   The events layers drawn as marks become latency lines and a rug
%   (figEventMarks, roles "eventLine" / "eventRug"), and with
%   options.waveform.mode on the first unit's waveform is an inset. Skipped
%   layers are noted (figLayerNotes). The legend offers the groups, then
%   the items when there are several, then the marks. HK: figDrawResult's,
%   yName = the rates' unit (a stack: its rows' parameters).
%
%   See also renderFigure, renderPSTH, histTrace, drawStack, figurePanelRegistry.

style = look.style;
o = look.panel.options;
Ls = look.panel.layers;
hk = figDrawResult(ax);
tagPart(ax, "axes", "", look.panelId);

items = zeros(0, 2);   % [layer, unit] (unit 0: the layer's mean)
for j = 1:numel(P.layers)
    R = P.layers(j).R;
    if P.layers(j).skip ~= "" || ~isstruct(R) || ~isfield(R, 'rate'); continue; end
    if j <= numel(Ls) && Ls(j).aggregate == "mean" && isfield(R, 'layerMean')
        items(end+1, :) = [j 0]; %#ok<AGROW>
    else
        nU = size(R.rate, 2);
        items = [items; repmat(j, nU, 1) probeOrder(R.meta, nU, style)]; %#ok<AGROW>
    end
end
nI = size(items, 1);
hasMarks = any(arrayfun(@(l) l.skip == "" && isstruct(l.R) && isfield(l.R, 'kind') && l.R.kind == "events", P.layers));
if nI == 0 && ~hasMarks
    figLayerNotes(ax, P, look, false);
    return
end

% each item's traces: its mean, its band's edges, its name, colors and look
auroc = nI > 0 && isAuroc(P.layers(items(1, 1)).R);
norm = o.normalize;
if auroc; norm = "none"; end   % an auROC is on its own 0-1 scale
ref = 0;
if auroc; ref = 0.5; end       % bars from chance
yName = "";
D = struct('R', {}, 'm', {}, 'lo', {}, 'hi', {}, 'peak', {}, 'name', {}, 'colors', {}, 'u', {});
normed = struct();
for i = 1:nI
    j = items(i, 1);
    u = items(i, 2);
    R = P.layers(j).R;
    key = "L" + j;
    if ~isfield(normed, key)
        [rate, ~, units, lo, hi] = normalizeRates(R, norm);
        normed.(key) = struct('rate', rate, 'units', units, 'lo', lo, 'hi', hi);
    end
    N = normed.(key);
    if yName == ""; yName = N.units; end
    if u == 0
        M = R.layerMean;
        m = M.mean; mlo = M.lo; mhi = M.hi;
        if norm ~= "none"
            m = mean(N.rate, 2, 'omitnan');
            [mlo, mhi] = errorBounds(N.rate, 2, M.type, look.spec.style.ErrorResamples);
        end
        name = P.layers(j).name;
        peak = reshape(max(m, [], 1), [], 1);
    else
        m = N.rate(:, u, :); mlo = N.lo(:, u, :); mhi = N.hi(:, u, :);
        nm = shortUnitLabels(R.labels);
        name = nm(u);
        if size(R.rate, 2) == 1 && P.layers(j).name ~= ""; name = P.layers(j).name; end
        peak = reshape(max(R.rate(:, u, :), [], 1), [], 1);
    end
    nG = size(m, 3);
    D(i) = struct('R', R, 'm', reshape(m, [], nG), 'lo', reshape(mlo, [], nG), 'hi', reshape(mhi, [], nG), ...
        'peak', peak, 'name', name, 'colors', paletteFor(look, R, style), 'u', u);
end
names = strings(1, nI);
for i = 1:nI; names(i) = D(i).name; end
stacked = o.stack && nI > 0 && size(D(1).m, 2) > 1;

hl = struct('hist', o.histStyle, 'fill', o.fill, 'alpha', o.fillAlpha, 'stack', stacked, 'spacing', o.stackSpacing, 'raster', []);
if ~isfinite(hl.alpha)
    hl.alpha = 1;
    if nI > 0 && size(D(1).m, 2) > 1 && ~stacked; hl.alpha = 0.5; end
end
hl.alpha = min(1, max(0, hl.alpha));
lss = strings(1, nI);
if stacked
    [yName, lss] = drawRows(ax, D, Ls, items, hl, style, o);
    for g = 1:size(D(1).m, 2)   % the groups, for the figure's legend (the rows are labeled on the axis)
        gl = string(D(1).R.groups.label(g));
        hk.legendHandles(end+1) = tagPart(line(ax, NaN, NaN, 'Color', D(1).colors(g, :), 'LineWidth', style.LineWidth), "rate", gl);
        hk.legendLabels(end+1) = gl;
        hk.legendGroup(end+1) = true;
    end
else
    hold(ax, 'on');
    if auroc; modulationWindow(ax, D(1).R); end
    for i = 1:nI
        j = items(i, 1);
        nG = size(D(i).m, 2);
        hli = hl;
        hli.fill = o.fill && i == 1;
        for g = 1:nG
            gl = string(D(i).R.groups.label(g));
            [c, ls] = figLayerLook(Ls(j), i, D(i).colors(g, :));
            lss(i) = ls;
            tg = groupTag(names(i), gl, nI, nG);
            if style.ShowSEM
                errorPatch(ax, D(i).R.t, D(i).lo(:, g), D(i).hi(:, g), c, tg, style);
            end
            h1 = histTrace(ax, D(i).R.t, D(i).R.edges, D(i).m(:, g) - ref, ref, c, hli, style.LineWidth, tg, ls);
            if i == 1 && nG > 1
                hk.legendHandles(end+1) = h1;
                hk.legendLabels(end+1) = gl;
                hk.legendGroup(end+1) = true;
            end
        end
    end
    if style.ShowZeroLine
        tagPart(xline(ax, 0, ':', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off'), "zeroLine");
    end
    if auroc
        tagPart(yline(ax, ref, ':', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off'), "chanceLine");
    end
    if nI > 0 && style.ShowStop && isfield(D(1).R, 'stopMean')
        R0 = D(1).R;
        for g = 1:numel(R0.stopMean)
            if isfinite(R0.stopMean(g))
                tagPart(xline(ax, R0.stopMean(g), '--', 'Color', D(1).colors(g, :), 'HandleVisibility', 'off'), "stopLine", ...
                    string(R0.groups.label(g)));
            end
        end
    end
    hold(ax, 'off');
end
if nI > 1   % the items, by line style (in the group's color when there is one group)
    for i = 1:nI
        j = items(i, 1);
        c = [0.25 0.25 0.25];
        if size(D(i).colors, 1) == 1; c = D(i).colors(1, :); end
        c = figLayerLook(Ls(j), i, c);
        hk.legendHandles(end+1) = tagPart(line(ax, NaN, NaN, 'Color', c, 'LineStyle', lss(i), 'LineWidth', style.LineWidth), ...
            "rate", names(i));
        hk.legendLabels(end+1) = names(i);
        hk.legendGroup(end+1) = false;
    end
end
if numel(look.W) == 2 && look.W(2) > look.W(1); xlim(ax, look.W); end
if ~stacked
    flat = style;
    flat.XLim = [];
    flat.YLim = o.yLim;
    styleAxes(ax, flat);
    if auroc && isempty(o.yLim); ylim(ax, [0 1]); end
end
if auroc; callMarks(ax, D(1).R, D(1).u, D(1).colors, style); end

nGroups = size(look.colors, 1);
if nI > 0; nGroups = height(D(1).R.groups); end
[hm, lm] = figEventMarks(ax, P, look, 1:max(1, nGroups), "group");
for m = 1:numel(hm)
    hk.legendHandles(end+1) = hm(m);
    hk.legendLabels(end+1) = lm(m);
    hk.legendGroup(end+1) = false;
end
wave = EphysAnalysisConfig.normalizeSection("Waveform", o.waveform);
first = find(items(:, 2) > 0, 1);
if wave.mode ~= "off" && ~isempty(first) && isfield(P.layers(items(first, 1)).R, 'waveforms')
    waveformInset(ax, P.layers(items(first, 1)).R.waveforms, items(first, 2), wave, style);
end
figLayerNotes(ax, P, look, true);
hk.yName = yName;
end


function [yName, lss] = drawRows(ax, D, Ls, items, hl, style, o)
%drawRows  The stack: the first item's rows by drawStack, every further item drawn into the same rows as an outline.
%   The step is taken from the tallest PSTH of every item, so each fits its
%   rows; the y limits of both sides then cover every item's reach.
nI = numel(D);
nG = size(D(1).m, 2);
lss = strings(1, nI);
tallest = -Inf;
for i = 1:nI
    tallest = max([tallest; D(i).m(:)]);
end
P1 = struct('m', D(1).m, 'lo', D(1).lo, 'hi', D(1).hi, 'peak', D(1).peak, ...
    'peakLabel', "Peak (" + D(1).R.units + ")", 'tallest', tallest);
if o.normalize ~= "none" && ~isAuroc(D(1).R); P1.peakLabel = "Peak (normalized)"; end
if D(1).u == 0; P1.peak = max(D(1).m, [], 1).'; end
if isAuroc(D(1).R)   % behind the rows
    hold(ax, 'on');
    modulationWindow(ax, D(1).R);
    hold(ax, 'off');
end
step = drawStack(ax, P1, D(1).R, D(1).colors, style, hl, struct('left', false, 'right', true));
[~, yName] = rowLabels(D(1).R);
[~, lss(1)] = figLayerLook(Ls(items(1, 1)), 1, D(1).colors(1, :));
if nI < 2; return; end
yyaxis(ax, 'left');
yl = ylim(ax);
lo = yl(1); hi = yl(2);
hold(ax, 'on');
out = hl;
out.fill = false;
for i = 2:nI
    j = items(i, 1);
    for g = 1:min(nG, size(D(i).m, 2))
        b = (g - 1) * step;
        gl = string(D(i).R.groups.label(g));
        [c, ls] = figLayerLook(Ls(j), i, D(i).colors(g, :));
        lss(i) = ls;
        tg = groupTag(D(i).name, gl, nI, nG);
        if style.ShowSEM
            errorPatch(ax, D(i).R.t, D(i).lo(:, g) + b, D(i).hi(:, g) + b, c, tg, style);
        end
        histTrace(ax, D(i).R.t, D(i).R.edges, D(i).m(:, g), b, c, out, style.LineWidth, tg, ls);
        reach = D(i).m(:, g);
        if style.ShowSEM; reach = [reach; D(i).hi(:, g)]; end %#ok<AGROW>
        hi = max([hi; b + reach(isfinite(reach))]);
        lo = min([lo; b + reach(isfinite(reach))]);
    end
end
hold(ax, 'off');
if hi > yl(2) || lo < yl(1)
    yl = [lo, hi + 0.03 * (hi - lo)];
    ylim(ax, yl);
    yyaxis(ax, 'right');
    ylim(ax, yl);
    yyaxis(ax, 'left');
end
end


function tg = groupTag(name, gl, nI, nG)
%groupTag  A trace's aesthetics group: the trial group, or with several items "<item> · <group>" (the item alone for one group).
tg = gl;
if nI > 1
    tg = name;
    if nG > 1; tg = name + " · " + gl; end
end
end


function colors = paletteFor(look, R, style)
%paletteFor  The trial groups' colors: the figure's palette when it fits R's groups, else R's own.
colors = look.colors;
if size(colors, 1) ~= height(R.groups); colors = groupPalette(R.groups, style); end
end
