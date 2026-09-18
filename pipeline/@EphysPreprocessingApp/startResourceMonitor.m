function startResourceMonitor(obj)
%startResourceMonitor  Launch the resource sampler and the timer that shows it.
%   The sampling is done by resource_monitor.ps1, launched detached at idle
%   priority in a fresh temporary folder: it opens the performance counters
%   once, keeps one nvidia-smi running for the GPU, and every 2 s
%   overwrites sample.json there. MATLAB only reads that small file, on a
%   2 s timer that does nothing while another tab is showing
%   (pollResourceMonitor). The sampler stops by itself when MATLAB exits.
%   Called again (as pollResourceMonitor does when samples stop coming), it
%   stops the previous sampler, launches a new one and keeps the timer.

interval = 2;
old = obj.ResourceMonitor.dir;
if old ~= "" && isfolder(old)
    fid = fopen(fullfile(old, "stop"), 'w');
    if fid > 0; fclose(fid); end
end
obj.ResourceMonitor.dir = "";
script = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'resource_monitor.ps1');
[~, name] = fileparts(tempname);
folder = string(fullfile(tempdir, "EphysResourceMonitor_" + name));
obj.showResourceSample([]);
if ~isfile(script)
    obj.RunMonitorNote.Text = "The sampler is missing: " + script;
    return
end
[ok, msg] = mkdir(folder);
if ~ok
    obj.RunMonitorNote.Text = "Could not make the sampler's folder: " + msg;
    return
end
cmd = sprintf('start "resource_monitor" /b powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%s" -Dir "%s" -ParentPid %d -Interval %g', ...
    script, folder, feature('getpid'), interval);
if system(cmd) ~= 0
    obj.RunMonitorNote.Text = "Could not launch the sampler: " + cmd;
    return
end
obj.ResourceMonitor = struct('dir', folder, 'started', datetime("now"), 'interval', interval);
obj.RunMonitorNote.Text = "Starting the sampler...";
t = obj.ResourceMonitorTimer;
if ~isempty(t) && isvalid(t) && strcmp(t.Running, 'on')
    return
end
obj.ResourceMonitorTimer = timer( ...
    "Name", "EphysPreprocessingAppResourceMonitor", ...
    "ExecutionMode", "fixedSpacing", "Period", interval, "StartDelay", interval, ...
    "BusyMode", "drop", "TimerFcn", @(~,~) obj.pollResourceMonitor());
start(obj.ResourceMonitorTimer);
end
