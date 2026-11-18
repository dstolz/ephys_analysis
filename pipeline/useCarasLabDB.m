function found = useCarasLabDB()
%useCarasLabDB  Put the CarasLabDB checkout (the labclient package) on the MATLAB path when it is not.
%   FOUND = useCarasLabDB() looks for the repository that holds the shared
%   lab database client (its +labclient and @CarasLabDB folders) in, in
%   order: the folder the environment variable CARASLABDB_DIR names, a
%   folder CarasLabDB beside this repository's folder, and one next to
%   the folder above that. Where it finds one it adds that folder (only that
%   folder: the repository has nothing else to put on the path) and returns
%   true. It does nothing, and returns the answer, when the package is
%   already there. LabBridge calls it once, before it says the client is
%   missing.
%
%   See also LabBridge, addpath_nogit.

found = exist("labclient.DB", "class") == 8;
if found; return; end
here = fileparts(mfilename('fullpath'));
repo = fileparts(here);
candidates = [string(getenv("CARASLABDB_DIR")), string(fullfile(fileparts(repo), "CarasLabDB")), ...
    string(fullfile(fileparts(fileparts(repo)), "CarasLabDB"))];
for c = candidates
    if strlength(c) > 0 && isfolder(fullfile(c, "+labclient"))
        addpath(char(c));
        found = exist("labclient.DB", "class") == 8;
        if found; return; end
    end
end
end
