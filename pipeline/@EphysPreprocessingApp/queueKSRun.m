function queueKSRun(obj, d, res)
%queueKSRun  The pipeline's QueueFcn: hold a prepared Kilosort4 run for the monitor.
%   obj.queueKSRun(D, RES): D is the dataset, RES what runKilosort
%   returned with Launch=false (every file written).
%   The run joins KSQueue and the monitor (pollKSRuns) starts it with
%   D.launchSorting once fewer than Sorting.MaxConcurrent runs are going.
%   Used when the Run tab's "Queue the waiting runs" is ticked, so the Run
%   goes on without waiting for slots. Stop queue (onStopKSQueue) drops
%   the queued runs; closing the app asks first (onClose).
%
%   See also pollKSRuns, EphysPipeline.runSorting.

obj.KSQueue(end+1) = struct('Name', string(d.Name), 'dataset', d, 'prepared', res);
if ~isempty(obj.RunKSStopQueueButton) && isvalid(obj.RunKSStopQueueButton)
    obj.RunKSStopQueueButton.Enable = "on";
end
obj.startKSMonitor();
end
