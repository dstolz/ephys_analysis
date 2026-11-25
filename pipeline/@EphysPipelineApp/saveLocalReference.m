function why = saveLocalReference(obj, d, map, probeFile, ticked)
%saveLocalReference  Keep a local reference map on dataset D, or on the ticked datasets.
%   WHY = app.saveLocalReference(D, MAP, PROBEFILE, TICKED): MAP (a
%   LocalReferenceMap, drawn on PROBEFILE) is set on D (TICKED false) or on
%   every dataset ticked in the Project table (TICKED true), with
%   LocalReferenceProbe = PROBEFILE, and saved in their manifests. A ticked
%   dataset is skipped, and named, when the steps would use another probe
%   for it (EphysPipeline.resolveProbe: a different file name) or when the
%   map names a channel past its channel count: the map follows a probe's
%   channels. WHY is "" when the map was saved on at least one dataset,
%   else the reason (LocalReferenceDialog shows it and stays open).
%   Refused while a run is under way.
%
%   See also onLocalReference, LocalReferenceDialog, EphysDataset.LocalReferenceMap.

why = "";
if obj.refuseWhileRunning("Local reference")
    why = "A run is under way: the map is not saved.";
    return
end
try
    map = EphysDataset.normalizeLocalReferenceMap(map);
catch ME
    why = string(ME.message);
    return
end
if ticked
    idx = obj.tickedDatasetIndices();
    if isempty(idx)
        why = "No dataset is ticked in the Project table.";
        return
    end
    targets = obj.Project.Datasets(idx);
else
    targets = d;
end
top = max([0, [map.reference], map.channels]);
keep = true(1, numel(targets));
skipped = strings(1, 0);
for k = 1:numel(targets)
    t = targets(k);
    pf = EphysPipeline.resolveProbe(obj.Config.Probe, t);
    if ~strcmpi(fileName(pf), fileName(probeFile))
        keep(k) = false;
        skipped(end + 1) = t.Name + " (probe " + ternary(pf == "", "none", fileName(pf)) + ")"; %#ok<AGROW>
    elseif isfinite(t.NumChannels) && top > t.NumChannels
        keep(k) = false;
        skipped(end + 1) = t.Name + sprintf(" (%d channels)", t.NumChannels); %#ok<AGROW>
    end
end
targets = targets(keep);
if isempty(targets)
    why = "Not saved: " + strjoin(skipped, ", ") + ". The map was drawn on " + fileName(probeFile) + ".";
    return
end
for t = reshape(targets, 1, [])
    t.LocalReferenceMap = map;
    t.LocalReferenceProbe = probeFile;
end
obj.saveManifests(targets);
obj.refreshReferencePanel();
obj.drawArtifactView();   % a preview made with the old map is out of date
if isempty(map)
    msg = sprintf("Local reference cleared on %d dataset(s).", numel(targets));
else
    msg = sprintf("Local reference (%d reference channel(s)) saved on %d dataset(s).", numel(map), numel(targets));
end
if ~isempty(skipped)
    msg = msg + " Skipped: " + strjoin(skipped, ", ") + ".";
end
hint = "Tick Local reference first to use it.";
if obj.ArtRefLocalCheckBox.Value
    hint = "Press Detect / Preview to see the artifacts with it.";
end
obj.setStatus(msg, hint);
end


function s = fileName(f)
[~, nm, ext] = fileparts(string(f));
s = string(nm) + string(ext);
end


function v = ternary(tf, a, b)
if tf; v = a; else; v = b; end
end
