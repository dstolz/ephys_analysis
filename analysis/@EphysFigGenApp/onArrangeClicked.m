function onArrangeClicked(obj, id, evt)
%onArrangeClicked  A click on the Arrange overlay: on a panel's box it selects the panel; anywhere it gives the arrow keys to the overlay.
%   onArrangeClicked(OBJ, ID, EVT) is the ROIClicked listener of panel
%   ID's widget (arrangeWidget; ":legend" the floating legend's) and, with
%   ID "", the overlay's ButtonDownFcn (a click on the page between the
%   boxes). It notes the overlay clicked last (FigureArrangeFocus: the
%   arrow keys now nudge the selected panel, nudgePanel, until an editor
%   control is used) and selects panel ID as Ctrl+Click on it does
%   (onPanelSelected: the editor shows it, its box turns blue). A drag
%   that Escape canceled is over with the next click. While Set corners
%   waits for its clicks (FigureArrangeMode "corners") the click is one
%   of them (cornerClick), wherever it lands on the page.
%
%   See also EphysFigGenApp.syncArrangeOverlay, EphysFigGenApp.nudgePanel, EphysFigGenApp.startCornerMode.
arguments
    obj (1,1) EphysFigGenApp
    id (1,1) string = ""
    evt = [] %#ok<INUSA> (the listener's; where a click lands is read from the window)
end
if obj.FigureArrangeMode == "corners"
    cornerClick(obj);
    return
end
if obj.FigureArrangeMode == "canceled"; obj.FigureArrangeMode = ""; end
obj.FigureArrangeFocus = true;
if id == "" || id == ":legend"; return; end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures) || isempty(obj.Config.Figures(k).panels); return; end
j = find([obj.Config.Figures(k).panels.id] == id, 1);
if ~isempty(j) && j ~= obj.SelectedPanel
    obj.onPanelSelected(j);
    obj.FigureArrangeFocus = true;
end
end
