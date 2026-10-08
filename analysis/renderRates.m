function h = renderRates(R, target, opts)
%renderRates  Draw a firingRate result: rate per unit and group.
%   H = renderRates(R, TARGET, Layout=, Style=) draws one panel, units along
%   x (by Style.SortShank / Style.SortDepth: by shank, then top of the probe
%   first; neither = as listed), groups side by side in their colours.
%   Style.LabelShank / Style.LabelDepth append the shank / depth to the unit
%   labels.
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

style = renderStyle(opts.Style);
colors = groupPalette(R.groups, style);
[nU, nG] = size(R.meanRate);
order = probeOrder(R.meta, nU, style);
[tl, ax] = renderLayout(target, 1, 1);
if isempty(ax); ax = nexttile(tl); end
tagPart(ax, "axes");
w = 0.8 / nG;                                   % width of one group's slot
offs = ((1:nG) - (nG + 1) / 2) * w;
hold(ax, 'on');
lh = gobjects(1, nG);
for g = 1:nG
    x = (1:nU).' + offs(g);
    m = R.meanRate(order, g);
    gl = R.groups.label(g);
    switch opts.Layout
        case "bar"
            lh(g) = tagPart(bar(ax, x, m, w * 0.9, 'FaceColor', colors(g, :), 'EdgeColor', 'none'), "bar", gl);
            if style.ShowSEM
                tagPart(errorbar(ax, x, m, R.sem(order, g), 'LineStyle', 'none', 'Color', [0.2 0.2 0.2], ...
                    'CapSize', 2, 'HandleVisibility', 'off'), "errorBar", gl);
            end
        case "box"
            rows = R.groupIndex == g;
            y = R.rate(rows, order);
            xx = repmat(x.', size(y, 1), 1);
            ok = isfinite(y);
            if any(ok(:))
                lh(g) = tagPart(boxchart(ax, xx(ok), y(ok), 'BoxWidth', w * 0.8, 'BoxFaceColor', colors(g, :), ...
                    'MarkerColor', colors(g, :), 'MarkerStyle', '.'), "box", gl);
            else
                lh(g) = tagPart(plot(ax, NaN, NaN, 's', 'Color', colors(g, :)), "box", gl);
            end
        case "points"
            rows = find(R.groupIndex == g);
            y = R.rate(rows, order);
            jit = (mod((0:numel(rows) - 1).', 7) - 3) / 3 * w * 0.3;
            xx = x.' + jit;
            ok = isfinite(y);
            tagPart(bar(ax, x, m, w * 0.9, 'FaceColor', paleColor(colors(g, :), 0.7, style), 'EdgeColor', 'none', ...
                'HandleVisibility', 'off'), "meanBar", gl);
            lh(g) = tagPart(plot(ax, xx(ok), y(ok), '.', 'Color', colors(g, :), 'MarkerSize', 7), "points", gl);
    end
end
hold(ax, 'off');
labels = siteLabels(shortUnitLabels(R.labels), R.meta, style);
labels = labels(order);
set(ax, 'XTick', 1:nU, 'XTickLabel', labels, 'TickLabelInterpreter', 'none');
if nU > 8; ax.XTickLabelRotation = 60; end
if nU > 40; ax.XTickLabel = []; xlabel(ax, sprintf('%d units', nU)); end
xlim(ax, [0.4 nU + 0.6]);
styleAxes(ax, style);
ylabel(ax, R.units);
if style.Legend && nG > 1
    placeLegend(ax, lh, R.groups.label, style, tl, 'bestoutside');
end
h = struct('layout', tl, 'axes', ax);
end
