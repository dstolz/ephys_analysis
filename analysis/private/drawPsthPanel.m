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
%   options.normalize divides the rates (normalizeRates); options.yLimMode
%   (panelYLimits) sets the y axis: "fixed" at options.yLim, "batch" at
%   the run's range, else from the data. Style.ShowZeroLine
%   draws the event's line, Style.ShowStop each group's mean stop latency
%   (R.stopMean, role "stopLine").
%   options.stack "groups" (with two or more groups) draws one row per
%   group, the first on top, as a raster lists them (drawStack in the rows
%   of a stackLayout: every row from its zero, the row step
%   options.stackSpacing x the row height; options.yLimMode "auto" scales
%   each row to its own reach, "rows" puts every row on one scale (the
%   tallest reach of any row's PSTH and band), "batch" on the run's range
%   and "fixed" on options.yLim; the rows' values on the left axis, their
%   peaks on the right); a further item is drawn into the same rows as an
%   outline. The groups are still offered to the figure's
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
%   options.latencyBox (enabled; not with display "heatmap") draws a box
%   plot of the first item's first-spike latencies (R.latency: the
%   figure's, its latency block's method and window, figureLatencies; a
%   layer's mean pools its units' epochs) per trial group,
%   along the time axis (latencyBoxStats: the box from the first to the
%   third quartile, a line at the median, whiskers to the most extreme
%   values within 1.5 IQR of the box, the values beyond as outliers), in
%   the group's color or one color, outlined in lineStyle / lineWidth, the
%   box filled at fillAlpha. Overlaid, the boxes sit in a band of their own
%   above the traces: the y range grows by a small gap and a lane of
%   boxHeight x its height per group (the first group's on top), so they
%   never cover a trace (nor options.yLim's range), and the y ticks stay on
%   the traces' range (whatever options.yLimMode sets it to; HK.yExtent is
%   the traces' range, not the band's). Stacked, each row holds its group's
%   box in a lane above its range (stackLayout's Above), the row step grown
%   to take it, so the box stays outside the row's values in every
%   yLimMode.
%   Roles "latencyBox", "latencyMedian", "latencyWhisker", "latencyOutlier"
%   (the group's label); each part carries its statistics (appdata
%   LatencyStats: n, nEpochs, q, whiskers, nOutliers, window, method) for its data
%   tip. A PSTH without the figure's latencies, or whose latency block
%   could not find them (no baseline before the event, say), says so in
%   its notes.
%   options.onsetLine ("unit" or "groups") draws the first item's unit's
%   response onset (R.onset: the figure's CUSUM onset) as a dashed line
%   across the axes, over every epoch or each group's in its color
%   (drawOnsetLines, role "latencyOnset"; a layer's mean has none: noted),
%   with a legend entry "Response onset".
%   options.trialCount says how many trials each group has (the epochs
%   the PSTH averages; R.nEpochs): "text" writes "n = 24" per group in the
%   group's color (role "trialCount", the group's label) in the top left
%   corner of the axes, the first group on top; stacked, at the right end
%   of each row's range; as a heat map, at the right end of each row.
%   "legend" appends " (n = 24)" to the group's legend entry (a heat map:
%   to its row's label); with one group, which has no legend entry, it
%   writes the text. The counts are read at draw time from the result, so
%   they follow the selection, the grouping and the artifact periods.
%   The events layers drawn as marks become latency lines and a rug
%   (figEventMarks, roles "eventLine" / "eventRug"), and with
%   options.waveform.mode on the first unit's waveform is an inset. Skipped
%   layers are noted (figLayerNotes). The legend offers the groups, then
%   the items when there are several, then the marks. A result merged
%   across sessions (figureSessionCompute) draws its series as the groups,
%   each member session (R.members) a pale line under them (memberLines,
%   divided as the series are: memberRates), and the trial groups of
%   trialGroups "combine" by line style (figSeriesStyle). HK: figDrawResult's,
%   yName = the rates' unit (a stack or a heat map: its rows' parameters),
%   yExtent a stack's reach in the rates' units (every row's, from 0), for
%   a run's batch range.
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
lb = EphysAnalysisConfig.defaults("LatencyBox");   % none on a spec without it
if isfield(o, 'latencyBox'); lb = EphysAnalysisConfig.normalizeSection("LatencyBox", o.latencyBox); end
boxes = [];   % the first item's first-spike latencies per trial group, as box plot statistics (latencyBoxes)
if lb.enabled && ~heat && nI > 0
    [boxes, why] = latencyBoxes(D(1), items(1, 2), lb);
    if why ~= ""
        P.layers(end+1) = P.layers(items(1, 1));
        P.layers(end).skip = why;
    end
end

cnt = struct('mode', "off", 'n', []);   % options.trialCount: each group's trials, as text or in its legend entry
if isfield(o, 'trialCount') && string(o.trialCount) ~= "off" && nI > 0
    cnt.n = trialCounts(D(1).R);
    cnt.mode = string(o.trialCount);
    if cnt.mode == "legend" && numel(cnt.n) < 2 && ~heat; cnt.mode = "text"; end   % one group has no legend entry
end

hl = struct('hist', o.histStyle, 'fill', o.fill, 'alpha', o.fillAlpha, 'stack', stacked);
if ~isfinite(hl.alpha)
    hl.alpha = 1;
    if nI > 0 && size(D(1).m, 2) > 1 && ~stacked; hl.alpha = 0.5; end
end
hl.alpha = min(1, max(0, hl.alpha));
lss = strings(1, nI);
if heat
    yName = drawHeat(ax, D(1), P.layers(items(1, 1)).name, look, o, style, cnt);
elseif stacked
    [yName, lss, hk.yExtent] = drawRows(ax, D, Ls, items, hl, style, o, look, boxes, lb, hasMarks, cnt);
    for g = 1:size(D(1).m, 2)   % the groups, for the figure's legend (the rows are labeled on the axis)
        gl = string(D(1).R.groups.label(g));
        hk.legendHandles(end+1) = tagPart(line(ax, NaN, NaN, 'Color', D(1).colors(g, :), 'LineWidth', style.LineWidth), "rate", gl);
        hk.legendLabels(end+1) = countLabel(gl, cnt, g);
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
                hk.legendLabels(end+1) = countLabel(gl, cnt, g);
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
    if cnt.mode == "text"
        countTexts(ax, cnt.n, D(1).R.groups.label, D(1).colors, style);
    end
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
    [~, yl] = panelYLimits(look);   % "fixed": yLim; "batch": the run's range; else the data's (an auROC: 0 to 1)
    flat = style;
    flat.XLim = [];
    flat.YLim = yl;
    styleAxes(ax, flat);
    if auroc && isempty(yl); ylim(ax, [0 1]); end
end
if auroc; callMarks(ax, D(1).R, D(1).u, D(1).colors, style); end

nGroups = size(look.colors, 1);
if nI > 0; nGroups = height(D(1).R.groups); end
colorBy = "group";
if heat; colorBy = "mark"; end   % over an image the latency lines take the marks' colors, as a heat map's do
[hm, lm] = figEventMarks(ax, P, look, 1:max(1, nGroups), colorBy);
onset = "off";   % the first item's unit's response onset: a line over every epoch, or each group's
if isfield(o, 'onsetLine'); onset = string(o.onsetLine); end
if onset ~= "off" && nI > 0
    [hOn, why] = onsetLines(ax, D(1), onset, style);
    if why ~= ""
        P.layers(end+1) = P.layers(items(1, 1));
        P.layers(end).skip = why;
    end
    if ~isempty(hOn)
        c = [0.25 0.25 0.25];
        if onset == "unit"; c = hOn(1).Color; end
        hk.legendHandles(end+1) = tagPart(line(ax, NaN, NaN, 'Color', c, 'LineStyle', '--', 'LineWidth', hOn(1).LineWidth), ...
            "latencyOnset");
        hk.legendLabels(end+1) = "Response onset";
        hk.legendGroup(end+1) = false;
    end
end
if ~isempty(boxes) && ~stacked   % above the traces, the rug and the spans: a band of their own
    hk.yExtent = ylim(ax);   % the traces' range (a run's batch range measures it, not the band)
    boxBand(ax, boxes, lb, style);
end
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


function yName = drawHeat(ax, d, layerName, look, o, style, cnt)
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
%   drawn behind an image). CNT (trialCount): "text" writes each row's
%   trials at its right end, "legend" adds them to its label.
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
if cnt.mode == "legend"
    for g = 1:min(nG, numel(cnt.n)); labels(g) = countLabel(labels(g), cnt, g); end
elseif cnt.mode == "text"
    W = R.edges([1 end]);
    for g = 1:min(nG, numel(cnt.n))
        tagPart(text(ax, W(2), g, countText(cnt.n(g)) + " ", 'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
            'Color', d.colors(min(g, size(d.colors, 1)), :), 'BackgroundColor', get(ax, 'Color'), 'Margin', 1, ...
            'FontSize', style.FontSize, 'Clipping', 'on', 'HitTest', 'off'), "trialCount", string(R.groups.label(g)));
    end
end
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


function [yName, lss, ext] = drawRows(ax, D, Ls, items, hl, style, o, look, boxes, lb, hasMarks, cnt)
%drawRows  The stack: the first item's rows by drawStack, every further item drawn into the same rows as an outline.
%   The rows' layout (stackLayout, Zero: every row from its zero; Mode and
%   Limits the panel's yLimMode: panelYLimits) is taken from every item's
%   reach in each row (its PSTH, and its band with Style.ShowSEM), so each
%   fits its rows; the y limits of both sides then cover every item's
%   reach. EXT: the rows' reach in the rates' units, [lo hi] (from 0), not
%   the latency lanes. With BOXES (latencyBoxes: a box per group) each row
%   also takes a lane above its range (stackLayout's Above: a gap of 0.05
%   and LB.boxHeight x the row height), so the box stays outside the row's
%   values in every yLimMode, the step taken from range, gap and lane
%   together; each group's box is drawn in its row's lane. With HASMARKS
%   the top grows a little more, so the marks' rug along the top edge
%   (figEventMarks) stays clear of the top row's box. CNT (trialCount):
%   "text" writes each row's trials at the right end of its range.
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
above = 0;   % the latency lanes: a gap and a lane above each row's range
if ~isempty(boxes); above = 0.05 + lb.boxHeight; end
[ymode, ylimits] = panelYLimits(look);
hl.layout = stackLayout(rlo, rhi, o.stackSpacing, Zero=true, Mode=ymode, Limits=ylimits, Above=above);
ext = [min([0 rlo]) max([0 rhi])];
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
if cnt.mode == "text"   % each row's trials, at the right end of its range
    W = D(1).R.edges([1 end]);
    hold(ax, 'on');
    for g = 1:min(nG, numel(cnt.n))
        tagPart(text(ax, W(2), hl.layout.top(g), countText(cnt.n(g)) + " ", 'HorizontalAlignment', 'right', ...
            'VerticalAlignment', 'top', 'Color', D(1).colors(min(g, size(D(1).colors, 1)), :), 'FontSize', style.FontSize, ...
            'Clipping', 'on', 'HitTest', 'off'), "trialCount", string(D(1).R.groups.label(g)));
    end
    hold(ax, 'off');
end
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
if ~isempty(boxes)   % each group's box in its row's lane, above the row's range
    Ly = hl.layout;
    lane = lb.boxHeight * Ly.height;
    hold(ax, 'on');
    for g = 1:min(nG, numel(boxes))
        drawBox(ax, boxes(g), Ly.top(g) + 0.05 * Ly.height + lane / 2, 0.35 * lane, lb, style);
    end
    hold(ax, 'off');
    if hasMarks   % room for the marks' rug along the top edge, clear of the top row's box
        yl = ylim(ax);
        yl(2) = yl(2) + 0.08 * diff(yl);
        ylim(ax, yl);
        yyaxis(ax, 'right');
        ylim(ax, yl);
        yyaxis(ax, 'left');
    end
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


function [B, why] = latencyBoxes(d, u, lb)
%latencyBoxes  The first item's first-spike latencies per trial group, as box plot statistics (one entry per group).
%   D is the item (drawPsthPanel's D(1)), U its unit (0: the layer's mean,
%   every unit of the layer pooled: one latency per unit and epoch). Each
%   entry: latencyBoxStats' fields, plus label (the group's), color (the
%   group's, or LB.color when it is one), nEpochs (the group's epochs x
%   units), window (the window searched) and method (the figure's rule).
%   B is empty, and WHY says why, when the result holds no latencies (the
%   figure's latencies were not taken for it) or the figure's block could
%   not find them.
B = [];
why = "";
R = d.R;
units = u;
if u == 0 && isfield(R, 'raster'); units = 1:numel(R.raster); end
if ~isfield(R, 'latency') || ~isstruct(R.latency) || ~isfield(R.latency, 'lat') || isempty(units) ...
        || any(units > size(R.latency.lat, 2))
    why = "no latency box plot: the PSTH holds no first-spike latencies (preview it again)";
    return
end
L = R.latency;
if L.why ~= ""
    why = "no latency box plot: " + L.why;
    return
end
nG = size(d.m, 2);
fixed = [];
c = strtrim(string(lb.color));
if c ~= "groups"
    try
        fixed = namedColor(c);
    catch
        % not a color: the groups' (validate warns)
    end
end
for g = 1:nG
    in = L.epochGroup == g;
    S = latencyBoxStats(L.lat(in, units));
    S.label = string(R.groups.label(g));
    S.color = d.colors(min(g, size(d.colors, 1)), :);
    if ~isempty(fixed); S.color = fixed; end
    S.nEpochs = nnz(in) * numel(units);
    S.window = L.window;
    S.method = string(L.method);
    if isempty(B); B = S; else; B(g) = S; end
end
end


function [h, why] = onsetLines(ax, d, mode, style)
%onsetLines  The item D's unit's response onset (R.onset: the figure's) across the axes, the unit's or each group's (drawOnsetLines); WHY when none can be drawn.
h = gobjects(1, 0);
why = "";
R = d.R;
if d.u == 0
    why = "no response onset: the layer's mean is no one unit";
    return
end
if ~isfield(R, 'onset') || ~isstruct(R.onset) || d.u > numel(R.onset.onset)
    why = "no response onset: the PSTH holds no onset (preview it again)";
    return
end
if R.onset.why ~= ""
    why = "no response onset: " + R.onset.why;
    return
end
h = drawOnsetLines(ax, R.onset, d.u, mode, d.colors, style);
end


function boxBand(ax, boxes, lb, style)
%boxBand  The overlaid PSTH's box plots in a band of their own above its y range: a lane per group, the first on top.
%   The y limits grow by a gap (4% of the range) and a lane of
%   LB.boxHeight x the range per box; the y ticks stay those of the range
%   the traces use.
yl = ylim(ax);
range = diff(yl);
if ~(range > 0); range = 1; end
yt = ax.YTick;
lane = lb.boxHeight * range;
top = yl(2) + 0.04 * range + numel(boxes) * lane;
ylim(ax, [yl(1) top]);
set(ax, 'YTick', yt(yt <= yl(2) + 1e-9 * range));
hold(ax, 'on');
for g = 1:numel(boxes)
    drawBox(ax, boxes(g), top - (g - 0.5) * lane, 0.35 * lane, lb, style);
end
hold(ax, 'off');
end


function drawBox(ax, B, yc, hh, lb, style)
%drawBox  One horizontal box plot along the time axis at height YC, the box 2 x HH high.
%   The box from the first to the third quartile (role "latencyBox"), the
%   median (a line twice as wide: "latencyMedian", in a pale shade of the
%   color over a fill above half opacity), the whiskers with their caps
%   ("latencyWhisker") and the outliers ("latencyOutlier"), every part in
%   B.color, tagged with B.label and carrying its statistics (appdata
%   LatencyStats). Nothing for a group with no latency.
if B.n == 0; return; end
c = B.color;
tg = B.label;
q = B.q;
w = B.whiskers;
ls = char(lb.lineStyle);
lw = lb.lineWidth;
stats = struct('n', B.n, 'nEpochs', B.nEpochs, 'q', q, 'whiskers', w, 'nOutliers', numel(B.outliers), 'window', B.window, ...
    'method', B.method);
mc = c;
if lb.fillAlpha > 0.5; mc = paleColor(c, 0.75, style); end
h = gobjects(1, 0);
h(end+1) = tagPart(patch(ax, 'XData', q([1 3 3 1]), 'YData', yc + hh * [-1 -1 1 1], 'FaceColor', c, 'FaceAlpha', lb.fillAlpha, ...
    'EdgeColor', c, 'LineStyle', ls, 'LineWidth', lw, 'HandleVisibility', 'off'), "latencyBox", tg);
h(end+1) = tagPart(line(ax, q([2 2]), yc + hh * [-1 1], 'Color', mc, 'LineWidth', 2 * lw, 'HandleVisibility', 'off'), ...
    "latencyMedian", tg);
cap = hh / 2;
X = [w(1) q(1) NaN q(3) w(2) NaN w(1) w(1) NaN w(2) w(2)];
Y = [yc yc NaN yc yc NaN yc - cap yc + cap NaN yc - cap yc + cap];
h(end+1) = tagPart(line(ax, X, Y, 'Color', c, 'LineStyle', ls, 'LineWidth', lw, 'HandleVisibility', 'off'), "latencyWhisker", tg);
if ~isempty(B.outliers) && lb.outlierMarker ~= "none"
    h(end+1) = tagPart(line(ax, B.outliers, repmat(yc, numel(B.outliers), 1), 'LineStyle', 'none', ...
        'Marker', char(lb.outlierMarker), 'MarkerSize', lb.outlierSize, 'Color', c, 'HandleVisibility', 'off'), "latencyOutlier", tg);
end
for k = 1:numel(h); setappdata(h(k), 'LatencyStats', stats); end
end


function n = trialCounts(R)
%trialCounts  The trials each group of a spikePSTH result has, [nGroups x 1]: R.nEpochs, else counted from R.epochGroup.
nG = height(R.groups);
if isfield(R, 'nEpochs') && numel(R.nEpochs) == nG
    n = double(R.nEpochs(:));
else
    g = double(R.epochGroup(:));
    n = accumarray(g(g >= 1 & g <= nG), 1, [nG 1]);
end
end


function s = countText(n)
%countText  A group's trials as text: "n = 24".
s = "n = " + string(n);
end


function label = countLabel(label, cnt, g)
%countLabel  A group's legend entry (or row label) with its trials, "<group> (n = 24)", when trialCount is "legend".
label = string(label);
if cnt.mode == "legend" && g <= numel(cnt.n)
    label = label + " (" + countText(cnt.n(g)) + ")";
end
end


function countTexts(ax, n, labels, colors, style)
%countTexts  Each group's trials, "n = 24" in the group's color, down the axes' top left corner, the first group on top.
%   One text object per group, tagged "trialCount" with the group's label.
for g = 1:numel(n)
    tagPart(text(ax, 0.02, 0.97 - (g - 1) * 0.085, countText(n(g)), 'Units', 'normalized', 'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'top', 'Color', colors(min(g, size(colors, 1)), :), 'FontSize', style.FontSize, 'Clipping', 'on', 'HitTest', 'off'), ...
        "trialCount", string(labels(g)));
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
