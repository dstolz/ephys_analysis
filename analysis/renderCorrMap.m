function h = renderCorrMap(R, target, opts)
%renderCorrMap  Unit-by-unit correlation matrices, one tile per group.
%   H = renderCorrMap(R, TARGET, Order=, Style=) draws a unitCorrelation
%   result as a square image per group on one colour scale (Style.CLim,
%   else [-1 1]) with Style.HeatColormap ("" = blueWhiteRed). Each tile's
%   title gives its group, the epochs used and the mean pairwise r.
%
%   Order
%     "depth"    (default) top of the probe first (probe y, else channel)
%     "channel"  by channel
%
%   H: layout (tiled layout or []), axes, colorbar.
%
%   See also unitCorrelation, renderHeatmap, renderPlot.

arguments
    R (1,1) struct
    target
    opts.Order (1,1) string {mustBeMember(opts.Order, ["depth" "channel"])} = "depth"
    opts.Style = struct()
end

style = EphysAnalysisConfig.normalizeSection("Style", opts.Style);
if R.kind ~= "corrmap"
    error('renderCorrMap:BadResult', 'A correlation map draws a corrmap result, not "%s".', R.kind);
end
nU = size(R.r, 1);
nG = size(R.r, 3);
order = depthOrder(R.meta, nU);
if opts.Order == "channel"
    order = (1:nU).';
    if istable(R.meta) && ismember("channel", string(R.meta.Properties.VariableNames))
        [~, order] = sortrows([double(R.meta.channel) (1:nU).']);
    end
end
clim0 = style.CLim;
if ~(numel(clim0) == 2 && clim0(2) > clim0(1)); clim0 = [-1 1]; end
cmapName = style.HeatColormap;
if cmapName == ""; cmapName = "blueWhiteRed"; end
cmap = feval(char(cmapName), 256);
[idx, nr, nc] = pageItems(nG, 1, max(nG, 1));
[tl, ax0] = renderLayout(target, nr, nc);
if ~isempty(ax0); idx = idx(1:min(1, end)); end
labels = R.labels(order);
axs = gobjects(1, numel(idx));
for j = 1:numel(idx)
    g = idx(j);
    if ~isempty(ax0); ax = ax0; else; ax = nexttile(tl, j); end
    M = R.r(order, order, g);
    imagesc(ax, 1:nU, 1:nU, M, 'AlphaData', double(isfinite(M)));
    set(ax, 'YDir', 'reverse', 'Color', [0.85 0.85 0.85]);
    colormap(ax, cmap);
    clim(ax, clim0);
    ax.FontSize = style.FontSize;
    box(ax, 'on');
    grid(ax, 'off');
    axis(ax, 'image');
    xlim(ax, [0.5 nU + 0.5]);
    ylim(ax, [0.5 nU + 0.5]);
    if nU <= 40
        fs = max(6, style.FontSize - (nU > 20));
        set(ax, 'XTick', 1:nU, 'XTickLabel', labels, 'YTick', 1:nU, 'YTickLabel', labels, ...
            'TickLabelInterpreter', 'none', 'XTickLabelRotation', 90, 'FontSize', fs);
    end
    t = string(sprintf('%s (n = %d', R.groups.label(g), R.nEpochs(g)));
    if isfinite(R.meanR(g)); t = t + sprintf(', mean r = %.2f', R.meanR(g)); end
    title(ax, t + ")", 'FontWeight', 'normal', 'Interpreter', 'none');
    if ceil(j / nc) == nr || ~isempty(ax0); xlabel(ax, 'Units'); end
    if mod(j - 1, nc) == 0; ylabel(ax, 'Units'); end
    axs(j) = ax;
end
cb = gobjects(0);
if ~isempty(axs)
    cb = colorbar(axs(end));
    cb.Label.String = corrName(R.type) + " (" + R.metric + " rate)";
    if ~isempty(tl); cb.Layout.Tile = 'east'; end
end
h = struct('layout', tl, 'axes', axs, 'colorbar', cb);
end


function s = corrName(type)
if type == "spearman"
    s = "Spearman's rho";
else
    s = "Pearson's r";
end
end
