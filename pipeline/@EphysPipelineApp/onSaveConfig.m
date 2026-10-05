function ok = onSaveConfig(obj)
%onSaveConfig  Save the working config to its file (Save As when it has none).
%   Refused while a text field does not parse (gatherConfig).
ok = false;
try
    cfg = obj.gatherConfig();
catch ME
    uialert(obj.Fig, string(ME.message), "Save config");
    return
end
if cfg.File == ""
    ok = obj.onSaveConfigAs();
    return
end
try
    cfg = cfg.save(cfg.File);
catch ME
    uialert(obj.Fig, "Could not save config:" + newline + string(ME.message), "Save config");
    return
end
obj.Config = cfg;
obj.SavedConfigStruct = cfg.toStruct();
obj.addRecentConfig(cfg.File);
obj.savePreferences();
obj.updateTitle();
obj.setStatus("Saved " + cfg.File, "");
ok = true;
end
