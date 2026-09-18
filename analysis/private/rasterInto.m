function rasterInto(ax, R, u, style, colors)
%rasterInto  Draw unit U's raster from a spikePSTH result into AX.
%   Epochs are rows, sorted by group then time, first on top; each group's
%   rows sit on a pale band of its colour. All ticks are one line object
%   (NaN-separated), so even long rasters export small. With ShowStop each
%   epoch's stop event is a dot.
nE = numel(R.epochGroup);
[~, order] = sortrows([R.epochGroup(:) (1:nE).']);
row = zeros(nE, 1);
row(order) = 1:nE;
W = R.edges([1 end]);
hold(ax, 'on');
for g = 1:height(R.groups)
    rows = row(R.epochGroup == g);
    if isempty(rows); continue; end
    r1 = min(rows) - 0.5; r2 = max(rows) + 0.5;
    patch(ax, W([1 2 2 1]), [r1 r1 r2 r2], colors(g, :) + (1 - colors(g, :)) * 0.82, ...
        'EdgeColor', 'none', 'HandleVisibility', 'off');
end
tm = R.raster(u).times(:);
ep = R.raster(u).epoch(:);
if ~isempty(tm)
    rr = row(ep);
    X = [tm tm NaN(size(tm))].';
    Y = [rr - 0.4 rr + 0.4 NaN(size(rr))].';
    line(ax, X(:), Y(:), 'Color', [0 0 0], 'LineWidth', 0.5);
end
if style.ShowStop && any(isfinite(R.epochStop))
    ok = isfinite(R.epochStop) & R.epochStop >= W(1) & R.epochStop <= W(2);
    line(ax, R.epochStop(ok), row(ok), 'LineStyle', 'none', 'Marker', '.', 'MarkerSize', 6, 'Color', [0.8 0.1 0.1]);
end
if style.ShowZeroLine
    xline(ax, 0, ':', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off');
end
hold(ax, 'off');
set(ax, 'YDir', 'reverse');
xlim(ax, W);
ylim(ax, [0.5 max(1, nE) + 0.5]);
ylabel(ax, 'Epoch');
end
