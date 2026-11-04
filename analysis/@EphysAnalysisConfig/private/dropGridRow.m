function fig = dropGridRow(fig, i)
%dropGridRow  Figure FIG without its grid row I: the panels below it move up, the spans across it shrink by one.
%   Its rowHeights entry goes, and from a row gap list sized to the grid
%   (rows - 1 gaps) the gap under it (under the last row, the one over
%   it); a list of another size is left as it is. A panel lying in row I
%   alone is not looked at: the callers (removePanel, removeCell) drop
%   only rows that hold none. Columns: drop the rows of the grid turned a
%   quarter (gridTransposed).
G = fig.grid;
for q = 1:numel(fig.panels)
    P = fig.panels(q);
    if P.row > i
        fig.panels(q).row = P.row - 1;
    elseif P.row + P.rowSpan - 1 >= i
        fig.panels(q).rowSpan = P.rowSpan - 1;
    end
end
if numel(G.rowHeights) >= i; G.rowHeights(i) = []; end
g = G.rowGaps;
if ~isempty(g) && numel(g) == G.rows - 1
    g(min(i, numel(g))) = [];
    G.rowGaps = g;
end
G.rows = G.rows - 1;
fig.grid = G;
end
