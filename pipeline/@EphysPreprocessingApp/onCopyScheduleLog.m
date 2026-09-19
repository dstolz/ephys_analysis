function onCopyScheduleLog(obj)
%onCopyScheduleLog  Open the scheduled copy's log in the system's text editor.
f = obj.CopyScheduler.logFile();
if ~isfile(f)
    uialert(obj.Fig, "The scheduled copy has not run yet, so there is no log.", "Scheduled copy");
    return
end
if ispc
    winopen(f);
else
    open(f);
end
end
