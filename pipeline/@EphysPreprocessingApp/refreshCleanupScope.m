function refreshCleanupScope(obj)
%refreshCleanupScope  Say which datasets the Clean up tab acts on; drop a preview made for others.
%   Called when the tab is shown: the dataset selection is made on the
%   Project tab and may have changed since the last Preview.
if isempty(obj.CleanupScopeLabel) || ~isvalid(obj.CleanupScopeLabel); return; end
if isempty(obj.Project) || obj.Project.NumDatasets == 0
    obj.CleanupScopeLabel.Text = "Scan a project on the Project tab first.";
    obj.onCleanupSettingsChanged("No project");
    return
end
n = obj.Project.NumDatasets;
ticked = obj.tickedDatasetIndices();
if isempty(ticked)
    obj.CleanupScopeLabel.Text = sprintf("Acts on all %d datasets of the project (none is ticked on the Project tab).", n);
else
    obj.CleanupScopeLabel.Text = sprintf("Acts on the %d dataset(s) ticked on the Project tab (of %d).", numel(ticked), n);
end
keys = obj.Project.datasetKeys();
if ~isempty(obj.CleanupPlan) && ~isequal(sort(keys(obj.selectedDatasetIndices())), sort(obj.CleanupPlanKeys))
    obj.onCleanupSettingsChanged("The dataset selection changed");
end
end
