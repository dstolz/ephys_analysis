function h = renderCorrMap(R, target, opts)
%renderCorrMap  Unit-by-unit correlation matrices, one tile per group.
%   H = renderCorrMap(R, TARGET, Style=) draws a unitCorrelation
%   result as a square image per group on one colour scale (Style.CLim,
%   else [-1 1]) with Style.HeatColormap ("" = blueWhiteRed). Each tile's
%   title gives its group, the epochs used and the mean pairwise r.
%
%   Units are ordered by Style.SortShank / Style.SortDepth (by shank, then
%   top of the probe first; neither = as listed) and labelled with their
%   shank / depth when Style.LabelShank / Style.LabelDepth say so: on the
%   outer tiles only, as every tile shares one order. The x and y labels
%   and the colour bar are the tiled layout's, once for every tile.
%
%   H: layout (tiled layout or []), axes, colorbar.
%
%   See also unitCorrelation, renderHeatmap, renderPlot.

arguments
    R (1,1) struct
    target
    opts.Style = struct()
end

style = renderStyle(opts.Style);
if R.kind ~= "corrmap"
    error('renderCorrMap:BadResult', 'A correlation map draws a corrmap result, not "%s".', R.kind);
end
nU = size(R.r, 1);
nG = size(R.r, 3);
order = probeOrder(R.meta, nU, style);
clim0 = style.CLim;
if ~(numel(clim0) == 2 && clim0(2) > clim0(1)); clim0 = [-1 1]; end
if style.HeatColormap == ""
    cmap = designColormap(style, "diverging", "blueWhiteRed");
else
    cmap = feval(char(style.HeatColormap), 256);
end
[idx, nr, nc] = pageItems(nG, 1, max(nG, 1));
[tl, ax0] = renderLayout(target, nr, nc, style);
if ~isempty(ax0); idx = idx(1:min(1, end)); end
labels = siteLabels(shortUnitLabels(R.labels), R.meta, style);
labels = labels(order);
axs = gobjects(1, numel(idx));
for j = 1:numel(idx)
    g = idx(j);
    if ~isempty(ax0); ax = ax0; else; ax = nexttile(tl, j); end
    M = R.r(order, order, g);
    tagPart(ax, "axes", "", R.groups.label(g));
    tagPart(imagesc(ax, 1:nU, 1:nU, M, 'AlphaData', double(isfinite(M))), "image", R.groups.label(g));
    set(ax, 'YDir', 'reverse', 'Color', [0.85 0.85 0.85]);
    colormap(ax, cmap);
    clim(ax, clim0);
    ax.FontSize = style.FontSize;
    box(ax, 'on');
    grid(ax, 'off');
    axis(ax, 'image');
    xlim(ax, [0.5 nU + 0.5]);
    ylim(ax, [0.5 nU + 0.5]);
    % Unit names as tick labels on the outer tiles only: every tile shares one order.
    bottom = j + nc > numel(idx) || ~isempty(ax0);   % no tile below
    left = mod(j - 1, nc) == 0;
    if nU <= 40
        fs = max(6, style.FontSize - (nU > 20));
        set(ax, 'XTick', 1:nU, 'YTick', 1:nU, 'TickLabelInterpreter', 'none', ...
            'XTickLabelRotation', 90, 'FontSize', fs);
        if bottom; ax.XTickLabel = labels; else; ax.XTickLabel = {}; end
        if left; ax.YTickLabel = labels; else; ax.YTickLabel = {}; end
    end
    t = string(sprintf('%s (n = %d', R.groups.label(g), R.nEpochs(g)));
    if isfinite(R.meanR(g)); t = t + sprintf(', mean r = %.2f', R.meanR(g)); end
    title(ax, t + ")", 'FontWeight', 'normal', 'Interpreter', 'none');
    axs(j) = ax;
end
gridLabels(tl, axs, "Units", "Units", style);
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
