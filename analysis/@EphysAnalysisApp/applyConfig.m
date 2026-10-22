function applyConfig(obj, cfg, opts)
%applyConfig  Show a config in every control (MarkSaved=true: it is the saved state).
%   With MarkSaved (a config opened or made new) the Figures tab's drawings
%   of the last config are dropped, every figure's container and the
%   editor states the figures left with them (clearFigureViews), and the
%   preview marked Out of date (autoFigurePreview then draws the new
%   config's figure when it can), and the undo history is cleared. Action=LABEL (the figure list's edits:
%   "Add figure", "Remove figure") records the change of the figures as a
%   step of the undo history (recordFigureEdit); without it (Undo and Redo
%   themselves, onUndoRedo) nothing is recorded.
arguments
    obj (1,1) EphysAnalysisApp
    cfg (1,1) EphysAnalysisConfig
    opts.MarkSaved (1,1) logical = false
    opts.Action (1,1) string = ""
end
obj.Applying = true;
restore = onCleanup(@() setApplying(obj, false));
if ~opts.MarkSaved; trackFigureIds(obj, cfg); end   % an edit: an automatic figure id may follow it
drawn = ~ismember(obj.FigurePreviewState, ["idle" "computing" "drawing"]);   % a preview of the last config shows
if opts.MarkSaved
    obj.FigureHistory = obj.FigureHistory.clear();   % another config: its edits start here
    refreshEditMenu(obj);
    if ~ismember(obj.FigurePreviewState, ["computing" "drawing"]); clearFigureViews(obj); end   % its figures' containers and editor states (ids may repeat)
elseif opts.Action ~= ""
    recordFigureEdit(obj, cfg, opts.Action);
end
obj.Config = cfg;
obj.ConfigNameField.Value = char(cfg.Name);
obj.ConfigDescField.Value = char(cfg.Description);
obj.applySourceSection(cfg.Source);
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
if opts.MarkSaved
    obj.SavedConfigStruct = cfg.toStruct();
end
clear restore
if ~isempty(obj.Runner)
    obj.Runner.Config = cfg;
    if ~isequaln(cfg.Source, obj.ScannedSource)
        obj.ScanLabel.Text = "The source changed: Scan to list its datasets.";
    end
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
