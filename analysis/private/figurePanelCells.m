function C = figurePanelCells(grid, panels)
%figurePanelCells  Each panel's rows and columns (clipped to the grid), its size in its cell and its alignment there.
%
%   See also renderFigure, renderProbeFigure.
nr = max(1, round(double(grid.rows)));
nc = max(1, round(double(grid.cols)));
C = struct('r1', {}, 'r2', {}, 'c1', {}, 'c2', {}, 'size', {}, 'align', {}, 'valign', {});
for k = 1:numel(panels)
    p = panels(k);
    r = min(max(1, round(p.row)), nr);
    c = min(max(1, round(p.col)), nc);
    s = double(p.size);
    if ~(numel(s) == 2 && all(isfinite(s) & s > 0)); s = [1 1]; end
    C(k) = struct('r1', r, 'r2', min(nr, r + max(1, round(p.rowSpan)) - 1), 'c1', c, ...
        'c2', min(nc, c + max(1, round(p.colSpan)) - 1), 'size', min(reshape(s, 1, 2), 1), ...
        'align', string(p.align), 'valign', string(p.valign));
end
end
