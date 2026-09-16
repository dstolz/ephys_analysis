function onClearManualArtifacts(obj)
%onClearManualArtifacts  Remove the selected dataset's manual periods (manifest too).
d = obj.currentDataset();
if isempty(d) || isempty(d.ManualArtifacts); return; end
d.ManualArtifacts = zeros(0, 2);
d.writeManifest();
obj.refreshManualArtifactsTable();
if ~isempty(obj.Viewer) && isvalid(obj.Viewer) && obj.VizDatasetIndex > 0 ...
        && obj.Project.Datasets(obj.VizDatasetIndex) == d
    obj.Viewer.render();
end
obj.updateVizArtStatus();
obj.setStatus(d.Name + ": manual artifact periods cleared.", "");
end
