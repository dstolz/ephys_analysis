function startCopyMonitor(obj)
%startCopyMonitor  Start (or leave running) the timer that follows the copy engine.
%   The engine runs detached, so the app only has to read what it reports;
%   pollCopyJob does that twice a second and stops the timer when the batch
%   is finished.
t = obj.CopyMonitorTimer;
if ~isempty(t) && isvalid(t) && strcmp(t.Running, 'on')
    return
end
obj.stopCopyMonitor();   % clear any stale, stopped timer
obj.CopyMonitorTimer = timer( ...
    "Name", "EphysPreprocessingAppCopyMonitor", ...
    "ExecutionMode", "fixedSpacing", "Period", 0.5, "BusyMode", "drop", ...
    "TimerFcn", @(~,~) obj.pollCopyJob());
start(obj.CopyMonitorTimer);
end
