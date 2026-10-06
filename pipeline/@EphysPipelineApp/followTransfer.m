function followTransfer(obj, X)
%followTransfer  Follow a Run's output transfer on the Run tab until it is done.
%   The pipeline's TransferFcn (runPipeline): X, an OutputTransfer, joins
%   Transfers. A timer polls every transfer twice a second (pollTransfers),
%   during the Run and after it, so the copies go on in the background
%   while the app is used; their progress is the Run tab's last row
%   (showTransferProgress). Each batch that changes restates its dataset's
%   "transfer" result row (markTransferResult), after the pipeline has
%   restated its own Results while the Run is under way.
prev = X.BatchFcn;
X.BatchFcn = @(b) batchChanged(obj, X, b, prev);
if isempty(obj.Transfers)
    obj.TransferRateHistory = zeros(0, 2);
    obj.TransferStarted = [];
end
obj.Transfers(end+1) = X;
obj.RunTransferStopButton.Enable = "on";
startMonitor(obj);
obj.showTransferProgress();
obj.syncTabStrip();
end


function batchChanged(obj, X, b, prev)
%batchChanged  X's BatchFcn: the pipeline's rows while it runs, then the Run tab's.
if ~isempty(prev) && runningTransfer(obj, X)
    prev(b);
end
obj.markTransferResult(X, b);
end


function tf = runningTransfer(obj, X)
tf = obj.RunActive && ~isempty(obj.Pipe) && isvalid(obj.Pipe) && ~isempty(obj.Pipe.Transfer) && obj.Pipe.Transfer == X;
end


function startMonitor(obj)
%startMonitor  Start (or leave running) the timer that polls the transfers.
t = obj.TransferMonitorTimer;
if ~isempty(t) && isvalid(t) && strcmp(t.Running, 'on')
    return
end
obj.stopTransferMonitor();
obj.TransferMonitorTimer = timer( ...
    "Name", "EphysPipelineAppTransferMonitor", ...
    "ExecutionMode", "fixedSpacing", "Period", 0.5, "BusyMode", "drop", ...
    "TimerFcn", @(~,~) obj.pollTransfers(), ...
    "ErrorFcn", @(~, evt) monitorFailed(obj, evt));
start(obj.TransferMonitorTimer);
end


function monitorFailed(obj, evt)
%monitorFailed  The timer's ErrorFcn: log, replace the timer while transfers remain.
obj.stopTransferMonitor();
if isempty(obj.Fig) || ~isvalid(obj.Fig); return; end
obj.log("[transfer] the output copy monitor stopped: %s", evt.Data.message);
if ~isempty(obj.Transfers)
    startMonitor(obj);
end
end
