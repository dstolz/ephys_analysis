function commitFigureEdit(obj, cfg, msg, opts)
%commitFigureEdit  Take CFG, changed in the selected figure's arrangement, a panel or its layers, and show it.
%   The structural edits of the Figures tab (a panel added, removed, moved
%   or of another type; a layer added, removed or moved) change the gathered
%   config and come here: the runner gets it, the list, the editor (the
%   panel and layer selected: SelectedPanel, SelectedLayer), the
%   observation picker and the epoch diagram follow, the status bar says
%   MSG, and the preview is redrawn (Auto) or marked out of date.
%   A figure observing the dataset whose edit gives it its first layer
%   that follows the observation (a panel added to a blank figure, a
%   heat map made a PSTH) observes what that layer reads from then on
%   (EphysAnalysisConfig.followedData, held by the active dataset:
%   heldObserveData), since a following layer has nothing to follow in
%   a dataset figure; an Observe choice of the dataset made while layers
%   already follow is kept. An automatic figure id follows the edit
%   (EphysAnalysisConfig.autoFigureId); trackFigureIds notes the rename.
%   Action=LABEL names the edit in the undo history (recordFigureEdit:
%   "Add panel", the Edit menu's "Undo Add panel"); "Edit" by default.
arguments
    obj (1,1) EphysAnalysisApp
    cfg (1,1) EphysAnalysisConfig
    msg (1,1) string
    opts.Action (1,1) string = "Edit"
end
k = obj.SelectedFigure;
if k >= 1 && k <= numel(cfg.Figures) && numel(cfg.Figures) == numel(obj.Config.Figures) ...   % the same figures (an automatic id may differ)
        && cfg.Figures(k).observe.data == "dataset" && EphysAnalysisConfig.followedData(obj.Config.Figures(k)) == "dataset"
    d = EphysAnalysisConfig.followedData(cfg.Figures(k));
    if d ~= "dataset"
        cfg.Figures(k).observe.data = heldObserveData(obj, d);
        msg = strtrim(msg + " It now observes " + cfg.Figures(k).observe.data + ".");
    end
end
trackFigureIds(obj, cfg);   % an automatic id that follows the edit
recordFigureEdit(obj, cfg, opts.Action);
obj.Config = cfg;
if ~isempty(obj.Runner); obj.Runner.Config = cfg; end
obj.refreshFigureList();
obj.applyFigureEditor();
obj.refreshFigureObservations();
obj.refreshEpochDiagram();
if msg ~= ""; obj.setStatus(msg); end
obj.autoFigurePreview();
obj.updateTitle();
end
