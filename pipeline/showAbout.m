function msg = showAbout(fig, appName, details)
%showAbout  The Help menu's About dialog: which version of the code is running.
%   showAbout(FIG, APPNAME) opens a dialog on the app window FIG giving
%   APPNAME, the version and git checkout (ephysVersion), the repository
%   folder and the MATLAB release. "Copy" puts the same text on the
%   clipboard, for pasting into a message or an issue.
%
%   showAbout(FIG, APPNAME, DETAILS) adds the lines of the string array
%   DETAILS (what is particular to that app) after the MATLAB release.
%
%   MSG = showAbout(...) also returns the text shown.
arguments
    fig (1,1) matlab.ui.Figure
    appName (1,1) string
    details (:,1) string = string.empty(0, 1)
end

v = ephysVersion();
lines = [appName; ""; "Version: " + v.Text];
if v.Commit == ""; lines = [lines; "Commit: unknown (not a git checkout)"]; end
lines = [lines; "Folder: " + v.Folder; "MATLAB: " + string(version)];
if ~isempty(details); lines = [lines; ""; details]; end
lines = [lines; ""; "https://github.com/dstolz/ephys_analysis"];
msg = join(lines, newline);

uiconfirm(fig, msg, "About " + appName, "Icon", "info", ...
    "Options", ["OK" "Copy"], "DefaultOption", "OK", "CancelOption", "OK", ...
    "CloseFcn", @(~, evt) copyIfAsked(evt, msg));
end


function copyIfAsked(evt, msg)
if evt.SelectedOption == "Copy"; clipboard('copy', msg); end
end
