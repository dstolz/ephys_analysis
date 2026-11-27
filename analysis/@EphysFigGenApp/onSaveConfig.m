function ok = onSaveConfig(obj)
%onSaveConfig  Save the working config to its file (Save As when it has none).
%   The preferences are saved after it; a failure there is a warning and a Log line, not a failed save.
ok = false;
cfg = obj.gatherConfig();
if cfg.File == ""
    ok = obj.onSaveConfigAs();
    return
end
try
    cfg = cfg.save(cfg.File);
catch ME
    obj.log("Could not save " + string(cfg.File) + ": " + string(ME.message));
    AppDialog.alertFailure(obj.Fig, "Save config", "save the config", string(cfg.File), ME, ...
        Try="save it somewhere else with File > Save config as...", Details="Log tab");
    return
end
obj.Config = cfg;
obj.SavedConfigStruct = cfg.toStruct();
obj.addRecentConfig(cfg.File);
try
    obj.savePreferences();   % the config is saved by now: a preferences file that cannot be written does not undo that (nor stop a Close that asked for the save)
catch ME
    obj.log("Could not save the preferences: " + string(ME.message));
    warning('EphysFigGenApp:SavePrefsFailed', 'Could not save preferences: %s', ME.message);
end
obj.updateTitle();
obj.setStatus("Saved " + cfg.File);
ok = true;
end
