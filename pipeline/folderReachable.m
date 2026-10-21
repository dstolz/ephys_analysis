function [ok, why] = folderReachable(folder, timeout)
%folderReachable  Whether a folder is there, without hanging on a network share that does not answer.
%   [OK, WHY] = folderReachable(FOLDER, TIMEOUT) is isfolder(FOLDER), except
%   that a folder on a network share (a \\server path, or on Windows a
%   mapped network drive) is looked for in the background (backgroundPool)
%   for at most TIMEOUT seconds (default 5): a share that has gone away can
%   hold isfolder for a minute or more. WHY says why OK is false: "no
%   folder is set", "it was not found" or "it did not answer within 5 s"
%   ("" when OK). The apps check a project root this way before their
%   startup scan (EphysPipelineApp, EphysAnalysisApp.openConfigFile).
%
%   See also isfolder, backgroundPool.
arguments
    folder (1,1) string
    timeout (1,1) double {mustBePositive} = 5
end
ok = false;
why = "";
folder = strtrim(folder);
if folder == ""
    why = "no folder is set";
    return
end
if ~isNetworkPath(folder)
    ok = isfolder(folder);
else
    try
        f = parfeval(backgroundPool, @isfolder, 1, char(folder));
        if ~wait(f, "finished", timeout)
            cancel(f);
            why = sprintf("it did not answer within %g s", timeout);
            return
        end
        ok = fetchOutputs(f);
    catch
        ok = isfolder(folder);   % no background pool here: look for it in this thread
    end
end
if ~ok; why = "it was not found"; end
end


function tf = isNetworkPath(folder)
%isNetworkPath  A \\server (or //server) path, or a folder on a mapped network drive (Windows).
tf = startsWith(folder, ["\\" "//"]);
if tf || ~ispc; return; end
d = regexp(char(folder), '^[A-Za-z]:', 'match', 'once');
if isempty(d); return; end
try
    tf = string(char(System.IO.DriveInfo([d '\']).DriveType)) == "Network";
catch
end
end
