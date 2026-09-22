function R = runCleanup(obj, T)
%runCleanup  Remove T's Remove rows the way the Clean up tab says (runLocalCleanup), then show what is left.
%   R = runCleanup(obj, T) deletes the files, sends them to the Recycle Bin
%   or moves them to the folder given (CleanupMethodDropDown,
%   CleanupDestField), under a progress dialog whose Cancel leaves the
%   files not yet handled in place. Each file handled is logged. The
%   manifests of the datasets that lost files are rewritten, since they
%   record the sorting and .bin on disk; the Datasets table and the Review
%   tab follow, and the preview is made again. onCleanupRun confirms first;
%   this asks nothing, so tests call it directly.
method = string(obj.CleanupMethodDropDown.Value);
dest = strtrim(string(obj.CleanupDestField.Value));
rm = T(T.Action == "remove", :);
verbs = struct('delete', ["Deleting" "Deleted"], 'recycle', ["Recycling" "Recycled"], 'move', ["Moving" "Moved"]);
verb = verbs.(method);

obj.CleanupRunButton.Enable = "off";
obj.CleanupPreviewButton.Enable = "off";
restore = onCleanup(@() set(obj.CleanupPreviewButton, "Enable", "on"));
to = "";
if method == "move"; to = " to " + dest; end
cleanupLog(obj, sprintf("%s %d file(s) from %d dataset(s)%s...", verb(1), height(rm), numel(unique(rm.Dataset)), to));
dlg = uiprogressdlg(obj.Fig, "Title", "Clean up", "Message", verb(1) + "...", "Value", 0, "Cancelable", "on");
closeDlg = onCleanup(@() delete(dlg));
R = rm([], :);
try
    R = runLocalCleanup(T, Method=method, Destination=dest, LogFcn=@(m) cleanupLog(obj, m), ...
        ProgressFcn=@(e) progress(dlg, e, verb(1)), CancelFcn=@() dlg.CancelRequested);
catch ME
    cleanupLog(obj, "Nothing was removed: " + ME.message);
    uialert(obj.Fig, ME.message, "Clean up");
    obj.refreshCleanupTable("summary");
    return
end
done = R.Status == "removed";
summary = sprintf("%s %d file(s), %s.", verb(2), nnz(done), bytesText(sum(R.Bytes(done))));
if any(~done)
    summary = summary + sprintf(" %d file(s) left in place (see the log).", nnz(~done));
end
noted = done & R.Message ~= "";
if any(noted)
    summary = summary + sprintf(" %d of them with a note (see the log).", nnz(noted));
end
cleanupLog(obj, summary);

% the manifests record the sorting and .bin on disk: bring them up to date
if any(done) && ~isempty(obj.Project)
    for d = obj.Project.Datasets(:).'
        if any(done & R.Folder == string(d.Folder) & R.Dataset == string(d.Name))
            d.writeManifest();
        end
    end
    obj.refreshDatasetsTable();
    obj.refreshSortingLabel();
    obj.ReviewDatasetIdx = -1;   % the Review tab reloads
end

obj.onCleanupPreview();   % show what is left
hint = "";
if any(done & R.Category == "raw")
    hint = "Scan the project again: datasets whose raw recording was removed drop out of it.";
end
obj.setStatus("Clean up: " + summary, hint);
if any(~done) || any(noted)
    uialert(obj.Fig, summary, "Clean up", "Icon", "warning");
end
end


function progress(dlg, e, verb)
if ~isvalid(dlg); return; end
dlg.Value = min(e.bytesDone / max(e.bytesTotal, 1), 1);
dlg.Message = sprintf("%s file %d of %d (%s of %s):\n%s", verb, e.index, e.count, ...
    bytesText(e.bytesDone), bytesText(e.bytesTotal), e.file);
drawnow limitrate;
end


function cleanupLog(obj, msg)
%cleanupLog  Append a timestamped line to the Clean up log (MSG used as is).
if isempty(obj.CleanupLogArea) || ~isvalid(obj.CleanupLogArea); return; end
line = string(datetime('now', 'Format', 'HH:mm:ss')) + "  " + string(msg);
cur = obj.CleanupLogArea.Value;
if isscalar(cur) && strlength(string(cur{1})) == 0
    cur = cell(0, 1);
end
obj.CleanupLogArea.Value = [cur; cellstr(line)];
scroll(obj.CleanupLogArea, 'bottom');
drawnow limitrate;
end


function s = bytesText(b)
units = ["B", "KB", "MB", "GB", "TB"];
k = 1;
while b >= 1024 && k < numel(units)
    b = b / 1024; k = k + 1;
end
if k == 1
    s = sprintf("%d B", round(b));
else
    s = sprintf("%.1f %s", b, units(k));
end
end
