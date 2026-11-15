function onOpenFromDatabase(obj, folders)
%onOpenFromDatabase  Recordings found in the lab database, as the Project tab's ticked datasets.
%   File > Open from database... opens LabLocatorDialog (What="sessions")
%   and calls this with the session folders picked, as they are on this
%   computer. onOpenFromDatabase(obj, FOLDERS) skips the window (scripts,
%   tests).
%
%   The project root becomes the folder that holds them all: their common
%   folder, or a lone session's parent. Recursive is turned on when one of
%   them is deeper than the folders directly in the root. The root is
%   scanned (onScan), and those sessions are ticked, every other dataset
%   unticked. The status bar names a folder the scan did not find as a
%   dataset. Folders on different drives or shares have no common folder:
%   nothing changes, and the status bar says so. Refused while a run is
%   under way.
%
%   See also LabLocatorDialog, LabLocator, onScan, applySelectionToTable.
arguments
    obj (1,1) EphysPipelineApp
    folders (1,:) string = strings(1, 0)
end
if nargin < 2
    if obj.refuseWhileRunning("Open from database"); return; end
    LabLocatorDialog.open(Parent=obj.Fig, What="sessions", OnDone=@(f) obj.onOpenFromDatabase(f));
    return
end
if obj.refuseWhileRunning("Open from database"); return; end
folders = regexprep(strtrim(folders), '[\\/]+$', '');
folders = unique(folders(strlength(folders) > 0), "stable");
if isempty(folders); return; end

[root, depth] = LabLocator.commonFolder(folders);
if root == ""
    obj.setStatus("Open from database: the " + numel(folders) + " session folders have no folder in common " + ...
        "(other drives or shares), so they cannot be one project.", ...
        "Pick the sessions of one drive or share, or set the project root by hand.");
    return
end
note = "";
if any(depth > 1) && ~obj.RecursiveCheckBox.Value
    obj.RecursiveCheckBox.Value = true;
    note = " Recursive is on: some sessions are deeper than the folders directly in the root.";
end
obj.RootPathField.Value = char(root);
obj.onConfigChanged();
obj.onScan();
if isempty(obj.Project) || obj.Project.NumDatasets == 0 || string(obj.Project.Root) ~= root
    return   % onScan said why
end

want = EphysDataset.pathKey(folders);
keys = strings(1, 0);
found = false(1, numel(folders));
for i = 1:obj.Project.NumDatasets
    k = find(want == EphysDataset.pathKey(obj.Project.Datasets(i).Folder), 1);
    if isempty(k); continue; end
    found(k) = true;
    keys(end + 1) = obj.Project.datasetKey(i); %#ok<AGROW>
end
P = obj.Config.Project;
P.Selection = "list";
P.Datasets = keys;
obj.applySelectionToTable(P);
obj.onConfigChanged();
msg = sprintf("Opened %d session(s) from the lab database: the project root is %s, %d ticked.", ...
    numel(folders), root, numel(keys)) + note;
if any(~found)
    msg = msg + " Not found as datasets by the scan: " + strjoin(folders(~found), ", ") + ".";
end
obj.setStatus(msg);
end

