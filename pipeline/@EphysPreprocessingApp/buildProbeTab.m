function buildProbeTab(obj)
%buildProbeTab  Pick a probe .json, channel-count check, assign to datasets,
%   the active dataset's channel exclusions, and the config's default probe.
%   Left: probe folder, probe table and the actions; right: the selected
%   probe's info and channel arrangement.

g = uigridlayout(obj.TabProbe, [1 2]);
g.ColumnWidth = {'1x', 460};
g.Padding     = [10 10 10 10];

% =================== left: library + actions ===================
left = uigridlayout(g, [7 1]);
left.Layout.Column = 1;
left.RowHeight = {'fit', '1x', 30, 'fit', 30, 'fit', 'fit'};
left.Padding   = [0 0 0 0];

% Row 1: probe folder
fr = uigridlayout(left, [1 5]);
fr.Layout.Row = 1;
fr.ColumnWidth = {'fit', 420, 'fit', 'fit', '1x'};
fr.Padding = [0 0 0 0];
uilabel(fr, "Text", "Probe folder:");
obj.ProbeFolderField = uieditfield(fr, "text", "Placeholder", "Folder of Kilosort4 probe .json files");
obj.BrowseProbeFolderButton = uibutton(fr, "Text", "Browse...", ...
    "ButtonPushedFcn", @(~,~) obj.onBrowseProbeFolder());
obj.RefreshProbesButton = uibutton(fr, "Text", "Refresh", ...
    "ButtonPushedFcn", @(~,~) obj.refreshProbeList());

% Row 2: table of probes
obj.ProbeTable = uitable(left);
obj.ProbeTable.Layout.Row = 2;
obj.ProbeTable.ColumnName = {'Probe', 'Ch', 'Shanks', 'Depth (um)', 'Notes'};
obj.ProbeTable.ColumnEditable = [false false false false true];
obj.ProbeTable.ColumnWidth = {'fit', 45, 60, 85, '1x'};
obj.ProbeTable.CellSelectionCallback = @(~,evt) obj.onProbeRowSelected(evt);
obj.ProbeTable.CellEditCallback = @(~,evt) obj.onProbeNotesEdited(evt);

% Row 3: design / import / edit
br = uigridlayout(left, [1 4]);
br.Layout.Row = 3;
br.ColumnWidth = {'fit', 'fit', 'fit', '1x'};
br.Padding = [0 0 0 0];
obj.DesignProbeButton = uibutton(br, "Text", "Design probe (probeinterface)...", ...
    "Tooltip", "Pick a manufactured probe from the probeinterface library or generate a geometry, wire it to channels, and save a Kilosort4 .json.", ...
    "ButtonPushedFcn", @(~,~) obj.onDesignProbe());
obj.ImportProbeButton = uibutton(br, "Text", "Import probe .json into folder...", ...
    "ButtonPushedFcn", @(~,~) obj.onImportProbe());
obj.EditProbeJSONButton = uibutton(br, "Text", "Edit probe .json...", ...
    "ButtonPushedFcn", @(~,~) obj.onEditProbeJSON());

% Row 4: assign
lbl = uilabel(left, "Text", "Assignment", "FontWeight", "bold");
lbl.Layout.Row = 4;
ar = uigridlayout(left, [1 3]);
ar.Layout.Row = 5;
ar.ColumnWidth = {'fit', 'fit', '1x'};
ar.Padding = [0 0 0 0];
obj.AssignSelectedButton = uibutton(ar, "Text", "Assign to selected datasets", ...
    "Tooltip", "Assign the probe to the datasets ticked in the Project table (the active dataset if none are ticked).", ...
    "ButtonPushedFcn", @(~,~) obj.onAssignProbe("selected"));
obj.AssignAllButton = uibutton(ar, "Text", "Assign to all datasets", ...
    "ButtonPushedFcn", @(~,~) obj.onAssignProbe("all"));

