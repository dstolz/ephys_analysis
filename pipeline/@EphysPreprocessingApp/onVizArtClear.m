function onVizArtClear(obj)
    % Remove all manual artifact periods of the dataset the plot shows.
    if obj.refuseWhileRunning("Clear Artifacts"); return; end
    d = obj.currentVizDataset();
    if isempty(d) || isempty(d.ManualArtifacts)
        obj.updateVizArtStatus();
        return
    end
    d.ManualArtifacts = zeros(0, 2);
    obj.saveManifests(d);              % periods persist in the manifest
    obj.refreshVizShading();
    obj.updateVizArtStatus();
end
