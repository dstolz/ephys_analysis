function idx = toolTargets(obj)
%toolTargets  The datasets the Tools panel opens (indices into Project.Datasets).
%   Scope "Active dataset": the active one (selectDataset). "Ticked
%   datasets": the rows ticked in the Project table, or every dataset when
%   none is ticked, as a run takes them (selectedDatasetIndices). Empty
%   before a scan.
%
%   See also EphysPreprocessingApp.onOpenTool, EphysPreprocessingApp.syncToolsPanel.
idx = zeros(1, 0);
if isempty(obj.Project) || obj.Project.NumDatasets == 0; return; end
if obj.ToolsScopeDropDown.Value == "ticked"
    idx = reshape(obj.selectedDatasetIndices(), 1, []);
elseif obj.SelectedDatasetIdx >= 1 && obj.SelectedDatasetIdx <= obj.Project.NumDatasets
    idx = obj.SelectedDatasetIdx;
end
end
