function ks = plotsOfFilter(obj)
%plotsOfFilter  The plots the drop-down above the tree names: the plots selected, or those of a type, source or layout.
%   Indices into Config.Plots, in the run order; empty when none match.
key = string(obj.PlotFilterDropDown.Value);
if key == "selected"
    ks = sort(obj.selectedPlots());
    return
end
[keys, ~, members] = plotGroups(obj.Config.Plots, extractBefore(key, ":"));
ks = [zeros(1, 0) members{keys == key}];
end
