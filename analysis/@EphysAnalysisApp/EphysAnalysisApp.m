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
    %                trial or recording scope), the epoch window (fixed, or
    %                between the event and a stop event) and the trial
    %                selection (filter, response words, pairing flags, up to
    %                two groupBy parameters), with a live count of epochs and
    %                groups on the active dataset
    %     Plots      the plots: add (psth, raster, evoked, rate, tuning,
    %                heatmap, probemap), remove, duplicate, reorder, enable;
    %                an editor whose rows follow the kind, the plot's own event
    %                / window / selection when "use defaults" is off, and a
    %                preview on the active dataset (auto-preview while a
    %                preview takes under 2 s)
    %     Export     figure formats, folder and file-name pattern, the report
    %                (HTML / PDF), Validate, Plan, Run over the ticked
    %                datasets (cancelable), results, open the report / folder
    %     Log        what the runner reported
    %
    %   File menu: New / Open / Open recent / Save / Save As / Generate
    %   script (compact | standalone) / Open preprocessing app / Close. Help
    %   menu: the wiki page of the tab shown, the documentation home and the
    %   analysis quick start.
    %
    %   Preferences (getpref group 'EphysAnalysisApp'): FigurePosition,
    %   LastConfigFile, RecentConfigs, ScriptFolder, AutoPreview,
    %   PreviewMaxMB (signal previews of larger extracts wait for the Preview
    %   button).
    %
    %   Usage
    %     EphysAnalysisApp                      % the last config, or defaults
    %     EphysAnalysisApp("D:\EPHYS")          % a pipeline project root
    %     EphysAnalysisApp("D:\EPHYS", OutputRoot="E:\out")
    %     EphysAnalysisApp("D:\out\subj1_day1") % one dataset's output folder
    %     EphysAnalysisApp("am_quicklook.json") % an analysis config
    %     app = EphysAnalysisApp(...);          % keep a handle
    %
    %   See also EphysAnalysisConfig, EphysAnalysisRunner, EphysAnalysisScript,
    %   EphysPreprocessingApp.

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
        HelpMenu   matlab.ui.container.Menu
        StatusBar  matlab.ui.control.Label

        % --- Data tab ---
        ConfigNameField    matlab.ui.control.EditField
        ConfigDescField    matlab.ui.control.EditField
        SourceModeDropDown matlab.ui.control.DropDown
        RootField          matlab.ui.control.EditField
        BrowseRootButton   matlab.ui.control.Button
        OutputRootField    matlab.ui.control.EditField
        BrowseOutputButton matlab.ui.control.Button
        NamePatternField   matlab.ui.control.EditField
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
        AlignAxes          matlab.ui.control.UIAxes
        AlignTrialsTable   matlab.ui.control.Table

        % --- Plots tab ---
        PlotsListBox       matlab.ui.control.ListBox
        AddKindDropDown    matlab.ui.control.DropDown
        AddPlotButton      matlab.ui.control.Button
        RemovePlotButton   matlab.ui.control.Button
        DuplicatePlotButton matlab.ui.control.Button
        UpPlotButton       matlab.ui.control.Button
        DownPlotButton     matlab.ui.control.Button
        PlotEditor struct = struct()             % plot-editor controls by field
        PlotAlignControls struct = struct()      % the plot's own event / window / selection
        PlotsDatasetDropDown matlab.ui.control.DropDown
        PreviewPanel       matlab.ui.container.Panel
        PreviewButton      matlab.ui.control.Button
        AutoPreviewCheckBox matlab.ui.control.CheckBox
        PrevPageButton     matlab.ui.control.Button
        NextPageButton     matlab.ui.control.Button
        PageLabel          matlab.ui.control.Label
        PreviewLabel       matlab.ui.control.Label

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
        SelectedPlot (1,1) double = 0       % the plot in the editor (index into Config.Plots)
        PreviewResult = []                  % last preview's result
        PreviewPage (1,1) double = 1
        PreviewPages (1,1) double = 1
        PreviewSeconds (1,1) double = Inf   % time the last preview took (auto-preview under 2 s)
        Running (1,1) logical = false
        LastReportFiles (1,:) string = string.empty(1,0)
        LastExportFolder (1,1) string = ""
    end

    properties (Constant)
        PrefGroup = 'EphysAnalysisApp'
        WikiURL = "https://github.com/dstolz/ephys_analysis/wiki"
        AutoPreviewSeconds = 2
    end

    methods
        function obj = EphysAnalysisApp(source, opts)
            %EphysAnalysisApp  Build the app; open SOURCE (config, project root or output folder).
            arguments
                source (1,1) string = ""
                opts.OutputRoot (1,1) string = ""
            end
            obj.buildUI();
            obj.loadPreferences(source == "");
            if source ~= ""
                obj.openSource(source, OutputRoot=opts.OutputRoot);
            end
            obj.updateTitle();
            if nargout == 0
                clear obj
            end
        end

        % --- UI construction ---
        buildUI(obj)
        buildMenus(obj)
        buildDataTab(obj)
        buildAlignTab(obj)
        buildPlotsTab(obj)
        buildExportTab(obj)
        buildLogTab(obj)
        C = buildAlignControls(obj, parent, changed)
        applyAlignControls(obj, C, ref, win, sel)
        [ref, win, sel] = gatherAlignControls(obj, C)
        fillAlignItems(obj, C)

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
        syncPlotEditorEnable(obj)
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
        onOpenPreprocessingApp(obj)
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

        % --- Plots tab ---
        onAddPlot(obj, kind)
        onRemovePlot(obj)
        onDuplicatePlot(obj)
        onMovePlot(obj, step)
        onPlotSelected(obj, k)
        refreshPreview(obj, opts)
        onPreviewPage(obj, step)
        onAutoPreviewToggled(obj)
        autoPreview(obj)

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
    end
end
