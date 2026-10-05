function rasterInto(ax, R, u, style, colors, sortBy)
%rasterInto  Draw unit U's raster from a spikePSTH result into AX.
%   Epochs are rows, sorted by group, then by SORTBY, then by time, first
%   on top; each group's rows sit on a pale band of its colour. SORTBY ""
%   (default) keeps the epochs in time (trial) order; "stop" sorts them by
%   their stop event's latency (R.epochStop); any other value names a
%   column of R.epochs (a trial parameter epochTable copied on). Missing
%   values sort last. All ticks are one line object (NaN-separated), so
%   even long rasters export small. With ShowStop each epoch's stop event
%   is a dot. The axes are styled (styleAxes) without Style.YLim: that is
%   for rates, and every row stays in view.
if nargin < 6; sortBy = ""; end
nE = numel(R.epochGroup);
[key, name] = rasterSortKey(R, sortBy, nE);
[~, order] = sortrows(table(R.epochGroup(:), key, (1:nE).'));
row = zeros(nE, 1);
row(order) = 1:nE;
W = R.edges([1 end]);
hold(ax, 'on');
for g = 1:height(R.groups)
    rows = row(R.epochGroup == g);
    if isempty(rows); continue; end
    r1 = min(rows) - 0.5; r2 = max(rows) + 0.5;
    tagPart(patch(ax, W([1 2 2 1]), [r1 r1 r2 r2], colors(g, :) + (1 - colors(g, :)) * 0.82, ...
        'EdgeColor', 'none', 'HandleVisibility', 'off'), "rasterBand", R.groups.label(g));
end
tm = R.raster(u).times(:);
ep = R.raster(u).epoch(:);
if ~isempty(tm)
    rr = row(ep);
    X = [tm tm NaN(size(tm))].';
    Y = [rr - 0.4 rr + 0.4 NaN(size(rr))].';
    tagPart(line(ax, X(:), Y(:), 'Color', [0 0 0], 'LineWidth', 0.5), "rasterTicks");
end
if style.ShowStop && any(isfinite(R.epochStop))
    ok = isfinite(R.epochStop) & R.epochStop >= W(1) & R.epochStop <= W(2);
    tagPart(line(ax, R.epochStop(ok), row(ok), 'LineStyle', 'none', 'Marker', '.', 'MarkerSize', 6, 'Color', [0.8 0.1 0.1]), ...
        "rasterStop");
end
if style.ShowZeroLine
    tagPart(xline(ax, 0, ':', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off'), "zeroLine");
end
hold(ax, 'off');
set(ax, 'YDir', 'reverse');
xlim(ax, W);
ylim(ax, [0.5 max(1, nE) + 0.5]);
ylabel(ax, name, 'Interpreter', 'none');
style.YLim = [];
styleAxes(ax, style);
end


function [key, name] = rasterSortKey(R, sortBy, nE)
%rasterSortKey  Each epoch's sort value and the raster's y label.
%   "" gives a constant key (time order stays), "stop" R.epochStop, any
%   other name that column of R.epochs.
sortBy = strtrim(string(sortBy));
name = "Epoch";
if sortBy == ""
    key = zeros(nE, 1);
    return
end
if sortBy == "stop"
    key = R.epochStop(:);
    name = "Epoch (by stop latency)";
    return
end
if ~(isfield(R, 'epochs') && istable(R.epochs) && ismember(sortBy, string(R.epochs.Properties.VariableNames)))
    error('renderRaster:NoSortColumn', ['The raster sorts by "%s", which is not a column of the epochs ' ...
        '(R.epochs: epochTable(..., Columns="%s")).'], sortBy, sortBy);
end
key = R.epochs.(sortBy);
if size(key, 1) ~= nE || size(key, 2) ~= 1
    error('renderRaster:NoSortColumn', 'The epochs'' column "%s" is not one value per epoch.', sortBy);
end
name = "Epoch (by " + sortBy + ")";
end
