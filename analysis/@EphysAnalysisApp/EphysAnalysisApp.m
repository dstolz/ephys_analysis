classdef EphysAnalysisApp < handle
    %EPHYSANALYSISAPP  GUI for quick-look figures of processed ephys datasets.
    %   EphysAnalysisApp edits one EphysAnalysisConfig and draws it with an
    %   EphysAnalysisRunner. It computes nothing itself: previews, plans and
    %   runs all go through the runner (computeFigure, computeSessionFigure,
    %   plan, run) and renderFigure, so what the app shows is what a
    %   generated script writes.
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
    %                (EpochDiagram): a window that stays above the app and
    %                draws, on the active dataset, the digital lines as TTL
    %                traces, each event, window and epoch and what is
    %                dropped, redrawn on every edit (onShowEpochs)
    %     Figures    figures (buildFiguresTab): panels of different types
    %                (raster, PSTH, continuous signal, heat map, unit
    %                waveforms, behavior, probe map, unit correlation) on a
    %                grid, designed for ONE observation (a sorted unit, a
    %                channel or the dataset) at a time; a tree of figures
    %                under groups (what they observe, enabled / off, none),
    %                each with a check box that enables it (add from a
    %                template, remove, duplicate, reorder within a group) and an
    %                editor in collapsible sections: the observations (the
    %                unit filter), the arrangement (a schematic of the grid:
    %                drag a panel to an empty cell or beside another one;
    %                Add panel above / below / left / right of the selected
    %                one, spans, relative row heights and column widths,
    %                spacing, Remove, Move), the panel (type, title, group
    %                shown), the figure's event reference, epoch window and
    %                trial selection ("Use default" for the Alignment tab's),
    %                the panel's own event and window ("Same as the figure"),
    %                its layers (each follows the observation or is fixed),
    %                the type's options, the panel's text note and overlays,
    %                appearance and remembered looks, and Sessions (the
    %                figure drawn once across the ticked or picked datasets:
    %                a session figure, its facet, colors, error band, unit
    %                matching by site or mapping file, minimum sessions,
    %                trial groups), showing only the rows the figure, panel
    %                and layer use (syncFigureEditor); a preview of the
    %                observation picked in the dataset and observation
    %                drop-downs (< and >), which computes only that unit's
    %                spikes or that channel's column (refreshFigurePreview:
    %                figureObservations, EphysAnalysisRunner.computeFigure,
    %                renderFigure; a session figure across its datasets:
    %                computeSessionFigure; Auto while a preview takes under
    %                2 s), with its own badge (setFigurePreviewState), drawn
    %                in the design picked above it (Design, PlotDesign; Save
    %                look as design...: onSaveDesign). Runs, plans, reports
    %                and the generated scripts draw the enabled figures: one
    %                page per observation on each dataset
    %                (EphysAnalysisRunner.runDataset), then each session
    %                figure across the datasets (runSessionFigure)
    %     Export     figure formats, folder and file-name pattern, the report
    %                (HTML / PDF), Validate, Plan, Run over the ticked
    %                datasets (cancelable), results, open the report / folder
    %     Chronux    Chronux analyses of the active dataset (buildChronuxTab):
    %                its <Name>_chronux.mat (found in its output folder or
    %                the local cache, or created from its extract, units and
    %                detections: onCreateChronuxExport), the signal and
    %                channels, the analysis (power spectrum, spectrogram)
    %                over epochs around the Alignment tab's event or over
    %                segments of a stretch, its tapers, frequencies, error
    %                bars, moving window, baseline and display; Compute
    %                (cancelable), Save figure, Save results
    %     Log        what the runner reported
    %
    %   File menu: New / Open / Open recent / Save / Save As / Generate
    %   script (compact | standalone) / Open pipeline app / Close. Design
    %   menu: the plot designs (choosing one redraws every figure), save the
    %   figure preview's look as a design, import or delete a design, your designs
    %   folder. Help menu: the wiki page of the tab shown, the documentation
    %   home and the analysis quick start; Report an issue and Request a
    %   feature on GitHub (onReportIssue); About.
    %
    %   Toolbar (buildToolbar): the most used commands as icons, each with
    %   its menu shortcut in the tooltip: New / Open / Save config; Scan,
    %   Preview; Validate, Plan, Run, Cancel; Open report, Open figure
    %   folder; Open pipeline app; Help for this tab.
    %
    %   Keys (onKeyPress), on the Figures tab: Ctrl+1 to Ctrl+9 and Ctrl+0
    %   (Cmd on a Mac) go to the figure editor's sections
    %   (gotoFigureSection); each header names its key and has a color of
    %   its own. Page Up and Page Down step to the previous and next
    %   observation (onFigureObservationStep). Escape cancels a panel drag.
    %
    %   Preferences (getpref group 'EphysAnalysisApp'): FigurePosition,
    %   LastConfigFile, RecentConfigs, ScriptFolder,
    %   PreviewMaxMB (signal previews of larger extracts wait for the Preview
    %   button), FigureAutoPreview (the Figures tab's Auto, on by default:
    %   one observation is quick), FigureSectionsCollapsed (its editor's
    %   collapsed sections), FigureGroupBy and FigureGroupsCollapsed (how
    %   its figure tree groups, and its collapsed groups),
    %   ChronuxCacheFolder (the local folder for
    %   Chronux files of datasets whose output folder cannot be written),
    %   ChronuxMaxMB (the most signal the Chronux tab reads at once),
    %   ChronuxSettings (its last settings) and ChronuxSectionsCollapsed.
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
        TabFigures matlab.ui.container.Tab
        TabExport  matlab.ui.container.Tab
        TabChronux matlab.ui.container.Tab
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

        % --- Figures tab (buildFiguresTab) ---
        FiguresTree            matlab.ui.container.Tree         % the figures under groups (figureGroups); a figure's node holds its index in NodeData
        FigureGroupDropDown    matlab.ui.control.DropDown       % how the tree groups: what it observes, status, none
        FigureTemplateDropDown matlab.ui.control.DropDown       % the template a new figure starts from (figureTemplates)
        AddFigureButton        matlab.ui.control.Button
        RemoveFigureButton     matlab.ui.control.Button
        DuplicateFigureButton  matlab.ui.control.Button
        CopyFigureButton       matlab.ui.control.Button         % Copy from...: another figure's settings onto the selected one (onCopyFigureSettings)
        UpFigureButton         matlab.ui.control.Button
        DownFigureButton       matlab.ui.control.Button
        FigureEditorPanel      matlab.ui.container.Panel        % the editor's panel (its title names the figure)
        FigureEditorGrid       matlab.ui.container.GridLayout   % the editor's column of sections
        FigureSections struct = struct([])       % the editor's sections (formSection), top to bottom
        FigureEditor struct = struct()           % figure-editor controls by field
        FigureAlignControls struct = struct()    % the figure's event / window / selection (buildAlignControls)
        PanelAlignControls struct = struct()     % the selected panel's own event / window (buildAlignControls; its selection hidden)
        FigureSchematic        matlab.ui.control.UIAxes         % the arrangement's schematic (drawFigureSchematic)
        FiguresDatasetDropDown matlab.ui.control.DropDown       % the active dataset (as on the other tabs)
        FigureObservationDropDown matlab.ui.control.DropDown    % the observation previewed; ItemsData = row of FigureObservations
        FigureObsPrevButton    matlab.ui.control.Button
        FigureObsNextButton    matlab.ui.control.Button
        FigurePreviewButton    matlab.ui.control.Button
        FigureGenerateButton   matlab.ui.control.Button         % Generate: the figure for every observation on the ticked datasets (onGenerateFigure)
        FigureAutoCheckBox     matlab.ui.control.CheckBox       % auto-preview (pref FigureAutoPreview, on by default)
        DesignDropDown         matlab.ui.control.DropDown       % the design every figure is drawn in (PlotDesign; also the Design menu)
        SaveDesignButton       matlab.ui.control.Button         % Save look as design...: the figure preview's look (onSaveDesign)
        FigurePreviewPanel     matlab.ui.container.Panel
        FigurePreviewBadge struct = struct()     % the figure preview's state badge: Grid, Icon, Text (setFigurePreviewState)
        FigurePreviewLabel     matlab.ui.control.Label
        FigureCancelButton     matlab.ui.control.Button         % the busy card's Cancel while the figure preview computes (else empty)
        FigureSessionDropDown  matlab.ui.control.DropDown       % "Figure:" under the preview: which of a session figure's figures (facet / group) is drawn

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

        % --- Chronux tab (buildChronuxTab) ---
        ChronuxDatasetDropDown  matlab.ui.control.DropDown
        ChronuxFileLabel        matlab.ui.control.Label     % where the Chronux file is, what it holds (refreshChronuxTab)
        ChronuxCreateButton     matlab.ui.control.Button    % Create / Recreate (onCreateChronuxExport)
        ChronuxOpenFolderButton matlab.ui.control.Button
        ChronuxCacheLabel       matlab.ui.control.Label
        ChronuxCacheButton      matlab.ui.control.Button
        ChronuxControls struct = struct()        % the tab's settings controls by field
        ChronuxSections struct = struct([])      % its sections (formSection), top to bottom
        ChronuxEditorGrid       matlab.ui.container.GridLayout
        ChronuxComputeButton    matlab.ui.control.Button
        ChronuxCancelButton     matlab.ui.control.Button
        ChronuxSaveFigureButton matlab.ui.control.Button
        ChronuxSaveResultsButton matlab.ui.control.Button
        ChronuxPrevPageButton   matlab.ui.control.Button
        ChronuxNextPageButton   matlab.ui.control.Button
        ChronuxPageLabel        matlab.ui.control.Label
        ChronuxPanel            matlab.ui.container.Panel   % renderChronux draws here
        ChronuxBadge struct = struct()           % the plot's state badge: Grid, Icon, Text (setChronuxState)
        ChronuxStatusLabel      matlab.ui.control.Label

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
        DatasetsSort (1,1) struct = TableSort.none()   % the datasets table's header click (a TableSort state), kept as it is filled again
        DatasetUnitCounts = []              % sorted units per dataset, counted when it is opened: containers.Map, "<key>|<sort folder>" -> n (refreshDatasetLabels)
        EpochDiagramWindow = []             % the EpochDiagram window, while open (onShowEpochs)
        EpochDiagramFor (1,1) string = "figure"   % what it draws: "figure" (the Figures tab's editor) | "defaults" (the Alignment tab's)
        Running (1,1) logical = false
        LastReportFiles (1,:) string = string.empty(1,0)
        LastExportFolder (1,1) string = ""

        SelectedFigure (1,1) double = 0     % the figure in the editor (index into Config.Figures), the one previewed
        SelectedPanel (1,1) double = 0      % its panel in the editor (index into its panels; 0 = none)
        SelectedLayer (1,1) double = 0      % that panel's layer in the editor (index into its layers; 0 = none)
        FigureObservations = []             % the picker's observations: figureObservations' table on the active dataset
        FigureObservation = []              % the observation each figure last showed: containers.Map, figure id -> its label
        FigurePreviewResult = []            % the last figure preview's result (computeFigure's F)
        FigurePreviewSeconds (1,1) double = 0   % time the last figure preview took (auto-preview under AutoPreviewSeconds)
        FigurePreviewWarm (1,1) logical = false % a figure was drawn already: the first one's time (graphics loading) is not counted
        FigureAutoPreviewSeconds (1,1) double = 2   % edits redraw the figure preview while the last one took under this (AutoPreviewSeconds; tests raise it)
        FigurePreviewState (1,1) string = "idle"   % what the figure preview's badge says (setFigurePreviewState)
        FigurePreviewRedo (1,1) logical = false    % an edit or a Preview press came in while one computed: it ends Out of date
        FigureAddType (1,1) string = "continuous"  % the panel type Add panel adds (the Arrangement's drop-down)
        FigureAddSource (1,1) string = "units"     % the source Add layer adds, when the panel's type draws it
        FigureSessionResults = []           % a session figure's last preview: struct(res (figureSessionCompute's RES), spec, what, label, seconds)
        FigureGroupsCollapsed (1,:) string = string.empty(1,0)   % keys of the figure tree's groups the user collapsed
        FigureDrag = []                     % a panel dragged in the schematic (onSchematicPress): its state, else []

        ChronuxIndex = []                  % loadChronuxExport's index of ChronuxFile
        ChronuxFile (1,1) string = ""       % the active dataset's Chronux file ("" = none)
        ChronuxFileWhere (1,1) string = ""  % "output" (its output folder) | "cache" (the local cache)
        ChronuxResult = []                  % the last Chronux analysis (chronuxSpectrum, chronuxSpecgram)
        ChronuxState (1,1) string = "idle"  % what the Chronux badge says (setChronuxState)
        ChronuxPage (1,1) double = 1
        ChronuxCancelRequested (1,1) logical = false
        ChronuxCacheFolder (1,1) string = ""   % where Chronux files go when an output folder cannot be written
        ChronuxMaxMB (1,1) double = 2000    % the most signal the Chronux tab reads at once (and a spectrogram's size)
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
        buildExportTab(obj)
        buildLogTab(obj)
        C = buildAlignControls(obj, parents, changed)
        applyAlignControls(obj, C, ref, win, sel)
        [ref, win, sel] = gatherAlignControls(obj, C, ref, win, sel)
        fillAlignItems(obj, C)
        editSequence(obj, holder, lineCtl, edgeCtl, done)

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
        onDatasetsSorted(obj, evt)
        clearDatasetsSort(obj)
        selectDataset(obj, idx)
        refreshDatasetInfo(obj)
        idx = tickedDatasetIndices(obj)

        % --- Alignment tab ---
        refreshAlignPreview(obj)
        onFilterHelp(obj)

        % --- the epoch diagram (Alignment tab, figure editor) ---
        onShowEpochs(obj, what)
        refreshEpochDiagram(obj)

        % --- plot designs (Design menu, the Figures tab's Design row) ---
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

        % --- Figures tab ---
        buildFiguresTab(obj)
        refreshFigureList(obj)
        onAddFigure(obj, template)
        onRemoveFigure(obj)
        onDuplicateFigure(obj)
        onMoveFigure(obj, step)
        onFigureSelected(obj, k)
        onCopyFigureSettings(obj, opts)
        applyFigureEditor(obj)
        fig = gatherFigureEditor(obj)
        applyFigureEditorDefaults(obj)
        syncFigureEditor(obj)
        layoutFigureEditor(obj)
        onFigureSectionToggled(obj, name)
        gotoFigureSection(obj, name)
        onFigureAlignEdited(obj, part)
        onFigureDefaultToggled(obj)
        onPanelAlignEdited(obj, part)
        onPanelDefaultToggled(obj)
        onPanelSelected(obj, k)
        onAddPanel(obj, where)
        onRemovePanel(obj)
        onMovePanel(obj, direction)
        onPanelTypeChanged(obj)
        drawFigureSchematic(obj)
        onLayerSelected(obj, j)
        onAddLayer(obj)
        onRemoveLayer(obj)
        onMoveLayer(obj, step)
        refreshFigureObservations(obj, opts)
        onFigureObservationChanged(obj)
        onFigureObservationStep(obj, step)
        refreshFigurePreview(obj, opts)
        autoFigurePreview(obj)
        onFigureAutoPreviewToggled(obj)
        onCancelFigurePreview(obj)
        R = onGenerateFigure(obj, opts)
        setFigurePreviewState(obj, state, opts)
        rememberFigureAesthetics(obj, id, rules)
        onPickFigureDatasets(obj, opts)
        onBrowseFigureMapping(obj, file)
        T = onEditUnitMapping(obj, opts)
        onFigureSessionPicked(obj)
        onFigureTreeSelected(obj, nodes)
        onFigureTreeClicked(obj, evt)
        onFigureGroupToggled(obj, node, collapsed)
        onFigureCheck(obj, how)
        setFiguresEnabled(obj, ks, how)
        onAddFigureOverlay(obj, shape)
        onRemoveFigureOverlay(obj)
        onDuplicateFigureOverlay(obj)
        onFigureOverlayPicked(obj)
        onSchematicPress(obj, q, evt)
        cancelSchematicDrag(obj, msg)
        p = schematicPixel(obj, xy)

        % --- Chronux tab ---
        buildChronuxTab(obj)
        refreshChronuxTab(obj)
        syncChronuxControls(obj)
        S = gatherChronuxSettings(obj)
        applyChronuxSettings(obj, S)
        onChronuxEdited(obj, what)
        onChronuxSectionToggled(obj, name)
        R = onChronuxCompute(obj)
        onCancelChronux(obj)
        chronuxCheck(obj)
        drawChronux(obj)
        setChronuxState(obj, state, opts)
        out = onCreateChronuxExport(obj, opts)
        onChronuxCacheFolder(obj, folder)
        file = onSaveChronuxFigure(obj, file)
        file = onSaveChronuxResults(obj, file)
        [file, where] = chronuxFileFor(obj, k)

        % --- app-wide ---
        loadPreferences(obj, openLast)
        savePreferences(obj)
        onClose(obj)
        setStatus(obj, message)
        log(obj, message)
        selectTab(obj, tab)
        onTabChanged(obj)
        onKeyPress(obj, evt)
        url = helpURL(obj, page)
        onHelp(obj, page)
        onReportIssue(obj, kind)
        body = issueReport(obj, kind, opts)
        [url, truncated] = issueURL(obj, kind, title, body)
    end
end
