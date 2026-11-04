function ok = onSaveConfigAs(obj, file)
%onSaveConfigAs  Save the working config to a file picked (or given as FILE).
arguments
    obj (1,1) EphysAnalysisApp
    file (1,1) string = ""
end
ok = false;
cfg = obj.gatherConfig();
if file == ""
    start = char(cfg.File);
    if isempty(start)
        d = char(obj.defaultConfigFolder());
        name = regexprep(char(cfg.Name), '[^\w\-]+', '_');
        if isempty(name); name = 'analysis'; end
        start = fullfile(d, [name '.json']);
    end
    [f, p] = uiputfile({'*.json', 'Analysis config (*.json)'}, "Save analysis config as", start);
    figure(obj.Fig);
    if isequal(f, 0); return; end
    file = string(fullfile(p, f));
end
try
    cfg = cfg.save(file);
catch ME
    obj.log("Could not save " + file + ": " + string(ME.message));
    AppDialog.alertFailure(obj.Fig, "Save config", "save the config", file, ME, ...
        Try="choose another folder or file name", Details="Log tab");
    return
end
obj.Config = cfg;
obj.SavedConfigStruct = cfg.toStruct();
obj.addRecentConfig(file);
obj.savePreferences();
obj.updateTitle();
obj.setStatus("Saved " + file);
ok = true;
end
