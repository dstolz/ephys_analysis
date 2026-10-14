function [cells, overlap] = figureCells(fig)
%figureCells  Which panel holds each cell of a figure's grid.
%   [CELLS, OVERLAP] = EphysAnalysisConfig.figureCells(FIG) is a rows x
%   cols matrix of FIG.grid: 0 for an empty cell, k for a cell that panel
%   FIG.panels(k) covers (its row / col and spans). A cell two panels
%   cover holds the first; OVERLAP lists each such pair once, an n x 2
%   matrix of panel indices [first second] (n = 0 when none overlap). The
%   parts of a panel outside the grid are left out (validate reports them).
%
%   See also EphysAnalysisConfig.placePanel, EphysAnalysisConfig.removePanel.

nr = gridCount(fig.grid.rows);
nc = gridCount(fig.grid.cols);
cells = zeros(nr, nc);
overlap = zeros(0, 2);
for k = 1:numel(fig.panels)
    p = fig.panels(k);
    if ~all(isfinite([p.row p.col p.rowSpan p.colSpan])); continue; end
    rr = max(1, round(p.row)) : min(nr, round(p.row) + round(p.rowSpan) - 1);
    cc = max(1, round(p.col)) : min(nc, round(p.col) + round(p.colSpan) - 1);
    for i = rr
        for j = cc
            if cells(i, j) == 0
                cells(i, j) = k;
            elseif ~ismember([cells(i, j) k], overlap, 'rows')
                overlap(end+1, :) = [cells(i, j) k]; %#ok<AGROW>
            end
        end
    end
end
end


function n = gridCount(v)
%gridCount  A grid's rows or columns as a whole number >= 0 (0 when not a usable number).
n = 0;
if isscalar(v) && isfinite(v) && v >= 1
    n = floor(v);
end
end
