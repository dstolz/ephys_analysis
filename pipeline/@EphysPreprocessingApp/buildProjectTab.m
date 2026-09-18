function buildProjectTab(obj)
%buildProjectTab  Config name, project root / output root, dataset table,
%   selection helpers and the Epsych2 behavior association panel.
%   The dataset table's Select column is the config's dataset selection
%   (Project.Selection / Project.Datasets); the Behavior panel edits the
%   config's Behavior section and associates session files per dataset.

g = uigridlayout(obj.TabProject, [4 1]);
g.RowHeight   = {'fit', 'fit', '1x', 'fit'};
g.ColumnWidth = {'1x'};
g.Padding     = [10 10 10 10];
g.RowSpacing  = 8;
changed = @(~,~) obj.onConfigChanged();

% --- rows 1-3: config name / project root / output root ---------------------
top = uigridlayout(g, [4 8]);
top.Layout.Row = 1;
top.RowHeight   = {'fit', 'fit', 'fit', 'fit'};
top.ColumnWidth = {'fit', 460, 'fit', 'fit', 'fit', 'fit', 360, '1x'};
top.Padding     = [0 0 0 0];

lbl = uilabel(top, "Text", "Config name:");
lbl.Layout.Row = 1; lbl.Layout.Column = 1;
obj.ConfigNameField = uieditfield(top, "text", "Value", "Untitled", ...
    "Tooltip", "Name of this pipeline configuration (saved in the JSON).", ...
    "ValueChangedFcn", changed);
obj.ConfigNameField.Layout.Row = 1; obj.ConfigNameField.Layout.Column = 2;
lbl = uilabel(top, "Text", "Description:");
lbl.Layout.Row = 1; lbl.Layout.Column = 3;
obj.ConfigDescField = uieditfield(top, "text", "Placeholder", "optional", ...
    "ValueChangedFcn", changed);
obj.ConfigDescField.Layout.Row = 1; obj.ConfigDescField.Layout.Column = [4 7];
obj.ConfigDescField.Tooltip = "Free-text description saved in the config.";

lbl = uilabel(top, "Text", "Project root:");
lbl.Layout.Row = 2; lbl.Layout.Column = 1;
obj.RootPathField = uieditfield(top, "text", ...
    "Placeholder", "Folder scanned for recordings", ...
    "ValueChangedFcn", changed);
obj.RootPathField.Layout.Row = 2; obj.RootPathField.Layout.Column = 2;
obj.BrowseRootButton = uibutton(top, "Text", "Browse...", ...
    "ButtonPushedFcn", @(~,~) obj.onBrowseRoot());
obj.BrowseRootButton.Layout.Row = 2; obj.BrowseRootButton.Layout.Column = 3;
obj.RecursiveCheckBox = uicheckbox(top, "Text", "Recursive", "Value", true, ...
    "Tooltip", "Scan searches every sub-folder of the project root. Off: only the root and the folders directly in it.", ...
    "ValueChangedFcn", changed);
obj.RecursiveCheckBox.Layout.Row = 2; obj.RecursiveCheckBox.Layout.Column = 4;
obj.ScanButton = uibutton(top, "Text", "Scan", "FontWeight", "bold", "FontSize", 14, ...
    "BackgroundColor", [0.15 0.45 0.80], "FontColor", [1 1 1], ...
    "Tooltip", "Scan the project root for recordings.", ...
    "ButtonPushedFcn", @(~,~) obj.onScan());
obj.ScanButton.Layout.Row = 2; obj.ScanButton.Layout.Column = 5;
obj.RefreshMetaButton = uibutton(top, "Text", "Refresh metadata", ...
    "ButtonPushedFcn", @(~,~) obj.onRefreshMetadata());
obj.RefreshMetaButton.Layout.Row = 2; obj.RefreshMetaButton.Layout.Column = 6;

lbl = uilabel(top, "Text", "Output root:", "Tooltip", ...
    "Per-dataset outputs (kilosort4/, *_extract[_LFP|_MUA|_SPIKE|_AUX].mat, *_spikes.mat, exports) go under <root>/<Name>. Blank = next to each recording.");
lbl.Layout.Row = 3; lbl.Layout.Column = 1;
obj.OutputRootField = uieditfield(top, "text", ...
    "Placeholder", "blank = next to each recording", "ValueChangedFcn", changed);
