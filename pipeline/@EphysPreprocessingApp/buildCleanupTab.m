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
% Include ticks which Remove files go (Keep files cannot be ticked); the
% search, Subject and "Show the files that remain" only filter what is
% shown, and the select buttons act on the rows shown.
right = uipanel(g, "Title", "Files of the selected datasets");
right.Layout.Column = 2;
rg = uigridlayout(right, [5 1]);
rg.RowHeight   = {'fit', 24, '1x', 24, 90};
rg.RowSpacing  = 6;
obj.CleanupSummaryLabel = uilabel(rg, "WordWrap", "on", "FontWeight", "bold", ...
    "Text", "Press Preview to see what would be removed and what would remain.");
obj.CleanupSummaryLabel.Layout.Row = 1;

fg = uigridlayout(rg, [1 4]);
fg.Layout.Row = 2;
fg.ColumnWidth = {'fit', '1x', 'fit', 160};
fg.Padding = [0 0 0 0];
uilabel(fg, "Text", "Search (regexp):");
obj.CleanupSearchField = uieditfield(fg, "text", "Placeholder", "e.g. \.rhd$ or kilosort4", ...
    "Tooltip", "Show only the files whose full path matches this regular expression (case-insensitive).", ...
    "ValueChangedFcn", @(~,~) obj.refreshCleanupTable());
uilabel(fg, "Text", "Subject ID:");
obj.CleanupSubjectDropDown = uidropdown(fg, "Items", {'All subjects'}, ...
    "Tooltip", "Show only the files of one subject (the SubjectID of Project.NamePattern).", ...
    "ValueChangedFcn", @(~,~) obj.refreshCleanupTable());

obj.CleanupTable = uitable(rg, "RowName", {}, "ColumnSortable", true, ...
    "ColumnName", {'Include', 'Action', 'Dataset', 'Subject', 'What', 'Size (MB)', 'File', 'Why'}, ...
    "ColumnWidth", {72, 78, 'fit', 80, 180, 92, '2x', '2x'}, ...
    "ColumnEditable", [true false(1, 7)], ...
    "ColumnFormat", {'logical', 'char', 'char', 'char', 'char', 'shortG', 'char', 'char'}, ...
    "Data", cell(0, 8), ...
    "CellEditCallback", @(~, evt) obj.onCleanupFileTicked(evt));
obj.CleanupTable.Layout.Row = 3;

bg = uigridlayout(rg, [1 6]);
bg.Layout.Row = 4;
bg.ColumnWidth = {'fit', '1x', 90, 90, 90, 95};
bg.Padding = [0 0 0 0];
obj.CleanupShowKeptCheckBox = uicheckbox(bg, "Text", "Show the files that remain", "Value", true, ...
    "ValueChangedFcn", @(~,~) obj.refreshCleanupTable());
obj.CleanupShownLabel = uilabel(bg, "Text", "", "FontColor", [0.4 0.4 0.4]);
obj.CleanupSelectButtons = [ ...
    uibutton(bg, "Text", "All visible", "Tooltip", "Tick every Remove file shown.", ...
        "ButtonPushedFcn", @(~,~) obj.onCleanupSelect("all"))
    uibutton(bg, "Text", "None visible", "Tooltip", "Untick every file shown.", ...
        "ButtonPushedFcn", @(~,~) obj.onCleanupSelect("none"))
    uibutton(bg, "Text", "Only visible", ...
        "Tooltip", "Tick every Remove file shown and untick every file hidden by the filters.", ...
        "ButtonPushedFcn", @(~,~) obj.onCleanupSelect("only"))
    uibutton(bg, "Text", "Invert visible", "Tooltip", "Flip the tick of every Remove file shown.", ...
        "ButtonPushedFcn", @(~,~) obj.onCleanupSelect("invert"))];
obj.CleanupLogArea = uitextarea(rg, "Editable", "off", "FontName", "Consolas");
obj.CleanupLogArea.Layout.Row = 5;
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
