function onScan(obj)
%onScan  Find the datasets (a new EphysAnalysisRunner) and list them.
%   In project mode every dataset under the root is listed and the config's
%   "list" selection only sets the Run ticks. The first ticked dataset
%   becomes the active one. The Figures tab's preview (a session figure's
%   too) and observation list are forgotten. Each dataset's stars are read
%   (loadFavorites) and shown (refreshFavorites). While the app starts the
%   scan and the first dataset's loading are steps on the splash.
cfg = obj.gatherConfig();
scanCfg = cfg;
scanCfg.Source.Selection = "all";
obj.setStatus("Scanning " + ternary(cfg.Source.Mode == "project", cfg.Source.Root, "the output folders") + " for datasets ...");
obj.Splash.step("scan", "Scanning the datasets ...");
drawnow;
try
    r = EphysAnalysisRunner(scanCfg, LogFcn=@(m) obj.log(m));
catch ME
    obj.ScanLabel.Text = "Scan failed: " + string(ME.message);
    obj.setStatus("Scan failed: " + string(ME.message));
    return
end
r.Config = cfg;
obj.Runner = r;
loadFavorites(obj);   % each dataset's <Name>_favorites.json
obj.FigureObservationDropDown.UserData = [];   % the Figures tab's observation list is made again on the new runner's sources
obj.ScannedSource = cfg.Source;
n = numel(r.Keys);
if cfg.Source.Mode == "project" && cfg.Source.Selection == "list"
    obj.Ticked = ismember(r.Keys, EphysProject.normalizeKey(cfg.Source.Datasets));   % as the runner's findByKey
else
    obj.Ticked = true(1, n);
end
obj.ActiveIdx = 0;
obj.FigurePreviewResult = [];
obj.FigureSessionResults = [];   % a session figure's last preview was drawn on the old runner's datasets
obj.refreshDatasetsTable();
names = r.Names;
if n == 0
    items = "(no datasets)"; data = 0;
else
    items = names; data = 1:n;
end
set([obj.AlignDatasetDropDown obj.FiguresDatasetDropDown], 'Items', items, 'ItemsData', data);
refreshDatasetLabels(obj);   % with what each holds of spikes (the units counted when a dataset was opened)
obj.refreshFavorites();
obj.ScanLabel.Text = sprintf("%d dataset(s) found (%s).", n, ternary(cfg.Source.Mode == "project", ...
    "project " + cfg.Source.Root, "output folders"));
obj.log("Scan: " + obj.ScanLabel.Text);
if n > 0
    first = find(obj.Ticked, 1);
    if isempty(first); first = 1; end
    obj.Splash.step("dataset", "Loading " + names(first) + " ...");
    obj.selectDataset(first);
end
obj.setStatus(obj.ScanLabel.Text);
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
