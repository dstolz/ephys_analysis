function buildExportTab(obj)
%buildExportTab  Export step: files for Chronux, FieldTrip and event epochs.
%   Edits the config's Export section (gatherExportSection /
%   applyExportSection). Only packaging options are exposed; no analysis
%   from either toolbox is surfaced here. The epoch options also drive
%   "Epochs to workspace", which builds the same event-organized struct for
%   the selected dataset without writing a file.

g = uigridlayout(obj.TabExport, [1 2]);
g.ColumnWidth = {520, '1x'};
g.Padding     = [10 10 10 10];
changed = @(~,~) obj.onConfigChanged();

opt = uipanel(g, "Title", "Export options (config: Export; exportChronux / exportFieldTrip / exportEpochs)");
opt.Layout.Column = 1;
nRows = 19;
cg = uigridlayout(opt, [nRows 4]);
cg.RowHeight   = repmat({26}, 1, nRows);
cg.ColumnWidth = {130, '1x', '1x', 30};

r = 1;
obj.ExpEnableCheckBox = uicheckbox(cg, "Text", "Enable the Export step", "FontWeight", "bold", ...
    "Value", false, "ValueChangedFcn", changed);
obj.ExpEnableCheckBox.Layout.Row = r; obj.ExpEnableCheckBox.Layout.Column = [1 4];

r = r + 1; sep(cg, "Formats", r);
r = r + 1;
obj.ExpChronuxCheckBox = uicheckbox(cg, "Text", "Chronux (<Name>_chronux.mat)", "Value", false, ...
    "Tooltip", "Continuous data as [samples x channels] + params, spikes as struct arrays of times, ready for mtspectrumc / mtspectrumpt.", ...
    "ValueChangedFcn", changed);
obj.ExpChronuxCheckBox.Layout.Row = r; obj.ExpChronuxCheckBox.Layout.Column = [1 2];
obj.ExpFieldTripCheckBox = uicheckbox(cg, "Text", "FieldTrip (<Name>_fieldtrip.mat)", "Value", false, ...
    "Tooltip", "FieldTrip raw / spike / event structures (ft_datatype_raw, ft_datatype_spike).", ...
    "ValueChangedFcn", changed);
obj.ExpFieldTripCheckBox.Layout.Row = r; obj.ExpFieldTripCheckBox.Layout.Column = [3 4];
r = r + 1;
obj.ExpEpochsCheckBox = uicheckbox(cg, "Text", "Event epochs (<Name>_epochs.mat)", "Value", false, ...
    "Tooltip", ["The same data organized by event: one epoch per digital pulse or paired trial, " ...
                "with the trial table, the per-trial spike times and the behavior columns."], ...
    "ValueChangedFcn", changed);
obj.ExpEpochsCheckBox.Layout.Row = r; obj.ExpEpochsCheckBox.Layout.Column = [1 2];

r = r + 1; sep(cg, "Contents", r);
r = r + 1;
lab(cg, "Signals:", r);
obj.ExpSignalsField = uieditfield(cg, "text", "Placeholder", "blank = every signal in the extract (LFP, MUA, SPIKE, AUX)", ...
    "Tooltip", "Comma-separated subset of LFP, MUA, SPIKE, AUX (accelerometer) taken from the Signals step's extract file.", ...
    "ValueChangedFcn", changed);
obj.ExpSignalsField.Layout.Row = r; obj.ExpSignalsField.Layout.Column = [2 4];
r = r + 1;
obj.ExpUnitsCheckBox = uicheckbox(cg, "Text", "Sorted units", "Value", true, ...
    "Tooltip", "The Kilosort / phy units associated with each dataset.", "ValueChangedFcn", changed);
obj.ExpUnitsCheckBox.Layout.Row = r; obj.ExpUnitsCheckBox.Layout.Column = 1;
lg = lab(cg, "Groups:", r); lg.Layout.Column = 2;
obj.ExpGroupsField = uieditfield(cg, "text", "Value", "good, mua", ...
    "Tooltip", "phy labels to keep. Blank = every non-noise cluster.", "ValueChangedFcn", changed);
obj.ExpGroupsField.Layout.Row = r; obj.ExpGroupsField.Layout.Column = [3 4];
r = r + 1;
obj.ExpDetectedCheckBox = uicheckbox(cg, "Text", "Detected spikes (from the Spikes step's file)", "Value", false, ...
    "ValueChangedFcn", changed);
