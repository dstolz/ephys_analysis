function onCleanupRun(obj)
%onCleanupRun  Confirm, then remove the ticked Remove rows of the Clean up preview (runCleanup).
%   The confirmation says how the files go (deleted, to the Recycle Bin, or
%   moved to the folder given), lists what goes, by kind and step, and what
%   stays, warns when phy curation or unit notes go with a sorting, and
%   says how many ticked files the table's filters hide. Nothing is
%   removed while the pipeline, a copy or a Kilosort4 run is under way,
%   since any of them may be using the files. A move needs a folder
%   outside the project and output roots, where a scan would find the
%   files again.
T = obj.CleanupPlan;
if isempty(T); return; end
% an unticked Remove row stays: runLocalCleanup removes only Action "remove"
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
method = string(obj.CleanupMethodDropDown.Value);
dest = strtrim(string(obj.CleanupDestField.Value));
if method == "move"
    why = destinationProblem(obj, dest);
    if why ~= ""
        uialert(obj.Fig, why, "Clean up");
        return
    end
end

rm = T(T.Action == "remove", :);
kept = T(T.Action == "keep", :);
nDs = numel(unique(rm.Dataset));
switch method
    case "delete"
        dlgTitle = "Delete local files";
        head = sprintf("Permanently delete %d file(s), %s, from %d dataset(s)?", height(rm), bytesText(sum(rm.Bytes)), nDs);
        how = "The files are deleted for good, not moved to the Recycle Bin.";
        button = sprintf('Delete %d file(s)', height(rm));
    case "recycle"
        dlgTitle = "Move local files to the Recycle Bin";
        head = sprintf("Move %d file(s), %s, from %d dataset(s) to the Recycle Bin?", height(rm), bytesText(sum(rm.Bytes)), nDs);
        how = "They can be restored from there; the space is freed only when the Recycle Bin is emptied. " + ...
            "A file on a drive without a Recycle Bin (network, removable) or too large for it is skipped, not deleted.";
        button = sprintf('Recycle %d file(s)', height(rm));
    case "move"
        dlgTitle = "Move local files";
        head = sprintf("Move %d file(s), %s, from %d dataset(s) to %s?", height(rm), bytesText(sum(rm.Bytes)), nDs, dest);
        how = "Each keeps its path below " + fullfile(dest, "<dataset key>") + "; a file already there is never overwritten.";
        button = sprintf('Move %d file(s)', height(rm));
end
msg = [head; groupLines(obj, rm); ""
    sprintf("%d file(s), %s, remain.", height(kept), bytesText(sum(kept.Bytes))); how];
% Kilosort4 writes a cluster_group.tsv of its own: only phy's is curation.
notes = rm.Category == "sorting" & endsWith(lower(rm.File), "cluster_notes.tsv");
labels = find(rm.Category == "sorting" & endsWith(lower(rm.File), "cluster_group.tsv"));
labels = labels(arrayfun(@(r) EphysDataset.phyCurated(fileparts(rm.File(r))), labels));
curated = unique(rm.Dataset([find(notes); labels]));
if ~isempty(curated)
    msg = [msg; ""; sprintf("The sorted units of %d dataset(s) carry phy curation or unit notes " + ...
        "(phy's cluster_group.tsv / cluster_notes.tsv), which go with them.", numel(curated))];
end
if ~isempty(hidden)
    msg = [msg; ""; sprintf("%d of the files to remove are ticked but hidden by the search, Subject or Show filters.", numel(hidden))];
end
if any(rm.Category == "raw")
    msg = [msg; ""; "Datasets whose raw recording is removed cannot be run, viewed or scanned until they are copied back from the source."];
end
answer = uiconfirm(obj.Fig, strjoin(msg, newline), dlgTitle, ...
    "Options", {button, 'Cancel'}, "DefaultOption", 2, "CancelOption", 2, "Icon", "warning");
if answer == "Cancel"
    obj.setStatus("Clean up cancelled; nothing was removed.", "");
    return
end
obj.runCleanup(T);
end


function lines = groupLines(obj, rm)
%groupLines  One line per kind of file going: raw, sorter copy and .bin when ticked as such, else by step.
kindTicked = ["raw" "sorter_copy" "bin"];
kindTicked = kindTicked([obj.CleanupRawCheckBox.Value, obj.CleanupSorterCopyCheckBox.Value, obj.CleanupBinCheckBox.Value]);
group = "step:" + rm.Step;
own = ismember(rm.Category, kindTicked);
group(own) = rm.Category(own);
words = ["raw" "Raw recording files (a copy of the same size is at the source)"
    "sorter_copy" "Kilosort4's filtered copy of the recording"
    "bin" "Sorting input .bin files"
    "step:sorting" "Sorting output: the kilosort4 folders (sorted units, phy curation, unit notes, logs) and .bin files"
    "step:signals" "Signals output (derived-signal .mat files)"
    "step:spikes" "Spikes output"
    "step:behavior" "Behavior output and digital events caches"
    "step:artifacts" "Artifact caches"
    "step:export" "Export files (Chronux, FieldTrip, epochs)"];
lines = strings(0, 1);
for k = 1:size(words, 1)
    sel = group == words(k, 1);
    if any(sel)
        lines(end+1, 1) = sprintf("  - %s: %d file(s), %s", words(k, 2), nnz(sel), bytesText(sum(rm.Bytes(sel)))); %#ok<AGROW>
    end
end
end


function why = destinationProblem(obj, dest)
%destinationProblem  Why DEST cannot take moved files ("" when it can).
why = "";
if dest == ""
    why = "Choose the folder to move the files into (Browse...).";
    return
end
if isempty(regexp(dest, '^([A-Za-z]:([\\/]|$)|\\\\)', 'once'))
    why = "The folder to move the files into must be a full path: " + dest;
    return
end
roots = [string(obj.Project.Root), string(obj.Project.OutputRoot)];
for r = roots(strlength(roots) > 0)
    if under(dest, r)
        why = sprintf("%s is inside the project folder %s, where a scan would find the moved files again. " + ...
            "Choose a folder outside it.", dest, r);
        return
    end
end
end


function tf = under(p, root)
%under  True when folder P is ROOT or inside it.
p = strip(strrep(string(p), "/", filesep), 'right', filesep);
root = strip(strrep(string(root), "/", filesep), 'right', filesep);
tf = strcmpi(p, root) || startsWith(lower(p), lower(root) + filesep);
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
