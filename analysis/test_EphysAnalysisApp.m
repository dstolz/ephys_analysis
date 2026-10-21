function test_EphysAnalysisApp(opts)
%test_EphysAnalysisApp  Headless checks of the analysis GUI over a synthetic project.
%   Builds the app on a small synthetic project run through the pipeline
%   and drives it through its own methods: the startup (built hidden behind
%   the splash, Splash=true and the -batch default without it); opening on
%   a folder (the last config with its source switched, else a quick look);
%   LastConfigFile kept after New; the five tabs (Data, Alignment,
%   Figures, Export, Log); the toolbar (its tools, icons and
%   shortcut tooltips; Preview and Plan from another tab; its run and
%   results tools following the Export tab's buttons); Scan filling the
%   datasets table; the active dataset's lines and parameters; grouping by
%   Depth from the Alignment controls (the epoch count reports the groups);
%   the toolbar's Preview drawing the selected figure on the Figures tab;
%   the header's column of buttons and the rows right of them;
%   Export code (its script, run, computing what the preview computed and
%   drawing it in a window of its own); the Design row on the Figures tab (the list and menu, a design chosen
%   redrawing the figure preview, Save look as design from the figure
%   preview, a heat map figure's axes rules kept for heat maps, deleting a
%   design); the epoch diagram (opened for the figure by default, redrawn
%   on an edit of its pre, Use default again, the Alignment tab's defaults,
%   closing); an event sequence for the figure's own event from the Event
%   sequence window (a bad step refused); the gather / apply round trip,
%   keeping the fields without a control (stop-event offset, length and
%   time range, trial rows); save and reopen; a version-1 config opened
%   (its plot migrated to a figure, the status bar and the Log saying so);
%   a standalone script from the app's config; Plan and a run of one
%   figure writing its pages and the report; the Figures tab (a figure from a template, its automatic id, the
%   schematic, the observation picker and its preview of one unit, < and
%   > and Page Up, a continuous panel added below, an events layer on the
%   raster, the rows a panel type shows, Ctrl+digit to a section, the
%   supersections (their order, collapsing, Alt+digit), the search (a
%   row's path, a hidden row's reason, a shown row gone to and
%   highlighted, Down and Escape, a section by its title), the panel keys
%   (Ctrl+Alt+arrows, Ctrl+[ and Ctrl+]) and the preview's outline of the
%   selected panel (moved without a redraw, following a resize, not in
%   Open in window), the keys window, Out of
%   date with Auto off, Cancel, the figure's own event, a panel's own
%   window, a tightened unit filter and one nothing passes, a listing
%   error, a type change, the gather / apply round trip, a remembered look
%   and Forget, another config opened, a row height the spinner's old
%   limits clipped, Remove panel, Duplicate ("<id> (2)"), New panel above / right /
%   left, Add (a blank figure and the New panel window, answered and
%   canceled), every panel type at every place, the Id row (an id typed
%   sticks, auto goes back; references follow an automatic rename),
%   spans (and their refusals), sizes and spacing, a panel's own
%   size and alignment, the Spacing window (custom gaps, one set apart,
%   a refused value, Apply, a preset and OK), Move, layer and
%   figure Up / Down, no Behavior type or trials source offered, linked
%   panels' locked alignment, a panel's own options (Apply to all
%   panels, Re-link all panels, Ctrl+7 / Ctrl+9), a scan listing the
%   observations again, save and reopen, its preferences restored by a new app,
%   Remove); Copy from... between figures; Generate (a figure's files per observation on the ticked
%   datasets, its rows in the results table, the status bar's counts,
%   Cancel during it, a figure that is off drawn for that run only), Unit
%   report (every figure for the unit picked on the active dataset, a
%   figure of the dataset left out, an HTML report in a temporary folder,
%   the output folder untouched) and
%   the Export tab's Plan and Run listing figures; a figure across
%   sessions (the Sessions section's rows wired to the config, the mapping
%   file's Browse / Edit, Pick, the picker's matched sites, a preview
%   across both datasets, no recompute on an edit, the "Figure:" drop-down,
%   Export code across the sessions (run, the figure picked),
%   Generate into the sessions folder); the figure tree (grouped by what
%   the figures observe, by status, flat; a leaf and a header picked; the
%   check boxes of a figure and of a group, All / None / Invert; Up / Down
%   within a group; Group by and the collapsed groups restored by a new
%   app), a panel's text note and overlays (their rows reach the panel
%   picked and the preview, Add / Duplicate / Remove, another panel's
%   own) and dragging a panel in the schematic (an edge drop, a move to
%   an empty cell, a release outside it and Escape canceling);
%   favorites (the star toggles beside Dataset and the observation, the Data
%   tab's ★ column, the files beside the data read back by a scan, ★ marks
%   in the drop-downs, a unit's sort recorded, a detection channel showing
%   its channel's star, the Favorites lists, their filter, picking a unit
%   from the Figures and Alignment tabs, the last star removing the file,
%   a read-only output folder); notes (the notepad from the note buttons
%   and the Data tab's ✎ column, following the active dataset and the
%   observation as it steps, the file beside the data, ✎ marks and yellow
%   buttons, Search notes with Go to and Edit note, a scan reading them
%   back); the Edit menu's Undo and Redo of the figure editor (between
%   File and Design, grayed off the Figures tab, named after the edit; a
%   burst of one field one step, an edit outside the figures none, a
%   removed panel back and selected, Ctrl+Shift+Z, a new edit dropping the
%   redo, the description kept, the title saved again, cleared by another
%   config; FigureEditHistory's depth);
%   closing (no plot or session preference written). The app's preferences live in a
%   temporary file for the run (AppPrefs.useTemporary), never the user's.
%
%   Usage:  test_EphysAnalysisApp
%           test_EphysAnalysisApp(Sections="5i")            % some sections (TestSections): "5d" runs every 5d.*
%           run_all_tests({'test_EphysAnalysisApp:5i,5j'})
%
%   Every section after the fixture and the app's build is guarded by
%   S.sec: a section run alone sets up what it needs from the earlier ones
%   through the prep helpers (savedConfig, groupedBy, exported, withFigure,
%   noFigures, called at its top) or declares it in Needs (the 5d.* ladder).

arguments
    opts.Sections (1,:) string = string.empty(1, 0)
end

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

app = EphysAnalysisApp(F.proj);   % built on the project and scanned: the setup every section runs on
appCleanup = onCleanup(@() closeApp(app));

% what the sections share: key presses, the figure editor's controls and sections, the preview's axes and title,
% the schematic's patches, section 4's Export folder and config file, the two datasets' places in the Runner
pressed = @(k, mods) struct('Key', k, 'Modifier', {mods}, 'Character', '');
FE = app.FigureEditor;
FA = app.FigureAlignControls;
FP = app.PanelAlignControls;
figAxes = @() findall(app.FigurePreviewPanel, 'Type', 'axes', '-regexp', 'Tag', '^(axes|rasterAxes)$');
figTitle = @() strjoin(string(findall(app.FigurePreviewPanel, 'Type', 'axes', 'Tag', 'titleHost').Title.String), " ");
nPatches = @() numel(findall(app.FigureSchematic, 'Type', 'patch'));
secOf = @(n) app.FigureSections([app.FigureSections.Name] == n);
outRoot = fullfile(root, 'out');
cfgFile = fullfile(root, 'app_analysis.json');
kF1 = find(app.Runner.Names == F.names(1));
kF2 = find(app.Runner.Names == F.names(2));

% the sections (TestSections): what one run alone needs from the earlier ones, rows [id, prerequisite] (the 5d.* ladder);
% the rest of its state comes from the prep helpers below, called at its top
needs = ["5d.observe" "5d.add"; "5d.layers" "5d.add"; "5d.keys" "5d.layers"; "5d.search" "5d.layers"; ...
    "5d.outline" "5d.layers"; "5d.goto" "5d.add"; "5d.stale" "5d.layers"; "5d.align" "5d.layers"; ...
    "5d.filter" "5d.add"; "5d.pergroup" "5d.add"; "5d.ownsel" "5d.add"; "5d.conttrials" "5d.layers"; ...
    "5d.type" "5d.add"; "5d.applyall" "5d.layers"; "5d.look" "5d.add"; "5d.otherconfig" "5d.add"; ...
    "5d.remove" "5d.layers"; "5d.arrange" "5d.add"; "5d.newpanel" "5d.add"; "5d.follow" "5d.add"; ...
    "5d.eventtrace" "5d.add"; "5d.psth" "5d.remove"; "5d.scan" "5d.add"; "5d.saveprefs" "5d.remove"];
