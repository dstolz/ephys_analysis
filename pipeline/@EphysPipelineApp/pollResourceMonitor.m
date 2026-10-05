function pollResourceMonitor(obj)
%pollResourceMonitor  Timer callback: show the sampler's latest sample.
%   Does nothing while another tab is showing. When no fresh sample has
%   come for 15 s (the sampler died, or never started), it is restarted.
if isempty(obj.Fig) || ~isvalid(obj.Fig)
    obj.stopResourceMonitor();
    return
end
if obj.Tabs.SelectedTab ~= obj.TabRun || obj.ResourceMonitor.dir == ""
    return
end
M = obj.ResourceMonitor;
S = [];
try
    S = jsondecode(fileread(fullfile(M.dir, "sample.json")));
catch
    % not written yet, or being swapped in: next tick
end
tNow = datetime("now");
last = M.started;
if ~isempty(S)
    last = max(last, datetime(S.t, "InputFormat", "yyyy-MM-dd'T'HH:mm:ss"));
end
quiet = seconds(tNow - last);
if quiet > 15
    obj.startResourceMonitor();
    obj.RunMonitorNote.Text = sprintf("No sample for %.0f s: restarted the sampler.", quiet);
    return
end
if ~isempty(S)
    obj.showResourceSample(S);
end
end
