function file = writeAnalysisData(file, S, opts)
%writeAnalysisData  Save a session plot's data struct (sessionData) as a .mat file.
%   FILE = writeAnalysisData(FILE, S, MatVersion="-v7.3", Overwrite=false)
%   writes the fields of S as the variables of the MAT-file FILE (".mat" is
%   added when FILE has no extension), so load(FILE) gives S's fields back
%   and S = load(FILE) the struct: for a sessionData struct the variables
%   schema, sessionPlot, spec, sessions, results, perSession, epochs,
%   config, created and provenance. EphysDataset.saveAtomically writes it:
%   to "~<name>.partial.mat" next to FILE, checked (no save warning, every
%   field present) and then renamed, so a failed or canceled save never
%   leaves a complete-looking file. The folder is made when it is not
%   there. Returns the file name written.
%
%   Options
%     MatVersion  "-v7.3" (default; HDF5, no 2 GB limit, h5read-able) or
%                 "-v7"
%     Overwrite   false (default): writeAnalysisData:Exists when FILE is
%                 there; true: replace it
%
%   See also sessionData, epochLongTable, EphysDataset.saveAtomically,
%   EphysAnalysisRunner.sessionData.
arguments
    file (1,1) string
    S (1,1) struct
    opts.MatVersion (1,1) string {mustBeMember(opts.MatVersion, ["-v7.3" "-v7"])} = "-v7.3"
    opts.Overwrite (1,1) logical = false
end
[~, ~, ext] = fileparts(file);
if ext == ""
    file = file + ".mat";
end
if isfile(file) && ~opts.Overwrite
    error('writeAnalysisData:Exists', '%s exists; pass Overwrite=true to replace it.', file);
end
EphysDataset.saveAtomically(file, S, opts.MatVersion);
end
