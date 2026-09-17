function onNasCopy(obj, dryRun)
%onNasCopy  Preview (DRYRUN true) or copy the ticked NAS sessions (copyNasSessions).
%   Progress and Cancel come from a progress dialog (checked between files).
%   Ticked unpaired rows are passed with IncludeUnpaired; ambiguous rows can
%   never be ticked. After a real copy with "open the copied sessions as the
%   project" ticked, the Project root is set to the folder holding the
%   copied / already present sessions and scanned.

T = obj.NasSessions;
if isempty(T) || height(T) == 0
    uialert(obj.Fig, "Find sessions first.", "Copy sessions");
    return
end
sel = find(obj.NasTicked & T.Status ~= "ambiguous");
if isempty(sel)
    uialert(obj.Fig, "Tick at least one session to copy.", "Copy sessions");
    return
end
rows = T(sel, :);
destRoot = string(obj.NasDestRootField.Value);
title = ternary(dryRun, "Preview copy", "Copy sessions");

obj.savePreferences();
buttons = [obj.NasFindButton, obj.NasPreviewButton, obj.NasCopyButton];
set(buttons, "Enable", "off");
cleanup = onCleanup(@() set(buttons(isvalid(buttons)), "Enable", "on"));
dlg = uiprogressdlg(obj.Fig, "Title", title, "Value", 0, "Cancelable", ~dryRun, ...
    "Message", sprintf("%s %d session(s)...", ternary(dryRun, "Checking", "Copying"), numel(sel)));
drawnow;
try
    obj.nasLog(sprintf("%s: %d session(s) to %s", title, numel(sel), destRoot));
    R = copyNasSessions(rows, DestRoot=destRoot, DryRun=dryRun, ...
        IfExists=string(obj.NasIfExistsDropDown.Value), ...
        IncludeUnpaired=any(ismember(rows.Status, ["intan_only" "epsych_only"])), ...
        Verify=string(obj.NasVerifyDropDown.Value), ...
        ProgressFcn=@(f, m) showProgress(dlg, f, m), ...
        CancelFcn=@() isvalid(dlg) && dlg.CancelRequested, ...
        LogFcn=@(m) obj.nasLog(m));
    close(dlg);
catch ME
    if isvalid(dlg); close(dlg); end
    obj.nasLog("ERROR: " + ME.message);
    uialert(obj.Fig, ME.message, title);
    obj.setStatus(title + " failed: " + string(ME.message), "");
    return
end

obj.NasSessions.DestDir(sel) = R.DestDir;
obj.NasCopyStatus(sel) = R.CopyStatus;
obj.NasMessage(sel) = R.Message;
obj.refreshNasTable();

statuses = ["planned", "copied", "already_present", "skipped", "failed", "cancelled"];
counts = arrayfun(@(s) nnz(R.CopyStatus == s), statuses);
parts = compose("%d %s", counts(counts > 0).', replace(statuses(counts > 0).', "_", " "));
summary = sprintf("%s: %s.", title, strjoin(parts, ", "));
obj.setStatus(summary, "");
if any(R.CopyStatus == "failed")
    bad = R(R.CopyStatus == "failed", :);
    msg = strjoin(compose("%s: %s", bad.DestDir, bad.Message), newline + newline);
    uialert(obj.Fig, msg, sprintf("%d session(s) failed", height(bad)));
end

ready = R.DestDir(R.CopyStatus == "copied" | R.CopyStatus == "already_present");
if ~dryRun && ~isempty(ready) && obj.NasScanAfterCheckBox.Value && ~any(R.CopyStatus == "failed")
    openAsProject(obj, ready);
end
end


function openAsProject(obj, sessionDirs)
%openAsProject  Scan the folder holding SESSIONDIRS as the project; make the first one active.
parents = unique(arrayfun(@(d) string(fileparts(d)), sessionDirs));
root = parents(1);
if numel(parents) > 1
    root = string(fileparts(parents(1)));   % sessions of several subjects: <DestRoot>
end
obj.nasLog("Opening " + root + " as the project");
obj.RootPathField.Value = char(root);
obj.onConfigChanged();
obj.selectTab(obj.TabProject);
obj.onScan();
P = obj.Project;
if isempty(P) || P.NumDatasets == 0; return; end
folders = arrayfun(@(d) string(d.Folder), P.Datasets);
idx = find(strcmpi(folders, sessionDirs(1)), 1);
if ~isempty(idx)
    obj.selectDataset(idx);
end
end


function showProgress(dlg, frac, msg)
if ~isvalid(dlg); return; end
dlg.Value = max(0, min(1, frac));
dlg.Message = msg;
drawnow limitrate;
end


function v = ternary(tf, a, b)
if tf; v = a; else; v = b; end
end
