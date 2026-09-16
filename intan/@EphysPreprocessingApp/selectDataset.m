function selectDataset(obj, idx)
    % Make dataset IDX the app-wide single-dataset target (Dataset menu).
    if isempty(obj.Project) || idx < 1 || idx > obj.Project.NumDatasets
        obj.SelectedDatasetIdx = 0;
    else
        obj.SelectedDatasetIdx = idx;
    end
    obj.updateDatasetMenuCheck();
    obj.populateVizFiles();
end
