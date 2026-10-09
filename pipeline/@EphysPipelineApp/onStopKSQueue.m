function onStopKSQueue(obj)
%onStopKSQueue  Drop the queued Kilosort4 runs that have not started.
%   Their result rows become "canceled"; their run files (and .bin) stay on
%   disk. Runs already going carry on, and the monitor keeps following
%   them.
%
%   See also queueKSRun, pollKSRuns.

n = numel(obj.KSQueue);
if n == 0; return; end
Q = obj.KSQueue;
obj.KSQueue(:) = [];
for q = Q
    obj.markKSResult(q.Name, q.prepared.resultsDir, "canceled", "queue stopped before it started");
end
obj.log("[sorting] queue stopped: %d queued dataset(s) not started", n);
if isempty(obj.KSRuns)
    obj.stopKSMonitor();
    obj.KSProgressLabel.Text = sprintf("Background %s: queue stopped, %d dataset(s) not started.", ...
        sortersLabel(arrayfun(@(q) string(q.prepared.resultsDir), Q)), n);
    if ~isempty(obj.RunKSLabel) && isvalid(obj.RunKSLabel)
        obj.RunKSLabel.Text = obj.KSProgressLabel.Text;
    end
    obj.RunKSStopQueueButton.Enable = "off";
else
    obj.pollKSRuns();   % the label and the button follow
end
end
