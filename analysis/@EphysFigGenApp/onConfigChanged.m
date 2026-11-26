function onConfigChanged(obj, what, src)
%onConfigChanged  A control changed: re-gather the config and refresh what depends on it.
%   WHAT says which part changed: "name", "source", "ticks", "filter"
%   (the Data tab's filter: Source.Filter, its table already filtered),
%   "downsample" (Source.Downsample, set by onDownsample: the Signals row
%   says it and the preview follows; no scan needed), "signalfilter"
%   (Source.SignalFilter, set by onSignalFilter: the Filters row says it
%   and the preview follows; no scan needed), "defaults"
%   (the Alignment tab), "figure" (the Figures tab's editor), "figuresize"
%   (its Size rows: a "figure" edit that changes how the figure is drawn,
%   not what it is computed from) or "export" (the Layout section's
%   lengths shown again on the new page: showPanelPlace).
%   The runner gets the new config, also while a run goes (the window
%   stays usable): that run keeps the config it started with
%   (EphysAnalysisRunner.run), the edit is the next run's. "source": the
%   Data tab's scan line says when the datasets listed are another
%   source's (showScanLabel, scannedSource: what a scan reads; the ticks,
%   the filter and the signals' rates and filters are no change of the
%   source), and back to the scan's own line when the source is the one
%   scanned again. "defaults": the Alignment count, the
%   figure editor's rows that show the defaults (applyFigureEditorDefaults),
%   the observation picker, the epoch diagram (when open) and the figure
%   preview (autoFigurePreview) follow. "figure": its list and editor
%   (the Layout section's values kept on the page: showPanelPlace), the
%   observation picker (made again when the observe block,
%   the figure's alignment or its sorting changed), the epoch diagram and
%   the figure preview follow, and the Id row shows the figure's id (an
%   automatic one follows the edit: trackFigureIds, showFigureId). A
%   "figuresize" edit is that too, but a drawn preview that was current is
%   shaped like the new page (fitFigureViews) and drawn again from the
%   figure it holds (redrawFigurePreview), not computed again; "export"
%   shapes the previews to the Export tab's page, and when the selected
%   figure's page changed (it follows the Export tab's Width and Height,
%   or its own size is in px and the Dpi changed: figurePage) its preview
%   is drawn again on the new page in the same way when it was current (a
%   figure across sessions from its kept figures), else as after any edit;
%   the other figures' kept previews, laid out on the old page, are out of
%   date (figureViewKey's page; the tree marks them). "ticks" (a Run tick on the Data tab: the
%   config's Selection and Datasets in either mode, gatherSourceSection): the
%   Alignment and Figures tabs' Dataset drop-downs list the datasets ticked
%   now (refreshDatasetLabels); when the figure in the editor is a session figure drawn across the ticked
%   datasets, its observations are matched again and its preview, drawn
%   over the old datasets, is forgotten and marked out of date
%   (autoFigurePreview).
%   A "figure" edit that changes the figures is a step of the undo history
%   (recordFigureEdit), named after the control SRC it came from (the
%   editor's controls pass themselves, else a string names the step, else
%   the callback object, gcbo: figureEditLabel), its edits in a burst one
%   step. With several panels selected (Shift+click) the edit of the
%   panel shown goes to the others too (spreadPanelEdit: those whose type
%   takes it), in the same step ("Stack (3 panels)"), and the status bar
%   says where it went. Made with Ctrl (Cmd) held (CtrlHeld: onKeyPress), an editor
%   control's edit also opens Apply to figures (onApplyToFigures: the
%   other figures and panels that can take it) and the preview waits for
%   its answer instead of redrawing.
%   Any edit takes the arrow keys back from Arrange's overlay
%   (FigureArrangeFocus: a field typed in after a drag keeps its arrows).
arguments
    obj (1,1) EphysFigGenApp
    what (1,1) string = ""
    src = []
end
if obj.Applying; return; end
obj.FigureArrangeFocus = false;
try
    cfg = obj.gatherConfig();
catch ME
    obj.setStatus("Config: " + string(ME.message));
    return
end
spread = false;
shared = "";
if what == "figure" || what == "figuresize"
    if isempty(src); src = gcbo; end
    spread = obj.CtrlHeld && ~isempty(src) && ~isstring(src) && ~ischar(src);   % an editor control used with Ctrl down
    before = obj.Config.Figures;
    [cfg, label, shared] = spreadPanelEdit(obj, cfg, figureEditLabel(obj, src));   % several panels selected: to all of them
    trackFigureIds(obj, cfg);   % an automatic figure id that follows the edit
    recordFigureEdit(obj, cfg, label, Key=src);
else
    trackFigureIds(obj, cfg);
end
fresh = ismember(what, ["figuresize" "export"]) && figureViewFresh(obj);   % the preview drawn is the figure as it was: only its page changes
page0 = [];
if what == "export"; page0 = figurePage(obj); end   % the selected figure's page before (the Export tab's, unless it has its own)
obj.Config = cfg;
if ~isempty(obj.Runner)
    obj.Runner.Config = cfg;
end
switch what
    case "source"
        obj.syncSourceEnable();
        showScanLabel(obj, cfg.Source);   % "The source changed: ..." while the datasets listed are another source's (scannedSource)
    case "downsample"
        obj.showDownsample();
        obj.refreshDatasetInfo();   % the active dataset's signals: the rate the figures read each at
        obj.autoFigurePreview();   % the figures that read a signal whose rate changed compute again (figureFor's layer rates)
    case "signalfilter"
        obj.showSignalFilter();
        obj.autoFigurePreview();   % the figures that read a signal whose filter changed compute again (figureFor's layer filters)
    case "defaults"
        AlignControls.syncEnable(obj.AlignControls);
        obj.refreshAlignPreview();
        obj.applyFigureEditorDefaults();
        obj.refreshFigureObservations();
        obj.refreshEpochDiagram();
        obj.autoFigurePreview();
    case {"figure" "figuresize"}
        showFigureId(obj);   % an automatic id follows the panels and data
        obj.refreshFigureList();
        obj.syncFigureEditor();
        if shared ~= ""; obj.setStatus(shared); end   % where an edit of several panels went
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
        showPanelPlace(obj);   % a rect in cm, in or px is a length on that page
        k = obj.SelectedFigure;
        if k >= 1 && k <= numel(cfg.Figures) && ~isequal(figurePage(obj), page0)   % its drawing was laid out and scaled on the old page
            if ~(fresh && obj.redrawFigurePreview(Page=true)); obj.autoFigurePreview(); end   % drawn again from what it holds, else as after any edit
        end
        markFigureTree(obj);   % the kept previews of the other figures that follow the page: out of date
    case "ticks"
        refreshDatasetLabels(obj);   % the Dataset drop-downs list the ticked datasets
        k = obj.SelectedFigure;
        if k >= 1 && k <= numel(cfg.Figures) && cfg.Figures(k).sessions.enabled && cfg.Figures(k).sessions.datasets == "ticked"
            obj.refreshFigureObservations();   % matched across the datasets ticked now
            obj.autoFigurePreview();           % forgets the kept figures: the drawing is out of date
        end
end
obj.updateTitle();
end
