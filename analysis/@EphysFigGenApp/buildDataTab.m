function buildDataTab(obj)
%buildDataTab  Config name, where the datasets are, the rates the signals are read at, the datasets table and the active dataset.
g = uigridlayout(obj.TabData, [1 2]);
g.ColumnWidth = {'3x', '2x'};
g.Padding = [8 8 8 8];
changed = @(~,~) obj.onConfigChanged("source");

left = uigridlayout(g, [11 4]);
left.Padding = [0 0 0 0];
left.RowHeight = {24, 30, 24, 24, 24, 56, 26, 20, 64, '1x', 20};
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
obj.ScanButton = uibutton(left, "Text", "Scan", ...
    "Tooltip", "Find the datasets and what each holds.", "ButtonPushedFcn", @(~,~) obj.onScan());
obj.ScanButton.Layout.Row = 2; obj.ScanButton.Layout.Column = 4;

lab(left, "Project root:", 3, 1);
obj.RootField = uieditfield(left, "text", "Placeholder", "the folder the pipeline app scans", "ValueChangedFcn", changed);
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
obj.NamePatternField.Layout.Row = 5; obj.NamePatternField.Layout.Column = 2;
obj.RecordingsDropDown = uidropdown(left, ...
    "Items", ["Open Ephys: join recordings" "Open Ephys: one dataset per recording" "Open Ephys: single recording"], ...
    "ItemsData", ["concatenate" "separate" "single"], ...
    "Tooltip", "What an Open Ephys session with several recordings is, as in the pipeline config (Acquisition.OpenEphys.Recordings).", ...
    "ValueChangedFcn", changed);
obj.RecordingsDropDown.Layout.Row = 5; obj.RecordingsDropDown.Layout.Column = [3 4];

lab(left, "Output folders:", 6, 1);
obj.FoldersArea = uitextarea(left, "Placeholder", "one dataset output folder per line (holding <Name>_extract*.mat, _spikes.mat, _behavior.mat ...)", ...
    "ValueChangedFcn", changed);
obj.FoldersArea.Layout.Row = 6; obj.FoldersArea.Layout.Column = [2 3];
obj.AddFolderButton = uibutton(left, "Text", "Add...", "ButtonPushedFcn", @(~,~) obj.onAddFolder());
obj.AddFolderButton.Layout.Row = 6; obj.AddFolderButton.Layout.Column = 4;

% Source.Downsample: the rate each signal is brought to (anti-aliased) before any figure reads it (onDownsample;
% showDownsample words it here and colors the button)
lab(left, "Signals:", 7, 1);
ds = uigridlayout(left, [1 2], "ColumnWidth", {'1x', 'fit'}, "RowHeight", {'1x'}, "Padding", [0 0 0 0]);
ds.Layout.Row = 7; ds.Layout.Column = [2 4];
obj.DownsampleLabel = uilabel(ds, "Text", "", "FontColor", [0.35 0.35 0.35]);
obj.DownsampleButton = uibutton(ds, "Text", "Downsample...", "ButtonPushedFcn", @(~,~) obj.onDownsample());

obj.ScanLabel =uilabel(left, "Text", "Scan to list the datasets.", "FontColor", [0.35 0.35 0.35]);
obj.ScanLabel.Layout.Row = 8; obj.ScanLabel.Layout.Column = [1 2];
obj.FilterLabel = uilabel(left, "Text", "", "FontColor", [0.35 0.35 0.35], "HorizontalAlignment", "right");
obj.FilterLabel.Layout.Row = 8; obj.FilterLabel.Layout.Column = [3 4];

