function onPlotTreeDoubleClicked(obj, evt)
%onPlotTreeDoubleClicked  A double-click on a plot of the tree ticks or unticks its check box (enables or disables it).
%   A group's header keeps its own double-click (it opens or closes the
%   group); its plots are ticked from the buttons above the tree.
node = evt.InteractionInformation.Node;
if isempty(node) || ~isnumeric(node.NodeData); return; end
obj.setPlotsEnabled(node.NodeData, "toggle");
end
