function onCleanupRun(obj)
%onCleanupRun  Confirm, then delete the ticked Remove rows of the Clean up preview (runLocalCleanup).
%   The confirmation lists what goes, by kind, and what stays, and says how
%   many ticked files the table's filters hide. Nothing is
%   deleted while the pipeline, a copy or a Kilosort4 run is under way,
%   since any of them may be using the files. Afterwards the preview is
%   made again, so the table shows what is left.
T = obj.CleanupPlan;
if isempty(T); return; end
% an unticked Remove row stays: runLocalCleanup deletes only Action "remove"
hidden = setdiff(find(T.Action == "remove" & T.Include), obj.CleanupRowMap);
unticked = T.Action == "remove" & ~T.Include;
T.Action(unticked) = "keep";
T.Reason(unticked) = "Unticked in the preview.";
if ~any(T.Action == "remove"); return; end
busy = "";
if obj.RunActive
    busy = "The pipeline is running.";
elseif ~isempty(obj.CopyJob)
    busy = "A copy is running.";
elseif ~isempty(obj.KSRuns) && ~all([obj.KSRuns.done])
    busy = "A Kilosort4 run is under way.";
elseif ~isempty(obj.KSQueue)
    busy = "Kilosort4 runs are queued (Run tab, Stop queue drops them).";
end
if busy ~= ""
    uialert(obj.Fig, busy + " Clean up once it has finished.", "Clean up");
    return
end

rm = T(T.Action == "remove", :);
kept = T(T.Action == "keep", :);
kinds = ["raw" "sorter_copy" "bin"];
words = ["Raw recording files (a copy of the same size is at the source)", ...
    "Kilosort4's filtered copy of the recording", "Sorting input .bin files"];
lines = strings(0, 1);
for k = 1:numel(kinds)
    sel = rm.Category == kinds(k);
    if any(sel)
        lines(end+1) = sprintf("  - %s: %d file(s), %s", words(k), nnz(sel), bytesText(sum(rm.Bytes(sel)))); %#ok<AGROW>
    end
end
nDs = numel(unique(rm.Dataset));
msg = [sprintf("Permanently delete %d file(s), %s, from %d dataset(s)?", height(rm), bytesText(sum(rm.Bytes)), nDs)
    lines
    ""
    sprintf("%d file(s), %s, remain: every pipeline output, the sorted units, the manifests and the Epsych2 sessions.", ...
        height(kept), bytesText(sum(kept.Bytes)))
    "The files are deleted, not moved to the Recycle Bin."];
if ~isempty(hidden)
    msg = [msg; ""; sprintf("%d of the files to delete are ticked but hidden by the search, Subject or Show filters.", numel(hidden))];
end
if any(rm.Category == "raw")
    msg = [msg; ""; "Datasets whose raw recording is removed cannot be run, viewed or scanned until they are copied back from the source."];
end
answer = uiconfirm(obj.Fig, strjoin(msg, newline), "Delete local files", ...
    "Options", {sprintf('Delete %d file(s)', height(rm)), 'Cancel'}, ...
    "DefaultOption", 2, "CancelOption", 2, "Icon", "warning");
if answer == "Cancel"
    obj.setStatus("Clean up cancelled; nothing was deleted.", "");
    return
end

obj.CleanupRunButton.Enable = "off";
obj.CleanupPreviewButton.Enable = "off";
restore = onCleanup(@() set(obj.CleanupPreviewButton, "Enable", "on"));
cleanupLog(obj, sprintf("Deleting %d file(s) from %d dataset(s)...", height(rm), nDs));
R = runLocalCleanup(T, LogFcn=@(m) cleanupLog(obj, m));
done = R.Status == "removed";
summary = sprintf("Removed %d file(s), %s.", nnz(done), bytesText(sum(R.Bytes(done))));
if any(~done)
    summary = summary + sprintf(" %d file(s) left in place (see the log).", nnz(~done));
end
cleanupLog(obj, summary);

obj.onCleanupPreview();   % show what is left
hint = "";
if any(done & R.Category == "raw")
    hint = "Scan the project again: datasets whose raw recording was removed drop out of it.";
end
obj.setStatus("Clean up: " + summary, hint);
if any(~done)
    uialert(obj.Fig, summary, "Clean up", "Icon", "warning");
end
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
