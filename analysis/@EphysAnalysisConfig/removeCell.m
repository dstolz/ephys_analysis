function [fig, what, removed] = removeCell(fig, rc, how)
%removeCell  Take an empty cell out of a figure's grid; the panels around it close the gap as HOW says.
%   [FIG, WHAT, REMOVED] = EphysAnalysisConfig.removeCell(FIG, [R C], HOW)
%   removes the empty cell at row R, column C of figure FIG (a Figures
%   entry). HOW:
%     "stretchColumn"  the panels of column C grow over it, and over the
%                      column's other empty cells with it, keeping their
%                      proportions: the panels and cells between the
%                      nearest panels across column C that span other
%                      columns too (else the grid's top and bottom). The
%                      panels in the other columns keep their size and
%                      place: the grid gets the row lines this needs (and
%                      rowHeights for them, the smallest row 1) and loses
%                      those nothing needs any more. (An empty cell that
%                      stretched would be cut by the other columns' lines
%                      into as many cells as before.)
%     "stretchRow"     the same along row R
%     "shiftUp"        the panels below it in column C move up one row (as
%                      a spreadsheet's Delete > Shift cells up); each must
%                      lie in column C alone
%     "shiftLeft"      the panels right of it in row R move left one column
%     "growAbove"      the panel above it grows down over it; it must lie
%                      in column C alone. "growBelow" (the panel below grows
%                      up), "growLeft" and "growRight" alike
%     "deleteRow"      row R goes: the panels below it move up, the spans
%                      across it shrink; no panel may lie in row R alone
%     "deleteColumn"   column C goes alike
%   Then every row and column without a panel in it goes from the grid (an
%   empty one from before the edit too). A gap list sized to the grid
%   (rowGaps, colGaps) keeps each gap with its line; a line the stretch
%   moved keeps its gap, the one that was over the panel (cell) under it.
%   WHAT says what happened, for the status bar: "psth_2 and raster_2
%   moved up; the empty row 4 dropped". REMOVED: the empty cells HOW took
%   out, [row column] each (more than the one given only by a stretch);
%   the rows and columns dropped after are not in it.
%
%   Errors: EphysAnalysisConfig:CellTaken (not an empty cell of the grid),
%   EphysAnalysisConfig:CannotRemoveCell (HOW cannot remove it; the
%   message says why as a phrase: "row 1 holds events_1").
%
%   See also EphysAnalysisConfig.cellRemovals, EphysAnalysisConfig.removePanel,
%   EphysAnalysisConfig.figureCells.

arguments
    fig (1,1) struct
    rc double
    how (1,1) string {mustBeMember(how, ["stretchColumn" "stretchRow" "shiftUp" "shiftLeft" ...
        "growAbove" "growBelow" "growLeft" "growRight" "deleteRow" "deleteColumn"])}
end

cells = EphysAnalysisConfig.figureCells(fig);
rc = round(reshape(double(rc), 1, []));
if ~(numel(rc) == 2 && all(rc >= 1) && rc(1) <= size(cells, 1) && rc(2) <= size(cells, 2))
    error('EphysAnalysisConfig:CellTaken', 'Give the empty cell as [row column], inside the %d x %d grid.', ...
        size(cells, 1), size(cells, 2));
end
if cells(rc(1), rc(2)) ~= 0
    error('EphysAnalysisConfig:CellTaken', 'Row %d, column %d holds %s: it is not an empty cell.', rc(1), rc(2), ...
        fig.panels(cells(rc(1), rc(2))).id);
end
if isempty(fig.panels)
    cannot("the figure has no panel to close the gap");
end

% along a row: the same along a column of the grid turned a quarter
along = ["stretchRow" "shiftLeft" "growLeft" "growRight" "deleteColumn"];
as = ["stretchColumn" "shiftUp" "growAbove" "growBelow" "deleteRow"];
i = find(along == how, 1);
across = ~isempty(i);
W = struct('col', "column", 'row', "row", 'cols', "columns", 'up', "up", 'down', "down", 'above', "above", 'below', "below");
if across
    fig = gridTransposed(fig);
    rc = rc([2 1]);
    how = as(i);
    W = struct('col', "row", 'row', "column", 'cols', "rows", 'up', "left", 'down', "right", 'above', "left of", 'below', "right of");
end
r = rc(1);
c = rc(2);
removed = [r c];
switch how
    case "stretchColumn", [fig, what, removed] = stretchColumn(fig, r, c, W);
    case "shiftUp",       [fig, what] = shiftUp(fig, r, c, W);
    case "growAbove",     [fig, what] = grow(fig, r, c, -1, W);
    case "growBelow",     [fig, what] = grow(fig, r, c, 1, W);
    case "deleteRow",     [fig, what] = deleteRow(fig, r, W);
end
if across
    fig = gridTransposed(fig);
    removed = removed(:, [2 1]);
end
[fig, dr] = dropEmptyRows(fig);
fig = gridTransposed(fig);   % the columns: the rows of the grid turned a quarter
[fig, dc] = dropEmptyRows(fig);
fig = gridTransposed(fig);
what = what + droppedText(dr, "row") + droppedText(dc, "column");
end


function [fig, what, removed] = stretchColumn(fig, r, c, W)
%stretchColumn  The panels of column C between the panels across it (or the grid's edges) grow over the cell (R, C) and the empty cells there.
cells = EphysAnalysisConfig.figureCells(fig);
[nr, nc] = size(cells);
P = fig.panels;
G = fig.grid;
e = [0 cumsum(gridSizes(G.rowHeights, nr))];   % the row lines, top to bottom
tol = 1e-9 * e(end);
wide = @(k) k ~= 0 && (P(k).colSpan > 1 || P(k).col ~= c);   % a panel across other columns too: its lines stay
top = r;
while top > 1 && ~wide(cells(top - 1, c)); top = top - 1; end
bot = r;
while bot < nr && ~wide(cells(bot + 1, c)); bot = bot + 1; end
items = zeros(0, 3);   % the panels that stretch, top to bottom: their first and last row, and the panel
i = top;
while i <= bot
    k = cells(i, c);
    if k == 0
        i = i + 1;
    else
        last = i;
        while last < bot && cells(last + 1, c) == k; last = last + 1; end
        items(end+1, :) = [i last k]; %#ok<AGROW>
        i = last + 1;
    end
end
if isempty(items)
    cannot(sprintf("no panel in %s %d can stretch over it", W.col, c));
end
gone = top - 1 + find(cells(top:bot, c) == 0);   % the empty cells it takes out
removed = [gone(:) repmat(c, numel(gone), 1)];
old = reshape(e(items(:, 2) + 1) - e(items(:, 1)), 1, []);   % their heights
ny = e(top) + [0 cumsum(old)] * (e(bot + 1) - e(top)) / sum(old);   % their lines, stretched
ny(end) = e(bot + 1);
keep = [0 e(end)];   % the lines the rest of the grid needs: wherever a column's cell changes (each empty cell its own)
for j = 1:nc
    for i = 1:nr - 1
        if j == c && i >= top - 1 && i <= bot; continue; end   % the stretched part of column C: its new lines
        if cells(i, j) == 0 || cells(i, j) ~= cells(i + 1, j); keep(end+1) = e(i + 1); end %#ok<AGROW>
    end
end
for q = 1:numel(ny)   % a stretched line on one that stays: the same line
    [d, at] = min(abs(keep - ny(q)));
    if d <= tol; ny(q) = keep(at); end
end
E = unique([keep ny]);
lineAt = @(y) find(abs(E - y) <= tol, 1);
for k = 1:numel(P)
    q = find(items(:, 3) == k, 1);
    if isempty(q)
        if ~all(isfinite([P(k).row P(k).rowSpan])); continue; end
        r0 = min(max(round(P(k).row), 1), nr);
        r1 = min(nr, r0 + max(1, round(P(k).rowSpan)) - 1);
        y = [e(r0) e(r1 + 1)];
    else
        y = ny([q q + 1]);
    end
    P(k).row = lineAt(y(1));
    P(k).rowSpan = lineAt(y(2)) - lineAt(y(1));
end
n = numel(E) - 1;
h = diff(E);
G.rowHeights = gridKeptSizes(round(h / min(h), 3), G.rowHeights);
g = reshape(double(G.rowGaps), 1, []);
if nr > 1 && numel(g) == nr - 1   % each line keeps its gap; a stretched line the one over the panel under it
    ng = zeros(1, n - 1);
    for m = 2:n
        o = find(e(2:nr) == E(m), 1);
        if ~isempty(o) && ismember(E(m), keep)
            ng(m - 1) = g(o);
        else
            q = find(ny == E(m), 1);
            ng(m - 1) = g(min(max(items(q, 1) - 1, 1), nr - 1));
        end
    end
    G.rowGaps = ng;
end
G.rows = n;
fig.grid = G;
fig.panels = P;
what = idList([P(items(:, 3)).id]) + " stretched over it";
if numel(gone) > 1; what = idList([P(items(:, 3)).id]) + sprintf(" stretched over %s %d's %d empty cells", W.col, c, numel(gone)); end
end


function [fig, what] = shiftUp(fig, r, c, W)
%shiftUp  The panels below the cell (R, C) in column C move up one row; each must lie in column C alone.
P = fig.panels;
below = find(arrayfun(@(p) p.col <= c && p.col + p.colSpan - 1 >= c && p.row > r, P));
if isempty(below)
    cannot(sprintf("nothing lies %s it in %s %d", W.below, W.col, c));
end
[~, o] = sort([P(below).row]);
below = below(o);
for k = below
    if P(k).colSpan > 1
        cannot(sprintf("%s spans %s %d-%d", P(k).id, W.cols, P(k).col, P(k).col + P(k).colSpan - 1));
    end
end
for k = below; fig.panels(k).row = P(k).row - 1; end
what = idList([P(below).id]) + " moved " + W.up;
end


function [fig, what] = grow(fig, r, c, side, W)
%grow  The panel next to the cell (R, C), above it (SIDE -1) or below it (1), grows over it; it must lie in column C alone.
cells = EphysAnalysisConfig.figureCells(fig);
where = W.above;
dir = W.down;
if side > 0
    where = W.below;
    dir = W.up;
end
rn = r + side;
if rn < 1 || rn > size(cells, 1) || cells(rn, c) == 0
    cannot(sprintf("no panel lies %s it", where));
end
k = cells(rn, c);
p = fig.panels(k);
if p.colSpan > 1
    cannot(sprintf("%s spans %s %d-%d", p.id, W.cols, p.col, p.col + p.colSpan - 1));
end
fig.panels(k).rowSpan = p.rowSpan + 1;
if side > 0; fig.panels(k).row = p.row - 1; end
what = p.id + " grown " + dir + " over it";
end


function [fig, what] = deleteRow(fig, r, W)
%deleteRow  Row R out of the grid (dropGridRow), unless a panel lies in it alone.
cells = EphysAnalysisConfig.figureCells(fig);
nr = size(cells, 1);
alone = zeros(1, 0);
for k = unique(cells(r, cells(r, :) ~= 0))
    if ~(r > 1 && any(cells(r - 1, :) == k)) && ~(r < nr && any(cells(r + 1, :) == k)); alone(end+1) = k; end %#ok<AGROW>
end
if ~isempty(alone)
    cannot(sprintf("%s %d holds %s", W.row, r, idList([fig.panels(alone).id])));
end
fig = dropGridRow(fig, r);
what = sprintf("%s %d deleted", W.row, r);
end


function [fig, dropped] = dropEmptyRows(fig)
%dropEmptyRows  FIG without the grid rows no panel covers (one row kept at least); DROPPED: their numbers before.
cells = EphysAnalysisConfig.figureCells(fig);
dropped = zeros(1, 0);
for i = size(cells, 1):-1:1
    if any(cells(i, :)) || fig.grid.rows <= 1; continue; end
    fig = dropGridRow(fig, i);
    dropped = [i dropped]; %#ok<AGROW>
end
end


function s = droppedText(d, word)
%droppedText  "; the empty row 4 dropped" for the rows (columns) D, "" for none.
s = "";
if isempty(d); return; end
if isscalar(d)
    s = sprintf("; the empty %s %d dropped", word, d);
else
    s = sprintf("; the empty %ss %s dropped", word, idList(string(d)));
end
end


function s = idList(ids)
%idList  "a", "a and b", "a, b and c".
ids = string(ids);
s = ids(end);
if numel(ids) > 1; s = strjoin(ids(1:end-1), ", ") + " and " + ids(end); end
end


function cannot(why)
%cannot  The CannotRemoveCell error, WHY its message.
error('EphysAnalysisConfig:CannotRemoveCell', '%s', why);
end
