function buildArtifactsTab(obj)
%buildArtifactsTab  Artifacts step: automatic detection settings + preview,
%   an artifact viewer, and the manual periods of the active dataset (the
%   Dataset box). Edits the config's Artifacts section (gatherArtifactsSection /
%   applyArtifactsSection). Manual periods are per dataset (marked on the
%   Visualize tab, saved in the manifest) and always apply; the automatic
%   detector applies when the step is enabled. Where the intervals are used
%   (sorting, spike detection) is chosen here too. After a preview the viewer
%   steps through the detected artifacts one at a time, each with the signal
%   around it, the kept and removed samples drawn apart.
%
%   See also EphysDataset.detectArtifacts, EphysDataset.analyzeArtifacts,
%   EphysDataset.artifactIntervals, onDetectArtifacts, showArtifactView,
%   drawArtifactView.

g = uigridlayout(obj.TabArtifacts, [1 2]);
g.ColumnWidth = {400, '1x'};
g.Padding     = [10 10 10 10];
changed = @(~,~) obj.onArtifactControlsChanged();

% =================== left: controls ===================
ctrl = uipanel(g, "Title", "Automatic artifact detection (config: Artifacts)");
ctrl.Layout.Column = 1;

nRows = 18;
cg = uigridlayout(ctrl, [nRows 2]);
cg.RowHeight   = [repmat({'fit'}, 1, nRows - 1), {'1x'}];
cg.ColumnWidth = {'fit', '1x'};

row = 1;
obj.ArtEnableCheckBox = uicheckbox(cg, "Text", "Enable automatic detection", "FontWeight", "bold", "Value", false, ...
    "Tooltip", "Manual periods (marked on the Visualize tab) always apply, whether or not this is on.", ...
    "ValueChangedFcn", changed);
obj.ArtEnableCheckBox.Layout.Row = row; obj.ArtEnableCheckBox.Layout.Column = [1 2];

row = row + 1;
lab(cg, "Dataset:", row);
obj.ArtDatasetDropDown = obj.datasetPicker(cg);
obj.ArtDatasetDropDown.Layout.Row = row; obj.ArtDatasetDropDown.Layout.Column = 2;

row = row + 1;
lab(cg, "Method:", row);
obj.ArtMethodDropDown = uidropdown(cg);
obj.ArtMethodDropDown.Items = {'Running RMS (per-channel SD)', 'MAD (per-channel SD)', ...
              'Absolute microvolts', 'Common-mode (mean)'};
obj.ArtMethodDropDown.ItemsData = {'rms', 'mad', 'microvolts', 'commonmode'};
obj.ArtMethodDropDown.Value = 'rms';
obj.ArtMethodDropDown.ValueChangedFcn = changed;
obj.ArtMethodDropDown.Layout.Row = row; obj.ArtMethodDropDown.Layout.Column = 2;

row = row + 1;
lab(cg, "Threshold:", row);
obj.ArtThresholdField = uieditfield(cg, "numeric", "Value", 9, "Limits", [0 Inf], ...
    "Tooltip", "Robust SDs above the per-channel baseline (microvolts for the absolute method).", ...
    "ValueChangedFcn", changed);
obj.ArtThresholdField.Layout.Row = row; obj.ArtThresholdField.Layout.Column = 2;

row = row + 1;
lab(cg, "RMS window (ms):", row);
obj.ArtRmsWindowField = uieditfield(cg, "numeric", "Value", 1, "Limits", [0 Inf], ...
    "Tooltip", "Running-RMS window length (ms). 0 = auto (~1 ms). RMS method only.", ...
    "ValueChangedFcn", changed);
obj.ArtRmsWindowField.Layout.Row = row; obj.ArtRmsWindowField.Layout.Column = 2;

row = row + 1;
lab(cg, "Stitch gap (ms):", row);
obj.ArtMergeGapField = uieditfield(cg, "numeric", "Value", 0, "Limits", [0 Inf], ...
    "Tooltip", "Merge artifacts separated by at most this much clean signal.", ...
    "ValueChangedFcn", changed);
obj.ArtMergeGapField.Layout.Row = row; obj.ArtMergeGapField.Layout.Column = 2;

row = row + 1;
lab(cg, "Pad (ms):", row);
obj.ArtPadField = uieditfield(cg, "numeric", "Value", 0, "Limits", [0 Inf], ...
    "Tooltip", "Expand each flagged region by this much on both sides.", ...
    "ValueChangedFcn", changed);