% Rows 6-7: the active dataset and its channel exclusions, the config's default probe
fg = uigridlayout(left, [3 5]);
fg.Layout.Row = [6 7];
fg.RowHeight   = {'fit', 'fit', 'fit'};
fg.ColumnWidth = {'fit', 340, 'fit', 'fit', '1x'};
fg.Padding     = [0 0 0 0];
dsLbl = uilabel(fg, "Text", "Dataset:", ...
    "Tooltip", "The dataset whose exclusions are edited below and checked against the probe on the right.");
dsLbl.Layout.Row = 1; dsLbl.Layout.Column = 1;
obj.ProbeDatasetDropDown = obj.datasetPicker(fg);
obj.ProbeDatasetDropDown.Layout.Row = 1; obj.ProbeDatasetDropDown.Layout.Column = 2;
exLbl = uilabel(fg, "Text", "Exclude channels:", ...
    "Tooltip", "1-based channels to drop from sorting (and optionally from the Signals step), e.g. 1,5,32-40. Saved to the dataset manifest.");
exLbl.Layout.Row = 2; exLbl.Layout.Column = 1;
obj.ExcludeChannelsField = uieditfield(fg, "text", ...
    "Placeholder", "e.g. 1,5,32-40 (blank = none)", ...
    "Tooltip", "Saved to the manifest of the dataset chosen above.", ...
    "ValueChangedFcn", @(~,~) obj.onApplyExclude("selected"));
obj.ExcludeChannelsField.Layout.Row = 2; obj.ExcludeChannelsField.Layout.Column = 2;

dfLbl = uilabel(fg, "Text", "Default probe (config):", ...
    "Tooltip", "Used for every dataset that has no probe of its own (the probe check, Sorting).");
dfLbl.Layout.Row = 3; dfLbl.Layout.Column = 1;
obj.ProbeDefaultField = uieditfield(fg, "text", "Placeholder", "blank = none", ...
    "ValueChangedFcn", @(~,~) obj.onConfigChanged());
obj.ProbeDefaultField.Layout.Row = 3; obj.ProbeDefaultField.Layout.Column = 2;
obj.ProbeUseSelectedButton = uibutton(fg, "Text", "Use selected probe", ...
    "ButtonPushedFcn", @(~,~) obj.onUseSelectedProbeAsDefault());
obj.ProbeUseSelectedButton.Layout.Row = 3; obj.ProbeUseSelectedButton.Layout.Column = 3;
obj.ProbeWriteDefaultCheckBox = uicheckbox(fg, "Text", "Save to manifests", "Value", false, ...
    "Tooltip", "The run's probe check also assigns the default probe to each dataset without one and saves it in its manifest.", ...
    "ValueChangedFcn", @(~,~) obj.onConfigChanged());
obj.ProbeWriteDefaultCheckBox.Layout.Row = 3; obj.ProbeWriteDefaultCheckBox.Layout.Column = 4;

% =================== right: probe info + preview ===================
infoPanel = uipanel(g, "Title", "Probe info");
infoPanel.Layout.Column = 2;
ig = uigridlayout(infoPanel, [4 1]);
ig.RowHeight = {'fit', 'fit', '1x', 'fit'};
obj.ProbeInfoLabel = uilabel(ig, "Text", "Select a probe.", "VerticalAlignment", "top", "WordWrap", "on");
obj.ProbeCheckLabel = uilabel(ig, "Text", "", "VerticalAlignment", "top", "WordWrap", "on", "FontWeight", "bold");
obj.ProbePreviewAxes = uiaxes(ig);
obj.ProbePreviewAxes.Layout.Row = 3;
title(obj.ProbePreviewAxes, "Channel arrangement");
xlabel(obj.ProbePreviewAxes, "x (\mum)");
ylabel(obj.ProbePreviewAxes, "y (\mum)");
obj.ShowChanNumbersCheckBox = uicheckbox(ig, "Text", "Show channel numbers", "Value", true, ...
    "Tooltip", "Label each probe site with its 1-based recording channel number.", ...
    "ValueChangedFcn", @(~,~) obj.onProbeSelected());
obj.ShowChanNumbersCheckBox.Layout.Row = 4;
end
