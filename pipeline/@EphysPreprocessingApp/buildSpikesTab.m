function buildSpikesTab(obj)
%buildSpikesTab  Spikes step: threshold detection and/or sorted units -> .mat.
%   Edits the config's Spikes section (gatherSpikesSection /
%   applySpikesSection): source, detection settings (EphysDataset.detectSpikes),
%   sorted-unit settings (readSortedUnits) and output. The right panel
%   previews detection on a short window of the Dataset-menu dataset and
%   runs the step.

g = uigridlayout(obj.TabSpikes, [1 2]);
g.ColumnWidth = {660, '1x'};
g.Padding     = [10 10 10 10];
changed = @(~,~) obj.onSpikesControlsChanged();

opt = uipanel(g, "Title", "Spike options (config: Spikes; EphysDataset.spikesToMat)");
opt.Layout.Column = 1;
nRows = 24;
cg = uigridlayout(opt, [nRows 5]);
cg.Scrollable  = "on";
cg.RowHeight   = repmat({26}, 1, nRows);
cg.ColumnWidth = {135, '1x', 130, 95, 95};

r = 1;
obj.SpkEnableCheckBox = uicheckbox(cg, "Text", "Enable the Spikes step", "FontWeight", "bold", ...
    "Value", false, "ValueChangedFcn", changed);
obj.SpkEnableCheckBox.Layout.Row = r; obj.SpkEnableCheckBox.Layout.Column = [1 2];
l = lab(cg, "Source:", r); l.Layout.Column = 3;
obj.SpkSourceDropDown = uidropdown(cg, ...
    "Items", {'Threshold detection', 'Sorted units (Kilosort / phy)', 'Both'}, ...
    "ItemsData", {'detect', 'sorted', 'both'}, "Value", 'detect', ...
    "Tooltip", "detect: EphysDataset.detectSpikes over the whole recording; sorted: the units associated with each dataset.", ...
    "ValueChangedFcn", changed);
obj.SpkSourceDropDown.Layout.Row = r; obj.SpkSourceDropDown.Layout.Column = [4 5];

% --- Filter ---
r = r + 1; sep(cg, "Detection: filter", r);
r = r + 1;
obj.SpkFilterCheckBox = uicheckbox(cg, "Text", "Band-pass before detecting", "Value", true, ...
    "ValueChangedFcn", changed);
obj.SpkFilterCheckBox.Layout.Row = r; obj.SpkFilterCheckBox.Layout.Column = [1 2];
l = lab(cg, "Band (Hz):", r); l.Layout.Column = 3;
obj.SpkBandLoField = numField(cg, 500, "Band(1): low edge of the zero-phase Butterworth band-pass.", changed);
obj.SpkBandLoField.Layout.Row = r; obj.SpkBandLoField.Layout.Column = 4;
obj.SpkBandHiField = numField(cg, 5000, "Band(2): high edge (below Fs/2).", changed);
obj.SpkBandHiField.Layout.Row = r; obj.SpkBandHiField.Layout.Column = 5;
r = r + 1;
lab(cg, "Filter order:", r);
obj.SpkFilterOrderField = uieditfield(cg, "numeric", "Value", 4, "Limits", [1 Inf], ...
    "RoundFractionalValues", "on", "ValueChangedFcn", changed);
obj.SpkFilterOrderField.Layout.Row = r; obj.SpkFilterOrderField.Layout.Column = 2;

% --- Threshold ---
r = r + 1; sep(cg, "Detection: threshold", r);
r = r + 1;
lab(cg, "Polarity:", r);
obj.SpkPolarityDropDown = uidropdown(cg, "Items", {'negative', 'positive', 'both'}, "Value", 'negative', ...
    "ValueChangedFcn", changed);
obj.SpkPolarityDropDown.Layout.Row = r; obj.SpkPolarityDropDown.Layout.Column = 2;
l = lab(cg, "Method:", r); l.Layout.Column = 3;
obj.SpkThreshMethodDropDown = uidropdown(cg, "Items", {'mad', 'std', 'rms', 'percentile', 'absolute'}, ...
    "Value", 'mad', "Tooltip", "How the threshold is derived from each chunk's noise (absolute = microvolts).", ...
    "ValueChangedFcn", changed);
