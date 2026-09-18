function h = renderTuning(R, target, opts)
%renderTuning  Draw a tuningCurve result: rate against the parameter.
%   H = renderTuning(R, TARGET, Layout=, Page=, Style=)
%
%   Layout
%     "grid"     (default) one tile per unit (MaxTiles per page), one curve
%                per series, mean +/- SEM over the epochs of each value
%     "overlay"  one panel: the mean over units, +/- SEM across units
%   A text parameter is spaced evenly with its values as tick labels.
%
%   H: layout (tiled layout or []), axes.
%
%   See also tuningCurve, renderRates, renderPlot.

arguments
    R (1,1) struct
    target
    opts.Layout (1,1) string {mustBeMember(opts.Layout, ["grid" "overlay"])} = "grid"
    opts.Page (1,1) double {mustBePositive, mustBeInteger} = 1
    opts.Style = struct()
end

style = EphysAnalysisConfig.normalizeSection("Style", opts.Style);
colors = groupPalette(R.groups, style);
[nX, nU, nS] = size(R.mean);
if R.xIsNumeric
    xv = double(R.x(:));
else
    xv = (1:nX).';
end
if opts.Layout == "overlay" && nU > 1
    [tl, ax] = renderLayout(target, 1, 1);
    if isempty(ax); ax = nexttile(tl); end
    m = reshape(mean(R.mean, 2, 'omitnan'), nX, nS);
    s = reshape(semOf(R.mean, 2), nX, nS);
    drawCurves(ax, xv, m, s, R, colors, style, true);
    title(ax, sprintf('Mean of %d units', nU), 'FontWeight', 'normal');
    ylabel(ax, R.units);
    h = struct('layout', tl, 'axes', ax);
    return
end
if opts.Layout == "overlay"
    idx = 1; nr = 1; nc = 1;
else
    [idx, nr, nc] = pageItems(nU, opts.Page, style.MaxTiles);
end
[tl, ax0] = renderLayout(target, nr, nc);
if ~isempty(ax0); idx = idx(1:min(1, end)); end
axs = gobjects(1, numel(idx));
for j = 1:numel(idx)
    u = idx(j);
    if ~isempty(ax0); ax = ax0; else; ax = nexttile(tl, j); end
    drawCurves(ax, xv, reshape(R.mean(:, u, :), nX, nS), reshape(R.sem(:, u, :), nX, nS), R, colors, style, j == 1);
    title(ax, R.labels(u), 'FontWeight', 'normal', 'Interpreter', 'none');
    if mod(j - 1, nc) == 0; ylabel(ax, R.units); end
    if ceil(j / nc) < nr && isempty(ax0); xlabel(ax, ''); end
    axs(j) = ax;
end
h = struct('layout', tl, 'axes', axs);
end


function drawCurves(ax, xv, m, s, R, colors, style, withLegend)
nS = size(m, 2);
hold(ax, 'on');
lh = gobjects(1, nS);
for k = 1:nS
    if style.ShowSEM
        lh(k) = errorbar(ax, xv, m(:, k), s(:, k), '-o', 'Color', colors(k, :), 'LineWidth', style.LineWidth, ...
            'MarkerSize', 4, 'MarkerFaceColor', colors(k, :), 'CapSize', 3);
    else
        lh(k) = plot(ax, xv, m(:, k), '-o', 'Color', colors(k, :), 'LineWidth', style.LineWidth, ...
            'MarkerSize', 4, 'MarkerFaceColor', colors(k, :));
    end
end
hold(ax, 'off');
if ~R.xIsNumeric
    set(ax, 'XTick', xv, 'XTickLabel', string(R.x), 'TickLabelInterpreter', 'none');
end
if numel(xv) > 1
    pad = 0.08 * (max(xv) - min(xv));
    xlim(ax, [min(xv) - pad, max(xv) + pad]);
end
styleAxes(ax, style);
xlabel(ax, R.param, 'Interpreter', 'none');
if withLegend && style.Legend && nS > 1
    legend(ax, lh, R.series, 'Location', 'best', 'Box', 'off', 'Interpreter', 'none', 'FontSize', max(6, style.FontSize - 1));
end
end