obj.OutputRootField.Layout.Row = 3; obj.OutputRootField.Layout.Column = 2;
obj.BrowseOutputButton = uibutton(top, "Text", "Browse...", ...
    "ButtonPushedFcn", @(~,~) obj.onBrowseOutput());
obj.BrowseOutputButton.Layout.Row = 3; obj.BrowseOutputButton.Layout.Column = 3;

lbl = uilabel(top, "Text", "Name pattern:", "Tooltip", ...
    "Tokens parsed from each dataset name. {Token} = any text, {Token:yyMMdd} = that many digits, {Token:regex} = a regular expression, * = ignored text.");
lbl.Layout.Row = 4; lbl.Layout.Column = 1;
obj.NamePatternField = uieditfield(top, "text", ...
    "Value", EphysPipelineConfig.defaults("Project").NamePattern, ...
    "Tooltip", lbl.Tooltip, "ValueChangedFcn", @(~,~) obj.onNameTokensChanged());
obj.NamePatternField.Layout.Row = 4; obj.NamePatternField.Layout.Column = 2;
obj.NameTokenGrid = uigridlayout(top, [1 1]);
obj.NameTokenGrid.Layout.Row = 4; obj.NameTokenGrid.Layout.Column = [3 7];
obj.NameTokenGrid.RowHeight = {'fit'};
obj.NameTokenGrid.Padding   = [0 0 0 0];
obj.NameTokenStatusLabel = uilabel(top, "Text", "", "FontColor", [0.4 0.4 0.4]);
obj.NameTokenStatusLabel.Layout.Row = 4; obj.NameTokenStatusLabel.Layout.Column = 8;

% --- row 2: table toolbar ----------------------------------------------------
tb = uigridlayout(g, [1 6]);
tb.Layout.Row = 2;
tb.RowHeight   = {'fit'};
tb.ColumnWidth = {'fit', 60, 60, 'fit', 'fit', '1x'};
tb.Padding     = [0 0 0 0];
lbl = uilabel(tb, "Text", "Datasets", "FontWeight", "bold");
lbl.Layout.Column = 1;
obj.SelectAllButton = uibutton(tb, "Text", "All", "Tooltip", "Tick every shown dataset", ...
    "ButtonPushedFcn", @(~,~) obj.onSelectDatasets("all"));
obj.SelectAllButton.Layout.Column = 2;
obj.SelectNoneButton = uibutton(tb, "Text", "None", "Tooltip", "Untick every dataset, shown or filtered out (= run all)", ...
    "ButtonPushedFcn", @(~,~) obj.onSelectDatasets("none"));
obj.SelectNoneButton.Layout.Column = 3;
obj.LaunchPhyButton = uibutton(tb, "Text", "Open in phy", ...
    "ButtonPushedFcn", @(~,~) obj.onLaunchPhy(), "Enable", "off", ...
    "Tooltip", "Launch phy template-gui on the active dataset's sorted output (the highlighted row).");
obj.LaunchPhyButton.Layout.Column = 4;
% One filter dropdown per name-pattern token (see syncTokenFilters).
obj.NameTokenFilterGrid = uigridlayout(tb, [1 1]);
obj.NameTokenFilterGrid.Layout.Column = 5;
obj.NameTokenFilterGrid.RowHeight = {'fit'};
obj.NameTokenFilterGrid.ColumnWidth = {'fit'};
obj.NameTokenFilterGrid.Padding   = [12 0 0 0];
obj.ScanStatusLabel = uilabel(tb, "Text", "No datasets scanned yet.", "FontColor", [0.4 0.4 0.4], ...
    "HorizontalAlignment", "right");
obj.ScanStatusLabel.Layout.Column = 6;

% --- row 3: datasets table ---------------------------------------------------
% Columns (headers, widths, the trailing hidden "DatasetIdx" that maps a row
% back to obj.Project.Datasets) are laid out by refreshDatasetsTable. Headers
% can be dragged into a new order, which refreshes keep.
obj.DatasetsTable = uitable(g, "ColumnRearrangeable", "on");
obj.DatasetsTable.Layout.Row = 3;
% Clicking a row makes its dataset the active one (highlighted; see selectDataset).
obj.DatasetsTable.CellSelectionCallback = @(~,evt) obj.onDatasetCellSelection(evt);
% Select is the only editable column: a tick changes the selection and the Dataset menu.
obj.DatasetsTable.CellEditCallback = @(~,~) ticksEdited(obj);

