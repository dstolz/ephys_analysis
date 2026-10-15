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
    %                baseline, the kind's options, appearance, unit waveform,
    %                aux signals (a PSTH's or raster's mean accelerometer
    %                signal below, above or over each unit's panels), text
    %                note, overlays: any number of lines and
    %                semitransparent patches on the plot's axes) showing only the
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
    %     Figures    figures (buildFiguresTab): panels of different types
    %                (raster, PSTH, continuous signal, heat map, unit
    %                waveforms, behavior, probe map, unit correlation) on a
    %                grid, designed for ONE observation (a sorted unit, a
    %                channel or the dataset) at a time; a list of figures
    %                (add from a template, remove, duplicate, reorder) and an
    %                editor in collapsible sections: the observations (the
    %                unit filter), the arrangement (a schematic of the grid:
    %                Add panel above / below / left / right of the selected
    %                one, spans, relative row heights and column widths,
    %                spacing, Remove, Move), the panel (type, title, group
    %                shown), the figure's event reference, epoch window and
    %                trial selection ("Use default" for the Alignment tab's),
    %                the panel's own event and window ("Same as the figure"),
    %                its layers (each follows the observation or is fixed),
    %                the type's options, appearance and remembered looks,
    %                showing only the rows the figure, panel and layer use
    %                (syncFigureEditor); a preview of the observation picked
    %                in the dataset and observation drop-downs (< and >),
    %                which computes only that unit's spikes or that
    %                channel's column (refreshFigurePreview: figureObservations,
    %                EphysAnalysisRunner.computeFigure, renderFigure; Auto
    %                while a preview takes under 2 s), with its own badge
    %                (setFigurePreviewState). Runs, plans, reports and the
    %                generated scripts draw the enabled figures too: one
    %                page per observation, after each dataset's plots
    %                (EphysAnalysisRunner.runDataset)
    %     Sessions   session plots (buildSessionsTab): one plot of the Plots
    %                tab (its base plot) computed on several datasets and
    %                merged (EphysAnalysisRunner.computeSessionPlot,
    %                combineSessions): add (on a base plot), remove,
    %                duplicate, reorder; an editor in collapsible sections
    %                (the datasets, figures per subject, a color per
    %                session / subject / one mean, color order, sessions
    %                under a summary, error band; unit matching: pool, site,
    %                mapping file; the data export, To workspace, Save .mat)
    %                showing only the rows it uses (syncSessionEditor); a
    %                preview over the ticked datasets (refreshSessionPreview;
    %                Auto off by default), its figures (per subject, per
    %                trial group) and pages, with its own badge
    %                (setSessionPreviewState)
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
    %   Keys (onKeyPress), on the Plots tab: Ctrl+1 to Ctrl+9 and Ctrl+0 (Cmd on a Mac)
    %   go to the plot editor's sections (gotoPlotSection); each header
    %   names its key and has a color of its own. On the Sessions tab
    %   Ctrl+1 to Ctrl+3 go to the session editor's (gotoSessionSection). On
    %   the Figures tab Ctrl+1 to Ctrl+9 and Ctrl+0 go to the figure
    %   editor's (gotoFigureSection).
    %   Page Up and Page Down flip the shown tab's preview pages; on the
    %   Figures tab, which has none, they step to the previous and next
    %   observation (onFigureObservationStep).
    %
    %   Preferences (getpref group 'EphysAnalysisApp'): FigurePosition,
    %   LastConfigFile, RecentConfigs, ScriptFolder, AutoPreview,
    %   PreviewMaxMB (signal previews of larger extracts wait for the Preview
    %   button), PlotSectionsCollapsed (the plot editor's collapsed sections),
    %   PlotGroupBy (how the plot tree groups), PlotGroupsCollapsed (its
    %   collapsed groups), SessionAutoPreview (the Sessions tab's Auto,
    %   off by default), SessionSectionsCollapsed (its editor's collapsed
    %   sections), FigureAutoPreview (the Figures tab's Auto, on by default:
    %   one observation is quick), FigureSectionsCollapsed (its editor's
    %   collapsed sections), ChronuxCacheFolder (the local folder for
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
        TabPlots   matlab.ui.container.Tab
        TabFigures matlab.ui.container.Tab
        TabSessions matlab.ui.container.Tab
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

        % --- Plots tab ---
        PlotsTree          matlab.ui.container.Tree         % the plots under groups (plotGroups); a plot's node holds its index in NodeData
        PlotGroupDropDown  matlab.ui.control.DropDown       % how the tree groups: plot type, source, layout, status, none
        PlotFilterDropDown matlab.ui.control.DropDown       % which plots the Check / Uncheck / Only buttons act on (refreshPlotFilter)
        AddKindDropDown    matlab.ui.control.DropDown
        AddPlotButton      matlab.ui.control.Button
        RemovePlotButton   matlab.ui.control.Button
        DuplicatePlotButton matlab.ui.control.Button
        CopyPlotButton     matlab.ui.control.Button         % Copy from...: another plot's settings onto the selected plots (onCopyPlotSettings)
        ConvertPlotButton  matlab.ui.control.Button         % Convert to figure: a figure of each selected plot (onConvertPlotToFigure)
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

        % --- Sessions tab (buildSessionsTab) ---
        SessionList            matlab.ui.control.ListBox        % "<id>  (<base plot>)"; ItemsData = index into Config.SessionPlots
        AddSessionBaseDropDown matlab.ui.control.DropDown       % the base plot of a new session plot (kinds in SessionKinds)
        AddSessionButton       matlab.ui.control.Button
        RemoveSessionButton    matlab.ui.control.Button
        DuplicateSessionButton matlab.ui.control.Button
        UpSessionButton        matlab.ui.control.Button
        DownSessionButton      matlab.ui.control.Button
        SessionEditorPanel     matlab.ui.container.Panel        % the editor's panel (its title names the session plot)
        SessionEditorGrid      matlab.ui.container.GridLayout   % the editor's column of sections
        SessionSections struct = struct([])      % the editor's sections (formSection): general, sessions, matching, data
        SessionEditor struct = struct()          % session-editor controls by field
        SessionCountLabel      matlab.ui.control.Label          % "Sessions: N ticked (...)": what the session plot draws
        SessionPreviewButton   matlab.ui.control.Button
        SessionAutoCheckBox    matlab.ui.control.CheckBox       % auto-preview (pref SessionAutoPreview, off by default)
        SessionGroupDropDown   matlab.ui.control.DropDown       % the figure shown (facet / trial group); ItemsData = index into SessionPreviewResults
        SessionPrevPageButton  matlab.ui.control.Button
        SessionNextPageButton  matlab.ui.control.Button
        SessionPageLabel       matlab.ui.control.Label
        SessionPreviewLabel    matlab.ui.control.Label
        SessionPreviewPanel    matlab.ui.container.Panel
        SessionPreviewBadge struct = struct()    % the session preview's state badge: Grid, Icon, Text (setSessionPreviewState)

        % --- Figures tab (buildFiguresTab) ---
        FigureList             matlab.ui.control.ListBox        % "<id>  (<n> panels, per <kind>)"; ItemsData = index into Config.Figures
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
        FigureDesignLabel      matlab.ui.control.Label          % "Design: <name>" (chosen on the Plots tab or the Design menu)
        FigurePreviewPanel     matlab.ui.container.Panel
        FigurePreviewBadge struct = struct()     % the figure preview's state badge: Grid, Icon, Text (setFigurePreviewState)
        FigurePreviewLabel     matlab.ui.control.Label
        FigureCancelButton     matlab.ui.control.Button         % the busy card's Cancel while the figure preview computes (else empty)

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
        EpochDiagramFor (1,1) string = "plot"   % what it draws: "plot" (the editor's) | "defaults" | "figure" (the Figures tab's)
        Running (1,1) logical = false
        LastReportFiles (1,:) string = string.empty(1,0)
        LastExportFolder (1,1) string = ""

        SelectedSessionPlot (1,1) double = 0    % the session plot in the editor (index into Config.SessionPlots), the one previewed
        SessionPreviewResults = []              % the last session preview's figures (computeSessionPlot's RES: facet, group, label, R, status, message)
        SessionPreviewIndex (1,1) double = 1    % the figure of SessionPreviewResults shown
        SessionPreviewPage (1,1) double = 1
        SessionPreviewPages (1,1) double = 1
        SessionPreviewState (1,1) string = "idle"   % what the session preview's badge says (setSessionPreviewState)
        SessionPreviewRedo (1,1) logical = false    % an edit or a Preview press came in while one computed: it ends Out of date
        SessionPreviewSeconds (1,1) double = 0      % time the last session preview took (auto-preview under 2 s)

        SelectedFigure (1,1) double = 0     % the figure in the editor (index into Config.Figures), the one previewed
        SelectedPanel (1,1) double = 0      % its panel in the editor (index into its panels; 0 = none)
        SelectedLayer (1,1) double = 0      % that panel's layer in the editor (index into its layers; 0 = none)
        FigureObservations = []             % the picker's observations: figureObservations' table on the active dataset
        FigureObservation = []              % the observation each figure last showed: containers.Map, figure id -> its label
        FigurePreviewResult = []            % the last figure preview's result (computeFigure's F)
        FigurePreviewSeconds (1,1) double = 0   % time the last figure preview took (auto-preview under AutoPreviewSeconds)
        FigurePreviewWarm (1,1) logical = false % a figure was drawn already: the first one's time (graphics loading) is not counted
        FigurePreviewState (1,1) string = "idle"   % what the figure preview's badge says (setFigurePreviewState)
        FigurePreviewRedo (1,1) logical = false    % an edit or a Preview press came in while one computed: it ends Out of date
        FigureAddType (1,1) string = "continuous"  % the panel type Add panel adds (the Arrangement's drop-down)
        FigureAddSource (1,1) string = "units"     % the source Add layer adds, when the panel's type draws it

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
        onDatasetsSorted(obj, evt)
        clearDatasetsSort(obj)
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
        onCopyPlotSettings(obj, opts)
        onMovePlot(obj, step)
        onPlotSelected(obj, k)
        onPlotTreeSelected(obj, nodes)
        ks = selectedPlots(obj)
        showPlotSelection(obj)
        onPlotGroupChanged(obj)
        onPlotGroupToggled(obj, node, collapsed)
        onPlotCheck(obj, how)
        onPlotTreeDoubleClicked(obj, evt)
        setPlotsEnabled(obj, ks, how)
        ks = plotsOfFilter(obj)
        refreshPlotFilter(obj)
        onPlotSectionToggled(obj, name)
        gotoPlotSection(obj, name)
        onKeyPress(obj, evt)
        onOverlayPicked(obj)
        onAddOverlay(obj, shape)
        onDuplicateOverlay(obj)
        onRemoveOverlay(obj)
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

        % --- Sessions tab ---
        buildSessionsTab(obj)
        refreshSessionList(obj)
        sp = gatherSessionEditor(obj)
        applySessionEditor(obj)
        syncSessionEditor(obj)
        layoutSessionEditor(obj)
        onAddSessionPlot(obj, base)
        onRemoveSessionPlot(obj)
        onDuplicateSessionPlot(obj)
        onMoveSessionPlot(obj, step)
        onSessionPlotSelected(obj, k)
        onSessionSectionToggled(obj, name)
        gotoSessionSection(obj, name)
        onPickSessionDatasets(obj, opts)
        onBrowseUnitMapping(obj, file)
        T = onEditUnitMapping(obj, opts)
        refreshSessionPreview(obj)
        state = drawSessionPreview(obj)
        setSessionPreviewState(obj, state, opts)
        onCancelSessionPreview(obj)
        onSessionPreviewPage(obj, step)
        onSessionGroupChanged(obj, i)
        rememberSessionAesthetics(obj, id, rules)
        autoSessionPreview(obj)
        onSessionAutoPreviewToggled(obj)
        S = onSessionsToWorkspace(obj, sp, opts)
        file = onSaveSessionData(obj, sp, opts)

        % --- Figures tab ---
        buildFiguresTab(obj)
        refreshFigureList(obj)
        onAddFigure(obj, template)
        onRemoveFigure(obj)
        onDuplicateFigure(obj)
        onMoveFigure(obj, step)
        onFigureSelected(obj, k)
        onCopyFigureSettings(obj, opts)
        onConvertPlotToFigure(obj)
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
        url = helpURL(obj, page)
        onHelp(obj, page)
        onReportIssue(obj, kind)
        body = issueReport(obj, kind, opts)
        [url, truncated] = issueURL(obj, kind, title, body)
    end
end
