function ok = openConfigFile(obj, file)
%openConfigFile  Load a config JSON into the app (no save prompt).
%   Returns true on success. Adds the file to the recent list.
ok = false;
try
    ws = warning('off', 'EphysPipelineConfig:LoadWarnings');
    cfg = EphysPipelineConfig.load(file);
    warning(ws);
catch ME
    uialert(obj.Fig, "Could not open config:" + newline + string(ME.message), "Open config");
    return
end
obj.applyConfig(cfg, MarkSaved=true);
obj.addRecentConfig(file);
obj.savePreferences();
if ~isempty(cfg.LoadWarnings)
    obj.setStatus("Opened " + file + " (" + strjoin(cfg.LoadWarnings, "; ") + ")", "");
else
    obj.setStatus("Opened " + file, "Scan the project root to load its datasets.");
end
ok = true;
end
