function arrangeClickDone(obj)
%arrangeClickDone  A click on one of several selected boxes waits no longer for its release: the window's WindowButtonUpFcn back as it was.
%   onArrangeClicked keeps the selection while the mouse button is down on
%   a selected box (FigureArrangeClick: the box's id and the window's
%   WindowButtonUpFcn before), so that a drag moves them all; this ends
%   that wait: at the release (no drag came: that panel alone is selected
%   then), when a drag starts (onArrangeMoving), or at the next click.
%
%   See also EphysFigGenApp.onArrangeClicked, EphysFigGenApp.onArrangeMoving.
C = obj.FigureArrangeClick;
obj.FigureArrangeClick = [];
if isstruct(C) && ~isempty(obj.Fig) && isvalid(obj.Fig); obj.Fig.WindowButtonUpFcn = C.oldUp; end
end
