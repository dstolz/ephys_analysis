function buildExportTab(obj)
%buildExportTab  Export step: an NWB 2 file per dataset.
%   Edits the config's Export section (gatherExportSection /
%   applyExportSection). One checkbox per export format
%   (EphysPipelineConfig.ExportFormats). The inputs of the analysis
%   toolboxes and event-organized epochs are the DatasetBrowser's, not
%   this step's.

g = uigridlayout(obj.TabExport, [1 2]);
g.ColumnWidth = {520, '1x'};
g.Padding     = [10 10 10 10];
changed = @(~,~) obj.onConfigChanged();

opt = uipanel(g, "Title", "Export options (config: Export; EphysDataset.export<Format>)");
opt.Layout.Column = 1;
nRows = 18;
cg = uigridlayout(opt, [nRows 4]);
cg.RowHeight   = repmat({26}, 1, nRows);
cg.Scrollable  = "on";
cg.ColumnWidth = {130, '1x', '1x', 30};

r = 1;
obj.ExpEnableCheckBox = uicheckbox(cg, "Text", "Enable the Export step", "FontWeight", "bold", ...
    "Value", false, "ValueChangedFcn", changed);
obj.ExpEnableCheckBox.Layout.Row = r; obj.ExpEnableCheckBox.Layout.Column = [1 2];
obj.ExpOverwriteCheckBox = uicheckbox(cg, "Text", "Overwrite existing", "FontWeight", "bold", "Value", false, ...
    "Tooltip", "Replace output files that already exist (off = skip those datasets).", "ValueChangedFcn", changed);
obj.ExpOverwriteCheckBox.Layout.Row = r; obj.ExpOverwriteCheckBox.Layout.Column = [3 4];

r = r + 1; sep(cg, "Formats", r);
r = r + 1;
obj.ExpNWBCheckBox = uicheckbox(cg, "Text", "NWB 2 (<Name>.nwb)", "Value", false, ...
    "Tooltip", ["Neurodata Without Borders: electrodes on the probe, the derived signals, the sorted units " ...
                "with their quality metrics, the paired trials, the digital lines and the erased periods. " ...
                "Written by Python (pynwb) and checked with nwbinspector; see the NWB settings below."], ...
    "ValueChangedFcn", changed);
obj.ExpNWBCheckBox.Layout.Row = r; obj.ExpNWBCheckBox.Layout.Column = [1 2];

r = r + 1; sep(cg, "Contents", r);
r = r + 1;
lab(cg, "Signals:", r);
obj.ExpSignalsField = uieditfield(cg, "text", "Placeholder", "blank = every signal in the extract (LFP, MUA, SPIKE, AUX)", ...
    "Tooltip", "Comma-separated subset of LFP, MUA, SPIKE, AUX (accelerometer) taken from the Signals step's extract file.", ...
    "ValueChangedFcn", changed);
obj.ExpSignalsField.Layout.Row = r; obj.ExpSignalsField.Layout.Column = [2 4];
r = r + 1;
obj.ExpUnitsCheckBox = uicheckbox(cg, "Text", "Sorted units", "Value", true, ...
    "Tooltip", "The sorted (phy) units associated with each dataset.", "ValueChangedFcn", changed);
obj.ExpUnitsCheckBox.Layout.Row = r; obj.ExpUnitsCheckBox.Layout.Column = 1;
lg = lab(cg, "Groups:", r); lg.Layout.Column = 2;
obj.ExpGroupsField = uieditfield(cg, "text", "Value", "good, mua", ...
    "Tooltip", "phy labels to keep. Blank = every non-noise cluster.", "ValueChangedFcn", changed);
obj.ExpGroupsField.Layout.Row = r; obj.ExpGroupsField.Layout.Column = [3 4];
r = r + 1;
obj.ExpEventsCheckBox = uicheckbox(cg, "Text", "Digital-input events", "Value", true, "ValueChangedFcn", changed);
obj.ExpEventsCheckBox.Layout.Row = r; obj.ExpEventsCheckBox.Layout.Column = [1 2];

r = r + 1; sep(cg, "NWB (EphysDataset.exportNWB)", r);
r = r + 1;
lab(cg, "Electrode location:", r);
obj.ExpNWBLocationField = uieditfield(cg, "text", "Placeholder", "brain region (blank = unknown)", ...
    "Tooltip", "Where the electrodes are, e.g. an Allen CCF region; written as each electrode's location.", ...
    "ValueChangedFcn", changed);
obj.ExpNWBLocationField.Layout.Row = r; obj.ExpNWBLocationField.Layout.Column = [2 4];
r = r + 1;
lab(cg, "Subject:", r);
obj.ExpNWBSpeciesField = uieditfield(cg, "text", "Placeholder", "species, e.g. Mus musculus", ...
    "Tooltip", "Latin binomial or NCBI taxonomy URL. Left blank, nothing is written and nwbinspector reports it.", ...
    "ValueChangedFcn", changed);
obj.ExpNWBSpeciesField.Layout.Row = r; obj.ExpNWBSpeciesField.Layout.Column = 2;
obj.ExpNWBSexDropDown = uidropdown(cg, "Items", {'sex: not given', 'female (F)', 'male (M)', 'unknown (U)', 'other (O)'}, ...
    "ItemsData", {'', 'F', 'M', 'U', 'O'}, "Value", '', "ValueChangedFcn", changed);
