function onRemoveFigure(obj)
%onRemoveFigure  Remove the selected figure; the one taking its place is selected and previewed.
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
cfg = obj.gatherConfig();
id = cfg.Figures(k).id;
cfg = cfg.removeFigure(id);
if isKey(obj.FigureObservation, char(id)); remove(obj.FigureObservation, char(id)); end
obj.SelectedFigure = min(k, numel(cfg.Figures));
obj.SelectedPanel = 1;
obj.SelectedLayer = 1;
obj.applyConfig(cfg);
obj.FigurePreviewResult = [];
obj.FigurePreviewSeconds = 0;
obj.setStatus("Removed " + id + ".");
if obj.SelectedFigure < 1
    obj.refreshFigurePreview();   % nothing to draw: the panel and the badge say so
else
    obj.autoFigurePreview();
end
end
