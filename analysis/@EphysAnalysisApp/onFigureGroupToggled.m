function onFigureGroupToggled(obj, node, collapsed)
%onFigureGroupToggled  The user collapsed (COLLAPSED true) or expanded a group of the figure tree.
%   Remembered (FigureGroupsCollapsed, a preference), so a rebuild of the
%   tree (a figure added or moved) keeps it so.
key = string(node.NodeData);
obj.FigureGroupsCollapsed(obj.FigureGroupsCollapsed == key) = [];
if collapsed
    obj.FigureGroupsCollapsed(end+1) = key;
end
end
