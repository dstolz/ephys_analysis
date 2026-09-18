function buildCopyTab(obj)
%buildCopyTab  Copy tab: find one subject's sessions on the source, pair each Intan
%   recording with its ePsych file by the timestamps in their names
%   (findCopySessions), and copy the ticked sessions to local session folders
%   (copySessions). Rows picked by hand can be stitched into one recording
%   with several ePsych files (stitchCopySessions). The app only collects the
%   settings, shows the pairing and passes the ticked rows on; the pairing,
%   stitching and copy rules live in those functions. The settings are
%   preferences, not part of the config.

g = uigridlayout(obj.TabCopy, [6 1]);
g.RowHeight   = {'fit', 'fit', 0, 'fit', '2x', '1x'};   % row 3 is the progress panel, collapsed while idle
g.ColumnWidth = {'1x'};
g.Padding     = [10 10 10 10];
g.RowSpacing  = 8;
obj.CopyGrid = g;

% --- session search ----------------------------------------------------------
top = uigridlayout(g, [4 8]);
top.Layout.Row = 1;
top.RowHeight   = {'fit', 'fit', 'fit', 'fit'};
top.ColumnWidth = {'fit', 170, 'fit', 130, 'fit', 130, 'fit', '1x'};
top.Padding     = [0 0 0 0];

lbl = uilabel(top, "Text", "Subject ID:");
lbl.Layout.Row = 1; lbl.Layout.Column = 1;
obj.CopySubjectField = uieditfield(top, "text", "Placeholder", "e.g. SUBJ-ID-1255", ...
    "Tooltip", "Must match the subject folder and file names exactly.");
obj.CopySubjectField.Layout.Row = 1; obj.CopySubjectField.Layout.Column = 2;
lbl = uilabel(top, "Text", "From:");
lbl.Layout.Row = 1; lbl.Layout.Column = 3;
obj.CopyFromDatePicker = uidatepicker(top, "Value", datetime('today'), "DisplayFormat", "yyyy-MM-dd");
obj.CopyFromDatePicker.Layout.Row = 1; obj.CopyFromDatePicker.Layout.Column = 4;
lbl = uilabel(top, "Text", "To:");
lbl.Layout.Row = 1; lbl.Layout.Column = 5;
obj.CopyToDatePicker = uidatepicker(top, "DisplayFormat", "yyyy-MM-dd", "Placeholder", "same day", ...
    "Tooltip", "Last day of the range (blank = the From day only).");
obj.CopyToDatePicker.Layout.Row = 1; obj.CopyToDatePicker.Layout.Column = 6;
obj.CopyFindButton = uibutton(top, "Text", "Find sessions", "FontWeight", "bold", ...
    "BackgroundColor", [0.15 0.45 0.80], "FontColor", [1 1 1], ...
    "Tooltip", "List and pair the subject's ePsych files and Intan folders for these days (by name; reads only headers).", ...
    "ButtonPushedFcn", @(~,~) obj.onCopyFind());
obj.CopyFindButton.Layout.Row = 1; obj.CopyFindButton.Layout.Column = 7;

roots = {"ePsych root:", "CopyEpsychRootField", "Source folder holding one folder of ePsych .mat files per subject."
         "Intan root:",  "CopyIntanRootField",  "Source folder holding one folder of Intan recording folders per subject."
         "Destination:", "CopyDestRootField",   "Local root; each session is copied to <root>/<subject>/<Intan folder name>."};
for k = 1:3
    lbl = uilabel(top, "Text", roots{k, 1}, "Tooltip", roots{k, 3});
    lbl.Layout.Row = k + 1; lbl.Layout.Column = 1;
    f = uieditfield(top, "text", "Tooltip", roots{k, 3});
    f.Layout.Row = k + 1; f.Layout.Column = [2 6];
    obj.(roots{k, 2}) = f;
    b = uibutton(top, "Text", "Browse...", "ButtonPushedFcn", @(~,~) obj.onBrowseCopyFolder(f));
    b.Layout.Row = k + 1; b.Layout.Column = 7;
end
obj.CopyEpsychRootField.Value = 'S:/RIG3_Backup_2025/epsych_files/Data';
obj.CopyIntanRootField.Value  = 'S:/RIG3_Backup_2025/intan_files/Data';
obj.CopyDestRootField.Value   = 'D:/EPHYS';

% --- pairing and copy options + actions --------------------------------------------
bar = uigridlayout(g, [3 15]);
bar.Layout.Row = 2;
bar.RowHeight   = {'fit', 'fit', 'fit'};
bar.ColumnWidth = {'fit', 50, 'fit', 50, 'fit', 50, 'fit', 50, 'fit', 70, 'fit', 70, '1x', 'fit', 'fit'};
bar.Padding     = [0 0 0 0];