obj.ExpDetectedCheckBox.Layout.Row = r; obj.ExpDetectedCheckBox.Layout.Column = [1 2];
obj.ExpEventsCheckBox = uicheckbox(cg, "Text", "Digital-input events", "Value", true, "ValueChangedFcn", changed);
obj.ExpEventsCheckBox.Layout.Row = r; obj.ExpEventsCheckBox.Layout.Column = [3 4];
r = r + 1;
obj.ExpValidateCheckBox = uicheckbox(cg, "Text", "Validate with FieldTrip when on the path", "Value", true, ...
    "Tooltip", "Runs ft_datatype_raw / ft_datatype_spike on the structures if FieldTrip is installed; never required.", ...
    "ValueChangedFcn", changed);
obj.ExpValidateCheckBox.Layout.Row = r; obj.ExpValidateCheckBox.Layout.Column = [1 2];

r = r + 1; sep(cg, "Event epochs (EphysDataset.eventEpochs)", r);
r = r + 1;
lab(cg, "Events from:", r);
obj.ExpEpochSourceDropDown = uidropdown(cg, "Items", {'digital-input line', 'paired behavior trials'}, ...
    "ItemsData", {'line', 'behavior'}, "Value", 'line', ...
    "Tooltip", ["Where the onsets come from: the pulses of one digital line, or the trials of the " ...
                "Epsych2 session paired with the recording (Trials tab)."], ...
    "ValueChangedFcn", changed);
obj.ExpEpochSourceDropDown.Layout.Row = r; obj.ExpEpochSourceDropDown.Layout.Column = 2;
obj.ExpEpochLineField = uieditfield(cg, "text", "Placeholder", "line (blank = the trial line)", ...
    "Tooltip", "Digital-input line to epoch around; blank uses the Behavior tab's trial line, else the only line.", ...
    "ValueChangedFcn", changed);
obj.ExpEpochLineField.Layout.Row = r; obj.ExpEpochLineField.Layout.Column = [3 4];
r = r + 1;
lab(cg, "Window (s):", r);
obj.ExpEpochPreField = uieditfield(cg, "numeric", "Value", -0.2, "ValueDisplayFormat", "%.10g", ...
    "Tooltip", "Seconds before the onset (negative).", "ValueChangedFcn", changed);
obj.ExpEpochPreField.Layout.Row = r; obj.ExpEpochPreField.Layout.Column = 2;
obj.ExpEpochPostField = uieditfield(cg, "numeric", "Value", 0.5, "ValueDisplayFormat", "%.10g", ...
    "Tooltip", "Seconds after the onset.", "ValueChangedFcn", changed);
obj.ExpEpochPostField.Layout.Row = r; obj.ExpEpochPostField.Layout.Column = 3;
r = r + 1;
lab(cg, "Past the end:", r);
obj.ExpEpochIncompleteDropDown = uidropdown(cg, "Items", {'pad with NaN', 'drop the epoch', 'error'}, ...
    "ItemsData", {'nan', 'drop', 'error'}, "Value", 'nan', ...
    "Tooltip", "An epoch whose window runs past the start or the end of the recording.", ...
    "ValueChangedFcn", changed);
obj.ExpEpochIncompleteDropDown.Layout.Row = r; obj.ExpEpochIncompleteDropDown.Layout.Column = 2;
obj.ExpEpochNonFiniteDropDown = uidropdown(cg, ...
    "Items", {'NaN samples: keep the epoch', 'NaN samples: drop the epoch', 'NaN samples: error'}, ...
    "ItemsData", {'keep', 'drop', 'error'}, "Value", 'keep', ...
    "Tooltip", "An epoch whose recorded samples hold NaN or Inf (blanked artifacts).", ...
    "ValueChangedFcn", changed);
obj.ExpEpochNonFiniteDropDown.Layout.Row = r; obj.ExpEpochNonFiniteDropDown.Layout.Column = [3 4];
r = r + 1;
lab(cg, "Spike times:", r);
obj.ExpEpochSpikeBaseDropDown = uidropdown(cg, "Items", {'0 at the onset', '0 at the window start', 'recording clock'}, ...
    "ItemsData", {'onset', 'window', 'absolute'}, "Value", 'onset', ...
    "Tooltip", "How the per-epoch spike times are stamped (ChronuxDataset.spikeTrials).", ...
    "ValueChangedFcn", changed);
obj.ExpEpochSpikeBaseDropDown.Layout.Row = r; obj.ExpEpochSpikeBaseDropDown.Layout.Column = 2;
obj.ExpEpochClassDropDown = uidropdown(cg, ...
    "Items", {'samples: double', 'samples: single', 'samples: as recorded'}, ...
    "ItemsData", {'double', 'single', 'asis'}, "Value", 'double', ...
    "Tooltip", "Class of the epoched continuous data; the values themselves are never changed.", ...
    "ValueChangedFcn", changed);
