function onCancelRun(obj)
%onCancelRun  Stop a run (or a figure's Generate) before its next figure observation.
if ~isempty(obj.Runner) && obj.Running
    obj.Runner.cancel();
    obj.setStatus("Canceling after the figure being drawn ...");
end
end
