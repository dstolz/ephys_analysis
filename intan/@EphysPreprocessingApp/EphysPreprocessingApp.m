classdef EphysPreprocessingApp < handle
    %EPHYSPREPROCESSINGAPP  GUI for the config-driven ephys preprocessing pipeline.
    %   EphysPreprocessingApp edits one EphysPipelineConfig and runs it with
    %   EphysPipeline over an EphysProject. It duplicates none of their logic:
    %   scanning, metadata, reading, artifacts, sorting, derived signals, spike
    %   detection and the exports all happen in EphysDataset / EphysPipeline;
    %   the app only edits the config, chooses datasets, shows progress and
    %   keeps per-dataset associations (probe, exclusions, manual artifacts,
    %   sorted output, Epsych2 session) in each dataset's manifest.
    %
    %   Tabs, in workflow order
    %     Project    config name, project root / output root, dataset table
    %                (the Select column is the config's dataset selection),
    %                Epsych2 behavior associations
    %     Probe      probe library, preview, assignment, per-dataset channel
    %                exclusions, the config's default probe
    %     Artifacts  automatic detection settings + preview, manual periods
    %     Sorting    SpikeInterface + Kilosort4 settings, sorted-output
    %                association, Run this step, background-run log
    %     Signals    derived LFP / MUA / SPIKE (.mat) settings, plan, Run
    %     Spikes     threshold detection / sorted units (.mat), preview, Run
    %     Export     Chronux / FieldTrip files, plan, Run
    %     Run        step checklist, validate, plan, run / dry run / cancel,
    %                progress, results, log
    %     Visualize  plot a window, mark manual artifact periods
    %     Review     inspect sorted units
    %
    %   File menu: New / Open / Open recent / Save / Save As / Export copy /
    %   Generate script (compact | standalone) / Close. The title shows "*"
    %   while the config has unsaved changes.
    %
    %   Preferences (getpref group 'EphysPreprocessingApp') hold only what is
    %   not part of a config: figure geometry, probe folder, phy command,
    %   Review folder, last / recent config files, script folder and the
    %   Visualize display options.
    %
    %   Usage
    %     EphysPreprocessingApp;            % launch
    %     app = EphysPreprocessingApp;      % launch and keep a handle
    %
    %   See also EPHYSPIPELINECONFIG, EPHYSPIPELINE, EPHYSPROJECT, EPHYSDATASET.

    properties
        Fig   matlab.ui.Figure
        Tabs  matlab.ui.container.TabGroup

        % --- Menu bar ---
        FileMenu         matlab.ui.container.Menu
        RecentMenu       matlab.ui.container.Menu
        DatasetMenu      matlab.ui.container.Menu   % app-wide single-dataset picker
        DatasetMenuItems matlab.ui.container.Menu
        RunMenu          matlab.ui.container.Menu

        % --- Global status bar ---
        StatusBar  matlab.ui.control.Label
        StatusHint matlab.ui.control.Label

        TabProject   matlab.ui.container.Tab
        TabProbe     matlab.ui.container.Tab
        TabArtifacts matlab.ui.container.Tab
        TabSorting   matlab.ui.container.Tab
        TabSignals   matlab.ui.container.Tab
        TabSpikes    matlab.ui.container.Tab
        TabExport    matlab.ui.container.Tab
        TabRun       matlab.ui.container.Tab
        TabVisualize matlab.ui.container.Tab
        TabReview    matlab.ui.container.Tab

        % --- Project tab ---
        ConfigNameField   matlab.ui.control.EditField
        ConfigDescField   matlab.ui.control.EditField
        RootPathField     matlab.ui.control.EditField
        BrowseRootButton  matlab.ui.control.Button
        ScanButton        matlab.ui.control.Button
        RefreshMetaButton matlab.ui.control.Button
        LaunchPhyButton   matlab.ui.control.Button
        SelectAllButton   matlab.ui.control.Button
        SelectNoneButton  matlab.ui.control.Button
        OutputRootField   matlab.ui.control.EditField
        BrowseOutputButton matlab.ui.control.Button
        DatasetsTable     matlab.ui.control.Table
        ScanStatusLabel   matlab.ui.control.Label
        BehEnableCheckBox    matlab.ui.control.CheckBox
        BehSearchDirsField   matlab.ui.control.EditField
        BehBrowseButton      matlab.ui.control.Button
        BehMatchDropDown     matlab.ui.control.DropDown
        BehMaxOffsetField    matlab.ui.control.NumericEditField
        BehFindButton        matlab.ui.control.Button
        BehStatusLabel       matlab.ui.control.Label
        BehOverwriteCheckBox matlab.ui.control.CheckBox
        BehAssociateButton   matlab.ui.control.Button
        BehClearButton       matlab.ui.control.Button

        % --- Visualize tab ---
        VizDatasetLabel    matlab.ui.control.Label
        VizFileDropDown    matlab.ui.control.DropDown
        VizChannelsField   matlab.ui.control.EditField
        VizStartField      matlab.ui.control.NumericEditField
        VizDurField        matlab.ui.control.NumericEditField
        VizHighpassField   matlab.ui.control.EditField
        VizLowpassField    matlab.ui.control.EditField
        VizOrderField      matlab.ui.control.NumericEditField
        VizRefDropDown     matlab.ui.control.DropDown
        VizDetrendCheckBox matlab.ui.control.CheckBox
        VizSpacingField    matlab.ui.control.NumericEditField
        VizModeDropDown    matlab.ui.control.DropDown
        VizColormapDropDown matlab.ui.control.DropDown
        VizSortByProbeCheckBox matlab.ui.control.CheckBox
        VizColorByShankCheckBox matlab.ui.control.CheckBox
        VizPlotButton      matlab.ui.control.Button
        VizArtButton       matlab.ui.control.StateButton
        VizArtClearButton  matlab.ui.control.Button
        VizArtStatusLabel  matlab.ui.control.Label
        VizAxes            matlab.ui.control.UIAxes
        VizStatusLabel     matlab.ui.control.Label
        VizHelpLabel       matlab.ui.control.Label

        % --- Artifacts tab ---
        ArtDatasetDropDown  matlab.ui.control.DropDown
        ArtEnableCheckBox   matlab.ui.control.CheckBox
        ArtMethodDropDown   matlab.ui.control.DropDown
        ArtThresholdField   matlab.ui.control.NumericEditField
        ArtRmsWindowField   matlab.ui.control.NumericEditField
        ArtMergeGapField    matlab.ui.control.NumericEditField
        ArtMinChannelsField matlab.ui.control.NumericEditField
        ArtPadField         matlab.ui.control.NumericEditField
        ArtFilterCheckBox   matlab.ui.control.CheckBox
        ArtHighpassField    matlab.ui.control.NumericEditField
        ArtApplySortingCheckBox matlab.ui.control.CheckBox
        ArtApplySpikesCheckBox  matlab.ui.control.CheckBox
        ArtCacheCheckBox    matlab.ui.control.CheckBox
        ArtDetectButton     matlab.ui.control.Button
        ArtSummaryLabel     matlab.ui.control.Label
        ArtChannelTable     matlab.ui.control.Table
        ArtStatusLabel      matlab.ui.control.Label
        ArtManualLabel      matlab.ui.control.Label
        ArtEditVizButton    matlab.ui.control.Button
        ArtManualClearButton matlab.ui.control.Button
        ArtManualTable      matlab.ui.control.Table

        % --- Probe tab ---
        ProbeFolderField    matlab.ui.control.EditField
        BrowseProbeFolderButton matlab.ui.control.Button
        ImportProbeButton   matlab.ui.control.Button
        EditProbeJSONButton matlab.ui.control.Button
        DesignProbeButton   matlab.ui.control.Button
        RefreshProbesButton matlab.ui.control.Button
        ProbeTable          matlab.ui.control.Table
        ProbeInfoLabel      matlab.ui.control.Label
        ProbeCheckLabel     matlab.ui.control.Label
        ProbePreviewAxes    matlab.ui.control.UIAxes
        AssignSelectedButton matlab.ui.control.Button
        AssignAllButton     matlab.ui.control.Button
        ExcludeChannelsField matlab.ui.control.EditField
        ShowChanNumbersCheckBox matlab.ui.control.CheckBox
        ProbeDefaultField   matlab.ui.control.EditField
        ProbeUseSelectedButton matlab.ui.control.Button
        ProbeWriteDefaultCheckBox matlab.ui.control.CheckBox

        % --- Sorting tab ---
        SortEnableCheckBox  matlab.ui.control.CheckBox
        SortSkipExistingCheckBox matlab.ui.control.CheckBox
        PythonExeField    matlab.ui.control.EditField
        BrowsePythonButton matlab.ui.control.Button
        CondaEnvField     matlab.ui.control.EditField
        PhyCmdField       matlab.ui.control.EditField
        ExecModeDropDown  matlab.ui.control.DropDown
        DryRunCheckBox    matlab.ui.control.CheckBox
        SIFilterCheckBox     matlab.ui.control.CheckBox
        SIFilterMinField     matlab.ui.control.NumericEditField
        SIFilterMaxField     matlab.ui.control.NumericEditField
        SICommonRefCheckBox  matlab.ui.control.CheckBox
        SIRefOperatorDropDown matlab.ui.control.DropDown
        SIDetectBadCheckBox  matlab.ui.control.CheckBox
        SIBadMethodDropDown  matlab.ui.control.DropDown
        SIBadActionDropDown  matlab.ui.control.DropDown
        % Kilosort4 parameter controls keyed by settings name (kilosortParamSpec).
        ParamControls struct = struct()
        ExtraSettingsArea matlab.ui.control.TextArea
        KSDocsLink        matlab.ui.control.Hyperlink
        SIDocsLink        matlab.ui.control.Hyperlink
        SortResultsLabel  matlab.ui.control.Label
        SortUseFolderButton matlab.ui.control.Button
        SortUseAutoButton matlab.ui.control.Button
        SortPhyButton     matlab.ui.control.Button
        RunStepSortingButton matlab.ui.control.Button
        KSProgressLabel   matlab.ui.control.Label
        KSLogArea         matlab.ui.control.TextArea

        % --- Review tab ---
        ReviewFolderField   matlab.ui.control.EditField
        BrowseReviewButton  matlab.ui.control.Button
        ReviewDatasetDropDown matlab.ui.control.DropDown
        LoadReviewButton    matlab.ui.control.Button
        OpenReviewFolderButton matlab.ui.control.Button
        ReviewPhyButton     matlab.ui.control.Button
        ReviewSummaryLabel  matlab.ui.control.Label
        ReviewUnitsTable    matlab.ui.control.Table
        ReviewAllUnitsButton matlab.ui.control.Button
        ReviewShankAxes     matlab.ui.control.UIAxes
        ReviewWaveAxes      matlab.ui.control.UIAxes
        ReviewAmpAxes       matlab.ui.control.UIAxes
        ReviewRateAxes      matlab.ui.control.UIAxes

        % --- Signals tab (config Signals; gather/applyConvertConfig) ---
        SigEnableCheckBox       matlab.ui.control.CheckBox
        ConvOutputDirField      matlab.ui.control.EditField
        ConvBrowseOutputButton  matlab.ui.control.Button
        ConvSuffixField         matlab.ui.control.EditField
        ConvMatVersionDropDown  matlab.ui.control.DropDown
        ConvOverwriteCheckBox   matlab.ui.control.CheckBox
        ConvIncludeBehaviorCheckBox matlab.ui.control.CheckBox
        ConvLFPCheckBox         matlab.ui.control.CheckBox
        ConvMUACheckBox         matlab.ui.control.CheckBox
        ConvSPIKECheckBox       matlab.ui.control.CheckBox
        ConvLFPFsField          matlab.ui.control.NumericEditField
        ConvLFPHighpassCheckBox matlab.ui.control.CheckBox
        ConvLFPHighpassField    matlab.ui.control.NumericEditField
        ConvLFPLowpassCheckBox  matlab.ui.control.CheckBox
        ConvLFPLowpassField     matlab.ui.control.NumericEditField
        ConvLFPNotchCheckBox    matlab.ui.control.CheckBox
        ConvLFPNotchField       matlab.ui.control.EditField
        ConvLFPNotchBWField     matlab.ui.control.NumericEditField
        ConvMUAFsField          matlab.ui.control.NumericEditField
        ConvMUAIntegrationField matlab.ui.control.NumericEditField
        ConvMUALoField          matlab.ui.control.NumericEditField
        ConvMUAHiField          matlab.ui.control.NumericEditField
        ConvSpikeOrigCheckBox   matlab.ui.control.CheckBox
        ConvSpikeFsField        matlab.ui.control.NumericEditField
        ConvSpikeLoField        matlab.ui.control.NumericEditField
        ConvSpikeHiField        matlab.ui.control.NumericEditField
        ConvLabelFieldDropDown  matlab.ui.control.DropDown
        ConvExcludeHandlingDropDown matlab.ui.control.DropDown
        ConvKeepChannelsField   matlab.ui.control.EditField
        ConvBadModeDropDown     matlab.ui.control.DropDown
        ConvBadThresholdField   matlab.ui.control.NumericEditField
        ConvBadListField        matlab.ui.control.EditField
        ConvRemapField          matlab.ui.control.EditField
        ConvResetButton         matlab.ui.control.Button
        ConvTargetsTable        matlab.ui.control.Table
        RunStepSignalsButton    matlab.ui.control.Button
        ConvRefreshButton       matlab.ui.control.Button

        % --- Spikes tab ---
        SpkEnableCheckBox    matlab.ui.control.CheckBox
        SpkSourceDropDown    matlab.ui.control.DropDown
        SpkFilterCheckBox    matlab.ui.control.CheckBox
        SpkBandLoField       matlab.ui.control.NumericEditField
        SpkBandHiField       matlab.ui.control.NumericEditField
        SpkFilterOrderField  matlab.ui.control.NumericEditField
        SpkPolarityDropDown  matlab.ui.control.DropDown
        SpkThreshMethodDropDown matlab.ui.control.DropDown
        SpkThresholdField    matlab.ui.control.EditField
        SpkMaxAmpField       matlab.ui.control.EditField
        SpkAlignDropDown     matlab.ui.control.DropDown
        SpkAlignWindowField  matlab.ui.control.NumericEditField
        SpkMinPeriodField    matlab.ui.control.NumericEditField
        SpkWaveformsCheckBox matlab.ui.control.CheckBox
        SpkWinBeforeField    matlab.ui.control.NumericEditField
        SpkWinAfterField     matlab.ui.control.NumericEditField
        SpkWaveSourceDropDown matlab.ui.control.DropDown
        SpkEdgeDropDown      matlab.ui.control.DropDown
        SpkChannelsDropDown  matlab.ui.control.DropDown
        SpkChannelListField  matlab.ui.control.EditField
        SpkRejectArtifactsCheckBox matlab.ui.control.CheckBox
        SpkChunkField        matlab.ui.control.EditField
        SpkEdgePadField      matlab.ui.control.EditField
        SpkParallelCheckBox  matlab.ui.control.CheckBox
        SpkGroupsField       matlab.ui.control.EditField
        SpkIncludeNoiseCheckBox matlab.ui.control.CheckBox
        SpkTemplatesCheckBox matlab.ui.control.CheckBox
        SpkOutputDirField    matlab.ui.control.EditField
        SpkBrowseOutputButton matlab.ui.control.Button
        SpkSuffixField       matlab.ui.control.EditField
        SpkOverwriteCheckBox matlab.ui.control.CheckBox
        SpkMatVersionDropDown matlab.ui.control.DropDown
        SpkPreviewButton     matlab.ui.control.Button
        SpkPreviewSecondsField matlab.ui.control.NumericEditField
        SpkPreviewLabel      matlab.ui.control.Label
        SpkPreviewTable      matlab.ui.control.Table
        RunStepSpikesButton  matlab.ui.control.Button

        % --- Export tab ---
        ExpEnableCheckBox    matlab.ui.control.CheckBox
        ExpChronuxCheckBox   matlab.ui.control.CheckBox
        ExpFieldTripCheckBox matlab.ui.control.CheckBox
        ExpSignalsField      matlab.ui.control.EditField
        ExpUnitsCheckBox     matlab.ui.control.CheckBox
        ExpGroupsField       matlab.ui.control.EditField
        ExpDetectedCheckBox  matlab.ui.control.CheckBox
        ExpEventsCheckBox    matlab.ui.control.CheckBox
        ExpBehaviorCheckBox  matlab.ui.control.CheckBox
        ExpValidateCheckBox  matlab.ui.control.CheckBox
        ExpOutputDirField    matlab.ui.control.EditField
        ExpBrowseOutputButton matlab.ui.control.Button
        ExpOverwriteCheckBox matlab.ui.control.CheckBox
        ExpMatVersionDropDown matlab.ui.control.DropDown
        ExpTargetsTable      matlab.ui.control.Table
        RunStepExportButton  matlab.ui.control.Button
        ExpRefreshButton     matlab.ui.control.Button

        % --- Run tab ---
        RunBehaviorCheckBox  matlab.ui.control.CheckBox
        RunArtifactsCheckBox matlab.ui.control.CheckBox
        RunSortingCheckBox   matlab.ui.control.CheckBox
        RunSignalsCheckBox   matlab.ui.control.CheckBox
        RunSpikesCheckBox    matlab.ui.control.CheckBox
        RunExportCheckBox    matlab.ui.control.CheckBox
        RunSelectionLabel    matlab.ui.control.Label
        RunValidateButton    matlab.ui.control.Button
        RunPlanButton        matlab.ui.control.Button
        RunButton            matlab.ui.control.Button
        RunDryButton         matlab.ui.control.Button
        RunCancelButton      matlab.ui.control.Button
        RunIssuesTable       matlab.ui.control.Table
        RunOverallBar        matlab.ui.container.GridLayout   % see setRunBar
        RunOverallText       matlab.ui.control.Label
        RunStepBar           matlab.ui.container.GridLayout
        RunStepText          matlab.ui.control.Label
        RunStepLabel         matlab.ui.control.Label
        RunResultsTable      matlab.ui.control.Table
        RunLogArea           matlab.ui.control.TextArea
        RunKSLabel           matlab.ui.control.Label
    end

    properties
        Project EphysProject = EphysProject.empty
        SelectedRow (1,1) double = 0   % last-clicked datasets-table row (0 = none)

        % --- config model ---
        Config EphysPipelineConfig = EphysPipelineConfig()   % working copy
        SavedConfigStruct struct = struct()                   % last saved / opened state
        Applying (1,1) logical = false     % true while applyConfig pushes values (suppresses onConfigChanged)
        RecentConfigs (1,:) string = string.empty(1,0)
        ScriptFolder (1,1) string = ""

        % --- run state ---
        Pipe = []                          % the EphysPipeline being run (for Cancel)
        RunActive (1,1) logical = false

        % Probe tab selection state.
        ProbePaths (1,:) string = string.empty(1,0)
        SelectedProbeRow (1,1) double = 0

        % Background Kilosort4 runs awaiting completion + the polling timer.
        KSRuns struct = struct('Name', {}, 'statusFile', {}, 'resultsDir', {}, ...
            'logFile', {}, 'logPos', {}, 'done', {})
        KSMonitorTimer = []

        % --- Visualize interaction state (display-only, in-memory) ---
        Viewer = []
        VizDetectedIntervals = zeros(0, 2)
        VizTimeOffset (1,1) double = 0
        VizDatasetIndex (1,1) double = 0
        SelectedDatasetIdx (1,1) double = 0
        VizChannels (1,:) double = double.empty(1,0)
        VizMemoryBudget (1,1) double = 0
        VizArtMode (1,1) logical = false
        VizArtDrag = struct('active', false)
        VizArtPatches = gobjects(0,1)
        VizArtPreview = gobjects(0,1)

        % --- Review (Kilosort4 output) state ---
        ReviewData = struct([])
        ReviewSelectedUnit (1,1) double = 0
    end

    properties (Constant)
        PrefGroup = 'EphysPreprocessingApp'
    end

    methods
        function obj = EphysPreprocessingApp()
            % Construct, build the UI, restore preferences and the last config.
            obj.buildUI();
            obj.loadPreferences();
            obj.refreshProbeList();
            obj.updateTitle();

            if nargout == 0
                clear obj
            end
        end

        % --- UI construction ---
        buildUI(obj)
        buildMenus(obj)
        buildProjectTab(obj)
        buildProbeTab(obj)
        buildArtifactsTab(obj)
        buildSortingTab(obj)
        buildSignalsTab(obj)
        buildSpikesTab(obj)
        buildExportTab(obj)
        buildRunTab(obj)
        buildVisualizeTab(obj)
        buildReviewTab(obj)

        % --- config model ---
        cfg = gatherConfig(obj)
        applyConfig(obj, cfg, opts)
        onConfigChanged(obj)
        updateTitle(obj)
        syncStepEnableStates(obj)
        P = gatherProjectSection(obj)
        applyProjectSection(obj, P)
        applySelectionToTable(obj, P)
        S = gatherProbeSection(obj)
        applyProbeSection(obj, S)
        B = gatherBehaviorSection(obj)
        applyBehaviorSection(obj, B)
        A = gatherArtifactsSection(obj)
        applyArtifactsSection(obj, A)
        [S, errMsg] = gatherSortingSection(obj)
        applySortingSection(obj, S)
        cfg = gatherConvertConfig(obj)
        applyConvertConfig(obj, cfg)
        K = gatherSpikesSection(obj)
        applySpikesSection(obj, K)
        E = gatherExportSection(obj)
        applyExportSection(obj, E)
        onNewConfig(obj)
        onOpenConfig(obj)
        ok = openConfigFile(obj, file)
        ok = onSaveConfig(obj)
        ok = onSaveConfigAs(obj)
        onExportConfigCopy(obj)
        onGenerateScript(obj, kind)
        ok = confirmDiscard(obj)
        addRecentConfig(obj, file)
        refreshRecentMenu(obj)
        p = defaultConfigFolder(obj)

        % --- running ---
        pipe = buildPipeline(obj)
        runPipeline(obj, opts)
        onPipelineProgress(obj, evt)
        onRunStep(obj, step)
        onCancelRun(obj)
        onValidate(obj)
        showIssues(obj, issues)
        onPlan(obj)
        refreshStepPlan(obj, step)
        runLog(obj, fmt, varargin)
        setRunBar(obj, bar, frac)

        % --- Project tab ---
        onScan(obj)
        refreshDatasetsTable(obj)
        onDatasetCellSelection(obj, evt)
        onRefreshMetadata(obj)
        onSelectDatasets(obj, mode)
        onBrowseRoot(obj)
        onBrowseOutput(obj)
        onBrowseBehaviorDir(obj)
        onAssociateBehavior(obj)
        onClearBehavior(obj)
        d = currentDataset(obj)
        updatePhyButtonState(obj)
        idx = selectedDatasetIndices(obj)
        applyConfigToProject(obj, P)
        applyArtifactConfigToProject(obj)

        % --- Artifacts tab ---
        onDetectArtifacts(obj)
        populateArtifactDatasets(obj)
        d = currentArtifactDataset(obj)
        onArtifactControlsChanged(obj)
        refreshManualArtifactsTable(obj)
        onClearManualArtifacts(obj)

        % --- Visualize tab ---
        onPlotVisualization(obj)
        onVizButtonDown(obj)
        onVizButtonUp(obj)
        drawVizArtifacts(obj)
        applyVizChannelOrder(obj)
        applyVizChannelColor(obj)
        onVizModeChanged(obj)
        onVizColormapChanged(obj)
        tf = vizActive(obj)
        tf = cursorOverAxes(obj)
        d = currentVizDataset(obj)
        onVizArtToggle(obj, val)
        onVizArtClear(obj)
        onVizArtMotion(obj)
        finishVizArtDrag(obj)
        updateVizArtStatus(obj)
        populateVizFiles(obj)
        populateDatasetMenu(obj)
        selectDataset(obj, idx)
        updateDatasetMenuCheck(obj)

        % --- Probe tab ---
        refreshProbeList(obj)
        onProbeSelected(obj)
        onImportProbe(obj)
        onDesignProbe(obj)
        result = runProbeTool(obj, varargin)
        onAssignProbe(obj, scope)
        onApplyExclude(obj, scope)
        onBrowseProbeFolder(obj)
        pf = selectedProbeFile(obj)
        onProbeRowSelected(obj, evt)
        onEditProbeJSON(obj)
        syncExcludeField(obj)
        selectProbeRow(obj, row)
        onProbeNotesEdited(obj, evt)
        saveProbeNotes(obj, pf, notes)
        p = defaultProbeFolder(obj)
        onUseSelectedProbeAsDefault(obj)

        % --- Sorting tab ---
        onBrowsePython(obj)
        cfg = gatherSIConfig(obj)
        applySIConfig(obj, cfg)
        setDropIfMember(obj, dd, value)
        syncSIEnableStates(obj)
        onSIControlsChanged(obj)
        p = defaultPythonExe(obj)
        onUseSortingFolder(obj)
        onUseAutoSorting(obj)
        refreshSortingLabel(obj)
        onLaunchPhy(obj)
        launchPhy(obj, resultsDir, label)
        startKSMonitor(obj)
        stopKSMonitor(obj)
        pollKSRuns(obj)
        log(obj, fmt, varargin)
        appendLogLines(obj, lines)

        % --- Signals tab ---
        syncConvertEnableStates(obj)
        onConvertControlsChanged(obj)
        onResetConvertConfig(obj)
        onBrowseConvertOutput(obj)

        % --- Spikes / Export tabs ---
        syncSpikesEnableStates(obj)
        onSpikesControlsChanged(obj)
        onSpikesPreview(obj)
        onBrowseSpikesOutput(obj)
        onBrowseExportOutput(obj)

        % --- Review tab ---
        loadReviewResults(obj)
        renderReviewPlots(obj)
        onBrowseReviewFolder(obj)
        onOpenReviewFolder(obj)
        onReviewOpenPhy(obj)
        populateReviewDatasets(obj)
        onReviewDatasetChanged(obj)
        onReviewUnitSelected(obj, evt)
        onReviewAllUnits(obj)

        % --- app-wide ---
        loadPreferences(obj)
        savePreferences(obj)
        onClose(obj)
        setStatus(obj, message, hint)
        hint = suggestNextStep(obj)
        onTabChanged(obj)
    end
end
