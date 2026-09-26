function buildProjectTab(obj)
%buildProjectTab  Config name, project root / output root, name pattern,
%   dataset table, selection helpers, the Tools panel beside the table (the
%   datasets in the manifest viewer, the analysis app, phy or the file
%   browser), the Source settings panel under it (the reader options of the
%   active dataset's recording system: Open Ephys, TDT; see
%   syncSourcePanel) and the Epsych2 behavior association panel.
%   The dataset table's Select column is the config's dataset selection
%   (Project.Selection / Project.Datasets); the Behavior panel edits the
%   config's Behavior section and associates session files per dataset.

g = uigridlayout(obj.TabProject, [5 1]);
g.RowHeight   = {'fit', 'fit', '1x', 'fit', 'fit'};
g.ColumnWidth = {'1x'};
g.Padding     = [10 10 10 10];
g.RowSpacing  = 8;
changed = @(~,~) obj.onConfigChanged();

% --- rows 1-4: config name / project root / output root / name pattern
top = uigridlayout(g, [4 8]);
top.Layout.Row = 1;
top.RowHeight   = {'fit', 30, 'fit', 'fit'};
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
obj.ScanButton = uibutton(top, "Text", "Scan", ...
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
    "Tokens parsed from each dataset name. {Token} = any text, {Token:yyMMdd} or {Token:yyyy-MM-dd} = that many digits (separators matched literally), {Token:regex} = a regular expression, * = ignored text. Open Ephys session folders: " + OpenEphysReader.DefaultNamePattern);
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
tb = uigridlayout(g, [1 5]);
tb.Layout.Row = 2;
tb.RowHeight   = {30};
tb.ColumnWidth = {'fit', 60, 60, 'fit', '1x'};
tb.Padding     = [0 0 0 0];
lbl = uilabel(tb, "Text", "Datasets", "FontWeight", "bold");
lbl.Layout.Column = 1;
obj.SelectAllButton = uibutton(tb, "Text", "All", "Tooltip", "Tick every shown dataset", ...
    "ButtonPushedFcn", @(~,~) obj.onSelectDatasets("all"));
obj.SelectAllButton.Layout.Column = 2;
obj.SelectNoneButton = uibutton(tb, "Text", "None", "Tooltip", "Untick every dataset, shown or filtered out (= run all)", ...
    "ButtonPushedFcn", @(~,~) obj.onSelectDatasets("none"));
obj.SelectNoneButton.Layout.Column = 3;
% One filter dropdown per name-pattern token (see syncTokenFilters).
obj.NameTokenFilterGrid = uigridlayout(tb, [1 1]);
obj.NameTokenFilterGrid.Layout.Column = 4;
obj.NameTokenFilterGrid.RowHeight = {'fit'};
obj.NameTokenFilterGrid.ColumnWidth = {'fit'};
obj.NameTokenFilterGrid.Padding   = [12 0 0 0];
obj.ScanStatusLabel = uilabel(tb, "Text", "No datasets scanned yet.", "FontColor", [0.4 0.4 0.4], ...
    "HorizontalAlignment", "right");
obj.ScanStatusLabel.Layout.Column = 5;

% --- row 3: datasets table, and the Tools panel beside it --------------------
% Columns (headers, widths, the trailing hidden "DatasetIdx" that maps a row
% back to obj.Project.Datasets) are laid out by refreshDatasetsTable. Headers
% can be dragged into a new order, which refreshes keep.
mid = uigridlayout(g, [1 2]);
mid.Layout.Row = 3;
mid.RowHeight   = {'1x'};
mid.ColumnWidth = {'1x', 190};
mid.Padding     = [0 0 0 0];
obj.DatasetsTable = uitable(mid, "ColumnRearrangeable", "on");
obj.DatasetsTable.Layout.Row = 1; obj.DatasetsTable.Layout.Column = 1;
buildToolsPanel(obj, mid);
% Clicking a row makes its dataset the active one (highlighted; see selectDataset).
obj.DatasetsTable.CellSelectionCallback = @(~,evt) obj.onDatasetCellSelection(evt);
% Select is the only editable column: a tick changes the selection and the Dataset menu.
obj.DatasetsTable.CellEditCallback = @(~,~) ticksEdited(obj);

