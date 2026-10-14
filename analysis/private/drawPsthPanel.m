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
%              figHistTrace), roles "rate" / "rateFill"
%   in the group's color (or the layer's color) and the item's line style
%   (the layer's lineStyle, else by order: -, --, :, -.); with several
%   items only the first is filled, the others are outlines, so each stays
%   visible. The components' group is the trial group's label, with
%   several items "<item> · <group>" (or the item alone for one group).
%   options.normalize divides the rates as renderPSTH does
%   (figNormalizeRates); options.yLim fixes the y axis. Style.ShowZeroLine
%   draws the event's line, Style.ShowStop each group's mean stop latency
%   (R.stopMean, role "stopLine"). The events layers drawn as marks become
%   latency lines and a rug (figEventMarks, roles "eventLine" /
%   "eventRug"), and with options.waveform.mode on the first unit's
%   waveform is an inset. Skipped layers are noted (figLayerNotes).
%   The legend offers the groups, then the items when there are several,
%   then the marks. HK: figDrawResult's, yName = the rates' unit.
%
%   See also renderFigure, renderPSTH, figHistTrace, figurePanelRegistry.

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

hold(ax, 'on');
yName = "";
R0 = [];
names = strings(1, nI);
lss = strings(1, nI);
normed = struct();
for i = 1:nI
    j = items(i, 1);
    u = items(i, 2);
    R = P.layers(j).R;
    if isempty(R0); R0 = R; end
    key = "L" + j;
    if ~isfield(normed, key)
        [rate, ~, units, lo, hi] = figNormalizeRates(R, o.normalize);
        normed.(key) = struct('rate', rate, 'units', units, 'lo', lo, 'hi', hi);
    end
    N = normed.(key);
    if yName == ""; yName = N.units; end
    if u == 0
        M = R.layerMean;
        m = M.mean; mlo = M.lo; mhi = M.hi;
        if o.normalize ~= "none"
            m = mean(N.rate, 2, 'omitnan');
            [mlo, mhi] = errorBounds(N.rate, 2, M.type, look.spec.style.ErrorResamples);
        end
        names(i) = P.layers(j).name;
    else
        m = N.rate(:, u, :); mlo = N.lo(:, u, :); mhi = N.hi(:, u, :);
        nm = shortUnitLabels(R.labels);
        names(i) = nm(u);
        if size(R.rate, 2) == 1 && P.layers(j).name ~= ""; names(i) = P.layers(j).name; end
    end
    nG = size(m, 3);
    colors = paletteFor(look, R, style);
    hl = struct('hist', o.histStyle, 'fill', o.fill && i == 1, 'alpha', o.fillAlpha);
    if ~isfinite(hl.alpha)
        hl.alpha = 1;
        if nG > 1; hl.alpha = 0.5; end
    end
    hl.alpha = min(1, max(0, hl.alpha));
    for g = 1:nG
        gl = string(R.groups.label(g));
        [c, ls] = figLayerLook(Ls(j), i, colors(g, :));
        lss(i) = ls;
        tg = gl;
        if nI > 1
            tg = names(i);
            if nG > 1; tg = names(i) + " · " + gl; end
        end
        if style.ShowSEM
            errorPatch(ax, R.t, mlo(:, 1, g), mhi(:, 1, g), c, tg, style);
        end
        h1 = figHistTrace(ax, R.t, R.edges, m(:, 1, g), 0, c, hl, style.LineWidth, tg, ls);
        if i == 1 && nG > 1
            hk.legendHandles(end+1) = h1;
            hk.legendLabels(end+1) = gl;
            hk.legendGroup(end+1) = true;
        end
    end
end
if nI > 1   % the items, by line style (in the group's color when there is one group)
    for i = 1:nI
        j = items(i, 1);
        R = P.layers(j).R;
        colors = paletteFor(look, R, style);
        c = [0.25 0.25 0.25];
        if size(colors, 1) == 1; c = colors(1, :); end
        c = figLayerLook(Ls(j), i, c);
        hk.legendHandles(end+1) = tagPart(line(ax, NaN, NaN, 'Color', c, 'LineStyle', lss(i), 'LineWidth', style.LineWidth), ...
            "rate", names(i));
        hk.legendLabels(end+1) = names(i);
        hk.legendGroup(end+1) = false;
    end
end
if style.ShowZeroLine
    tagPart(xline(ax, 0, ':', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off'), "zeroLine");
end
if ~isempty(R0) && style.ShowStop && isfield(R0, 'stopMean')
    colors = paletteFor(look, R0, style);
    for g = 1:numel(R0.stopMean)
        if isfinite(R0.stopMean(g))
            tagPart(xline(ax, R0.stopMean(g), '--', 'Color', colors(g, :), 'HandleVisibility', 'off'), "stopLine", ...
                string(R0.groups.label(g)));
        end
    end
end
hold(ax, 'off');
if numel(look.W) == 2 && look.W(2) > look.W(1); xlim(ax, look.W); end
flat = style;
flat.XLim = [];
flat.YLim = o.yLim;
styleAxes(ax, flat);

nGroups = size(look.colors, 1);
if ~isempty(R0); nGroups = height(R0.groups); end
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


function colors = paletteFor(look, R, style)
%paletteFor  The trial groups' colors: the figure's palette when it fits R's groups, else R's own.
colors = look.colors;
if size(colors, 1) ~= height(R.groups); colors = groupPalette(R.groups, style); end
end
