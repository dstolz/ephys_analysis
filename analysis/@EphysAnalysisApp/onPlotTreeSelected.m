function onPlotTreeSelected(obj, nodes)
%onPlotTreeSelected  A node of the plot tree was picked: a plot opens in the editor.
%   A group's header is not a plot; the plot in the editor stays selected.
if ~isempty(nodes) && isnumeric(nodes(1).NodeData)
    obj.onPlotSelected(nodes(1).NodeData);
else
    obj.refreshPlotList();
end
end
