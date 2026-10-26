function onScan(obj)
%onScan  Find the datasets (a new EphysAnalysisRunner) and list them.
%   In project mode every dataset under the root is listed and the config's
%   "list" selection only sets the Run ticks. The first ticked dataset
%   becomes the active one -- unless a ticked dataset has a starred unit:
%   the first such unit is gone to (goToFavorite: its dataset is active and
%   the unit is picked in the Figures tab's observation list). The Figures tab's preview (a session figure's
%   too) and observation list are forgotten. Each dataset's stars and
%   notes are read (loadFavorites, loadNotes) and shown (refreshFavorites,
%   refreshNotes). While the app starts the scan and the first dataset's
%   loading are steps on the splash; later a modal progress dialog shows the
%   scan (dataset i/n, time left; Cancel stops it before the datasets are
%   listed) and then the favorites, the notes and the first dataset.
cfg = obj.gatherConfig();
scanCfg = cfg;
scanCfg.Source.Selection = "all";
obj.setStatus("Scanning " + ternary(cfg.Source.Mode == "project", cfg.Source.Root, "the output folders") + " for datasets ...");
obj.Splash.step("scan", "Scanning the datasets ...");
if ~obj.Splash.isActive(); drawnow; end   % the hidden window is laid out once, when it shows (setStatus)
dlg = [];
if ~obj.Splash.isActive()
    dlg = uiprogressdlg(obj.Fig, "Title", "Scanning for datasets", "Indeterminate", "on", "Cancelable", "on", ...
        "Message", "Looking for datasets in " + ternary(cfg.Source.Mode == "project", string(cfg.Source.Root), "the output folders") + " ...");
end
clock = ProgressClock();
cleanup = onCleanup(@() closeDialog(dlg));   % closed on every way out, an error too
try
    r = EphysAnalysisRunner(scanCfg, LogFcn=@(m) obj.log(m), ProgressFcn=@(f, m) scanProgress(dlg, clock, f, m));
catch ME
    if ME.identifier == "EphysAnalysisRunner:Canceled"
        obj.setStatus("Scan canceled.");
        return
    end
    obj.ScanLabel.Text = "Scan failed: " + string(ME.message);
    obj.setStatus("Scan failed: " + string(ME.message));
    return
end
r.ProgressFcn = [];   % the dialog is for the scan only (a run sets its own)
setDialog(dlg, "Message", "Reading favorites and notes ...");
r.Config = cfg;
obj.Runner = r;
loadFavorites(obj);   % each dataset's <Name>_favorites.json
loadNotes(obj);       % and <Name>_notes.json
obj.FigureObservationDropDown.UserData = [];   % the Figures tab's observation list is made again on the new runner's sources
forgetFigurePickers(obj);   % and each figure's kept one
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
obj.FigurePreviewGeneration = obj.FigurePreviewGeneration + 1;   % every figure's kept preview is out of date (figureViewKey)
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
obj.refreshNotes();
obj.ScanLabel.Text = sprintf("%d dataset(s) found (%s).", n, ternary(cfg.Source.Mode == "project", ...
    "project " + cfg.Source.Root, "output folders"));
obj.log("Scan: " + obj.ScanLabel.Text);
if n > 0
    E = obj.FavoriteEntries;
    fav = 0;
    if istable(E)
        fav = find(E.level == "unit" & ismember(E.dataset, find(obj.Ticked)), 1);   % a starred unit of a ticked dataset first
        if isempty(fav); fav = 0; end
    end
    if fav > 0
        obj.Splash.step("dataset", "Loading " + names(E.dataset(fav)) + " ...");
        setDialog(dlg, "Message", "Opening " + names(E.dataset(fav)) + " ...");
        goToFavorite(obj, E(fav, :));
    else
        first = find(obj.Ticked, 1);
        if isempty(first); first = 1; end
        obj.Splash.step("dataset", "Loading " + names(first) + " ...");
        setDialog(dlg, "Message", "Opening " + names(first) + " ...");
        obj.selectDataset(first);
    end
end
obj.setStatus(obj.ScanLabel.Text);
end


function scanProgress(dlg, clock, fraction, message)
%scanProgress  The runner's report while it reads the datasets: the dialog shows it; Cancel stops the scan.
if isempty(dlg) || ~isvalid(dlg); return; end
dlg.Indeterminate = "off";
dlg.Value = min(max(fraction, 0), 1);
dlg.Message = char(clock.message(message, fraction));
drawnow limitrate;
if dlg.CancelRequested
    error('EphysAnalysisRunner:Canceled', 'The scan was canceled.');
end
end


function setDialog(dlg, varargin)
%setDialog  Set properties of the scan dialog (none while the splash shows) and draw it.
if isempty(dlg) || ~isvalid(dlg); return; end
set(dlg, varargin{:});
dlg.Indeterminate = "on";   % the steps after the scan have no count
drawnow limitrate;
end


function closeDialog(dlg)
if ~isempty(dlg) && isvalid(dlg); close(dlg); end
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
