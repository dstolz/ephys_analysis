function stackAxes(ax, L, labels, rightName)
%stackAxes  A line stack's y axes: each row named on the left, its top value on the right, the limits.
%   stackAxes(AX, L, LABELS, RIGHTNAME) dresses the axes AX whose traces
%   were drawn in the rows of the stackLayout L (call styleAxes first):
%   the left y axis has a tick at each row's middle labeled with LABELS(r)
%   (its trial group, channel or series; first on top), the right y axis
%   (yyaxis) a tick at each row's top labeled with the value it stands for
%   (L.range(r, 2), "%.3g"; one tick where rows share a top), named
%   RIGHTNAME ("" = none). Both take L.ylim. Like a stacked PSTH's
%   (drawStack, whose right axis names each row's peak), so a panel's own
%   ySide is not used (renderFigure's panelAxes leaves a yyaxis' sides).
%   AX is left on its left y axis, both axes in the x axis' color.
%
%   See also stackLayout, stackBaseLines, drawStack.
arguments
    ax
    L (1,1) struct
    labels string
    rightName (1,1) string = ""
end
labels = reshape(labels, 1, []);
if numel(labels) < L.n; labels(end+1:L.n) = ""; end
yyaxis(ax, 'left');
ylim(ax, L.ylim);
set(ax, 'YTick', fliplr(L.mid), 'YTickLabel', cellstr(flip(labels(1:L.n))), 'TickLabelInterpreter', 'none');
yyaxis(ax, 'right');
ylim(ax, L.ylim);
[tk, iu] = unique(round(L.top, 12));
txt = compose("%.3g", L.range(:, 2));
set(ax, 'YTick', tk, 'YTickLabel', cellstr(txt(iu)));
if rightName ~= ""; ylabel(ax, rightName, 'Interpreter', 'none'); end
yyaxis(ax, 'left');
set(ax.YAxis, 'Color', ax.XAxis.Color);
end
