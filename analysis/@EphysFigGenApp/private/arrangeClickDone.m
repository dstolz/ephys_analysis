function arrangeClickDone(obj)
%arrangeClickDone  A click on a box waits no longer for its release: the window's WindowButtonUpFcn back as it was.
%   onArrangeClicked keeps the selection while the mouse button is down on
%   one of several selected boxes (FigureArrangeClick: the box's id, the
%   window's WindowButtonUpFcn before, alone true), so that a drag moves
%   them all, and waits for the release of a press that selected a box
%   lightly (alone false: selectLightly), whose editor rows the release
%   fills (finishPendingSelect) when no drag came; this ends that wait: at
%   the release, when a drag starts (onArrangeMoving: the drag's release
%   fills the rows then, onArrangeMoved), or at the next click.
%
%   See also EphysFigGenApp.onArrangeClicked, EphysFigGenApp.onArrangeMoving.
C = obj.FigureArrangeClick;
obj.FigureArrangeClick = [];
if isstruct(C) && ~isempty(obj.Fig) && isvalid(obj.Fig); obj.Fig.WindowButtonUpFcn = C.oldUp; end
end
