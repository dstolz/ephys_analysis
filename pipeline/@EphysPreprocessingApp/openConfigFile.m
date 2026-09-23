function ok = openConfigFile(obj, file)
%openConfigFile  Load a config JSON into the app (no save prompt).
%   Returns true on success. Adds the file to the recent list. A config the
%   controls cannot show at all is refused (the config shown before stays,
%   with its file); values they cannot show are listed in an alert
%   (applyConfig).
ok = false;
try
    ws = warning('off', 'EphysPipelineConfig:LoadWarnings');
    cfg = EphysPipelineConfig.load(file);
    warning(ws);
catch ME
    uialert(obj.Fig, "Could not open config:" + newline + string(ME.message), "Open config");
    return
end
try
    rejected = obj.applyConfig(cfg, MarkSaved=true);
catch ME
    uialert(obj.Fig, "Could not open config " + file + ":" + newline + string(ME.message) + ...
        newline + newline + "The config shown before is kept.", "Open config");
    obj.setStatus("Could not open " + file + ": " + string(ME.message), "");
    return
end
obj.addRecentConfig(file);
obj.savePreferences();
if ~isempty(cfg.LoadWarnings)
    obj.setStatus("Opened " + file + " (" + strjoin(cfg.LoadWarnings, "; ") + ")", "");
else
    obj.setStatus("Opened " + file, "Scan the project root to load its datasets.");
end
if ~isempty(rejected)
    uialert(obj.Fig, "These settings cannot be shown in their fields, which show another value " + ...
        "(the config marks it unsaved; Save writes what is shown):" + newline + newline + ...
        strjoin(rejected, newline), "Open config", "Icon", "warning");
end
ok = true;
end
