function buildRunTab(obj)
%buildRunTab  Run the whole pipeline: step checklist, validate / plan,
%   run / dry run / cancel, progress bars, validation issues, results,
%   merged log and the background Kilosort4 runs being monitored.

g = uigridlayout(obj.TabRun, [2 2]);
g.RowHeight   = {'fit', '1x'};
g.ColumnWidth = {300, '1x'};
g.Padding     = [10 10 10 10];
%(the Validate / Plan / Run buttons have their own callbacks; checklist ticks mirror the step tabs)

% --- steps checklist ---------------------------------------------------------
steps = uipanel(g, "Title", "Steps (same switches as on each tab)");
steps.Layout.Row = [1 2]; steps.Layout.Column = 1;
sg = uigridlayout(steps, [13 1]);
sg.RowHeight = [repmat({'fit'}, 1, 12), {'1x'}];
uilabel(sg, "Text", "Probe check (always)", "FontColor", [0.4 0.4 0.4]);
obj.RunBehaviorCheckBox  = uicheckbox(sg, "Text", "Behavior: match Epsych2 sessions", "ValueChangedFcn", @(src,~) mirror(obj, "BehEnableCheckBox", src.Value));
obj.RunArtifactsCheckBox = uicheckbox(sg, "Text", "Artifacts: automatic detection", "ValueChangedFcn", @(src,~) mirror(obj, "ArtEnableCheckBox", src.Value));
obj.RunSortingCheckBox   = uicheckbox(sg, "Text", "Sorting: SpikeInterface + Kilosort4", "ValueChangedFcn", @(src,~) mirror(obj, "SortEnableCheckBox", src.Value));
obj.RunSignalsCheckBox   = uicheckbox(sg, "Text", "Signals: LFP / MUA / SPIKE / AUX .mat", "ValueChangedFcn", @(src,~) mirror(obj, "SigEnableCheckBox", src.Value));
obj.RunSpikesCheckBox    = uicheckbox(sg, "Text", "Spikes: detected / sorted .mat", "ValueChangedFcn", @(src,~) mirror(obj, "SpkEnableCheckBox", src.Value));
obj.RunExportCheckBox    = uicheckbox(sg, "Text", "Export: Chronux / FieldTrip", "ValueChangedFcn", @(src,~) mirror(obj, "ExpEnableCheckBox", src.Value));
pg = uigridlayout(sg, [1 3]);
pg.Padding = [0 0 0 0]; pg.ColumnWidth = {'1x', 'fit', 56}; pg.RowHeight = {'fit'}; pg.ColumnSpacing = 4;
obj.RunParallelCheckBox = uicheckbox(pg, "Text", "Parallel: chunks on the process pool", ...
    "Tooltip", "Artifacts and spike detection process their chunks on a process pool (Parallel Computing Toolbox). Results are identical; the worker count is capped by free memory.", ...
    "ValueChangedFcn", @(~,~) obj.onParallelControlsChanged());
l = uilabel(pg, "Text", "Max workers:");
l.Tooltip = "Cap on chunks in flight at once; blank = automatic (from free memory).";
obj.RunMaxWorkersField = uieditfield(pg, "text", "Placeholder", "auto", "Enable", "off", ...
    "Tooltip", "Cap on chunks in flight at once; blank = automatic (from free memory).", ...
    "ValueChangedFcn", @(~,~) obj.onParallelControlsChanged());
obj.RunSelectionLabel = uilabel(sg, "Text", "Selection: (scan first)", "WordWrap", "on", "FontColor", [0.3 0.3 0.3]);
obj.RunValidateButton = uibutton(sg, "Text", "Validate config", "ButtonPushedFcn", @(~,~) obj.onValidate());
obj.RunPlanButton     = uibutton(sg, "Text", "Plan (writes nothing)", "ButtonPushedFcn", @(~,~) obj.onPlan());
bg = uigridlayout(sg, [1 3]);
bg.Padding = [0 0 0 0]; bg.ColumnWidth = {'1x', 'fit', 'fit'};
obj.RunButton = uibutton(bg, "Text", "Run pipeline", "FontWeight", "bold", ...
    "ButtonPushedFcn", @(~,~) obj.runPipeline());
