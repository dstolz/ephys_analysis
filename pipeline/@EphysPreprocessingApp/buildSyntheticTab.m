function buildSyntheticTab(obj)
%buildSyntheticTab  Design, preview and write a synthetic dataset (makeSyntheticRecording).
%   Top: where the events come from (Timing from: the built-in task, or the
%   active dataset's Epsych2 session with its recorded lines, or the session
%   alone with lines rebuilt from its parameters), the dataset, Load source
%   (onSynthLoadSource), Preview (onSynthPreview) and Generate...
%   (onSynthGenerate), and a status line.
%   Left, scrolling: the source's options (the task's trials and scenario;
%   for a rebuilt session the trial duration and one row per line, each an
%   expression over the trial's parameters), the recording (format, rate,
%   channels, file length, a length limit, seed, subject, sorted output,
%   artifacts), the units and the event-linked LFP components (one table
%   row each, see SyntheticDesign; Event, Edge, Shape, Parameter, Tuning,
%   Kind and Profile are lists), the background, and where it is written
%   plus Load / Save design (JSON).
%   Right: the preview of what Generate writes (same seed, same spikes):
%   the lines and spikes over a stretch of the recording, the chosen unit's
%   raster and PSTH around its event (split by its parameter, with the
%   model's rate dashed), the chosen LFP component around its event (single
%   events, their mean and the model), and its gain over the probe
%   (renderSynthPreview). Every setting is kept as a preference.

g = uigridlayout(obj.TabSynthetic, [3 2]);
g.RowHeight   = {30, 'fit', '1x'};
g.ColumnWidth = {600, '1x'};
g.Padding     = [10 10 10 10];
g.RowSpacing  = 6;
changed = @(~,~) obj.onSynthControlsChanged();
scheduleChanged = @(~,~) obj.onSynthControlsChanged("schedule");

% --- row 1: source + actions ----------------------------------------------------
top = uigridlayout(g, [1 8]);
top.Layout.Row = 1; top.Layout.Column = [1 2];
top.ColumnWidth = {'fit', 300, 'fit', 240, 'fit', 'fit', 'fit', '1x'};
top.RowHeight = {30};
top.ColumnSpacing = 6;
top.Padding = [0 0 0 0];
uilabel(top, "Text", "Timing from:");
obj.SynthSourceDropDown = uidropdown(top, ...
    "Items", {'Built-in task (synthetic session)', 'Active dataset: recorded lines + Epsych2 session', ...
        'Active dataset: Epsych2 session only (rebuilt lines)'}, ...
    "ItemsData", {'task', 'recording', 'session'}, "Value", 'task', ...
    "Tooltip", ["Where the trials and digital-line events come from." ...
        "Built-in task: an AM-detection session drawn from the seed (six lines, as on the lab's rig)." ...
        "Recorded lines: the active dataset's own digital lines and trial pairing, so the synthetic recording has its events at the same times; a copy of its Epsych2 session goes with it." ...
        "Session only: the lines rebuilt from the Epsych2 parameters (Lines below), for a session whose recording cannot be read."], ...
    "ValueChangedFcn", @(~,~) obj.onSynthSourceChanged());
uilabel(top, "Text", "Dataset:");
obj.SynthDatasetDropDown = obj.datasetPicker(top);
obj.SynthLoadButton = uibutton(top, "Text", "Load source", ...
    "Tooltip", "Read the schedule: the task, or the active dataset's Epsych2 session and (Recorded lines) its digital lines, cached after the first read. Fills the Event and Parameter lists.", ...
    "ButtonPushedFcn", @(~,~) obj.onSynthLoadSource());
obj.SynthPreviewButton = uibutton(top, "Text", "Preview", ...
    "Tooltip", "Build the model (units, spikes, LFP) from the settings and plot it. Generate writes exactly this (same seed).", ...
    "ButtonPushedFcn", @(~,~) obj.onSynthPreview());
obj.SynthGenerateButton = uibutton(top, "Text", "Generate...", ...
    "Tooltip", "Write the synthetic dataset (recording, Epsych2 session, ground-truth sorted output, manifest) under the output folder.", ...
    "ButtonPushedFcn", @(~,~) obj.onSynthGenerate());

% --- row 2: status -------------------------------------------------------------
obj.SynthStatusLabel = uilabel(g, "Text", "Choose where the events come from, set up units and LFP, then Preview.", ...
    "WordWrap", "on", "FontSize", 14, "FontColor", [0.3 0.3 0.3]);
obj.SynthStatusLabel.Layout.Row = 2; obj.SynthStatusLabel.Layout.Column = [1 2];

