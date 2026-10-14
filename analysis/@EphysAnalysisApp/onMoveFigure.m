function onMoveFigure(obj, step)
%onMoveFigure  Move the selected figure up (STEP -1) or down (+1) the list; it stays selected, its preview as it is.
k = obj.SelectedFigure;
n = numel(obj.Config.Figures);
j = k + step;
if k < 1 || k > n || j < 1 || j > n; return; end
cfg = obj.gatherConfig();
F = cfg.Figures;
F([k j]) = F([j k]);
cfg.Figures = F;
obj.SelectedFigure = j;
obj.applyConfig(cfg);
obj.setStatus("Moved " + F(j).id + " " + ternary(step < 0, "up", "down") + ".");
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
