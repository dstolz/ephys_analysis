function fillSelectLater(obj, msg)
%fillSelectLater  The editor's rows for a panel Arrange's press selected lightly, filled a moment after the release rather than in it.
%   fillSelectLater(OBJ, MSG) does nothing unless FigureSelectPending is
%   set (selectLightly). It starts a one-shot timer (FigureSelectTimer,
%   0.4 s; one started before is stopped) that fills the rows then
%   (finishPendingSelect(OBJ, MSG): MSG [] says "Selected <id>.", ""
%   nothing), so a release paints at once and the refill, the editor's
%   slowest part, comes after; while a drag is under way when it fires,
%   it waits another 0.4 s. The rows are filled sooner where they must
%   be: before the editor is read back (gatherFigureEditor), on the next
%   press (onArrangeClicked), Escape (cancelArrange) and Arrange off;
%   each stops the timer (stopSelectTimer), and so do a drag's first step
%   (onArrangeMoving: its release starts it again) and the window closed
%   (onClose).
%
%   See also finishPendingSelect, stopSelectTimer, EphysFigGenApp.onArrangeMoved.
arguments
    obj (1,1) EphysFigGenApp
    msg = []
end
stopSelectTimer(obj);
if ~isvalid(obj) || ~obj.FigureSelectPending; return; end
t = timer('StartDelay', 0.4, 'ExecutionMode', 'singleShot', 'Tag', 'arrangeSelectTimer', ...
    'TimerFcn', @(~, ~) fire(obj, msg), 'StopFcn', @(t, ~) delete(t));
obj.FigureSelectTimer = t;
start(t);
end


function fire(obj, msg)
%fire  The timer: the rows filled now, unless a drag is under way (then a moment later).
if ~isvalid(obj); return; end
obj.FigureSelectTimer = [];
if obj.FigureArrangeMode == "drag"
    fillSelectLater(obj, msg);
    return
end
try
    finishPendingSelect(obj, msg);
catch ME
    obj.log("The editor could not show the panel selected: " + string(ME.message));
end
end