% --- row 3 left: settings (scrolls) ------------------------------------------------
left = uigridlayout(g, [6 1]);
left.Layout.Row = 3; left.Layout.Column = 1;
left.RowHeight = {'fit', 'fit', 250, 190, 'fit', 'fit'};
left.Padding = [0 0 4 0];
left.RowSpacing = 8;
left.Scrollable = "on";

% Source
sp = uipanel(left, "Title", "Source");
sg = uigridlayout(sp, [4 6]);
sg.RowHeight = {26, 26, 110, 'fit'};
sg.ColumnWidth = {'fit', 70, 'fit', 110, 'fit', '1x'};
sg.RowSpacing = 4; sg.Padding = [6 6 6 6];
uilabel(sg, "Text", "Task trials:");
obj.SynthTrialsSpinner = uispinner(sg, "Limits", [4 5000], "Step", 1, "RoundFractionalValues", "on", "Value", 12, ...
    "Tooltip", "Built-in task: Epsych2 trials in the session.", "ValueChangedFcn", changed);
uilabel(sg, "Text", "Scenario:");
obj.SynthScenarioDropDown = uidropdown(sg, "Items", {'clean', 'late-start', 'early-stop', 'spurious'}, "Value", 'clean', ...
    "Tooltip", "Built-in task: how the recording covers the session (see makeSyntheticRecording).", "ValueChangedFcn", changed);
lbl = uilabel(sg, "Text", "Trial (ms):"); lbl.Layout.Row = 2; lbl.Layout.Column = 1;
obj.SynthTrialDurField = uieditfield(sg, "text", "Value", "", "Placeholder", "automatic", ...
    "Tooltip", "Session only: how long each trial is on the trial line, in ms; an expression over the trial's numeric parameters (e.g. StimDelay + RespWinDelay + RespWinDur + 50). Blank = automatic. Trials end at their computerTimestamp.", ...
    "ValueChangedFcn", scheduleChanged);
obj.SynthTrialDurField.Layout.Row = 2; obj.SynthTrialDurField.Layout.Column = [2 6];
obj.SynthLinesTable = uitable(sg, "ColumnName", {'Line', 'Onset (ms)', 'Duration (ms)'}, ...
    "ColumnEditable", true, "ColumnWidth", {110, 'auto', 'auto'}, "RowName", {}, ...
    "Tooltip", "Session only: each line goes on Onset ms after its trial starts, for Duration ms (expressions over the trial's parameters; a trial where either is not a number gets none). Empty = automatic from the parameters there are.", ...
    "Data", cell(0, 3), "CellEditCallback", scheduleChanged);
obj.SynthLinesTable.Layout.Row = 3; obj.SynthLinesTable.Layout.Column = [1 6];
lb = uigridlayout(sg, [1 3]);
lb.Layout.Row = 4; lb.Layout.Column = [1 6];
lb.ColumnWidth = {'fit', 'fit', '1x'}; lb.RowHeight = {28}; lb.Padding = [0 0 0 0];
obj.SynthAddLineButton = uibutton(lb, "Text", "Add line", "ButtonPushedFcn", @(~,~) obj.onSynthDesign("addLine"));
obj.SynthRemoveLineButton = uibutton(lb, "Text", "Remove line", ...
    "Tooltip", "Remove the selected line (all lines: back to automatic).", "ButtonPushedFcn", @(~,~) obj.onSynthDesign("removeLine"));
uilabel(lb, "Text", "Rebuilt lines are used with ""Epsych2 session only"".", "FontColor", [0.45 0.45 0.45]);

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
    "Tooltip", "Sample rate (Load source sets the dataset's).", "ValueChangedFcn", changed);
uilabel(rg, "Text", "Channels:");
obj.SynthChannelsField = uieditfield(rg, "numeric", "Limits", [2 1024], "RoundFractionalValues", "on", "Value", 16, ...
    "Tooltip", "Amplifier channels (Load source sets the dataset's; its probe gives the site positions when it has enough sites).", ...
    "ValueChangedFcn", changed);
uilabel(rg, "Text", "Seed:");
obj.SynthSeedField = uieditfield(rg, "numeric", "RoundFractionalValues", "on", "Value", 1, ...
    "Tooltip", "Random seed: the same seed and settings give the same data.", "ValueChangedFcn", changed);
uilabel(rg, "Text", "Subject:");
obj.SynthSubjectField = uieditfield(rg, "text", "Value", "SYNTH-01", ...
    "Tooltip", "Subject of the synthetic recording and its session copy (names the folder and files).", "ValueChangedFcn", changed);
