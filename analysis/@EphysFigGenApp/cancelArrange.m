function cancelArrange(obj, msg)
%cancelArrange  End what Arrange is doing over the preview without changing the figure: a drag, or Set corners' clicks.
%   cancelArrange(OBJ, MSG): Set corners (FigureArrangeMode "corners")
%   ends: the window's pointer callbacks it replaced (FigureDrag: oldMotion,
%   oldDown, oldUp) come back as they were, the pointer is an arrow again,
%   the boxes are free again (arrangeWidgetLock) and the dashed rectangle
%   from the first corner goes. A drag of a box (FigureArrangeMode "drag")
%   is canceled: the box goes back to the panel's rect, the panel's plots
%   it moved along go back where they were drawn (arrangePartsAt; every
%   panel selected with it too), the
%   Position and Size fields show it again (showPanelPlace), and the box stays there
%   until the mouse button is let go (FigureArrangeMode "canceled", which
%   onArrangeMoving and onArrangeMoved honor). The smart guides are
%   hidden; FigureCorners goes back to []. A press that selected a box
%   lightly has the editor's rows filled (finishPendingSelect). The status bar says MSG unless
%   it is "" (default "Canceled."). Escape calls it, on any tab
%   (onKeyPress), and so do Arrange turned off (onArrangeToggled), the
%   overlay taken away (syncArrangeOverlay) and a click off the page while
%   Set corners waits.
%
%   See also EphysFigGenApp.onArrangeToggled, EphysFigGenApp.startCornerMode, EphysFigGenApp.onKeyPress.
if nargin < 2; msg = "Canceled."; end
D = obj.FigureDrag;
mode = obj.FigureArrangeMode;
obj.FigureDrag = [];
obj.FigureCorners = [];
obj.FigureArrangeMode = "";
fig = ~isempty(obj.Fig) && isvalid(obj.Fig);
if isstruct(D) && fig
    back = struct('oldMotion', 'WindowButtonMotionFcn', 'oldUp', 'WindowButtonUpFcn', 'oldDown', 'WindowButtonDownFcn');
    for f = string(fieldnames(back)).'
        if isfield(D, f); obj.Fig.(back.(f)) = D.(f); end
    end
end
O = obj.FigureArrangeOverlay;
if isstruct(O) && ~isempty(O.axes) && isvalid(O.axes)
    if mode == "corners"
        for w = [O.widgets.values {O.legend}]
            if ~isempty(w{1}); arrangeWidgetLock(w{1}, false); end
        end
        if ~isempty(O.band) && isvalid(O.band); delete(O.band); end
        O.band = [];
        obj.FigureArrangeOverlay = O;
        if fig; obj.Fig.Pointer = "arrow"; end
    elseif ismember(mode, ["drag" "canceled"]) && obj.FigureArrange
        obj.FigureArrangeMode = "canceled";   % the mouse button is still down: the box stays put until it is let go
        if isstruct(D) && isfield(D, 'id')
            C = arrangeContext(obj, D.id);
            if ~isempty(C) && ~isempty(C.w) && isvalid(C.w); arrangeWidgetSet(C.w, C.rect0); end
        end
        if isstruct(D) && isfield(D, 'parts') && ~isempty(D.parts); arrangePartsAt(D.parts, D.parts.box0); end   % the plots back too
        if isstruct(D) && isfield(D, 'group')   % the others selected, moved along: back too
            for i = 1:numel(D.group)
                arrangeWidgetSet(D.group(i).w, D.group(i).rect0);
                if ~isempty(D.group(i).parts); arrangePartsAt(D.group(i).parts, D.group(i).parts.box0); end
            end
        end
        showPanelPlace(obj);
    end
    arrangeCues(obj, [], []);
elseif mode == "corners" && fig
    obj.Fig.Pointer = "arrow";
end
finishPendingSelect(obj, "");   % a press that selected a box: the editor's rows now (selectLightly)
if msg ~= ""; obj.setStatus(msg); end
end