obj.SpkThreshMethodDropDown.Layout.Row = r; obj.SpkThreshMethodDropDown.Layout.Column = [4 5];
r = r + 1;
l = lab(cg, "Threshold:", r);
l.Tooltip = "Multiplier (or microvolts for 'absolute'). Blank = the method's default.";
obj.SpkThresholdField = uieditfield(cg, "text", "Placeholder", "blank = default", ...
    "ValueChangedFcn", changed);
obj.SpkThresholdField.Layout.Row = r; obj.SpkThresholdField.Layout.Column = 2;
l = lab(cg, "Max amplitude (uV):", r); l.Layout.Column = 3;
obj.SpkMaxAmpField = uieditfield(cg, "text", "Value", "Inf", "Placeholder", "Inf = none", ...
    "Tooltip", "Events larger than this are rejected (artifact guard).", "ValueChangedFcn", changed);
obj.SpkMaxAmpField.Layout.Row = r; obj.SpkMaxAmpField.Layout.Column = [4 5];

% --- Events ---
r = r + 1; sep(cg, "Detection: events", r);
r = r + 1;
lab(cg, "Align:", r);
obj.SpkAlignDropDown = uidropdown(cg, "Items", {'trough', 'peak', 'extremum', 'none'}, "Value", 'trough', ...
    "ValueChangedFcn", changed);
obj.SpkAlignDropDown.Layout.Row = r; obj.SpkAlignDropDown.Layout.Column = 2;
l = lab(cg, "Align window (ms):", r); l.Layout.Column = 3;
obj.SpkAlignWindowField = numField0(cg, 1, "Search window after the crossing for the alignment point.", changed);
obj.SpkAlignWindowField.Layout.Row = r; obj.SpkAlignWindowField.Layout.Column = [4 5];
r = r + 1;
lab(cg, "Min period (ms):", r);
obj.SpkMinPeriodField = numField0(cg, 1, "Refractory guard: events closer than this are merged.", changed);
obj.SpkMinPeriodField.Layout.Row = r; obj.SpkMinPeriodField.Layout.Column = 2;

% --- Waveforms ---
r = r + 1; sep(cg, "Detection: waveforms", r);
r = r + 1;
obj.SpkWaveformsCheckBox = uicheckbox(cg, "Text", "Save waveforms", "Value", false, ...
    "Tooltip", "Store one [nSpikes x nWin] block per channel (can be large).", "ValueChangedFcn", changed);
obj.SpkWaveformsCheckBox.Layout.Row = r; obj.SpkWaveformsCheckBox.Layout.Column = [1 2];
l = lab(cg, "Window (ms):", r); l.Layout.Column = 3;
obj.SpkWinBeforeField = uieditfield(cg, "numeric", "Value", -0.5, "ValueDisplayFormat", "%.10g", ...
    "Tooltip", "WindowMs(1): before the event (negative).", "ValueChangedFcn", changed);
obj.SpkWinBeforeField.Layout.Row = r; obj.SpkWinBeforeField.Layout.Column = 4;
obj.SpkWinAfterField = uieditfield(cg, "numeric", "Value", 1.5, "ValueDisplayFormat", "%.10g", ...
    "Tooltip", "WindowMs(2): after the event.", "ValueChangedFcn", changed);
obj.SpkWinAfterField.Layout.Row = r; obj.SpkWinAfterField.Layout.Column = 5;
r = r + 1;
lab(cg, "Waveform source:", r);
obj.SpkWaveSourceDropDown = uidropdown(cg, "Items", {'filtered', 'raw'}, "Value", 'filtered', ...
    "ValueChangedFcn", changed);
obj.SpkWaveSourceDropDown.Layout.Row = r; obj.SpkWaveSourceDropDown.Layout.Column = 2;
l = lab(cg, "Edge handling:", r); l.Layout.Column = 3;
obj.SpkEdgeDropDown = uidropdown(cg, "Items", {'nan', 'drop'}, "Value", 'nan', ...
    "Tooltip", "Waveforms cut by the recording edges: NaN-pad or drop the event.", "ValueChangedFcn", changed);
