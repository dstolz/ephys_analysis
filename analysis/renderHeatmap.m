function h = renderHeatmap(R, target, opts)
%renderHeatmap  Units or channels by time, one tile per group.
%   H = renderHeatmap(R, TARGET, Order=, Style=) draws a spikePSTH result
%   (rows = units, rate) or an evokedPotential result (rows = channels, mean)
%   as an image per group, on one color scale (Style.CLim, else the range
%   of every tile) with Style.HeatColormap ("" = parula).
%
%   Order
%     "probe"    (default) as Style.SortShank / Style.SortDepth say: by shank,
%                then top of the probe first (probe y); neither = as listed
%     "peak"     by the time of each row's maximum (over the groups' mean)
%     "modulation"  an auROC result's units by their mean auROC in the
%                modulation window in the first group, highest first; the
%                other tiles keep that order (as the paper's Fig 3A). Other
%                results: as "probe"
%   Style.LabelShank / Style.LabelDepth append the shank / depth to the row
%   labels. A result merged across sessions (combineSessions: R.sessions,
%   R.meta.session) keeps each session's rows together, in session order,
%   each session's rows in the Order chosen, with a thin line in the
%   ground's color between sessions (role "sessionDivider"); its row
%   labels name the session ("su12 · SYNTH-01 2026-09-08").
%
%   An auROC result (spikePSTH BaselineMode "auroc") is colored on [0 1]
%   unless Style.CLim says otherwise. With a cutoff and
%   R.auroc.settings.marks, a bar along each tile's top spans the
%   modulation window, and a red up or blue down triangle right of the
%   image marks each unit the group's call finds modulated.
%
%   The x and y labels and the color bar are the tiled layout's, once for
%   every tile.
%
%   Stack=true draws every group into one axes instead (TARGET an axes):
%   a block of rows per group, the first on top (as a raster lists its
%   groups), the blocks Spacing x a block's height apart (never
%   overlapping: below 1 counts as 1; stackLayout), every block in the
%   same row order and on the one color scale; a thin strip of each
%   group's color (Colors, one row per group; [] = groupPalette) along its
%   left edge (role "rasterBand") and a gray line between blocks (role
%   "stackBase"); the y axis names the groups at their blocks' middles
%   (the row labels are left out), the title names none. An auROC
%   result's modulation bar sits over the top block, each block's calls
%   right of its rows. H.groupHandles: a color swatch per group for a
%   legend (role "rasterBand").
%
%   H: layout (tiled layout or []), axes, colorbar (and with Stack,
%   groupHandles).
%
%   See also spikePSTH, evokedPotential, renderFigure.

arguments
    R (1,1) struct
    target
    opts.Order (1,1) string {mustBeMember(opts.Order, ["probe" "peak" "modulation"])} = "probe"
    opts.Style = struct()
    opts.Stack (1,1) logical = false
    opts.Spacing (1,1) double = 1.1
    opts.Colors double = []
end

style = renderStyle(opts.Style);
switch R.kind
    case "psth",   V = R.rate; what = "Units";
    case "evoked", V = R.mean; what = "Channels";
    otherwise
        error('renderHeatmap:BadResult', 'A heatmap draws a psth or an evoked result, not "%s".', R.kind);