S = TestSections(mfilename, opts.Sections, Needs=needs);
timing = onCleanup(@() S.done()); %#ok<NASGU> the sections' times, even after a failure on the way

    function savedConfig()
        %savedConfig  The config saved to cfgFile once (section 4's Save As): onSaveConfig then saves there instead of opening uiputfile.
        if all(app.Config.File == ""); app.onSaveConfigAs(string(cfgFile)); end
    end

    function groupedBy(by)
        %groupedBy  The defaults aligned on Stim and grouped by the parameter BY, as section 2 sets them; nothing when they are.
        if isequal(string(app.Config.Defaults.Selection.groupBy), string(by)); return; end
        app.AlignControls.Line.Value = 'Stim';
        app.AlignControls.Group1.Value = char(by);
        app.onConfigChanged("defaults");
    end

    function exported()
        %exported  Section 4's Export and Report settings: PNG pages at 60 dpi under outRoot/<Name>, the report in outRoot at 50 dpi.
        if string(app.ExportControls.Folder.Value) == string(fullfile(outRoot, '{Name}')); return; end
        app.ExportControls.Folder.Value = fullfile(outRoot, '{Name}');
        app.ExportControls.svg.Value = false;
        app.ExportControls.png.Value = true;
        app.ExportControls.Dpi.Value = 60;
        app.ReportControls.Folder.Value = outRoot;
        app.ReportControls.Dpi.Value = 50;
        app.onConfigChanged("export");
    end

    function withFigure(template)
        %withFigure  A figure from TEMPLATE when the config has none (section 3's "PSTH units").
        if isempty(app.Config.Figures); app.onAddFigure(template); end
    end

    function noFigures()
        %noFigures  Every figure removed: the section starts from none (the earlier sections leave theirs saved).
        while ~isempty(app.Config.Figures)
            app.onFigureSelected(1);
            app.onRemoveFigure();
        end
    end

if S.sec("1", "build, open the project, scan")
    check(app.Fig.Visible == "on" && ~app.Splash.isActive() && app.Splash.Window == "" && isempty(findall(groot, 'Tag', 'AppSplash')) ...
        && isequal(app.Splash.History.Step.', ["window" "Data" "Alignment" "Figures" "Export" "Log" "finish" "prefs" "scan" "dataset" "show"]), ...
        'under -batch the app starts without the splash window: built hidden, each tab, the scan and the first dataset a step, then shown');
    check(isvalid(app.Fig) && numel(app.Tabs.Children) == 5 && app.Tabs.Children(1) == app.TabData ...
        && app.Tabs.Children(2) == app.TabAlign && app.Tabs.Children(3) == app.TabFigures && app.Tabs.Children(4) == app.TabExport ...
        && app.Tabs.Children(5) == app.TabLog && ~isprop(app, 'TabChronux') && ~isprop(app, 'TabPlots') && ~isprop(app, 'TabSessions'), ...
        'the app has the Data, Alignment, Figures, Export and Log tabs');
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
    app.onDatasetCellSelection(struct('Indices', [1 4]));   % the Name cell (Run, ★ and ✎ before it do not select)
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
    nUk = numel(app.Runner.Outputs(k).load("sorting").unitId);
    dItems = string(app.FiguresDatasetDropDown.Items);
    check(dItems(k) == F.names(1) + sprintf("  (%d units)", nUk) && all(startsWith(dItems, app.Runner.Names)) ...
        && isequal(dItems, string(app.AlignDatasetDropDown.Items)) ...
        && isequal(app.FiguresDatasetDropDown.ItemsData, 1:2) && app.FiguresDatasetDropDown.Value == k, ...
        sprintf('the Dataset drop-downs name each dataset with its sorted units once opened ("%s"); the pick is by index', dItems(k)));
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
end

if S.sec("1b", "Toolbar: the most used commands")
    tools = flip(app.Toolbar.Children);
    tags = string({tools.Tag});
    check(isequal(tags, ["new" "open" "save" "undo" "redo" "scan" "preview" "notes" "validate" "plan" "run" "cancel" "report" "figurefolder" "pipelineapp" "help"]) ...
        && isequal(find(logical([tools.Separator])), [4 6 9 13 15 16]) ...
        && all(isfile(fullfile(here, 'icons', 'toolbar', tags + ".svg"))), ...
        'the toolbar holds the config, undo, look, run, results, app and help commands in groups, each with its icon');
    if ismac; modifier = "Cmd+"; else; modifier = "Ctrl+"; end
    tips = string({tools.Tooltip});
    menuItems = findall(app.FileMenu, 'Type', 'uimenu');   % the Edit menu's Undo and Redo are tools of their own (5k)
    keyed = menuItems(strlength(string({menuItems.Accelerator})) > 0);
    named = erase(string({keyed.Text}), "...") + " (" + modifier + string({keyed.Accelerator}) + ")";
    check(numel(keyed) == 3 && all(ismember(named, tips)) && nnz(contains(tips, "(" + modifier)) == numel(keyed) + 2 ...
        && all(strlength(tips) > 0), ...
        'every File menu shortcut is on the toolbar, named in its tool''s tooltip, and no tooltip names another but Undo and Redo''s');
    check(app.ToolbarValidateTool.Enable == "on" && app.ToolbarPlanTool.Enable == "on" && app.ToolbarRunTool.Enable == "on" ...
        && app.ToolbarCancelTool.Enable == "off" && app.ToolbarReportTool.Enable == "off" && app.ToolbarFolderTool.Enable == "off", ...
        'before a run: Validate, Plan and Run are on; Cancel, the report and the figure folder off');
end

if S.sec("1c", "Help menu: GitHub issue and feature request")
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
end

if S.sec("2", "Alignment: group by Depth")
    app.selectTab(app.TabAlign);
    app.AlignControls.Line.Value = 'Stim';
    app.AlignControls.Group1.Value = 'Depth';
    app.onConfigChanged("defaults");
    [trials, ~] = readEpsychSession(F.truth(1).behaviorFile);
    nG = numel(unique(trials.Depth));
    counts = findall(app.AlignAxes, 'Tag', 'epochCount');
    check(app.Config.Defaults.Selection.groupBy == "Depth" && startsWith(app.AlignSummaryLabel.Text, "12 epochs from 12 of 12 trials") ...
        && ~contains(app.AlignSummaryLabel.Text, "Depth = ") && numel(counts) == nG && sum(str2double(strtrim(string({counts.String})))) == 12, ...
        sprintf('the epoch count reports %d Depth groups, each bar''s count on top of it', nG));
    app.AlignBarsExcluded.Value = true;
    app.refreshAlignPreview();
    counts = findall(app.AlignAxes, 'Tag', 'epochCount');
    check(numel(findobj(app.AlignAxes, 'Type', 'bar')) == 3 && numel(counts) == nG && ~isempty(app.AlignAxes.Legend), ...
        'Show the epochs Pairing and Artifacts exclude: kept, Pairing and artifact epochs stacked, with a legend');
    app.AlignBarsExcluded.Value = false;
    C = app.AlignControls;
    C.ExcludeArtifacts.Value = false;
    C.ExcludeArtifacts.ValueChangedFcn(C.ExcludeArtifacts, []);
    check(~app.Config.Defaults.Selection.excludeArtifacts && C.MinArtifact.Enable == "off", ...
        'unticking Artifacts: Exclude epochs keeps the artifact epochs in the Defaults, and its minimum length is off');
    C.ExcludeArtifacts.Value = true;
    C.MinArtifact.Value = 0.5;
    C.MinArtifact.ValueChangedFcn(C.MinArtifact, []);
    check(app.Config.Defaults.Selection.excludeArtifacts && app.Config.Defaults.Selection.minArtifactSec == 0.5 ...
        && C.MinArtifact.Enable == "on", 'the artifacts'' minimum length goes to the Defaults');
    C.MinArtifact.Value = 0;
    C.MinArtifact.ValueChangedFcn(C.MinArtifact, []);
    check(height(app.AlignTrialsTable.Data) == 12 && ismember("Group", string(app.AlignTrialsTable.Data.Properties.VariableNames)), ...
        'the kept trials are listed with their group');
    da = app.AlignEpochDiagram;
    check(isa(da, 'EpochDiagram') && da.isOpen() && isempty(da.Fig) && numel(findall(app.TabAlign, 'Type', 'axes')) == 3 ...
        && ~shown(app.AlignControls.Diagram) && startsWith(da.Heading, "Defaults on ") && nnz(da.Epochs.kept) == 12 ...
        && height(da.Groups) == nG && endsWith(da.Rule(end), "grouped by Depth."), ...
        'the Alignment tab draws the defaults'' epoch diagram beside the count (no window, no button): 12 epochs in the Depth groups');
    check(startsWith(app.Fig.Name, "*"), 'the edit marks the config unsaved');
end

if S.sec("3", "the Figures tab: the toolbar's Preview, the Design row, the epoch diagram, an event sequence")
    app.FigureAutoPreviewSeconds = Inf;   % a preview slowed by a loaded machine must not leave the next one out of date
    restoreAutoLimit3 = onCleanup(@() resetAutoLimit(app));
    app.selectTab(app.TabFigures);
    app.onAddFigure("psth");
    check(isscalar(app.Config.Figures) && app.Config.Figures(1).id == "PSTH units" && app.Config.Figures(1).autoId && app.SelectedFigure == 1 ...
        && app.Config.Figures(1).panels(1).type == "psth", 'a figure from the PSTH template: "PSTH units" (an automatic id), opened in the editor');
    app.selectTab(app.TabData);
    app.FigurePreviewResult = [];
    clickTool(app, "preview");   % as the Preview button, from another tab
    check(app.Tabs.SelectedTab == app.TabFigures && ~isempty(app.FigurePreviewResult) && app.FigurePreviewState == "drawn" ...
        && ~isempty(findall(app.FigurePreviewPanel, 'Type', 'axes')) && string(app.FigurePreviewBadge.Text.Text) == "Drawn", ...
        'the toolbar''s Preview shows the Figures tab and draws the selected figure into its preview');
    % the Design row: the list and Save look as design..., over the figure preview
    dd = app.DesignDropDown;
    designs = PlotDesign.list();
    check(ancestor(dd, 'uitab') == app.TabFigures && ancestor(app.SaveDesignButton, 'uitab') == app.TabFigures ...
        && numel(dd.Items) == height(designs) && string(dd.Value) == "Default" && any(string({app.DesignMenu.Children.Text}) == "Tufte"), ...
        'the Design list and Save look as design... sit on the Figures tab; the list and the Design menu offer every design, Default chosen');
    % the Design controls sit right of Dataset / Observation (same grid, same rows), each drop-down with its star; Favorites
    % under them; Open in window draws a figure() of its own
    pgrid = app.DesignDropDown.Parent;
    dsg = app.FiguresDatasetDropDown.Parent;
    osg = app.FigureObservationDropDown.Parent;
    check(dsg.Parent == pgrid && osg.Parent == pgrid && app.SaveDesignButton.Parent == pgrid ...
        && app.DesignDropDown.Layout.Row == dsg.Layout.Row && app.SaveDesignButton.Layout.Row == osg.Layout.Row ...
        && min(app.DesignDropDown.Layout.Column) > max(dsg.Layout.Column) && min(app.SaveDesignButton.Layout.Column) > max(osg.Layout.Column) ...
        && app.FiguresDatasetStar.Parent == dsg && app.FigureObservationStar.Parent == osg ...
        && app.FiguresDatasetNote.Parent == dsg && app.FigureObservationNote.Parent == osg && app.AlignDatasetNote.Parent == app.AlignDatasetStar.Parent ...
        && app.FigureFavorites.Grid.Parent == pgrid && app.FigureFavorites.Grid.Layout.Row == osg.Layout.Row + 1 ...
        && app.FigurePreviewPanel.Layout.Row == app.FigureFavorites.Grid.Layout.Row + 1, ...
        'the Design list sits right of Dataset and Save look as design... right of Observation, in their rows, each drop-down with its star and note button; Favorites under them, the preview under that');
    % the buttons in a column of their own left of those rows: Preview, Generate, Unit report, Auto, < > (a row each)
    bgrid = app.FigurePreviewButton.Parent;
    btnCol = [app.FigurePreviewButton app.FigureGenerateButton app.FigureUnitReportButton app.FigureAutoCheckBox app.FigureObsPrevButton.Parent];
    check(bgrid.Parent == pgrid && isequal(bgrid.Layout.Column, 1) && isequal(bgrid.Layout.Row, [dsg.Layout.Row app.FigureFavorites.Grid.Layout.Row]) ...
        && all(arrayfun(@(h) h.Parent == bgrid, btnCol)) && isequal(arrayfun(@(h) h.Layout.Row, btnCol), 1:5) ...
        && app.FigureObsNextButton.Parent == app.FigureObsPrevButton.Parent ...
        && all(arrayfun(@(h) min(h.Layout.Column) > 1, [dsg osg app.FigureFavorites.Grid])), ...
        'the buttons stand in a column at the left, a row each (Preview, Generate, Unit report, Auto, < >), beside the Dataset, Observation and Favorites rows');
    check(app.FigureOpenButton.Enable == "on" && ancestor(app.FigureOpenButton, 'uitab') == app.TabFigures, ...
        'Open in window is on with a figure selected');
    nFigs = numel(findall(groot, 'Type', 'figure'));
    hw = app.onOpenFigureWindow();
    closeWin = onCleanup(@() delete(hw(isgraphics(hw))));
    check(isgraphics(hw, 'figure') && numel(findall(groot, 'Type', 'figure')) == nFigs + 1 ...
        && startsWith(string(hw.Name), app.Config.Figures(app.SelectedFigure).id + ": ") ...
        && numel(findall(hw, 'Type', 'axes')) == numel(findall(app.FigurePreviewPanel, 'Type', 'axes')) ...
        && app.FigurePreviewState == "drawn", ...
        'Open in window opens a regular figure holding the panels'' axes, named for the figure, the preview untouched');
    delete(hw);
    % Export code, left of Open in window under the preview: the preview's code, which run draws the observation picked as the preview did
    check(app.FigureCodeButton.Parent == app.FigureOpenButton.Parent && app.FigureCodeButton.Enable == "on" ...
        && app.FigureCodeButton.Layout.Column == app.FigureOpenButton.Layout.Column - 1, ...
        'Export code sits left of Open in window under the preview, on with a figure selected');
    % every button of the preview has its key in its tooltip, and the key presses it: Ctrl+W opens the window, Ctrl+T toggles Auto, Ctrl+P previews
    btnKeys = {app.FigurePreviewButton "+P"; app.FigureGenerateButton "+G"; app.FigureUnitReportButton "+U"; app.FigureAutoCheckBox "+T"; app.FigureCodeButton "+E"; ...
        app.FigureOpenButton "+W"; app.FigureObsPrevButton "Page Up"; app.FigureObsNextButton "Page Down"};
    inTip = cellfun(@(h, k) contains(string(h.Tooltip), k), btnKeys(:, 1), btnKeys(:, 2));
    check(all(inTip), 'every button of the preview names its key in its tooltip');
    nFigs = numel(findall(groot, 'Type', 'figure'));
    figs0 = findall(groot, 'Type', 'figure');
    mods = {'control'};
    if ismac; mods = {'command'}; end
    app.onKeyPress(pressed('w', mods));
    figs1 = findall(groot, 'Type', 'figure');
    check(numel(figs1) == nFigs + 1, 'Ctrl+W opens the figure in a window of its own, as Open in window does');
    delete(setdiff(figs1, figs0));
    auto0 = app.FigureAutoCheckBox.Value;
    app.onKeyPress(pressed('t', mods));
    check(app.FigureAutoCheckBox.Value == ~auto0, 'Ctrl+T toggles Auto');
    app.onKeyPress(pressed('t', mods));
    check(app.FigureAutoCheckBox.Value == auto0, 'Ctrl+T toggles Auto back');
    app.setFigurePreviewState("stale");
    app.onKeyPress(pressed('p', mods));
    check(app.FigurePreviewState == "drawn", 'Ctrl+P previews, as Preview does');
    codeFile = fullfile(root, 'preview_code.m');
    code = app.onFigureCode(string(codeFile));
    [Fc, hc] = runPreviewCode(codeFile);
    closeCode = onCleanup(@() delete(hc(isgraphics(hc))));
    check(isfile(codeFile) && contains(app.StatusBar.Text, codeFile) && contains(code, "src = loadAnalysisSource(outs, Key=key);") ...
        && contains(code, "F = figureCompute(src, spec, Observation=obs);") && contains(code, "Design=""Default""") ...
        && sameResult(Fc, app.FigurePreviewResult) && numel(findall(hc, 'Type', 'axes')) == numel(findall(app.FigurePreviewPanel, 'Type', 'axes')), ...
        'Export code writes the preview''s code: run, it computes the observation picked as the preview did and draws it in a window of its own');
    delete(hc);
    cfg0 = app.Config.toStruct();
    dd.Value = "Night";
    dd.ValueChangedFcn(dd, []);
    night = PlotDesign.load("Night");
    menuChecked = string({app.DesignMenu.Children(strcmp({app.DesignMenu.Children.Checked}, 'on')).Text});
    check(isequal(app.FigurePreviewPanel.BackgroundColor, night.background) && PlotDesign.currentName() == "Night" ...
        && isequal(menuChecked, "Night") && isequaln(app.Config.toStruct(), cfg0) && app.FigurePreviewState == "drawn", ...
        sprintf('a design chosen in the list redraws the figure preview in it at once and ticks it in the menu, the config untouched (ground %s, menu %s)', ...
        mat2str(app.FigurePreviewPanel.BackgroundColor, 3), strjoin(menuChecked, "|")));
    app.setFigurePreviewState("stale");
    app.onSaveDesign("Stale look", "");
    check(~any(PlotDesign.list().Name == "Stale look") && contains(app.StatusBar.Text, "the drawing is out of date"), ...
        'Save look as design refuses an Out of date preview (its drawing is not the figure any more) and says to preview first');
    app.setFigurePreviewState("drawn");
    app.onSaveDesign("Lab look", "for lab meeting");
    mine = PlotDesign.list();
    k = find(mine.Name == "Lab look");
    check(isscalar(k) && mine.Source(k) == "mine" && PlotDesign.currentName() == "Lab look" && string(dd.Value) == "Lab look" ...
        && isequal(app.FigurePreviewPanel.BackgroundColor, night.background) && contains(app.StatusBar.Text, "Saved design Lab look"), ...
        'Save look as design keeps the figure preview''s look as a design of yours and chooses it');
    app.onAddFigure("heatmap");
    app.refreshFigurePreview(Force=true);
    heatDrawn = app.FigurePreviewState == "drawn" && ~isempty(findall(app.FigurePreviewPanel, 'Tag', 'image'));
    app.onSaveDesign("Heat look", "");
    Dh = PlotDesign.load("Heat look");
    check(heatDrawn && isfield(Dh.kinds, "heatmap") && any([Dh.kinds.heatmap.role] == "axes"), ...
        'saved from a heat map figure, the design keeps the heat map''s axes rules for heat maps only (kinds.heatmap)');
    app.onRemoveFigure();
    app.onFigureSelected(1);
    app.onDeleteDesign("Heat look", Confirm=false);
    app.onDeleteDesign("Lab look", Confirm=false);
    app.refreshFigurePreview(Force=true);
    check(~any(ismember(PlotDesign.list().Name, ["Lab look" "Heat look"])) && string(dd.Value) == "Default" ...
        && isequal(app.FigurePreviewPanel.BackgroundColor, [1 1 1]), 'deleting the chosen design goes back to Default');
    if isfolder(PlotDesign.folder()); rmdir(PlotDesign.folder(), 's'); end
    % the epoch diagram window of the figure in the editor; the Alignment tab's follows the defaults
    check(shown(FE.epochs) && FE.epochs.Text == "Epoch Diagram", 'the figure editor offers "Epoch Diagram" under the Epoch window');
    app.onShowEpochs();
    d = app.EpochDiagramWindow;
    src = app.Runner.source(app.ActiveIdx);
    check(isa(d, 'EpochDiagram') && d.isOpen() && string(d.Fig.WindowStyle) == "alwaysontop" && d.Message == "" ...
        && any(d.Epochs.kept) && startsWith(d.Heading, "PSTH units on ") && contains(d.Heading, "the defaults"), ...
        sprintf('the diagram opens above the app with the figure''s epochs (%d kept)', nnz(d.Epochs.kept)));
    FA.Pre.Value = -0.5;
    app.onFigureAlignEdited("window");
    check(isstruct(app.Config.Figures(1).window) && all(abs(d.Epochs.tStart - d.Epochs.t0 + 0.5) < 1e-9) ...
        && contains(d.Heading, "its own window"), 'editing the figure''s pre redraws the diagram at once: every window starts 0.5 s before its event');
    FE.defaultWindow.Value = true;
    app.onFigureDefaultToggled();
    W = app.Config.Defaults.Window;
    check(~isstruct(app.Config.Figures(1).window) && all(abs(d.Epochs.tStart - d.Epochs.t0 - W.pre) < 1e-9), ...
        'ticking Use default again: the diagram follows the default window');
    preWas = app.AlignControls.Pre.Value;
    app.AlignControls.Pre.Value = -0.3;
    app.onConfigChanged("defaults");
    da = app.AlignEpochDiagram;
    Dd = app.Config.Defaults;
    Ed = epochTable(src, Dd.EventRef, Window=Dd.Window, Selection=Dd.Selection);
    check(all(abs(da.Epochs.tStart - da.Epochs.t0 + 0.3) < 1e-9) && nnz(da.Epochs.kept) == height(Ed) ...
        && all(abs(d.Epochs.tStart - d.Epochs.t0 + 0.3) < 1e-9) && startsWith(d.Heading, "PSTH units on "), ...
        'editing the default pre redraws the Alignment tab''s diagram and the window of a figure on the defaults');
    app.AlignControls.Pre.Value = preWas;
    app.onConfigChanged("defaults");
    d.close();
    app.onConfigChanged("figure");
    check(~d.isOpen(), 'closing the diagram leaves it closed through later edits');
    % an event sequence for the figure's own event (the Event sequence window)
    FA.Line.Value = 'Trial'; FA.Edge.Value = 'offset';
    app.onFigureAlignEdited("ref");
    FA.SeqEdit.ButtonPushedFcn(FA.SeqEdit, []);
    D = app.SequenceDialog.UserData;
    check(isvalid(app.SequenceDialog) && string(D.Line.Value) == "Trial" && string(D.Edge.Value) == "offset" && D.Line.Enable == "off" ...
        && height(D.Table.Data) == 0 && ~isfield(D, 'List'), ...
        'Edit... opens the Event sequence window at the figure''s line and edge, with no step yet (one sequence: no list of marks)');
    D.AddStep.ButtonPushedFcn(D.AddStep, []);
    T = D.Table.Data; T.n(1) = 0; D.Table.Data = T;
    D.Apply.ButtonPushedFcn(D.Apply, []);
    check(isvalid(app.SequenceDialog) && isempty(app.Config.Figures(1).ref.sequence), 'Apply refuses a bad step (n 0) and keeps the window open');
    T.n(1) = 1; D.Table.Data = T;
    D.Apply.ButtonPushedFcn(D.Apply, []);
    r1 = app.Config.Figures(1).ref;
    check(~(~isempty(app.SequenceDialog) && isvalid(app.SequenceDialog)) && numel(r1.sequence) == 1 && r1.sequence.line == "Trough" ...
        && r1.sequence.relation == "followedBy" && isinf(r1.alignStep) && string(FA.SeqText.Text) == "then Trough onset", ...
        'Apply gives the figure its sequence: Trial offset then Trough onset');
    FE.defaultRef.Value = true;
    app.onFigureDefaultToggled();
    check(~isstruct(app.Config.Figures(1).ref), 'Use default again: the figure takes the default event');
    clear restoreAutoLimit3
end

if S.sec("4", "gather / apply, save / reopen, a version-1 config, script")
    withFigure("psth");   % section 3's figure, when the config has none
    c1 = app.gatherConfig();
    app.applyConfig(c1);
    c2 = app.gatherConfig();
    check(c1.isequalConfig(c2), 'gatherConfig -> applyConfig -> gatherConfig is the same config');
    c3 = c1;
    c3.Defaults.Window.stop = struct('line', "Stim", 'edge', "offset", 'which', "nth", 'n', 2, 'scope', "trial", ...
        'offsetSec', 0.05, 'minDurationSec', 0.01, 'maxDurationSec', 5, 'timeRange', [0 60]);
    c3.Defaults.Selection.trials = [1 3 5];
    c3.Figures(1).window = c3.Defaults.Window;
    c3.Figures(1).selection = c3.Defaults.Selection;
    app.applyConfig(c3);
    app.onConfigChanged("defaults");   % an edit re-gathers the config from the controls
    c4 = app.gatherConfig();
    check(c4.isequalConfig(c3) && app.AlignControls.StopN.Value == 2 && app.FigureAlignControls.StopN.Value == 2, ...
        'a re-gather keeps what has no control (the stop event''s offset, length and time range; trial rows) and the stop''s n');
    app.applyConfig(c1);
    app.ExportControls.Folder.Value = fullfile(outRoot, '{Name}');
    app.ExportControls.svg.Value = false;
    app.ExportControls.png.Value = true;
    app.ExportControls.Dpi.Value = 60;
    app.ReportControls.Folder.Value = outRoot;
    app.ReportControls.Dpi.Value = 50;
    app.onConfigChanged("export");
    ok = app.onSaveConfigAs(string(cfgFile));
    check(ok && isfile(cfgFile) && ~startsWith(app.Fig.Name, "*") && app.Config.File == string(cfgFile), 'Save As writes the config and clears the marker');
    app.onNewConfig();
    check(isempty(app.Config.Figures) && app.Config.File == "" && app.SelectedFigure == 0, 'New config resets to the defaults');
    app.savePreferences();
    check(strcmp(AppPrefs.getpref(g, 'LastConfigFile'), cfgFile), 'after New (no file yet) the preferences keep the last config file');
    v1File = fullfile(root, 'app_analysis_v1.json');
    writeJsonFile(v1File, struct('schema', "ephys-analysis-config", 'version', 1, 'name', "old quick look", ...
        'Plots', {{struct('kind', "psth", 'id', "psth_v1")}}));
    ok = app.openConfigFile(v1File);
    logText = strjoin(string(app.LogArea.Value), newline);
    check(ok && isscalar(app.Config.Figures) && app.Config.Figures(1).id == "psth_v1" && app.SelectedFigure == 1 ...
        && contains(app.StatusBar.Text, "config version 1") && contains(logText, "config version 1") && contains(logText, "migrated"), ...
        'a version-1 config opens with its plot migrated to a figure of the same id; the status bar and the Log say so');
    ok = app.openConfigFile(cfgFile);
    check(ok && isscalar(app.Config.Figures) && app.Config.Figures(1).id == "PSTH units" && app.SelectedFigure == 1 && ~isempty(app.Runner) ...
        && height(app.DatasetsTable.Data) == 2 && any(app.RecentConfigs == string(cfgFile)), ...
        'reopening restores the figure, selects it and rescans');
    % opened on a folder (the pipeline app's Open analysis app): the last config, its source switched
    key1 = app.Runner.Keys(kF1);
    tab0 = app.Tabs.SelectedTab;
    app.Tabs.SelectedTab = app.TabData;   % no figure preview drawn on each open
    app.openSource(F.proj, Datasets=key1);
    S1 = app.Config.Source;
    check(app.Config.File == string(cfgFile) && isscalar(app.Config.Figures) && app.Config.Figures(1).id == "PSTH units" ...
        && S1.Mode == "project" && S1.Root == F.proj && S1.Selection == "list" && isequal(S1.Datasets, key1) ...
        && isequal(app.Ticked, app.Runner.Keys == key1) && startsWith(app.Fig.Name, "*") ...
        && contains(app.StatusBar.Text, "Opened the last config") && contains(app.StatusBar.Text, "unsaved"), ...
        ['opened on a project with Datasets= it reopens the last config, its figures kept, the source switched to the project ' ...
        'and selection (the rows ticked: not the ticks of the config shown before): unsaved, the status bar says so']);
    app.openSource(F.folders(1));
    S1 = app.Config.Source;
    check(app.Config.File == string(cfgFile) && isscalar(app.Config.Figures) && S1.Mode == "folders" ...
        && isequal(S1.Folders, F.folders(1)) && height(app.DatasetsTable.Data) == 1 && startsWith(app.Fig.Name, "*"), ...
        'opened on one dataset''s output folder: the same, the source in folders mode');
    badFile = fullfile(root, 'bad_analysis.json');
    writelines("{ not json", badFile);
    AppPrefs.setpref(g, 'LastConfigFile', badFile);
    app.openSource(F.proj);
    [~, projLeaf] = fileparts(F.proj);
    check(app.Config.Name == string(projLeaf) + " quick look" && isempty(app.Config.Figures) && app.Config.File == "" ...
        && ~startsWith(app.Fig.Name, "*") && contains(app.StatusBar.Text, "could not be read"), ...
        'a last config that cannot be read: a quick look config instead, and the status bar says why');
    AppPrefs.setpref(g, 'LastConfigFile', cfgFile);
    app.openConfigFile(cfgFile);
    app.Tabs.SelectedTab = tab0;
    txt = EphysAnalysisScript.standalone(app.gatherConfig());
    check(contains(txt, "figureCompute(") && contains(txt, "renderFigure("), 'a standalone script from the app''s config draws its figure');
    scriptFile = fullfile(root, 'run_app_compact.m');
    app.onGenerateScript("compact", string(scriptFile));
    check(isfile(scriptFile) && contains(fileread(scriptFile), "EphysAnalysisConfig.load("), 'Generate script (compact) writes the file');
end

if S.sec("5", "run one figure")
    withFigure("psth");
    exported();
    savedConfig();
    app.selectTab(app.TabExport);
    I = app.onValidate();
    check(~any(I.Severity == "error"), 'the config validates');
    P = app.onPlan();
    check(height(P) == 2 && all(P.Enabled) && all(P.Plot == "PSTH units") && contains(app.StatusBar.Text, "Plan: 2 of 2 figure run(s) will draw"), ...
        'Plan: the figure on both datasets, counted in the status bar');
    app.selectTab(app.TabData);
    app.IssuesTable.Data = table();
    clickTool(app, "plan");
    check(app.Tabs.SelectedTab == app.TabExport && height(app.IssuesTable.Data) == 2 && all(app.IssuesTable.Data.Enabled), ...
        'the toolbar''s Plan shows the Export tab and fills its table as the Plan button does');
    R = app.onRunExport(Figures="PSTH units");
    files = dir(fullfile(outRoot, '**', '*PSTH_units*.png'));   % {Plot}: the id, file-name safe
    check(height(R) == 2 && all(R.Status == "done") && all(R.Kind == "figure") && numel(files) >= 2 ...
        && isfile(fullfile(outRoot, 'analysis_report.html')) && app.OpenReportButton.Enable == "on" && contains(app.RunLabel.Text, "2 done"), ...
        'Run (PSTH units): its pages for both datasets and the report');
    check(app.ToolbarReportTool.Enable == "on" && app.ToolbarFolderTool.Enable == app.OpenFolderButton.Enable ...
        && app.ToolbarRunTool.Enable == "on" && app.ToolbarPlanTool.Enable == "on" && app.ToolbarCancelTool.Enable == "off", ...
        'after the run the toolbar''s report and figure-folder tools follow the Export tab''s buttons; Run is on again, Cancel off');
    check(any(contains(string(app.LogArea.Value), "PSTH units done")), 'the Log tab has the runner''s lines');
    app.selectTab(app.TabFigures);
    app.onRemoveFigure();
    app.onSaveConfig();
    app.Tabs.SelectedTab = app.TabData;
end

if S.sec("5d.add", "the Figures tab: a figure from the rasterPsth template, the observation picker and its preview (drawn at once), < and > and Page Up")
    noFigures();
    app.FigureAutoPreviewSeconds = Inf;   % Auto is on here: a preview slowed by a loaded machine must not leave the next one out of date
    restoreAutoLimit = onCleanup(@() resetAutoLimit(app));
    app.selectTab(app.TabFigures);
    check(isempty(app.Config.Figures) && isempty(findall(app.FiguresTree, 'Type', 'uitreenode')) && ~shown(FE.id) && shown(FE.summary) ...
        && app.FigurePreviewState == "idle" && endsWith(app.helpURL("tab"), "#figures-tab") && app.RemoveFigureButton.Enable == "off" ...
        && ~isprop(app, 'FigureTemplateDropDown') && string(app.AddFigureButton.Text) == "Add" ...
        && app.FigureSections([app.FigureSections.Name] == "arrangement").Title == "Panels" ...
        && app.FigureSections([app.FigureSections.Name] == "panel").Title == "Selected panel", ...
        'the Figures tab: no figure yet, only a hint in the editor, no preview, no template drop-down; the Panels and Selected panel sections; Help goes to its section');
    app.onAddFigure("rasterPsth");
    fg = app.Config.Figures;
    check(isscalar(fg) && fg.id == "Raster+PSTH units" && numel(fg.panels) == 2 && app.SelectedFigure == 1 && app.SelectedPanel == 1 ...
        && nPatches() == 2 && string(figureNode(app.FiguresTree, 1).Text) == "Raster+PSTH units  (2 panels)" ...
        && startsWith(string(figureNode(app.FiguresTree, 1).Parent.Text), "Per unit") && string(FE.id.Value) == "Raster+PSTH units" ...
        && FE.idAuto.Value && startsWith(app.Fig.Name, "*"), ...
        'a figure from the rasterPsth template: "Raster+PSTH units" (auto ticked), two panels, two patches in the schematic, listed per unit; the config is unsaved');
    spec = app.Config.figureFor(1);
    T0 = figureObservations(app.Runner.source(app.ActiveIdx), spec);
    T = app.FigureObservations;
    nSp = cellfun(@(m) m.nSpikes(1), T.meta);
    spikesText = "  (" + regexprep(string(nSp), '(\d)(?=(\d{3})+$)', '$1,') + " spikes)";
    check(istable(T) && height(T) >= 2 && isequal(T.label, T0.label) && all(T.kind == "unit") && all(nSp > 1) ...
        && isequal(reshape(string(app.FigureObservationDropDown.Items), [], 1), T.label + spikesText) && app.FigureObservationDropDown.Value == 1 ...
        && app.FigurePreviewState == "drawn" && numel(figAxes()) == 2 && app.FigurePreviewResult.observation.label == T.label(1) ...
        && app.FigureObsPrevButton.Enable == "off" && app.FigureObsNextButton.Enable == "on" && contains(figTitle(), T.label(1)), ...
        sprintf('the picker lists the dataset''s %d units, each with its spikes, and the preview draws the first at once, in two axes (%s)', ...
        height(T), string(app.FigureObservationDropDown.Items{1})));
    app.onFigureObservationStep(1);
    check(app.FigureObservationDropDown.Value == 2 && app.FigurePreviewState == "drawn" && contains(figTitle(), T.label(2)) ...
        && string(app.FigureObservation('Raster+PSTH units')) == T.label(2) && app.FigureObsPrevButton.Enable == "on", ...
        '> draws the next unit: the title names it, and the figure remembers its pick');
    app.onKeyPress(pressed('pageup', {}));
    check(app.FigureObservationDropDown.Value == 1 && contains(figTitle(), T.label(1)), 'Page Up (<) goes back to the first unit');
    app.FigureAutoCheckBox.Value = false;   % no redraw per edit from here on: a section refreshes the preview before reading it (Auto on again only where it is itself under test)
    clear restoreAutoLimit
end

if S.sec("5d.observe", "Observe: the data types, what the active dataset holds first; the rows under it follow the choice")
    app.FigureAutoCheckBox.Value = false;   % no redraw per edit (as 5d.add leaves it)
    srcA = app.Runner.source(app.ActiveIdx);
    types = EphysAnalysisConfig.ObserveData;
    held = [srcA.hasUnits srcA.hasDetected arrayfun(@(s) srcA.signals.(s), types(3:6)) true];
    obsItems = string(FE.observe.Items);
    obsData = string(FE.observe.ItemsData);
    check(string(FE.observe.Value) == "units" && obsItems(1) == "Sorted units" && isequal(obsData, [types(held) types(~held)]) ...
        && all(contains(obsItems(numel(find(held)) + 1:end), "(not in " + srcA.name + ")")) && ~any(contains(obsItems(1:nnz(held)), "(not in")) ...
        && any(obsItems == "The dataset") && ~shown(FE.obsChannels) && shown(FE.obsClasses.su) && shown(FE.obsQuality) && shown(FE.obsIds), ...
        sprintf('Observe lists the data types, what %s holds first and plain (%s), a type it lacks marked; sorted units show the unit filter', ...
        srcA.name, strjoin(obsItems, " | ")));
    FE.observe.Value = "LFP";
    app.onConfigChanged("figure");
    TL = app.FigureObservations;
    check(app.Config.Figures(1).observe.data == "LFP" && istable(TL) && height(TL) >= 1 && all(TL.kind == "channel") ...
        && all(startsWith(TL.label, "LFP ch ")) && isequal(reshape(string(app.FigureObservationDropDown.Items), [], 1), TL.label) ...
        && shown(FE.obsChannels) && ~shown(FE.obsClasses.su) && ~shown(FE.obsIds) && ~shown(FE.obsResponse) && ~shown(FE.obsMaxUnits) ...
        && contains(string(FE.obsCount.Text), "LFP channel"), ...
        'Observe LFP: the channel rows only, and the picker lists the LFP channels (no counts)');
    if srcA.hasDetected
        FE.observe.Value = "detected";
        app.onConfigChanged("figure");
        TD = app.FigureObservations;
        check(app.Config.Figures(1).observe.data == "detected" && all(TD.kind == "unit") && all(endsWith(string(app.FigureObservationDropDown.Items), "detections)")) ...
            && shown(FE.obsIds) && shown(FE.obsUnitChannels) && ~shown(FE.obsClasses.su) && ~shown(FE.obsQuality) && ~shown(FE.obsChannels), ...
            'Observe detected spikes: the filter without classes or quality, each channel with its number of detections');
    end
    FE.observe.Value = "dataset";
    app.onConfigChanged("figure");
    check(app.Config.Figures(1).observe.data == "dataset" && height(app.FigureObservations) == 1 && app.FigureObservations.kind == "dataset" ...
        && ~shown(FE.obsChannels) && ~shown(FE.obsClasses.su) && ~shown(FE.obsIds) && ~shown(FE.obsResponse) && shown(FE.obsPerGroup), ...
        'Observe the dataset: nothing more than Per trial group, one observation');
    FE.observe.Value = "units";
    app.onConfigChanged("figure");
    check(app.Config.Figures(1).observe.data == "units" && height(app.FigureObservations) == height(T) && shown(FE.obsClasses.su), ...
        'back to sorted units: the units again');
end

if S.sec("5d.layers", "a continuous panel below (drawn at once); its layers: AUX fixed; an events layer on the raster, as marks and as spans")
    app.FigureAutoPreviewSeconds = Inf;   % Auto is on for the panel added: a preview slowed by a loaded machine must not leave it out of date
    restoreAutoLimit = onCleanup(@() resetAutoLimit(app));
    app.FigureAutoCheckBox.Value = true;   % the automatic preview itself: the panel added is drawn at once
    app.onPanelSelected(2);
    app.onNewPanel(Type="continuous", Where="below");
    fg = app.Config.Figures(1);
    p3 = fg.panels(end);
    check(fg.id == "Raster+PSTH+Continuous units+LFP" && string(FE.id.Value) == fg.id && string(figureNode(app.FiguresTree, 1).Text) == fg.id + "  (3 panels)" ...
        && isKey(app.FigureObservation, char(fg.id)) && ~isKey(app.FigureObservation, 'Raster+PSTH units') ...
        && app.FigureIdRenames('Raster+PSTH units') == fg.id, ...
        'the automatic id follows the new panel (Continuous, its LFP); the Id row and the tree show it, the observation picked moves with it');
    check(fg.grid.rows == 3 && fg.grid.cols == 1 && p3.type == "continuous" && p3.row == 3 && isscalar(p3.layers) ...
        && p3.layers.source == "LFP" && p3.layers.binding == "observation" && app.SelectedPanel == 3 && nPatches() == 3 ...
        && app.FigurePreviewState == "drawn" && numel(figAxes()) == 3 && contains(app.StatusBar.Text, "below psth_1"), ...
        'Continuous signal, Below: a 3 x 1 stack whose new panel''s LFP layer follows the observed unit, drawn at once');
    app.FigureAutoCheckBox.Value = false;   % Auto off again: no redraw per edit
    check(string(FE.panelType.Value) == "continuous" && shown(FE.contDisplay) && shown(FE.errorType) && shown(FE.layerFollows) ...
        && ~shown(FE.binMs) && ~shown(FE.histStyle) && ~shown(FE.rasterSort) && ~shown(FE.evLine) && ~shown(FE.group) ...
        && FE.layerBinding.Enable == "on" && contains(string(FE.layerFollows.Text), "own LFP channel") ...
        && app.FigureSections([app.FigureSections.Name] == "options").Title == "Continuous signal options", ...
        'the editor shows the continuous panel''s rows only: its options, its layer following the unit');
    FE.addSource.Value = "AUX";
    FE.addSource.ValueChangedFcn(FE.addSource, []);
    app.onAddLayer();
    L = app.Config.Figures(1).panels(3).layers(end);
    check(L.source == "AUX" && L.binding == "fixed" && isempty(L.channels) && FE.layerBinding.Enable == "off" ...
        && string(FE.layerBinding.Value) == "fixed" && shown(FE.layerChannels) && ~shown(FE.layerFollows), ...
        'an AUX layer beside the unit''s LFP is fixed (AUX has no recording channel to follow), every AUX channel');
    FE.layerSource.Value = "LFP";
    app.onConfigChanged("figure");
    FE.layerBinding.Value = "observation";
    app.onConfigChanged("figure");
    FE.layerSource.Value = "AUX";
    app.onConfigChanged("figure");
    check(app.Config.Figures(1).panels(3).layers(end).binding == "fixed" && FE.layerBinding.Enable == "off", ...
        'a following LFP layer switched to AUX turns fixed');
    app.onRemoveLayer();
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
    app.refreshFigurePreview(Force=true);
    L = app.Config.Figures(1).panels(1).layers(2);
    marks = findall(app.FigurePreviewPanel, 'Tag', 'rasterEvent');
    nMarks = 0;
    for m = reshape(marks, 1, [])
        nMarks = nMarks + nnz(isfinite(m.XData));
    end
    check(L.source == "events" && L.binding == "fixed" && L.event.line == "Stim" && L.event.edge == "offset" && L.eventsAs == "marks" ...
        && app.FigurePreviewState == "drawn" && nMarks > 0, sprintf('Stim offset marks are drawn on the raster''s rows (%d marks)', nMarks));
    FE.evDrawAs.Value = "span";
    app.onConfigChanged("figure");
    spanRows = shown(FE.evSpanStyle) && shown(FE.evColor) && ~shown(FE.evMarker) && ~shown(FE.layerColor) && FE.evDrawAs.Enable == "on";
    FE.evSpanStyle.Value = "--";
    FE.evSpanWidth.Value = 3;
    FE.evSpanAlpha.Value = 0.5;
    app.onConfigChanged("figure");
    app.refreshFigurePreview(Force=true);
    L = app.Config.Figures(1).panels(1).layers(2);
    spans = findall(app.FigurePreviewPanel, 'Tag', 'eventSpan');
    spans = spans(arrayfun(@(m) any(isfinite(m.XData)), spans));
    check(spanRows && L.eventsAs == "span" && L.event.spanStyle == "--" && L.event.spanWidth == 3 && L.event.spanAlpha == 0.5 ...
        && app.FigurePreviewState == "drawn" && ~isempty(spans) && all([spans.LineWidth] == 3) && all(string({spans.LineStyle}) == "--"), ...
        'Draw as a line from onset to offset: the span''s rows show (not the marker), its style, width and opacity reach the config and the raster''s lines');
    FE.evDrawAs.Value = "marks";
    app.onConfigChanged("figure");
    clear restoreAutoLimit
end

if S.sec("5d.keys", "the section keys (Ctrl+digit); the supersections: their order, collapsing, Ctrl+8 and Alt+2")
    app.onFigureSectionToggled("observations");
    collapsed = ~app.FigureSections([app.FigureSections.Name] == "observations").Expanded;
    app.onKeyPress(pressed('1', {'control'}));
    check(collapsed && app.FigureSections([app.FigureSections.Name] == "observations").Expanded ...
        && app.FigureSections([app.FigureSections.Name] == "observations").Key == "1" ...
        && app.FigureSections([app.FigureSections.Name] == "palign").Key == "7" ...
        && app.FigureSections([app.FigureSections.Name] == "options").Key == "9" ...
        && app.FigureSections([app.FigureSections.Name] == "ref").Key == "2" ...
        && app.FigureSections([app.FigureSections.Name] == "arrangement").Key == "5" ...
        && app.FigureSections([app.FigureSections.Name] == "note").Key == "0" ...
        && app.FigureSections([app.FigureSections.Name] == "style").Key == "" ...
        && app.FigureSections([app.FigureSections.Name] == "sessions").Key == "" ...
        && ~any([app.FigureSections.Name] == "common"), ...
        'Ctrl+1 opens the collapsed Observations section; Event reference is Ctrl+2, Arrangement Ctrl+5, Panel alignment Ctrl+7, Options Ctrl+9, Text note Ctrl+0; Appearance and Sessions have no key');
    % the supersections
    U = app.FigureSupers;
    rowOf = @(h) h.Layout.Row;
    check(isequal([U.Name], ["figure" "panel" "look"]) && all(arrayfun(@(u) shown(u.Header), U)) ...
        && secOf("observations").Super == "figure" && secOf("ref").Super == "figure" && secOf("sessions").Super == "figure" ...
        && secOf("arrangement").Super == "figure" && secOf("panel").Super == "panel" && secOf("options").Super == "panel" ...
        && secOf("overlays").Super == "panel" && secOf("style").Super == "look" && secOf("looks").Super == "look" ...
        && rowOf(U(1).Header) < rowOf(secOf("observations").Grid) && rowOf(secOf("observations").Grid) < rowOf(secOf("ref").Grid) ...
        && rowOf(secOf("arrangement").Grid) < rowOf(U(2).Header) && rowOf(U(2).Header) < rowOf(secOf("panel").Grid) ...
        && rowOf(secOf("overlays").Grid) < rowOf(U(3).Header) && rowOf(U(3).Header) < rowOf(secOf("style").Grid) ...
        && contains(U(1).Header.Text, "FIGURE") && contains(U(1).Header.Text, "Alt+1") && contains(U(2).Header.Text, "raster_1 (Raster)") ...
        && contains(U(3).Header.Text, "Alt+3"), ...
        'three supersections head the editor''s sections in order: Figure, Panel (naming the selected panel) and Look, each with its Alt key');
    app.onFigureSuperToggled("panel");
    shut = ~app.FigureSupers(2).Expanded && ~shown(FE.panelType) && ~shown(FE.layerList) && startsWith(strtrim(app.FigureSupers(2).Header.Text), "►") ...
        && shown(app.FigureSupers(2).Header) && shown(FE.observe) && secOf("layers").Expanded;
    app.onKeyPress(pressed('8', {'control'}));
    check(shut && app.FigureSupers(2).Expanded && secOf("layers").Expanded && shown(FE.layerList), ...
        'collapsing the Panel supersection hides its sections (each keeps its own state); Ctrl+8 opens it again with Layers');
    app.onFigureSuperToggled("panel");
    app.onKeyPress(pressed('2', {'alt'}));
    viaAlt = app.FigureSupers(2).Expanded && shown(FE.panelType);
    app.onKeyPress(pressed('2', {'alt' 'control'}));   % AltGr+2 on Windows: a character, not the key
    check(viaAlt && app.FigureSupers(2).Expanded, 'Alt+2 opens the collapsed Panel supersection; Ctrl+Alt+2 (AltGr) is left alone');
end

if S.sec("5d.search", "the search: by label, listed as Supersection > Section > Row; a row the raster does not show says why")
    app.onPanelSelected(1);   % the raster, as 5d.layers leaves it
    X = app.FigureSearchIndex;
    lb = app.FigureSearchList;
    app.onKeyPress(pressed('f', {'control'}));
    app.FigureSearchField.Value = 'bin';
    app.onFigureSearch("bin");
    check(app.FigureSearchState == "typing" && shown(lb) && X(lb.ItemsData(1)).Label == "Bin (ms)" ...
        && string(lb.Items{1}) == "Panel > Raster options > Bin (ms)" && numel(X) > 150 ...
        && any(arrayfun(@(e) e.Label == "Line" && e.Section == "ref", X)) && any(arrayfun(@(e) e.Label == "Use default" && e.Section == "window", X)), ...
        sprintf('Ctrl+F, "bin": "Panel > Raster options > Bin (ms)" first of %d, though a raster hides it; the alignment rows are found too (%d rows indexed)', ...
        numel(lb.Items), numel(X)));
    app.onKeyPress(pressed('return', {}));
    check(app.SelectedPanel == 1 && contains(app.StatusBar.Text, "Bin (ms) is an option of PSTH, heat map and unit correlation panels, not of raster panels") ...
        && app.FigureSearchState == "", 'Enter on a row the raster does not show says why in the status bar, and nothing moves');
end

if S.sec("5d.outline", "the panel keys across the grid and in the panel order; the preview's outline of the selected panel follows them without a redraw, and a resize")
    app.onPanelSelected(1);   % raster_1, as 5d.layers leaves it
    app.refreshFigurePreview(Force=true);   % the outline is read from the preview drawn
    P = app.FigurePreviewPanel;
    ax0 = figAxes();
    [bm, nm] = markBox(P);
    check(app.FigurePreviewState == "drawn" && nm == 4 && boxNear(bm, expectBox(P, "raster_1")), ...
        'the preview outlines the selected panel (raster_1): a frame of four strips round its axes and labels');
    app.onKeyPress(pressed('downarrow', {'control' 'alt'}));
    [bm, nm] = markBox(P);
    moved = app.SelectedPanel == 2 && nm == 4 && boxNear(bm, expectBox(P, "psth_1")) && numel(figAxes()) == numel(ax0) ...
        && all(ismember(figAxes(), ax0)) && app.FigurePreviewState == "drawn" && contains(app.FigureSupers(2).Header.Text, "psth_1");
    app.onKeyPress(pressed('downarrow', {'control' 'alt'}));
    third = app.SelectedPanel == 3;
    app.onKeyPress(pressed('downarrow', {'control' 'alt'}));
    check(moved && third && app.SelectedPanel == 3 && contains(app.StatusBar.Text, "No panel below continuous_1"), ...
        'Ctrl+Alt+Down selects the panel below (psth_1, then continuous_1; none below the last): the outline moves, the preview is not drawn again');
    app.onKeyPress(pressed('leftarrow', {'control' 'alt'}));
    noLeft = app.SelectedPanel == 3 && contains(app.StatusBar.Text, "No panel to the left of continuous_1");
    app.onKeyPress(pressed('uparrow', {'control' 'alt'}));
    up = app.SelectedPanel == 2;
    app.onKeyPress(pressed('leftbracket', {'control'}));
    prev = app.SelectedPanel == 1;
    app.onKeyPress(pressed('leftbracket', {'control'}));
    round1 = app.SelectedPanel == 3;
    app.onKeyPress(pressed('rightbracket', {'control'}));
    check(noLeft && up && prev && round1 && app.SelectedPanel == 1 && contains(app.StatusBar.Text, "panel 1 of 3"), ...
        'Ctrl+Alt+Left (none), Ctrl+Alt+Up; Ctrl+[ and Ctrl+] step through the panel order, round at the ends');
    % the outline follows the figure laid out again (the preview resized)
    app.onPanelSelected(2);
    pos0 = findPanelAxes(P, "psth_1").Position;
    app.Fig.Position(3) = app.Fig.Position(3) + 160;
    drawnow;
    P.SizeChangedFcn(P, []);   % (MATLAB runs it for a visible figure only)
    [bm, nm] = markBox(P);
    check(nm == 4 && ~isequal(findPanelAxes(P, "psth_1").Position, pos0) && boxNear(bm, expectBox(P, "psth_1")), ...
        'the preview made wider, the figure is laid out again and the outline follows psth_1''s axes');
    app.Fig.Position(3) = app.Fig.Position(3) - 160;
    drawnow;
    P.SizeChangedFcn(P, []);
    h = app.onOpenFigureWindow();
    check(isgraphics(h) && isempty(findall(h, 'Tag', 'previewPanelMark')) && numel(findall(P, 'Tag', 'previewPanelMark')) == 4, ...
        'Open in window draws no outline (it is the preview''s, not the figure''s)');
    delete(h);
end

if S.sec("5d.goto", "right-click Go to setting: the part's setting, in the panel the part is in")
    fid = app.Config.Figures(app.SelectedFigure).id;
    panel0 = app.SelectedPanel;
    styleOpen = secOf("style").Expanded;
    if styleOpen; app.onFigureSectionToggled("style"); end
    okSem = app.gotoFigureSetting(fid, "sem", "psth_1");
    check(okSem && app.SelectedPanel == 2 && secOf("style").Expanded && shown(FE.showSEM), ...
        'Go to setting on a PSTH''s error band: psth_1 is picked and the Show row of Appearance is open');
    okTitle = app.gotoFigureSetting(fid, "tileTitle", "raster_1");
    okFig = app.gotoFigureSetting(fid, "zeroLine", "");
    check(okTitle && app.SelectedPanel == 1 && okFig, ...
        'a tile title goes to its panel''s Title row; the event line (t = 0) to the Event reference section');
    app.onPanelSelected(panel0);
    if secOf("style").Expanded ~= styleOpen; app.onFigureSectionToggled("style"); end
end

if S.wants("5d.search")   % the search, continued: a shown row gone to (its supersection and section open, its label highlighted), Down and Escape, a section by its title, the keys window
    app.onPanelSelected(2);   % the PSTH, as 5d.outline leaves it
    optionsOpen = secOf("options").Expanded;
    if optionsOpen; app.onFigureSectionToggled("options"); end
    app.onFigureSuperToggled("panel");
    app.onFigureSearch("bin");
    iBin = lb.ItemsData(1);
    app.onKeyPress(pressed('return', {}));
    check(app.FigureSupers(2).Expanded && secOf("options").Expanded && shown(FE.binMs) ...
        && string(app.StatusBar.Text) == "Panel > PSTH options > Bin (ms)" && isequal(X(iBin).Flash.BackgroundColor, [1.00 0.90 0.35]), ...
        'Enter on Bin (ms) with the PSTH selected opens the Panel supersection and the options, scrolls there and highlights the row');
    app.onFigureSearch("line");
    v1 = lb.Value;
    app.onKeyPress(pressed('downarrow', {}));
    down = lb.Value == lb.ItemsData(2) && v1 == lb.ItemsData(1);
    app.onKeyPress(pressed('escape', {}));
    check(down && ~shown(lb) && app.FigureSearchState == "" && string(app.FigureSearchField.Value) == "", ...
        'Down picks the next match while typing; Escape clears the search');
    app.onFigureSearch("layers");
    first = X(lb.ItemsData(1));
    app.onFigureSearch("");
    check(first.Row == 0 && first.Section == "layers", 'a section is found by its title ("layers")');
    w = app.onFigureKeys();
    keysT = findall(w, 'Tag', 'keysTable').Data;
    w2 = app.onFigureKeys();
    check(isequal(w, w2) && any(startsWith(keysT.Key, "Alt+1")) && any(keysT.Key == "Ctrl+F") && any(contains(keysT.Key, "Ctrl+Alt+arrows")) ...
        && any(contains(keysT.Key, "F6")), 'the "?" button lists the tab''s keys in one window (a second press brings it back)');
    delete(w);
    if ~optionsOpen; app.onFigureSectionToggled("options"); end
    app.onPanelSelected(1);
end

if S.sec("5d.stale", "Out of date with Auto off; Cancel on the busy card")
    app.FigureAutoPreviewSeconds = Inf;   % Auto is on here: a preview slowed by a loaded machine must not leave the next one out of date
    restoreAutoLimit = onCleanup(@() resetAutoLimit(app));
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
    clear restoreAutoLimit
end

if S.sec("5d.align", "the figure's own event, a panel's own window: locked while linked, Apply to all panels, Re-link all panels")
    app.FigureAutoCheckBox.Value = false;   % no redraw per edit (as 5d.add leaves it)
    FA.Edge.Value = 'offset';
    app.onFigureAlignEdited("ref");
    app.refreshFigurePreview(Force=true);
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
    app.refreshFigurePreview(Force=true);
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
    app.refreshFigurePreview(Force=true);
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
end

if S.sec("5d.filter", "a tightened unit filter, one nothing passes, a listing error")
    app.FigureAutoCheckBox.Value = false;   % no redraw per edit (as 5d.add leaves it)
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
    app.refreshFigurePreview(Force=true);
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
end

if S.sec("5d.pergroup", "Per trial group: the picker lists every unit and group, the preview draws one group")
    app.FigureAutoCheckBox.Value = false;   % no redraw per edit (as 5d.add leaves it)
    groupedBy("Depth");
    n0 = height(app.FigureObservations);   % the units listed (5d.filter's n0)
    FE.obsPerGroup.Value = true;
    app.onConfigChanged("figure");
    app.refreshFigurePreview(Force=true);
    Tg = app.FigureObservations;
    nGa = numel(unique(Tg.group));
    check(app.Config.Figures(1).observe.perGroup && nGa >= 2 && height(Tg) == n0 * nGa && all(endsWith(Tg.label, " · " + Tg.groupLabel)) ...
        && all(startsWith(reshape(string(app.FigureObservationDropDown.Items), [], 1), Tg.label + "  (")) && app.FigurePreviewState == "drawn" ...
        && height(app.FigurePreviewResult.groups) == 1 && app.FigurePreviewResult.observation.groupLabel == Tg.groupLabel(1) ...
        && contains(string(FE.obsCount.Text), "trial groups") && contains(figTitle(), Tg.label(1)), ...
        sprintf('Per trial group lists every unit and group (%d x %d) in the picker; the preview draws the first group''s epochs only', n0, nGa));
    app.onFigureObservationStep(1);
    check(app.FigurePreviewState == "drawn" && app.FigurePreviewResult.observation.groupLabel == Tg.groupLabel(2) ...
        && string(app.FigurePreviewResult.groups.label) == Tg.groupLabel(2) && contains(figTitle(), Tg.groupLabel(2)), ...
        '> steps to the next group of the unit');
    FE.obsPerGroup.Value = false;
    app.onConfigChanged("figure");
    check(~app.Config.Figures(1).observe.perGroup && height(app.FigureObservations) == n0 && all(isnan(app.FigureObservations.group)), ...
        'unticked, one observation per unit again');
end

if S.sec("5d.ownsel", "a panel's own trial selection: locked while linked, copied when unticked, re-linked, applied to all")
    app.FigureAutoCheckBox.Value = false;   % no redraw per edit (as 5d.add leaves it)
    groupedBy("Depth");
    app.onPanelSelected(2);   % the PSTH
    lockedSel = FE.panelSameSel.Value && FE.panelSameSel.Enable == "on" && FP.Group1.Enable == "off" && FP.Filter.Enable == "off";
    FP.Group1.Value = '(none)';
    app.onPanelAlignEdited("selection");   % as if an edit came in: ignored while linked
    ignoredSel = isequal(app.Config.Figures(1).panels(2).selection, "default");
    FE.panelSameSel.Value = false;
    FE.panelSameSel.ValueChangedFcn(FE.panelSameSel, []);
    p2 = app.Config.Figures(1).panels(2);
    check(lockedSel && ignoredSel && isstruct(p2.selection) && isequal(p2.selection.groupBy, "Depth") && FP.Group1.Enable == "on" ...
        && string(FP.Group1.Value) == "Depth" && FE.alignApplyAll.Enable == "on" && FE.alignRelinkAll.Enable == "on" ...
        && contains(app.StatusBar.Text, "trial selection of its own"), ...
        'the panel''s trial selection: the figure''s, locked, while ticked (an edit is not taken); unticking copies it into the panel');
    FP.Group1.Value = '(none)';
    app.onPanelAlignEdited("selection");
    app.refreshFigurePreview(Force=true);
    p2 = app.Config.Figures(1).panels(2);
    Fo2 = app.FigurePreviewResult;
    check(isstruct(p2.selection) && isempty(p2.selection.groupBy) && app.FigurePreviewState == "drawn" && Fo2.panels(2).ownSelection ...
        && height(Fo2.panels(2).groups) == 1 && height(Fo2.groups) > 1 && ~Fo2.panels(1).ownSelection ...
        && any(arrayfun(@(a) string(a.Title.String) == "all trials", figAxes())), ...
        'an edit of its own selection (no Group by): the preview draws the PSTH on its own single group, titled "all trials"');
    FE.alignRelinkAll.ButtonPushedFcn(FE.alignRelinkAll, []);
    check(isequal(app.Config.Figures(1).panels(2).selection, "default") && FE.panelSameSel.Value && FP.Group1.Enable == "off" ...
        && string(FP.Group1.Value) == "Depth" && contains(app.StatusBar.Text, "Re-linked 1 panel"), ...
        'Re-link all panels drops the panel''s own selection: the figure''s again, locked');
    FE.panelSameSel.Value = false;
    FE.panelSameSel.ValueChangedFcn(FE.panelSameSel, []);
    FP.Order.Value = 'descending';
    app.onPanelAlignEdited("selection");
    FE.alignApplyAll.ButtonPushedFcn(FE.alignApplyAll, []);
    app.refreshFigurePreview(Force=true);
    fg = app.Config.Figures(1);
    check(isstruct(fg.selection) && fg.selection.groupOrder == "descending" && all(arrayfun(@(q) isequal(q.selection, "default"), fg.panels)) ...
        && ~FE.defaultSelection.Value && FE.panelSameSel.Value && string(FA.Order.Value) == "descending" && app.FigurePreviewState == "drawn", ...
        'Apply to all panels makes the panel''s own selection the figure''s, every panel linked to it');
    FE.defaultSelection.Value = true;
    app.onFigureDefaultToggled();
    check(isequal(app.Config.Figures(1).selection, "default"), 'the figure''s selection back to the default');
end

if S.sec("5d.conttrials", "a continuous panel's Trials row: the Options rows reach the config, the traces are drawn")
    app.FigureAutoCheckBox.Value = false;   % no redraw per edit (as 5d.add leaves it)
    app.onPanelSelected(3);
    offRows = shown(FE.contTrials) && ~shown(FE.heatRows) && FE.maxTrials.Enable == "off";
    FE.contTrials.Value = "faint";
    FE.maxTrials.Value = 4;
    app.onConfigChanged("figure");
    app.refreshFigurePreview(Force=true);
    o3 = app.Config.Figures(1).panels(3).options;
    check(offRows && o3.trials == "faint" && o3.maxTrials == 4 && FE.maxTrials.Enable == "on" && app.FigurePreviewState == "drawn" ...
        && ~isempty(findall(app.FigurePreviewPanel, 'Tag', 'trialTrace')) ...
        && size(app.FigurePreviewResult.panels(3).layers(1).R.data, 3) <= 4, ...
        'a continuous panel''s Trials row: faint, at most 4, reach the config; the preview draws the traces');
    FE.contTrials.Value = "off";
    FE.maxTrials.Value = Inf;
    app.onConfigChanged("figure");
end

if S.sec("5d.type", "a type change: the PSTH's bins, a heat map and its rows, back to a PSTH; a layer's binding")
    app.FigureAutoCheckBox.Value = false;   % no redraw per edit (as 5d.add leaves it)
    app.onPanelSelected(2);
    openBins = FE.binMs.Enable == "on" && FE.histStyle.Enable == "on" && FE.binMs.Value == 10;
    FE.binMs.Value = 20;
    app.onConfigChanged("figure");
    app.refreshFigurePreview(Force=true);
    spec = app.Config.figureFor(1);
    check(openBins && app.Config.Figures(1).panels(2).options.bins.BinSec == 0.02 && spec.panels(2).options.bins.BinSec == 0.02 ...
        && app.FigurePreviewState == "drawn" && app.FigurePreviewResult.spec.panels(2).options.bins.BinSec == 0.02, ...
        'the PSTH''s bins row is its own: an edit reaches its options and the preview is computed again');
    FE.panelType.Value = "heatmap";
    app.onPanelTypeChanged();
    app.refreshFigurePreview(Force=true);
    p2 = app.Config.Figures(1).panels(2);
    check(p2.type == "heatmap" && isscalar(p2.layers) && p2.layers.source == "units" && p2.layers.binding == "fixed" ...
        && app.Config.figureFor(1).panels(2).options.bins.BinSec == 0.02 && isfield(p2.options, 'order') && shown(FE.group) && shown(FE.order) ...
        && contains(app.StatusBar.Text, "is now a heat map") && app.FigurePreviewState == "drawn", ...
        'a heat map now: its units layer kept but fixed, the PSTH''s bins kept, its own rows shown');
    itemRows = shown(FE.heatRows) && ~shown(FE.rasterSort) && FE.layerBinding.Enable == "off";
    FE.heatRows.Value = "trials";
    app.onConfigChanged("figure");
    trialShown = shown(FE.rasterSort) && shown(FE.rasterByGroup) && ~shown(FE.order) && ~shown(FE.group) && FE.layerBinding.Enable == "on";
    FE.layerBinding.Value = "observation";
    FE.rasterSortOrder.Value = "descending";
    app.onConfigChanged("figure");
    app.refreshFigurePreview(Force=true);
    p2 = app.Config.Figures(1).panels(2);
    Rh = app.FigurePreviewResult.panels(2).layers(1).R;
    img = findall(app.FigurePreviewPanel, 'Tag', 'image');
    check(itemRows && trialShown && p2.options.rows == "trials" && p2.options.rasterSortOrder == "descending" ...
        && p2.layers(1).binding == "observation" && app.FigurePreviewState == "drawn" && isfield(Rh, 'trialMatrix') ...
        && isscalar(img) && size(img.CData, 1) == height(app.FigurePreviewResult.epochs), ...
        'a heat map''s Rows "trials": the raster sort rows show (not the row order or group), its layer may follow the unit; one row per epoch drawn');
    FE.heatRows.Value = "items";
    app.onConfigChanged("figure");
    check(app.Config.Figures(1).panels(2).layers(1).binding == "fixed" && app.Config.Figures(1).panels(2).options.rows == "items", ...
        'back to its units as rows, the layer is fixed again');
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
    app.refreshFigurePreview(Force=true);
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
end

if S.sec("5d.applyall", "Apply to all panels (Options), Re-link all panels (Panel alignment)")
    app.FigureAutoCheckBox.Value = false;   % no redraw per edit (as 5d.add leaves it)
    app.onPanelSelected(2);   % the PSTH
    FE.binMs.Value = 10;
    FE.waveMode.Value = "mean";
    FE.baselineMode.Value = "zscore";
    app.onConfigChanged("figure");
    fg0 = app.Config.Figures(1);
    ids = [fg0.panels.id];
    appliable = FE.optApplyAll.Enable == "on" && FE.alignRelinkAll.Enable == "off";   % own options are no alignment to re-link
    FE.optApplyAll.ButtonPushedFcn(FE.optApplyAll, []);
    fg = app.Config.Figures(1);
    st = string(app.StatusBar.Text);
    check(appliable && fg.panels(1).options.waveform.mode == "mean" && fg.panels(3).options.baseline.Mode == "none" ...
        && isequaln(fg.panels(3).options, fg0.panels(3).options) && contains(st, ids(1) + " (waveform)") ...
        && contains(st, ids(3) + " kept their own baseline") && contains(st, """zscore""") && FE.alignRelinkAll.Enable == "off", ...
        'Apply to all panels: the PSTH''s waveform inset goes to the raster; the continuous panel keeps its baseline (no zscore there); the status bar says so');
    FE.waveMode.Value = "off";
    FE.baselineMode.Value = "none";
    app.onConfigChanged("figure");
    FE.optApplyAll.ButtonPushedFcn(FE.optApplyAll, []);
    FE.optApplyAll.ButtonPushedFcn(FE.optApplyAll, []);   % again: nothing left to copy
    check(app.Config.Figures(1).panels(1).options.waveform.mode == "off" && contains(string(app.StatusBar.Text), "already"), ...
        'applied back, then once more: the other panels have the PSTH''s options already');
    app.onFigureSectionToggled("palign");
    app.onFigureSectionToggled("options");
    app.onKeyPress(pressed('7', {'control'}));
    toPalign = app.FigureSections([app.FigureSections.Name] == "palign").Expanded;
    app.onKeyPress(pressed('9', {'control'}));
    check(toPalign && app.FigureSections([app.FigureSections.Name] == "options").Expanded, 'Ctrl+7 goes to Panel alignment, Ctrl+9 to Options');
end

if S.sec("5d.look", "the gather / apply round trip, a remembered look and Forget, data tips")
    app.FigureAutoCheckBox.Value = false;   % no redraw per edit (as 5d.add leaves it)
    app.onPanelSelected(2);   % the PSTH, as 5d.applyall leaves it
    s1 = app.gatherConfig();
    app.applyConfig(s1);
    s2 = app.gatherConfig();
    check(isequaln(s1.Figures, s2.Figures) && s1.isequalConfig(s2) && app.SelectedFigure == 1 && app.SelectedPanel == 2, ...
        'gatherConfig -> applyConfig -> gatherConfig keeps the figure and the panel picked');
    app.refreshFigurePreview(Force=true);
    ctx = getappdata(app.FigurePreviewPanel, PlotAesthetics.ContextKey);
    figLook = struct('role', "rateFill", 'group', "", 'property', "FaceAlpha", 'value', 0.4);
    ctx.onRemember(figLook);
    check(isstruct(ctx) && ctx.kind == "figure" && ctx.id == app.Config.Figures(1).id && isscalar(app.Config.Figures(1).aesthetics) ...
        && app.Config.Figures(1).aesthetics.value == 0.4 && isequal(app.Runner.Config.Figures(1).aesthetics, app.Config.Figures(1).aesthetics) ...
        && startsWith(string(FE.looksText.Text), "1 remembered") && FE.looksForget.Enable == "on", ...
        'the figure preview is editable (right-click); rules remembered for the figure go into the config (rememberFigureAesthetics)');
    tipParts = findall(app.FigurePreviewPanel, '-function', @(o) isappdata(o, FigureDataTips.InfoKey));
    tipItems = findall(app.Fig, 'Tag', FigureDataTips.MenuTag);
    tipMenu = findobj(app.DesignMenu.Children, 'flat', 'Tag', 'DataTipFieldsMenu');
    dlg0 = findall(groot, 'Type', 'figure', 'Name', 'Data tip fields');
    if isscalar(tipMenu); tipMenu.MenuSelectedFcn(tipMenu, []); end
    dlg = setdiff(findall(groot, 'Type', 'figure', 'Name', 'Data tip fields'), dlg0);
    check(~isempty(tipParts) && ~isempty(tipItems) && isscalar(tipMenu) && isscalar(dlg) && numel(findall(dlg, 'Type', 'uicheckbox')) == height(FigureDataTips.fields()), ...
        sprintf(['the figure preview has data tips (%d parts) and "Data tip fields..." on its right-click menus; the Design menu''s ' ...
        'Data tip fields... opens the dialog, a check box per field'], numel(tipParts)));
    delete(dlg);
    FE.looksForget.ButtonPushedFcn(FE.looksForget, []);
    check(isempty(app.Config.Figures(1).aesthetics) && FE.looksForget.Enable == "off" && app.FigurePreviewState == "drawn", ...
        'Forget drops them and redraws the preview without them');
end

if S.sec("5d.otherconfig", "another config opened; sizes the spinners cannot show")
    app.refreshFigurePreview(Force=true);   % drawn, so that another config opened is seen to drop the drawing
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
end

if S.sec("5d.remove", "Remove panel, Duplicate, Remove")
    app.FigureAutoCheckBox.Value = false;   % no redraw per edit (as 5d.add leaves it)
    app.onPanelSelected(3);
    app.onRemovePanel();
    app.refreshFigurePreview(Force=true);
    fg = app.Config.Figures(1);
    check(fg.grid.rows == 2 && numel(fg.panels) == 2 && nPatches() == 2 && app.SelectedPanel == 2 && numel(figAxes()) == 2 ...
        && app.FigurePreviewState == "drawn", 'Remove panel takes the continuous panel and its row away');
    app.onDuplicateFigure();
    check(numel(app.Config.Figures) == 2 && app.Config.Figures(1).id == "Raster+PSTH units" && app.Config.Figures(2).id == "Raster+PSTH units (2)" ...
        && app.SelectedFigure == 2 && isequaln(rmfield(app.Config.Figures(2), 'id'), rmfield(app.Config.Figures(1), 'id')) ...
        && string(FE.id.Value) == "Raster+PSTH units (2)", ...
        'Duplicate copies the figure as "Raster+PSTH units (2)" (the id followed the panel removed), right after it, and selects the copy');
    app.onRemoveFigure();
    check(isscalar(app.Config.Figures) && app.SelectedFigure == 1 && string(FE.id.Value) == "Raster+PSTH units", 'Remove takes the copy away');
end

if S.sec("5d.arrange", "the arrangement on a blank figure: New panel above, right and left, spans, sizes and spacing, the Spacing window, Move, layer and figure Up and Down (Auto off: nothing here needs drawing)")
    app.FigureAutoCheckBox.Value = false;
    app.onAddFigure("blank");
    cellOf = @(id) arrayfun(@(q) [q.row q.col q.rowSpan q.colSpan], app.Config.Figures(2).panels([app.Config.Figures(2).panels.id] == id), ...
        'UniformOutput', false);
    gridOf = @() [app.Config.Figures(2).grid.rows app.Config.Figures(2).grid.cols];
    app.onNewPanel(Type="psth", Where="right");
    check(app.SelectedFigure == 2 && isequal(gridOf(), [1 1]) && isequal(cellOf("psth_1"), {[1 1 1 1]}), ...
        'a blank figure''s first panel goes to row 1, column 1, whatever the place');
    app.onNewPanel(Type="raster", Where="above");
    check(isequal(gridOf(), [2 1]) && isequal(cellOf("raster_1"), {[1 1 1 1]}) && isequal(cellOf("psth_1"), {[2 1 1 1]}) ...
        && app.Config.Figures(2).panels(app.SelectedPanel).id == "raster_1", 'Above: a row before the selected panel; the new one is selected');
    app.onNewPanel(Type="raster", Where="right");
    check(isequal(gridOf(), [2 2]) && isequal(cellOf("raster_2"), {[1 2 1 1]}) && isequal(cellOf("psth_1"), {[2 1 1 1]}), ...
        'Right: a column after it, in its row');
    app.onNewPanel(Type="raster", Where="left");
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
    FE.panelWidth.Value = 60;
    FE.panelAlign.Value = "right";
    app.onConfigChanged("figure");
    pS = app.Config.Figures(2).panels(app.SelectedPanel);
    check(isequal(pS.size, [0.6 1]) && pS.align == "right" && pS.valign == "middle" && FE.panelAlign.Enable == "on" ...
        && FE.panelVAlign.Enable == "off", ...
        'Panel size and Align reach the selected panel alone (60 % of its cell''s width, at the right); Align up the cell off while 100 % high');
    FE.spacingDialog.ButtonPushedFcn(FE.spacingDialog, []);
    dS = findall(groot, 'Type', 'figure', 'Tag', 'figureSpacingDialog');
    DS = dS.UserData;
    DS.Spacing.Value = "custom"; DS.Spacing.ValueChangedFcn(DS.Spacing, []);
    DS.Units.Value = "px"; DS.Units.ValueChangedFcn(DS.Units, []);
    DS.RowGap.Value = 10; DS.RowGap.ValueChangedFcn(DS.RowGap, []);
    DS.ColGap.Value = 4; DS.ColGap.ValueChangedFcn(DS.ColGap, []);
    TS = DS.Table.Data;
    check(isscalar(dS) && DS.FigureId == app.Config.Figures(2).id && app.Config.Figures(2).id == "Raster+PSTH units (2)" && height(TS) == 3 && isequal(TS.Gap, [10; 4; 4]) && DS.Units.Enable == "on", ...
        'Spacing...: the window lists every gap of the 2 x 3 grid, filled by the one gap between rows and the one between columns');
    DS.Table.CellEditCallback(DS.Table, struct('Indices', [3 2], 'NewData', 16));
    DS.Table.CellEditCallback(DS.Table, struct('Indices', [1 2], 'NewData', -3));
    DS.Apply.ButtonPushedFcn(DS.Apply, []);
    G3 = app.Config.Figures(2).grid;
    check(isvalid(dS) && G3.spacing == "custom" && G3.gapUnits == "px" && G3.rowGap == 10 && isempty(G3.rowGaps) && G3.colGap == 4 ...
        && isequal(G3.colGaps, [4 16]) && string(FE.spacing.Value) == "custom", ...
        'Apply: the gaps reach the grid (a gap under 0 refused; the second column gap set apart, the row gap the one value); the window stays');
    DS.Spacing.Value = "compact"; DS.Spacing.ValueChangedFcn(DS.Spacing, []);
    DS.Ok.ButtonPushedFcn(DS.Ok, []);
    G4 = app.Config.Figures(2).grid;
    check(~isvalid(dS) && G4.spacing == "compact" && isequal(G4.colGaps, [4 16]), 'OK: a preset, the custom gaps kept unused; the window closes');
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
    check(~any(string(FE.panelType.ItemsData) == "behavior") && ~any(string(FE.addSource.ItemsData) == "trials") ...
        && ~any(string(FE.layerSource.ItemsData) == "trials"), ...
        'no Behavior panel type is offered, and no trials layer source');
    ids0 = [app.Config.Figures.id];
    app.onMoveFigure(-1);
    movedUp = isequal([app.Config.Figures.id], fliplr(ids0)) && app.SelectedFigure == 1 && app.UpFigureButton.Enable == "off";
    app.onMoveFigure(1);
    check(movedUp && isequal([app.Config.Figures.id], ids0) && app.SelectedFigure == 2 && app.DownFigureButton.Enable == "off", ...
        sprintf('figure Up and Down reorder the list (the ids stay: %s); the figure stays selected', strjoin(ids0, " | ")));
    app.onRemoveFigure();
    app.FigureAutoCheckBox.Value = true;
    check(isscalar(app.Config.Figures) && app.SelectedFigure == 1, 'the blank figure removed again');
end

if S.sec("5d.newpanel", "Add: a blank figure, then the New panel window (answered from a timer); every type at every place; the Id row")
    app.FigureAutoCheckBox.Value = false;
    PTn = EphysAnalysisConfig.panelTypes();
    answerDialog('New panel', @(D) press(D, "Cancel"));
    app.onAddFigure();
    f2 = app.Config.Figures(end);
    check(numel(app.Config.Figures) == 2 && app.SelectedFigure == 2 && isempty(f2.panels) && f2.id == "Blank dataset" && f2.autoId ...
        && contains(app.StatusBar.Text, "New panel canceled") && shown(FE.noPanel) && shown(FE.newPanel), ...
        'Add makes a blank figure ("Blank dataset", an automatic id) and opens the New panel window; Cancel leaves it blank');
    answerDialog('New panel', @newPanelAnswer);
    app.onNewPanel();
    seen = getappdata(groot, 'newPanelSeen');
    if isappdata(groot, 'newPanelSeen'); rmappdata(groot, 'newPanelSeen'); end
    f2 = app.Config.Figures(2);
    check(isstruct(seen) && isequal(sort(seen.types), sort(PTn.Type.')) && all(seen.icons) && isempty(seen.failed) && seen.where == "off" ...
        && seen.name0 == "continuous_1" && all(ismember(["Source" "Binding" "Display" "ErrorType"], seen.params)) && seen.binding == "on" ...
        && isscalar(f2.panels) && f2.panels.id == "lfp_a" && f2.panels.title == "Its LFP" && f2.panels.type == "continuous" ...
        && f2.panels.options.display == "stacked" && f2.panels.layers.source == "LFP" && f2.panels.layers.binding == "observation" ...
        && f2.observe.data == "LFP" && f2.id == "Continuous LFP" && app.SelectedPanel == 1, ...
        'New panel...: a tile with its picture per panel type, the name, title, place (the first panel: row 1, column 1) and the type''s key parameters; OK adds it, and the id and Observe follow');
    wh = ["below" "right" "above" "left"];
    bad = strings(1, 0);
    for t = reshape(PTn.Type, 1, [])
        for w = wh
            app.onPanelSelected(1);
            f0 = app.Config.Figures(2);
            a0 = f0.panels(1);
            app.onNewPanel(Type=t, Where=w, Options=struct());
            f = app.Config.Figures(2);
            p = f.panels(end);
            a = f.panels(1);
            placed = (w == "below" && p.row == a.row + a.rowSpan && p.col == a.col) || (w == "right" && p.col == a.col + a.colSpan && p.row == a.row) ...
                || (w == "above" && p.row + 1 == a.row && p.col == a.col) || (w == "left" && p.col + 1 == a.col && p.row == a.row);
            if ~(numel(f.panels) == 2 && p.type == t && ~isempty(p.layers) && placed && app.SelectedPanel == 2 && a.id == a0.id ...
                    && f.grid.rows * f.grid.cols == 2)
                bad(end+1) = t + " " + w; %#ok<AGROW>
            end
            app.onRemovePanel();
        end
    end
    check(isempty(bad) && isscalar(app.Config.Figures(2).panels) && isequal([app.Config.Figures(2).grid.rows app.Config.Figures(2).grid.cols], [1 1]), ...
        sprintf('New panel adds every panel type (%d) at every place (below, right, above, left of the selected panel), each with its default layer%s', ...
        height(PTn), strjoin(", not: " + bad, "")));
    check(all(isfile(fullfile(repo, 'analysis', 'icons', 'panels', PTn.Type + ".png"))), ...
        'every panel type has its picture (analysis/icons/panels, tools/makePanelThumbnails)');
    FE.id.Value = 'lfp_card';
    FE.id.ValueChangedFcn(FE.id, struct('PreviousValue', 'Continuous LFP', 'Value', 'lfp_card'));
    app.onNewPanel(Type="psth", Where="above");
    f2 = app.Config.Figures(2);
    check(f2.id == "lfp_card" && ~f2.autoId && ~FE.idAuto.Value && isequal(FE.id.FontColor, [0 0 0]) && numel(f2.panels) == 2, ...
        'an id typed is the figure''s own (auto unticked): a panel added leaves it');
    app.FigureObservation('lfp_card') = "picked";
    FE.idAuto.Value = true;
    FE.idAuto.ValueChangedFcn(FE.idAuto, []);
    f2 = app.Config.Figures(2);
    statusAuto = string(app.StatusBar.Text);
    look = struct('role', "trace", 'group', "", 'property', "LineWidth", 'value', 2);
    app.rememberFigureAesthetics("lfp_card", look);   % an editor opened before the rename
    check(f2.id == "PSTH+Continuous LFP+units" && f2.autoId && string(FE.id.Value) == f2.id && contains(statusAuto, "follows") ...
        && isKey(app.FigureObservation, char(f2.id)) && ~isKey(app.FigureObservation, 'lfp_card') ...
        && isscalar(app.Config.Figures(2).aesthetics), ...
        'auto ticked again: the automatic id is back; the observation picked and a look remembered under the old id follow the figure');
    app.onRemoveFigure();
    app.FigureAutoCheckBox.Value = true;
    check(isscalar(app.Config.Figures) && app.SelectedFigure == 1, 'that figure removed again');
end

if S.sec("5d.follow", "a panel made from a heat map or a probe map follows the observation: one unit, not all of them")
    app.FigureAutoCheckBox.Value = false;   % no redraw per edit (as 5d.add leaves it)
    for pair = ["heatmap" "psth"; "probemap" "raster"].'
        app.onAddFigure(pair(1));
        FE.panelType.Value = pair(2);
        app.onPanelTypeChanged();
        app.refreshFigurePreview(Force=true);
        Lp = app.Config.Figures(2).panels(1).layers;
        Fp = app.FigurePreviewResult;
        nShown = NaN;
        if isstruct(Fp) && ~isempty(Fp.panels(1).layers(1).meta); nShown = height(Fp.panels(1).layers(1).meta); end
        check(isscalar(Lp) && Lp.source == "units" && Lp.binding == "observation" && contains(app.StatusBar.Text, "now follows the observation") ...
            && app.FigurePreviewState == "drawn" && Fp.observation.kind == "unit" && nShown == 1, ...
            sprintf('a %s made a %s: its units layer follows the observation, and the preview draws %g unit', pair(1), pair(2), nShown));
        app.onRemoveFigure();
    end
end

if S.sec("5d.eventtrace", "an event-trace panel: its template, its Options rows (those its display does not use grayed out), the preview")
    app.FigureAutoCheckBox.Value = false;   % no redraw per edit (as 5d.add leaves it)
    app.onAddFigure("eventTrace");
    app.refreshFigurePreview(Force=true);
    etRows = shown(FE.etDisplay) && shown(FE.etTrials) && shown(FE.etBaseline) && shown(FE.etRowSpacing) && ~shown(FE.binMs) ...
        && ~shown(FE.yLim) && FE.etEdge.Enable == "on" && FE.etLineStyle.Enable == "off" && FE.etGroupBands.Enable == "off" ...
        && shown(FE.evLine) && FE.evDrawAs.Enable == "off" && ~shown(FE.evMarker) && shown(FE.layerColor) ...
        && isequal(string(FE.addSource.ItemsData), "events") && app.FigurePreviewState == "drawn" ...
        && ~isempty(findall(app.FigurePreviewPanel, 'Tag', 'eventBar'));
    FE.etDisplay.Value = "line";
    FE.etTrials.Value = "rows";
    FE.etAlpha.Value = 0.5;
    FE.etBaseline.Value = false;
    app.onConfigChanged("figure");
    app.refreshFigurePreview(Force=true);
    oe = app.Config.Figures(2).panels(1).options;
    check(etRows && oe.display == "line" && oe.trials == "rows" && oe.alpha == 0.5 && ~oe.showBaseline && FE.etLineStyle.Enable == "on" ...
        && FE.etEdge.Enable == "off" && FE.etGroupBands.Enable == "on" && FE.etBaseColor.Enable == "off" && app.FigurePreviewState == "drawn" ...
        && ~isempty(findall(app.FigurePreviewPanel, 'Tag', 'eventLevel')) && isempty(findall(app.FigurePreviewPanel, 'Tag', 'eventBaseline')), ...
        'an event-trace panel: its rows (events layers only, no Draw as), a logic level per epoch''s sub-row reaching the config and the preview');
    app.onRemoveFigure();
end

if S.sec("5d.psth", "a PSTH's Stack box, auROC rows and Display; Firing rate and Tuning curve panels (drawn at once); a type change's display and stackSpacing")
    app.FigureAutoCheckBox.Value = false;   % no redraw per edit (as 5d.add leaves it)
    groupedBy("Depth");
    app.FigureAutoPreviewSeconds = Inf;   % Auto is on for the panels added: a preview slowed by a loaded machine must not leave them out of date
    restoreAutoLimit = onCleanup(@() resetAutoLimit(app));
    app.onFigureSelected(1);
    app.onPanelSelected(2);   % the PSTH
    pS = app.Config.Figures(1).panels(2);
    check(pS.type == "psth" && shown(FE.stack) && ~shown(FE.auMethod) && ~shown(FE.rateDisplay) ...
        && ~shown(FE.param) && ~shown(FE.waveLayout) && FE.psthSpacing.Enable == "off", ...
        'a PSTH shows its Stack row (the spacing off while unticked) and no auROC rows without the auROC baseline');
    FE.stack.Value = true;
    app.onConfigChanged("figure");
    FE.psthSpacing.Value = 1.5;
    app.onConfigChanged("figure");
    app.refreshFigurePreview(Force=true);
    oS = app.Config.Figures(1).panels(2).options;
    nRows = numel(findall(app.FigurePreviewPanel, 'Tag', 'stackBase'));
    check(oS.stack && oS.stackSpacing == 1.5 && FE.psthSpacing.Enable == "on" && app.FigurePreviewState == "drawn" ...
        && nRows == height(app.FigurePreviewResult.groups) * (height(app.FigurePreviewResult.groups) > 1), ...
        sprintf('the Stack box and its spacing reach the PSTH''s options; the preview stacks its groups (%d rows)', nRows));
    FE.baselineMode.Value = "auroc";
    app.onConfigChanged("figure");
    auShown = shown(FE.auMethod) && shown(FE.auCutoff) && shown(FE.auMarks) && FE.auMethod.Enable == "on" ...
        && any(string(FE.baselineMode.Items) == "auroc");
    FE.auWinMs.Value = 20;
    FE.auCutoff.Value = "fixed";
    FE.auModOnly.Value = false;
    app.onConfigChanged("figure");
    app.refreshFigurePreview(Force=true);
    oS = app.Config.Figures(1).panels(2).options;
    check(auShown && oS.baseline.Mode == "auroc" && oS.auroc.windowSec == 0.02 && oS.auroc.cutoff == "fixed" ...
        && app.Config.figureFor(1).panels(2).options.auroc.windowSec == 0.02 && FE.auThreshold.Enable == "on" ...
        && app.FigurePreviewState == "drawn" && isfield(app.FigurePreviewResult.panels(2).layers(1).R, 'auroc'), ...
        'the PSTH''s auROC baseline: its rows show, and their edits reach its options and the preview');
    FE.stack.Value = false;
    FE.baselineMode.Value = "none";
    app.onConfigChanged("figure");
    % a PSTH's Display: a heat map shows its colormap and color limits, hides the trace rows; back to trace
    FE.psthDisplay.Value = "heatmap";
    app.onConfigChanged("figure");
    heatShown = shown(FE.panelColormap) && shown(FE.cLim) && shown(FE.normalize) && ~shown(FE.histStyle) ...
        && ~shown(FE.fill) && ~shown(FE.stack) && ~shown(FE.yLim);
    FE.panelColormap.Value = "hot";
    FE.cLim.Value = '0 30';
    app.onConfigChanged("figure");
    app.refreshFigurePreview(Force=true);
    oH = app.Config.Figures(1).panels(2).options;
    imH = findall(app.FigurePreviewPanel, 'Type', 'image');
    check(heatShown && oH.display == "heatmap" && oH.colormap == "hot" && isequal(oH.cLim, [0 30]) && app.FigurePreviewState == "drawn" ...
        && isscalar(imH) && isequal(clim(ancestor(imH, 'axes')), [0 30]), ...
        'a PSTH''s Display "heat map": Colormap and Color limits shown (PSTH as, Fill, Stack, Y limits hidden), reaching the options and the preview''s image');
    FE.psthDisplay.Value = "trace";
    FE.panelColormap.Value = "auto";
    FE.cLim.Value = '';
    app.onConfigChanged("figure");
    app.refreshFigurePreview(Force=true);
    oT = app.Config.Figures(1).panels(2).options;
    check(oT.display == "trace" && oT.colormap == "" && isempty(oT.cLim) && shown(FE.histStyle) && shown(FE.stack) && shown(FE.yLim) ...
        && ~shown(FE.panelColormap) && ~shown(FE.cLim) && isempty(findall(app.FigurePreviewPanel, 'Type', 'image')) ...
        && app.FigurePreviewState == "drawn", 'back to Display "trace": the trace rows again, the colormap "auto" stored as "", no image');
    nAx = numel(figAxes());
    check(any(string(FE.panelType.ItemsData) == "rate") && any(string(FE.panelType.ItemsData) == "tuning") && app.FigurePreviewState == "drawn", ...
        'the panel type drop-down offers Firing rate and Tuning curve');
    app.FigureAutoCheckBox.Value = true;   % the automatic preview itself: the panels added are drawn at once
    app.onNewPanel(Type="rate", Where="below");
    pr = app.Config.Figures(1).panels(end);
    check(pr.type == "rate" && isscalar(pr.layers) && pr.layers.source == "units" && pr.layers.binding == "observation" ...
        && app.FigurePreviewState == "drawn" && numel(figAxes()) == nAx + 1 && ~isempty(findall(app.FigurePreviewPanel, 'Tag', 'bar')) ...
        && shown(FE.rateDisplay) && shown(FE.measure) && shown(FE.baselineMode) && ~shown(FE.binMs) && ~shown(FE.stack) ...
        && isequal(string(FE.baselineMode.Items), ["none" "subtract" "ratio" "zscore"]) ...
        && app.FigureSections([app.FigureSections.Name] == "options").Title == "Firing rate options", ...
        'Firing rate, Below: its units layer follows the unit and a bar per trial group is drawn at once; its own rows shown');
    FE.rateDisplay.Value = "points";
    app.onConfigChanged("figure");
    check(app.Config.Figures(1).panels(end).options.display == "points" && ~isempty(findall(app.FigurePreviewPanel, 'Tag', 'points')) ...
        && app.FigurePreviewState == "drawn", 'its Display reaches the options and the drawing (points)');
    app.onNewPanel(Type="tuning", Where="below");
    pt = app.Config.Figures(1).panels(end);
    Lt = app.FigurePreviewResult.panels(end).layers(1);
    check(pt.type == "tuning" && pt.layers.binding == "observation" && app.FigurePreviewState == "drawn" && numel(figAxes()) == nAx + 2 ...
        && Lt.skip == "" && Lt.R.param == "Depth" && ~isempty(findall(app.FigurePreviewPanel, 'Tag', 'curve')) ...
        && shown(FE.param) && shown(FE.waveMode) && ~shown(FE.rateDisplay) ...
        && app.FigureSections([app.FigureSections.Name] == "options").Title == "Tuning curve options", ...
        'Tuning curve, Below: drawn at once over the figure''s group-by parameter (Depth), its Parameter rows shown');
    app.FigureAutoCheckBox.Value = false;   % Auto off again: no redraw per edit
    FE.param.Value = 'Depth';
    FE.seriesParam.Value = 'TrialType';
    app.onConfigChanged("figure");
    app.refreshFigurePreview(Force=true);
    ot = app.Config.Figures(1).panels(end).options;
    check(ot.param == "Depth" && ot.seriesParam == "TrialType" && app.FigurePreviewState == "drawn" ...
        && app.FigurePreviewResult.panels(end).layers(1).R.seriesParam == "TrialType", ...
        sprintf('its Parameter and series reach the options and the drawing (%s / %s; preview %s: %s)', ot.param, ot.seriesParam, ...
        app.FigurePreviewState, string(app.FigurePreviewLabel.Text)));
    % a type change takes the new type's display and stackSpacing: the names mean other things on continuous, rate and PSTH panels
    kr = numel(app.Config.Figures(1).panels) - 1;   % the rate panel (its display "points")
    app.onPanelSelected(kr);
    FE.panelType.Value = "continuous";
    app.onPanelTypeChanged();
    o1 = app.Config.Figures(1).panels(kr).options;
    FE.panelType.Value = "rate";
    app.onPanelTypeChanged();
    o2 = app.Config.Figures(1).panels(kr).options;
    FE.panelType.Value = "psth";
    app.onPanelTypeChanged();
    FE.psthSpacing.Value = 1.5;
    app.onConfigChanged("figure");
    o3 = app.Config.Figures(1).panels(kr).options;
    FE.panelType.Value = "continuous";
    app.onPanelTypeChanged();
    o4 = app.Config.Figures(1).panels(kr).options;
    FE.panelType.Value = "psth";
    app.onPanelTypeChanged();
    o5 = app.Config.Figures(1).panels(kr).options;
    I5 = app.Config.validate(CheckPaths=false);
    check(o1.display == "lines" && isnan(o1.stackSpacing) && o2.display == "bar" && o3.stackSpacing == 1.5 ...
        && isnan(o4.stackSpacing) && o4.display == "lines" && o5.stackSpacing == 1.1 ...
        && ~any(startsWith(I5.Field, app.Config.Figures(1).id + "." + app.Config.Figures(1).panels(kr).id + ".options") & I5.Severity == "error"), ...
        sprintf(['rate -> continuous -> rate -> PSTH -> continuous -> PSTH: each takes its own display and stackSpacing ' ...
        'defaults, none the other''s (%s %g, %s, %g, %s %g, %g; preview %s)'], o1.display, o1.stackSpacing, o2.display, ...
        o3.stackSpacing, o4.display, o4.stackSpacing, o5.stackSpacing, app.FigurePreviewState));
    FE.panelType.Value = "rate";
    app.onPanelTypeChanged();
    app.onPanelSelected(numel(app.Config.Figures(1).panels));
    app.onRemovePanel();
    app.onPanelSelected(numel(app.Config.Figures(1).panels));
    app.onRemovePanel();
    app.refreshFigurePreview(Force=true);
    check(numel(app.Config.Figures(1).panels) == 2 && app.Config.Figures(1).grid.rows == 2 && app.FigurePreviewState == "drawn", ...
        'the tuning and rate panels removed again');
    clear restoreAutoLimit
end

if S.sec("5d.scan", "a scan makes the observation list again (the same dataset active)")
    app.selectDataset(find(app.Ticked, 1));
    oldT = app.FigureObservations;
    stale = oldT;
    stale.label(:) = "stale";
    app.FigureObservations = stale;
    app.onScan();
    T1 = figureObservations(app.Runner.source(app.ActiveIdx), app.Config.figureFor(1));
    check(app.ActiveIdx == find(app.Ticked, 1) && istable(app.FigureObservations) && isequal(app.FigureObservations.label, T1.label) ...
        && ~any(app.FigureObservations.label == "stale"), 'Scan lists the observations again on the new runner, even with the same dataset active');
    app.refreshFigurePreview(Force=true);
end

if S.sec("5d.saveprefs", "save, reopen; the preferences restored by a new app; Remove")
    savedConfig();
    app.onFigureSectionToggled("options");
    app.onFigureSuperToggled("look");
    app.FigureAutoCheckBox.Value = false;
    app.onFigureAutoPreviewToggled();
    app.onSaveConfig();
    app2 = EphysAnalysisApp(Splash=true);
    H2 = app2.Splash.History;
    check(app2.Splash.Window ~= "" && ~app2.Splash.isOpen() && isempty(findall(groot, 'Tag', 'AppSplash')) ...
        && app2.Fig.Visible == "on" && all(ismember(["window" "config" "scan" "dataset" "show"], H2.Step)), ...
        'Splash=true: the splash window shows the steps (the last config opened, its scan, the first dataset) and closes when the window shows');
    kept = isscalar(app2.Config.Figures) && isequaln(app2.Config.Figures, app.Config.Figures) && app2.SelectedFigure == 1 ...
        && string(figureNode(app2.FiguresTree, 1).Text) == app.Config.Figures(1).id + "  (2 panels)";
    restored = ~app2.FigureAutoCheckBox.Value && ~app2.FigureSections([app2.FigureSections.Name] == "options").Expanded ...
        && app2.FigureSections([app2.FigureSections.Name] == "layers").Expanded ...
        && isequal([app2.FigureSupers.Expanded], [true true false]) && ~shown(app2.FigureEditor.fontSize);
    closeApp(app2);
    check(~startsWith(app.Fig.Name, "*") && kept, 'saved and opened again, the config keeps the figure');
    check(restored, 'a new app restores the Figures tab''s Auto, collapsed section and collapsed supersection (Look)');
    app.FigureAutoCheckBox.Value = true;
    app.onFigureAutoPreviewToggled();
    app.onFigureSectionToggled("options");
    app.onFigureSuperToggled("look");
    app.onRemoveFigure();
    check(isempty(app.Config.Figures) && isempty(findall(app.FiguresTree, 'Type', 'uitreenode')) && app.FigurePreviewState == "idle" && ~shown(FE.id) ...
        && app.RemoveFigureButton.Enable == "off" && nPatches() == 0 && ~any(arrayfun(@(u) shown(u.Header), app.FigureSupers)) ...
        && isempty(findall(app.FigurePreviewPanel, 'Tag', 'previewPanelMark')), ...
        'Remove takes the figure away; the editor (its supersection headers too) and preview (its outline too) are empty');
end

if S.sec("5d.spectrum", "a spectrum panel and a spectrogram panel (Chronux: the bundled copy, on the path for these checks only)")
    savedConfig();
    noFigures();
    app.FigureAutoCheckBox.Value = false;   % no redraw per edit (as 5d.add leaves it)
    spPath = "";
    if ~ChronuxDataset.hasChronux() && isfolder(fullfile(repo, 'toolboxes', 'chronux'))
        spPath = string(genpath(fullfile(repo, 'toolboxes', 'chronux')));
        addpath(spPath);
    end
    if ~ChronuxDataset.hasChronux()
        fprintf('  SKIP: Chronux is not on the path: the spectrum panel is not tested\n');
    else
        app.onAddFigure("blank");
        app.refreshFigurePreview(Force=true);
        check(app.FigurePreviewState ~= "failed", 'a blank figure previews without failing (no axes for the aesthetics editor to read)');
        app.onNewPanel(Type="spectrum", Where="below");
        app.refreshFigurePreview(Force=true);
        fs1 = app.Config.Figures(1);
        spAx = findall(app.FigurePreviewPanel, 'Type', 'axes', 'Tag', 'axes');
        spTr = findall(app.FigurePreviewPanel, 'Tag', 'trace');
        spKind = "";
        if isstruct(app.FigurePreviewResult) && isstruct(app.FigurePreviewResult.panels(1).layers(1).R)
            spKind = string(app.FigurePreviewResult.panels(1).layers(1).R.kind);
        end
        spX = "";
        if ~isempty(spAx); spX = strjoin(string(spAx(1).XLabel.String), " "); end
        if app.FigurePreviewState ~= "drawn"   % say why in the check's message
            spX = strjoin(string(get(findall(app.FigurePreviewPanel, 'Type', 'uilabel'), 'Text')), " | ");
        end
        check(isscalar(fs1.panels) && fs1.panels.type == "spectrum" && fs1.panels.layers.source == "units" ...
            && fs1.panels.layers.binding == "observation" && app.FigurePreviewState == "drawn" && ~isempty(spAx) && ~isempty(spTr) ...
            && spX == "Frequency (Hz)" && spKind == "chronuxSpikeSpectrum", ...
            sprintf('a Power spectrum panel added from the drop-down: the observed unit''s spike spectrum, previewed (%s, %d axes, %d traces, x "%s", %s)', ...
            app.FigurePreviewState, numel(spAx), numel(spTr), spX, spKind));
        check(shown(FE.spTaperMode) && shown(FE.spTW) && shown(FE.spErr) && shown(FE.spScale) && shown(FE.spTimeBase) && shown(FE.spSpikeFs) ...
            && ~shown(FE.spRangeFrom) && ~shown(FE.spWin) && ~shown(FE.spShowPhase) && ~shown(FE.binMs) && ~shown(FE.baselineMode) ...
            && shown(FE.yLim) && FE.spTW.Enable == "on" && FE.spW.Enable == "off" ...
            && app.FigureSections([app.FigureSections.Name] == "options").Title == "Power spectrum options", ...
            'its options show the Chronux rows: tapers, error, scale, time base, spike rate (no range on epochs, no moving window)');
        FE.spTW.Value = 2;
        FE.spK.Value = 3;
        FE.spFmax.Value = 80;
        FE.spScale.Value = "linear";
        FE.spTimeBase.Value = "range";
        FE.spSegment.Value = 1;
        app.onConfigChanged("figure");
        app.refreshFigurePreview(Force=true);
        o1 = app.Config.Figures(1).panels.options;
        R1 = app.FigurePreviewResult.panels.layers.R;
        check(o1.TW == 2 && o1.K == 3 && isequal(o1.fpass, [0 80]) && o1.scale == "linear" && o1.timeBase == "range" && o1.segmentSec == 1 ...
            && shown(FE.spRangeFrom) && shown(FE.spSegment) && app.FigurePreviewState == "drawn" && R1.tapers.TW == 2 && R1.tapers.K == 3 ...
            && max(R1.f) <= 80 && R1.timeBase.mode == "range", ...
            'its rows reach the config (tapers, frequency range, scale, the range time base) and the preview is computed with them');
        FE.addSource.Value = "AUX";
        FE.addSource.ValueChangedFcn(FE.addSource, []);
        app.onAddLayer();
        FE.layerBinding.Value = "fixed";
        app.onConfigChanged("figure");
        aggOffered = string(FE.layerAggregate.ItemsData);
        FE.layerAggregate.Value = "magnitude";
        app.onConfigChanged("figure");
        app.refreshFigurePreview(Force=true);
        La = app.Config.Figures(1).panels.layers(end);
        Ra = app.FigurePreviewResult.panels.layers(end).R;
        listed = string(FE.layerList.Items);
        check(isequal(aggOffered, ["each" "magnitude"]) && shown(FE.layerAggregate) && La.source == "AUX" && La.aggregate == "magnitude" ...
            && app.FigurePreviewState == "drawn" && isstruct(Ra) && isequal(Ra.names, "magnitude of 3 AUX channels") ...
            && endsWith(listed(end), "(magnitude)"), ...
            'a fixed AUX layer on a spectrum panel: Aggregate offers each channel or their vector magnitude, which reaches the config, the Layers list and the preview');
        FE.layerSource.Value = "units";
        app.onConfigChanged("figure");
        check(app.Config.Figures(1).panels.layers(end).aggregate == "each" && ~shown(FE.layerAggregate), ...
            'the layer switched to units there: no Aggregate row, and the magnitude goes back to each');
        app.onRemoveLayer();   % the spectrum panel's one layer again
        app.onNewPanel(Type="spectrogram", Where="below");
        sgSrc = string(FE.layerSource.ItemsData);
        FE.layerSource.Value = "units";
        app.onConfigChanged("figure");
        app.refreshFigurePreview(Force=true);
        ps = app.Config.Figures(1).panels;
        k2 = find([ps.type] == "spectrogram", 1);
        sgKind = "";
        if isstruct(app.FigurePreviewResult) && isstruct(app.FigurePreviewResult.panels(k2).layers(1).R)
            sgKind = string(app.FigurePreviewResult.panels(k2).layers(1).R.kind);
        end
        check(isscalar(k2) && isequal(sgSrc, ["LFP" "MUA" "SPIKE" "AUX" "units" "detected" "events"]) && ps(k2).layers(1).source == "units" ...
            && ps(k2).layers(1).binding == "observation" && app.FigurePreviewState == "drawn" && sgKind == "chronuxSpikeSpecgram" ...
            && shown(FE.spSpikeFs) && shown(FE.spWin), ...
            sprintf(['a Spectrogram panel offers sorted units and detected spikes after the signals; switched to units, it previews ' ...
            'the observed unit''s spike spectrogram, with the spike rate row (%s, %s)'], app.FigurePreviewState, sgKind));
        app.onRemoveFigure();
        app.onSaveConfig();
    end
    if spPath ~= ""; rmpath(spPath); end
    app.FigureAutoCheckBox.Value = true;   % the automatic preview on again at the end of 5d, as the tab starts
    app.onSaveConfig();
    app.Tabs.SelectedTab = app.TabData;
end

if S.sec("5e", "Copy from... for figures")
    savedConfig();
    noFigures();
    app.FigureAutoPreviewSeconds = Inf;   % a preview slowed by a loaded machine must not leave the next one out of date
    restoreAutoLimit = onCleanup(@() resetAutoLimit(app));
    app.FigureAutoCheckBox.Value = true;   % the automatic preview, as 5d leaves it
    app.selectTab(app.TabFigures);
    app.onAddFigure("rasterPsth");
    want = app.Config.Figures(1);
    check(app.CopyFigureButton.Enable == "off" && want.id == "Raster+PSTH units", 'Copy from... is off with one figure: there is no other to copy from');
    app.onAddFigure("heatmap");
    cx = app.gatherConfig();
    cx.Figures(2).style.FontSize = 15;
    cx.Figures(2).panels(1).options.bins.BinSec = 0.05;
    app.applyConfig(cx);
    app.onFigureSelected(1);
    check(app.CopyFigureButton.Enable == "on", 'Copy from... is on with a figure selected and another to copy from');
    hid = app.Config.Figures(2).id;   % "Heatmap units": a fixed units layer, the dataset observed
    app.onCopyFigureSettings(From=hid, Parts="style");
    f1 = app.Config.Figures(1);
    check(hid == "Heatmap units" && f1.id == "Raster+PSTH units" && f1.style.FontSize == 15 && isequal([f1.panels.type], [want.panels.type]) ...
        && contains(string(app.StatusBar.Text), "Copied from Heatmap units onto Raster+PSTH units: Appearance") && app.FigurePreviewState == "drawn", ...
        'From= and Parts= copy the appearance alone; the panels stay, the preview follows');
    answerDialog('Copy figure settings', @copyFigureDialog);
    app.onCopyFigureSettings();
    seen = getappdata(groot, 'copyFigureSeen');
    if isappdata(groot, 'copyFigureSeen'); rmappdata(groot, 'copyFigureSeen'); end
    f1 = app.Config.Figures(1);
    check(isstruct(seen) && seen.count == "2 part(s) to copy" && seen.from == "Heatmap units  (1 panels)" ...
        && f1.id == "Heatmap units (2)" && isequal([f1.panels.type], "heatmap") && f1.panels.options.bins.BinSec == 0.05 && app.SelectedPanel == 1 ...
        && nPatches() == 1, 'the window copies the parts ticked (alignment, arrangement): the figure is now the heat map''s panels, their options too, and its automatic id follows ("Heatmap units (2)")');
    app.onRemoveFigure();
    app.onFigureSelected(1);
    app.onRemoveFigure();
    check(isempty(app.Config.Figures), 'both figures removed');
    app.onSaveConfig();
    app.Tabs.SelectedTab = app.TabData;
    clear restoreAutoLimit
end

if S.sec("5f", "Generate a figure; figures on the Export tab")
    savedConfig();
    noFigures();
    exported();
    app.FigureAutoPreviewSeconds = Inf;   % a preview slowed by a loaded machine must not leave the next one out of date
    restoreAutoLimit = onCleanup(@() resetAutoLimit(app));
    app.FigureAutoCheckBox.Value = true;   % the automatic preview, as 5d leaves it
    app.selectTab(app.TabFigures);
    bcol = app.FigurePreviewButton.Parent;   % the column of buttons, left of the Dataset, Observation and Favorites rows
    check(app.FigureGenerateButton.Enable == "off" && app.FigureUnitReportButton.Enable == "off" ...
        && app.FigureGenerateButton.Parent == bcol && app.FigureUnitReportButton.Parent == bcol && app.FigureAutoCheckBox.Parent == bcol ...
        && isequal(app.FigurePreviewButton.Layout.Row, 1) && isequal(app.FigureGenerateButton.Layout.Row, 2) && isequal(app.FigureUnitReportButton.Layout.Row, 3) ...
        && isequal(app.FigureGenerateButton.BackgroundColor, app.FigurePreviewButton.BackgroundColor) ...
        && app.FigureObsPrevButton.Parent == app.FigureObsNextButton.Parent && app.FigureObsPrevButton.Parent.Parent == bcol ...
        && app.FigureObsPrevButton.Layout.Row == 1 && app.FigureObsNextButton.Layout.Row == 1 ...
        && bcol.Parent == app.FiguresDatasetDropDown.Parent.Parent && max(bcol.Layout.Column) < min(app.FiguresDatasetDropDown.Parent.Layout.Column) ...
        && isequal(bcol.Layout.Row, [1 3]), ...
        ['Preview, Generate (colored as it is, under Preview), Unit report (under Generate; both off with no figure), Auto and < > ' ...
        '(on one row) form a column left of Dataset, Observation and Favorites']);
    mods = {'control'};
    if ismac; mods = {'command'}; end
    report0 = app.LastReportFiles;
    app.onKeyPress(pressed('u', mods));
    check(isequal(app.LastReportFiles, report0) && ~app.Running, 'Ctrl+U does nothing while Unit report is off');
    app.onAddFigure("rasterPsth");
    kG = app.SelectedFigure;
    fid = app.Config.Figures(kG).id;
    gIdx = app.tickedDatasetIndices();
    gSpec = app.Config.figureFor(fid);
    gX = app.gatherConfig().Export;
    want = strings(0, 1);
    nObsWant = 0;
    for kk = gIdx
        name = app.Runner.Names(kk);
        Tk = figureObservations(app.Runner.source(kk), gSpec);
        nObsWant = nObsWant + height(Tk);
        for i = 1:height(Tk)
            base = fullfile(outRoot, name, figureOutputName(gX.FilenamePattern, name, gSpec, Tk(i, :), i, height(Tk)));
            want = [want; reshape(base + "." + gX.Formats, [], 1)]; %#ok<AGROW>
        end
    end
    check(app.FigureGenerateButton.Enable == "on" && numel(gIdx) == 2 && nObsWant >= 2, ...
        sprintf('Generate is on with %s selected (%d observation(s) on the %d ticked datasets)', fid, nObsWant, numel(gIdx)));
    R = app.onGenerateFigure();
    T = app.ResultsTable.Data;
    check(istable(R) && height(R) == numel(gIdx) && all(R.Kind == "figure") && all(R.Plot == fid) && all(R.Status == "done") ...
        && sum(arrayfun(@(s) sscanf(char(s), '%d', 1), R.Message)) == nObsWant && all(isfile(want)) ...
        && height(T) == height(R) && all(string(T.Kind) == "figure") && all(ismember(["Subject" "Date"], string(T.Properties.VariableNames))), ...
        sprintf('Generate draws %s for every observation on both datasets: %d file(s) in the Export folder, the results table shows its figure rows', fid, numel(want)));
    check(startsWith(string(app.StatusBar.Text), sprintf("Generated %s: %d observation(s) on %d dataset(s), %d file(s) in ", fid, nObsWant, numel(gIdx), numel(want))) ...
        && app.OpenFolderButton.Enable == "on" && app.ToolbarFolderTool.Enable == "on" && app.OpenReportButton.Enable == "off" ...
        && ~app.Running && app.FigureGenerateButton.Enable == "on" && app.RunButton.Enable == "on" && app.CancelButton.Enable == "off" ...
        && app.Tabs.SelectedTab == app.TabFigures && app.Config.Figures(kG).enabled, ...
        'the status bar counts observations, datasets and files; Open figure folder is on, no report; the buttons are back');
    % Cancel during a generate
    delete(want{:});
    setappdata(groot, 'genProbe', []);
    tm = timer('ExecutionMode', 'fixedRate', 'Period', 0.005, 'TimerFcn', @(t, ~) cancelGenerate(t, app));
    start(tm);
    Rc = app.onGenerateFigure();
    stop(tm); delete(tm);
    pr = getappdata(groot, 'genProbe');
    rmappdata(groot, 'genProbe');
    check(isstruct(pr) && pr.generate == "off" && pr.run == "off" && pr.cancel == "on" && contains(pr.preview, "A run is going") ...
        && pr.state ~= "computing", 'while it runs, Generate and Run are off, Cancel is on, and the preview computes nothing');
    check(istable(Rc) && height(Rc) == numel(gIdx) && all(Rc.Status == "canceled") && height(app.ResultsTable.Data) == height(Rc) ...
        && startsWith(string(app.StatusBar.Text), "Generating " + fid + " was canceled") && ~app.Running && app.FigureGenerateButton.Enable == "on", ...
        'Cancel during a generate: its rows are canceled, the status bar says so, Generate is on again');
    % the plan and a run from the Export tab
    P = app.onPlan();
    pf = P(P.Kind == "figure", :);
    check(height(pf) == numel(gIdx) && all(pf.Plot == fid) && all(pf.Source == "unit") && all(pf.Enabled) ...
        && height(app.IssuesTable.Data) == height(P) && contains(string(app.StatusBar.Text), sprintf("Plan: %d of %d figure run(s) will draw", numel(gIdx), numel(gIdx))), ...
        'Plan lists the figure on each ticked dataset (Kind "figure", Source "unit") and the status bar counts its runs');
    R = app.onRunExport();
    rf = R(R.Kind == "figure", :);
    check(height(R) == numel(gIdx) && height(rf) == numel(gIdx) && all(rf.Plot == fid) && all(rf.Status == "done") ...
        && all(isfile(want)) && contains(app.RunLabel.Text, sprintf("%d done", height(R))), ...
        'Run from the Export tab draws the enabled figure: one figure row per dataset');
    % a figure that is off is generated all the same, for that run only
    app.selectTab(app.TabFigures);
    FE.enabled.Value = false;
    app.onConfigChanged("figure");
    R = app.onGenerateFigure();
    check(~app.Config.Figures(kG).enabled && istable(R) && height(R) == numel(gIdx) && all(R.Status == "done") ...
        && contains(string(app.StatusBar.Text), fid + " is off, so it was switched on for this run only") ...
        && endsWith(string(figureNode(app.FiguresTree, kG).Text), "(off)") && ~app.Runner.Config.Figures(kG).enabled, ...
        'Generate on a figure that is off draws it (not skipped), says so, and the config keeps it off');
    % Unit report: every enabled figure (and the selected one, though off) for the unit picked, an HTML report in a
    % temporary folder; a channel figure draws the unit's channel, a figure of the dataset is left out
    app.onAddFigure("continuous");
    app.onAddFigure("heatmap");
    app.onFigureSelected(kG);
    app.FigureObservationDropDown.Value = 2;
    app.onFigureObservationChanged();
    uT = app.FigureObservations;
    uLabel = uT.label(2);
    check(app.FigureUnitReportButton.Enable == "on" && uT.kind(2) == "unit", 'Unit report is on with a unit picked');
    nTicked = numel(app.tickedDatasetIndices());
    [Ru, fu] = app.onUnitReport(Open=false);
    uKinds = arrayfun(@(f) EphysAnalysisConfig.observeKind(f), app.Config.Figures);
    okRows = true;
    for q = 1:numel(app.Config.Figures)
        rq = Ru(Ru.Plot == app.Config.Figures(q).id, :);
        if uKinds(q) == "dataset"
            okRows = okRows && isscalar(rq.Status) && rq.Status == "skipped" && rq.Message == "it observes the dataset, not one unit";
        elseif q == kG
            okRows = okRows && isscalar(rq.Status) && rq.Status == "done" && rq.Message == "1 observation(s)";
        else   % what is on the unit's channel, or why nothing is
            okRows = okRows && isscalar(rq.Status) && (rq.Status == "done" || rq.Status == "skipped" && startsWith(rq.Message, "no "));
        end
    end
    check(istable(Ru) && height(Ru) == 3 && all(Ru.Dataset == app.Runner.Names(app.ActiveIdx)) && okRows ...
        && isfile(fu) && endsWith(fu, "unit_report.html") && startsWith(fu, string(tempdir)) && ~startsWith(fu, string(outRoot)) ...
        && contains(fileread(fu), fid) && isempty(dir(fullfile(outRoot, '**', 'unit_report*'))) ...
        && isequal(app.LastReportFiles, fu) && ~app.Config.Figures(kG).enabled && nTicked == numel(app.tickedDatasetIndices()), ...
        sprintf('Unit report draws the three figures for %s on the active dataset only (the dataset''s figure left out), into a temporary HTML report; the output folder untouched, the figure kept off', uLabel));
    check(startsWith(string(app.StatusBar.Text), "Unit report for " + uLabel + ": ") && contains(string(app.StatusBar.Text), "left out") == any(Ru.Status ~= "done") ...
        && contains(string(app.StatusBar.Text), fid + " is off, so it was drawn for this report only") ...
        && ~app.Running && app.FigureUnitReportButton.Enable == "on" && app.FigureGenerateButton.Enable == "on", ...
        'the status bar names the unit, what was left out, the figure that is off; the buttons are back');
    app.onFigureSelected(3); app.onRemoveFigure();
    app.onFigureSelected(2); app.onRemoveFigure();
    app.onFigureSelected(kG);
    app.onRemoveFigure();
    clear restoreAutoLimit
end

if S.sec("5g", "a figure across sessions: the Sessions section, the picker, the preview, Generate")
    savedConfig();
    noFigures();
    groupedBy("Depth");
    app.FigureAutoPreviewSeconds = Inf;   % a preview slowed by a loaded machine must not leave the next one out of date
    restoreAutoLimit = onCleanup(@() resetAutoLimit(app));
    app.FigureAutoCheckBox.Value = true;   % the automatic preview, as 5d leaves it
    app.selectTab(app.TabFigures);
    app.onAddFigure("rasterPsth");
    kS = app.SelectedFigure;
    sid = app.Config.Figures(kS).id;
    if ~app.FigureSections([app.FigureSections.Name] == "sessions").Expanded; app.onFigureSectionToggled("sessions"); end
    check(~shown(FE.sesDatasets) && shown(FE.sesEnabled) && ~FE.sesEnabled.Value && shown(FE.obsPerGroup) && app.FiguresDatasetDropDown.Enable == "on", ...
        'the Sessions section: only "Across sessions" until it is ticked; Per trial group and the Dataset drop-down as usual');
    FE.sesEnabled.Value = true;
    app.onConfigChanged("figure");
    ssA = app.Config.Figures(kS).sessions;
    check(ssA.enabled && shown(FE.sesDatasets) && shown(FE.sesSeries) && shown(FE.sesMatch) && shown(FE.sesTrialGroups) && ~shown(FE.sesKeys) ...
        && ~shown(FE.sesMappingFile) && ~shown(FE.obsPerGroup) && app.FiguresDatasetDropDown.Enable == "off" && FE.sesError.Enable == "off" ...
        && contains(string(FE.sesNote.Text), "once across the datasets") && isempty(app.Config.enabledFigures()) ...
        && isequal(app.Config.enabledSessionFigures(), sid), ...
        'Across sessions ticked: the config''s sessions.enabled, its rows shown (the error band off for a color per session), the Dataset drop-down off');
    FE.sesSeries.Value = "all";
    FE.sesShowMembers.Value = true;
    FE.sesMatch.Value = "mapping";
    app.onConfigChanged("figure");
    ssB = app.Config.Figures(kS).sessions;
    check(ssB.series == "all" && ssB.showMembers && ssB.match == "mapping" && shown(FE.sesMappingFile) && FE.sesError.Enable == "on", ...
        'the rows write series, showMembers and match into the config; the mapping file row shows with match "mapping"');
    keysS = reshape(app.Runner.sessionTable(app.tickedDatasetIndices()).key, 1, []);
    mapS = fullfile(tempdir, "app_session_figure_map.csv");
    cleanMap = onCleanup(@() delete(mapS));
    app.onBrowseFigureMapping(mapS);
    TmS = app.onEditUnitMapping(Table=table("cellX", "1", "2", 'VariableNames', ["cell" keysS]));
    check(app.Config.Figures(kS).sessions.mappingFile == mapS && isfile(mapS) && height(TmS) == 1 && string(FE.sesMappingFile.Value) == mapS, ...
        'Browse... and Edit... set and write the session figure''s mapping file');
    FE.sesMatch.Value = "site";
    FE.sesSeries.Value = "session";
    FE.sesShowMembers.Value = false;
    app.onConfigChanged("figure");
    app.onPickFigureDatasets(Keys=keysS(2));
    check(isequal(app.Config.Figures(kS).sessions.datasetKeys, keysS(2)) && string(FE.sesKeys.Value) == keysS(2), ...
        'Pick... (keys given) writes the figure''s sessions.datasetKeys');
    app.onPickFigureDatasets(Keys=string.empty(1, 0));
    % the picker lists the observations matched across the sessions; the preview draws them across both datasets
    app.refreshFigureObservations(Force=true);
    TS = app.FigureObservations;
    check(istable(TS) && height(TS) >= 1 && ismember("perSession", string(TS.Properties.VariableNames)) && all(startsWith(TS.label, "site ch ")) ...
        && all(contains(string(app.FigureObservationDropDown.Items), "(across ")) && contains(string(FE.obsCount.Text), "matched across 2 sessions"), ...
        sprintf('the picker lists the sites matched across the ticked datasets ("%s")', string(app.FigureObservationDropDown.Items{1})));
    app.refreshFigurePreview(Force=true);
    FpS = app.FigurePreviewResult;
    check(app.FigurePreviewState == "drawn" && isstruct(FpS) && isfield(FpS, 'nSessions') && height(FpS.sessions) == 2 ...
        && contains(string(app.FigurePreviewLabel.Text), "across sessions: " + FpS.nSessions + " merged") ...
        && ~isempty([findall(app.FigurePreviewPanel, 'Tag', 'rate'); findall(app.FigurePreviewPanel, 'Tag', 'rateFill')]) ...
        && app.FigureSessionDropDown.Visible == "off", ...
        sprintf('Preview draws the figure across both datasets: "%s"', string(app.FigurePreviewLabel.Text)));
    FE.sesFacet.Value = "subject";
    FE.sesTrialGroups.Value = "each";
    app.onConfigChanged("figure");
    check(app.FigurePreviewState == "stale" && contains(string(app.FigurePreviewLabel.Text), "press Preview"), ...
        'an edit does not recompute a figure across sessions: the preview is out of date until Preview');
    app.refreshFigurePreview(Force=true);
    nRes = numel(app.FigureSessionResults.res);
    if nRes > 1
        app.FigureSessionDropDown.Value = 2;
        app.onFigureSessionPicked();
    end
    check(app.FigurePreviewState == "drawn" && nRes > 1 && app.FigureSessionDropDown.Visible == "on" ...
        && app.FigureSessionResults.label == app.FigureSessionResults.res(2).label && contains(string(app.FigurePreviewLabel.Text), app.FigureSessionResults.res(2).label), ...
        sprintf('a figure per trial group: the "Figure:" drop-down picks which of the %d is drawn, computing nothing', nRes));
    codeFileS = fullfile(root, 'preview_sessions.m');
    codeS = app.onFigureCode(string(codeFileS));
    [FcS, hcS] = runPreviewCode(codeFileS);
    closeCodeS = onCleanup(@() delete(hcS(isgraphics(hcS))));
    check(contains(codeS, "res = figureSessionCompute(sources, sessions, spec, Observation=obs);") && all(contains(codeS, app.Runner.Keys)) ...
        && contains(codeS, """" + app.FigureSessionResults.label + """") && sameResult(FcS, app.FigurePreviewResult) && height(FcS.sessions) == 2, ...
        'Export code of a figure across sessions: run, the script merges the observation over both datasets and draws the figure picked under the preview');
    delete(hcS);
    Tt = app.DatasetsTable.Data;
    Tt.Run(2) = false;
    app.DatasetsTable.Data = Tt;
    app.onDatasetsTableEdited([]);   % a Run tick: the session figure is drawn across the ticked datasets
    check(app.FigurePreviewState == "stale" && isempty(app.FigureSessionResults) && app.FigureSessionDropDown.Visible == "off" ...
        && nnz(app.Ticked) == 1, 'unticking a dataset forgets the session figure''s drawing (over the old datasets): Out of date, the "Figure:" drop-down cleared');
    Tt.Run(2) = true;
    app.DatasetsTable.Data = Tt;
    app.onDatasetsTableEdited([]);
    FE.sesFacet.Value = "none";
    FE.sesTrialGroups.Value = "pool";
    app.onConfigChanged("figure");
    app.onFigureSessionPicked();   % the drop-down after an edit: the kept figures are gone, nothing old is drawn as current
    check(isempty(app.FigureSessionResults) && app.FigureSessionDropDown.Visible == "off" && app.FigurePreviewState ~= "drawn", ...
        'an edit forgets the kept figures and hides the "Figure:" drop-down; picking then draws nothing old');
    % Generate draws it across the datasets into the sessions folder
    gXS = app.gatherConfig().Export;
    RS = app.onGenerateFigure();
    k1S = app.Runner.sessionTable(app.tickedDatasetIndices()).index(1);
    folderS = figureFileName(gXS.SessionsFolder, struct('OutputFolder', app.Runner.datasetFolder(k1S), 'OutputRoot', app.Runner.outputRoot(), ...
        'Root', app.Config.Source.Root, 'Name', app.Runner.Names(k1S)), Kind="folder");
    wantS = split(RS.Files(1), "; ");
    check(istable(RS) && height(RS) == 1 && RS.Kind == "figure" && RS.Dataset == "sessions: all" && RS.Status == "done" && all(isfile(wantS)) ...
        && numel(wantS) == height(TS) * numel(gXS.Formats) && all(startsWith(wantS, folderS)) && all(contains(wantS, regexprep(sid, '[^\w\-\.]', '_') + "_site_ch")) ...
        && startsWith(string(app.StatusBar.Text), "Generated " + sid + " across the sessions: all: " + height(TS) + " observation(s); "), ...
        sprintf('Generate on a session figure writes a page per site into the sessions folder (%d), one results row', height(TS)));
    app.onRemoveFigure();
    clear cleanMap
    app.onSaveConfig();
    app.Tabs.SelectedTab = app.TabData;
    clear restoreAutoLimit
end

if S.sec("5h", "the figure tree, a panel's note and overlays, dragging a panel in the schematic")
    savedConfig();
    app.FigureAutoPreviewSeconds = Inf;   % as in 5d-5f: a preview slowed by a loaded machine must not leave the next one out of date
    restoreAutoLimit5h = onCleanup(@() resetAutoLimit(app));
    app.FigureAutoCheckBox.Value = true;   % the automatic preview, as 5d leaves it
    app.selectTab(app.TabFigures);
    ftree = app.FiguresTree;
    noFigures();
    app.onAddFigure("rasterPsth");
    app.onAddFigure("continuous");
    app.onAddFigure("rasterPsth");
    fid = [app.Config.Figures.id];
    kinds = arrayfun(@(f) EphysAnalysisConfig.observeKind(f), app.Config.Figures);
    groupBy = @(by) setGroupBy(app, by);
    groupBy("observe");
    top = ftree.Children;
    check(isequal(kinds, ["unit" "channel" "unit"]) && numel(top) == 2 && string(top(1).Text) == "Per unit  (2)" ...
        && string(top(2).Text) == "Per channel  (1)" && isequal([top(1).Children.NodeData], [1 3]) && top(2).Children.NodeData == 2 ...
        && string(figureNode(ftree, 2).Text) == fid(2) + "  (1 panel)" && string(ftree.SelectedNodes.NodeData) == "3", ...
        'the tree groups the figures by what they observe (unit, channel), a leaf "<id>  (<n> panels)", the one in the editor selected');
    groupBy("status");
    check(isscalar(ftree.Children) && string(ftree.Children.Text) == "Enabled  (3)" ...
        && string(figureNode(ftree, 2).Text) == fid(2) + "  (1 panel, per channel)", ...
        'grouped by status: one Enabled group, each leaf saying what it observes');
    groupBy("none");
    check(numel(ftree.Children) == 3 && all(arrayfun(@(n) isnumeric(n.NodeData), ftree.Children)) ...
        && string(ftree.Children(1).Text) == fid(1) + "  (2 panels, per unit)", 'grouped by none: a flat list in the run order');
    groupBy("observe");
    app.onFigureTreeSelected(figureNode(ftree, 1));
    check(app.SelectedFigure == 1 && string(FE.id.Value) == fid(1), 'picking a leaf of the tree edits that figure');
    app.onFigureTreeSelected(ftree.Children(2));
    check(app.SelectedFigure == 1 && ftree.SelectedNodes.NodeData == 1, 'picking a group''s header keeps the figure selected');
    % the check boxes: the tree's hit test (a figure's box at level 2, a group's at level 1)
    clickAt = @(node, x) struct('InteractionInformation', struct('Node', node, 'Location', ftree.Position(1:2) + [x 5]));
    leafBox = @(k) clickAt(figureNode(ftree, k), 19 + 18 + 8);
    unitGroup = ftree.Children(1);
    check(all(arrayfun(@(k) string(figureNode(ftree, k).UserData) == "on" && ~isempty(figureNode(ftree, k).Icon), 1:3)) ...
        && string(unitGroup.UserData) == "on", 'every figure starts enabled: its box (and its group''s) ticked');
    app.onFigureTreeClicked(clickAt(figureNode(ftree, 3), 150));
    check(app.Config.Figures(3).enabled, 'a click on a figure''s name, not its box, changes nothing');
    app.onFigureTreeClicked(leafBox(3));
    check(~app.Config.Figures(3).enabled && app.Config.Figures(1).enabled && string(figureNode(ftree, 3).UserData) == "off" ...
        && string(ftree.Children(1).UserData) == "mixed" && endsWith(string(figureNode(ftree, 3).Text), "(off)") ...
        && app.SelectedFigure == 1 && FE.enabled.Value, ...
        'a click on its box unticks a figure: off in the config, its box empty, its group''s half-filled, "(off)" on it, the editor''s figure unchanged');
    app.onFigureTreeClicked(leafBox(1));
    check(~app.Config.Figures(1).enabled && ~FE.enabled.Value && string(ftree.Children(1).UserData) == "off", ...
        'unticking the figure in the editor clears its Enabled box; both of the group off: the group''s box empty');
    app.onFigureTreeClicked(clickAt(ftree.Children(1), 19 + 8));
    check(app.Config.Figures(1).enabled && app.Config.Figures(3).enabled && string(ftree.Children(1).UserData) == "on", ...
        'a click on a group''s box ticks its figures');
    app.onFigureTreeClicked(clickAt(ftree.Children(1), 19 + 8));
    check(~app.Config.Figures(1).enabled && ~app.Config.Figures(3).enabled && app.Config.Figures(2).enabled, ...
        'and, all ticked, unticks them (the other group''s figure untouched)');
    app.onFigureCheck("all");
    allOn = all([app.Config.Figures.enabled]);
    app.onFigureCheck("invert");
    inverted = ~any([app.Config.Figures.enabled]);
    app.onFigureCheck("none");
    noneOn = ~any([app.Config.Figures.enabled]);
    app.onFigureCheck("all");
    check(allOn && inverted && noneOn && all([app.Config.Figures.enabled]) && contains(app.StatusBar.Text, "3 of 3 figures enabled"), ...
        'All, Invert and None tick, flip and untick every figure');
    % Up / Down within the group: the unit figures swap, the channel figure between them stays
    app.onFigureSelected(3);
    upOn = app.UpFigureButton.Enable == "on" && app.DownFigureButton.Enable == "off";
    app.onMoveFigure(-1);
    check(upOn && isequal([app.Config.Figures.id], fid([3 2 1])) && app.SelectedFigure == 1 && app.UpFigureButton.Enable == "off" ...
        && app.DownFigureButton.Enable == "on", 'Up moves a figure past its group''s neighbor, not the other group''s figure between them');
    app.onMoveFigure(1);
    check(isequal([app.Config.Figures.id], fid) && app.SelectedFigure == 3, 'Down moves it back');
    app.onFigureSelected(2);
    check(app.UpFigureButton.Enable == "off" && app.DownFigureButton.Enable == "off", 'a figure alone in its group has no Up or Down');
    groupBy("none");
    app.onFigureSelected(2);
    check(app.UpFigureButton.Enable == "on" && app.DownFigureButton.Enable == "on", 'ungrouped, Up and Down go over the whole list');
    % the preferences: Group by and the collapsed groups, restored by a new app (the selected figure's group is always open)
    groupBy("status");
    app.onFigureSelected(1);
    app.setFiguresEnabled(2, "off");
    offGroup = ftree.Children(2);
    app.onFigureGroupToggled(offGroup, true);
    app.onSaveConfig();
    app2 = EphysAnalysisApp();
    restoredBy = string(app2.FigureGroupDropDown.Value) == "status" && isequal(app2.FigureGroupsCollapsed, "status:Off") ...
        && numel(app2.FiguresTree.Children) == 2 && app2.SelectedFigure == 1;
    closeApp(app2);
    check(string(offGroup.NodeData) == "status:Off" && restoredBy ...
        && isequal(string(AppPrefs.getpref(EphysAnalysisApp.PrefGroup, 'FigureGroupBy')), "status"), ...
        'a new app restores the figure tree''s Group by and its collapsed group (FigureGroupBy, FigureGroupsCollapsed)');
    app.onFigureGroupToggled(offGroup, false);
    app.setFiguresEnabled(2, "on");
    groupBy("observe");
    check(isempty(app.FigureGroupsCollapsed), 'expanding the group forgets it');

    % a panel's text note and overlays: the rows apply to the panel picked
    app.onFigureSelected(1);
    app.onPanelSelected(2);   % the PSTH
    for sname = ["note" "overlays"]
        if ~app.FigureSections([app.FigureSections.Name] == sname).Expanded; app.onFigureSectionToggled(sname); end
    end
    Sn = app.FigureSections([app.FigureSections.Name] == "note");
    check(shown(FE.annText) && shown(FE.ovList) && ~shown(FE.ovName) && Sn.Title == "Text note on psth_1" && Sn.Key == "0" ...
        && app.FigureSections([app.FigureSections.Name] == "overlays").Key == "" && FE.annPlace.Enable == "off", ...
        'the Text note and Overlays sections show for the panel picked (Text note on Ctrl+0, Overlays no key), the note''s look off without text');
    FE.annText.Value = {'n = 12'};
    FE.annPlace.Value = "northeast";
    FE.annColor.Value = "#ff0000";
    app.onConfigChanged("figure");
    nt = app.Config.Figures(1).panels(2).note;
    noteTx = findall(app.FigurePreviewPanel, 'Type', 'text', 'Tag', 'note');
    check(nt.text == "n = 12" && nt.placement == "northeast" && nt.color == "#ff0000" && FE.annPlace.Enable == "on" ...
        && app.FigurePreviewState == "drawn" && isscalar(noteTx) && string(noteTx.String) == "n = 12" && isequal(noteTx.Color, [1 0 0]), ...
        'the note rows reach the selected panel''s note, and the preview draws it on that panel');
    app.onAddFigureOverlay("region");
    FE.ovFrom.Value = '0';
    FE.ovTo.Value = '0.05';
    app.onConfigChanged("figure");
    ov1 = app.Config.Figures(1).panels(2).overlays;
    regs = findall(app.FigurePreviewPanel, 'Tag', 'overlayRegion');
    check(isscalar(ov1) && ov1.shape == "region" && ov1.name == "Patch 1" && ov1.to == 0.05 && ov1.panel == "all" ...
        && shown(FE.ovFill) && ~shown(FE.ovValue) && isscalar(regs) && app.FigurePreviewState == "drawn" ...
        && contains(app.FigureSections([app.FigureSections.Name] == "overlays").Title, "Overlays (1) on psth_1"), ...
        'Add patch: an overlay of the panel, its rows edit it, the preview draws it on the PSTH');
    app.onAddFigureOverlay("line");
    app.onDuplicateFigureOverlay();
    three = numel(app.Config.Figures(1).panels(2).overlays) == 3 && app.Config.Figures(1).panels(2).overlays(3).name == "Line 1 copy";
    app.onRemoveFigureOverlay();
    check(three && numel(app.Config.Figures(1).panels(2).overlays) == 2 && numel(FE.ovList.Items) == 2 && shown(FE.ovValue), ...
        'Add line, Duplicate and Remove act on the panel''s overlays');
    app.onPanelSelected(1);   % the raster: none of its own
    rasterRows = isempty(FE.ovList.Items) && strtrim(strjoin(string(FE.annText.Value), "")) == "" && ~shown(FE.ovName);
    app.onPanelSelected(2);
    check(rasterRows && numel(FE.ovList.Items) == 2 && string(FE.annText.Value) == "n = 12" ...
        && numel(app.Config.Figures(1).panels(2).overlays) == 2 && isempty(app.Config.Figures(1).panels(1).overlays), ...
        'picking another panel shows its own note and overlays; going back loses nothing');
    cfgG = app.gatherConfig();
    check(isequaln(cfgG.Figures(1).panels(2).note, app.Config.Figures(1).panels(2).note) ...
        && isequaln(cfgG.Figures(1).panels(2).overlays, app.Config.Figures(1).panels(2).overlays), ...
        'gather after apply gives the panel''s note and overlays back unchanged');
    % a panel's Box row (every type) and the raster's Show y ticks row (rasters only)
    app.onPanelSelected(1);
    boxShown = shown(FE.panelBox) && shown(FE.yTicks) && string(FE.panelBox.Value) == "auto" && ~FE.yTicks.Value;
    FE.panelBox.Value = "off";
    FE.yTicks.Value = true;
    app.onConfigChanged("figure");
    pBx = app.Config.Figures(1).panels(1);
    axBx = findall(app.FigurePreviewPanel, 'Tag', 'rasterAxes');
    check(boxShown && pBx.box == "off" && pBx.options.yTicks && app.FigurePreviewState == "drawn" && isscalar(axBx) ...
        && string(axBx.Box) == "off" && numel(axBx.YTick) >= 2, ...
        'the Panel section''s Box row and a raster''s Show y ticks row reach the panel, and the preview draws them');
    % the ticks' drop-down lists "groups" (stored as is) and the Tick width row reaches the ticks
    groupsShown = string(FE.tickColor.Value) == "groups" && string(FE.tickColor.Items(1)) == "groups" && FE.tickWidth.Value == 0 ...
        && pBx.options.tickColor == "groups";
    FE.tickWidth.Value = 2.5;
    app.onConfigChanged("figure");
    tkW = findall(app.FigurePreviewPanel, 'Tag', 'rasterTicks');
    tkW = tkW(arrayfun(@(t) any(isfinite(t.XData)), tkW));
    check(groupsShown && app.Config.Figures(1).panels(1).options.tickWidth == 2.5 && ~isempty(tkW) && all([tkW.LineWidth] == 2.5), ...
        'a raster''s Colors row shows "groups" for the groups'' colors; the Tick width row reaches the panel and the preview''s ticks');
    FE.tickWidth.Value = 0;
    FE.panelBox.Value = "auto";
    FE.yTicks.Value = false;
    app.onConfigChanged("figure");
    app.onPanelSelected(2);
    check(shown(FE.panelBox) && ~shown(FE.yTicks) && app.Config.Figures(1).panels(1).box == "auto" && ~app.Config.Figures(1).panels(1).options.yTicks, ...
        'a PSTH panel has the Box row but no y ticks row; both back to their defaults on the raster');
    % a panel's X axis and Y axis rows (every type): its own label text and side reach the panel and the preview
    axRows = shown(FE.panelXLabel) && shown(FE.panelXSide) && shown(FE.panelYLabel) && shown(FE.panelYSide) ...
        && string(FE.panelXSide.Value) == "bottom" && string(FE.panelYSide.Value) == "left" && string(FE.panelYLabel.Value) == "" ...
        && FE.panelYSide.Enable == "on";
    FE.panelYLabel.Value = "Rate";
    FE.panelYSide.Value = "right";
    app.onConfigChanged("figure");
    pAx = app.Config.Figures(1).panels(2);
    axP = findPanelAxes(app.FigurePreviewPanel, "psth_1");
    check(axRows && pAx.yLabel == "Rate" && pAx.ySide == "right" && pAx.xSide == "bottom" && app.FigurePreviewState == "drawn" ...
        && strcmp(axP.YAxisLocation, 'right') && string(axP.YLabel.String) == "Rate", ...
        'the X axis and Y axis rows show for the selected panel; its y label and side reach the panel, and the preview draws them');
    FE.stack.Value = true;
    app.onConfigChanged("figure");
    stackOff = FE.panelYSide.Enable == "off";
    FE.stack.Value = false;
    app.onConfigChanged("figure");
    check(stackOff && FE.panelYSide.Enable == "on", 'a stacked PSTH (a y axis on each side) grays out the Y axis row''s side');
    % an axis label's right-click menu (renderFigure's OnAxisEdit) goes through the editor's path: config, rows, preview
    app.onPanelSelected(1);
    app.onFigureAxisEdited(app.Config.Figures(1).id, "psth_1", struct('ySide', "left", 'yLabel', "", 'xLabel', "Lag (s)"));
    pAx = app.Config.Figures(1).panels(2);
    axP = findPanelAxes(app.FigurePreviewPanel, "psth_1");
    check(pAx.ySide == "left" && pAx.yLabel == "" && pAx.xLabel == "Lag (s)" && app.SelectedPanel == 2 ...
        && string(FE.panelYSide.Value) == "left" && string(FE.panelYLabel.Value) == "" && string(FE.panelXLabel.Value) == "Lag (s)" ...
        && strcmp(axP.YAxisLocation, 'left') && string(axP.XLabel.String) == "Lag (s)", ...
        'onFigureAxisEdited: the panel''s fields set, the panel selected and its rows following, the preview drawn again');
    app.onFigureAxisEdited(app.Config.Figures(1).id, "psth_1", struct('xLabel', ""));
    check(app.Config.Figures(1).panels(2).xLabel == "" && app.FigureHistory.undoLabel() == "Label text", ...
        'a blank label text: the automatic label again, a step of its own in the undo history (Undo Label text)');
    app.onFigureAxisEdited(app.Config.Figures(1).id, "psth_1", struct('xSide', "top"));
    app.onUndoRedo("undo");
    check(app.Config.Figures(1).panels(2).xSide == "bottom" && app.FigureHistory.undoLabel() == "Label text" ...
        && contains(app.StatusBar.Text, "Axis side"), 'Move to top from the label''s menu is undone like an editor edit (Undo Axis side)');

    % drag a panel in the schematic: the press installs the window's pointer callbacks; motion shades the target; release applies
    if ~app.FigureSections([app.FigureSections.Name] == "arrangement").Expanded; app.onFigureSectionToggled("arrangement"); end
    app.onFigureSelected(1);
    sch = @() app.FigureSchematic;
    cellOf1 = @(id) arrayfun(@(q) [q.row q.col q.rowSpan q.colSpan], app.Config.Figures(1).panels([app.Config.Figures(1).panels.id] == id), ...
        'UniformOutput', false);
    qOf = @(id) find([app.Config.Figures(1).panels.id] == id);
    app.Fig.CurrentPoint = [400 300];
    app.onSchematicPress(qOf("raster_1"), struct('IntersectionPoint', [0.5 0.25 0]));
    installed = isa(app.Fig.WindowButtonMotionFcn, 'function_handle') && isa(app.Fig.WindowButtonUpFcn, 'function_handle') ...
        && ~isempty(app.FigureDrag) && app.SelectedPanel == qOf("raster_1");
    axS = sch();
    unitsS = axS.Units;
    axS.Units = 'pixels';
    ipS = axS.InnerPosition;
    axS.Units = unitsS;
    wantScale = [diff(axS.XLim) / ipS(3), -diff(axS.YLim) / ipS(4)];
    pHalf = app.schematicPixel([0.5 0.25] + [diff(axS.XLim) / 2, diff(axS.YLim) / 2]) - [400 300];
    check(all(abs(app.FigureDrag.scale - wantScale) < 1e-9) && norm(app.schematicPixel([0.5 0.25]) - [400 300]) < 1e-6 ...
        && norm(pHalf - [ipS(3) / 2, -ipS(4) / 2]) < 1e-6, ...
        sprintf('the drag''s scale is the schematic''s limits over its plot box (%g x %g px), y down; the press point maps to the pointer', ipS(3), ipS(4)));
    app.Fig.CurrentPoint = app.schematicPixel([0.5 0.92]);   % psth_1's bottom band, in its middle third
    app.Fig.WindowButtonMotionFcn(app.Fig, []);
    T1 = app.FigureDrag.target;
    dragGfx = isscalar(findall(sch(), 'Tag', 'schematicDragOutline')) && isscalar(findall(sch(), 'Tag', 'schematicDropTarget'));
    check(installed && dragGfx && T1.kind == "edge" && T1.where == "below" && T1.anchor == "psth_1", ...
        'a press on raster_1 starts a drag (the window''s motion and release callbacks); over psth_1''s bottom band the outline follows and "below psth_1" is shaded');
    app.Fig.WindowButtonUpFcn(app.Fig, []);
    check(isempty(app.FigureDrag) && isempty(app.Fig.WindowButtonMotionFcn) && isempty(app.Fig.WindowButtonUpFcn) ...
        && isequal(cellOf1("psth_1"), {[1 1 1 1]}) && isequal(cellOf1("raster_1"), {[2 1 1 1]}) && app.Config.Figures(1).grid.rows == 2 ...
        && app.SelectedPanel == qOf("raster_1") && contains(app.StatusBar.Text, "Moved raster_1 below psth_1") && nPatches() == 2 ...
        && isempty(findall(sch(), 'Tag', 'schematicDragOutline')) && app.FigurePreviewState == "drawn", ...
        'released there, raster_1 is moved below psth_1 (removePanel, placePanel); the callbacks are cleared, the schematic and preview redrawn');
    app.onPanelSelected(qOf("psth_1"));
    app.onNewPanel(Type="continuous", Where="right");   % a column right of psth_1: the cell under it, right of raster_1, stays empty
    emptyCell = EphysAnalysisConfig.figureCells(app.Config.Figures(1));
    app.Fig.CurrentPoint = [400 300];
    app.onSchematicPress(qOf("raster_1"), struct('IntersectionPoint', [0.25 0.75 0]));
    app.Fig.CurrentPoint = app.schematicPixel([0.75 0.75]);
    app.Fig.WindowButtonMotionFcn(app.Fig, []);
    T2 = app.FigureDrag.target;
    app.Fig.WindowButtonUpFcn(app.Fig, []);
    check(isequal(size(emptyCell), [2 2]) && emptyCell(2, 2) == 0 && T2.kind == "cell" && T2.row == 2 && T2.col == 2 ...
        && isequal(cellOf1("raster_1"), {[2 2 1 1]}) && contains(app.StatusBar.Text, "Moved raster_1 to row 2, column 2") ...
        && isempty(app.Fig.WindowButtonUpFcn), 'dragged onto the empty cell, raster_1 moves there (its row and column)');
    % cancel: released outside the schematic, or Escape
    before = app.Config.Figures(1);
    app.Fig.CurrentPoint = [400 300];
    app.onSchematicPress(qOf("raster_1"), struct('IntersectionPoint', [0.75 0.75 0]));
    app.Fig.CurrentPoint = app.schematicPixel([0.25 0.75]);
    app.Fig.WindowButtonMotionFcn(app.Fig, []);
    app.Fig.CurrentPoint = app.schematicPixel([1.6 0.5]);
    app.Fig.WindowButtonUpFcn(app.Fig, []);
    check(isequaln(app.Config.Figures(1), before) && isempty(app.FigureDrag) && isempty(app.Fig.WindowButtonUpFcn) ...
        && contains(app.StatusBar.Text, "released outside") && isempty(findall(sch(), 'Tag', 'schematicDropTarget')), ...
        'released outside the schematic, the drag is canceled: nothing moves, the callbacks are cleared');
    app.Fig.CurrentPoint = [400 300];
    app.onSchematicPress(qOf("raster_1"), struct('IntersectionPoint', [0.75 0.75 0]));
    app.Fig.CurrentPoint = app.schematicPixel([0.25 0.75]);
    app.Fig.WindowButtonMotionFcn(app.Fig, []);
    shaded = app.FigureDrag.target.kind == "cell";
    app.onKeyPress(pressed('escape', {}));
    check(shaded && isequaln(app.Config.Figures(1), before) && isempty(app.FigureDrag) && isempty(app.Fig.WindowButtonMotionFcn) ...
        && contains(app.StatusBar.Text, "Drag canceled") && isempty(findall(sch(), 'Tag', 'schematicDragOutline')), ...
        'Escape cancels a drag over an empty cell: nothing moves, the outline goes');
    % a 3 x 2 grid: psth_1 over rows 1-2 of column 1, continuous_1 at (1, 2), raster_1 at (3, 2); (2, 2) and (3, 1) empty
    cfgD = app.gatherConfig();
    fz = cfgD.Figures(1);
    fz.grid.rows = 3; fz.grid.cols = 2; fz.grid.rowHeights = []; fz.grid.colWidths = [];
    place3 = struct('psth_1', [1 1 2 1], 'continuous_1', [1 2 1 1], 'raster_1', [3 2 1 1]);
    for q = 1:numel(fz.panels)
        v = place3.(fz.panels(q).id);
        fz.panels(q).row = v(1); fz.panels(q).col = v(2); fz.panels(q).rowSpan = v(3); fz.panels(q).colSpan = v(4);
    end
    cfgD.Figures(1) = fz;
    app.applyConfig(cfgD);
    before = app.Config.Figures(1);
    dragTo = @(id, from, to) dragPanel(app, qOf(id), from, to);
    T3 = dragTo("psth_1", [0.25 1/3], [0.75 0.5]);   % (2, 2): rows 2-3 would cover raster_1
    check(T3.kind == "none" && isfield(T3, 'why') && isequaln(app.Config.Figures(1), before) ...
        && contains(app.StatusBar.Text, "psth_1 does not fit at row 2, column 2: it would overlap raster_1") ...
        && isempty(findall(sch(), 'Tag', 'schematicDropTarget')), ...
        'an empty cell the panel would not fit in is no target (not shaded): released there, nothing moves and the status bar says why');
    T4 = dragTo("psth_1", [0.25 1/3], [0.25 5/6]);   % (3, 1): its two rows clipped to one
    check(T4.kind == "cell" && isequal(cellOf1("psth_1"), {[3 1 1 1]}) ...
        && contains(app.StatusBar.Text, "Moved psth_1 to row 3, column 1. Its spans became 1 x 1 to fit the grid."), ...
        'dropped on the bottom row, a panel over two rows moves there with its span clipped to the grid, and says so');
    before = app.Config.Figures(1);
    T5 = dragTo("psth_1", [0.25 5/6], [0.75 1/6]);   % continuous_1's middle: no edge band
    check(T5.kind == "none" && isequaln(app.Config.Figures(1), before) && contains(app.StatusBar.Text, "Nothing to drop psth_1 on there"), ...
        'released over another panel''s middle, nothing moves and the status bar says where to drop it');
    order0 = [app.Config.Figures(1).panels.id];
    T6 = dragTo("continuous_1", [0.75 1/6], [0.75 0.95]);   % raster_1's bottom band: below it
    check(T6.kind == "edge" && isequal([app.Config.Figures(1).panels.id], order0) && app.SelectedPanel == qOf("continuous_1") ...
        && contains(app.StatusBar.Text, "Moved continuous_1 below raster_1"), ...
        'an edge drop keeps the panel''s place in the figure''s panel order (the draw order and the legend''s first panel)');
    noFigures();
    app.onSaveConfig();
    app.Tabs.SelectedTab = app.TabData;
    clear restoreAutoLimit5h
end

if S.sec("5i", "favorites: stars on datasets, units and channels; the Favorites lists")
    savedConfig();
    noFigures();
    app.FigureAutoPreviewSeconds = Inf;   % as in 5d-5f
    restoreAutoLimit5i = onCleanup(@() resetAutoLimit(app));
    app.FigureAutoCheckBox.Value = true;   % the automatic preview, as 5d leaves it
    app.selectDataset(kF1);
    favDD = app.FigureFavorites.DropDown;
    check(numel(app.Favorites) == 2 && isa(app.Favorites, 'DatasetFavorites') && ~any([app.Favorites.Dataset]) ...
        && ~any(app.DatasetsTable.Data.Star) && app.FiguresDatasetStar.Enable == "on" && ~app.FiguresDatasetStar.Value ...
        && string(app.FiguresDatasetStar.Text) == "☆" && startsWith(string(favDD.Items{1}), "(no favorites") ...
        && isequal(string(app.AlignFavorites.DropDown.Items), string(favDD.Items)), ...
        'no star yet: the Data tab''s ★ column clear, the star toggles on and empty, the Favorites lists say so');
    app.onStarToggled("dataset", true);
    fav1 = app.Favorites(kF1);
    J1 = jsondecode(fileread(fav1.File));
    check(fav1.Dataset && isfile(fav1.File) && fav1.File == fullfile(app.Runner.datasetFolder(kF1), F.names(1) + "_favorites.json") ...
        && J1.schema == "ephys-favorites/1" && J1.starred && app.FiguresDatasetStar.Value && app.AlignDatasetStar.Value ...
        && string(app.FiguresDatasetStar.Text) == "★" && startsWith(string(app.FiguresDatasetDropDown.Items{kF1}), "★ " + F.names(1)) ...
        && ~startsWith(string(app.FiguresDatasetDropDown.Items{kF2}), "★") && app.DatasetsTable.Data.Star(app.DatasetsTable.Data.Idx == kF1) ...
        && numel(favDD.Items) == 2 && string(favDD.Items{2}) == F.names(1) && favDD.Value == 0 && contains(app.StatusBar.Text, "Starred " + F.names(1)), ...
        sprintf('the star beside Dataset stars the active dataset at once: <Name>_favorites.json in its output folder, ★ in the drop-downs, the table and Favorites ("%s")', ...
        app.StatusBar.Text));
    ticked0 = app.Ticked;
    TD = app.DatasetsTable.Data;
    TD.Star(TD.Idx == kF2) = true;
    app.DatasetsTable.Data = TD;
    app.onDatasetsTableEdited([]);
    check(app.Favorites(kF2).Dataset && isfile(app.Favorites(kF2).File) && isequal(app.Ticked, ticked0) && numel(favDD.Items) == 3, ...
        'ticking ★ in the Data tab''s table stars that dataset (the Run ticks stay)');
    app.onScan();
    check(numel(app.Favorites) == 2 && all([app.Favorites.Dataset]) && all(app.DatasetsTable.Data.Star) && numel(favDD.Items) == 3, ...
        'a new scan reads the stars back from the datasets'' files');
    app.selectTab(app.TabFigures);
    app.selectDataset(kF1);
    app.onAddFigure("rasterPsth");
    TU = app.FigureObservations;
    oDD = app.FigureObservationDropDown;
    oDD.Value = 2;
    app.onFigureObservationChanged();
    u2 = TU.unitId(2);
    idF = char(app.Config.Figures(1).id);
    app.onStarToggled("observation", true);
    J1 = jsondecode(fileread(app.Favorites(kF1).File));
    oItems = string(oDD.Items);
    check(app.Favorites(kF1).isStarred("unit", u2) && app.FigureObservationStar.Value && startsWith(oItems(2), "★ " + TU.label(2)) ...
        && ~startsWith(oItems(1), "★") && oDD.Value == 2 && string(app.FigureObservation(idF)) == TU.label(2) ...
        && isscalar(J1.units) && J1.units.ids == u2 && string(J1.units.sort) ~= "" && J1.units.spikeTimesBytes > 0, ...
        sprintf('the star beside the observation stars the unit previewed, with its sort ("%s", %d bytes of spike times); the picker marks it and keeps the pick', ...
        string(J1.units.sort), J1.units.spikeTimesBytes));
    app.onFigureObservationStep(-1);
    offOther = ~app.FigureObservationStar.Value && app.FigureObservationStar.Enable == "on";
    app.onFigureObservationStep(1);
    check(offOther && app.FigureObservationStar.Value && contains(figTitle(), TU.label(2)), ...
        '< and > step through the marked list, the star toggle following each unit');
    E = app.FavoriteEntries;
    iu = find(E.level == "unit");
    mu = TU.meta{2};   % the unit's class, channel and depth: read when its dataset was opened (DatasetUnits)
    richU = F.names(1) + " · unit " + u2 + " · " + mu.class(1) + " · ch " + mu.channel(1);
    if isfinite(mu.y(1)); richU = richU + " · " + compose("%g µm", round(mu.y(1))); end
    check(height(E) == 3 && isequal(E.level(E.dataset == kF1), ["dataset"; "unit"]) && isequal(E.level(E.dataset == kF2), "dataset") ...
        && issorted(E.dataset) && isscalar(iu) && E.label(iu) == richU ...
        && numel(favDD.Items) == 4 && contains(string(favDD.Items{1}), "3 favorites"), ...
        sprintf('Favorites lists each starred dataset with its units, in dataset order, a unit of an opened dataset with its class, channel and depth ("%s")', E.label(iu)));
    app.DatasetUnits = [];   % as before its dataset was opened: the short label, nothing read for it
    app.refreshFavorites();
    shortU = app.FavoriteEntries.label(iu);
    app.selectDataset(kF1);   % opening it fills the label in
    check(shortU == F.names(1) + " · unit " + u2 && app.FavoriteEntries.label(iu) == richU, ...
        sprintf('a dataset not opened keeps the short label ("%s"); opening it fills the list in', shortU));
    app.onFavoritesFilter("FigureFavorites", "UNIT " + u2);
    fItems = string(favDD.Items);
    check(numel(fItems) == 2 && fItems(2) == E.label(iu) && contains(fItems(1), "1 of 3") && isequal(favDD.ItemsData, [0 iu]), ...
        'typing in the filter narrows the Favorites list (every word, any case)');
    app.onFavoritesFilter("FigureFavorites", "no such thing");
    check(numel(favDD.Items) == 1 && contains(string(favDD.Items{1}), "0 of 3"), 'a filter nothing matches leaves only the count');
    app.onFavoritesFilter("FigureFavorites", "");
    app.selectDataset(kF2);
    app.onScan();
    check(app.ActiveIdx == kF1 && oDD.Value == 2 && string(app.FigureObservation(idF)) == TU.label(2) && contains(figTitle(), TU.label(2)), ...
        'a scan (a config opened) starts on the first starred unit: its dataset active, the unit previewed, not the first dataset');
    app.selectDataset(kF2);
    favDD.Value = iu;
    app.onFavoritePicked("FigureFavorites");
    check(app.ActiveIdx == kF1 && oDD.Value == 2 && app.FigurePreviewState == "drawn" && contains(figTitle(), TU.label(2)) ...
        && favDD.Value == 0 && app.FigureObservationStar.Value, ...
        'picking the starred unit in Favorites makes its dataset active and previews that unit');
    app.selectTab(app.TabAlign);
    aDD = app.AlignFavorites.DropDown;
    aDD.Value = find(app.FavoriteEntries.dataset == kF2, 1);
    app.onFavoritePicked("AlignFavorites");
    check(app.ActiveIdx == kF2 && string(app.AlignDatasetDropDown.Value) == string(kF2) && app.AlignDatasetStar.Value && aDD.Value == 0, ...
        'the Alignment tab''s Favorites: picking a dataset makes it active');
    aDD.Value = find(app.FavoriteEntries.level == "unit", 1);
    app.onFavoritePicked("AlignFavorites");
    check(app.ActiveIdx == kF1 && oDD.Value == 2 && app.FigurePreviewState ~= "computing" && string(app.FigureObservation(idF)) == TU.label(2), ...
        'picked from the Alignment tab, a starred unit becomes the Figures tab''s pick on its dataset');
    app.selectTab(app.TabFigures);
    FE.observe.Value = "LFP";
    app.onConfigChanged("figure");
    TLf = app.FigureObservations;
    oDD.Value = 1;
    app.onFigureObservationChanged();
    app.onStarToggled("observation", true);
    ch1 = TLf.channel(1);
    richC = F.names(1) + " · channel " + ch1;
    if isfinite(TLf.depth(1)); richC = richC + " · " + compose("%g µm", round(TLf.depth(1))); end
    check(app.Favorites(kF1).isStarred("channel", ch1) && startsWith(string(oDD.Items{1}), "★ ") && app.FigureObservationStar.Value ...
        && any(app.FavoriteEntries.label == richC), ...
        sprintf('a figure of LFP channels: the star stars the channel (channel %d), marked in the picker and listed', ch1));
    srcF = app.Runner.source(kF1);
    if srcF.hasDetected
        FE.observe.Value = "detected";
        app.onConfigChanged("figure");
        TDf = app.FigureObservations;
        oDD.Value = 1;
        app.onFigureObservationChanged();
        app.onStarToggled("observation", true);
        chD = TDf.channel(1);
        marked = startsWith(string(oDD.Items), "★");
        check(app.Favorites(kF1).isStarred("channel", chD) && marked(1) && isequal(marked(:), ismember(TDf.channel, app.Favorites(kF1).Channels)), ...
            sprintf('a detection channel is starred as its channel (channel %d); every detection channel whose channel is starred is marked', chD));
    end
    FE.observe.Value = "dataset";
    app.onConfigChanged("figure");
    check(app.FigureObservationStar.Value && startsWith(string(oDD.Items{1}), "★ "), ...
        'a figure of the dataset: the observation''s star is the dataset''s');
    app.onStarToggled("observation", false);
    check(~app.Favorites(kF1).Dataset && ~app.FiguresDatasetStar.Value && app.Favorites(kF1).isStarred("unit", u2), ...
        'unstarring the dataset from there leaves its unit and channel stars');
    FE.obsStarred.Value = true;   % Starred only: the dataset is not starred now
    app.onConfigChanged("figure");
    check(app.Config.Figures(1).observe.starred && shown(FE.obsStarred) && isempty(app.FigureObservations) ...
        && contains(string(FE.obsCount.Text), "not starred"), ...
        sprintf('Starred only on a figure of an unstarred dataset: no observation, the count line says why ("%s")', FE.obsCount.Text));
    FE.observe.Value = "units";
    app.onConfigChanged("figure");
    TS = app.FigureObservations;
    check(istable(TS) && height(TS) == 1 && TS.unitId == u2 && TS.starred && contains(string(FE.obsCount.Text), "starred only") ...
        && startsWith(string(oDD.Items{1}), "★ "), ...
        sprintf('Starred only: the picker lists just the starred unit ("%s")', FE.obsCount.Text));
    u1 = TU.unitId(1);
    app.Favorites(kF1).star("unit", u1);
    app.refreshFavorites();   % as a toggle does: the list is made again
    n2 = height(app.FigureObservations);
    app.Favorites(kF1).star("unit", u1, false);
    app.refreshFavorites();
    check(n2 == 2 && height(app.FigureObservations) == 1 && app.FigureObservations.unitId == u2, ...
        'with Starred only a star added or taken away lists the units again');
    if ismember(kF1, app.tickedDatasetIndices())
        FE.obsStarred.Value = false;
        FE.sesEnabled.Value = true;   % across sessions: the site of the starred unit is marked
        app.onConfigChanged("figure");
        TM = app.FigureObservations;
        jM = find(TM.channel == TU.channel(2), 1);
        mItems = string(oDD.Items);
        check(~isempty(jM) && TM.starred(jM) && startsWith(mItems(jM), "★ ") && nnz(startsWith(mItems, "★ ")) == nnz(TM.starred), ...
            'a figure across sessions marks the match starred on any of its sessions (the site of the starred unit)');
        FE.obsStarred.Value = true;
        app.onConfigChanged("figure");
        TM2 = app.FigureObservations;
        check(height(TM2) == nnz(TM.starred) && all(TM2.starred) && contains(string(FE.obsCount.Text), "starred on any session"), ...
            sprintf('Starred only across sessions keeps the matches starred on any session ("%s")', FE.obsCount.Text));
        FE.sesEnabled.Value = false;
    end
    FE.obsStarred.Value = false;
    app.onConfigChanged("figure");
    app.selectDataset(kF2);
    app.onStarToggled("dataset", false);
    fav2 = app.Favorites(kF2);
    check(~fav2.Dataset && ~isfile(fav2.File), 'unstarring the last star removes the file');
    if ispc
        me = string(getenv('USERNAME'));
        folder2 = fav2.Folder;
        [stDeny, outDeny] = system(sprintf('icacls "%s" /deny "%s":(W)', folder2, me));
        undeny = onCleanup(@() system(sprintf('icacls "%s" /remove:d "%s"', folder2, me)));
        if stDeny == 0
            app.onStarToggled("dataset", true);
            check(~fav2.Dataset && ~isfile(fav2.File) && ~app.FiguresDatasetStar.Value && ~app.DatasetsTable.Data.Star(app.DatasetsTable.Data.Idx == kF2) ...
                && contains(app.StatusBar.Text, "not starred") && contains(app.StatusBar.Text, "read-only") && isvalid(app.Fig), ...
                sprintf('an output folder that cannot be written (read-only): no star, the toggle back off, the status bar says why ("%s")', app.StatusBar.Text));
        else
            fprintf('  (skipped the read-only folder: icacls could not deny writing: %s)\n', strtrim(outDeny));
        end
        clear undeny
    end
    noFigures();
    app.onSaveConfig();
    app.Tabs.SelectedTab = app.TabData;
    clear restoreAutoLimit5i
end

if S.sec("5j", "notes: the notepad on datasets, units and channels; the ✎ marks; Search notes")
    savedConfig();
    noFigures();
    app.FigureAutoPreviewSeconds = Inf;   % as in 5i
    restoreAutoLimit5j = onCleanup(@() resetAutoLimit(app));
    app.FigureAutoCheckBox.Value = true;   % the automatic preview, as 5d leaves it
    yellow = [1 0.88 0.45];
    app.selectTab(app.TabFigures);
    app.selectDataset(kF1);
    check(numel(app.Notes) == 2 && isa(app.Notes, 'DatasetNotes') && ~any(arrayfun(@(d) d.hasNote("dataset"), app.Notes)) ...
        && all(app.DatasetsTable.Data.Note == "") && app.FiguresDatasetNote.Enable == "on" && app.AlignDatasetNote.Enable == "on" ...
        && string(app.FiguresDatasetNote.Text) == "✎" && ~isequal(app.FiguresDatasetNote.BackgroundColor, yellow) && isempty(app.NotePadWindow), ...
        'no note yet: the Data tab''s ✎ column empty, the note buttons on and plain, no notepad');
    app.onNoteButton("dataset");
    pad = app.NotePadWindow;
    check(isa(pad, 'NotePad') && isvalid(pad) && pad.Item.level == "dataset" && pad.Item.notes == app.Notes(kF1) ...
        && app.NotePadFollows == "dataset" && pad.TitleLabel.Text == F.names(1) && pad.Text == "", ...
        'the note button beside Dataset opens the notepad on the active dataset');
    pad.setText(["good day"; "check channel 3"]);
    pad.save();
    notes1 = app.Notes(kF1);
    J1 = jsondecode(fileread(notes1.File));
    TD = app.DatasetsTable.Data;
    check(notes1.note("dataset") == "good day" + newline + "check channel 3" ...
        && notes1.File == fullfile(app.Runner.datasetFolder(kF1), F.names(1) + "_notes.json") && J1.schema == "ephys-notes/1" ...
        && isequal(app.FiguresDatasetNote.BackgroundColor, yellow) && isequal(app.AlignDatasetNote.BackgroundColor, yellow) ...
        && any(contains(string(app.FiguresDatasetNote.Tooltip), "Note: good day")) && TD.Note(TD.Idx == kF1) == "✎" ...
        && TD.Note(TD.Idx == kF2) == "" && startsWith(string(app.FiguresDatasetDropDown.Items{kF1}), "✎ " + F.names(1)), ...
        'Save writes <Name>_notes.json in its output folder; the note buttons turn yellow with its first line, ✎ in the Data tab and the Dataset drop-downs');
    app.selectDataset(kF2);
    check(pad.Item.notes == app.Notes(kF2) && pad.Text == "" && app.NotePadFollows == "dataset" ...
        && ~isequal(app.FiguresDatasetNote.BackgroundColor, yellow), ...
        'another active dataset: the notepad follows it (no note there), the buttons plain again');
    pad.setText("second dataset");
    app.selectDataset(kF1);
    check(app.Notes(kF2).note("dataset") == "second dataset" && pad.Item.notes == notes1 && pad.Text == "good day" + newline + "check channel 3", ...
        'moving on writes the note typed, then shows the next dataset''s');
    app.onAddFigure("rasterPsth");
    idF = char(app.Config.Figures(1).id);
    TU = app.FigureObservations;
    oDD = app.FigureObservationDropDown;
    oDD.Value = 2;
    app.onFigureObservationChanged();
    u1 = TU.unitId(1);
    u2 = TU.unitId(2);
    app.onNoteButton("observation");
    check(pad.Item.level == "unit" && pad.Item.id == u2 && app.NotePadFollows == "observation" && contains(pad.TitleLabel.Text, "unit " + u2), ...
        'the note button beside Observation moves the notepad to the unit previewed');
    pad.setText("bursty");
    pad.save();
    J1 = jsondecode(fileread(notes1.File));
    oItems = string(oDD.Items);
    check(notes1.note("unit", u2) == "bursty" && isscalar(J1.units) && J1.units.notes.id == u2 && J1.units.spikeTimesBytes > 0 ...
        && contains(oItems(2), "✎ " + TU.label(2)) && ~contains(oItems(1), "✎") && oDD.Value == 2 ...
        && isequal(app.FigureObservationNote.BackgroundColor, yellow), ...
        'the unit''s note is written with its sort; ✎ marks it in the observation list, the pick kept; its button is yellow');
    app.onFigureObservationStep(-1);
    check(pad.Item.id == u1 && pad.Text == "" && ~isequal(app.FigureObservationNote.BackgroundColor, yellow), ...
        '< moves the notepad to the previous unit');
    pad.setText("quiet");
    app.onFigureObservationStep(1);
    check(notes1.note("unit", u1) == "quiet" && pad.Item.id == u2 && pad.Text == "bursty", ...
        '> writes the note typed and moves the notepad back to the next unit, its note in the box');
    FE.observe.Value = "LFP";
    app.onConfigChanged("figure");
    TLn = app.FigureObservations;
    oDD.Value = 1;
    app.onFigureObservationChanged();
    chN = TLn.channel(1);
    check(pad.Item.level == "channel" && pad.Item.id == chN, sprintf('a figure of LFP channels: the notepad follows the channel (%d)', chN));
    pad.setText("noisy");
    pad.save();
    check(notes1.note("channel", chN) == "noisy" && contains(string(oDD.Items{1}), "✎ "), 'the channel''s note, marked in the picker');
    FE.observe.Value = "units";
    app.onConfigChanged("figure");
    app.onSearchNotes();
    NS = app.NoteSearchWindow;
    check(isa(NS, 'NoteSearch') && isvalid(NS) && height(NS.Entries) == 5 && numel(NS.Matches) == 5 ...
        && nnz(NS.Entries.dataset == kF1) == 4 && nnz(NS.Entries.dataset == kF2) == 1, ...
        'Search notes (the toolbar) lists every note of the scanned datasets');
    NS.search("BURSTY");
    NS.pick(1);
    app.selectDataset(kF2);
    NS.goTo();
    check(isscalar(NS.Matches) && app.ActiveIdx == kF1 && oDD.Value == 2 && string(app.FigureObservation(idF)) == TU.label(2) ...
        && startsWith(app.StatusBar.Text, "Note: "), ...
        sprintf('Go to on a unit''s note makes its dataset active and picks the unit in the Figures tab ("%s")', app.StatusBar.Text));
    NS.search(F.names(2));
    NS.pick(1);
    NS.goTo();
    check(isscalar(NS.Matches) && NS.Table.Data.Item(1) == "dataset" && app.ActiveIdx == kF2, 'Go to on a dataset''s note makes it the active dataset');
    NS.search("quiet");
    NS.pick(1);
    NS.edit();
    check(pad.Item.level == "unit" && pad.Item.id == u1 && pad.Item.notes == notes1 && app.NotePadFollows == "" && pad.Text == "quiet", ...
        'Edit note opens that note in the notepad, which then stays on it');
    app.selectDataset(kF1);
    check(pad.Item.id == u1 && pad.Item.level == "unit", 'opened from the search, the notepad does not follow the active dataset');
    pad.setText("quiet, then bursts");
    pad.save();
    NS.search("bursts");
    check(isscalar(NS.Matches) && NS.Table.Data.Item(1) == "unit " + u1, 'a note written shows in the open search window at once');
    app.selectTab(app.TabData);
    TD = app.DatasetsTable.Data;
    app.onDatasetNoteClicked(struct('InteractionInformation', struct('Row', find(TD.Idx == kF2), ...
        'Column', find(TD.Properties.VariableNames == "Note"))));
    check(app.ActiveIdx == kF2 && pad.Item.notes == app.Notes(kF2) && pad.Item.level == "dataset" && pad.Text == "second dataset" ...
        && app.NotePadFollows == "dataset", 'a click in the Data tab''s ✎ column makes the dataset active and opens its note');
    pad.setText("");
    pad.save();
    TD = app.DatasetsTable.Data;
    check(~app.Notes(kF2).hasNote("dataset") && ~isfile(app.Notes(kF2).File) && TD.Note(TD.Idx == kF2) == "", ...
        'an emptied note is no note: its file gone (its only note), the ✎ cleared');
    app.onScan();
    TD = app.DatasetsTable.Data;
    check(app.Notes(kF1).note("unit", u2) == "bursty" && app.Notes(kF1).note("channel", chN) == "noisy" && TD.Note(TD.Idx == kF1) == "✎" ...
        && height(NS.Entries) == 4 && isvalid(pad), 'a new scan reads the notes back; the search window lists them again');
    pad.close();
    NS.close();
    check(~isvalid(pad) && ~isvalid(NS), 'the notepad and the search window close');
    noFigures();
    app.onSaveConfig();
    app.Tabs.SelectedTab = app.TabData;
    clear restoreAutoLimit5j
end

if S.sec("5k", "Edit menu: undo and redo of the figure editor")
    savedConfig();
    noFigures();
    app.onSaveConfig();   % the saved figures: none, which undoing every edit below comes back to
    app.FigureAutoCheckBox.Value = false;   % no preview drawn: undo is about the config and the editor
    restoreAuto5k = onCleanup(@() set(app.FigureAutoCheckBox, 'Value', true));
    menus = flip(findobj(app.Fig.Children, 'flat', 'Type', 'uimenu'));
    app.selectTab(app.TabData);
    H = app.FigureHistory;
    check(isequal(string({menus.Text}), ["File" "Edit" "Design" "Help"]) && string(app.UndoMenu.Text) == strtrim("Undo " + H.undoLabel()) ...
        && string(app.UndoMenu.Accelerator) == "Z" && string(app.RedoMenu.Accelerator) == "Y" && app.UndoMenu.Enable == "off", ...
        sprintf('an Edit menu between File and Design: Undo (Ctrl+Z) names the last edit ("%s"), grayed off the Figures tab', app.UndoMenu.Text));
    app.selectTab(app.TabFigures);
    check(app.UndoMenu.Enable == matlab.lang.OnOffSwitchState(~isempty(H.Undo)) && app.RedoMenu.Enable == "off" && string(app.RedoMenu.Text) == "Redo", ...
        sprintf('on the Figures tab Undo is on (%d steps of the sections above); Redo is grayed with nothing undone', numel(H.Undo)));
    app.FigureHistory = FigureEditHistory();
    app.onTabChanged();
    check(string(app.UndoMenu.Text) == "Undo" && app.UndoMenu.Enable == "off", 'an empty history: Undo grayed, no edit named');
    clean = @() ~startsWith(string(app.Fig.Name), "*");
    check(clean(), 'the config starts saved');
    app.onAddFigure("rasterPsth");
    check(string(app.UndoMenu.Text) == "Undo Add figure" && ~clean(), 'Add (a template): Undo Add figure; the title shows unsaved changes');
    FE.title.Value = 'Undo me';
    FE.title.ValueChangedFcn(FE.title, []);
    FE.title.Value = 'Undo me twice';
    FE.title.ValueChangedFcn(FE.title, []);
    H = app.FigureHistory;
    check(numel(H.Undo) == 2 && string(app.UndoMenu.Text) == "Undo Title" && H.Undo(end).After(1).title == "Undo me twice" ...
        && H.Undo(end).Before(1).title == "", ...
        'two edits of the Title field within a second are one step, named after its row: Undo Title');
    desc0 = app.ConfigDescField.Value;
    app.ConfigDescField.Value = 'kept by undo';
    app.ConfigDescField.ValueChangedFcn(app.ConfigDescField, []);
    check(numel(app.FigureHistory.Undo) == 2, 'an edit outside the figures (the description) is no step');
    np0 = numel(app.Config.Figures(1).panels);
    app.onPanelSelected(np0);
    app.onRemovePanel();
    check(numel(app.Config.Figures(1).panels) == np0 - 1 && string(app.UndoMenu.Text) == "Undo Remove panel", ...
        'Remove panel: Undo Remove panel');
    app.onUndoRedo("undo");
    check(numel(app.Config.Figures(1).panels) == np0 && app.SelectedPanel == np0 && string(app.RedoMenu.Text) == "Redo Remove panel" ...
        && app.RedoMenu.Enable == "on" && string(app.UndoMenu.Text) == "Undo Title" && contains(app.StatusBar.Text, "Undid ""Remove panel""") ...
        && string(app.FigureEditor.title.Value) == "Undo me twice", ...
        'Undo: the panel is back and selected, Redo Remove panel offered, Undo names the step before; the editor shows the figure');
    app.onKeyPress(pressed('z', {'shift' 'control'}));
    check(numel(app.Config.Figures(1).panels) == np0 - 1 && string(app.UndoMenu.Text) == "Undo Remove panel" && app.RedoMenu.Enable == "off", ...
        'Ctrl+Shift+Z redoes it');
    app.onUndoRedo("undo");
    app.onUndoRedo("undo");
    check(app.Config.Figures(1).title == "" && string(app.FigureEditor.title.Value) == "" && string(app.UndoMenu.Text) == "Undo Add figure" ...
        && string(app.RedoMenu.Text) == "Redo Title" && string(app.ConfigDescField.Value) == "kept by undo" ...
        && app.Config.Description == "kept by undo", ...
        'Undo Title: the field and the config go back; the description edited since stays as it is');
    app.setFiguresEnabled(1, "off");
    check(~app.Config.Figures(1).enabled && string(app.UndoMenu.Text) == "Undo Disable figure" && isempty(app.FigureHistory.Redo) ...
        && app.RedoMenu.Enable == "off", 'a new edit (a figure disabled in the tree) drops what was undone: Redo grayed');
    app.onUndoRedo("undo");
    app.onUndoRedo("undo");
    check(isempty(app.Config.Figures) && app.SelectedFigure == 0 && app.UndoMenu.Enable == "off" && string(app.RedoMenu.Text) == "Redo Add figure", ...
        'Undo Add figure: no figure left, nothing more to undo');
    app.onUndoRedo("undo");
    check(contains(app.StatusBar.Text, "Nothing to undo"), 'Undo with nothing to undo says so');
    app.ConfigDescField.Value = desc0;
    app.ConfigDescField.ValueChangedFcn(app.ConfigDescField, []);
    check(clean(), 'the figures undone back to the saved ones (and the description typed back): the title shows the config saved');
    app.onUndoRedo("redo");
    check(numel(app.Config.Figures) == 1 && app.SelectedFigure == 1 && ~clean(), 'Redo Add figure: the figure is back, selected');
    app.applyConfig(app.Config, MarkSaved=true);   % as opening or making a config does
    check(isempty(app.FigureHistory.Undo) && isempty(app.FigureHistory.Redo) && app.UndoMenu.Enable == "off" && app.RedoMenu.Enable == "off", ...
        'another config (applied as saved): the history is cleared');
    if ismac; modifier = "Cmd+"; else; modifier = "Ctrl+"; end
    check(app.ToolbarUndoTool.Enable == "off" && app.ToolbarRedoTool.Enable == "off" ...
        && app.ToolbarUndoTool.Tooltip == "Undo (" + modifier + "Z)" && app.ToolbarRedoTool.Tooltip == "Redo (" + modifier + "Y)", ...
        'the toolbar''s Undo and Redo are off with the menu items (an empty history); their tooltips name the shortcuts');
    nf0 = numel(app.Config.Figures);
    app.onAddFigure("rasterPsth");
    check(app.ToolbarUndoTool.Enable == "on" && app.ToolbarRedoTool.Enable == "off" ...
        && app.ToolbarUndoTool.Tooltip == "Undo Add figure (" + modifier + "Z)", 'the Undo tool is on and names the step: Undo Add figure (Ctrl+Z)');
    app.selectTab(app.TabData);
    check(app.ToolbarUndoTool.Enable == "off" && app.ToolbarUndoTool.Enable == app.UndoMenu.Enable, 'off the Figures tab the tool is off, as the menu item');
    app.selectTab(app.TabFigures);
    app.ToolbarUndoTool.ClickedCallback(app.ToolbarUndoTool, []);
    check(numel(app.Config.Figures) == nf0 && app.ToolbarUndoTool.Enable == "off" && app.ToolbarRedoTool.Enable == "on" ...
        && app.ToolbarRedoTool.Tooltip == "Redo Add figure (" + modifier + "Y)", 'the Undo tool takes the figure back; the Redo tool is on, naming it');
    app.ToolbarRedoTool.ClickedCallback(app.ToolbarRedoTool, []);
    check(numel(app.Config.Figures) == nf0 + 1 && app.ToolbarRedoTool.Enable == "off" && app.ToolbarRedoTool.Tooltip == "Redo (" + modifier + "Y)", ...
        'the Redo tool does it again');
    nameCheck = @(want, why) check(string(app.UndoMenu.Text) == "Undo " + want, why);
    app.onAddFigureOverlay("line");
    nameCheck("Add overlay", 'an overlay added from the editor: Undo Add overlay (not Undo Edit)');
    app.onRemoveFigureOverlay();
    nameCheck("Remove overlay", 'an overlay removed: Undo Remove overlay');
    app.onPickFigureDatasets(Keys=["a" "b"]);
    nameCheck("Pick datasets", 'datasets picked for a session figure: Undo Pick datasets');
    cfgL = app.Config;
    cfgL.Figures(app.SelectedFigure).panels(1).window = cfgL.Defaults.Window;   % a panel with a window of its own
    app.applyConfig(cfgL);
    app.FigureEditor.alignRelinkAll.ButtonPushedFcn(app.FigureEditor.alignRelinkAll, []);
    nameCheck("Re-link all panels", 'Re-link all panels: Undo Re-link all panels');
    app.FigureEditor.title.Value = 'named by its caller';
    app.onConfigChanged("figure", "Event sequence");   % as the sequence dialog's OK
    nameCheck("Event sequence", 'a caller naming the step (the event-sequence dialog''s OK): Undo Event sequence, not Undo Edit');
    app.applyConfig(app.Config, MarkSaved=true);
    Hx = FigureEditHistory();
    Hx.Depth = 3;
    a = struct('v', 0);
    for v = 1:5
        b = struct('v', v);
        Hx = Hx.record(a, b, "step " + v);
        a = b;
    end
    Hy = Hx.record(a, a, "no change");
    Hz = FigureEditHistory().record(struct('v', 0), struct('v', 1), "typed", Key=1);
    Hz = Hz.record(struct('v', 1), struct('v', 0), "typed", Key=1);
    check(numel(Hx.Undo) == 3 && Hx.undoLabel() == "step 5" && Hx.Undo(1).Label == "step 3" && numel(Hy.Undo) == 3 && isempty(Hz.Undo), ...
        'FigureEditHistory: past Depth the oldest steps go; no step without a change; a burst typed back to where it started is none');
    noFigures();
    app.onSaveConfig();
    clear restoreAuto5k
    app.Tabs.SelectedTab = app.TabData;
end

if S.sec("6", "close")
    savedConfig();
    app.savePreferences();
    shutNow = [string.empty(1, 0) app.FigureSections(~[app.FigureSections.Expanded]).Name];
    superShut = [string.empty(1, 0) app.FigureSupers(~[app.FigureSupers.Expanded]).Name];
    check(strcmp(AppPrefs.getpref(g, 'LastConfigFile'), cfgFile) ...
        && isequal(sort(string(AppPrefs.getpref(g, 'FigureSectionsCollapsed'))), sort(shutNow)) ...
        && AppPrefs.ispref(g, 'FigureSupersectionsCollapsed') && isempty(setxor(string(AppPrefs.getpref(g, 'FigureSupersectionsCollapsed')), superShut)) ...
        && ~any(arrayfun(@(n) AppPrefs.ispref(g, n), ["AutoPreview" "PlotGroupBy" "PlotGroupsCollapsed" "PlotSectionsCollapsed" ...
        "SessionAutoPreview" "SessionSectionsCollapsed"])), ...
        'the last config and the figure editor''s collapsed sections and supersections are remembered; no plot or session preference is written');
    app.onShowEpochs();
    dz = app.EpochDiagramWindow;
    app.onClose();
    check(~isvalid(app.Fig) && ~dz.isOpen(), 'Close (clean config) closes the window, and the epoch diagram with it');
end

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


function newPanelAnswer(D)
%newPanelAnswer  In the New panel window: note its tiles, their pictures, the place and the parameters; pick Continuous signal, name and title it, stacked rows, OK (appdata newPanelSeen).
types = string(fieldnames(D.Types)).';
icons = arrayfun(@(t) (ischar(D.Types.(t).Icon) || isstring(D.Types.(t).Icon)) && isfile(string(D.Types.(t).Icon)), types);
failed = strings(1, 0);
for t = types   % every type's key parameters build
    try
        D.Pick(t);
        if ~(D.Types.(t).Value && isstruct(D.Params())); failed(end+1) = t; end %#ok<AGROW>
    catch ME
        failed(end+1) = t + " (" + ME.message + ")"; %#ok<AGROW>
    end
end
D.Pick("continuous");
P = D.Params();
seen = struct('types', types, 'icons', icons, 'where', string(D.Where.Enable), 'params', string(fieldnames(P)).', ...
    'name0', string(D.Name.Value), 'binding', string(P.Binding.Enable), 'failed', failed);
D.Name.Value = 'lfp_a';
D.Name.ValueChangedFcn(D.Name, []);
D.Title.Value = 'Its LFP';
P.Display.Value = "stacked";
setappdata(groot, 'newPanelSeen', seen);
press(D, "Ok");
end


function copyFigureDialog(D)
%copyFigureDialog  In the Copy figure settings window: None, tick Alignment and Arrangement, note the count, Copy.
press(D, "None");
for b = [D.Boxes.alignment D.Boxes.arrangement]
    b.Value = true;
    b.ValueChangedFcn(b, []);
end
lab = findall(ancestor(D.All, 'figure'), 'Type', 'uilabel');
seen = struct('count', string(lab(contains(string({lab.Text}), "part(s) to copy")).Text), ...
    'from', string(D.From.Items{D.From.ItemsData == D.From.Value}));
setappdata(groot, 'copyFigureSeen', seen);
press(D, "Ok");
end


function n = figureNode(tree, k)
%figureNode  The figure tree's node of figure K (a leaf: its NodeData is K).
n = findall(tree, 'Type', 'uitreenode');
n = n(arrayfun(@(x) isequal(x.NodeData, k), n));
end


function setGroupBy(app, by)
%setGroupBy  Pick BY in the figure tree's Group by drop-down, as a user would (its ValueChangedFcn).
dd = app.FigureGroupDropDown;
dd.Value = by;
dd.ValueChangedFcn(dd, []);
end


function cancelGenerate(tm, app)
%cancelGenerate  Once a Generate's run has started (the runner's Results emptied), note what the app shows, ask for a preview, press Cancel (appdata genProbe).
if ~app.Running || isempty(app.Runner) || height(app.Runner.Results) > 0; return; end
stop(tm);
app.refreshFigurePreview(Force=true);
setappdata(groot, 'genProbe', struct('generate', string(app.FigureGenerateButton.Enable), 'run', string(app.RunButton.Enable), ...
    'cancel', string(app.CancelButton.Enable), 'preview', string(app.FigurePreviewLabel.Text), 'state', app.FigurePreviewState));
app.CancelButton.ButtonPushedFcn(app.CancelButton, []);   % the Export tab's Cancel, as a click
end


function resetAutoLimit(app)
%resetAutoLimit  The figure preview's auto limit back to AutoPreviewSeconds (5d-5f raise it), while the app lives.
if isvalid(app); app.FigureAutoPreviewSeconds = app.AutoPreviewSeconds; end
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


function [F, fig] = runPreviewCode(file) %#ok<STOUT> the script sets them
%runPreviewCode  Run a script of Export code (EphysAnalysisScript.preview) in a workspace of its own: its figure result and window.
run(file);
end


function tf = sameResult(a, b)
%sameResult  Two figure results hold the same data: equal but for when each was made (created) and the shape of an empty value.
if isstruct(a) && isstruct(b)
    tf = isequal(size(a), size(b)) && isempty(setxor(fieldnames(a), fieldnames(b)));
    if ~tf; return; end
    for k = 1:numel(a)
        for f = setdiff(string(fieldnames(a)), "created").'
            tf = tf && sameResult(a(k).(f), b(k).(f));
        end
    end
elseif iscell(a) && iscell(b)
    tf = isequal(size(a), size(b)) && all(cellfun(@sameResult, a(:), b(:)));
elseif isempty(a) && isempty(b)
    tf = true;
else
    tf = isequaln(a, b);
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


function [b, n] = markBox(P)
%markBox  The preview's outline of the selected panel (markFigurePanel): the box its visible strips make, [x0 y0 x1 y1] px, and how many there are.
M = findall(P, 'Tag', 'previewPanelMark');
M = M(strcmp(get(M, 'Visible'), 'on'));
n = numel(M);
b = [NaN NaN NaN NaN];
if n == 0; return; end
p = reshape([M.Position], 4, []).';
b = [min(p(:, 1)) min(p(:, 2)) max(p(:, 1) + p(:, 3)) max(p(:, 2) + p(:, 4))];
end


function ax = findPanelAxes(P, id)
%findPanelAxes  The preview's (first) axes of panel ID.
ax = findall(P, 'Type', 'axes');
ax = ax(arrayfun(@(a) isappdata(a, 'FigurePanel') && string(getappdata(a, 'FigurePanel')) == id, ax));
ax = ax(1);
end


function e = expectBox(P, id)
%expectBox  Where the outline of panel ID belongs: its axes and their labels (TightInset), 7 px out, inside the preview.
ax = findPanelAxes(P, id);
p = ax.Position;
t = ax.TightInset;
sz = P.InnerPosition(3:4);
e = [max([p(1) - t(1), p(2) - t(2)] - 7, 1), min([p(1) + p(3) + t(3), p(2) + p(4) + t(4)] + 7, sz)];
end


function tf = boxNear(a, b)
tf = all(isfinite(a)) && max(abs(a - b)) < 1.5;
end


function T = dragPanel(app, q, from, to)
%dragPanel  Drag panel Q of the figure tree's figure in the schematic from FROM to TO ([x y], its units): press, one motion, release.
%   T: the drop target the motion found.
app.Fig.CurrentPoint = [400 300];
app.onSchematicPress(q, struct('IntersectionPoint', [from 0]));
app.Fig.CurrentPoint = app.schematicPixel(to);
app.Fig.WindowButtonMotionFcn(app.Fig, []);
T = app.FigureDrag.target;
app.Fig.WindowButtonUpFcn(app.Fig, []);
end
