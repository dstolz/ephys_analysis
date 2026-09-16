function buildProjectTab(obj)
%buildProjectTab  Config name, project root / output root, dataset table,
%   selection helpers and the Epsych2 behavior association panel.
%   The dataset table's Select column is the config's dataset selection
%   (Project.Selection / Project.Datasets); the Behavior panel edits the
%   config's Behavior section and associates session files per dataset.

g = uigridlayout(obj.TabProject, [5 8]);
g.RowHeight    = {'fit', 'fit', 'fit', '1x', 'fit'};
g.ColumnWidth  = {'fit', '1x', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit'};
g.Padding      = [10 10 10 10];
changed = @(~,~) obj.onConfigChanged();

% Row 1: config name + description
lbl = uilabel(g, "Text", "Config name:");
lbl.Layout.Row = 1; lbl.Layout.Column = 1;
obj.ConfigNameField = uieditfield(g, "text", "Value", "Untitled", ...
    "Tooltip", "Name of this pipeline configuration (saved in the JSON).", ...
    "ValueChangedFcn", changed);
obj.ConfigNameField.Layout.Row = 1; obj.ConfigNameField.Layout.Column = 2;
lbl = uilabel(g, "Text", "Description:");
lbl.Layout.Row = 1; lbl.Layout.Column = 3;
obj.ConfigDescField = uieditfield(g, "text", "Placeholder", "optional", ...
    "ValueChangedFcn", changed);
obj.ConfigDescField.Layout.Row = 1; obj.ConfigDescField.Layout.Column = [4 8];

% Row 2: project root
lbl = uilabel(g, "Text", "Project root:");
lbl.Layout.Row = 2; lbl.Layout.Column = 1;
obj.RootPathField = uieditfield(g, "text", ...
    "Placeholder", "Folder scanned recursively for recordings", ...
    "ValueChangedFcn", changed);
obj.RootPathField.Layout.Row = 2; obj.RootPathField.Layout.Column = 2;
obj.BrowseRootButton = uibutton(g, "Text", "Browse...", ...
    "ButtonPushedFcn", @(~,~) obj.onBrowseRoot());
obj.BrowseRootButton.Layout.Row = 2; obj.BrowseRootButton.Layout.Column = 3;
obj.ScanButton = uibutton(g, "Text", "Scan", "FontWeight", "bold", ...
    "ButtonPushedFcn", @(~,~) obj.onScan());
obj.ScanButton.Layout.Row = 2; obj.ScanButton.Layout.Column = 4;
obj.RefreshMetaButton = uibutton(g, "Text", "Refresh metadata", ...
    "ButtonPushedFcn", @(~,~) obj.onRefreshMetadata());
obj.RefreshMetaButton.Layout.Row = 2; obj.RefreshMetaButton.Layout.Column = 5;
obj.LaunchPhyButton = uibutton(g, "Text", "Open in phy", ...
    "ButtonPushedFcn", @(~,~) obj.onLaunchPhy(), "Enable", "off", ...
    "Tooltip", "Launch phy template-gui on the selected dataset's sorted output.");
obj.LaunchPhyButton.Layout.Row = 2; obj.LaunchPhyButton.Layout.Column = 6;
obj.SelectAllButton = uibutton(g, "Text", "All", "Tooltip", "Tick every dataset", ...
    "ButtonPushedFcn", @(~,~) obj.onSelectDatasets("all"));
obj.SelectAllButton.Layout.Row = 2; obj.SelectAllButton.Layout.Column = 7;
obj.SelectNoneButton = uibutton(g, "Text", "None", "Tooltip", "Untick every dataset (= run all)", ...
    "ButtonPushedFcn", @(~,~) obj.onSelectDatasets("none"));
obj.SelectNoneButton.Layout.Row = 2; obj.SelectNoneButton.Layout.Column = 8;

% Row 3: output root + status
lbl = uilabel(g, "Text", "Output root:", "Tooltip", ...
    "Per-dataset outputs (kilosort4/, *_extract[_LFP|_MUA|_SPIKE|_AUX].mat, *_spikes.mat, exports) go under <root>/<Name>. Blank = next to each recording.");
lbl.Layout.Row = 3; lbl.Layout.Column = 1;
obj.OutputRootField = uieditfield(g, "text", ...
    "Placeholder", "blank = next to each recording", "ValueChangedFcn", changed);
obj.OutputRootField.Layout.Row = 3; obj.OutputRootField.Layout.Column = 2;
obj.BrowseOutputButton = uibutton(g, "Text", "Browse...", ...
    "ButtonPushedFcn", @(~,~) obj.onBrowseOutput());
obj.BrowseOutputButton.Layout.Row = 3; obj.BrowseOutputButton.Layout.Column = 3;
obj.ScanStatusLabel = uilabel(g, "Text", "No datasets scanned yet.", "FontColor", [0.4 0.4 0.4]);
obj.ScanStatusLabel.Layout.Row = 3; obj.ScanStatusLabel.Layout.Column = [4 8];

% Row 4: datasets table
obj.DatasetsTable = uitable(g);
obj.DatasetsTable.Layout.Row = 4; obj.DatasetsTable.Layout.Column = [1 8];
% Trailing "DatasetIdx" is a hidden bookkeeping column (see refreshDatasetsTable)
% that maps a table row back to its position in obj.Project.Datasets.
obj.DatasetsTable.ColumnName = {'Select', 'Name', 'Key', 'Acq date', '# chan', 'Fs (Hz)', ...
    'Duration (min)', 'Format', 'Probe', 'Exclude', 'Sorting', 'Behavior', ''};
obj.DatasetsTable.ColumnEditable = [true false(1, 11) false];
obj.DatasetsTable.ColumnSortable = [true(1, 12) false];
obj.DatasetsTable.CellSelectionCallback = @(~,evt) obj.onDatasetCellSelection(evt);
obj.DatasetsTable.CellEditCallback = @(~,~) obj.onConfigChanged();
obj.DatasetsTable.ColumnWidth = {50, 110, 150, 120, 55, 70, 90, 110, 100, 70, 130, 130, 1};

% Row 5: behavior (Epsych2) panel
bp = uipanel(g, "Title", "Behavior: Epsych2 session files (associated per dataset, saved in the manifest)");
bp.Layout.Row = 5; bp.Layout.Column = [1 8];
bg = uigridlayout(bp, [2 9]);
bg.RowHeight   = {'fit', 'fit'};
bg.ColumnWidth = {'fit', '1x', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit'};

obj.BehEnableCheckBox = uicheckbox(bg, "Text", "Match sessions as a pipeline step", ...
    "Tooltip", "When on, the run looks for an Epsych2 session for each dataset that has none.", ...
    "ValueChangedFcn", changed);
obj.BehEnableCheckBox.Layout.Row = 1; obj.BehEnableCheckBox.Layout.Column = 1;
obj.BehSearchDirsField = uieditfield(bg, "text", ...
    "Placeholder", "folders searched recursively for Epsych2 .mat files; separate with ;", ...
    "ValueChangedFcn", changed);
obj.BehSearchDirsField.Layout.Row = 1; obj.BehSearchDirsField.Layout.Column = [2 5];
obj.BehBrowseButton = uibutton(bg, "Text", "Add folder...", ...
    "ButtonPushedFcn", @(~,~) obj.onBrowseBehaviorDir());
obj.BehBrowseButton.Layout.Row = 1; obj.BehBrowseButton.Layout.Column = 6;
lbl = uilabel(bg, "Text", "Match:"); lbl.Layout.Row = 1; lbl.Layout.Column = 7;
obj.BehMatchDropDown = uidropdown(bg, "Items", {'prefix, then time', 'prefix only', 'time only'}, ...
    "ItemsData", {'prefix-then-time', 'prefix', 'time'}, "Value", 'prefix-then-time', ...
    "Tooltip", "prefix: the recording name starts with the session file stem (how Epsych2 names RHX recordings); time: nearest start time.", ...
    "ValueChangedFcn", changed);
obj.BehMatchDropDown.Layout.Row = 1; obj.BehMatchDropDown.Layout.Column = 8;
obj.BehMaxOffsetField = uieditfield(bg, "numeric", "Value", 30, "Limits", [0 Inf], ...
    "LowerLimitInclusive", "off", "ValueDisplayFormat", "%g min", ...
    "Tooltip", "Time matching: maximum |session start - recording start|.", ...
    "ValueChangedFcn", changed);
obj.BehMaxOffsetField.Layout.Row = 1; obj.BehMaxOffsetField.Layout.Column = 9;

obj.BehFindButton = uibutton(bg, "Text", "Find sessions for selected", ...
    "Tooltip", "Search the folders above and associate a session with each selected dataset that has none.", ...
    "ButtonPushedFcn", @(~,~) obj.onRunStep("behavior"));
obj.BehFindButton.Layout.Row = 2; obj.BehFindButton.Layout.Column = 1;
obj.BehStatusLabel = uilabel(bg, "Text", "", "FontColor", [0.4 0.4 0.4]);
obj.BehStatusLabel.Layout.Row = 2; obj.BehStatusLabel.Layout.Column = [2 4];
obj.BehWriteFileCheckBox = uicheckbox(bg, "Text", "Write behavior .mat", "Value", true, ...
    "Tooltip", "The behavior step saves each associated session once as <name>_behavior.mat in the dataset's output folder.", ...
    "ValueChangedFcn", changed);
obj.BehWriteFileCheckBox.Layout.Row = 2; obj.BehWriteFileCheckBox.Layout.Column = 5;
obj.BehOverwriteCheckBox = uicheckbox(bg, "Text", "Re-match existing", ...
    "Tooltip", "Also re-match datasets that already have a session file.", ...
    "ValueChangedFcn", changed);
obj.BehOverwriteCheckBox.Layout.Row = 2; obj.BehOverwriteCheckBox.Layout.Column = 6;
obj.BehAssociateButton = uibutton(bg, "Text", "Associate file...", ...
    "Tooltip", "Pick an Epsych2 session .mat for the dataset selected in the table.", ...
    "ButtonPushedFcn", @(~,~) obj.onAssociateBehavior());
obj.BehAssociateButton.Layout.Row = 2; obj.BehAssociateButton.Layout.Column = [7 8];
obj.BehClearButton = uibutton(bg, "Text", "Clear", ...
    "Tooltip", "Remove the session association of the selected dataset.", ...
    "ButtonPushedFcn", @(~,~) obj.onClearBehavior());
obj.BehClearButton.Layout.Row = 2; obj.BehClearButton.Layout.Column = 9;
end
