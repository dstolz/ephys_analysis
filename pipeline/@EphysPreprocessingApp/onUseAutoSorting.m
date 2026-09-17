function onUseAutoSorting(obj)
%onUseAutoSorting  Back to the auto-discovered run under the output folder.
d = obj.currentDataset();
if isempty(d); return; end
d.SortingDir = "";
d.writeManifest();
obj.refreshDatasetsTable();
obj.refreshSortingLabel();
obj.ReviewDatasetIdx = -1;   % the Review tab reloads it
obj.setStatus(d.Name + ": sorted output association set to auto.", "");
end
