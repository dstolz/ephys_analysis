function buildProbeTab(obj)
%buildProbeTab  Pick a probe .json, channel-count check, assign to datasets,
%   per-dataset channel exclusions, and the config's default probe.

g = uigridlayout(obj.TabProbe, [7 4]);
g.RowHeight   = {'fit', '1x', 'fit', 'fit', 'fit', 'fit', 'fit'};
g.ColumnWidth = {'fit', '1x', 'fit', 'fit'};
g.Padding     = [10 10 10 10];

% Row 1: probe folder
lbl = uilabel(g, "Text", "Probe folder:");
lbl.Layout.Row = 1; lbl.Layout.Column = 1;
obj.ProbeFolderField = uieditfield(g, "text", "Placeholder", "Folder of Kilosort4 probe .json files");
obj.ProbeFolderField.Layout.Row = 1; obj.ProbeFolderField.Layout.Column = 2;
obj.BrowseProbeFolderButton = uibutton(g, "Text", "Browse...", ...
    "ButtonPushedFcn", @(~,~) obj.onBrowseProbeFolder());
obj.BrowseProbeFolderButton.Layout.Row = 1; obj.BrowseProbeFolderButton.Layout.Column = 3;
obj.RefreshProbesButton = uibutton(g, "Text", "Refresh", ...
    "ButtonPushedFcn", @(~,~) obj.refreshProbeList());
obj.RefreshProbesButton.Layout.Row = 1; obj.RefreshProbesButton.Layout.Column = 4;

% Row 2: table of probes + info
obj.ProbeTable = uitable(g);
obj.ProbeTable.Layout.Row = 2; obj.ProbeTable.Layout.Column = [1 2];
obj.ProbeTable.ColumnName = {'Probe', 'Ch', 'Shanks', 'Depth (um)', 'Notes'};
obj.ProbeTable.ColumnEditable = [false false false false true];
obj.ProbeTable.ColumnWidth = {'auto', 45, 60, 80, 'auto'};
obj.ProbeTable.CellSelectionCallback = @(~,evt) obj.onProbeRowSelected(evt);
obj.ProbeTable.CellEditCallback = @(~,evt) obj.onProbeNotesEdited(evt);

infoPanel = uipanel(g, "Title", "Probe info");
infoPanel.Layout.Row = 2; infoPanel.Layout.Column = [3 4];
ig = uigridlayout(infoPanel, [3 1]);
ig.RowHeight = {'fit', 'fit', '1x'};
obj.ProbeInfoLabel = uilabel(ig, "Text", "Select a probe.", "VerticalAlignment", "top", "WordWrap", "on");
obj.ProbeCheckLabel = uilabel(ig, "Text", "", "VerticalAlignment", "top", "WordWrap", "on", "FontWeight", "bold");
obj.ProbePreviewAxes = uiaxes(ig);
obj.ProbePreviewAxes.Layout.Row = 3;
title(obj.ProbePreviewAxes, "Channel arrangement");
xlabel(obj.ProbePreviewAxes, "x (\mum)");
ylabel(obj.ProbePreviewAxes, "y (\mum)");

% Row 3: design
obj.DesignProbeButton = uibutton(g, "Text", "Design probe from probeinterface (library / generate)...", ...
    "Tooltip", "Pick a manufactured probe or generate a geometry, wire it to channels, and save a Kilosort4 .json.", ...
    "ButtonPushedFcn", @(~,~) obj.onDesignProbe());
obj.DesignProbeButton.Layout.Row = 3; obj.DesignProbeButton.Layout.Column = [1 4];

% Row 4: import / edit + channel numbers
obj.ImportProbeButton = uibutton(g, "Text", "Import probe .json into folder...", ...
    "ButtonPushedFcn", @(~,~) obj.onImportProbe());
obj.ImportProbeButton.Layout.Row = 4; obj.ImportProbeButton.Layout.Column = 1;
obj.EditProbeJSONButton = uibutton(g, "Text", "Edit probe .json...", ...
    "ButtonPushedFcn", @(~,~) obj.onEditProbeJSON());
obj.EditProbeJSONButton.Layout.Row = 4; obj.EditProbeJSONButton.Layout.Column = 2;
obj.ShowChanNumbersCheckBox = uicheckbox(g, "Text", "Show channel numbers", "Value", false, ...
    "Tooltip", "Label each probe site with its 1-based recording channel number.", ...
    "ValueChangedFcn", @(~,~) obj.onProbeSelected());
obj.ShowChanNumbersCheckBox.Layout.Row = 4; obj.ShowChanNumbersCheckBox.Layout.Column = [3 4];

% Row 5: per-recording channel exclusions (saved to the dataset manifest)
exLbl = uilabel(g, "Text", "Exclude channels:", ...
    "Tooltip", "1-based channels to drop from sorting (and optionally from the Signals step), e.g. 1,5,32-40. Saved to the dataset manifest.");
exLbl.Layout.Row = 5; exLbl.Layout.Column = 1;
obj.ExcludeChannelsField = uieditfield(g, "text", ...
    "Placeholder", "e.g. 1,5,32-40 (blank = none) - saved to the selected dataset's manifest", ...
    "ValueChangedFcn", @(~,~) obj.onApplyExclude("selected"));
obj.ExcludeChannelsField.Layout.Row = 5; obj.ExcludeChannelsField.Layout.Column = [2 4];

% Row 6: assign
obj.AssignSelectedButton = uibutton(g, "Text", "Assign to selected datasets", ...
    "Tooltip", "Assign the probe to the datasets ticked in the Project table (the last-clicked row if none are ticked).", ...
    "ButtonPushedFcn", @(~,~) obj.onAssignProbe("selected"));
obj.AssignSelectedButton.Layout.Row = 6; obj.AssignSelectedButton.Layout.Column = 1;
obj.AssignAllButton = uibutton(g, "Text", "Assign to all datasets", ...
    "ButtonPushedFcn", @(~,~) obj.onAssignProbe("all"));
obj.AssignAllButton.Layout.Row = 6; obj.AssignAllButton.Layout.Column = 2;

% Row 7: the config's default probe (assigned by the probe preflight)
dfLbl = uilabel(g, "Text", "Default probe (config):", ...
    "Tooltip", "Assigned by the run's probe check to every selected dataset that has no probe yet.");
dfLbl.Layout.Row = 7; dfLbl.Layout.Column = 1;
obj.ProbeDefaultField = uieditfield(g, "text", "Placeholder", "blank = none", ...
    "ValueChangedFcn", @(~,~) obj.onConfigChanged());
obj.ProbeDefaultField.Layout.Row = 7; obj.ProbeDefaultField.Layout.Column = 2;
obj.ProbeUseSelectedButton = uibutton(g, "Text", "Use selected probe", ...
    "ButtonPushedFcn", @(~,~) obj.onUseSelectedProbeAsDefault());
obj.ProbeUseSelectedButton.Layout.Row = 7; obj.ProbeUseSelectedButton.Layout.Column = 3;
obj.ProbeWriteDefaultCheckBox = uicheckbox(g, "Text", "Save to manifests", "Value", false, ...
    "Tooltip", "When the default probe is assigned during a run, also write it into the dataset manifest.", ...
    "ValueChangedFcn", @(~,~) obj.onConfigChanged());
obj.ProbeWriteDefaultCheckBox.Layout.Row = 7; obj.ProbeWriteDefaultCheckBox.Layout.Column = 4;
end
