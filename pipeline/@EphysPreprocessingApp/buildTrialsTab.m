function buildTrialsTab(obj)
%buildTrialsTab  Review the pairing of Epsych2 trials with the trial digital line.
%   Top: dataset, Load (reads the digital events once, cached per dataset),
%   Reset cuts, Approve / Mark unreviewed, Write behavior .mat, the Epsych2
%   session / <name>_behavior.mat to the base workspace, and the pairing
%   summary with the count-mismatch warning. Left: the config's
%   pairing settings (Behavior section: pair in the behavior step, trial
%   line), one row per digital line with its polarity (Signals.InvertedLines:
%   an inverted line is on while low, so its onset is the falling edge; this
%   also applies to the events in the extract and export files), and the
%   cuts that resolve a count mismatch: trials or trial-line intervals
%   dropped from the start or the end before the in-order pairing (kept per
%   dataset in its manifest, not in the config). Right: one row per trial;
%   its columns sort and move, and its context menu adds or removes Epsych2
%   parameter columns (remembered for every dataset as preferences).
%   Bottom: the digital lines over the recording, one bar per event from its
%   onset to its offset with the polarity applied, the trial line coloured by
%   pairing state (refreshTrialsPlot; its context menu shows or hides the
%   trial onset / offset lines, grid lines and Epsych2 parameter labels); the mouse wheel zooms time about the cursor and dragging
%   pans time (the line rows stay fixed). Approving saves the cuts in the dataset manifest
%   (EphysDataset.setTrialPairing); the behavior step then reuses them.

g = uigridlayout(obj.TabTrials, [4 2]);
g.RowHeight   = {'fit', 'fit', '1x', 200};
g.ColumnWidth = {300, '1x'};
g.Padding     = [10 10 10 10];
changed = @(~,~) obj.onTrialsSettingsChanged();
cutsChanged = @(~,~) obj.onTrialsCutsChanged();

% --- row 1: dataset + actions ------------------------------------------------
top = uigridlayout(g, [1 10]);
top.Layout.Row = 1; top.Layout.Column = [1 2];
top.ColumnWidth = {'fit', 240, 'fit', 'fit', 'fit', 'fit', 'fit', '1x', 'fit', 'fit'};
top.Padding = [0 0 0 0];
uilabel(top, "Text", "Dataset:");
obj.TrialsDatasetDropDown = obj.datasetPicker(top);
obj.TrialsLoadButton = uibutton(top, "Text", "Load", "FontWeight", "bold", ...
    "Tooltip", "Read the digital lines (cached after the first read) and pair the trials in order, reusing the recorded cuts when they still match.", ...
    "ButtonPushedFcn", @(~,~) obj.onTrialsLoad("recorded"));
obj.TrialsResetButton = uibutton(top, "Text", "Reset cuts", ...
    "Tooltip", "Drop the cuts (shown and recorded) and pair every trial with every interval in order again.", ...
    "ButtonPushedFcn", @(~,~) obj.onTrialsLoad("none"));
obj.TrialsApproveButton = uibutton(top, "Text", "Approve pairing", ...
    "BackgroundColor", [0.86 0.94 0.86], ...
    "Tooltip", "Save this pairing (its cuts) as reviewed in the dataset manifest.", ...
    "ButtonPushedFcn", @(~,~) obj.onTrialsApprove("approved"));
obj.TrialsRevokeButton = uibutton(top, "Text", "Mark unreviewed", ...
    "Tooltip", "Keep these cuts in the manifest but mark the pairing as not reviewed.", ...
    "ButtonPushedFcn", @(~,~) obj.onTrialsApprove("unreviewed"));
obj.TrialsWriteButton = uibutton(top, "Text", "Write behavior .mat", ...
    "Tooltip", "Write <name>_behavior.mat with the pairing columns now.", ...
    "ButtonPushedFcn", @(~,~) obj.onTrialsWriteBehavior());
obj.TrialsEpsychToWorkspaceButton = uibutton(top, "Text", "Epsych2 to workspace", ...
    "Tooltip", "Load the associated Epsych2 session file as saved (Data, Info) into the base workspace as epsych_<name>.", ...
    "ButtonPushedFcn", @(~,~) obj.onTrialsToWorkspace("epsych"));
