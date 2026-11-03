function [fig, ids] = placePanels(fig, block, where, anchorId, opts)
%placePanels  Add another figure's panels to a figure as one block above, below, left or right of a panel.
%   [FIG, IDS] = EphysAnalysisConfig.placePanels(FIG, BLOCK, WHERE,
%   ANCHORID) adds every panel of BLOCK (a figure entry, normalizeFigure'd:
%   a figure saved as a panel type, FigureTemplate.panelTypes) to figure
%   FIG next to its panel ANCHORID, as placePanel adds one panel, keeping
%   the block's own arrangement: its panels' places and spans, its rows'
%   heights and columns' widths relative to one another and the gaps
%   between them (a raster flush over its PSTH stays flush). WHERE:
%     "below" / "above"  the block's rows become new rows of FIG right
%              after the anchor's last row (before its first row); the
%              block spans the anchor's columns. Each new row is as tall
%              as the anchor's row on average (the block's rowHeights
%              kept in proportion).
%     "right" / "left"   the block's columns become new columns after the
%              anchor's last column (before its first); it spans the
%              anchor's rows, each new column as wide as the anchor's on
%              average.
%   Where the block has a column boundary inside one of the anchor's
%   columns (a 1 x 2 block below a panel one column wide), that column is
%   split in FIG at the same share of its width, and every panel across it
%   spans its pieces, so each row keeps its look and the plot areas still
%   line up across the grid. The rows (columns) after the new ones move
%   down (right); the panels whose span crosses where they go grow by
%   them, as with placePanel. A figure without panels takes BLOCK's grid
%   and panels as they are; ANCHORID is then not needed.
%
%   The gaps: FIG's gaps stay. The block's gaps between its own rows and
%   columns come with it (between a new row and FIG's rows, the gap that
%   was there, on both sides); when they differ from FIG's spacing, FIG's
%   grid becomes "custom" with gap lists (rowGaps, colGaps) in its own
%   units, FIG's gaps kept. A block gap in other units than FIG's is
%   FIG's gap there (0 stays 0).
%
%   The panels keep their type, options, layers, alignment, note, overlays
%   and size in their cell. A panel id FIG has already becomes
%   "<type>_<n>" (the smallest n free). IDS: the block's panels' ids in
%   FIG, in the block's order (FIG.panels(end-numel(IDS)+1:end)).
%   Alignment="own" gives each panel that takes the figure's event
%   reference, window or trial selection ("default") the block's own, when
%   the block has its own (a struct); "figure" (the default) leaves them
%   "default": they follow FIG's.
%   BLOCK's other settings (what it observes, its page size, latency,
%   appearance, looks, sessions and probe layout) are not used: FIG keeps
%   its own.
%
%   Errors: EphysAnalysisConfig:NoPanel (BLOCK has no panel; no anchor, or
%   no such panel).
%
%   See also EphysAnalysisConfig.placePanel, FigureTemplate.panelTypes,
%   EphysAnalysisConfig.removePanel.

arguments
    fig (1,1) struct
    block (1,1) struct
    where (1,1) string {mustBeMember(where, ["above" "below" "left" "right"])} = "below"
    anchorId (1,1) string = ""
    opts.Alignment (1,1) string {mustBeMember(opts.Alignment, ["figure" "own"])} = "figure"
end

B = EphysAnalysisConfig.normalizeFigure(block, "block");
if isempty(B.panels)
    error('EphysAnalysisConfig:NoPanel', 'The figure placed has no panel.');
end
P = B.panels;
if opts.Alignment == "own"   % the block's own event, window and selection, where its panels take the figure's
    for f = ["ref" "window" "selection"]
        if ~isstruct(B.(f)); continue; end
        for k = 1:numel(P)
            if ~isstruct(P(k).(f)); P(k).(f) = B.(f); end
        end
    end
end
taken = string.empty(1, 0);
if ~isempty(fig.panels); taken = [fig.panels.id]; end
for k = 1:numel(P)
    if ismember(P(k).id, taken); P(k).id = EphysAnalysisConfig.freeId(P(k).type, taken); end
    taken(end+1) = P(k).id; %#ok<AGROW>
end
ids = [P.id];
B.panels = P;

if isempty(fig.panels)   % the block is the figure
    fig.grid = B.grid;
    fig.panels = P;
    return
