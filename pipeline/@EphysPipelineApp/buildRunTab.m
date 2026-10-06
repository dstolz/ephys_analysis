function buildRunTab(obj)
%buildRunTab  Run the whole pipeline: step checklist (with how many
%   background Kilosort4 runs go at once, Sorting.MaxConcurrent, the GPUs
%   they share, Sorting.Devices, and whether the Run queues the waiting
%   ones with the monitor instead of waiting), validate / plan,
%   run / dry run / cancel, progress bars, validation issues, results,
%   merged log and the background Kilosort4 runs being monitored (Stop
%   runs... stops running ones, Stop queue drops the queued ones). A diagram
%   of the run's steps (the one underway highlighted, each with its
%   percentage) always takes the right quarter of the right side
%   (runDiagramHTML), and the computer's CPU, memory, disk and GPU use is
%   always shown under the Steps panel (resource_monitor.ps1, started by
%   onTabChanged when the tab is first shown). Copy outputs to (under the
%   steps) is the config's Transfer section: each dataset's outputs copied
%   or moved to <folder>/<subject>/<session> in the background; the
%   copies' progress and Stop copying are the last row on the right
%   (showTransferProgress, onStopTransfers).

g = uigridlayout(obj.TabRun, [2 2]);
g.RowHeight   = {'1x', 'fit'};
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
tip = "How many sorting runs go at once in the background; each further dataset waits for one to finish. " + ...
    "Blocking runs (Sorting tab, Execution) always go one at a time. With no GPU listed below, or one, " + ...
    "every run goes on the same GPU, where several at once can run out of memory (Validate warns).";
l = uilabel(kg, "Text", "Kilosort4 runs at once:", "Tooltip", tip); l.Layout.Row = 1; l.Layout.Column = 1;
obj.RunKSAtOnceLabel = l;   % showSorterControls names the selected sorter
obj.RunKSAtOnceSpinner = uispinner(kg, "Limits", [1 Inf], "Step", 1, "RoundFractionalValues", "on", ...
    "Value", 1, "Tooltip", tip, "ValueChangedFcn", @(~,~) obj.onConfigChanged());
obj.RunKSAtOnceSpinner.Layout.Row = 1; obj.RunKSAtOnceSpinner.Layout.Column = 2;
tip = "Torch devices the runs share, e.g. ""cuda:0, cuda:1"": each run gets the GPU the fewest running runs use. " + ...
    "Blocking runs use the first. Blank = Kilosort4's own choice (the first GPU). SpikeInterface sorters do not take a device.";
l = uilabel(kg, "Text", "GPUs:", "Tooltip", tip); l.Layout.Row = 2; l.Layout.Column = 1;
obj.RunKSDevicesField = uieditfield(kg, "text", "Placeholder", "e.g. cuda:0, cuda:1", "Tooltip", tip, ...
    "ValueChangedFcn", @(~,~) obj.onConfigChanged());
obj.RunKSDevicesField.Layout.Row = 2; obj.RunKSDevicesField.Layout.Column = [2 3];
obj.RunKSQueueCheckBox = uicheckbox(kg, "Text", "Queue the waiting runs; the Run goes on", ...
    "Tooltip", "Hand the datasets that wait for a free sorting slot to the background monitor, which starts " + ...
    "each as a slot frees, so the Run carries on with its next step at once. Stop queue (under the log) " + ...
    "drops the ones not started yet; closing the app asks whether to keep them for next time.");
obj.RunKSQueueCheckBox.Layout.Row = 3; obj.RunKSQueueCheckBox.Layout.Column = [1 3];
obj.RunSignalsCheckBox   = uicheckbox(sg, "Text", "Signals: LFP / MUA / SPIKE / AUX .mat", "ValueChangedFcn", @(src,~) mirror(obj, "SigEnableCheckBox", src.Value));
obj.RunSpikesCheckBox    = uicheckbox(sg, "Text", "Spikes: detected spikes .mat", "ValueChangedFcn", @(src,~) mirror(obj, "SpkEnableCheckBox", src.Value));
obj.RunExportCheckBox    = uicheckbox(sg, "Text", "Export: analysis-toolbox files", "ValueChangedFcn", @(src,~) mirror(obj, "ExpEnableCheckBox", src.Value));
obj.RunAnalysisCheckBox  = uicheckbox(sg, "Text", "Analysis: figures and report", "ValueChangedFcn", @(src,~) mirror(obj, "AnaEnableCheckBox", src.Value));
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
buildTransferControls(obj, sg);
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

