function onCleanupPreview(obj)
%onCleanupPreview  List the selected datasets' files as Remove or Keep (planLocalCleanup).
%   Reads only file listings (and the sources of copied raw files); nothing
%   is changed. The plan is what Remove files... deletes.
obj.CleanupPlan = [];
obj.CleanupPlanKeys = string.empty(1, 0);
idx = obj.selectedDatasetIndices();
if isempty(idx)
    obj.refreshCleanupTable();
    uialert(obj.Fig, "Scan a project on the Project tab first.", "Clean up");
    return
end
kinds = ["raw" "sorter_copy" "bin"];
kinds = kinds([obj.CleanupRawCheckBox.Value, obj.CleanupSorterCopyCheckBox.Value, obj.CleanupBinCheckBox.Value]);
obj.setStatus(sprintf("Clean up: listing the files of %d dataset(s) and checking the sources...", numel(idx)), "");
try
    T = planLocalCleanup(obj.Project.Datasets(idx), Remove=kinds);
catch ME
    obj.refreshCleanupTable();
    uialert(obj.Fig, ME.message, "Clean up");
    obj.setStatus("Clean up: preview failed.", "");
    return
end
keys = obj.Project.datasetKeys();
obj.CleanupPlan = T;
obj.CleanupPlanKeys = keys(idx);
obj.refreshCleanupTable();
obj.setStatus("Clean up: " + obj.CleanupSummaryLabel.Text, "");
end
