function buildArtifactsTab(obj)
%buildArtifactsTab  Artifacts step: automatic detection settings + preview,
%   and the manual periods of the selected dataset.
%   Edits the config's Artifacts section (gatherArtifactsSection /
%   applyArtifactsSection). Manual periods are per dataset (marked on the
%   Visualize tab, saved in the manifest) and always apply; the automatic
%   detector applies when the step is enabled. Where the intervals are used
%   (sorting, spike detection) is chosen here too.
%
%   See also EphysDataset.detectArtifacts, EphysDataset.analyzeArtifacts,
%   EphysDataset.artifactIntervals, onDetectArtifacts.

g = uigridlayout(obj.TabArtifacts, [1 2]);
g.ColumnWidth = {360, '1x'};
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
obj.ArtEnableCheckBox = uicheckbox(cg, "Text", "Enable automatic detection (manual periods always apply)", ...
    "FontWeight", "bold", "Value", false, "ValueChangedFcn", changed);
obj.ArtEnableCheckBox.Layout.Row = row; obj.ArtEnableCheckBox.Layout.Column = [1 2];

row = row + 1;
lab(cg, "Preview dataset:", row);
obj.ArtDatasetDropDown = uidropdown(cg);
obj.ArtDatasetDropDown.Items = {'(scan first)'};
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

row = row + 1;
obj.ArtStatusLabel = uilabel(cg, "Text", "", "FontColor", [0.4 0.4 0.4], "WordWrap", "on");
obj.ArtStatusLabel.Layout.Row = row; obj.ArtStatusLabel.Layout.Column = [1 2];

% =================== right: summary + per-channel table + manual periods ===================
right = uigridlayout(g, [5 1]);
right.Layout.Column = 2;
right.RowHeight = {'fit', 130, '1x', 'fit', 160};
right.RowSpacing = 8;

uilabel(right, "Text", "Preview summary", "FontWeight", "bold");
summaryPanel = uipanel(right);
sg = uigridlayout(summaryPanel, [1 1]);
sg.Padding = [8 6 8 6];
obj.ArtSummaryLabel = uilabel(sg, "Text", "Pick a dataset and press Detect / Preview.", ...
    "VerticalAlignment", "top", "WordWrap", "on", "FontName", "monospaced", "FontColor", [0.2 0.2 0.2]);
obj.ArtChannelTable = uitable(right, "ColumnName", {'Ch', 'Name', '#Samples', '% of duration'}, ...
    "ColumnWidth", {44, '1x', 100, 110}, "RowName", {});
obj.ArtChannelTable.Layout.Row = 3;

mg = uigridlayout(right, [1 3]);
mg.Layout.Row = 4; mg.Padding = [0 0 0 0]; mg.ColumnWidth = {'1x', 'fit', 'fit'};
obj.ArtManualLabel = uilabel(mg, "Text", "Manual periods of the selected dataset (saved in its manifest)", "FontWeight", "bold");
obj.ArtEditVizButton = uibutton(mg, "Text", "Edit in Visualize", ...
    "ButtonPushedFcn", @(~,~) set(obj.Tabs, 'SelectedTab', obj.TabVisualize));
obj.ArtManualClearButton = uibutton(mg, "Text", "Clear", "ButtonPushedFcn", @(~,~) obj.onClearManualArtifacts());
obj.ArtManualTable = uitable(right, "ColumnName", {'Start (s)', 'End (s)', 'Duration (s)'}, ...
    "ColumnWidth", {110, 110, 110}, "RowName", {});
obj.ArtManualTable.Layout.Row = 5;
end


function lab(parent, txt, row)
l = uilabel(parent, "Text", txt);
l.Layout.Row = row;
l.Layout.Column = 1;
end
