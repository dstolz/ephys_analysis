function onCopyScheduleRunNow(obj)
%onCopyScheduleRunNow  Start a scheduled run now, in the background (CopySchedule.startNow).
%   Windows starts the task as it would at its time, so this also tries the
%   schedule out. The status line follows the run until it is over; the log
%   has every session.
try
    obj.CopyScheduler.startNow();
catch ME
    uialert(obj.Fig, ME.message, "Scheduled copy");
    return
end
obj.copyLog("Scheduled copy started now, in the background (Open log follows it).");
obj.refreshCopySchedule();
obj.setStatus("Scheduled copy running in the background.", ...
    "It takes a little while to start MATLAB; the Copy tab shows when it has finished.");
end
