function h = renderHeatmap(R, target, opts)
%renderHeatmap  Units or channels by time, one tile per group.
%   H = renderHeatmap(R, TARGET, Order=, Style=) draws a spikePSTH result
%   (rows = units, rate) or an evokedPotential result (rows = channels, mean)
%   as an image per group, on one colour scale (Style.CLim, else the range
%   of every tile) with Style.HeatColormap ("" = parula).
%
%   Order
%     "depth"    (default) top of the probe first (probe y, else channel)
%     "channel"  by channel
%     "peak"     by the time of each row's maximum (over the groups' mean)
%
%   H: layout (tiled layout or []), axes, colorbar.
%
%   See also spikePSTH, evokedPotential, renderPlot.

arguments
    R (1,1) struct
    target
    opts.Order (1,1) string {mustBeMember(opts.Order, ["depth" "channel" "peak"])} = "depth"
    opts.Style = struct()
end

style = EphysAnalysisConfig.normalizeSection("Style", opts.Style);
switch R.kind
    case "psth",   V = R.rate; what = "Units";
    case "evoked", V = R.mean; what = "Channels";
    otherwise
        error('renderHeatmap:BadResult', 'A heatmap draws a psth or an evoked result, not "%s".', R.kind);
end
[~, nR, nG] = size(V);
t = R.t;
switch opts.Order
    case "depth"
        order = depthOrder(R.meta, nR);
    case "channel"
        order = (1:nR).';
        if istable(R.meta) && ismember("channel", string(R.meta.Properties.VariableNames))
            [~, order] = sortrows([double(R.meta.channel) (1:nR).']);
        end
    case "peak"
        m = mean(V, 3, 'omitnan');
        [~, pk] = max(m, [], 1);
        [~, order] = sortrows([pk(:) (1:nR).']);
end
clim0 = style.CLim;
if ~(numel(clim0) == 2 && clim0(2) > clim0(1))
    v = V(isfinite(V));
    if isempty(v); clim0 = [0 1]; else; clim0 = [min(v) max(v)]; end
    if clim0(2) <= clim0(1); clim0 = clim0 + [-0.5 0.5]; end
end
[idx, nr, nc] = pageItems(nG, 1, max(nG, 1));
[tl, ax0] = renderLayout(target, nr, nc);
if ~isempty(ax0); idx = idx(1:min(1, end)); end
cmapName = style.HeatColormap;
if cmapName == ""; cmapName = "parula"; end
cmap = feval(char(cmapName), 256);
axs = gobjects(1, numel(idx));
for j = 1:numel(idx)
    g = idx(j);
    if ~isempty(ax0); ax = ax0; else; ax = nexttile(tl, j); end
    M = V(:, order, g).';
    imagesc(ax, t, 1:nR, M, 'AlphaData', double(isfinite(M)));
    set(ax, 'YDir', 'reverse');
    colormap(ax, cmap);
    clim(ax, clim0);
    if style.ShowZeroLine; xline(ax, 0, '--', 'Color', [1 1 1], 'LineWidth', 1); end
    styleAxes(ax, style);
    grid(ax, 'off');
    ylim(ax, [0.5 nR + 0.5]);
    if nR <= 40
        set(ax, 'YTick', 1:nR, 'YTickLabel', shortUnitLabels(R.labels(order)), 'TickLabelInterpreter', 'none', ...
            'FontSize', max(6, style.FontSize - (nR > 20)));
    end
    title(ax, sprintf('%s (n = %d)', R.groups.label(g), R.n(g)), 'FontWeight', 'normal', 'Interpreter', 'none');
    if ceil(j / nc) == nr || ~isempty(ax0); xlabel(ax, 'Time (s)'); end
    if mod(j - 1, nc) == 0; ylabel(ax, what); end
    axs(j) = ax;
end
cb = gobjects(0);
if ~isempty(axs)
    cb = colorbar(axs(end));
    cb.Label.String = R.units;
    if ~isempty(tl); cb.Layout.Tile = 'east'; end
end
h = struct('layout', tl, 'axes', axs, 'colorbar', cb);
end