uilabel(rg, "Text", "File (s):");
obj.SynthFileSecondsField = uieditfield(rg, "numeric", "Limits", [1 3600], "Value", 30, ...
    "Tooltip", "Seconds per .rhd file (also the chunk written at a time).", "ValueChangedFcn", changed);
uilabel(rg, "Text", "Max (s):");
obj.SynthMaxDurField = uieditfield(rg, "numeric", "Limits", [0 Inf], "Value", 0, ...
    "Tooltip", "Dataset sources: stop the recording after this many seconds (0 = as long as the source). Lines still on then end at the last sample, as when a recording is stopped early.", ...
    "ValueChangedFcn", changed);
ob = uigridlayout(rg, [1 2]);
ob.Layout.Row = 2; ob.Layout.Column = [7 8];
ob.ColumnWidth = {'fit', 'fit'}; ob.Padding = [0 0 0 0];
obj.SynthSortedCheckBox = uicheckbox(ob, "Text", "Sorted output", "Value", true, ...
    "Tooltip", "Write the ground-truth units as Kilosort4 / phy output (kilosort4/).", "ValueChangedFcn", changed);
obj.SynthArtifactsCheckBox = uicheckbox(ob, "Text", "Artifacts", "Value", true, ...
    "Tooltip", "Add a noise burst and a saturating step.", "ValueChangedFcn", changed);
obj.SynthProbeLabel = uilabel(rg, "Text", "Probe: synthetic", "FontColor", [0.4 0.4 0.4]);
obj.SynthProbeLabel.Layout.Row = 3; obj.SynthProbeLabel.Layout.Column = [1 8];

% Units
up = uipanel(left, "Title", "Units (spikes)");
ug = uigridlayout(up, [2 1]);
ug.RowHeight = {28, '1x'}; ug.Padding = [6 6 6 6]; ug.RowSpacing = 4;
ub = uigridlayout(ug, [1 5]);
ub.ColumnWidth = {'fit', 'fit', 'fit', 'fit', '1x'}; ub.Padding = [0 0 0 0];
obj.SynthAddUnitButton = uibutton(ub, "Text", "Add unit", ...
    "Tooltip", "A unit responding to the trial line (or the first line) with a phasic-tonic burst.", ...
    "ButtonPushedFcn", @(~,~) obj.onSynthDesign("addUnit"));
obj.SynthRemoveUnitButton = uibutton(ub, "Text", "Remove", "Tooltip", "Remove the selected unit.", ...
    "ButtonPushedFcn", @(~,~) obj.onSynthDesign("removeUnit"));
obj.SynthBuiltInButton = uibutton(ub, "Text", "Built-in design", ...
    "Tooltip", "Replace units and LFP with makeSyntheticRecording's default for this channel count: random units, half driven by Stim (or the first line), one suppressed, and an evoked potential.", ...
    "ButtonPushedFcn", @(~,~) obj.onSynthDesign("builtIn"));
obj.SynthClearButton = uibutton(ub, "Text", "Clear", "Tooltip", "Remove every unit and LFP component.", ...
    "ButtonPushedFcn", @(~,~) obj.onSynthDesign("clear"));
uilabel(ub, "Text", "NaN = random / automatic", "FontColor", [0.45 0.45 0.45], "HorizontalAlignment", "right");
[~, names, widths] = obj.synthColumns("unit");
obj.SynthUnitsTable = uitable(ug, "ColumnName", names, "ColumnWidth", widths, "RowName", {}, ...
    "ColumnEditable", true, "Data", cell(0, numel(names)), "SelectionType", "row", ...
    "Tooltip", ["Event: the line the unit responds to ((none): unmodulated); Edge: its onset or offset." ...
        "Gain: rate x Gain at the response peak (> 1 excites, < 1 suppresses). Shape: sustained, transient (a bump) or phasic-tonic." ...
        "Latency / Duration (ms): the response window after the edge (Duration NaN: as long as the line is on). Jitter: SD of the latency." ...
        "Channel NaN: spread the units; Baseline / Amplitude / Width / Gain NaN: drawn from the seed." ...
        "Parameter: an Epsych2 trial parameter that scales the response (Tuning: increasing or decreasing with it)."], ...
    "CellEditCallback", changed);

% LFP
lp = uipanel(left, "Title", "Event-linked LFP");
lg = uigridlayout(lp, [2 1]);
lg.RowHeight = {28, '1x'}; lg.Padding = [6 6 6 6]; lg.RowSpacing = 4;
lb2 = uigridlayout(lg, [1 4]);
lb2.ColumnWidth = {'fit', 'fit', 'fit', '1x'}; lb2.Padding = [0 0 0 0];
obj.SynthAddOscButton = uibutton(lb2, "Text", "Add oscillation", ...
    "Tooltip", "A 40 Hz phase-locked oscillation after the event (untick Locked for induced power only).", ...
    "ButtonPushedFcn", @(~,~) obj.onSynthDesign("addOscillation"));