obj.SpkEdgeDropDown.Layout.Row = r; obj.SpkEdgeDropDown.Layout.Column = [4 5];

% --- Channels & artifacts ---
r = r + 1; sep(cg, "Detection: channels and artifacts", r);
r = r + 1;
lab(cg, "Channels:", r);
obj.SpkChannelsDropDown = uidropdown(cg, ...
    "Items", {'all', 'all except manifest exclusions', 'list'}, ...
    "ItemsData", {'all', 'excludeManifest', 'list'}, "Value", 'all', "ValueChangedFcn", changed);
obj.SpkChannelsDropDown.Layout.Row = r; obj.SpkChannelsDropDown.Layout.Column = 2;
obj.SpkChannelListField = uieditfield(cg, "text", "Placeholder", "e.g. 1-16, 20", "Enable", "off", ...
    "ValueChangedFcn", changed);
obj.SpkChannelListField.Layout.Row = r; obj.SpkChannelListField.Layout.Column = [3 5];
r = r + 1;
obj.SpkRejectArtifactsCheckBox = uicheckbox(cg, "Text", "Reject events inside artifact periods", "Value", true, ...
    "Tooltip", "Manual periods always; the automatic detector's periods when Artifacts > apply to spikes is on.", ...
    "ValueChangedFcn", changed);
obj.SpkRejectArtifactsCheckBox.Layout.Row = r; obj.SpkRejectArtifactsCheckBox.Layout.Column = [1 5];

% --- Performance ---
r = r + 1; sep(cg, "Detection: chunking", r);
r = r + 1;
lab(cg, "Max chunk samples:", r);
obj.SpkChunkField = uieditfield(cg, "text", "Placeholder", "blank = auto", ...
    "Tooltip", "Cap on samples per streamed chunk (readers with random access).", "ValueChangedFcn", changed);
obj.SpkChunkField.Layout.Row = r; obj.SpkChunkField.Layout.Column = 2;
l = lab(cg, "Edge pad (ms):", r); l.Layout.Column = 3;
obj.SpkEdgePadField = uieditfield(cg, "text", "Placeholder", "blank = auto", ...
    "Tooltip", "Context carried across chunk boundaries. Blank = auto (10 ms).", "ValueChangedFcn", changed);
obj.SpkEdgePadField.Layout.Row = r; obj.SpkEdgePadField.Layout.Column = 4;

% --- Sorted units ---
r = r + 1; sep(cg, "Sorted units (Kilosort4 / phy output associated with each dataset)", r);
r = r + 1;
lab(cg, "Groups:", r);
obj.SpkGroupsField = uieditfield(cg, "text", "Value", "good, mua", ...
    "Tooltip", "phy labels to keep (cluster_group.tsv, else cluster_KSLabel.tsv). Blank = every non-noise cluster.", ...
    "ValueChangedFcn", changed);
obj.SpkGroupsField.Layout.Row = r; obj.SpkGroupsField.Layout.Column = 2;
obj.SpkIncludeNoiseCheckBox = uicheckbox(cg, "Text", "Include noise", "Value", false, "ValueChangedFcn", changed);
obj.SpkIncludeNoiseCheckBox.Layout.Row = r; obj.SpkIncludeNoiseCheckBox.Layout.Column = 3;
obj.SpkTemplatesCheckBox = uicheckbox(cg, "Text", "Template waveforms", "Value", true, ...
    "Tooltip", "Read templates.npy for peak channels and mean waveforms.", "ValueChangedFcn", changed);
obj.SpkTemplatesCheckBox.Layout.Row = r; obj.SpkTemplatesCheckBox.Layout.Column = [4 5];

% --- Output ---
r = r + 1; sep(cg, "Output", r);
r = r + 1;
lab(cg, "Output folder:", r);
obj.SpkOutputDirField = uieditfield(cg, "text", "Placeholder", "blank = each dataset's output folder", ...
    "ValueChangedFcn", changed);
