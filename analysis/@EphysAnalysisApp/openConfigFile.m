function ok = openConfigFile(obj, file)
%openConfigFile  Load an analysis config JSON (no save prompt) and scan its source.
%   Returns true on success; adds the file to the recent list. The source
%   is scanned when its root or folders exist.
ok = false;
try
    ws = warning('off', 'EphysAnalysisConfig:LoadWarnings');
    cfg = EphysAnalysisConfig.load(file);
    warning(ws);
catch ME
    uialert(obj.Fig, "Could not open the analysis config:" + newline + string(ME.message), "Open config");
    return
end
obj.SelectedPlot = min(1, numel(cfg.Plots));
obj.applyConfig(cfg, MarkSaved=true);
obj.addRecentConfig(file);
obj.savePreferences();
msg = "Opened " + string(file);
if ~isempty(cfg.LoadWarnings); msg = msg + " (" + strjoin(cfg.LoadWarnings, "; ") + ")"; end
obj.setStatus(msg);
S = cfg.Source;
if (S.Mode == "project" && S.Root ~= "" && isfolder(S.Root)) || (S.Mode == "folders" && ~isempty(S.Folders) && all(isfolder(S.Folders)))
    obj.onScan();
end
ok = true;
end
