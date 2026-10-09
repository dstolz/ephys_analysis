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
%   only the rows and sections a plot uses (y limits, heat colours, the
%   alignment sections), greying out the ones its options switch off, and
%   collapsing a section; the epoch diagram (opened from the plot editor
%   with the plot's own epochs, redrawn on an edit of pre, epochs dropped
%   outside the recording, a refused window reported, paging, opened from
%   the Alignment tab for the defaults, closing with the app); a raster's
%   sort, direction, grouping and event
%   marks, an event shifted by a trial parameter, an event sequence and a
%   mark sequence from the Event sequence window (a bad step refused), and
%   a behavior plot reaching the config and the preview; several plots
%   selected at once (Ctrl-click: the first picked in the editor and the
%   preview, the banner and the bar saying so, only the rows they share,
%   an edit, an event edit, Use default and a remembered look reaching
%   each but only as changed; Duplicate and Remove taking them all);
%   the gather / apply round trip, keeping the fields without a control
%   (stop-event offset, length and time range, trial rows); save
%   and reopen; a standalone script from the app's config; a run of one
%   plot writing its figures and report; closing. The app's preferences live in a
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
check(isvalid(app.Fig) && numel(app.Tabs.Children) == 5 && app.Tabs.Children(1) == app.TabData ...
    && app.Tabs.Children(5) == app.TabLog, 'the app has the Data, Alignment, Plots, Export and Log tabs');
T = app.DatasetsTable.Data;
check(~isempty(app.Runner) && height(T) == 2 && all(T.Run) && isequal(sort(T.Name), sort(F.names(:))) ...
    && all(T.LFP == "✓") && all(T.Behavior == "✓"), 'the project root was scanned: both datasets, ticked, with LFP and behavior');
check(app.Config.Source.Mode == "project" && app.Config.Source.Root == F.proj && ~startsWith(app.Fig.Name, "*"), ...
    'a new config for the project, clean');
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
tm = timer('ExecutionMode', 'fixedRate', 'Period', 0.005, 'TimerFcn', @(~, ~) app.onCancelPreview());   % a click on the busy card's Cancel
start(tm);
app.refreshPreview(Force=true);
stop(tm); delete(tm);
check(app.PreviewState == "cancelled" && string(app.PreviewBadge.Text.Text) == "Cancelled" && isempty(app.PreviewResult) ...
    && isempty(findall(app.PreviewPanel, 'Tag', 'previewBusyCard')) && string(app.Fig.Pointer) == "arrow" ...
    && isempty(app.Runner.PollFcn) && ~isfinite(app.PreviewSeconds), ...
    'Cancel on the busy card stops the preview while it computes: the badge says Cancelled, the card and the polling are gone');
app.onCancelPreview();   % nothing computes: no effect
app.autoPreview();
check(app.PreviewState == "cancelled", 'a cancelled preview is not redrawn by an edit; it waits for Preview');
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
    ['a PSTH shows stack, normalize, fill, opacity and group colours (spacing waits for Stack), not heat colours ' ...
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
    'a probe map hides the event, window, selection and baseline; it shows its value and heat colours');
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
    'the note''s text, place, alignment, rotation, font and colour reach the plot; "auto" and "none" are blank');
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
    'Add line puts a dashed line at 0 in the list, picked; its rows are a line''s (position, colour), not a patch''s');
E.ovName.Value = 'Stim on'; E.ovValue.Value = '0.25'; E.ovColor.Value = 'blue'; E.ovAlpha.Value = 0.5;
E.ovStyle.Value = ':'; E.ovWidth.Value = 3; E.ovLayer.Value = 'under'; E.ovPanel.Value = 'data';
app.onConfigChanged("plot");
ovs = app.Config.Plots(k0).overlays;
check(ovs.name == "Stim on" && ovs.value == 0.25 && ovs.color == "blue" && ovs.alpha == 0.5 && ovs.lineStyle == ":" && ovs.lineWidth == 3 ...
    && ovs.layer == "under" && ovs.panel == "data" && contains(string(E.ovList.Items{1}), "Stim on") ...
    && contains(string(E.ovList.Items{1}), "x = 0.25"), ...
    'the line''s name, position, colour, opacity, style, width, layer and panel reach the config; the list follows its name and position');
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
    'Add patch adds a second overlay and keeps the first; a patch shows its edges, fill and outline, not a line''s position and colour');
E.ovEdge.Value = 'none';
app.syncPlotEditor();
outlineOff = E.ovStyle.Enable == "off" && E.ovWidth.Enable == "off";
E.ovEdge.Value = 'black';
app.syncPlotEditor();
check(outlineOff && E.ovStyle.Enable == "on" && E.ovWidth.Enable == "on", 'a patch''s outline style and width wait for an outline colour');
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
check(shown(E.rasterSort) && shown(E.rasterSortOrder) && shown(E.rasterByGroup) && shown(E.markLines) && shown(E.markMarker) ...
    && E.markMarker.Enable == "off" && ~shown(E.yParam) && ~shown(E.xScale), ...
    'a raster shows its sort, direction, grouping and event marks (their look waits for a line to mark)');
E.rasterSort.Value = 'Depth'; E.rasterSortOrder.Value = 'descending'; E.rasterByGroup.Value = false;
E.markLines.Value = 'Trough, RespWindow'; E.markEdge.Value = 'both'; E.markMarker.Value = '^'; E.markSize.Value = 6;
E.markColor.Value = 'red';
app.onConfigChanged("plot");
p = app.Config.Plots(kR);
check(p.rasterSort == "Depth" && p.rasterSortOrder == "descending" && ~p.rasterByGroup ...
    && isequal(p.rasterEvents.lines, ["Trough" "RespWindow"]) && p.rasterEvents.edge == "both" && p.rasterEvents.marker == "^" ...
    && p.rasterEvents.size == 6 && p.rasterEvents.color == "red" && E.markMarker.Enable == "on", ...
    'the raster''s sort, its direction and grouping, and the lines to mark and their look reach the plot');
app.refreshPreview(Force=true);
check(~isempty(app.PreviewResult) && numel(app.PreviewResult.rasterEvents) == 4 && ~isempty(findall(app.PreviewPanel, 'Tag', 'rasterEvent')), ...
    'the preview marks the Trough and RespWindow onsets and offsets');
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
check(D.List.Parent.Visible == "on" && numel(D.List.Items) == 1 && string(D.List.Items{1}) == "Trial offset then Trough onset", ...
    'Mark sequences: Add sequence starts at Trial offset then Trough onset');
D.Apply.ButtonPushedFcn(D.Apply, []);
p = app.Config.Plots(kR);
app.refreshPreview(Force=true);
check(numel(p.rasterEvents.sequences) == 1 && p.rasterEvents.sequences.which == "all" ...
    && numel(app.PreviewResult.rasterEvents) == 5 && app.PreviewResult.rasterEvents(5).label == "Trial offset then Trough onset", ...
    'the mark sequence reaches the plot and the preview marks it after the four line marks');
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
    && height(app.DatasetsTable.Data) == 2 && any(app.RecentConfigs == string(cfgFile)), 'reopening restores the plots and rescans');
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


function n = plotNode(tree, k)
%plotNode  The plot tree's node of plot K.
n = findall(tree, 'Type', 'uitreenode');
n = n(arrayfun(@(x) isequal(x.NodeData, k), n));
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