obj.TrialsEpsychToWorkspaceButton.Layout.Column = 9;
obj.TrialsBehaviorToWorkspaceButton = uibutton(top, "Text", "Behavior to workspace", ...
    "Tooltip", "Load the behavior struct of <name>_behavior.mat (trials with the pairing columns, info, meta, pairing) into the base workspace as behavior_<name>.", ...
    "ButtonPushedFcn", @(~,~) obj.onTrialsToWorkspace("behavior"));
obj.TrialsBehaviorToWorkspaceButton.Layout.Column = 10;

% --- row 2: summary --------------------------------------------------------
obj.TrialsSummaryLabel = uilabel(g, "Text", "Scan a project, pick a dataset with an Epsych2 session and press Load.", ...
    "WordWrap", "on", "FontColor", [0.3 0.3 0.3]);
obj.TrialsSummaryLabel.Layout.Row = 2; obj.TrialsSummaryLabel.Layout.Column = [1 2];

% --- row 3 left: settings and cuts -------------------------------------------
sp = uipanel(g, "Title", "Digital lines and pairing");
sp.Layout.Row = 3; sp.Layout.Column = 1;
sg = uigridlayout(sp, [5 2]);
sg.RowHeight = {'fit', 'fit', '1x', 'fit', 'fit'};
sg.ColumnWidth = {'fit', '1x'};
obj.TrialsPairCheckBox = uicheckbox(sg, "Text", "Pair trials in the behavior step", "Value", true, ...
    "ValueChangedFcn", changed);
obj.TrialsPairCheckBox.Layout.Row = 1; obj.TrialsPairCheckBox.Layout.Column = [1 2];
lbl = uilabel(sg, "Text", "Trial line:"); lbl.Layout.Row = 2; lbl.Layout.Column = 1;
obj.TrialsLineDropDown = uidropdown(sg, "Items", {'InTrial'}, "Value", 'InTrial', "Editable", "on", ...
    "Tooltip", "Digital line that is on for the duration of each trial (type a name or pick a loaded line).", ...
    "ValueChangedFcn", changed);
obj.TrialsLineDropDown.Layout.Row = 2; obj.TrialsLineDropDown.Layout.Column = 2;
obj.TrialsLinesTable = uitable(sg, "ColumnName", {'Line', 'Intervals', 'Inverted'}, ...
    "ColumnEditable", [false false true], "ColumnWidth", {110, 65, 70}, "RowName", {}, ...
    "Tooltip", "Tick lines with inverted polarity: on while low, onset = falling edge, offset = rising edge. Applies to pairing and to the events written by the Signals step.", ...
    "CellEditCallback", changed);
obj.TrialsLinesTable.Layout.Row = 3; obj.TrialsLinesTable.Layout.Column = [1 2];
obj.TrialsLinesTable.Data = table(strings(0, 1), zeros(0, 1), false(0, 1), ...
    'VariableNames', {'Line', 'Intervals', 'Inverted'});

cp = uipanel(sg, "Title", "Resolve a count mismatch (this dataset)");
cp.Layout.Row = 4; cp.Layout.Column = [1 2];
cg = uigridlayout(cp, [3 3]);
cg.RowHeight = {'fit', 'fit', 'fit'};
cg.ColumnWidth = {'1x', 64, 64};
cg.Padding = [6 6 6 6];
cg.RowSpacing = 4;
h = uilabel(cg, "Text", "Cut from the", "FontColor", [0.4 0.4 0.4]); h.Layout.Row = 1; h.Layout.Column = 1;
h = uilabel(cg, "Text", "start", "HorizontalAlignment", "center"); h.Layout.Row = 1; h.Layout.Column = 2;
h = uilabel(cg, "Text", "end", "HorizontalAlignment", "center"); h.Layout.Row = 1; h.Layout.Column = 3;
h = uilabel(cg, "Text", "Epsych2 trials"); h.Layout.Row = 2; h.Layout.Column = 1;
obj.TrialsCutIntervalsLabel = uilabel(cg, "Text", "InTrial intervals");
obj.TrialsCutIntervalsLabel.Layout.Row = 3; obj.TrialsCutIntervalsLabel.Layout.Column = 1;
tips = ["Trials Epsych2 ran before the recording started (dropped before pairing).", ...
        "Trials Epsych2 ran after the recording stopped (dropped before pairing)."; ...
        "Intervals at the start of the recording that are not whole trials (dropped before pairing).", ...
        "Intervals at the end of the recording that are not whole trials (dropped before pairing)."];
