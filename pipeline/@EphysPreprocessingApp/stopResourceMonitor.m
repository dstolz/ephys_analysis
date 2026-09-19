function stopResourceMonitor(obj)
%stopResourceMonitor  Stop the resource timer and tell the sampler to exit.
%   The sampler sees the stop file within one interval, exits and deletes
%   its folder.
t = obj.ResourceMonitorTimer;
if ~isempty(t) && isvalid(t)
    try
        stop(t);
    catch
    end
    try
        delete(t);
    catch
    end
end
obj.ResourceMonitorTimer = [];
d = obj.ResourceMonitor.dir;
if d ~= "" && isfolder(d)
    fid = fopen(fullfile(d, "stop"), 'w');
    if fid > 0; fclose(fid); end
end
obj.ResourceMonitor.dir = "";
end
