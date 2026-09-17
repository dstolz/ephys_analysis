function refreshFlowChart(obj)
%refreshFlowChart  Redraw the Flow tab's chart from the working config.
if isempty(obj.FlowHTML) || ~isvalid(obj.FlowHTML); return; end
try
    [html, summary] = obj.flowChartHTML();
catch ME
    html = "<p style=""font:12px sans-serif;color:#b42318"">Could not draw the flow chart: " ...
        + replace(replace(string(ME.message), "&", "&amp;"), "<", "&lt;") + "</p>";
    summary = "Flow chart failed.";
end
obj.FlowHTML.HTMLSource = char(html);
obj.FlowSummaryLabel.Text = summary;
end
