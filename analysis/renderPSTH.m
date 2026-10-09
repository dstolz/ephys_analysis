function h = renderPSTH(R, target, opts)
%renderPSTH  Draw a spikePSTH result: rate traces per group, with rasters.
%   H = renderPSTH(R, TARGET, Name=Value) draws into TARGET: an axes or
%   uiaxes (one panel: the first unit of the page, no raster), or a figure,
%   uifigure, panel, tab, grid layout or tiled layout (a tiled layout of
%   panels is made inside). Renderers never create figures.
%
%   Options
%     Layout      "grid" (default): one tile per unit;
%                 "overlay": one panel with the mean over units (+/- SEM
%                 across units); a single unit is shown as itself
%     WithRaster  a raster above each rate panel (default true; grid, or
%                 overlay of one unit), flush on the same time axis: the
%                 two are a 2 x 1 tiled layout in the unit's tile
%     SortBy      the raster's epoch order within a group: "" (default)
%                 time order, "stop" stop event latency, "event" the
%                 latency to R.rasterSortEvent, or a column of R.epochs
%                 (see renderRaster)
%     SortOrder   "ascending" (default) | "descending": SortBy's direction
%     ByGroup     true (default): the raster's rows by group first; false:
%                 every epoch sorted as one block (see renderRaster)
%     EventMarks  how the raster marks R.rasterEvents (see renderRaster)
%     HistStyle   "bar" (default): one bar per bin; "line": a trace through
%                 the bin centers. SEM is a band behind either
%     Fill        true (default): the bars, or the area under the line,
%                 filled; false: the bars' outline, or the line alone
%     FillAlpha   fill opacity 0-1; NaN (default) = 0.5 where groups are
%                 overlaid, else 1
%     Normalize   "none" (default); "unitPeak": each unit's PSTHs divided by
%                 their largest absolute value over every group (the groups
%                 keep their sizes); "groupPeak": each PSTH divided by its
%                 own. The overlay layout normalizes each unit before the
%                 mean
%     Stack       false (default): groups overlaid; true: one row per
%                 group, the first at the bottom, a row's baseline labeled
%                 with its group's value on the left axis and its peak with
%                 the peak's value on the right axis (in R.units; the
%                 overlay layout's normalized mean in its own units). The
%                 raster above is flipped to match (first group at the
%                 bottom). A single group is not stacked
%     Spacing     stack: the row step as a multiple of the panel's tallest
%                 PSTH (default 1.1; below 1 the rows overlap, the lower in
%                 front)
%     Page        page of units in grid layout (MaxTiles per page)
%     Waveform    EphysAnalysisConfig.defaults("Waveform") fields: grid
%                 layout, each unit's waveform from R.waveforms
%                 (unitWaveforms) as a box in its rate panel -- its mean,
%                 a subsample of its spikes, or both -- at a compass point
%                 (location), with or without the box's outline (box), sized
%                 by scale (default mode "off": none)
%     Style       EphysAnalysisConfig.defaults("Style") fields (LineWidth,
%                 ShowSEM, ShowStop, ShowZeroLine, Colormap, FontSize, XLim,
%                 YLim, Grid, Legend, LegendLocation, LegendOrientation,
%                 LegendBox, MaxTiles, SortShank, SortDepth,
%                 LabelShank, LabelDepth: the grid's units go by shank, then
%                 top of the probe first, and are titled with their shank /
%                 depth); YLim is for the rate
%                 panels (the rasters show every epoch), and a stack
%                 ignores YLim and Legend (its rows are labeled)
%
%   An auROC result (spikePSTH BaselineMode "auroc") is drawn from 0.5, a
%   dotted line, on a 0-1 axis unless Style.YLim says otherwise; Normalize
%   does not apply. With a cutoff and R.auroc.settings.marks, the
%   modulation window is shaded and each unit's call sits at the right of
%   its title, one per group in the group's color: an up arrow, a down
%   arrow or n.s. (overlay: each group's count of units called up and
%   down).
%
%   A grid's x and y labels are its tiled layout's, once for every tile
%   (with rasters, the y label names the rates, then the rasters' rows);
%   its legend goes east of the grid unless Style.LegendLocation says
%   otherwise. A stack's right axis is labeled on the right column.
%
%   H: layout (tiled layout or []), axes (rate panels), rasterAxes, step
%   (each rate panel's row step in its y units; NaN when not stacked). A
%   raster and its rate panel get the same x limits; the axes are not
%   linked (a caller that wants linked zoom can link them).
%
%   See also spikePSTH, renderRaster, renderPlot.

arguments
    R (1,1) struct
    target
    opts.Layout (1,1) string {mustBeMember(opts.Layout, ["grid" "overlay"])} = "grid"
    opts.WithRaster (1,1) logical = true
    opts.SortBy (1,1) string = ""
    opts.SortOrder (1,1) string {mustBeMember(opts.SortOrder, ["ascending" "descending"])} = "ascending"
    opts.ByGroup (1,1) logical = true
    opts.EventMarks = struct()
    opts.HistStyle (1,1) string {mustBeMember(opts.HistStyle, ["bar" "line"])} = "bar"
    opts.Fill (1,1) logical = true
    opts.FillAlpha (1,1) double = NaN
    opts.Normalize (1,1) string {mustBeMember(opts.Normalize, ["none" "unitPeak" "groupPeak"])} = "none"
    opts.Stack (1,1) logical = false
    opts.Spacing (1,1) double {mustBePositive, mustBeFinite} = 1.1
    opts.Page (1,1) double {mustBePositive, mustBeInteger} = 1
    opts.Waveform = struct()
    opts.Style = struct()
end

style = renderStyle(opts.Style);
wave = EphysAnalysisConfig.normalizeSection("Waveform", opts.Waveform);
waves = [];
if isfield(R, 'waveforms') && opts.Layout == "grid"; waves = R.waveforms; end
colors = groupPalette(R.groups, style);
nU = size(R.rate, 2);
nG = size(R.rate, 3);
auroc = isAuroc(R);
norm = opts.Normalize;
if auroc; norm = "none"; end   % an auROC is on its own 0-1 scale
[rate, sem, yUnits] = normalizeRates(R, norm);
look = struct('hist', opts.HistStyle, 'fill', opts.Fill, 'alpha', opts.FillAlpha, ...
    'stack', opts.Stack && nG > 1, 'spacing', opts.Spacing);
if ~isfinite(look.alpha)
    look.alpha = 1;
    if nG > 1 && ~look.stack; look.alpha = 0.5; end
end
look.alpha = min(1, max(0, look.alpha));
h = struct('layout', [], 'axes', gobjects(0), 'rasterAxes', gobjects(0), 'step', zeros(1, 0));

if opts.Layout == "overlay" && nU > 1
    [tl, ax] = renderLayout(target, 1, 1);
    if isempty(ax); ax = nexttile(tl); end
    P.m = reshape(mean(rate, 2, 'omitnan'), [], nG);
    P.s = reshape(semOf(rate, 2), [], nG);
    P.peak = max(P.m, [], 1).';
    P.peakLabel = "Peak (" + R.units + ")";
    if norm ~= "none"; P.peakLabel = "Peak (normalized)"; end
    P.yUnits = yUnits;
    h.step = drawPanel(ax, P, R, colors, style, look, struct('legend', true, 'left', true, 'right', true, 'layout', tl, 'auto', 'best'));
    title(ax, sprintf('Mean of %d units', nU), 'FontWeight', 'normal');
    if auroc; callMarks(ax, R, 0, colors, style); end
    xlabel(ax, 'Time (s)');
    h.layout = tl; h.axes = ax;
    return
end

if opts.Layout == "overlay"
    idx = 1; nr = 1; nc = 1;
else
    [idx, nr, nc] = pageItems(nU, opts.Page, style.MaxTiles);
end
withRaster = opts.WithRaster && isfield(R, 'raster') && ~isempty(R.raster);
[tl, ax0] = renderLayout(target, nr, nc, style);
if ~isempty(ax0)
    idx = idx(1:min(1, end));
    withRaster = false;
end
axs = gobjects(1, numel(idx));
rax = gobjects(1, 0);
step = NaN(1, numel(idx));
names = siteLabels(shortUnitLabels(R.labels), R.meta, style);
order = probeOrder(R.meta, nU, style);
rows = "";
for j = 1:numel(idx)
    u = order(idx(j));
    r = ceil(j / nc); c = j - (r - 1) * nc;
    if ~isempty(ax0)
        ax = ax0;
    elseif withRaster
        % The raster and its rate panel share a tile, flush on one time axis;
        % the grid's spacing falls between the units.
        pair = tiledlayout(tl, 2, 1, 'TileSpacing', 'none', 'Padding', 'tight');
        pair.Layout.Tile = j;
        ra = nexttile(pair, 1);
        rows = rasterInto(ra, R, u, style, colors, opts.SortBy, ...
            struct('order', opts.SortOrder, 'byGroup', opts.ByGroup, 'marks', opts.EventMarks));
        tagPart(ra, "rasterAxes", "", names(u));
        if look.stack; set(ra, 'YDir', 'normal'); end
        ra.XTickLabel = [];
        title(ra, names(u), 'FontWeight', 'normal', 'Interpreter', 'none');
        rax(end+1) = ra; %#ok<AGROW>
        ax = nexttile(pair, 2);
    else
        ax = nexttile(tl, j);
    end
    tagPart(ax, "axes", "", names(u));
    P.m = reshape(rate(:, u, :), [], nG);
    P.s = reshape(sem(:, u, :), [], nG);
    P.peak = reshape(max(R.rate(:, u, :), [], 1), [], 1);
    P.peakLabel = "Peak (" + R.units + ")";
    P.yUnits = yUnits;
    step(j) = drawPanel(ax, P, R, colors, style, look, ...
        struct('legend', j == 1, 'left', false, 'right', c == nc || j == numel(idx), 'layout', tl, 'auto', "east"));
    waveformInset(ax, waves, u, wave, style);
    if ~withRaster
        title(ax, names(u), 'FontWeight', 'normal', 'Interpreter', 'none');
    end
    if auroc
        top = ax;
        if withRaster; top = rax(end); end
        callMarks(top, R, u, colors, style);
    end
    axs(j) = ax;
end
% One y label for the grid: the rates' (a stack's: its rows' parameters),
% then, reading up, the rasters' above them.
yName = yUnits;
if look.stack; [~, yName] = rowLabels(R); end
if rows ~= ""; yName = yName + "  ·  " + rows; end
gridLabels(tl, [axs rax], "Time (s)", yName, style);
if nr * nc > 1; tileTicks([rax axs], style); end
clearRasterEdge(rax);
h.layout = tl; h.axes = axs; h.rasterAxes = rax; h.step = step;
end


function clearRasterEdge(rax)
%clearRasterEdge  Drop the y ticks in the bottom tenth of each raster.
%   A raster sits right on its rate panel, so a label there would run into
%   the rate panel's top one. The bottom is the last epoch (YDir reverse),
%   or the first under a stack.
for ra = reshape(rax, 1, [])
    r = ra.YAxis(1);
    lim = double(r.Limits);
    tk = r.TickValues;
    up = tk - lim(1);
    if strcmp(ra.YDir, 'reverse'); up = lim(2) - tk; end
    keep = up >= 0.1 * diff(lim);
    if ~all(keep); r.TickValues = tk(keep); end
end
end


function [rate, sem, label] = normalizeRates(R, mode)
%normalizeRates  R.rate / R.sem divided per unit ("unitPeak") or per PSTH ("groupPeak").
%   The divisor is the largest absolute value (the peak, for rates); a unit
%   or PSTH with none is NaN. LABEL is the y axis label of what comes back.
rate = R.rate;
sem = R.sem;
label = R.units;
switch mode
    case "unitPeak"
        p = max(abs(rate), [], [1 3]);
        label = "Normalized (unit peak = 1)";
    case "groupPeak"
        p = max(abs(rate), [], 1);
        label = "Normalized (each peak = 1)";
    otherwise
        return
end
p(~(p > 0)) = NaN;
rate = rate ./ p;
sem = sem ./ p;
end


function callMarks(ax, R, u, colors, style)
%callMarks  Unit U's auROC call in each group, at the top right of AX (the title's line), in the group's color.
%   An up arrow (modulated upwards), a down arrow or n.s.; U = 0 (the
%   overlay's mean) gives each group's count of units called up and down.
A = R.auroc;
if A.cutoff == "none" || (isfield(A, 'settings') && ~A.settings.marks); return; end
nG = size(A.direction, 2);
parts = strings(1, nG);
for g = 1:nG
    c = string(sprintf('\\color[rgb]{%.3f,%.3f,%.3f}', colors(g, :)));
    if u == 0
        parts(g) = c + sprintf('\\uparrow%d \\downarrow%d', sum(A.direction(:, g) == "increase"), sum(A.direction(:, g) == "decrease"));
        continue
    end
    switch A.direction(u, g)
        case "increase", parts(g) = c + "\uparrow";
        case "decrease", parts(g) = c + "\downarrow";
        case "none",     parts(g) = c + "n.s.";
        otherwise,       parts(g) = c + "-";
    end
end
tagPart(text(ax, 1, 1, strjoin(parts, "  "), 'Units', 'normalized', 'HorizontalAlignment', 'right', ...
    'VerticalAlignment', 'bottom', 'Interpreter', 'tex', 'FontSize', style.FontSize, 'Clipping', 'off'), "modMarks");
end


function modulationWindow(ax, R)
%modulationWindow  Shade the auROC modulation window: the windows that decide each unit's call.
A = R.auroc;
if A.cutoff == "none" || (isfield(A, 'settings') && ~A.settings.marks); return; end
m = A.modulationWindow;
tagPart(xregion(ax, m(1), m(2), 'FaceColor', [0.5 0.5 0.5], 'FaceAlpha', 0.12, 'HandleVisibility', 'off'), "modWindow");
end


function step = drawPanel(ax, P, R, colors, style, look, show)
%drawPanel  One rate panel: the groups overlaid, or stacked in rows.
%   P: m / s [nBins x nGroups] (what is drawn), peak [nGroups x 1] and
%   peakLabel (the right axis of a stack), yUnits (the y label when
%   overlaid). SHOW: legend (overlaid), left / right (the axis labels),
%   layout (the grid's tiled layout, [] for one axes) and auto (the
%   legend's own place: placeLegend's AUTO).
if look.stack
    step = drawStack(ax, P, R, colors, style, look, show);
    return
end
step = NaN;
nG = size(P.m, 2);
ref = 0;
if isAuroc(R); ref = 0.5; end   % auROC: bars from chance, 0.5
hold(ax, 'on');
if ref ~= 0
    modulationWindow(ax, R);
end
if style.ShowSEM
    for g = 1:nG
        semBand(ax, R.t, P.m(:, g), P.s(:, g), colors(g, :), R.groups.label(g), style);
    end
end
lh = gobjects(1, nG);
for g = 1:nG
    lh(g) = histTrace(ax, R.t, R.edges, P.m(:, g) - ref, ref, colors(g, :), look, style.LineWidth, R.groups.label(g));
end
if style.ShowZeroLine
    tagPart(xline(ax, 0, ':', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off'), "zeroLine");
end
if ref ~= 0
    tagPart(yline(ax, ref, ':', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off'), "chanceLine");
end
if style.ShowStop && isfield(R, 'stopMean')
    for g = 1:nG
        if isfinite(R.stopMean(g))
            tagPart(xline(ax, R.stopMean(g), '--', 'Color', colors(g, :), 'HandleVisibility', 'off'), "stopLine", R.groups.label(g));
        end
    end
end
hold(ax, 'off');
xlim(ax, R.edges([1 end]));
styleAxes(ax, style);
if ref ~= 0 && isempty(style.YLim); ylim(ax, [0 1]); end
if show.left; ylabel(ax, P.yUnits); end
if show.legend && style.Legend && nG > 1
    placeLegend(ax, lh, R.groups.label, style, show.layout, show.auto);
end
end


function step = drawStack(ax, P, R, colors, style, look, show)
%drawStack  One row per group, the first at the bottom, step = Spacing x the tallest PSTH.
%   Left axis: a tick at each row's baseline, labeled with the group's
%   value (the groupBy parameters name the axis). Right axis: a tick where
%   each row peaks, labeled with P.peak (named by P.peakLabel). Rows are drawn top
%   down, so where they overlap the lower one is in front.
nG = size(P.m, 2);
tallest = max(P.m, [], 'all');
if ~(tallest > 0); tallest = max(abs(P.m), [], 'all'); end
if ~(tallest > 0); tallest = 1; end
step = look.spacing * tallest;
base = (0:nG-1) * step;
W = R.edges([1 end]);
yyaxis(ax, 'left');
ax.LineStyleOrder = '-';   % a yyaxis side cycles through markers ('o-', '^-', ...) otherwise
hold(ax, 'on');
lo = 0;
hi = base(end) + tallest;
for g = nG:-1:1
    b = base(g);
    tagPart(line(ax, W, [b b], 'Color', [0.72 0.72 0.72], 'LineWidth', 0.5, 'HandleVisibility', 'off'), "stackBase", R.groups.label(g));
    m = P.m(:, g);
    s = zeros(size(m));
    if style.ShowSEM
        semBand(ax, R.t, m + b, P.s(:, g), colors(g, :), R.groups.label(g), style);
        s = P.s(:, g);
        s(~isfinite(s)) = 0;
    end
    histTrace(ax, R.t, R.edges, m, b, colors(g, :), look, style.LineWidth, R.groups.label(g));
    if style.ShowStop && isfield(R, 'stopMean') && isfinite(R.stopMean(g))
        tagPart(line(ax, R.stopMean([g g]), b + [0 0.9 * min(step, tallest)], 'LineStyle', '--', 'Color', colors(g, :), ...
            'HandleVisibility', 'off'), "stopLine", R.groups.label(g));
    end
    lo = min([lo; b + m - s]);
    hi = max([hi; b + m + s]);
end
if style.ShowZeroLine
    tagPart(xline(ax, 0, ':', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off'), "zeroLine");
end
hold(ax, 'off');
pad = 0.03 * (hi - lo);
yl = [lo - pad, hi + pad];
xlim(ax, W);
flat = style;
flat.YLim = [];
styleAxes(ax, flat);
[labels, name] = rowLabels(R);
set(ax, 'YTick', base, 'YTickLabel', labels(1:nG), 'TickLabelInterpreter', 'none');
ylim(ax, yl);
if show.left; ylabel(ax, name, 'Interpreter', 'none'); end

yyaxis(ax, 'right');
ylim(ax, yl);
top = base(:) + max(P.m, [], 1).';
ok = isfinite(top) & isfinite(P.peak(:));
[tk, iu] = unique(top(ok));
txt = compose("%.3g", P.peak(ok));
set(ax, 'YTick', tk, 'YTickLabel', txt(iu));
if show.right; ylabel(ax, P.peakLabel, 'Interpreter', 'none'); end
yyaxis(ax, 'left');
set(ax.YAxis, 'Color', ax.XAxis.Color);
end


function hMain = histTrace(ax, t, e, m, base, color, look, lw, group)
%histTrace  One PSTH from BASE up: bars or a line, filled or not.
%   The fill patches are tagged "rateFill", the line or outline "rate",
%   both with GROUP (tagPart).
%   Filled: one patch per run of finite bins (FaceAlpha look.alpha), bars
%   as a staircase, a line with the area down to BASE under it. Unfilled
%   bars are the staircase outline, dropping to BASE at each run's ends.
%   Returns the object a legend shows (the bars' first patch or outline;
%   the line).
t = t(:); e = e(:); m = m(:);
ok = isfinite(m);
d = diff([false; ok; false]);
starts = find(d == 1);
stops = find(d == -1) - 1;
hMain = gobjects(0);
ox = zeros(0, 1); oy = zeros(0, 1);
for k = 1:numel(starts)
    r = (starts(k):stops(k)).';
    if look.hist == "bar"
        x = [e(r(1)); reshape([e(r) e(r + 1)].', [], 1); e(r(end) + 1)];
        y = [0; reshape([m(r) m(r)].', [], 1); 0] + base;
    else
        x = [t(r(1)); t(r); t(r(end))];
        y = [0; m(r); 0] + base;
    end
    if look.fill
        p = tagPart(patch(ax, x, y, color, 'FaceAlpha', look.alpha, 'EdgeColor', 'none'), "rateFill", group);
        if isempty(hMain) && look.hist == "bar"; hMain = p; else; p.HandleVisibility = 'off'; end
    end
    ox = [ox; x; NaN]; oy = [oy; y; NaN]; %#ok<AGROW>
end
if look.hist == "line"
    hMain = tagPart(plot(ax, t, m + base, 'Color', color, 'LineWidth', lw), "rate", group);
elseif ~look.fill && ~isempty(ox)
    hMain = tagPart(line(ax, ox, oy, 'Color', color, 'LineWidth', lw), "rate", group);
end
if isempty(hMain)
    hMain = tagPart(line(ax, NaN, NaN, 'Color', color, 'LineWidth', lw), "rate", group);
end
end


function [labels, name] = rowLabels(R)
%rowLabels  Each group's value (its groupBy columns) and the parameter names.
%   The parameters are the trial selection's groupBy (R.epochs' UserData,
%   from epochTable); a result without it (put together by hand) takes the
%   group table's columns other than its bookkeeping (index, label, color,
%   n, nTrials). Without any: the group labels, and "Group".
G = R.groups;
vars = string(G.Properties.VariableNames);
extra = string.empty(1, 0);
if isfield(R, 'epochs') && istable(R.epochs) && isfield(R.epochs.Properties.UserData, 'selection')
    extra = R.epochs.Properties.UserData.selection.groupBy;
end
if isempty(extra)
    extra = setdiff(vars, ["index" "label" "color" "n" "nTrials"], 'stable');
end
extra = extra(ismember(extra, vars));
if isempty(extra)
    labels = string(G.label);
    name = "Group";
    return
end
parts = strings(height(G), numel(extra));
for j = 1:numel(extra)
    v = G.(extra(j));
    if isnumeric(v) || islogical(v)
        parts(:, j) = compose("%.6g", double(v));
    else
        parts(:, j) = string(v);
    end
end
parts(ismissing(parts)) = "<missing>";
labels = join(parts, ", ", 2);
name = strjoin(extra, ", ");
end
