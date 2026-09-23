function buildCopyTab(obj)
%buildCopyTab  Copy tab: find one subject's sessions on the source, pair each
%   recording (Intan RHX folder or Open Ephys GUI session) with its ePsych
%   file by the times in their names
%   (findCopySessions), and copy the ticked sessions to local session folders
%   (copySessions). Rows picked by hand can be stitched into one recording
%   with several ePsych files (stitchCopySessions). The Scheduled copy panel
%   sets up a Windows task that copies new sessions at an interval without
%   MATLAB open (CopySchedule). The app only collects the settings, shows the
%   pairing and passes the ticked rows on; the pairing, stitching, copy and
%   schedule rules live in those functions. The settings are preferences, not
%   part of the config; the schedule keeps its own settings file.

g = uigridlayout(obj.TabCopy, [7 1]);
g.RowHeight   = {'fit', 'fit', 0, 'fit', 'fit', '2x', '1x'};   % row 3 is the progress panel, collapsed while idle
g.ColumnWidth = {'1x'};
g.Padding     = [10 10 10 10];
g.RowSpacing  = 8;
obj.CopyGrid = g;

% --- session search ----------------------------------------------------------
top = uigridlayout(g, [4 8]);
top.Layout.Row = 1;
top.RowHeight   = {30, 'fit', 'fit', 'fit'};
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
obj.CopyFindButton = uibutton(top, "Text", "Find sessions", ...
    "Tooltip", "List and pair the subject's ePsych files and recording folders for these days (by name; reads only headers).", ...
    "ButtonPushedFcn", @(~,~) obj.onCopyFind());
obj.CopyFindButton.Layout.Row = 1; obj.CopyFindButton.Layout.Column = 7;

roots = {"ePsych root:", "CopyEpsychRootField", "Source folder holding one folder of ePsych .mat files per subject."
         "Recording roots:", "CopyRecordingRootsField", ...
            "Source folders holding one folder of recordings per subject: Intan RHX folders <subject>_yyMMdd_HHmmss " + ...
            "and Open Ephys GUI sessions <subject>_yyyy-MM-dd_HH-mm-ss. Separate several roots with "";""; Browse adds one."
         "Destination:", "CopyDestRootField",   "Local root; each session is copied to <root>/<subject>/<recording folder name>."};
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
obj.CopyRecordingRootsField.Value = 'S:/RIG3_Backup_2025/intan_files/Data';
obj.CopyDestRootField.Value   = 'D:/EPHYS';

% --- pairing and copy options + actions --------------------------------------------
bar = uigridlayout(g, [3 15]);
bar.Layout.Row = 2;
bar.RowHeight   = {30, 'fit', 'fit'};
bar.ColumnWidth = {'fit', 50, 'fit', 50, 'fit', 50, 'fit', 50, 'fit', 70, 'fit', 70, '1x', 'fit', 'fit'};
bar.Padding     = [0 0 0 0];

lbl = uilabel(bar, "Text", "Max lead (min):", "Tooltip", "How long the ePsych file may start before the recording.");
lbl.Layout.Row = 1; lbl.Layout.Column = 1;
obj.CopyMaxLeadField = uieditfield(bar, "numeric", "Value", 10, "Limits", [0 Inf], "Tooltip", lbl.Tooltip);
obj.CopyMaxLeadField.Layout.Row = 1; obj.CopyMaxLeadField.Layout.Column = 2;
lbl = uilabel(bar, "Text", "Max lag (min):", "Tooltip", "How long the ePsych file may start after the recording (clock skew).");
lbl.Layout.Row = 1; lbl.Layout.Column = 3;
obj.CopyMaxLagField = uieditfield(bar, "numeric", "Value", 2, "Limits", [0 Inf], "Tooltip", lbl.Tooltip);
obj.CopyMaxLagField.Layout.Row = 1; obj.CopyMaxLagField.Layout.Column = 4;
lbl = uilabel(bar, "Text", "Ambiguity margin (s):", "Tooltip", ...
    "Candidates whose time differences are closer than this make the pairing ambiguous; ambiguous rows are never copied.");
