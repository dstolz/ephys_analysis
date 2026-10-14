function onMoveLayer(obj, step)
%onMoveLayer  Move the layer picked up (STEP -1) or down (+1) the selected panel's layers; it stays picked.
%   The order is the drawing order: the first layer's units are a raster's
%   top rows, its line style solid.
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
j = obj.SelectedPanel;
if j < 1 || j > numel(obj.Config.Figures(k).panels); return; end
i = obj.SelectedLayer;
n = numel(obj.Config.Figures(k).panels(j).layers);
t = i + step;
if i < 1 || i > n || t < 1 || t > n; return; end
cfg = obj.gatherConfig();
fig = cfg.Figures(k);
p = fig.panels(j);
p.layers([i t]) = p.layers([t i]);
fig.panels(j) = p;
cfg.Figures(k) = fig;
obj.SelectedLayer = t;
commitFigureEdit(obj, cfg, "Moved layer """ + layerLabel(p.layers(t)) + """ " + ternary(step < 0, "up", "down") + ".");
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
