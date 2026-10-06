function stopTransferMonitor(obj)
%stopTransferMonitor  Stop and delete the timer polling the output transfers.
%   This only stops watching: a copy engine in flight finishes its job on
%   its own, but nothing checks it, starts the next one or removes what a
%   move copied.
t = obj.TransferMonitorTimer;
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
obj.TransferMonitorTimer = [];
end