% --- resource use, under the Steps panel (sampled every 2 s by a small idle-priority process outside MATLAB)
obj.RunMonitorPanel = uipanel(g, "Title", "Resource use");
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

% --- right side: progress + results + log | the run diagram -------------------
obj.RunSplitGrid = uigridlayout(g, [1 2]);
obj.RunSplitGrid.Layout.Row = [1 2]; obj.RunSplitGrid.Layout.Column = 2;
obj.RunSplitGrid.RowHeight = {'1x'};
obj.RunSplitGrid.ColumnWidth = {'3x', '1x'};
obj.RunSplitGrid.ColumnSpacing = 10;
obj.RunSplitGrid.Padding = [0 0 0 0];

right = uigridlayout(obj.RunSplitGrid, [10 3]);
right.Layout.Row = 1; right.Layout.Column = 1;
right.RowHeight   = {20, 20, 'fit', 'fit', 110, '1x', 'fit', '1x', 'fit', 'fit'};
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
obj.RunKSLabel = uilabel(ksg, "Text", "Background sorting runs: none.", "FontColor", [0.4 0.4 0.4]);
obj.RunKSStopRunsButton = uibutton(ksg, "Text", "Stop runs...", "Enable", "off", ...
    "Tooltip", "Stop background sorting runs that are going; what they wrote so far stays. Their rows turn cancelled.", ...
    "ButtonPushedFcn", @(~,~) obj.onStopKSRuns());
obj.RunKSStopQueueButton = uibutton(ksg, "Text", "Stop queue", "Enable", "off", ...
    "Tooltip", "Drop the queued sorting runs that have not started. Runs already going carry on.", ...
    "ButtonPushedFcn", @(~,~) obj.onStopKSQueue());

tg = uigridlayout(right, [1 3], "Padding", [0 0 0 0], "ColumnSpacing", 6);
tg.Layout.Row = 10; tg.Layout.Column = [1 3];
tg.ColumnWidth = {'1x', 160, 'fit'}; tg.RowHeight = {30};
obj.RunTransferLabel = uilabel(tg, "Text", "Output copies: none.", "FontColor", [0.4 0.4 0.4]);
p = uipanel(tg, "BorderType", "line", "BackgroundColor", [0.92 0.92 0.94]);
p.Layout.Row = 1; p.Layout.Column = 2;
obj.RunTransferBar = uigridlayout(p, [1 2], "Padding", [0 0 0 0], "ColumnSpacing", 0, ...
    "RowSpacing", 0, "BackgroundColor", [0.92 0.92 0.94]);
obj.RunTransferBar.RowHeight = {'1x'};
obj.RunTransferBar.ColumnWidth = {0, '1x'};
uipanel(obj.RunTransferBar, "BorderType", "none", "BackgroundColor", [0.25 0.55 0.85]);
obj.RunTransferStopButton = uibutton(tg, "Text", "Stop copying...", "Enable", "off", ...
    "Tooltip", "Stop copying the outputs: the files being copied stop where they are, what is copied stays there, the rest are not copied, and a move removes nothing more here.", ...
    "ButtonPushedFcn", @(~,~) obj.onStopTransfers());

obj.RunDiagramPanel = uipanel(obj.RunSplitGrid, "Title", "Run diagram");
obj.RunDiagramPanel.Layout.Row = 1; obj.RunDiagramPanel.Layout.Column = 2;
dg = uigridlayout(obj.RunDiagramPanel, [1 1], "Padding", [0 0 0 0]);
obj.RunDiagramHTML = uihtml(dg, "HTMLSource", char(obj.runDiagramHTML()));
obj.resetRunDiagram();
end


