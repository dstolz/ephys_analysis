function closePanelFilterDialog(obj, force)
%closePanelFilterDialog  Close a panel's Filter window when the editor no longer shows the panel it edits.
%   closePanelFilterDialog(OBJ) closes the window (editPanelFilter,
%   OBJ.PanelFilterWindow) unless the figure editor shows its figure (by
%   id, followed through renames: followedFigureId) and its panel:
%   another figure or panel picked, the panel removed, a config opened, so
%   an OK cannot land on them (as closeTrialMeasureDialog does for the
%   Trial measure window). closePanelFilterDialog(OBJ, true) closes it
%   whatever is shown. Closed so, it is canceled: nothing changes.
%
%   See also editPanelFilter, closeTrialMeasureDialog.
if nargin < 2; force = false; end
d = obj.PanelFilterWindow;
if isempty(d) || ~isvalid(d); return; end
T = obj.PanelFilterTarget;
k = obj.SelectedFigure;
j = obj.SelectedPanel;
F = obj.Config.Figures;
shows = k >= 1 && k <= numel(F) && F(k).id == followedFigureId(obj, T.FigureId) && j >= 1 && j <= numel(F(k).panels) ...
    && F(k).panels(j).id == T.PanelId;
if force || ~shows
    d.cancel();
    if isvalid(d); delete(d); end
    obj.PanelFilterWindow = [];
end
end
