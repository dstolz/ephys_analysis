function d = currentArtifactDataset(obj)
    % Dataset selected on the Artifacts tab ([] if none).
    d = EphysDataset.empty;
    idx = obj.ArtDatasetDropDown.Value;
    if isempty(idx) || ~isnumeric(idx) || isempty(obj.Project) ...
            || idx > obj.Project.NumDatasets
        return
    end
    d = obj.Project.Datasets(idx);
end
