function bg = backgroundCommand(command, logFile, exitFile, title)
%backgroundCommand  Wrap COMMAND to run detached with output redirected to LOG.
%   Once the process has exited, for any reason, an empty EXITFILE is written
%   next to it. The drivers write ks4_status.json only when Python gets far
%   enough to catch the failure. Without that status file, the exit marker
%   is what tells EphysDataset.sortRunState that a run has ended (a missing
%   Python or conda env, a crash).
%   PYTHONUNBUFFERED=1 forces unbuffered stdout/stderr; without it, Python
%   fully block-buffers when writing to a redirected file (not a TTY), so
%   ks4_run.log stays empty until the process exits and the live tail in
%   pollKSRuns has nothing to show.
log = char(logFile);
ex  = char(exitFile);
if ispc
    % start returns immediately; cmd /s /c keeps the inner quotes verbatim.
    bg = sprintf('start "%s" /min cmd /s /c "set PYTHONUNBUFFERED=1&& %s 1> "%s" 2>&1 & type nul > "%s""', ...
        title, command, log, ex);
else
    bg = sprintf('(PYTHONUNBUFFERED=1 %s > "%s" 2>&1; touch "%s") > /dev/null 2>&1 &', command, log, ex);
end
end
