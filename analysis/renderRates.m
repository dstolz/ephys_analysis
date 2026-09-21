function h = renderRates(R, target, opts)
%renderRates  Draw a firingRate result: rate per unit and group.
%   H = renderRates(R, TARGET, Layout=, Style=) draws one panel, units along
%   x (top of the probe first: probe y, else channel), groups side by side
%   in their colours.
%
%   Layout
%     "bar"     (default) mean +/- SEM over each group's epochs
%     "box"     box plot of the epochs' rates
%     "points"  every epoch's rate as a dot (a fixed, repeatable jitter)
%               with the mean as a bar
%
%   H: layout (tiled layout or []), axes.
%
%   See also firingRate, renderTuning, renderPlot.

arguments
    R (1,1) struct
    target
    opts.Layout (1,1) string {mustBeMember(opts.Layout, ["bar" "box" "points"])} = "bar"
    opts.Style = struct()
end

style = EphysAnalysisConfig.normalizeSection("Style", opts.Style);
colors = groupPalette(R.groups, style);
[nU, nG] = size(R.meanRate);
order = depthOrder(R.meta, nU);
[tl, ax] = renderLayout(target, 1, 1);
if isempty(ax); ax = nexttile(tl); end
w = 0.8 / nG;                                   % width of one group's slot
offs = ((1:nG) - (nG + 1) / 2) * w;
hold(ax, 'on');
lh = gobjects(1, nG);
for g = 1:nG
    x = (1:nU).' + offs(g);
    m = R.meanRate(order, g);
    switch opts.Layout
        case "bar"
            lh(g) = bar(ax, x, m, w * 0.9, 'FaceColor', colors(g, :), 'EdgeColor', 'none');
            if style.ShowSEM
                errorbar(ax, x, m, R.sem(order, g), 'LineStyle', 'none', 'Color', [0.2 0.2 0.2], ...
                    'CapSize', 2, 'HandleVisibility', 'off');
            end
        case "box"
            rows = R.groupIndex == g;
            y = R.rate(rows, order);
            xx = repmat(x.', size(y, 1), 1);
            ok = isfinite(y);
            if any(ok(:))
                lh(g) = boxchart(ax, xx(ok), y(ok), 'BoxWidth', w * 0.8, 'BoxFaceColor', colors(g, :), ...
                    'MarkerColor', colors(g, :), 'MarkerStyle', '.');
            else
                lh(g) = plot(ax, NaN, NaN, 's', 'Color', colors(g, :));
            end
        case "points"
            rows = find(R.groupIndex == g);
            y = R.rate(rows, order);
            jit = (mod((0:numel(rows) - 1).', 7) - 3) / 3 * w * 0.3;
            xx = x.' + jit;
            ok = isfinite(y);
            bar(ax, x, m, w * 0.9, 'FaceColor', colors(g, :) + (1 - colors(g, :)) * 0.7, 'EdgeColor', 'none', ...
                'HandleVisibility', 'off');
            lh(g) = plot(ax, xx(ok), y(ok), '.', 'Color', colors(g, :), 'MarkerSize', 7);
    end
end
hold(ax, 'off');
labels = shortUnitLabels(R.labels(order));
set(ax, 'XTick', 1:nU, 'XTickLabel', labels, 'TickLabelInterpreter', 'none');
if nU > 8; ax.XTickLabelRotation = 60; end
if nU > 40; ax.XTickLabel = []; xlabel(ax, sprintf('%d units (top of the probe first)', nU)); end
xlim(ax, [0.4 nU + 0.6]);
styleAxes(ax, style);
ylabel(ax, R.units);
if style.Legend && nG > 1
    legend(ax, lh, R.groups.label, 'Location', 'bestoutside', 'Box', 'off', 'Interpreter', 'none', ...
        'FontSize', max(6, style.FontSize - 1));
end
h = struct('layout', tl, 'axes', ax);
end
