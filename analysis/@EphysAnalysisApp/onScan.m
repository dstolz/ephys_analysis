function onScan(obj)
%onScan  Find the datasets (a new EphysAnalysisRunner) and list them.
%   In project mode every dataset under the root is listed and the config's
%   "list" selection only sets the Run ticks. The first ticked dataset
%   becomes the active one.
cfg = obj.gatherConfig();
scanCfg = cfg;
scanCfg.Source.Selection = "all";
obj.setStatus("Scanning ...");
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
obj.ScannedSource = cfg.Source;
n = numel(r.Keys);
if cfg.Source.Mode == "project" && cfg.Source.Selection == "list"
    obj.Ticked = ismember(r.Keys, EphysProject.normalizeKey(cfg.Source.Datasets));   % as the runner's findByKey
else
    obj.Ticked = true(1, n);
end
obj.ActiveIdx = 0;
obj.PreviewResult = [];
obj.refreshDatasetsTable();
names = r.Names;
if n == 0
    items = "(no datasets)"; data = 0;
else
    items = names; data = 1:n;
end
set([obj.AlignDatasetDropDown obj.PlotsDatasetDropDown], 'Items', items, 'ItemsData', data);
obj.ScanLabel.Text = sprintf("%d dataset(s) found (%s).", n, ternary(cfg.Source.Mode == "project", ...
    "project " + cfg.Source.Root, "output folders"));
obj.log("Scan: " + obj.ScanLabel.Text);
if n > 0
    first = find(obj.Ticked, 1);
    if isempty(first); first = 1; end
    obj.selectDataset(first);
end
obj.setStatus(obj.ScanLabel.Text);
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
