function fig = placePanel(fig, panel, where, anchorId)
%placePanel  Add a panel to a figure above, below, left or right of another.
%   FIG = EphysAnalysisConfig.placePanel(FIG, PANEL, WHERE, ANCHORID) adds
%   PANEL (a partial panel struct, normalizePanel'd; an empty id becomes
%   "<type>_<n>") next to the panel ANCHORID of figure FIG (a Figures
%   entry), WHERE being:
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
%   The first panel of a figure without panels goes to (1, 1), the grid
%   unchanged; ANCHORID is then not needed.
%
%   Errors: EphysAnalysisConfig:NoPanel (no anchor, or no such panel),
%   EphysAnalysisConfig:DuplicatePanelId.
%
%   See also EphysAnalysisConfig.removePanel, EphysAnalysisConfig.movePanel,
%   EphysAnalysisConfig.figureCells.

arguments
    fig (1,1) struct
    panel = struct()
    where (1,1) string {mustBeMember(where, ["above" "below" "left" "right"])} = "below"
    anchorId (1,1) string = ""
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
a = find(ids == anchorId, 1);
if isempty(a)
    if anchorId == ""
        error('EphysAnalysisConfig:NoPanel', 'Place the new panel %s one of the figure''s panels: give its id.', where);
    end
    error('EphysAnalysisConfig:NoPanel', 'The figure has no panel "%s".', anchorId);
end
A = fig.panels(a);
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
