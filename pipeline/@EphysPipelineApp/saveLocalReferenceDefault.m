function why = saveLocalReferenceDefault(obj, d, map, probeFile)
%saveLocalReferenceDefault  Keep a local reference map on dataset D and as its probe's default.
%   WHY = app.saveLocalReferenceDefault(D, MAP, PROBEFILE): MAP (a
%   LocalReferenceMap on D's channels, drawn on PROBEFILE) is saved on D
%   (saveLocalReference), then kept in the config as PROBEFILE's default
%   (Reference.LocalDefaultProbes / LocalDefaultMaps), on the probe's
%   channels: channel c is chanMap value c-1, matched through D's hardware
%   numbers (EphysPipeline.localReferenceKey), so a dataset with channels
%   disabled at acquisition gives the map of a full recording. A default
%   of a probe file of that name is replaced. "Give new datasets their
%   probe's default" (Reference.LocalAutoAssign) is ticked: every dataset
%   on that probe without a map of its own then takes it, on Scan and when
%   a run starts (EphysPipeline.assignLocalReferenceDefaults). An empty
%   MAP removes the probe's default. The config is changed, not saved.
%   WHY is "" when it was kept, else the reason (LocalReferenceDialog
%   shows it and stays open).
%
%   See also saveLocalReference, onLocalReference, EphysPipeline.localReferenceDefault.

why = obj.saveLocalReference(d, map, probeFile, false);
if why ~= ""; return; end
map = EphysDataset.normalizeLocalReferenceMap(map);
R = obj.Config.Reference;
[~, nm, ext] = fileparts(R.LocalDefaultProbes);
[~, pnm, pext] = fileparts(string(probeFile));
probeName = string(pnm) + string(pext);
same = lower(string(nm) + string(ext)) == lower(probeName);
if isempty(map)
    R.LocalDefaultProbes(same) = [];
    R.LocalDefaultMaps(same) = [];
    msg = "Local reference cleared on " + d.Name + "; probe " + probeName + " has no default any more.";
else
    probe = readJsonFile(probeFile, ErrorOnFail=false);
    top = max([0, [map.reference], map.channels]);
    key = EphysPipeline.localReferenceKey(d, probe, top);
    def = EphysDataset.translateLocalReferenceMap(map, key, 0:max(key));
    text = EphysDataset.localReferenceText(def);
    k = find(same, 1);
    if isempty(k); k = numel(R.LocalDefaultProbes) + 1; end
    R.LocalDefaultProbes(k) = string(probeFile);
    R.LocalDefaultMaps(k) = text;
    keep = true(1, numel(R.LocalDefaultProbes));
    keep(setdiff(find(same), k)) = false;   % one default per probe name
    R.LocalDefaultProbes = R.LocalDefaultProbes(keep);
    R.LocalDefaultMaps = R.LocalDefaultMaps(keep);
    obj.ArtRefLocalAutoCheckBox.Value = true;
    msg = "Local reference saved on " + d.Name + ", and kept as the default of probe " + probeName + " (" + text + ...
        "): datasets on it without a local reference take it on Scan and when a run starts.";
end
obj.Config.Reference = R;
obj.onArtifactControlsChanged();   % gathers the config (the defaults kept, the box read), marks it unsaved
obj.setStatus(msg, "Save the config to keep the default.");
end
