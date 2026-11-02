function lockDatasets(obj, runId)
%lockDatasets  Take the run lock of every selected dataset not in use elsewhere.
%   pipe.lockDatasets(RUNID) takes RunLock "run" for each selected dataset
%   for the run RUNID; run() calls it before the first step and
%   unlockDatasets after the last. A dataset another session holds is
%   logged and not locked (the steps skip it, see inUse); LockedDatasets
%   lists those that were. A lock that cannot be written (a read-only
%   share) is logged, and the run goes on without it.
%
%   See also RunLock, EphysPipeline.unlockDatasets, EphysPipeline.run.

arguments
    obj (1,1) EphysPipeline
    runId (1,1) string = ""
end

obj.unlockDatasets();
held = EphysDataset.empty(1, 0);
for d = obj.selected()
    try
        RunLock.acquire(d, "run", "pipeline run '" + obj.Config.Name + "'", RunId=runId);
        held(end+1) = d; %#ok<AGROW>
    catch ME
        if strcmp(ME.identifier, 'RunLock:Held')
            obj.log("[lock] %s: %s; its steps are skipped", d.Name, strip(string(ME.message)));
        else
            obj.log("[lock] %s: no run lock (%s)", d.Name, ME.message);
        end
    end
end
obj.LockedDatasets = held;
end
