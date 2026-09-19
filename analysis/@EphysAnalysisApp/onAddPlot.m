function onAddPlot(obj, kind)
%onAddPlot  Add a plot of KIND (a kind name, or a partial plot struct) and edit it.
cfg = obj.gatherConfig();
[cfg, id] = cfg.addPlot(kind);
obj.SelectedPlot = numel(cfg.Plots);
obj.applyConfig(cfg);
obj.PreviewPage = 1;
obj.PreviewSeconds = 0;
obj.setStatus("Added plot " + id + ".");
obj.autoPreview();
end
