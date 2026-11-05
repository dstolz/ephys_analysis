function commitFigureEdit(obj, cfg, msg, opts)
%commitFigureEdit  Take CFG, changed in the selected figure's arrangement, a panel or its layers, and show it.
%   The structural edits of the Figures tab (a panel added, removed,
%   reordered or of another type; a layer added, removed or moved) change the gathered
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
%   Key=KEY (any value, [] by default) makes a burst of edits with one
%   key, within a second, one step (recordFigureEdit: the arrow keys'
%   nudges of a panel, Key "arrangeKeys:move" or "arrangeKeys:resize").
%   Arrange=true (a panel placed in Arrange: a drag released, an arrow
%   key, Set corners): the preview is laid out at the new rects whatever
%   Auto and the time gate say, and drawn again only when it must and may
%   (arrangedPreview) in place of autoFigurePreview.
%   The preview settles first, before the editor is refilled: with Auto
%   on, the figure is drawn from the runner's cache with no busy card,
%   the panels an edit left alone kept (quickFigurePreview) -- when the
%   redraw fits under the Auto slider's limit (previewCost under
%   autoRedrawLimit), or whatever the limit when the edit only removed
%   or reordered panels and every panel left is kept (KeptOnly). When it
%   draws nothing (a step not in the cache, a panel to draw, Auto off),
%   the preview goes on as before (autoFigurePreview: the busy card, or
%   Out of date). A panel removed or reordered was shown on the preview
%   before (paintEditFirst, by the caller).
%   From its start through the editor's refill (applyFigureEditor) it
%   runs under Applying (restored after), so no callback a paint lets run
%   reads the editor back into the config before the editor shows it.
arguments
    obj (1,1) EphysFigGenApp
    cfg (1,1) EphysAnalysisConfig
    msg (1,1) string
    opts.Action (1,1) string = "Edit"
    opts.Key = []
    opts.Arrange (1,1) logical = false
end
wasApplying = obj.Applying;
obj.Applying = true;
guard = onCleanup(@() setApplying(obj, wasApplying));   % (applyFigureEditor nests its own, which leaves it set)
k = obj.SelectedFigure;
if k >= 1 && k <= numel(cfg.Figures) && numel(cfg.Figures) == numel(obj.Config.Figures) ...   % the same figures (an automatic id may differ)
        && cfg.Figures(k).observe.data == "dataset" && EphysAnalysisConfig.followedData(obj.Config.Figures(k)) == "dataset"
    d = EphysAnalysisConfig.followedData(cfg.Figures(k));
    if d ~= "dataset"
        cfg.Figures(k).observe.data = heldObserveData(obj, d);
        msg = strtrim(msg + " It now observes " + cfg.Figures(k).observe.data + ".");
    end
end
kept = keepsPanels(obj.Config, cfg, k);   % panels removed or reordered, nothing else: every panel left may be kept
trackFigureIds(obj, cfg);   % an automatic id that follows the edit
recordFigureEdit(obj, cfg, opts.Action, Key=opts.Key);
obj.Config = cfg;
if ~isempty(obj.Runner); obj.Runner.Config = cfg; end
drew = false;
if ~opts.Arrange
    limit = autoRedrawLimit(obj);
    auto = ~isempty(obj.Tabs) && obj.Tabs.SelectedTab == obj.TabFigures && limit > 0;
    if auto
        open = previewCost(obj) < limit;
        if open || kept; drew = quickFigurePreview(obj, KeptOnly=~open); end   % no busy card: from the cache, the panels left alone kept
    end
end
obj.refreshFigureList();
obj.applyFigureEditor();
obj.refreshFigureObservations();
obj.refreshEpochDiagram();
clear guard   % the editor shows the config now: its callbacks may run (the status bar's paint, a busy preview's polls)
if msg ~= ""; obj.setStatus(msg); end
if drew
    markFigureTree(obj);
elseif opts.Arrange
    arrangedPreview(obj, msg);
else
    obj.autoFigurePreview();
end
obj.updateTitle();
end


function tf = keepsPanels(old, new, k)
%keepsPanels  Figure K of NEW is OLD's with panels removed or reordered, nothing else (its id aside: an automatic one follows), and as many figures are there.
tf = false;
if k < 1 || k > numel(new.Figures) || numel(new.Figures) ~= numel(old.Figures); return; end
a = new.Figures(k);
b = old.Figures(k);
if isempty(a.panels) || isempty(b.panels); return; end
[in, at] = ismember([a.panels.id], [b.panels.id]);
if ~all(in) || ~isequaln(a.panels, b.panels(at)); return; end   % each panel left as it was
drop = intersect({'panels' 'id'}, fieldnames(a));
tf = isequaln(rmfield(a, drop), rmfield(b, drop));
end


function setApplying(obj, tf)
if isvalid(obj); obj.Applying = tf; end
end
