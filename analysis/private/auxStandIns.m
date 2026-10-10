function [h, labels] = auxStandIns(ax, X, style)
%auxStandIns  Legend stand-ins for the mean aux traces: one empty line per entry of X.legend (auxLooks).
%   [H, LABELS] = auxStandIns(AX, X, STYLE) draws in AX, for each of
%   X.legend's entries, a line with no data in its color and line style,
%   tagged "auxTrace" with its label as the group, so the aesthetics rules
%   of the traces reach the legend's entry too (as a raster's event marks
%   do). H and LABELS go to the legend; both are empty when X.legend is.
%
%   See also auxLooks, auxInto, placeLegend.

n = numel(X.legend);
h = gobjects(1, n);
labels = strings(1, n);
for k = 1:n
    e = X.legend(k);
    h(k) = tagPart(line(ax, NaN, NaN, 'Color', e.color, 'LineStyle', char(e.lineStyle), 'LineWidth', style.LineWidth), ...
        "auxTrace", e.label);
    labels(k) = e.label;
end
end
