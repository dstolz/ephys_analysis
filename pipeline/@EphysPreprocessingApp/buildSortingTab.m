function buildSortingTab(obj)
%buildSortingTab  Sorting step: SpikeInterface preprocessing + Kilosort4.
%   Edits the config's Sorting section (gatherSortingSection /
%   applySortingSection): Python paths, execution mode, SpikeInterface
%   preprocessing and every Kilosort4 parameter from
%   EphysPipelineConfig.kilosortParamSpec, with "Optimize for probe"
%   (onOptimizeKS4ForProbe) and "Reset to defaults" (onResetKS4Params)
%   above the parameters. The right column shows the
%   selected dataset's sorted-output association (auto-discovered or pinned
%   with "Use folder..."), runs the step, and streams background run logs.

spec = EphysPipelineConfig.kilosortParamSpec();
groups = unique({spec.group}, 'stable');

nRows = 12;
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
obj.SortEnableCheckBox = uicheckbox(cg, "Text", "Enable the Sorting step (SpikeInterface + Kilosort4)", ...
    "FontWeight", "bold", "Value", false, "ValueChangedFcn", changed);
obj.SortEnableCheckBox.Layout.Row = r; obj.SortEnableCheckBox.Layout.Column = [1 3];
obj.SortSkipExistingCheckBox = uicheckbox(cg, "Text", "Skip datasets already sorted", ...
    "Value", false, "ValueChangedFcn", changed);
obj.SortSkipExistingCheckBox.Layout.Row = r; obj.SortSkipExistingCheckBox.Layout.Column = [4 5];

r = r + 1;
lab(cg, "Python exe:", r);
obj.PythonExeField = uieditfield(cg, "text", "Placeholder", "kilosort env python.exe", ...
    "ValueChangedFcn", changed);
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
l.Tooltip = "Command used to launch phy (a preference, not part of the config). Blank defaults to 'conda run -n phy phy'.";
obj.PhyCmdField = uieditfield(cg, "text", "Placeholder", "blank = default", ...
    "ValueChangedFcn", @(~,~) obj.savePreferences());
obj.PhyCmdField.Layout.Row = r; obj.PhyCmdField.Layout.Column = 2;
obj.DryRunCheckBox = uicheckbox(cg, "Text", "Dry run (write si_config.json + driver only)", ...
    "ValueChangedFcn", changed);
obj.DryRunCheckBox.Layout.Row = r; obj.DryRunCheckBox.Layout.Column = [3 5];

% --- Preprocessing (SpikeInterface) ---
r = r + 1;
sep(cg, "Preprocessing (SpikeInterface) - KS4 still filters + whitens internally", r);

r = r + 1;
obj.SIDetectBadCheckBox = uicheckbox(cg, "Text", "Detect bad channels (auto)", ...
    "Value", true, "Tooltip", ...
    ["Run spikeinterface.detect_bad_channels and drop dead/noisy channels " ...
     "before sorting. Detected channels are unioned with the manual Exclude list."], ...
    "ValueChangedFcn", @(~,~) obj.onSIControlsChanged());
obj.SIDetectBadCheckBox.Layout.Row = r; obj.SIDetectBadCheckBox.Layout.Column = [1 2];
l = lab(cg, "Action:", r); l.Layout.Column = 3;
obj.SIBadActionDropDown = uidropdown(cg);
obj.SIBadActionDropDown.Items = ["remove", "interpolate"];
obj.SIBadActionDropDown.Value = "remove";
set(obj.SIBadActionDropDown, "Tooltip", ...
    "Remove bad channels from the probe, or interpolate them from neighbours.", ...
    "ValueChangedFcn", @(~,~) obj.onSIControlsChanged());
obj.SIBadActionDropDown.Layout.Row = r; obj.SIBadActionDropDown.Layout.Column = 4;

r = r + 1;
lab(cg, "Detector method:", r);
obj.SIBadMethodDropDown = uidropdown(cg);
obj.SIBadMethodDropDown.Items = ["coherence+psd", "std", "mad", "neighborhood_r2"];
obj.SIBadMethodDropDown.Value = "coherence+psd";
obj.SIBadMethodDropDown.Tooltip = "spikeinterface.detect_bad_channels method.";
obj.SIBadMethodDropDown.ValueChangedFcn = @(~,~) obj.onSIControlsChanged();
obj.SIBadMethodDropDown.Layout.Row = r; obj.SIBadMethodDropDown.Layout.Column = [2 4];

r = r + 1;
obj.SICommonRefCheckBox = uicheckbox(cg, "Text", "Common reference (CMR/CAR)", ...
    "Value", false, "Tooltip", ...
    "Apply spikeinterface.common_reference across channels before sorting.", ...
    "ValueChangedFcn", @(~,~) obj.onSIControlsChanged());
obj.SICommonRefCheckBox.Layout.Row = r; obj.SICommonRefCheckBox.Layout.Column = [1 2];
l = lab(cg, "Operator:", r); l.Layout.Column = 3;
obj.SIRefOperatorDropDown = uidropdown(cg);
obj.SIRefOperatorDropDown.Items = ["median", "average"];
obj.SIRefOperatorDropDown.Value = "median";
obj.SIRefOperatorDropDown.ValueChangedFcn = @(~,~) obj.onSIControlsChanged();
obj.SIRefOperatorDropDown.Layout.Row = r; obj.SIRefOperatorDropDown.Layout.Column = 4;

