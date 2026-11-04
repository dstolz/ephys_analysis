function onRemoveLayer(obj)
%onRemoveLayer  Remove the layer picked from the selected panel; the one taking its place is picked.
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
j = obj.SelectedPanel;
if j < 1 || j > numel(obj.Config.Figures(k).panels); return; end
i = obj.SelectedLayer;
if i < 1 || i > numel(obj.Config.Figures(k).panels(j).layers); return; end
cfg = obj.gatherConfig();
fig = cfg.Figures(k);
p = fig.panels(j);
what = layerLabel(p.layers(i));
p.layers(i) = [];
fig.panels(j) = p;
cfg.Figures(k) = fig;
obj.SelectedLayer = min(i, numel(p.layers));
commitFigureEdit(obj, cfg, "Removed layer """ + what + """ from " + p.id + ".", Action="Remove layer");
end
