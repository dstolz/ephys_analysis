function L = figureArrange(sz, grid, cells, opts)
%figureArrange  Where a figure's panels go: their plot areas, note bands, legend and title, in pixels (renderFigure's layout; pure).
%   L = figureArrange(SZ, GRID, CELLS, Name=Value) lays out a figure of
%   SZ = [width height] pixels (the area drawn in). GRID is the figure's
%   grid (EphysAnalysisConfig's Figure.grid: rows, cols, rowHeights,
%   colWidths, spacing, gapUnits, rowGap, colGap, rowGaps, colGaps). CELLS
%   has one element per panel drawn:
%     r1, r2, c1, c2  the rows and columns it covers (clipped to the grid)
%     size        [width height], its share (0-1) of its cell
%     align, valign  where it sits in its cell when smaller: left / center
%                 / right, top / middle / bottom
%     inset       [left bottom right top]: the room its labels take round
%                 its plot area (tick labels, axis labels, title, a color
%                 bar outside), 0 on a side where nothing sits
%     band        "" or the side of its note's band: "below", "above",
%                 "left" or "right"
%     need        the band's thickness the note asks for (its text, and the
%                 panel's labels on that side, which the band holds: give
%                 that side's inset as 0)
%     shares      its axes' shares of its plot area, top to bottom (1: one
%                 axes; a coherence panel's magnitude over its phase: [2 1])
%
%   The rows and columns are laid out so their plot areas line up across
%   the grid. Each row boundary gets the room the tallest labels there take
%   (the panels ending in the row above: their bottom insets; those
%   starting in the row below: their top insets) and the gap; columns the
%   same with the left and right insets. The rest is the plot areas, in the
%   exact proportions of rowHeights and colWidths ([] = equal). So a gap is
%   the clear space between neighboring panels' labels: 0 makes plot areas
%   flush where no label sits between them (a time stack whose inner tick
%   labels are dropped). The gaps (figureArrange's L.gaps):
%     spacing "loose" | "compact" | "tight" | "none"   every gap that many
%                 px (EphysAnalysisConfig.GridSpacingPx: 24, 12, 6, 0)
%     spacing "custom"   rowGap between every two rows and colGap between
%                 every two columns, unless rowGaps (rows - 1 values: between
%                 rows i and i + 1) or colGaps (cols - 1) set them apart, in
%                 gapUnits: "px", or "%" of the mean row's plot height (row
%                 gaps) and of the mean column's plot width (column gaps), so
%                 the figure keeps its look at any size
%   A panel smaller than its cell (size below 1) takes that share of the
%   cell's plot area at its alignment; then its note's band, at most half
%   of it, comes off the side the note is on, and its axes share what is
%   left top to bottom. A margin of Margin px goes round it all.
%
%   Options
%     Top      px kept over the grid for the figure's title (default 0)
%     Legend   struct(side, size): the figure's legend in a band on a side
%              of the grid ("north", "south", "east", "west"; "" = none) of
%              its size [width height] px
%     Margin   px round the figure (default 6)
%
%   L fields (pixel boxes [x y width height] from the bottom left)
%     area    the grid's box, inside the margin, title and legend band
%     rows    nrows x 2: each row's plot area [bottom top]
%     cols    ncols x 2: each column's plot area [left right]
%     gaps    struct(rows, cols): the gaps in px
%     panels  one per CELLS: cell (its cell's plot area), box (its plot
%             area), axes (one row per share: each axes' plot box, top to
%             bottom), band (its note's band; [] = none)
%     legend  the legend's box ([] = none)
%     title   the title band's box ([] when Top is 0)
%
%   See also renderFigure, figureLayout, EphysAnalysisConfig.GridSpacings.

arguments
    sz (1,2) double
    grid (1,1) struct
    cells struct
    opts.Top (1,1) double = 0
    opts.Legend struct = struct('side', "", 'size', [0 0])
    opts.Margin (1,1) double = 6
end
nr = max(1, round(double(grid.rows)));
nc = max(1, round(double(grid.cols)));
m = opts.Margin;
x0 = m; y0 = m;
x1 = max(x0 + 1, sz(1) - m);
y1 = max(y0 + 1, sz(2) - m);
L = struct('area', [], 'rows', zeros(nr, 2), 'cols', zeros(nc, 2), 'gaps', struct('rows', [], 'cols', []), ...
    'panels', struct('cell', {}, 'box', {}, 'axes', {}, 'band', {}), 'legend', [], 'title', []);

% the title over the grid, the legend in a band on its side
if opts.Top > 0
    L.title = [x0, y1 - opts.Top, x1 - x0, opts.Top];
    y1 = y1 - opts.Top;
end
lg = opts.Legend;
side = "";
if isstruct(lg) && isfield(lg, 'side'); side = string(lg.side); end
pad = 8;   % between the legend and the grid
if ismember(side, ["north" "south" "east" "west"])
    w = lg.size(1); h = lg.size(2);
    switch side
        case "east"
            x1 = x1 - w - pad;
            L.legend = [x1 + pad, 0, w, h];
        case "west"
            L.legend = [x0, 0, w, h];
            x0 = x0 + w + pad;
        case "north"
            y1 = y1 - h - pad;
            L.legend = [0, y1 + pad, w, h];
        case "south"
            L.legend = [0, y0, w, h];
            y0 = y0 + h + pad;
    end
end
L.area = [x0, y0, max(1, x1 - x0), max(1, y1 - y0)];

% the room the labels take at each row and column boundary
top = zeros(1, nr); bot = zeros(1, nr); lef = zeros(1, nc); rig = zeros(1, nc);
for k = 1:numel(cells)
    c = cells(k);
    in = max(0, double(c.inset));
    top(c.r1) = max(top(c.r1), in(4));
    bot(c.r2) = max(bot(c.r2), in(2));
    lef(c.c1) = max(lef(c.c1), in(1));
    rig(c.c2) = max(rig(c.c2), in(3));
end
[gr, gc, pct] = gapsOf(grid, nr, nc);

% rows, top to bottom: their plot areas in the exact proportions of rowHeights
rh = sizesOf(grid.rowHeights, nr);
avail = L.area(4) - sum(top) - sum(bot);
if pct; gr = gr / 100 * max(avail, 0) / (nr + sum(gr) / 100); end
plotH = max(avail - sum(gr), nr);
h = plotH * rh / sum(rh);
y = L.area(2) + L.area(4);
for i = 1:nr
    L.rows(i, 2) = y - top(i);
    L.rows(i, 1) = L.rows(i, 2) - h(i);
    y = L.rows(i, 1) - bot(i);
    if i < nr; y = y - gr(i); end
end
% columns, left to right
cw = sizesOf(grid.colWidths, nc);
avail = L.area(3) - sum(lef) - sum(rig);
if pct; gc = gc / 100 * max(avail, 0) / (nc + sum(gc) / 100); end
plotW = max(avail - sum(gc), nc);
w = plotW * cw / sum(cw);
x = L.area(1);
for j = 1:nc
    L.cols(j, 1) = x + lef(j);
    L.cols(j, 2) = L.cols(j, 1) + w(j);
    x = L.cols(j, 2) + rig(j);
    if j < nc; x = x + gc(j); end
end
L.gaps = struct('rows', gr, 'cols', gc);

% the legend beside the grid's plot areas, in the middle of them
if ~isempty(L.legend)
    if ismember(side, ["east" "west"])
        mid = (L.rows(1, 2) + L.rows(end, 1)) / 2;
        L.legend(2) = mid - L.legend(4) / 2;
    else
        mid = (L.cols(1, 1) + L.cols(end, 2)) / 2;
        L.legend(1) = mid - L.legend(3) / 2;
    end
end

% each panel: its cell, its share of it, its note's band, its axes
for k = 1:numel(cells)
    c = cells(k);
    cellBox = [L.cols(c.c1, 1), L.rows(c.r2, 1), L.cols(c.c2, 2) - L.cols(c.c1, 1), L.rows(c.r1, 2) - L.rows(c.r2, 1)];
    s = min(max(double(c.size), 0.01), 1);
    bw = cellBox(3) * s(1);
    bh = cellBox(4) * s(2);
    bx = cellBox(1) + (cellBox(3) - bw) * shareOf(c.align, ["left" "center" "right"]);
    by = cellBox(2) + (cellBox(4) - bh) * shareOf(c.valign, ["bottom" "middle" "top"]);
    box = [bx by bw bh];
    band = [];
    b = max(0, double(c.need));
    switch string(c.band)
        case "below"
            b = min(b, box(4) / 2);
            band = [box(1), box(2), box(3), b];
            box = box + [0 b 0 -b];
        case "above"
            b = min(b, box(4) / 2);
            band = [box(1), box(2) + box(4) - b, box(3), b];
            box(4) = box(4) - b;
        case "left"
            b = min(b, box(3) / 2);
            band = [box(1), box(2), b, box(4)];
            box = box + [b 0 -b 0];
        case "right"
            b = min(b, box(3) / 2);
            band = [box(1) + box(3) - b, box(2), b, box(4)];
            box(3) = box(3) - b;
    end
    f = reshape(double(c.shares), 1, []);
    if isempty(f) || any(~(f > 0)); f = 1; end
    f = f / sum(f);
    A = zeros(numel(f), 4);
    yTop = box(2) + box(4);
    for i = 1:numel(f)
        hi = box(4) * f(i);
        A(i, :) = [box(1), yTop - hi, box(3), hi];
        yTop = yTop - hi;
    end
    L.panels(k) = struct('cell', cellBox, 'box', box, 'axes', A, 'band', band);
end
end


function [gr, gc, pct] = gapsOf(grid, nr, nc)
%gapsOf  The row and column gaps a grid asks for, and whether they are percents (spacing "custom", gapUnits "%").
pct = false;
sp = string(grid.spacing);
names = EphysAnalysisConfig.GridSpacings;
px = EphysAnalysisConfig.GridSpacingPx;
i = find(names(1:numel(px)) == sp, 1);
if ~isempty(i)
    gr = repmat(px(i), 1, nr - 1);
    gc = repmat(px(i), 1, nc - 1);
    return
end
% custom: one value each way, unless the lists set the gaps apart
pct = string(grid.gapUnits) == "%";
gr = listOf(grid.rowGaps, grid.rowGap, nr - 1);
gc = listOf(grid.colGaps, grid.colGap, nc - 1);
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


function s = shareOf(v, order)
%shareOf  0, 0.5 or 1 for the first, second or third of ORDER (0.5 when V is none of them).
s = (find(string(v) == order, 1) - 1) / 2;
if isempty(s); s = 0.5; end
end
