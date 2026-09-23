function stopTimers(obj)
%stopTimers  Stop and delete the app's timers: the Kilosort4 monitor, the
%   copy monitor, the resource monitor (and its sampler), the scheduled
%   copy's refresh and the Visualize viewer (whose timer merges redraws).
%   onClose calls it, and so does the figure's DeleteFcn, so
%   a figure deleted any other way (delete(app.Fig), close all force) leaves
%   none running. A background copy and running Kilosort4 processes carry
%   on: only the watching stops.
obj.stopKSMonitor();
obj.stopCopyMonitor();
obj.stopResourceMonitor();
t = obj.CopyScheduleTimer;   % only watches the scheduled copy's state
if ~isempty(t) && isvalid(t)
    stop(t);
    delete(t);
end
obj.CopyScheduleTimer = [];
if ~isempty(obj.Viewer) && isvalid(obj.Viewer)
    delete(obj.Viewer);
end
obj.Viewer = [];
end
