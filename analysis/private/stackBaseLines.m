function h = stackBaseLines(ax, x, L, names, opts)
%stackBaseLines  A stack's row lines: a thin gray line along each row, behind its traces (role "stackBase").
%   H = stackBaseLines(AX, X, L, NAMES) draws, for each row r of the
%   stackLayout L, a thin gray line across X ([from to]) at the row's zero
%   when its range holds 0, else along its bottom, tagged "stackBase" with
%   the row's name NAMES(r) (its trial group, channel or series). Each line
%   carries appdata 'StackMap' = [offset scale], how its row maps values
%   onto the axis, so a data tip reads a trace's own values
%   (FigureDataTips). Zero=false draws every line along its row's bottom
%   (an image stack: the edge between two blocks). Kept out of legends.
%
%   See also stackLayout, stackAxes, drawStack.
arguments
    ax
    x double
    L (1,1) struct
    names string
    opts.Zero (1,1) logical = true
end
x = double(x([1 end]));
h = gobjects(1, L.n);
for r = 1:L.n
    y = L.base(r);
    if opts.Zero && L.range(r, 1) <= 0 && L.range(r, 2) >= 0; y = L.offset(r); end
    h(r) = tagPart(line(ax, x, [y y], 'Color', [0.72 0.72 0.72], 'LineWidth', 0.5, 'HandleVisibility', 'off'), ...
        "stackBase", names(min(r, numel(names))));
    setappdata(h(r), 'StackMap', [L.offset(r) L.scale(r)]);
end
end
