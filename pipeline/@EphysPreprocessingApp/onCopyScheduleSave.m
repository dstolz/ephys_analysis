function onCopyScheduleSave(obj)
%onCopyScheduleSave  Save the scheduled copy and create its Windows task (CopySchedule.save).
%   The schedule copies with the Copy tab's roots, destination, pairing and
%   copy options as they are now, plus its own subjects (blank: the Subject
%   ID above), interval, days back, quiet time and when it may run. For
%   "even when I am signed out" the app first says that Windows will ask
%   for the password in a window of its own, and waits for that window.
title = "Scheduled copy";
subjects = strtrim(string(obj.CopyScheduleSubjectsField.Value));
if subjects == ""
    subjects = strtrim(string(obj.CopySubjectField.Value));
end
s = CopySchedule.defaults();
s.Subjects = subjects;
s.EpsychRoot = string(obj.CopyEpsychRootField.Value);
s.RecordingRoots = obj.copyRecordingRoots();
s.DestRoot = string(obj.CopyDestRootField.Value);
s.MaxLeadMin = obj.CopyMaxLeadField.Value;
s.MaxLagMin = obj.CopyMaxLagField.Value;
s.MarginSec = obj.CopyMarginField.Value;
s.MinDurationMin = obj.CopyMinDurationField.Value;
s.Verify = string(obj.CopyVerifyDropDown.Value);
s.IfExists = string(obj.CopyIfExistsDropDown.Value);
s.EveryMin = obj.CopyScheduleEveryField.Value;
s.LookBackDays = obj.CopyScheduleDaysField.Value;
s.QuietMin = obj.CopyScheduleQuietField.Value;
s.RunWhen = string(obj.CopyScheduleRunWhenDropDown.Value);
try
    s = CopySchedule.normalize(s);
catch ME
    uialert(obj.Fig, ME.message, title);
    return
end

message = "Creating the Windows task...";
if s.RunWhen == "always"
    answer = uiconfirm(obj.Fig, ...
        "To copy while you are signed out, Windows needs your Windows password once. " + ...
        "A console window will open and ask for it; Task Scheduler keeps it with the task, " + ...
        "and this app never sees it." + newline + newline + ...
        "Save the schedule again after your password changes. If Windows refuses (some accounts " + ...
        "may not run tasks while signed out), choose ""while I am signed in"" instead.", ...
        title, "Options", ["Continue", "Cancel"], "DefaultOption", 1, "CancelOption", 2);
    if answer ~= "Continue"; return; end
    message = "Type your Windows password in the console window that has opened (it may be behind this one).";
end
obj.savePreferences();
dlg = uiprogressdlg(obj.Fig, "Title", title, "Indeterminate", "on", "Message", message);
drawnow;
try
    s = obj.CopyScheduler.save(s);
catch ME
    if isvalid(dlg); close(dlg); end
    obj.copyLog("ERROR: the schedule was not saved: " + ME.message);
    uialert(obj.Fig, ME.message, title);
    obj.refreshCopySchedule();
    return
end
close(dlg);
obj.copyLog(sprintf("Scheduled copy saved: %s, every %g min, sessions of the last %d day(s), to %s (Windows task %s).", ...
    strjoin(s.Subjects, ", "), s.EveryMin, s.LookBackDays, s.DestRoot, obj.CopyScheduler.TaskName));
obj.refreshCopySchedule(Fill=true);
obj.setStatus("Scheduled copy saved: " + strjoin(s.Subjects, ", ") + ".", ...
    "It runs through Windows Task Scheduler whether or not the app is open; Run now tries it at once.");
end
