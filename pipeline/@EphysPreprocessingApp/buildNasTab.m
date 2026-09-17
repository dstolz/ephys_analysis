function buildNasTab(obj)
%buildNasTab  NAS tab: find one subject's sessions on the NAS, pair each Intan
%   recording with its ePsych file by the timestamps in their names
%   (findNasSessions), and copy the ticked sessions to local session folders
%   (copyNasSessions). The app only collects the settings, shows the pairing
%   and passes the ticked rows on; the pairing and copy rules live in those
%   two functions. The settings are preferences, not part of the config.

g = uigridlayout(obj.TabNas, [4 1]);
g.RowHeight   = {'fit', 'fit', '2x', '1x'};
g.ColumnWidth = {'1x'};
g.Padding     = [10 10 10 10];
g.RowSpacing  = 8;

% --- session search ----------------------------------------------------------
top = uigridlayout(g, [4 8]);
top.Layout.Row = 1;
top.RowHeight   = {'fit', 'fit', 'fit', 'fit'};
top.ColumnWidth = {'fit', 170, 'fit', 130, 'fit', 130, 'fit', '1x'};
top.Padding     = [0 0 0 0];

lbl = uilabel(top, "Text", "Subject ID:");
lbl.Layout.Row = 1; lbl.Layout.Column = 1;
obj.NasSubjectField = uieditfield(top, "text", "Placeholder", "e.g. SUBJ-ID-1255", ...
    "Tooltip", "Must match the subject folder and file names exactly.");
obj.NasSubjectField.Layout.Row = 1; obj.NasSubjectField.Layout.Column = 2;
lbl = uilabel(top, "Text", "From:");
lbl.Layout.Row = 1; lbl.Layout.Column = 3;
obj.NasFromDatePicker = uidatepicker(top, "Value", datetime('today'), "DisplayFormat", "yyyy-MM-dd");
obj.NasFromDatePicker.Layout.Row = 1; obj.NasFromDatePicker.Layout.Column = 4;
lbl = uilabel(top, "Text", "To:");
lbl.Layout.Row = 1; lbl.Layout.Column = 5;
obj.NasToDatePicker = uidatepicker(top, "DisplayFormat", "yyyy-MM-dd", "Placeholder", "same day", ...
    "Tooltip", "Last day of the range (blank = the From day only).");
obj.NasToDatePicker.Layout.Row = 1; obj.NasToDatePicker.Layout.Column = 6;
obj.NasFindButton = uibutton(top, "Text", "Find sessions", "FontWeight", "bold", ...
    "BackgroundColor", [0.15 0.45 0.80], "FontColor", [1 1 1], ...
    "Tooltip", "List and pair the subject's ePsych files and Intan folders for these days (reads names only).", ...
    "ButtonPushedFcn", @(~,~) obj.onNasFind());
obj.NasFindButton.Layout.Row = 1; obj.NasFindButton.Layout.Column = 7;

roots = {"ePsych root:", "NasEpsychRootField", "NAS folder holding one folder of ePsych .mat files per subject."
         "Intan root:",  "NasIntanRootField",  "NAS folder holding one folder of Intan recording folders per subject."
         "Destination:", "NasDestRootField",   "Local root; each session is copied to <root>/<subject>/<Intan folder name>."};
for k = 1:3
    lbl = uilabel(top, "Text", roots{k, 1}, "Tooltip", roots{k, 3});
    lbl.Layout.Row = k + 1; lbl.Layout.Column = 1;
    f = uieditfield(top, "text", "Tooltip", roots{k, 3});
    f.Layout.Row = k + 1; f.Layout.Column = [2 6];
    obj.(roots{k, 2}) = f;
    b = uibutton(top, "Text", "Browse...", "ButtonPushedFcn", @(~,~) obj.onBrowseNasFolder(f));
    b.Layout.Row = k + 1; b.Layout.Column = 7;
end
obj.NasEpsychRootField.Value = 'S:/RIG3_Backup_2025/epsych_files/Data';
obj.NasIntanRootField.Value  = 'S:/RIG3_Backup_2025/intan_files/Data';
obj.NasDestRootField.Value   = 'D:/EPHYS';

% --- pairing and copy options + actions --------------------------------------------
bar = uigridlayout(g, [2 13]);
bar.Layout.Row = 2;
bar.RowHeight   = {'fit', 'fit'};
bar.ColumnWidth = {'fit', 50, 'fit', 50, 'fit', 50, 'fit', 70, 'fit', 70, '1x', 'fit', 'fit'};
bar.Padding     = [0 0 0 0];

