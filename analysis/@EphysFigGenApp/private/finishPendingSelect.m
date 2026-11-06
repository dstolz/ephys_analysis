function finishPendingSelect(obj, msg)
%finishPendingSelect  The editor's rows follow a panel Arrange's press selected lightly: the panel's and its layer's rows filled, the status bar told.
%   finishPendingSelect(OBJ) does nothing unless FigureSelectPending is
%   set: a press on a box that was not selected (onArrangeClicked, or a
%   drag's first step: onArrangeMoving) selects it at once with its box
%   blue and its Position and Size fields (selectLightly), leaving the
%   rest of the editor showing the previous panel while the mouse button
%   is down, so a drag can start without waiting for the editor. Then the
%   panel's rows are filled (applyFigureEditor, Scope "panel", which
%   clears FigureSelectPending) and the status bar says "Selected <id>.",
%   as onPanelSelected does. A release (onArrangeMoved, and the release
%   of a click with no drag: onArrangeClicked) leaves it to a timer a
%   moment later (fillSelectLater), so the release paints first; it is
%   called at once on Escape (cancelArrange), the next click
%   (onArrangeClicked), Arrange off and before the editor is read back
%   (gatherFigureEditor). Any call stops that timer (stopSelectTimer).
%   finishPendingSelect(OBJ, MSG) says MSG instead; "" says nothing.
%
%   See also EphysFigGenApp.onArrangeClicked, EphysFigGenApp.onArrangeMoving, selectLightly, fillSelectLater.
arguments
    obj (1,1) EphysFigGenApp
    msg = []
end
stopSelectTimer(obj);
if ~isvalid(obj) || ~obj.FigureSelectPending; return; end
obj.applyFigureEditor(Scope="panel");   % (clears FigureSelectPending)
obj.FigureSelectPending = false;
if isempty(msg)
    k = obj.SelectedFigure;
    j = obj.SelectedPanel;
    if k < 1 || k > numel(obj.Config.Figures) || j < 1 || j > numel(obj.Config.Figures(k).panels); return; end
    msg = "Selected " + obj.Config.Figures(k).panels(j).id + ".";
end
if string(msg) ~= ""; obj.setStatus(msg); end
end
