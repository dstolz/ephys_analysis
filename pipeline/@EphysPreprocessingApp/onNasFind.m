function onNasFind(obj)
%onNasFind  List and pair the subject's NAS sessions for the chosen days (findNasSessions).
%   Paired rows are ticked; unpaired rows can be ticked by hand; ambiguous
%   rows cannot be ticked.

subj = strtrim(string(obj.NasSubjectField.Value));
if subj == ""
    uialert(obj.Fig, "Enter a subject ID first.", "Find sessions");
    return
end
d0 = obj.NasFromDatePicker.Value;
d1 = obj.NasToDatePicker.Value;
if isempty(d0) || isnat(d0)
    uialert(obj.Fig, "Choose the first day to search.", "Find sessions");
    return
end
if isempty(d1) || isnat(d1); d1 = d0; end

obj.savePreferences();
obj.NasFindButton.Enable = "off";
cleanup = onCleanup(@() set(obj.NasFindButton, "Enable", "on"));
dlg = uiprogressdlg(obj.Fig, "Title", "Find sessions", "Indeterminate", "on", ...
    "Message", sprintf("Listing %s on the NAS...", subj));
drawnow;
try
    obj.nasLog(sprintf("Find sessions: %s, %s to %s", subj, string(d0, 'yyyy-MM-dd'), string(d1, 'yyyy-MM-dd')));
    T = findNasSessions(subj, [d0 d1], ...
        EpsychRoot=string(obj.NasEpsychRootField.Value), ...
        IntanRoot=string(obj.NasIntanRootField.Value), ...
        DestRoot=string(obj.NasDestRootField.Value), ...
        MaxLeadTime=minutes(obj.NasMaxLeadField.Value), ...
        MaxLagTime=minutes(obj.NasMaxLagField.Value), ...
        AmbiguityMargin=seconds(obj.NasMarginField.Value), ...
        LogFcn=@(m) obj.nasLog(m));
    close(dlg);
catch ME
    if isvalid(dlg); close(dlg); end
    obj.nasLog("ERROR: " + ME.message);
    uialert(obj.Fig, ME.message, "Find sessions");
    obj.setStatus("Find sessions failed: " + string(ME.message), "Check the roots (is the NAS drive mounted?).");
    return
end

obj.NasSessions = T;
obj.NasTicked = T.Status == "paired";
obj.NasCopyStatus = strings(height(T), 1);
obj.NasMessage = strings(height(T), 1);
obj.refreshNasTable();
nAmb = nnz(T.Status == "ambiguous");
hint = "Tick the sessions to copy, then Preview or Copy selected.";
if nAmb > 0
    hint = sprintf("%d ambiguous row(s) cannot be copied; pair them by hand.", nAmb);
end
obj.setStatus(sprintf("NAS: %s", obj.NasSummaryLabel.Text), hint);
end
