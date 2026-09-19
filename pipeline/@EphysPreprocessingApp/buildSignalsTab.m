function buildSignalsTab(obj)
%buildSignalsTab  Signals step: derived LFP / MUA / SPIKE / AUX -> .mat (toMat).
%   Edits the config's Signals section (gatherConvertConfig /
%   applyConvertConfig): every EphysDataset.deriveSignals option plus where
%   and how the results are saved, how manifest channel exclusions are
%   handled and whether the behavior data is attached. The right panel
%   previews the step's plan for the selected datasets and runs it.

g = uigridlayout(obj.TabSignals, [1 2]);
g.ColumnWidth = {560, '1x'};
g.Padding     = [10 10 10 10];

opt = uipanel(g, "Title", "Signal options (config: Signals; EphysDataset.deriveSignals / toMat)");
opt.Layout.Column = 1;

nRows = 28;
cg = uigridlayout(opt, [nRows 5]);
cg.Scrollable  = "on";
cg.RowHeight   = repmat({26}, 1, nRows);
cg.ColumnWidth = {130, '1x', 110, '1x', 30};

changed = @(~,~) obj.onConvertControlsChanged();

r = 1;
obj.SigEnableCheckBox = uicheckbox(cg, "Text", "Enable the Signals step", "FontWeight", "bold", ...
    "Value", false, "ValueChangedFcn", changed);
obj.SigEnableCheckBox.Layout.Row = r; obj.SigEnableCheckBox.Layout.Column = [1 5];

% --- Output ---
r = r + 1;
sep(cg, "Output", r);

r = r + 1;
l = lab(cg, "Output folder:", r);
l.Tooltip = "Folder for the .mat files. Blank = each dataset's output folder (<output root>/<Name>, or the recording folder).";
obj.ConvOutputDirField = uieditfield(cg, "text", ...
    "Placeholder", "blank = each dataset's output folder", ...
    "ValueChangedFcn", changed);
obj.ConvOutputDirField.Layout.Row = r; obj.ConvOutputDirField.Layout.Column = [2 4];
obj.ConvBrowseOutputButton = uibutton(cg, "Text", "...", ...
    "ButtonPushedFcn", @(~,~) obj.onBrowseConvertOutput());
obj.ConvBrowseOutputButton.Layout.Row = r; obj.ConvBrowseOutputButton.Layout.Column = 5;

r = r + 1;
lab(cg, "File suffix:", r);
obj.ConvSuffixField = uieditfield(cg, "text", "Value", "_extract", ...
    "Tooltip", "Output file name is <dataset name><suffix>.mat, or <dataset name><suffix>_<LFP|MUA|SPIKE|AUX>.mat with one file per signal type.", ...
    "ValueChangedFcn", changed);
obj.ConvSuffixField.Layout.Row = r; obj.ConvSuffixField.Layout.Column = 2;
l = lab(cg, "MAT version:", r); l.Layout.Column = 3;
obj.ConvMatVersionDropDown = uidropdown(cg, ...
    "Items", {'-v7.3 (any size)', '-v7 (< 2 GB per variable)'}, ...
    "ItemsData", {'-v7.3', '-v7'}, "Value", '-v7.3', ...
    "ValueChangedFcn", changed);
obj.ConvMatVersionDropDown.Layout.Row = r; obj.ConvMatVersionDropDown.Layout.Column = [4 5];

r = r + 1;
obj.ConvOverwriteCheckBox = uicheckbox(cg, "Text", "Overwrite existing output files", ...
    "Value", false, "ValueChangedFcn", changed);
obj.ConvOverwriteCheckBox.Layout.Row = r; obj.ConvOverwriteCheckBox.Layout.Column = [1 2];

r = r + 1;
obj.ConvSeparateFilesCheckBox = uicheckbox(cg, "Text", "Save one file per signal type (<name><suffix>_LFP.mat, _MUA.mat, _SPIKE.mat, _AUX.mat)", ...
    "Value", true, "Tooltip", ...
    "SeparateFiles: each file holds Y / info for its signal only, plus events and conversion. Off = one file with every signal.", ...
    "ValueChangedFcn", changed);
obj.ConvSeparateFilesCheckBox.Layout.Row = r; obj.ConvSeparateFilesCheckBox.Layout.Column = [1 5];

% --- dataTypeOut ---
r = r + 1;
sep(cg, "Signals to compute (dataTypeOut)", r);

r = r + 1;
obj.ConvLFPCheckBox = uicheckbox(cg, "Text", "LFP", "Value", true, ...
    "Tooltip", "Y.LFP: amplifier data resampled to LFP_Fs, then the optional zero-phase filters below.", ...
    "ValueChangedFcn", changed);
