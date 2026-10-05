function onAssociateBehavior(obj)
%onAssociateBehavior  Pick an Epsych2 session file for the active dataset.
if obj.refuseWhileRunning("Associate file"); return; end
d = obj.currentDataset();
if isempty(d)
    uialert(obj.Fig, "Scan a project first.", "Behavior");
    return
end
start = char(d.BehaviorFile);
if isempty(start)
    dirs = obj.gatherBehaviorSection().SearchDirs;
    if ~isempty(dirs) && isfolder(dirs(1)); start = char(dirs(1)); else; start = pwd; end
end
[f, p] = uigetfile({'*.mat', 'Epsych2 session (*.mat)'}, "Associate an Epsych2 session with " + d.Name, start);
figure(obj.Fig);
if isequal(f, 0); return; end
file = fullfile(p, f);
try
    meta = epsychSessionMeta(file);
catch ME
    uialert(obj.Fig, "Not an Epsych2 session file:" + newline + string(ME.message), "Behavior");
    return
end
d.BehaviorFile = string(file);
obj.saveManifests(d);
obj.refreshDatasetsTable();
obj.setStatus(sprintf("%s: associated %s (%s, %d trials).", d.Name, f, meta.subject, meta.nTrials), "");
end
