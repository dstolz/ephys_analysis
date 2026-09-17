function stopKSMonitor(obj)
    % Stop and delete the polling timer if present.
    t = obj.KSMonitorTimer;
    if ~isempty(t) && isvalid(t)
        try
            stop(t);
        catch
        end
        try
            delete(t);
        catch
        end
    end
    obj.KSMonitorTimer = [];
end
