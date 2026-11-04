function onRemoveCell(obj, rc, how)
%onRemoveCell  Take the empty cell RC ([row column]) out of the selected figure's grid, the panels around it closing the gap as HOW says.
%   The gray minus sign in an empty cell of the arrangement's schematic
%   (and a right click on the cell) opens a menu of the ways
%   (EphysAnalysisConfig.cellRemovals: stretch its column or row over it,
%   shift the cells below it up or right of it left, grow a panel next to
%   it over it, delete its row or column), those that cannot grayed with
%   why (drawFigureSchematic); the one picked comes here. HOW is
%   EphysAnalysisConfig.removeCell's ("stretchColumn", "shiftUp",
%   "growLeft", "deleteRow", ...). The rows and columns left without a
%   panel go too. The edit ends as every structural one does
%   (commitFigureEdit: the schematic, the editor and the preview follow),
%   undoable as "Remove cell"; the status bar says what happened. A way
%   that cannot remove the cell leaves the figure as it was, and the
%   status bar says why.
%
%   See also EphysAnalysisConfig.removeCell, EphysAnalysisConfig.cellRemovals.
arguments
    obj (1,1) EphysAnalysisApp
    rc (1,2) double
    how (1,1) string
end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
cfg = obj.gatherConfig();
fig = cfg.Figures(k);
try
    [fig, what] = EphysAnalysisConfig.removeCell(fig, rc, how);
catch ME
    msg = string(ME.message);
    if ~endsWith(msg, "."); msg = msg + "."; end
    obj.setStatus(sprintf("Remove cell at row %d, column %d: %s", rc(1), rc(2), msg));
    return
end
cfg.Figures(k) = fig;
commitFigureEdit(obj, cfg, sprintf("Removed the empty cell at row %d, column %d: %s.", rc(1), rc(2), what), Action="Remove cell");
end
