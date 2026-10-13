function file = onSaveSessionData(obj, sp, opts)
%onSaveSessionData  Save a session plot's data as a .mat file.
%   FILE = app.onSaveSessionData(SP) asks where to save (uiputfile, which
%   asks before replacing a file; it starts in Export.Data.Folder, filled
%   in for the first of the session plot's datasets, as <id>.mat), then
%   computes the session plot SP (an id of the config's session plots, or a
%   session plot struct) over its datasets as EphysAnalysisRunner.sessionData
%   does -- under a cancelable progress dialog -- and writes the struct with
%   writeAnalysisData (Export.Data.MatVersion): the variables of the file
%   are the struct's fields. Returns the file ("" when canceled or nothing
%   could be made).
%
%   File=PATH skips the dialog, for scripts and tests; an existing file is
%   replaced.
%
%   See also onSessionsToWorkspace, writeAnalysisData, EphysAnalysisRunner.sessionData.
arguments
    obj (1,1) EphysAnalysisApp
    sp
    opts.File (1,1) string = ""
end
file = "";
dlgTitle = "Save session data";
if obj.Running; return; end
[cfg, sp, idx] = sessionPlotContext(obj, sp);
if isempty(sp); return; end
target = opts.File;
if target == ""
    r = obj.Runner;
    first = r.sessionTable(idx).index(1);
    tokens = struct('OutputFolder', r.datasetFolder(first), 'OutputRoot', r.outputRoot(), ...
        'Root', cfg.Source.Root, 'Name', r.Names(first));
    folder = figureFileName(cfg.Export.Data.Folder, tokens, Kind="folder");
    if ~isfolder(folder); folder = string(pwd); end
    [f, p] = uiputfile({'*.mat', 'MAT-file'}, "Save the data of " + sp.id, fullfile(folder, sp.id + ".mat"));
    if isequal(f, 0); return; end
    target = string(fullfile(p, f));
end
obj.setStatus("Sessions: reading the data of " + sp.id + " ...");
S = collectSessionData(obj, sp, cfg, idx, dlgTitle);
if isempty(S)
    return
end
try
    file = writeAnalysisData(target, S, MatVersion=cfg.Export.Data.MatVersion, Overwrite=true);
catch ME
    file = "";
    obj.log("Sessions: saving " + target + " failed: " + string(ME.message));
    uialert(obj.Fig, "Could not save " + target + ":" + newline + string(ME.message), dlgTitle);
    return
end
obj.log("Sessions: the data of " + sp.id + " saved to " + file);
obj.setStatus("Saved " + file);
end
