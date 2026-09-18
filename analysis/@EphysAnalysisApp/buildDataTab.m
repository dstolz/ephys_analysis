function buildDataTab(obj)
%buildDataTab  Config name, where the datasets are, the datasets table and the active dataset.
g = uigridlayout(obj.TabData, [1 2]);
g.ColumnWidth = {'3x', '2x'};
g.Padding = [8 8 8 8];
changed = @(~,~) obj.onConfigChanged("source");

left = uigridlayout(g, [9 4]);
left.Padding = [0 0 0 0];
left.RowHeight = {24, 24, 24, 24, 24, 56, 20, '1x', 20};
left.ColumnWidth = {110, '1x', '1x', 90};

lab(left, "Config name:", 1, 1);
obj.ConfigNameField = uieditfield(left, "text", "ValueChangedFcn", @(~,~) obj.onConfigChanged("name"));
obj.ConfigNameField.Layout.Row = 1; obj.ConfigNameField.Layout.Column = 2;
obj.ConfigDescField = uieditfield(left, "text", "Placeholder", "description", ...
    "ValueChangedFcn", @(~,~) obj.onConfigChanged("name"));
obj.ConfigDescField.Layout.Row = 1; obj.ConfigDescField.Layout.Column = [3 4];

lab(left, "Datasets from:", 2, 1);
obj.SourceModeDropDown = uidropdown(left, "Items", ["a pipeline project (root folder)" "output folders"], ...
    "ItemsData", ["project" "folders"], "ValueChangedFcn", @(~,~) obj.onSourceModeChanged());
obj.SourceModeDropDown.Layout.Row = 2; obj.SourceModeDropDown.Layout.Column = 2;
obj.ScanButton = uibutton(left, "Text", "Scan", "FontWeight", "bold", ...
    "Tooltip", "Find the datasets and what each holds.", "ButtonPushedFcn", @(~,~) obj.onScan());
obj.ScanButton.Layout.Row = 2; obj.ScanButton.Layout.Column = 4;

lab(left, "Project root:", 3, 1);
obj.RootField = uieditfield(left, "text", "Placeholder", "the folder the preprocessing app scans", "ValueChangedFcn", changed);
obj.RootField.Layout.Row = 3; obj.RootField.Layout.Column = [2 3];
obj.BrowseRootButton = uibutton(left, "Text", "Browse...", "ButtonPushedFcn", @(~,~) obj.onBrowseRoot("root"));
obj.BrowseRootButton.Layout.Row = 3; obj.BrowseRootButton.Layout.Column = 4;

lab(left, "Output root:", 4, 1);
obj.OutputRootField = uieditfield(left, "text", "Placeholder", "blank = outputs next to each recording", "ValueChangedFcn", changed);
obj.OutputRootField.Layout.Row = 4; obj.OutputRootField.Layout.Column = [2 3];
obj.BrowseOutputButton = uibutton(left, "Text", "Browse...", "ButtonPushedFcn", @(~,~) obj.onBrowseRoot("output"));
obj.BrowseOutputButton.Layout.Row = 4; obj.BrowseOutputButton.Layout.Column = 4;

lab(left, "Name pattern:", 5, 1);
obj.NamePatternField = uieditfield(left, "text", "Tooltip", "Dataset-name tokens (see parseNameTokens), as in the pipeline config.", ...
    "ValueChangedFcn", changed);
obj.NamePatternField.Layout.Row = 5; obj.NamePatternField.Layout.Column = [2 4];

lab(left, "Output folders:", 6, 1);
obj.FoldersArea = uitextarea(left, "Placeholder", "one dataset output folder per line (holding <Name>_extract*.mat, _spikes.mat, _behavior.mat ...)", ...
    "ValueChangedFcn", changed);
obj.FoldersArea.Layout.Row = 6; obj.FoldersArea.Layout.Column = [2 3];
obj.AddFolderButton = uibutton(left, "Text", "Add...", "ButtonPushedFcn", @(~,~) obj.onAddFolder());
obj.AddFolderButton.Layout.Row = 6; obj.AddFolderButton.Layout.Column = 4;

obj.ScanLabel = uilabel(left, "Text", "Scan to list the datasets.", "FontColor", [0.35 0.35 0.35]);
obj.ScanLabel.Layout.Row = 7; obj.ScanLabel.Layout.Column = [1 4];
obj.DatasetsTable = uitable(left, "RowName", {}, ...
    "ColumnName", {'Run', 'Name', 'Key', 'LFP', 'MUA', 'SPIKE', 'AUX', 'Units', 'Detected', 'Behavior', 'Trials', 'Pairing', 'Duration (s)'}, ...
    "ColumnWidth", {36, 'auto', 'auto', 38, 38, 44, 38, 44, 60, 60, 46, 'auto', 80}, ...
    "CellEditCallback", @(~, evt) obj.onDatasetsTableEdited(evt), ...
    "CellSelectionCallback", @(~, evt) obj.onDatasetCellSelection(evt));
obj.DatasetsTable.Layout.Row = 8; obj.DatasetsTable.Layout.Column = [1 4];
hint = uilabel(left, "Text", "Tick Run for the datasets to run; click a row to make it the active dataset (Alignment and Plots preview it).", ...
    "FontColor", [0.35 0.35 0.35]);
hint.Layout.Row = 9; hint.Layout.Column = [1 4];

right = uipanel(g, "Title", "Active dataset");
rg = uigridlayout(right, [6 1]);
rg.RowHeight = {'fit', '1x', '1x', 'fit', '1x', '1x'};
obj.MemoryLabel = uilabel(rg, "Text", "No dataset selected.", "WordWrap", "on");
obj.InventoryTable = uitable(rg, "RowName", {}, "ColumnName", {'Kind', 'Exists', 'Source', 'File'}, ...
    "ColumnWidth", {70, 50, 80, 'auto'});
obj.LinesTable = uitable(rg, "RowName", {}, ...
    "ColumnName", {'Line', 'Count', 'Mean length (s)', 'First (s)', 'Last (s)', 'Inverted'}, "ColumnWidth", 'auto');
obj.BehaviorLabel = uilabel(rg, "Text", "", "WordWrap", "on");
obj.ParamsTable = uitable(rg, "RowName", {}, "ColumnName", {'Parameter', 'Values'}, "ColumnWidth", {120, 'auto'});
obj.UnitsTable = uitable(rg, "RowName", {}, "ColumnName", {'Class', 'Shank', 'Units', 'Spikes'}, "ColumnWidth", 'auto');
end


function l = lab(parent, txt, row, col)
l = uilabel(parent, "Text", txt);
l.Layout.Row = row;
l.Layout.Column = col;
end
