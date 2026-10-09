function onCancelRun(obj)
%onCancelRun  Stop a run before its next plot.
if ~isempty(obj.Runner) && obj.Running
    obj.Runner.cancel();
    obj.setStatus("Canceling after the plot being drawn ...");
end
end
