function buildSortingTab(obj)
%buildSortingTab  Sorting step: Kilosort4, or a SpikeInterface sorter, on a .bin of the recording.
%   Edits the config's Sorting section (gatherSortingSection /
%   applySortingSection): the sorter (Sorting.Sorter: Kilosort4, or a
%   SpikeInterface sorter found in the Python env with "Find SpikeInterface
%   sorters", onFindSorters), Python paths, execution mode and, for
%   Kilosort4, every Kilosort4 parameter from
%   EphysPipelineConfig.kilosortParamSpec, with "Optimize for probe"
%   (onOptimizeKS4ForProbe) and "Reset to defaults" (onResetKS4Params)
%   above the parameters. For a SpikeInterface sorter those rows give way to
%   its parameters as JSON (SIPanel: Sorting.SIParams.<sorter>, seeded with
%   SpikeInterface's defaults, beside their descriptions; showSorterControls).
%   The "Bin folder" field (Sorting.BinDir, onBrowseBinDir) puts the sorting
%   .bin in a folder of its own instead of the dataset's output folder.
%   The right column shows the
%   selected dataset's sorted-output association (auto-discovered or pinned
%   with "Use folder..."), what phy did there (a lamp and a line, from
%   EphysDataset.phyStatus: not opened, opened, modified), runs the step,
%   and streams background run logs.

spec = EphysPipelineConfig.kilosortParamSpec();
groups = unique({spec.group}, 'stable');

nRows = 8;
for gi = 1:numel(groups)
    np = sum(strcmp({spec.group}, groups{gi}));
    nRows = nRows + 1 + ceil(np / 2);
end
nRows = nRows + 5;

g = uigridlayout(obj.TabSorting, [1 2]);
g.ColumnWidth = {720, '1x'};
g.Padding     = [10 10 10 10];
changed = @(~,~) obj.onConfigChanged();

% =================== left column: configuration ===================
cfg = uipanel(g, "Title", "Sorting settings (config: Sorting)");
cfg.Layout.Column = 1;
cg = uigridlayout(cfg, [nRows 5]);
cg.Scrollable  = "on";
cg.RowHeight   = repmat({26}, 1, nRows);
cg.ColumnWidth = {150, '1x', 150, '1x', 30};

r = 1;
obj.SortEnableCheckBox = uicheckbox(cg, "Text", "Enable the Sorting step (Kilosort4)", ...
    "FontWeight", "bold", "Value", false, "ValueChangedFcn", changed);
obj.SortEnableCheckBox.Layout.Row = r; obj.SortEnableCheckBox.Layout.Column = [1 3];
obj.SortSkipExistingCheckBox = uicheckbox(cg, "Text", "Skip datasets already sorted", ...
    "Value", false, "ValueChangedFcn", changed);
obj.SortSkipExistingCheckBox.Layout.Row = r; obj.SortSkipExistingCheckBox.Layout.Column = [4 5];

r = r + 1;
l = lab(cg, "Sorter:", r);
l.Tooltip = "Kilosort4 (run natively), or a SpikeInterface sorter installed in the Python env below.";
obj.SortSorterDropDown = uidropdown(cg, "Items", {'Kilosort4'}, "ItemsData", {'kilosort4'}, ...
    "Value", 'kilosort4', "ValueChangedFcn", @(~,~) obj.onSorterChanged());
obj.SortSorterDropDown.Layout.Row = r; obj.SortSorterDropDown.Layout.Column = [2 3];
obj.SIFindSortersButton = uibutton(cg, "Text", "Find SpikeInterface sorters", ...
    "Tooltip", ["List the SpikeInterface sorters installed in the Python env (Python exe / Conda env " ...
     "below), with their default parameters. The list is remembered."], ...
    "ButtonPushedFcn", @(~,~) obj.onFindSorters());
obj.SIFindSortersButton.Layout.Row = r; obj.SIFindSortersButton.Layout.Column = [4 5];

r = r + 1;
lab(cg, "Python exe:", r);
obj.PythonExeField = uieditfield(cg, "text", "Placeholder", "kilosort env python.exe", ...
    "ValueChangedFcn", @(~,~) pythonChanged(obj));
obj.PythonExeField.Layout.Row = r; obj.PythonExeField.Layout.Column = [2 4];
obj.BrowsePythonButton = uibutton(cg, "Text", "...", ...
    "ButtonPushedFcn", @(~,~) obj.onBrowsePython());
obj.BrowsePythonButton.Layout.Row = r; obj.BrowsePythonButton.Layout.Column = 5;

r = r + 1;
l = lab(cg, "Conda env:", r);
l.Tooltip = "Optional. When set, the pipeline runs via 'conda run -n <env>'. Leave blank if the Python exe above is already the kilosort env python.";
obj.CondaEnvField = uieditfield(cg, "text", "Placeholder", "optional (e.g. kilosort)", ...
    "ValueChangedFcn", changed);
obj.CondaEnvField.Layout.Row = r; obj.CondaEnvField.Layout.Column = 2;
l = lab(cg, "Execution:", r); l.Layout.Column = 3;
obj.ExecModeDropDown = uidropdown(cg);
obj.ExecModeDropDown.Items = {'Non-blocking (background)', 'Blocking (wait)'};
obj.ExecModeDropDown.ItemsData = {false, true};
obj.ExecModeDropDown.Value = false;
obj.ExecModeDropDown.ValueChangedFcn = changed;
obj.ExecModeDropDown.Layout.Row = r; obj.ExecModeDropDown.Layout.Column = [4 5];

r = r + 1;
l = lab(cg, "Phy command:", r);
l.Tooltip = "Command used to launch phy (a preference, not part of the config). Blank uses phy.exe from the 'phy' conda env (found next to the Python exe's conda install), else 'conda run -n phy phy'.";
obj.PhyCmdField = uieditfield(cg, "text", "Placeholder", "blank = default", ...
    "ValueChangedFcn", @(~,~) obj.savePreferences());
obj.PhyCmdField.Layout.Row = r; obj.PhyCmdField.Layout.Column = 2;
obj.DryRunCheckBox = uicheckbox(cg, "Text", "Dry run (write the run files only)", ...
    "ValueChangedFcn", changed);
obj.DryRunCheckBox.Layout.Row = r; obj.DryRunCheckBox.Layout.Column = [3 5];

r = r + 1;
l = lab(cg, "Bin folder:", r);
l.Tooltip = "Folder the .bin of each dataset is written to (<folder>/<Name>.bin and its .json sidecar), apart " + ...
    "from the other outputs: the .bin is as large as the recording, so this keeps it out of the output folders " + ...
    "you copy. Blank = the dataset's output folder (<output root>/<Name>).";
obj.SortBinDirField = uieditfield(cg, "text", "Placeholder", "blank = the project output root", ...
    "Tooltip", l.Tooltip, "ValueChangedFcn", changed);
obj.SortBinDirField.Layout.Row = r; obj.SortBinDirField.Layout.Column = [2 4];
obj.BrowseBinDirButton = uibutton(cg, "Text", "...", ...
    "Tooltip", "Choose the folder for the sorting .bin files.", ...
    "ButtonPushedFcn", @(~,~) obj.onBrowseBinDir());
obj.BrowseBinDirButton.Layout.Row = r; obj.BrowseBinDirButton.Layout.Column = 5;

r = r + 1;
note = uilabel(cg, "WordWrap", "on", "FontColor", [0.4 0.4 0.4], "Text", ...
    "Artifact silencing (manual periods always; automatic detection when enabled) is configured on the Artifacts tab, the way they are erased included; those periods are erased in the .bin Kilosort4 sorts.");
note.Layout.Row = r; note.Layout.Column = [1 5];
obj.SortNoteLabel = note;

% --- Kilosort4 parameters (from kilosortParamSpec), two per row ---
r = r + 1;
rKS4 = r;   % first of the rows a SpikeInterface sorter's parameters take over
l = lab(cg, "Kilosort4 parameters", r);
l.FontWeight = "bold";
obj.KSOptimizeButton = uibutton(cg, "Text", "Optimize for probe", ...
    "Tooltip", ["Load the Kilosort4 parameters saved for the probe of the active dataset (the Dataset box " ...
     "on the right; else the default probe) from <probe>.ks4.json next to the probe map. " ...
     "When there is no such file, offers to generate one from the current parameters or from the probe layout."], ...
    "ButtonPushedFcn", @(~,~) obj.onOptimizeKS4ForProbe());
obj.KSOptimizeButton.Layout.Row = r; obj.KSOptimizeButton.Layout.Column = 2;
obj.KSResetButton = uibutton(cg, "Text", "Reset to defaults", ...
    "Tooltip", "Put every Kilosort4 parameter below back to its default and clear the extra settings JSON.", ...
    "ButtonPushedFcn", @(~,~) obj.onResetKS4Params());
obj.KSResetButton.Layout.Row = r; obj.KSResetButton.Layout.Column = 4;

obj.ParamControls = struct();
for gi = 1:numel(groups)
    gp = spec(strcmp({spec.group}, groups{gi}));
    r = r + 1;
    sep(cg, groups{gi}, r);
    for k = 1:numel(gp)
        s = gp(k);
        if mod(k, 2) == 1
            r = r + 1;
            lcol = 1;
        else
            lcol = 3;
        end
        l = lab(cg, [s.label ':'], r);
        l.Layout.Column = lcol;
        l.Tooltip = s.tip;
        ctrl = makeControl(cg, s, changed);
        ctrl.Layout.Row = r;
        ctrl.Layout.Column = lcol + 1;
        obj.ParamControls.(s.name) = ctrl;
    end
end

% --- free-form extra settings ---
r = r + 1;
l = uilabel(cg, "Text", "Extra settings (JSON):", "VerticalAlignment", "top");
l.Layout.Row = r; l.Layout.Column = 1;
l.Tooltip = "Any additional KS4 settings as JSON; these override the fields above.";
obj.ExtraSettingsArea = uitextarea(cg, "Value", {'{'; '}'}, ...
    "Placeholder", '{ "x_centers": 2 }', "ValueChangedFcn", changed);
obj.ExtraSettingsArea.Layout.Row = r; obj.ExtraSettingsArea.Layout.Column = [2 5];
cg.RowHeight{r} = 70;

r = r + 1;
obj.KSDocsLink = uihyperlink(cg, "Text", "Kilosort4 parameter docs", ...
    "URL", "https://kilosort.readthedocs.io/en/latest/parameters.html");
obj.KSDocsLink.Layout.Row = r; obj.KSDocsLink.Layout.Column = [2 3];

% Every control on those rows, hidden while a SpikeInterface sorter is chosen.
kids = cg.Children;
rows = arrayfun(@(c) c.Layout.Row(1), kids);
obj.KS4ParamWidgets = kids(rows >= rKS4 & rows <= r);
buildSIPanel(obj, cg, [rKS4 r]);

% =================== right column: results association + run + log ===================
right = uigridlayout(g, [2 1]);
right.Layout.Column = 2;
right.RowHeight = {'fit', '1x'};
right.Padding = [0 0 0 0];

resPanel = uipanel(right, "Title", "Sorted output");
rg = uigridlayout(resPanel, [5 4]);
rg.RowHeight   = {'fit', 'fit', 'fit', 30, 30};
rg.ColumnWidth = {'fit', 'fit', 'fit', '1x'};
l = uilabel(rg, "Text", "Dataset:");
l.Layout.Row = 1; l.Layout.Column = 1;
obj.SortDatasetDropDown = obj.datasetPicker(rg);
obj.SortDatasetDropDown.Layout.Row = 1; obj.SortDatasetDropDown.Layout.Column = [2 4];
obj.SortResultsLabel = uilabel(rg, "Text", "Scan a project first.", ...
    "WordWrap", "on", "FontColor", [0.3 0.3 0.3]);
obj.SortResultsLabel.Layout.Row = 2; obj.SortResultsLabel.Layout.Column = [1 4];
% What phy did in the sorted output (EphysDataset.phyStatus; refreshSortingLabel).
pg = uigridlayout(rg, [1 3]);
pg.Layout.Row = 3; pg.Layout.Column = [1 4];
pg.ColumnWidth = {20, '1x', 'fit'};
pg.RowHeight = {'fit'};
pg.Padding = [0 0 0 0];
obj.SortPhyLamp = uilamp(pg, "Color", [0.75 0.75 0.75], "Tooltip", ...
    "Grey: not opened in phy. Amber: opened in phy, or saved without a change. Green: modified in phy.");
obj.SortPhyLamp.Layout.Row = 1; obj.SortPhyLamp.Layout.Column = 1;
obj.SortPhyLabel = uilabel(pg, "Text", "", "WordWrap", "on");
obj.SortPhyLabel.Layout.Row = 1; obj.SortPhyLabel.Layout.Column = 2;
obj.SortPhyRefreshButton = uibutton(pg, "Text", "Refresh", ...
    "Tooltip", "Read the sorted-output folder again (after saving in phy).", ...
    "ButtonPushedFcn", @(~,~) obj.refreshSortingLabel());
obj.SortPhyRefreshButton.Layout.Row = 1; obj.SortPhyRefreshButton.Layout.Column = 3;
obj.SortUseFolderButton = uibutton(rg, "Text", "Use folder...", ...
    "Tooltip", "Pin a sorted (phy) results folder (e.g. sorted elsewhere or a curated copy); saved in the manifest.", ...
    "ButtonPushedFcn", @(~,~) obj.onUseSortingFolder());
obj.SortUseFolderButton.Layout.Row = 4; obj.SortUseFolderButton.Layout.Column = 1;
obj.SortUseAutoButton = uibutton(rg, "Text", "Use auto", ...
    "Tooltip", "Back to the run under <output root>/<Name>/kilosort4.", ...
    "ButtonPushedFcn", @(~,~) obj.onUseAutoSorting());
obj.SortUseAutoButton.Layout.Row = 4; obj.SortUseAutoButton.Layout.Column = 2;
obj.SortPhyButton = uibutton(rg, "Text", "Open in phy", ...
    "ButtonPushedFcn", @(~,~) obj.onLaunchPhy());
obj.SortPhyButton.Layout.Row = 4; obj.SortPhyButton.Layout.Column = 3;
obj.RunStepSortingButton = uibutton(rg, "Text", "Run this step", ...
    "Tooltip", "Run the Sorting step for the selected datasets (progress on the Run tab).", ...
    "ButtonPushedFcn", @(~,~) obj.onRunStep("sorting"));
obj.RunStepSortingButton.Layout.Row = 5; obj.RunStepSortingButton.Layout.Column = 1;
obj.KSProgressLabel = uilabel(rg, "Text", "Idle.", "FontColor", [0.4 0.4 0.4]);
obj.KSProgressLabel.Layout.Row = 5; obj.KSProgressLabel.Layout.Column = [2 4];

logPanel = uipanel(right, "Title", "Kilosort4 log (background runs stream here)");
obj.KSLogPanel = logPanel;
lg = uigridlayout(logPanel, [1 1]);
obj.KSLogArea = uitextarea(lg, "Editable", "off");

obj.refreshSorterItems();   % the sorters remembered from the last Find
end


function buildSIPanel(obj, cg, rows)
%buildSIPanel  A SpikeInterface sorter's parameters, over the Kilosort4 parameter ROWS of CG.
%   The JSON (Sorting.SIParams.<sorter>) on the left, what each parameter
%   is on the right (spikeinterface.sorters.get_sorter_params_description).
changed = @(~,~) obj.onConfigChanged();
obj.SIPanel = uipanel(cg, "BorderType", "none", "Visible", "off");
obj.SIPanel.Layout.Row = rows; obj.SIPanel.Layout.Column = [1 5];
sg = uigridlayout(obj.SIPanel, [4 2]);
sg.RowHeight = {30, 'fit', '1x', 22};
sg.ColumnWidth = {'3x', '2x'};
sg.Padding = [0 0 0 0];
head = uigridlayout(sg, [1 2]);
head.Layout.Row = 1; head.Layout.Column = [1 2];
head.ColumnWidth = {'1x', 150};
head.Padding = [0 0 0 0];
obj.SIParamsTitle = uilabel(head, "Text", "SpikeInterface sorter parameters", "FontWeight", "bold");
obj.SIResetButton = uibutton(head, "Text", "Reset to defaults", ...
    "Tooltip", "Put the sorter's parameters back to SpikeInterface's defaults.", ...
    "ButtonPushedFcn", @(~,~) obj.onResetSIParams());
obj.SIInfoLabel = uilabel(sg, "WordWrap", "on", "FontColor", [0.4 0.4 0.4], "Text", "");
obj.SIInfoLabel.Layout.Row = 2; obj.SIInfoLabel.Layout.Column = [1 2];
mono = get(groot, "FixedWidthFontName");
obj.SIParamsArea = uitextarea(sg, "FontName", mono, "Value", {'{'; '}'}, "ValueChangedFcn", changed, ...
    "Tooltip", ["The sorter's parameters as JSON, merged over SpikeInterface's defaults when it runs " ...
     "(nested objects key by key). Names the sorter does not have are dropped (the run's log says which)."]);
obj.SIParamsArea.Layout.Row = 3; obj.SIParamsArea.Layout.Column = 1;
obj.SIParamsHelpArea = uitextarea(sg, "Editable", "off", "Value", {''}, "FontColor", [0.25 0.25 0.25]);
obj.SIParamsHelpArea.Layout.Row = 3; obj.SIParamsHelpArea.Layout.Column = 2;
obj.SIDocsLink = uihyperlink(sg, "Text", "SpikeInterface sorter docs", ...
    "URL", "https://spikeinterface.readthedocs.io/en/stable/modules/sorters.html");
obj.SIDocsLink.Layout.Row = 4; obj.SIDocsLink.Layout.Column = 1;
end


function ctrl = makeControl(parent, s, changed)
%makeControl  Create the control for one parameter spec entry (no layout set).
switch s.kind
    case 'bool'
        ctrl = uicheckbox(parent, "Text", "", "Value", logical(s.default), "ValueChangedFcn", changed);
    case 'int'
        ctrl = uieditfield(parent, "numeric", "Value", s.default, ...
            "RoundFractionalValues", "on", "ValueChangedFcn", changed);
    case 'float'
        ctrl = uieditfield(parent, "numeric", "Value", s.default, "ValueChangedFcn", changed);
    otherwise   % 'floatinf', 'nullable', 'vector' -> free text
        ctrl = uieditfield(parent, "text", "Value", char(string(s.default)), "ValueChangedFcn", changed);
        if strcmp(s.kind, 'nullable')
            ctrl.Placeholder = "blank = auto/none";
        elseif strcmp(s.kind, 'floatinf')
            ctrl.Placeholder = "Infinity = off";
        end
end
ctrl.Tooltip = s.tip;
end


function l = lab(parent, txt, row)
l = uilabel(parent, "Text", txt);
l.Layout.Row = row;
l.Layout.Column = 1;
end


function sep(parent, txt, row)
l = uilabel(parent, "Text", txt, "FontWeight", "bold");
l.Layout.Row = row;
l.Layout.Column = [1 5];
end


function pythonChanged(obj)
%pythonChanged  Remember an existing python as the new-config default.
p = strtrim(string(obj.PythonExeField.Value));
if p ~= "" && isfile(p); AppPrefs.setpref(obj.PrefGroup, 'PythonExe', char(p)); end
obj.onConfigChanged();
end
