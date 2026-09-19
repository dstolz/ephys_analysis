function onMovePlot(obj, step)
%onMovePlot  Move the selected plot up (-1) or down (+1) the list (the run and report order).
k = obj.SelectedPlot;
cfg = obj.gatherConfig();
j = k + step;
if k < 1 || j < 1 || j > numel(cfg.Plots); return; end
order = 1:numel(cfg.Plots);
order([k j]) = [j k];
cfg.Plots = cfg.Plots(order);
obj.SelectedPlot = j;
obj.applyConfig(cfg);
end
