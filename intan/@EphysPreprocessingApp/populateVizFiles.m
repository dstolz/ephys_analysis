function populateVizFiles(obj)
    % Fill the Visualize file dropdown for the chosen dataset.
    idx = obj.SelectedDatasetIdx;
    if idx < 1 || isempty(obj.Project) || idx > obj.Project.NumDatasets
        obj.VizFileDropDown.Items = {'(all)'};
        return
    end
    d = obj.Project.Datasets(idx);
    if d.NumFiles == 0; d.discoverFiles(); end
    obj.VizFileDropDown.Items = ['(all)'; cellstr(d.Files(:))];
end
