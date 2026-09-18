function onGenerateScript(obj, kind, file)
%onGenerateScript  Write a compact or standalone script for the working config.
%   The compact form loads the saved JSON, so unsaved changes are saved
%   first (with a prompt). FILE skips the file dialog.
arguments
    obj (1,1) EphysAnalysisApp
    kind (1,1) string {mustBeMember(kind, ["compact", "standalone"])}
    file (1,1) string = ""
end
cfg = obj.gatherConfig();
if kind == "compact" && (cfg.File == "" || ~isequaln(cfg.toStruct(), obj.SavedConfigStruct))
    sel = uiconfirm(obj.Fig, "The compact script loads the saved config file. Save the config first?", ...
        "Generate script", "Options", {'Save', 'Cancel'}, "DefaultOption", 1, "CancelOption", 2);
    if ~strcmp(sel, 'Save') || ~obj.onSaveConfig(); return; end
    cfg = obj.Config;
end
if file == ""
    start = char(obj.ScriptFolder);
    if isempty(start) || ~isfolder(start); start = fileparts(char(cfg.File)); end
    if isempty(start) || ~isfolder(start); start = pwd; end
    name = regexprep(char(cfg.Name), '[^\w\-]+', '_');
    if isempty(name); name = 'analysis'; end
    [f, p] = uiputfile({'*.m', 'MATLAB script (*.m)'}, "Save " + kind + " script", ...
        fullfile(start, sprintf('run_%s_%s.m', name, kind)));
    figure(obj.Fig);
    if isequal(f, 0); return; end
    file = string(fullfile(p, f));
end
try
    if kind == "compact"
        EphysAnalysisScript.compact(cfg, File=file);
    else
        EphysAnalysisScript.standalone(cfg, File=file);
    end
catch ME
    uialert(obj.Fig, "Could not generate the script:" + newline + string(ME.message), "Generate script");
    return
end
obj.ScriptFolder = string(fileparts(file));
obj.savePreferences();
obj.setStatus("Wrote " + file + ". Open it in the editor and run it in a fresh MATLAB session.");
end