s = gobjects(2, 2);
for r = 1:2
    for c = 1:2
        s(r, c) = uispinner(cg, "Limits", [0 Inf], "Step", 1, "RoundFractionalValues", "on", ...
            "Value", 0, "Enable", "off", "Tooltip", tips(r, c), "ValueChangedFcn", cutsChanged);
        s(r, c).Layout.Row = r + 1; s(r, c).Layout.Column = c + 1;
    end
end
obj.TrialsCutSpinners = s;

lbl = uilabel(sg, "WordWrap", "on", "FontColor", [0.4 0.4 0.4], "Text", ...
    "Trials pair in order with the trial line's intervals. When the counts differ, cut the trials run before the recording started (or after it stopped), or the partial intervals at the recording edges, then Approve.");
lbl.Layout.Row = 5; lbl.Layout.Column = [1 2];

% --- row 3 right: trials ---------------------------------------------------
% Columns are laid out by refreshTrialsTable; the context menu adds or removes
% Epsych2 parameter columns and is rebuilt each time it opens.
obj.TrialsTable = uitable(g, "RowName", {}, ...
    "ColumnName", {'Trial', 'TrialIndex', 'Interval', 'Onset (s)', 'Offset (s)', ...
        'Onset sample', 'Offset sample', 'Flag', 'Other lines'}, ...
    "ColumnWidth", {45, 70, 60, 80, 80, 95, 95, 70, 'auto'}, ...
    "ColumnSortable", true, "ColumnRearrangeable", "on", ...
    "Tooltip", "Click a header to sort, drag it to move the column. Right-click to add or remove Epsych2 parameter columns.", ...
    "ContextMenu", uicontextmenu(obj.Fig, "ContextMenuOpeningFcn", @(m, evt) obj.onTrialsTableMenu(m, evt)));
obj.TrialsTable.Layout.Row = 3; obj.TrialsTable.Layout.Column = 2;

% --- row 4: the digital lines over the recording -----------------------------
obj.TrialsAxes = uiaxes(g);
obj.TrialsAxes.Layout.Row = 4; obj.TrialsAxes.Layout.Column = [1 2];
obj.TrialsAxes.InteractionOptions.LimitsDimensions = "x";   % wheel zoom (about the cursor), drag pan and toolbar zoom move time only
title(obj.TrialsAxes, "Digital lines over the recording");
xlabel(obj.TrialsAxes, "Time (s)");
% Right-click: the trial line's onset / offset lines (shown by default), grid
% lines (hidden) and Trial labels, the Epsych2 parameter values written above
% each trial (none; the list is built as the menu opens).
cm = uicontextmenu(obj.Fig, "ContextMenuOpeningFcn", @(~,~) obj.onTrialsPlotMenu());
obj.TrialsEdgesMenu = uimenu(cm, "Text", "Trial onset / offset lines", "Checked", "on", ...
    "MenuSelectedFcn", @(m, ~) toggleTrialEdges(m, obj.TrialsAxes));
obj.TrialsGridMenu = uimenu(cm, "Text", "Grid lines", "Checked", "off", ...
    "MenuSelectedFcn", @(m, ~) toggleGrid(m, obj.TrialsAxes));
obj.TrialsLabelsMenu = uimenu(cm, "Text", "Trial labels", "Separator", "on");
obj.TrialsAxes.ContextMenu = cm;

obj.syncTrialsButtons();
obj.syncTrialsCuts();
end


function toggleTrialEdges(menu, ax)
%toggleTrialEdges  Show or hide the dotted lines at the trial line's onsets and offsets.
menu.Checked = ~menu.Checked;
set(findall(ax, "Tag", "trialEdges"), "Visible", menu.Checked);
end


function toggleGrid(menu, ax)
%toggleGrid  Show or hide the plot's grid lines.
menu.Checked = ~menu.Checked;
ax.XGrid = menu.Checked;
ax.YGrid = menu.Checked;
end
