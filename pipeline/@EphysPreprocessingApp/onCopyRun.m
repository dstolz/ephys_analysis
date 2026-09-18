function onCopyRun(obj, dryRun)
%onCopyRun  Preview (DRYRUN true) or copy the ticked Copy-tab sessions (copySessions).
%   A preview is a dry run: it writes nothing, is quick and blocks behind a
%   progress dialog. A copy does not block: copySessions launches the copy
%   engine and returns, a timer polls it (pollCopyJob) and the rest of the app
%   stays usable while the files move. Copy selected becomes Cancel copy for
%   as long as the batch is in flight.
%
%   Ticked unpaired rows are passed with IncludeUnpaired; ambiguous rows can
%   never be ticked. After a copy finishes with "open the copied sessions as
%   the project" ticked, the Project root is set to the folder holding the
%   copied / already present sessions and scanned (finishCopyRun).

if ~isempty(obj.CopyJob)
    uialert(obj.Fig, "A copy is already running. Cancel it first, or wait for it to finish.", "Copy sessions");
    return
end
T = obj.CopySessions;
if isempty(T) || height(T) == 0
    uialert(obj.Fig, "Find sessions first.", "Copy sessions");
    return
end
sel = find(obj.CopyTicked & T.Status ~= "ambiguous");
if isempty(sel)
    uialert(obj.Fig, "Tick at least one session to copy.", "Copy sessions");
    return
end
rows = T(sel, :);
destRoot = string(obj.CopyDestRootField.Value);
obj.savePreferences();

if dryRun
    runPreview(obj, rows, sel, destRoot);
else
    startCopy(obj, rows, sel, destRoot);
end
end


function runPreview(obj, rows, sel, destRoot)
%runPreview  A dry run: nothing is written, so it blocks behind a dialog.
buttons = [obj.CopyFindButton, obj.CopyPreviewButton, obj.CopyRunButton];
set(buttons, "Enable", "off");
cleanup = onCleanup(@() set(buttons(isvalid(buttons)), "Enable", "on"));
dlg = uiprogressdlg(obj.Fig, "Title", "Preview copy", "Indeterminate", "on", ...
    "Message", sprintf("Checking %d session(s)...", numel(sel)));
drawnow;
try
    obj.copyLog(sprintf("Preview copy: %d session(s) to %s", numel(sel), destRoot));
    R = copySessions(rows, DestRoot=destRoot, DryRun=true, ...
        IfExists=string(obj.CopyIfExistsDropDown.Value), ...
        IncludeUnpaired=any(ismember(rows.Status, ["intan_only" "epsych_only"])), ...
        Verify=string(obj.CopyVerifyDropDown.Value), ...
        LogFcn=@(m) obj.copyLog(m));
    close(dlg);
catch ME
    if isvalid(dlg); close(dlg); end
    obj.copyLog("ERROR: " + ME.message);
    uialert(obj.Fig, ME.message, "Preview copy");
    obj.setStatus("Preview copy failed: " + string(ME.message), "");
    return
end
obj.applyCopyResult(sel, R);
obj.setStatus(obj.copySummaryText("Preview copy", R), "");
end


function startCopy(obj, rows, sel, destRoot)
%startCopy  Launch the copy engine and let a timer follow it.
obj.CopyCancelRequested = false;
obj.CopyRows = sel;
obj.CopyStarted = tic;
obj.CopyRateHistory = zeros(0, 2);
obj.CopyLiveRow = 0;
obj.CopyLivePos = 0;
obj.CopyLivePhase = "copying";
obj.CopyProgressLabel.Text = '';
obj.copyLog(sprintf("Copy sessions: %d session(s) to %s", numel(sel), destRoot));
try
    [R, job] = copySessions(rows, DestRoot=destRoot, DryRun=false, ...
        IfExists=string(obj.CopyIfExistsDropDown.Value), ...
        IncludeUnpaired=any(ismember(rows.Status, ["intan_only" "epsych_only"])), ...
        Verify=string(obj.CopyVerifyDropDown.Value), ...
        Background=true, ...
        ProgressFcn=@(f, m, i) obj.showCopyProgress(f, m, i), ...
        CancelFcn=@() obj.CopyCancelRequested, ...
        LogFcn=@(m) obj.copyLog(m));
catch ME
    obj.copyLog("ERROR: " + ME.message);
    uialert(obj.Fig, ME.message, "Copy sessions");
    obj.setStatus("Copy sessions failed: " + string(ME.message), "");
    return
end
obj.applyCopyResult(sel, R);

if job.Done   % nothing was left to copy: every row was skipped or already there
    obj.finishCopyRun(R);
    return
end
obj.CopyJob = job;
obj.setCopyRunning(true);
obj.startCopyMonitor();
obj.setStatus(sprintf("Copying %d session(s) in the background.", nnz(R.CopyStatus == "copying")), ...
    "The app stays usable; Cancel copy stops after the file being copied.");
end