end
[~, nR, nG] = size(V);
t = R.t;
auroc = R.kind == "psth" && isAuroc(R);
switch opts.Order
    case "peak"
        m = mean(V, 3, 'omitnan');
        [~, pk] = max(m, [], 1);
        [~, order] = sortrows([pk(:) (1:nR).']);
    otherwise
        order = probeOrder(R.meta, nR, style);
        if opts.Order == "modulation" && auroc
            [~, order] = sortrows([-R.auroc.mean(:, 1) (1:nR).']);   % highest first; NaN last
        end
end
session = [];   % a result merged across sessions: each row's session (rows are session-units)
if isfield(R, 'sessions') && istable(R.meta) && height(R.meta) == nR && ismember("session", string(R.meta.Properties.VariableNames))
    session = double(R.meta.session(:));
    order = order(:);
    [~, by] = sortrows([session(order) (1:nR).']);   % by session, each session's rows in the order chosen
    order = order(by);
    session = session(order);
end
labels = siteLabels(shortUnitLabels(R.labels), R.meta, style);
clim0 = style.CLim;
if ~(numel(clim0) == 2 && clim0(2) > clim0(1))
    v = V(isfinite(V));
    if isempty(v); clim0 = [0 1]; else; clim0 = [min(v) max(v)]; end
    if clim0(2) <= clim0(1); clim0 = clim0 + [-0.5 0.5]; end
    if auroc; clim0 = [0 1]; end
end
if opts.Stack
    h = drawStacked(R, target, V, t, order, session, labels, clim0, auroc, style, opts);
    return
end
[idx, nr, nc] = pageItems(nG, 1, max(nG, 1));
[tl, ax0] = renderLayout(target, nr, nc, style);
if ~isempty(ax0); idx = idx(1:min(1, end)); end
if style.HeatColormap == ""
    maps = "heat";
    if auroc; maps = ["diverging" "heat"]; end   % auROC: centerd on 0.5
    cmap = designColormap(style, maps, "parula");
else
    cmap = feval(char(style.HeatColormap), 256);
end
axs = gobjects(1, numel(idx));
for j = 1:numel(idx)
    g = idx(j);
    if ~isempty(ax0); ax = ax0; else; ax = nexttile(tl, j); end
    M = V(:, order, g).';
    tagPart(ax, "axes", "", R.groups.label(g));
    tagPart(imagesc(ax, t, 1:nR, M, 'AlphaData', double(isfinite(M))), "image", R.groups.label(g));
    set(ax, 'YDir', 'reverse');
    colormap(ax, cmap);
    clim(ax, clim0);
    if style.ShowZeroLine; tagPart(xline(ax, 0, '--', 'Color', [1 1 1], 'LineWidth', 1), "zeroLine"); end
    styleAxes(ax, style);
    grid(ax, 'off');
    ylim(ax, [0.5 nR + 0.5]);
    if auroc; heatMarks(ax, R, order, g, style); end
    for b = reshape(find(diff(session) ~= 0), 1, [])   % a thin line in the ground's color between sessions
        tagPart(yline(ax, b + 0.5, '-', 'Color', paleColor([0 0 0], 1, style), 'LineWidth', 1, 'HandleVisibility', 'off'), ...
            "sessionDivider", R.groups.label(g));
    end
    if nR <= 40
        set(ax, 'YTick', 1:nR, 'YTickLabel', labels(order), 'TickLabelInterpreter', 'none', ...
            'FontSize', max(6, style.FontSize - (nR > 20)));
    end
    title(ax, sprintf('%s (n = %d)', R.groups.label(g), R.n(g)), 'FontWeight', 'normal', 'Interpreter', 'none');
    axs(j) = ax;
end
gridLabels(tl, axs, "Time (s)", what, style);
cb = gobjects(0);
if ~isempty(axs)
    cb = colorbar(axs(end));
    cb.Label.String = R.units;
    if ~isempty(tl); cb.Layout.Tile = 'east'; end
end
h = struct('layout', tl, 'axes', axs, 'colorbar', cb);
end


function h = drawStacked(R, ax, V, t, order, session, labels, clim0, auroc, style, opts)
%drawStacked  Every group's rows as a block of one axes, the first on top (renderHeatmap's Stack).
[~, nR, nG] = size(V);
if style.HeatColormap == ""
    maps = "heat";
    if auroc; maps = ["diverging" "heat"]; end
    cmap = designColormap(style, maps, "parula");
else
    cmap = feval(char(style.HeatColormap), 256);
end
colors = opts.Colors;
if size(colors, 1) ~= nG; colors = groupPalette(R.groups, style); end
L = stackLayout(zeros(1, nG), repmat(nR, 1, nG), opts.Spacing, Image=true);
first = @(g) L.n * L.step - L.top(g);   % block g's first row sits just below this (YDir reverse: block 1 on top)
names = string(R.groups.label);
gh = gobjects(1, nG);
for g = 1:nG
    M = V(:, order, g).';
    y0 = first(g);
    hi = tagPart(imagesc(ax, t, y0 + (1:nR), M, 'AlphaData', double(isfinite(M))), "image", names(g));
    setappdata(hi, 'RowLabels', labels(order));   % its rows' units or channels, for the data tips
    if g == 1; hold(ax, 'on'); end   % imagesc resets an axes it does not hold
end
set(ax, 'YDir', 'reverse');
colormap(ax, cmap);
clim(ax, clim0);
xr = double(t([1 end]));
if numel(t) > 1; xr = xr(:).' + [-1 1] * median(diff(double(t(:)))) / 2; end
w = 0.025 * diff(xr);
for g = 1:nG
    y0 = first(g);
    tagPart(patch(ax, xr(1) + [0 w w 0], y0 + [0.5 0.5 nR + 0.5 nR + 0.5], colors(g, :), 'EdgeColor', 'none', ...
        'HandleVisibility', 'off'), "rasterBand", names(g));
    gh(g) = tagPart(patch(ax, 'XData', NaN, 'YData', NaN, 'FaceColor', colors(g, :), 'EdgeColor', 'none'), "rasterBand", names(g));
    if g > 1
        hb = tagPart(line(ax, xr, (y0 + 0.5) * [1 1], 'Color', [0.72 0.72 0.72], 'LineWidth', 0.5, 'HandleVisibility', 'off'), ...
            "stackBase", names(g));
        setappdata(hb, 'StackMap', [y0 1]);
    end
    for b = reshape(find(diff(session) ~= 0), 1, [])   % a thin line in the ground's color between sessions
        tagPart(yline(ax, y0 + b + 0.5, '-', 'Color', paleColor([0 0 0], 1, style), 'LineWidth', 1, 'HandleVisibility', 'off'), ...
            "sessionDivider", names(g));
    end
    if auroc; heatMarks(ax, R, order, g, style, y0, g == 1); end
end
if style.ShowZeroLine; tagPart(xline(ax, 0, '--', 'Color', [1 1 1], 'LineWidth', 1), "zeroLine"); end
hold(ax, 'off');
styleAxes(ax, style);
grid(ax, 'off');
ylim(ax, [first(1) + 0.5, first(nG) + nR + 0.5]);
mids = arrayfun(first, 1:nG) + (nR + 1) / 2;
[tk, o] = sort(mids);
set(ax, 'YTick', tk, 'YTickLabel', cellstr(names(o)), 'TickLabelInterpreter', 'none');
cb = colorbar(ax);
cb.Label.String = R.units;
h = struct('layout', [], 'axes', ax, 'colorbar', cb, 'groupHandles', gh);
end


function heatMarks(ax, R, order, g, style, y0, withBar)
%heatMarks  Tile G's auROC calls: a bar over the modulation window, a triangle right of each modulated row.
%   The x axis gains a margin right of the image for the triangles (unless
%   Style.XLim is set): red up, modulated upwards; blue down, downwards.
%   Y0 (default 0) shifts the rows (a stacked block's first row is at Y0 +
%   1); WITHBAR (default true) draws the modulation window's bar over the
%   rows (a stack: over its top block only).
if nargin < 6; y0 = 0; end
if nargin < 7; withBar = true; end
A = R.auroc;
if A.cutoff == "none" || (isfield(A, 'settings') && ~A.settings.marks); return; end
nR = numel(order);
if withBar
    tagPart(line(ax, A.modulationWindow, y0 + [0.5 0.5], 'Color', [0 0 0], 'LineWidth', 3, 'Clipping', 'off', ...
        'HandleVisibility', 'off'), "modWindow");
end
e = R.edges([1 end]);
margin = 0.05 * (e(2) - e(1));
if isempty(style.XLim); xlim(ax, [e(1), e(2) + margin]); end
d = A.direction(order, g);
fs = max(4, min(style.FontSize, round(240 / max(nR, 1))));
calls = ["increase" "decrease"];
glyphs = [char(9650) char(9660)];
colors = [0.85 0.15 0.1; 0.1 0.35 0.85];
for k = 1:2
    rows = find(d == calls(k));
    if isempty(rows); continue; end
    tagPart(text(ax, repmat(e(2) + margin / 2, numel(rows), 1), y0 + rows, glyphs(k), 'Color', colors(k, :), ...
        'FontSize', fs, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Clipping', 'off', ...
        'Interpreter', 'none'), "modMarks", calls(k));
end
end
