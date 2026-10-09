function onPlotGroupToggled(obj, node, collapsed)
%onPlotGroupToggled  The user collapsed (COLLAPSED true) or expanded a group of the plot tree.
%   Remembered, so a rebuild of the tree (a plot added or moved) keeps it so.
key = string(node.NodeData);
obj.PlotGroupsCollapsed(obj.PlotGroupsCollapsed == key) = [];
if collapsed
    obj.PlotGroupsCollapsed(end+1) = key;
end
end
