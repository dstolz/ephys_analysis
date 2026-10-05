function refreshFlowChart(obj)
%refreshFlowChart  Redraw the Flow tab's chart from the working config.
%   In the view picked (flowChartHTML); Layout is on for the detail view only.
%   The page gets back the zoom its view was left in (FlowZoom), read by its
%   setup() from the component's Data.
if isempty(obj.FlowHTML) || ~isvalid(obj.FlowHTML); return; end
obj.FlowLayoutDropDown.Enable = obj.FlowViewDropDown.Value == "detail";
key = "overview";
if obj.FlowViewDropDown.Value == "detail"; key = "detail_" + obj.FlowLayoutDropDown.Value; end
if isfield(obj.FlowZoom, key)
    obj.FlowHTML.Data = obj.FlowZoom.(key);
else
    obj.FlowHTML.Data = [];
end
try
    [html, summary] = obj.flowChartHTML();
catch ME
    html = "<p style=""font:12px sans-serif;color:#b42318"">Could not draw the diagram: " ...
        + replace(replace(string(ME.message), "&", "&amp;"), "<", "&lt;") + "</p>";
    summary = "Diagram failed.";
end
obj.FlowHTML.HTMLSource = char(html);
obj.FlowSummaryLabel.Text = summary;
end
