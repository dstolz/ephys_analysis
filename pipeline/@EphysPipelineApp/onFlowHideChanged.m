function onFlowHideChanged(obj)
%onFlowHideChanged  Redraw the Diagram with or without what the config does not use.
%   The Hide unused box, in either view (flowChartHTML). The choice is a
%   preference (DiagramHideUnused).
obj.refreshFlowChart();
obj.savePreferences();
end
