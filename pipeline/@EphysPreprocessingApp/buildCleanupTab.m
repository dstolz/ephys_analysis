function buildCleanupTab(obj)
%buildCleanupTab  Clean up tab: free local disk space, or remove what preprocessing steps wrote.
%   Lists every local file of the selected datasets as Remove or Keep
%   (planLocalCleanup) and, after a confirmation that says what goes and
%   what stays, deletes the Remove rows, sends them to the Recycle Bin or
%   moves them to a folder (runLocalCleanup). Not a pipeline step and not
%   part of the config: the kinds ticked and where files go are preferences.

g = uigridlayout(obj.TabCleanup, [1 2]);
g.ColumnWidth = {400, '1x'};
g.Padding     = [10 10 10 10];
stale = @(~,~) obj.onCleanupSettingsChanged();

% =================== left: what to remove ===================
opt = uipanel(g, "Title", "What to remove (planLocalCleanup / runLocalCleanup)");
opt.Layout.Column = 1;
og = uigridlayout(opt, [2 1]);   % the options scroll; the buttons under them stay in view
og.RowHeight = {'1x', 32};
og.Padding = [0 10 0 0];
og.RowSpacing = 6;
cg = uigridlayout(og, [18 2]);
cg.Layout.Row = 1;
cg.RowHeight   = {'fit', 22, 24, 'fit', 24, 'fit', 24, 'fit', 22, 'fit', 'fit', 22, 'fit', 22, 24, 26, 'fit', '1x'};
cg.ColumnWidth = {'1x', '1x'};
cg.RowSpacing  = 4;
cg.Scrollable  = "on";

obj.CleanupScopeLabel = uilabel(cg, "WordWrap", "on", "Text", "Scan a project first.");
obj.CleanupScopeLabel.Layout.Row = 1; obj.CleanupScopeLabel.Layout.Column = [1 2];

sep(cg, "Free space (the outputs stay), for the selected datasets", 2);
obj.CleanupRawCheckBox = uicheckbox(cg, "Text", "Raw recording files", "Value", true, ...
    "FontWeight", "bold", "ValueChangedFcn", stale);
obj.CleanupRawCheckBox.Layout.Row = 3; obj.CleanupRawCheckBox.Layout.Column = [1 2];
note(cg, 4, "Only the recording files the Copy tab copied (listed in session_manifest.json), and only when " + ...
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

% one box per step that writes files (the probe step writes none)
sep(cg, "Remove what a preprocessing step wrote", 9);
sg = uigridlayout(cg, [3 2]);
sg.Layout.Row = 10; sg.Layout.Column = [1 2];
sg.RowHeight = {22, 22, 22}; sg.ColumnWidth = {'1x', '1x'};
sg.Padding = [0 0 0 0]; sg.RowSpacing = 2;
steps = ["sorting" "Sorting (Kilosort4)" "The kilosort4 folder (the sorted units with their phy curation and unit notes, " + ...
        "run files, logs, Kilosort4's copy of the recording) and <Name>.bin + .json. A sorted-output folder chosen by hand is kept."
    "signals" "Signals" "The derived-signal .mat files (<Name>_extract*.mat, or the configured suffix and folder)."
    "spikes" "Spikes" "The spikes .mat (<Name>_spikes.mat, or the configured suffix and folder)."
    "behavior" "Behavior" "<Name>_behavior.mat and the digital events cache <Name>_events.mat. The trial pairing in the manifest stays."
    "artifacts" "Artifacts" "The artifact-interval cache <Name>_artifacts.json. Manual artifact periods (in the manifest) stay."
    "export" "Export" "The Chronux, FieldTrip and epochs .mat files."];
for k = 1:size(steps, 1)
    obj.CleanupStepCheckBoxes(k) = uicheckbox(sg, "Text", steps(k, 2), "Tag", steps(k, 1), ...
        "Value", false, "Tooltip", steps(k, 3), "ValueChangedFcn", stale);
end
note(cg, 11, "Everything the step wrote, to run it again or drop it (hover over a box for its files). " + ...
    "Sorting takes the whole kilosort4 folder, phy curation included.");

sep(cg, "Always kept", 12);
note(cg, 13, "The outputs of the steps not ticked, the manifests, the copy record, the Epsych2 session file, " + ...
    "the clean-up record and any other file. Nothing on the source is touched.");

% where removed files go (acts on the preview as it is: changing it keeps the preview)
sep(cg, "Removed files go", 14);
ways = ["delete" "Delete permanently"; "recycle" "Move to the Recycle Bin"; "move" "Move to a folder"];
if ~ispc; ways(2, :) = []; end   % the Recycle Bin is Windows only
obj.CleanupMethodDropDown = uidropdown(cg, "Items", cellstr(ways(:, 2)), "ItemsData", cellstr(ways(:, 1)), ...
    "Value", 'delete', "Tooltip", "What happens to the Remove files of the preview.", ...
    "ValueChangedFcn", @(~,~) obj.onCleanupMethodChanged());
obj.CleanupMethodDropDown.Layout.Row = 15; obj.CleanupMethodDropDown.Layout.Column = [1 2];
dg = uigridlayout(cg, [1 2]);
dg.Layout.Row = 16; dg.Layout.Column = [1 2];
dg.ColumnWidth = {'1x', 80}; dg.Padding = [0 0 0 0];
obj.CleanupDestField = uieditfield(dg, "text", "Placeholder", "Folder to move the files into", ...
    "Tooltip", "Each file goes to <folder>\<dataset key>\<its path in the dataset folder>. " + ...
    "Not inside the project or output root, where a scan would find the files again.");
obj.CleanupDestButton = uibutton(dg, "Text", "Browse...", ...
    "ButtonPushedFcn", @(~,~) obj.onCleanupBrowseDest());
obj.CleanupMethodNote = uilabel(cg, "Text", "", "WordWrap", "on", "FontColor", [0.4 0.4 0.4]);
obj.CleanupMethodNote.Layout.Row = 17; obj.CleanupMethodNote.Layout.Column = [1 2];

pb = uigridlayout(og, [1 2]);
pb.Layout.Row = 2;
pb.Padding = [10 0 10 0];
obj.CleanupPreviewButton = uibutton(pb, "Text", "Preview", ...   % primary, and Run danger (buildUI styleButtons)
    "Tooltip", "List the files of the selected datasets as Remove or Keep; nothing is changed.", ...
    "ButtonPushedFcn", @(~,~) obj.onCleanupPreview());
obj.CleanupRunButton = uibutton(pb, "Text", "Delete files...", "Enable", "off", ...
    "ButtonPushedFcn", @(~,~) obj.onCleanupRun());
obj.onCleanupMethodChanged();

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
