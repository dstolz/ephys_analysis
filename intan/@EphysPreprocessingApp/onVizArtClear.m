function onVizArtClear(obj)
    % Remove all manual artifact periods for the current dataset.
    d = obj.currentVizDataset();
    if isempty(d) || isempty(d.ManualArtifacts)
        obj.updateVizArtStatus();
        return
    end
    d.ManualArtifacts = zeros(0, 2);
    d.writeManifest();                 % periods persist in the manifest
    if ~isempty(obj.Viewer) && isvalid(obj.Viewer); obj.Viewer.render(); end
    obj.updateVizArtStatus();
end
