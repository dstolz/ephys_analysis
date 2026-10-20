function buildAlignTab(obj)
%buildAlignTab  The config's Defaults (event, window, selection) and a live epoch count.
%   "Epoch Diagram", under the Epoch window, opens the epoch diagram for the
%   Defaults (onShowEpochs). Beside the active dataset, its star (starButton)
%   and the Favorites (buildFavorites): every starred dataset, channel and
%   unit, to go to.
g = uigridlayout(obj.TabAlign, [1 2]);
g.ColumnWidth = {470, '1x'};
g.Padding = [8 8 8 8];

left = uigridlayout(g, [3 1]);
left.RowHeight = {22, 'fit', '1x'};
left.Padding = [0 0 0 0];
note = uilabel(left, "Text", "Defaults: every figure whose event / window / selection is ""default"" uses these.", ...
    "FontColor", [0.35 0.35 0.35]);
note.Layout.Row = 1;
host = uigridlayout(left, [3 1]);
host.Layout.Row = 2;
host.RowHeight = {'fit', 'fit', 'fit'};
host.Padding = [0 0 0 0];
host.RowSpacing = 6;
panels = [uipanel(host, "Title", "Event reference (align to)") uipanel(host, "Title", "Epoch window") ...
    uipanel(host, "Title", "Trial selection")];
obj.AlignControls = obj.buildAlignControls(panels, @(~) obj.onConfigChanged("defaults"));
obj.AlignEpochsButton = obj.AlignControls.Diagram;
obj.AlignEpochsButton.ButtonPushedFcn = @(~,~) obj.onShowEpochs("defaults");
obj.AlignEpochsButton.Tooltip = "A window, kept above the app, that draws how these defaults cut the active dataset into epochs: " + ...
    "the digital lines as TTL traces, each event (time 0), each epoch's window, and the epochs dropped and why. " + ...
    "It follows every edit.";

right = uigridlayout(g, [5 2]);
right.RowHeight = {30, 30, 'fit', '1x', '1x'};
right.ColumnWidth = {'fit', '1x'};
right.Padding = [0 0 0 0];
l = uilabel(right, "Text", "Active dataset:");
l.Layout.Row = 1; l.Layout.Column = 1;
sg = uigridlayout(right, [1 2], "ColumnWidth", {'1x', 34}, "ColumnSpacing", 4, "Padding", [0 0 0 0]);
sg.Layout.Row = 1; sg.Layout.Column = 2;
obj.AlignDatasetDropDown = uidropdown(sg, "Items", "(scan first)", "ItemsData", 0, ...
    "ValueChangedFcn", @(dd, ~) obj.selectDataset(dd.Value));
obj.AlignDatasetStar = starButton(obj, sg, "dataset");
l = uilabel(right, "Text", "Favorites:");
l.Layout.Row = 2; l.Layout.Column = 1;
obj.AlignFavorites = buildFavorites(obj, right, "AlignFavorites");
obj.AlignFavorites.Grid.Layout.Row = 2; obj.AlignFavorites.Grid.Layout.Column = 2;
obj.AlignSummaryLabel = uilabel(right, "Text", "Scan and pick a dataset to see its epochs.", "WordWrap", "on", ...
    "FontWeight", "bold");
obj.AlignSummaryLabel.Layout.Row = 3; obj.AlignSummaryLabel.Layout.Column = [1 2];
obj.AlignAxes = uiaxes(right);
obj.AlignAxes.Layout.Row = 4; obj.AlignAxes.Layout.Column = [1 2];
title(obj.AlignAxes, "Epochs per group");
obj.AlignTrialsTable = uitable(right, "RowName", {}, "ColumnWidth", 'auto', "ColumnSortable", true);
obj.AlignTrialsTable.Layout.Row = 5; obj.AlignTrialsTable.Layout.Column = [1 2];
end
