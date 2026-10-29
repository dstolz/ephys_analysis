function test_EphysAnalysisApp(opts)
%test_EphysAnalysisApp  Headless checks of the analysis GUI over a synthetic project.
%   Builds the app on a small synthetic project run through the pipeline
%   and drives it through its own methods: the startup (built hidden behind
%   the splash, Splash=true and the -batch default without it; the tabs but
%   Data, and the Alignment tab's epoch count, waiting to be shown); opening on
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
%   Remove); Copy settings... between figures and into a design; File > Generate selected figure (a figure's files per observation on the ticked
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
%   config; FigureEditHistory's depth); Apply to figures (an edit made with
%   Ctrl held offered to the other figures' panels that take it, the
%   window's rows, All, the ticks remembered, nothing drawn again unless
%   Replot, Edit > Apply last change, Ctrl+Shift+A, Cancel, Undo, an edit
%   that stays with its figure opening none); the first-spike marks' and
%   latency box's windows (a raster's First spike row and a PSTH's Latency
%   box row, each button opening its modal window on the look, its note
%   naming the figure's rule, OK as one named undo step, the row's summary,
%   Cancel, the preview drawing the marks and the boxes); the figure's
%   First-spike latency section (5u: shown with a raster, PSTH or heat map,
%   its note naming the panels that read it, the rows of each method, a
%   method and a window as named steps, the baseline window's fields with
%   Window, a PSTH's Onset line, the preview computing the latencies once
%   for both panels and drawing the onsets, an edit of the block computing
%   no panel again, Copy settings listing the block, a figure without such
%   a panel hiding the section);
%   each figure's own preview container (a switch back shows its drawing
%   again, the same axes, without drawing it; the tree selecting the
%   figure shown and marking it bold, a preview out of date after an edit
%   of its figure only, after another dataset every one, current again
%   when the dataset comes back; the editor's sections and panel as each
%   figure left them; the observation list each figure kept (shown back
%   with its pick and not listed again, the others' forgotten by a star,
%   listed again after an edit of its filter); Remove freeing the
%   container; the cap dropping the least recently shown; Redraw All
%   drawing the enabled figures out of date up to the cap, Ctrl+R finding
%   them current, the toolbar's Cancel stopping it; Undo / Redo of an Add
%   keeping the tree, the
%   containers and the selection together);
%   a figure's Size (the editable drop-down and its suggestions, an own
%   size in px, in or cm, Lock ratio, Fit preview, a text no size refused;
%   the preview the shape of the page and drawn again without computing,
%   the export page that size, the Export tab's size followed, Undo) and a
%   Ctrl+Click on a drawn panel selecting it in the editor (no edit);
%   remembered panel options (a
%   new panel, from a script with Remembered or from the New panel window,
%   starting from the options last set on a panel of its type, an existing
%   panel left alone, a trial parameter the dataset lacks and a value of
%   the wrong class not pre-filled, Edit > Reset panel options to defaults
%   as one undo step forgetting its type's, the preference written, Forget)
%   and the color fields' swatches (one beside every color field, the
%   chooser in the tests' place: a color picked as one named step, Cancel,
%   a color typed and Undo followed by the swatch, the search going to the
%   field; the First-spike marks window's);
%   figure templates and Apply last change (the row above the preview: its
%   controls, off with no template; Save as... from a script and from its
%   window; Apply... in its window onto two figures, one undo step, each
%   keeping its title and enabled, the other figures untouched; Undo; as a
%   new figure; one part only; Update keeping the description and leaving
%   the figures applied as they were; Export, Remove, Import; the template
%   issue window's title and report; the Apply last change button on and
%   tooltipped as the Edit menu's item, naming the step, opening Apply to
%   figures); an edit of text alone (an x
%   and a y label, a panel title of its own) set on the drawn preview
%   (nothing computed or drawn again, the texts and places a whole
%   drawing's; a first title and a side drawn again);
%   a figure on the probe (5v: the Probe layout section's rows wired to
%   the config both ways, Physical enabling its rows, Across sessions
%   and On the probe excluding each other, Undo Probe layout, the
%   picker's one entry and count line, the preview's tiles and status
%   line, the tree's On the probe group, Generate writing one page);
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
    "5d.probemap" "5d.add"; "5d.eventtrace" "5d.add"; "5d.psth" "5d.remove"; "5d.scan" "5d.add"; "5d.saveprefs" "5d.remove"];
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

applyRows = [];    % the Apply to figures window's rows as it opened (answerApply)
applyCount = "";   % its count after All
applyFilter = [];  % what its filters did (answerApply): [rows shown for "continuous", ticks kept after None on those, rows shown for "has it", rows back]
    function answerApply(D, want, replot, accept)
        %answerApply  Answer Apply to figures: its rows noted (applyRows), All pressed (applyCount), WANT ticked, Replot REPLOT, then Apply (ACCEPT) or Cancel.
        applyRows = D.Table.Data;
        if height(applyRows) == 2 && isempty(applyFilter)
            D.Text.Value = 'continuous';
            D.Text.ValueChangedFcn(D.Text, []);
            shown1 = height(D.Table.Data);
            press(D, "None");
            D.Text.Value = '';
            D.Text.ValueChangedFcn(D.Text, []);
            kept = nnz(D.Table.Data.Apply);   % the hidden row kept its tick, the one None cleared did not
            D.Show.Value = 'has';
            D.Show.ValueChangedFcn(D.Show, []);
            shown2 = height(D.Table.Data);
            D.Show.Value = 'all';
            D.Show.ValueChangedFcn(D.Show, []);
            applyFilter = [shown1 kept shown2 height(D.Table.Data)];
        end
        press(D, "All");
        applyCount = string(D.Count.Text);
        D.Table.Data.Apply = reshape(logical(want), [], 1);
        D.Replot.Value = replot;
        if accept; press(D, "Ok"); else; press(D, "Cancel"); end
    end

templateRows = [];   % the Apply figure template window's figures as it opened (answerTemplate)
    function answerTemplate(D, want, parts, asNew)
        %answerTemplate  Answer Apply figure template: its rows noted (templateRows), WANT ticked, the PARTS ticked, New ASNEW, Apply.
        templateRows = D.Table.Data;
        D.Table.Data.Apply = reshape(logical(want), [], 1);
        for tplPart = string(fieldnames(D.Parts)).'
            D.Parts.(tplPart).Value = ismember(tplPart, parts);
        end
        D.New.Value = asNew;
        press(D, "Ok");
    end

if S.sec("1", "build, open the project, scan")
    check(app.Fig.Visible == "on" && ~app.Splash.isActive() && app.Splash.Window == "" && isempty(findall(groot, 'Tag', 'AppSplash')) ...
        && isequal(app.Splash.History.Step.', ["window" "Data" "Alignment" "Figures" "Export" "Log" "finish" "prefs" "scan" "dataset" "show"]), ...
        'under -batch the app starts without the splash window: built hidden, each tab, the scan and the first dataset a step, then shown');
    hiddenIn = @(t) all(string({t.Children.Visible}) == "off");
    check(~hiddenIn(app.TabData) && hiddenIn(app.TabAlign) && hiddenIn(app.TabFigures) && hiddenIn(app.TabExport) ...
        && hiddenIn(app.TabLog) && startsWith(app.AlignSummaryLabel.Text, "Scan and pick"), ...
        'the window shows with the Data tab''s contents alone; the other tabs'' wait, and so does the Alignment tab''s epoch count');
    app.selectTab(app.TabAlign);
    alignShown = ~hiddenIn(app.TabAlign) && ~startsWith(app.AlignSummaryLabel.Text, "Scan and pick");
    app.selectTab(app.TabFigures);
    check(alignShown && ~hiddenIn(app.TabFigures) && hiddenIn(app.TabExport), ...
        'a tab''s contents show when it is first shown (revealTab), the Alignment tab''s epoch count drawn then');
    app.selectTab(app.TabData);
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
    check(ismember("Tags", string(T.Properties.VariableNames)) && isstring(T.Tags) && numel(app.DatasetsTable.ColumnName) == width(T) ...
        && app.DatasetsTable.ColumnName{find(string(T.Properties.VariableNames) == "Tags")} == "Tags", 'the datasets table has a read-only Tags column after Key');
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
    % the filter above the table: Subject and Tags (any / all of) hide rows, a hidden row keeps its tick,
    % Tick shown only and Untick all set the ticks from what shows
    fk = {char(app.Runner.Keys(kF1)), char(app.Runner.Keys(kF2))};
    app.Runner.source(kF1); app.Runner.source(kF2);   % both loaded: the table's tags are their sources'
    tags0 = {setSourceTags(app, fk{1}, {'pilot'}), setSourceTags(app, fk{2}, {'draft', 'pilot'})};
    app.refreshDatasetsTable();
    T0 = app.DatasetsTable.Data;
    subjOf = @(kk) T0.Subject(T0.Idx == kk);
    s1 = subjOf(kF1);
    check(isequal(app.SubjectFilterDropDown.Items, [{'(any)'}, cellstr(unique(T0.Subject)).']) ...
        && isequal(app.TagFilterDropDown.Items, {'(any)', 'draft', 'pilot'}) && app.FilterLabel.Text == "", ...
        'the Subject and Tags filters list the subjects and tags in use; no filter on, no count');
    filterBy(app, s1, '(any)', 'any');
    T3 = app.DatasetsTable.Data;
    nS1 = nnz(T0.Subject == s1);
    filterBy(app, lower(s1) + ", nosuch", '(any)', 'any');
    T4 = app.DatasetsTable.Data;
    filterBy(app, "nosuch*", '(any)', 'any');
    check(all(T3.Subject == s1) && height(T3) == nS1 && any(T3.Idx == kF1) && height(T4) == nS1 ...
        && height(app.DatasetsTable.Data) == 0 && app.FilterLabel.Text == "showing 0 of 2 (2 ticked hidden)" && all(app.Ticked), ...
        'Subject keeps the datasets of the subjects picked or typed (several, case ignored, * wildcards); hidden rows keep their ticks, counted');
    filterBy(app, '(any)', 'draft', 'any');
    T5 = app.DatasetsTable.Data;
    filterBy(app, '(any)', 'draft, pilot', 'any');
    T6 = app.DatasetsTable.Data;
    filterBy(app, '(any)', 'draft, pilot', 'all');
    T7 = app.DatasetsTable.Data;
    filterBy(app, '(any)', 'Bad Tag!', 'any');
    check(isequal(T5.Idx, kF2) && height(T6) == 2 && isequal(T7.Idx, kF2) && height(app.DatasetsTable.Data) == 0, ...
        'Tags keeps the datasets holding any of the tags, or all of them; a term that is no tag matches nothing');
    filterBy(app, s1, 'draft', 'any');
    check(isequal(reshape(app.DatasetsTable.Data.Idx, 1, []), reshape(kF2(subjOf(kF2) == s1), 1, [])), ...
        'Subject and Tags together keep the datasets that pass both');
    % the DatasetBrowser's other selections: "not" subjects, "not" tags, Search over name, key, subject and tags
    filterBy(app, '(any)', '(any)', 'any', NotSubject=s1);
    U1 = app.DatasetsTable.Data;
    filterBy(app, '(any)', '(any)', 'any', NotTags='draft');
    U2 = app.DatasetsTable.Data;
    filterBy(app, '(any)', 'pilot', 'any', NotTags='draft, nosuch');
    U3 = app.DatasetsTable.Data;
    filterBy(app, s1, '(any)', 'any', NotSubject=s1);
    nNone = height(app.DatasetsTable.Data);
    check(isequal(sort(U1.Idx), sort(T0.Idx(T0.Subject ~= s1))) && isequal(U2.Idx, kF1) && isequal(U3.Idx, kF1) && nNone == 0, ...
        '"not" subject and "not" tags drop the datasets of those subjects or holding any of those tags; a "not" cancels the same pick');
    filterBy(app, '(any)', '(any)', 'any', Search=lower(s1) + " " + T0.Name(T0.Idx == kF1));
    V1 = app.DatasetsTable.Data;
    filterBy(app, '(any)', '(any)', 'any', Search='DRAFT');
    V2 = app.DatasetsTable.Data;
    filterBy(app, '(any)', 'pilot', 'any', Search='draft');
    V3 = app.DatasetsTable.Data;
    filterBy(app, '(any)', '(any)', 'any', Search='nosuchword');
    check(isequal(V1.Idx, kF1) && isequal(V2.Idx, kF2) && isequal(V3.Idx, kF2) && height(app.DatasetsTable.Data) == 0 ...
        && contains(app.FilterLabel.Text, "showing 0 of 2"), ...
        'Search keeps the datasets whose name, key, subject and tags hold every word (case ignored), together with the other filters');
    check(isequal(app.NotSubjectFilterDropDown.Items, app.SubjectFilterDropDown.Items) ...
        && isequal(app.NotTagFilterDropDown.Items, app.TagFilterDropDown.Items), ...
        'the "not" lists hold the same subjects and tags in use');
    filterBy(app, '(any)', 'draft', 'any');
    Tt = app.DatasetsTable.Data;
    Tt.Run(:) = false;
    app.DatasetsTable.Data = Tt;
    app.onDatasetsTableEdited([]);
    check(app.Ticked(kF1) && ~app.Ticked(kF2), 'a tick cleared on the row shown leaves the hidden dataset''s alone');
    app.onTickDatasets("shown");
    check(~app.Ticked(kF1) && app.Ticked(kF2) && app.Config.Source.Selection == "list" ...
        && isequal(app.Config.Source.Datasets, app.Runner.Keys(kF2)) && app.FilterLabel.Text == "showing 1 of 2", ...
        'Tick shown only ticks the rows shown and clears the hidden ones; the config''s selection follows');
    app.onTickDatasets("none");
    noneTicked = ~any(app.Ticked);
    filterBy(app, '(any)', '(any)', 'any');
    app.onTickDatasets("shown");
    check(noneTicked && all(app.Ticked) && height(app.DatasetsTable.Data) == 2 && app.FilterLabel.Text == "" ...
        && app.Config.Source.Selection == "all", 'Untick all clears every tick; with no filter on, Tick shown only ticks every dataset');
    setSourceTags(app, fk{1}, tags0{1}); setSourceTags(app, fk{2}, tags0{2});
    app.refreshDatasetsTable();
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
    keyed = keyed(keyed ~= app.GenerateFigureMenu);   % Generate selected figure (Ctrl+G) is a Figures tab command: the menu's alone
    named = erase(string({keyed.Text}), "...") + " (" + modifier + string({keyed.Accelerator}) + ")";
    check(numel(keyed) == 3 && all(ismember(named, tips)) && nnz(contains(tips, "(" + modifier)) == numel(keyed) + 2 ...
        && all(strlength(tips) > 0) && app.GenerateFigureMenu.Accelerator == "G", ...
        'every File menu shortcut but Generate selected figure''s is on the toolbar, named in its tool''s tooltip, and no tooltip names another but Undo and Redo''s');
    check(app.ToolbarValidateTool.Enable == "on" && app.ToolbarPlanTool.Enable == "on" && app.ToolbarRunTool.Enable == "on" ...
        && app.ToolbarCancelTool.Enable == "off" && app.ToolbarReportTool.Enable == "off" && app.ToolbarFolderTool.Enable == "off", ...
        'before a run: Validate, Plan and Run are on; Cancel, the report and the figure folder off');
end

if S.sec("1c", "Help menu: GitHub issue and feature request")
    items = flip(string({app.HelpMenu.Children.Text}));
    check(isequal(items(end-4:end), ["Report an issue on GitHub..." "Request a feature on GitHub..." "Report a figure template issue..." ...
        "Request a figure template feature..." "About EphysAnalysisApp"]), ...
        'the Help menu ends with the two GitHub issue items, the two about figure templates and About');
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
        && app.FigurePreviewHost.Parent == pgrid && app.FigurePreviewPanel.Parent == app.FigurePreviewHost ...
        && app.FigureTemplateDropDown.Parent.Parent == pgrid && app.FigureTemplateDropDown.Parent.Layout.Row == app.FigureFavorites.Grid.Layout.Row + 1 ...
        && app.FigurePreviewHost.Layout.Row == app.FigureFavorites.Grid.Layout.Row + 2, ...
        'the Design list sits right of Dataset and Save look as design... right of Observation, in their rows, each drop-down with its star and note button; Favorites under them, the template row under that, the preview (the figures'' containers) under it');
    % the buttons in a column of their own left of those rows: Preview, Redraw All, Export preview, Auto, < > (a row each)
    bgrid = app.FigurePreviewButton.Parent;
    btnCol = [app.FigurePreviewButton app.FigureRedrawAllButton app.FigureExportPreviewColumnButton app.FigureAutoCheckBox app.FigureObsPrevButton.Parent];
    check(bgrid.Parent == pgrid && isequal(bgrid.Layout.Column, 1) && isequal(bgrid.Layout.Row, [dsg.Layout.Row app.FigureFavorites.Grid.Layout.Row]) ...
        && all(arrayfun(@(h) h.Parent == bgrid, btnCol)) && isequal(arrayfun(@(h) h.Layout.Row, btnCol), 1:5) ...
        && app.FigureObsNextButton.Parent == app.FigureObsPrevButton.Parent ...
        && all(arrayfun(@(h) min(h.Layout.Column) > 1, [dsg osg app.FigureFavorites.Grid])), ...
        'the buttons stand in a column at the left, a row each (Preview, Redraw All, Export preview, Auto, < >), beside the Dataset, Observation and Favorites rows');
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
    btnKeys = {app.FigurePreviewButton "+P"; app.FigureRedrawAllButton "+R"; app.FigureExportPreviewColumnButton "+K"; app.FigureAutoCheckBox "+T"; app.FigureCodeButton "+E"; ...
        app.FigureExportPreviewButton "+K"; app.TestReportButton "+U"; ...
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
    [Fc, hc, Dc] = runPreviewCode(codeFile);
    closeCode = onCleanup(@() delete(hc(isgraphics(hc))));
    check(isfile(codeFile) && contains(app.StatusBar.Text, codeFile) && contains(code, "src = loadAnalysisSource(outs, Key=key);") ...
        && contains(code, "F = figureCompute(src, spec, Observation=obs);") && contains(code, "Design=""Default""") ...
        && sameResult(Fc, app.FigurePreviewResult) && numel(findall(hc, 'Type', 'axes')) == numel(findall(app.FigurePreviewPanel, 'Type', 'axes')), ...
        'Export code writes the preview''s code: run, it computes the observation picked as the preview did and draws it in a window of its own');
    % ... and the data before it: every event and spike train, each cut into the preview's epochs
    srcD = app.Runner.source(app.ActiveIdx);
    okData = all(isfield(Dc, ["events" "lineNames" "trials" "spikes" "units" "E" "G" "spikesIn" "onsets" "offsets"]));
    if okData
        nE = height(Dc.E);
        Mo = epochEvents(srcD, Dc.E, Lines=Dc.lineNames(1), Edge="onset");
        okData = isequal(Dc.lineNames, string(fieldnames(srcD.events)).') && isequaln(Dc.trials, srcD.trials) ...
            && isequal(size(Dc.spikesIn), [nE numel(Dc.spikes)]) && height(Dc.units) == numel(Dc.spikes) ...
            && isequal(Dc.spikesIn, epochSpikes(Dc.spikes, Dc.E)) && isequal(vertcat(Dc.onsets.(Dc.lineNames(1)){:}), Mo.t) ...
            && isequal(fieldnames(Dc.offsets), fieldnames(Dc.onsets)) && numel(Dc.offsets.(Dc.lineNames(1))) == nE ...
            && (~istable(Fc.epochs) || isequaln(Fc.epochs.t0, Dc.E.t0(ismember(Dc.E.group, Fc.epochs.group))));
        if Fc.observation.kind == "unit"
            u = find(Dc.units.unitId == Fc.observation.unitId);
            okData = okData && isscalar(u) && Dc.units.observed(u) && nnz(Dc.units.observed) <= height(Dc.units);
        end
    end
    check(okData && contains(code, "[E, G] = figureEpochs(src, spec);") && contains(code, "spikesIn = epochSpikes(spikes, E);"), ...
        'Export code loads the data first: every event line and spike train, the trials, the preview''s epochs (figureEpochs) and each unit''s spikes and each line''s events in them');
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
        && string(app.AddFigureButton.Text) == "Add" ...
        && app.FigureSections([app.FigureSections.Name] == "arrangement").Title == "Panels" ...
        && app.FigureSections([app.FigureSections.Name] == "panel").Title == "Selected panel", ...
        'the Figures tab: no figure yet, only a hint in the editor, no preview, an Add button; the Panels and Selected panel sections; Help goes to its section');
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
    check(string(FE.panelType.Value) == "continuous" && shown(FE.stack) && shown(FE.errorType) && shown(FE.layerFollows) ...
        && isequal(string(FE.stack.ItemsData), ["off" "groups" "items"]) ...
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
    Xs = app.FigureSearchIndex;
    iStack = find(arrayfun(@(e) ~isempty(e.Keys) && e.Keys(1) == "stack", Xs), 1);
    wentStack = app.gotoFigureRow(iStack, Focus=false);
    check(shown(FE.rasterSort) && shown(FE.waveMode) && ~shown(FE.stack) && ~shown(FE.binMs) && FE.panelSame.Enable == "on" ...
        && ~wentStack && contains(app.StatusBar.Text, "lists its groups in blocks"), ...
        'a raster shows its own rows instead (no Stack row: a raster lists its groups in blocks already, the reason says)');
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
        && app.FigurePreviewState == "drawn" && ~isempty(spans) && all(arrayfun(@(m) PlotAesthetics.getValue(m, "LineWidth"), spans) == 3) ...
        && all(string({spans.LineStyle}) == "--"), ...   % (the width as exported: the preview draws it at its scale)
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
    app.Fig.Position(3:4) = app.Fig.Position(3:4) + [160 120];   % (the preview is the shape of its page: it grows with whichever side limits it)
    drawnow;
    app.fitFigureViews();   % (the preview host's SizeChangedFcn: MATLAB runs it for a visible figure only)
    P.SizeChangedFcn(P, []);   % (MATLAB runs it for a visible figure only)
    [bm, nm] = markBox(P);
    check(nm == 4 && ~isequal(findPanelAxes(P, "psth_1").Position, pos0) && boxNear(bm, expectBox(P, "psth_1")), ...
        'the preview made larger, the figure is laid out again and the outline follows psth_1''s axes');
    app.Fig.Position(3:4) = app.Fig.Position(3:4) - [160 120];
    drawnow;
    app.fitFigureViews();
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
    check(canceled && app.FigurePreviewState == "drawn" && numel(figAxes()) == 3, sprintf(['an edit does not redraw a canceled preview; ' ...
        'Preview does (canceled after the edit: %d; then %s, %d axes)'], canceled, app.FigurePreviewState, numel(figAxes())));
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
    Xs = app.FigureSearchIndex;
    iWave = find(arrayfun(@(e) ~isempty(e.Keys) && e.Keys(1) == "waveMode", Xs), 1);
    wentWave = app.gotoFigureRow(iWave, Focus=false);
    check(app.FigureSections([app.FigureSections.Name] == "waveform").Visible && shown(FE.waveNote) && ~shown(FE.waveMode) ...
        && contains(FE.waveNote.Text, "no waveform inset") && ~wentWave && contains(app.StatusBar.Text, "no waveform inset"), ...
        'a heat map of spikes shows the Waveform section with a note on why it draws no inset (the search says so too), no rows');
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
    arrayfun(@PlotAesthetics.fillMenu, findall(app.Fig, 'Type', 'uicontextmenu', 'Tag', PlotAesthetics.MenuTag));   % (made when each opens)
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
        && seen.name0 == "continuous_1" && all(ismember(["Source" "Binding" "Stack" "ErrorType"], seen.params)) && seen.binding == "on" ...
        && isscalar(f2.panels) && f2.panels.id == "lfp_a" && f2.panels.title == "Its LFP" && f2.panels.type == "continuous" ...
        && f2.panels.options.stack == "items" && f2.panels.layers.source == "LFP" && f2.panels.layers.binding == "observation" ...
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

if S.sec("5d.probemap", "a probe map's rows: Unit labels, the Waveform section (Off = circles, its glyphs' rows, the band with a mean), round trip")
    app.FigureAutoCheckBox.Value = false;   % no redraw per edit (as 5d.add leaves it)
    app.onAddFigure("probemap");
    check(shown(FE.unitLabels) && ~FE.unitLabels.Value && shown(FE.waveMode) && string(FE.waveMode.Value) == "off" ...
        && FE.waveMode.Items{1} == "Off (a circle per unit)" && any(string(FE.waveMode.ItemsData) == "template") ...
        && shown(FE.waveWidth) && ~shown(FE.wavePP) && ~shown(FE.waveSites) && ~shown(FE.waveLocation) ...
        && FE.waveBand.Enable == "off" && isequal(string(FE.waveAmp.ItemsData), EphysAnalysisConfig.WaveformAmpScales), ...
        'a probe map: Unit labels in its options; its Waveform rows (Off: circles), no label, location or sites rows, the band off');
    FE.unitLabels.Value = true;
    FE.waveMode.Value = "mean";
    app.onConfigChanged("figure");
    FE.waveBand.Value = "std";
    app.onConfigChanged("figure");
    o = app.Config.Figures(2).panels(1).options;
    bandOn = FE.waveBand.Enable == "on";
    FE.waveMode.Value = "template";
    app.onConfigChanged("figure");
    check(o.unitLabels && o.waveform.mode == "mean" && o.waveform.band == "std" && bandOn && FE.waveBand.Enable == "off" ...
        && FE.waveSpikes.Enable == "off" && app.Config.Figures(2).panels(1).options.waveform.mode == "template", ...
        'the rows reach the options: unit labels, the mean with its SD band; a template takes no band and reads no spikes');
    app.onRemoveFigure();
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

if S.sec("5d.psth", "a PSTH's Stack row, auROC rows, Display and Y limits mode; Firing rate and Tuning curve panels (drawn at once); a type change's display and stack")
    app.FigureAutoCheckBox.Value = false;   % no redraw per edit (as 5d.add leaves it)
    groupedBy("Depth");
    app.FigureAutoPreviewSeconds = Inf;   % Auto is on for the panels added: a preview slowed by a loaded machine must not leave them out of date
    restoreAutoLimit = onCleanup(@() resetAutoLimit(app));
    app.onFigureSelected(1);
    app.onPanelSelected(2);   % the PSTH
    pS = app.Config.Figures(1).panels(2);
    check(pS.type == "psth" && shown(FE.stack) && ~shown(FE.auMethod) && ~shown(FE.rateDisplay) ...
        && ~shown(FE.param) && ~shown(FE.waveLayout) && FE.stackSpacing.Enable == "off" ...
        && isequal(string(FE.stack.ItemsData), ["off" "groups"]), ...
        'a PSTH shows its Stack row (off or a row per group; the spacing off while Off) and no auROC rows without the auROC baseline');
    FE.stack.Value = "groups";
    app.onConfigChanged("figure");
    FE.stackSpacing.Value = 1.5;
    app.onConfigChanged("figure");
    app.refreshFigurePreview(Force=true);
    oS = app.Config.Figures(1).panels(2).options;
    nRows = numel(findall(app.FigurePreviewPanel, 'Tag', 'stackBase'));
    check(oS.stack == "groups" && oS.stackSpacing == 1.5 && FE.stackSpacing.Enable == "on" && app.FigurePreviewState == "drawn" ...
        && nRows == height(app.FigurePreviewResult.groups) * (height(app.FigurePreviewResult.groups) > 1), ...
        sprintf('the Stack row and its spacing reach the PSTH''s options; the preview stacks its groups (%d rows)', nRows));
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
    FE.stack.Value = "off";
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
    % the Y limits row: the mode drop-down, its lo-hi field only for Fixed
    yOff = FE.yLim.Enable == "off" && string(FE.yLimMode.Value) == "auto" && isequal(string(FE.yLimMode.ItemsData), EphysAnalysisConfig.YLimModes);
    FE.yLimMode.Value = "fixed";
    app.onConfigChanged("figure");
    yOn = FE.yLim.Enable == "on";
    FE.yLim.Value = '0 40';
    app.onConfigChanged("figure");
    app.refreshFigurePreview(Force=true);
    oY = app.Config.Figures(1).panels(2).options;
    axY = findPanelAxes(app.FigurePreviewPanel, app.Config.Figures(1).panels(2).id);
    check(yOff && yOn && oY.yLimMode == "fixed" && isequal(oY.yLim, [0 40]) && app.FigurePreviewState == "drawn" && isequal(ylim(axY), [0 40]), ...
        'Y limits: Auto by default (the lo-hi field grayed out); Fixed opens it, and the limits reach the options and the preview''s axis');
    FE.yLimMode.Value = "batch";
    app.onConfigChanged("figure");
    app.refreshFigurePreview(Force=true);
    check(app.Config.Figures(1).panels(2).options.yLimMode == "batch" && FE.yLim.Enable == "off" ...
        && contains(string(app.FigurePreviewLabel.Text), "shared by every observation when generated"), ...
        'Shared by batch reaches the options; the preview draws its own range and its status line says the run shares it');
    FE.yLimMode.Value = "auto";
    FE.yLim.Value = '';
    app.onConfigChanged("figure");
    app.refreshFigurePreview(Force=true);
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
    % the Waveform section: its own, under Panel, for every panel type of spikes; the rate panel's inset from its rows
    secW = app.FigureSections([app.FigureSections.Name] == "waveform");
    check(secW.Visible && secW.Super == "panel" && secW.Key == "" && startsWith(secW.Title, "Waveform on ") && shown(FE.waveNote) ...
        && shown(FE.waveMode) && shown(FE.waveFrom) && shown(FE.waveAmp) && shown(FE.waveWidth) && shown(FE.waveLocation) ...
        && ~shown(FE.waveSites) && FE.waveFrom.Enable == "off" && isequal(string(FE.waveAmp.ItemsData), ["unit" "fixed"]), ...
        'a rate panel''s Waveform section (in Panel, no key): its note, Show, Time, Amplitude, Size and place rows, grayed while Off');
    FE.waveMode.Value = "mean";
    FE.waveFrom.Value = -0.5;
    FE.waveAmp.Value = "fixed";
    FE.waveAmpLo.Value = -200;
    FE.waveAmpHi.Value = 80;
    FE.waveWidth.Value = 1.5;
    app.onConfigChanged("figure");
    wr = app.Config.Figures(1).panels(end).options.waveform;
    check(wr.mode == "mean" && isequal(wr.timeMs, [-0.5 Inf]) && wr.ampScale == "fixed" && isequal(wr.ampLim, [-200 80]) && wr.width == 1.5 ...
        && FE.waveAmpLo.Enable == "on" && FE.waveSpikes.Enable == "on" && app.FigurePreviewState == "drawn" ...
        && isfield(app.FigurePreviewResult.panels(end).layers(1).R, 'waveforms'), ...
        'its rows reach options.waveform (a blank end: Inf; the fixed range, its fields open) and the preview reads the waveforms');
    FE.waveMode.Value = "off";
    app.onConfigChanged("figure");
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
    % a type change takes the new type's display (it means other things on rate and PSTH panels; a continuous panel has none);
    % the stack and its spacing mean the same everywhere: carried, but a value the new type does not take
    kr = numel(app.Config.Figures(1).panels) - 1;   % the rate panel (its display "points")
    app.onPanelSelected(kr);
    FE.panelType.Value = "continuous";
    app.onPanelTypeChanged();
    o1 = app.Config.Figures(1).panels(kr).options;
    check(~app.FigureSections([app.FigureSections.Name] == "waveform").Visible, 'a continuous panel (no spikes) has no Waveform section');
    FE.panelType.Value = "rate";
    app.onPanelTypeChanged();
    o2 = app.Config.Figures(1).panels(kr).options;
    FE.panelType.Value = "psth";
    app.onPanelTypeChanged();
    FE.stackSpacing.Value = 1.5;
    app.onConfigChanged("figure");
    o3 = app.Config.Figures(1).panels(kr).options;
    FE.panelType.Value = "continuous";
    app.onPanelTypeChanged();
    FE.stack.Value = "items";
    app.onConfigChanged("figure");
    o4 = app.Config.Figures(1).panels(kr).options;
    FE.panelType.Value = "psth";
    app.onPanelTypeChanged();
    o5 = app.Config.Figures(1).panels(kr).options;
    I5 = app.Config.validate(CheckPaths=false);
    check(~isfield(o1, 'display') && o1.stack == "off" && o1.stackSpacing == 1.1 && o2.display == "bar" && ~isfield(o2, 'stack') ...
        && o3.stackSpacing == 1.5 && o4.stackSpacing == 1.5 && o4.stack == "items" && o5.stackSpacing == 1.5 && o5.stack == "off" ...
        && o5.display == "trace" ...
        && ~any(startsWith(I5.Field, app.Config.Figures(1).id + "." + app.Config.Figures(1).panels(kr).id + ".options") & I5.Severity == "error"), ...
        sprintf(['rate -> continuous -> rate -> PSTH -> continuous -> PSTH: each takes its own display; the stack spacing is carried, a ' ...
        'continuous panel''s "items" is not (a PSTH takes off or groups) (%g, %s, %g, %s %g, %s %g; preview %s)'], o1.stackSpacing, ...
        o2.display, o3.stackSpacing, o4.stack, o4.stackSpacing, o5.stack, o5.stackSpacing, app.FigurePreviewState));
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
    workersDefault = app.WorkersSpinner.Value;
    app.WorkersSpinner.Value = 2;
    app.WorkersSpinner.ValueChangedFcn(app.WorkersSpinner, []);
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
    workersKept = app2.WorkersSpinner.Value;
    closeApp(app2);
    check(workersDefault == 4 && workersKept == 2, sprintf(['the Export tab''s Workers: 4 by default, and a new app ' ...
        'restores the number set (%g, then %g)'], workersDefault, workersKept));
    app.WorkersSpinner.Value = workersDefault;
    app.WorkersSpinner.ValueChangedFcn(app.WorkersSpinner, []);
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

if S.sec("5e", "Copy settings... for figures: one setting, one figure onto another (out of date, not drawn), the window (From, the tree, Find, the figures ticked), Undo, into a design")
    savedConfig();
    noFigures();
    app.FigureAutoPreviewSeconds = Inf;   % a preview slowed by a loaded machine must not leave the next one out of date
    restoreAutoLimit = onCleanup(@() resetAutoLimit(app));
    app.FigureAutoCheckBox.Value = true;   % the automatic preview, as 5d leaves it
    app.selectTab(app.TabFigures);
    app.CopyUnticked = string.empty(1, 0);
    app.CopyTargets = string.empty(1, 0);
    lookOf = @(k) app.FigureTreeMarks.look([app.FigureTreeMarks.nodes.NodeData] == k);
    app.onAddFigure("rasterPsth");
    want = app.Config.Figures(1);
    check(app.CopyFigureButton.Enable == "on" && string(app.CopyFigureButton.Text) == "Copy settings..." && want.id == "Raster+PSTH units", ...
        'Copy settings... is on with one figure (its look can go into a design)');
    app.onAddFigure("heatmap");
    app.onAddFigure("psth");
    cx = app.gatherConfig();
    cx.Figures(2).style.FontSize = 15;
    cx.Figures(2).panels(1).options.bins.BinSec = 0.05;
    app.applyConfig(cx);
    ids = app.Config.figureIds();
    app.onFigureSelected(1);
    hid = ids(2);   % "Heatmap units": a fixed units layer, the dataset observed
    app.onCopyFigureSettings(From=hid, Settings="style.FontSize");
    f1 = app.Config.Figures(1);
    check(hid == "Heatmap units" && f1.id == "Raster+PSTH units" && f1.style.FontSize == 15 && isequal([f1.panels.type], [want.panels.type]) ...
        && f1.style.LineWidth == want.style.LineWidth && contains(string(app.StatusBar.Text), "Copied 1 setting(s) from Heatmap units onto Raster+PSTH units") ...
        && app.FigureHistory.undoLabel() == "Copy settings from Heatmap units to Raster+PSTH units" && app.FigurePreviewState == "drawn", ...
        'From= and Settings= copy the font size alone onto the figure selected (the panels and the rest stay), one step of Undo; the preview follows');

    % one figure onto another not shown: its kept preview marked out of date, nothing drawn
    app.onFigureSelected(3);   % drawn (Auto) and kept
    app.onFigureSelected(1);
    fresh3 = lookOf(3) == "fresh";
    app.onCopyFigureSettings(Settings="style.FontSize", To=ids(2:3));
    F5e = app.Config.Figures;   % (not F: the fixture)
    check(fresh3 && F5e(3).style.FontSize == 15 && lookOf(3) == "stale" && lookOf(1) == "fresh" && app.FigurePreviewState == "drawn" ...
        && app.FigureHistory.undoLabel() == "Copy settings from Raster+PSTH units to PSTH units" && contains(string(app.StatusBar.Text), "onto PSTH units."), ...
        ['the figure shown onto two: the heat map has the font size already, the PSTH figure takes it; its kept preview is marked out ' ...
        'of date, nothing is drawn']);
    app.onUndoRedo("undo");
    check(app.Config.Figures(3).style.FontSize ~= 15 && app.Config.Figures(1).style.FontSize == 15, 'Undo takes the copy back, one step');

    % the window: From the heat map, None, the alignment and the layout ticked, Find, onto the figure selected
    answerDialog('Copy figure settings', @copyFigureDialog);
    app.onCopyFigureSettings();
    seen = getappdata(groot, 'copyFigureSeen');
    if isappdata(groot, 'copyFigureSeen'); rmappdata(groot, 'copyFigureSeen'); end
    f1 = app.Config.Figures(1);
    check(isstruct(seen) && seen.count == "4 setting(s) onto 1 figure(s)" && isequal(seen.targets, "Raster+PSTH units  (2 panels), shown") ...
        && isequal(seen.found, "Font size = 15") && seen.from == "Heatmap units  (1 panels)" ...
        && f1.id == "Heatmap units (2)" && isequal([f1.panels.type], "heatmap") && f1.panels.options.bins.BinSec == 0.05 && app.SelectedPanel == 1 ...
        && nPatches() == 1 && f1.style.FontSize == 15, ...
        ['the window: From the heat map ticks the figure selected; Find shows the font size alone; the alignment and the layout ticked ' ...
        'copy the heat map''s panels, their options too, and the automatic id follows ("Heatmap units (2)")']);
    check(ismember("style.FontSize", app.CopyUnticked) && ~ismember("alignment.ref", app.CopyUnticked) && isequal(app.CopyTargets, "Heatmap units (2)"), ...
        'the ticks are remembered for the next time: the settings left unticked, the figure ticked (by the id it follows)');

    % into a design
    cx = app.gatherConfig();
    cx.Figures(1).style.Colormap = "turbo";
    app.applyConfig(cx);
    app.onCopyFigureSettings(Design="Copied look");
    Dc = PlotDesign.load("Copied look");
    check(Dc.source == "mine" && Dc.sequential == "turbo" && isequal(size(Dc.palette), [7 3]) && PlotDesign.currentName() ~= "Copied look" ...
        && contains(string(app.StatusBar.Text), "into design Copied look"), ...
        'Design= copies the figure''s look (its group colors) into a new design of yours, not chosen');
    app.onDeleteDesign("Copied look", Confirm=false);
    noFigures();
    check(isempty(app.Config.Figures), 'every figure removed');
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
    check(app.FigureRedrawAllButton.Enable == "off" && app.GenerateFigureMenu.Enable == "off" && app.FigureExportPreviewColumnButton.Enable == "off" ...
        && app.TestReportButton.Enable == "off" ...
        && app.FigureRedrawAllButton.Parent == bcol && app.FigureExportPreviewColumnButton.Parent == bcol && app.FigureAutoCheckBox.Parent == bcol ...
        && isequal(app.FigurePreviewButton.Layout.Row, 1) && isequal(app.FigureRedrawAllButton.Layout.Row, 2) && isequal(app.FigureExportPreviewColumnButton.Layout.Row, 3) ...
        && isequal(app.FigureRedrawAllButton.BackgroundColor, app.FigurePreviewButton.BackgroundColor) ...
        && app.GenerateFigureMenu.Parent == app.FileMenu && app.GenerateFigureMenu.Accelerator == "G" ...
        && app.FigureObsPrevButton.Parent == app.FigureObsNextButton.Parent && app.FigureObsPrevButton.Parent.Parent == bcol ...
        && app.FigureObsPrevButton.Layout.Row == 1 && app.FigureObsNextButton.Layout.Row == 1 ...
        && bcol.Parent == app.FiguresDatasetDropDown.Parent.Parent && max(bcol.Layout.Column) < min(app.FiguresDatasetDropDown.Parent.Layout.Column) ...
        && isequal(bcol.Layout.Row, [1 3]), ...
        ['Preview, Redraw All (colored as it is, under Preview), Export preview (under Redraw All; both off with no figure), Auto and < > ' ...
        '(on one row) form a column left of Dataset, Observation and Favorites; File > Generate selected figure (Ctrl+G) and the Export tab''s Test report are off too']);
    mods = {'control'};
    if ismac; mods = {'command'}; end
    report0 = app.LastReportFiles;
    app.onKeyPress(pressed('u', mods));
    check(isequal(app.LastReportFiles, report0) && ~app.Running, 'Ctrl+U does nothing while Test report is off');
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
    check(app.GenerateFigureMenu.Enable == "on" && numel(gIdx) == 2 && nObsWant >= 2, ...
        sprintf('Generate is on with %s selected (%d observation(s) on the %d ticked datasets)', fid, nObsWant, numel(gIdx)));
    R = app.onGenerateFigure();
    T = app.ResultsTable.Data;
    check(istable(R) && height(R) == numel(gIdx) && all(R.Kind == "figure") && all(R.Plot == fid) && all(R.Status == "done") ...
        && sum(arrayfun(@(s) sscanf(char(s), '%d', 1), R.Message)) == nObsWant && all(isfile(want)) ...
        && height(T) == height(R) && all(string(T.Kind) == "figure") && all(ismember(["Subject" "Date"], string(T.Properties.VariableNames))), ...
        sprintf('Generate draws %s for every observation on both datasets: %d file(s) in the Export folder, the results table shows its figure rows', fid, numel(want)));
    check(startsWith(string(app.StatusBar.Text), sprintf("Generated %s: %d observation(s) on %d dataset(s), %d file(s) in ", fid, nObsWant, numel(gIdx), numel(want))) ...
        && app.OpenFolderButton.Enable == "on" && app.ToolbarFolderTool.Enable == "on" && app.OpenReportButton.Enable == "off" ...
        && ~app.Running && app.GenerateFigureMenu.Enable == "on" && app.FigureRedrawAllButton.Enable == "on" && app.RunButton.Enable == "on" && app.CancelButton.Enable == "off" ...
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
    check(isstruct(pr) && pr.generate == "off" && pr.redraw == "off" && pr.run == "off" && pr.cancel == "on" && contains(pr.preview, "A run is going") ...
        && pr.state ~= "computing", 'while it runs, Generate, Redraw All and Run are off, Cancel is on, and the preview computes nothing');
    check(istable(Rc) && height(Rc) == numel(gIdx) && all(Rc.Status == "canceled") && height(app.ResultsTable.Data) == height(Rc) ...
        && startsWith(string(app.StatusBar.Text), "Generating " + fid + " was canceled") && ~app.Running && app.GenerateFigureMenu.Enable == "on", ...
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
    % Test report: every enabled figure (and the selected one, though off) for the unit picked, an HTML report in a
    % temporary folder; a channel figure draws the unit's channel, a figure of the dataset draws the dataset; in the
    % report's Order, here by unit (the Export tab's drop-down)
    app.onAddFigure("continuous");
    app.onAddFigure("heatmap");
    app.onFigureSelected(kG);
    app.FigureObservationDropDown.Value = 2;
    app.onFigureObservationChanged();
    uT = app.FigureObservations;
    uLabel = uT.label(2);
    check(app.TestReportButton.Enable == "on" && app.TestReportButton.Text == "Test report" && uT.kind(2) == "unit" ...
        && app.TestReportButton.Parent == app.RunButton.Parent && app.TestReportButton.Layout.Column == app.RunButton.Layout.Column - 1, ...
        'Test report is on with a unit picked, left of Run on the Export tab');
    check(app.ReportControls.Order.Value == "figure" && isequal(app.ReportControls.Order.ItemsData, ["figure" "unit"]), ...
        'the Export tab''s report Order is By figure by default, or By unit');
    app.ReportControls.Order.Value = "unit";
    nTicked = numel(app.tickedDatasetIndices());
    [Ru, fu] = app.onTestReport(Open=false);
    app.ReportControls.Order.Value = "figure";
    uKinds = arrayfun(@(f) EphysAnalysisConfig.observeKind(f), app.Config.Figures);
    okRows = true;
    for q = 1:numel(app.Config.Figures)
        rq = Ru(Ru.Plot == app.Config.Figures(q).id, :);
        if uKinds(q) == "dataset" || q == kG
            okRows = okRows && isscalar(rq.Status) && rq.Status == "done" && rq.Message == "1 observation(s)";
        else   % what is on the unit's channel, or why nothing is
            okRows = okRows && isscalar(rq.Status) && (rq.Status == "done" || rq.Status == "skipped" && startsWith(rq.Message, "no "));
        end
    end
    uHtml = string(fileread(fu));
    dsName = app.Runner.Names(app.ActiveIdx);
    check(istable(Ru) && height(Ru) == 3 && all(Ru.Dataset == dsName) && okRows && any(uKinds == "dataset") ...
        && isfile(fu) && endsWith(fu, "test_report.html") && startsWith(fu, string(tempdir)) && ~startsWith(fu, string(outRoot)) ...
        && contains(uHtml, fid) && isempty(dir(fullfile(outRoot, '**', 'test_report*'))) ...
        && isequal(app.LastReportFiles, fu) && ~app.Config.Figures(kG).enabled && nTicked == numel(app.tickedDatasetIndices()), ...
        sprintf('Test report draws the three figures for %s on the active dataset only (the dataset''s figure for the dataset), into a temporary HTML report; the output folder untouched, the figure kept off', uLabel));
    check(contains(uHtml, "<h3 class=""obs"">" + htmlEscape(uLabel) + "</h3>") && contains(uHtml, "<h3 class=""obs"">" + htmlEscape(dsName) + "</h3>") ...
        && contains(uHtml, "test report, " + htmlEscape(uLabel) + " on " + htmlEscape(dsName)), ...
        'by unit, the report heads the unit''s figures with its label and the dataset''s figure with the dataset''s name; its title names the unit');
    check(startsWith(string(app.StatusBar.Text), "Test report for " + uLabel + ": ") && contains(string(app.StatusBar.Text), "left out") == any(Ru.Status ~= "done") ...
        && contains(string(app.StatusBar.Text), fid + " is off, so it was drawn for this report only") ...
        && ~app.Running && app.TestReportButton.Enable == "on" && app.GenerateFigureMenu.Enable == "on", ...
        'the status bar names the unit, what was left out, the figure that is off; the buttons are back');
    app.onFigureSelected(3); app.onRemoveFigure();
    app.onFigureSelected(2); app.onRemoveFigure();
    app.onFigureSelected(kG);
    % Export preview: the observation picked, written as a run writes it, into the preview folder (not the figure folder)
    app.ExportPreviewFolder = fullfile(root, 'export_preview');
    check(app.FigureExportPreviewColumnButton.Enable == "on" && app.FigureExportPreviewButton.Enable == "on" ...
        && app.FigureExportPreviewColumnButton.Text == "Export preview" ...
        && app.FigureExportPreviewButton.Parent == app.FigureCodeButton.Parent ...
        && app.FigureExportPreviewButton.Layout.Column == app.FigureCodeButton.Layout.Column - 1, ...
        'Export preview is on with a figure selected: in the column of buttons, and left of Export code under the preview');
    app.ExportControls.svg.Value = true;
    app.onConfigChanged("export");
    TP = app.FigureObservations;
    iP = app.FigureObservationDropDown.Value;
    nameP = app.Runner.Names(app.ActiveIdx);
    baseP = figureOutputName(gX.FilenamePattern, nameP, gSpec, TP(iP, :), iP, height(TP));
    filesP = app.onExportPreview();
    WP = app.ExportPreviewWindow;
    infoP = join(string(findall(WP, 'Type', 'uilabel').Text), " ");
    check(isequal(sort(filesP), sort(fullfile(app.ExportPreviewFolder, baseP) + "." + ["png" "svg"])) && all(isfile(filesP)) ...
        && isvalid(WP) && contains(string(WP.Name), fid) && isscalar(findall(WP, 'Type', 'uiimage')) ...
        && contains(infoP, "60 dpi") && contains(infoP, fullfile(outRoot, nameP)) && ~isfile(fullfile(outRoot, nameP, baseP) + ".svg"), ...
        sprintf('Export preview writes %s (png, svg) as a run names it into the preview folder, none into the figure folder, and shows it', baseP));
    app.ExportControls.png.Value = false;
    app.onConfigChanged("export");
    mods = {'control'};
    if ismac; mods = {'command'}; end
    app.onKeyPress(pressed('k', mods));
    check(isfile(fullfile(app.ExportPreviewFolder, baseP) + ".svg") && ~isfile(fullfile(app.ExportPreviewFolder, baseP) + ".png") ...
        && isfile(fullfile(app.ExportPreviewFolder, "view", baseP) + ".png") && app.ExportPreviewWindow == WP ...
        && contains(string(app.StatusBar.Text), "1 file(s)"), ...
        'Ctrl+K with png unticked: the svg alone, the PNG shown written apart, the last preview''s png gone, the same window');
    delete(WP);
    app.ExportControls.png.Value = true;
    app.ExportControls.svg.Value = false;
    app.onConfigChanged("export");
    app.onRemoveFigure();
    check(app.FigureExportPreviewColumnButton.Enable == "off" && app.FigureExportPreviewButton.Enable == "off", 'Export preview is off with no figure');
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
    [FcS, hcS, DcS] = runPreviewCode(codeFileS);
    closeCodeS = onCleanup(@() delete(hcS(isgraphics(hcS))));
    check(contains(codeS, "res = figureSessionCompute(sources, sessions, spec, Observation=obs);") && all(contains(codeS, app.Runner.Keys)) ...
        && contains(codeS, """" + app.FigureSessionResults.label + """") && sameResult(FcS, app.FigurePreviewResult) && height(FcS.sessions) == 2, ...
        'Export code of a figure across sessions: run, the script merges the observation over both datasets and draws the figure picked under the preview');
    okS = isfield(DcS, 'data') && numel(DcS.data) == 2;
    for jS = 1:2 * okS
        dj = DcS.data(jS);
        okS = okS && dj.session == DcS.sessions.label(jS) && dj.name == string(DcS.sources{jS}.name) ...
            && isequaln(dj.E, figureEpochs(DcS.sources{jS}, DcS.spec)) && isequal(dj.spikesIn, epochSpikes(dj.spikes, dj.E)) ...
            && isequal(fieldnames(dj.onsets), cellstr(dj.lineNames(:)));
    end
    check(okS, 'Export code across sessions loads each session''s data in the preview''s epochs too, as data(j) in session order');
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
    % Export preview: the site picked, written into the preview folder
    app.ExportPreviewFolder = fullfile(root, 'export_preview');
    filesS = app.onExportPreview();
    check(~isempty(filesS) && all(isfile(filesS)) && all(startsWith(filesS, app.ExportPreviewFolder)) ...
        && contains(string(app.ExportPreviewWindow.Name), sid), 'Export preview of a session figure writes the site picked into the preview folder');
    delete(app.ExportPreviewWindow);
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
    [~, nmS, extS] = fileparts(filesS(1));
    check(any(endsWith(wantS, filesep + nmS + extS)), sprintf('Generate writes a file of the name Export preview gave (%s)', nmS + extS));
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
    check(groupsShown && app.Config.Figures(1).panels(1).options.tickWidth == 2.5 && ~isempty(tkW) ...
        && all(arrayfun(@(t) PlotAesthetics.getValue(t, "LineWidth"), tkW) == 2.5), ...   % (as exported: the preview draws it at its scale)
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
    FE.stack.Value = "groups";
    app.onConfigChanged("figure");
    stackOff = FE.panelYSide.Enable == "off";
    FE.stack.Value = "off";
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
    % the panel axes' own right-click menu: both labels' text and both sides, the panel's and every panel's
    axP = findPanelAxes(app.FigurePreviewPanel, "psth_1");
    axR = findPanelAxes(app.FigurePreviewPanel, "raster_1");
    mP = string({PlotAesthetics.menuOf(axP).Children.Text});
    hiddenR = isempty(axR.XTickLabel) && strjoin(string(axR.XLabel.String), "") == "";   % the stack tells the time on the PSTH under it
    allTop = findobj(PlotAesthetics.menuOf(axP).Children, 'flat', 'Text', "Move every panel's X axis to top");
    allTop.MenuSelectedFcn(allTop, []);
    fgT = app.Config.Figures(1);
    axP = findPanelAxes(app.FigurePreviewPanel, "psth_1");
    axR = findPanelAxes(app.FigurePreviewPanel, "raster_1");
    check(all(ismember(["Edit aesthetics..." "Edit X label text..." "Edit Y label text..." "Move X axis to top" "Move Y axis to right" ...
        "Move every panel's X axis to top" "Move every panel's Y axis to right"], mP)) && hiddenR ...
        && all([fgT.panels.xSide] == "top") && app.FigureHistory.undoLabel() == "Every panel's axis side" && app.FigurePreviewState == "drawn" ...
        && strcmp(axR.XAxisLocation, 'top') && ~isempty(axR.XTickLabel) && string(axR.XLabel.String) == "Time (s)" ...
        && strcmp(axP.XAxisLocation, 'top') && isempty(axP.XTickLabel) && contains(app.StatusBar.Text, "every panel"), ...
        ['the axes'' menu holds both labels'' text, both sides and the every-panel moves; "Move every panel''s X axis to top" ' ...
        'moves the raster''s and the PSTH''s: one time axis, on top of the stack, one undo step']);
    app.onUndoRedo("undo");
    check(all([app.Config.Figures(1).panels.xSide] == "bottom") && app.FigureHistory.undoLabel() == "Label text", ...
        'one undo puts every panel''s x axis back (Undo Every panel''s axis side)');
    app.onFigureAxisEdited(app.Config.Figures(1).id, "raster_1", struct('xLabel', "Hidden"));
    hidSt = string(app.StatusBar.Text);
    app.onFigureAxisEdited(app.Config.Figures(1).id, "raster_1", struct('xLabel', ""));
    allBottom = app.Config.Figures(1);
    app.onFigureAxisEdited(allBottom.id, [allBottom.panels.id], struct('xSide', "bottom"));
    check(contains(hidSt, """Hidden""") && contains(hidSt, "not shown") && app.Config.Figures(1).panels(1).xLabel == "" ...
        && isequaln(app.Config.Figures(1), allBottom) && contains(app.StatusBar.Text, "already"), ...
        ['the text of an x label the stack hides (Edit X label text... on the raster''s axes) is kept, the status saying the stack ' ...
        'hides it; an every-panel move that changes nothing says so']);

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

if S.sec("5l", "a raster's First-spike marks... and a PSTH's Latency box plot... windows: their looks, OK as one named step, Cancel, the preview")
    noFigures();
    groupedBy("Depth");
    app.selectTab(app.TabFigures);
    app.FigureAutoCheckBox.Value = false;   % no redraw per edit: the preview is drawn once, at the end
    restoreAuto5l = onCleanup(@() autoBoxOn(app));
    app.onAddFigure("rasterPsth");
    app.onPanelSelected(1);   % the raster
    check(shown(FE.firstSpike) && shown(FE.firstSpikeDialog) && ~shown(FE.latencyBox) && string(FE.firstSpike.Text) == "off", ...
        'a raster shows its First spike row ("off" beside its button), not the PSTH''s Latency box row');
    FE.firstSpikeDialog.ButtonPushedFcn(FE.firstSpikeDialog, []);
    dF = findall(groot, 'Type', 'figure', 'Tag', 'latencyDialog');
    DF = dF.UserData;
    grayed = DF.Marker.Enable == "off" && DF.Color.Enable == "off" && DF.Enabled.Enable == "on";
    modal = string(dF.WindowStyle) == "modal";
    noted = contains(DF.Note.Text, "the first spike in [0 ms to the window's end]") && ~isfield(DF, 'MinMs');
    DF.Enabled.Value = true;
    DF.Enabled.ValueChangedFcn(DF.Enabled, []);
    DF.Marker.Value = "diamond";
    DF.Size.Value = 6;
    DF.Color.Value = "red";
    DF.Filled.Value = true;
    nU5l = numel(app.FigureHistory.Undo);
    DF.Ok.ButtonPushedFcn(DF.Ok, []);
    fsO = app.Config.Figures(1).panels(1).options.firstSpike;
    check(isscalar(dF) && DF.Kind == "firstSpike" && DF.PanelId == "raster_1" && modal && grayed && noted ...
        && ~isvalid(dF) && fsO.enabled && ~isfield(fsO, 'minSec') && fsO.marker == "diamond" ...
        && fsO.size == 6 && fsO.color == "red" && fsO.filled && numel(app.FigureHistory.Undo) == nU5l + 1 ...
        && string(app.UndoMenu.Text) == "Undo First-spike marks" && string(FE.firstSpike.Text) == "on, ◆ red", ...
        sprintf(['First-spike marks...: a modal window on the look, its rows grayed while off, its note naming the ' ...
        'figure''s rule; OK gives the raster the look as one step, "Undo First-spike marks", and the row says "%s"'], ...
        FE.firstSpike.Text));
    app.onUndoRedo("undo");
    undone = ~app.Config.Figures(1).panels(1).options.firstSpike.enabled && string(FE.firstSpike.Text) == "off";
    app.onUndoRedo("redo");
    check(undone && app.Config.Figures(1).panels(1).options.firstSpike.enabled && string(FE.firstSpike.Text) == "on, ◆ red", ...
        'Undo takes the marks off again in one step, Redo puts them back');
    FE.firstSpikeDialog.ButtonPushedFcn(FE.firstSpikeDialog, []);
    dF = findall(groot, 'Type', 'figure', 'Tag', 'latencyDialog');
    DF = dF.UserData;
    shownBack = DF.Enabled.Value && string(DF.Marker.Value) == "diamond" && DF.Size.Value == 6;
    DF.Size.Value = 9;
    DF.Cancel.ButtonPushedFcn(DF.Cancel, []);
    check(shownBack && ~isvalid(dF) && app.Config.Figures(1).panels(1).options.firstSpike.size == 6 ...
        && numel(app.FigureHistory.Undo) == nU5l + 1, ...
        'the window opens on the panel''s settings; Cancel changes nothing');
    app.onPanelSelected(2);   % the PSTH
    check(shown(FE.latencyBox) && shown(FE.latencyBoxDialog) && ~shown(FE.firstSpike) && string(FE.latencyBox.Text) == "off", ...
        'a PSTH shows its Latency box row, not the raster''s First spike row');
    FE.latencyBoxDialog.ButtonPushedFcn(FE.latencyBoxDialog, []);
    dB = findall(groot, 'Type', 'figure', 'Tag', 'latencyDialog');
    DB = dB.UserData;
    DB.Enabled.Value = true;
    DB.Enabled.ValueChangedFcn(DB.Enabled, []);
    DB.LineStyle.Value = "--";
    DB.LineWidth.Value = 1.5;
    DB.BoxHeight.Value = 0.2;
    DB.FillAlpha.Value = 0.5;
    DB.OutlierMarker.Value = "x";
    DB.Ok.ButtonPushedFcn(DB.Ok, []);
    lbO = app.Config.Figures(1).panels(2).options.latencyBox;
    check(DB.Kind == "latencyBox" && ~isvalid(dB) && lbO.enabled && ~isfield(lbO, 'maxSec') && lbO.lineStyle == "--" ...
        && lbO.lineWidth == 1.5 && abs(lbO.boxHeight - 0.2) < 1e-12 && lbO.fillAlpha == 0.5 && lbO.outlierMarker == "x" ...
        && string(app.UndoMenu.Text) == "Undo Latency box plot" && string(FE.latencyBox.Text) == "on, groups --", ...
        sprintf('Latency box plot...: OK gives the PSTH its box plot as one step, "Undo Latency box plot"; the row says "%s"', ...
        FE.latencyBox.Text));
    app.refreshFigurePreview(Force=true);
    mkP = findall(app.FigurePreviewPanel, 'Tag', 'firstSpike');
    bxP = findall(app.FigurePreviewPanel, 'Tag', 'latencyBox');
    check(app.FigurePreviewState == "drawn" && any(arrayfun(@(h) any(isfinite(h.XData)), mkP)) && ~isempty(bxP), ...
        sprintf('the preview draws the first-spike marks (%d lines) and the latency boxes (%d)', numel(mkP), numel(bxP)));
    % the PSTH's Trial count row and the raster's Sort rows by "latency"
    shownTc = shown(FE.trialCount) && string(FE.trialCount.Value) == "off";
    FE.trialCount.Value = "text";
    app.onConfigChanged("figure", FE.trialCount);
    app.refreshFigurePreview(Force=true);
    txP = findall(app.FigurePreviewPanel, 'Tag', 'trialCount');
    check(shownTc && app.Config.Figures(1).panels(2).options.trialCount == "text" && string(app.UndoMenu.Text) == "Undo Trial count" ...
        && app.FigurePreviewState == "drawn" && numel(txP) == height(app.FigurePreviewResult.groups), ...
        sprintf('Trial count: text gives the PSTH "n = <trials>" per group (%d) as one named step', numel(txP)));
    app.onPanelSelected(1);   % the raster
    offered = any(string(FE.rasterSort.Items) == "latency");
    FE.rasterSort.Value = "latency";
    app.onConfigChanged("figure", FE.rasterSort);
    app.refreshFigurePreview(Force=true);
    check(offered && ~shown(FE.trialCount) && app.Config.Figures(1).panels(1).options.rasterSort == "latency" ...
        && app.FigurePreviewState == "drawn", ...
        'a raster''s Sort rows by offers "latency" and keeps it; the Trial count row is the PSTH''s alone');
    noFigures();
    clear restoreAuto5l
end

if S.sec("5m", "each figure's own preview container: kept drawings, the tree's marks, the editor's state, the observation lists, the cap, Redraw All and its Cancel, Remove, Undo / Redo")
    noFigures();
    app.selectTab(app.TabFigures);
    app.FigureAutoCheckBox.Value = true;
    app.FigureAutoPreviewSeconds = Inf;   % Auto draws every figure shown here, however loaded the machine
    restore5m = onCleanup(@() resetAutoLimit(app));
    tree = app.FiguresTree;
    lookOf = @(k) app.FigureTreeMarks.look([app.FigureTreeMarks.nodes.NodeData] == k);
    app.onAddFigure("rasterPsth");
    P1 = app.FigurePreviewPanel;
    ax1 = figAxes();
    app.onAddFigure("psth");
    P2 = app.FigurePreviewPanel;
    ax2 = figAxes();
    check(app.FigurePreviewState == "drawn" && P2 ~= P1 && P1.Parent == app.FigurePreviewHost && P2.Parent == app.FigurePreviewHost ...
        && P1.Visible == "off" && P2.Visible == "on" && numel(ax1) == 2 && all(isvalid(ax1)) && isscalar(ax2) ...
        && isequal(sort([app.FigureViews.Id]), sort(["" app.Config.figureIds()])), ...
        'a figure added gets a container of its own in the preview''s cell: the first one''s drawing stays, hidden, in its own');
    t0 = tic;
    app.onFigureSelected(1);
    drawnow;
    tSwitch = toc(t0);
    check(app.FigurePreviewPanel == P1 && P1.Visible == "on" && P2.Visible == "off" && isequal(figAxes(), ax1) && all(isvalid(ax2)) ...
        && app.FigurePreviewState == "drawn" && app.FigurePreviewResult.id == app.Config.Figures(1).id ...
        && contains(string(app.FigurePreviewLabel.Text), app.Config.Figures(1).id), ...
        sprintf('back to the first figure: its own drawing shows again (the same axes, not drawn again), its badge and status line too (%.2f s)', tSwitch));
    st = tree.StyleConfigurations;
    check(isequal(tree.SelectedNodes, figureNode(tree, 1)) && isequal(app.FigureTreeMarks.current, [app.FigureTreeMarks.nodes.NodeData] == 1) ...
        && all(app.FigureTreeMarks.look == "fresh") && height(st) == 1 && st.Style(1).FontWeight == "bold" ...
        && isequal(st.TargetIndex{1}, figureNode(tree, 1)), ...
        'the tree selects the figure shown and marks it bold; both previews are current, so nothing else is marked');
    app.FigureAutoCheckBox.Value = false;
    FE.title.Value = 'Kept apart';
    app.onConfigChanged("figure", FE.title);
    check(app.FigurePreviewState == "stale" && lookOf(1) == "stale" && lookOf(2) == "fresh" ...
        && any(arrayfun(@(i) any(tree.StyleConfigurations.TargetIndex{i} == figureNode(tree, 1)) ...
        && tree.StyleConfigurations.Style(i).FontAngle == "italic", 1:height(tree.StyleConfigurations))), ...
        'an edit of the first figure (Auto off) marks its preview out of date in the tree (amber italic), not the other figure''s');
    app.onFigureSelected(2);
    check(app.FigurePreviewPanel == P2 && isequal(figAxes(), ax2) && app.FigurePreviewState == "drawn" && lookOf(1) == "stale" && lookOf(2) == "fresh", ...
        'the other figure is current: shown as kept, with Auto off too; the first stays marked');
    app.onFigureSelected(1);
    check(app.FigurePreviewState == "stale" && isequal(figAxes(), ax1), 'back on the first: still Out of date, its old drawing kept');
    app.refreshFigurePreview(Force=true);
    check(app.FigurePreviewState == "drawn" && lookOf(1) == "fresh" && app.FigurePreviewPanel == P1, 'Preview draws it again in its own container: current');
    FE.title.Value = '';
    app.onConfigChanged("figure", FE.title);
    app.refreshFigurePreview(Force=true);
    a0 = app.ActiveIdx;   % (an earlier section may leave either dataset active)
    app.selectDataset(kF1 + kF2 - a0);
    check(lookOf(1) == "stale" && lookOf(2) == "stale", 'another dataset: every figure''s preview is out of date');
    app.selectDataset(a0);
    check(lookOf(2) == "fresh", 'the dataset back: the hidden figure''s kept drawing is current again');
    app.refreshFigurePreview(Force=true);

    % the editor as each figure left it
    opt = @() app.FigureSections([app.FigureSections.Name] == "options").Expanded;
    if ~opt(); app.onFigureSectionToggled("options"); end
    app.onPanelSelected(2);
    app.onFigureSectionToggled("options");   % figure 1: Options collapsed, panel 2
    app.onFigureSelected(2);
    check(app.SelectedPanel == 1, 'the second figure: its own panel (its first), not the first figure''s panel 2');
    if ~opt(); app.onFigureSectionToggled("options"); end   % figure 2: Options open
    app.onFigureSelected(1);
    check(app.SelectedPanel == 2 && ~opt() && isKey(app.FigureEditorStates, char(app.Config.Figures(2).id)), ...
        'back to the first: its panel 2 and its Options collapsed, as it left them');
    ax1 = figAxes();
    s1 = app.FigureEditorStates(char(app.Config.Figures(2).id));
    app.onFigureSelected(2);
    check(app.SelectedPanel == 1 && opt() && isfield(s1, 'Scroll') && (isempty(s1.Scroll) || numel(s1.Scroll) == 2), ...
        'and the second: its Options open again (its scroll kept too)');

    % the observation picker as each figure left it (keepFigurePicker): a switch back lists nothing again
    dd = app.FigureObservationDropDown;
    id1 = char(app.Config.Figures(1).id);
    id2 = char(app.Config.Figures(2).id);
    app.onFigureSelected(1);
    if numel(dd.ItemsData) > 1; dd.Value = 2; app.onFigureObservationChanged(); end
    pick1 = dd.Value;
    items1 = dd.Items;
    app.onFigureSelected(2);
    P = app.FigurePickers(id1);
    P.Count = "kept list";   % a mark: the count line says it only when the kept list is taken back
    app.FigurePickers(id1) = P;
    app.onFigureSelected(1);
    check(isKey(app.FigurePickers, id2) && string(FE.obsCount.Text) == "kept list" && isequal(dd.Items, items1) && dd.Value == pick1 ...
        && string(app.FigureObservation(id1)) == app.FigureObservations.label(pick1), ...
        'back to the first figure: its own observation list, as it left it (its pick too), without listing it again');
    app.refreshFavorites();
    P = struct('Count', "");
    if isKey(app.FigurePickers, id1); P = app.FigurePickers(id1); end
    check(~isKey(app.FigurePickers, id2) && P.Count == "kept list", ...
        'a star set or cleared forgets the other figures'' lists (their marks may be old); the one shown is kept with its marks');
    ax1 = figAxes();
    app.onFigureSelected(2);
    nAll = height(app.FigureObservations);
    FE.obsMaxUnits.Value = '1';
    app.onConfigChanged("figure", FE.obsMaxUnits);
    id2 = char(app.Config.Figures(2).id);
    app.onFigureSelected(1);
    app.onFigureSelected(2);
    P = app.FigurePickers(id2);
    check(nAll > 1 && height(app.FigureObservations) == 1 && numel(dd.Items) == 1 && P.UserData.key.observe.units.maxUnits == 1, ...
        'an edit of the figure''s unit filter lists it again, and that list is the one kept for it');
    FE.obsMaxUnits.Value = 'Inf';
    app.onConfigChanged("figure", FE.obsMaxUnits);
    check(height(app.FigureObservations) == nAll, 'the filter back: every unit listed again');

    % Remove frees the container; the cap
    app.onRemoveFigure();
    check(~isvalid(P2) && numel(app.FigureViews) == 2 && app.FigureViewId == app.Config.Figures(1).id && app.FigurePreviewPanel == P1 ...
        && isequal(figAxes(), ax1) && ~isKey(app.FigureEditorStates, 'PSTH units'), ...
        'Remove frees the figure''s container and its editor state; the figure taking its place shows its kept drawing');
    for i = 1:app.MaxFigureViews
        app.onAddFigure("psth");   % (Auto off: shown, not drawn)
    end
    check(numel(app.FigureViews) == app.MaxFigureViews + 1 && ~isvalid(P1) && all(isvalid([app.FigureViews.Panel])) ...
        && lookOf(1) == "none" && numel(app.FigurePreviewHost.Children) == app.MaxFigureViews + 1, ...
        sprintf('past %d containers the one shown least recently goes (the first figure''s): the tree marks it not drawn', app.MaxFigureViews));
    app.FigureAutoCheckBox.Value = true;
    app.onFigureSelected(1);
    check(app.FigurePreviewState == "drawn" && numel(figAxes()) == 2 && lookOf(1) == "fresh", 'shown again, it is drawn again (Auto)');

    % Redraw All: every enabled figure's preview made current, up to the cap (the shown one, then those shown last)
    ids = app.Config.figureIds();
    nF = numel(ids);
    ax1 = figAxes();
    R = app.onRedrawAllFigures();
    check(isequal(R.current, ids(1)) && isequal(sort(R.drawn), sort(ids(3:nF))) && isequal(R.left, ids(2)) && isempty(R.notDrawn) ...
        && ~R.canceled && ~R.stopped && app.SelectedFigure == 1 && isequal(figAxes(), ax1) ...
        && all(arrayfun(@(k) lookOf(k) == "fresh", [1 3:nF])) && lookOf(2) == "none" && numel(app.FigureViews) == app.MaxFigureViews + 1 ...
        && startsWith(string(app.StatusBar.Text), sprintf("Redraw All: %d drawn, 1 already current", nF - 2)) ...
        && contains(string(app.StatusBar.Text), sprintf("1 more enabled figure(s) are drawn when shown (%d previews are kept)", app.MaxFigureViews)) ...
        && ~app.FigureRedrawing && app.FigureRedrawAllButton.Enable == "on" && app.ToolbarCancelTool.Enable == "off", ...
        sprintf(['Redraw All with %d enabled figures: the shown one is current (kept), the %d shown most recently drawn, the one ' ...
        'shown least recently left for later (the cap); the shown figure selected again'], nF, nF - 2));
    mods5m = {'control'};
    if ismac; mods5m = {'command'}; end
    app.onKeyPress(pressed('r', mods5m));   % Ctrl+R
    check(startsWith(string(app.StatusBar.Text), sprintf("Redraw All: 0 drawn, %d already current", nF - 1)) && isequal(figAxes(), ax1), ...
        'Ctrl+R again: every preview is current, nothing computed');
    app.FigurePreviewGeneration = app.FigurePreviewGeneration + 1;   % as a scan: every preview out of date
    setappdata(groot, 'redrawProbe', []);
    tm = timer('ExecutionMode', 'fixedRate', 'Period', 0.005, 'TimerFcn', @(t, ~) cancelRedraw(t, app));
    start(tm);
    R = app.onRedrawAllFigures();
    stop(tm); delete(tm);
    pr = getappdata(groot, 'redrawProbe');
    rmappdata(groot, 'redrawProbe');
    check(isstruct(pr) && pr.cancel == "on" && pr.redraw == "off" && R.canceled && numel(R.drawn) < nF - 1 ...
        && startsWith(string(app.StatusBar.Text), "Redraw All canceled: ") && app.SelectedFigure == 1 ...
        && ~app.FigureRedrawing && app.FigureRedrawAllButton.Enable == "on" && app.ToolbarCancelTool.Enable == "off" && app.CancelButton.Enable == "off", ...
        'the toolbar''s Cancel while Redraw All computes: it stops, says so, the shown figure is back, Cancel off again');

    % Undo and Redo across figures keep the tree, the containers and the selection together
    n0 = numel(app.Config.Figures);
    app.onUndoRedo("undo");   % the last Add
    synced = @() isequal(tree.SelectedNodes.NodeData, app.SelectedFigure) && app.FigureViewId == app.Config.Figures(app.SelectedFigure).id ...
        && all(ismember([app.FigureViews.Id], ["" app.Config.figureIds()])) && app.FigurePreviewPanel.Visible == "on" ...
        && nnz(arrayfun(@(p) p.Visible == "on", [app.FigureViews.Panel])) == 1 && isequal(app.FigureTreeMarks.current, [app.FigureTreeMarks.nodes.NodeData] == app.SelectedFigure);
    check(numel(app.Config.Figures) == n0 - 1 && synced(), 'Undo of an Add: the figure and its container go; the tree, the container shown and the bold node agree');
    app.onUndoRedo("redo");
    check(numel(app.Config.Figures) == n0 && app.SelectedFigure == n0 && synced(), 'Redo: the figure back and selected, in a container of its own');
    noFigures();
    check(numel(app.FigureViews) == 1 && app.FigureViews.Id == "" && app.FigurePreviewPanel.Visible == "on", ...
        'every figure removed: only the empty container is left');
    clear restore5m
    app.FigureAutoCheckBox.Value = false;
    app.Tabs.SelectedTab = app.TabData;
end

if S.sec("5n", "Apply to figures: an edit made with Ctrl held given to other figures, the window, its ticks remembered, Edit > Apply last change, Replot, Cancel, Undo")
    noFigures();
    app.selectTab(app.TabFigures);
    app.FigureAutoCheckBox.Value = true;
    app.FigureAutoPreviewSeconds = Inf;   % Auto draws every figure shown here, however loaded the machine
    restore5n = onCleanup(@() resetAutoLimit(app));
    app.ApplyTicked = string.empty(1, 0);
    app.ApplySeen = string.empty(1, 0);
    app.ApplyReplot = false;
    lookOf = @(k) app.FigureTreeMarks.look([app.FigureTreeMarks.nodes.NodeData] == k);
    app.onAddFigure("rasterPsth");
    app.onAddFigure("psth");
    app.onAddFigure("continuous");
    ids = app.Config.figureIds();
    app.onFigureSelected(1);
    app.onPanelSelected(2);   % the PSTH under the raster
    app.onKeyPress(pressed('control', {'control'}));
    held = app.CtrlHeld;
    FE.stack.Value = "groups";
    applyRows = [];
    answerDialog("Apply to figures", @(D) answerApply(D, [true false], false, true));
    FE.stack.ValueChangedFcn(FE.stack, []);
    F1 = app.Config.Figures;
    check(held && ~app.CtrlHeld && istable(applyRows) && isequal(string(applyRows.Figure).', ids(2:3)) ...
        && isequal(string(applyRows.Panel).', ["psth_1  (psth)" "continuous_1  (continuous)"]) ...
        && isequal(string(applyRows.Now).', ["Off (overlaid)" "Off (overlaid)"]) && all(applyRows.Apply) && applyCount == "2 of 2 will change", ...
        ['with Ctrl held the Stack edit opens Apply to figures: the other figures'' PSTH and continuous panels (not the raster), ' ...
        'each "Off (overlaid)" now, all ticked the first time']);
    check(isequal(applyFilter, [1 1 0 2]), ...
        'the window''s filters: the text "continuous" shows its one row, None on the rows shown leaves the hidden row ticked, "has it" shows none yet, and clearing brings both back');
    check(F1(1).panels(2).options.stack == "groups" && F1(2).panels(1).options.stack == "groups" && F1(3).panels(1).options.stack == "off" ...
        && app.FigureHistory.undoLabel() == "Stack to 1 panel" && contains(string(app.StatusBar.Text), "psth_1 in " + ids(2)) ...
        && app.ApplyMenu.Enable == "on", ...
        'Apply gives it to the panel ticked only, a step of the undo history of its own; the status bar names it');
    check(app.FigurePreviewState == "stale" && lookOf(1) == "stale" && lookOf(2) == "stale", ...
        'nothing is drawn again, with Auto on: the figure shown and the one changed are marked out of date');
    check(ismember(ids(2) + "/psth_1", app.ApplyTicked) && ismember(ids(3) + "/continuous_1", app.ApplySeen) ...
        && ~ismember(ids(3) + "/continuous_1", app.ApplyTicked), 'the ticks are remembered');

    % Edit > Apply last change: the same edit (not the step that gave it), the ticks as left, Replot
    applyRows = [];
    answerDialog("Apply to figures", @(D) answerApply(D, [true true], true, true));
    app.onApplyToFigures();
    F2 = app.Config.Figures;
    check(istable(applyRows) && isequal(applyRows.Apply.', [false false]) && isequal(string(applyRows.Now).', ["One row per group  (has it)" "Off (overlaid)"]) ...
        && applyCount == "1 of 1 will change" && F2(3).panels(1).options.stack == "groups", ...
        ['Apply last change offers the Stack edit again: the panel that has it gray and unticked, the other unticked as left; ' ...
        'All ticks the one that can change; applied']);
    check(app.SelectedFigure == 1 && lookOf(1) == "fresh" && lookOf(3) == "fresh" && lookOf(2) == "stale" && app.ApplyReplot, ...
        'Replot draws the figure shown and the one changed again (the one changed before stays out of date), back on the figure shown; the box is remembered');

    % a figure setting, canceled: the edit stays with its figure, drawn as after any edit
    app.ApplyReplot = false;
    app.onKeyPress(pressed('control', {'control'}));
    FE.fontSize.Value = 14;
    applyRows = [];
    answerDialog("Apply to figures", @(D) answerApply(D, [true false], false, false));
    FE.fontSize.ValueChangedFcn(FE.fontSize, []);
    F3 = app.Config.Figures;
    check(istable(applyRows) && ~ismember("Panel", applyRows.Properties.VariableNames) && isequal(string(applyRows.Figure).', ids(2:3)) ...
        && F3(1).style.FontSize == 14 && all([F3(2).style.FontSize F3(3).style.FontSize] ~= 14) && app.FigurePreviewState == "drawn", ...
        'a figure setting (Font size) lists the other figures, no panel column; Cancel leaves it to its figure, drawn again (Auto)');

    % Ctrl+Shift+A, then Undo
    answerDialog("Apply to figures", @(D) answerApply(D, [true false], false, true));
    app.onKeyPress(pressed('a', {'control' 'shift'}));
    F4 = app.Config.Figures;
    app.onUndoRedo("undo");
    check(F4(2).style.FontSize == 14 && F4(3).style.FontSize ~= 14 && app.Config.Figures(2).style.FontSize ~= 14 ...
        && app.Config.Figures(1).style.FontSize == 14, 'Ctrl+Shift+A gives the font size to the figure ticked; Undo takes that back only');

    % an edit that stays with its figure: no window
    applyRows = [];
    tm = answerDialog("Apply to figures", @(D) answerApply(D, false(1, 0), false, false));
    app.onKeyPress(pressed('control', {'control'}));
    FE.title.Value = 'Own title';
    FE.title.ValueChangedFcn(FE.title, []);
    stop(tm);
    delete(tm);
    check(isempty(applyRows) && contains(string(app.StatusBar.Text), "stays with its figure") && app.Config.Figures(1).title == "Own title", ...
        'a title edited with Ctrl held opens no window: the status bar says it stays with its figure');
    FE.title.Value = '';
    app.onConfigChanged("figure", FE.title);
    noFigures();
    clear restore5n
    app.FigureAutoCheckBox.Value = false;
    app.Tabs.SelectedTab = app.TabData;
end

if S.sec("5o", "Size: the page a figure is exported on, the preview shaped like it, redrawn without computing; Ctrl+Click on a panel selects it")
    noFigures();
    app.selectTab(app.TabFigures);
    app.FigureAutoCheckBox.Value = true;
    app.FigureAutoPreviewSeconds = Inf;   % Auto draws every figure shown here, however loaded the machine
    restore5o = onCleanup(@() resetAutoLimit(app));
    app.onAddFigure("rasterPsth");
    app.onAddFigure("psth");
    ids = app.Config.figureIds();
    app.onFigureSelected(1);
    app.onPanelSelected(1);
    app.refreshFigurePreview(Force=true);
    P = app.FigurePreviewPanel;
    shape = @() P.Position(3) / P.Position(4);
    cm0 = figureExportSize(app.Config.Export, [], app.Config.figureFor(1));
    check(app.FigurePreviewState == "drawn" && app.Config.Figures(1).size.source == "export" && string(FE.sizePreset.Value) == "Export tab size" ...
        && abs(shape() - cm0(1) / cm0(2)) < 0.03 && all(abs([FE.sizeWidth.Value FE.sizeHeight.Value] - cm0) < 0.01) && string(FE.sizeUnits.Value) == "cm", ...
        'a new figure follows the Export tab''s size: the editor shows it in cm, the preview is the shape of that page');

    % an own size typed: one undo step, the preview shaped like it and drawn again without computing
    app.FigurePreviewResult.marker = 1;   % computeFigure's result has none: it is still there when nothing was computed again
    FE.sizePreset.Value = '1200 x 800 px';
    FE.sizePreset.ValueChangedFcn(FE.sizePreset, []);
    z = app.Config.Figures(1).size;
    check(z.source == "own" && z.width == 1200 && z.height == 800 && z.units == "px" && string(FE.sizePreset.Value) == "1200 x 800 px" ...
        && FE.sizeWidth.Value == 1200 && FE.sizeHeight.Value == 800 && string(FE.sizeUnits.Value) == "px", ...
        'a size typed in the drop-down ("1200 x 800 px") is the figure''s own: the rows show it');
    check(abs(shape() - 1.5) < 0.03 && app.FigurePreviewState == "drawn" && isfield(app.FigurePreviewResult, 'marker') ...
        && contains(app.FigureHistory.undoLabel(), "Size"), ...
        'the preview is 3:2 now and drawn again from the figure it held (nothing computed again); the edit is one step named Size');
    spec = app.Config.figureFor(1);
    fx = newExportFigure(app.Config.Export, app.FigurePreviewResult, spec);
    cmx = fx.Position(3:4);
    close(fx);
    check(all(abs(cmx - [1200 800] / app.Config.Export.Dpi * 2.54) < 1e-6) && all(abs(figureExportSize(app.Config.Export, [], spec) - cmx) < 1e-9), ...
        'the export page is that size: 1200 x 800 px at the Export dpi');
    other = figureExportSize(app.Config.Export, [], app.Config.figureFor(2));
    check(app.Config.Figures(2).size.source == "export" && all(abs(other - [18 12]) < 1e-9), 'another figure keeps the Export tab''s size');

    % the lock, the units
    FE.sizeLock.Value = true;
    FE.sizeLock.ValueChangedFcn(FE.sizeLock, []);
    FE.sizeWidth.Value = 600;
    FE.sizeWidth.ValueChangedFcn(FE.sizeWidth, []);
    check(app.Config.Figures(1).size.lock && FE.sizeHeight.Value == 400 && app.Config.Figures(1).size.height == 400, ...
        'Lock ratio: a width of 600 gives a height of 400 (3:2 kept)');
    FE.sizeUnits.Value = 'in';
    FE.sizeUnits.ValueChangedFcn(FE.sizeUnits, []);
    z = app.Config.Figures(1).size;
    check(z.units == "in" && abs(z.width - 4) < 1e-9 && abs(z.height - 8 / 3) < 1e-3 && abs(shape() - 1.5) < 0.03, ...
        'the units changed to in: 600 x 400 px at 150 dpi is 4 x 2.667 in, the same page');
    FE.sizeHeight.Value = 3;
    FE.sizeHeight.ValueChangedFcn(FE.sizeHeight, []);
    check(abs(app.Config.Figures(1).size.width - 4.5) < 0.01 && abs(shape() - 1.5) < 0.03, 'locked, a height of 3 in gives a width of 4.5 in (to the thousandth the editor keeps)');
    FE.sizeLock.Value = false;
    FE.sizeLock.ValueChangedFcn(FE.sizeLock, []);

    % suggestions, Fit preview, a text that cannot be read, the Export tab size again
    FE.sizePreset.Value = 'Journal 2 column (7 x 4.5 in)';
    FE.sizePreset.ValueChangedFcn(FE.sizePreset, []);
    z = app.Config.Figures(1).size;
    check(z.source == "own" && z.width == 7 && z.height == 4.5 && z.units == "in" && abs(shape() - 7 / 4.5) < 0.03, 'a suggestion: Journal 2 column is 7 x 4.5 in');
    FE.sizePreset.Value = '15 x 10';
    FE.sizePreset.ValueChangedFcn(FE.sizePreset, []);
    z = app.Config.Figures(1).size;
    check(z.width == 15 && z.height == 10 && z.units == "in", 'no unit typed: the units shown (in)');
    before = app.Config.Figures(1).size;
    FE.sizePreset.Value = 'not a size';
    FE.sizePreset.ValueChangedFcn(FE.sizePreset, []);
    check(isequal(app.Config.Figures(1).size, before) && string(FE.sizePreset.Value) == "15 x 10 in" && contains(string(app.StatusBar.Text), "Size not read"), ...
        'text that is no size is refused: the status bar says so, the rows go back');
    FE.sizePreset.Value = 'Fit preview';
    FE.sizePreset.ValueChangedFcn(FE.sizePreset, []);
    z = app.Config.Figures(1).size;
    pane = app.FigurePreviewHost.InnerPosition(3:4) - 8;
    check(z.source == "own" && z.units == "in" && abs(z.width * 96 - pane(1)) < 0.5 && abs(z.height * 96 - pane(2)) < 0.5, ...
        'Fit preview: the preview area''s shape and size as it is');
    FE.sizePreset.Value = 'Export tab size';
    FE.sizePreset.ValueChangedFcn(FE.sizePreset, []);
    check(app.Config.Figures(1).size.source == "export" && abs(shape() - cm0(1) / cm0(2)) < 0.03, 'Export tab size again: the Export tab''s page');

    % the Export tab's size reaches the figures that follow it; Undo takes a size edit back
    app.ExportControls.Width.Value = 24;
    app.ExportControls.Height.Value = 12;
    app.onConfigChanged("export");
    check(abs(shape() - 2) < 0.03 && abs(FE.sizeWidth.Value - 24 / 2.54) < 2e-3, 'a wider Export tab size: the preview and the editor (in inches here) follow');
    app.ExportControls.Width.Value = 18;
    app.onConfigChanged("export");
    FE.sizePreset.Value = '700 x 800 px';
    FE.sizePreset.ValueChangedFcn(FE.sizePreset, []);
    app.onUndoRedo("undo");
    check(app.Config.Figures(1).size.source == "export" && abs(shape() - cm0(1) / cm0(2)) < 0.03 && string(FE.sizePreset.Value) == "Export tab size", ...
        'Undo takes the size back: the rows and the preview''s shape');

    % Ctrl+Click on a panel of the preview selects it and goes to its section; it is no edit
    app.onPanelSelected(1);
    if secOf("panel").Expanded; app.onFigureSectionToggled("panel"); end
    app.refreshFigurePreview(Force=true);
    P = app.FigurePreviewPanel;
    ax = findPanelAxes(P, "psth_1");
    ln = findall(ax, 'Type', 'line');
    label0 = app.FigureHistory.undoLabel();
    check(~isempty(ax.ButtonDownFcn) && (isempty(ln) || all(arrayfun(@(l) ~isempty(l.ButtonDownFcn), ln))), ...
        'the panels'' axes and what is drawn in them take a click (a line passes none to its axes)');
    ax.ButtonDownFcn(ax, []);   % a plain click: the figure reports no Ctrl
    check(app.SelectedPanel == 1, 'a click without Ctrl selects nothing');
    app.onFigurePanelClicked(ids(1), "psth_1", false, false);
    check(app.SelectedPanel == 1, 'a right-click (no Ctrl seen) is left to its menu');
    app.onKeyPress(pressed('control', {'control'}));
    app.onFigurePanelClicked(ids(1), "psth_1", true, false);
    check(app.SelectedPanel == 2 && secOf("panel").Expanded && app.FigureHistory.undoLabel() == label0, ...
        'Ctrl+Click on psth_1 selects it and opens the Selected panel section; no undo step, and no Apply to figures although Ctrl is held');
    app.onKeyRelease(struct('Key', 'control', 'Modifier', {{}}));
    app.onPanelSelected(1);
    h = app.onOpenFigureWindow();
    axw = findall(h, 'Type', 'axes', '-regexp', 'Tag', '^(axes|rasterAxes)$');
    app.onFigurePanelClicked(ids(1), "psth_1", true, true);
    check(~isempty(axw) && all(arrayfun(@(a) ~isempty(a.ButtonDownFcn), axw)) && app.SelectedPanel == 2 && app.Tabs.SelectedTab == app.TabFigures, ...
        'a Ctrl+Click in Open in window selects the panel in the app''s editor too');
    delete(h);
    noFigures();
    clear restore5o
    app.FigureAutoCheckBox.Value = false;
    app.Tabs.SelectedTab = app.TabData;
end

if S.sec("5p", "remembered panel options: a new panel starts from the last set, Reset panel options, Forget, the preference; the color fields' swatches (the chooser replaced)")
    noFigures();
    app.selectTab(app.TabFigures);
    app.FigureAutoCheckBox.Value = false;   % nothing here needs drawing
    restoreAuto5p = onCleanup(@() autoBoxOn(app));
    restorePicker5p = onCleanup(@() pickerBack(app));
    app.onForgetPanelOptions();
    forgotten = isempty(fieldnames(app.PanelOptions));
    app.onAddFigure("rasterPsth");
    app.onPanelSelected(1);   % the raster
    FE.tickWidth.Value = 2;
    FE.tickWidth.ValueChangedFcn(FE.tickWidth, []);
    app.onPanelSelected(2);   % the PSTH
    FE.stackSpacing.Value = 1.5;
    FE.stackSpacing.ValueChangedFcn(FE.stackSpacing, []);
    FE.yLimMode.Value = "rows";
    FE.yLimMode.ValueChangedFcn(FE.yLimMode, []);
    FE.measure.Value = "count";
    FE.measure.ValueChangedFcn(FE.measure, []);
    M = app.PanelOptions;
    check(forgotten && isfield(M, 'raster') && isequal(fieldnames(M.raster), {'tickWidth'}) && M.raster.tickWidth == 2 ...
        && isfield(M, 'psth') && isempty(setxor(string(fieldnames(M.psth)), ["stackSpacing" "yLimMode" "measure"])) ...
        && M.psth.stackSpacing == 1.5 && M.psth.yLimMode == "rows" && M.psth.measure == "count", ...
        'the options set on a panel are remembered by type, only those set (the raster''s tick width; the PSTH''s stack spacing, Y limits mode, measure)');
    app.onNewPanel(Type="psth", Where="right", Remembered=true);
    pR = app.Config.Figures(1).panels(end);
    msgR = string(app.StatusBar.Text);
    app.onNewPanel(Type="psth", Where="right");
    pD = app.Config.Figures(1).panels(end);
    app.onNewPanel(Type="raster", Where="below", Remembered=true);
    rR = app.Config.Figures(1).panels(end);
    PT5p = EphysAnalysisConfig.panelTypes();
    defPsth = PT5p.DefaultOptions{PT5p.Type == "psth"};
    check(pR.options.stackSpacing == 1.5 && pR.options.yLimMode == "rows" && pR.options.measure == "count" && contains(msgR, "last set on a PSTH panel") ...
        && isequaln(pD.options, defPsth) && rR.options.tickWidth == 2 && app.Config.Figures(1).panels(1).options.tickWidth == 2, ...
        'a new panel made with Remembered starts from them (the status bar says so); without, from the type''s defaults');
    app.PanelOptions.raster.rasterSort = "noSuchParameter";   % a trial parameter this dataset has not
    app.PanelOptions.psth.histStyle = 5;                       % the wrong class: preferences of older code
    app.onNewPanel(Type="raster", Where="below", Remembered=true);
    rS = app.Config.Figures(1).panels(end);
    app.onNewPanel(Type="psth", Where="below", Remembered=true);
    pS = app.Config.Figures(1).panels(end);
    check(rS.options.rasterSort == "" && rS.options.tickWidth == 2 && pS.options.histStyle == defPsth.histStyle && pS.options.stackSpacing == 1.5, ...
        'a remembered sort by a trial parameter the active dataset lacks, and a value of the wrong class, are not pre-filled');
    app.PanelOptions.raster = rmfield(app.PanelOptions.raster, 'rasterSort');
    app.PanelOptions.psth = rmfield(app.PanelOptions.psth, 'histStyle');
    answerDialog('New panel', @rememberedAnswer);
    app.onNewPanel();
    seen5p = getappdata(groot, 'rememberedSeen');
    if isappdata(groot, 'rememberedSeen'); rmappdata(groot, 'rememberedSeen'); end
    pW = app.Config.Figures(1).panels(end);
    check(isequal(seen5p, "count") && pW.type == "psth" && pW.options.measure == "count" && pW.options.stackSpacing == 1.5 ...
        && pW.options.yLimMode == "rows", ...
        'the New panel window starts the PSTH''s Measure at the remembered "count"; the panel takes the other remembered options too');
    nU5p = numel(app.FigureHistory.Undo);
    app.onResetPanelOptions();
    pZ = app.Config.Figures(1).panels(app.SelectedPanel);
    check(pZ.id == pW.id && isequaln(pZ.options, defPsth) && (numel(app.FigureHistory.Undo) == nU5p + 1 || nU5p == app.FigureHistory.Depth) ...
        && string(app.UndoMenu.Text) == "Undo Reset panel options" && ~isfield(app.PanelOptions, 'psth') && isfield(app.PanelOptions, 'raster'), ...
        'Edit > Reset panel options to defaults: the selected panel''s type''s defaults as one named step; that type''s remembered options forgotten, not the others''');
    app.onUndoRedo("undo");
    check(app.Config.Figures(1).panels(app.SelectedPanel).options.measure == "count", 'Undo gives the panel its options back');
    app.savePreferences();
    P5p = AppPrefs.getpref(g, 'PanelOptions');
    app.onForgetPanelOptions();
    check(isstruct(P5p) && isfield(P5p, 'raster') && P5p.raster.tickWidth == 2 && isempty(fieldnames(app.PanelOptions)) ...
        && isempty(fieldnames(AppPrefs.getpref(g, 'PanelOptions'))) && contains(string(app.StatusBar.Text), "Forgot"), ...
        'the remembered options are a preference (PanelOptions); Edit > Forget remembered panel options empties it and writes it');

    % the color fields' swatches, the chooser in the tests' place (uisetcolor is modal)
    names5p = string(fieldnames(FE.swatch)).';
    wrapped = arrayfun(@(f) isvalid(FE.swatch.(f)) && FE.swatch.(f).Tag == "colorSwatch" && FE.swatch.(f).UserData == FE.(f) ...
        && FE.swatch.(f).Parent == FE.(f).Parent, names5p);
    toSwatch = arrayfun(@(e) isprop(e.Target, 'Tag') && strcmp(e.Target.Tag, 'colorSwatch'), app.FigureSearchIndex);
    check(numel(names5p) >= 14 && all(wrapped) && ~any(toSwatch) && all(ismember(["tickColor" "layerColor" "ovColor" "errFace"], names5p)), ...
        sprintf('every color field of the editor (%d) has a swatch beside it; the search goes to the field, not the swatch', numel(names5p)));
    app.onPanelSelected(1);   % the raster
    app.gotoFigureSection("options");   % open, whatever the sections before left collapsed
    b5p = FE.swatch.tickColor;
    plain = string(b5p.Text) == "..." && b5p.Enable == "on" && shown(FE.tickColor);
    app.ColorPicker = @(c, t) [1 0 0];
    b5p.ButtonPushedFcn(b5p, []);
    picked = app.Config.Figures(1).panels(1).options.tickColor == "#ff0000" && string(FE.tickColor.Value) == "#ff0000" ...
        && isequal(b5p.BackgroundColor, [1 0 0]) && string(b5p.Text) == "" && string(app.UndoMenu.Text) ~= "Undo Edit";
    app.onUndoRedo("undo");   % one step: the ticks' groups again (the history may be at its Depth: counts do not tell)
    undone = app.Config.Figures(1).panels(1).options.tickColor == "groups" && string(b5p.Text) == "...";
    app.onUndoRedo("redo");
    nU5p = numel(app.FigureHistory.Undo);
    check(plain && picked && undone && app.Config.Figures(1).panels(1).options.tickColor == "#ff0000", ...
        sprintf('a color picked with the ticks'' swatch ("groups": a plain button) is the field''s, as #rrggbb, one named step (%s); the swatch shows it', ...
        app.UndoMenu.Text));
    app.ColorPicker = @(c, t) 0;   % Cancel
    b5p.ButtonPushedFcn(b5p, []);
    canceled = numel(app.FigureHistory.Undo) == nU5p && isempty(app.FigureHistory.Redo) && app.Config.Figures(1).panels(1).options.tickColor == "#ff0000";
    FE.tickColor.Value = 'blue';
    FE.tickColor.ValueChangedFcn(FE.tickColor, []);
    typed = isequal(b5p.BackgroundColor, [0 0 1]) && app.Config.Figures(1).panels(1).options.tickColor == "blue";
    app.onUndoRedo("undo");
    check(canceled && typed && string(FE.tickColor.Value) == "#ff0000" && isequal(b5p.BackgroundColor, [1 0 0]), ...
        'Cancel changes nothing; a color typed still works and the swatch follows it, and Undo');
    app.ColorPicker = @(c, t) [0 0 1];
    FE.firstSpikeDialog.ButtonPushedFcn(FE.firstSpikeDialog, []);
    d5p = findall(groot, 'Type', 'figure', 'Tag', 'latencyDialog');
    D5p = d5p.UserData;
    grayedSwatch = D5p.ColorSwatch.Enable == "off";
    D5p.Enabled.Value = true;
    D5p.Enabled.ValueChangedFcn(D5p.Enabled, []);
    D5p.ColorSwatch.ButtonPushedFcn(D5p.ColorSwatch, []);
    inField = string(D5p.Color.Value) == "#0000ff" && isequal(D5p.ColorSwatch.BackgroundColor, [0 0 1]);
    D5p.Ok.ButtonPushedFcn(D5p.Ok, []);
    check(grayedSwatch && inField && ~isvalid(d5p) && app.Config.Figures(1).panels(1).options.firstSpike.color == "#0000ff", ...
        'the First-spike marks window''s Color has a swatch too (grayed while off): the color picked goes into its field, and OK gives it the panel');
    noFigures();
    app.onForgetPanelOptions();
    clear restoreAuto5p restorePicker5p
    app.Tabs.SelectedTab = app.TabData;
end

if S.sec("5q", "figure templates (the row above the preview: Save as, Apply into figures or as a new one, Update, Export, Remove, Import, the issue window) and the Apply last change button")
    noFigures();
    app.selectTab(app.TabFigures);
    app.FigureAutoCheckBox.Value = false;   % nothing here needs drawing
    restoreAuto5q = onCleanup(@() autoBoxOn(app));
    app.onKeyRelease(struct('Key', 'control', 'Modifier', {{}}));   % a Ctrl key an earlier section pressed (5k), let go: edits stay with their figure
    tplFolder5q = FigureTemplate.folder();
    if isfolder(tplFolder5q); rmdir(tplFolder5q, 's'); end
    restoreTpl5q = onCleanup(@() removeTemplates(tplFolder5q));
    app.refreshTemplates();
    drawnow;
    row5q = app.FigureTemplateDropDown.Parent;
    tplButtons5q = [app.FigureTemplateApplyButton app.FigureTemplateSaveButton app.FigureTemplateUpdateButton ...
        app.FigureTemplateRemoveButton app.FigureTemplateImportButton app.FigureTemplateExportButton];
    check(all(arrayfun(@(h) h.Parent == row5q, [tplButtons5q app.FigureApplyLastButton])) && app.FigureTemplateIssueLink.Parent == row5q ...
        && isequal(string(app.FigureTemplateDropDown.Items), "(no templates)") && app.FigureTemplateSaveButton.Enable == "on" ...
        && all([app.FigureTemplateApplyButton.Enable app.FigureTemplateUpdateButton.Enable app.FigureTemplateRemoveButton.Enable ...
        app.FigureTemplateExportButton.Enable] == "off") && row5q.Parent.RowHeight{row5q.Layout.Row} - sum(row5q.Padding([2 4])) >= 30 ...
        && isequal(app.FigureTemplateApplyButton.BackgroundColor, [0.16 0.52 0.28]) && isequal(app.FigureTemplateRemoveButton.BackgroundColor, [0.80 0.25 0.20]), ...
        'the template row above the preview: the list, Apply... (green), Save as..., Update, Remove (red), Import..., Export..., Report issue and Apply last change; with no template Apply, Update, Remove and Export are off; buttons at least 30 px');
    app.onAddFigure("rasterPsth");
    app.onAddFigure("psth");
    app.onAddFigure("continuous");
    ids5q = app.Config.figureIds();
    app.onFigureSelected(1);
    FE.fontSize.Value = 15;
    FE.fontSize.ValueChangedFcn(FE.fontSize, []);
    tip5q = string(app.FigureApplyLastButton.Tooltip);
    check(app.FigureApplyLastButton.Enable == "on" && app.ApplyMenu.Enable == "on" && startsWith(tip5q, "Apply last change to figures: Font size (") ...
        && contains(tip5q, "+Shift+A)"), sprintf('Apply last change is on with the Edit menu''s item, its tooltip naming the step (%s)', tip5q));
    applyRows = [];
    answerDialog("Apply to figures", @(D) answerApply(D, [false false], false, false));
    app.FigureApplyLastButton.ButtonPushedFcn(app.FigureApplyLastButton, []);
    check(istable(applyRows) && isequal(string(applyRows.Figure).', ids5q(2:3)) && app.Config.Figures(2).style.FontSize ~= 15, ...
        'the button opens Apply to figures for that step, as Edit > Apply last change does (Cancel: nothing given)');

    % Save as...: from a script, then from its window
    app.onFigureTemplate("save", Name="Card", Description="a raster over a PSTH");
    T5q = FigureTemplate.list();
    check(isequal(T5q.Name, "Card") && T5q.Description == "a raster over a PSTH" && string(app.FigureTemplateDropDown.Value) == "Card" ...
        && all([app.FigureTemplateApplyButton.Enable app.FigureTemplateUpdateButton.Enable app.FigureTemplateRemoveButton.Enable ...
        app.FigureTemplateExportButton.Enable] == "on") && contains(string(app.StatusBar.Text), "as the template Card") ...
        && contains(string(app.FigureTemplateDropDown.Tooltip), "2 x 1: raster, psth"), ...
        'Save as... keeps the figure shown as a template: listed and picked, its shape in the tooltip, the buttons on');
    answerDialog("Save the figure as a template", @(D) saveTemplateAnswer(D, "Dialog card"));
    app.onFigureTemplate("save");
    check(isequal(sort(FigureTemplate.list().Name).', ["Card" "Dialog card"]) && string(app.FigureTemplateDropDown.Value) == "Dialog card" ...
        && isequal(getappdata(groot, 'templateOffered'), app.Config.Figures(1).id), ...
        'Save as... asks the name in its window (the figure''s id offered) and picks the new template');
    FigureTemplate.remove("Dialog card");
    app.refreshTemplates("Card");

    % Apply... in its window: the figures picked, one undo step
    app.onFigureSelected(2);
    titled5q = app.Config;
    titled5q.Figures(3).title = "Own title";
    titled5q.Figures(3).enabled = false;
    app.applyConfig(titled5q, Action="Title");
    F05q = app.Config.Figures;
    nUndo5q = numel(app.FigureHistory.Undo);
    templateRows = [];
    answerDialog("Apply figure template", @(D) answerTemplate(D, [false true true], figureSettingParts().Part, false));
    app.onApplyTemplate();
    F15q = app.Config.Figures;
    check(istable(templateRows) && height(templateRows) == 3 && isequal(templateRows.Apply.', [false true false]) ...
        && endsWith(string(templateRows.Figure(2)), "(shown)"), 'the window lists every figure, the one shown ticked');
    check(isequal([F15q(2).panels.type], ["raster" "psth"]) && isequal([F15q(3).panels.type], ["raster" "psth"]) ...
        && F15q(2).style.FontSize == 15 && F15q(3).style.FontSize == 15 && F15q(3).title == "Own title" && ~F15q(3).enabled ...
        && isequaln(F15q(1), F05q(1)) && numel(app.FigureHistory.Undo) == nUndo5q + 1 ...
        && app.FigureHistory.undoLabel() == "Apply template Card to 2 figures" && contains(string(app.StatusBar.Text), "Applied template Card"), ...
        'Apply copies the template into the two figures ticked (their panels, appearance), each keeping its title and enabled, as one undo step; the others untouched');
    app.onUndoRedo("undo");
    check(isequaln(app.Config.Figures, F05q), 'Undo takes the template back off both');
    app.onApplyTemplate("Card", New=true);
    check(numel(app.Config.Figures) == 4 && app.SelectedFigure == 4 && isequal([app.Config.Figures(4).panels.type], ["raster" "psth"]) ...
        && app.Config.Figures(4).autoId && app.FigureHistory.undoLabel() == "Apply template Card as a new figure", ...
        'as a new figure: the whole template, an automatic id, selected');
    app.onApplyTemplate("Card", To=app.Config.Figures(3).id, Parts="style");
    check(app.Config.Figures(3).style.FontSize == 15 && isequal([app.Config.Figures(3).panels.type], "continuous"), ...
        'one part only (Appearance): the figure keeps its panels');

    % Update, Export, Remove, Import
    app.onFigureSelected(1);
    FE.fontSize.Value = 9;
    FE.fontSize.ValueChangedFcn(FE.fontSize, []);
    app.onFigureTemplate("update", Confirm=false);
    U5q = FigureTemplate.load("Card");
    check(U5q.figure.style.FontSize == 9 && U5q.description == "a raster over a PSTH" && app.Config.Figures(4).style.FontSize == 15, ...
        'Update makes the template again from the figure shown, its description kept; a figure it was applied to keeps its settings');
    ex5q = string(tempname) + ".json";
    app.onFigureTemplate("export", File=ex5q);
    app.onFigureTemplate("remove", Confirm=false);
    gone5q = isempty(FigureTemplate.list()) && isequal(string(app.FigureTemplateDropDown.Items), "(no templates)");
    app.onFigureTemplate("import", File=ex5q, Confirm=false);
    check(isfile(ex5q) && gone5q && isequal(FigureTemplate.list().Name, "Card") && string(app.FigureTemplateDropDown.Value) == "Card" ...
        && FigureTemplate.load("Card").figure.style.FontSize == 9, ...
        'Export writes it to a file, Remove deletes it (the list empty), Import brings it back by its own name');
    delete(ex5q);

    % the issue window about templates: its title and the template in its report
    app.onFigureTemplate("issue");
    w5q = findall(groot, 'Type', 'figure', 'Name', 'Report an issue');
    fields5q = findall(w5q, 'Type', 'uieditfield');
    areas5q = findall(w5q, 'Type', 'uitextarea');
    report5q = strjoin(string(vertcat(areas5q.Value)), newline);
    check(isscalar(w5q) && any(string({fields5q.Value}) == "[Bug] Figure templates: ") && contains(report5q, "Figure template Card") ...
        && contains(report5q, """schema"": ""ephys-figure-template"""), ...
        'Report issue opens the issue window titled "Figure templates: ", the template''s file in its report');
    delete(w5q);

    noFigures();
    clear restoreAuto5q restoreTpl5q
    app.Tabs.SelectedTab = app.TabData;
end

if S.sec("5u", "the figure's First-spike latency section: one block for every panel, its rows by method, the onset line, the preview computing it once")
    noFigures();
    groupedBy("Depth");
    app.selectTab(app.TabFigures);
    app.FigureAutoCheckBox.Value = false;   % the preview is drawn when asked
    restoreAuto5u = onCleanup(@() autoBoxOn(app));
    app.onAddFigure("rasterPsth");
    app.onPanelSelected(1);   % the raster: its marks on
    FE.firstSpikeDialog.ButtonPushedFcn(FE.firstSpikeDialog, []);
    dU = findall(groot, 'Type', 'figure', 'Tag', 'latencyDialog');
    DU = dU.UserData;
    DU.Enabled.Value = true;
    DU.Enabled.ValueChangedFcn(DU.Enabled, []);
    DU.Ok.ButtonPushedFcn(DU.Ok, []);
    app.onPanelSelected(2);   % the PSTH: its box plot on
    FE.latencyBoxDialog.ButtonPushedFcn(FE.latencyBoxDialog, []);
    dU = findall(groot, 'Type', 'figure', 'Tag', 'latencyDialog');
    DU = dU.UserData;
    DU.Enabled.Value = true;
    DU.Enabled.ValueChangedFcn(DU.Enabled, []);
    DU.Ok.ButtonPushedFcn(DU.Ok, []);
    secU = app.FigureSections([app.FigureSections.Name] == "latency");
    check(shown(FE.latMethod) && shown(FE.latFrom) && shown(FE.latBaseline) && shown(FE.latCusum) && ~shown(FE.latRate) ...
        && ~shown(FE.latSurprise) && ~shown(FE.latAlpha) && string(FE.latMethod.Value) == "first" ...
        && contains(FE.latNote.Text, "raster_1 (marks)") && contains(FE.latNote.Text, "psth_1 (box plot)") ...
        && secU.Super == "figure" && FE.latBaseFrom.Enable == "off", ...
        sprintf(['the figure''s First-spike latency section (Figure): Method first, the window, baseline and onset rows; ' ...
        'the note names the panels that read it ("%s")'], FE.latNote.Text));
    FE.latMethod.Value = "surprise";
    app.onConfigChanged("figure", FE.latMethod);
    LU = app.Config.Figures(1).latency;
    surpriseRows = shown(FE.latRate) && shown(FE.latSurprise) && ~shown(FE.latAlpha);
    undoMethod = string(app.UndoMenu.Text) == "Undo Method";
    FE.latMethod.Value = "poisson";
    app.onConfigChanged("figure", FE.latMethod);
    poissonRows = shown(FE.latRate) && ~shown(FE.latSurprise) && shown(FE.latAlpha);
    FE.latTo.Value = 150;
    app.onConfigChanged("figure", FE.latTo);
    FE.latBaseline.Value = "window";
    app.onConfigChanged("figure", FE.latBaseline);
    L2U = app.Config.Figures(1).latency;
    check(LU.method == "surprise" && surpriseRows && undoMethod && poissonRows && L2U.method == "poisson" ...
        && abs(L2U.maxSec - 0.15) < 1e-12 && L2U.minSec == 0 && L2U.baseline == "window" && FE.latBaseFrom.Enable == "on" ...
        && isequal(L2U.baselineWindow, [-0.1 0]) && L2U.cusumBinSec == 0.002, ...
        ['a method is one named step ("Undo Method"), showing its own rows (the rate and burst with surprise, the rate ' ...
        'and alpha with poisson); To (ms) sets the window''s end; a window of its own enables its fields, the values ' ...
        'not edited kept exactly']);
    FE.onsetLine.Value = "groups";   % the PSTH's onset line
    app.onConfigChanged("figure", FE.onsetLine);
    shownOn = shown(FE.onsetLine) && app.Config.Figures(1).panels(2).options.onsetLine == "groups" ...
        && contains(FE.latNote.Text, "psth_1 (box plot, onset line)");
    app.refreshFigurePreview(Force=true);
    FU = app.FigurePreviewResult;
    RU1 = FU.panels(1).layers(1).R;
    RU2 = FU.panels(2).layers(1).R;
    oneEntry = isscalar(FU.latency.entries) && isequal(FU.latency.entries.panels, ["raster_1" "psth_1"]);
    check(shownOn && app.FigurePreviewState == "drawn" && oneEntry && isequaln(RU1.latency, RU2.latency) ...
        && RU1.latency.method == "poisson" && abs(RU1.latency.window(2) - 0.15) < 1e-12 && isfield(RU2, 'onset') ...
        && ~isfield(RU1, 'onset'), ...
        ['the preview takes the latencies once for the raster and the PSTH (F.latency: one entry read by both), by the ' ...
        'figure''s block, and the onset for the PSTH that draws it']);
    K0 = app.Runner.FigureCache;
    FE.latMethod.Value = "surprise";
    app.onConfigChanged("figure", FE.latMethod);
    app.refreshFigurePreview(Force=true);
    K1 = app.Runner.FigureCache;
    isNew = arrayfun(@(e) ~any(arrayfun(@(o) o.kind == e.kind && isequaln(o.key, e.key), K0)), K1);
    newKinds = unique([K1(isNew).kind]);
    check(app.FigurePreviewState == "drawn" && app.FigurePreviewResult.panels(1).layers(1).R.latency.method == "surprise" ...
        && isequal(newKinds, "latency"), ...
        sprintf(['an edit of the method computes the latencies again and nothing else: no panel, no onset (new in the ' ...
        'cache: %s)'], strjoin(newKinds, ", ")));
    I = figureSettingItems(app.Config.Figures(1));
    keysU = I.Key(I.Part == "latency");
    check(all(ismember(["latency.method" "latency.minSec" "latency.cusumThreshold"], keysU)) ...
        && ~any(keysU == "latency.baselineWindow") && any(figureSettingParts().Part == "latency"), ...
        'Copy settings lists the figure''s latency block, setting by setting (the baseline window with the baseline)');
    app.onAddFigure("continuous");   % no panel that can read it: no section
    check(~shown(FE.latMethod) && ~app.FigureSections([app.FigureSections.Name] == "latency").Visible, ...
        'a figure without a raster, PSTH or heat map has no First-spike latency section');
    noFigures();
    clear restoreAuto5u
    app.Tabs.SelectedTab = app.TabData;
end

if S.sec("5s", "an edit of text alone (a label, a panel title) set on the drawn preview: nothing computed or drawn again, the drawing a whole one's; a side drawn again")
    noFigures();
    app.selectTab(app.TabFigures);
    app.FigureAutoCheckBox.Value = true;
    app.FigureAutoPreviewSeconds = Inf;   % Auto draws here, however loaded the machine
    restore5s = onCleanup(@() resetAutoLimit(app));
    app.onAddFigure("rasterPsth");
    app.refreshFigurePreview(Force=true);
    fid = app.Config.Figures(1).id;
    axR = findPanelAxes(app.FigurePreviewPanel, "raster_1");
    axP = findPanelAxes(app.FigurePreviewPanel, "psth_1");
    secs0 = app.FigurePreviewSeconds;
    app.FigurePreviewSeconds = 1234;   % a compute would set it: an edit set in place leaves it
    app.onFigureAxisEdited(fid, "psth_1", struct('xLabel', "Lag (s)"));
    app.onFigureAxisEdited(fid, "raster_1", struct('yLabel', "Trial number"));
    kept5s = isequal(findPanelAxes(app.FigurePreviewPanel, "raster_1"), axR) && isequal(findPanelAxes(app.FigurePreviewPanel, "psth_1"), axP) ...
        && app.FigurePreviewSeconds == 1234 && app.FigurePreviewState == "drawn";
    app.onPanelSelected(2);
    FE.panelTitle.Value = "Rate";   % a panel title of its own, none before: drawn again, as an empty title has no looks
    app.onConfigChanged("figure", FE.panelTitle);
    axP2 = findPanelAxes(app.FigurePreviewPanel, "psth_1");
    redrawn5s = ~isequal(axP2, axP) && app.FigurePreviewSeconds ~= 1234;
    app.FigurePreviewSeconds = 1234;
    FE.panelTitle.Value = "Rate by group";   % its own before and after: set in place (the editor's row)
    app.onConfigChanged("figure", FE.panelTitle);
    kept5s = kept5s && redrawn5s && isequal(findPanelAxes(app.FigurePreviewPanel, "psth_1"), axP2) && app.FigurePreviewSeconds == 1234 ...
        && app.FigurePreviewState == "drawn";
    shown5s = previewTexts(app.FigurePreviewPanel, ["raster_1" "psth_1"]);
    rmappdata(app.FigurePreviewPanel, 'FigureDrawing');   % the next preview draws everything
    app.refreshFigurePreview(Force=true);
    whole5s = previewTexts(app.FigurePreviewPanel, ["raster_1" "psth_1"]);
    [same5s, why5s] = sameTexts5s(shown5s, whole5s);
    check(kept5s && same5s && app.FigurePreviewResult.spec.panels(2).title == "Rate by group" && shown5s(2).x == "Lag (s)" ...
        && shown5s(1).y == "Trial number" && shown5s(2).t == "Rate by group" && app.FigureHistory.undoLabel() ~= "", ...
        sprintf(['an x and a y label (right-click) and a panel title of its own (the editor) are set on the drawn preview: the same axes, ' ...
        'nothing computed (%.2f s before), the badge Drawn; a first title of its own is drawn again; a whole drawing makes the same ' ...
        'texts and places (%s)'], secs0, why5s));
    axP = findPanelAxes(app.FigurePreviewPanel, "psth_1");
    app.onFigureAxisEdited(fid, "psth_1", struct('ySide', "right"));
    axP3 = findPanelAxes(app.FigurePreviewPanel, "psth_1");
    check(~isequal(axP3, axP) && strcmp(axP3.YAxisLocation, 'right') && app.FigurePreviewState == "drawn", ...
        'a side is not text alone: the panel is drawn again');
    noFigures();
    clear restore5s
    app.Tabs.SelectedTab = app.TabData;
end

if S.sec("5v", "a figure on the probe: the Probe layout section's rows wired to the config, the picker's one entry, the preview of every tile, Undo, the tree, Generate")
    savedConfig();
    noFigures();
    exported();
    app.FigureAutoPreviewSeconds = Inf;   % a preview slowed by a loaded machine must not leave the next one out of date
    restore5v = onCleanup(@() resetAutoLimit(app));
    app.FigureAutoCheckBox.Value = false;   % no redraw per edit: the preview is pressed below
    app.selectTab(app.TabFigures);
    app.onAddFigure("rasterPsth");
    kP = app.SelectedFigure;
    pid = app.Config.Figures(kP).id;
    rowOf5v = @(s) s.Grid.Layout.Row;
    if ~app.FigureSupers(1).Expanded; app.onFigureSuperToggled("figure"); end
    if ~secOf("probe").Expanded; app.onFigureSectionToggled("probe"); end
    check(secOf("probe").Super == "figure" && secOf("probe").Key == "" && secOf("probe").Title == "Probe layout" ...
        && rowOf5v(secOf("sessions")) < rowOf5v(secOf("probe")) && rowOf5v(secOf("probe")) < rowOf5v(secOf("arrangement")) ...
        && shown(FE.prbEnabled) && ~FE.prbEnabled.Value && ~shown(FE.prbLayout) && ~shown(FE.prbNote) && shown(FE.obsPerGroup) ...
        && ~app.Config.Figures(kP).probe.enabled, ...
        'the Probe layout section: in the Figure supersection after Sessions, no key; only "On the probe" until it is ticked');
    FE.prbEnabled.Value = true;
    app.onConfigChanged("figure", FE.prbEnabled);
    check(app.Config.Figures(kP).probe.enabled && app.Config.isProbeFigure(pid) && shown(FE.prbLayout) && shown(FE.prbMaxTiles) ...
        && shown(FE.prbLeaders) && shown(FE.prbNote) && ~shown(FE.obsPerGroup) && FE.sesEnabled.Enable == "off" && FE.prbEnabled.Enable == "on" ...
        && FE.prbOverlap.Enable == "off" && FE.prbScale.Enable == "off" && FE.prbLeaders.Enable == "off" && FE.prbLanes.Enable == "off" ...
        && app.FiguresDatasetDropDown.Enable == "on" && string(app.UndoMenu.Text) == "Undo Probe layout", ...
        ['On the probe ticked: probe.enabled in the config, its rows shown (Overlap, Lanes, Tile scale and Leaders off for a ' ...
        'schematic), Per trial group hidden, Across sessions off, the Dataset drop-down on; Undo Probe layout']);
    FE.prbLayout.Value = "physical";
    app.onConfigChanged("figure", FE.prbLayout);
    physOn = FE.prbOverlap.Enable == "on" && FE.prbScale.Enable == "on" && FE.prbLeaders.Enable == "on" && FE.prbLanes.Enable == "off";
    FE.prbOverlap.Value = "lanes";
    app.onConfigChanged("figure", FE.prbOverlap);
    check(physOn && FE.prbLanes.Enable == "on" && app.Config.Figures(kP).probe.layout == "physical" ...
        && app.Config.Figures(kP).probe.overlap == "lanes" && string(app.UndoMenu.Text) == "Undo Probe layout: Overlap", ...
        'Physical enables Overlap, Tile scale and Leaders, Lanes beside the shank Lanes too; a row is a named edit (Undo Probe layout: Overlap)');
    % every row reaches the config (gather), and a config reaches the rows (apply)
    want5v = struct('lanes', 3, 'shanks', [1 2], 'channels', 1:4, 'depthRange', [0 400], 'maxTiles', 5, 'maxPerSite', 2, ...
        'tileWidth', 0.8, 'tileHeight', 0.7, 'tileScale', 1.5, 'labels', "full", 'sharedY', false, 'scaleTile', false, ...
        'showSites', false, 'leaders', false);
    FE.prbLanes.Value = 3;
    FE.prbShanks.Value = '1, 2';
    FE.prbChannels.Value = '1:4';
    FE.prbDepth.Value = '0 400';
    FE.prbMaxTiles.Value = 5;
    FE.prbPerSite.Value = 2;
    FE.prbTileWidth.Value = 0.8;
    FE.prbTileHeight.Value = 0.7;
    FE.prbScale.Value = 1.5;
    FE.prbLabels.Value = "full";
    FE.prbSharedY.Value = false;
    FE.prbScaleTile.Value = false;
    FE.prbShowSites.Value = false;
    FE.prbLeaders.Value = false;
    app.onConfigChanged("figure", FE.prbMaxTiles);
    prG = app.Config.Figures(kP).probe;
    bad5v = strings(1, 0);
    for f5v = string(fieldnames(want5v)).'
        if ~isequal(string(reshape(prG.(f5v), 1, [])), string(reshape(want5v.(f5v), 1, []))); bad5v(end+1) = f5v; end %#ok<AGROW>
    end
    check(isempty(bad5v) && prG.layout == "physical" && prG.overlap == "lanes" && prG.enabled, ...
        sprintf('every Probe layout row reaches probe.* (gather; the lists parsed, the depth range lo hi)%s', ...
        strjoin(" -- not: " + bad5v, "")));
    cfgP = app.Config;
    pr0 = EphysAnalysisConfig.defaults("FigureProbe");
    pr0.enabled = true;
    pr0.shanks = 1;
    pr0.depthRange = [-50 300];
    pr0.labels = "none";
    pr0.tileWidth = 0.05;   % under the spinner's 0.1: shown as 0.1, kept until the spinner is changed
    cfgP.Figures(kP).probe = pr0;
    app.applyConfig(cfgP);
    shownOk = FE.prbEnabled.Value && string(FE.prbLayout.Value) == "schematic" && string(FE.prbOverlap.Value) == "nudge" ...
        && FE.prbLanes.Value == pr0.lanes && string(FE.prbShanks.Value) == "1" && string(FE.prbChannels.Value) == "" ...
        && string(FE.prbDepth.Value) == "-50 300" && FE.prbMaxTiles.Value == pr0.maxTiles && FE.prbPerSite.Value == pr0.maxPerSite ...
        && FE.prbTileWidth.Value == 0.1 && FE.prbTileHeight.Value == pr0.tileHeight && FE.prbScale.Value == pr0.tileScale ...
        && string(FE.prbLabels.Value) == "none" && FE.prbSharedY.Value == pr0.sharedY && FE.prbScaleTile.Value == pr0.scaleTile ...
        && FE.prbShowSites.Value == pr0.showSites && FE.prbLeaders.Value == pr0.leaders && FE.prbOverlap.Enable == "off";
    FE.prbDepth.Value = '';
    FE.prbShanks.Value = '';
    app.onConfigChanged("figure", FE.prbDepth);
    prA = app.Config.Figures(kP).probe;
    check(shownOk && prA.tileWidth == 0.05 && isempty(prA.depthRange) && isempty(prA.shanks), ...
        'a config''s probe block reaches every row (apply); a tile width the spinner cannot show is kept; blank Depth range and Shanks are all');
    % Across sessions and On the probe exclude each other
    FE.prbEnabled.Value = false;
    FE.sesEnabled.Value = true;
    app.onConfigChanged("figure", FE.sesEnabled);
    sesOff = FE.prbEnabled.Enable == "off" && FE.sesEnabled.Enable == "on" && shown(FE.prbEnabled) && ~shown(FE.prbLayout);
    FE.sesEnabled.Value = false;
    FE.prbEnabled.Value = true;
    app.onConfigChanged("figure", FE.prbEnabled);
    check(sesOff && FE.sesEnabled.Enable == "off" && FE.prbEnabled.Enable == "on" && app.Config.Figures(kP).probe.enabled ...
        && ~app.Config.Figures(kP).sessions.enabled, 'Across sessions ticked grays On the probe out, and the reverse');
    % the picker: one entry, the probe; the count line and the section's note
    app.refreshFigureObservations(Force=true);
    src5v = app.Runner.source(app.ActiveIdx);
    T5v = figureProbeTiles(src5v, app.Config.figureFor(kP));
    TP = app.FigureObservations;
    nT5v = height(T5v);
    check(nT5v >= 2 && istable(TP) && height(TP) == 1 && TP.kind == "probe" && startsWith(TP.label, "the probe: " + nT5v + " units") ...
        && numel(app.FigureObservationDropDown.Items) == 1 && string(app.FigureObservationDropDown.Items{1}) == TP.label ...
        && app.FigureObsPrevButton.Enable == "off" && app.FigureObsNextButton.Enable == "off" && app.FigureObservationStar.Enable == "off" ...
        && startsWith(string(FE.obsCount.Text), "Laid out on the probe: " + nT5v + " tiles") ...
        && startsWith(string(FE.prbNote.Text), nT5v + " tiles: " + nT5v + " units"), ...
        sprintf('the picker lists one entry, "%s", < and > and its star off; the count line "%s"; the note "%s"', ...
        string(app.FigureObservationDropDown.Items{1}), string(FE.obsCount.Text), string(FE.prbNote.Text)));
    % the preview: every tile, each panel an axes of its own
    app.refreshFigurePreview(Force=true);
    PF5v = app.FigurePreviewResult;
    np5v = numel(app.Config.Figures(kP).panels);
    ax5v = findall(app.FigurePreviewPanel, 'Type', 'axes');
    ax5v = ax5v(arrayfun(@(a) isappdata(a, 'ProbeTile'), ax5v));
    check(app.FigurePreviewState == "drawn" && isstruct(PF5v) && string(PF5v.kind) == "probeFigure" && PF5v.nTiles == nT5v ...
        && numel(ax5v) == PF5v.nTiles * np5v && startsWith(string(app.FigurePreviewLabel.Text), pid + " on " + string(src5v.name) + ":") ...
        && contains(string(app.FigurePreviewLabel.Text), PF5v.nTiles + " tiles"), ...
        sprintf('Preview computes and draws every tile: %d axes (%d tiles x %d panels); the status line "%s"', numel(ax5v), ...
        PF5v.nTiles, np5v, string(app.FigurePreviewLabel.Text)));
    % the tree: under On the probe
    setGroupBy(app, "observe");
    node5v = figureNode(app.FiguresTree, kP);
    check(isscalar(node5v) && startsWith(string(node5v.Parent.Text), "On the probe") && contains(string(node5v.Text), ", per unit"), ...
        sprintf('the tree groups the figure under On the probe ("%s": "%s")', string(node5v.Parent.Text), string(node5v.Text)));
    % Generate: one page for the dataset, every tile on it
    R5v = app.onGenerateFigure(Datasets=app.ActiveIdx);
    files5v = split(R5v.Files(1), "; ");
    check(istable(R5v) && height(R5v) == 1 && R5v.Kind == "figure" && R5v.Plot == pid && R5v.Status == "done" ...
        && startsWith(R5v.Message, PF5v.nTiles + " tile") && isscalar(files5v) && isfile(files5v) && endsWith(files5v, ".png") ...
        && startsWith(string(app.StatusBar.Text), sprintf("Generated %s: 1 page (%d tiles) on 1 dataset(s), 1 file(s)", pid, PF5v.nTiles)), ...
        sprintf('Generate writes one page for the dataset (%s); the status bar counts the page and its tiles', files5v(1)));
    app.onRemoveFigure();
    app.onSaveConfig();
    app.Tabs.SelectedTab = app.TabData;
    clear restore5v
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


function filterBy(app, subject, tags, mode, opts)
%filterBy  The Data tab's filter as picked or typed: Subject SUBJECT, Tags TAGS, MODE "any" | "all", applied as their callbacks do.
%   NotSubject, NotTags and Search (all blank by default) fill the "not" drop-downs and the Search field.
arguments
    app
    subject
    tags
    mode
    opts.NotSubject = '(any)'
    opts.NotTags = '(any)'
    opts.Search = ''
end
app.SubjectFilterDropDown.Value = char(subject);
app.TagFilterDropDown.Value = char(tags);
app.TagFilterModeDropDown.Value = char(mode);
app.NotSubjectFilterDropDown.Value = char(opts.NotSubject);
app.NotTagFilterDropDown.Value = char(opts.NotTags);
app.SearchFilterField.Value = char(opts.Search);
app.refreshDatasetsTable();
end


function was = setSourceTags(app, key, tags)
%setSourceTags  Give the loaded source KEY the tags TAGS, as if its manifest held them; WAS the ones it had.
src = app.Runner.Sources(key);
was = src.tags;
src.tags = tags;
app.Runner.Sources(key) = src;
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


function saveTemplateAnswer(D, name)
%saveTemplateAnswer  In the Save the figure as a template window: note the name offered (appdata templateOffered), type NAME, Save.
setappdata(groot, 'templateOffered', string(D.Name.Value));
D.Name.Value = char(name);
D.Save.ButtonPushedFcn(D.Save, []);
end


function removeTemplates(folder)
%removeTemplates  The templates folder the section made, gone (its cleanup).
if isfolder(folder); rmdir(folder, 's'); end
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
P.Stack.Value = "items";
setappdata(groot, 'newPanelSeen', seen);
press(D, "Ok");
end


function pickerBack(app)
%pickerBack  The color chooser back to uisetcolor, if the app is still there (a section's cleanup).
if isvalid(app); app.ColorPicker = @uisetcolor; end
end


function rememberedAnswer(D)
%rememberedAnswer  In the New panel window: pick PSTH, note its Measure (appdata rememberedSeen), OK.
D.Pick("psth");
P = D.Params();
setappdata(groot, 'rememberedSeen', string(P.Measure.Value));
press(D, "Ok");
end


function copyFigureDialog(D)
%copyFigureDialog  In the Copy figure settings window: From the second figure, None, tick the Alignment part and the layout, Find "font", note the count, Copy.
D.From.Value = 2;
D.From.ValueChangedFcn(D.From, []);
targets = string({D.Targets.CheckedNodes.Text});
press(D, "None");
nodes = findall(D.Settings, 'Type', 'uitreenode');
align = nodes(string({nodes.Text}) == "Alignment");
layout = nodes(startsWith(string({nodes.Text}), "Grid and panels"));
D.Settings.CheckedNodes = [align; align.Children; layout];
D.Settings.CheckedNodesChangedFcn(D.Settings, []);
D.Find.ValueChangingFcn(D.Find, struct('Value', 'font'));
nodes = findall(D.Settings, 'Type', 'uitreenode');
found = string({nodes(arrayfun(@(n) isnumeric(n.NodeData) && isscalar(n.NodeData), nodes)).Text});
D.Find.ValueChangingFcn(D.Find, struct('Value', ''));
seen = struct('count', string(D.Count.Text), 'from', string(D.From.Items{D.From.ItemsData == D.From.Value}), ...
    'targets', targets, 'found', found);
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


function cancelRedraw(tm, app)
%cancelRedraw  Once Redraw All computes a figure, note what the app shows and click the toolbar's Cancel (appdata redrawProbe).
if ~app.FigureRedrawing || app.FigurePreviewState ~= "computing"; return; end
stop(tm);
setappdata(groot, 'redrawProbe', struct('cancel', string(app.ToolbarCancelTool.Enable), 'redraw', string(app.FigureRedrawAllButton.Enable)));
clickTool(app, "cancel");
end


function cancelGenerate(tm, app)
%cancelGenerate  Once a Generate's run has started (the runner's Results emptied), note what the app shows, ask for a preview, press Cancel (appdata genProbe).
if ~app.Running || isempty(app.Runner) || height(app.Runner.Results) > 0; return; end
stop(tm);
app.refreshFigurePreview(Force=true);
setappdata(groot, 'genProbe', struct('generate', string(app.GenerateFigureMenu.Enable), 'redraw', string(app.FigureRedrawAllButton.Enable), 'run', string(app.RunButton.Enable), ...
    'cancel', string(app.CancelButton.Enable), 'preview', string(app.FigurePreviewLabel.Text), 'state', app.FigurePreviewState));
app.CancelButton.ButtonPushedFcn(app.CancelButton, []);   % the Export tab's Cancel, as a click
end


function resetAutoLimit(app)
%resetAutoLimit  The figure preview's auto limit back to AutoPreviewSeconds (5d-5f raise it), while the app lives.
if isvalid(app); app.FigureAutoPreviewSeconds = app.AutoPreviewSeconds; end
end


function autoBoxOn(app)
%autoBoxOn  Auto ticked again, if the app is still there (a section's cleanup).
if isvalid(app) && isvalid(app.FigureAutoCheckBox); app.FigureAutoCheckBox.Value = true; end
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


function [F, fig, D] = runPreviewCode(file) %#ok<STOUT> the script sets them
%runPreviewCode  Run a script of Export code (EphysAnalysisScript.preview) in a workspace of its own: its figure result and window, and D, every variable it left.
run(file);
D = struct();
for v = string(who).'
    if ~ismember(v, ["file" "F" "fig" "D"]); D.(v) = eval(v); end
end
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


function T = previewTexts(P, ids)
%previewTexts  Each panel's axes place and its x label, y label and title in the preview P: text, place, interpreter and font size.
T = struct('id', {}, 'pos', {}, 'x', {}, 'y', {}, 't', {}, 'texts', {});
for id = reshape(ids, 1, [])
    ax = findPanelAxes(P, id);
    L = [ax.XLabel ax.YAxis(1).Label ax.Title];
    T(end+1) = struct('id', id, 'pos', ax.Position, 'x', strjoin(string(L(1).String), " "), 'y', strjoin(string(L(2).String), " "), ...
        't', strjoin(string(L(3).String), " "), 'texts', {arrayfun(@(l) {string(l.String), l.Position, string(l.Interpreter), l.FontSize}, ...
        L, 'UniformOutput', false)}); %#ok<AGROW>
end
end


function [ok, why] = sameTexts5s(A, B)
%sameTexts5s  Two previewTexts alike: places within 1e-6 px (data units for the texts), the same strings, interpreters and sizes.
ok = numel(A) == numel(B);
why = "the same";
if ~ok; why = "the panels"; return; end
for i = 1:numel(A)
    if any(abs(A(i).pos - B(i).pos) > 1e-6); ok = false; why = A(i).id + ": its axes' place"; return; end
    for j = 1:numel(A(i).texts)
        a = A(i).texts{j};
        b = B(i).texts{j};
        if ~isequal(a{1}, b{1}) || any(abs(a{2} - b{2}) > 1e-6) || a{3} ~= b{3} || a{4} ~= b{4}
            ok = false; why = A(i).id + ": text " + j + " (" + strjoin(a{1}, " ") + ")"; return
        end
    end
end
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
