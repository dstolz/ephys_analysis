function buildAlignTab(obj)
%buildAlignTab  The config's Defaults (event, window, selection), a live epoch count and the epoch diagram.
%   Under the count, "Show the epochs Pairing and Artifacts exclude"
%   (AlignBarsExcluded) and its bar per group; then the kept trials. Right
%   of them, the epoch
%   diagram of the Defaults on the active dataset (EpochDiagram drawn in
%   the tab, refreshAlignPreview); so the controls' own "Epoch Diagram"
%   button (the figure editor's opens the window) is hidden here. Beside the
%   active dataset, its star (starButton), its note (noteButton: the
%   notepad) and the Favorites (buildFavorites): every starred dataset,
%   channel and unit, to go to.
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
obj.AlignControls.Diagram.Visible = "off";   % the diagram is in the tab
obj.AlignControls.WindowGrid.RowHeight{end} = 0;

right = uigridlayout(g, [3 2]);
right.RowHeight = {30, 30, '1x'};
right.ColumnWidth = {'fit', '1x'};
right.Padding = [0 0 0 0];
l = uilabel(right, "Text", "Active dataset:");
l.Layout.Row = 1; l.Layout.Column = 1;
sg = uigridlayout(right, [1 3], "ColumnWidth", {'1x', 34, 34}, "ColumnSpacing", 4, "Padding", [0 0 0 0]);
sg.Layout.Row = 1; sg.Layout.Column = 2;
obj.AlignDatasetDropDown = uidropdown(sg, "Items", "(scan first)", "ItemsData", 0, ...
    "ValueChangedFcn", @(dd, ~) obj.selectDataset(dd.Value));
obj.AlignDatasetStar = starButton(obj, sg, "dataset");
obj.AlignDatasetNote = noteButton(obj, sg, "dataset");
l = uilabel(right, "Text", "Favorites:");
l.Layout.Row = 2; l.Layout.Column = 1;
obj.AlignFavorites = buildFavorites(obj, right, "AlignFavorites");
obj.AlignFavorites.Grid.Layout.Row = 2; obj.AlignFavorites.Grid.Layout.Column = 2;
body = uigridlayout(right, [1 2], "ColumnWidth", {'1x', '2x'}, "Padding", [0 0 0 0]);
body.Layout.Row = 3; body.Layout.Column = [1 2];
stats = uigridlayout(body, [4 1], "RowHeight", {'fit', 22, '1x', '1x'}, "Padding", [0 0 0 0]);
obj.AlignSummaryLabel = uilabel(stats, "Text", "Scan and pick a dataset to see its epochs.", "WordWrap", "on", ...
    "FontWeight", "bold");
obj.AlignBarsExcluded = uicheckbox(stats, "Text", "Show the epochs Pairing and Artifacts exclude", "Value", false, ...
    "ValueChangedFcn", @(~,~) obj.refreshAlignPreview(), ...
    "Tooltip", "Off: each bar counts the epochs the selection keeps. On: each bar counts the epochs of every " + ...
    "pairing flag, with or without an artifact, and stacks the ones the Pairing ticks (gray) and the artifacts " + ...
    "(red) exclude on the kept ones (the group's color).");
obj.AlignAxes = uiaxes(stats);
title(obj.AlignAxes, "Epochs per group");
obj.AlignTrialsTable = uitable(stats, "RowName", {}, "ColumnWidth", 'auto', "ColumnSortable", true);
dp = uipanel(body, "Title", "Epoch Diagram: how these defaults cut the active dataset into epochs");
obj.AlignEpochDiagram = EpochDiagram(Parent=dp);
end