obj.RunDryButton = uibutton(bg, "Text", "Dry run", "ButtonPushedFcn", @(~,~) obj.runPipeline(DryRun=true));
obj.RunCancelButton = uibutton(bg, "Text", "Cancel", "Enable", "off", ...
    "ButtonPushedFcn", @(~,~) obj.onCancelRun());

% --- progress + results + log -------------------------------------------------
right = uigridlayout(g, [9 3]);
right.Layout.Row = [1 2]; right.Layout.Column = 2;
right.RowHeight   = {20, 20, 'fit', 'fit', 110, '1x', 'fit', '1x', 'fit'};
right.ColumnWidth = {'fit', '1x', 120};
right.Padding = [0 0 0 0];

l = uilabel(right, "Text", "Overall:"); l.Layout.Row = 1; l.Layout.Column = 1;
obj.RunOverallBar = makeBar(right, 1);
obj.RunOverallText = uilabel(right, "Text", "", "FontColor", [0.3 0.3 0.3]);
obj.RunOverallText.Layout.Row = 1; obj.RunOverallText.Layout.Column = 3;
l = uilabel(right, "Text", "Current:"); l.Layout.Row = 2; l.Layout.Column = 1;
obj.RunStepBar = makeBar(right, 2);
obj.RunStepText = uilabel(right, "Text", "", "FontColor", [0.3 0.3 0.3]);
obj.RunStepText.Layout.Row = 2; obj.RunStepText.Layout.Column = 3;
obj.RunStepLabel = uilabel(right, "Text", "Idle.", "FontColor", [0.4 0.4 0.4]);
obj.RunStepLabel.Layout.Row = 3; obj.RunStepLabel.Layout.Column = [1 3];

l = uilabel(right, "Text", "Issues (Validate)", "FontWeight", "bold"); l.Layout.Row = 4; l.Layout.Column = [1 3];
obj.RunIssuesTable = uitable(right, "ColumnName", {'Step', 'Field', 'Severity', 'Message'}, ...
    "ColumnWidth", {80, 140, 70, '1x'}, "RowName", {});
obj.RunIssuesTable.Layout.Row = 5; obj.RunIssuesTable.Layout.Column = [1 3];

obj.RunResultsTable = uitable(right, "ColumnName", {'Step', 'Dataset', 'Key', 'Output', 'Status', 'Note'}, ...
    "ColumnWidth", {80, 'fit', 'fit', '2x', 130, '1x'}, "RowName", {});
obj.RunResultsTable.Layout.Row = 6; obj.RunResultsTable.Layout.Column = [1 3];

l = uilabel(right, "Text", "Log", "FontWeight", "bold"); l.Layout.Row = 7; l.Layout.Column = [1 3];
obj.RunLogArea = uitextarea(right, "Editable", "off");
obj.RunLogArea.Layout.Row = 8; obj.RunLogArea.Layout.Column = [1 3];

obj.RunKSLabel = uilabel(right, "Text", "Background Kilosort4 runs: none.", "FontColor", [0.4 0.4 0.4]);
obj.RunKSLabel.Layout.Row = 9; obj.RunKSLabel.Layout.Column = [1 3];
end


function bar = makeBar(parent, row)
%makeBar  Simple horizontal progress bar in column 2 of PARENT at ROW.
bgc = [0.92 0.92 0.94];
p = uipanel(parent, "BorderType", "line", "BackgroundColor", bgc);
p.Layout.Row = row; p.Layout.Column = 2;
bar = uigridlayout(p, [1 2], "Padding", [0 0 0 0], "ColumnSpacing", 0, ...
    "RowSpacing", 0, "BackgroundColor", bgc);
bar.RowHeight   = {'1x'};
bar.ColumnWidth = {0, '1x'};
fill = uipanel(bar, "BorderType", "none", "BackgroundColor", [0.25 0.55 0.85]);
fill.Layout.Row = 1; fill.Layout.Column = 1;
end


function mirror(obj, prop, value)
%mirror  A Run-tab checklist tick is the same thing as the step tab's Enabled box.
if obj.Applying; return; end
obj.(prop).Value = logical(value);
obj.onConfigChanged();
end
