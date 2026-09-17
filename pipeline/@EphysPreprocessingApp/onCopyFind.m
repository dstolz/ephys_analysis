function onCopyFind(obj)
%onCopyFind  List and pair the subject's source sessions for the chosen days (findCopySessions).
%   Paired rows are ticked; unpaired rows can be ticked by hand; ambiguous
%   rows cannot be ticked.

subj = strtrim(string(obj.CopySubjectField.Value));
if subj == ""
    uialert(obj.Fig, "Enter a subject ID first.", "Find sessions");
    return
end
d0 = obj.CopyFromDatePicker.Value;
d1 = obj.CopyToDatePicker.Value;
if isempty(d0) || isnat(d0)
    uialert(obj.Fig, "Choose the first day to search.", "Find sessions");
    return
end
if isempty(d1) || isnat(d1); d1 = d0; end

obj.savePreferences();
obj.CopyFindButton.Enable = "off";
cleanup = onCleanup(@() set(obj.CopyFindButton, "Enable", "on"));
dlg = uiprogressdlg(obj.Fig, "Title", "Find sessions", "Indeterminate", "on", ...
    "Message", sprintf("Listing %s on the source...", subj));
drawnow;
try
    obj.copyLog(sprintf("Find sessions: %s, %s to %s", subj, string(d0, 'yyyy-MM-dd'), string(d1, 'yyyy-MM-dd')));
    T = findCopySessions(subj, [d0 d1], ...
        EpsychRoot=string(obj.CopyEpsychRootField.Value), ...
        IntanRoot=string(obj.CopyIntanRootField.Value), ...
        DestRoot=string(obj.CopyDestRootField.Value), ...
        MaxLeadTime=minutes(obj.CopyMaxLeadField.Value), ...
        MaxLagTime=minutes(obj.CopyMaxLagField.Value), ...
        AmbiguityMargin=seconds(obj.CopyMarginField.Value), ...
        MinIntanDuration=minutes(obj.CopyMinDurationField.Value), ...
        LogFcn=@(m) obj.copyLog(m));
    close(dlg);
catch ME
    if isvalid(dlg); close(dlg); end
    obj.copyLog("ERROR: " + ME.message);
    uialert(obj.Fig, ME.message, "Find sessions");
    obj.setStatus("Find sessions failed: " + string(ME.message), "Check the roots (is the source drive mounted?).");
    return
end

obj.CopyFound = T;
obj.CopySessions = T;
obj.CopyTicked = T.Status == "paired";
obj.CopyStatus = strings(height(T), 1);
obj.CopyMessage = strings(height(T), 1);
obj.refreshCopyTable();
nAmb = nnz(T.Status == "ambiguous");
hint = "Tick the sessions to copy, then Preview or Copy selected.";
if nAmb > 0
    hint = sprintf("%d ambiguous row(s) cannot be copied; pair them by hand.", nAmb);
end
obj.setStatus(sprintf("Copy: %s", obj.CopySummaryLabel.Text), hint);
end
