function buildAlignTab(obj)
%buildAlignTab  The config's Defaults (event, window, selection) and a live epoch count.
g = uigridlayout(obj.TabAlign, [1 2]);
g.ColumnWidth = {470, '1x'};
g.Padding = [8 8 8 8];

left = uigridlayout(g, [3 1]);
left.RowHeight = {22, 'fit', '1x'};
left.Padding = [0 0 0 0];
note = uilabel(left, "Text", "Defaults: every plot whose event / window / selection is ""default"" uses these.", ...
    "FontColor", [0.35 0.35 0.35]);
note.Layout.Row = 1;
host = uipanel(left, "BorderType", "none");
host.Layout.Row = 2;
obj.AlignControls = obj.buildAlignControls(host, @() obj.onConfigChanged("defaults"));

right = uigridlayout(g, [4 2]);
right.RowHeight = {22, 'fit', '1x', '1x'};
right.ColumnWidth = {'fit', '1x'};
right.Padding = [0 0 0 0];
l = uilabel(right, "Text", "Active dataset:");
l.Layout.Row = 1; l.Layout.Column = 1;
obj.AlignDatasetDropDown = uidropdown(right, "Items", "(scan first)", "ItemsData", 0, ...
    "ValueChangedFcn", @(dd, ~) obj.selectDataset(dd.Value));
obj.AlignDatasetDropDown.Layout.Row = 1; obj.AlignDatasetDropDown.Layout.Column = 2;
obj.AlignSummaryLabel = uilabel(right, "Text", "Scan and pick a dataset to see its epochs.", "WordWrap", "on", ...
    "FontWeight", "bold");
obj.AlignSummaryLabel.Layout.Row = 2; obj.AlignSummaryLabel.Layout.Column = [1 2];
obj.AlignAxes = uiaxes(right);
obj.AlignAxes.Layout.Row = 3; obj.AlignAxes.Layout.Column = [1 2];
title(obj.AlignAxes, "Epochs per group");
obj.AlignTrialsTable = uitable(right, "RowName", {}, "ColumnWidth", 'auto');
obj.AlignTrialsTable.Layout.Row = 4; obj.AlignTrialsTable.Layout.Column = [1 2];
end
