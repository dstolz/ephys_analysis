function onClearManualArtifacts(obj, opts)
%onClearManualArtifacts  Remove the active dataset's manual periods (manifest too), after a confirmation.
%   onClearManualArtifacts(Confirm=false) skips the dialog (the tests).
arguments
    obj
    opts.Confirm (1,1) logical = true
end
if obj.refuseWhileRunning("Clear"); return; end
d = obj.currentDataset();
if isempty(d) || isempty(d.ManualArtifacts); return; end
if opts.Confirm
    n = size(d.ManualArtifacts, 1);
    answer = uiconfirm(obj.Fig, sprintf("Remove the %d period(s) you marked by hand on %s? They are taken out of its manifest; this cannot be undone.", n, d.Name), ...
        "Clear manual artifact periods", "Options", ["Remove them" "Cancel"], "DefaultOption", 2, "CancelOption", 2, "Icon", "warning");
    if answer ~= "Remove them"; return; end
end
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
