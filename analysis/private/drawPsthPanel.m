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
%   options.normalize divides the rates (normalizeRates); options.yLim fixes the y axis. Style.ShowZeroLine
%   draws the event's line, Style.ShowStop each group's mean stop latency
%   (R.stopMean, role "stopLine").
%   options.stack "groups" (with two or more groups) draws one row per
%   group, the first on top, as a raster lists them (drawStack in the rows
%   of a stackLayout: every row from its zero, the row step
%   options.stackSpacing x the row height, the tallest reach of any row's
%   PSTH and band; the rows' values on the left axis, their peaks on the
%   right; options.yLim is not used); a further item is drawn into the
%   same rows as an outline. The groups are still offered to the figure's
%   legend.
%   options.display "heatmap" draws the first item as an image instead
%   (drawHeat): a row per trial group, the first on top (as a stack and a
%   raster list them), x the PSTH's bins, colored by its rate (after
%   measure, smoothing, baseline and normalize) on that item's own range
%   (options.cLim, else its rows' min to max; an auROC 0 to 1), never
%   across units, in options.colormap ("" = the design's heat colormap,
%   Style.HeatColormap, as a heat map panel's); role "image", the color bar
%   "colorbar" (in R.units; inside the axes when the panel shares a column
%   with other time panels: inTimeColumn), y label the rows' parameters
%   (rowLabels). The zero line and stop latencies are drawn over it, an
%   auROC's modulation window as a bar along its top; histStyle, fill,
%   fillAlpha, stack, stackSpacing and yLim are not used, nor a merged
%   result's member sessions; the groups are not offered to the legend
%   (the rows are labeled) and the marks' latency lines take the marks'
%   colors. The further items are noted at the bottom left
%   (figLayerNotes).
%   An auROC result (baseline Mode "auroc") is drawn from 0.5 (a dotted
%   chance line, role "chanceLine") on a 0-1 axis unless options.yLim says
%   otherwise, the modulation window shaded (modulationWindow) and the first
%   item's call per group at the top right (callMarks; a layer's mean: its
%   units' counts up and down); normalize does not
%   apply.
%   The events layers drawn as marks become latency lines and a rug
%   (figEventMarks, roles "eventLine" / "eventRug"), and with
%   options.waveform.mode on the first unit's waveform is an inset. Skipped
%   layers are noted (figLayerNotes). The legend offers the groups, then
%   the items when there are several, then the marks. A result merged
%   across sessions (figureSessionCompute) draws its series as the groups,
%   each member session (R.members) a pale line under them (memberLines,
%   divided as the series are: memberRates), and the trial groups of
%   trialGroups "combine" by line style (figSeriesStyle). HK: figDrawResult's,
%   yName = the rates' unit (a stack or a heat map: its rows' parameters).
%
%   See also renderFigure, histTrace, drawStack, figurePanelRegistry.

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
D = struct('R', {}, 'm', {}, 'lo', {}, 'hi', {}, 'peak', {}, 'name', {}, 'colors', {}, 'u', {}, 'members', {}, 'units', {});
normed = struct();
for i = 1:nI
    j = items(i, 1);
    u = items(i, 2);
    R = P.layers(j).R;
    key = "L" + j;
    if ~isfield(normed, key)
        [rate, ~, units, lo, hi, pn] = normalizeRates(R, norm);
        mem = [];   % the member sessions' rates (a result merged across sessions, ShowMembers), divided like the series'
        if isfield(R, 'members') && isstruct(R.members) && isfield(R.members, 'rate') && ~isempty(R.members.rate)
            mem = memberRates(R, norm, pn);
        end
        normed.(key) = struct('rate', rate, 'units', units, 'lo', lo, 'hi', hi, 'members', mem);
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
        mm = [];
        if ~isempty(N.members); mm = reshape(mean(N.members, 2, 'omitnan'), size(N.members, 1), []); end   % each member's mean over the tiles
    else
        m = N.rate(:, u, :); mlo = N.lo(:, u, :); mhi = N.hi(:, u, :);
        nm = shortUnitLabels(R.labels);
        name = nm(u);
        if size(R.rate, 2) == 1 && P.layers(j).name ~= ""; name = P.layers(j).name; end
        peak = reshape(max(R.rate(:, u, :), [], 1), [], 1);
        mm = [];
        if ~isempty(N.members); mm = reshape(N.members(:, u, :), size(N.members, 1), []); end
    end
    nG = size(m, 3);
    D(i) = struct('R', R, 'm', reshape(m, [], nG), 'lo', reshape(mlo, [], nG), 'hi', reshape(mhi, [], nG), ...
        'peak', peak, 'name', name, 'colors', paletteFor(look, R, style), 'u', u, 'members', mm, 'units', N.units);
end
names = strings(1, nI);
for i = 1:nI; names(i) = D(i).name; end
heat = o.display == "heatmap" && nI > 0;   % the first item as an image, a row per trial group
stacked = ~heat && o.stack == "groups" && nI > 0 && size(D(1).m, 2) > 1;

hl = struct('hist', o.histStyle, 'fill', o.fill, 'alpha', o.fillAlpha, 'stack', stacked);
if ~isfinite(hl.alpha)
    hl.alpha = 1;
    if nI > 0 && size(D(1).m, 2) > 1 && ~stacked; hl.alpha = 0.5; end
end
hl.alpha = min(1, max(0, hl.alpha));
lss = strings(1, nI);
if heat
    yName = drawHeat(ax, D(1), P.layers(items(1, 1)).name, look, o, style);
elseif stacked
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
        if ~isempty(D(i).members)   % each member session, faint, under its series (a result merged across sessions)
            memberLines(ax, D(i).R.t, D(i).members, D(i).R, D(i).colors, style);
        end
        for g = 1:nG
            gl = string(D(i).R.groups.label(g));
            [c, ls] = figLayerLook(Ls(j), i, D(i).colors(g, :));
            ls = figSeriesStyle(D(i).R, g, ls, Ls(j));
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
if nI > 1 && ~heat   % the items, by line style (in the group's color when there is one group)
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
if ~stacked && ~heat
    flat = style;
    flat.XLim = [];
    flat.YLim = o.yLim;
    styleAxes(ax, flat);
    if auroc && isempty(o.yLim); ylim(ax, [0 1]); end
end
if auroc; callMarks(ax, D(1).R, D(1).u, D(1).colors, style); end

nGroups = size(look.colors, 1);
if nI > 0; nGroups = height(D(1).R.groups); end
colorBy = "group";
if heat; colorBy = "mark"; end   % over an image the latency lines take the marks' colors, as a heat map's do
[hm, lm] = figEventMarks(ax, P, look, 1:max(1, nGroups), colorBy);
for m = 1:numel(hm)
    hk.legendHandles(end+1) = hm(m);
    hk.legendLabels(end+1) = lm(m);
    hk.legendGroup(end+1) = false;
end
wave = EphysAnalysisConfig.normalizeSection("Waveform", o.waveform);
first = find(items(:, 2) > 0, 1);
if heat; first = find(items(1, 2) > 0, 1); end   % the unit drawn, if the first item is one
if wave.mode ~= "off" && ~isempty(first) && isfield(P.layers(items(first, 1)).R, 'waveforms')
    waveformInset(ax, P.layers(items(first, 1)).R.waveforms, items(first, 2), wave, style);
end
if heat && nI > 1
    P = heatNotes(P, items, names, Ls);
end
figLayerNotes(ax, P, look, true);
hk.yName = yName;
end


function yName = drawHeat(ax, d, layerName, look, o, style)
%drawHeat  One item's PSTH as an image: a row per trial group, the first on top, colored on that item's own range.
%   D is the item (drawPsthPanel's D(1): its rates after measure, smoothing,
%   baseline and normalize, d.m [nBins x nGroups]). The color limits are
%   options.cLim, else the range of this item's rows (an auROC: 0 to 1),
%   never another unit's; the colormap is heatColormap's. The rows are
%   labeled with the groups' values on the y axis (rowLabels; YNAME: their
%   parameters); a color bar in the rows' unit (d.units) is the scale, kept
%   inside the axes when the panel shares a column with other time panels
%   (inTimeColumn). Over the image: the zero line, each group's mean stop
%   latency in its row and, for an auROC with a cutoff and its marks on, a
%   bar along the top over the modulation window (a line: an xregion is
%   drawn behind an image).
R = d.R;
M = d.m.';   % groups x bins: the first group in row 1, on top (YDir reverse)
nG = size(M, 1);
auroc = isAuroc(R);
tagPart(imagesc(ax, R.t(:).', 1:nG, M, 'AlphaData', double(isfinite(M))), "image", layerName);
tagPart(ax, "axes", "", look.panelId);   % after imagesc, which resets a replaced axes' properties
set(ax, 'YDir', 'reverse');
colormap(ax, heatColormap(o, style, auroc));
v = M(isfinite(M));
cl = [0 1];
if ~isempty(v) && ~auroc; cl = [min(v) max(v)]; end
if cl(2) <= cl(1); cl = cl + [-0.5 0.5]; end
if numel(o.cLim) == 2 && o.cLim(2) > o.cLim(1); cl = o.cLim; end
clim(ax, cl);
hold(ax, 'on');
if style.ShowZeroLine; tagPart(xline(ax, 0, '--', 'Color', [1 1 1], 'LineWidth', 1, 'HandleVisibility', 'off'), "zeroLine"); end
if style.ShowStop && isfield(R, 'stopMean')
    for g = 1:min(nG, numel(R.stopMean))
        if isfinite(R.stopMean(g))
            tagPart(line(ax, R.stopMean([g g]), g + [-0.5 0.5], 'LineStyle', '--', 'Color', [1 1 1], 'HandleVisibility', 'off'), ...
                "stopLine", string(R.groups.label(g)));
        end
    end
end
if auroc
    A = R.auroc;
    if A.cutoff ~= "none" && ~(isfield(A, 'settings') && ~A.settings.marks)
        tagPart(line(ax, A.modulationWindow, [0.5 0.5], 'Color', [0 0 0], 'LineWidth', 3, 'Clipping', 'off', ...
            'HandleVisibility', 'off'), "modWindow");
    end
end
hold(ax, 'off');
st = style;
st.XLim = [];
st.YLim = [];
styleAxes(ax, st);
grid(ax, 'off');
xlim(ax, R.edges([1 end]));
ylim(ax, [0.5 nG + 0.5]);
[labels, yName] = rowLabels(R);
if nG <= 40
    set(ax, 'YTick', 1:nG, 'YTickLabel', labels(1:nG), 'TickLabelInterpreter', 'none');
end
cb = tagPart(colorbar(ax), "colorbar");
cb.Label.String = d.units;
if look.panel.sharesTime && inTimeColumn(look)
    cb.Location = 'east';   % beside the axes it would narrow them, out of line with the time panels above and below
end
end


function cmap = heatColormap(o, style, auroc)
%heatColormap  A PSTH heat map's colormap: options.colormap, else Style.HeatColormap, else the design's heat colormap.
%   As a heat map panel picks it (an auROC: the design's diverging colormap
%   first); a colormap name that is no colormap function takes the default.
if o.colormap ~= "" && ismember(exist(char(o.colormap)), [2 5]) %#ok<EXIST>
    try
        cmap = feval(char(o.colormap), 256);
        if ismatrix(cmap) && size(cmap, 2) == 3 && size(cmap, 1) >= 2; return; end
    catch
    end
end
if style.HeatColormap ~= ""
    cmap = feval(char(style.HeatColormap), 256);
    return
end
maps = "heat";
if auroc; maps = ["diverging" "heat"]; end   % centered on chance, 0.5
cmap = designColormap(style, maps, "parula");
end


function P = heatNotes(P, items, names, Ls)
%heatNotes  P with a note for every item a heat map leaves out (it draws the first only), for figLayerNotes.
%   A further layer is noted as its own skip; the first layer's further
%   units as one more entry, "<layer>: N more ...".
why = "not in the heat map, which draws one item: " + names(1);
j1 = items(1, 1);
for j = reshape(unique(items(2:end, 1)), 1, [])
    if j ~= j1
        P.layers(j).skip = why;
        continue
    end
    e = P.layers(j);
    if e.name == "" && j <= numel(Ls); e.name = Ls(j).name; end
    if e.name == ""; e.name = e.source; end
    e.skip = sum(items(2:end, 1) == j) + " more " + why;
    P.layers(end+1) = e;
end
end


function [yName, lss] = drawRows(ax, D, Ls, items, hl, style, o)
%drawRows  The stack: the first item's rows by drawStack, every further item drawn into the same rows as an outline.
%   The rows' layout (stackLayout, Zero: every row from its zero) is
%   taken from every item's reach in each row (its PSTH, and its band with
%   Style.ShowSEM), so each fits its rows; the y limits of both sides then
%   cover every item's reach.
nI = numel(D);
nG = size(D(1).m, 2);
lss = strings(1, nI);
rlo = NaN(1, nG);
rhi = NaN(1, nG);
for i = 1:nI
    for g = 1:min(nG, size(D(i).m, 2))
        v = D(i).m(:, g);
        if style.ShowSEM; v = [v; D(i).lo(:, g); D(i).hi(:, g)]; end %#ok<AGROW>
        v = v(isfinite(v));
        if isempty(v); continue; end
        rlo(g) = min([rlo(g); v]);
        rhi(g) = max([rhi(g); v]);
    end
end
hl.layout = stackLayout(rlo, rhi, o.stackSpacing, Zero=true);
P1 = struct('m', D(1).m, 'lo', D(1).lo, 'hi', D(1).hi, 'peak', D(1).peak, ...
    'peakLabel', "Peak (" + D(1).R.units + ")");
if o.normalize ~= "none" && ~isAuroc(D(1).R); P1.peakLabel = "Peak (normalized)"; end
if D(1).u == 0; P1.peak = max(D(1).m, [], 1).'; end
if isAuroc(D(1).R)   % behind the rows
    hold(ax, 'on');
    modulationWindow(ax, D(1).R);
    hold(ax, 'off');
end
[~, base] = drawStack(ax, P1, D(1).R, D(1).colors, style, hl, struct('left', false, 'right', true));   % its line styles: groupLineStyles (combine)
[~, yName] = rowLabels(D(1).R);
[~, lss(1)] = figLayerLook(Ls(items(1, 1)), 1, D(1).colors(1, :));
lss(1) = figSeriesStyle(D(1).R, 1, lss(1), Ls(items(1, 1)));
yyaxis(ax, 'left');
hasMembers = any(arrayfun(@(d) ~isempty(d.members), D));
if hasMembers   % each member session, faint, in its series' row (a result merged across sessions, ShowMembers)
    hold(ax, 'on');
    for i = 1:nI
        if isempty(D(i).members); continue; end
        sr = double(D(i).R.members.series(:)).';   % the row of each member's series
        memberLines(ax, D(i).R.t, D(i).members .* hl.layout.scale(sr) + base(sr), D(i).R, D(i).colors, style);
    end
    hold(ax, 'off');
end
if nI < 2; return; end
yl = ylim(ax);
lo = yl(1); hi = yl(2);
hold(ax, 'on');
out = hl;
out.fill = false;
for i = 2:nI
    j = items(i, 1);
    for g = 1:min(nG, size(D(i).m, 2))
        b = base(g);
        k = hl.layout.scale(g);
        gl = string(D(i).R.groups.label(g));
        [c, ls] = figLayerLook(Ls(j), i, D(i).colors(g, :));
        ls = figSeriesStyle(D(i).R, g, ls, Ls(j));
        lss(i) = ls;
        tg = groupTag(D(i).name, gl, nI, nG);
        if style.ShowSEM
            errorPatch(ax, D(i).R.t, k * D(i).lo(:, g) + b, k * D(i).hi(:, g) + b, c, tg, style);
        end
        histTrace(ax, D(i).R.t, D(i).R.edges, k * D(i).m(:, g), b, c, out, style.LineWidth, tg, ls);
        reach = k * D(i).m(:, g);
        if style.ShowSEM; reach = [reach; k * D(i).hi(:, g)]; end %#ok<AGROW>
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
