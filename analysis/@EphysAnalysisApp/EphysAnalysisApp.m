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
    %                groups on the active dataset and, right of them, the
    %                epoch diagram for them (EpochDiagram in the tab): the
    %                digital lines as TTL traces, each event, window and
    %                epoch and what is dropped, redrawn on every edit
    %                (refreshAlignPreview)
    %     Figures    figures (buildFiguresTab): panels of different types
    %                (raster, PSTH, continuous signal, heat map, unit
    %                waveforms, behavior, probe map, unit correlation) on a
    %                grid, designed for ONE observation (a sorted unit, a
    %                channel or the dataset) at a time; a tree of figures
    %                under groups (what they observe, enabled / off, none),
    %                each with a check box that enables it (add a blank
    %                figure, remove, duplicate as "<id> (2)", reorder within
    %                a group); its id follows its panels and data
    %                ("Raster+PSTH units") until one is typed; and an
    %                editor in collapsible sections under three collapsible
    %                supersections (Figure, Panel, Look), with a search
    %                field that finds a setting by name: the observations (the
    %                unit filter), the panels (a schematic of the grid:
    %                drag a panel to an empty cell or beside another one;
    %                New panel... (a window: the type, each shown as a small
    %                plot, its name, place and key parameters: onNewPanel),
    %                spans, relative row heights and column widths,
    %                spacing, Remove, Move), the selected panel (type, title,
    %                box, group shown), the figure's event reference, epoch window and
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
    %                look as design...: onSaveDesign); each figure keeps its
    %                preview in a container of its own (syncFigureView: a
    %                switch back shows it without drawing it again, up to
    %                MaxFigureViews kept) and the editor as it left it, and
    %                the tree marks the figure shown and the previews out of
    %                date (markFigureTree). Runs, plans, reports
    %                and the generated scripts draw the enabled figures: one
    %                page per observation on each dataset
    %                (EphysAnalysisRunner.runDataset), then each session
    %                figure across the datasets (runSessionFigure)
    %     Export     figure formats, folder and file-name pattern, the report
    %                (HTML / PDF), Validate, Plan, Run over the ticked
    %                datasets (cancelable), results, open the report / folder
    %     Log        what the runner reported
    %
    %   File menu: New / Open / Open recent / Save / Save As / Generate
    %   script (compact | standalone) / Open pipeline app / Close. Edit
    %   menu: Undo and Redo of the figure editor's edits (onUndoRedo, over
    %   FigureEditHistory: Ctrl+Z, Ctrl+Y and Ctrl+Shift+Z, on the Figures
    %   tab). Design menu: the plot designs (choosing one redraws every figure), save the
    %   figure preview's look as a design, import or delete a design, your designs
    %   folder. Help menu: the wiki page of the tab shown, the documentation
    %   home and the analysis quick start; Report an issue and Request a
    %   feature on GitHub (onReportIssue); About.
    %
    %   Favorites: a plain star (on / off) on a dataset, a channel or a sorted
    %   unit (kept with its sort), written at once into <Name>_favorites.json
    %   in the dataset's output folder (DatasetFavorites), so the stars
    %   travel with the data; read on Scan. Star a dataset with the Data
    %   tab's ★ column or the ★ toggle beside a Dataset drop-down, and the
    %   unit, channel (a detection channel's) or dataset previewed with the
    %   toggle beside the observation picker (onStarToggled); starred ones
    %   are marked ★ in those drop-downs. The Favorites drop-down (Alignment
    %   and Figures tabs, with a filter that narrows it as you type) lists
    %   every star of the scanned datasets; picking one goes to it
    %   (onFavoritePicked). An output folder that cannot be written (a
    %   read-only share) leaves the star off and the status bar says why.
    %
    %   Notes: free text on a dataset, a channel or a sorted unit (kept with
    %   its sort), in <Name>_notes.json in the dataset's output folder
    %   (DatasetNotes), beside the stars; read on Scan. The ✎ button right
    %   of each star (and the Data tab's ✎ column) opens a little notepad
    %   (NotePad, onNoteButton) that stays above the app and follows the
    %   active dataset or the observation as you step; the note is written
    %   when you leave its box, save, move on or close it. A button with a
    %   note is yellow, and the drop-downs mark noted items ✎. Search notes
    %   (the toolbar) searches every note of the scanned datasets as you
    %   type and goes to the dataset of the one picked (onSearchNotes,
    %   NoteSearch, goToNote).
    %
    %   Toolbar (buildToolbar): the most used commands as icons, each with
    %   its menu shortcut in the tooltip: New / Open / Save config; Scan,
    %   Preview, Search notes; Validate, Plan, Run, Cancel; Open report, Open figure
    %   folder; Open pipeline app; Help for this tab.
    %
    %   Keys (onKeyPress), on the Figures tab: Alt+1, Alt+2 and Alt+3 go to
    %   the figure editor's supersections, Figure, Panel and Look
    %   (gotoFigureSuper); Ctrl+1 to Ctrl+9 and Ctrl+0 (Cmd on a Mac) to its
    %   sections (gotoFigureSection); each header names its key. Ctrl+F
    %   goes to the search field (onFigureSearch, gotoFigureRow), F6 and
    %   Shift+F6 to the next and previous column (focusFigurePane), Ctrl+]
    %   and Ctrl+[ to the next and previous panel, Ctrl+Alt+arrows to the
    %   panel above, below, left or right (stepFigurePanel; the preview
    %   outlines it: markFigurePanel). Page Up and Page Down step to the
    %   previous and next observation (onFigureObservationStep). Ctrl+P,
    %   Ctrl+G, Ctrl+U, Ctrl+T, Ctrl+E and Ctrl+W press Preview, Generate,
    %   Unit report, Auto, Export code and Open in window
    %   (pressFigureButton). Escape cancels a panel drag. Ctrl+Z undoes
    %   the last edit of the figures, Ctrl+Y and Ctrl+Shift+Z redo it
    %   (onUndoRedo). The "?" button lists them all (onFigureKeys).
    %
    %   Preferences (getpref group 'EphysAnalysisApp'): FigurePosition,
    %   LastConfigFile, RecentConfigs, ScriptFolder,
    %   PreviewMaxMB (signal previews of larger extracts wait for the Preview
    %   button), FigureAutoPreview (the Figures tab's Auto, on by default:
    %   one observation is quick), FigureSectionsCollapsed and
    %   FigureSupersectionsCollapsed (its editor's collapsed sections and
    %   supersections), FigureGroupBy and FigureGroupsCollapsed (how
    %   its figure tree groups, and its collapsed groups).
    %
    %   Startup: a small window (AppSplash) shows the app's name, version
    %   and a progress bar while the window is built hidden, the
    %   preferences restored, the config opened, its datasets scanned and
    %   the first one loaded; then the window shows. Splash=false starts
    %   without it, the default under -batch (the test runs). Opened on a
    %   project root or an output folder (the pipeline app's Open analysis
    %   app), the app takes the last config again with its source switched
    %   to them (openSource).
    %
    %   Usage
    %     EphysAnalysisApp                      % the last config, or defaults
    %     EphysAnalysisApp("D:\EPHYS")          % a pipeline project root, with the last config's figures
    %     EphysAnalysisApp("D:\EPHYS", OutputRoot="E:\out", NamePattern=..., Recordings="separate")
    %     EphysAnalysisApp("D:\EPHYS", Datasets=["subj1/day1" "subj1/day2"])  % only these ticked (root-relative keys)
    %     EphysAnalysisApp("D:\out\subj1_day1") % one dataset's output folder
    %     EphysAnalysisApp("am_quicklook.json") % an analysis config
    %     EphysAnalysisApp(..., Splash=false)   % no startup window
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
        TabLog     matlab.ui.container.Tab
        FileMenu   matlab.ui.container.Menu
        RecentMenu matlab.ui.container.Menu
        EditMenu   matlab.ui.container.Menu
        UndoMenu   matlab.ui.container.Menu   % "Undo <edit>" (refreshEditMenu)
        RedoMenu   matlab.ui.container.Menu   % "Redo <edit>"
        ApplyMenu  matlab.ui.container.Menu   % "Apply last change to figures..." (onApplyToFigures; refreshEditMenu)
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
        ToolbarUndoTool   matlab.ui.container.toolbar.PushTool   % Undo / Redo as the Edit menu's (refreshEditMenu)
        ToolbarRedoTool   matlab.ui.container.toolbar.PushTool
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
        AlignDatasetStar   matlab.ui.control.StateButton  % stars the active dataset (starButton)
        AlignDatasetNote   matlab.ui.control.Button       % the active dataset's note (noteButton)
        AlignFavorites struct = struct()         % the Favorites row: Grid, Filter, DropDown (buildFavorites)
        AlignControls struct = struct()          % buildAlignControls handles
        AlignSummaryLabel  matlab.ui.control.Label
        AlignEpochDiagram = []                   % the epoch diagram of the Defaults, right of the count (EpochDiagram, refreshAlignPreview)
        AlignAxes          matlab.ui.control.UIAxes
        AlignBarsExcluded  matlab.ui.control.CheckBox   % off: the bars leave out what Pairing and Artifacts exclude; on: stack it on
        AlignTrialsTable   matlab.ui.control.Table
        SequenceDialog     matlab.ui.Figure = matlab.ui.Figure.empty   % the Event sequence window (editSequence), when open

        % --- Figures tab (buildFiguresTab) ---
        FiguresTree            matlab.ui.container.Tree         % the figures under groups (figureGroups); a figure's node holds its index in NodeData
        FigureGroupDropDown    matlab.ui.control.DropDown       % how the tree groups: what it observes, status, none
        AddFigureButton        matlab.ui.control.Button
        RemoveFigureButton     matlab.ui.control.Button
        DuplicateFigureButton  matlab.ui.control.Button
        CopyFigureButton       matlab.ui.control.Button         % Copy from...: another figure's settings onto the selected one (onCopyFigureSettings)
        UpFigureButton         matlab.ui.control.Button
        DownFigureButton       matlab.ui.control.Button
        FigureEditorPanel      matlab.ui.container.Panel        % the editor's panel (its title names the figure)
        FigureEditorGrid       matlab.ui.container.GridLayout   % the editor's column of sections
        FigureSections struct = struct([])       % the editor's sections (formSection), top to bottom
        FigureSupers struct = struct([])         % the editor's supersections: Name, Title, Sections, Header, Expanded, Key
        FigureSearchField      matlab.ui.control.EditField      % Find a setting (Ctrl+F): over every row's label (onFigureSearch)
        FigureSearchList       matlab.ui.control.ListBox        % its matches, "Supersection > Section > Row"; ItemsData = index rows
        FigureKeysButton       matlab.ui.control.Button         % "?": the Figures tab's keys (onFigureKeys)
        FigureEditor struct = struct()           % figure-editor controls by field
        FigureAlignControls struct = struct()    % the figure's event / window / selection (buildAlignControls)
        PanelAlignControls struct = struct()     % the selected panel's own event / window (buildAlignControls; its selection hidden)
        FigureSchematic        matlab.ui.control.UIAxes         % the arrangement's schematic (drawFigureSchematic)
        FiguresDatasetDropDown matlab.ui.control.DropDown       % the active dataset (as on the other tabs)
        FigureObservationDropDown matlab.ui.control.DropDown    % the observation previewed; ItemsData = row of FigureObservations
        FiguresDatasetStar     matlab.ui.control.StateButton    % stars the active dataset (starButton)
        FigureObservationStar  matlab.ui.control.StateButton    % stars the observation previewed: its unit, channel or the dataset
        FiguresDatasetNote     matlab.ui.control.Button         % the active dataset's note (noteButton)
        FigureObservationNote  matlab.ui.control.Button         % the note on the observation previewed: its unit, channel or the dataset
        FigureFavorites struct = struct()        % the Favorites row: Grid, Filter, DropDown (buildFavorites)
        FigureObsPrevButton    matlab.ui.control.Button
        FigureObsNextButton    matlab.ui.control.Button
        FigurePreviewButton    matlab.ui.control.Button
        FigureGenerateButton   matlab.ui.control.Button         % Generate: the figure for every observation on the ticked datasets (onGenerateFigure)
        FigureUnitReportButton matlab.ui.control.Button         % Unit report: every enabled figure for the observation picked, a temporary HTML report (onUnitReport)
        FigureOpenButton       matlab.ui.control.Button         % Open in window: the figure as previewed in a figure() of its own (onOpenFigureWindow)
        FigureCodeButton       matlab.ui.control.Button         % Export code: the code that draws the preview, in the editor (onFigureCode)
        FigureExportPreviewButton matlab.ui.control.Button      % Export preview: the observation picked written as a run writes it (onExportPreview)
        FigureAutoCheckBox     matlab.ui.control.CheckBox       % auto-preview (pref FigureAutoPreview, on by default)
        DesignDropDown         matlab.ui.control.DropDown       % the design every figure is drawn in (PlotDesign; also the Design menu)
        SaveDesignButton       matlab.ui.control.Button         % Save look as design...: the figure preview's look (onSaveDesign)
        FigurePreviewPanel     matlab.ui.container.Panel        % the shown figure's own preview container (syncFigureView: one per figure, in FigurePreviewHost)
        FigurePreviewHost      matlab.ui.container.GridLayout   % the preview's cell: every figure's container stacked in it, the shown one visible
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
        ExportPreviewButton matlab.ui.control.Button     % Export preview, as the Figures tab's (onExportPreview)
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
        Splash AppSplash = AppSplash.empty  % the startup window (AppSplash; isActive while the app starts, closed once it shows)

        Runner = []                         % the EphysAnalysisRunner (rebuilt by Scan; owns the caches)
        ScannedSource struct = struct()     % Config.Source when the runner last scanned
        ActiveIdx (1,1) double = 0          % the active dataset (index into Runner.Outputs)
        Ticked (1,:) logical = logical.empty(1, 0)   % datasets ticked to run
        DatasetsSort (1,1) struct = TableSort.none()   % the datasets table's header click (a TableSort state), kept as it is filled again
        Favorites = []                      % the scanned datasets' stars: a DatasetFavorites each, in Runner order (read on Scan)
        FavoriteEntries = []                % the Favorites drop-downs' entries: table dataset, level, id, label (refreshFavorites)
        Notes = []                          % the scanned datasets' notes: a DatasetNotes each, in Runner order (read on Scan)
        NotePadWindow = []                  % the notepad (NotePad), while open (openNotePad)
        NotePadFollows (1,1) string = ""    % what the notepad follows: "dataset" (the active one), "observation" (the one picked), "" (the note it was opened on)
        NoteSearchWindow = []               % the Search notes window (NoteSearch), while open (onSearchNotes)
        DatasetUnits = []                   % sorted units per dataset, read when it is opened: containers.Map, "<key>|<sort folder>" -> table unitId, class, channel, depth (refreshDatasetLabels; labels the Favorites)
        EpochDiagramWindow = []             % the EpochDiagram window of the Figures tab's figure, while open (onShowEpochs)
        ExportPreviewWindow = []            % the Export preview window, while open (onExportPreview)
        ExportPreviewFolder (1,1) string = string(fullfile(tempdir, "ephys_export_preview"))   % where Export preview writes (emptied each time; tests move it)
        Running (1,1) logical = false
        LastReportFiles (1,:) string = string.empty(1,0)
        LastExportFolder (1,1) string = ""

        SelectedFigure (1,1) double = 0     % the figure in the editor (index into Config.Figures), the one previewed
        SelectedPanel (1,1) double = 0      % its panel in the editor (index into its panels; 0 = none)
        SelectedLayer (1,1) double = 0      % that panel's layer in the editor (index into its layers; 0 = none)
        FigureObservations = []             % the picker's observations: figureObservations' table on the active dataset
        FigureObservation = []              % the observation each figure last showed: containers.Map, figure id -> its label
        FigureIdRenames = []                % figures renamed (an automatic id that followed an edit): containers.Map, old id -> new (trackFigureIds)
        FigurePreviewResult = []            % the shown figure's last preview result (computeFigure's F)
        FigurePreviewDrawn = []             % what the shown figure's preview was drawn from (figureViewKey), once drawn
        FigurePreviewSeconds (1,1) double = 0   % time the shown figure's last preview took (auto-preview under AutoPreviewSeconds)
        FigureViews struct = struct([])     % one preview container per figure kept (syncFigureView): Id, Panel, State, Result, Drawn, Seconds, Sessions, Label, Used; "" = none selected
        FigureViewId (1,1) string = ""      % the figure whose container shows: its State, Result, ... are the FigurePreview* properties meanwhile
        FigureViewTick (1,1) double = 0     % counts the containers shown (FigureViews.Used: the least recently used goes over MaxFigureViews)
        FigurePreviewGeneration (1,1) double = 0   % a scan adds one: every preview drawn before is out of date (figureViewKey)
        FigureTreeMarks = []                % the figure tree's marks as applied (markFigureTree): nodes, look, current
        FigureEditorStates = []             % the editor as each figure left it: containers.Map, figure id -> its sections, scroll, panel and layer (saveFigureEditorState)
        FigurePickers = []                  % each figure's last observation list: containers.Map, figure id -> the picker's items, key and table (keepFigurePicker)
        FigurePreviewWarm (1,1) logical = false % a figure was drawn already: the first one's time (graphics loading) is not counted
        FigureAutoPreviewSeconds (1,1) double = 2   % edits redraw the figure preview while the last one took under this (AutoPreviewSeconds; tests raise it)
        FigurePreviewState (1,1) string = "idle"   % what the figure preview's badge says (setFigurePreviewState)
        FigurePreviewRedo (1,1) logical = false    % an edit or a Preview press came in while one computed: it ends Out of date
        FigureAddSource (1,1) string = "units"     % the source Add layer adds, when the panel's type draws it
        FigureSessionResults = []           % a session figure's last preview: struct(res (figureSessionCompute's RES), spec, what, label, seconds)
        FigureGroupsCollapsed (1,:) string = string.empty(1,0)   % keys of the figure tree's groups the user collapsed
        FigureDrag = []                     % a panel dragged in the schematic (onSchematicPress): its state, else []
        FigureSearchIndex struct = struct([])   % the editor's searchable rows, as built (figureSearchIndex)
        FigureSearchState (1,1) string = ""     % "typing" (the search field), "list" (its matches), "" (Enter, arrows and Escape are left alone)
        FigureFlash = []                    % the row gotoFigureRow highlights: struct(handles, saved, timer), else []
        FigurePanelMark = []                % the preview's outline of the selected panel (markFigurePanel): four strips, else []
        FigurePanelMarkAxes = []            % the preview's axes its listeners follow (re-laid out on a resize)
        FigurePanelMarkListeners = []       % those listeners (Position PostSet)
        FigureFocusPane (1,1) double = 0    % the column F6 last went to: 1 the figure list, 2 the editor, 3 the preview
        FigureHistory FigureEditHistory = FigureEditHistory()   % the figure editor's undo and redo (recordFigureEdit, onUndoRedo); cleared by another config
        CtrlHeld (1,1) logical = false      % Ctrl (Cmd) is down (onKeyPress, onKeyRelease): an editor edit made with it opens Apply to figures (onApplyToFigures)
        ApplyTicked (1,:) string = string.empty(1, 0)   % Apply to figures: the targets ticked when last shown ("<figure id>" or "<figure id>/<panel id>")
        ApplySeen (1,:) string = string.empty(1, 0)     % ... and every target it has shown (one not seen yet is ticked)
        ApplyReplot (1,1) logical = false   % ... and its "Replot the changed figures now" box

    end

    properties (Constant)
        PrefGroup = 'EphysAnalysisApp'
        WikiURL = "https://github.com/dstolz/ephys_analysis/wiki"
        RepoURL = "https://github.com/dstolz/ephys_analysis"        % the repository the issue items file against
        AutoPreviewSeconds = 2
        % the figure previews kept drawn (syncFigureView): each holds its computed result and its graphics, so a
        % switch back shows it at once; beyond this many the least recently shown one is dropped (drawn again when
        % it is shown). A constant, not a preference: about what eight heavy figures cost in memory and handles.
        MaxFigureViews = 8
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
                opts.Splash (1,1) logical = ~batchStartupOptionUsed()   % no one watches a -batch run
            end
            % Behind the startup window (AppSplash) the UI is built hidden;
            % the window shows at the end. On an error the splash and the
            % hidden window close and the error goes on.
            [steps, weights] = startupSteps();
            obj.Splash = AppSplash("Ephys analysis", steps, weights, Show=opts.Splash);
            unfinished = onCleanup(@() abandonStartup(obj)); %#ok<NASGU>
            obj.Splash.step("window", "Building the window ...");
            obj.buildUI();
            obj.Splash.step("prefs", "Restoring the preferences ...");
            obj.loadPreferences(source == "");
            if source ~= ""
                obj.openSource(source, OutputRoot=opts.OutputRoot, NamePattern=opts.NamePattern, ...
                    Recordings=opts.Recordings, Datasets=opts.Datasets);
            end
            obj.updateTitle();
            obj.Splash.step("show", "Drawing the window ...");
            obj.Fig.Visible = "on";
            drawnow;
            obj.Splash.close();
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
        onConfigChanged(obj, what, src)
        updateTitle(obj)
        onUndoRedo(obj, how)
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
        onDatasetNoteClicked(obj, evt)
        onDatasetsSorted(obj, evt)
        clearDatasetsSort(obj)
        selectDataset(obj, idx)
        refreshDatasetInfo(obj)
        idx = tickedDatasetIndices(obj)

        % --- favorites (stars: DatasetFavorites) ---
        refreshFavorites(obj)
        onStarToggled(obj, what, tf)
        onFavoritePicked(obj, which)
        onFavoritesFilter(obj, which, text)

        % --- notes (DatasetNotes; the notepad NotePad, the Search notes window NoteSearch) ---
        refreshNotes(obj)
        onNoteButton(obj, what)
        onSearchNotes(obj)

        % --- Alignment tab ---
        refreshAlignPreview(obj)
        onFilterHelp(obj)

        % --- the epoch diagram window (figure editor; the Alignment tab's is refreshAlignPreview's) ---
        onShowEpochs(obj)
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
        onApplyToFigures(obj, opts)
        applyFigureEditor(obj)
        fig = gatherFigureEditor(obj)
        applyFigureEditorDefaults(obj)
        syncFigureEditor(obj)
        layoutFigureEditor(obj)
        onFigureSectionToggled(obj, name)
        gotoFigureSection(obj, name)
        onFigureSuperToggled(obj, name)
        gotoFigureSuper(obj, name)
        onFigureSearch(obj, text)
        ok = gotoFigureRow(obj, i, opts)
        ok = gotoFigureSetting(obj, id, role, panel)
        stepFigurePanel(obj, how)
        markFigurePanel(obj)
        focusFigurePane(obj, step)
        pressFigureButton(obj, key)
        w = onFigureKeys(obj)
        onFigureAlignEdited(obj, part)
        onFigureDefaultToggled(obj)
        onPanelAlignEdited(obj, part)
        onPanelDefaultToggled(obj)
        onPanelSelected(obj, k)
        onNewPanel(obj, opts)
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
        switched = syncFigureView(obj)
        autoFigurePreview(obj)
        onFigureAutoPreviewToggled(obj)
        onCancelFigurePreview(obj)
        R = onGenerateFigure(obj, opts)
        [R, file] = onUnitReport(obj, opts)
        h = onOpenFigureWindow(obj)
        files = onExportPreview(obj)
        txt = onFigureCode(obj, file)
        setFigurePreviewState(obj, state, opts)
        rememberFigureAesthetics(obj, id, rules)
        onFigureAxisEdited(obj, id, panel, change)
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

        % --- app-wide ---
        loadPreferences(obj, openLast)
        savePreferences(obj)
        onClose(obj)
        setStatus(obj, message)
        log(obj, message)
        selectTab(obj, tab)
        onTabChanged(obj)
        onKeyPress(obj, evt)
        onKeyRelease(obj, evt)
        url = helpURL(obj, page)
        onHelp(obj, page)
        onReportIssue(obj, kind)
        body = issueReport(obj, kind, opts)
        [url, truncated] = issueURL(obj, kind, title, body)
    end
end


function [steps, weights] = startupSteps()
%startupSteps  The constructor's steps on the splash (AppSplash) and the seconds each takes (measured warm).
%   The tab steps are named by their tabs, in buildUI's order; "scan" and
%   "dataset" are onScan's (the datasets found, the first one loaded).
S = { ...
    "window", 0.2; "Data", 0.34; "Alignment", 0.97; "Figures", 5.4; "Export", 0.29; ...
    "Log", 0.02; "finish", 0.19; "prefs", 0.44; "config", 6.0; "scan", 5.1; "dataset", 4.9; "show", 0.6};
steps = [S{:, 1}];
weights = [S{:, 2}];
end


function abandonStartup(obj)
%abandonStartup  The constructor's cleanup: when it stopped before the window showed, the hidden window and the splash go.
if ~isvalid(obj) || ~obj.Splash.isActive(); return; end   % it finished: the splash closed then
if ~isempty(obj.Fig) && isvalid(obj.Fig)
    delete(obj.Fig);
end
obj.Splash.close();
end
