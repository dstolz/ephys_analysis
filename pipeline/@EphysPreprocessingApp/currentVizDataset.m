function d = currentVizDataset(obj)
    % Dataset handle backing the currently cached Visualize data ([] none).
    d = EphysDataset.empty;
    i = obj.VizDatasetIndex;
    if i >= 1 && ~isempty(obj.Project) && i <= obj.Project.NumDatasets
        d = obj.Project.Datasets(i);
    end
end
