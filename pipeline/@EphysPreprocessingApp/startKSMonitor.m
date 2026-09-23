function startKSMonitor(obj)
    % Start (or leave running) the timer that polls background KS4 runs.
    % A timer whose callback errored stops for good, so its ErrorFcn logs
    % the error, deletes it and starts a new one while runs are still
    % followed (pollKSRuns guards each run and the queue, so this is only
    % for an error nothing else caught).
    t = obj.KSMonitorTimer;
    if ~isempty(t) && isvalid(t) && strcmp(t.Running, 'on')
        return   % already polling; it will pick up newly-added runs
    end
    obj.stopKSMonitor();   % clear any stale, stopped timer
    obj.KSMonitorTimer = timer( ...
        "Name", "EphysPreprocessingAppMonitor", ...
        "ExecutionMode", "fixedSpacing", "Period", 3, "BusyMode", "drop", ...
        "TimerFcn", @(~,~) obj.pollKSRuns(), ...
        "ErrorFcn", @(~, evt) monitorFailed(obj, evt));
    start(obj.KSMonitorTimer);
end


function monitorFailed(obj, evt)
%monitorFailed  The monitor's ErrorFcn: log, replace the timer, go on.
obj.stopKSMonitor();
if isempty(obj.Fig) || ~isvalid(obj.Fig); return; end
obj.log("[error] the Kilosort4 monitor stopped: %s", evt.Data.message);
if ~isempty(obj.KSRuns) || ~isempty(obj.KSQueue)
    obj.startKSMonitor();
end
end
