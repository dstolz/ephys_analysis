function h = renderRaster(R, target, opts)
%renderRaster  Draw the spike rasters of a spikePSTH result, one tile per unit.
%   H = renderRaster(R, TARGET, Page=, Style=) draws one raster per unit of
%   the page (MaxTiles per page): epochs as rows, sorted by group then time,
%   each group on a pale band of its colour; all ticks of a tile are one
%   line object. An axes TARGET gets the first unit of the page.
%
%   H: layout (tiled layout or []), axes.
%
%   See also spikePSTH, renderPSTH, renderPlot.

arguments
    R (1,1) struct
    target
    opts.Page (1,1) double {mustBePositive, mustBeInteger} = 1
    opts.Style = struct()
end

style = EphysAnalysisConfig.normalizeSection("Style", opts.Style);
if ~isfield(R, 'raster') || isempty(R.raster)
    error('renderRaster:NoRaster', 'The result holds no raster (compute it with spikePSTH(..., Raster=true)).');
end
colors = groupPalette(R.groups, style);
nU = numel(R.raster);
[idx, nr, nc] = pageItems(nU, opts.Page, style.MaxTiles);
[tl, ax0] = renderLayout(target, nr, nc);
if ~isempty(ax0); idx = idx(1:min(1, end)); end
axs = gobjects(1, numel(idx));
for j = 1:numel(idx)
    if ~isempty(ax0); ax = ax0; else; ax = nexttile(tl, j); end
    rasterInto(ax, R, idx(j), style, colors);
    styleAxes(ax, style);
    title(ax, R.labels(idx(j)), 'FontWeight', 'normal', 'Interpreter', 'none');
    r = ceil(j / nc);
    if r == nr || ~isempty(ax0); xlabel(ax, 'Time (s)'); end
    axs(j) = ax;
end
if ~isempty(axs) && style.Legend && height(R.groups) > 1
    ax = axs(1);
    hold(ax, 'on');
    lh = gobjects(1, height(R.groups));
    for g = 1:height(R.groups)
        lh(g) = patch(ax, NaN, NaN, colors(g, :) + (1 - colors(g, :)) * 0.82, 'EdgeColor', colors(g, :));
    end
    hold(ax, 'off');
    legend(ax, lh, R.groups.label, 'Location', 'bestoutside', 'Box', 'off', 'Interpreter', 'none', ...
        'FontSize', max(6, style.FontSize - 1));
end
h = struct('layout', tl, 'axes', axs);
end
