function onCopyScheduleRemove(obj)
%onCopyScheduleRemove  Delete the scheduled copy's Windows task (CopySchedule.remove).
%   Copies already made stay where they are, and so do the log and the
%   last run's summary. A run under way finishes. Saving the schedule again
%   brings the task back.
try
    obj.CopyScheduler.remove();
catch ME
    uialert(obj.Fig, ME.message, "Scheduled copy");
    return
end
obj.copyLog("Scheduled copy removed; the copies it made are kept.");
obj.refreshCopySchedule();
obj.setStatus("Scheduled copy removed.", "Nothing is copied automatically until a schedule is saved again.");
end
