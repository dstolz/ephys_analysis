function onFlowViewChanged(obj)
%onFlowViewChanged  Redraw the Diagram in the view just picked.
%   Every parameter ("detail", flowChartHTML) or the data-flow overview
%   ("overview", flowOverviewHTML). Layout applies to the first only, so
%   refreshFlowChart turns it off for the overview. The choice is a
%   preference (DiagramView).
obj.refreshFlowChart();
obj.savePreferences();
end
