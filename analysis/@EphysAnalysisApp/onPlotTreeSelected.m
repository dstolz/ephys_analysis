function onPlotTreeSelected(obj, nodes)
%onPlotTreeSelected  Nodes of the plot tree were picked: those plots open in the editor.
%   A group's header is not a plot; picked alone, the plots selected stay
%   selected. Several plots (Ctrl- or Shift-click) are edited together:
%   the first picked stays first (the one previewed), those added since
%   follow in the tree's order.
ks = zeros(1, 0);
for n = reshape(nodes, 1, [])
    if isnumeric(n.NodeData); ks(end+1) = n.NodeData; end %#ok<AGROW>
end
if isempty(ks)
    obj.refreshPlotList();
    return
end
old = obj.selectedPlots();
obj.onPlotSelected([old(ismember(old, ks)) ks(~ismember(ks, old))]);
end
