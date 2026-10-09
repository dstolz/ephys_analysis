function onMovePlot(obj, step)
%onMovePlot  Move the selected plot up (-1) or down (+1) its group (the run and report order).
%   It swaps places with its neighbour in the tree's group (the whole list
%   when ungrouped), which shows as one step; the plots between them keep theirs.
k = obj.SelectedPlot;
cfg = obj.gatherConfig();
if k < 1 || k > numel(cfg.Plots); return; end
[~, ~, members] = plotGroups(cfg.Plots, string(obj.PlotGroupDropDown.Value));
group = members{cellfun(@(m) any(m == k), members)};
i = find(group == k) + step;
if i < 1 || i > numel(group); return; end
j = group(i);
order = 1:numel(cfg.Plots);
order([k j]) = [j k];
cfg.Plots = cfg.Plots(order);
obj.SelectedPlot = j;
obj.applyConfig(cfg);
end
