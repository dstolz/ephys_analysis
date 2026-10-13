function onRemoveSessionPlot(obj)
%onRemoveSessionPlot  Remove the selected session plot (its base plot stays); the one taking its place is selected.
k = obj.SelectedSessionPlot;
if k < 1 || k > numel(obj.Config.SessionPlots); return; end
cfg = obj.gatherConfig();
id = cfg.SessionPlots(k).id;
cfg = cfg.removeSessionPlot(id);
obj.SelectedSessionPlot = min(k, numel(cfg.SessionPlots));
obj.applyConfig(cfg);
resetSessionPreview(obj, "Removed session plot " + id + ".");
obj.setStatus("Removed session plot " + id + ".");
obj.autoSessionPreview();
end