end
a = [];
if anchorId ~= ""; a = find([fig.panels.id] == anchorId, 1); end
if isempty(a)
    if anchorId == ""
        error('EphysAnalysisConfig:NoPanel', 'Place the panels %s one of the figure''s panels: give its id.', where);
    end
    error('EphysAnalysisConfig:NoPanel', 'The figure has no panel "%s".', anchorId);
end

% columns are rows turned a quarter: place them as rows of the transposed grids
across = ismember(where, ["left" "right"]);
if across
    fig = transposed(fig);
    B = transposed(B);
end
fig = placeRows(fig, B, a, ismember(where, ["below" "right"]));
if across; fig = transposed(fig); end
end


function H = placeRows(H, B, a, after)
%placeRows  Block B's rows into H after (AFTER) or before the rows of H's panel A; its columns split to B's where needed.
G = H.grid;
nr = rowsOf(G.rows);
nc = rowsOf(G.cols);
[grH, gcH, unitsH, preset] = gapsOf(G, nr, nc);
[grB, gcB, unitsB] = gapsOf(B.grid, rowsOf(B.grid.rows), rowsOf(B.grid.cols));
grB = inUnits(grB, unitsB, unitsH, G.rowGap, preset);
gcB = inUnits(gcB, unitsB, unitsH, G.colGap, preset);

% the anchor's columns, split where the block has a boundary inside one of them
A = H.panels(a);
w = sizesOf(G.colWidths, nc);
span = A.col:min(A.col + A.colSpan - 1, nc);
W = sum(w(span));
hb = [0 cumsum(w(span))] / W;
nb = rowsOf(B.grid.cols);
bw = sizesOf(B.grid.colWidths, nb);
bb = [0 cumsum(bw)] / sum(bw);
tol = 1e-9;
for i = numel(span):-1:1
    c = span(i);
    q = find(bb > hb(i) + tol & bb < hb(i + 1) - tol);
    if isempty(q); continue; end
    cuts = [hb(i) bb(q) hb(i + 1)];
    pieces = diff(cuts) * W;
    m = numel(pieces) - 1;   % the columns added
    w = [w(1:c-1) pieces w(c+1:end)];
    gcH = [gcH(1:c-1) gcB(q - 1) gcH(c:end)];   % between the pieces: the block's own gaps there
    for k = 1:numel(H.panels)
        p = H.panels(k);
        if p.col > c
            H.panels(k).col = p.col + m;
        elseif p.col + p.colSpan - 1 >= c
            H.panels(k).colSpan = p.colSpan + m;
        end
    end
    nc = nc + m;
end
A = H.panels(a);
span = A.col:min(A.col + A.colSpan - 1, nc);
U = [0 cumsum(w(span))] / W;
at = zeros(1, nb + 1);   % each block boundary's index among the anchor's column boundaries
for q = 1:nb + 1
    [~, at(q)] = min(abs(U - bb(q)));
end

% the new rows: the block's heights in proportion, their mean the height of the row they copy
h = sizesOf(G.rowHeights, nr);
if after
    ins = A.row + A.rowSpan;
    from = ins - 1;
else
    ins = A.row;
    from = A.row;
end
from = min(max(from, 1), nr);
R = rowsOf(B.grid.rows);
bh = sizesOf(B.grid.rowHeights, R);
h = [h(1:ins-1), bh / mean(bh) * h(from), h(ins:end)];
for k = 1:numel(H.panels)
    p = H.panels(k);
    if p.row >= ins
        H.panels(k).row = p.row + R;
    elseif p.row + p.rowSpan - 1 >= ins
        H.panels(k).rowSpan = p.rowSpan + R;
    end
end
if nr == 1
    edge = oneGap(G, "row", preset);
elseif ins == 1
    edge = grH(1);
elseif ins > nr
    edge = grH(end);
else
    edge = grH(ins - 1);
end
if ins == 1
    grH = [grB, edge, grH];
elseif ins > nr
    grH = [grH, edge, grB];
else
    grH = [grH(1:ins-2), edge, grB, edge, grH(ins:end)];
end
nr = nr + R;

% the block's panels at their new places
P = B.panels;
for k = 1:numel(P)
    p = P(k);
    c1 = min(max(p.col, 1), nb);
    c2 = min(max(p.col + p.colSpan - 1, c1), nb);
    P(k).row = ins + p.row - 1;
    P(k).col = A.col + at(c1) - 1;
    P(k).colSpan = at(c2 + 1) - at(c1);
end
H.panels = [H.panels, P];