obj.ConvLFPCheckBox.Layout.Row = r; obj.ConvLFPCheckBox.Layout.Column = 1;
obj.ConvMUACheckBox = uicheckbox(cg, "Text", "MUA", "Value", false, ...
    "Tooltip", "Y.MUA: bandpass at the original rate, rectify, resample to MUA_Fs, moving-mean integration.", ...
    "ValueChangedFcn", changed);
obj.ConvMUACheckBox.Layout.Row = r; obj.ConvMUACheckBox.Layout.Column = 2;
obj.ConvSPIKECheckBox = uicheckbox(cg, "Text", "SPIKE", "Value", false, ...
    "Tooltip", "Y.SPIKE: optional resample to SPIKE_Fs, then zero-phase bandpass.", ...
    "ValueChangedFcn", changed);
obj.ConvSPIKECheckBox.Layout.Row = r; obj.ConvSPIKECheckBox.Layout.Column = 3;
obj.ConvAUXCheckBox = uicheckbox(cg, "Text", "AUX (accelerometer)", "Value", false, ...
    "Tooltip", "Y.AUX: the headstage auxiliary (accelerometer) inputs, unprocessed, in volts at their own rate. Skipped for recordings without them.", ...
    "ValueChangedFcn", changed);
obj.ConvAUXCheckBox.Layout.Row = r; obj.ConvAUXCheckBox.Layout.Column = [4 5];

% --- LFP ---
r = r + 1;
sep(cg, "LFP", r);

r = r + 1;
lab(cg, "LFP_Fs (Hz):", r);
obj.ConvLFPFsField = numField(cg, 1000, "Target LFP sampling rate (resample).", changed);
obj.ConvLFPFsField.Layout.Row = r; obj.ConvLFPFsField.Layout.Column = 2;

r = r + 1;
obj.ConvLFPHighpassCheckBox = uicheckbox(cg, "Text", "High-pass (Hz):", "Value", false, ...
    "Tooltip", "LFP_bpLoHi(1): 4th-order Butterworth high-pass, zero-phase, designed at LFP_Fs.", ...
    "ValueChangedFcn", changed);
obj.ConvLFPHighpassCheckBox.Layout.Row = r; obj.ConvLFPHighpassCheckBox.Layout.Column = 1;
obj.ConvLFPHighpassField = numField(cg, 1, "High-pass cut-off (Hz); below LFP_Fs / 2 and the low-pass cut-off.", changed);
obj.ConvLFPHighpassField.Layout.Row = r; obj.ConvLFPHighpassField.Layout.Column = 2;
obj.ConvLFPLowpassCheckBox = uicheckbox(cg, "Text", "Low-pass (Hz):", "Value", false, ...
    "Tooltip", "LFP_bpLoHi(2): 4th-order Butterworth low-pass, zero-phase, designed at LFP_Fs.", ...
    "ValueChangedFcn", changed);
obj.ConvLFPLowpassCheckBox.Layout.Row = r; obj.ConvLFPLowpassCheckBox.Layout.Column = 3;
obj.ConvLFPLowpassField = numField(cg, 300, "Low-pass cut-off (Hz); below LFP_Fs / 2.", changed);
obj.ConvLFPLowpassField.Layout.Row = r; obj.ConvLFPLowpassField.Layout.Column = [4 5];

r = r + 1;
obj.ConvLFPNotchCheckBox = uicheckbox(cg, "Text", "Notch (Hz):", "Value", false, ...
    "Tooltip", "LFP_NotchHz: zero-phase band-stop at each listed frequency, e.g. 60, 120, 180.", ...
    "ValueChangedFcn", changed);
obj.ConvLFPNotchCheckBox.Layout.Row = r; obj.ConvLFPNotchCheckBox.Layout.Column = 1;
obj.ConvLFPNotchField = uieditfield(cg, "text", "Value", "60", ...
    "Placeholder", "e.g. 60, 120, 180", "ValueChangedFcn", changed);
obj.ConvLFPNotchField.Layout.Row = r; obj.ConvLFPNotchField.Layout.Column = 2;
l = lab(cg, "Notch width (Hz):", r); l.Layout.Column = 3;
obj.ConvLFPNotchBWField = numField(cg, 2, "LFP_NotchBW: each notch removes f +/- width/2.", changed);
obj.ConvLFPNotchBWField.Layout.Row = r; obj.ConvLFPNotchBWField.Layout.Column = [4 5];

% --- MUA ---
r = r + 1;
sep(cg, "MUA", r);

