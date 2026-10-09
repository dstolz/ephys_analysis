classdef EphysAnalysisApp < handle
    %EPHYSANALYSISAPP  GUI for quick-look figures of processed ephys datasets.
    %   EphysAnalysisApp edits one EphysAnalysisConfig and draws it with an
    %   EphysAnalysisRunner. It computes nothing itself: previews, plans and
    %   runs all go through the runner (computePlot, renderPlotFigures, plan,
    %   run), so what the app shows is what a generated script writes.
    %
    %   Tabs
    %     Data       where the datasets are: a pipeline project (root + output
    %                root) or a list of output folders; Scan; a table of what
    %                each dataset holds (signals, units, detections, behavior,
    %                trials, pairing); for the active dataset its files, digital
    %                lines, behavior and units
    %     Alignment  the config's Defaults: the event reference (any digital
    %                line or "Trial", onset / offset, first / last / all / nth,
    %                trial or recording scope, and a sequence of events that
    %                must or must not follow it: editSequence), the epoch window (fixed, or
    %                between the event and a stop event) and the trial
    %                selection (filter, response words, pairing flags, up to
    %                two groupBy parameters), with a live count of epochs and
    %                groups on the active dataset; "Epoch Diagram", under
    %                the Epoch window, opens the epoch diagram for them
    %     Plots      the plots, in a tree grouped by plot type (or by source,
    %                layout, enabled / off, or not at all: Group by): add
    %                (psth, raster, evoked, rate, tuning, heatmap, probemap,
    %                corrmap), remove, duplicate, reorder, enable;
    %                Ctrl- or Shift-click selects several plots: the editor
    %                then shows only the options they all have, with the
    %                first one's values, an edit goes to every one of them
    %                (only what it changed: spreadPlotEdit), the preview
    %                draws the first, and a bar over it and a banner in the
    %                editor say so (showPlotSelection); Remove and Duplicate
    %                act on them all;
    %                an editor in collapsible sections (units & channels,
    %                event reference, epoch window, trial selection, bins &
    %                baseline, the kind's options, appearance) showing only the
    %                options the plot uses -- its event / window / selection
    %                the Alignment tab's while "Use default" is ticked, its own
    %                once edited -- and a preview on the active dataset
    %                (auto-preview while a preview takes under 2 s), drawn
    %                in the design picked above it (PlotDesign), a badge under
    %                it saying where it is (Computing, Drawn, Out of date,
    %                Failed ...: setPreviewState). "Epoch Diagram",
    %                under the epoch window, opens the epoch diagram
    %                (EpochDiagram): a window that stays above the app and
    %                draws, on the active dataset, the digital lines as TTL
    %                traces, each event, window and epoch and what is
    %                dropped, redrawn on every edit (onShowEpochs)
    %     Export     figure formats, folder and file-name pattern, the report
    %                (HTML / PDF), Validate, Plan, Run over the ticked
    %                datasets (cancelable), results, open the report / folder
    %     Log        what the runner reported
    %
    %   File menu: New / Open / Open recent / Save / Save As / Generate
    %   script (compact | standalone) / Open pipeline app / Close. Design
    %   menu: the plot designs (choosing one redraws every plot), save the
    %   preview's look as a design, import or delete a design, your designs
    %   folder. Help menu: the wiki page of the tab shown, the documentation
    %   home and the analysis quick start; Report an issue and Request a
    %   feature on GitHub (onReportIssue); About.
    %
    %   Toolbar (buildToolbar): the most used commands as icons, each with
    %   its menu shortcut in the tooltip: New / Open / Save config; Scan,
    %   Preview; Validate, Plan, Run, Cancel; Open report, Open figure
    %   folder; Open pipeline app; Help for this tab.
    %
    %   Preferences (getpref group 'EphysAnalysisApp'): FigurePosition,
    %   LastConfigFile, RecentConfigs, ScriptFolder, AutoPreview,
    %   PreviewMaxMB (signal previews of larger extracts wait for the Preview
    %   button), PlotSectionsCollapsed (the plot editor's collapsed sections),
    %   PlotGroupBy (how the plot tree groups), PlotGroupsCollapsed (its
    %   collapsed groups).
    %
    %   Usage
    %     EphysAnalysisApp                      % the last config, or defaults
    %     EphysAnalysisApp("D:\EPHYS")          % a pipeline project root
    %     EphysAnalysisApp("D:\EPHYS", OutputRoot="E:\out", NamePattern=..., Recordings="separate")
    %     EphysAnalysisApp("D:\EPHYS", Datasets=["subj1/day1" "subj1/day2"])  % only these ticked (root-relative keys)
    %     EphysAnalysisApp("D:\out\subj1_day1") % one dataset's output folder
    %     EphysAnalysisApp("am_quicklook.json") % an analysis config
    %     app = EphysAnalysisApp(...);          % keep a handle
    %
    %   See also EphysAnalysisConfig, EphysAnalysisRunner, EphysAnalysisScript,
    %   EphysPipelineApp.

    properties
        Fig   matlab.ui.Figure
        Tabs  matlab.ui.container.TabGroup
        TabData    matlab.ui.container.Tab
        TabAlign   matlab.ui.container.Tab
        TabPlots   matlab.ui.container.Tab
        TabExport  matlab.ui.container.Tab
        TabLog     matlab.ui.container.Tab
        FileMenu   matlab.ui.container.Menu
        RecentMenu matlab.ui.container.Menu
        DesignMenu matlab.ui.container.Menu
        HelpMenu   matlab.ui.container.Menu
        StatusBar  matlab.ui.control.Label

        % --- Toolbar (buildToolbar): the most used commands ---
        Toolbar             matlab.ui.container.Toolbar
        ToolbarValidateTool matlab.ui.container.toolbar.PushTool   % off while a run goes
        ToolbarPlanTool     matlab.ui.container.toolbar.PushTool   % off while a run goes
        ToolbarRunTool      matlab.ui.container.toolbar.PushTool   % off while a run goes
        ToolbarCancelTool   matlab.ui.container.toolbar.PushTool   % on only while a run goes
        ToolbarReportTool   matlab.ui.container.toolbar.PushTool   % on once a run wrote a report
        ToolbarFolderTool   matlab.ui.container.toolbar.PushTool   % on once a run wrote figures

        % --- Data tab ---
        ConfigNameField    matlab.ui.control.EditField
        ConfigDescField    matlab.ui.control.EditField
        SourceModeDropDown matlab.ui.control.DropDown
        RootField          matlab.ui.control.EditField
        BrowseRootButton   matlab.ui.control.Button
        OutputRootField    matlab.ui.control.EditField
        BrowseOutputButton matlab.ui.control.Button
        NamePatternField   matlab.ui.control.EditField
        RecordingsDropDown matlab.ui.control.DropDown   % Source.Recordings (Open Ephys recording mode)
        FoldersArea        matlab.ui.control.TextArea
        AddFolderButton    matlab.ui.control.Button
        ScanButton         matlab.ui.control.Button
        ScanLabel          matlab.ui.control.Label
        DatasetsTable      matlab.ui.control.Table
        InventoryTable     matlab.ui.control.Table
        LinesTable         matlab.ui.control.Table
        BehaviorLabel      matlab.ui.control.Label
        ParamsTable        matlab.ui.control.Table
        UnitsTable         matlab.ui.control.Table
        MemoryLabel        matlab.ui.control.Label

        % --- Alignment tab (Config.Defaults) ---
        AlignDatasetDropDown matlab.ui.control.DropDown
        AlignControls struct = struct()          % buildAlignControls handles
        AlignSummaryLabel  matlab.ui.control.Label
        AlignEpochsButton  matlab.ui.control.Button     % the epoch diagram of the Defaults (onShowEpochs)
        AlignAxes          matlab.ui.control.UIAxes
        AlignTrialsTable   matlab.ui.control.Table
        SequenceDialog     matlab.ui.Figure = matlab.ui.Figure.empty   % the Event sequence window (editSequence), when open

        % --- Plots tab ---
        PlotsTree          matlab.ui.container.Tree         % the plots under groups (plotGroups); a plot's node holds its index in NodeData
        PlotGroupDropDown  matlab.ui.control.DropDown       % how the tree groups: plot type, source, layout, status, none
        AddKindDropDown    matlab.ui.control.DropDown
        AddPlotButton      matlab.ui.control.Button
        RemovePlotButton   matlab.ui.control.Button
        DuplicatePlotButton matlab.ui.control.Button
        UpPlotButton       matlab.ui.control.Button
        DownPlotButton     matlab.ui.control.Button
        PlotEditorPanel    matlab.ui.container.Panel        % the editor's panel (its title counts the plots selected)
        PlotEditorGrid     matlab.ui.container.GridLayout   % the editor's column of sections
        PlotSections struct = struct([])         % the editor's sections (formSection), top to bottom
        PlotEditor struct = struct()             % plot-editor controls by field
        PlotAlignControls struct = struct()      % the plot's event / window / selection (buildAlignControls)
        PlotsDatasetDropDown matlab.ui.control.DropDown
        DesignDropDown     matlab.ui.control.DropDown   % the plot design (PlotDesign), for every plot
        SaveDesignButton   matlab.ui.control.Button
        PreviewPanel       matlab.ui.container.Panel
        PreviewButton      matlab.ui.control.Button
        AutoPreviewCheckBox matlab.ui.control.CheckBox
        PrevPageButton     matlab.ui.control.Button
        NextPageButton     matlab.ui.control.Button
        PageLabel          matlab.ui.control.Label
        PreviewLabel       matlab.ui.control.Label
        PreviewBadge struct = struct()           % the preview's state badge: Grid, Icon, Text (setPreviewState)
        PreviewGrid        matlab.ui.container.GridLayout   % the SelectionBar (row 1, 0 px while one plot is selected) over the PreviewPanel
        SelectionBar struct = struct()           % the bar over the preview while several plots are selected: Grid, Text (showPlotSelection)

        % --- Export tab ---
        ExportControls struct = struct()
        ReportControls struct = struct()
        ValidateButton     matlab.ui.control.Button
        PlanButton         matlab.ui.control.Button
        RunButton          matlab.ui.control.Button
        CancelButton       matlab.ui.control.Button
        OpenReportButton   matlab.ui.control.Button
        OpenFolderButton   matlab.ui.control.Button
        IssuesTable        matlab.ui.control.Table
        ResultsTable       matlab.ui.control.Table
        RunLabel           matlab.ui.control.Label

        % --- Log tab ---
        LogArea            matlab.ui.control.TextArea
    end

    properties
        Config EphysAnalysisConfig = EphysAnalysisConfig()   % working copy
        SavedConfigStruct struct = struct()                   % last saved / opened state
        Applying (1,1) logical = false      % applyConfig is pushing values (suppresses onConfigChanged)
        RecentConfigs (1,:) string = string.empty(1,0)
        ScriptFolder (1,1) string = ""
        PreviewMaxMB (1,1) double = 500     % larger signal extracts are previewed only on request

        Runner = []                         % the EphysAnalysisRunner (rebuilt by Scan; owns the caches)
        ScannedSource struct = struct()     % Config.Source when the runner last scanned
        ActiveIdx (1,1) double = 0          % the active dataset (index into Runner.Outputs)
        Ticked (1,:) logical = logical.empty(1, 0)   % datasets ticked to run
        SelectedPlot (1,1) double = 0       % the plot in the editor (index into Config.Plots), the one previewed
        AlsoSelected (1,:) double = zeros(1, 0)   % the other plots selected with it (tree multi-select), in the order picked; edits go to them too
        ShownPlot struct = struct()         % the plot in the editor as its controls showed it before the edit (spreadPlotEdit)
        PlotGroupsCollapsed (1,:) string = string.empty(1,0)   % keys of the tree's groups the user collapsed
        PreviewResult = []                  % last preview's result
        PreviewPage (1,1) double = 1
        PreviewPages (1,1) double = 1
        PreviewSeconds (1,1) double = Inf   % time the last preview took (auto-preview under 2 s)
        PreviewState (1,1) string = "idle"  % what the preview badge says (setPreviewState)
        PreviewRedo (1,1) logical = false   % an edit or a Preview press came in while one computed: it ends Out of date
        EpochDiagramWindow = []             % the EpochDiagram window, while open (onShowEpochs)
        EpochDiagramFor (1,1) string = "plot"   % what it draws: "plot" (the editor's) | "defaults"
        Running (1,1) logical = false
        LastReportFiles (1,:) string = string.empty(1,0)
        LastExportFolder (1,1) string = ""
    end

    properties (Constant)
        PrefGroup = 'EphysAnalysisApp'
        WikiURL = "https://github.com/dstolz/ephys_analysis/wiki"
        RepoURL = "https://github.com/dstolz/ephys_analysis"        % the repository the issue items file against
        AutoPreviewSeconds = 2
    end

    methods
        function obj = EphysAnalysisApp(source, opts)
            %EphysAnalysisApp  Build the app; open SOURCE (config, project root or output folder).
            arguments
                source (1,1) string = ""
                opts.OutputRoot (1,1) string = ""
                opts.NamePattern (1,1) string = ""
                opts.Recordings (1,1) string = ""
                opts.Datasets (1,:) string = string.empty(1,0)
            end
            obj.buildUI();
            obj.loadPreferences(source == "");
            if source ~= ""
                obj.openSource(source, OutputRoot=opts.OutputRoot, NamePattern=opts.NamePattern, ...
                    Recordings=opts.Recordings, Datasets=opts.Datasets);
            end
            obj.updateTitle();
            if nargout == 0
                clear obj
            end
        end

        % --- UI construction ---
        buildUI(obj)
        buildMenus(obj)
        buildToolbar(obj)
        buildDataTab(obj)
        buildAlignTab(obj)
        buildPlotsTab(obj)
        buildExportTab(obj)
        buildLogTab(obj)
        C = buildAlignControls(obj, parents, changed)
        applyAlignControls(obj, C, ref, win, sel)
        [ref, win, sel] = gatherAlignControls(obj, C, ref, win, sel)
        fillAlignItems(obj, C)
        editSequence(obj, holder, mode, lineCtl, edgeCtl, done)

        % --- config model ---
        cfg = gatherConfig(obj)
        applyConfig(obj, cfg, opts)
        onConfigChanged(obj, what)
        updateTitle(obj)
        ok = confirmDiscard(obj)
        S = gatherSourceSection(obj)
        applySourceSection(obj, S)
        syncSourceEnable(obj)
        X = gatherExportSection(obj)
        applyExportSection(obj, X)
        P = gatherReportSection(obj)
        applyReportSection(obj, P)
        p = gatherPlotEditor(obj)
        applyPlotEditor(obj)
        applyPlotEditorDefaults(obj)
        syncPlotEditor(obj)
        layoutPlotEditor(obj)
        refreshPlotList(obj)

        % --- file menu ---
        onNewConfig(obj)
        onOpenConfig(obj)
        ok = openConfigFile(obj, file)
        ok = onSaveConfig(obj)
        ok = onSaveConfigAs(obj, file)
        addRecentConfig(obj, file)
        refreshRecentMenu(obj)
        onGenerateScript(obj, kind, file)
        onOpenPipelineApp(obj)
        openSource(obj, source, opts)
        p = defaultConfigFolder(obj)

        % --- Data tab ---
        onSourceModeChanged(obj)
        onBrowseRoot(obj, which)
        onAddFolder(obj)
        onScan(obj)
        refreshDatasetsTable(obj)
        onDatasetsTableEdited(obj, evt)
        onDatasetCellSelection(obj, evt)
        selectDataset(obj, idx)
        refreshDatasetInfo(obj)
        idx = tickedDatasetIndices(obj)

        % --- Alignment tab ---
        refreshAlignPreview(obj)
        onFilterHelp(obj)

        % --- the epoch diagram (Alignment tab, plot editor) ---
        onShowEpochs(obj, what)
        refreshEpochDiagram(obj)

        % --- Plots tab ---
        onAddPlot(obj, kind)
        onRemovePlot(obj)
        onDuplicatePlot(obj)
        onMovePlot(obj, step)
        onPlotSelected(obj, k)
        onPlotTreeSelected(obj, nodes)
        ks = selectedPlots(obj)
        showPlotSelection(obj)
        onPlotGroupChanged(obj)
        onPlotGroupToggled(obj, node, collapsed)
        onPlotSectionToggled(obj, name)
        onPlotAlignEdited(obj, part)
        onPlotDefaultToggled(obj)
        refreshPreview(obj, opts)
        setPreviewState(obj, state, opts)
        onCancelPreview(obj)
        onPreviewPage(obj, step)
        rememberAesthetics(obj, id, rules)
        onAutoPreviewToggled(obj)
        autoPreview(obj)

        % --- plot designs (Design menu, the preview's Design row) ---
        onDesignChosen(obj, name)
        onSaveDesign(obj, name, description)
        onImportDesign(obj, file)
        onDeleteDesign(obj, name, opts)
        onDesignsFolder(obj, action, folder)
        refreshDesigns(obj)

        % --- Export tab ---
        issues = onValidate(obj)
        T = onPlan(obj)
        R = onRunExport(obj, opts)
        onCancelRun(obj)
        onOpenReport(obj)
        onOpenExportFolder(obj)

        % --- app-wide ---
        loadPreferences(obj, openLast)
        savePreferences(obj)
        onClose(obj)
        setStatus(obj, message)
        log(obj, message)
        selectTab(obj, tab)
        onTabChanged(obj)
        url = helpURL(obj, page)
        onHelp(obj, page)
        onReportIssue(obj, kind)
        body = issueReport(obj, kind, opts)
        [url, truncated] = issueURL(obj, kind, title, body)
    end
end
