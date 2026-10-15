function ok = openConfigFile(obj, file)
%openConfigFile  Load an analysis config JSON (no save prompt) and scan its source.
%   Returns true on success; adds the file to the recent list. The source
%   is scanned when its root or folders exist. The config's LoadWarnings
%   (dropped fields; a version-1 file's migration of its plots and session
%   plots to figures) go to the status bar and, one line each, to the Log.
ok = false;
try
    ws = warning('off', 'EphysAnalysisConfig:LoadWarnings');
    cfg = EphysAnalysisConfig.load(file);
    warning(ws);
catch ME
    uialert(obj.Fig, "Could not open the analysis config:" + newline + string(ME.message), "Open config");
    return
end
obj.SelectedFigure = min(1, numel(cfg.Figures));
obj.applyConfig(cfg, MarkSaved=true);
obj.addRecentConfig(file);
obj.savePreferences();
msg = "Opened " + string(file);
if ~isempty(cfg.LoadWarnings); msg = msg + " (" + strjoin(cfg.LoadWarnings, "; ") + ")"; end
obj.setStatus(msg);
for w = cfg.LoadWarnings
    obj.log("Open " + string(file) + ": " + w);   % a version-1 config's migration notes stay in the Log tab after a scan
end
S = cfg.Source;
if (S.Mode == "project" && S.Root ~= "" && isfolder(S.Root)) || (S.Mode == "folders" && ~isempty(S.Folders) && all(isfolder(S.Folders)))
    obj.onScan();
end
ok = true;
end
