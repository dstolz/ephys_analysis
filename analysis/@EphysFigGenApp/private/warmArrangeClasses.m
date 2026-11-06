function warmArrangeClasses(obj)
%warmArrangeClasses  Run warmUp a moment after the window shows: Arrange's classes and the drag's functions loaded in the idle moment after startup.
%   warmArrangeClasses(OBJ) starts a one-shot timer (WarmTimer, 2 s after
%   the window is shown; stopped by onClose) that calls warmUp(OBJ).
%   Nothing is done under -batch (a test, a script): a timer's second of
%   work in the middle of a timed step is worse than the one slow Arrange
%   on, and no one waits for it there; a bench calls warmUp itself.
%
%   See also EphysFigGenApp.warmUp, EphysFigGenApp.onClose.
if batchStartupOptionUsed(); return; end
t = timer('StartDelay', 2, 'ExecutionMode', 'singleShot', 'Tag', 'arrangeWarmTimer', ...
    'TimerFcn', @(~, ~) fire(obj), 'StopFcn', @(t, ~) delete(t));
obj.WarmTimer = t;
start(t);
end


function fire(obj)
%fire  The timer: warmUp, unless the window is gone.
if ~isvalid(obj); return; end
obj.WarmTimer = [];
try
    obj.warmUp();
catch
end
end