r = r + 1;
lab(cg, "MUA_Fs (Hz):", r);
obj.ConvMUAFsField = numField(cg, 2000, "Sampling rate of the MUA envelope.", changed);
obj.ConvMUAFsField.Layout.Row = r; obj.ConvMUAFsField.Layout.Column = 2;
l = lab(cg, "Integration (Hz):", r); l.Layout.Column = 3;
obj.ConvMUAIntegrationField = numField(cg, 1000, ...
    "MUA_IntegrationHz: moving-mean window = round(MUA_Fs / MUA_IntegrationHz) samples.", changed);
obj.ConvMUAIntegrationField.Layout.Row = r; obj.ConvMUAIntegrationField.Layout.Column = [4 5];

r = r + 1;
lab(cg, "Bandpass low (Hz):", r);
obj.ConvMUALoField = numField(cg, 300, "MUA_bpLoHi(1)", changed);
obj.ConvMUALoField.Layout.Row = r; obj.ConvMUALoField.Layout.Column = 2;
l = lab(cg, "Bandpass high (Hz):", r); l.Layout.Column = 3;
obj.ConvMUAHiField = numField(cg, 5000, "MUA_bpLoHi(2): below half the amplifier rate.", changed);
obj.ConvMUAHiField.Layout.Row = r; obj.ConvMUAHiField.Layout.Column = [4 5];

% --- SPIKE ---
r = r + 1;
sep(cg, "SPIKE", r);

r = r + 1;
obj.ConvSpikeOrigCheckBox = uicheckbox(cg, "Text", "Keep original rate (SPIKE_Fs = Inf)", ...
    "Value", true, "ValueChangedFcn", changed);
obj.ConvSpikeOrigCheckBox.Layout.Row = r; obj.ConvSpikeOrigCheckBox.Layout.Column = [1 2];
l = lab(cg, "SPIKE_Fs (Hz):", r); l.Layout.Column = 3;
obj.ConvSpikeFsField = numField(cg, 20000, "Target spike-band rate (when 'Keep original rate' is off).", changed);
obj.ConvSpikeFsField.Layout.Row = r; obj.ConvSpikeFsField.Layout.Column = [4 5];

r = r + 1;
lab(cg, "Bandpass low (Hz):", r);
obj.ConvSpikeLoField = numField(cg, 300, "SPIKE_bpLoHi(1)", changed);
obj.ConvSpikeLoField.Layout.Row = r; obj.ConvSpikeLoField.Layout.Column = 2;
l = lab(cg, "Bandpass high (Hz):", r); l.Layout.Column = 3;
obj.ConvSpikeHiField = numField(cg, 5000, "SPIKE_bpLoHi(2): below SPIKE_Fs / 2.", changed);
obj.ConvSpikeHiField.Layout.Row = r; obj.ConvSpikeHiField.Layout.Column = [4 5];

% --- Channels ---
r = r + 1;
sep(cg, "Channels", r);

r = r + 1;
lab(cg, "Label field:", r);
obj.ConvLabelFieldDropDown = uidropdown(cg, ...
    "Items", {'custom name', 'native name'}, "ItemsData", {'custom', 'native'}, ...
    "Value", 'custom', ...
    "Tooltip", ["LabelField: which name labels the channels (info.labels), aux inputs and digital lines." ...
        "Digital lines renamed on the Trials tab (Signals.LineNames) keep their given names."], ...
    "ValueChangedFcn", changed);
obj.ConvLabelFieldDropDown.Layout.Row = r; obj.ConvLabelFieldDropDown.Layout.Column = 2;
l = lab(cg, "Manifest exclusions:", r); l.Layout.Column = 3;
l.Tooltip = "How each dataset's excluded channels (Probe tab / manifest) are treated here.";
obj.ConvExcludeHandlingDropDown = uidropdown(cg, ...
    "Items", {'ignore', 'drop', 'interpolate'}, "ItemsData", {'none', 'drop', 'interpolate'}, ...
    "Value", 'none', "Tooltip", "ExcludeHandling: ignore | drop the channels | interpolate them as bad channels.", ...
    "ValueChangedFcn", changed);
obj.ConvExcludeHandlingDropDown.Layout.Row = r; obj.ConvExcludeHandlingDropDown.Layout.Column = [4 5];

r = r + 1;
lab(cg, "Keep amp channels:", r);
obj.ConvKeepChannelsField = uieditfield(cg, "text", ...
    "Placeholder", "blank = all (e.g. 1-32, 40)", "Tooltip", ...
    "keepAmpChannels: 1-based channels to load, in the order given. Blank = all.", ...
    "ValueChangedFcn", changed);
obj.ConvKeepChannelsField.Layout.Row = r; obj.ConvKeepChannelsField.Layout.Column = [2 5];

