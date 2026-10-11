function buildSyntheticTab(obj)
%buildSyntheticTab  Design, preview and write a synthetic dataset (makeSyntheticRecording).
%   Top: Preview (onSynthPreview) and Generate... (onSynthGenerate), and a
%   status line.
%   Left, scrolling: the built-in task (trials, scenario), the recording
%   (format, rate, channels, file length, seed, subject, sorted output,
%   artifacts, white noise, the 2 Hz sine), the units and the evoked
%   potentials (one table row each, see SyntheticDesign; Event, Edge and
%   Parameter are lists), and where it is written plus Load / Save design
%   (JSON).
%   Right: the preview of what Generate writes (same seed, same spikes):
%   the lines and spikes over a stretch of the recording, the chosen unit's
%   raster and PSTH around its event (the model's rate dashed), and the
%   chosen evoked potential around its event (single events, their mean
%   and the model) (renderSynthPreview). Every setting is kept as a
%   preference.

g = uigridlayout(obj.TabSynthetic, [3 2]);
g.RowHeight   = {30, 'fit', '1x'};
g.ColumnWidth = {560, '1x'};
g.Padding     = [10 10 10 10];
g.RowSpacing  = 6;
changed = @(~,~) obj.onSynthControlsChanged();

% --- row 1: actions ----------------------------------------------------------------
top = uigridlayout(g, [1 3]);
top.Layout.Row = 1; top.Layout.Column = [1 2];
top.ColumnWidth = {'fit', 'fit', '1x'};
top.RowHeight = {30};
top.ColumnSpacing = 6;
top.Padding = [0 0 0 0];
obj.SynthPreviewButton = uibutton(top, "Text", "Preview", ...
    "Tooltip", "Build the model (units, spikes, evoked potentials) from the settings and plot it. Generate writes exactly this (same seed).", ...
    "ButtonPushedFcn", @(~,~) obj.onSynthPreview());
obj.SynthGenerateButton = uibutton(top, "Text", "Generate...", ...
    "Tooltip", "Write the synthetic dataset (recording, Epsych2 session, ground-truth sorted output, manifest) under the output folder.", ...
    "ButtonPushedFcn", @(~,~) obj.onSynthGenerate());

% --- row 2: status -------------------------------------------------------------
obj.SynthStatusLabel = uilabel(g, "Text", "Set up units and evoked potentials, then Preview.", ...
    "WordWrap", "on", "FontSize", 14, "FontColor", [0.3 0.3 0.3]);
obj.SynthStatusLabel.Layout.Row = 2; obj.SynthStatusLabel.Layout.Column = [1 2];

% --- row 3 left: settings (scrolls) ------------------------------------------------
left = uigridlayout(g, [5 1]);
left.Layout.Row = 3; left.Layout.Column = 1;
left.RowHeight = {'fit', 'fit', 220, 160, 'fit'};
left.Padding = [0 0 4 0];
left.RowSpacing = 8;
left.Scrollable = "on";

% Task
sp = uipanel(left, "Title", "Built-in task");
sg = uigridlayout(sp, [1 4]);
sg.RowHeight = {26};
sg.ColumnWidth = {'fit', 70, 'fit', 110};
sg.Padding = [6 6 6 6];
uilabel(sg, "Text", "Trials:");
obj.SynthTrialsSpinner = uispinner(sg, "Limits", [4 5000], "Step", 1, "RoundFractionalValues", "on", "Value", 12, ...
    "Tooltip", "Epsych2 trials in the session.", "ValueChangedFcn", changed);
uilabel(sg, "Text", "Scenario:");
obj.SynthScenarioDropDown = uidropdown(sg, "Items", {'clean', 'late-start', 'early-stop', 'spurious'}, "Value", 'clean', ...
    "Tooltip", "How the recording covers the session (see makeSyntheticRecording).", "ValueChangedFcn", changed);

% Recording
rp = uipanel(left, "Title", "Recording");
rg = uigridlayout(rp, [3 8]);
rg.RowHeight = {26, 26, 26};
rg.ColumnWidth = {'fit', 150, 'fit', 70, 'fit', 60, 'fit', '1x'};
rg.RowSpacing = 4; rg.Padding = [6 6 6 6];
uilabel(rg, "Text", "Format:");
obj.SynthFormatDropDown = uidropdown(rg, ...
    "Items", {'Intan RHX (*.rhd)', 'Intan one file per signal', 'Binary (recording.json)', ...
        'Open Ephys binary', 'Open Ephys format', 'Open Ephys NWB'}, ...
    "ItemsData", {'traditional', 'one-file-per-signal', 'binary', 'openephys-binary', 'openephys-legacy', 'openephys-nwb'}, ...
    "Value", 'traditional', "ValueChangedFcn", changed);
uilabel(rg, "Text", "Fs (Hz):");
obj.SynthFsField = uieditfield(rg, "numeric", "Limits", [1000 100000], "Value", 30000, "ValueDisplayFormat", "%.0f", ...
    "Tooltip", "Sample rate.", "ValueChangedFcn", changed);
uilabel(rg, "Text", "Channels:");
obj.SynthChannelsField = uieditfield(rg, "numeric", "Limits", [2 1024], "RoundFractionalValues", "on", "Value", 16, ...
    "Tooltip", "Amplifier channels (a synthetic probe is written with the dataset).", "ValueChangedFcn", changed);
uilabel(rg, "Text", "Seed:");
obj.SynthSeedField = uieditfield(rg, "numeric", "RoundFractionalValues", "on", "Value", 1, "Limits", [0 4294967295], ...
    "Tooltip", "Random seed: the same seed and settings give the same data.", "ValueChangedFcn", changed);
uilabel(rg, "Text", "Subject:");
obj.SynthSubjectField = uieditfield(rg, "text", "Value", "SYNTH-01", ...
    "Tooltip", "Subject of the synthetic recording and its session (names the folder and files).", "ValueChangedFcn", changed);
uilabel(rg, "Text", "File (s):");
obj.SynthFileSecondsField = uieditfield(rg, "numeric", "Limits", [1 3600], "Value", 30, ...
    "Tooltip", "Seconds per .rhd file (also the chunk written at a time).", "ValueChangedFcn", changed);
uilabel(rg, "Text", "Noise (uV):");
obj.SynthNoiseField = uieditfield(rg, "numeric", "Limits", [0 10000], "Value", 10, ...
    "Tooltip", "RMS of the white noise on every channel.", "ValueChangedFcn", changed);
ob = uigridlayout(rg, [1 2]);
ob.Layout.Row = 2; ob.Layout.Column = [7 8];
ob.ColumnWidth = {'fit', 'fit'}; ob.Padding = [0 0 0 0];
obj.SynthSortedCheckBox = uicheckbox(ob, "Text", "Sorted output", "Value", true, ...
    "Tooltip", "Write the ground-truth units as Kilosort4 / phy output (kilosort4/).", "ValueChangedFcn", changed);
obj.SynthArtifactsCheckBox = uicheckbox(ob, "Text", "Artifacts", "Value", true, ...
    "Tooltip", "Add a noise burst and a saturating step.", "ValueChangedFcn", changed);
lbl = uilabel(rg, "Text", "Sine (uV):"); lbl.Layout.Row = 3; lbl.Layout.Column = 1;
obj.SynthSineField = uieditfield(rg, "numeric", "Limits", [0 10000], "Value", 100, ...
    "Tooltip", ["Amplitude of a 2 Hz sine on every channel (0 = off): a stand-in for the ongoing LFP, so the artifact detector's running-RMS threshold sits above spikes and evoked potentials, as on real recordings." ...
        "Spike filtering removes it; averages over trials cancel it."], "ValueChangedFcn", changed);
obj.SynthSineField.Layout.Row = 3; obj.SynthSineField.Layout.Column = 2;

% Units
up = uipanel(left, "Title", "Units (spikes)");
ug = uigridlayout(up, [2 1]);
ug.RowHeight = {28, '1x'}; ug.Padding = [6 6 6 6]; ug.RowSpacing = 4;
ub = uigridlayout(ug, [1 4]);
ub.ColumnWidth = {'fit', 'fit', 'fit', 'fit'}; ub.Padding = [0 0 0 0];
obj.SynthAddUnitButton = uibutton(ub, "Text", "Add unit", ...
    "Tooltip", "A unit driven x 4 from 15 to 215 ms after Stim's onset (or the trial line's).", ...
    "ButtonPushedFcn", @(~,~) obj.onSynthDesign("addUnit"));
obj.SynthRemoveUnitButton = uibutton(ub, "Text", "Remove", "Tooltip", "Remove the selected unit.", ...
    "ButtonPushedFcn", @(~,~) obj.onSynthDesign("removeUnit"));
obj.SynthBuiltInButton = uibutton(ub, "Text", "Built-in design", ...
    "Tooltip", "Replace units and evoked potentials with makeSyntheticRecording's default for this channel count: half the units driven by Stim, one silenced, and an evoked potential.", ...
    "ButtonPushedFcn", @(~,~) obj.onSynthDesign("builtIn"));
obj.SynthClearButton = uibutton(ub, "Text", "Clear", "Tooltip", "Remove every unit and evoked potential.", ...
    "ButtonPushedFcn", @(~,~) obj.onSynthDesign("clear"));
[~, names, widths] = obj.synthColumns("unit");
obj.SynthUnitsTable = uitable(ug, "ColumnName", names, "ColumnWidth", widths, "RowName", {}, ...
    "ColumnEditable", true, "Data", cell(0, numel(names)), "SelectionType", "row", ...
    "Tooltip", ["Event: the line the unit responds to ((none): unmodulated); Edge: its onset or offset." ...
        "From Latency to Latency + Duration (ms) after the edge the rate is Baseline x Gain (> 1 excites, < 1 suppresses, 0 silences)." ...
        "Channel: the one channel its spikes are on (a fixed trough of Amplitude uV)." ...
        "Parameter: an Epsych2 trial parameter that scales the response (0 at its smallest value, full at its largest)."], ...
    "CellEditCallback", changed);

% Evoked potentials
lp = uipanel(left, "Title", "Evoked potentials (LFP)");
lg = uigridlayout(lp, [2 1]);
lg.RowHeight = {28, '1x'}; lg.Padding = [6 6 6 6]; lg.RowSpacing = 4;
lb2 = uigridlayout(lg, [1 2]);
lb2.ColumnWidth = {'fit', 'fit'}; lb2.Padding = [0 0 0 0];
obj.SynthAddEvokedButton = uibutton(lb2, "Text", "Add evoked", ...
    "Tooltip", "A -100 uV deflection on every channel from 10 to 70 ms after Stim's onset (or the trial line's).", ...
    "ButtonPushedFcn", @(~,~) obj.onSynthDesign("addEvoked"));
obj.SynthRemoveLFPButton = uibutton(lb2, "Text", "Remove", "Tooltip", "Remove the selected evoked potential.", ...
    "ButtonPushedFcn", @(~,~) obj.onSynthDesign("removeLFP"));
[~, names, widths] = obj.synthColumns("lfp");
obj.SynthLFPTable = uitable(lg, "ColumnName", names, "ColumnWidth", widths, "RowName", {}, ...
    "ColumnEditable", true, "Data", cell(0, numel(names)), "SelectionType", "row", ...
    "Tooltip", ["A raised-cosine deflection of Amplitude uV (signed) from Latency to Latency + Duration (ms) after the event's Edge, peaking halfway." ...
        "Channel: the one channel it is on; NaN = every channel." ...
        "Parameter: an Epsych2 trial parameter that scales the amplitude."], ...
    "CellEditCallback", changed);

% Output
op = uipanel(left, "Title", "Output");
og = uigridlayout(op, [2 4]);
og.RowHeight = {28, 28};
og.ColumnWidth = {'fit', '1x', 'fit', 'fit'};
og.Padding = [6 6 6 6]; og.RowSpacing = 4;
uilabel(og, "Text", "Folder:");
obj.SynthOutputField = uieditfield(og, "text", "Value", "", "Placeholder", "<project root>_synthetic", ...
    "Tooltip", "The dataset is written to <folder>\<Subject>\<Subject>_<date>_<time>. Blank: next to the project root, as <root>_synthetic.", ...
    "ValueChangedFcn", changed);
obj.SynthBrowseOutputButton = uibutton(og, "Text", "Browse...", "ButtonPushedFcn", @(~,~) obj.onSynthDesign("browseOutput"));
obj.SynthBrowseOutputButton.Layout.Column = [3 4];
obj.SynthLoadDesignButton = uibutton(og, "Text", "Load design...", ...
    "Tooltip", "Read units, evoked potentials and noise from a design .json (SyntheticDesign.save).", ...
    "ButtonPushedFcn", @(~,~) obj.onSynthDesign("load"));
obj.SynthLoadDesignButton.Layout.Row = 2; obj.SynthLoadDesignButton.Layout.Column = 3;
obj.SynthSaveDesignButton = uibutton(og, "Text", "Save design...", ...
    "Tooltip", "Write units, evoked potentials and noise to a .json (SyntheticDesign.load reads it; every generated dataset also holds its own as <name>_synthetic.json).", ...
    "ButtonPushedFcn", @(~,~) obj.onSynthDesign("save"));
obj.SynthSaveDesignButton.Layout.Row = 2; obj.SynthSaveDesignButton.Layout.Column = 4;

% --- row 3 right: preview -------------------------------------------------------------
right = uigridlayout(g, [4 1]);
right.Layout.Row = 3; right.Layout.Column = 2;
right.RowHeight = {28, '0.8x', '1x', '1x'};
right.Padding = [0 0 0 0];
right.RowSpacing = 6;
sel = uigridlayout(right, [1 8]);
sel.ColumnWidth = {'fit', '1x', 'fit', '1x', 'fit', 60, 'fit', 50};
sel.Padding = [0 0 0 0];
render = @(~,~) obj.renderSynthPreview();
uilabel(sel, "Text", "Unit:");
obj.SynthUnitDropDown = uidropdown(sel, "Items", {'-'}, "ItemsData", {0}, "Value", 0, "ValueChangedFcn", render);
uilabel(sel, "Text", "LFP:");
obj.SynthLFPDropDown = uidropdown(sel, "Items", {'-'}, "ItemsData", {0}, "Value", 0, "ValueChangedFcn", render);
uilabel(sel, "Text", "From (s):");
obj.SynthTimelineStartField = uieditfield(sel, "numeric", "Limits", [0 Inf], "Value", 0, ...
    "Tooltip", "Start of the stretch shown in the timeline.", "ValueChangedFcn", render);
uilabel(sel, "Text", "Span:");
obj.SynthTimelineSpanField = uieditfield(sel, "numeric", "Limits", [0.1 3600], "Value", 20, ...
    "Tooltip", "Seconds shown in the timeline.", "ValueChangedFcn", render);

obj.SynthTimelineAxes = uiaxes(right);
title(obj.SynthTimelineAxes, "Lines and spikes");
xlabel(obj.SynthTimelineAxes, "Time (s)");
r2 = uigridlayout(right, [1 2]);
r2.Padding = [0 0 0 0]; r2.ColumnSpacing = 8;
obj.SynthRasterAxes = uiaxes(r2);
title(obj.SynthRasterAxes, "Raster");
obj.SynthPSTHAxes = uiaxes(r2);
title(obj.SynthPSTHAxes, "PSTH");
obj.SynthLFPAxes = uiaxes(right);
title(obj.SynthLFPAxes, "LFP around the event");

obj.applySynthDesign(SyntheticDesign.builtIn(16));
obj.syncSynthControls();
end
