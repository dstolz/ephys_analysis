function onConfigChanged(obj, what, src)
%onConfigChanged  A control changed: re-gather the config and refresh what depends on it.
%   WHAT says which part changed: "name", "source", "ticks", "defaults"
%   (the Alignment tab), "figure" (the Figures tab's editor), "figuresize"
%   (its Size rows: a "figure" edit that changes how the figure is drawn,
%   not what it is computed from) or "export".
%   The runner gets the new config. "defaults": the Alignment count, the
%   figure editor's rows that show the defaults (applyFigureEditorDefaults),
%   the observation picker, the epoch diagram (when open) and the figure
%   preview (autoFigurePreview) follow. "figure": its list, editor and
%   schematic, the observation picker (made again when the observe block,
%   the figure's alignment or its sorting changed), the epoch diagram and
%   the figure preview follow, and the Id row shows the figure's id (an
%   automatic one follows the edit: trackFigureIds, showFigureId). A
%   "figuresize" edit is that too, but a drawn preview that was current is
%   shaped like the new page (fitFigureViews) and drawn again from the
%   figure it holds (redrawFigurePreview), not computed again; "export"
%   shapes the previews to the Export tab's page. "ticks" (a Run tick on the Data tab): when
%   the figure in the editor is a session figure drawn across the ticked
%   datasets, its observations are matched again and its preview, drawn
%   over the old datasets, is forgotten and marked out of date
%   (autoFigurePreview).
%   A "figure" edit that changes the figures is a step of the undo history
%   (recordFigureEdit), named after the control SRC it came from (the
%   editor's controls pass themselves, else a string names the step, else
%   the callback object, gcbo: figureEditLabel), its edits in a burst one
%   step. Made with Ctrl (Cmd) held (CtrlHeld: onKeyPress), an editor
%   control's edit also opens Apply to figures (onApplyToFigures: the
%   other figures and panels that can take it) and the preview waits for
%   its answer instead of redrawing.
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
spread = false;
if what == "figure" || what == "figuresize"
    if isempty(src); src = gcbo; end
    spread = obj.CtrlHeld && ~isempty(src) && ~isstring(src) && ~ischar(src);   % an editor control used with Ctrl down
    before = obj.Config.Figures;
    recordFigureEdit(obj, cfg, figureEditLabel(obj, src), Key=src);
end
fresh = what == "figuresize" && figureViewFresh(obj);   % the preview drawn is the figure as it was: only its size changes
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
    case {"figure" "figuresize"}
        showFigureId(obj);   % an automatic id follows the panels and data
        obj.refreshFigureList();
        obj.syncFigureEditor();
        obj.refreshFigureObservations();   % again only when its observe block, alignment or sorting changed
        obj.refreshEpochDiagram();
        if what == "figuresize"; obj.fitFigureViews(); end   % the preview takes the new page's shape at once
        if spread
            obj.CtrlHeld = false;   % its release goes to the window that opens, not to the app
            obj.onApplyToFigures(Before=before, Control=src);   % the preview waits for its answer
        elseif what == "figuresize"
            if ~(fresh && obj.redrawFigurePreview()); obj.autoFigurePreview(); end   % drawn again as it is, else as after any edit
        else
            obj.autoFigurePreview();
        end
    case "export"
        obj.fitFigureViews();   % the page the figures are exported on is the Export tab's
        obj.showFigureSize();
    case "ticks"
        k = obj.SelectedFigure;
        if k >= 1 && k <= numel(cfg.Figures) && cfg.Figures(k).sessions.enabled && cfg.Figures(k).sessions.datasets == "ticked"
            obj.refreshFigureObservations();   % matched across the datasets ticked now
            obj.autoFigurePreview();           % forgets the kept figures: the drawing is out of date
        end
end
obj.updateTitle();
end
