function buildFlowTab(obj)
%buildFlowTab  Flow tab: a flow chart of the processing the working config does.
%   One tree per step that reads the raw recording (Artifacts, Sorting,
%   Signals, Spikes), each drawn top-down from the recording through every
%   filter / reference / detection stage with its parameters to the files
%   written, plus the downstream steps that read those files instead (sorted
%   units, Export). Built by flowChartHTML from obj.Config and shown in an
%   HTML component; refreshed when the tab is shown and whenever the config
%   changes while it is (syncStepEnableStates). Clicking a box opens the
%   setting it draws (onFlowNavigate).

g = uigridlayout(obj.TabFlow, [2 1]);
g.RowHeight = {'fit', '1x'};
g.Padding   = [10 10 10 10];

bar = uigridlayout(g, [1 4]);
bar.Layout.Row = 1;
bar.ColumnWidth = {'fit', 'fit', 'fit', '1x'};
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
obj.FlowSummaryLabel = uilabel(bar, "Text", "", "FontColor", [0.4 0.4 0.4]);

obj.FlowHTML = uihtml(g, "HTMLEventReceivedFcn", @(~, evt) obj.onFlowNavigate(evt));
obj.FlowHTML.Layout.Row = 2;
end