% --- row 4: source settings of the active dataset's recording system ---------
buildSourcePanel(obj, g);

% --- row 5: behavior (Epsych2) panel -----------------------------------------
bp = uipanel(g, "Title", "Behavior: Epsych2 session files (associated per dataset, saved in the manifest)");
bp.Layout.Row = 5;
bg = uigridlayout(bp, [2 9]);
bg.RowHeight   = {'fit', 30};
bg.ColumnWidth = {'fit', 'fit', 460, 'fit', 'fit', 'fit', 'fit', '1x', 'fit'};

obj.BehEnableCheckBox = uicheckbox(bg, "Text", "Behavior as a pipeline step", ...
    "Tooltip", "When on, the run's behavior step pairs the trials of each dataset's session and writes its behavior file, first looking for a session for each dataset that has none (Search).", ...
    "ValueChangedFcn", changed);
obj.BehEnableCheckBox.Layout.Row = 1; obj.BehEnableCheckBox.Layout.Column = 1;
obj.BehSearchCheckBox = uicheckbox(bg, "Text", "Search", "Value", true, ...
    "Tooltip", "Look in these folders for a session for each dataset that has none. Off: the step uses only the sessions already associated (Associate file..., or the one in the recording folder).", ...
    "ValueChangedFcn", changed);
obj.BehSearchCheckBox.Layout.Row = 1; obj.BehSearchCheckBox.Layout.Column = 2;
obj.BehSearchDirsField = uieditfield(bg, "text", ...
    "Placeholder", "folders searched recursively for Epsych2 .mat files; separate with ;", ...
    "ValueChangedFcn", changed);
obj.BehSearchDirsField.Layout.Row = 1; obj.BehSearchDirsField.Layout.Column = 3;
obj.BehBrowseButton = uibutton(bg, "Text", "Add folder...", ...
    "ButtonPushedFcn", @(~,~) obj.onBrowseBehaviorDir());
obj.BehBrowseButton.Layout.Row = 1; obj.BehBrowseButton.Layout.Column = 4;
lbl = uilabel(bg, "Text", "Match:"); lbl.Layout.Row = 1; lbl.Layout.Column = 5;
obj.BehMatchDropDown = uidropdown(bg, "Items", {'prefix, then time', 'prefix only', 'time only'}, ...
    "ItemsData", {'prefix-then-time', 'prefix', 'time'}, "Value", 'prefix-then-time', ...
    "Tooltip", "prefix: the recording name starts with the session file stem (how Epsych2 names RHX recordings); time: nearest start time.", ...
    "ValueChangedFcn", changed);
obj.BehMatchDropDown.Layout.Row = 1; obj.BehMatchDropDown.Layout.Column = 6;
obj.BehMaxOffsetField = uieditfield(bg, "numeric", "Value", 30, "Limits", [0 Inf], ...
    "LowerLimitInclusive", "off", "ValueDisplayFormat", "%g min", ...
    "Tooltip", "Time matching: maximum |session start - recording start|.", ...
    "ValueChangedFcn", changed);
obj.BehMaxOffsetField.Layout.Row = 1; obj.BehMaxOffsetField.Layout.Column = 7;

% Its text and tooltip follow Behavior.Search (syncStepEnableStates).
obj.BehFindButton = uibutton(bg, "Text", "Find sessions for selected", ...
    "ButtonPushedFcn", @(~,~) obj.onRunStep("behavior"));
obj.BehFindButton.Layout.Row = 2; obj.BehFindButton.Layout.Column = [1 2];
bb = uigridlayout(bg, [1 4]);
bb.Layout.Row = 2; bb.Layout.Column = [3 7];
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
obj.BehStatusLabel.Layout.Row = 2; obj.BehStatusLabel.Layout.Column = [8 9];
end


