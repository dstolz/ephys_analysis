function populateArtifactDatasets(obj)
    % Fill the Artifacts dataset dropdown from the scanned project.
    if isempty(obj.Project) || obj.Project.NumDatasets == 0
        obj.ArtDatasetDropDown.Items = {'(scan first)'};
        obj.ArtDatasetDropDown.ItemsData = {};
        return
    end
    names = cellstr([obj.Project.Datasets.Name]);
    obj.ArtDatasetDropDown.Items = names;
    obj.ArtDatasetDropDown.ItemsData = num2cell(1:numel(names));
end
