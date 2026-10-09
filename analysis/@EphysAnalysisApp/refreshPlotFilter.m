function refreshPlotFilter(obj)
%refreshPlotFilter  The drop-down above the plot tree: the plots selected, then each plot type, source and layout in use.
%   Each entry is a plotGroups key ("kind:PSTH") with the number of plots
%   in it; the entry picked stays picked while it is still there.
P = obj.Config.Plots;
items = "Selected plots";
data = "selected";
names = ["kind" "source" "layout"];
titles = ["Type" "Source" "Layout"];
for i = 1:numel(names)
    [keys, labels, members] = plotGroups(P, names(i));
    for g = 1:numel(keys)
        items(end+1) = sprintf("%s: %s (%d)", titles(i), labels(g), numel(members{g})); %#ok<AGROW>
        data(end+1) = keys(g); %#ok<AGROW>
    end
end
dd = obj.PlotFilterDropDown;
if isequal(reshape(string(dd.Items), 1, []), items) && isequal(reshape(string(dd.ItemsData), 1, []), data)
    return
end
keep = string(dd.Value);
dd.ItemsData = {};
dd.Items = items;
dd.ItemsData = data;
if ismember(keep, data)
    dd.Value = keep;
end
end
