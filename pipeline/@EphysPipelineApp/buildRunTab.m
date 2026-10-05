function buildRunTab(obj)
%buildRunTab  Run the whole pipeline: step checklist (with how many
%   background Kilosort4 runs go at once, Sorting.MaxConcurrent, the GPUs
%   they share, Sorting.Devices, and whether the Run queues the waiting
%   ones with the monitor instead of waiting), validate / plan,
%   run / dry run / cancel, progress bars, validation issues, results,
%   merged log and the background Kilosort4 runs being monitored (Stop
%   runs... stops running ones, Stop queue drops the queued ones). With
%   Show the run diagram ticked, a diagram of the run's steps (the one
%   underway highlighted, each with its percentage) takes the right quarter
%   of the right side (onRunDiagramToggled, runDiagramHTML). With Monitor CPU,
%   memory, disk and GPU ticked, their use is shown under the Steps panel
%   (onResourceMonitorToggled, resource_monitor.ps1).

g = uigridlayout(obj.TabRun, [2 2]);
g.RowHeight   = {'1x', 0};   % onResourceMonitorToggled: {'1x', 'fit'} while monitoring
obj.RunLeftGrid = g;
g.ColumnWidth = {300, '1x'};
g.Padding     = [10 10 10 10];
%(the Validate / Plan / Run buttons have their own callbacks; checklist ticks mirror the step tabs)

% --- steps checklist ---------------------------------------------------------
steps = uipanel(g, "Title", "Steps (same switches as on each tab)");
steps.Layout.Row = 1; steps.Layout.Column = 1;
sg = uigridlayout(steps, [16 1]);
sg.RowHeight = [repmat({'fit'}, 1, 15), {'1x'}];
uilabel(sg, "Text", "Probe check (always)", "FontColor", [0.4 0.4 0.4]);
obj.RunBehaviorCheckBox  = uicheckbox(sg, "Text", "Behavior: match Epsych2 sessions", "ValueChangedFcn", @(src,~) mirror(obj, "BehEnableCheckBox", src.Value));
obj.RunArtifactsCheckBox = uicheckbox(sg, "Text", "Artifacts: automatic detection", "ValueChangedFcn", @(src,~) mirror(obj, "ArtEnableCheckBox", src.Value));
obj.RunSortingCheckBox   = uicheckbox(sg, "Text", "Sorting: Kilosort4", "ValueChangedFcn", @(src,~) mirror(obj, "SortEnableCheckBox", src.Value));
kg = uigridlayout(sg, [3 3]);
kg.Padding = [20 0 0 0]; kg.ColumnWidth = {'fit', 60, '1x'}; kg.RowHeight = {'fit', 'fit', 'fit'}; kg.ColumnSpacing = 4;
tip = "How many Kilosort4 runs go at once in the background; each further dataset waits for one to finish. " + ...
    "Blocking runs (Sorting tab, Execution) always go one at a time.";
l = uilabel(kg, "Text", "Kilosort4 runs at once:", "Tooltip", tip); l.Layout.Row = 1; l.Layout.Column = 1;
obj.RunKSAtOnceSpinner = uispinner(kg, "Limits", [1 Inf], "Step", 1, "RoundFractionalValues", "on", ...
    "Value", 1, "Tooltip", tip, "ValueChangedFcn", @(~,~) obj.onConfigChanged());
obj.RunKSAtOnceSpinner.Layout.Row = 1; obj.RunKSAtOnceSpinner.Layout.Column = 2;
tip = "Torch devices the runs share, e.g. ""cuda:0, cuda:1"": each run gets the GPU the fewest running runs use. " + ...
    "Blocking runs use the first. Blank = Kilosort4's own choice (the first GPU).";
l = uilabel(kg, "Text", "GPUs:", "Tooltip", tip); l.Layout.Row = 2; l.Layout.Column = 1;
obj.RunKSDevicesField = uieditfield(kg, "text", "Placeholder", "e.g. cuda:0, cuda:1", "Tooltip", tip, ...
    "ValueChangedFcn", @(~,~) obj.onConfigChanged());
obj.RunKSDevicesField.Layout.Row = 2; obj.RunKSDevicesField.Layout.Column = [2 3];
obj.RunKSQueueCheckBox = uicheckbox(kg, "Text", "Queue the waiting runs; the Run goes on", ...
    "Tooltip", "Hand the datasets that wait for a free Kilosort4 slot to the background monitor, which starts " + ...
    "each as a slot frees, so the Run carries on with its next step at once. Stop queue (under the log) " + ...
    "drops the ones not started yet; closing the app drops them too.");
obj.RunKSQueueCheckBox.Layout.Row = 3; obj.RunKSQueueCheckBox.Layout.Column = [1 3];
obj.RunSignalsCheckBox   = uicheckbox(sg, "Text", "Signals: LFP / MUA / SPIKE / AUX .mat", "ValueChangedFcn", @(src,~) mirror(obj, "SigEnableCheckBox", src.Value));
obj.RunSpikesCheckBox    = uicheckbox(sg, "Text", "Spikes: detected / sorted .mat", "ValueChangedFcn", @(src,~) mirror(obj, "SpkEnableCheckBox", src.Value));
obj.RunExportCheckBox    = uicheckbox(sg, "Text", "Export: analysis-toolbox files", "ValueChangedFcn", @(src,~) mirror(obj, "ExpEnableCheckBox", src.Value));
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
obj.RunButton = uibutton(bg, "Text", "Run pipeline", ...
    "ButtonPushedFcn", @(~,~) obj.runPipeline());
