function applyConfig(obj, cfg, opts)
%applyConfig  Show a config in every control (MarkSaved=true: it is the saved state).
%   With MarkSaved (a config opened or made new) the keys the last config
%   kept in its selection though the datasets listed lack them are
%   forgotten (TickedNotListed: tickConfigSelection), the Figures tab's drawings
%   of the last config are dropped, every figure's container and the
%   editor states the figures left with them (clearFigureViews), and the
%   preview marked Out of date (autoFigurePreview then draws the new
%   config's figure when it can), and the undo history is cleared. Action=LABEL (the figure list's edits:
%   "Add figure", "Remove figure") records the change of the figures as a
%   step of the undo history (recordFigureEdit); without it (Undo and Redo
%   themselves, onUndoRedo) nothing is recorded. The Data tab's scan line
%   says whether the datasets listed are the scan of the config's source
%   (showScanLabel: what scannedSource reads, so a config that differs only
%   in its ticks or filter asks for no scan). It is all or nothing: when a
%   control cannot show a value (it throws), the controls and the config
%   the app holds go back to what they were, and so do the undo history
%   (an Action's step is taken back; a config opened does not clear it),
%   the panels Shift+click selected and the figure ids followed
%   (trackFigureIds); a config opened drops the figures' kept previews
%   only once it shows, so they are kept too. The Log says so and the
%   error goes on, so a Save does not write half of each config.
arguments
    obj (1,1) EphysFigGenApp
    cfg (1,1) EphysAnalysisConfig
    opts.MarkSaved (1,1) logical = false
    opts.Action (1,1) string = ""
end
obj.Applying = true;
restore = onCleanup(@() setApplying(obj, false));
prev = obj.Config;   % what a control that cannot show CFG goes back to, as it is before anything below changes
history = obj.FigureHistory;   % (a value: a copy)
extra = obj.FigurePanelExtra;
extraOf = obj.FigurePanelIds;
unlisted = obj.TickedNotListed;   % (a config opened forgets them; given back if it cannot show)
if ~opts.MarkSaved; trackFigureIds(obj, cfg); end   % an edit: an automatic figure id may follow it
drawn = ~ismember(obj.FigurePreviewState, ["idle" "computing" "drawing"]);   % a preview of the last config shows
busy = ismember(obj.FigurePreviewState, ["computing" "drawing"]);
if opts.MarkSaved
    obj.FigurePanelExtra = strings(1, 0);   % another config's figures: the primary panel alone, whatever the ids
    obj.TickedNotListed = string.empty(1, 0);   % another config: the keys the last one kept are not its (tickConfigSelection sets its own)
    obj.FigureHistory = obj.FigureHistory.clear();   % another config: its edits start here
    refreshEditMenu(obj);
elseif opts.Action ~= ""
    recordFigureEdit(obj, cfg, opts.Action);
end
try
    pushConfig(obj, cfg);
catch ME   % all or nothing: a control that cannot show a value must not leave the controls (what Save gathers) half one config, half another
    try
        if ~opts.MarkSaved; trackFigureIds(obj, prev); end   % the ids followed back
        obj.FigureHistory = history;   % (an Action's step taken back; a config opened: its edits as they were)
        obj.FigurePanelExtra = extra;
        obj.FigurePanelIds = extraOf;   % (so the editor shown again keeps the Shift+click panels)
        obj.TickedNotListed = unlisted;
        refreshEditMenu(obj);
        pushConfig(obj, prev);   % the controls as they were, the config the app holds with them
    catch
    end
    obj.log("Could not show the config: " + string(ME.message) + " The window keeps the config it had.");
    rethrow(ME);
end
if opts.MarkSaved && ~busy
    clearFigureViews(obj);   % the last config's containers and editor states (ids may repeat), once this one shows
    obj.syncFigureView();    % the selected figure's own container, new
end
if opts.MarkSaved
    obj.SavedConfigStruct = cfg.toStruct();
end
clear restore
if ~isempty(obj.Runner)
    obj.Runner.Config = cfg;   % a run going on keeps the config it started with (EphysAnalysisRunner.run)
    showScanLabel(obj, cfg.Source);   % what a scan reads (scannedSource): not the ticks, the filter or the signals' rates and filters
end
obj.refreshFigureObservations();
if opts.MarkSaved && drawn && ~ismember(obj.FigurePreviewState, ["computing" "drawing"])
    forgetFigurePreview(obj);   % another config: its figure is not the one drawn (its container says so)
end
if obj.SelectedFigure < 1 && ~ismember(obj.FigurePreviewState, ["idle" "computing" "drawing"])
    obj.refreshFigurePreview();   % no figure left to show: the preview empties
elseif opts.MarkSaved && obj.SelectedFigure >= 1
    obj.autoFigurePreview();
end
obj.refreshAlignPreview();
obj.refreshEpochDiagram();
obj.updateTitle();
end


function pushConfig(obj, cfg)
%pushConfig  Make CFG the app's config and show it in the Data, Export, Report and Figures tabs' controls (applyConfig's all-or-nothing part).
ratesBefore = sourceRates(obj.Config.Source);
obj.Config = cfg;
obj.ConfigNameField.Value = char(cfg.Name);
obj.ConfigDescField.Value = char(cfg.Description);
obj.applySourceSection(cfg.Source);
if ~isequaln(ratesBefore, sourceRates(cfg.Source)) && ~isempty(obj.Runner) && obj.ActiveIdx >= 1
    obj.refreshDatasetInfo();   % the active dataset's signals: the rate the figures read each at
end
D = cfg.Defaults;
obj.applyAlignControls(obj.AlignControls, D.EventRef, D.Window, D.Selection);
obj.applyExportSection(cfg.Export);
obj.applyReportSection(cfg.Report);
nf = numel(cfg.Figures);
if nf == 0
    obj.SelectedFigure = 0;
else
    obj.SelectedFigure = min(max(obj.SelectedFigure, 1), nf);
end
obj.refreshFigureList();
obj.applyFigureEditor();
end


function setApplying(obj, tf)
if isvalid(obj); obj.Applying = tf; end
end


function forgetFigurePreview(obj)
%forgetFigurePreview  Drop the Figures tab's drawing of the last config: its result, its look editor; Out of date.
%   (The shown container is the new config's figure's, clearFigureViews having dropped the others.)
obj.FigurePreviewResult = [];
obj.FigurePreviewDrawn = [];
obj.FigurePreviewSeconds = 0;
P = obj.FigurePreviewPanel;
delete(P.Children);
if isappdata(P, PlotAesthetics.ContextKey); rmappdata(P, PlotAesthetics.ContextKey); end   % its right-click editor drew the old figure
g = uigridlayout(P, [1 1]);
msg = "Another config is open: press Preview to draw its figure.";
uilabel(g, "Text", msg, "WordWrap", "on", "HorizontalAlignment", "center", "FontColor", [0.4 0.4 0.4]);
obj.FigurePreviewLabel.Text = msg;
obj.setFigurePreviewState("stale");
end
