function test_EphysAnalysisApp()
%test_EphysAnalysisApp  Headless checks of the analysis GUI over a synthetic project.
%   Builds the app on a small synthetic project run through the pipeline
%   and drives it through its own methods: the tabs; the toolbar (its
%   tools, icons and shortcut tooltips; Preview and Plan from another tab;
%   its run and results tools following the Export tab's buttons); Scan
%   filling the datasets table; the active dataset's lines and parameters; grouping by
%   Depth from the Alignment controls (the epoch count reports the groups);
%   adding a PSTH and previewing it into the preview panel; the plot designs
%   (the Design list and menu, choosing one redrawing the preview, saving
%   the preview's look as a design and deleting it); editing the plot
%   (bins; an edit in a "Use default" section giving the plot its own event
%   reference or window, ticking it again going back); the editor showing
%   only the rows and sections a plot uses (y limits, heat colors, the
%   alignment sections), graying out the ones its options switch off, and
%   collapsing a section; the section headers' colors and keys (Ctrl+1 to
%   Ctrl+9 and Ctrl+0 going to a section; Aux signals has none); the Aux
%   signals rows of a PSTH (shown for spikes only, grayed out while Off, an
%   edit reaching the plot and the preview); the error rows (type, band
%   fill and edge reaching the style and the preview's bands, enabled with
%   the Error box); the epoch diagram (opened from the plot editor
%   with the plot's own epochs, redrawn on an edit of pre, epochs dropped
%   outside the recording, a refused window reported, paging, opened from
%   the Alignment tab for the defaults, closing with the app); a raster's
%   sort (by a trial parameter, or by a sort event's latency: its rows
%   enabled, its line and edge reaching the plot and the preview),
%   direction, grouping and event marks, an event shifted by a trial parameter, an event sequence and a
%   mark sequence from the Event sequence window (a bad step refused), and
%   a behavior plot reaching the config and the preview; several plots
%   selected at once (Ctrl-click: the first picked in the editor and the
%   preview, the banner and the bar saying so, only the rows they share,
%   an edit, an event edit, Use default and a remembered look reaching
%   each but only as changed; Duplicate and Remove taking them all);
%   the gather / apply round trip, keeping the fields without a control
%   (stop-event offset, length and time range, trial rows); save
%   and reopen; a standalone script from the app's config; a run of one
%   plot writing its figures and report; the Chronux tab (a dataset
%   without a Chronux file, Create writing it into the output folder and
%   showing it, a spectrum over the Alignment tab's epochs per group, Out
%   of date after an edit of what is computed, a display edit redrawing,
%   a spectrogram over the whole recording, Save results and Save
%   figure, the local cache: a file created there and found once the
%   output folder's is gone); the Sessions tab (Add on a base plot, the
%   editor's rows and its gather / apply round trip, a preview over both
%   datasets, Out of date after a base-plot edit, the toolbar's Preview
%   and Help there, Browse for a mapping file, Remove, its preferences
%   restored by a new app); the Figures tab (Add from the template, the
%   schematic, the observation picker and its preview of one unit, < and
%   > and Page Up, a continuous panel added below, an events layer on the
%   raster, the rows a panel type shows, Ctrl+digit to a section, Out of
%   date with Auto off, Cancel, the figure's own event, a panel's own
%   window, a tightened unit filter and one nothing passes, a listing
%   error, a type change, the gather / apply round trip, a remembered look
%   and Forget, another config opened, a row height the spinner's old
%   limits clipped, Remove panel, Duplicate, Add panel above / right /
%   left, spans (and their refusals), sizes and spacing, Move, layer and
%   figure Up / Down, the display across type changes, a scan listing the
%   observations again, the previews refusing each other while one
%   computes, save and reopen, its preferences restored by a new app,
%   Remove);
%   closing. The app's preferences live in a
%   temporary file for the run (AppPrefs.useTemporary), never the user's.
%
%   Usage:  test_EphysAnalysisApp

here = fileparts(mfilename('fullpath'));
repo = fileparts(here);
addpath(here);
addpath(fullfile(repo, 'pipeline'));
addpath(repo);
addpath(genpath(fullfile(repo, 'vendor')));

root = fullfile(tempdir, sprintf('AnaApp_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);
g = EphysAnalysisApp.PrefGroup;
restorePrefs = AppPrefs.useTemporary(); %#ok<NASGU> preferences in a temporary file, never the user's
cleanup = onCleanup(@() removeRoot(root));

nPass = 0; nFail = 0;
    function check(cond, msg)
        if cond
            nPass = nPass + 1;
            fprintf('  PASS: %s\n', msg);
        else
            nFail = nFail + 1;
            fprintf(2, '  FAIL: %s\n', msg);
            LegacySuiteTest.checkFailed(msg);   % one failure per check in run_all_tests' report
        end
    end

fprintf('\n== 0. fixture ==\n');
F = makeAnalysisFixture(string(root), Scenarios=["clean" "late-start"], NumTrials=12);
check(numel(F.names) == 2, 'two datasets run through the pipeline');

fprintf('\n== 1. build, open the project, scan ==\n');
app = EphysAnalysisApp(F.proj);
appCleanup = onCleanup(@() closeApp(app));
check(isvalid(app.Fig) && numel(app.Tabs.Children) == 8 && app.Tabs.Children(1) == app.TabData ...
    && app.Tabs.Children(4) == app.TabFigures && app.Tabs.Children(5) == app.TabSessions ...
    && app.Tabs.Children(7) == app.TabChronux && app.Tabs.Children(8) == app.TabLog, ...
    'the app has the Data, Alignment, Plots, Figures, Sessions, Export, Chronux and Log tabs');
T = app.DatasetsTable.Data;
check(~isempty(app.Runner) && height(T) == 2 && all(T.Run) && isequal(sort(T.Name), sort(F.names(:))) ...
    && all(T.LFP == "✓") && all(T.Behavior == "✓"), 'the project root was scanned: both datasets, ticked, with LFP and behavior');
check(app.Config.Source.Mode == "project" && app.Config.Source.Root == F.proj && ~startsWith(app.Fig.Name, "*"), ...
    'a new config for the project, clean');
check(all(ismember(["Subject" "Date" "Idx"], string(T.Properties.VariableNames))) && all(T.Subject ~= "") ...
    && all(~cellfun(@isempty, regexp(cellstr(T.Date), '^\d{4}-\d{2}-\d{2}$', 'once'))) && isequal(T.Idx, (1:2).') ...
    && app.DatasetsTable.ColumnSortable(1), 'the datasets table has Subject and Date, a hidden Idx, and sorts on a header click');
app.DatasetsSort = struct('column', "Name", 'direction', "descend");   % as a click on Name leaves it
app.refreshDatasetsTable();
T2 = app.DatasetsTable.Data;
check(isequal(T2.Name, sort(F.names(:), 'descend')) && isequal(T2.Idx, arrayfun(@(n) find(app.Runner.Names == n), T2.Name)), ...
    'a remembered sort orders the rows and each row keeps its dataset''s place in the Runner (Idx)');
app.onDatasetCellSelection(struct('Indices', [1 2]));
check(app.Runner.Names(app.ActiveIdx) == T2.Name(1), 'a click goes to the row''s dataset, whatever the sort');
T2.Run(1) = false;
app.DatasetsTable.Data = T2;
app.onDatasetsTableEdited([]);
check(isequal(app.Ticked, ~(app.Runner.Names == T2.Name(1))), 'a Run tick goes to the row''s dataset, whatever the sort');
T2.Run(1) = true;
app.DatasetsTable.Data = T2;
app.onDatasetsTableEdited([]);
app.clearDatasetsSort();
check(~TableSort.isSorted(app.DatasetsSort) && isequal(app.DatasetsTable.Data.Idx, (1:2).') && all(app.Ticked), ...
    'Clear sort puts the rows back in the scan order');
k = find(app.Runner.Names == F.names(1));
app.selectDataset(k);
check(app.ActiveIdx == k && any(app.LinesTable.Data.Line == "Stim") && any(app.ParamsTable.Data.Parameter == "Depth") ...
    && contains(app.BehaviorLabel.Text, "12 trials") && height(app.UnitsTable.Data) > 0, ...
    'the active dataset shows its lines (Stim), parameters (Depth), trials and units');
gItems = string(app.AlignControls.Group1.Items(2:end));
[~, gOrd] = sort(lower(gItems));
check(any(string(app.AlignControls.Line.Items) == "Stim") && any(gItems == "Depth") && any(gItems == "RespCode") ...
    && isequal(gItems, gItems(gOrd)), 'the Alignment boxes list the lines and every parameter (RespCode too), alphabetically');
key1 = app.Runner.Keys(k);
app1 = EphysAnalysisApp(F.proj, Datasets=key1);
[~, leaf1] = fileparts(key1);
check(app1.Config.Source.Selection == "list" && isequal(app1.Config.Source.Datasets, key1) ...
    && height(app1.DatasetsTable.Data) == 2 && isequal(app1.Ticked, app1.Runner.Keys == key1) ...
    && app1.ActiveIdx >= 1 && app1.Runner.Names(app1.ActiveIdx) == F.names(1) ...
    && app1.Config.Name == string(leaf1) + " quick look" && ~startsWith(app1.Fig.Name, "*"), ...
    ['Datasets= (the pipeline app''s Tools panel) ticks only those datasets of the project to run, ' ...
    'the first one active, and names the config after the one']);
closeApp(app1);

fprintf('\n== 1b. Toolbar: the most used commands ==\n');
tools = flip(app.Toolbar.Children);
tags = string({tools.Tag});
check(isequal(tags, ["new" "open" "save" "scan" "preview" "validate" "plan" "run" "cancel" "report" "figurefolder" "pipelineapp" "help"]) ...
    && isequal(find(logical([tools.Separator])), [4 6 10 12 13]) ...
    && all(isfile(fullfile(here, 'icons', 'toolbar', tags + ".svg"))), ...
    'the toolbar holds the config, look, run, results, app and help commands in groups, each with its icon');
if ismac; modifier = "Cmd+"; else; modifier = "Ctrl+"; end
tips = string({tools.Tooltip});
menuItems = findall(app.Fig, 'Type', 'uimenu');
keyed = menuItems(strlength(string({menuItems.Accelerator})) > 0);
named = erase(string({keyed.Text}), "...") + " (" + modifier + string({keyed.Accelerator}) + ")";
check(numel(keyed) == 3 && all(ismember(named, tips)) && nnz(contains(tips, "(" + modifier)) == numel(keyed) ...
    && all(strlength(tips) > 0), ...
    'every menu shortcut is on the toolbar, named in its tool''s tooltip, and no tooltip names another');
check(app.ToolbarValidateTool.Enable == "on" && app.ToolbarPlanTool.Enable == "on" && app.ToolbarRunTool.Enable == "on" ...
    && app.ToolbarCancelTool.Enable == "off" && app.ToolbarReportTool.Enable == "off" && app.ToolbarFolderTool.Enable == "off", ...
    'before a run: Validate, Plan and Run are on; Cancel, the report and the figure folder off');

fprintf('\n== 1c. Help menu: GitHub issue and feature request ==\n');
items = flip(string({app.HelpMenu.Children.Text}));
check(isequal(items(end-2:end), ["Report an issue on GitHub..." "Request a feature on GitHub..." "About EphysAnalysisApp"]), ...
    'the Help menu ends with the two GitHub issue items and About');
app.log("synthetic log line for the report");
bug = app.issueReport("bug", Description="the preview stops here");
check(contains(bug, "### What happened") && contains(bug, "the preview stops here") ...
    && contains(bug, "### Steps to reproduce") && contains(bug, "<summary>System</summary>") ...
    && contains(bug, "<summary>Analysis config</summary>") && contains(bug, string(F.proj)) ...
    && contains(bug, "2 scanned, 2 ticked") && contains(bug, "<summary>Config JSON</summary>") ...
    && contains(bug, """schema""") && contains(bug, "<summary>Log tab</summary>") ...
    && contains(bug, "synthetic log line for the report") && contains(bug, "Filed from the EphysAnalysisApp"), ...
    'a bug report carries the description, the system, the config and the log tab');
feat = app.issueReport("feature", Description="a button that stitches", System=false, Config=false, Logs=false);
check(contains(feat, "### What would you like to be able to do") && contains(feat, "a button that stitches") ...
    && ~contains(feat, "<details>") && ~contains(feat, "### What happened") && ~contains(feat, string(F.proj)), ...
    'a feature request keeps only what is ticked: no system, config or log');
check(~contains(app.issueReport("bug", System=false, Config=false, Logs=false), "<details>") ...
    && contains(app.issueReport("bug", System=false, Config=false, MaxLogLines=1), "the last 1 of "), ...
    'the log is cut to its last lines and says how many it had');
[url, cut] = app.issueURL("bug", "a title", "line one" + newline + "line two");
check(startsWith(url, app.RepoURL + "/issues/new?") && contains(url, "title=a%20title") ...
    && contains(url, "body=line%20one%0Aline%20two") && contains(url, "labels=bug") ...
    && ~cut && ~contains(url, " ") && ~contains(url, newline), ...
    'the issue address is the prefilled form, percent-encoded');
check(contains(app.issueURL("feature", "t", "b"), "labels=enhancement"), 'a feature request is filed as an enhancement');
[long, cut] = app.issueURL("bug", "t", join(repmat("0123456789", 1, 2000), newline));
check(cut && strlength(long) <= IssueReport.MaxURL && contains(long, "was%20too%20long%20for%20the%20address"), ...
    'a report too long for the address is cut and says so in the body');
app.onReportIssue("feature");
dlg = findall(groot, 'Type', 'figure', 'Name', 'Request a feature');
dlgClean = onCleanup(@() delete(dlg)); %#ok<NASGU>
boxes = findall(dlg, 'Type', 'uicheckbox');
btns = findall(dlg, 'Type', 'uibutton');
area = findall(dlg, 'Type', 'uitextarea', 'Editable', 'off');
check(isscalar(dlg) && isequal(sort(string({boxes.Text})), sort(["System info" "Analysis config" "Log tab"])) ...
    && isequal(sort(string({btns.Text})), sort(["Open on GitHub" "Copy report" "Cancel"])) ...
    && nnz([boxes.Value]) == 1 && string(boxes([boxes.Value]).Text) == "System info" ...
    && contains(strjoin(string(area.Value), newline), "<summary>System</summary>") ...
    && ~contains(strjoin(string(area.Value), newline), "<summary>Analysis config</summary>"), ...
    'the feature dialog starts with only the system info ticked and previews the report');
cfgBox = boxes(string({boxes.Text}) == "Analysis config");
cfgBox.Value = true;
cfgBox.ValueChangedFcn(cfgBox, []);
check(contains(strjoin(string(area.Value), newline), "<summary>Analysis config</summary>"), ...
    'ticking a section puts it in the preview');
delete(dlg);

fprintf('\n== 2. Alignment: group by Depth ==\n');
app.selectTab(app.TabAlign);
app.AlignControls.Line.Value = 'Stim';
app.AlignControls.Group1.Value = 'Depth';
app.onConfigChanged("defaults");
[trials, ~] = readEpsychSession(F.truth(1).behaviorFile);
nG = numel(unique(trials.Depth));
check(app.Config.Defaults.Selection.groupBy == "Depth" && startsWith(app.AlignSummaryLabel.Text, "12 epochs from 12 of 12 trials") ...
    && count(app.AlignSummaryLabel.Text, "Depth = ") == nG, sprintf('the epoch count reports %d Depth groups', nG));
check(height(app.AlignTrialsTable.Data) == 12 && ismember("Group", string(app.AlignTrialsTable.Data.Properties.VariableNames)), ...
    'the kept trials are listed with their group');
check(startsWith(app.Fig.Name, "*"), 'the edit marks the config unsaved');

fprintf('\n== 3. Plots: add, edit, preview ==\n');
app.selectTab(app.TabPlots);
app.onAddPlot("psth");
check(isscalar(app.Config.Plots) && app.SelectedPlot == 1 && app.Config.Plots(1).id == "psth_1" ...
    && string(app.PlotEditor.kind.Text) == "PSTH" && string(app.PlotsTree.Children(1).Children(1).Text) == "psth_1  (units)", ...
    'Add psth makes psth_1 and opens it in the editor, under its plot type in the tree');
app.selectTab(app.TabData);
clickTool(app, "preview");   % as the Preview button, from another tab
axs = findall(app.PreviewPanel, 'Type', 'axes');
check(app.Tabs.SelectedTab == app.TabPlots && ~isempty(axs) && ~isempty(app.PreviewResult) ...
    && app.PreviewResult.kind == "psth" && isfinite(app.PreviewSeconds), ...
    sprintf('the toolbar''s Preview shows the Plots tab and draws %d axes into the preview panel', numel(axs)));
check(app.PreviewState == "drawn" && string(app.PreviewBadge.Text.Text) == "Drawn" ...
    && endsWith(string(app.PreviewBadge.Icon.ImageSource), "drawn.svg") ...
    && isempty(findall(app.PreviewPanel, 'Tag', 'previewBusyCard')) && string(app.Fig.Pointer) == "arrow", ...
    'the badge says Drawn once the preview is drawn; the busy card and the watch pointer are gone');
app.AutoPreviewCheckBox.Value = false;
app.autoPreview();   % as after an edit, with Auto off
stale = app.PreviewState == "stale" && string(app.PreviewBadge.Text.Text) == "Out of date";
app.AutoPreviewCheckBox.Value = true;
app.refreshPreview(Force=true);
check(stale && app.PreviewState == "drawn", 'an edit Auto does not redraw marks the preview Out of date; Preview draws it again');
blue = app.PreviewButton.BackgroundColor;
app.setPreviewState("stale");
orange = app.PreviewButton.BackgroundColor;
app.setPreviewState("drawn");
check(~isequal(orange, blue) && isequal(app.PreviewButton.BackgroundColor, blue) ...
    && app.PreviewButton.Layout.Row(end) - app.PreviewButton.Layout.Row(1) == 1 ...
    && contains(app.PrevPageButton.Tooltip, "Page Up") && contains(app.NextPageButton.Tooltip, "Page Down"), ...
    'the Preview button spans two rows and turns orange while the plot is Out of date; the page buttons name their keys');
pressed = @(k, mods) struct('Key', k, 'Modifier', {mods}, 'Character', '');
app.onKeyPress(pressed('pagedown', {}));
app.onKeyPress(pressed('pageup', {}));
check(app.PreviewPage == 1 && app.PreviewState == "drawn", 'Page Up and Page Down on a single page leave the preview as it is');
tm = timer('ExecutionMode', 'fixedRate', 'Period', 0.005, 'TimerFcn', @(~, ~) app.onCancelPreview());   % a click on the busy card's Cancel
start(tm);
app.refreshPreview(Force=true);
stop(tm); delete(tm);
check(app.PreviewState == "canceled" && string(app.PreviewBadge.Text.Text) == "Canceled" && isempty(app.PreviewResult) ...
    && isempty(findall(app.PreviewPanel, 'Tag', 'previewBusyCard')) && string(app.Fig.Pointer) == "arrow" ...
    && isempty(app.Runner.PollFcn) && ~isfinite(app.PreviewSeconds), ...
    'Cancel on the busy card stops the preview while it computes: the badge says Canceled, the card and the polling are gone');
app.onCancelPreview();   % nothing computes: no effect
app.autoPreview();
check(app.PreviewState == "canceled", 'a canceled preview is not redrawn by an edit; it waits for Preview');
app.refreshPreview(Force=true);
check(app.PreviewState == "drawn" && ~isempty(app.PreviewResult) && ~isempty(findall(app.PreviewPanel, 'Type', 'axes')), ...
    'Preview after a cancel computes and draws the plot');
ctx = getappdata(app.PreviewPanel, PlotAesthetics.ContextKey);
look = struct('role', "rateFill", 'group', "", 'property', "FaceAlpha", 'value', 0.4);
ctx.onRemember(look);
check(isstruct(ctx) && ctx.id == "psth_1" && isscalar(app.Config.Plots(1).aesthetics) ...
    && app.Config.Plots(1).aesthetics.value == 0.4 && isequal(app.Runner.Config.Plots(1).aesthetics, app.Config.Plots(1).aesthetics) ...
    && startsWith(app.Fig.Name, "*"), ...
    'the preview is editable (right-click), and rules remembered for the plot go into the config');
app.rememberAesthetics("psth_1", []);
designs = PlotDesign.list();
check(numel(app.DesignDropDown.Items) == height(designs) && string(app.DesignDropDown.Value) == "Default" ...
    && any(string({app.DesignMenu.Children.Text}) == "Tufte"), 'the Design list and menu offer every design, Default chosen');
cfg0 = app.Config.toStruct();
app.onDesignChosen("Night");
night = PlotDesign.load("Night");
menuChecked = string({app.DesignMenu.Children(strcmp({app.DesignMenu.Children.Checked}, 'on')).Text});
check(isequal(app.PreviewPanel.BackgroundColor, night.background) && string(app.DesignDropDown.Value) == "Night" ...
    && isequal(menuChecked, "Night") && isequaln(app.Config.toStruct(), cfg0), ...
    sprintf('choosing a design redraws the preview in it at once and ticks it, without touching the config (ground %s, list %s, menu %s)', ...
    mat2str(app.PreviewPanel.BackgroundColor, 3), string(app.DesignDropDown.Value), strjoin(menuChecked, "|")));
app.onSaveDesign("Lab look", "for lab meeting");
mine = PlotDesign.list();
k = find(mine.Name == "Lab look");
check(isscalar(k) && mine.Source(k) == "mine" && PlotDesign.currentName() == "Lab look" ...
    && string(app.DesignDropDown.Value) == "Lab look" && isequal(app.PreviewPanel.BackgroundColor, night.background), ...
    'Save look as design keeps the preview''s look as a design of yours and chooses it');
app.onDeleteDesign("Lab look", Confirm=false);
check(~any(PlotDesign.list().Name == "Lab look") && string(app.DesignDropDown.Value) == "Default" ...
    && isequal(app.PreviewPanel.BackgroundColor, [1 1 1]), 'deleting the chosen design goes back to Default');
if isfolder(PlotDesign.folder()); rmdir(PlotDesign.folder(), 's'); end
E = app.PlotEditor;
A = app.PlotAlignControls;
check(E.defaultRef.Value && E.defaultWindow.Value && A.Line.Enable == "on" && A.Pre.Enable == "on" ...
    && A.Filter.Enable == "on" && shown(A.Line) && shown(A.Pre) && shown(A.Filter), ...
    'the event, window and selection sections are shown and editable while they use the defaults');
E.binMs.Value = 20;
app.onConfigChanged("plot");
A.Line.Value = 'Trial';
app.onPlotAlignEdited("ref");
p = app.Config.Plots(1);
check(p.bins.BinSec == 0.02 && isstruct(p.ref) && p.ref.line == "Trial" && ~E.defaultRef.Value ...
    && isequal(p.window, "default") && E.defaultWindow.Value && app.Config.Defaults.EventRef.line == "Stim", ...
    'editing the bins; editing the event line gives the plot its own event reference; the window stays default');
A.Pre.Value = -0.35;
app.onPlotAlignEdited("window");
p = app.Config.Plots(1);
check(isstruct(p.window) && p.window.pre == -0.35 && ~E.defaultWindow.Value && app.Config.Defaults.Window.pre ~= -0.35, ...
    'editing the window''s pre gives the plot its own window; the Alignment tab''s is unchanged');
E.defaultWindow.Value = true;
app.onPlotDefaultToggled();
p = app.Config.Plots(1);
check(isequal(p.window, "default") && A.Pre.Value == app.Config.Defaults.Window.pre && isstruct(p.ref), ...
    'ticking Use default again goes back to (and shows) the default window');
check(shown(E.response) && shown(E.respFrom) && shown(E.respParam) && E.respTest.Enable == "off" && E.respFrom.Enable == "off", ...
    'a spike plot shows the response test, its settings off until Responsive only is ticked');
E.response.Value = true;
E.respTest.Value = 'either'; E.respParam.Value = 'Depth'; E.respTo.Value = 0.1; E.respCorrection.Value = 'holm';
app.onConfigChanged("plot");
rs = app.Config.Plots(1).units.response;
on = E.respTest.Enable == "on" && E.respAlpha.Enable == "on";
E.response.Value = false;
app.onConfigChanged("plot");
check(rs.enabled && rs.test == "either" && rs.param == "Depth" && isequal(rs.window, [0 0.1]) && rs.correction == "holm" ...
    && on && ~app.Config.Plots(1).units.response.enabled && app.Config.Plots(1).units.response.param == "Depth", ...
    'Responsive only and its settings reach the plot''s units.response; unticking keeps the settings');
check(shown(E.stack) && shown(E.normalize) && shown(E.fill) && shown(E.fillAlpha) && shown(E.colormap) ...
    && E.fillAlpha.Enable == "on" && E.stackSpacing.Enable == "off" && ~shown(E.heatColormap) && ~shown(E.param) ...
    && ~shown(E.value) && ~shown(E.metric) && string(A.Mode.ItemsData) == "fixed", ...
    ['a PSTH shows stack, normalize, fill, opacity and group colors (spacing waits for Stack), not heat colors ' ...
    'or other kinds'' rows; its window is fixed']);
E.legendLoc.Value = 'east'; E.legendOrient.Value = 'horizontal'; E.legendBox.Value = true;
app.onConfigChanged("plot");
st = app.Config.Plots(1).style;
check(shown(E.legendLoc) && shown(E.legendOrient) && shown(E.legendBox) && E.legendLoc.Enable == "on" ...
    && st.LegendLocation == "east" && st.LegendOrientation == "horizontal" && st.LegendBox, ...
    'a PSTH offers the legend''s place, orientation and box; they reach the plot''s style');
E.legendLoc.Value = 'auto'; E.legendOrient.Value = 'auto'; E.legendBox.Value = false;
app.onConfigChanged("plot");
E.stack.Value = true; E.normalize.Value = 'groupPeak'; E.fill.Value = false; E.stackSpacing.Value = 0.8;
E.colormap.Value = 'black'; E.lineWidth.Value = 2;
app.onConfigChanged("plot");
p = app.Config.Plots(1);
check(p.stack && p.normalize == "groupPeak" && ~p.fill && isnan(p.fillAlpha) && p.stackSpacing == 0.8 ...
    && p.style.Colormap == "black" && p.style.LineWidth == 2 && E.stackSpacing.Enable == "on" && E.fillAlpha.Enable == "off" ...
    && E.ylim.Enable == "off" && E.legend.Enable == "off" && E.legendLoc.Enable == "off", ...
    'stack, group-peak normalization, unfilled, spacing 0.8, black, width 2 reach the plot; spacing on, opacity / y limits / legend off');
app.refreshPreview(Force=true);
axs = findall(app.PreviewPanel, 'Type', 'axes');
check(any(arrayfun(@(a) numel(a.YAxis) == 2, axs)) == (nG > 1), 'the preview draws the stack (value and peak axes)');
app.onAddPlot("evoked");
check(app.SelectedPlot == 2 && string(E.source.Value) == "LFP" && ~any(string(E.source.Items) == "units") ...
    && ~shown(E.binMs) && ~shown(E.withRaster) && ~shown(E.stack) && ~shown(E.fill) && ~shown(E.classes.su) && ~shown(E.ids) ...
    && shown(E.channels) && shown(E.baselineMode) && shown(E.lineWidth), ...
    'an evoked plot reads LFP and shows its channels and baseline, not the unit, bin or PSTH rows');
tree = app.PlotsTree;
check(isequal(string({tree.Children.Text}), ["PSTH  (1)" "Evoked potential  (1)"]) && string(app.PlotGroupDropDown.Value) == "kind" ...
    && tree.SelectedNodes.NodeData == 2 && string(tree.SelectedNodes.Text) == "evoked_1  (LFP)", ...
    'the plot tree groups the plots by plot type by default, the selected plot highlighted');
app.PlotGroupDropDown.Value = 'source';
app.onPlotGroupChanged();
check(isequal(string({tree.Children.Text}), ["units  (1)" "LFP  (1)"]) && tree.SelectedNodes.NodeData == 2 ...
    && string(tree.SelectedNodes.Text) == "evoked_1  (evoked)", 'grouped by source, the groups follow and the selection stays');
app.onPlotTreeSelected(tree.Children(1).Children(1));
app.onPlotTreeSelected(tree.Children(2));
check(app.SelectedPlot == 1 && tree.SelectedNodes.NodeData == 1, ...
    'picking a plot opens it; picking a group header leaves the plot in the editor');
app.PlotGroupDropDown.Value = 'none';
app.onPlotGroupChanged();
app.onMovePlot(1);
check(all(arrayfun(@(n) isnumeric(n.NodeData), tree.Children)) && numel(tree.Children) == 2 ...
    && isequal([app.Config.Plots.id], ["evoked_1" "psth_1"]) && app.SelectedPlot == 2 && tree.SelectedNodes.NodeData == 2, ...
    'ungrouped, the tree is a flat list and Down moves the plot');
app.onMovePlot(-1);
app.PlotGroupDropDown.Value = 'kind';
app.onPlotGroupChanged();
app.onMovePlot(1);
app.onPlotGroupToggled(tree.Children(1), true);
check(isequal([app.Config.Plots.id], ["psth_1" "evoked_1"]) && app.SelectedPlot == 1 && isequal(app.PlotGroupsCollapsed, "kind:PSTH"), ...
    'grouped, Down stays within the plot''s group (alone in it: no move); a collapsed group is remembered');
app.onPlotGroupToggled(tree.Children(1), false);
app.onPlotSelected(2);
check(isempty(app.PlotGroupsCollapsed) && app.SelectedPlot == 2, 'expanding it forgets that');
% the check boxes: a plot's is ticked while it is enabled
dblclick = @(k) struct('InteractionInformation', struct('Node', plotNode(tree, k)));
check(all(arrayfun(@(k) string(plotNode(tree, k).UserData) == "on" && ~isempty(plotNode(tree, k).Icon), 1:2)) ...
    && string(tree.Children(1).UserData) == "on", 'every plot starts enabled, its box (and its group''s) ticked');
app.onPlotTreeDoubleClicked(dblclick(1));
check(~app.Config.Plots(1).enabled && app.Config.Plots(2).enabled && string(plotNode(tree, 1).UserData) == "off" ...
    && string(tree.Children(1).UserData) == "off" && endsWith(string(plotNode(tree, 1).Text), "(off)") && app.SelectedPlot == 2, ...
    'a double-click unticks a plot: disabled in the config, the box and "(off)" follow, the plot in the editor stays');
app.onPlotTreeDoubleClicked(dblclick(2));
check(~app.Config.Plots(2).enabled && ~E.enabled.Value, 'unticking the plot in the editor clears its Enabled box');
E.enabled.Value = true;
app.onConfigChanged("plot");
check(app.Config.Plots(2).enabled && string(plotNode(tree, 2).UserData) == "on", 'ticking Enabled in the editor ticks the tree box');
app.onPlotTreeDoubleClicked(struct('InteractionInformation', struct('Node', tree.Children(1))));
check(~app.Config.Plots(1).enabled, 'a double-click on a group header changes no plot');
app.onPlotCheck("all");
allOn = all([app.Config.Plots.enabled]);
app.onPlotCheck("none");
noneOn = ~any([app.Config.Plots.enabled]);
app.onPlotCheck("invert");
check(allOn && noneOn && all([app.Config.Plots.enabled]) && string(tree.Children(1).UserData) == "on", ...
    'All, None and Invert tick, untick and flip every plot');
fkeys = string(app.PlotFilterDropDown.ItemsData);
check(fkeys(1) == "selected" && all(ismember(["kind:PSTH" "kind:Evoked potential" "source:units" "source:LFP"], fkeys)), ...
    'the drop-down above the tree names the selected plots and each plot type and source in use');
app.PlotFilterDropDown.Value = 'kind:PSTH';
app.onPlotCheck("only");
check(isequal([app.Config.Plots.enabled], [true false]), 'Only ticks the plots of the type named and unticks the rest');
app.PlotFilterDropDown.Value = 'source:LFP';
app.onPlotCheck("check");
check(all([app.Config.Plots.enabled]), 'Check ticks the plots of the source named');
app.PlotFilterDropDown.Value = 'selected';
app.onPlotCheck("uncheck");
check(isequal([app.Config.Plots.enabled], [true false]), 'Uncheck unticks the plots selected (the second)');
app.PlotGroupDropDown.Value = 'status';
app.onPlotGroupChanged();
check(isequal(string({tree.Children.Text}), ["Enabled  (1)" "Off  (1)"]), 'grouped by Enabled / off, the plots sit under their state');
app.onPlotCheck("all");
check(isequal(string({tree.Children.Text}), "Enabled  (2)"), 'ticking them all moves them under Enabled');
app.PlotGroupDropDown.Value = 'kind';
app.onPlotGroupChanged();
app.PlotEditor.source.Value = 'LFP';
app.onConfigChanged("plot");
app.refreshPreview(Force=true);
check(~isempty(app.PreviewResult) && app.PreviewResult.kind == "evoked" && ~isempty(findall(app.PreviewPanel, 'Type', 'axes')), ...
    'the LFP evoked potential previews');
ylStack = shown(E.ylim);
E.layout.Value = 'grid'; app.syncPlotEditor();
ylGrid = shown(E.ylim);
E.layout.Value = 'stack'; app.syncPlotEditor();
app.onAddPlot("raster");
ylRaster = shown(E.ylim);
app.onRemovePlot();
check(~ylStack && ylGrid && ~ylRaster && numel(app.Config.Plots) == 2 && app.SelectedPlot == 2, ...
    'y limits are hidden where they would hide rows (an evoked stack, a raster), shown for an evoked grid');
app.onAddPlot("probemap");
sec = app.PlotSections;
check(~shown(E.defaultRef) && ~shown(A.Line) && ~shown(A.Pre) && ~shown(A.Filter) && ~shown(E.baselineMode) ...
    && shown(E.value) && shown(E.heatColormap) && ~shown(E.colormap) && ~shown(E.maxTiles), ...
    'a probe map hides the event, window, selection and baseline; it shows its value and heat colors');
app.onRemovePlot();
app.onAddPlot("waveforms");
wfGrid = shown(E.waveMode) && ~any(string(E.waveMode.ItemsData) == "off") && string(E.waveMode.Value) == "both" ...
    && ~shown(E.waveLocation) && shown(E.waveAmp) && shown(E.wavePP) && ~shown(E.waveSites) && ~shown(E.waveScale) ...
    && shown(E.maxTiles) && ~shown(E.defaultRef) && ~shown(E.baselineMode);
E.layout.Value = 'probe'; E.waveNames.Value = true; E.waveAmp.Value = 'common';
app.onConfigChanged("plot");
p = app.Config.Plots(end);
check(wfGrid && shown(E.waveSites) && shown(E.waveNames) && shown(E.waveScale) && ~shown(E.maxTiles) && p.kind == "waveforms" ...
    && p.layout == "probe" && p.waveform.mode == "both" && p.waveform.showNames && p.waveform.ampScale == "common", ...
    'a waveforms plot shows its mode (never Off), amplitude scale and labels; the probe layout adds size, sites and unit names');
app.refreshPreview(Force=true);
check(~isempty(app.PreviewResult) && app.PreviewResult.kind == "waveforms" && ~isempty(findall(app.PreviewPanel, 'Tag', 'waveMean')) ...
    && ~isempty(findall(app.PreviewPanel, 'Tag', 'waveName')), 'the waveforms plot previews on the probe, with the unit names');
app.onRemovePlot();
app.onPlotSelected(1);
check(any(string(E.waveMode.ItemsData) == "off"), 'another kind''s plot offers Off again');
kAux = find([app.Config.Plots.kind] == "psth" & [app.Config.Plots.source] == "units", 1);
app.onPlotSelected(kAux);
auxRows = shown(E.auxMode) && shown(E.auxChannels) && shown(E.auxBaseline) && shown(E.auxByGroup) ...
    && string(E.auxMode.Value) == "off" && E.auxPlacement.Enable == "off" && E.auxBaseFrom.Enable == "off";
E.auxMode.Value = 'magnitude'; E.auxPlacement.Value = 'above'; E.auxChannels.Value = '1 2 3';
E.auxBaseline.Value = true; E.auxBaseFrom.Value = -0.1; E.auxByGroup.Value = false;
app.onConfigChanged("plot");
xa = app.Config.Plots(kAux).aux;
check(~isempty(kAux) && auxRows && xa.mode == "magnitude" && xa.placement == "above" && isequal(xa.channels, [1 2 3]) ...
    && xa.baseline == "subtract" && isequal(xa.baselineWindow, [-0.1 0]) && ~xa.byGroup ...
    && E.auxPlacement.Enable == "on" && E.auxBaseFrom.Enable == "on", ...
    'a PSTH of units shows the Aux signals rows (grayed out while Off); an edit reaches the plot''s aux');
app.refreshPreview(Force=true);
check(~isempty(app.PreviewResult) && isfield(app.PreviewResult, 'aux') && ~isempty(findall(app.PreviewPanel, 'Tag', 'auxAxes')) ...
    && ~isempty(findall(app.PreviewPanel, 'Tag', 'auxTrace')), 'the preview computes the mean aux signal and draws its panels');
kSig = find(ismember([app.Config.Plots.source], EphysAnalysisConfig.SignalSources), 1);
if ~isempty(kSig)
    app.onPlotSelected(kSig);
    auxHidden = ~shown(E.auxMode) && ~shown(app.PlotSections([app.PlotSections.Name] == "aux").Toggle);
else
    auxHidden = false;
end
app.onPlotSelected(kAux);
check(auxHidden && string(E.auxMode.Value) == "magnitude" && string(E.auxPlacement.Value) == "above" ...
    && string(E.auxChannels.Value) == "1 2 3" && E.auxBaseline.Value && E.auxBaseFrom.Value == -0.1 && ~E.auxByGroup.Value, ...
    'a plot of signals hides the Aux signals section; selecting the PSTH again shows its aux settings');
spanOff = E.auxOverFrom.Enable == "off";   % placement "above"
E.auxPlacement.Value = 'over'; E.auxOverFrom.Value = 0; E.auxOverTo.Value = 0.3; E.auxYLim.Value = '-0.1 0.1';
app.onConfigChanged("plot");
xa = app.Config.Plots(kAux).aux;
check(spanOff && E.auxOverFrom.Enable == "on" && isequal(xa.overPosition, [0 0.3]) && isequal(xa.yLim, [-0.1 0.1]) ...
    && xa.placement == "over", 'over the plot: its span (0 to 0.3) and y limits reach the plot; the span waits for placement Over');
E.auxYLim.Value = '0.1 -0.1'; app.onConfigChanged("plot");
check(isempty(app.Config.Plots(kAux).aux.yLim), 'y limits that are not two ascending values are automatic');
E.auxPlacement.Value = 'below'; E.auxYLim.Value = '';
E.auxDisplay.Value = 'heatmap'; E.auxStatistic.Value = 'median'; E.auxTransform.Value = 'rectify';
E.auxErrType.Value = 'iqr'; E.auxColorBy.Value = 'channel';
app.onConfigChanged("plot");
xa = app.Config.Plots(kAux).aux;
check(shown(E.auxDisplay) && shown(E.auxStatistic) && shown(E.auxErrType) && shown(E.auxColorBy) && xa.display == "heatmap" ...
    && xa.statistic == "median" && xa.transform == "rectify" && xa.errorType == "iqr" && xa.colorBy == "channel" ...
    && E.auxErrType.Enable == "off" && E.auxStatistic.Enable == "on", ...
    'the Aux signals display, statistic, rectify, error band and color-by choices reach the plot''s aux; a heat map takes no band');
app.refreshPreview(Force=true);
check(~isempty(findall(app.PreviewPanel, 'Tag', 'auxImage')) && isempty(findall(app.PreviewPanel, 'Tag', 'auxTrace')) ...
    && app.PreviewResult.aux.statistic == "median" && app.PreviewResult.aux.rectified, ...
    'the preview computes the median of the rectified signal and draws it as a heat map');
E.auxDisplay.Value = 'stacked'; E.auxErrType.Value = 'ci95'; app.onConfigChanged("plot");
check(E.auxErrType.Enable == "on" && E.errResamples.Enable == "on" && E.errFace.Enable == "on", ...
    'an aux bootstrap band enables the resamples and the band look, whatever the plot''s own Error says');
E.auxDisplay.Value = 'lines'; E.auxStatistic.Value = 'mean'; E.auxTransform.Value = 'none';
E.auxErrType.Value = 'sem'; E.auxColorBy.Value = 'auto';
E.auxMode.Value = 'off'; app.onConfigChanged("plot");
check(app.Config.Plots(kAux).aux.mode == "off" && E.auxChannels.Enable == "off", 'Off takes the aux signal off the plot');
E.auxPlacement.Value = 'below'; E.auxChannels.Value = ''; E.auxBaseline.Value = false; E.auxBaseFrom.Value = -0.2;
E.auxByGroup.Value = true; E.auxYLim.Value = ''; E.auxOverFrom.Value = 0; E.auxOverTo.Value = 1;
app.onConfigChanged("plot");   % the defaults again, for what follows
errRows = shown(E.errType) && shown(E.errFace) && shown(E.errEdge) && E.errResamples.Enable == "off" ...
    && E.errEdgeStyle.Enable == "off" && string(E.showSEM.Text) == "Error";
E.errType.Value = 'std'; E.errAlpha.Value = 0.3; E.errEdge.Value = 'auto'; E.errEdgeWidth.Value = 1;
app.onConfigChanged("plot");
st = app.Config.Plots(kAux).style;
check(errRows && st.ErrorType == "std" && st.ErrorFaceAlpha == 0.3 && st.ErrorEdgeColor == "auto" && st.ErrorEdgeWidth == 1 ...
    && st.ErrorFaceColor == "" && E.errEdgeStyle.Enable == "on" && E.errResamples.Enable == "off", ...
    'a PSTH shows the Error, Band fill and Band edge rows; edits reach its style (auto fill = "", the edge''s style once it has one)');
app.refreshPreview(Force=true);
sb = findall(app.PreviewPanel, 'Tag', 'sem');
check(~isempty(app.PreviewResult) && app.PreviewResult.err.type == "std" && ~isempty(sb) && all([sb.FaceAlpha] == 0.3), ...
    'the preview computes mean +/- SD and draws the bands in the look set');
E.errType.Value = 'ci95'; app.syncPlotEditor();
ciOn = E.errResamples.Enable == "on";
E.showSEM.Value = false; app.syncPlotEditor();
check(ciOn && E.errType.Enable == "off" && E.errFace.Enable == "off", 'resamples for the bootstrap CI; the rows wait for the Error box');
E.showSEM.Value = true; E.errType.Value = 'sem'; E.errAlpha.Value = []; E.errEdge.Value = 'none'; E.errEdgeWidth.Value = 0.5;
app.onConfigChanged("plot");   % the defaults again
app.onPlotSelected(1);
app.onAddPlot("heatmap");
hideA = ~shown(E.aMethod) && ~shown(E.aCutoff) && any(string(E.baselineMode.Items) == "auroc") && ~shown(E.raMethod);
E.baselineMode.Value = 'auroc';
app.onConfigChanged("plot");
showA = shown(E.aMethod) && shown(E.aWinMs) && shown(E.aModFrom) && shown(E.aCutoff) && shown(E.aMarks) && ~shown(E.aTest) ...
    && E.smoothMs.Enable == "off" && E.aStepMs.Enable == "off" && E.aThreshold.Enable == "off" ...
    && any(string(E.order.Items) == "modulation");
E.aWindows.Value = 'sliding'; E.aWinMs.Value = 50; E.aStepMs.Value = 20; E.aCutoff.Value = 'test';
E.aModFrom.Value = 0; E.aModTo.Value = 0.3; E.order.Value = 'modulation';
app.onConfigChanged("plot");
p = app.Config.Plots(end);
a = p.auroc;
check(hideA && showA && shown(E.aTest) && E.aStepMs.Enable == "on" && a.windows == "sliding" && a.windowSec == 0.05 ...
    && a.stepSec == 0.02 && a.cutoff == "test" && isequal(a.modulationWindow, [0 0.3]) && p.order == "modulation" ...
    && p.baseline.Mode == "auroc", ['a spike heatmap offers the auROC baseline; choosing it shows its settings ' ...
    '(smoothing off), and sliding windows, a per-unit test, the call window and the modulation order reach the plot']);
E.aCutoff.Value = 'fixed'; E.aThreshold.Value = 0.05;
app.onConfigChanged("plot");
app.refreshPreview(Force=true);
R = app.PreviewResult;
check(~isempty(R) && isfield(R, 'auroc') && isstruct(R.auroc) && R.units == "auROC" ...
    && ~isempty(findall(app.PreviewPanel, 'Tag', 'modWindow')), 'the auROC heatmap previews, its call window marked');
E.response.Value = true; E.respTest.Value = 'auroc';
app.onConfigChanged("plot");
showR = shown(E.raMethod) && shown(E.raWinMs) && shown(E.raBinMs) && shown(E.raCutoff) && ~shown(E.raTest) ...
    && ~any(string(E.raCutoff.ItemsData) == "none") && app.Config.Plots(end).units.response.test == "auroc";
E.aWindows.Value = 'tiled';
app.applyPlotEditor();
check(showR && string(E.aWindows.Value) == "sliding" && E.aWinMs.Value == 50 && string(E.respTest.Value) == "auroc", ...
    'the auROC response test shows its own settings (no "none" cutoff); showing the plot again restores its auROC settings');
app.onRemovePlot();
app.onPlotSelected(1);
app.onPlotSectionToggled("style");
collapsed = ~shown(E.fontSize) && shown(sec([sec.Name] == "style").Toggle);
app.onPlotSectionToggled("style");
check(collapsed && shown(E.fontSize), 'the Appearance section collapses to its header and expands again');
app.onPlotSectionToggled("bins");
app.onPlotSelected(1);
check(app.SelectedPlot == 1 && app.PlotEditor.binMs.Value == 20 && app.PlotEditor.stack.Value ...
    && string(app.PlotEditor.normalize.Value) == "groupPeak" && isempty(app.PlotEditor.fillAlpha.Value) ...
    && string(app.PlotEditor.colormap.Value) == "black", 'selecting plot 1 shows its edits');
check(shown(E.waveMode) && shown(E.waveLocation) && string(E.waveMode.Value) == "off" && E.waveLocation.Enable == "off" ...
    && E.waveBox.Enable == "off" && string(E.waveLocation.Value) == "northeast" && E.waveBox.Value, ...
    'a PSTH grid shows the Unit waveform rows: off, north-east, with its axis box; the others wait for a mode');
E.waveMode.Value = 'both'; E.waveLocation.Value = 'southwest'; E.waveBox.Value = false; E.waveScale.Value = 1.5; E.waveSpikes.Value = 30;
app.onConfigChanged("plot");
wv = app.Config.Plots(1).waveform;
check(wv.mode == "both" && wv.location == "southwest" && ~wv.box && wv.scale == 1.5 && wv.maxSpikes == 30 ...
    && E.waveLocation.Enable == "on" && E.waveBox.Enable == "on", 'the waveform mode, location, axis box, size and spikes reach the plot');
app.refreshPreview(Force=true);
check(isfield(app.PreviewResult, 'waveforms') && ~isempty(findall(app.PreviewPanel, 'Tag', 'waveMean')) ...
    && isempty(findall(app.PreviewPanel, 'Tag', 'waveBox')), ...
    'the preview draws each unit''s waveform (the synthetic sort''s templates), without the box');
E.layout.Value = 'overlay'; app.syncPlotEditor();
hiddenOverlay = ~shown(E.waveMode);
E.layout.Value = 'grid'; app.syncPlotEditor();
E.waveMode.Value = 'off';
app.onConfigChanged("plot");
check(hiddenOverlay && app.Config.Plots(1).waveform.mode == "off" && ~app.Config.Plots(1).waveform.box, ...
    'an overlay hides the waveform rows; Off keeps the other waveform settings');

check(shown(E.annText) && shown(sec([sec.Name] == "note").Toggle) && E.annPlace.Enable == "off" && E.annBold.Enable == "off" ...
    && string(E.annPlace.Value) == "below" && isempty(E.annSize.Value) && string(E.annFont.Value) == "auto", ...
    'the Text note section shows for a plot without a note, its settings waiting for some text');
E.annText.Value = {'Condition A'; 'n = 12'}; E.annPlace.Value = 'custom'; E.annX.Value = 0.2; E.annY.Value = 0.8;
E.annBold.Value = true; E.annSize.Value = 14; E.annColor.Value = 'red'; E.annAlign.Value = 'center'; E.annRotation.Value = 15;
app.onConfigChanged("plot");
nt = app.Config.Plots(1).note;
check(nt.text == "Condition A" + newline + "n = 12" && nt.placement == "custom" && nt.x == 0.2 && nt.y == 0.8 && nt.bold && ~nt.italic ...
    && nt.fontSize == 14 && nt.color == "red" && nt.fontName == "" && nt.background == "" && nt.align == "center" && nt.rotation == 15 ...
    && E.annPlace.Enable == "on" && E.annBold.Enable == "on" && E.annX.Enable == "on", ...
    'the note''s text, place, alignment, rotation, font and color reach the plot; "auto" and "none" are blank');
app.refreshPreview(Force=true);
tx = findall(app.PreviewPanel, 'Type', 'text', 'Tag', 'note');
check(isscalar(tx) && numel(tx.String) == 2 && tx.FontWeight == "bold" && tx.FontSize == 14 && isequal(tx.Color, [1 0 0]) ...
    && tx.Rotation == 15 && isequal(tx.Position(1:2), [0.2 0.8]), 'the preview draws the note');
app.onPlotSelected(1);
check(isequal(string(E.annText.Value(:)).', ["Condition A" "n = 12"]) && string(E.annPlace.Value) == "custom" && E.annSize.Value == 14 ...
    && string(E.annColor.Value) == "red" && E.annX.Enable == "on", 'selecting the plot again shows its note');
E.annPlace.Value = 'below'; app.onConfigChanged("plot");
check(E.annX.Enable == "off" && E.annY.Enable == "off", 'x and y wait for the place "At x, y"');
app.onPlotSectionToggled("note");
collapsed = ~shown(E.annText) && shown(sec([sec.Name] == "note").Toggle);
app.onPlotSectionToggled("note");
check(collapsed && shown(E.annText), 'the Text note section collapses to its header and expands again');
heads = app.PlotSections([app.PlotSections.Name] ~= "general");
barColors = cell2mat(arrayfun(@(s) s.Toggle.BackgroundColor, heads, 'UniformOutput', false).');
fontColors = cell2mat(arrayfun(@(s) s.Toggle.FontColor, heads, 'UniformOutput', false).');
ratios = arrayfun(@(i) wcagRatio(fontColors(i, :), barColors(i, :)), 1:numel(heads));
satur = max(barColors, [], 2) - min(barColors, [], 2);
check(numel(heads) == 12 && size(unique(round(barColors, 3), 'rows'), 1) == 12 && all(ratios >= 4.5) ...
    && all(fontColors(:) == 0) && all(satur > 0.01 & satur < 0.4) ...
    && isequal([heads.Name], ["units" "ref" "window" "selection" "bins" "kind" "marks" "style" "waveform" "aux" "note" "overlays"]) ...
    && isequal([heads.Key], [string(1:6) "" "7" "8" "" "9" "0"]) ...
    && all(arrayfun(@(s) s.Key == "" || endsWith(s.Toggle.Text, modifier + s.Key + ")"), heads)) ...
    && ~contains(heads([heads.Name] == "aux").Toggle.Text, modifier) && ~contains(heads([heads.Name] == "marks").Toggle.Text, modifier), ...
    ['each of the twelve section headers has a desaturated bar color of its own with black text; all but Event marks ' ...
    'and Aux signals name their key (Ctrl+1 to Ctrl+9, Ctrl+0), the keys they had before them']);
pressed = @(k, mods) struct('Key', k, 'Modifier', {mods}, 'Character', '');
app.onKeyPress(pressed('5', {'control', 'shift'}));
app.onKeyPress(pressed('5', {'alt'}));
app.onKeyPress(pressed('5', {}));
app.onKeyPress(pressed('6', {'control'}));
untouched = ~shown(E.binMs);
app.onKeyPress(pressed('5', {'control'}));
opened = shown(E.binMs);
app.onPlotSectionToggled("bins");
app.onKeyPress(pressed('numpad5', {'command'}));
openedPad = shown(E.binMs);
app.onPlotSectionToggled("bins");
check(untouched && opened && openedPad, ...
    'Ctrl+5 (or Cmd, or the number pad) opens the collapsed Bins & baseline section; other chords and keys leave it');
app.onPlotSectionToggled("overlays");
app.onKeyPress(pressed('0', {'control'}));
openedOverlays = shown(E.ovList);
check(openedOverlays, 'Ctrl+0 opens the collapsed Overlays section, the tenth');
kLfp = find([app.Config.Plots.source] == "LFP", 1);
if ~isempty(kLfp); app.onPlotSelected(kLfp); end
app.onKeyPress(pressed('8', {'control'}));
check(~isempty(kLfp) && ~shown(E.waveMode) && contains(app.StatusBar.Text, "Unit waveform section is not shown"), ...
    'the key of a section the plot does not show says so in the status bar and moves nothing');
app.onPlotSelected(1);
E.annText.Value = {''}; E.annSize.Value = []; app.onConfigChanged("plot");
app.refreshPreview(Force=true);
check(app.Config.Plots(1).note.text == "" && isnan(app.Config.Plots(1).note.fontSize) && E.annPlace.Enable == "off" ...
    && isempty(findall(app.PreviewPanel, 'Tag', 'note')), 'clearing the text takes the note off the plot');

% --- overlays: lines and patches on the plot's axes
k0 = app.SelectedPlot;
ovSec = @() app.PlotSections([app.PlotSections.Name] == "overlays");
check(shown(E.ovList) && shown(ovSec().Toggle) && ~shown(E.ovName) && ~shown(E.ovValue) && ~shown(E.ovFrom) ...
    && E.ovAddLine.Enable == "on" && E.ovAddRegion.Enable == "on" && E.ovDuplicate.Enable == "off" && E.ovRemove.Enable == "off" ...
    && string(ovSec().Title) == "Overlays" && isempty(app.Config.Plots(k0).overlays) && isempty(E.ovList.Items), ...
    'the Overlays section shows for a plot without overlays: the list and its Add buttons, the rows waiting for one');
app.onAddOverlay("line");
ovs = app.Config.Plots(k0).overlays;
check(isscalar(ovs) && ovs.shape == "line" && ovs.axis == "x" && ovs.name == "Line 1" && ovs.layer == "over" && ovs.panel == "all" ...
    && shown(E.ovName) && shown(E.ovKind) && shown(E.ovValue) && ~shown(E.ovFrom) && shown(E.ovColor) && ~shown(E.ovFill) ...
    && ~shown(E.ovEdge) && shown(E.ovStyle) && shown(E.ovPanel) && E.ovRemove.Enable == "on" && E.ovDuplicate.Enable == "on" ...
    && string(ovSec().Title) == "Overlays (1)" && numel(E.ovList.Items) == 1, ...
    'Add line puts a dashed line at 0 in the list, picked; its rows are a line''s (position, color), not a patch''s');
E.ovName.Value = 'Stim on'; E.ovValue.Value = '0.25'; E.ovColor.Value = 'blue'; E.ovAlpha.Value = 0.5;
E.ovStyle.Value = ':'; E.ovWidth.Value = 3; E.ovLayer.Value = 'under'; E.ovPanel.Value = 'data';
app.onConfigChanged("plot");
ovs = app.Config.Plots(k0).overlays;
check(ovs.name == "Stim on" && ovs.value == 0.25 && ovs.color == "blue" && ovs.alpha == 0.5 && ovs.lineStyle == ":" && ovs.lineWidth == 3 ...
    && ovs.layer == "under" && ovs.panel == "data" && contains(string(E.ovList.Items{1}), "Stim on") ...
    && contains(string(E.ovList.Items{1}), "x = 0.25"), ...
    'the line''s name, position, color, opacity, style, width, layer and panel reach the config; the list follows its name and position');
app.onAddOverlay("region");
E.ovKind.Value = 'region|y'; E.ovFrom.Value = '5'; E.ovTo.Value = '2'; E.ovFill.Value = 'green'; E.ovFillAlpha.Value = 0.4;
E.ovEdge.Value = 'black';
app.onConfigChanged("plot");
ovs = app.Config.Plots(k0).overlays;
check(numel(ovs) == 2 && ovs(1).name == "Stim on" && ovs(1).value == 0.25 && ovs(1).color == "blue" ...
    && ovs(2).name == "Patch 1" && ovs(2).shape == "region" && ovs(2).axis == "y" && ovs(2).from == 5 && ovs(2).to == 2 ...
    && ovs(2).faceColor == "green" && ovs(2).faceAlpha == 0.4 && ovs(2).edgeColor == "black" ...
    && shown(E.ovFrom) && ~shown(E.ovValue) && shown(E.ovFill) && shown(E.ovEdge) && ~shown(E.ovColor) ...
    && E.ovStyle.Enable == "on" && string(ovSec().Title) == "Overlays (2)" && numel(E.ovList.Items) == 2, ...
    'Add patch adds a second overlay and keeps the first; a patch shows its edges, fill and outline, not a line''s position and color');
E.ovEdge.Value = 'none';
app.syncPlotEditor();
outlineOff = E.ovStyle.Enable == "off" && E.ovWidth.Enable == "off";
E.ovEdge.Value = 'black';
app.syncPlotEditor();
check(outlineOff && E.ovStyle.Enable == "on" && E.ovWidth.Enable == "on", 'a patch''s outline style and width wait for an outline color');
E.ovList.Value = 1;
app.onOverlayPicked();
check(string(E.ovName.Value) == "Stim on" && string(E.ovValue.Value) == "0.25" && string(E.ovColor.Value) == "blue" ...
    && E.ovWidth.Value == 3 && string(E.ovLayer.Value) == "under" && shown(E.ovValue) && ~shown(E.ovFrom), ...
    'picking the first overlay shows its rows');
E.ovList.Value = 2;
app.onOverlayPicked();
check(string(E.ovKind.Value) == "region|y" && string(E.ovFrom.Value) == "5" && string(E.ovTo.Value) == "2" ...
    && string(E.ovFill.Value) == "green" && E.ovFillAlpha.Value == 0.4 && shown(E.ovFrom) && ~shown(E.ovValue), ...
    'and the second''s: nothing was lost on the way');
app.refreshPreview(Force=true);
nRate = numel(findall(app.PreviewPanel, 'Type', 'axes', 'Tag', 'axes'));
nRas = numel(findall(app.PreviewPanel, 'Type', 'axes', 'Tag', 'rasterAxes'));
ln = findall(app.PreviewPanel, 'Tag', 'overlayLine');
rg = findall(app.PreviewPanel, 'Tag', 'overlayRegion');
check(app.PreviewState == "drawn" && nRate > 0 && numel(ln) == nRate && numel(rg) == nRate + nRas && all([ln.Value] == 0.25) ...
    && all(arrayfun(@(x) isequal(sort(x.Value), [2 5]), rg)) && all(arrayfun(@(x) isequal(x.Color, [0 0 1]) && x.LineWidth == 3, ln)), ...
    'the preview draws the line in the data panels and the patch in every panel, as set');
E.ovList.Value = 1;
app.onOverlayPicked();
app.onDuplicateOverlay();
ovs = app.Config.Plots(k0).overlays;
check(numel(ovs) == 3 && ovs(2).name == "Stim on copy" && isequal(rmfield(ovs(2), 'name'), rmfield(ovs(1), 'name')) ...
    && ovs(3).name == "Patch 1" && E.ovList.Value == 2 && string(E.ovName.Value) == "Stim on copy", ...
    'Duplicate copies the overlay right after itself, look and all, under a name of its own, and picks the copy');
app.onRemoveOverlay();
ovs = app.Config.Plots(k0).overlays;
check(numel(ovs) == 2 && ovs(1).name == "Stim on" && ovs(2).name == "Patch 1" && E.ovList.Value == 2 && string(E.ovName.Value) == "Patch 1", ...
    'Remove takes the overlay picked and picks the one that took its place');
if numel(app.Config.Plots) > 1
    other = find((1:numel(app.Config.Plots)) ~= k0, 1);
    app.onPlotSelected(other);
    noneThere = isempty(E.ovList.Items) && ~shown(E.ovName) && string(ovSec().Title) == "Overlays";
    app.onPlotSelected(k0);
    check(noneThere && numel(E.ovList.Items) == 2 && E.ovList.Value == 1 && string(E.ovName.Value) == "Stim on" ...
        && string(ovSec().Title) == "Overlays (2)", 'each plot has its own overlays: another plot''s list is empty, and this one''s is back');
end
app.onPlotSectionToggled("overlays");
collapsed = ~shown(E.ovList) && shown(ovSec().Toggle);
app.onPlotSectionToggled("overlays");
check(collapsed && shown(E.ovList), 'the Overlays section collapses to its header and expands again');
c1 = app.gatherConfig();
app.applyConfig(c1);
check(isequal(app.Config.Plots(k0).overlays, c1.Plots(k0).overlays) && numel(E.ovList.Items) == 2, ...
    'the overlays survive a gather / apply round trip');
app.onRemoveOverlay();
app.onRemoveOverlay();
app.refreshPreview(Force=true);
check(isempty(app.Config.Plots(k0).overlays) && isempty(E.ovList.Items) && ~shown(E.ovName) && E.ovRemove.Enable == "off" ...
    && isempty(findall(app.PreviewPanel, 'Tag', 'overlayLine')) && isempty(findall(app.PreviewPanel, 'Tag', 'overlayRegion')), ...
    'removing the last overlay empties the list and takes them off the preview');

fprintf('\n== 3a. the epoch diagram ==\n');
A = app.PlotAlignControls;
check(shown(E.epochs) && E.epochs.Text == "Epoch Diagram" && E.epochs.Parent == app.PlotAlignControls.WindowGrid ...
    && isvalid(app.AlignEpochsButton) && ancestor(app.AlignEpochsButton, 'uitab') == app.TabAlign ...
    && app.AlignEpochsButton.Parent == app.AlignControls.WindowGrid, ...
    'the plot editor and the Alignment tab each offer "Epoch Diagram" under the Epoch window');
app.onShowEpochs("plot");
d = app.EpochDiagramWindow;
src = app.Runner.source(app.ActiveIdx);
spec = app.Config.plotFor(1);
b = [];
if spec.baseline.Mode ~= "none"; b = spec.baseline.Window; end
E0 = epochTable(src, spec.ref, Window=spec.window, Selection=spec.selection, Baseline=b);
check(isa(d, 'EpochDiagram') && d.isOpen() && string(d.Fig.WindowStyle) == "alwaysontop" && d.Message == "" ...
    && nnz(d.Epochs.kept) == height(E0) && isequal(d.Epochs.t0(d.Epochs.kept), E0.t0) ...
    && isequal(d.Epochs.number(d.Epochs.kept), (1:height(E0)).') && ~isempty(d.Shown) ...
    && startsWith(d.Heading, "psth_1 on ") && contains(d.Heading, "its own event"), ...
    sprintf('the diagram opens above the app with exactly the plot''s %d epochs, numbered as the plot numbers them', height(E0)));
check(startsWith(d.Lanes(1), "Trials") && contains(d.Lanes(1), "▲ event") && d.Lanes(end) == "Epochs" ...
    && startsWith(d.Rule(1), "Time 0 is each trial's onset") && contains(d.Summary, "epochs from") ...
    && ~isempty(findall(d.Fig, 'Type', 'patch')) && ~isempty(findall(d.Fig, 'Type', 'legend')), ...
    'aligned to the trial line, the trials row carries the ▲ marks and the rule says what time 0 is');
A.Pre.Value = -0.5;
app.onPlotAlignEdited("window");
check(all(abs(d.Epochs.tStart - d.Epochs.t0 + 0.5) < 1e-9) && contains(d.Rule(2), "0.5 s before it"), ...
    'editing pre redraws the diagram at once: every window starts 0.5 s before its event');
A.Pre.Value = -100;
app.onPlotAlignEdited("window");
check(height(d.Epochs) == height(E0) && ~any(d.Epochs.kept) && all(d.Epochs.reason == "outside the recording") ...
    && startsWith(d.Summary, "0 epochs") && contains(d.Summary, "outside the recording"), ...
    'a window reaching before the recording: every event shown, every epoch dropped and saying why');
A.Pre.Value = 1;
app.onPlotAlignEdited("window");
check(startsWith(d.Summary, "No epochs") && contains(d.Message, "pre <= post") && height(d.Epochs) == 0 ...
    && ~isempty(findall(d.Fig, 'Type', 'line')), 'a window epochTable refuses is reported, and the lines are still drawn');
E.defaultWindow.Value = true;
app.onPlotDefaultToggled();
W = app.Config.Defaults.Window;
check(d.Message == "" && all(abs(d.Epochs.tStart - d.Epochs.t0 - W.pre) < 1e-9) && nnz(d.Epochs.kept) == height(E0), ...
    'ticking Use default again: the diagram follows the default window');
d.setCount(3);
s1 = d.Shown;
d.page(1);
s2 = d.Shown;
d.page(-1);
check(numel(s1) >= 3 && min(s1) == 1 && min(s2) == max(s1) + 1 && min(d.Shown) == 1, ...
    'Next and Previous step through the events, Show at a time');
app.onShowEpochs("defaults");
Dd = app.Config.Defaults;
Ed = epochTable(src, Dd.EventRef, Window=Dd.Window, Selection=Dd.Selection);
check(app.EpochDiagramWindow == d && startsWith(d.Heading, "Defaults") && nnz(d.Epochs.kept) == height(Ed) ...
    && height(d.Groups) == nG && endsWith(d.Rule(end), "grouped by Depth.") && contains(d.Lanes(2), "Stim  ▲ event"), ...
    'from the Alignment tab the same window shows the defaults: Stim onset, grouped by Depth');
d.close();
app.onConfigChanged("plot");
check(~d.isOpen(), 'closing the diagram leaves it closed through later edits');

fprintf('\n== 3b. the raster''s sort and marks, events shifted by a parameter, behavior plots ==\n');
app.onAddPlot("raster");
kR = app.SelectedPlot;
check(shown(E.rasterSort) && shown(E.rasterSortOrder) && shown(E.rasterByGroup) && shown(E.markSeqText) && shown(E.markSeqEdit) ...
    && shown(E.markTable) && E.markTable.Enable == "off" && height(E.markTable.Data) == 0 && ~shown(E.yParam) && ~shown(E.xScale), ...
    'a raster shows its sort, direction, grouping and event marks (the table waits for a mark)');
E.rasterSort.Value = 'Depth'; E.rasterSortOrder.Value = 'descending'; E.rasterByGroup.Value = false;
app.onConfigChanged("plot");
E.markSeqEdit.ButtonPushedFcn(E.markSeqEdit, []);
D = app.SequenceDialog.UserData;
D.AddSeq.ButtonPushedFcn(D.AddSeq, []);   % a plain line mark: Trough onset, no steps
D.Line.Value = 'Trough'; D.Edge.Value = 'onset';
D.Table.Data = D.Table.Data([], :);
D.AddSeq.ButtonPushedFcn(D.AddSeq, []);   % Trial offset then Trough onset
D.AddSeq.ButtonPushedFcn(D.AddSeq, []);
D.Line.Value = 'RespWindow'; D.Edge.Value = 'onset';
D.Table.Data = D.Table.Data([], :);
D.Apply.ButtonPushedFcn(D.Apply, []);
p = app.Config.Plots(kR);
labels = ["Trough onset" "Trial offset then Trough onset" "RespWindow onset"];
check(p.rasterSort == "Depth" && p.rasterSortOrder == "descending" && ~p.rasterByGroup && numel(p.rasterEvents) == 3 ...
    && isequal(rasterMarkLabels(p.rasterEvents), labels) && all([p.rasterEvents.which] == "all") ...
    && all([p.rasterEvents.marker] == "diamond") && all([p.rasterEvents.color] == ""), ...
    'the raster''s sort, its direction and grouping, and its marks -- a sequence each, with or without steps -- reach the plot');
T = E.markTable.Data;
check(E.markTable.Enable == "on" && isequal(T.Properties.VariableNames, {'Mark', 'Marker', 'Size', 'Color'}) ...
    && isequal(T.Mark.', labels) && all(T.Size == 4) && all(T.Color == "auto") && all(string(T.Marker) == "diamond"), ...
    'Each mark lists every mark in order, each in its own look (no Own column)');
app.refreshPreview(Force=true);
check(~isempty(app.PreviewResult) && isequal([app.PreviewResult.rasterEvents.label], labels) ...
    && ~isempty(findall(app.PreviewPanel, 'Tag', 'rasterEvent')), 'the preview marks each of them');
T.Color(1) = "blue";
E.markTable.Data = T;
E.markTable.CellEditCallback(E.markTable, struct('Indices', [1 4], 'NewData', "blue", 'PreviousData', "auto"));
T = E.markTable.Data;
T.Marker(3) = "square";
E.markTable.Data = T;
E.markTable.CellEditCallback(E.markTable, struct('Indices', [3 2], 'NewData', categorical("square"), 'PreviousData', categorical("diamond")));
p = app.Config.Plots(kR);
app.refreshPreview(Force=true);
drawn = findall(app.PreviewPanel, 'Tag', 'rasterEvent', 'HandleVisibility', 'off');
trough = drawn(arrayfun(@(x) getappdata(x, 'PlotGroup') == "Trough onset", drawn));
resp = drawn(arrayfun(@(x) getappdata(x, 'PlotGroup') == "RespWindow onset", drawn));
check(p.rasterEvents(1).color == "blue" && p.rasterEvents(3).marker == "square" && p.rasterEvents(2).color == "" ...
    && ~isempty(trough) && all(arrayfun(@(x) isequal(x.Color, [0 0 1]) && string(x.Marker) == "diamond", trough)) ...
    && ~isempty(resp) && all(arrayfun(@(x) string(x.Marker) == "square" && ~isequal(x.Color, [0 0 1]), resp)), ...
    "a mark's color or marker changed in Each mark reaches that mark alone, in the plot and the preview:" ...
    + strjoin(arrayfun(@(x) " " + getappdata(x, 'PlotGroup') + "=" + mat2str(x.Color, 3) + string(x.Marker), drawn(:).'), ""));
T = E.markTable.Data;
T.Size(2) = -1;
E.markTable.Data = T;
E.markTable.CellEditCallback(E.markTable, struct('Indices', [2 3], 'NewData', -1, 'PreviousData', 4));
check(E.markTable.Data.Size(2) == 4 && app.Config.Plots(kR).rasterEvents(2).size == 4, 'a size that is not positive is undone');
E.markSeqEdit.ButtonPushedFcn(E.markSeqEdit, []);
D = app.SequenceDialog.UserData;
D.List.Value = 2; D.List.ValueChangedFcn(D.List, []);
D.RemoveSeq.ButtonPushedFcn(D.RemoveSeq, []);
D.Apply.ButtonPushedFcn(D.Apply, []);
p = app.Config.Plots(kR);
check(isequal(rasterMarkLabels(p.rasterEvents), labels([1 3])) && p.rasterEvents(1).color == "blue" && p.rasterEvents(2).marker == "square" ...
    && isequal(E.markTable.Data.Mark.', labels([1 3])), ...
    'removing a sequence in the Event sequence window keeps the other marks'' looks with them');
check(shown(E.sortLine) && shown(E.sortSeqText) && E.sortLine.Enable == "off" && E.sortSeqEdit.Enable == "off", ...
    'a raster shows its sort event rows, off while it sorts by a trial parameter');
E.rasterSort.Value = 'event';
app.onConfigChanged("plot");
check(E.sortLine.Enable == "on" && E.sortEdge.Enable == "on" && E.sortSeqEdit.Enable == "on" ...
    && isempty(app.Config.Plots(kR).rasterSortEvent) && any(string(E.sortLine.Items) == "RespWindow"), ...
    'sorting by "event" turns the sort event rows on, listing the lines; no line picked yet, the plot has no event');
E.sortLine.Value = 'RespWindow'; E.sortEdge.Value = 'offset';
app.onConfigChanged("plot");
p = app.Config.Plots(kR);
check(p.rasterSort == "event" && isstruct(p.rasterSortEvent) && p.rasterSortEvent.line == "RespWindow" ...
    && p.rasterSortEvent.edge == "offset" && isempty(p.rasterSortEvent.sequence), 'the sort event''s line and edge reach the plot');
app.refreshPreview(Force=true);
R = app.PreviewResult;
check(~isempty(R) && isfield(R, 'rasterSortEvent') && R.rasterSortEvent.label == "RespWindow offset" ...
    && numel(R.rasterSortEvent.t) == height(R.epochs) && any(isfinite(R.rasterSortEvent.t)), ...
    'the preview sorts the raster by each epoch''s latency to the RespWindow offset');
E.rasterSort.Value = 'Depth';
app.onConfigChanged("plot");
p = app.Config.Plots(kR);
check(E.sortLine.Enable == "off" && p.rasterSort == "Depth" && p.rasterSortEvent.line == "RespWindow", ...
    'another sort turns the rows off; the plot keeps its sort event for later');
A.Line.Value = 'RespWindow';
A.ShiftParam.Value = 'RespLatency';
app.onPlotAlignEdited("ref");
p = app.Config.Plots(kR);
check(isstruct(p.ref) && p.ref.line == "RespWindow" && p.ref.offsetParam == "RespLatency" && p.ref.offsetParamUnit == "ms" ...
    && A.ShiftUnit.Enable == "on" && any(string(A.ShiftParam.Items) == "RespLatency"), ...
    'Shift by (listing the trial parameters) gives the plot its own event: RespWindow onset + RespLatency (ms)');
app.refreshPreview(Force=true);
check(~isempty(app.PreviewResult) && app.PreviewResult.epochs.Properties.UserData.nDroppedNoValue == nnz(~isfinite(trials.RespLatency)), ...
    'the preview aligns to the responses; the trials without one are left out');
A.Line.Value = 'Trial'; A.Edge.Value = 'offset'; A.ShiftParam.Value = '(none)';
app.onPlotAlignEdited("ref");
A.SeqEdit.ButtonPushedFcn(A.SeqEdit, []);
D = app.SequenceDialog.UserData;
check(isvalid(app.SequenceDialog) && string(D.Line.Value) == "Trial" && string(D.Edge.Value) == "offset" && D.Line.Enable == "off" ...
    && height(D.Table.Data) == 0 && D.List.Parent.Visible == "off", ...
    'Edit... opens the Event sequence window at the panel''s line and edge, with no step yet');
D.AddStep.ButtonPushedFcn(D.AddStep, []);
T = D.Table.Data; T.n(1) = 0; D.Table.Data = T;
D.Apply.ButtonPushedFcn(D.Apply, []);
check(isvalid(app.SequenceDialog) && isempty(app.Config.Plots(kR).ref.sequence), 'Apply refuses a bad step (n 0) and keeps the window open');
T.n(1) = 1; D.Table.Data = T;
D.Apply.ButtonPushedFcn(D.Apply, []);
p = app.Config.Plots(kR);
check(~(~isempty(app.SequenceDialog) && isvalid(app.SequenceDialog)) && numel(p.ref.sequence) == 1 && p.ref.sequence.line == "Trough" ...
    && p.ref.sequence.relation == "followedBy" && isinf(p.ref.alignStep) && string(A.SeqText.Text) == "then Trough onset", ...
    'Apply gives the plot its sequence: Trial offset then Trough onset');
app.refreshPreview(Force=true);
src0 = app.Runner.source(app.ActiveIdx);
Ep = app.PreviewResult.epochs;
check(~isempty(app.PreviewResult) && all(Ep.t0 > src0.trials.TrialOffset(Ep.trial)) ...
    && height(Ep) + Ep.Properties.UserData.nDroppedNoSequence <= src0.nTrials, ...
    'the preview aligns each epoch to the first Trough onset after its trial''s end');
E.markSeqEdit.ButtonPushedFcn(E.markSeqEdit, []);
D = app.SequenceDialog.UserData;
D.AddSeq.ButtonPushedFcn(D.AddSeq, []);
check(D.List.Parent.Visible == "on" && numel(D.List.Items) == 3 && string(D.List.Items{3}) == "Trial offset then Trough onset", ...
    'Mark sequences: Add sequence starts at Trial offset then Trough onset');
D.Apply.ButtonPushedFcn(D.Apply, []);
p = app.Config.Plots(kR);
app.refreshPreview(Force=true);
check(numel(p.rasterEvents) == 3 && p.rasterEvents(3).which == "all" && p.rasterEvents(1).color == "blue" ...
    && numel(app.PreviewResult.rasterEvents) == 3 && app.PreviewResult.rasterEvents(3).label == "Trial offset then Trough onset", ...
    'a mark added later reaches the plot after the others, which keep their looks, and the preview marks it');
app.onRemovePlot();
app.onAddPlot("behavior");
check(string(E.source.Value) == "trials" && string(E.kind.Text) == "Behavior" && shown(E.yParam) && shown(E.param) ...
    && shown(E.seriesParam) && shown(E.xScale) && shown(E.jitter) && ~shown(E.classes.su) && ~shown(E.channels) ...
    && ~shown(E.binMs) && ~shown(E.baselineMode) && ~shown(E.rasterSort) && ~shown(E.waveMode) && ~shown(E.maxTiles) ...
    && shown(E.colormap) && shown(E.ylim) && shown(A.Line), ...
    'a behavior plot reads the trials and shows its y value, parameter, series, x axis and alignment; no unit, bin or baseline rows');
E.yParam.Value = 'RespLatency'; E.param.Value = 'Depth'; E.jitter.Value = false; E.layout.Value = 'box';
app.onConfigChanged("plot");
p = app.Config.Plots(end);
check(p.yParam == "RespLatency" && p.param == "Depth" && ~p.jitter && p.layout == "box" && E.jitter.Enable == "off", ...
    'the y value, parameter, jitter and layout reach the plot; the jitter waits for the points layout');
app.refreshPreview(Force=true);
check(~isempty(app.PreviewResult) && app.PreviewResult.kind == "behavior" && ~isempty(findall(app.PreviewPanel, 'Tag', 'box')), ...
    'the behavior plot previews its box plots');
app.onRemovePlot();
app.onPlotSelected(1);

fprintf('\n== 3c. several plots at once ==\n');
app.onPlotSectionToggled("bins");   % expanded for this section's checks (collapsed again at its end)
D0 = app.Config.Defaults;
app.onAddPlot("psth");
k2 = app.SelectedPlot;
E.binMs.Value = 5;
app.onConfigChanged("plot");
A.Line.Value = 'Trial';
app.onPlotAlignEdited("ref");
app.onAddPlot("psth");
k3 = app.SelectedPlot;
app.onAddPlot("raster");
kR = app.SelectedPlot;
tree = app.PlotsTree;
app.onPlotTreeSelected(plotNode(tree, k3));
app.onPlotTreeSelected([plotNode(tree, k2) plotNode(tree, k3)]);   % Ctrl-click psth_2, above psth_3 in the tree
check(string(tree.Multiselect) == "on" && app.SelectedPlot == k3 && isequal(app.AlsoSelected, k2) ...
    && isequal(sort(reshape(arrayfun(@(n) n.NodeData, tree.SelectedNodes), 1, [])), sort([k2 k3])), ...
    'Ctrl-click selects a second plot in the tree; the first picked (psth_3) stays the one in the editor');
B = app.SelectionBar;
check(startsWith(E.note.Text, "2 plots selected: psth_3, psth_2.") && isequal(E.note.BackgroundColor, [1 0.93 0.75]) ...
    && shown(B.Text) && contains(B.Text.Text, "Previewing psth_3 only") && app.PreviewGrid.RowHeight{1} == 26 ...
    && contains(app.PlotEditorPanel.Title, "2 selected") && string(E.kind.Text) == "PSTH  (2 plots)", ...
    'the editor''s banner, its title and a bar over the preview say that two plots are edited together and psth_3 is previewed');
check(~shown(E.id) && ~shown(E.title) && shown(E.binMs) && shown(E.stack) && shown(A.Line) ...
    && app.UpPlotButton.Enable == "off" && app.DownPlotButton.Enable == "off" && E.binMs.Value == 10, ...
    'two PSTHs show the PSTH rows but no id or title, with psth_3''s values; Up / Down are off');
E.smoothMs.Value = 25;
app.onConfigChanged("plot");
p2 = app.Config.Plots(k2); p3 = app.Config.Plots(k3);
check(p2.bins.SmoothSec == 0.025 && p3.bins.SmoothSec == 0.025 && p2.bins.BinSec == 0.005 && p3.bins.BinSec == 0.01, ...
    'an edit goes to both plots, and only what it changed: each keeps its own bin');
A.Edge.Value = 'offset';
app.onPlotAlignEdited("ref");
p2 = app.Config.Plots(k2); p3 = app.Config.Plots(k3);
check(isstruct(p3.ref) && p3.ref.line == D0.EventRef.line && p3.ref.edge == "offset" ...
    && isstruct(p2.ref) && p2.ref.line == "Trial" && p2.ref.edge == "offset" && isequaln(app.Config.Defaults, D0), ...
    'editing the event''s edge gives both their own event: each the one it used (default Stim, own Trial) at offset');
E.defaultRef.Value = true;
app.onPlotDefaultToggled();
check(isequal(app.Config.Plots(k2).ref, "default") && isequal(app.Config.Plots(k3).ref, "default"), ...
    'ticking Use default puts both back on the default event');
app.refreshPreview(Force=true);
ctx = getappdata(app.PreviewPanel, PlotAesthetics.ContextKey);
check(app.PreviewState == "drawn" && ctx.id == "psth_3", 'the preview draws psth_3 alone');
ctx.onRemember(look);
hasLook = @(k) isscalar(app.Config.Plots(k).aesthetics) && app.Config.Plots(k).aesthetics.value == 0.4;
both = hasLook(k2) && hasLook(k3);
ctx.onRemember([]);
check(both && isempty(app.Config.Plots(k2).aesthetics) && isempty(app.Config.Plots(k3).aesthetics), ...
    'a look remembered from the preview goes to both plots; forgetting it there drops it from both');
app.onPlotTreeSelected([plotNode(tree, k2) plotNode(tree, k3) plotNode(tree, kR)]);
check(app.SelectedPlot == k3 && startsWith(string(E.kind.Text), "3 plots: PSTH, Raster") && shown(E.binMs) ...
    && shown(E.rasterSort) && shown(E.fontSize) && ~shown(E.stack) && ~shown(E.withRaster) && ~shown(E.baselineMode) ...
    && ~shown(E.showSEM) && shown(E.legend) && string(app.PlotSections([app.PlotSections.Name] == "kind").Title) == "Options", ...
    'adding a raster leaves only the rows a PSTH and a raster share (bins, raster sort, legend), not the PSTH''s own or the baseline');
ovAll = @(v) all(arrayfun(@(k) isscalar(app.Config.Plots(k).overlays) && app.Config.Plots(k).overlays.value == v, [k2 k3 kR]));
check(shown(E.ovList) && shown(app.PlotSections([app.PlotSections.Name] == "overlays").Toggle), ...
    'plots without overlays show the Overlays section: one can be added to all of them');
app.onAddOverlay("line");
E.ovValue.Value = '0.2';
app.onConfigChanged("plot");
check(ovAll(0.2) && app.Config.Plots(k3).overlays.name == "Line 1" && isempty(app.Config.Plots(1).overlays), ...
    'an overlay added with three plots selected is added to each of them, and an edit of it reaches each; the others are left alone');
cx = app.Config; cx.Plots(k2).overlays(1).value = 0.9; app.Config = cx;
app.syncPlotEditor();
hidden = ~shown(E.ovList) && ~shown(E.ovName);
cx.Plots(k2).overlays(1).value = 0.2; app.Config = cx;
app.syncPlotEditor();
check(hidden && shown(E.ovList) && shown(E.ovName), ...
    'plots that hold different overlays hide the section (an edit would give each the first''s list); the same ones show it again');
app.onRemoveOverlay();
check(all(arrayfun(@(k) isempty(app.Config.Plots(k).overlays), [k2 k3 kR])), 'Remove takes the overlay off all three');
E.fontSize.Value = 12;
app.onConfigChanged("plot");
check(all(arrayfun(@(k) app.Config.Plots(k).style.FontSize == 12, [k2 k3 kR])) && app.Config.Plots(1).style.FontSize ~= 12, ...
    'a font size set there reaches all three, not the plots left unselected');
E.rasterSort.Value = 'event'; E.sortLine.Value = 'RespWindow'; E.sortEdge.Value = 'offset';
app.onConfigChanged("plot");
sortsBy = @(k) app.Config.Plots(k).rasterSort == "event" && isstruct(app.Config.Plots(k).rasterSortEvent) ...
    && app.Config.Plots(k).rasterSortEvent.line == "RespWindow" && app.Config.Plots(k).rasterSortEvent.edge == "offset";
check(all(arrayfun(sortsBy, [k2 k3 kR])) && isempty(app.Config.Plots(1).rasterSortEvent), ...
    'sorting the rasters by an event there gives all three that sort event, though none had one');
n0 = numel(app.Config.Plots);
app.onDuplicatePlot();
ks = app.selectedPlots();
check(numel(app.Config.Plots) == n0 + 3 && numel(ks) == 3 && app.SelectedPlot == k3 + 2 ...
    && isequal(sort(ks), [k2+1, k3+2, kR+3]) && app.Config.Plots(k3 + 2).style.FontSize == 12, ...
    'Duplicate copies each selected plot right after itself and selects the copies');
app.onRemovePlot();
app.onPlotSelected([k2 k3 kR]);
app.onRemovePlot();
check(numel(app.Config.Plots) == n0 - 3 && isequal([app.Config.Plots.id], ["psth_1" "evoked_1"]) ...
    && isscalar(app.selectedPlots()) && ~shown(B.Text) && app.PlotEditorPanel.Title == "Plot" && shown(E.id), ...
    'Remove takes every selected plot; one plot left selected, the banner and bar are gone');
app.onPlotSectionToggled("bins");
app.onPlotSelected(1);
% --- Copy from...: another plot's settings onto the selected one, of another type ------------------
cx = app.Config; p1 = cx.Plots(1); cx.Plots(1).style.FontSize = 13; cx.Plots(1).bins.BinSec = 0.025; app.applyConfig(cx);
app.onAddPlot("raster");
kC = app.SelectedPlot;
idC = app.Config.Plots(kC).id;
check(app.CopyPlotButton.Enable == "on", 'Copy from... is on with a plot selected and another to copy from');
answerDialog('Copy plot settings', @copySettingsDialog);
app.onCopyPlotSettings();
seen = getappdata(groot, 'copySettingsSeen');
if isappdata(groot, 'copySettingsSeen'); rmappdata(groot, 'copySettingsSeen'); end
pC = app.Config.Plots(kC);
check(isstruct(seen) && ~seen.evokedMarks && seen.evokedStyle && seen.psthMarks && seen.count == "12 part(s) to copy", ...
    'the window offers only the parts the raster shares with the plot picked (no event marks from an evoked potential)');
check(pC.id == idC && pC.kind == "raster" && pC.style.FontSize == 13 && pC.bins.BinSec ~= 0.025 && E.fontSize.Value == 13 ...
    && app.SelectedPlot == kC && contains(string(app.StatusBar.Text), "Copied from psth_1"), ...
    'Copy gives the raster the PSTH''s ticked parts (its look), not the one unticked (bins); the editor shows them');
app.onCopyPlotSettings(From="psth_1", Parts="bins");
check(app.Config.Plots(kC).bins.BinSec == 0.025 && E.binMs.Value == 25, 'From= and Parts= copy without the window (the bins now)');
app.onRemovePlot();
cx = app.Config; cx.Plots(1) = p1; app.applyConfig(cx);   % psth_1 as it was
app.onPlotSelected(1);

fprintf('\n== 4. gather / apply, save / reopen, script ==\n');
c1 = app.gatherConfig();
app.applyConfig(c1);
c2 = app.gatherConfig();
check(c1.isequalConfig(c2), 'gatherConfig -> applyConfig -> gatherConfig is the same config');
c3 = c1;
c3.Defaults.Window.stop = struct('line', "Stim", 'edge', "offset", 'which', "nth", 'n', 2, 'scope', "trial", ...
    'offsetSec', 0.05, 'minDurationSec', 0.01, 'maxDurationSec', 5, 'timeRange', [0 60]);
c3.Defaults.Selection.trials = [1 3 5];
c3.Plots(1).window = c3.Defaults.Window;
c3.Plots(1).selection = c3.Defaults.Selection;
app.applyConfig(c3);
app.onConfigChanged("defaults");   % an edit re-gathers the config from the controls
c4 = app.gatherConfig();
check(c4.isequalConfig(c3) && app.AlignControls.StopN.Value == 2 && app.PlotAlignControls.StopN.Value == 2, ...
    'a re-gather keeps what has no control (the stop event''s offset, length and time range; trial rows) and the stop''s n');
app.applyConfig(c1);
outRoot = fullfile(root, 'out');
app.ExportControls.Folder.Value = fullfile(outRoot, '{Name}');
app.ExportControls.svg.Value = false;
app.ExportControls.png.Value = true;
app.ExportControls.Dpi.Value = 60;
app.ReportControls.Folder.Value = outRoot;
app.ReportControls.Dpi.Value = 50;
app.onConfigChanged("export");
cfgFile = fullfile(root, 'app_analysis.json');
ok = app.onSaveConfigAs(string(cfgFile));
check(ok && isfile(cfgFile) && ~startsWith(app.Fig.Name, "*") && app.Config.File == string(cfgFile), 'Save As writes the config and clears the marker');
app.onNewConfig();
check(isempty(app.Config.Plots) && app.Config.File == "", 'New config resets to the defaults');
ok = app.openConfigFile(cfgFile);
check(ok && numel(app.Config.Plots) == 2 && app.Config.Plots(1).bins.BinSec == 0.02 && ~isempty(app.Runner) ...
    && height(app.DatasetsTable.Data) == 2 && any(app.RecentConfigs == string(cfgFile)), ...
    sprintf('reopening restores the plots and rescans (ok %d, %d plots, BinSec %s, runner %d, %d datasets, recent %d)', ok, ...
    numel(app.Config.Plots), mat2str(arrayfun(@(q) q.bins.BinSec, app.Config.Plots)), ~isempty(app.Runner), height(app.DatasetsTable.Data), ...
    any(app.RecentConfigs == string(cfgFile))));
txt = EphysAnalysisScript.standalone(app.gatherConfig());
check(contains(txt, "spikePSTH(") && contains(txt, "evokedPotential(") && contains(txt, "spec1.ref.line = ""Trial"";"), ...
    'a standalone script from the app''s config');
scriptFile = fullfile(root, 'run_app_compact.m');
app.onGenerateScript("compact", string(scriptFile));
check(isfile(scriptFile) && contains(fileread(scriptFile), "EphysAnalysisConfig.load("), 'Generate script (compact) writes the file');

fprintf('\n== 5. run one plot ==\n');
app.selectTab(app.TabExport);
I = app.onValidate();
check(~any(I.Severity == "error"), 'the config validates');
P = app.onPlan();
check(height(P) == 4 && all(P.Enabled), 'Plan: both plots on both datasets');
app.selectTab(app.TabData);
app.IssuesTable.Data = table();
clickTool(app, "plan");
check(app.Tabs.SelectedTab == app.TabExport && height(app.IssuesTable.Data) == 4 && all(app.IssuesTable.Data.Enabled), ...
    'the toolbar''s Plan shows the Export tab and fills its table as the Plan button does');
R = app.onRunExport(Plots="psth_1");
files = dir(fullfile(outRoot, '**', '*psth_1*.png'));
check(height(R) == 2 && all(R.Status == "done") && numel(files) >= 2 && isfile(fullfile(outRoot, 'analysis_report.html')) ...
    && app.OpenReportButton.Enable == "on" && contains(app.RunLabel.Text, "2 done"), ...
    'Run (psth_1): figures for both datasets and the report');
check(app.ToolbarReportTool.Enable == "on" && app.ToolbarFolderTool.Enable == app.OpenFolderButton.Enable ...
    && app.ToolbarRunTool.Enable == "on" && app.ToolbarPlanTool.Enable == "on" && app.ToolbarCancelTool.Enable == "off", ...
    'after the run the toolbar''s report and figure-folder tools follow the Export tab''s buttons; Run is on again, Cancel off');
check(any(contains(string(app.LogArea.Value), "psth_1 done")), 'the Log tab has the runner''s lines');

fprintf('\n== 5b. the Chronux tab ==\n');
chronuxPath = "";
if ~ChronuxDataset.hasChronux()   % the bundled copy, only for this section: its findpeaks shadows MATLAB's
    chronuxPath = string(genpath(fullfile(repo, 'toolboxes', 'chronux')));
    addpath(chronuxPath);
end
k = app.ActiveIdx;
out = app.Runner.Outputs(k);
app.Tabs.SelectedTab = app.TabChronux;
app.onTabChanged();
check(app.ChronuxFile == "" && contains(app.ChronuxFileLabel.Text, "No Chronux file") ...
    && app.ChronuxCreateButton.Enable == "on" && app.ChronuxComputeButton.Enable == "off" ...
    && endsWith(app.helpURL("tab"), "#chronux-tab"), ...
    'a dataset without a Chronux file: Create on, Compute off; Help goes to the tab''s section');
o = app.onCreateChronuxExport(WithoutUnits=false);
C = app.ChronuxControls;
check(~isempty(o) && isfile(o.file) && endsWith(o.file, app.Runner.Names(k) + "_chronux.mat") ...
    && app.ChronuxFileWhere == "output" && contains(app.ChronuxFileLabel.Text, "In the output folder") ...
    && any(string(C.signal.Items) == "LFP") && numel(C.channels.Items) > 1 && app.ChronuxComputeButton.Enable == "on", ...
    'Create writes <Name>_chronux.mat into the output folder; the tab shows it, its signals and channels');
C.channels.Value = [1 2];
C.pre.Value = -0.2;
C.post.Value = 0.5;
C.TW.Value = 2;
C.K.Value = 3;
app.onChronuxEdited("compute");
R = app.onChronuxCompute();
nGroups = height(R.groups);
check(~isempty(R) && R.kind == "chronuxSpectrum" && size(R.S, 2) == 2 && nGroups > 1 && size(R.S, 3) == nGroups ...
    && app.ChronuxState == "drawn" && ~isempty(findobj(app.ChronuxPanel, 'Type', 'axes')) ...
    && app.ChronuxSaveResultsButton.Enable == "on" && contains(app.ChronuxControls.coverage.Text, "epochs"), ...
    'Compute: a spectrum of the two channels over the Alignment tab''s epochs, one per Depth group, drawn');
C.fmax.Value = 80;
app.onChronuxEdited("compute");
stale = app.ChronuxState == "stale";
C.scale.Value = "linear";
app.onChronuxEdited("display");
check(stale && app.ChronuxState == "stale" && ~isempty(findobj(app.ChronuxPanel, 'Type', 'axes')), ...
    'an edit of what is computed leaves the plot Out of date; a display edit redraws it, still Out of date');
C.analysis.Value = "specgram";
app.onChronuxEdited("analysis");
C.timeBase.Value = "range";
app.onChronuxEdited("timeBase");
sec = app.ChronuxSections;
check(sec([sec.Name] == "moving").Visible && ~sec([sec.Name] == "baseline").Visible ...
    && strcmp(C.from.Parent.Visible, 'on') && strcmp(C.segment.Visible, 'off'), ...
    'a spectrogram over a stretch shows the moving window, not the baseline or the segments');
R2 = app.onChronuxCompute();
check(~isempty(R2) && R2.kind == "chronuxSpecgram" && ~R2.aligned && app.ChronuxState == "drawn" ...
    && ~isempty(findobj(app.ChronuxPanel, 'Type', 'image')), 'a spectrogram over the whole recording, drawn');
fr = string(fullfile(root, 'chronux_result.mat'));
fp = string(fullfile(root, 'chronux_figure.png'));
app.onSaveChronuxResults(fr);
app.onSaveChronuxFigure(fp);
L = load(fr);
check(isfield(L, 'R') && L.R.kind == "chronuxSpecgram" && isfile(fp), 'Save results writes R; Save figure writes the page');
nSp = numel(app.ChronuxIndex.sp);
C.timeBase.Value = "aligned";
C.analysis.Value = "coherence";
app.onChronuxEdited("analysis");
app.onChronuxEdited("timeBase");
C.channels.Value = [1 2];
R7 = app.onChronuxCompute();
check(~isempty(R7) && R7.kind == "chronuxCoherence" && size(R7.C, 2) == 1 && R7.pairs.a == 1 && R7.pairs.b == 2 ...
    && size(R7.C, 3) > 1 && app.ChronuxState == "drawn" && numel(findall(app.ChronuxPanel, 'Tag', 'phase')) > 0 ...
    && strcmp(C.seed.Visible, 'on') && strcmp(C.overTime.Visible, 'on') && strcmp(C.partner.Visible, 'off'), ...
    'Compute: the coherence of the seed channel with the other channel picked, one per Depth group, phase drawn under it');
C.pairMode.Value = "pair";
C.partner.Value = C.partner.ItemsData(end);
app.onChronuxEdited("pairMode");
R7b = app.onChronuxCompute();
check(~isempty(R7b) && size(R7b.C, 2) == 1 && R7b.pairs.b == C.partner.ItemsData(end) && strcmp(C.partner.Visible, 'on'), ...
    'one partner: the seed with a channel that is not picked');
C.pairMode.Value = "seed";
C.overTime.Value = true;
app.onChronuxEdited("analysis");
R7c = app.onChronuxCompute();
check(~isempty(R7c) && R7c.kind == "chronuxCohgram" && R7c.aligned && ~isempty(findobj(app.ChronuxPanel, 'Type', 'image')) ...
    && app.ChronuxSections([app.ChronuxSections.Name] == "moving").Visible, 'over time: a coherogram over the moving window, drawn as an image');
C.overTime.Value = false;
C.analysis.Value = "spikeSpectrum";
app.onChronuxEdited("analysis");
check(nSp > 1 && numel(C.units.Items) == nSp && numel(C.unitSeed.ItemsData) == nSp && numel(C.fieldChannel.ItemsData) > 1 ...
    && strcmp(C.units.Visible, 'on') && strcmp(C.signal.Visible, 'off') && strcmp(C.channels.Visible, 'off') ...
    && strcmp(C.spikeFs.Visible, 'on') && app.ChronuxComputeButton.Enable == "on", ...
    'a spike analysis lists the file''s sorted units and shows the spike grid, not the signal and its channels');
R3 = app.onChronuxCompute();
check(~isempty(R3) && R3.kind == "chronuxSpikeSpectrum" && size(R3.S, 2) == nSp && size(R3.S, 3) > 1 ...
    && app.ChronuxState == "drawn" && ~isempty(findobj(app.ChronuxPanel, 'Type', 'axes')) ...
    && ~isempty(findall(app.ChronuxPanel, 'Tag', 'rateLine')), ...
    'Compute: a spike spectrum of every sorted unit over the Alignment tab''s epochs, one per Depth group, with its mean rates');
C.units.Value = C.units.ItemsData(1);
app.onChronuxEdited("compute");
R3b = app.onChronuxCompute();
check(~isempty(R3b) && size(R3b.S, 2) == 1 && isequal(R3b.index, 1), 'a unit picked: only its spectrum');
C.units.Value = {};
C.analysis.Value = "spikeField";
app.onChronuxEdited("analysis");
check(strcmp(C.signal.Visible, 'on') && strcmp(C.channels.Visible, 'off') && strcmp(C.fieldChannel.Visible, 'on'), ...
    'spike-field coherence shows the signal and its field channel, not the channel list');
C.fieldChannel.Value = C.fieldChannel.ItemsData(1);
R4 = app.onChronuxCompute();
check(~isempty(R4) && R4.kind == "chronuxSpikeField" && size(R4.C, 2) == nSp && R4.settings.fieldChannel == 1 ...
    && app.ChronuxState == "drawn" && numel(findall(app.ChronuxPanel, 'Tag', 'phase')) > 0, ...
    'Compute: the units'' coherence with the field channel, its phase drawn under it');
C.analysis.Value = "unitCoherence";
app.onChronuxEdited("analysis");
C.unitSeed.Value = C.unitSeed.ItemsData(1);
R5 = app.onChronuxCompute();
check(~isempty(R5) && R5.kind == "chronuxUnitCoherence" && size(R5.C, 2) == nSp - 1 && R5.settings.unitSeed == 1, ...
    'Compute: the seed unit''s coherence with every other unit');
C.pairMode.Value = "pair";
C.unitPartner.Value = C.unitPartner.ItemsData(2);
app.onChronuxEdited("pairMode");
R6 = app.onChronuxCompute();
check(~isempty(R6) && size(R6.C, 2) == 1 && R6.pairs.b == 2 && strcmp(C.unitPartner.Visible, 'on'), ...
    'one partner: the seed against it alone');
o3 = app.onCreateChronuxExport(WithoutUnits=true);
app.onChronuxEdited("analysis");
check(~isempty(o3) && o3.nUnits == 0 && app.ChronuxComputeButton.Enable == "off" && contains(C.about.Text, "no sorted units") ...
    && isempty(C.units.Items), ...
    'a file without units: the spike analyses cannot be computed, and the tab says why');
C.analysis.Value = "spectrum";
app.onChronuxEdited("analysis");
check(app.ChronuxComputeButton.Enable == "on", 'the continuous analyses still can');
app.onCreateChronuxExport(WithoutUnits=false);
C.pairMode.Value = "seed";
C.analysis.Value = "spectrum";
app.onChronuxEdited("analysis");
cache = string(fullfile(root, 'chronux cache'));
app.onChronuxCacheFolder(cache);
o2 = app.onCreateChronuxExport(Where="cache", WithoutUnits=false);
check(~isempty(o2) && startsWith(o2.file, cache) && isfile(o2.file) && endsWith(o2.file, app.Runner.Names(k) + "_chronux.mat") ...
    && string(AppPrefs.getpref(g, 'ChronuxCacheFolder')) == cache, ...
    'Create into the local cache: <cache>/<key>/<Name>_chronux.mat; the cache folder is remembered');
check(app.ChronuxFileWhere == "output", 'while the output folder has its file, that one is used');
delete(o.file);
out.refresh();
app.refreshChronuxTab();
check(app.ChronuxFileWhere == "cache" && app.ChronuxFile == o2.file && contains(app.ChronuxFileLabel.Text, "local cache"), ...
    'once the output folder''s file is gone, the cache''s is found');
app.Tabs.SelectedTab = app.TabData;
if chronuxPath ~= ""; rmpath(chronuxPath); end

fprintf('\n== 5c. the Sessions tab ==\n');
app.selectTab(app.TabSessions);
SE = app.SessionEditor;
check(isempty(app.Config.SessionPlots) && isempty(app.SessionList.Items) && app.SessionPreviewState == "idle" ...
    && isequal(string(app.AddSessionBaseDropDown.ItemsData), ["psth_1" "evoked_1"]) && app.RemoveSessionButton.Enable == "off" ...
    && ~shown(SE.id) && shown(SE.note) && endsWith(app.helpURL("tab"), "#sessions-tab") ...
    && startsWith(string(app.SessionCountLabel.Text), "Sessions: 2 ticked"), ...
    'the Sessions tab: no session plot yet, the PSTH and the evoked plot offered as bases, two datasets ticked; Help goes to its section');
app.AddSessionBaseDropDown.Value = "psth_1";
app.onAddSessionPlot();
sp = app.Config.SessionPlots;
check(isscalar(sp) && sp.plot == "psth_1" && sp.id == "psth_1_sessions_1" && app.SelectedSessionPlot == 1 ...
    && string(app.SessionList.Items{1}) == "psth_1_sessions_1  (psth_1)" && string(SE.id.Value) == sp.id ...
    && string(SE.plot.Value) == "psth_1" && string(SE.layout.Value) == "base" && startsWith(string(SE.kind.Text), "PSTH") ...
    && startsWith(app.Fig.Name, "*") && app.RemoveSessionButton.Enable == "on", ...
    'Add makes psth_1_sessions_1 on the chosen base plot, listed and shown in the editor; the config is unsaved');
grouped = ~isempty(app.Config.plotFor("psth_1").selection.groupBy);
check(shown(SE.series) && shown(SE.match) && shown(SE.minSessions) && ~shown(SE.showMembers) && ~shown(SE.error) ...
    && ~shown(SE.datasetKeys) && ~shown(SE.mappingFile) && shown(SE.trialGroups) == grouped && ~shown(SE.dataSignals) ...
    && shown(SE.toWorkspace) && SE.toWorkspace.Enable == "on", ...
    'a PSTH of units shows the matching rows, not the summary''s, the keys, the mapping file or the signals box');
SE.series.Value = "all";
SE.error.Value = "sd";
SE.showMembers.Value = true;
SE.minSessions.Value = 2;
SE.title.Value = 'Across days';
SE.dataEpochs.Value = true;
SE.match.Value = "mapping";
app.onConfigChanged("sessions");
sp = app.Config.SessionPlots(1);
check(sp.series == "all" && sp.error == "sd" && sp.showMembers && sp.minSessions == 2 && sp.title == "Across days" ...
    && isequal(sp.data, ["results" "epochs"]) && sp.match == "mapping" && shown(SE.showMembers) && shown(SE.error) ...
    && shown(SE.mappingFile) && shown(SE.editMapping), ...
    'edits reach the session plot; one mean shows the faint sessions and the error band, mapping the file row');
mapFile = string(fullfile(root, 'unit_mapping.csv'));
writelines(["cell," + strjoin(app.Runner.Keys, ","), "cellA,1,1"], mapFile);
app.onBrowseUnitMapping(mapFile);
check(app.Config.SessionPlots(1).mappingFile == mapFile && string(SE.mappingFile.Value) == mapFile, ...
    'Browse (a file given) puts the mapping file in the editor and the session plot');
s1 = app.gatherConfig();
app.applyConfig(s1);
s2 = app.gatherConfig();
check(s1.isequalConfig(s2) && isequaln(s1.SessionPlots, s2.SessionPlots) && string(SE.series.Value) == "all" ...
    && SE.minSessions.Value == 2 && string(SE.mappingFile.Value) == mapFile, ...
    'gatherConfig -> applyConfig -> gatherConfig keeps the session plot and the editor''s values');
SE.series.Value = "session";
SE.match.Value = "pool";
SE.minSessions.Value = 1;
app.onConfigChanged("sessions");
check(~shown(SE.showMembers) && ~shown(SE.error) && ~shown(SE.mappingFile), ...
    'a color per session and pooled units hide the summary rows and the mapping file again');
app.refreshSessionPreview();
res = app.SessionPreviewResults;
drawn = app.SessionPreviewState == "drawn" && string(app.SessionPreviewBadge.Text.Text) == "Drawn" && isscalar(res) ...
    && res(1).status == "done";
if drawn
    R = res(1).R;
    drawn = height(R.sessions) == 2 && height(R.groups) == 2;
end
nRate = numel(findall(app.SessionPreviewPanel, 'Tag', 'rate'));
check(drawn && nRate >= 2 && isempty(findall(app.SessionPreviewPanel, 'Tag', 'previewBusyCard')) ...
    && isempty(app.Runner.PollFcn) && string(app.Fig.Pointer) == "arrow" && app.SessionGroupDropDown.Parent.Visible == "off" ...
    && contains(string(app.SessionPreviewLabel.Text), "over 2 of 2 session"), ...
    sprintf('Preview computes psth_1 on both datasets and draws them merged, a color each (%d rate lines); one figure', nRate));
ctx = getappdata(app.SessionPreviewPanel, PlotAesthetics.ContextKey);
kP = app.Config.plotIndex("psth_1");
baseLook = app.Config.Plots(kP).aesthetics;
ctx.onRemember(look);
check(isstruct(ctx) && isscalar(app.Config.SessionPlots(1).aesthetics) && app.Config.SessionPlots(1).aesthetics.value == 0.4 ...
    && isequaln(app.Config.Plots(kP).aesthetics, baseLook) && app.SessionPreviewResults(1).R.spec.sessionAesthetics.value == 0.4, ...
    'a look remembered from the session preview goes to the session plot, not to its base plot');
app.onPlotSelected(kP);
app.PlotEditor.smoothMs.Value = app.PlotEditor.smoothMs.Value + 5;
app.onConfigChanged("plot");
check(app.SessionPreviewState == "stale" && string(app.SessionPreviewBadge.Text.Text) == "Out of date" ...
    && app.Tabs.SelectedTab == app.TabSessions, 'an edit of the base plot leaves the session preview Out of date (Auto is off)');
clickTool(app, "preview");
check(app.Tabs.SelectedTab == app.TabSessions && app.SessionPreviewState == "drawn" ...
    && ~isempty(findall(app.SessionPreviewPanel, 'Tag', 'rate')), ...
    'the toolbar''s Preview on the Sessions tab previews the session plot there');
% --- Duplicate, Up, Down ---------------------------------------------------------------------
app.onDuplicateSessionPlot();
P = app.Config.SessionPlots;
origId = P(1).id;
copyId = P(2).id;
check(numel(P) == 2 && copyId ~= origId && P(2).plot == P(1).plot && P(2).minSessions == P(1).minSessions && P(2).title == P(1).title ...
    && app.SelectedSessionPlot == 2 && string(SE.id.Value) == copyId && string(app.SessionList.Items{2}) == copyId + "  (psth_1)" ...
    && app.UpSessionButton.Enable == "on" && app.DownSessionButton.Enable == "off", ...
    'Duplicate copies the session plot under a new id, right after it, and selects the copy');
app.onMoveSessionPlot(-1);
check(isequal([app.Config.SessionPlots.id], [copyId origId]) && app.SelectedSessionPlot == 1 && string(SE.id.Value) == copyId ...
    && app.UpSessionButton.Enable == "off" && app.DownSessionButton.Enable == "on" && startsWith(string(app.SessionList.Items{1}), copyId), ...
    'Up moves the selected session plot up the list, and it stays selected');
app.onMoveSessionPlot(-1);   % already first: nothing
app.onMoveSessionPlot(1);
check(isequal([app.Config.SessionPlots.id], [origId copyId]) && app.SelectedSessionPlot == 2 && string(SE.id.Value) == copyId ...
    && app.DownSessionButton.Enable == "off", 'Down moves it back; Up on the first and Down on the last change nothing');
app.onRemoveSessionPlot();
check(isscalar(app.Config.SessionPlots) && app.Config.SessionPlots(1).id == origId && app.SelectedSessionPlot == 1, ...
    'Remove takes the copy away');

% --- the figure box: a figure per trial group ---------------------------------------------------
SE.trialGroups.Value = "each";
app.onConfigChanged("sessions");
app.refreshSessionPreview();
res = app.SessionPreviewResults;
dd = app.SessionGroupDropDown;
check(grouped && numel(res) >= 2 && numel(dd.ItemsData) == numel(res) && dd.Parent.Visible == "on" && app.SessionPreviewState == "drawn", ...
    sprintf('trial groups "a figure per group" on a base plot grouped by Depth: the figure box lists %d figures', numel(res)));
app.onSessionGroupChanged(2);
check(app.SessionPreviewIndex == 2 && ~isempty(findall(app.SessionPreviewPanel, 'Tag', 'rate')), ...
    'picking the second figure draws it from the results already computed');
SE.trialGroups.Value = "pool";
app.onConfigChanged("sessions");

% --- Pick datasets ---------------------------------------------------------------------------
keys = reshape(string(app.Runner.Keys), 1, []);
SE.datasets.Value = "list";
app.onConfigChanged("sessions");
check(app.Config.SessionPlots(1).datasets == "list" && shown(SE.datasetKeys) && shown(SE.pickDatasets) ...
    && startsWith(string(app.SessionCountLabel.Text), "Sessions: 0 listed"), ...
    '"These datasets" shows the keys box and Pick..., and no dataset is listed yet');
app.onPickSessionDatasets(Keys=keys(2));
check(isequal(app.Config.SessionPlots(1).datasetKeys, keys(2)) && string(SE.datasetKeys.Value) == keys(2) ...
    && startsWith(string(app.SessionCountLabel.Text), "Sessions: 1 listed"), ...
    'Pick (keys given) writes datasetKeys into the editor and the config; the sessions line follows');
tm = answerDialog('Pick the datasets', @(D) press(D, ["All" "Ok"]));
app.onPickSessionDatasets();
delete(tm);
T = app.Runner.sessionTable();
check(isequal(app.Config.SessionPlots(1).datasetKeys, reshape(T.key, 1, [])) && startsWith(string(app.SessionCountLabel.Text), "Sessions: 2 listed"), ...
    'the Pick window (answered by a timer): All, then OK, lists both datasets in date order');
tm = answerDialog('Pick the datasets', @(D) press(D, ["None" "Cancel"]));
app.onPickSessionDatasets();
delete(tm);
check(numel(app.Config.SessionPlots(1).datasetKeys) == 2, 'Cancel in the Pick window changes nothing');
tm = answerDialog('Pick the datasets', @(D) press(D, ["None" "Ok"]));
app.onPickSessionDatasets();
delete(tm);
check(isempty(app.Config.SessionPlots(1).datasetKeys) && isempty(SE.datasetKeys.Value), 'None, then OK, lists no dataset');
app.onPickSessionDatasets(Keys=keys);

% --- Edit mapping ------------------------------------------------------------------------------
oldMap = string(fullfile(root, 'unit_mapping_edit.csv'));
extra = "OTHER/260101_000000";
writelines(["cell," + strjoin(keys, ",") + "," + extra, "cellA,1,2,X1", "cellB,3 4,,X2"], oldMap);
tm = answerDialog('Unit mapping: unit_mapping_edit.csv', @editMappingDialog);
app.onEditUnitMapping(File=oldMap);
delete(tm);
M = readUnitMapping(oldMap);
check(isequal(string(M.Properties.VariableNames), ["cell" keys extra]) && isequal(string(M.cell), ["cellA"; "cellC"]) ...
    && isequaln(M.(keys(1)), [5; NaN]) && isequaln(M.(keys(2)), [NaN; 9]) && M.(extra)(1) == "X1" && ismissing(M.(extra)(2)) ...
    && app.Config.SessionPlots(1).mappingFile == oldMap && string(SE.mappingFile.Value) == oldMap, ...
    'Edit mapping (the window answered by a timer): edit a field, add a row, remove a row, Save; the other dataset''s column is kept for the cell that stayed');
noneMap = oldMap + ".new.csv";
app.onEditUnitMapping(File=noneMap, Table=table(["x"; "y"], [10; NaN], ["3 7"; "8"], 'VariableNames', {'cell', char(keys(1)), char(keys(2))}));
M2 = readUnitMapping(noneMap);
check(isequal(string(M2.cell), ["x"; "y"]) && isequaln(M2.(keys(1)), [10; NaN]) && isequal(string(M2.(keys(2))), ["3 7"; "8"]) ...
    && app.Config.SessionPlots(1).mappingFile == noneMap && string(SE.mappingFile.Value) == noneMap, ...
    'Edit mapping (a table given) writes it straight away, as readUnitMapping reads it back, and puts the file in the editor');
delete(noneMap);
bad = false;
try
    app.onEditUnitMapping(File=oldMap, Table=table(["x"; "x"], [1; 2], [3; 4], 'VariableNames', {'cell', char(keys(1)), char(keys(2))}));
catch ME
    bad = ME.identifier == "EphysAnalysisApp:UnitMapping";
end
check(bad && height(readUnitMapping(oldMap)) == 2, 'a mapping with two cells of one name is refused and the file is left as it was');

% --- a session plot that matches by the mapping ---------------------------------------------------
pspec = app.Config.sessionPlotFor(app.Config.SessionPlots(1).id);
ids = cell(1, 2);
for j = 1:2
    [~, meta] = selectUnits(app.Runner.source(app.Runner.index(keys(j))), pspec.units, Ref=pspec.ref, Selection=pspec.selection);
    ids{j} = meta.unitId(1:min(2, height(meta)));
end
nCells = min(numel(ids{1}), numel(ids{2}));
cellNames = "cell" + string(char('A' + (0:nCells - 1)).');
mapFile = string(fullfile(root, 'unit_mapping_ids.csv'));
app.onEditUnitMapping(File=mapFile, Table=table(cellNames, ids{1}(1:nCells), ids{2}(1:nCells), 'VariableNames', {'cell', char(keys(1)), char(keys(2))}));
check(nCells >= 2 && app.Config.SessionPlots(1).mappingFile == mapFile, ...
    sprintf('a mapping of %d cells, the first units of each dataset, written for the session plot', nCells));
SE.datasets.Value = "ticked";
SE.match.Value = "mapping";
app.onConfigChanged("sessions");
app.refreshSessionPreview();
res = app.SessionPreviewResults;
ok = app.SessionPreviewState == "drawn" && isscalar(res) && res(1).status == "done";
if ok
    R = res(1).R;
    ok = R.tiles.match == "mapping" && isequal(string(R.meta.cell), cellNames) && all(R.tiles.nUnits(:) == 1) && size(R.rate, 2) == nCells;
end
check(ok && ~isempty(findall(app.SessionPreviewPanel, 'Tag', 'rate')), ...
    'a session plot with match "mapping" previews over the fixture with that CSV: a tile per cell, one unit of each dataset on it');
SE.match.Value = "pool";
app.onConfigChanged("sessions");

% --- the data buttons -----------------------------------------------------------------------------
sid = app.Config.SessionPlots(1).id;
vname = string(matlab.lang.makeValidName("sessions_" + sid));
S = app.onSessionsToWorkspace(sid, Variable=vname);
W = evalin('base', char(vname));
evalin('base', "clear " + vname);
check(isstruct(S) && isstruct(W) && W.schema == "ephys-analysis-sessions/1" && height(W.sessions) == 2 && ~isempty(W.epochs) ...
    && W.results(1).R.kind == "psth", 'To workspace puts sessions_<id> in the base workspace: the merged and per-session results, and the epochs');
dataFile = string(fullfile(root, 'sessions_data.mat'));
out = app.onSaveSessionData(sid, File=dataFile);
L = load(dataFile);
check(out == dataFile && isfield(L, 'schema') && L.schema == "ephys-analysis-sessions/1" && height(L.sessions) == 2 && numel(L.results) == 1, ...
    'Save .mat (a file given) writes the data; load gives schema, sessions and results');

% --- the Export tab shows the session figures -------------------------------------------------------
R = app.onRunExport(Plots="psth_1");
row = find(startsWith(string(R.Dataset), "sessions: "));
T = app.ResultsTable.Data;
files = string.empty;
if isscalar(row)
    files = split(R.Files(row), "; ");
    files = files(endsWith(files, ".png"));
end
check(isscalar(row) && R.Status(row) == "done" && ~isempty(files) && isfile(files(1)) && contains(files(1), sid) ...
    && height(T) == height(R) && all(ismember(["Subject" "Date"], string(T.Properties.VariableNames))) ...
    && T.Subject(string(T.Dataset) == R.Dataset(row)) == "" && T.Date(string(T.Dataset) == R.Dataset(row)) == "", ...
    'a run with a session plot: a "sessions: ..." row with its figure, and the results table shows it without a subject or date');
check(~isempty(files) && contains(string(app.OpenFolderButton.Tooltip), string(fileparts(files(1)))), ...
    'Open figure folder''s tooltip names the sessions folder');
app.SessionAutoCheckBox.Value = true;
app.onSessionAutoPreviewToggled();   % keeps the preference; draws now
app.onSessionSectionToggled("data");
app.savePreferences();
saved = isequal(AppPrefs.getpref(g, 'SessionAutoPreview'), true) ...
    && isequal(string(AppPrefs.getpref(g, 'SessionSectionsCollapsed')), "data");
check(saved && app.SessionPreviewState == "drawn" && ~app.SessionSections([app.SessionSections.Name] == "data").Expanded, ...
    'Auto and a collapsed section of the Sessions tab are kept as preferences');
app.onRemoveSessionPlot();
check(isempty(app.Config.SessionPlots) && isempty(app.SessionList.Items) && app.SessionPreviewState == "idle" ...
    && ~shown(SE.id) && app.RemoveSessionButton.Enable == "off", 'Remove takes the session plot away; the editor and preview are empty');
app.onSaveConfig();
app2 = EphysAnalysisApp();
restored = app2.SessionAutoCheckBox.Value && ~app2.SessionSections([app2.SessionSections.Name] == "data").Expanded ...
    && app2.SessionSections([app2.SessionSections.Name] == "sessions").Expanded;
closeApp(app2);
check(~startsWith(app.Fig.Name, "*") && restored, 'a new app restores the Sessions tab''s Auto and collapsed section');
app.Tabs.SelectedTab = app.TabData;

fprintf('\n== 5d. the Figures tab ==\n');
app.selectTab(app.TabFigures);
FE = app.FigureEditor;
FA = app.FigureAlignControls;
FP = app.PanelAlignControls;
figAxes = @() findall(app.FigurePreviewPanel, 'Type', 'axes', '-regexp', 'Tag', '^(axes|rasterAxes)$');
figTitle = @() strjoin(string(findall(app.FigurePreviewPanel, 'Type', 'tiledlayout').Title.String), " ");
nPatches = @() numel(findall(app.FigureSchematic, 'Type', 'patch'));
check(isempty(app.Config.Figures) && isempty(app.FigureList.Items) && ~shown(FE.id) && shown(FE.summary) ...
    && app.FigurePreviewState == "idle" && endsWith(app.helpURL("tab"), "#figures-tab") && app.RemoveFigureButton.Enable == "off" ...
    && string(app.FigureTemplateDropDown.Value) == "rasterPsth", ...
    'the Figures tab: no figure yet, only a hint in the editor, no preview, "Raster over PSTH" offered first; Help goes to its section');
app.onAddFigure(string(app.FigureTemplateDropDown.Value));
fg = app.Config.Figures;
check(isscalar(fg) && fg.id == "figure_1" && numel(fg.panels) == 2 && app.SelectedFigure == 1 && app.SelectedPanel == 1 ...
    && nPatches() == 2 && string(app.FigureList.Items{1}) == "figure_1  (2 panels, per unit)" && string(FE.id.Value) == "figure_1" ...
    && startsWith(app.Fig.Name, "*"), ...
    'Add makes figure_1 from the template: two panels, two patches in the schematic, listed per unit; the config is unsaved');
spec = app.Config.figureFor(1);
T0 = figureObservations(app.Runner.source(app.ActiveIdx), spec);
T = app.FigureObservations;
check(istable(T) && height(T) >= 2 && isequal(T.label, T0.label) && all(T.kind == "unit") ...
    && isequal(reshape(string(app.FigureObservationDropDown.Items), [], 1), T.label) && app.FigureObservationDropDown.Value == 1 ...
    && app.FigurePreviewState == "drawn" && numel(figAxes()) == 2 && app.FigurePreviewResult.observation.label == T.label(1) ...
    && app.FigureObsPrevButton.Enable == "off" && app.FigureObsNextButton.Enable == "on" && contains(figTitle(), T.label(1)), ...
    sprintf('the picker lists the dataset''s %d units and the preview draws the first at once, in two axes (%s)', height(T), T.label(1)));
app.onFigureObservationStep(1);
check(app.FigureObservationDropDown.Value == 2 && app.FigurePreviewState == "drawn" && contains(figTitle(), T.label(2)) ...
    && string(app.FigureObservation('figure_1')) == T.label(2) && app.FigureObsPrevButton.Enable == "on", ...
    '> draws the next unit: the title names it, and the figure remembers its pick');
app.onKeyPress(pressed('pageup', {}));
check(app.FigureObservationDropDown.Value == 1 && contains(figTitle(), T.label(1)), 'Page Up (<) goes back to the first unit');
app.onPanelSelected(2);
FE.addType.Value = "continuous";
FE.addType.ValueChangedFcn(FE.addType, []);
app.onAddPanel("below");
fg = app.Config.Figures(1);
p3 = fg.panels(end);
check(fg.grid.rows == 3 && fg.grid.cols == 1 && p3.type == "continuous" && p3.row == 3 && isscalar(p3.layers) ...
    && p3.layers.source == "LFP" && p3.layers.binding == "observation" && app.SelectedPanel == 3 && nPatches() == 3 ...
    && app.FigurePreviewState == "drawn" && numel(figAxes()) == 3 && contains(app.StatusBar.Text, "below psth_1"), ...
    'Continuous signal, Below: a 3 x 1 stack whose new panel''s LFP layer follows the observed unit, drawn at once');
check(string(FE.panelType.Value) == "continuous" && shown(FE.contDisplay) && shown(FE.errorType) && shown(FE.layerFollows) ...
    && ~shown(FE.binMs) && ~shown(FE.histStyle) && ~shown(FE.rasterSort) && ~shown(FE.evLine) && ~shown(FE.group) ...
    && FE.layerBinding.Enable == "on" && contains(string(FE.layerFollows.Text), "own LFP channel") ...
    && app.FigureSections([app.FigureSections.Name] == "options").Title == "Continuous signal options", ...
    'the editor shows the continuous panel''s rows only: its options, its layer following the unit');
app.onPanelSelected(1);
check(shown(FE.rasterSort) && shown(FE.waveMode) && ~shown(FE.contDisplay) && ~shown(FE.binMs) && FE.panelSame.Enable == "on", ...
    'a raster shows its own rows instead');
FE.addSource.Value = "events";
FE.addSource.ValueChangedFcn(FE.addSource, []);
app.onAddLayer();
check(app.SelectedLayer == 2 && shown(FE.evLine) && shown(FE.evDrawAs) && shown(FE.evMarker) && ~shown(FE.layerFollows) ...
    && FE.layerBinding.Enable == "off" && string(FE.layerBinding.Value) == "fixed" && numel(FE.layerList.Items) == 2, ...
    'Add an events layer to the raster: its line, edge, sequence and marks show; it is always fixed');
FE.evLine.Value = 'Stim';
FE.evEdge.Value = 'offset';
app.onConfigChanged("figure");
L = app.Config.Figures(1).panels(1).layers(2);
marks = findall(app.FigurePreviewPanel, 'Tag', 'rasterEvent');
nMarks = 0;
for m = reshape(marks, 1, [])
    nMarks = nMarks + nnz(isfinite(m.XData));
end
check(L.source == "events" && L.binding == "fixed" && L.event.line == "Stim" && L.event.edge == "offset" && L.eventsAs == "marks" ...
    && app.FigurePreviewState == "drawn" && nMarks > 0, sprintf('Stim offset marks are drawn on the raster''s rows (%d marks)', nMarks));
app.onFigureSectionToggled("observations");
collapsed = ~app.FigureSections([app.FigureSections.Name] == "observations").Expanded;
app.onKeyPress(pressed('1', {'control'}));
check(collapsed && app.FigureSections([app.FigureSections.Name] == "observations").Expanded ...
    && app.FigureSections([app.FigureSections.Name] == "observations").Key == "1" ...
    && app.FigureSections([app.FigureSections.Name] == "style").Key == "0", ...
    'Ctrl+1 opens the collapsed Observations section; Appearance is Ctrl+0');
% Out of date with Auto off, Cancel
app.FigureAutoCheckBox.Value = false;
FE.title.Value = 'Unit card';
app.onConfigChanged("figure");
stale = app.FigurePreviewState == "stale" && string(app.FigurePreviewBadge.Text.Text) == "Out of date" && app.Config.Figures(1).title == "Unit card";
app.FigureAutoCheckBox.Value = true;
app.refreshFigurePreview(Force=true);
check(stale && app.FigurePreviewState == "drawn" && contains(figTitle(), "Unit card"), ...
    'with Auto off an edit leaves the preview Out of date; Preview draws it with the new title');
FE.title.Value = '';
app.onConfigChanged("figure");
tm = timer('ExecutionMode', 'fixedRate', 'Period', 0.005, 'TimerFcn', @(~, ~) app.onCancelFigurePreview());   % a click on the busy card's Cancel
start(tm);
app.refreshFigurePreview(Force=true);
stop(tm); delete(tm);
check(app.FigurePreviewState == "canceled" && string(app.FigurePreviewBadge.Text.Text) == "Canceled" && isempty(app.FigurePreviewResult) ...
    && isempty(findall(app.FigurePreviewPanel, 'Tag', 'previewBusyCard')) && isempty(app.Runner.PollFcn) ...
    && ~isfinite(app.FigurePreviewSeconds) && string(app.Fig.Pointer) == "arrow", ...
    'Cancel on the busy card stops the figure preview while it computes: Canceled, the card and the polling gone');
app.autoFigurePreview();
canceled = app.FigurePreviewState == "canceled";
app.refreshFigurePreview(Force=true);
check(canceled && app.FigurePreviewState == "drawn" && numel(figAxes()) == 3, 'an edit does not redraw a canceled preview; Preview does');
% the figure's own event, a panel's own window
FA.Edge.Value = 'offset';
app.onFigureAlignEdited("ref");
fg = app.Config.Figures(1);
check(isstruct(fg.ref) && fg.ref.edge == "offset" && ~FE.defaultRef.Value && isequal(fg.window, "default") && FE.defaultWindow.Value ...
    && app.Config.Defaults.EventRef.edge == "onset" && app.FigurePreviewState == "drawn" && contains(figTitle(), "Stim offset") ...
    && string(FP.Edge.Value) == "offset", ...
    'an edit of the figure''s event gives it its own (the defaults unchanged); the preview and the panel''s alignment follow');
FE.defaultRef.Value = true;
app.onFigureDefaultToggled();
check(isequal(app.Config.Figures(1).ref, "default") && string(FA.Edge.Value) == "onset", 'Use default goes back to the Alignment tab''s event');
app.onPanelSelected(3);
locked = FE.panelSame.Value && FP.Post.Enable == "off" && FP.Line.Enable == "off" && FE.alignApplyAll.Enable == "off" ...
    && FE.alignRelinkAll.Enable == "off";
FP.Post.Value = 0.5;
app.onPanelAlignEdited("window");   % as if an edit came in: ignored while the panel is linked
check(locked && isequal(app.Config.Figures(1).panels(3).window, "default") && FE.panelSame.Value, ...
    'while "Same as the figure" is ticked the panel''s rows are locked, and an edit does not detach it');
FA.Post.Value = 0.9;
app.onFigureAlignEdited("window");
spec = app.Config.figureFor(1);
check(isstruct(app.Config.Figures(1).window) && spec.panels(3).window.post == 0.9 && spec.panels(3).sharesTime ...
    && FP.Post.Value == 0.9 && app.FigurePreviewState == "drawn" && app.FigurePreviewResult.spec.panels(3).window.post == 0.9, ...
    'an edit of the figure''s Epoch window reaches the linked panel (its rows show it) and the preview is computed again');
FE.panelSame.Value = false;
app.onPanelDefaultToggled();
spec = app.Config.figureFor(1);
p3 = app.Config.Figures(1).panels(3);
check(isstruct(p3.ref) && isstruct(p3.window) && p3.window.post == 0.9 && p3.ref.line == spec.ref.line && p3.ref.edge == spec.ref.edge ...
    && FP.Post.Enable == "on" && FE.alignApplyAll.Enable == "on" && FE.alignRelinkAll.Enable == "on" && ~spec.panels(3).sharesTime, ...
    'unticking copies the figure''s current event and window into the panel and opens its rows');
FP.Post.Value = 0.5;
app.onPanelAlignEdited("window");
p3 = app.Config.Figures(1).panels(3);
check(p3.window.post == 0.5 && app.Config.figureFor(1).panels(1).window.post == 0.9 && app.FigurePreviewState == "drawn", ...
    'an edit then changes this panel''s own window only');
app.onPanelSelected(1);
FE.panelSame.Value = false;
app.onPanelDefaultToggled();   % the raster's own copy too
app.onPanelSelected(3);
FE.alignApplyAll.ButtonPushedFcn(FE.alignApplyAll, []);
fg = app.Config.Figures(1);
relinked = arrayfun(@(q) isequal(q.ref, "default") && isequal(q.window, "default"), fg.panels);
check(isstruct(fg.window) && fg.window.post == 0.5 && all(relinked) && FE.panelSame.Value && FA.Post.Value == 0.5 ...
    && app.Config.figureFor(1).panels(1).window.post == 0.5 && contains(app.StatusBar.Text, "are now the figure's") ...
    && FE.alignRelinkAll.Enable == "off", ...
    'Apply to all panels makes this panel''s window the figure''s and links every panel (the raster''s own dropped)');
FE.panelSame.Value = false;
app.onPanelDefaultToggled();
FP.Post.Value = 0.6;
app.onPanelAlignEdited("window");
own = isstruct(app.Config.Figures(1).panels(3).window);
FE.alignRelinkAll.ButtonPushedFcn(FE.alignRelinkAll, []);
fg = app.Config.Figures(1);
check(own && isequal(fg.panels(3).window, "default") && isequal(fg.panels(3).ref, "default") && fg.window.post == 0.5 ...
    && FE.panelSame.Value && FP.Post.Value == 0.5 && contains(app.StatusBar.Text, "Re-linked 1 panel"), ...
    'Re-link all panels drops a panel''s own window: it follows the figure''s again');
FE.defaultWindow.Value = true;
app.onFigureDefaultToggled();
check(isequal(app.Config.Figures(1).window, "default") && FP.Post.Value == app.Config.figureFor(1).window.post, ...
    'the figure''s window back to the default, the linked panel''s rows follow');
% a tightened unit filter
n0 = height(app.FigureObservations);
FE.obsMaxUnits.Value = '1';
app.onConfigChanged("figure");
n1 = height(app.FigureObservations);
check(app.Config.Figures(1).observe.units.maxUnits == 1 && n1 == 1 && numel(app.FigureObservationDropDown.Items) == 1 ...
    && startsWith(string(FE.obsCount.Text), "1 unit on") && app.FigureObsNextButton.Enable == "off", ...
    sprintf('Max units 1 shrinks the picker from %d units to %d', n0, n1));
FE.obsMaxUnits.Value = 'Inf';
app.onConfigChanged("figure");
check(height(app.FigureObservations) == n0, 'and Inf lists them all again');
FE.obsIds.Value = '999';
app.onConfigChanged("figure");
U = app.FigureObservationDropDown.UserData;
check(isempty(app.FigureObservations) && startsWith(string(app.FigureObservationDropDown.Items{1}), "(no unit") ...
    && isstruct(U) && isfield(U, 'key') && U.error == "" && app.FigurePreviewState == "skipped", ...
    'a filter no unit passes: an empty picker, kept (not listed again on every edit), and nothing drawn');
FE.obsIds.Value = '';
app.onConfigChanged("figure");
U = app.FigureObservationDropDown.UserData;
U.error = "Cannot list the observations: a test error";
app.FigureObservationDropDown.UserData = U;   % as when figureObservations throws
app.FigureObservations = [];
app.refreshFigurePreview(Force=true);
check(app.FigurePreviewState == "failed" && contains(string(app.FigurePreviewLabel.Text), "a test error"), ...
    'when the observations cannot be listed, the preview says why');
app.refreshFigureObservations(Force=true);
app.refreshFigurePreview(Force=true);
check(height(app.FigureObservations) == n0 && app.FigurePreviewState == "drawn", 'listed again, the figure draws');
% a type change
app.onPanelSelected(2);
FE.binMs.Value = 20;
app.onConfigChanged("figure");
FE.panelType.Value = "heatmap";
app.onPanelTypeChanged();
p2 = app.Config.Figures(1).panels(2);
check(p2.type == "heatmap" && isscalar(p2.layers) && p2.layers.source == "units" && p2.layers.binding == "fixed" ...
    && p2.options.bins.BinSec == 0.02 && isfield(p2.options, 'order') && shown(FE.group) && shown(FE.order) ...
    && contains(app.StatusBar.Text, "is now a heat map") && app.FigurePreviewState == "drawn", ...
    'a heat map now: its units layer kept but fixed, the bins it shares kept, its own rows shown');
FE.panelType.Value = "psth";
app.onPanelTypeChanged();
backFollows = app.Config.Figures(1).panels(2).layers(1).binding == "observation" ...
    && contains(app.StatusBar.Text, "now follows the observation") && string(FE.layerBinding.Value) == "observation";
FE.layerBinding.Value = "observation";
app.onConfigChanged("figure");
check(backFollows && app.Config.Figures(1).panels(2).type == "psth" && app.Config.Figures(1).panels(2).layers(1).binding == "observation", ...
    'back to a PSTH, its layer follows the unit again by itself (the heat map could only fix it), and the status bar says so');
Tobs = app.FigureObservations;
obsId = Tobs.unitId(app.FigureObservationDropDown.Value);
FE.layerBinding.Value = "fixed";
FE.layerBinding.ValueChangedFcn(FE.layerBinding, struct('Value', "fixed", 'PreviousValue', "observation"));
L2 = app.Config.Figures(1).panels(2).layers(1);
check(L2.binding == "fixed" && isequal(L2.units.ids, obsId) && string(FE.layerIds.Value) == string(obsId) ...
    && startsWith(app.StatusBar.Text, "Fixed to unit " + obsId) && app.FigurePreviewState == "drawn", ...
    sprintf('Binding Fixed on the PSTH''s units layer keeps the observed unit: ids = %d', obsId));
FE.layerBinding.Value = "observation";
FE.layerBinding.ValueChangedFcn(FE.layerBinding, struct('Value', "observation", 'PreviousValue', "fixed"));
L2 = app.Config.Figures(1).panels(2).layers(1);
check(L2.binding == "observation" && isequal(L2.units.ids, obsId), 'following again, the layer keeps the ids as they are');
FE.layerIds.Value = '';
app.onConfigChanged("figure");
% the gather / apply round trip, a remembered look
s1 = app.gatherConfig();
app.applyConfig(s1);
s2 = app.gatherConfig();
check(isequaln(s1.Figures, s2.Figures) && s1.isequalConfig(s2) && app.SelectedFigure == 1 && app.SelectedPanel == 2, ...
    'gatherConfig -> applyConfig -> gatherConfig keeps the figure and the panel picked');
app.refreshFigurePreview(Force=true);
ctx = getappdata(app.FigurePreviewPanel, PlotAesthetics.ContextKey);
figLook = struct('role', "rateFill", 'group', "", 'property', "FaceAlpha", 'value', 0.4);
ctx.onRemember(figLook);
check(isstruct(ctx) && ctx.kind == "figure" && ctx.id == "figure_1" && isscalar(app.Config.Figures(1).aesthetics) ...
    && app.Config.Figures(1).aesthetics.value == 0.4 && isequal(app.Runner.Config.Figures(1).aesthetics, app.Config.Figures(1).aesthetics) ...
    && startsWith(string(FE.looksText.Text), "1 remembered") && FE.looksForget.Enable == "on", ...
    'the figure preview is editable (right-click); rules remembered for the figure go into the config (rememberFigureAesthetics)');
FE.looksForget.ButtonPushedFcn(FE.looksForget, []);
check(isempty(app.Config.Figures(1).aesthetics) && FE.looksForget.Enable == "off" && app.FigurePreviewState == "drawn", ...
    'Forget drops them and redraws the preview without them');
% another config opened; sizes the spinners cannot show
cfgA = app.gatherConfig();
saved0 = app.SavedConfigStruct;
other = EphysAnalysisConfig();
other = other.addFigure("continuous", Id="figure_1");
cfgB = cfgA;
cfgB.Figures = other.Figures;
app.FigureAutoCheckBox.Value = false;
app.applyConfig(cfgB, MarkSaved=true);
check(app.FigurePreviewState == "stale" && isempty(app.FigurePreviewResult) && isempty(figAxes()) ...
    && ~isappdata(app.FigurePreviewPanel, PlotAesthetics.ContextKey), ...
    'another config opened: the last config''s drawing and its look editor are dropped; the preview is Out of date');
app.FigureAutoCheckBox.Value = true;
app.applyConfig(cfgA);
app.SavedConfigStruct = saved0;
app.updateTitle();
rows0 = app.Config.Figures(1).grid.rowHeights;
cfgC = app.gatherConfig();
cfgC.Figures(1).grid.rowHeights = [0.2 0.8 ones(1, cfgC.Figures(1).grid.rows - 2)];
app.applyConfig(cfgC);
app.onPanelSelected(1);
name0 = app.ConfigNameField.Value;
app.ConfigNameField.Value = [name0 ' (2)'];
app.onConfigChanged("name");
check(isequal(app.Config.Figures(1).grid.rowHeights(1:2), [0.2 0.8]) && FE.rowHeight.Value == 0.2, ...
    'a row height the old spinner limits did not take (0.2) survives an edit elsewhere');
app.ConfigNameField.Value = name0;
cfgC = app.gatherConfig();
cfgC.Figures(1).grid.rowHeights = rows0;
app.applyConfig(cfgC);
app.refreshFigurePreview(Force=true);
% Remove panel, Duplicate
app.onPanelSelected(3);
app.onRemovePanel();
fg = app.Config.Figures(1);
check(fg.grid.rows == 2 && numel(fg.panels) == 2 && nPatches() == 2 && app.SelectedPanel == 2 && numel(figAxes()) == 2 ...
    && app.FigurePreviewState == "drawn", 'Remove panel takes the continuous panel and its row away');
app.onDuplicateFigure();
check(numel(app.Config.Figures) == 2 && app.Config.Figures(2).id == "figure_2" && app.SelectedFigure == 2 ...
    && isequaln(rmfield(app.Config.Figures(2), 'id'), rmfield(app.Config.Figures(1), 'id')) && string(FE.id.Value) == "figure_2", ...
    'Duplicate copies the figure as figure_2, right after it, and selects the copy');
app.onRemoveFigure();
check(isscalar(app.Config.Figures) && app.SelectedFigure == 1 && string(FE.id.Value) == "figure_1", 'Remove takes the copy away');
% the arrangement, on a blank figure (Auto off: nothing here needs drawing)
app.FigureAutoCheckBox.Value = false;
app.onAddFigure("blank");
pickType = @(t) FE.addType.ValueChangedFcn(FE.addType, struct('Value', t));
cellOf = @(id) arrayfun(@(q) [q.row q.col q.rowSpan q.colSpan], app.Config.Figures(2).panels([app.Config.Figures(2).panels.id] == id), ...
    'UniformOutput', false);
gridOf = @() [app.Config.Figures(2).grid.rows app.Config.Figures(2).grid.cols];
FE.addType.Value = "psth"; pickType("psth");
app.onAddPanel("right");
check(app.SelectedFigure == 2 && isequal(gridOf(), [1 1]) && isequal(cellOf("psth_1"), {[1 1 1 1]}), ...
    'a blank figure''s first panel goes to row 1, column 1, whichever button');
FE.addType.Value = "raster"; pickType("raster");
app.onAddPanel("above");
check(isequal(gridOf(), [2 1]) && isequal(cellOf("raster_1"), {[1 1 1 1]}) && isequal(cellOf("psth_1"), {[2 1 1 1]}) ...
    && app.Config.Figures(2).panels(app.SelectedPanel).id == "raster_1", 'Above: a row before the selected panel; the new one is selected');
app.onAddPanel("right");
check(isequal(gridOf(), [2 2]) && isequal(cellOf("raster_2"), {[1 2 1 1]}) && isequal(cellOf("psth_1"), {[2 1 1 1]}), ...
    'Right: a column after it, in its row');
app.onAddPanel("left");
check(isequal(gridOf(), [2 3]) && isequal(cellOf("raster_3"), {[1 2 1 1]}) && isequal(cellOf("raster_2"), {[1 3 1 1]}) ...
    && nPatches() == 4, 'Left: a column before it; the panels right of it move over');
app.onPanelSelected(find([app.Config.Figures(2).panels.id] == "psth_1"));
FE.colSpan.Value = 3;
FE.colSpan.ValueChangedFcn(FE.colSpan, struct('PreviousValue', 1, 'Value', 3));
check(isequal(cellOf("psth_1"), {[2 1 1 3]}), 'Column span 3: the bottom panel spans the three columns');
FE.rowSpan.Value = 2;
FE.rowSpan.ValueChangedFcn(FE.rowSpan, struct('PreviousValue', 1, 'Value', 2));
check(isequal(cellOf("psth_1"), {[2 1 1 3]}) && FE.rowSpan.Value == 1 && contains(app.StatusBar.Text, "cannot span past"), ...
    'a row span past the grid''s last row is refused');
app.onPanelSelected(find([app.Config.Figures(2).panels.id] == "raster_3"));
FE.rowSpan.Value = 2;
FE.rowSpan.ValueChangedFcn(FE.rowSpan, struct('PreviousValue', 1, 'Value', 2));
check(isequal(cellOf("raster_3"), {[1 2 1 1]}) && FE.rowSpan.Value == 1 && contains(app.StatusBar.Text, "would overlap psth_1"), ...
    'a span over another panel is refused');
FE.rowHeight.Value = 1.5;
FE.colWidth.Value = 2;
FE.spacing.Value = "loose";
app.onConfigChanged("figure");
G2 = app.Config.Figures(2).grid;
check(isequal(G2.rowHeights, [1.5 1]) && isequal(G2.colWidths, [1 2 1]) && G2.spacing == "loose", ...
    'Row height, Column width and Spacing reach the grid (its row and column, the others 1)');
app.onMovePanel("right");
check(isequal(cellOf("raster_3"), {[1 3 1 1]}) && isequal(cellOf("raster_2"), {[1 2 1 1]}) && contains(app.StatusBar.Text, "Moved raster_3 right"), ...
    'Move right swaps the panel with its same-shaped neighbor');
app.onMovePanel("up");
check(isequal(cellOf("raster_3"), {[1 3 1 1]}) && contains(app.StatusBar.Text, "no panel of the same shape above"), ...
    'Move up with nothing above it changes nothing, and says so');
FE.addSource.Value = "events";
FE.addSource.ValueChangedFcn(FE.addSource, []);
app.onAddLayer();
srcs = @() [app.Config.Figures(2).panels(app.SelectedPanel).layers.source];
app.onMoveLayer(-1);
up = isequal(srcs(), ["events" "units"]) && app.SelectedLayer == 1 && FE.layerUp.Enable == "off";
app.onMoveLayer(1);
down = isequal(srcs(), ["units" "events"]) && app.SelectedLayer == 2;
app.onRemoveLayer();
check(up && down && isequal(srcs(), "units") && numel(FE.layerList.Items) == 1 && contains(app.StatusBar.Text, "Removed layer"), ...
    'layer Up and Down reorder the panel''s layers, Remove takes the one picked away');
FE.panelType.Value = "continuous";
app.onPanelTypeChanged();
FE.contDisplay.Value = "stacked";
app.onConfigChanged("figure");
FE.panelType.Value = "behavior";
app.onPanelTypeChanged();
dispB = app.Config.Figures(2).panels(app.SelectedPanel).options.display;
FE.behDisplay.Value = "box";
app.onConfigChanged("figure");
FE.panelType.Value = "continuous";
app.onPanelTypeChanged();
dispC = app.Config.Figures(2).panels(app.SelectedPanel).options.display;
check(dispB == "points" && dispC == "lines" && string(FE.contDisplay.Value) == "lines", ...
    'a type change starts the display afresh: stacked continuous -> behavior points; box behavior -> continuous lines');
app.onMoveFigure(-1);
movedUp = isequal([app.Config.Figures.id], ["figure_2" "figure_1"]) && app.SelectedFigure == 1 && app.UpFigureButton.Enable == "off";
app.onMoveFigure(1);
check(movedUp && isequal([app.Config.Figures.id], ["figure_1" "figure_2"]) && app.SelectedFigure == 2 && app.DownFigureButton.Enable == "off", ...
    'figure Up and Down reorder the list; the figure stays selected');
app.onRemoveFigure();
app.FigureAutoCheckBox.Value = true;
check(isscalar(app.Config.Figures) && app.SelectedFigure == 1, 'the blank figure removed again');
% a panel made from a heat map or a probe map follows the observation: one unit, not all of them
for pair = ["heatmap" "psth"; "probemap" "raster"].'
    app.onAddFigure(pair(1));
    FE.panelType.Value = pair(2);
    app.onPanelTypeChanged();
    Lp = app.Config.Figures(2).panels(1).layers;
    Fp = app.FigurePreviewResult;
    nShown = NaN;
    if isstruct(Fp) && ~isempty(Fp.panels(1).layers(1).meta); nShown = height(Fp.panels(1).layers(1).meta); end
    check(isscalar(Lp) && Lp.source == "units" && Lp.binding == "observation" && contains(app.StatusBar.Text, "now follows the observation") ...
        && app.FigurePreviewState == "drawn" && Fp.observation.kind == "unit" && nShown == 1, ...
        sprintf('a %s made a %s: its units layer follows the observation, and the preview draws %g unit', pair(1), pair(2), nShown));
    app.onRemoveFigure();
end
% a scan makes the observation list again (the same dataset active)
app.selectDataset(find(app.Ticked, 1));
oldT = app.FigureObservations;
stale = oldT;
stale.label(:) = "stale";
app.FigureObservations = stale;
app.onScan();
T1 = figureObservations(app.Runner.source(app.ActiveIdx), app.Config.figureFor(1));
check(app.ActiveIdx == find(app.Ticked, 1) && istable(app.FigureObservations) && isequal(app.FigureObservations.label, T1.label) ...
    && ~any(app.FigureObservations.label == "stale"), 'Scan lists the observations again on the new runner, even with the same dataset active');
% the previews refuse each other while one computes (the runner is busy)
app.refreshPreview(Force=true);
app.refreshFigurePreview(Force=true);
setappdata(groot, 'probeOther', []);
tm = timer('ExecutionMode', 'fixedRate', 'Period', 0.005, 'TimerFcn', @(t, ~) probeOther(t, app, "figure"));
start(tm);
app.refreshFigurePreview(Force=true);
stop(tm); delete(tm);
r1 = getappdata(groot, 'probeOther');
check(isstruct(r1) && r1.state == "stale" && r1.same && app.FigurePreviewState == "drawn", ...
    'asked while the figure preview computes, the Plots preview computes nothing and is marked Out of date');
app.refreshPreview(Force=true);
setappdata(groot, 'probeOther', []);
tm = timer('ExecutionMode', 'fixedRate', 'Period', 0.005, 'TimerFcn', @(t, ~) probeOther(t, app, "plot"));
start(tm);
app.refreshPreview(Force=true);
stop(tm); delete(tm);
r2 = getappdata(groot, 'probeOther');
check(isstruct(r2) && r2.state == "stale" && r2.same && app.PreviewState == "drawn", ...
    'and asked while the Plots preview computes, the figure preview is marked Out of date');
rmappdata(groot, 'probeOther');
app.refreshFigurePreview(Force=true);
% save, reopen, preferences
app.onFigureSectionToggled("options");
app.FigureAutoCheckBox.Value = false;
app.onFigureAutoPreviewToggled();
app.onSaveConfig();
app2 = EphysAnalysisApp();
kept = isscalar(app2.Config.Figures) && isequaln(app2.Config.Figures, app.Config.Figures) && app2.SelectedFigure == 1 ...
    && string(app2.FigureList.Items{1}) == "figure_1  (2 panels, per unit)";
restored = ~app2.FigureAutoCheckBox.Value && ~app2.FigureSections([app2.FigureSections.Name] == "options").Expanded ...
    && app2.FigureSections([app2.FigureSections.Name] == "layers").Expanded;
closeApp(app2);
check(~startsWith(app.Fig.Name, "*") && kept, 'saved and opened again, the config keeps the figure');
check(restored, 'a new app restores the Figures tab''s Auto and collapsed section');
app.FigureAutoCheckBox.Value = true;
app.onFigureAutoPreviewToggled();
app.onFigureSectionToggled("options");
app.onRemoveFigure();
check(isempty(app.Config.Figures) && isempty(app.FigureList.Items) && app.FigurePreviewState == "idle" && ~shown(FE.id) ...
    && app.RemoveFigureButton.Enable == "off" && nPatches() == 0, 'Remove takes the figure away; the editor and preview are empty');
app.onSaveConfig();
app.Tabs.SelectedTab = app.TabData;

fprintf('\n== 6. close ==\n');
app.savePreferences();
check(strcmp(AppPrefs.getpref(g, 'LastConfigFile'), cfgFile) && isequal(string(AppPrefs.getpref(g, 'PlotSectionsCollapsed')), "bins"), ...
    'the last config and the collapsed plot-editor section are remembered');
app.onShowEpochs("plot");
dz = app.EpochDiagramWindow;
app.onClose();
check(~isvalid(app.Fig) && ~dz.isOpen(), 'Close (clean config) closes the window, and the epoch diagram with it');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysAnalysisApp:Failures', '%d checks failed.', nFail);
end
end


function clickTool(app, tag)
%clickTool  Run the toolbar tool TAG's callback as a click would.
t = findobj(app.Toolbar.Children, 'flat', 'Tag', tag);
t.ClickedCallback(t, []);
end


function t = answerDialog(name, fcn)
%answerDialog  Answer the modal window NAME from a timer, as a user would: FCN(UserData) gets its controls.
%   The window is created inside the call under test (which waits in uiwait);
%   the timer looks for it every half second and runs FCN once. A failing FCN
%   closes the window, so the call under test returns instead of waiting.
t = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.5, 'StartDelay', 0.5, 'TasksToExecute', 240, ...
    'TimerFcn', @(tm, ~) answerTick(tm, name, fcn));
start(t);
end


function answerTick(tm, name, fcn)
f = findall(0, 'Type', 'figure', 'Name', name);
if isempty(f) || ~isstruct(f(1).UserData); return; end   % not built yet: the window sets its UserData last
stop(tm);
try
    fcn(f(1).UserData);
catch ME
    fprintf(2, '  (the answer to "%s" failed: %s)\n', name, ME.message);
    delete(f);
end
end


function press(D, names)
%press  Push the buttons NAMES of a window's controls D, one after the other.
for n = reshape(string(names), 1, [])
    D.(n).ButtonPushedFcn(D.(n), []);
end
end


function editMappingDialog(D)
%editMappingDialog  In the Unit mapping window: change cellA's first id, give cellA no id in the second dataset, add cellC (id 9 in the second), remove cellB, Save.
X = D.Table.Data;
X{1, 2} = '5';
X{1, 3} = '';
D.Table.Data = X;
press(D, "Add");
X = D.Table.Data;
X{3, 1} = 'cellC';
X{3, 3} = '9';
D.Table.Data = X;
D.Table.CellSelectionCallback(D.Table, struct('Indices', [2 1]));
press(D, ["Remove" "Save"]);
end


function copySettingsDialog(D)
%copySettingsDialog  In the Copy plot settings window: note what evoked_1 and psth_1 offer, untick Bins, Copy from psth_1.
from = D.From.ItemsData;
D.From.Value = from(string(D.From.Items) == "evoked_1  (Evoked potential)");
D.From.ValueChangedFcn(D.From, []);
seen = struct('evokedMarks', D.Boxes.marks.Enable == "on", 'evokedStyle', D.Boxes.style.Enable == "on");
D.From.Value = from(string(D.From.Items) == "psth_1  (PSTH)");
D.From.ValueChangedFcn(D.From, []);
seen.psthMarks = D.Boxes.marks.Enable == "on" && D.Boxes.marks.Value;
D.Boxes.bins.Value = false;
D.Boxes.bins.ValueChangedFcn(D.Boxes.bins, []);
lab = findall(ancestor(D.All, 'figure'), 'Type', 'uilabel');
seen.count = string(lab(contains(string({lab.Text}), "part(s) to copy")).Text);
setappdata(groot, 'copySettingsSeen', seen);
press(D, "Ok");
end


function n = plotNode(tree, k)
%plotNode  The plot tree's node of plot K.
n = findall(tree, 'Type', 'uitreenode');
n = n(arrayfun(@(x) isequal(x.NodeData, k), n));
end


function r = wcagRatio(a, b)
%wcagRatio  The WCAG contrast ratio of two RGB colors.
la = relLuminance(a);
lb = relLuminance(b);
r = (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
end


function l = relLuminance(c)
%relLuminance  The relative luminance of the sRGB color C.
lin = (c <= 0.04045) .* (c / 12.92) + (c > 0.04045) .* (((c + 0.055) / 1.055) .^ 2.4);
l = lin(:).' * [0.2126; 0.7152; 0.0722];
end


function probeOther(tm, app, busy)
%probeOther  While the BUSY preview ("figure" or "plot") computes, ask once for the other one; keep its state then (appdata probeOther).
switch busy
    case "figure"
        if app.FigurePreviewState ~= "computing"; return; end
        stop(tm);
        before = app.PreviewResult;
        app.refreshPreview();
        setappdata(groot, 'probeOther', struct('state', app.PreviewState, 'same', isequaln(before, app.PreviewResult)));
    otherwise
        if app.PreviewState ~= "computing"; return; end
        stop(tm);
        before = app.FigurePreviewResult;
        app.refreshFigurePreview();
        setappdata(groot, 'probeOther', struct('state', app.FigurePreviewState, 'same', isequaln(before, app.FigurePreviewResult)));
end
end


function tf = shown(h)
%shown  H and every container above it are visible (hidden row, section or collapsed).
tf = true;
while ~isempty(h) && ~isa(h, 'matlab.ui.Figure')
    if isprop(h, 'Visible') && h.Visible == "off"
        tf = false;
        return
    end
    h = h.Parent;
end
end


function closeApp(app)
try
    if isvalid(app) && isvalid(app.Fig)
        delete(app.Fig);
    end
catch
end
end


function removeRoot(root)
if isfolder(root)
    try
        rmdir(root, 's');
    catch
    end
end
end
