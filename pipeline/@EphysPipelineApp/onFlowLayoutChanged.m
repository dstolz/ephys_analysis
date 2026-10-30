function onFlowLayoutChanged(obj)
%onFlowLayoutChanged  Redraw the Diagram in the layout or direction just picked.
%   One tree from the raw recording ("tree") or a tree per step ("steps"),
%   from top to bottom ("vertical") or from left to right ("horizontal"); see
%   flowChartHTML. The choices are preferences (DiagramLayout, DiagramDirection).
obj.refreshFlowChart();
obj.savePreferences();
end
