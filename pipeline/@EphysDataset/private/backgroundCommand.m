function bg = backgroundCommand(command, logFile, exitFile, launcher, title)
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
%
%   On Windows the steps go into the batch file LAUNCHER (the run folder's
%   ks4_launch.cmd), and BG starts it minimised in a window titled TITLE. A
%   one-line "start ... cmd /s /c "..."" cannot carry them: its nested quotes
%   leave the paths unquoted to the shell that runs it, so a path with & or
%   ^ in it splits the command. In the batch file every path sits in quotes
%   of its own (% is doubled). The command runs in a cmd of its own (cmd /c)
%   so that the batch file goes on to the exit marker even when the command
%   is itself a batch file (conda.bat); the @ in front of it (and of the
%   launcher) keeps cmd /c from stripping the command's first and last
%   quote. The batch file is UTF-8 (chcp 65001), for paths that are not
%   ASCII.
log = char(logFile);
ex  = char(exitFile);
if ispc
    pct = @(s) strrep(char(s), '%', '%%');
    lines = ["@chcp 65001 > nul"
        "@echo off"
        "rem Kilosort4 run in the background, written by EphysDataset.launchSorting"
        "set PYTHONUNBUFFERED=1"
        "cmd /d /c @" + pct(command) + " 1> """ + pct(log) + """ 2>&1"
        "type nul > """ + pct(ex) + """"];
    writelines(lines, launcher, LineEnding="\r\n", Encoding="UTF-8");
    bg = sprintf('start "%s" /min cmd /c @"%s"', title, launcher);
else
    bg = sprintf('(PYTHONUNBUFFERED=1 %s > "%s" 2>&1; touch "%s") > /dev/null 2>&1 &', command, log, ex);
end
end
