classdef EphysPreprocessingApp < handle
    %EPHYSPREPROCESSINGAPP  GUI for discovering Intan recordings and running Kilosort4.
    %   EphysPreprocessingApp is a thin front end over EphysProject and
    %   EphysDataset. It does not duplicate any of their logic: scanning,
    %   metadata, reading, filtering, .bin streaming and the Kilosort4 spawn all
    %   happen through those classes. The app only orchestrates them and shows
    %   progress.
    %
    %   Features
    %   --------
    %     1. Datasets   Pick a parent directory, scan recursively for recording
    %                   folders, and view per-dataset metadata in a table.
    %     2. Visualize  Quick time-domain plots of a short window with optional
    %                   filtering / CAR / detrend. Display-only: the underlying
    %                   recording is never modified.
    %     3. Artifacts  Configure the automatic amplitude-deviation detector
    %                   (running-RMS, threshold in robust SDs, with stitching),
    %                   preview per-channel counts and the percent of the
    %                   recording it would zero, and enable blanking on .bin write.
    %     4. Probe      Pick a Kilosort4 probe .json (stored under
    %                   intan/probes by default), with a simple channel-
    %                   count check, and assign it to one or all datasets.
    %     5. Kilosort   Expose Kilosort4 / .bin configuration, save & reload it,
    %                   and batch-process selected datasets (.bin then KS4) with
    %                   per-dataset progress.
    %     6. Convert    Derive LFP / MUA / SPIKE + digital events for the
    %                   selected datasets via EphysDataset.toMat (the
    %                   intan2matlab processing, any recording layout) with
    %                   every option exposed, and save one .mat per dataset
    %                   (default: next to the raw data), with in-tab progress,
    %                   status and a Cancel button.
    %
    %   User preferences (paths, config, and the figure position/size) persist
    %   across sessions via getpref/setpref under the 'IntanKilosortApp'
    %   group (kept at the old name so existing preferences survive the
    %   rename to EphysPreprocessingApp).
    %
    %   Usage
    %   -----
    %     EphysPreprocessingApp;            % launch
    %     app = EphysPreprocessingApp;      % launch and keep a handle
    %
    %   See also EPHYSPROJECT, EPHYSDATASET.

    properties
        Fig   matlab.ui.Figure
        Tabs  matlab.ui.container.TabGroup

        % --- Menu bar ---
        % "Dataset" is the app-wide single-dataset picker (it replaces the
        % per-tab dataset dropdown); one checkable item per scanned dataset.
        DatasetMenu      matlab.ui.container.Menu
        DatasetMenuItems matlab.ui.container.Menu

        % --- Global status bar (bottom strip; see buildUI/setStatus) ---
        StatusBar  matlab.ui.control.Label   % last action / current state
        StatusHint matlab.ui.control.Label   % suggested next action

        TabDatasets  matlab.ui.container.Tab
        TabVisualize matlab.ui.container.Tab
        TabArtifacts matlab.ui.container.Tab
        TabProbe     matlab.ui.container.Tab
        TabKilosort  matlab.ui.container.Tab
        TabReview    matlab.ui.container.Tab
        TabConvert   matlab.ui.container.Tab

        % --- Datasets tab ---
        RootPathField    matlab.ui.control.EditField
        BrowseRootButton matlab.ui.control.Button
        ScanButton       matlab.ui.control.Button
        RefreshMetaButton matlab.ui.control.Button
        DatasetsTable    matlab.ui.control.Table
        ScanStatusLabel  matlab.ui.control.Label

        % --- Visualize tab ---
        VizDatasetLabel    matlab.ui.control.Label   % mirrors the Dataset menu
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
        ArtDetectButton     matlab.ui.control.Button
        ArtSummaryLabel     matlab.ui.control.Label
        ArtChannelTable     matlab.ui.control.Table
        ArtStatusLabel      matlab.ui.control.Label

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

        % --- Kilosort tab ---
        PythonExeField    matlab.ui.control.EditField
        BrowsePythonButton matlab.ui.control.Button
        CondaEnvField     matlab.ui.control.EditField
        OutputRootField   matlab.ui.control.EditField
        BrowseOutputButton matlab.ui.control.Button
        PhyCmdField       matlab.ui.control.EditField

        % --- SpikeInterface preprocessing controls (see gatherSIConfig) ---
        SIFilterCheckBox     matlab.ui.control.CheckBox
        SIFilterMinField     matlab.ui.control.NumericEditField
        SIFilterMaxField     matlab.ui.control.NumericEditField
        SICommonRefCheckBox  matlab.ui.control.CheckBox
        SIRefOperatorDropDown matlab.ui.control.DropDown
        SIDetectBadCheckBox  matlab.ui.control.CheckBox
        SIBadMethodDropDown  matlab.ui.control.DropDown
        SIBadActionDropDown  matlab.ui.control.DropDown

        % Kilosort4 parameter controls, keyed by KS4 settings name. Built from
        % kilosortParamSpec(); see buildKilosortTab / buildKS4Extra.
        ParamControls struct = struct()
        ExtraSettingsArea matlab.ui.control.TextArea
        ExecModeDropDown  matlab.ui.control.DropDown
        DryRunCheckBox    matlab.ui.control.CheckBox
        SaveConfigButton  matlab.ui.control.Button
        LoadConfigButton  matlab.ui.control.Button
        KSDocsLink        matlab.ui.control.Hyperlink
        SIDocsLink        matlab.ui.control.Hyperlink
        RunKilosortButton matlab.ui.control.Button
        LaunchPhyButton   matlab.ui.control.Button
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

        % --- Convert tab (EphysDataset.toMat; see buildConvertTab / onRunConvert) ---
        ConvOutputDirField      matlab.ui.control.EditField
        ConvBrowseOutputButton  matlab.ui.control.Button
        ConvSuffixField         matlab.ui.control.EditField
        ConvMatVersionDropDown  matlab.ui.control.DropDown
        ConvOverwriteCheckBox   matlab.ui.control.CheckBox
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
        ConvKeepChannelsField   matlab.ui.control.EditField
        ConvBadModeDropDown     matlab.ui.control.DropDown
        ConvBadThresholdField   matlab.ui.control.NumericEditField
        ConvBadListField        matlab.ui.control.EditField
        ConvRemapField          matlab.ui.control.EditField
        ConvResetButton         matlab.ui.control.Button
        ConvTargetsTable        matlab.ui.control.Table
        ConvRunButton           matlab.ui.control.Button
        ConvCancelButton        matlab.ui.control.Button
        ConvRefreshButton       matlab.ui.control.Button
        ConvOverallBar          matlab.ui.container.GridLayout   % see setConvertBar
        ConvOverallText         matlab.ui.control.Label
        ConvStepBar             matlab.ui.container.GridLayout
        ConvStepText            matlab.ui.control.Label
        ConvStepLabel           matlab.ui.control.Label
        ConvLogArea             matlab.ui.control.TextArea
    end

    properties
        Project EphysProject = EphysProject.empty
        SelectedRow (1,1) double = 0   % last-clicked datasets-table row (0 = none)

        % Probe tab selection state. ProbeTable shows one row per probe .json;
        % ProbePaths holds the matching full paths (the table itself only shows
        % file names + parsed metadata), and SelectedProbeRow is the active row.
        ProbePaths (1,:) string = string.empty(1,0)
        SelectedProbeRow (1,1) double = 0   % selected ProbeTable row (0 = none)

        % Background Kilosort4 runs awaiting completion + the polling timer.
        % logFile/logPos let the monitor tail each run's ks4_run.log into the
        % status box: logPos is the byte offset already shown.
        KSRuns struct = struct('Name', {}, 'statusFile', {}, 'resultsDir', {}, ...
            'logFile', {}, 'logPos', {}, 'done', {})
        KSMonitorTimer = []

        % --- Visualize interaction state (display-only, in-memory) ---
        % Viewer is the MultiChannelViewer (plotting/@MultiChannelViewer) that
        % owns the cached data, viewport, graphics, and pan/zoom/scroll
        % interaction for the Visualize axes. Constructed on the first Plot
        % press and reused (via Viewer.loadData) on subsequent presses, so its
        % attached KeyMap/mouse callbacks are never re-installed.
        Viewer = []
        % Detected-artifact intervals (window-relative seconds) and the
        % recording-relative time offset of the currently loaded window -- the
        % two pieces of app-specific bookkeeping that don't belong on the
        % generic Viewer. Read by drawVizArtifacts/finishVizArtDrag.
        VizDetectedIntervals = zeros(0, 2)
        VizTimeOffset (1,1) double = 0
        VizDatasetIndex (1,1) double = 0   % index into obj.Project.Datasets
        % Dataset picked in the figure's "Dataset" menu (0 = none). This is the
        % single-dataset target for Visualize; VizDatasetIndex above is the one
        % whose data is actually cached in the Viewer.
        SelectedDatasetIdx (1,1) double = 0
        % 1-based amplifier channels currently loaded into Viewer, in their
        % original (as-typed) order -- i.e. Viewer's data-column order before
        % any probe-depth sort. Read by applyVizChannelOrder to map the
        % Viewer's data columns back to physical .bin channels.
        VizChannels (1,:) double = double.empty(1,0)
        % Byte budget for the cached single-precision Visualize matrix. The
        % loader streams files one at a time and, when the full-resolution span
        % would exceed this, peak-decimates on load so RAM stays bounded
        % regardless of recording length. 0 = auto (see autoMemoryBudget).
        VizMemoryBudget (1,1) double = 0

        % --- Manual artifact marking (Visualize tab) ---
        % When VizArtMode is on, a plain left-drag on the plot defines an
        % artifact period and a left-click inside a marked region removes it.
        % Periods live on the dataset (EphysDataset.ManualArtifacts) and are
        % blanked by toBin; the data on disk is never altered. They are drawn
        % with xregion (handles in VizArtPatches; VizArtPreview is the live
        % rubber-band during a drag).
        VizArtMode (1,1) logical = false
        VizArtDrag = struct('active', false)
        VizArtPatches = gobjects(0,1)
        VizArtPreview = gobjects(0,1)

        % --- Review (Kilosort4 output) state ---
        % ReviewData caches everything parsed from a kilosort4/ results folder so
        % unit selection re-plots without re-reading .npy files. See
        % loadReviewResults / renderReviewPlots.
        ReviewData = struct([])
        ReviewSelectedUnit (1,1) double = 0   % row index into ReviewData unit list (0 = all)

        % --- Convert (EphysDataset.toMat) run state ---
        % ConvRunning guards against re-entry and freezes the targets table;
        % ConvCancelRequested is set by the Cancel button and checked by the
        % toMat/deriveSignals ProgressFcn at each step boundary (see onRunConvert).
        ConvRunning (1,1) logical = false
        ConvCancelRequested (1,1) logical = false
    end

    properties (Constant)
        PrefGroup = 'IntanKilosortApp'
    end

    methods
        function obj = EphysPreprocessingApp()
            % Construct, build the UI, restore preferences.
            obj.buildUI();
            obj.loadPreferences();
            obj.refreshProbeList();

            if nargout == 0
                clear obj
            end
        end

        % --- declared in separate files in this @-folder ---
        buildUI(obj)
        buildDatasetsTab(obj)
        buildVisualizeTab(obj)
        buildArtifactsTab(obj)
        buildProbeTab(obj)
        buildKilosortTab(obj)
        buildReviewTab(obj)
        buildConvertTab(obj)

        onScan(obj)
        refreshDatasetsTable(obj)
        onDatasetCellSelection(obj, evt)
        onRefreshMetadata(obj)

        onDetectArtifacts(obj)

        onPlotVisualization(obj)
        onVizButtonDown(obj)
        onVizButtonUp(obj)
        drawVizArtifacts(obj)
        applyVizChannelOrder(obj)
        applyVizChannelColor(obj)

        refreshProbeList(obj)
        onProbeSelected(obj)
        onImportProbe(obj)
        onDesignProbe(obj)
        result = runProbeTool(obj, varargin)
        onAssignProbe(obj, scope)
        onApplyExclude(obj, scope)

        [extra, errMsg] = buildKS4Extra(obj)
        cfg = gatherKilosortConfig(obj)
        applyKilosortConfig(obj, cfg)
        onSaveConfig(obj)
        onLoadConfig(obj)

        onRunBatch(obj, mode)
        onLaunchPhy(obj)
        launchPhy(obj, resultsDir, label)
        pollKSRuns(obj)

        loadReviewResults(obj)
        renderReviewPlots(obj)

        onRunConvert(obj)
        cfg = gatherConvertConfig(obj)
        applyConvertConfig(obj, cfg)

        loadPreferences(obj)
        savePreferences(obj)

        % --- handlers and helpers in their own files (moved out of the classdef) ---
        startKSMonitor(obj)
        stopKSMonitor(obj)
        onBrowseRoot(obj)
        onBrowseProbeFolder(obj)
        onBrowsePython(obj)
        onBrowseOutput(obj)
        onBrowseReviewFolder(obj)
        onOpenReviewFolder(obj)
        onReviewOpenPhy(obj)
        populateReviewDatasets(obj)
        onReviewDatasetChanged(obj)
        onReviewUnitSelected(obj, evt)
        onReviewAllUnits(obj)
        cfg = defaultConvertConfig(obj)
        syncConvertEnableStates(obj)
        onConvertControlsChanged(obj)
        onResetConvertConfig(obj)
        onBrowseConvertOutput(obj)
        onCancelConvert(obj)
        T = convertTargets(obj, cfg)
        refreshConvertTargets(obj)
        setConvertBar(obj, bar, frac)
        convLog(obj, fmt, varargin)
        onClose(obj)
        setStatus(obj, message, hint)
        hint = suggestNextStep(obj)
        onTabChanged(obj)
        log(obj, fmt, varargin)
        appendLogLines(obj, lines)
        pf = selectedProbeFile(obj)
        onProbeRowSelected(obj, evt)
        onEditProbeJSON(obj)
        syncExcludeField(obj)
        selectProbeRow(obj, row)
        onProbeNotesEdited(obj, evt)
        saveProbeNotes(obj, pf, notes)
        p = defaultProbeFolder(obj)
        p = defaultConfigFolder(obj)
        d = currentDataset(obj)
        updatePhyButtonState(obj)
        applyConfigToProject(obj, P)
        cfg = gatherSIConfig(obj)
        applySIConfig(obj, cfg)
        setDropIfMember(obj, dd, value)
        syncSIEnableStates(obj)
        onSIControlsChanged(obj)
        p = defaultPythonExe(obj)
        populateDatasetMenu(obj)
        selectDataset(obj, idx)
        updateDatasetMenuCheck(obj)
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
        populateArtifactDatasets(obj)
        d = currentArtifactDataset(obj)
        cfg = artifactConfigFromControls(obj)
        applyArtifactConfigToProject(obj)
        onArtifactControlsChanged(obj)
        idx = selectedDatasetIndices(obj)

        %% --- small inline handlers --------------------------------------
        %% --- Review tab handlers -----------------------------------------
        %% --- Convert tab (EphysDataset.toMat / deriveSignals) ------------
        %% --- Global status bar -------------------------------------------
        %% --- Probe tab handlers ------------------------------------------
        %% --- Manual artifact marking (Visualize tab) ---------------------
        %% --- Artifacts tab -----------------------------------------------
    end
end
