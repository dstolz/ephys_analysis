function d = currentDataset(obj)
%currentDataset  The active dataset (see selectDataset), [] when none.
d = EphysDataset.empty;
i = obj.SelectedDatasetIdx;
if i >= 1 && ~isempty(obj.Project) && i <= obj.Project.NumDatasets
    d = obj.Project.Datasets(i);
end
end
