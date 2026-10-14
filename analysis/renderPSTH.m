function h = renderPSTH(R, target, opts)
%renderPSTH  Draw a spikePSTH result: rate traces per group, with rasters.
%   H = renderPSTH(R, TARGET, Name=Value) draws into TARGET: an axes or
%   uiaxes (one panel: the first unit of the page, no raster), or a figure,
%   uifigure, panel, tab, grid layout or tiled layout (a tiled layout of
%   panels is made inside). Renderers never create figures.
%
%   Options
%     Layout      "grid" (default): one tile per unit;
%                 "overlay": one panel with the mean over units (its error
%                 band across the units, Style.ErrorType); a single unit
%                 is shown as itself
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
%                 the bin centers. The error band (R.err: mean +/- SEM or
%                 SD, or a bootstrap 95% CI, over the epochs) is behind
%                 either, as patches in Style's Error* look (errorPatch)
%     Fill        true (default): the bars, or the area under the line,
%                 filled; false: the bars' outline, or the line alone
%     FillAlpha   fill opacity 0-1; NaN (default) = 0.5 where groups are
%                 overlaid, else 1
%     Normalize   "none" (default); "unitPeak": each unit's PSTHs divided by
%                 their largest absolute value over every group (the groups
%                 keep their sizes); "groupPeak": each PSTH divided by its
%                 own; "allPeak": every PSTH of every unit divided by the
%                 largest of them all (the PSTHs keep their sizes). The overlay layout normalizes each unit before the
%                 mean
%     Stack       false (default): groups overlaid; true: one row per
%                 group, the first at the bottom, a row's baseline labeled
%                 with its group's value on the left axis and its peak with
%                 the peak's value on the right axis (in R.units; the
%                 overlay layout's normalized mean in its own units). The
%                 raster above is flipped to match (first group at the
%                 bottom). A single group is not stacked
%     StackRaster stack with WithRaster: false (default): the raster in a
%                 panel above; true: each group's raster in its own row,
%                 just above its PSTH (as tall as the tallest PSTH, its
%                 epochs first at the bottom; grid layout, or overlay of
%                 one unit), and no raster panel
%     StackRasterEqual  StackRaster: true: every row's raster ticks one
%                 height, that of the row showing the most epochs, a row
%                 with fewer filled from the bottom; false (default): each
%                 row's epochs fill its raster
%     StackRasterTrials  StackRaster: the most epochs a row's raster shows
%                 (default Inf: all), picked evenly over its sorted order;
%                 the PSTH still averages every epoch
%     Spacing     stack: the row step as a multiple of the panel's tallest
%                 PSTH, or with StackRaster of a row's height (its tallest
%                 PSTH and its band, then the raster) (default 1.1; below 1
%                 the rows overlap, the lower in front)
%     Page        page of units in grid layout (MaxTiles per page)
%     Waveform    EphysAnalysisConfig.defaults("Waveform") fields: grid
%                 layout, each unit's waveform from R.waveforms
%                 (unitWaveforms) as a box in its rate panel -- its mean,
%                 a subsample of its spikes, or both -- at a compass point
%                 (location), with or without the box's outline (box), sized
%                 by scale (default mode "off": none)
%     Aux         EphysAnalysisConfig.defaults("Aux") fields: with a mode
%                 other than "off" (default "off": none), the mean aux
%                 signal R.aux (auxMean) in every unit's tile, by its
%                 placement: "below" or "above" -- a panel of its own,
%                 half a rate panel high, under the rate panel or over the
%                 raster, flush on the same time axis -- or "over" the
%                 rate panel, on its right y axis. A stack's right axis is
%                 its rows' peaks, so "over" goes below a stack; an axes
%                 TARGET has room for "over" only. Each trace is drawn as
%                 auxLooks says (colorBy: the trial group's color or a
%                 channel's own, the other by line style), its error band
%                 (R.aux.err) with errorType (not "off"); several
%                 channels get legend entries (in the aux panel's own
%                 legend under a stack). display "lines" is a line a
%                 trace; "stacked", a row each; "heatmap", an image (a
%                 panel of its own, no bands: "over" goes below).
%                 yLim fixes the signal's y limits (a row's span; the color
%                 scale); overPosition ([bottom top], fractions of the
%                 rate panel's height) is where it sits over the panel
%                 (auxInto)
%     Style       EphysAnalysisConfig.defaults("Style") fields (LineWidth,
%                 ShowSEM, ErrorType (the overlay's band across units),
%                 ErrorResamples, the bands' look (ErrorFaceColor,
%                 ErrorFaceAlpha, ErrorEdgeColor, ErrorEdgeStyle,
%                 ErrorEdgeWidth), ShowStop, ShowZeroLine, Colormap, FontSize, XLim,
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
%   A result merged across sessions (combineSessions) draws like any other;
%   with R.members (ShowMembers) each member session is a thin pale line in
%   its series' color under the error bands (role "memberLine", out of the
%   legend; the overlay layout: each member's mean over the tiles; not in
%   a stack), and with R.groups.lineStyle (TrialGroups "combine") each
%   series' line takes its style.
%
%   A grid's x and y labels are its tiled layout's, once for every tile
%   (with rasters, the y label names the rates, then the rasters' rows);
%   its legend goes east of the grid unless Style.LegendLocation says
%   otherwise. A stack's right axis is labeled on the right column.
%
%   H: layout (tiled layout or []), axes (rate panels), rasterAxes,
%   auxAxes (the aux panels, tagged "auxAxes"), step (each rate panel's row
%   step in its y units; NaN when not stacked). A raster, its rate panel
%   and its aux panel get the same x limits; the axes are not linked (a
%   caller that wants linked zoom can link them). A grid's y label names
%   the panels of a tile from the bottom up ("|AUX| (V)  ·  spikes/s  ·
%   Epoch"); the aux on the right axis is named there on the right column.
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
    opts.EventMarks = []
    opts.HistStyle (1,1) string {mustBeMember(opts.HistStyle, ["bar" "line"])} = "bar"
    opts.Fill (1,1) logical = true
    opts.FillAlpha (1,1) double = NaN
    opts.Normalize (1,1) string {mustBeMember(opts.Normalize, ["none" "unitPeak" "groupPeak" "allPeak"])} = "none"
    opts.Stack (1,1) logical = false
    opts.StackRaster (1,1) logical = false
    opts.StackRasterEqual (1,1) logical = false
    opts.StackRasterTrials (1,1) double {mustBePositive} = Inf
    opts.Spacing (1,1) double {mustBePositive, mustBeFinite} = 1.1
    opts.Page (1,1) double {mustBePositive, mustBeInteger} = 1
    opts.Waveform = struct()
    opts.Aux = struct()
    opts.Style = struct()
end

style = renderStyle(opts.Style);
wave = EphysAnalysisConfig.normalizeSection("Waveform", opts.Waveform);
auxOpt = EphysAnalysisConfig.normalizeSection("Aux", opts.Aux);
waves = [];
if isfield(R, 'waveforms') && opts.Layout == "grid"; waves = R.waveforms; end
colors = groupPalette(R.groups, style);
nU = size(R.rate, 2);
nG = size(R.rate, 3);
auroc = isAuroc(R);
norm = opts.Normalize;
if auroc; norm = "none"; end   % an auROC is on its own 0-1 scale
[rate, ~, yUnits, errLo, errHi, normBy] = normalizeRates(R, norm);
members = [];   % the member sessions' rates (combineSessions ShowMembers), divided like the series'
if isfield(R, 'members') && isstruct(R.members) && isfield(R.members, 'rate') && ~isempty(R.members.rate)
    members = memberRates(R, norm, normBy);
end
look = struct('hist', opts.HistStyle, 'fill', opts.Fill, 'alpha', opts.FillAlpha, ...
    'stack', opts.Stack && nG > 1, 'spacing', opts.Spacing, 'raster', []);
if ~isfinite(look.alpha)
    look.alpha = 1;
    if nG > 1 && ~look.stack; look.alpha = 0.5; end
end
look.alpha = min(1, max(0, look.alpha));
h = struct('layout', [], 'axes', gobjects(0), 'rasterAxes', gobjects(0), 'auxAxes', gobjects(0), 'step', zeros(1, 0));
place = "";   % where the mean aux signal goes: "" (none), "above", "below" (panels of their own) or "over"
X = [];
W = R.edges([1 end]);
if auxOpt.mode ~= "off" && isfield(R, 'aux') && isstruct(R.aux) && ~isempty(R.aux)
    place = auxPlace(auxOpt, look.stack);   % a stack's right axis is its rows' peaks; an image is not drawn on one
    X = auxLooks(R.aux, colors, style, auxOpt);
end
paneled = ismember(place, ["above" "below"]);

if opts.Layout == "overlay" && nU > 1
    [tl, ax] = renderLayout(target, 1, 1);
    xa = gobjects(0);
    if isempty(ax)
        [~, ax, xa] = tilePanels(tl, 1, false, place);
    elseif paneled
        place = "";   % one axes: no room for a panel
    end
    P.m = reshape(mean(rate, 2, 'omitnan'), [], nG);
    P.lo = NaN(size(P.m)); P.hi = P.lo;
    if style.ShowSEM   % the band across the units, of the style's error type
        [olo, ohi] = errorBounds(rate, 2, style.ErrorType, style.ErrorResamples);
        P.lo = reshape(olo, [], nG); P.hi = reshape(ohi, [], nG);
    end
    P.peak = max(P.m, [], 1).';
    P.peakLabel = "Peak (" + R.units + ")";
    if norm ~= "none"; P.peakLabel = "Peak (normalized)"; end
    P.yUnits = yUnits;
    P.members = [];
    if ~isempty(members); P.members = reshape(mean(members, 2, 'omitnan'), size(members, 1), []); end   % each member's mean over the tiles
    h.step = drawPanel(ax, P, R, colors, style, look, struct('legend', true, 'left', true, 'right', true, 'layout', tl, ...
        'auto', 'best', 'aux', legendAux(X, place, look)));
    top = ax;
    bottom = ax;
    if ~isempty(xa)
        auxInto(xa, R.aux, X, W, style, false, true, auxOpt);
        tagPart(xa, "auxAxes", "", "Mean");
        stackAuxLegend(xa, X, style, look);
        if place == "above"
            top = xa;
        else
            bottom = xa;
        end
    elseif place == "over"
        auxInto(ax, R.aux, X, W, style, true, true, auxOpt);
    end
    if ~isempty(xa); top.XTickLabel = []; end   % the upper of the two
    title(top, sprintf('Mean of %d units', nU), 'FontWeight', 'normal');
    if auroc; callMarks(top, R, 0, colors, style); end
    xlabel(bottom, 'Time (s)');
    auxEdgeTicks(xa, edgeOf(place));
    h.layout = tl; h.axes = ax; h.auxAxes = xa;
    return
end

if opts.Layout == "overlay"
    idx = 1; nr = 1; nc = 1;
else
    [idx, nr, nc] = pageItems(nU, opts.Page, style.MaxTiles);
end
withRaster = opts.WithRaster && isfield(R, 'raster') && ~isempty(R.raster);
inRows = withRaster && look.stack && opts.StackRaster;   % each group's raster in its row of the stack, not a panel
withRaster = withRaster && ~inRows;
[tl, ax0] = renderLayout(target, nr, nc, style);
if ~isempty(ax0)
    idx = idx(1:min(1, end));
    withRaster = false;
    if paneled; place = ""; end   % one axes: no room for a panel
end
axs = gobjects(1, numel(idx));
rax = gobjects(1, 0);
xax = gobjects(1, 0);
step = NaN(1, numel(idx));
names = siteLabels(shortUnitLabels(R.labels), R.meta, style);
order = probeOrder(R.meta, nU, style);
rows = "";
for j = 1:numel(idx)
    u = order(idx(j));
    r = ceil(j / nc); c = j - (r - 1) * nc;
    ra = gobjects(0);
    xa = gobjects(0);
    if ~isempty(ax0)
        ax = ax0;
    else
        [ra, ax, xa] = tilePanels(tl, j, withRaster, place);
    end
    top = ax;
    if ~isempty(ra)
        rows = rasterInto(ra, R, u, style, colors, opts.SortBy, ...
            struct('order', opts.SortOrder, 'byGroup', opts.ByGroup, 'marks', {opts.EventMarks}));
        tagPart(ra, "rasterAxes", "", names(u));
        if look.stack; set(ra, 'YDir', 'normal'); end
        ra.XTickLabel = [];
        rax(end+1) = ra; %#ok<AGROW>
        top = ra;
    end
    tagPart(ax, "axes", "", names(u));
    P.m = reshape(rate(:, u, :), [], nG);
    P.lo = reshape(errLo(:, u, :), [], nG);
    P.hi = reshape(errHi(:, u, :), [], nG);
    P.peak = reshape(max(R.rate(:, u, :), [], 1), [], 1);
    P.peakLabel = "Peak (" + R.units + ")";
    P.yUnits = yUnits;
    P.members = [];
    if ~isempty(members); P.members = reshape(members(:, u, :), size(members, 1), []); end
    if inRows
        look.raster = struct('u', u, 'sortBy', opts.SortBy, 'equal', opts.StackRasterEqual, 'trials', opts.StackRasterTrials, 'look', ...
            struct('order', opts.SortOrder, 'byGroup', true, 'marks', {opts.EventMarks}));
    end
    right = c == nc || j == numel(idx);
    step(j) = drawPanel(ax, P, R, colors, style, look, ...
        struct('legend', j == 1, 'left', false, 'right', right, 'layout', tl, 'auto', "east", 'aux', legendAux(X, place, look)));
    waveformInset(ax, waves, u, wave, style);
    if ~isempty(xa)
        auxInto(xa, R.aux, X, W, style, false, false, auxOpt);
        tagPart(xa, "auxAxes", "", names(u));
        if j == 1; stackAuxLegend(xa, X, style, look); end
        if place == "above"
            xa.XTickLabel = [];
            top = xa;
        else
            ax.XTickLabel = [];
        end
        xax(end+1) = xa; %#ok<AGROW>
    elseif place == "over"
        auxInto(ax, R.aux, X, W, style, true, right || ~isempty(ax0), auxOpt);
    end
    title(top, names(u), 'FontWeight', 'normal', 'Interpreter', 'none');
    if auroc
        callMarks(top, R, u, colors, style);
    end
    axs(j) = ax;
end
% One y label for the grid: the rates' (a stack's: its rows' parameters),
% then, reading up, the rasters' above them; an aux panel's below or above.
yName = yUnits;
if look.stack; [~, yName] = rowLabels(R); end
if rows ~= ""; yName = yName + "  ·  " + rows; end
if ~isempty(xax)
    if place == "below"
        yName = X.label + "  ·  " + yName;
    else
        yName = yName + "  ·  " + X.label;
    end
end
gridLabels(tl, [axs rax xax], "Time (s)", yName, style);
if nr * nc > 1; tileTicks([rax axs xax], style); end
clearRasterEdge(rax);
auxEdgeTicks(xax, edgeOf(place));
h.layout = tl; h.axes = axs; h.rasterAxes = rax; h.auxAxes = xax; h.step = step;
end


function [ra, ax, xa] = tilePanels(tl, j, withRaster, place)
%tilePanels  The axes of tile J of the grid TL, top to bottom, flush on one time axis.
%   RA: the raster (when WITHRASTER, else empty); AX: the rate panel; XA:
%   the aux panel (PLACE "above": at the top; "below": at the bottom; else
%   empty). Alone, the rate panel is the tile's axes; with a raster the two
%   share it as a 2 x 1 tiled layout; with an aux panel the raster and the
%   rate panel span two rows each and the aux panel one. The grid's spacing
%   falls between the units.
ra = gobjects(0);
xa = gobjects(0);
paneled = ismember(place, ["above" "below"]);
if ~withRaster && ~paneled
    ax = nexttile(tl, j);
    return
end
if ~paneled
    pair = tiledlayout(tl, 2, 1, 'TileSpacing', 'none', 'Padding', 'tight');
    pair.Layout.Tile = j;
    ra = nexttile(pair, 1);
    ax = nexttile(pair, 2);
    return
end
pair = tiledlayout(tl, 2 * (1 + withRaster) + 1, 1, 'TileSpacing', 'none', 'Padding', 'tight');
pair.Layout.Tile = j;
at = 1;
if place == "above"
    xa = nexttile(pair, at);
    at = at + 1;
end
if withRaster
    ra = nexttile(pair, at, [2 1]);
    at = at + 2;
end
ax = nexttile(pair, at, [2 1]);
if place == "below"; xa = nexttile(pair, at + 2); end
end


function x = legendAux(X, place, look)
%legendAux  The aux looks whose entries join the rate panel's legend ([]: none, or a stack's: no legend there).
x = [];
if place ~= "" && ~look.stack; x = X; end
end


function stackAuxLegend(xa, X, style, look)
%stackAuxLegend  A stack has no legend: its aux channels' entries go in the aux panel's own, inside it.
if ~look.stack || ~style.Legend || isempty(X.legend); return; end
[sh, sl] = auxStandIns(xa, X, style);
lgd = legend(xa, sh, cellstr(sl), 'Interpreter', 'none', 'FontSize', max(6, style.FontSize - 1), 'Location', 'best');
lgd.Box = matlab.lang.OnOffSwitchState(style.LegendBox);
end


function s = edgeOf(place)
%edgeOf  The edge an aux panel shares with the panel next to it (auxEdgeTicks).
s = "top";
if place == "above"; s = "bottom"; end
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
%   P: m / lo / hi [nBins x nGroups] (what is drawn: the means and their
%   error bands' edges), peak [nGroups x 1] and
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
ls = groupLineStyles(R);
hold(ax, 'on');
if ref ~= 0
    modulationWindow(ax, R);
end
if isfield(P, 'members') && ~isempty(P.members)   % each member session, faint, under its series
    memberLines(ax, R.t, P.members, R, colors, style);
end
if style.ShowSEM
    for g = 1:nG
        errorPatch(ax, R.t, P.lo(:, g), P.hi(:, g), colors(g, :), R.groups.label(g), style);
    end
end
lh = gobjects(1, nG);
for g = 1:nG
    lh(g) = histTrace(ax, R.t, R.edges, P.m(:, g) - ref, ref, colors(g, :), look, style.LineWidth, R.groups.label(g), ls(g));
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
if show.legend && style.Legend
    labels = reshape(string(R.groups.label), 1, []);
    if nG < 2; lh = gobjects(1, 0); labels = strings(1, 0); end
    if isfield(show, 'aux') && ~isempty(show.aux)   % the aux channels' entries (auxStandIns)
        [sh, sl] = auxStandIns(ax, show.aux, style);
        lh = [lh sh];
        labels = [labels sl];
    end
    if ~isempty(lh)
        placeLegend(ax, lh, labels, style, show.layout, show.auto);
    end
end
end


function step = drawStack(ax, P, R, colors, style, look, show)
%drawStack  One row per group, the first at the bottom, step = Spacing x the tallest PSTH.
%   Left axis: a tick at each row's baseline, labeled with the group's
%   value (the groupBy parameters name the axis). Right axis: a tick where
%   each row peaks, labeled with P.peak (named by P.peakLabel). Rows are drawn top
%   down, so where they overlap the lower one is in front. With look.raster
%   (u, sortBy, equal, trials, look: rasterInto's) each row also holds its group's raster,
%   as tall as the tallest PSTH, just above the highest reach of any row's
%   PSTH and band; the step is then Spacing x that row's height.
nG = size(P.m, 2);
tallest = max(P.m, [], 'all');
if ~(tallest > 0); tallest = max(abs(P.m), [], 'all'); end
if ~(tallest > 0); tallest = 1; end
rowHeight = tallest;
inRows = isfield(look, 'raster') && ~isempty(look.raster);
if inRows
    reach = tallest;
    if style.ShowSEM; reach = max([reach; P.hi(:)]); end
    gap = 0.05 * tallest;
    rasterAt = reach + gap;   % the raster's bottom, from the row's baseline
    rowHeight = rasterAt + tallest;
end
step = look.spacing * rowHeight;
base = (0:nG-1) * step;
W = R.edges([1 end]);
ls = groupLineStyles(R);
yyaxis(ax, 'left');
ax.LineStyleOrder = '-';   % a yyaxis side cycles through markers ('o-', '^-', ...) otherwise
hold(ax, 'on');
lo = 0;
hi = base(end) + rowHeight;
if inRows   % behind the rows' PSTHs
    rl = look.raster.look;
    rl.into = struct('base', base + rasterAt, 'height', tallest, 'equal', look.raster.equal, 'trials', look.raster.trials);
    rasterInto(ax, R, look.raster.u, style, colors, look.raster.sortBy, rl);
end
for g = nG:-1:1
    b = base(g);
    tagPart(line(ax, W, [b b], 'Color', [0.72 0.72 0.72], 'LineWidth', 0.5, 'HandleVisibility', 'off'), "stackBase", R.groups.label(g));
    m = P.m(:, g);
    elo = m; ehi = m;   % how far the row reaches: its band, where it has one
    if style.ShowSEM
        errorPatch(ax, R.t, P.lo(:, g) + b, P.hi(:, g) + b, colors(g, :), R.groups.label(g), style);
        f = isfinite(P.lo(:, g)); elo(f) = P.lo(f, g);
        f = isfinite(P.hi(:, g)); ehi(f) = P.hi(f, g);
    end
    histTrace(ax, R.t, R.edges, m, b, colors(g, :), look, style.LineWidth, R.groups.label(g), ls(g));
    if style.ShowStop && isfield(R, 'stopMean') && isfinite(R.stopMean(g))
        tagPart(line(ax, R.stopMean([g g]), b + [0 0.9 * min(step, tallest)], 'LineStyle', '--', 'Color', colors(g, :), ...
            'HandleVisibility', 'off'), "stopLine", R.groups.label(g));
    end
    lo = min([lo; b + elo]);
    hi = max([hi; b + ehi]);
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


function memberLines(ax, t, M, R, colors, style)
%memberLines  Each member session (R.members) as a thin pale line, under its series' summary.
%   M: [nBins x nMembers], the members' values on this panel. Tagged
%   "memberLine" with the series' label; kept out of the legend.
ls = groupLineStyles(R);
for s = 1:size(M, 2)
    g = R.members.series(s);
    tagPart(plot(ax, t, M(:, s), 'Color', paleColor(colors(g, :), 0.55, style), 'LineWidth', 0.6 * style.LineWidth, ...
        'LineStyle', ls(g), 'HandleVisibility', 'off'), "memberLine", R.groups.label(g));
end
end


function M = memberRates(R, norm, p)
%memberRates  R.members.rate [nBins x nTiles x nMembers] divided as normalizeRates divided the series (P: its divisor).
M = R.members.rate;
if norm == "none" || isempty(p); return; end
if size(p, 3) > 1   % groupPeak: each member by its series' peak
    p = p(:, :, R.members.series);
end
M = M ./ p;
end


function [labels, name] = rowLabels(R)
%rowLabels  Each group's value (its groupBy columns) and the parameter names.
%   The parameters are the trial selection's groupBy (R.epochs' UserData,
%   from epochTable); a result without it (put together by hand) takes the
%   group table's columns other than its bookkeeping (index, label, color,
%   n, nTrials). Without any: the group labels, and "Group". A result
%   merged across sessions (combineSessions: R.sessions) has series, not
%   trial groups, as its rows: their labels, named by what they are
%   ("Session", "Subject"; combine: "Session · trial group").
G = R.groups;
vars = string(G.Properties.VariableNames);
if isfield(R, 'sessions') && istable(R.sessions)
    labels = string(G.label);
    name = "Group";
    if isfield(R, 'sessionSeries') && isfield(R.sessionSeries, 'mode')
        switch R.sessionSeries.mode
            case "session", name = "Session";
            case "subject", name = "Subject";
        end
    end
    if ismember("lineStyle", vars)
        if name == "Group"; name = "Trial group"; else; name = name + " · trial group"; end
    end
    return
end
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
