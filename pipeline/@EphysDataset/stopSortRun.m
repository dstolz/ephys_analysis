function [stopped, message] = stopSortRun(statusFile)
%stopSortRun  Stop a background Kilosort4 run that is going.
%   [STOPPED, MESSAGE] = EphysDataset.stopSortRun(STATUSFILE) ends the run
%   whose ks4_status.json is STATUSFILE (a launchSorting result's
%   statusFile, or a LaunchedRuns element's). Every process whose command
%   line names the run folder's driver (<run folder>\run_si_ks4.py or
%   run_ks4.py: the launcher's cmd.exe, conda, Python) is ended with its
%   child processes (taskkill /T on Windows, pkill elsewhere). Then
%   ks4_status.json is written as {"state": "cancelled", "message":
%   "stopped by the user"} and the SortExitMarker beside it, so
%   sortRunState reports "cancelled" and the run's slot frees. Whatever
%   Kilosort4 had written so far stays in the run folder.
%
%   STOPPED is false, and nothing is touched, when the run is not running
%   (sortRunState: it has finished, failed or was stopped). MESSAGE says
%   how many processes were ended ("" when STOPPED is false). A run whose
%   processes are already gone (say, after a reboot) is marked cancelled
%   all the same.
%
%   Only background runs can be stopped this way: MATLAB itself waits for
%   a blocking run.
%
%   See also EphysDataset.sortRunState, EphysDataset.launchSorting.

arguments
    statusFile (1,1) string
end

stopped = false;
message = "";
if EphysDataset.sortRunState(statusFile) ~= "running"
    return
end
runDir = fileparts(char(statusFile));
pattern = [runDir filesep 'run_'];

% The pattern goes through the environment, so no command line but the
% run's own processes holds it (not the shell that runs the search).
old = getenv('EPHYS_STOP_PATTERN');
setenv('EPHYS_STOP_PATTERN', pattern);
restore = onCleanup(@() setenv('EPHYS_STOP_PATTERN', old));
if ispc
    ps = ['$ids = @(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and ' ...
        '$_.CommandLine.IndexOf($env:EPHYS_STOP_PATTERN, [StringComparison]::OrdinalIgnoreCase) -ge 0 } | ' ...
        'ForEach-Object { $_.ProcessId }); ' ...
        'foreach ($i in $ids) { taskkill /T /F /PID $i 2>&1 | Out-Null }; $ids.Count'];
    [~, out] = system(['powershell.exe -NoProfile -NonInteractive -Command "' ps '"']);
else
    [~, out] = system('n=$(pgrep -f -- "$EPHYS_STOP_PATTERN" | wc -l); pkill -f -- "$EPHYS_STOP_PATTERN"; echo $n');
end
n = str2double(regexp(strtrim(out), '\d+$', 'match', 'once'));
if isnan(n); n = 0; end
clear restore

writeJsonFile(char(statusFile), struct('state', "cancelled", 'message', "stopped by the user"));
fclose(fopen(fullfile(runDir, char(EphysDataset.SortExitMarker)), 'w'));
stopped = true;
message = sprintf("stopped %d process(es)", n);
end
