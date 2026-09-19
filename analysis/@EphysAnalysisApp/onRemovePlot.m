function onRemovePlot(obj)
%onRemovePlot  Remove the selected plot.
k = obj.SelectedPlot;
if k < 1; return; end
cfg = obj.gatherConfig();
id = cfg.Plots(k).id;
cfg = cfg.removePlot(id);
obj.SelectedPlot = min(k, numel(cfg.Plots));
obj.applyConfig(cfg);
obj.setStatus("Removed plot " + id + ".");
obj.PreviewSeconds = 0;
obj.autoPreview();
end
