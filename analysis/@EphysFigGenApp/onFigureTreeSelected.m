function onFigureTreeSelected(obj, nodes)
%onFigureTreeSelected  A node of the figure tree was picked: that figure opens in the editor (onFigureSelected).
%   A group's header is not a figure: picked, the selected figure stays
%   selected (the tree shows it again). A click in the tree takes the arrow
%   keys back from Arrange's nudges (FigureArrangeFocus).
obj.FigureArrangeFocus = false;
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