obj.RunDryButton = uibutton(bg, "Text", "Dry run", "ButtonPushedFcn", @(~,~) obj.runPipeline(DryRun=true));
obj.RunCancelButton = uibutton(bg, "Text", "Cancel", "Enable", "off", ...
    "ButtonPushedFcn", @(~,~) obj.onCancelRun());
sg.RowHeight([obj.RunValidateButton.Layout.Row, obj.RunPlanButton.Layout.Row, bg.Layout.Row]) = {30};
obj.RunDiagramCheckBox = uicheckbox(sg, "Text", "Show the run diagram", ...
    "Tooltip", "Draw the steps beside the progress bars: the one underway highlighted, each with its % done.", ...
    "ValueChangedFcn", @(~,~) obj.onRunDiagramToggled());
obj.RunMonitorCheckBox = uicheckbox(sg, "Text", "Monitor CPU, memory, disk and GPU", ...
    "Tooltip", "Show the computer's CPU, memory, disk and GPU use under this panel, sampled every 2 s by a small idle-priority process outside MATLAB.", ...
    "ValueChangedFcn", @(~,~) obj.onResourceMonitorToggled());

% --- resource use (when monitored), under the Steps panel ----------------------
obj.RunMonitorPanel = uipanel(g, "Title", "Resource use", "Visible", "off");
obj.RunMonitorPanel.Layout.Row = 2; obj.RunMonitorPanel.Layout.Column = 1;
mg = uigridlayout(obj.RunMonitorPanel, [5 3]);
mg.RowHeight = {18, 18, 18, 18, 'fit'};
mg.ColumnWidth = {'fit', '1x', 112};
mg.RowSpacing = 6;
names = ["CPU" "Memory" "Disk" "GPU"];
for k = 1:4
    l = uilabel(mg, "Text", names(k) + ":"); l.Layout.Row = k; l.Layout.Column = 1;
    obj.RunMonitorBars(k) = makeBar(mg, k);
    obj.RunMonitorTexts(k) = uilabel(mg, "Text", "", "FontColor", [0.3 0.3 0.3]);
    obj.RunMonitorTexts(k).Layout.Row = k; obj.RunMonitorTexts(k).Layout.Column = 3;
end
obj.RunMonitorNote = uilabel(mg, "Text", "", "WordWrap", "on", "FontColor", [0.4 0.4 0.4]);
obj.RunMonitorNote.Layout.Row = 5; obj.RunMonitorNote.Layout.Column = [1 3];

% --- right side: progress + results + log | the run diagram (when shown) -----
obj.RunSplitGrid = uigridlayout(g, [1 2]);
obj.RunSplitGrid.Layout.Row = [1 2]; obj.RunSplitGrid.Layout.Column = 2;
obj.RunSplitGrid.RowHeight = {'1x'};
obj.RunSplitGrid.ColumnWidth = {'1x', 0};   % onRunDiagramToggled: {'3x', '1x'} while shown
obj.RunSplitGrid.ColumnSpacing = 0;
obj.RunSplitGrid.Padding = [0 0 0 0];

right = uigridlayout(obj.RunSplitGrid, [9 3]);
right.Layout.Row = 1; right.Layout.Column = 1;
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

ksg = uigridlayout(right, [1 3], "Padding", [0 0 0 0], "ColumnSpacing", 6);
ksg.Layout.Row = 9; ksg.Layout.Column = [1 3];
ksg.ColumnWidth = {'1x', 'fit', 'fit'}; ksg.RowHeight = {30};
obj.RunKSLabel = uilabel(ksg, "Text", "Background Kilosort4 runs: none.", "FontColor", [0.4 0.4 0.4]);
obj.RunKSStopRunsButton = uibutton(ksg, "Text", "Stop runs...", "Enable", "off", ...
    "Tooltip", "Stop background Kilosort4 runs that are going; what they wrote so far stays. Their rows turn cancelled.", ...
    "ButtonPushedFcn", @(~,~) obj.onStopKSRuns());
obj.RunKSStopQueueButton = uibutton(ksg, "Text", "Stop queue", "Enable", "off", ...
    "Tooltip", "Drop the queued Kilosort4 runs that have not started. Runs already going carry on.", ...
    "ButtonPushedFcn", @(~,~) obj.onStopKSQueue());

obj.RunDiagramPanel = uipanel(obj.RunSplitGrid, "Title", "Run diagram", "Visible", "off");
obj.RunDiagramPanel.Layout.Row = 1; obj.RunDiagramPanel.Layout.Column = 2;
dg = uigridlayout(obj.RunDiagramPanel, [1 1], "Padding", [0 0 0 0]);
obj.RunDiagramHTML = uihtml(dg, "HTMLSource", char(obj.runDiagramHTML()));
obj.resetRunDiagram();
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