function buildTransferControls(obj, parent)
%buildTransferControls  Copy outputs to: the config's Transfer section, under the steps.
%   Each dataset's outputs go to <folder>/<key> (its recording folder below
%   the project root, e.g. subject/session), copied or moved, as each step
%   writes them or once the run is over; IfExists when that folder is
%   already there. The controls follow the box (onTransferControlsChanged).
d = EphysPipelineConfig.defaults("Transfer");
tip = "Copy (or move) each dataset's outputs to <this folder>\<subject>\<session>: its recording folder below the project root, " + ...
    "so the copies have the raw data's folders. The copying runs outside MATLAB (robocopy) while the run goes on; " + ...
    "its progress is under the log. Not a dry run.";
changed = @(~,~) obj.onTransferControlsChanged();
xg = uigridlayout(parent, [4 4]);
xg.Padding = [0 4 0 0]; xg.RowSpacing = 4; xg.ColumnSpacing = 4;
xg.ColumnWidth = {'fit', '1x', 'fit', 'fit'}; xg.RowHeight = {'fit', 'fit', 'fit', 'fit'};
obj.RunTransferCheckBox = uicheckbox(xg, "Text", "Copy outputs to:", "Value", d.Enabled, "Tooltip", tip, ...
    "ValueChangedFcn", changed);
obj.RunTransferCheckBox.Layout.Row = 1; obj.RunTransferCheckBox.Layout.Column = 1;
obj.RunTransferDestField = uieditfield(xg, "text", "Placeholder", "e.g. S:\backup\EXTRACT", "Tooltip", tip, ...
    "ValueChangedFcn", changed);
obj.RunTransferDestField.Layout.Row = 1; obj.RunTransferDestField.Layout.Column = [2 3];
obj.RunTransferBrowseButton = uibutton(xg, "Text", "...", "Tooltip", "Choose the folder.", ...
    "ButtonPushedFcn", @(~,~) obj.onBrowseTransferDest());
obj.RunTransferBrowseButton.Layout.Row = 1; obj.RunTransferBrowseButton.Layout.Column = 4;
obj.RunTransferMethodDropDown = uidropdown(xg, "Items", {'copy', 'move'}, "ItemsData", {'copy', 'move'}, ...
    "Value", char(d.Method), "ValueChangedFcn", changed, "Tooltip", ...
    ["copy: the outputs stay here too" ...
     "move: once copied and checked, they are removed here when the run is over (the manifest stays; a moved sort folder becomes the dataset's sorting folder)"]);
obj.RunTransferMethodDropDown.Layout.Row = 2; obj.RunTransferMethodDropDown.Layout.Column = 1;
obj.RunTransferWhenDropDown = uidropdown(xg, "Items", {'after each step', 'after the run'}, ...
    "ItemsData", {'step', 'run'}, "Value", char(d.When), "ValueChangedFcn", changed, "Tooltip", ...
    ["after each step: each output as soon as its step has written it, while the next steps run (a background sort once it has finished)" ...
     "after the run: every output once the run is over"]);
obj.RunTransferWhenDropDown.Layout.Row = 2; obj.RunTransferWhenDropDown.Layout.Column = [2 4];
l = uilabel(xg, "Text", "If it is there:", "HorizontalAlignment", "right", "Tooltip", ...
    "When the dataset's folder at the destination already holds something.");
l.Layout.Row = 3; l.Layout.Column = 1;
obj.RunTransferIfExistsDropDown = uidropdown(xg, "Items", {'new version', 'overwrite', 'skip'}, ...
    "ItemsData", {'version', 'overwrite', 'skip'}, "Value", char(d.IfExists), "ValueChangedFcn", changed, "Tooltip", ...
    ["new version: the run's copies go to a new folder <session>_v2 (_v3, ...); the earlier copy stays as it is" ...
     "overwrite: files already there are replaced" ...
     "skip: files already there are left as they are; only the missing ones are copied"]);
obj.RunTransferIfExistsDropDown.Layout.Row = 3; obj.RunTransferIfExistsDropDown.Layout.Column = [2 4];
obj.RunTransferHashCheckBox = uicheckbox(xg, "Text", "Check each copy by SHA-256", "Value", d.Verify == "hash", ...
    "Tooltip", "Check every copy against its source by SHA-256 checksum (reads both once more); off: by size and time.", ...
    "ValueChangedFcn", changed);
obj.RunTransferHashCheckBox.Layout.Row = 4; obj.RunTransferHashCheckBox.Layout.Column = [1 4];
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