% The filter, as the DatasetBrowser has it: Subject (and "not" these), Search,
% Tags (any / all of, and "not" these) in two rows (refreshDatasetsTable
% applies it, lists the subjects and tags in use and says above how many rows
% show; the rows it hides keep their ticks), and the Run ticks from what it
% shows (onTickDatasets). The filter is the config's Source.Filter
% (gatherSourceSection): a change is a config edit.
fb = uigridlayout(left, [2 1]);
fb.Layout.Row = 9; fb.Layout.Column = [1 4];
fb.RowHeight = {30, 30};
fb.RowSpacing = 4;
fb.Padding = [0 0 0 0];
refilter = @(~,~) filterChanged(obj);
r1 = uigridlayout(fb, [1 6], "ColumnWidth", {'fit', 120, 'fit', 120, 'fit', '1x'}, "RowHeight", {30}, "Padding", [0 0 0 0]);
uilabel(r1, "Text", "Subject");
obj.SubjectFilterDropDown = uidropdown(r1, "Items", {'(any)'}, "Editable", "on", "Value", '(any)', ...
    "Tooltip", "Show these subjects (the name pattern's SubjectID): pick one, or type several separated by commas; * and ? are wildcards. With Tags, the datasets that pass both.", ...
    "ValueChangedFcn", refilter);
uilabel(r1, "Text", "not");
obj.NotSubjectFilterDropDown = uidropdown(r1, "Items", {'(any)'}, "Editable", "on", "Value", '(any)', ...
    "Tooltip", "Leave these subjects out (comma-separated; * and ? are wildcards).", "ValueChangedFcn", refilter);
uilabel(r1, "Text", "Search");
obj.SearchFilterField = uieditfield(r1, "text", "ValueChangedFcn", refilter, ...
    "Placeholder", "words in the name, key, subject or tags", ...
    "Tooltip", "Every word must appear (case ignored); applied when you press Enter or leave the field.");
r2 = uigridlayout(fb, [1 7], "ColumnWidth", {'fit', 120, 70, 'fit', 120, 'fit', 'fit'}, "RowHeight", {30}, "Padding", [0 0 0 0]);
uilabel(r2, "Text", "Tags");
obj.TagFilterDropDown = uidropdown(r2, "Items", {'(any)'}, "Editable", "on", "Value", '(any)', ...
    "Tooltip", "Show the datasets with these tags (any or all of them): pick one, or type several separated by commas. A term that is no tag in use matches nothing. With Subject, the datasets that pass both.", ...
    "ValueChangedFcn", refilter);
obj.TagFilterModeDropDown = uidropdown(r2, "Items", {'any of', 'all of'}, "ItemsData", {'any', 'all'}, "Value", 'any', ...
    "Tooltip", "any of: a dataset with at least one of the tags; all of: with every one", "ValueChangedFcn", refilter);
uilabel(r2, "Text", "not");
obj.NotTagFilterDropDown = uidropdown(r2, "Items", {'(any)'}, "Editable", "on", "Value", '(any)', ...
    "Tooltip", "Leave out the datasets holding any of these tags.", "ValueChangedFcn", refilter);
obj.TickShownButton = uibutton(r2, "Text", "Tick shown only", ...
    "Tooltip", "Tick Run for the datasets shown and clear it for those the filter hides (no filter: tick every one).", ...
    "ButtonPushedFcn", @(~,~) obj.onTickDatasets("shown"));
obj.UntickAllButton = uibutton(r2, "Text", "Untick all", "Tooltip", "Clear Run for every dataset, shown or hidden.", ...
    "ButtonPushedFcn", @(~,~) obj.onTickDatasets("none"));

obj.DatasetsTable = uitable(left, "RowName", {}, ...
    "ColumnName", {'Run', '★', '✎', 'Name', 'Subject', 'Date', 'Key', 'Tags', 'Variables', 'LFP', 'MUA', 'Spike band', 'AUX', 'Units', 'Detected', 'Behavior', 'Trials', 'Pairing', 'Duration (s)', ''}, ...
    "ColumnWidth", {36, 30, 30, 'auto', 90, 84, 'auto', 90, 120, 38, 38, 72, 38, 44, 60, 60, 46, 'auto', 80, 1}, ...
    "ColumnSortable", true, ...
    "CellEditCallback", @(~, evt) obj.onDatasetsTableEdited(evt), ...
    "CellSelectionCallback", @(~, evt) obj.onDatasetCellSelection(evt), ...
    "ClickedFcn", @(~, evt) obj.onDatasetNoteClicked(evt), ...
    "DisplayDataChangedFcn", @(~, evt) obj.onDatasetsSorted(evt), ...
    "ContextMenu", uicontextmenu(obj.Fig));
