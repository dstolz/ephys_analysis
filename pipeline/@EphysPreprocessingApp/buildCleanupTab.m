function buildCleanupTab(obj)
%buildCleanupTab  Clean up tab: free local disk space once datasets are preprocessed.
%   Lists every local file of the selected datasets as Remove or Keep
%   (planLocalCleanup) and, after a confirmation that says what goes and
%   what stays, deletes the Remove rows (runLocalCleanup). Not a pipeline
%   step and not part of the config: the kinds ticked are a preference.

g = uigridlayout(obj.TabCleanup, [1 2]);
g.ColumnWidth = {400, '1x'};
g.Padding     = [10 10 10 10];
stale = @(~,~) obj.onCleanupSettingsChanged();

% =================== left: what to remove ===================
opt = uipanel(g, "Title", "What to remove (planLocalCleanup / runLocalCleanup)");
opt.Layout.Column = 1;
cg = uigridlayout(opt, [13 2]);
cg.RowHeight   = {'fit', 22, 24, 'fit', 24, 'fit', 24, 'fit', 22, 'fit', 'fit', 32, '1x'};
cg.ColumnWidth = {'1x', '1x'};
cg.RowSpacing  = 4;

obj.CleanupScopeLabel = uilabel(cg, "WordWrap", "on", "Text", "Scan a project first.");
obj.CleanupScopeLabel.Layout.Row = 1; obj.CleanupScopeLabel.Layout.Column = [1 2];

sep(cg, "Remove, for the selected datasets", 2);
obj.CleanupRawCheckBox = uicheckbox(cg, "Text", "Raw recording files", "Value", true, ...
    "FontWeight", "bold", "ValueChangedFcn", stale);
obj.CleanupRawCheckBox.Layout.Row = 3; obj.CleanupRawCheckBox.Layout.Column = [1 2];
note(cg, 4, "Only the Intan files the Copy tab copied (listed in session_manifest.json), and only when " + ...
    "the source still holds each one with the same size, so it can be copied back. " + ...
    "Afterwards the dataset cannot be run, viewed or scanned until it is copied back.");
obj.CleanupSorterCopyCheckBox = uicheckbox(cg, "Text", "Kilosort4's filtered copy of the recording", ...
    "Value", true, "FontWeight", "bold", "ValueChangedFcn", stale);
obj.CleanupSorterCopyCheckBox.Layout.Row = 5; obj.CleanupSorterCopyCheckBox.Layout.Column = [1 2];
note(cg, 6, "recording.dat / temp_wh.dat in the sorting folder, about the size of the raw recording. " + ...
    "The sorted units do not need it; phy's trace view does.");
obj.CleanupBinCheckBox = uicheckbox(cg, "Text", "Sorting input .bin (<Name>.bin + .json)", ...
    "Value", true, "FontWeight", "bold", "ValueChangedFcn", stale);
obj.CleanupBinCheckBox.Layout.Row = 7; obj.CleanupBinCheckBox.Layout.Column = [1 2];
note(cg, 8, "The flat binary toBin writes for the native Kilosort engine, as large as the raw recording. " + ...
    "As above: the sorted units do not need it; phy's trace view does.");

sep(cg, "Always kept", 9);
note(cg, 10, "Every pipeline output (extract, spikes, behavior, events, artifacts, toolbox exports)," + ...
    "the sorted output (phy files), the dataset manifest, the copy record (session_manifest.json), " + ...
    "the Epsych2 session file and any file not named above. Nothing on the source is touched.");
note(cg, 11, "Files are deleted outright, not moved to the Recycle Bin. Each dataset gets <Name>_cleanup.json " + ...
    "listing what was removed and where its source copy is.");

obj.CleanupPreviewButton = uibutton(cg, "Text", "Preview", "FontWeight", "bold", ...
    "Tooltip", "List the files of the selected datasets as Remove or Keep; nothing is changed.", ...
    "ButtonPushedFcn", @(~,~) obj.onCleanupPreview());
obj.CleanupPreviewButton.Layout.Row = 12; obj.CleanupPreviewButton.Layout.Column = 1;
obj.CleanupRunButton = uibutton(cg, "Text", "Remove files...", "Enable", "off", ...
    "BackgroundColor", [0.80 0.25 0.20], "FontColor", [1 1 1], "FontWeight", "bold", ...
    "Tooltip", "Delete the Remove rows of the preview, after a confirmation.", ...
    "ButtonPushedFcn", @(~,~) obj.onCleanupRun());
obj.CleanupRunButton.Layout.Row = 12; obj.CleanupRunButton.Layout.Column = 2;

% =================== right: the files ===================
right = uipanel(g, "Title", "Files of the selected datasets");
right.Layout.Column = 2;
rg = uigridlayout(right, [4 2]);
rg.RowHeight   = {'fit', '1x', 24, 90};
rg.ColumnWidth = {'1x', 'fit'};
obj.CleanupSummaryLabel = uilabel(rg, "WordWrap", "on", "FontWeight", "bold", ...
    "Text", "Press Preview to see what would be removed and what would remain.");
obj.CleanupSummaryLabel.Layout.Row = 1; obj.CleanupSummaryLabel.Layout.Column = [1 2];
obj.CleanupTable = uitable(rg, "RowName", {}, ...
    "ColumnName", {'Action', 'Dataset', 'What', 'Size', 'File', 'Why'}, ...
    "ColumnWidth", {60, 'fit', 190, 70, '2x', '2x'});
obj.CleanupTable.Layout.Row = 2; obj.CleanupTable.Layout.Column = [1 2];
obj.CleanupShowKeptCheckBox = uicheckbox(rg, "Text", "Show the files that remain", "Value", true, ...
    "ValueChangedFcn", @(~,~) obj.refreshCleanupTable());
obj.CleanupShowKeptCheckBox.Layout.Row = 3; obj.CleanupShowKeptCheckBox.Layout.Column = 1;
obj.CleanupLogArea = uitextarea(rg, "Editable", "off", "FontName", "Consolas");
obj.CleanupLogArea.Layout.Row = 4; obj.CleanupLogArea.Layout.Column = [1 2];
end


function sep(parent, txt, row)
l = uilabel(parent, "Text", txt, "FontWeight", "bold");
l.Layout.Row = row;
l.Layout.Column = [1 2];
end


function note(parent, row, txt)
l = uilabel(parent, "Text", txt, "WordWrap", "on", "FontColor", [0.4 0.4 0.4]);
l.Layout.Row = row;
l.Layout.Column = [1 2];
end
