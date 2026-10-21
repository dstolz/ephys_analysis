function hk = drawRasterPanel(ax, P, look)
%drawRasterPanel  Draw a figure's raster panel: a row per epoch for each unit, train or layer, events as marks.
%   HK = drawRasterPanel(AX, P, LOOK) draws the panel result P
%   (F.panels(k) of EphysAnalysisRunner.computeFigure) into the axes AX,
%   as renderFigure asks (LOOK: style, colors, W, spec, panel, panelId,
%   isTop, isBottom, epochs, groups, observation, isTime). The point layers
%   (units, detected, events drawn as a train: spikePSTH results with
%   R.raster) give the blocks of rows, each layer's units in probe order:
%     the first block   rasterInto, as a raster plot draws one unit: a row
%                       per epoch (first on top), by group
%                       (options.rasterByGroup), sorted by
%                       options.rasterSort / rasterSortOrder; the stop
%                       dots (Style.ShowStop) and the zero line
%     each further one  under the first, a small gap between, through
%                       rasterInto's stack mode: each group a band of its
%                       own (the block as tall as the first), its epochs
%                       in the same sort; the y axis then names the blocks
%   The ticks are each group's color, as the PSTH's traces are; a layer's
%   own color (Color) draws that block's ticks in it, else options.tickColor
%   draws every tick in one color ("groups": each group's). options.tickWidth
%   (points; 0: the design's) is applied by renderFigure, over the design. options.backColor puts bands behind the
%   rows: none (the default), each group's pale band ("groups") or one
%   color for every group (a color also paints the axes behind them).
%   The y axis has no tick marks or labels (the epoch numbers) unless
%   options.yTicks; the names of further blocks stay either way.
%   The events layers drawn as marks (epochEvents) mark every block's rows
%   in their EventMark's look (rasterMarkLooks); those drawn as a span
%   (eventsAs "span") draw a line on every row from each interval's onset
%   to its offset (rasterInto's rasterSpans: the EventMark's color, else
%   the next automatic mark color, its spanStyle, spanWidth and spanAlpha;
%   role "eventSpan"). options.firstSpike (enabled) marks each epoch's
%   first spike at or after its minSec and at or before its maxSec
%   (firstSpikeLatency of that block's unit) on the epoch's row in every
%   block, over the ticks, wherever the sort, rasterByGroup or a further
%   block's band put the row (rasterInto; role "firstSpike", one line per
%   group). With options.waveform.mode
%   on, the first block's unit's waveform is an inset (waveformInset). A
%   skipped layer's reason is noted in the panel (figLayerNotes); a panel
%   with marks but no rows says they need some.
%   The legend offers the groups (tick swatches in their colors; with one
%   color for every tick, the groups' pale bands when there are any), the
%   marks and the first-spike marks ("First spike").
%   HK: figDrawResult's, yName = what the rows are and how they are sorted.
%
%   See also renderFigure, rasterInto, figurePanelRegistry.

style = look.style;
o = look.panel.options;
Ls = look.panel.layers;
hk = figDrawResult(ax);
tagPart(ax, "rasterAxes", "", look.panelId);

% the marks every block's rows carry
ev = [];
marks = [];
for j = 1:numel(P.layers)
    R = P.layers(j).R;
    if P.layers(j).skip ~= "" || ~isstruct(R) || ~isfield(R, 'kind') || R.kind ~= "events" || isempty(R.marks); continue; end
    ev = [ev reshape(R.marks, 1, [])]; %#ok<AGROW>
    marks = [marks repmat(Ls(j).event, 1, numel(R.marks))]; %#ok<AGROW>
end
sp = [];   % the spans every block's rows carry: a line from each onset to its offset (eventsAs "span")
for j = 1:numel(P.layers)
    R = P.layers(j).R;
    if P.layers(j).skip ~= "" || ~isstruct(R) || ~isfield(R, 'spans'); continue; end
    e = Ls(j).event;
    sp = [sp struct('label', R.spans.label, 'epoch', R.spans.epoch, 'on', R.spans.on, 'off', R.spans.off, ...
        'color', rasterMarkColor(e.color, numel(ev) + numel(sp) + 1), 'style', e.spanStyle, 'width', e.spanWidth, ...
        'alpha', e.spanAlpha)]; %#ok<AGROW>
end

% the blocks: each spikePSTH layer's units, in probe order
blocks = struct('j', {}, 'u', {}, 'name', {});
for j = 1:numel(P.layers)
    lay = P.layers(j);
    R = lay.R;
    if lay.skip ~= "" || ~isstruct(R) || ~isfield(R, 'raster') || isempty(R.raster); continue; end
    nU = numel(R.raster);
    names = shortUnitLabels(R.labels);
    for u = reshape(probeOrder(R.meta, nU, style), 1, [])
        nm = names(u);
        if nU == 1 && lay.name ~= ""; nm = lay.name; end
        blocks(end+1) = struct('j', j, 'u', u, 'name', nm); %#ok<AGROW>
    end
end
if isempty(blocks)
    empty = "";
    if ~isempty(ev) || ~isempty(sp); empty = "Marks need rows: add a units, detected or train layer"; end
    figLayerNotes(ax, P, look, false, empty);
    return
end

R1 = P.layers(blocks(1).j).R;
colors = look.colors;
if size(colors, 1) ~= height(R1.groups); colors = groupPalette(R1.groups, style); end
fs = EphysAnalysisConfig.defaults("FirstSpike");   % none on a spec without it
if isfield(o, 'firstSpike'); fs = EphysAnalysisConfig.normalizeSection("FirstSpike", o.firstSpike); end
rl = struct('order', o.rasterSortOrder, 'byGroup', o.rasterByGroup, 'marks', {marks}, ...
    'tickColor', o.tickColor, 'backColor', o.backColor, 'firstSpike', fs);
flat = style;
flat.XLim = [];
if ~isempty(ev); R1.rasterEvents = ev; end
if ~isempty(sp); R1.rasterSpans = sp; end
rl1 = rl;
rl1.tickColor = blockTicks(o.tickColor, Ls(blocks(1).j));
rows = rasterInto(ax, R1, blocks(1).u, flat, colors, o.rasterSort, rl1);

nB = numel(blocks);
if nB > 1
    nE = numel(R1.epochGroup);
    nG = height(R1.groups);
    grp = double(R1.epochGroup(:));
    have = grp >= 1 & grp <= nG;
    cnt = accumarray(grp(have), 1, [nG 1]);
    present = find(cnt > 0).';
    band = max(1, sum(cnt)) / max(1, numel(present));   % each group's band in a further block
    gap = max(1, round(0.04 * nE));
    centers = zeros(1, nB);
    centers(1) = (nE + 1) / 2;
    edge = nE + 0.5;   % the lowest row so far, as seen (YDir reverse)
    for b = 2:nB
        base0 = edge + gap;
        base = NaN(1, nG);
        base(present) = base0 + (0:numel(present) - 1) * band;
        Rb = P.layers(blocks(b).j).R;
        if ~isempty(ev); Rb.rasterEvents = ev; end
        if ~isempty(sp); Rb.rasterSpans = sp; end
        rb = rl;
        rb.tickColor = blockTicks(o.tickColor, Ls(blocks(b).j));
        rb.into = struct('base', base, 'height', band, 'equal', false);
        rasterInto(ax, Rb, blocks(b).u, flat, colors, o.rasterSort, rb);
        centers(b) = base0 + numel(present) * band / 2;
        edge = base0 + numel(present) * band;
    end
    ylim(ax, [0.5 edge]);
    set(ax, 'YTick', centers, 'YTickLabel', cellstr([blocks.name]), 'TickLabelInterpreter', 'none');
elseif ~o.yTicks
    set(ax, 'YTick', []);   % one block: no epoch numbers on the y axis (options.yTicks)
end
if numel(look.W) == 2 && look.W(2) > look.W(1); xlim(ax, look.W); end

% a background color paints every band alike, and the axes behind them
back = strtrim(string(o.backColor));
if ~ismember(back, ["" "none" "groups"])
    try
        set(ax, 'Color', validatecolor(back));
    catch
        % not a color: no bands (rasterInto ignores it too)
    end
end

% legend: the groups (a tick in their color; with one color for every tick, their pale band when the bands show
% them) and the marks (their markers)
nG = height(R1.groups);
oneColor = ~isempty(rl1.tickColor) && isColorSpec(rl1.tickColor);
shown = 1:nG;   % the groups with an entry
if nG < 2 || (oneColor && back ~= "groups"); shown = []; end
for g = shown
    if oneColor
        hk.legendHandles(end+1) = tagPart(patch(ax, 'XData', NaN, 'YData', NaN, 'FaceColor', paleColor(colors(g, :), 0.82, style), ...
            'EdgeColor', 'none'), "rasterBand", R1.groups.label(g));
    else
        hk.legendHandles(end+1) = tagPart(line(ax, NaN, NaN, 'Color', colors(g, :), 'LineWidth', 0.5), ...
            "rasterTicks", R1.groups.label(g));
    end
    hk.legendLabels(end+1) = string(R1.groups.label(g));
    hk.legendGroup(end+1) = true;
end
if ~isempty(ev)
    mk = rasterMarkLooks(marks, [ev.label]);
    for m = 1:numel(ev)
        if any(hk.legendLabels(~hk.legendGroup) == ev(m).label); continue; end
        hk.legendHandles(end+1) = tagPart(line(ax, NaN, NaN, 'LineStyle', 'none', 'Marker', mk(m).marker, ...
            'MarkerSize', mk(m).size, 'Color', mk(m).color, 'MarkerFaceColor', mk(m).color), "rasterEvent", ev(m).label);
        hk.legendLabels(end+1) = ev(m).label;
        hk.legendGroup(end+1) = false;
    end
end
if fs.enabled && ~isempty(findall(ax, 'Tag', 'firstSpike'))   % the first-spike marks: one entry, in their one color (else gray)
    c = [0.25 0.25 0.25];
    if nG == 1; c = colors(1, :); end
    if isColorSpec(fs.color); c = validatecolor(char(fs.color)); end
    face = 'none';
    if fs.filled; face = c; end
    hk.legendHandles(end+1) = tagPart(line(ax, NaN, NaN, 'LineStyle', 'none', 'Marker', char(fs.marker), 'MarkerSize', fs.size, ...
        'Color', c, 'MarkerFaceColor', face), "firstSpike");
    hk.legendLabels(end+1) = "First spike";
    hk.legendGroup(end+1) = false;
end
for m = 1:numel(sp)
    if any(hk.legendLabels(~hk.legendGroup) == sp(m).label); continue; end
    hk.legendHandles(end+1) = tagPart(line(ax, NaN, NaN, 'Color', [sp(m).color sp(m).alpha], 'LineStyle', char(sp(m).style), ...
        'LineWidth', sp(m).width), "eventSpan", sp(m).label);
    hk.legendLabels(end+1) = sp(m).label;
    hk.legendGroup(end+1) = false;
end

wave =EphysAnalysisConfig.normalizeSection("Waveform", o.waveform);
Rw = P.layers(blocks(1).j).R;
if wave.mode ~= "off" && isfield(Rw, 'waveforms')
    waveformInset(ax, Rw.waveforms, blocks(1).u, wave, style);
end
figLayerNotes(ax, P, look, true);
hk.yName = rows;
end


function spec = blockTicks(spec, L)
%blockTicks  The tick color spec of the block of layer L: the layer's own color when it has one, else the panel's (OPTIONS.TICKCOLOR; "groups" = each group's).
if isfield(L, 'color') && isColorSpec(L.color); spec = L.color; end
end


function tf = isColorSpec(spec)
%isColorSpec  Whether SPEC is a color name or hex code ("" and "auto" are not).
tf = false;
spec = strtrim(string(spec));
if ~isscalar(spec) || spec == ""; return; end
try
    validatecolor(char(spec));
    tf = true;
catch
    % not a color
end
end
