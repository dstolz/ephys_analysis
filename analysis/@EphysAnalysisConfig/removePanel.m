function fig = removePanel(fig, id)
%removePanel  Drop a panel from a figure, and the rows and columns it leaves without a panel.
%   FIG = EphysAnalysisConfig.removePanel(FIG, ID) removes panel ID from
%   figure FIG (a Figures entry), then drops every row in which no
%   remaining panel starts, and every column likewise: the panels below
%   (right of) a dropped row (column) move up (left), and the spans that
%   crossed it shrink by one, as do its rowHeights / colWidths entries and
%   a gap list (the gap under it; under the last row, the one over it). So
%   it undoes placePanel exactly (a row merely crossed by a span is
%   dropped too, rather than leave an empty cell behind). Removing the
%   last panel leaves a 1 x 1 grid.
%
%   Error: EphysAnalysisConfig:NoPanel.
%
%   See also EphysAnalysisConfig.placePanel, EphysAnalysisConfig.figureCells.

arguments
    fig (1,1) struct
    id (1,1) string
end

k = [];
if ~isempty(fig.panels); k = find([fig.panels.id] == id, 1); end
if isempty(k)
    error('EphysAnalysisConfig:NoPanel', 'The figure has no panel "%s".', id);
end
fig.panels(k) = [];
G = fig.grid;
if isempty(fig.panels)
    G.rows = 1;
    G.cols = 1;
    if numel(G.rowHeights) > 1; G.rowHeights = G.rowHeights(1); end
    if numel(G.colWidths) > 1; G.colWidths = G.colWidths(1); end
    G.rowGaps = [];
    G.colGaps = [];
    fig.grid = G;
    return
end
for i = G.rows:-1:1
    if any([fig.panels.row] == i); continue; end
    for q = 1:numel(fig.panels)
        P = fig.panels(q);
        if P.row > i
            fig.panels(q).row = P.row - 1;
        elseif P.row + P.rowSpan - 1 >= i
            fig.panels(q).rowSpan = P.rowSpan - 1;
        end
    end
    if numel(G.rowHeights) >= i; G.rowHeights(i) = []; end
    G.rowGaps = dropGap(G.rowGaps, i, G.rows);
    G.rows = G.rows - 1;
end
for j = G.cols:-1:1
    if any([fig.panels.col] == j); continue; end
    for q = 1:numel(fig.panels)
        P = fig.panels(q);
        if P.col > j
            fig.panels(q).col = P.col - 1;
        elseif P.col + P.colSpan - 1 >= j
            fig.panels(q).colSpan = P.colSpan - 1;
        end
    end
    if numel(G.colWidths) >= j; G.colWidths(j) = []; end
    G.colGaps = dropGap(G.colGaps, j, G.cols);
    G.cols = G.cols - 1;
end
fig.grid = G;
end


function g = dropGap(g, i, n)
%dropGap  The gaps G between N rows (columns) with row I dropped: the gap under it goes (the last row's: the one over it).
%   G not sized to the grid (N - 1 gaps) is left as it is.
if isempty(g) || numel(g) ~= n - 1; return; end
g(min(i, numel(g))) = [];
end