obj.ExpEpochClassDropDown.Layout.Row = r; obj.ExpEpochClassDropDown.Layout.Column = [3 4];
r = r + 1;
obj.ExpEpochsToWorkspaceButton = uibutton(cg, "Text", "Epochs to workspace", ...
    "Tooltip", ["Build the event-organized struct for the dataset selected on the Project tab, " ...
                "with these settings, and put it in the base workspace (no file is written)."], ...
    "ButtonPushedFcn", @(~,~) obj.onExportEpochsToWorkspace());
obj.ExpEpochsToWorkspaceButton.Layout.Row = r; obj.ExpEpochsToWorkspaceButton.Layout.Column = [1 2];
obj.ExpEpochOnsetRuleDropDown = uidropdown(cg, "Items", {'onset rule: event', 'onset rule: sample'}, ...
    "ItemsData", {'event', 'sample'}, "Value", 'event', ...
    "Tooltip", ["Which sample an onset maps to: event = round(t*Fs), the digital-input convention; " ...
                "sample = round(t*Fs)+1, for times on a continuous time base. See ChronuxDataset.trials."], ...
    "ValueChangedFcn", changed);
obj.ExpEpochOnsetRuleDropDown.Layout.Row = r; obj.ExpEpochOnsetRuleDropDown.Layout.Column = [3 4];

r = r + 1; sep(cg, "Output", r);
r = r + 1;
lab(cg, "Output folder:", r);
obj.ExpOutputDirField = uieditfield(cg, "text", "Placeholder", "blank = each dataset's output folder", ...
    "ValueChangedFcn", changed);
obj.ExpOutputDirField.Layout.Row = r; obj.ExpOutputDirField.Layout.Column = [2 3];
obj.ExpBrowseOutputButton = uibutton(cg, "Text", "...", "ButtonPushedFcn", @(~,~) obj.onBrowseExportOutput());
obj.ExpBrowseOutputButton.Layout.Row = r; obj.ExpBrowseOutputButton.Layout.Column = 4;
r = r + 1;
obj.ExpOverwriteCheckBox = uicheckbox(cg, "Text", "Overwrite existing", "Value", false, "ValueChangedFcn", changed);
obj.ExpOverwriteCheckBox.Layout.Row = r; obj.ExpOverwriteCheckBox.Layout.Column = 1;
lm = lab(cg, "MAT version:", r); lm.Layout.Column = 2;
obj.ExpMatVersionDropDown = uidropdown(cg, "Items", {'-v7.3', '-v7'}, "Value", '-v7.3', "ValueChangedFcn", changed);
obj.ExpMatVersionDropDown.Layout.Row = r; obj.ExpMatVersionDropDown.Layout.Column = 3;
r = r + 1;
note = uilabel(cg, "WordWrap", "on", "FontColor", [0.4 0.4 0.4], "Text", ...
    "Exports read the Signals step's extract file(s) (<Name>_extract.mat, or <Name>_extract_<TYPE>.mat per signal type), so run Signals first. The files load directly into Chronux / FieldTrip outside this app; no analysis happens here. The epoch file holds the same recorded samples and spike times, cut into one epoch per event.");
note.Layout.Row = r; note.Layout.Column = [1 4];
cg.RowHeight{r} = 56;

% =================== right: plan + run ===================
runPanel = uipanel(g, "Title", "This step for the selected datasets");
runPanel.Layout.Column = 2;
rg = uigridlayout(runPanel, [2 3]);
rg.RowHeight   = {'1x', 'fit'};
rg.ColumnWidth = {'fit', '1x', 'fit'};
obj.ExpTargetsTable = uitable(rg, "ColumnName", {'Step', 'Dataset', 'Output file', 'Status', 'Note'}, ...
    "ColumnWidth", {80, 'fit', '2x', 140, '1x'}, "RowName", {});
obj.ExpTargetsTable.Layout.Row = 1; obj.ExpTargetsTable.Layout.Column = [1 3];
obj.RunStepExportButton = uibutton(rg, "Text", "Run this step", "FontWeight", "bold", ...
    "ButtonPushedFcn", @(~,~) obj.onRunStep("export"));
obj.RunStepExportButton.Layout.Row = 2; obj.RunStepExportButton.Layout.Column = 1;
obj.ExpRefreshButton = uibutton(rg, "Text", "Refresh plan", ...
    "ButtonPushedFcn", @(~,~) obj.refreshStepPlan("export"));
obj.ExpRefreshButton.Layout.Row = 2; obj.ExpRefreshButton.Layout.Column = 3;
end


function l = lab(parent, txt, row)
l = uilabel(parent, "Text", txt);
l.Layout.Row = row;
l.Layout.Column = 1;
end


function sep(parent, txt, row)
l = uilabel(parent, "Text", txt, "FontWeight", "bold");
l.Layout.Row = row;
l.Layout.Column = [1 4];
end