obj.SpkOutputDirField.Layout.Row = r; obj.SpkOutputDirField.Layout.Column = [2 4];
obj.SpkBrowseOutputButton = uibutton(cg, "Text", "...", "ButtonPushedFcn", @(~,~) obj.onBrowseSpikesOutput());
obj.SpkBrowseOutputButton.Layout.Row = r; obj.SpkBrowseOutputButton.Layout.Column = 5;
r = r + 1;
lab(cg, "File suffix:", r);
obj.SpkSuffixField = uieditfield(cg, "text", "Value", "_spikes", "ValueChangedFcn", changed);
obj.SpkSuffixField.Layout.Row = r; obj.SpkSuffixField.Layout.Column = 2;
obj.SpkOverwriteCheckBox = uicheckbox(cg, "Text", "Overwrite existing", "Value", false, "ValueChangedFcn", changed);
obj.SpkOverwriteCheckBox.Layout.Row = r; obj.SpkOverwriteCheckBox.Layout.Column = 3;
obj.SpkMatVersionDropDown = uidropdown(cg, "Items", {'-v7.3', '-v7'}, "Value", '-v7.3', "ValueChangedFcn", changed);
obj.SpkMatVersionDropDown.Layout.Row = r; obj.SpkMatVersionDropDown.Layout.Column = [4 5];

% =================== right: preview + run ===================
right = uigridlayout(g, [4 2]);
right.Layout.Column = 2;
right.ColumnWidth = {'fit', '1x'};
right.RowHeight = {'fit', 'fit', '1x', 'fit'};
right.Padding = [0 0 0 0];
pp = uigridlayout(right, [1 3]);
pp.Layout.Column = [1 2];
pp.RowHeight = {'fit'}; pp.ColumnWidth = {'fit', 'fit', '1x'}; pp.Padding = [0 0 0 0];
obj.SpkPreviewButton = uibutton(pp, "Text", "Preview on the Dataset-menu dataset", ...
    "Tooltip", "Detect on the first seconds of the dataset picked in the Dataset menu with the settings on the left.", ...
    "ButtonPushedFcn", @(~,~) obj.onSpikesPreview());
obj.SpkPreviewSecondsField = uieditfield(pp, "numeric", "Value", 10, "Limits", [0.1 Inf], ...
    "ValueDisplayFormat", "%g s", "Tooltip", "Length of the preview window.");
obj.SpkPreviewLabel = uilabel(pp, "Text", "", "FontColor", [0.4 0.4 0.4], "WordWrap", "on");
l = uilabel(right, "Text", "Preview: per-channel rates and thresholds", "FontWeight", "bold");
l.Layout.Row = 2; l.Layout.Column = [1 2];
obj.SpkPreviewTable = uitable(right, "ColumnName", {'Ch', 'Name', 'Threshold (uV)', 'Events', 'Rate (Hz)'}, ...
    "ColumnWidth", {44, '1x', 110, 80, 90}, "RowName", {});
obj.SpkPreviewTable.Layout.Row = 3; obj.SpkPreviewTable.Layout.Column = [1 2];
obj.RunStepSpikesButton = uibutton(right, "Text", "Run this step", "FontWeight", "bold", ...
    "ButtonPushedFcn", @(~,~) obj.onRunStep("spikes"));
obj.RunStepSpikesButton.Layout.Row = 4; obj.RunStepSpikesButton.Layout.Column = 1;

obj.syncSpikesEnableStates();
end


function f = numField(parent, value, tip, cb)
f = uieditfield(parent, "numeric", "Value", value, "Limits", [0 Inf], ...
    "LowerLimitInclusive", "off", "ValueDisplayFormat", "%.10g", "Tooltip", tip, "ValueChangedFcn", cb);
end


function f = numField0(parent, value, tip, cb)
f = uieditfield(parent, "numeric", "Value", value, "Limits", [0 Inf], ...
    "ValueDisplayFormat", "%.10g", "Tooltip", tip, "ValueChangedFcn", cb);
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