lbl.Layout.Row = 1; lbl.Layout.Column = 5;
obj.CopyMarginField = uieditfield(bar, "numeric", "Value", 30, "Limits", [0 Inf], "Tooltip", lbl.Tooltip);
obj.CopyMarginField.Layout.Row = 1; obj.CopyMarginField.Layout.Column = 6;
lbl = uilabel(bar, "Text", "Min duration (min):", "Tooltip", ...
    "Recordings shorter than this (from their headers) are never paired (listed as recording only); 0 pairs every recording.");
lbl.Layout.Row = 1; lbl.Layout.Column = 7;
obj.CopyMinDurationField = uieditfield(bar, "numeric", "Value", 2, "Limits", [0 Inf], "Tooltip", lbl.Tooltip);
obj.CopyMinDurationField.Layout.Row = 1; obj.CopyMinDurationField.Layout.Column = 8;
lbl = uilabel(bar, "Text", "Verify:", "Tooltip", "After copying: compare each file's size and modified time with its source's, " + ...
    "or also its SHA-256 (reads every file twice more; not again for a session whose manifest already records them).");
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
obj.CopyRunButton = uibutton(bar, "Text", "Copy selected", ...
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
buildSchedulePanel(obj, g);

% --- stitching ------------------------------------------------------------------------
st = uigridlayout(g, [1 3]);
st.Layout.Row = 5;
st.RowHeight   = {30};
st.ColumnWidth = {'fit', 'fit', '1x'};
st.Padding     = [0 0 0 0];
obj.CopyStitchButton = uibutton(st, "Text", "Stitch selected rows", ...
    "Tooltip", "Merge the selected rows (one recording folder and its ePsych files) into one session; copying joins the ePsych files, in chronological order, into one file.", ...
    "ButtonPushedFcn", @(~,~) obj.onCopyStitch());
obj.CopyUnstitchButton = uibutton(st, "Text", "Unstitch", ...
    "Tooltip", "Put the selected stitched rows back as Find sessions paired them.", ...
    "ButtonPushedFcn", @(~,~) obj.onCopyUnstitch());
uilabel(st, "FontColor", [0.4 0.4 0.4], "Text", ...
    "To stitch ePsych files: select the recording folder's row and the rows of its ePsych files (Ctrl-click), then Stitch.");

% --- sessions table ------------------------------------------------------------------
obj.CopyTable = uitable(g, "RowName", {}, "ColumnSortable", false, ...
    "SelectionType", "row", "Multiselect", "on", ...
    "CellEditCallback", @(~, evt) obj.onCopyTableEdited(evt));
obj.CopyTable.Layout.Row = 6;

% --- log -------------------------------------------------------------------------------
obj.CopyLogArea = uitextarea(g, "Editable", "off", "FontName", "Consolas", "Value", {''});
obj.CopyLogArea.Layout.Row = 7;

obj.refreshCopyTable();
end


function buildSchedulePanel(obj, g)
%buildSchedulePanel  The scheduled copy: its own settings, its buttons and its state.
%   A schedule copies with the roots, destination, pairing and copy options
%   above, as they are when it is saved, so only what is its own is here:
%   the subjects, how often, how many days back, how long a session must
%   have been quiet, and whether it also runs while signed out.
%   refreshCopySchedule shows its state on the second row.
p = uipanel(g, "Title", "Scheduled copy: copies new sessions in the background through Windows Task Scheduler (MATLAB need not be open)", ...
    "FontWeight", "bold");
p.Layout.Row = 4;
sg = uigridlayout(p, [2 12]);
sg.RowHeight   = {30, 'fit'};
sg.ColumnWidth = {'fit', '1x', 'fit', 55, 'fit', 50, 'fit', 50, 'fit', 250, 'fit', 'fit'};
sg.Padding     = [8 6 8 6];
sg.RowSpacing  = 6;

tip = "Subject IDs to copy, separated by spaces or commas; each is searched as Find sessions searches it. Blank: the Subject ID above.";
lbl = uilabel(sg, "Text", "Subjects:", "Tooltip", tip);
lbl.Layout.Row = 1; lbl.Layout.Column = 1;
obj.CopyScheduleSubjectsField = uieditfield(sg, "text", "Tooltip", tip, ...
    "Placeholder", "e.g. SUBJ-ID-1255 SUBJ-ID-1256 (blank: the Subject ID above)");
obj.CopyScheduleSubjectsField.Layout.Row = 1; obj.CopyScheduleSubjectsField.Layout.Column = 2;

fields = {
    "Every (min):", "CopyScheduleEveryField", 60, [5 1440], ...
        "How often Windows starts a copy (5 to 1440 min). Runs are on the clock: every 60 min is on the hour."
    "Days back:", "CopyScheduleDaysField", 3, [1 366], ...
        "Each run looks for the sessions of this many days, ending today (1: today only). Sessions already copied (their session_manifest.json says so, " + ...
        "or Clean up removed files from them) are left alone; a run never copies files back."
    "Quiet (min):", "CopyScheduleQuietField", 15, [0 1440], ...
        "A session whose source changed within this many minutes is left for a later run, so a recording that is still being written, or synced to the source, is never copied half way."};
for k = 1:size(fields, 1)
    lbl = uilabel(sg, "Text", fields{k, 1}, "Tooltip", fields{k, 5});
    lbl.Layout.Row = 1; lbl.Layout.Column = 2 * k + 1;
    f = uieditfield(sg, "numeric", "Value", fields{k, 3}, "Limits", fields{k, 4}, ...
        "RoundFractionalValues", k < 3, "Tooltip", fields{k, 5});
    f.Layout.Row = 1; f.Layout.Column = 2 * k + 2;
    obj.(fields{k, 2}) = f;
end

tip = "While I am signed in: runs whenever you are signed in to Windows, with the screen locked too. " + ...
    "Even when I am signed out: also after a restart or sign-out; Windows asks for your password once, " + ...
    "in a window of its own, and keeps it with the task (some accounts are not allowed this).";
lbl = uilabel(sg, "Text", "Run:", "Tooltip", tip);
lbl.Layout.Row = 1; lbl.Layout.Column = 9;
obj.CopyScheduleRunWhenDropDown = uidropdown(sg, "Tooltip", tip, ...
    "Items", ["while I am signed in", "even when I am signed out (asks for my password)"], ...
    "ItemsData", ["signed_in", "always"], "Value", "signed_in");
obj.CopyScheduleRunWhenDropDown.Layout.Row = 1; obj.CopyScheduleRunWhenDropDown.Layout.Column = 10;

obj.CopyScheduleSaveButton = uibutton(sg, "Text", "Save schedule", ...
    "Tooltip", "Save these settings with the roots, destination, pairing and copy options above, and create (or replace) the Windows task. Paired sessions are copied; ambiguous, unpaired and to-be-stitched ones are left for you.", ...
    "ButtonPushedFcn", @(~,~) obj.onCopyScheduleSave());
obj.CopyScheduleSaveButton.Layout.Row = 1; obj.CopyScheduleSaveButton.Layout.Column = 11;
obj.CopyScheduleRemoveButton = uibutton(sg, "Text", "Remove", ...
    "Tooltip", "Delete the Windows task. Copies already made are kept, and so is the log.", ...
    "ButtonPushedFcn", @(~,~) obj.onCopyScheduleRemove());
obj.CopyScheduleRemoveButton.Layout.Row = 1; obj.CopyScheduleRemoveButton.Layout.Column = 12;

obj.CopyScheduleStatusLabel = uilabel(sg, "Text", "Not scheduled.", "WordWrap", "on", ...
    "FontColor", [0.35 0.35 0.35]);
obj.CopyScheduleStatusLabel.Layout.Row = 2; obj.CopyScheduleStatusLabel.Layout.Column = [1 10];
obj.CopyScheduleRunNowButton = uibutton(sg, "Text", "Run now", "Enable", "off", ...
    "Tooltip", "Start a scheduled run now, in the background, as Windows would.", ...
    "ButtonPushedFcn", @(~,~) obj.onCopyScheduleRunNow());
obj.CopyScheduleRunNowButton.Layout.Row = 2; obj.CopyScheduleRunNowButton.Layout.Column = 11;
obj.CopyScheduleLogButton = uibutton(sg, "Text", "Open log", "Enable", "off", ...
    "Tooltip", "Open the scheduled copy's log: every run, every session.", ...
    "ButtonPushedFcn", @(~,~) obj.onCopyScheduleLog());
obj.CopyScheduleLogButton.Layout.Row = 2; obj.CopyScheduleLogButton.Layout.Column = 12;
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
