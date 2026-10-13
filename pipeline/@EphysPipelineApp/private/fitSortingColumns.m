function fitSortingColumns(obj)
%fitSortingColumns  Widths of the Sorting tab's columns: settings, parameter details, sorted output.
%   The settings keep 720 px. The right column (Sorted output and the log)
%   gets at least the 310 px its buttons need, else 55% of what is left;
%   the Kilosort4 parameter details column (KSHelpPanel) takes the rest, or
%   none while it is hidden (a SpikeInterface sorter; showSorterControls).
%   Runs when the tab is resized and when the sorter changes.
if isempty(obj.KSHelpPanel) || ~isvalid(obj.KSHelpPanel); return; end
g = obj.KSHelpPanel.Parent;
if ~logical(obj.KSHelpPanel.Visible)
    g.ColumnWidth = {720, 0, '1x'};
    return
end
free = obj.TabSorting.InnerPosition(3) - sum(g.Padding([1 3])) - 2 * g.ColumnSpacing - 720;
g.ColumnWidth = {720, '1x', max(310, round(0.55 * free))};
end
