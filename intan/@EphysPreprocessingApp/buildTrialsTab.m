function buildTrialsTab(obj)
%buildTrialsTab  Review the pairing of Epsych2 trials with the trial digital line.
%   Top: dataset, Load (reads the digital events once, cached per dataset),
%   Re-align, Approve / Revoke, Write behavior .mat, and the pairing summary.
%   Left: the config's pairing settings (Behavior section): pair in the
%   behavior step, trial line, timestamp tolerance, and one row per digital
%   line with its polarity (Signals.InvertedLines: an inverted line is on
%   while low, so its onset is the falling edge; this also applies to the
%   events in the extract and export files). Right: one row per trial; the
%   Interval column is editable (blank = unpaired). Bottom: timestamp
%   residual per trial. Approving saves the pairing in the dataset manifest
%   (EphysDataset.setTrialPairing); the behavior step then reuses it.

g = uigridlayout(obj.TabTrials, [4 2]);
g.RowHeight   = {'fit', 'fit', '1x', 190};
g.ColumnWidth = {290, '1x'};
g.Padding     = [10 10 10 10];
changed = @(~,~) obj.onTrialsSettingsChanged();

% --- row 1: dataset + actions ------------------------------------------------
top = uigridlayout(g, [1 8]);
top.Layout.Row = 1; top.Layout.Column = [1 2];
top.ColumnWidth = {'fit', 260, 'fit', 'fit', 'fit', 'fit', 'fit', '1x'};
top.Padding = [0 0 0 0];
uilabel(top, "Text", "Dataset:");
obj.TrialsDatasetDropDown = uidropdown(top, "Items", {'(scan first)'}, ...
    "ValueChangedFcn", @(~,~) obj.clearTrialsView());
obj.TrialsLoadButton = uibutton(top, "Text", "Load", "FontWeight", "bold", ...
    "Tooltip", "Read the digital lines (cached after the first read) and pair the trials, reusing a recorded pairing when it still matches.", ...
    "ButtonPushedFcn", @(~,~) obj.onTrialsLoad("recorded"));
obj.TrialsAutoButton = uibutton(top, "Text", "Re-align automatically", ...
    "Tooltip", "Discard edits and the recorded assignment; align by the Epsych2 timestamps again.", ...
    "ButtonPushedFcn", @(~,~) obj.onTrialsLoad("auto"));
obj.TrialsApproveButton = uibutton(top, "Text", "Approve pairing", ...
    "BackgroundColor", [0.86 0.94 0.86], ...
    "Tooltip", "Save this pairing as reviewed in the dataset manifest.", ...
    "ButtonPushedFcn", @(~,~) obj.onTrialsApprove("approved"));
obj.TrialsRevokeButton = uibutton(top, "Text", "Mark unreviewed", ...
    "Tooltip", "Keep this assignment in the manifest but mark it as not reviewed.", ...
    "ButtonPushedFcn", @(~,~) obj.onTrialsApprove("unreviewed"));
obj.TrialsWriteButton = uibutton(top, "Text", "Write behavior .mat", ...
    "Tooltip", "Write <name>_behavior.mat with the pairing columns now.", ...
    "ButtonPushedFcn", @(~,~) obj.onTrialsWriteBehavior());

% --- row 2: summary --------------------------------------------------------
obj.TrialsSummaryLabel = uilabel(g, "Text", "Scan a project, pick a dataset with an Epsych2 session and press Load.", ...
    "WordWrap", "on", "FontColor", [0.3 0.3 0.3]);
obj.TrialsSummaryLabel.Layout.Row = 2; obj.TrialsSummaryLabel.Layout.Column = [1 2];

% --- row 3 left: settings ----------------------------------------------------
sp = uipanel(g, "Title", "Digital lines and pairing (config)");
sp.Layout.Row = 3; sp.Layout.Column = 1;
sg = uigridlayout(sp, [5 2]);
sg.RowHeight = {'fit', 'fit', 'fit', '1x', 'fit'};
sg.ColumnWidth = {'fit', '1x'};
obj.TrialsPairCheckBox = uicheckbox(sg, "Text", "Pair trials in the behavior step", "Value", true, ...
    "ValueChangedFcn", changed);
obj.TrialsPairCheckBox.Layout.Row = 1; obj.TrialsPairCheckBox.Layout.Column = [1 2];
lbl = uilabel(sg, "Text", "Trial line:"); lbl.Layout.Row = 2; lbl.Layout.Column = 1;
obj.TrialsLineDropDown = uidropdown(sg, "Items", {'InTrial'}, "Value", 'InTrial', "Editable", "on", ...
    "Tooltip", "Digital line that is on for the duration of each trial (type a name or pick a loaded line).", ...
    "ValueChangedFcn", changed);
obj.TrialsLineDropDown.Layout.Row = 2; obj.TrialsLineDropDown.Layout.Column = 2;
lbl = uilabel(sg, "Text", "Tolerance:"); lbl.Layout.Row = 3; lbl.Layout.Column = 1;
obj.TrialsToleranceField = uieditfield(sg, "numeric", "Value", 0.5, "Limits", [0 Inf], ...
    "LowerLimitInclusive", "off", "ValueDisplayFormat", "%g s", ...
    "Tooltip", "A trial's timestamp agrees with its interval offset within this many seconds.", ...
    "ValueChangedFcn", changed);
obj.TrialsToleranceField.Layout.Row = 3; obj.TrialsToleranceField.Layout.Column = 2;
obj.TrialsLinesTable = uitable(sg, "ColumnName", {'Line', 'Intervals', 'Inverted'}, ...
    "ColumnEditable", [false false true], "ColumnWidth", {110, 65, 70}, "RowName", {}, ...
    "Tooltip", "Tick lines with inverted polarity: on while low, onset = falling edge. Applies to pairing and to the events written by the Signals step.", ...
    "CellEditCallback", changed);
obj.TrialsLinesTable.Layout.Row = 4; obj.TrialsLinesTable.Layout.Column = [1 2];
obj.TrialsLinesTable.Data = table(strings(0, 1), zeros(0, 1), false(0, 1), ...
    'VariableNames', {'Line', 'Intervals', 'Inverted'});
lbl = uilabel(sg, "WordWrap", "on", "FontColor", [0.4 0.4 0.4], "Text", ...
    "Edit the Interval column to fix a pairing (blank = unpaired), then Approve.");
lbl.Layout.Row = 5; lbl.Layout.Column = [1 2];

% --- row 3 right: trials ---------------------------------------------------
obj.TrialsTable = uitable(g, "RowName", {}, ...
    "ColumnName", {'Trial', 'TrialIndex', 'Interval', 'Onset (s)', 'Offset (s)', ...
        'Onset sample', 'Offset sample', 'Residual (s)', 'Flag', 'Other lines'}, ...
    "ColumnEditable", [false false true false(1, 7)], ...
    "ColumnWidth", {45, 70, 60, 80, 80, 95, 95, 85, 95, 'auto'}, ...
    "CellEditCallback", @(~, evt) obj.onTrialsCellEdit(evt));
obj.TrialsTable.Layout.Row = 3; obj.TrialsTable.Layout.Column = 2;

% --- row 4: residual plot -------------------------------------------------
obj.TrialsAxes = uiaxes(g);
obj.TrialsAxes.Layout.Row = 4; obj.TrialsAxes.Layout.Column = [1 2];
title(obj.TrialsAxes, "Timestamp residual per trial");
xlabel(obj.TrialsAxes, "Trial");
ylabel(obj.TrialsAxes, "Residual (s)");

obj.syncTrialsButtons();
end
