function arrangeSelectBoxes(obj)
%arrangeSelectBoxes  Arrange's boxes drawn as the selection is now (blue, the primary's line thicker) with the selected panels' size labels, nothing else.
%   arrangeSelectBoxes(OBJ) recolors each box of the overlay
%   (FigureArrangeOverlay's widgets: arrangeWidgetSelect at
%   arrangeSelectLevel of selectedPanelIds) and puts the size labels by
%   the selected boxes (arrangeSizeLabels). It is the light part of
%   syncArrangeOverlay: no box is moved, made or deleted, the overlay is
%   not stacked again and the preview is not checked, since only the
%   selection changed. A press on a box that was not selected
%   (onArrangeClicked, or a drag's first step: onArrangeMoving) shows the
%   new selection so at once; the editor's rows follow at the release
%   (finishPendingSelect).
%
%   See also EphysFigGenApp.syncArrangeOverlay, finishPendingSelect, arrangeWidgetSelect.
O = obj.FigureArrangeOverlay;
if ~isstruct(O) || isempty(O.axes) || ~isvalid(O.axes); return; end
sel = selectedPanelIds(obj);
W = O.widgets;
for key = string(W.keys)
    w = W(char(key));
    if isvalid(w); arrangeWidgetSelect(w, arrangeSelectLevel(key, sel)); end
end
arrangeSizeLabels(obj);
end
