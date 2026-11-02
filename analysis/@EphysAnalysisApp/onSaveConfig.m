function ok = onSaveConfig(obj)
%onSaveConfig  Save the working config to its file (Save As when it has none).
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
obj.savePreferences();
obj.updateTitle();
obj.setStatus("Saved " + cfg.File);
ok = true;
end
