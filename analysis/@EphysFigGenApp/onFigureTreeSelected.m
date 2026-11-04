function onFigureTreeSelected(obj, nodes)
%onFigureTreeSelected  A node of the figure tree was picked: that figure opens in the editor (onFigureSelected).
%   A group's header is not a figure: picked, the selected figure stays
%   selected (the tree shows it again).
k = [];
for n = reshape(nodes, 1, [])
    if isnumeric(n.NodeData); k = n.NodeData; break; end
end
if isempty(k)
    obj.refreshFigureList();
    return
end
obj.onFigureSelected(k);
end
