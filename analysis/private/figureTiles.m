function [nRowUnits, nColUnits, tileOf, spanOf] = figureTiles(grid, panels)
%figureTiles  A figure's arrangement as a tiled layout of equal tiles: each panel's tile and span.
%   [NROWUNITS, NCOLUNITS, TILEOF, SPANOF] = figureTiles(GRID, PANELS)
%   expands the figure's grid (EphysAnalysisConfig's Figure.grid: rows,
%   cols, rowHeights, colWidths) into equal units, since a tiledlayout has
%   equal tiles only. Each row's relative height is quantized to quarter
%   steps of the smallest (round(4 * h / min(h))) and the steps divided by
%   their greatest common divisor, so [1 2] is 1 and 2 units, [1 1.5] is 2
%   and 3; beyond 32 units in all the steps get coarser (halves, wholes,
%   then shares of 32), so [1 1.37] draws as [1 1.25]. The columns go the
%   same way. rowHeights / colWidths [] (or not one positive size per row /
%   column) mean equal sizes, one unit each. Pure: no graphics.
%     NROWUNITS, NCOLUNITS  the tiled layout's grid size
%     TILEOF(k)   the linear tile index (row-major, as nexttile numbers
%                 them) of the top-left unit cell of PANELS(k)
%     SPANOF(k,:) its span [unit rows, unit columns]: the units of the rows
%                 and columns it covers
%   A panel reaching past the grid is clipped to it.
%
%   See also renderFigure, EphysAnalysisConfig.figureCells.

arguments
    grid (1,1) struct
    panels struct
end
u = unitsOf(grid.rowHeights, grid.rows);
v = unitsOf(grid.colWidths, grid.cols);
nRowUnits = sum(u);
nColUnits = sum(v);
cu = [0 cumsum(u)];
cv = [0 cumsum(v)];
np = numel(panels);
tileOf = zeros(np, 1);
spanOf = zeros(np, 2);
for k = 1:np
    p = panels(k);
    r = min(max(1, round(p.row)), numel(u));
    c = min(max(1, round(p.col)), numel(v));
    r2 = min(numel(u), r + max(1, round(p.rowSpan)) - 1);
    c2 = min(numel(v), c + max(1, round(p.colSpan)) - 1);
    tileOf(k) = cu(r) * nColUnits + cv(c) + 1;
    spanOf(k, :) = [sum(u(r:r2)) sum(v(c:c2))];
end
end


function q = unitsOf(sizes, n)
%unitsOf  The units of N rows (or columns) of relative SIZES: quarter steps of the smallest, at most 32 in all.
n = max(1, round(double(n)));
q = ones(1, n);
h = reshape(double(sizes), 1, []);
if numel(h) ~= n || any(~isfinite(h) | h <= 0); return; end
cap = max(32, n);   % one unit each cannot be fewer
for step = [4 2 1]
    q = max(1, round(step * h / min(h)));
    q = q / gcdOf(q);
    if sum(q) <= cap; return; end
end
exact = h / sum(h) * cap;
q = max(1, floor(exact));   % shares of the cap, the smallest one unit
while sum(q) > cap
    over = q - exact;   % take a unit from the row furthest above its share (never below one): proportions stay in order
    over(q <= 1) = -Inf;
    [~, k] = max(over);
    if ~isfinite(over(k)); break; end
    q(k) = q(k) - 1;
end
end


function g = gcdOf(q)
%gcdOf  The greatest common divisor of the whole numbers Q.
g = q(1);
for x = q(2:end)
    g = gcd(g, x);
end
end
