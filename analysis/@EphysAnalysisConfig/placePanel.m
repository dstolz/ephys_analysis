function fig = placePanel(fig, panel, where, anchorId, at)
%placePanel  Add a panel to a figure above, below, left or right of another, or in an empty cell.
%   FIG = EphysAnalysisConfig.placePanel(FIG, PANEL, WHERE, ANCHORID) adds
%   PANEL (a partial panel struct, normalizePanel'd; an empty id becomes
%   "<type>_<n>") next to the panel ANCHORID of figure FIG (a Figures
%   entry), WHERE being "below", "above", "right" or "left". When the cells
%   next to the anchor on that side, across its columns (rows), are in the
%   grid and empty, the new panel fills them and the grid is unchanged.
%   Otherwise the grid gets a new row (column) there:
%     "below"  a new row right after the anchor's last row; its rowHeights
%              entry (when the heights are given) copies that row's
%     "above"  a new row right before the anchor's first row (copying its
%              height)
%     "right"  a new column after the anchor's last column (copying its
%              colWidths entry)
%     "left"   a new column before the anchor's first column
%   A gap list (grid.rowGaps / colGaps, when given) gets the gap where the
%   new row (column) goes on both sides of it (at an edge, the outermost
%   gap again).
%   The panels after the new row (column) move down (right) by one; those
%   whose span crosses it grow by one; the new panel takes the anchor's
%   columns (rows) and one row (column). removePanel undoes it exactly.
%   FIG = EphysAnalysisConfig.placePanel(FIG, PANEL, "cell", "", [R C])
%   puts the panel in the empty cell R, C (one row and one column); the
%   grid is unchanged and no anchor is needed. (A positional input: a
%   name-value Cell would take the place "cell" for its name.)
%   The first panel of a figure without panels goes to (1, 1), the grid
%   unchanged, whatever WHERE; ANCHORID is then not needed.
%
%   Errors: EphysAnalysisConfig:NoPanel (no anchor, or no such panel),
%   EphysAnalysisConfig:DuplicatePanelId, EphysAnalysisConfig:CellTaken
%   ("cell": a cell outside the grid or covered by a panel).
%
%   See also EphysAnalysisConfig.removePanel, EphysAnalysisConfig.movePanel,
%   EphysAnalysisConfig.figureCells.

arguments
    fig (1,1) struct
    panel = struct()
    where (1,1) string {mustBeMember(where, ["above" "below" "left" "right" "cell"])} = "below"
    anchorId (1,1) string = ""
    at double = []
end

p = EphysAnalysisConfig.normalizePanel(panel);
ids = string.empty(1, 0);
if ~isempty(fig.panels); ids = [fig.panels.id]; end
if p.id == ""
    p.id = EphysAnalysisConfig.freeId(p.type, ids);
elseif ismember(p.id, ids)
    error('EphysAnalysisConfig:DuplicatePanelId', 'The figure has a panel "%s" already.', p.id);
end
p.rowSpan = 1;
p.colSpan = 1;
if isempty(fig.panels)
    p.row = 1;
    p.col = 1;
    fig.panels = p;
    return
end
cells = EphysAnalysisConfig.figureCells(fig);
if where == "cell"
    rc = round(at);
    if ~(numel(rc) == 2 && all(rc >= 1) && rc(1) <= size(cells, 1) && rc(2) <= size(cells, 2))
        error('EphysAnalysisConfig:CellTaken', 'Give the empty cell as [row column], inside the %d x %d grid.', ...
            size(cells, 1), size(cells, 2));
    end
    if cells(rc(1), rc(2)) ~= 0
        error('EphysAnalysisConfig:CellTaken', 'Row %d, column %d holds %s: pick an empty cell.', rc(1), rc(2), ...
            fig.panels(cells(rc(1), rc(2))).id);
    end
    p.row = rc(1);
    p.col = rc(2);
    fig.panels(1, end+1) = p;
    return
end
a = find(ids == anchorId, 1);
if isempty(a)
    if anchorId == ""
        error('EphysAnalysisConfig:NoPanel', 'Place the new panel %s one of the figure''s panels: give its id.', where);
    end
    error('EphysAnalysisConfig:NoPanel', 'The figure has no panel "%s".', anchorId);
end
A = fig.panels(a);
[r, c, fits] = besideAnchor(A, where, cells);
if fits   % the empty cells next to the anchor: the grid stays as it is
    p.row = r(1);
    p.col = c(1);
    p.rowSpan = numel(r);
    p.colSpan = numel(c);
    fig.panels(1, end+1) = p;
    return
end
G = fig.grid;
if ismember(where, ["above" "below"])
    if where == "below"
        ins = A.row + A.rowSpan;     % the new row's index
        from = ins - 1;              % the row whose height it copies
    else
        ins = A.row;
        from = A.row;
    end
    for k = 1:numel(fig.panels)
        q = fig.panels(k);
        if q.row >= ins
            fig.panels(k).row = q.row + 1;
        elseif q.row + q.rowSpan - 1 >= ins
            fig.panels(k).rowSpan = q.rowSpan + 1;
        end
    end
    G.rowHeights = insertSize(G.rowHeights, ins, from);
    G.rowGaps = insertGap(G.rowGaps, ins, G.rows);
    G.rows = G.rows + 1;
    p.row = ins;
    p.col = A.col;
    p.colSpan = A.colSpan;
else
    if where == "right"
        ins = A.col + A.colSpan;
        from = ins - 1;
    else
        ins = A.col;
        from = A.col;
    end
    for k = 1:numel(fig.panels)
        q = fig.panels(k);
        if q.col >= ins
            fig.panels(k).col = q.col + 1;
        elseif q.col + q.colSpan - 1 >= ins
            fig.panels(k).colSpan = q.colSpan + 1;
        end
    end
    G.colWidths = insertSize(G.colWidths, ins, from);
    G.colGaps = insertGap(G.colGaps, ins, G.cols);
    G.cols = G.cols + 1;
    p.col = ins;
    p.row = A.row;
    p.rowSpan = A.rowSpan;
end
fig.grid = G;
fig.panels(1, end+1) = p;
end


function [r, c, fits] = besideAnchor(A, where, cells)
%besideAnchor  The cells next to panel A on side WHERE, across its columns (rows), and whether they are all in the grid and empty.
%   R, C: the rows and columns of that one-row (one-column) band.
r = A.row : A.row + A.rowSpan - 1;
c = A.col : A.col + A.colSpan - 1;
switch where
    case "below", r = A.row + A.rowSpan;
    case "above", r = A.row - 1;
    case "right", c = A.col + A.colSpan;
    case "left",  c = A.col - 1;
end
fits = ~isempty(r) && ~isempty(c) && all(r >= 1) && all(c >= 1) && all(r <= size(cells, 1)) && all(c <= size(cells, 2)) ...
    && all(cells(r, c) == 0, 'all');
end


function s = insertSize(s, ins, from)
%insertSize  Insert a copy of relative size S(FROM) at index INS ([] stays []).
if isempty(s); return; end
from = min(max(from, 1), numel(s));
ins = min(max(ins, 1), numel(s) + 1);
s = [s(1:ins-1), s(from), s(ins:end)];
end


function g = insertGap(g, ins, n)
%insertGap  The gaps G between N rows (columns) with a row inserted at index INS: the gap where it goes, twice ([] stays []).
%   At an edge the outermost gap is copied. G not sized to the grid (N - 1
%   gaps) is left as it is (Validate reports it).
if isempty(g) || numel(g) ~= n - 1; return; end
i = min(max(ins - 1, 1), numel(g));
g = [g(1:i), g(i:end)];
end
