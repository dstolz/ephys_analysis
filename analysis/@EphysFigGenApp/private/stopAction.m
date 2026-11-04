function stopAction(obj, title, message, opts)
%stopAction  An action cannot go on: the status bar says so, an alert says what to do, and the tab that fixes it shows.
%   stopAction(OBJ, TITLE, MESSAGE) puts MESSAGE in the status bar (whose
%   tooltip holds all of it) and in an alert titled TITLE
%   (AppDialog.alert: the tests read it with AppDialog.captured).
%   Tab=T shows tab T (selectTab) and Control=C gives C the keyboard focus,
%   so the person lands where the fix is. While the app starts (the
%   window is hidden behind AppSplash) the alert is held back until it
%   shows, and no tab is switched. NoAlert=true skips the alert (the
%   status bar and the tab only).
%
%   Text for the failures that carry an MException is AppDialog.failure's:
%   pass its result as MESSAGE.
%
%   See also AppDialog, onScan, onPlan, onRunExport.
arguments
    obj
    title (1,1) string
    message (1,1) string
    opts.Tab = []
    opts.Control = []
    opts.Status (1,1) string = ""
    opts.NoAlert (1,1) logical = false
    opts.Icon (1,1) string = "warning"
end
starting = obj.Splash.isActive();
status = opts.Status;
if status == ""
    status = strjoin(strtrim(splitlines(message)), " ");
end
obj.setStatus(status);
if ~starting && ~isempty(opts.Tab) && obj.Tabs.SelectedTab ~= opts.Tab
    obj.selectTab(opts.Tab);
    obj.setStatus(status);   % the tab's own hint (onTabChanged) must not hide it
end
if ~starting && ~isempty(opts.Control)
    try focus(opts.Control); catch; end
end
if opts.NoAlert; return; end
if starting
    obj.Splash.alert(obj.Fig, message, title, "Icon", opts.Icon);
else
    AppDialog.alert(obj.Fig, message, title, "Icon", opts.Icon);
end
end
