function buildFlowTab(obj)
%buildFlowTab  Flow tab: a flow chart of the processing the working config does.
%   The View drop-down picks what it draws (a preference, DiagramView):
%   - Every parameter (flowChartHTML): one tree from the raw recording, a
%     branch per step that reads it (Artifacts, Signals, Spikes; Sorting,
%     and Signals / Spikes while they erase the periods, hang from the
%     artifact periods), drawn top-down through every filter / reference / detection stage
%     with its parameters to the files written, with the steps that read
%     those files instead hanging from them (sorted units under Sorting,
%     Export under the Signals extract). The Layout drop-down switches to a
%     tree per step instead (then the steps that read their outputs as
%     downstream trees); it is a preference (DiagramLayout).
%   - Data-flow overview (flowOverviewHTML): every step as one box with the
%     files it writes, and an arrow from each input or file to every step
%     that reads it. Layout does not apply.
%   Shown in an HTML component; refreshed when the tab is shown and whenever
%   the config changes while it is (syncStepEnableStates). Clicking a box
%   opens the setting it draws (onFlowNavigate).

g = uigridlayout(obj.TabFlow, [2 1]);
g.RowHeight = {'fit', '1x'};
g.Padding   = [10 10 10 10];

bar = uigridlayout(g, [1 8]);
bar.Layout.Row = 1;
bar.ColumnWidth = {'fit', 'fit', 'fit', 'fit', 170, 'fit', 150, '1x'};
bar.RowHeight   = {30};
bar.Padding     = [0 0 0 0];
obj.FlowRefreshButton = uibutton(bar, "Text", "Refresh", ...
    "ButtonPushedFcn", @(~,~) obj.refreshFlowChart());
obj.FlowSaveButton = uibutton(bar, "Text", "Save as HTML...", ...
    "Tooltip", "Write the chart as a standalone .html file (opens in any browser, prints to PDF).", ...
    "ButtonPushedFcn", @(~,~) obj.onSaveFlowChart());
obj.FlowOpenButton = uibutton(bar, "Text", "Open in Browser", ...
    "Tooltip", "Open the chart in your default web browser.", ...
    "ButtonPushedFcn", @(~,~) obj.onOpenFlowChartInBrowser());
uilabel(bar, "Text", "View:", "HorizontalAlignment", "right");
obj.FlowViewDropDown = uidropdown(bar, "Items", ["Every parameter", "Data-flow overview"], ...
    "ItemsData", ["detail", "overview"], "Value", "detail", ...
    "Tooltip", "Every step with all its parameters, or an overview of how the data flows from step to step.", ...
    "ValueChangedFcn", @(~,~) obj.onFlowViewChanged());
uilabel(bar, "Text", "Layout:", "HorizontalAlignment", "right");
obj.FlowLayoutDropDown = uidropdown(bar, "Items", ["One tree", "Tree per step"], ...
    "ItemsData", ["tree", "steps"], "Value", "tree", ...
    "Tooltip", "One tree from the raw recording, or a tree of its own for each step (Every parameter view).", ...
    "ValueChangedFcn", @(~,~) obj.onFlowLayoutChanged());
obj.FlowSummaryLabel = uilabel(bar, "Text", "", "FontColor", [0.4 0.4 0.4]);

obj.FlowHTML = uihtml(g, "HTMLEventReceivedFcn", @(~, evt) obj.onFlowNavigate(evt));
obj.FlowHTML.Layout.Row = 2;
end