obj.SynthAddEvokedButton = uibutton(lb2, "Text", "Add evoked", ...
    "Tooltip", "An evoked potential (alpha function) that reverses polarity with depth.", ...
    "ButtonPushedFcn", @(~,~) obj.onSynthDesign("addEvoked"));
obj.SynthRemoveLFPButton = uibutton(lb2, "Text", "Remove", "Tooltip", "Remove the selected LFP component.", ...
    "ButtonPushedFcn", @(~,~) obj.onSynthDesign("removeLFP"));
[~, names, widths] = obj.synthColumns("lfp");
obj.SynthLFPTable = uitable(lg, "ColumnName", names, "ColumnWidth", widths, "RowName", {}, ...
    "ColumnEditable", true, "Data", cell(0, numel(names)), "SelectionType", "row", ...
    "Tooltip", ["Kind: oscillation (Freq, Amplitude, Rise = the envelope's ramps; Locked = the same phase on every event) or evoked (Rise = time to peak, signed Amplitude)." ...
        "Latency / Duration (ms) after the event's Edge (Duration NaN: oscillation as long as the line is on, evoked 8 x Rise)." ...
        "Profile over the probe's depth: uniform, superficial, middle, deep, or reversal (the sign flips at mid depth)." ...
        "Parameter / Tuning: an Epsych2 trial parameter that scales the amplitude."], ...
    "CellEditCallback", changed);

% Background
bp = uipanel(left, "Title", "Background");
bg = uigridlayout(bp, [1 10]);
bg.RowHeight = {26};
bg.ColumnWidth = {'fit', 50, 'fit', 50, 'fit', 50, 'fit', 50, 'fit', 60};
bg.Padding = [6 6 6 6];
uilabel(bg, "Text", "Rhythms (x):");
obj.SynthRhythmField = uieditfield(bg, "numeric", "Limits", [0 100], "Value", 1, ...
    "Tooltip", "Ongoing 1.7 / 7.3 / 12.5 Hz rhythms (120 / 60 / 25 uV at 1); 0 = off.", "ValueChangedFcn", changed);
uilabel(bg, "Text", "1/f (uV):");
obj.SynthPinkField = uieditfield(bg, "numeric", "Limits", [0 10000], "Value", 30, ...
    "Tooltip", "RMS of the slow (4 Hz low-passed) noise.", "ValueChangedFcn", changed);
uilabel(bg, "Text", "Noise (uV):");
obj.SynthNoiseField = uieditfield(bg, "numeric", "Limits", [0 10000], "Value", 9, ...
    "Tooltip", "RMS of the white noise.", "ValueChangedFcn", changed);
uilabel(bg, "Text", "Line (uV):");
obj.SynthLineNoiseField = uieditfield(bg, "numeric", "Limits", [0 10000], "Value", 5, ...
    "Tooltip", "Line-noise amplitude (its 3rd harmonic at 30 %).", "ValueChangedFcn", changed);
uilabel(bg, "Text", "at");
obj.SynthLineFreqDropDown = uidropdown(bg, "Items", {'60 Hz', '50 Hz'}, "ItemsData", {60, 50}, "Value", 60, ...
    "ValueChangedFcn", changed);

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
    "Tooltip", "Read units, LFP and background from a design .json (SyntheticDesign.save).", ...
    "ButtonPushedFcn", @(~,~) obj.onSynthDesign("load"));
obj.SynthLoadDesignButton.Layout.Row = 2; obj.SynthLoadDesignButton.Layout.Column = 3;
obj.SynthSaveDesignButton = uibutton(og, "Text", "Save design...", ...
    "Tooltip", "Write units, LFP and background to a .json (SyntheticDesign.load reads it; every generated dataset also holds its own as <name>_synthetic.json).", ...
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
r3 = uigridlayout(right, [1 2]);
r3.ColumnWidth = {'2x', '1x'};
r3.Padding = [0 0 0 0]; r3.ColumnSpacing = 8;
obj.SynthLFPAxes = uiaxes(r3);
title(obj.SynthLFPAxes, "LFP around the event");
obj.SynthProfileAxes = uiaxes(r3);
title(obj.SynthProfileAxes, "Gain over the probe");

obj.applySynthDesign(SyntheticDesign.builtIn(16));
obj.syncSynthControls();
end
