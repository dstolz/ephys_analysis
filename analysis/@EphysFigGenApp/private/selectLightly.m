function selectLightly(obj, j)
%selectLightly  Arrange's press on a box that was not selected: panel J of the selected figure is selected at once, the editor's rows filled at the release.
%   selectLightly(OBJ, J) makes panel J the selected one (SelectedPanel;
%   its first layer, SelectedLayer 1, when it was another panel), draws
%   the boxes as the selection now is (arrangeSelectBoxes: its box blue,
%   the size labels) and shows its place in the Position and Size fields
%   (showPanelPlace), so the drag that may follow shows it. The rest of
%   the editor (the panel's type, options, layers) still shows the
%   previous panel until the press ends: FigureSelectPending is set, and
%   the release fills those rows (finishPendingSelect), so the drag can
%   start without waiting for the editor (onPanelSelected's refill takes
%   most of a second). The caller sets FigurePanelExtra first.
%
%   See also finishPendingSelect, EphysFigGenApp.onArrangeClicked, EphysFigGenApp.onArrangeMoving.
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures) || j < 1 || j > numel(obj.Config.Figures(k).panels); return; end
if j ~= obj.SelectedPanel; obj.SelectedLayer = 1; end
obj.SelectedPanel = j;
obj.FigureSelectPending = true;
arrangeSelectBoxes(obj);
showPanelPlace(obj);
end