lbl = uilabel(bar, "Text", "Max lead (min):", "Tooltip", "How long the ePsych file may start before the Intan recording.");
lbl.Layout.Row = 1; lbl.Layout.Column = 1;
obj.NasMaxLeadField = uieditfield(bar, "numeric", "Value", 10, "Limits", [0 Inf], "Tooltip", lbl.Tooltip);
obj.NasMaxLeadField.Layout.Row = 1; obj.NasMaxLeadField.Layout.Column = 2;
lbl = uilabel(bar, "Text", "Max lag (min):", "Tooltip", "How long the ePsych file may start after the Intan recording (clock skew).");
lbl.Layout.Row = 1; lbl.Layout.Column = 3;
obj.NasMaxLagField = uieditfield(bar, "numeric", "Value", 2, "Limits", [0 Inf], "Tooltip", lbl.Tooltip);
obj.NasMaxLagField.Layout.Row = 1; obj.NasMaxLagField.Layout.Column = 4;
lbl = uilabel(bar, "Text", "Ambiguity margin (s):", "Tooltip", ...
    "Candidates whose time differences are closer than this make the pairing ambiguous; ambiguous rows are never copied.");
lbl.Layout.Row = 1; lbl.Layout.Column = 5;
obj.NasMarginField = uieditfield(bar, "numeric", "Value", 30, "Limits", [0 Inf], "Tooltip", lbl.Tooltip);
obj.NasMarginField.Layout.Row = 1; obj.NasMarginField.Layout.Column = 6;
lbl = uilabel(bar, "Text", "Verify:", "Tooltip", "After copying: compare file sizes, or sizes and SHA-256 (reads every file twice).");
lbl.Layout.Row = 1; lbl.Layout.Column = 7;
obj.NasVerifyDropDown = uidropdown(bar, "Items", ["size", "hash"], "Value", "size", "Tooltip", lbl.Tooltip);
obj.NasVerifyDropDown.Layout.Row = 1; obj.NasVerifyDropDown.Layout.Column = 8;
lbl = uilabel(bar, "Text", "If it exists:", "Tooltip", ...
    "When a destination folder exists and differs from the source: skip the session or report it as failed. Nothing is ever overwritten.");
lbl.Layout.Row = 1; lbl.Layout.Column = 9;
obj.NasIfExistsDropDown = uidropdown(bar, "Items", ["skip", "error"], "Value", "skip", "Tooltip", lbl.Tooltip);
obj.NasIfExistsDropDown.Layout.Row = 1; obj.NasIfExistsDropDown.Layout.Column = 10;
obj.NasPreviewButton = uibutton(bar, "Text", "Preview (dry run)", ...
    "Tooltip", "Check the ticked sessions and report what a copy would do; writes nothing.", ...
    "ButtonPushedFcn", @(~,~) obj.onNasCopy(true));
obj.NasPreviewButton.Layout.Row = 1; obj.NasPreviewButton.Layout.Column = 12;
obj.NasCopyButton = uibutton(bar, "Text", "Copy selected", "FontWeight", "bold", ...
    "Tooltip", "Copy the ticked sessions, verify them and write session_manifest.json in each.", ...
    "ButtonPushedFcn", @(~,~) obj.onNasCopy(false));
obj.NasCopyButton.Layout.Row = 1; obj.NasCopyButton.Layout.Column = 13;

obj.NasSummaryLabel = uilabel(bar, "Text", "Enter a subject and dates, then Find sessions.", "FontColor", [0.4 0.4 0.4]);
obj.NasSummaryLabel.Layout.Row = 2; obj.NasSummaryLabel.Layout.Column = [1 10];
obj.NasScanAfterCheckBox = uicheckbox(bar, "Text", "After copying, open the copied sessions as the project", "Value", true, ...
    "Tooltip", "Set the Project root to the folder holding the copied sessions and Scan it.");
obj.NasScanAfterCheckBox.Layout.Row = 2; obj.NasScanAfterCheckBox.Layout.Column = [11 13];

% --- sessions table ------------------------------------------------------------------
obj.NasTable = uitable(g, "RowName", {}, "ColumnSortable", false, ...
    "CellEditCallback", @(~, evt) obj.onNasTableEdited(evt));
obj.NasTable.Layout.Row = 3;

% --- log -------------------------------------------------------------------------------
obj.NasLogArea = uitextarea(g, "Editable", "off", "FontName", "Consolas", "Value", {''});
obj.NasLogArea.Layout.Row = 4;

obj.refreshNasTable();
end