r = r + 1;
lab(cg, "Bad channels:", r);
obj.ConvBadModeDropDown = uidropdown(cg, ...
    "Items", {'None', 'Manual list (below)', 'Auto: |zscore(RMS of LFP)| > threshold'}, ...
    "ItemsData", {'none', 'manual', 'auto'}, "Value", 'none', ...
    "Tooltip", "badChannels: channels replaced by interpolation across neighbouring columns.", ...
    "ValueChangedFcn", changed);
obj.ConvBadModeDropDown.Layout.Row = r; obj.ConvBadModeDropDown.Layout.Column = [2 5];

r = r + 1;
lab(cg, "Auto threshold:", r);
obj.ConvBadThresholdField = numField(cg, 3, "Auto mode: |zscore(RMS of LFP)| above this value.", changed);
obj.ConvBadThresholdField.Layout.Row = r; obj.ConvBadThresholdField.Layout.Column = 2;

r = r + 1;
lab(cg, "Bad channel list:", r);
obj.ConvBadListField = uieditfield(cg, "text", "Placeholder", "e.g. 3, 17-18", ...
    "Tooltip", "Manual mode: 1-based column indices AFTER 'Keep amp channels' and BEFORE 'Channel remap'.", ...
    "ValueChangedFcn", changed);
obj.ConvBadListField.Layout.Row = r; obj.ConvBadListField.Layout.Column = [2 5];

r = r + 1;
lab(cg, "Channel remap:", r);
obj.ConvRemapField = uieditfield(cg, "text", "Placeholder", "blank = none (e.g. 32-1)", ...
    "Tooltip", "channelRemap: final column order applied after processing (1-based, into the kept channels).", ...
    "ValueChangedFcn", changed);
obj.ConvRemapField.Layout.Row = r; obj.ConvRemapField.Layout.Column = [2 5];

r = r + 1;
note = uilabel(cg, "WordWrap", "on", "FontColor", [0.4 0.4 0.4], "Text", ...
    "Order: keep channels -> LFP (resample, then filters) / MUA / SPIKE -> interpolate bad channels -> remap. Lists accept 1-based indices and ranges (1-16, 20, 32-17); order is kept.");
note.Layout.Row = r; note.Layout.Column = [1 5];
cg.RowHeight{r} = 40;

r = r + 1;
obj.ConvResetButton = uibutton(cg, "Text", "Reset to defaults", ...
    "ButtonPushedFcn", @(~,~) obj.onResetConvertConfig());
obj.ConvResetButton.Layout.Row = r; obj.ConvResetButton.Layout.Column = 2;

% =================== right: plan preview + run ===================
runPanel = uipanel(g, "Title", "This step for the selected datasets");
runPanel.Layout.Column = 2;
rg = uigridlayout(runPanel, [3 3]);
rg.RowHeight   = {'fit', '1x', 'fit'};
rg.ColumnWidth = {'fit', '1x', 'fit'};
hint = uilabel(rg, "WordWrap", "on", "FontColor", [0.4 0.4 0.4], "Text", ...
    "Datasets ticked on the Project tab (none ticked = all). Each dataset reads its own recording through its reader, so every supported layout works. Progress shows on the Run tab.");
hint.Layout.Row = 1; hint.Layout.Column = [1 3];
obj.ConvTargetsTable = uitable(rg, "ColumnName", {'Dataset', 'Output file', 'Status', 'Note'}, ...
    "ColumnWidth", {'fit', '2x', 140, '1x'}, "RowName", {});
obj.ConvTargetsTable.Layout.Row = 2; obj.ConvTargetsTable.Layout.Column = [1 3];
obj.RunStepSignalsButton = uibutton(rg, "Text", "Run this step", "FontWeight", "bold", ...
    "ButtonPushedFcn", @(~,~) obj.onRunStep("signals"));
obj.RunStepSignalsButton.Layout.Row = 3; obj.RunStepSignalsButton.Layout.Column = 1;
obj.ConvRefreshButton = uibutton(rg, "Text", "Refresh plan", ...
    "ButtonPushedFcn", @(~,~) obj.refreshStepPlan("signals"));
obj.ConvRefreshButton.Layout.Row = 3; obj.ConvRefreshButton.Layout.Column = 3;

obj.syncConvertEnableStates();
end


function f = numField(parent, value, tip, cb)
f = uieditfield(parent, "numeric", "Value", value, "Limits", [0 Inf], ...
    "LowerLimitInclusive", "off", "ValueDisplayFormat", "%.10g", ...
    "Tooltip", tip, "ValueChangedFcn", cb);
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
