function n = sortRunProcesses(statusFiles)
%sortRunProcesses  How many processes each background Kilosort4 run has going.
%   N = EphysDataset.sortRunProcesses(STATUSFILES) counts, for the run
%   whose ks4_status.json is STATUSFILES(k), the processes whose command
%   line names the run folder's driver (<run folder>\run_ks4.py: the
%   cmd.exe that ks4_launch.cmd runs the command in, conda, Python), the
%   ones stopSortRun would end. One search covers every run (Win32_Process
%   through PowerShell on Windows, pgrep elsewhere). N(k) is 0 for a run
%   with no process left, and NaN where the search failed.
%
%   A background run leaves its exit marker once its launcher ends, so
%   sortRunState reports it "running" until then. A launcher that never
%   ends, as when the computer restarts under a run, leaves no marker: such
%   a run still reads "running" and has 0 processes here. The app does not
%   follow such a run again when it next opens (followKeptKSRuns).
%
%   See also EphysDataset.stopSortRun, EphysDataset.sortRunState.

arguments
    statusFiles (1,:) string
end

n = NaN(size(statusFiles));
if isempty(statusFiles); return; end
patterns = strings(size(statusFiles));
for k = 1:numel(statusFiles)
    patterns(k) = string([fileparts(char(statusFiles(k))) filesep 'run_']);
end

% The patterns go through the environment, so no command line but the
% runs' own processes holds them (not the shell that runs the search).
old = getenv('EPHYS_RUN_PATTERNS');
restore = onCleanup(@() setenv('EPHYS_RUN_PATTERNS', old)); %#ok<NASGU>
if ispc
    setenv('EPHYS_RUN_PATTERNS', char(strjoin(patterns, "|")));   % no Windows path holds "|"
    ps = ['$cl = @(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine } | ForEach-Object { $_.CommandLine }); ' ...
        '($env:EPHYS_RUN_PATTERNS -split ''\|'' | ForEach-Object { $p = $_; ' ...
        '@($cl | Where-Object { $_.IndexOf($p, [StringComparison]::OrdinalIgnoreCase) -ge 0 }).Count }) -join '' '''];
    [status, out] = system(['powershell.exe -NoProfile -NonInteractive -Command "' ps '"']);
    lines = splitlines(strtrim(string(out)));
    counts = str2double(split(lines(end)));   % the counts are the last line
    if status == 0 && numel(counts) == numel(patterns) && all(~isnan(counts))
        n = reshape(counts, size(statusFiles));
    end
else
    for k = 1:numel(patterns)
        setenv('EPHYS_RUN_PATTERNS', char(patterns(k)));
        [status, out] = system('pgrep -f -- "$EPHYS_RUN_PATTERNS" | wc -l');
        c = str2double(strtrim(out));
        if status == 0 && ~isnan(c); n(k) = c; end
    end
end
end
