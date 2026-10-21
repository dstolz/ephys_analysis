function onConfigChanged(obj, what, src)
%onConfigChanged  A control changed: re-gather the config and refresh what depends on it.
%   WHAT says which part changed: "name", "source", "ticks", "defaults"
%   (the Alignment tab), "figure" (the Figures tab's editor) or "export".
%   The runner gets the new config. "defaults": the Alignment count, the
%   figure editor's rows that show the defaults (applyFigureEditorDefaults),
%   the observation picker, the epoch diagram (when open) and the figure
%   preview (autoFigurePreview) follow. "figure": its list, editor and
%   schematic, the observation picker (made again when the observe block,
%   the figure's alignment or its sorting changed), the epoch diagram and
%   the figure preview follow, and the Id row shows the figure's id (an
%   automatic one follows the edit: trackFigureIds, showFigureId). "ticks" (a Run tick on the Data tab): when
%   the figure in the editor is a session figure drawn across the ticked
%   datasets, its observations are matched again and its preview, drawn
%   over the old datasets, is forgotten and marked out of date
%   (autoFigurePreview).
%   A "figure" edit that changes the figures is a step of the undo history
%   (recordFigureEdit), named after the control SRC it came from (the
%   editor's controls pass themselves, else a string names the step, else
%   the callback object, gcbo: figureEditLabel), its edits in a burst one
%   step.
arguments
    obj (1,1) EphysAnalysisApp
    what (1,1) string = ""
    src = []
end
if obj.Applying; return; end
try
    cfg = obj.gatherConfig();
catch ME
    obj.setStatus("Config: " + string(ME.message));
    return
end
trackFigureIds(obj, cfg);   % an automatic figure id that follows the edit
if what == "figure"
    if isempty(src); src = gcbo; end
    recordFigureEdit(obj, cfg, figureEditLabel(obj, src), Key=src);
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
        showFigureId(obj);   % an automatic id follows the panels and data
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