lbl = uilabel(bar, "Text", "Max lead (min):", "Tooltip", "How long the ePsych file may start before the Intan recording.");
lbl.Layout.Row = 1; lbl.Layout.Column = 1;
obj.CopyMaxLeadField = uieditfield(bar, "numeric", "Value", 10, "Limits", [0 Inf], "Tooltip", lbl.Tooltip);
obj.CopyMaxLeadField.Layout.Row = 1; obj.CopyMaxLeadField.Layout.Column = 2;
lbl = uilabel(bar, "Text", "Max lag (min):", "Tooltip", "How long the ePsych file may start after the Intan recording (clock skew).");
lbl.Layout.Row = 1; lbl.Layout.Column = 3;
obj.CopyMaxLagField = uieditfield(bar, "numeric", "Value", 2, "Limits", [0 Inf], "Tooltip", lbl.Tooltip);
obj.CopyMaxLagField.Layout.Row = 1; obj.CopyMaxLagField.Layout.Column = 4;
lbl = uilabel(bar, "Text", "Ambiguity margin (s):", "Tooltip", ...
    "Candidates whose time differences are closer than this make the pairing ambiguous; ambiguous rows are never copied.");
lbl.Layout.Row = 1; lbl.Layout.Column = 5;
obj.CopyMarginField = uieditfield(bar, "numeric", "Value", 30, "Limits", [0 Inf], "Tooltip", lbl.Tooltip);
obj.CopyMarginField.Layout.Row = 1; obj.CopyMarginField.Layout.Column = 6;
lbl = uilabel(bar, "Text", "Min duration (min):", "Tooltip", ...
    "Intan recordings shorter than this are never paired (listed as Intan only); 0 pairs every recording.");
lbl.Layout.Row = 1; lbl.Layout.Column = 7;
obj.CopyMinDurationField = uieditfield(bar, "numeric", "Value", 2, "Limits", [0 Inf], "Tooltip", lbl.Tooltip);
obj.CopyMinDurationField.Layout.Row = 1; obj.CopyMinDurationField.Layout.Column = 8;
lbl = uilabel(bar, "Text", "Verify:", "Tooltip", "After copying: compare file sizes, or sizes and SHA-256 (reads every file twice).");
lbl.Layout.Row = 1; lbl.Layout.Column = 9;
obj.CopyVerifyDropDown = uidropdown(bar, "Items", ["size", "hash"], "Value", "size", "Tooltip", lbl.Tooltip);
obj.CopyVerifyDropDown.Layout.Row = 1; obj.CopyVerifyDropDown.Layout.Column = 10;
lbl = uilabel(bar, "Text", "If it exists:", "Tooltip", ...
    "When a destination folder already holds some of the session: resume completes the partial copy (only the files that are missing or differ are written), " + ...
    "skip leaves the folder alone, error reports it as failed. A file that is not in the source is never touched.");
lbl.Layout.Row = 1; lbl.Layout.Column = 11;
obj.CopyIfExistsDropDown = uidropdown(bar, "Items", ["resume", "skip", "error"], "Value", "resume", "Tooltip", lbl.Tooltip);
obj.CopyIfExistsDropDown.Layout.Row = 1; obj.CopyIfExistsDropDown.Layout.Column = 12;
obj.CopyPreviewButton = uibutton(bar, "Text", "Preview (dry run)", ...
    "Tooltip", "Check the ticked sessions and report what a copy would do; writes nothing.", ...
    "ButtonPushedFcn", @(~,~) obj.onCopyRun(true));
obj.CopyPreviewButton.Layout.Row = 1; obj.CopyPreviewButton.Layout.Column = 14;
obj.CopyRunButton = uibutton(bar, "Text", "Copy selected", "FontWeight", "bold", ...
    "Tooltip", "Copy the ticked sessions in the background, verify them and write session_manifest.json in each. " + ...
    "The app stays usable while they copy; this button becomes Cancel copy.", ...
    "ButtonPushedFcn", @(~,~) obj.onCopyRun(false));
obj.CopyRunButton.Layout.Row = 1; obj.CopyRunButton.Layout.Column = 15;

obj.CopySummaryLabel = uilabel(bar, "Text", "Enter a subject and dates, then Find sessions.", "FontColor", [0.4 0.4 0.4]);
obj.CopySummaryLabel.Layout.Row = 2; obj.CopySummaryLabel.Layout.Column = [1 12];
obj.CopyScanAfterCheckBox = uicheckbox(bar, "Text", "After copying, open the copied sessions as the project", "Value", true, ...
    "Tooltip", "Set the Project root to the folder holding the copied sessions and Scan it.");
obj.CopyScanAfterCheckBox.Layout.Row = 2; obj.CopyScanAfterCheckBox.Layout.Column = [13 15];
buildProgressPanel(obj, g);