r = r + 1;
obj.SIFilterCheckBox = uicheckbox(cg, "Text", ...
    "Bandpass filter in SpikeInterface (off = let KS4 filter)", ...
    "Value", false, "Tooltip", ...
    ["Filter in SpikeInterface instead of relying on KS4's internal high-pass. " ...
     "Off by default to avoid double-filtering."], ...
    "ValueChangedFcn", @(~,~) obj.onSIControlsChanged());
obj.SIFilterCheckBox.Layout.Row = r; obj.SIFilterCheckBox.Layout.Column = [1 5];

r = r + 1;
lab(cg, "Filter min (Hz):", r);
obj.SIFilterMinField = uieditfield(cg, "numeric", "Value", 300, "Limits", [0 Inf], ...
    "ValueChangedFcn", @(~,~) obj.onSIControlsChanged());
obj.SIFilterMinField.Layout.Row = r; obj.SIFilterMinField.Layout.Column = 2;
l = lab(cg, "Filter max (Hz):", r); l.Layout.Column = 3;
obj.SIFilterMaxField = uieditfield(cg, "numeric", "Value", 6000, "Limits", [0 Inf], ...
    "ValueChangedFcn", @(~,~) obj.onSIControlsChanged());
obj.SIFilterMaxField.Layout.Row = r; obj.SIFilterMaxField.Layout.Column = 4;

r = r + 1;
note = uilabel(cg, "WordWrap", "on", "FontColor", [0.4 0.4 0.4], "Text", ...
    "Artifact silencing (manual periods always; automatic detection when enabled) is configured on the Artifacts tab.");
note.Layout.Row = r; note.Layout.Column = [1 5];

% --- Kilosort4 parameters (from kilosortParamSpec), two per row ---
r = r + 1;
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
obj.SIDocsLink = uihyperlink(cg, "Text", "SpikeInterface docs", ...
    "URL", "https://spikeinterface.readthedocs.io/en/stable/");
obj.SIDocsLink.Layout.Row = r; obj.SIDocsLink.Layout.Column = [4 5];

% =================== right column: results association + run + log ===================
right = uigridlayout(g, [2 1]);
right.Layout.Column = 2;
right.RowHeight = {'fit', '1x'};
right.Padding = [0 0 0 0];

resPanel = uipanel(right, "Title", "Sorted output");
rg = uigridlayout(resPanel, [4 4]);
rg.RowHeight   = {'fit', 'fit', 'fit', 'fit'};
rg.ColumnWidth = {'fit', 'fit', 'fit', '1x'};
l = uilabel(rg, "Text", "Dataset:");
l.Layout.Row = 1; l.Layout.Column = 1;
obj.SortDatasetDropDown = obj.datasetPicker(rg);
obj.SortDatasetDropDown.Layout.Row = 1; obj.SortDatasetDropDown.Layout.Column = [2 4];
obj.SortResultsLabel = uilabel(rg, "Text", "Scan a project first.", ...
    "WordWrap", "on", "FontColor", [0.3 0.3 0.3]);
obj.SortResultsLabel.Layout.Row = 2; obj.SortResultsLabel.Layout.Column = [1 4];
obj.SortUseFolderButton = uibutton(rg, "Text", "Use folder...", ...
    "Tooltip", "Pin a Kilosort4 / phy results folder (e.g. sorted elsewhere or a curated copy); saved in the manifest.", ...
    "ButtonPushedFcn", @(~,~) obj.onUseSortingFolder());
obj.SortUseFolderButton.Layout.Row = 3; obj.SortUseFolderButton.Layout.Column = 1;
obj.SortUseAutoButton = uibutton(rg, "Text", "Use auto", ...
    "Tooltip", "Back to the run under <output root>/<Name>/kilosort4.", ...
    "ButtonPushedFcn", @(~,~) obj.onUseAutoSorting());
obj.SortUseAutoButton.Layout.Row = 3; obj.SortUseAutoButton.Layout.Column = 2;
obj.SortPhyButton = uibutton(rg, "Text", "Open in phy", ...
    "ButtonPushedFcn", @(~,~) obj.onLaunchPhy());
obj.SortPhyButton.Layout.Row = 3; obj.SortPhyButton.Layout.Column = 3;
obj.RunStepSortingButton = uibutton(rg, "Text", "Run this step", "FontWeight", "bold", ...
    "Tooltip", "Run the Sorting step for the selected datasets (progress on the Run tab).", ...
    "ButtonPushedFcn", @(~,~) obj.onRunStep("sorting"));
obj.RunStepSortingButton.Layout.Row = 4; obj.RunStepSortingButton.Layout.Column = 1;
obj.KSProgressLabel = uilabel(rg, "Text", "Idle.", "FontColor", [0.4 0.4 0.4]);
obj.KSProgressLabel.Layout.Row = 4; obj.KSProgressLabel.Layout.Column = [2 4];

logPanel = uipanel(right, "Title", "Kilosort4 log (background runs stream here)");
lg = uigridlayout(logPanel, [1 1]);
obj.KSLogArea = uitextarea(lg, "Editable", "off");

obj.syncSIEnableStates();
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