obj.ExpNWBSexDropDown.Layout.Row = r; obj.ExpNWBSexDropDown.Layout.Column = [3 4];
r = r + 1;
lab(cg, "Age / time zone:", r);
obj.ExpNWBAgeField = uieditfield(cg, "text", "Placeholder", "age, ISO 8601: P90D", ...
    "Tooltip", "The subject's age as an ISO 8601 duration (P90D = 90 days, P12W = 12 weeks).", ...
    "ValueChangedFcn", changed);
obj.ExpNWBAgeField.Layout.Row = r; obj.ExpNWBAgeField.Layout.Column = 2;
obj.ExpNWBTimeZoneField = uieditfield(cg, "text", "Placeholder", "time zone (blank = this computer's)", ...
    "Tooltip", "IANA name of the time zone the recording was made in (America/New_York); the session start is written with it.", ...
    "ValueChangedFcn", changed);
obj.ExpNWBTimeZoneField.Layout.Row = r; obj.ExpNWBTimeZoneField.Layout.Column = [3 4];
r = r + 1;
lab(cg, "Experimenter:", r);
obj.ExpNWBExperimenterField = uieditfield(cg, "text", "Placeholder", "Last, First; Last, First", ...
    "Tooltip", "One person per ';' (each as Last, First).", "ValueChangedFcn", changed);
obj.ExpNWBExperimenterField.Layout.Row = r; obj.ExpNWBExperimenterField.Layout.Column = [2 4];
r = r + 1;
lab(cg, "Lab / institution:", r);
obj.ExpNWBLabField = uieditfield(cg, "text", "Placeholder", "lab", "ValueChangedFcn", changed);
obj.ExpNWBLabField.Layout.Row = r; obj.ExpNWBLabField.Layout.Column = 2;
obj.ExpNWBInstitutionField = uieditfield(cg, "text", "Placeholder", "institution", "ValueChangedFcn", changed);
obj.ExpNWBInstitutionField.Layout.Row = r; obj.ExpNWBInstitutionField.Layout.Column = [3 4];
r = r + 1;
lab(cg, "Python (NWB):", r);
obj.ExpNWBPythonField = uieditfield(cg, "text", "Placeholder", "blank = the Sorting tab's Python", ...
    "Tooltip", "A Python with pynwb and nwbinspector (pip install pynwb nwbinspector); INSTALL.md.", ...
    "ValueChangedFcn", changed);
obj.ExpNWBPythonField.Layout.Row = r; obj.ExpNWBPythonField.Layout.Column = [2 4];
r = r + 1;
lab(cg, "Conda env (NWB):", r);
obj.ExpNWBCondaField = uieditfield(cg, "text", "Placeholder", "blank = the Sorting tab's", ...
    "Tooltip", "conda run -n <env> when set.", "ValueChangedFcn", changed);
obj.ExpNWBCondaField.Layout.Row = r; obj.ExpNWBCondaField.Layout.Column = 2;
obj.ExpNWBInspectCheckBox = uicheckbox(cg, "Text", "Check with nwbinspector", "Value", true, ...
    "Tooltip", "Run nwbinspector (pynwb's validation and the NWB best practices) on each file; findings of " + ...
        "importance CRITICAL or above are reported, all go to <Name>_nwbinspector.json.", ...
    "ValueChangedFcn", changed);
obj.ExpNWBInspectCheckBox.Layout.Row = r; obj.ExpNWBInspectCheckBox.Layout.Column = [3 4];

r = r + 1; sep(cg, "Output", r);
r = r + 1;
lab(cg, "Output folder:", r);
obj.ExpOutputDirField = uieditfield(cg, "text", "Placeholder", "blank = each dataset's output folder", ...
    "ValueChangedFcn", changed);
obj.ExpOutputDirField.Layout.Row = r; obj.ExpOutputDirField.Layout.Column = [2 3];
obj.ExpBrowseOutputButton = uibutton(cg, "Text", "...", "ButtonPushedFcn", @(~,~) obj.onBrowseExportOutput());
obj.ExpBrowseOutputButton.Layout.Row = r; obj.ExpBrowseOutputButton.Layout.Column = 4;
r = r + 1;
note = uilabel(cg, "WordWrap", "on", "FontColor", [0.4 0.4 0.4], "Text", ...
    "The export reads the Signals step's extract file(s) (<Name>_extract.mat, or <Name>_extract_<TYPE>.mat per signal type), so run Signals first. The inputs of the analysis toolboxes (Chronux, FieldTrip, kCSD, ...) and event-organized epochs are made in the DatasetBrowser (its post-processing scripts).");
note.Layout.Row = r; note.Layout.Column = [1 4];
cg.RowHeight{r} = 56;

% =================== right: plan + run ===================
runPanel = uipanel(g, "Title", "This step for the selected datasets");
runPanel.Layout.Column = 2;
rg = uigridlayout(runPanel, [2 3]);
rg.RowHeight   = {'1x', 30};
rg.ColumnWidth = {'fit', '1x', 'fit'};
obj.ExpTargetsTable = uitable(rg, "ColumnName", {'Step', 'Dataset', 'Subject', 'Date', 'Output file', 'Status', 'Note'}, ...
    "ColumnWidth", {'fit', 'fit', 90, 84, '2x', 130, '1x'}, "RowName", {});
obj.ExpTargetsTable.Layout.Row = 1; obj.ExpTargetsTable.Layout.Column = [1 3];
makeSortable(obj, obj.ExpTargetsTable, "ExportPlan");
obj.RunStepExportButton = uibutton(rg, "Text", "Run this step", ...
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
