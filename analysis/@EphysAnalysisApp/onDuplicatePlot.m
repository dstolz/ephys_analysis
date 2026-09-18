function onDuplicatePlot(obj)
%onDuplicatePlot  Copy the selected plot under a new id, right after it.
k = obj.SelectedPlot;
if k < 1; return; end
cfg = obj.gatherConfig();
p = cfg.Plots(k);
p.id = "";
[cfg, id] = cfg.addPlot(p);
n = numel(cfg.Plots);
cfg.Plots = cfg.Plots([1:k n k+1:n-1]);
obj.SelectedPlot = k + 1;
obj.applyConfig(cfg);
obj.setStatus("Duplicated as " + id + ".");
end
