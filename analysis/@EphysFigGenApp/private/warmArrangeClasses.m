function warmArrangeClasses(obj)
%warmArrangeClasses  Load the images.roi classes Arrange's boxes are made of a moment after the window shows, so the first Arrange on of a session is as quick as the next.
%   warmArrangeClasses(OBJ) starts a one-shot timer (WarmTimer, 2 s after
%   the window is shown; stopped by onClose) that makes one
%   images.roi.Rectangle in an axes of a hidden figure and deletes both.
%   Loading those classes takes about a second the first time in a MATLAB
%   session (measured 2026-11-05: 1.2 s for the first box, then 0.03 s
%   each), which the first Arrange on paid; the idle moment after startup
%   pays it instead. Nothing is done under -batch (a test, a script): a
%   timer's second of work in the middle of a timed step is worse than the
%   one slow Arrange on, and no one waits for it there.
%
%   See also arrangeWidget, EphysFigGenApp.syncArrangeOverlay, EphysFigGenApp.onClose.
if batchStartupOptionUsed(); return; end
t = timer('StartDelay', 2, 'ExecutionMode', 'singleShot', 'Tag', 'arrangeWarmTimer', ...
    'TimerFcn', @(~, ~) warm(obj), 'StopFcn', @(t, ~) delete(t));
obj.WarmTimer = t;
start(t);
end


function warm(obj)
%warm  The timer: one box made and deleted in a hidden figure, unless the window is gone or Arrange already made its boxes.
if ~isvalid(obj); return; end
obj.WarmTimer = [];
if isstruct(obj.FigureArrangeOverlay) || ~isempty(obj.FigureArrangeKept); return; end   % (Arrange on already loaded them)
f = figure('Visible', 'off', 'HandleVisibility', 'off', 'IntegerHandle', 'off');
c = onCleanup(@() delete(f));
try
    ax = axes(f, 'XLim', [0 1], 'YLim', [0 1]);
    w = images.roi.Rectangle(ax, 'Position', [0.1 0.1 0.2 0.2]);
    delete(w);
catch
    % (nothing lost: Arrange on loads the classes itself)
end
end