obj.ArtPadField.Layout.Row = row; obj.ArtPadField.Layout.Column = 2;

row = row + 1;
lab(cg, "Min channels:", row);
obj.ArtMinChannelsField = uieditfield(cg, "numeric", "Value", 2, "Limits", [1 Inf], ...
    "RoundFractionalValues", "on", "Tooltip", ...
    "Channels that must exceed the threshold at the same sample (ignored for common-mode).", ...
    "ValueChangedFcn", changed);
obj.ArtMinChannelsField.Layout.Row = row; obj.ArtMinChannelsField.Layout.Column = 2;

row = row + 1;
obj.ArtFilterCheckBox = uicheckbox(cg, "Text", "High-pass before detecting", "Value", false, ...
    "Tooltip", "Detect on the high-pass-filtered signal instead of broadband (applies to runs and previews alike).", ...
    "ValueChangedFcn", changed);
obj.ArtFilterCheckBox.Layout.Row = row; obj.ArtFilterCheckBox.Layout.Column = [1 2];

row = row + 1;
lab(cg, "High-pass (Hz):", row);
obj.ArtHighpassField = uieditfield(cg, "numeric", "Value", 300, "Limits", [0 Inf], "Enable", "off", ...
    "ValueChangedFcn", changed);
obj.ArtHighpassField.Layout.Row = row; obj.ArtHighpassField.Layout.Column = 2;

row = row + 1;
obj.ArtApplySortingCheckBox = uicheckbox(cg, "Text", "Silence in sorting (SpikeInterface silence_periods)", ...
    "Value", true, "ValueChangedFcn", changed);
obj.ArtApplySortingCheckBox.Layout.Row = row; obj.ArtApplySortingCheckBox.Layout.Column = [1 2];
row = row + 1;
obj.ArtApplySpikesCheckBox = uicheckbox(cg, "Text", "Reject detected spikes inside the periods", ...
    "Value", true, "ValueChangedFcn", changed);
obj.ArtApplySpikesCheckBox.Layout.Row = row; obj.ArtApplySpikesCheckBox.Layout.Column = [1 2];
row = row + 1;
obj.ArtCacheCheckBox = uicheckbox(cg, "Text", "Cache intervals (<Name>_artifacts.json)", ...
    "Value", true, "Tooltip", "Reuse detected intervals across steps and runs while the settings and manual periods are unchanged.", ...
    "ValueChangedFcn", changed);
obj.ArtCacheCheckBox.Layout.Row = row; obj.ArtCacheCheckBox.Layout.Column = [1 2];

row = row + 1;
obj.ArtDetectButton = uibutton(cg, "Text", "Detect / Preview", ...
    "ButtonPushedFcn", @(~,~) obj.onDetectArtifacts());
obj.ArtDetectButton.Layout.Row = row; obj.ArtDetectButton.Layout.Column = [1 2];
cg.RowHeight{row} = 30;

row = row + 1;
obj.ArtStatusLabel = uilabel(cg, "Text", "", "FontColor", [0.4 0.4 0.4], "WordWrap", "on");
obj.ArtStatusLabel.Layout.Row = row; obj.ArtStatusLabel.Layout.Column = [1 2];

% ===== right: summary + per-channel table, artifact viewer, manual periods =====
right = uigridlayout(g, [6 1]);
right.Layout.Column = 2;
right.RowHeight = {'fit', 175, 'fit', '1x', 'fit', 110};
right.RowSpacing = 8;

uilabel(right, "Text", "Preview summary", "FontWeight", "bold");
top = uigridlayout(right, [1 2]);
top.Padding = [0 0 0 0];
top.ColumnWidth = {'1x', 330};
summaryPanel = uipanel(top);
sg = uigridlayout(summaryPanel, [1 1]);
sg.Padding = [8 6 8 6];
obj.ArtSummaryLabel = uilabel(sg, "Text", "Pick a dataset and press Detect / Preview.", ...
    "VerticalAlignment", "top", "WordWrap", "on", "FontName", "monospaced", "FontColor", [0.2 0.2 0.2]);
obj.ArtChannelTable = uitable(top, "ColumnName", {'Ch', 'Name', '#Samples', '% of duration'}, ...
    "ColumnWidth", {36, '1x', 80, 95}, "RowName", {});

