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
%   See also EphysAnalysisConfig.placePanel, EphysAnalysisConfig.removeCell,
%   EphysAnalysisConfig.figureCells.

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
    if ~any([fig.panels.row] == i); fig = dropGridRow(fig, i); end
end
fig = gridTransposed(fig);   % the columns: the rows of the grid turned a quarter
for j = fig.grid.rows:-1:1
    if ~any([fig.panels.row] == j); fig = dropGridRow(fig, j); end
end
fig = gridTransposed(fig);
end
