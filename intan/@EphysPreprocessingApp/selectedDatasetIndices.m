function idx = selectedDatasetIndices(obj)
    % Indices into obj.Project.Datasets ticked in the table's "Select"
    % column, resolved through each row's DatasetIdx (not the row
    % number) since sorting reorders table rows independently of
    % obj.Project.Datasets. Falls back to all datasets when none ticked.
    idx = [];
    if isempty(obj.Project) || obj.Project.NumDatasets == 0; return; end
    T = obj.DatasetsTable.Data;
    if istable(T) && any(strcmp('Select', T.Properties.VariableNames)) ...
            && any(strcmp('DatasetIdx', T.Properties.VariableNames))
        idx = T.DatasetIdx(T.Select(:))';
    end
    if isempty(idx)
        idx = 1:obj.Project.NumDatasets;
    end
end