G.rows = nr;
G.cols = nc;
G.rowHeights = keptSizes(h, G.rowHeights);
G.colWidths = keptSizes(w, G.colWidths);
H.grid = setGaps(G, grH, gcH, unitsH, preset);
end


function F = transposed(F)
%transposed  Figure F's grid and panels turned a quarter: rows for columns (heights for widths, row gaps for column gaps).
G = F.grid;
F.grid.rows = G.cols;          F.grid.cols = G.rows;
F.grid.rowHeights = G.colWidths; F.grid.colWidths = G.rowHeights;
F.grid.rowGap = G.colGap;      F.grid.colGap = G.rowGap;
F.grid.rowGaps = G.colGaps;    F.grid.colGaps = G.rowGaps;
for k = 1:numel(F.panels)
    p = F.panels(k);
    F.panels(k).row = p.col;   F.panels(k).col = p.row;
    F.panels(k).rowSpan = p.colSpan;   F.panels(k).colSpan = p.rowSpan;
end
end


function [gr, gc, units, preset] = gapsOf(G, nr, nc)
%gapsOf  Grid G's row and column gaps as lists, their units ("px" | "%") and its named spacing ("" = custom): as figureArrange reads them.
names = EphysAnalysisConfig.GridSpacings;
px = EphysAnalysisConfig.GridSpacingPx;
i = find(names(1:numel(px)) == string(G.spacing), 1);
if ~isempty(i)
    gr = repmat(px(i), 1, nr - 1);
    gc = repmat(px(i), 1, nc - 1);
    units = "px";
    preset = string(G.spacing);
    return
end
units = string(G.gapUnits);
preset = "";
gr = listOf(G.rowGaps, G.rowGap, nr - 1);
gc = listOf(G.colGaps, G.colGap, nc - 1);
end


function g = oneGap(G, side, preset)
%oneGap  Grid G's gap between rows (SIDE "row") or columns where it has no list to read it from.
if preset ~= ""
    g = EphysAnalysisConfig.GridSpacingPx(EphysAnalysisConfig.GridSpacings == preset);
else
    g = double(G.(side + "Gap"));
    if ~(isscalar(g) && isfinite(g) && g >= 0); g = 0; end
end
end


function g = inUnits(g, from, to, own, preset)
%inUnits  Block gaps G (in units FROM) in units TO: as they are in the same units, else 0 where 0 and the figure's own gap OWN elsewhere.
if from == to || isempty(g); return; end
if preset ~= ""; own = EphysAnalysisConfig.GridSpacingPx(EphysAnalysisConfig.GridSpacings == preset); end
g(g ~= 0) = own;
end


function G = setGaps(G, gr, gc, units, preset)
%setGaps  Grid G with row gaps GR and column gaps GC: its named spacing while every gap is that one's, else custom gap lists in UNITS.
if preset ~= ""
    v = EphysAnalysisConfig.GridSpacingPx(EphysAnalysisConfig.GridSpacings == preset);
    if all([gr gc] == v); return; end
    G.spacing = "custom";
    G.gapUnits = units;
    G.rowGap = v;
    G.colGap = v;
end
G.rowGaps = gapList(gr, G.rowGap);
G.colGaps = gapList(gc, G.colGap);
end


function g = gapList(g, one)
%gapList  The gap list G, [] when each gap is ONE (the grid's single gap).
if all(g == one); g = []; end
end


function g = listOf(list, one, n)
%listOf  N gaps: LIST when it has N values, else ONE each (a value that is not a number >= 0 counts as 0).
g = reshape(double(list), 1, []);
if numel(g) ~= n
    v = double(one);
    if ~isscalar(v); v = 0; end
    g = repmat(v, 1, n);
end
g(~(isfinite(g) & g >= 0)) = 0;
end


function s = sizesOf(sizes, n)
%sizesOf  N relative sizes: SIZES when they are N positive numbers, else equal ones.
s = ones(1, n);
v = reshape(double(sizes), 1, []);
if numel(v) == n && all(isfinite(v) & v > 0); s = v; end
end


function s = keptSizes(s, was)
%keptSizes  The relative sizes S, [] (equal) when they are all equal and the grid had none of its own (WAS []).
if isempty(was) && all(abs(s - s(1)) <= 1e-12 * max(abs(s(1)), 1)); s = []; end
end


function n = rowsOf(v)
%rowsOf  A grid's row (column) count, at least 1.
n = max(1, round(double(v)));
end
