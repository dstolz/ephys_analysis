function d = currentDataset(obj)
    % Return the EphysDataset for the last-selected table row ([] if none).
    % Looked up via the row's DatasetIdx (not the row number itself),
    % since sorting the table reorders rows independently of
    % obj.Project.Datasets.
    d = EphysDataset.empty;
    if isempty(obj.Project) || obj.SelectedRow < 1; return; end
    T = obj.DatasetsTable.Data;
    if ~istable(T) || obj.SelectedRow > height(T) ...
            || ~any(strcmp('DatasetIdx', T.Properties.VariableNames))
        return
    end
    di = T.DatasetIdx(obj.SelectedRow);
    if di >= 1 && di <= obj.Project.NumDatasets
        d = obj.Project.Datasets(di);
    end
end
