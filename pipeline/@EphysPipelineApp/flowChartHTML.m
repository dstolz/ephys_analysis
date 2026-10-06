function [html, summary] = flowChartHTML(obj, opts)
%flowChartHTML  Flow chart of the working config as a standalone HTML page.
%   [HTML, SUMMARY] = app.flowChartHTML() draws the Diagram tab's view
%   (FlowViewDropDown) of obj.Config and the active dataset: "overview"
%   (the default), the steps and the data that flows between them
%   (flowOverviewHTML: PipelineDiagram.overview), or "detail", every step
%   with all its parameters (PipelineDiagram.detail), in the Layout picked
%   on the tab (FlowLayoutDropDown: "tree" or "steps").
%
%   app.flowChartHTML(View=V, Layout=L, HideUnused=H) picks them instead: V
%   "detail" or "overview", L "tree" or "steps" (the detail view's only), H
%   whether to leave out what the config does not use (default: the tab's
%   Hide unused box).
%
%   The pages themselves are drawn by PipelineDiagram, which needs no app:
%   each box names the control(s) behind it, and a click in the app sends
%   them to onFlowNavigate, which opens that control's tab.
%
%   See also PipelineDiagram, flowOverviewHTML, onFlowNavigate, flowNavControls.

arguments
    obj
    opts.View (1,1) string {mustBeMember(opts.View, ["" "detail" "overview"])} = ""
    opts.Layout (1,1) string {mustBeMember(opts.Layout, ["" "tree" "steps"])} = ""
    opts.HideUnused (1,:) logical = logical.empty
end
if isempty(opts.HideUnused); opts.HideUnused = obj.hideUnused(); end
view = pick(opts.View, obj.FlowViewDropDown, "overview");
if view == "overview"
    [html, summary] = obj.flowOverviewHTML(HideUnused=opts.HideUnused);
    return
end
layout = pick(opts.Layout, obj.FlowLayoutDropDown, "tree");
[html, summary] = PipelineDiagram.detail(obj.Config, obj.currentDataset(), Layout=layout, HideUnused=opts.HideUnused);
end


function v = pick(given, dropDown, fallback)
%pick  GIVEN, else the drop-down's value, else FALLBACK (before the tab is built).
v = given;
if v == ""
    v = string(fallback);
    if ~isempty(dropDown) && isvalid(dropDown)
        v = string(dropDown.Value);
    end
end
end
