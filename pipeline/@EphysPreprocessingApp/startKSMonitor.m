function startKSMonitor(obj)
    % Start (or leave running) the timer that polls background KS4 runs.
    t = obj.KSMonitorTimer;
    if ~isempty(t) && isvalid(t) && strcmp(t.Running, 'on')
        return   % already polling; it will pick up newly-added runs
    end
    obj.stopKSMonitor();   % clear any stale, stopped timer
    obj.KSMonitorTimer = timer( ...
        "Name", "EphysPreprocessingAppMonitor", ...
        "ExecutionMode", "fixedSpacing", "Period", 3, "BusyMode", "drop", ...
        "TimerFcn", @(~,~) obj.pollKSRuns());
    start(obj.KSMonitorTimer);
end
