function onUseSortingFolder(obj)
%onUseSortingFolder  Pin a Kilosort4 / phy results folder to the active dataset.
d = obj.currentDataset();
if isempty(d)
    uialert(obj.Fig, "Scan a project first.", "Sorting");
    return
end
start = char(d.sortingResultsDir());
if isempty(start) || ~isfolder(start); start = char(d.outputFolder()); end
if isempty(start) || ~isfolder(start); start = pwd; end
p = uigetdir(start, "Folder holding params.py / spike_clusters.npy for " + d.Name);
figure(obj.Fig);
if isequal(p, 0); return; end
r = EphysDataset.resolvePhyDir(p);
if ~isfile(fullfile(r, 'params.py'))
    uialert(obj.Fig, "No params.py found in or below " + string(p) + ".", "Sorting");
    return
end
d.SortingDir = string(r);
d.writeManifest();
obj.refreshDatasetsTable();
obj.refreshSortingLabel();
obj.ReviewDatasetIdx = -1;   % the Review tab reloads it
obj.setStatus(d.Name + ": sorted output pinned to " + string(r), "");
end