% --- row 4: behavior (Epsych2) panel -----------------------------------------
bp = uipanel(g, "Title", "Behavior: Epsych2 session files (associated per dataset, saved in the manifest)");
bp.Layout.Row = 4;
bg = uigridlayout(bp, [2 8]);
bg.RowHeight   = {'fit', 'fit'};
bg.ColumnWidth = {'fit', 460, 'fit', 'fit', 'fit', 'fit', '1x', 'fit'};

obj.BehEnableCheckBox = uicheckbox(bg, "Text", "Match sessions as a pipeline step", ...
    "Tooltip", "When on, the run looks for an Epsych2 session for each dataset that has none.", ...
    "ValueChangedFcn", changed);
obj.BehEnableCheckBox.Layout.Row = 1; obj.BehEnableCheckBox.Layout.Column = 1;
obj.BehSearchDirsField = uieditfield(bg, "text", ...
    "Placeholder", "folders searched recursively for Epsych2 .mat files; separate with ;", ...
    "ValueChangedFcn", changed);
obj.BehSearchDirsField.Layout.Row = 1; obj.BehSearchDirsField.Layout.Column = 2;
obj.BehBrowseButton = uibutton(bg, "Text", "Add folder...", ...
    "ButtonPushedFcn", @(~,~) obj.onBrowseBehaviorDir());
obj.BehBrowseButton.Layout.Row = 1; obj.BehBrowseButton.Layout.Column = 3;
lbl = uilabel(bg, "Text", "Match:"); lbl.Layout.Row = 1; lbl.Layout.Column = 4;
obj.BehMatchDropDown = uidropdown(bg, "Items", {'prefix, then time', 'prefix only', 'time only'}, ...
    "ItemsData", {'prefix-then-time', 'prefix', 'time'}, "Value", 'prefix-then-time', ...
    "Tooltip", "prefix: the recording name starts with the session file stem (how Epsych2 names RHX recordings); time: nearest start time.", ...
    "ValueChangedFcn", changed);
obj.BehMatchDropDown.Layout.Row = 1; obj.BehMatchDropDown.Layout.Column = 5;
obj.BehMaxOffsetField = uieditfield(bg, "numeric", "Value", 30, "Limits", [0 Inf], ...
    "LowerLimitInclusive", "off", "ValueDisplayFormat", "%g min", ...
    "Tooltip", "Time matching: maximum |session start - recording start|.", ...
    "ValueChangedFcn", changed);
obj.BehMaxOffsetField.Layout.Row = 1; obj.BehMaxOffsetField.Layout.Column = 6;

obj.BehFindButton = uibutton(bg, "Text", "Find sessions for selected", ...
    "Tooltip", "Search the folders above and associate a session with each selected dataset that has none.", ...
    "ButtonPushedFcn", @(~,~) obj.onRunStep("behavior"));
obj.BehFindButton.Layout.Row = 2; obj.BehFindButton.Layout.Column = 1;
bb = uigridlayout(bg, [1 4]);
bb.Layout.Row = 2; bb.Layout.Column = [2 6];
bb.ColumnWidth = {'fit', 'fit', 'fit', 'fit'};
bb.Padding     = [0 0 0 0];
obj.BehAssociateButton = uibutton(bb, "Text", "Associate file...", ...
    "Tooltip", "Pick an Epsych2 session .mat for the dataset selected in the table.", ...
    "ButtonPushedFcn", @(~,~) obj.onAssociateBehavior());
obj.BehClearButton = uibutton(bb, "Text", "Clear", ...
    "Tooltip", "Remove the session association of the active dataset (the highlighted row).", ...
    "ButtonPushedFcn", @(~,~) obj.onClearBehavior());
obj.BehWriteFileCheckBox = uicheckbox(bb, "Text", "Write behavior .mat", "Value", true, ...
    "Tooltip", "The behavior step saves each associated session once as <name>_behavior.mat in the dataset's output folder.", ...
    "ValueChangedFcn", changed);
obj.BehOverwriteCheckBox = uicheckbox(bb, "Text", "Re-match existing", ...
    "Tooltip", "Also re-match datasets that already have a session file.", ...
    "ValueChangedFcn", changed);
obj.BehStatusLabel = uilabel(bg, "Text", "", "FontColor", [0.4 0.4 0.4]);
obj.BehStatusLabel.Layout.Row = 2; obj.BehStatusLabel.Layout.Column = [7 8];
end


function ticksEdited(obj)
obj.refreshDatasetMenu();
obj.onConfigChanged();
end