function ticksEdited(obj)
obj.refreshDatasetMenu();
obj.onConfigChanged();
end


function buildSourcePanel(obj, parent)
%buildSourcePanel  The reader options of the active dataset's recording system.
%   One row per system with settings (Open Ephys, TDT) and a note row; only
%   the row of the active dataset's system shows (syncSourcePanel). The
%   options are the config's Acquisition section, so they apply to every
%   dataset of that system in the project; a change rescans the project
%   (onAcquisitionChanged).
obj.SourcePanel = uipanel(parent, "Title", "Source settings");
obj.SourcePanel.Layout.Row = 4;
obj.SourceGrid = uigridlayout(obj.SourcePanel, [3 1]);
obj.SourceGrid.RowHeight   = {'fit', 0, 0};
obj.SourceGrid.ColumnWidth = {'1x'};
obj.SourceGrid.RowSpacing  = 0;
obj.SourceGrid.Padding     = [8 4 8 4];
obj.SourceNoteLabel = uilabel(obj.SourceGrid, "Text", "Scan a project first.", "FontColor", [0.4 0.4 0.4]);
obj.SourceNoteLabel.Layout.Row = 1;
changed = @(~,~) obj.onAcquisitionChanged();
scope = " Applies to every %s in the project; a change rescans it.";

% --- Open Ephys: Acquisition.OpenEphys -----------------------------------------
oe = uigridlayout(obj.SourceGrid, [1 6]);
oe.Layout.Row = 2;
oe.RowHeight   = {'fit'};
oe.ColumnWidth = {230, 'fit', 90, 'fit', 180, '1x'};
oe.Padding     = [0 0 0 0];
oe.Visible     = "off";
obj.SourceOEGrid = oe;
obj.OERecordingsDropDown = uidropdown(oe, ...
    "Items", {'join recordings (one dataset)', 'one dataset per recording', 'single recording only'}, ...
    "ItemsData", {'concatenate', 'separate', 'single'}, "Value", 'concatenate', ...
    "Tooltip", ["A session with several recordings (recording stopped and restarted, or acquisition restarted):" ...
        "join: one dataset, the recordings end to end" ...
        "one dataset per recording: a part folder per recording inside the session folder (created by the scan), named from its start time" ...
        "single: a session must hold one recording" ...
        sprintf(strtrim(scope), "Open Ephys session")], ...
    "ValueChangedFcn", changed);
obj.OERecordingsDropDown.Layout.Column = 1;
lbl = uilabel(oe, "Text", "Record node:", "HorizontalAlignment", "right");
lbl.Layout.Column = 2;
obj.OERecordNodeField = uieditfield(oe, "text", "Placeholder", "automatic", ...
    "Tooltip", "Record Node id to read (e.g. 101). Blank: the only one, or the lowest id when a session has several." ...
        + sprintf(scope, "Open Ephys session"), ...
    "ValueChangedFcn", changed);
obj.OERecordNodeField.Layout.Column = 3;
lbl = uilabel(oe, "Text", "Stream:", "HorizontalAlignment", "right");
lbl.Layout.Column = 4;
obj.OEStreamField = uieditfield(oe, "text", "Placeholder", "automatic", ...
    "Tooltip", "Continuous stream to read (its name, e.g. Rhythm Data). Blank: the stream with the most headstage channels." ...
        + sprintf(scope, "Open Ephys session"), ...
    "ValueChangedFcn", changed);
obj.OEStreamField.Layout.Column = 5;

