function onGenerateScript(obj, kind)
%onGenerateScript  Write a compact or standalone script for the working config.
%   The compact form loads the saved JSON, so unsaved changes are saved
%   first (with a prompt). Refused while a text field does not parse
%   (gatherConfig).
arguments
    obj (1,1) EphysPreprocessingApp
    kind (1,1) string {mustBeMember(kind, ["compact", "standalone"])}
end
try
    cfg = obj.gatherConfig();
catch ME
    uialert(obj.Fig, string(ME.message), "Generate script");
    return
end
if kind == "compact"
    dirty = cfg.File == "" || ~isequaln(cfg.toStruct(), obj.SavedConfigStruct);
    if dirty
        sel = uiconfirm(obj.Fig, "The compact script loads the saved config file. Save the config first?", ...
            "Generate script", "Options", {'Save', 'Cancel'}, "DefaultOption", 1, "CancelOption", 2);
        if ~strcmp(sel, 'Save'); return; end
        if ~obj.onSaveConfig(); return; end
        cfg = obj.Config;
    end
end
start = char(obj.ScriptFolder);
if isempty(start) || ~isfolder(start)
    start = fileparts(char(cfg.File));
end
if isempty(start) || ~isfolder(start); start = pwd; end
name = regexprep(char(cfg.Name), '[^\w\-]+', '_');
if isempty(name); name = 'pipeline'; end
[f, p] = uiputfile({'*.m', 'MATLAB script (*.m)'}, "Save " + kind + " script", ...
    fullfile(start, sprintf('run_%s_%s.m', name, kind)));
figure(obj.Fig);
if isequal(f, 0); return; end
file = fullfile(p, f);
try
    if kind == "compact"
        EphysPipelineScript.compact(cfg, File=file);
    else
        EphysPipelineScript.standalone(cfg, File=file);
    end
catch ME
    uialert(obj.Fig, "Could not generate the script:" + newline + string(ME.message), "Generate script");
    return
end
obj.ScriptFolder = string(p);
obj.savePreferences();
obj.setStatus("Wrote " + string(file), "Open it in the editor and run it in a fresh MATLAB session.");
try
    edit(file);
catch
end
end
