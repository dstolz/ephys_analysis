function queueKSRun(obj, d, res)
%queueKSRun  The pipeline's QueueFcn: hold a prepared Kilosort4 run for the monitor.
%   obj.queueKSRun(D, RES): D is the dataset, RES what runKilosort
%   returned with Launch=false (every file written).
%   The run joins KSQueue and the monitor (pollKSRuns) starts it with
%   D.launchSorting once fewer than Sorting.MaxConcurrent runs are going.
%   Used when the Run tab's "Queue the waiting runs" is ticked, so the Run
%   goes on without waiting for slots. Stop queue (onStopKSQueue) drops
%   the queued runs; closing the app asks first (onClose). A run for a
%   dataset whose Kilosort4 folder already has one queued or going is not
%   queued again (the log says so): the sorting step skips such datasets
%   (EphysPipeline.activeRun), so this only guards against a second copy.
%
%   See also pollKSRuns, EphysPipeline.runSorting.

busy = strings(1, 0);   % the Kilosort4 folders of the runs queued or going
for q = obj.KSQueue
    busy(end+1) = q.prepared.resultsDir; %#ok<AGROW>
end
for r = obj.KSRuns(~[obj.KSRuns.done])
    busy(end+1) = r.resultsDir; %#ok<AGROW>
end
if any(EphysDataset.pathKey(busy) == EphysDataset.pathKey(res.resultsDir))
    obj.log("[sorting] %s: Kilosort4 is already queued or running for it; not queued again", d.Name);
    return
end
obj.KSQueue(end+1) = struct('Name', string(d.Name), 'dataset', d, 'prepared', res);
if ~isempty(obj.RunKSStopQueueButton) && isvalid(obj.RunKSStopQueueButton)
    obj.RunKSStopQueueButton.Enable = "on";
end
obj.startKSMonitor();
end