% --- TDT: Acquisition.TDT --------------------------------------------------------
td = uigridlayout(obj.SourceGrid, [1 5]);
td.Layout.Row = 3;
td.RowHeight   = {'fit'};
td.ColumnWidth = {'fit', 180, 'fit', 110, '1x'};
td.Padding     = [0 0 0 0];
td.Visible     = "off";
obj.SourceTDTGrid = td;
lbl = uilabel(td, "Text", "Stream:", "HorizontalAlignment", "right");
lbl.Layout.Column = 1;
obj.TDTStreamDropDown = uidropdown(td, "Items", {'automatic'}, "Value", 'automatic', "Editable", "on", ...
    "Tooltip", "The stream store read as the amplifier channels (pick one of the active block's, or type a name). automatic: the stream with the most channels, the highest rate among those." ...
        + sprintf(scope, "TDT block"), ...
    "ValueChangedFcn", changed);
obj.TDTStreamDropDown.Layout.Column = 2;
lbl = uilabel(td, "Text", "Gain (µV per unit):", "HorizontalAlignment", "right");
lbl.Layout.Column = 3;
obj.TDTGainField = uieditfield(td, "text", "Placeholder", "automatic", ...
    "Tooltip", "Microvolts per stored value. Blank: 1e6 for float streams (TDT stores them in volts). A stream stored as integers needs it: the block does not record its scale." ...
        + sprintf(scope, "TDT block"), ...
    "ValueChangedFcn", changed);
obj.TDTGainField.Layout.Column = 4;
obj.TDTStatusLabel = uilabel(td, "Text", "", "FontColor", [0.4 0.4 0.4]);
obj.TDTStatusLabel.Layout.Column = 5;
end


function buildToolsPanel(obj, parent)
%buildToolsPanel  Open the active or the ticked datasets in another program.
%   The scope box chooses the datasets (toolTargets), the label names them
%   and each button opens them in one program (onOpenTool). Everything
%   is off until a scan (syncToolsPanel).
tp = uipanel(parent, "Title", "Tools");
tp.Layout.Row = 1; tp.Layout.Column = 2;
tg = uigridlayout(tp, [7 1]);
tg.RowHeight   = {'fit', 'fit', 30, 30, 30, 30, '1x'};
tg.ColumnWidth = {'1x'};
tg.RowSpacing  = 6;
tg.Padding     = [8 8 8 8];
obj.ToolsScopeDropDown = uidropdown(tg, "Items", {'Active dataset', 'Ticked datasets'}, ...
    "ItemsData", {'active', 'ticked'}, "Value", 'active', ...
    "Tooltip", ["What the buttons below open:" ...
        "Active dataset: the highlighted row" ...
        "Ticked datasets: the ticked rows, or every dataset when none is ticked"], ...
    "ValueChangedFcn", @(~,~) obj.syncToolsPanel());
obj.ToolsTargetLabel = uilabel(tg, "Text", "Scan a project first.", "WordWrap", "on", ...
    "FontColor", [0.4 0.4 0.4]);
obj.ToolsManifestButton = uibutton(tg, "Text", "Manifest viewer", "Enable", "off", ...
    "Tooltip", "Open each dataset's <Name>_manifest.json in the manifest viewer, a window each.", ...
    "ButtonPushedFcn", @(~,~) obj.onOpenTool("manifest"));
obj.ToolsAnalysisButton = uibutton(tg, "Text", "Analysis app", "Enable", "off", ...
    "Tooltip", "Open the analysis app (PSTHs, rasters, evoked potentials, rates, tuning, probe maps) on these datasets' outputs, all in one window.", ...
    "ButtonPushedFcn", @(~,~) obj.onOpenTool("analysis"));
obj.ToolsPhyButton = uibutton(tg, "Text", "phy", "Enable", "off", ...
    "Tooltip", "Launch phy template-gui on each dataset's sorted output (the ones with a params.py), a window each.", ...
    "ButtonPushedFcn", @(~,~) obj.onOpenTool("phy"));
obj.ToolsFolderButton = uibutton(tg, "Text", "Output folder", "Enable", "off", ...
    "Tooltip", "Open each dataset's output folder in the file browser.", ...
    "ButtonPushedFcn", @(~,~) obj.onOpenTool("folder"));
end
