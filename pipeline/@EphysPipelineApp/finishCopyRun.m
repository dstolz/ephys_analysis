function finishCopyRun(obj, R)
%finishCopyRun  Report a finished copy batch and, if asked, open what it copied.
%   R is the copySessions result for the ticked rows. Failures are shown once,
%   in one dialog; a cancelled batch says how to complete it. With "open the
%   copied sessions as the project" ticked and nothing failed, the Project root
%   becomes the folder holding the copied / already present sessions and is
%   scanned.

obj.CopyProgressLabel.Text = '';
obj.setStatus(obj.copySummaryText("Copy sessions", R), "");

if any(R.CopyStatus == "failed")
    bad = R(R.CopyStatus == "failed", :);
    msg = strjoin(compose("%s: %s", bad.DestDir, bad.Message), newline + newline);
    uialert(obj.Fig, msg, sprintf("%d session(s) failed", height(bad)));
elseif any(R.CopyStatus == "cancelled")
    obj.setStatus(obj.copySummaryText("Copy sessions", R), ...
        "Copy selected with If it exists = resume completes what was cancelled.");
end

ready = R.DestDir(R.CopyStatus == "copied" | R.CopyStatus == "already_present");
if ~isempty(ready) && obj.CopyScanAfterCheckBox.Value && ~any(R.CopyStatus == "failed")
    openAsProject(obj, ready);
end
end


function openAsProject(obj, sessionDirs)
%openAsProject  Scan the folder holding SESSIONDIRS as the project; make the first one active.
%   The first dataset is the session folder itself or, for an Open Ephys
%   session split into one dataset per recording, its first part folder.
parents = unique(arrayfun(@(d) string(fileparts(d)), sessionDirs));
root = parents(1);
if numel(parents) > 1
    root = string(fileparts(parents(1)));   % sessions of several subjects: <DestRoot>
end
obj.copyLog("Opening " + root + " as the project");
obj.RootPathField.Value = char(root);
obj.onConfigChanged();
obj.selectTab(obj.TabProject);
obj.onScan();
P = obj.Project;
if isempty(P) || P.NumDatasets == 0; return; end
folders = arrayfun(@(d) string(d.Folder), P.Datasets);
idx = find(strcmpi(folders, sessionDirs(1)) | startsWith(lower(folders), lower(sessionDirs(1) + filesep)), 1);
if ~isempty(idx)
    obj.selectDataset(idx);
end
end
