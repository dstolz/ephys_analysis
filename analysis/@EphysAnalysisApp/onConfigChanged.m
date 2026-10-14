function onConfigChanged(obj, what)
%onConfigChanged  A control changed: re-gather the config and refresh what depends on it.
%   WHAT says which part changed: "name", "source", "ticks", "defaults"
%   (the Alignment tab), "plot" (the plot editor), "sessions" (the session
%   plot editor) or "export". The runner gets the new config; the
%   Alignment count, the plot list, the epoch diagram (when open) and the
%   preview (auto-preview) follow. The Sessions tab's preview
%   (autoSessionPreview: redrawn, or marked out of date) follows an edit of
%   the session plot, of its base plot, of the defaults, and of the ticks
%   when it draws the ticked datasets; its list and editor follow the plots.
%   "figure" (the Figures tab's editor): its list, editor and schematic,
%   the observation picker (made again when the observe block, the
%   figure's alignment or its sorting changed), the epoch diagram and the
%   figure preview (autoFigurePreview) follow; an edit of the defaults
%   reaches the figure editor and its preview too.
arguments
    obj (1,1) EphysAnalysisApp
    what (1,1) string = ""
end
if obj.Applying; return; end
try
    cfg = obj.gatherConfig();
catch ME
    obj.setStatus("Config: " + string(ME.message));
    return
end
obj.Config = cfg;
if ~isempty(obj.Runner)
    obj.Runner.Config = cfg;
end
k = obj.SelectedPlot;
if k >= 1 && k <= numel(cfg.Plots)
    obj.ShownPlot = cfg.Plots(k);   % what the editor shows now: the next edit's "before"
end
switch what
    case "source"
        obj.syncSourceEnable();
        if ~isempty(obj.Runner) && ~isempty(fieldnames(obj.ScannedSource)) && ~isequaln(rmfield(cfg.Source, {'Selection', 'Datasets'}), ...
                rmfield(obj.ScannedSource, {'Selection', 'Datasets'}))
            obj.ScanLabel.Text = "The source changed: Scan to list its datasets.";
        end
    case "defaults"
        syncAlignEnable(obj.AlignControls);
        obj.refreshAlignPreview();
        obj.applyPlotEditorDefaults();
        obj.applyFigureEditorDefaults();
        obj.refreshFigureObservations();
        obj.refreshEpochDiagram();
        obj.autoPreview();
        obj.autoSessionPreview();
        obj.autoFigurePreview();
    case "figure"
        obj.refreshFigureList();
        obj.syncFigureEditor();
        obj.refreshFigureObservations();   % again only when its observe block, alignment or sorting changed
        obj.refreshEpochDiagram();
        obj.autoFigurePreview();
    case "plot"
        obj.refreshPlotList();
        obj.syncPlotEditor();
        obj.refreshEpochDiagram();
        obj.autoPreview();
        obj.refreshSessionList();   % a plot's id or kind: the base plots offered
        obj.syncSessionEditor();
        j = obj.SelectedSessionPlot;
        ks = obj.selectedPlots();
        if j >= 1 && j <= numel(cfg.SessionPlots) && ~isempty(ks) && (any([cfg.Plots(ks).id] == cfg.SessionPlots(j).plot) ...
                || cfg.plotIndex(cfg.SessionPlots(j).plot) == 0)
            obj.autoSessionPreview();   % its base plot changed (or was renamed away)
        end
    case "ticks"
        obj.syncSessionEditor();   % the sessions it covers
        j = obj.SelectedSessionPlot;
        if j >= 1 && j <= numel(cfg.SessionPlots) && cfg.SessionPlots(j).datasets == "ticked"
            obj.autoSessionPreview();
        end
    case "sessions"
        obj.refreshSessionList();
        obj.syncSessionEditor();
        obj.autoSessionPreview();
end
obj.updateTitle();
end
