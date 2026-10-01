function onClearManualArtifacts(obj)
%onClearManualArtifacts  Remove the active dataset's manual periods (manifest too).
if obj.refuseWhileRunning("Clear"); return; end
d = obj.currentDataset();
if isempty(d) || isempty(d.ManualArtifacts); return; end
d.ManualArtifacts = zeros(0, 2);
obj.saveManifests(d);
obj.refreshManualArtifactsTable();
shown = obj.currentVizDataset();
if ~isempty(shown) && shown == d
    obj.refreshVizShading();
end
obj.updateVizArtStatus();
obj.setStatus(d.Name + ": manual artifact periods cleared.", "");
end
