function onDuplicatePlot(obj)
%onDuplicatePlot  Copy each selected plot under a new id, right after it; the copies are selected.
ks = obj.selectedPlots();
if isempty(ks); return; end
cfg = obj.gatherConfig();
[order, back] = sort(ks);
copies = zeros(1, numel(ks));
ids = strings(1, numel(ks));
for i = 1:numel(order)
    k = order(i) + i - 1;   % where it is now, after the copies put in above it
    p = cfg.Plots(k);
    p.id = "";
    [cfg, ids(i)] = cfg.addPlot(p);
    n = numel(cfg.Plots);
    cfg.Plots = cfg.Plots([1:k n k+1:n-1]);
    copies(i) = k + 1;
end
copies(back) = copies;   % in the selection's order
ids(back) = ids;
obj.SelectedPlot = copies(1);
obj.applyConfig(cfg);
if isscalar(ks)
    obj.setStatus("Duplicated as " + ids + ".");
else
    obj.onPlotSelected(copies);
    obj.setStatus(sprintf("Duplicated %d plots as %s.", numel(ids), strjoin(ids, ", ")));
end
end
