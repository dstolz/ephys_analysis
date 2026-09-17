function idx = selectedDatasetIndices(obj)
    % Indices into obj.Project.Datasets ticked in the table's "Select"
    % column, including rows hidden by the token filters (see
    % tickedDatasetIndices). Falls back to all datasets when none ticked.
    idx = [];
    if isempty(obj.Project) || obj.Project.NumDatasets == 0; return; end
    idx = obj.tickedDatasetIndices();
    if isempty(idx)
        idx = 1:obj.Project.NumDatasets;
    end
end
