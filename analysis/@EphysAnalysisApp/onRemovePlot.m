function onRemovePlot(obj)
%onRemovePlot  Remove the selected plots (every one picked in the tree).
%   The plot that takes the first one's place is selected next.
ks = obj.selectedPlots();
if isempty(ks); return; end
cfg = obj.gatherConfig();
ids = [cfg.Plots(ks).id];
for id = ids
    cfg = cfg.removePlot(id);
end
obj.SelectedPlot = min(min(ks), numel(cfg.Plots));
obj.applyConfig(cfg);
if isscalar(ids)
    obj.setStatus("Removed plot " + ids + ".");
else
    obj.setStatus(sprintf("Removed %d plots: %s.", numel(ids), strjoin(ids, ", ")));
end
obj.PreviewSeconds = 0;
obj.autoPreview();
end
