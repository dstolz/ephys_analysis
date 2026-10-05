function stopCopyMonitor(obj)
%stopCopyMonitor  Stop and delete the copy-polling timer if present.
%   This only stops watching: a detached copy engine keeps running.
t = obj.CopyMonitorTimer;
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
obj.CopyMonitorTimer = [];
end