% --- stitching ------------------------------------------------------------------------
st = uigridlayout(g, [1 3]);
st.Layout.Row = 4;
st.RowHeight   = {'fit'};
st.ColumnWidth = {'fit', 'fit', '1x'};
st.Padding     = [0 0 0 0];
obj.CopyStitchButton = uibutton(st, "Text", "Stitch selected rows", ...
    "Tooltip", "Merge the selected rows (one Intan folder and its ePsych files) into one session; copying joins the ePsych files, in chronological order, into one file.", ...
    "ButtonPushedFcn", @(~,~) obj.onCopyStitch());
obj.CopyUnstitchButton = uibutton(st, "Text", "Unstitch", ...
    "Tooltip", "Put the selected stitched rows back as Find sessions paired them.", ...
    "ButtonPushedFcn", @(~,~) obj.onCopyUnstitch());
uilabel(st, "FontColor", [0.4 0.4 0.4], "Text", ...
    "To stitch ePsych files: select the Intan folder's row and the rows of its ePsych files (Ctrl-click), then Stitch.");

% --- sessions table ------------------------------------------------------------------
obj.CopyTable = uitable(g, "RowName", {}, "ColumnSortable", false, ...
    "SelectionType", "row", "Multiselect", "on", ...
    "CellEditCallback", @(~, evt) obj.onCopyTableEdited(evt));
obj.CopyTable.Layout.Row = 5;

% --- log -------------------------------------------------------------------------------
obj.CopyLogArea = uitextarea(g, "Editable", "off", "FontName", "Consolas", "Value", {''});
obj.CopyLogArea.Layout.Row = 6;

obj.refreshCopyTable();
end


function buildProgressPanel(obj, g)
%buildProgressPanel  Where a background copy says how far it has got.
%   A percentage on its own says little about a batch that takes an hour, and
%   the Copy tab has the width to say more: a bar, what the engine is doing to
%   which session, how much of the batch has moved, how fast and how long is
%   left. The panel is only shown while a copy is running (setCopyRunning
%   opens and closes row 3 of the tab).
p = uipanel(g, "BorderType", "line", "BackgroundColor", [0.97 0.98 1.00], ...
    "Title", "", "Visible", "off");
p.Layout.Row = 3;
obj.CopyProgressPanel = p;

pg = uigridlayout(p, [3 2]);
pg.RowHeight   = {'fit', 22, 'fit'};
pg.ColumnWidth = {'1x', 'fit'};
pg.Padding     = [10 8 10 8];
pg.RowSpacing  = 4;

obj.CopyProgressHeadline = uilabel(pg, "Text", "", "FontWeight", "bold", "FontSize", 13);
obj.CopyProgressHeadline.Layout.Row = 1; obj.CopyProgressHeadline.Layout.Column = 1;
obj.CopyPercentLabel = uilabel(pg, "Text", "0%", "FontWeight", "bold", "FontSize", 18, ...
    "FontColor", [0.15 0.45 0.80], "HorizontalAlignment", "right");
obj.CopyPercentLabel.Layout.Row = 1; obj.CopyPercentLabel.Layout.Column = 2;

% The bar is two panels in a grid: their column weights are the percentage, so
% showing progress is one property set and no graphics object is redrawn.
track = uigridlayout(pg, [1 2]);
track.Layout.Row = 2; track.Layout.Column = [1 2];
track.ColumnWidth = {0.0001, '1x'};
track.RowHeight   = {'1x'};
track.Padding     = [0 0 0 0];
track.ColumnSpacing = 0;
obj.CopyProgressTrack = track;
obj.CopyProgressFill = uipanel(track, "BorderType", "none", "BackgroundColor", [0.15 0.45 0.80]);
obj.CopyProgressFill.Layout.Row = 1; obj.CopyProgressFill.Layout.Column = 1;
obj.CopyProgressRest = uipanel(track, "BorderType", "none", "BackgroundColor", [0.88 0.90 0.93]);
obj.CopyProgressRest.Layout.Row = 1; obj.CopyProgressRest.Layout.Column = 2;

obj.CopyProgressLabel = uilabel(pg, "Text", "", "FontColor", [0.30 0.30 0.30], ...
    "Tooltip", "The file the copy engine is working on now.");
obj.CopyProgressLabel.Layout.Row = 3; obj.CopyProgressLabel.Layout.Column = 1;

obj.CopyProgressETA = uilabel(pg, "Text", "", "FontColor", [0.35 0.35 0.35], ...
    "HorizontalAlignment", "right", ...
    "Tooltip", "Measured from what has been copied so far, so it settles as the copy runs.");
obj.CopyProgressETA.Layout.Row = 3; obj.CopyProgressETA.Layout.Column = 2;
end
