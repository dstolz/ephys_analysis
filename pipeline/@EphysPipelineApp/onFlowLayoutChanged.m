function onFlowLayoutChanged(obj)
%onFlowLayoutChanged  Redraw the Diagram in the layout just picked.
%   One tree from the raw recording ("tree") or a tree per step ("steps");
%   see flowChartHTML. The choice is a preference (DiagramLayout).
obj.refreshFlowChart();
obj.savePreferences();
end