% Artifact viewer: one detected artifact at a time with the signal around it
% (showArtifactView reads, drawArtifactView draws).
vg = uigridlayout(right, [2 12]);
vg.Layout.Row = 3; vg.Padding = [0 0 0 0]; vg.ColumnSpacing = 6; vg.RowSpacing = 4;
vg.RowHeight = {'fit', 'fit'};
vg.ColumnWidth = {'fit', 34, 64, 'fit', 34, '1x', 'fit', 60, 'fit', 50, 'fit', 140};
uilabel(vg, "Text", "Detected artifacts", "FontWeight", "bold");
obj.ArtViewPrevButton = uibutton(vg, "Text", char(9664), "Tooltip", "Previous artifact", ...
    "ButtonPushedFcn", @(~,~) stepArtifact(obj, -1));
obj.ArtViewSpinner = uispinner(vg, "Limits", [1 Inf], "Step", 1, "RoundFractionalValues", "on", ...
    "Value", 1, "Tooltip", "Artifact number, in recording order", ...
    "ValueChangedFcn", @(~,~) obj.showArtifactView());
obj.ArtViewCountLabel = uilabel(vg, "Text", "of 0");
obj.ArtViewNextButton = uibutton(vg, "Text", char(9654), "Tooltip", "Next artifact", ...
    "ButtonPushedFcn", @(~,~) stepArtifact(obj, 1));
uilabel(vg, "Text", "");
uilabel(vg, "Text", "Context (ms):", "HorizontalAlignment", "right");
obj.ArtViewContextField = uieditfield(vg, "numeric", "Value", 0, "Limits", [0 60000], ...
    "Tooltip", "Signal shown before and after the artifact. 0 = auto (twice its length, 25 ms to 5 s).", ...
    "ValueChangedFcn", @(~,~) obj.showArtifactView());
uilabel(vg, "Text", "Channels:", "HorizontalAlignment", "right");
obj.ArtViewChannelsField = uieditfield(vg, "numeric", "Value", 8, "Limits", [1 Inf], ...
    "RoundFractionalValues", "on", "Tooltip", "How many channels to draw: the ones the artifact is largest on.", ...
    "ValueChangedFcn", @(~,~) obj.drawArtifactView());
uilabel(vg, "Text", "Scale:", "HorizontalAlignment", "right");
obj.ArtViewScaleDropDown = uidropdown(vg, "Items", {'Fit the artifact', 'Fit the kept signal'}, ...
    "ItemsData", {'artifact', 'kept'}, "Value", 'artifact', ...
    "Tooltip", "Fit the kept signal to check that nothing of the artifact is left either side (larger values are clipped).", ...
    "ValueChangedFcn", @(~,~) obj.drawArtifactView());
obj.ArtViewNoteLabel = uilabel(vg, "Text", "", "WordWrap", "on");
obj.ArtViewNoteLabel.Layout.Row = 2; obj.ArtViewNoteLabel.Layout.Column = [1 12];

obj.ArtViewAxes = uiaxes(right);
obj.ArtViewAxes.Layout.Row = 4;
obj.ArtViewAxes.Toolbar.Visible = "on";
obj.drawArtifactView();   % the empty state

mg = uigridlayout(right, [1 3]);
mg.Layout.Row = 5; mg.Padding = [0 0 0 0]; mg.ColumnWidth = {'1x', 'fit', 'fit'}; mg.RowHeight = {30};
obj.ArtManualLabel = uilabel(mg, "Text", "Manual periods (scan a project first)", "FontWeight", "bold");
obj.ArtEditVizButton = uibutton(mg, "Text", "Edit in Visualize", ...
    "ButtonPushedFcn", @(~,~) obj.selectTab(obj.TabVisualize));
obj.ArtManualClearButton = uibutton(mg, "Text", "Clear", "ButtonPushedFcn", @(~,~) obj.onClearManualArtifacts());
obj.ArtManualTable = uitable(right, "ColumnName", {'Start (s)', 'End (s)', 'Duration (s)'}, ...
    "ColumnWidth", {'1x', '1x', '1x'}, "RowName", {});
obj.ArtManualTable.Layout.Row = 6;
end


function stepArtifact(obj, step)
% Previous / next artifact; the spinner's limits keep it in range.
sp = obj.ArtViewSpinner;
v = min(max(sp.Value + step, sp.Limits(1)), sp.Limits(2));
if v ~= sp.Value
    sp.Value = v;
    obj.showArtifactView();
end
end


function lab(parent, txt, row)
l = uilabel(parent, "Text", txt);
l.Layout.Row = row;
l.Layout.Column = 1;
end
