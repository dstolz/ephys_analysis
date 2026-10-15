function onConfigChanged(obj, what)
%onConfigChanged  A control changed: re-gather the config and refresh what depends on it.
%   WHAT says which part changed: "name", "source", "ticks", "defaults"
%   (the Alignment tab), "figure" (the Figures tab's editor) or "export".
%   The runner gets the new config. "defaults": the Alignment count, the
%   figure editor's rows that show the defaults (applyFigureEditorDefaults),
%   the observation picker, the epoch diagram (when open) and the figure
%   preview (autoFigurePreview) follow. "figure": its list, editor and
%   schematic, the observation picker (made again when the observe block,
%   the figure's alignment or its sorting changed), the epoch diagram and
%   the figure preview follow. "ticks" (a Run tick on the Data tab): when
%   the figure in the editor is a session figure drawn across the ticked
%   datasets, its observations are matched again and its preview, drawn
%   over the old datasets, is forgotten and marked out of date
%   (autoFigurePreview).
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
        obj.applyFigureEditorDefaults();
        obj.refreshFigureObservations();
        obj.refreshEpochDiagram();
        obj.autoFigurePreview();
    case "figure"
        obj.refreshFigureList();
        obj.syncFigureEditor();
        obj.refreshFigureObservations();   % again only when its observe block, alignment or sorting changed
        obj.refreshEpochDiagram();
        obj.autoFigurePreview();
    case "ticks"
        k = obj.SelectedFigure;
        if k >= 1 && k <= numel(cfg.Figures) && cfg.Figures(k).sessions.enabled && cfg.Figures(k).sessions.datasets == "ticked"
            obj.refreshFigureObservations();   % matched across the datasets ticked now
            obj.autoFigurePreview();           % forgets the kept figures: the drawing is out of date
        end
end
obj.updateTitle();
end
