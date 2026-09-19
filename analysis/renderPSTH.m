function h = renderPSTH(R, target, opts)
%renderPSTH  Draw a spikePSTH result: rate traces per group, with rasters.
%   H = renderPSTH(R, TARGET, Name=Value) draws into TARGET: an axes or
%   uiaxes (one panel: the first unit of the page, no raster), or a figure,
%   uifigure, panel, tab, grid layout or tiled layout (a tiled layout of
%   panels is made inside). Renderers never create figures.
%
%   Options
%     Layout      "grid" (default): one tile per unit, groups overlaid;
%                 "overlay": one panel with the mean over units (+/- SEM
%                 across units); a single unit is shown as itself
%     WithRaster  a raster above each rate panel (default true; grid, or
%                 overlay of one unit)
%     Page        page of units in grid layout (MaxTiles per page)
%     Style       EphysAnalysisConfig.defaults("Style") fields (LineWidth,
%                 ShowSEM, ShowStop, ShowZeroLine, Colormap, FontSize, XLim,
%                 YLim, Grid, Legend, MaxTiles)
%
%   H: layout (tiled layout or []), axes (rate panels), rasterAxes.
%
%   See also spikePSTH, renderRaster, renderPlot.

arguments
    R (1,1) struct
    target
    opts.Layout (1,1) string {mustBeMember(opts.Layout, ["grid" "overlay"])} = "grid"
    opts.WithRaster (1,1) logical = true
    opts.Page (1,1) double {mustBePositive, mustBeInteger} = 1
    opts.Style = struct()
end

style = EphysAnalysisConfig.normalizeSection("Style", opts.Style);
colors = groupPalette(R.groups, style);
nU = size(R.rate, 2);
nG = size(R.rate, 3);
h = struct('layout', [], 'axes', gobjects(0), 'rasterAxes', gobjects(0));

if opts.Layout == "overlay" && nU > 1
    [tl, ax] = renderLayout(target, 1, 1);
    if isempty(ax); ax = nexttile(tl); end
    m = reshape(mean(R.rate, 2, 'omitnan'), [], nG);
    s = reshape(semOf(R.rate, 2), [], nG);
    drawRates(ax, R.t, m, s, R, colors, style, true);
    title(ax, sprintf('Mean of %d units', nU), 'FontWeight', 'normal');
    xlabel(ax, 'Time (s)');
    ylabel(ax, R.units);
    h.layout = tl; h.axes = ax;
    return
end

if opts.Layout == "overlay"
    idx = 1; nr = 1; nc = 1;
else
    [idx, nr, nc] = pageItems(nU, opts.Page, style.MaxTiles);
end
withRaster = opts.WithRaster && isfield(R, 'raster') && ~isempty(R.raster);
rowsPer = 1 + withRaster;
[tl, ax0] = renderLayout(target, nr * rowsPer, nc);
if ~isempty(ax0)
    idx = idx(1:min(1, end));
    withRaster = false;
end
axs = gobjects(1, numel(idx));
rax = gobjects(1, 0);
for j = 1:numel(idx)
    u = idx(j);
    r = ceil(j / nc); c = j - (r - 1) * nc;
    if ~isempty(ax0)
        ax = ax0;
    else
        if withRaster
            ra = nexttile(tl, ((r - 1) * rowsPer) * nc + c);
            rasterInto(ra, R, u, style, colors);
            styleAxes(ra, style);
            ra.XTickLabel = [];
            title(ra, R.labels(u), 'FontWeight', 'normal', 'Interpreter', 'none');
            rax(end+1) = ra; %#ok<AGROW>
        end
        ax = nexttile(tl, ((r - 1) * rowsPer + withRaster) * nc + c);
    end
    drawRates(ax, R.t, reshape(R.rate(:, u, :), [], nG), reshape(R.sem(:, u, :), [], nG), R, colors, style, j == 1);
    if ~withRaster
        title(ax, R.labels(u), 'FontWeight', 'normal', 'Interpreter', 'none');
    end
    if r == nr || ~isempty(ax0); xlabel(ax, 'Time (s)'); end
    if c == 1; ylabel(ax, R.units); end
    axs(j) = ax;
end
if withRaster && ~isempty(rax)
    for j = 1:numel(rax)
        linkaxes([rax(j) axs(j)], 'x');
    end
end
h.layout = tl; h.axes = axs; h.rasterAxes = rax;
end


function drawRates(ax, t, m, s, R, colors, style, withLegend)
%drawRates  Traces (and SEM bands, stop lines) of every group into AX.
hold(ax, 'on');
nG = size(m, 2);
if style.ShowSEM
    for g = 1:nG
        semBand(ax, t, m(:, g), s(:, g), colors(g, :));
    end
end
lh = gobjects(1, nG);
for g = 1:nG
    lh(g) = plot(ax, t, m(:, g), 'Color', colors(g, :), 'LineWidth', style.LineWidth);
end
if style.ShowZeroLine
    xline(ax, 0, ':', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off');
end
if style.ShowStop && isfield(R, 'stopMean')
    for g = 1:nG
        if isfinite(R.stopMean(g))
            xline(ax, R.stopMean(g), '--', 'Color', colors(g, :), 'HandleVisibility', 'off');
        end
    end
end
hold(ax, 'off');
xlim(ax, R.edges([1 end]));
styleAxes(ax, style);
if withLegend && style.Legend && nG > 1
    legend(ax, lh, R.groups.label, 'Location', 'best', 'Box', 'off', 'Interpreter', 'none', 'FontSize', max(6, style.FontSize - 1));
end
end