uimenu(obj.DatasetsTable.ContextMenu, "Text", "Clear sort", "MenuSelectedFcn", @(~,~) obj.clearDatasetsSort());
uimenu(obj.DatasetsTable.ContextMenu, "Text", "Variables...", "Separator", "on", ...
    "Tooltip", "Record values (probe depth, dose, cohort...) on the datasets of the selected rows (the active one when none is selected): a row per dataset, a column per variable. Every change is kept in the manifest.", ...
    "MenuSelectedFcn", @(~,~) obj.onEditVariables());
uimenu(obj.DatasetsTable.ContextMenu, "Text", "View manifest...", ...
    "Tooltip", "Open the active dataset's manifest in the manifest viewer: how it was processed, its variables and their history.", ...
    "MenuSelectedFcn", @(~,~) obj.onViewManifest());
obj.DatasetsTable.Layout.Row = 10; obj.DatasetsTable.Layout.Column = [1 4];
hint = uilabel(left, "Text", "Tick Run for the datasets to run, ★ to star one, ✎ for its notes, a Variables cell to record values on it; click a row to make it the active dataset. Right-click the table for more.", ...
    "FontColor", [0.35 0.35 0.35], "Tooltip", "Tick Run for the datasets to run, ★ to star one (a favorite), click ✎ for its notes; " + ...
    "click a Variables cell to record values on it (probe depth, dose...); click a row to make it the active dataset (Alignment and Figures preview it). " + ...
    "Right-click the table to clear its sort, edit the variables of the selected rows or view the manifest.");
hint.Layout.Row = 11; hint.Layout.Column = [1 4];

right = uipanel(g, "Title", "Active dataset");
rg = uigridlayout(right, [6 1]);
rg.RowHeight = {'fit', '1x', '1x', 'fit', '1x', '1x'};
obj.MemoryLabel = uilabel(rg, "Text", "No dataset selected.", "WordWrap", "on");
obj.InventoryTable = uitable(rg, "RowName", {}, "ColumnName", {'Kind', 'Exists', 'Source', 'File'}, ...
    "ColumnWidth", {70, 50, 80, 'auto'}, "ColumnSortable", true);
obj.LinesTable = uitable(rg, "RowName", {}, ...
    "ColumnName", {'Line', 'Count', 'Mean length (s)', 'First (s)', 'Last (s)', 'Inverted', 'Derived from'}, "ColumnWidth", 'auto', "ColumnSortable", true, ...
    "Tooltip", "Derived from: a derived event's definition (the pipeline's Behavior.DerivedEvents), blank for a recorded line.");
obj.BehaviorLabel = uilabel(rg, "Text", "", "WordWrap", "on");
obj.ParamsTable = uitable(rg, "RowName", {}, "ColumnName", {'Parameter', 'Values'}, "ColumnWidth", {120, 'auto'}, "ColumnSortable", true);
obj.UnitsTable = uitable(rg, "RowName", {}, "ColumnName", {'Class', 'Shank', 'Units', 'Spikes'}, "ColumnWidth", 'auto', "ColumnSortable", true);
end


function filterChanged(obj)
%filterChanged  A filter control changed: the table shows what passes, and the config holds the filter.
obj.refreshDatasetsTable();
obj.onConfigChanged("filter");
end


function l = lab(parent, txt, row, col)
l = uilabel(parent, "Text", txt);
l.Layout.Row = row;
l.Layout.Column = col;
end
