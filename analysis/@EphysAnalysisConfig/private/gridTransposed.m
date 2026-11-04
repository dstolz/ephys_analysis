function F = gridTransposed(F)
%gridTransposed  Figure F's grid and panels turned a quarter: rows for columns (heights for widths, row gaps for column gaps).
%   Turning twice gives F back. The grid edits that work along rows
%   (placePanels, removePanel, removeCell) do columns as the rows of the
%   turned grid.
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
