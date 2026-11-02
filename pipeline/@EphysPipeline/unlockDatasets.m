function unlockDatasets(obj)
%unlockDatasets  Give up the run locks lockDatasets took.
%   pipe.unlockDatasets() deletes the run lock of each dataset in
%   LockedDatasets (a lock of another process is never touched) and empties
%   the list. A sort lock of a background run stays with the run.
%
%   See also EphysPipeline.lockDatasets, RunLock.

arguments
    obj (1,1) EphysPipeline
end

for d = obj.LockedDatasets
    try
        RunLock.release(d, "run");
    catch
        % a lock that cannot be removed ages out (RunLock.StaleSeconds)
    end
end
obj.LockedDatasets = EphysDataset.empty(1, 0);
end
