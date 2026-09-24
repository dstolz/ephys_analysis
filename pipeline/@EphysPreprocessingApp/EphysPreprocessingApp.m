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
    %     Copy       find one subject's sessions on the source for a day or range,
    %                pair each recording (Intan RHX folder, Open Ephys GUI
    %                session) with its ePsych file by the times in their
    %                names (findCopySessions), stitch the
    %                ePsych files of one recording picked by hand
    %                (stitchCopySessions), preview and
    %                copy the ticked sessions to <destination>/<subject>/<recording
    %                folder> with verification and a manifest (copySessions),
    %                then open the copied sessions as the project. The copy
    %                runs in a detached engine (copy_engine.ps1) polled by a
    %                timer, so it never blocks the app, and an interrupted one
    %                is completed rather than restarted (IfExists="resume").
    %                Scheduled copy: a Windows task copies the new sessions
    %                of chosen subjects at an interval, with no MATLAB open
    %                (CopySchedule); the tab saves it and shows its last run
    %     Project    config name, project root / output root, dataset table
    %                (the Select column is the config's dataset selection),
    %                a Tools panel that opens the active or the ticked
    %                datasets in the manifest viewer, the analysis app, phy
    %                or the file browser, Epsych2 behavior associations
    %     Trials     pair Epsych2 trials in order with the trial digital line,
    %                per-line TTL polarity, resolve a trial / interval count
    %                mismatch by cutting from either end, approve the pairing
    %                (or auto approve the ones whose counts match), prefetch
    %                the digital lines of every ticked dataset at once
    %     Probe      probe library, preview, assignment, per-dataset channel
    %                exclusions, the config's default probe
    %     Artifacts  automatic detection settings + preview, a viewer that steps
    %                through the detected artifacts (what a run removes and
    %                keeps around each), manual periods
    %     Sorting    Kilosort4 settings (Optimize for probe,
    %                Reset to defaults), sorted-output association, Run this
    %                step, background-run log
    %     Signals    derived LFP / MUA / SPIKE / AUX (.mat) settings, plan, Run
    %     Spikes     threshold detection / sorted units (.mat), preview, Run
    %     Export     analysis-toolbox and epoch files (one per format), plan, Run
    %     Diagram    diagram of the working config (View): every parameter,
    %                as one tree from the raw recording, a branch per step
    %                (filters, references, detection parameters, files
    %                written), with the steps that read those files hanging
    %                from them, or a tree per step (Layout); or a data-flow
    %                overview, every step as one box with the files it
    %                writes and an arrow to each step that reads them;
    %                Save as HTML
    %     Run        step checklist (with how many background Kilosort4 runs
    %                go at once, the GPUs they share and whether the Run
    %                hands the waiting ones to the monitor's queue),
    %                validate, plan, run / dry run / cancel, progress,
    %                results (background runs' rows follow them to done /
    %                error), log, Stop runs... / Stop queue; optionally a diagram of the
    %                run's steps (the one underway highlighted, each with
    %                its % done) in the right quarter, and CPU / memory / disk /
    %                GPU use under the steps
    %     Visualize  any signal of the active dataset (recording, Sorting .bin,
    %                LFP / MUA / SPIKE / AUX) with its sorted units and
    %                detected spikes, read a window at a time; mark manual
    %                artifact periods
    %     Review     inspect sorted units
    %     Synthetic  design and write a synthetic dataset (makeSyntheticRecording):
    %                events from the built-in task or from the active
    %                dataset's Epsych2 session (its recorded lines, or lines
    %                rebuilt from the session's parameters); spiking units
    %                whose rate follows a line's edges (latency, duration,
    %                shape, gain, jitter, tuned to an Epsych2 parameter) and
    %                event-locked LFP (phase-locked or induced oscillations,
    %                evoked potentials, a depth profile); preview the
    %                spikes, rasters, PSTHs and LFP it will write, then
    %                Generate. Not a pipeline step
    %     Clean up   free local disk space once datasets are preprocessed, or
    %                remove what chosen preprocessing steps wrote: preview
    %                every local file of the selected datasets as Remove or
    %                Keep (planLocalCleanup), then, after a confirmation,
    %                delete the Remove ones, send them to the Recycle Bin or
    %                move them to a folder (runLocalCleanup). Raw files go
    %                only when the source they were copied from still holds
    %                them. Not a pipeline step
    %
    %   File menu: New / Open / Open recent / Save / Save As / Export copy /
    %   Generate script (compact | standalone) / Create synthetic test
    %   project (makeSyntheticProject: recordings with Epsych2 sessions and
    %   ground-truth sorted output, opened and scanned at once) / Close. The
    %   title shows "*" while the config has unsaved changes.
    %
    %   Help menu: opens the GitHub wiki (WikiURL) in the browser: the page
    %   for the tab that is shown, the home page, the quick start and the
    %   user, scripting and developer guides. Its last two items file
    %   against the repository (RepoURL) instead: Report an issue and
    %   Request a feature open a dialog that collects what the maintainer
    %   would ask for (MATLAB and machine, the working config, the tail of
    %   the logs and the error the last run stopped on), shows the whole
    %   report before anything leaves the app and opens GitHub's new-issue
    %   form with it filled in (onReportIssue, issueReport, issueURL).
    %
    %   The active dataset is what every single-dataset control works on
    %   (Trials, exclusions, previews, the sorted-output association, phy,
    %   Visualize, Review). The Dataset menu, the Dataset box on each of those
    %   tabs and a click on a Project-table row all choose it, and all of them
    %   show it (see selectDataset). Runs, plans and step targets use the
    %   ticked rows instead.
    %
    %   Preferences (getpref group 'EphysPreprocessingApp') hold only what is
    %   not part of a config: figure geometry, probe folder, phy command,
    %   Review folder, last / recent config files, script folder, the
    %   datasets-table column order, the Trials-table parameter columns and
    %   column order, the Trials-plot label parameters, the Visualize
    %   display options, the Copy tab settings, the Synthetic tab's settings
    %   and design, the Diagram tab's view and layout, and the Run tab's
    %   Show the run diagram and Monitor CPU,
    %   memory, disk and GPU switches.
    %
    %   Usage
    %     EphysPreprocessingApp;            % launch
    %     app = EphysPreprocessingApp;      % launch and keep a handle
    %
    %   See also EPHYSPIPELINECONFIG, EPHYSPIPELINE, EPHYSPROJECT, EPHYSDATASET.

    properties
        Fig   matlab.ui.Figure
        Tabs  matlab.ui.container.TabGroup
        TabHost       matlab.ui.container.Panel      % clips the tab group's own headers
        TabList       matlab.ui.container.Tab        % tabs in strip order
        TabButtons    matlab.ui.control.Button       % coloured status strip (one per tab)
        TabMarks      matlab.ui.container.Panel      % selected-tab underline (one per tab)

        % --- Menu bar ---
        FileMenu           matlab.ui.container.Menu
        RecentMenu         matlab.ui.container.Menu
        DatasetMenu        matlab.ui.container.Menu   % chooses the active dataset (selectDataset)
        DatasetTickedItems matlab.ui.container.Menu   % top of the menu: the ticked datasets (UserData = dataset index)
        DatasetAllMenu     matlab.ui.container.Menu   % "All datasets" submenu
        DatasetMenuItems   matlab.ui.container.Menu   % its items, one per dataset (index = dataset index)
        DatasetManifestItem matlab.ui.container.Menu  % bottom of the menu: View manifest (onViewManifest)
        RunMenu            matlab.ui.container.Menu
        HelpMenu           matlab.ui.container.Menu   % wiki pages (helpURL, onHelp) + the issue items (onReportIssue)

        % --- Global status bar ---
        StatusBar  matlab.ui.control.Label
        StatusHint matlab.ui.control.Label

        TabCopy       matlab.ui.container.Tab
        TabProject   matlab.ui.container.Tab
        TabTrials    matlab.ui.container.Tab
        TabProbe     matlab.ui.container.Tab
        TabArtifacts matlab.ui.container.Tab
        TabSorting   matlab.ui.container.Tab
        TabSignals   matlab.ui.container.Tab
        TabSpikes    matlab.ui.container.Tab
        TabExport    matlab.ui.container.Tab
        TabRun       matlab.ui.container.Tab
        TabFlow      matlab.ui.container.Tab
        TabVisualize matlab.ui.container.Tab
        TabReview    matlab.ui.container.Tab
        TabSynthetic matlab.ui.container.Tab
        TabCleanup   matlab.ui.container.Tab

        % --- Copy tab (settings are preferences; findCopySessions / copySessions) ---
        CopySubjectField      matlab.ui.control.EditField
        CopyFromDatePicker    matlab.ui.control.DatePicker
        CopyToDatePicker      matlab.ui.control.DatePicker
        CopyFindButton        matlab.ui.control.Button
        CopyEpsychRootField   matlab.ui.control.EditField
        CopyRecordingRootsField  matlab.ui.control.EditField   % one or more roots, separated by ";"
        CopyDestRootField     matlab.ui.control.EditField
        CopyMaxLeadField      matlab.ui.control.NumericEditField   % minutes
        CopyMaxLagField       matlab.ui.control.NumericEditField   % minutes
        CopyMarginField       matlab.ui.control.NumericEditField   % seconds
        CopyMinDurationField  matlab.ui.control.NumericEditField   % minutes
        CopyVerifyDropDown    matlab.ui.control.DropDown
        CopyIfExistsDropDown  matlab.ui.control.DropDown
        CopyPreviewButton     matlab.ui.control.Button
        CopyRunButton         matlab.ui.control.Button
        CopyStitchButton      matlab.ui.control.Button
        CopyUnstitchButton    matlab.ui.control.Button
        CopySummaryLabel      matlab.ui.control.Label
        CopyScanAfterCheckBox matlab.ui.control.CheckBox
        CopyTable             matlab.ui.control.Table
        CopyLogArea           matlab.ui.control.TextArea
        CopyGrid              matlab.ui.container.GridLayout    % the tab's rows (row 3 is the progress panel)
        CopyProgressPanel     matlab.ui.container.Panel         % only open while a copy runs
        CopyProgressHeadline  matlab.ui.control.Label           % what is being done to which session
        CopyProgressETA       matlab.ui.control.Label           % rate and time left
        CopyProgressTrack     matlab.ui.container.GridLayout    % the bar: its column weights are the fraction
        CopyProgressFill      matlab.ui.container.Panel
        CopyProgressRest      matlab.ui.container.Panel
        CopyPercentLabel      matlab.ui.control.Label
        CopyProgressLabel     matlab.ui.control.Label           % the file the engine is on
        CopyScheduleSubjectsField   matlab.ui.control.EditField          % scheduled copy (CopySchedule)
        CopyScheduleEveryField      matlab.ui.control.NumericEditField   % minutes between runs
        CopyScheduleDaysField       matlab.ui.control.NumericEditField   % days each run looks back
        CopyScheduleQuietField      matlab.ui.control.NumericEditField   % minutes a source must be unchanged
        CopyScheduleRunWhenDropDown matlab.ui.control.DropDown           % ItemsData "signed_in" | "always"
        CopyScheduleSaveButton      matlab.ui.control.Button
        CopyScheduleRemoveButton    matlab.ui.control.Button
        CopyScheduleRunNowButton    matlab.ui.control.Button
        CopyScheduleLogButton       matlab.ui.control.Button
        CopyScheduleStatusLabel     matlab.ui.control.Label              % refreshCopySchedule

        % --- Project tab ---
        ConfigNameField   matlab.ui.control.EditField
        ConfigDescField   matlab.ui.control.EditField
        RootPathField     matlab.ui.control.EditField
        BrowseRootButton  matlab.ui.control.Button
        RecursiveCheckBox matlab.ui.control.CheckBox
        OERecordingsDropDown matlab.ui.control.DropDown   % Acquisition.OpenEphys.Recordings
        OERecordNodeField    matlab.ui.control.EditField  % Acquisition.OpenEphys.RecordNode ("" = automatic)
        OEStreamField        matlab.ui.control.EditField  % Acquisition.OpenEphys.Stream ("" = automatic)
        ScanButton        matlab.ui.control.Button
        RefreshMetaButton matlab.ui.control.Button
        SelectAllButton   matlab.ui.control.Button
        SelectNoneButton  matlab.ui.control.Button
        OutputRootField   matlab.ui.control.EditField
        BrowseOutputButton matlab.ui.control.Button
        NamePatternField  matlab.ui.control.EditField
        NameTokenGrid     matlab.ui.container.GridLayout
        NameTokenChecks   matlab.ui.control.CheckBox   % one per pattern token: show as a table column
        NameTokenStatusLabel matlab.ui.control.Label
        NameTokenFilterGrid  matlab.ui.container.GridLayout
        NameTokenFilters  matlab.ui.control.DropDown   % one per pattern token: row filter (UserData = token name)
        DatasetsTable     matlab.ui.control.Table
        ScanStatusLabel   matlab.ui.control.Label
        % Tools panel (beside the table): open datasets in other programs (onOpenTool)
        ToolsScopeDropDown  matlab.ui.control.DropDown   % ItemsData "active" | "ticked" (toolTargets)
        ToolsTargetLabel    matlab.ui.control.Label      % names what the buttons open (syncToolsPanel)
        ToolsManifestButton matlab.ui.control.Button
        ToolsAnalysisButton matlab.ui.control.Button
        ToolsPhyButton      matlab.ui.control.Button
        ToolsFolderButton   matlab.ui.control.Button
        BehEnableCheckBox    matlab.ui.control.CheckBox
        BehSearchCheckBox    matlab.ui.control.CheckBox
        BehSearchDirsField   matlab.ui.control.EditField
        BehBrowseButton      matlab.ui.control.Button
        BehMatchDropDown     matlab.ui.control.DropDown
        BehMaxOffsetField    matlab.ui.control.NumericEditField
        BehFindButton        matlab.ui.control.Button
        BehStatusLabel       matlab.ui.control.Label
        BehOverwriteCheckBox matlab.ui.control.CheckBox
        BehWriteFileCheckBox matlab.ui.control.CheckBox
        BehAssociateButton   matlab.ui.control.Button
        BehClearButton       matlab.ui.control.Button

        % --- Trials tab ---
        TrialsDatasetDropDown matlab.ui.control.DropDown
        TrialsLoadButton      matlab.ui.control.Button
        TrialsPrefetchButton  matlab.ui.control.Button
        TrialsResetButton     matlab.ui.control.Button
        TrialsApproveButton   matlab.ui.control.Button
        TrialsRevokeButton    matlab.ui.control.Button
        TrialsWriteButton     matlab.ui.control.Button
        TrialsEpsychToWorkspaceButton   matlab.ui.control.Button
        TrialsBehaviorToWorkspaceButton matlab.ui.control.Button
        TrialsSummaryLabel    matlab.ui.control.Label
        TrialsPairCheckBox    matlab.ui.control.CheckBox
        TrialsAutoApproveCheckBox matlab.ui.control.CheckBox
        TrialsLineDropDown    matlab.ui.control.DropDown
        TrialsLinesTable      matlab.ui.control.Table
        TrialsCutSpinners     % 2 x 2 matlab.ui.control.Spinner: rows trials / intervals, columns start / end
        TrialsCutIntervalsLabel matlab.ui.control.Label
        TrialsTable           matlab.ui.control.Table
        TrialsAxes            matlab.ui.control.UIAxes
        TrialsEdgesMenu       matlab.ui.container.Menu   % plot context menu: trial onset / offset lines (checked = shown)
        TrialsGridMenu        matlab.ui.container.Menu   % plot context menu: grid lines (checked = shown)
        TrialsLabelsMenu      matlab.ui.container.Menu   % plot context menu: Trial labels submenu (rebuilt as it opens)

        % --- Visualize tab ---
        VizDatasetDropDown matlab.ui.control.DropDown
        VizSourceDropDown  matlab.ui.control.DropDown     % the signal shown (Show)
        VizSourceNoteLabel matlab.ui.control.Label        % what that signal is
        VizChannelsField   matlab.ui.control.EditField
        VizLanesField      matlab.ui.control.NumericEditField   % lanes shown at once
        VizRefDropDown     matlab.ui.control.DropDown
        VizHighpassField   matlab.ui.control.EditField
        VizLowpassField    matlab.ui.control.EditField
        VizOrderField      matlab.ui.control.NumericEditField
        VizOffsetCheckBox  matlab.ui.control.CheckBox     % centre each lane on its median
        VizPlotButton      matlab.ui.control.Button       % Reload data
        VizUnitsCheckBox   matlab.ui.control.CheckBox
        VizUnitStyleDropDown matlab.ui.control.DropDown   % ticks / waveforms
        VizUnitGroupsDropDown matlab.ui.control.DropDown  % which units by label
        VizDetectedCheckBox matlab.ui.control.CheckBox
        VizDetectedStyleDropDown matlab.ui.control.DropDown
        VizPlacementDropDown matlab.ui.control.DropDown   % spikes on their channel's lane / lanes of their own
        VizSpikesLabel     matlab.ui.control.Label
        VizStartField      matlab.ui.control.NumericEditField
        VizDurField        matlab.ui.control.NumericEditField
        VizSpacingField    matlab.ui.control.NumericEditField
        VizModeDropDown    matlab.ui.control.DropDown
        VizColormapDropDown matlab.ui.control.DropDown
        VizSortByProbeCheckBox matlab.ui.control.CheckBox
        VizColorByShankCheckBox matlab.ui.control.CheckBox
        VizShadingCheckBox matlab.ui.control.CheckBox
        VizArtButton       matlab.ui.control.StateButton
        VizArtClearButton  matlab.ui.control.Button
        VizArtStatusLabel  matlab.ui.control.Label
        VizHelpLabel       matlab.ui.control.Label
        VizToolbarButtons  % 1 x 8 matlab.ui.control.Button: page, zoom, scale, auto scale, reset
        VizStatusLabel     matlab.ui.control.Label
        VizAxes            matlab.ui.control.UIAxes
        VizOverviewAxes    matlab.ui.control.UIAxes       % the whole recording under the plot

        % --- Artifacts tab ---
        ArtDatasetDropDown  matlab.ui.control.DropDown
        ArtRefDropDown      matlab.ui.control.DropDown           % common reference: none / car / cmr
        ArtRefLowField      matlab.ui.control.NumericEditField   % good-noise band (x median) of the suggestion
        ArtRefHighField     matlab.ui.control.NumericEditField
        ArtRefExcludeField  matlab.ui.control.EditField          % active dataset's channels left out of the reference
        ArtRefSuggestButton matlab.ui.control.Button
        ArtRefStatusLabel   matlab.ui.control.Label
        ArtEnableCheckBox   matlab.ui.control.CheckBox
        ArtMethodDropDown   matlab.ui.control.DropDown
        ArtThresholdField   matlab.ui.control.NumericEditField
        ArtRmsWindowField   matlab.ui.control.NumericEditField
        ArtMergeGapField    matlab.ui.control.NumericEditField
        ArtMinChannelsField matlab.ui.control.NumericEditField
        ArtPadField         matlab.ui.control.NumericEditField
        ArtFilterCheckBox   matlab.ui.control.CheckBox
        ArtHighpassField    matlab.ui.control.NumericEditField
        ArtFillDropDown     matlab.ui.control.DropDown           % what replaces the artifact samples
        ArtApplySortingCheckBox matlab.ui.control.CheckBox
        ArtApplySpikesCheckBox  matlab.ui.control.CheckBox
        ArtApplySignalsCheckBox matlab.ui.control.CheckBox
        ArtCacheCheckBox    matlab.ui.control.CheckBox
        ArtProbeOrderCheckBox matlab.ui.control.CheckBox         % plot / table in probe order (syncArtProbeControls)
        ArtDetectButton     matlab.ui.control.Button
        ArtSummaryLabel     matlab.ui.control.Label
        ArtChannelTable     matlab.ui.control.Table
        ArtStatusLabel      matlab.ui.control.Label
        ArtManualLabel      matlab.ui.control.Label
        ArtEditVizButton    matlab.ui.control.Button
        ArtManualClearButton matlab.ui.control.Button
        ArtManualTable      matlab.ui.control.Table
        ArtViewPrevButton   matlab.ui.control.Button             % artifact viewer (showArtifactView)
        ArtViewSpinner      matlab.ui.control.Spinner
        ArtViewCountLabel   matlab.ui.control.Label
        ArtViewNextButton   matlab.ui.control.Button
        ArtViewContextField matlab.ui.control.NumericEditField
        ArtViewChannelsField matlab.ui.control.NumericEditField
        ArtViewScaleDropDown matlab.ui.control.DropDown
        ArtViewLanesField   matlab.ui.control.NumericEditField   % uV between lanes (Scale: Manual)
        ArtViewShankDropDown matlab.ui.control.DropDown
        ArtViewShankColorCheckBox matlab.ui.control.CheckBox
        ArtViewResetButton  matlab.ui.control.Button
        ArtViewNoteLabel    matlab.ui.control.Label              % what red / black mean on a run
        ArtViewAxes         matlab.ui.control.UIAxes

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
        ProbeDatasetDropDown matlab.ui.control.DropDown
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
        KSOptimizeButton  matlab.ui.control.Button
        KSResetButton     matlab.ui.control.Button
        % Kilosort4 parameter controls keyed by settings name (kilosortParamSpec).
        ParamControls struct = struct()
        ExtraSettingsArea matlab.ui.control.TextArea
        KSDocsLink        matlab.ui.control.Hyperlink
        SortDatasetDropDown matlab.ui.control.DropDown
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
        ReviewUnitShankAxes matlab.ui.control.UIAxes          % the selected unit's spikes on its shank
        ReviewShankSpikesCheckBox matlab.ui.control.CheckBox
        ReviewShankCountSpinner matlab.ui.control.Spinner
        ReviewShankMeanCheckBox matlab.ui.control.CheckBox
        ReviewShankBandDropDown matlab.ui.control.DropDown

        % --- Synthetic tab (makeSyntheticRecording; every setting is a preference) ---
        SynthSourceDropDown   matlab.ui.control.DropDown          % ItemsData "task" | "recording" | "session"
        SynthDatasetDropDown  matlab.ui.control.DropDown          % datasetPicker
        SynthLoadButton       matlab.ui.control.Button
        SynthPreviewButton    matlab.ui.control.Button
        SynthGenerateButton   matlab.ui.control.Button
        SynthStatusLabel      matlab.ui.control.Label
        SynthTrialsSpinner    matlab.ui.control.Spinner           % built-in task: trials
        SynthScenarioDropDown matlab.ui.control.DropDown          % built-in task: scenario
        SynthTrialDurField    matlab.ui.control.EditField         % rebuilt session: trial duration (ms expression)
        SynthLinesTable       matlab.ui.control.Table             % rebuilt session: Line | Onset | Duration (ms expressions)
        SynthAddLineButton    matlab.ui.control.Button
        SynthRemoveLineButton matlab.ui.control.Button
        SynthFormatDropDown   matlab.ui.control.DropDown
        SynthFsField          matlab.ui.control.NumericEditField
        SynthChannelsField    matlab.ui.control.NumericEditField
        SynthSeedField        matlab.ui.control.NumericEditField
        SynthSubjectField     matlab.ui.control.EditField
        SynthFileSecondsField matlab.ui.control.NumericEditField
        SynthMaxDurField      matlab.ui.control.NumericEditField  % dataset sources: length limit (s), 0 = whole
        SynthSortedCheckBox   matlab.ui.control.CheckBox
        SynthArtifactsCheckBox matlab.ui.control.CheckBox
        SynthProbeLabel       matlab.ui.control.Label
        SynthUnitsTable       matlab.ui.control.Table             % SyntheticDesign.Units (synthColumns order)
        SynthAddUnitButton    matlab.ui.control.Button
        SynthRemoveUnitButton matlab.ui.control.Button
        SynthBuiltInButton    matlab.ui.control.Button
        SynthClearButton      matlab.ui.control.Button
        SynthLFPTable         matlab.ui.control.Table             % SyntheticDesign.LFP (synthColumns order)
        SynthAddOscButton     matlab.ui.control.Button
        SynthAddEvokedButton  matlab.ui.control.Button
        SynthRemoveLFPButton  matlab.ui.control.Button
        SynthRhythmField      matlab.ui.control.NumericEditField  % SyntheticDesign.Background
        SynthPinkField        matlab.ui.control.NumericEditField
        SynthNoiseField       matlab.ui.control.NumericEditField
        SynthLineNoiseField   matlab.ui.control.NumericEditField
        SynthLineFreqDropDown matlab.ui.control.DropDown
        SynthOutputField      matlab.ui.control.EditField         % output root ("" = <project root>_synthetic)
        SynthBrowseOutputButton matlab.ui.control.Button
        SynthLoadDesignButton matlab.ui.control.Button
        SynthSaveDesignButton matlab.ui.control.Button
        SynthUnitDropDown     matlab.ui.control.DropDown          % preview: the unit shown (ItemsData = index)
        SynthLFPDropDown      matlab.ui.control.DropDown          % preview: the LFP component shown
        SynthTimelineStartField matlab.ui.control.NumericEditField
        SynthTimelineSpanField  matlab.ui.control.NumericEditField
        SynthTimelineAxes     matlab.ui.control.UIAxes
        SynthRasterAxes       matlab.ui.control.UIAxes
        SynthPSTHAxes         matlab.ui.control.UIAxes
        SynthLFPAxes          matlab.ui.control.UIAxes
        SynthProfileAxes      matlab.ui.control.UIAxes

        % --- Clean up tab (planLocalCleanup / runLocalCleanup; the kinds ticked and where files go are preferences) ---
        CleanupScopeLabel         matlab.ui.control.Label
        CleanupRawCheckBox        matlab.ui.control.CheckBox
        CleanupSorterCopyCheckBox matlab.ui.control.CheckBox
        CleanupBinCheckBox        matlab.ui.control.CheckBox
        CleanupStepCheckBoxes     matlab.ui.control.CheckBox   % one per step that writes files; Tag = the step name
        CleanupMethodDropDown     matlab.ui.control.DropDown   % where removed files go: "delete" | "recycle" | "move"
        CleanupDestField          matlab.ui.control.EditField  % the folder for "move"
        CleanupDestButton         matlab.ui.control.Button
        CleanupMethodNote         matlab.ui.control.Label
        CleanupPreviewButton      matlab.ui.control.Button
        CleanupRunButton          matlab.ui.control.Button
        CleanupSummaryLabel       matlab.ui.control.Label
        CleanupSearchField        matlab.ui.control.EditField
        CleanupSubjectDropDown    matlab.ui.control.DropDown
        CleanupTable              matlab.ui.control.Table
        CleanupShowKeptCheckBox   matlab.ui.control.CheckBox
        CleanupShownLabel         matlab.ui.control.Label
        CleanupSelectButtons      matlab.ui.control.Button   % All / None / Only / Invert visible
        CleanupLogArea            matlab.ui.control.TextArea

        % --- Signals tab (config Signals; gather/applyConvertConfig) ---
        SigEnableCheckBox       matlab.ui.control.CheckBox
        ConvOutputDirField      matlab.ui.control.EditField
        ConvBrowseOutputButton  matlab.ui.control.Button
        ConvSuffixField         matlab.ui.control.EditField
        ConvMatVersionDropDown  matlab.ui.control.DropDown
        ConvOverwriteCheckBox   matlab.ui.control.CheckBox
        ConvSeparateFilesCheckBox matlab.ui.control.CheckBox
        ConvLFPCheckBox         matlab.ui.control.CheckBox
        ConvMUACheckBox         matlab.ui.control.CheckBox
        ConvSPIKECheckBox       matlab.ui.control.CheckBox
        ConvAUXCheckBox         matlab.ui.control.CheckBox
        SigBlankArtifactsCheckBox matlab.ui.control.CheckBox   % erase the artifact periods before deriving
        SigRefLFPCheckBox       matlab.ui.control.CheckBox     % the common reference subtracted from the LFP
        SigRefMUACheckBox       matlab.ui.control.CheckBox     % ... from the MUA
        SigRefSPIKECheckBox     matlab.ui.control.CheckBox     % ... from the SPIKE band
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
        SpkArtifactModeDropDown matlab.ui.control.DropDown   % artifact periods: reject / erase / none
        SpkChunkField        matlab.ui.control.EditField
        SpkEdgePadField      matlab.ui.control.EditField
        SpkGroupsField       matlab.ui.control.EditField
        SpkIncludeNoiseCheckBox matlab.ui.control.CheckBox
        SpkTemplatesCheckBox matlab.ui.control.CheckBox
        SpkOutputDirField    matlab.ui.control.EditField
        SpkBrowseOutputButton matlab.ui.control.Button
        SpkSuffixField       matlab.ui.control.EditField
        SpkOverwriteCheckBox matlab.ui.control.CheckBox
        SpkMatVersionDropDown matlab.ui.control.DropDown
        SpkDatasetDropDown   matlab.ui.control.DropDown
        SpkPreviewButton     matlab.ui.control.Button
        SpkPreviewSecondsField matlab.ui.control.NumericEditField
        SpkPreviewLabel      matlab.ui.control.Label
        SpkPreviewTable      matlab.ui.control.Table
        RunStepSpikesButton  matlab.ui.control.Button

        % --- Export tab ---
        ExpEnableCheckBox    matlab.ui.control.CheckBox
        ExpChronuxCheckBox   matlab.ui.control.CheckBox
        ExpFieldTripCheckBox matlab.ui.control.CheckBox
        ExpEpochsCheckBox    matlab.ui.control.CheckBox
        ExpSignalsField      matlab.ui.control.EditField
        ExpUnitsCheckBox     matlab.ui.control.CheckBox
        ExpGroupsField       matlab.ui.control.EditField
        ExpDetectedCheckBox  matlab.ui.control.CheckBox
        ExpEventsCheckBox    matlab.ui.control.CheckBox
        ExpValidateCheckBox  matlab.ui.control.CheckBox
        ExpEpochSourceDropDown     matlab.ui.control.DropDown
        ExpEpochLineField          matlab.ui.control.EditField
        ExpEpochPreField           matlab.ui.control.NumericEditField
        ExpEpochPostField          matlab.ui.control.NumericEditField
        ExpEpochOnsetRuleDropDown  matlab.ui.control.DropDown
        ExpEpochIncompleteDropDown matlab.ui.control.DropDown
        ExpEpochNonFiniteDropDown  matlab.ui.control.DropDown
        ExpEpochArtifactsDropDown  matlab.ui.control.DropDown
        ExpEpochSpikeBaseDropDown  matlab.ui.control.DropDown
        ExpEpochClassDropDown      matlab.ui.control.DropDown
        ExpEpochsToWorkspaceButton matlab.ui.control.Button
        ExpOutputDirField    matlab.ui.control.EditField
        ExpBrowseOutputButton matlab.ui.control.Button
        ExpOverwriteCheckBox matlab.ui.control.CheckBox
        ExpMatVersionDropDown matlab.ui.control.DropDown
        ExpTargetsTable      matlab.ui.control.Table
        RunStepExportButton  matlab.ui.control.Button
        ExpRefreshButton     matlab.ui.control.Button

        % --- Flow tab ---
        FlowRefreshButton matlab.ui.control.Button
        FlowSaveButton    matlab.ui.control.Button
        FlowOpenButton    matlab.ui.control.Button
        FlowViewDropDown  matlab.ui.control.DropDown   % every parameter | data-flow overview (a preference)
        FlowLayoutDropDown matlab.ui.control.DropDown
        FlowSummaryLabel  matlab.ui.control.Label
        FlowHTML          matlab.ui.control.HTML
        % Controls a click in the Diagram marked, with the look to put back
        % (onFlowNavigate / clearFlowHighlight).
        FlowHighlight struct = struct('Control', {}, 'Saved', {})

        % --- Run tab ---
        RunBehaviorCheckBox  matlab.ui.control.CheckBox
        RunArtifactsCheckBox matlab.ui.control.CheckBox
        RunSortingCheckBox   matlab.ui.control.CheckBox
        RunKSAtOnceSpinner   matlab.ui.control.Spinner        % Sorting.MaxConcurrent
        RunKSDevicesField    matlab.ui.control.EditField      % Sorting.Devices ("cuda:0, cuda:1")
        RunKSQueueCheckBox   matlab.ui.control.CheckBox       % hand waiting runs to the monitor (a preference)
        RunSignalsCheckBox   matlab.ui.control.CheckBox
        RunSpikesCheckBox    matlab.ui.control.CheckBox
        RunExportCheckBox    matlab.ui.control.CheckBox
        RunParallelCheckBox  matlab.ui.control.CheckBox
        RunMaxWorkersField   matlab.ui.control.EditField
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
        RunKSStopRunsButton  matlab.ui.control.Button         % stop running Kilosort4 runs (onStopKSRuns)
        RunKSStopQueueButton matlab.ui.control.Button         % drop the queued Kilosort4 runs (onStopKSQueue)
        RunDiagramCheckBox   matlab.ui.control.CheckBox       % Show the run diagram (a preference)
        RunSplitGrid         matlab.ui.container.GridLayout   % right side: progress / results / log | diagram
        RunDiagramPanel      matlab.ui.container.Panel
        RunDiagramHTML       matlab.ui.control.HTML           % runDiagramHTML; Data from refreshRunDiagram
        RunLeftGrid          matlab.ui.container.GridLayout   % the tab's grid: Steps panel over Resource use
        RunMonitorCheckBox   matlab.ui.control.CheckBox       % Monitor CPU, memory, disk and GPU (a preference)
        RunMonitorPanel      matlab.ui.container.Panel        % Resource use, under the Steps panel
        RunMonitorBars       matlab.ui.container.GridLayout   % CPU, memory, disk, GPU (see setRunBar)
        RunMonitorTexts      matlab.ui.control.Label          % ... their figures
        RunMonitorNote       matlab.ui.control.Label
    end

    properties
        Project EphysProject = EphysProject.empty
        % The active dataset (index into Project.Datasets, 0 = none): what the
        % single-dataset controls on every tab work on. Set by selectDataset,
        % and by onScan, which finds the same recording in the new project.
        SelectedDatasetIdx (1,1) double = 0
        DatasetPickers matlab.ui.control.DropDown   % every tab's Dataset box (datasetPicker)
        HiddenSelectedKeys (1,:) string = string.empty(1,0)   % ticked dataset keys hidden by the token filters
        DatasetsColumnOrder (1,:) string = string.empty(1,0)  % datasets-table variables in display order (a preference)

        % --- config model ---
        Config EphysPipelineConfig = EphysPipelineConfig()   % working copy
        SavedConfigStruct struct = struct()                   % last saved / opened state
        Applying (1,1) logical = false     % true while applyConfig pushes values (suppresses onConfigChanged)
        % Config values a control could not show while applyConfig pushed a
        % config ("Section.Field = value (shown as ...)"; setControlValue).
        ApplyRejected (1,:) string = string.empty(1,0)
        RecentConfigs (1,:) string = string.empty(1,0)
        ScriptFolder (1,1) string = ""

        % --- run state ---
        Pipe = []                          % the EphysPipeline being run (for Cancel)
        % The last Run's Results table (Step, Dataset, Status, Message,
        % Output, Seconds), kept while a Plan fills the results table: the
        % monitor restates a background run's row here as the run ends.
        RunResults table = EphysPipeline.emptyResults()
        RunActive (1,1) logical = false
        % The Run tab diagram's model: phase, times, results so far, one entry
        % per step (resetRunDiagram / updateRunDiagram / finishRunDiagram).
        RunDiagram struct = struct('phase', "idle")
        % The resource sampler (resource_monitor.ps1) being shown: its folder
        % ("" = none), launch time and interval, and the timer reading it.
        ResourceMonitor struct = struct('dir', "", 'started', NaT, 'interval', 2)
        ResourceMonitorTimer = []

        % Probe tab selection state.
        ProbePaths (1,:) string = string.empty(1,0)
        SelectedProbeRow (1,1) double = 0

        % Background Kilosort4 runs awaiting completion + the polling timer.
        KSRuns struct = EphysPipeline.emptyRuns()
        % Runs whose files are written, waiting for the monitor to start them
        % when a slot frees (queueKSRun): the dataset and the prepared result.
        KSQueue struct = struct('Name', {}, 'dataset', {}, 'prepared', {})
        KSMonitorTimer = []

        % --- Visualize interaction state (display-only, in-memory) ---
        Viewer = []                % EphysTraceViewer on VizAxes
        % The dataset the plot shows (may differ from the active one). A
        % handle, so a rescan that rebuilds the datasets cannot point it at
        % another recording (onScan rebinds it to the same folder).
        VizDataset EphysDataset = EphysDataset.empty
        % What was loaded for it (onPlotVisualization): sources (its
        % EphysTraceSource array), units, detected, layers, notes.
        VizData = []
        VizSourceKind (1,1) string = "recording"   % the kind shown, kept across datasets
        VizGesture (1,1) string = ""               % "pan" | "seek" | "mark" while a button is held
        VizArtMode (1,1) logical = false
        VizArtDrag = struct('active', false)

        % --- Artifacts tab viewer (in memory; showArtifactView / drawArtifactView) ---
        % intervals: the last preview's detected artifacts (recording-relative
        % s) and previewed: whether a preview ran for the active dataset;
        % settings: the detection settings it ran with (a change makes it
        % stale); summary: its analyzeArtifacts result (the per-channel
        % table); chunk: the last chunk read, for readers without random
        % access; win: the window being drawn; drawn: what the axes show
        % (the window's key, its full time span and envelope resolution);
        % gain: the voltage scale (onArtViewInput); layout / layoutKey: the
        % active dataset's channelLayout and the dataset + probe it is for;
        % mods: the modifier keys held (wheel events carry none).
        ArtView struct = struct('intervals', zeros(0, 2), 'previewed', false, ...
            'settings', struct(), 'summary', [], 'chunk', [], 'win', [], ...
            'drawn', struct('key', [], 'span', [0 1], 'factor', 1, 'decimated', false), 'gain', 1, ...
            'layout', [], 'layoutKey', "", 'mods', strings(1, 0))

        % Figure wheel / key handlers installed before routeFigureInput:
        % they get the events when neither the Artifacts nor the Visualize
        % tab is showing.
        FigInput struct = struct('scroll', [], 'key', [], 'release', [])

        % --- Trials tab state (in memory; the pairing is saved via Approve) ---
        TrialsEvents = []                    % EphysDataset.digitalEvents(Relabel=false) of the loaded dataset (native-keyed; see namedTrialsEvents)
        TrialsEventsIdx (1,1) double = 0     % dataset index TrialsEvents belongs to
        TrialsPairing = []                   % EphysDataset.pairTrials result shown
        TrialsSession = []                   % EphysDataset.readBehavior trials of the loaded dataset
        TrialsParamColumns (1,:) string = string.empty(1,0)  % Epsych2 parameters shown as Trials-table columns (a preference)
        TrialsLabelParams (1,:) string = string.empty(1,0)   % Epsych2 parameters shown as trial labels in the Trials plot (a preference)
        TrialsColumnOrder (1,:) string = string.empty(1,0)   % Trials-table variables in display order (a preference)

        % --- Copy tab state (in memory) ---
        CopyFound = []                                  % findCopySessions table as found (Unstitch restores rows from it)
        CopySessions = []                               % the table shown: CopyFound after stitching (DestDir updated by a copy)
        CopyTicked (:,1) logical = false(0, 1)          % Copy ticks, one per row
        CopyStatus (:,1) string = strings(0, 1)         % last copySessions CopyStatus per row
        CopyMessage (:,1) string = strings(0, 1)        % ... and its Message
        CopyJob = []                                    % copySessions job while a background copy runs ([] when idle)
        CopyRows (:,1) double = zeros(0, 1)             % CopySessions rows that job was made from, in order
        CopyMonitorTimer = []                           % timer polling CopyJob (startCopyMonitor)
        CopyCancelRequested (1,1) logical = false       % Cancel copy was pressed; the engine stops at once
        CopyStarted = []                                % tic when the running batch was launched (rate and time left)
        CopyRateHistory (:,2) double = zeros(0, 2)      % [seconds, bytes] over the last few seconds
        CopyLiveRow (1,1) double = 0                    % CopySessions row the engine is inside (0: none)
        CopyLiveFrac (1,1) double = 0                   % how far through that row it is
        CopyLivePos (1,1) double = 0                    % its place in the batch: later rows are still waiting
        CopyLivePhase (1,1) string = ""                 % "copying" | "verifying" | "stitching" | "done"
        CopyScheduler CopySchedule = CopySchedule()     % this user's scheduled copy (a test points it elsewhere)
        CopyScheduleTimer = []                          % refreshes its state while a scheduled run is under way

        % --- Review (Kilosort4 output) state ---
        ReviewData = struct([])
        ReviewSelectedUnit (1,1) double = 0
        ReviewDatasetIdx (1,1) double = 0    % dataset the tab last showed (-1 = reload; syncReviewDataset)
        ReviewSpikeWaves = struct([])        % the last unit's spikes read for the shank plot (renderReviewUnitShank)

        % Epsych2 session summaries for the Project table's Behavior column,
        % by file (epsychSessionMeta, read again when the file changes;
        % refreshDatasetsTable). A containers.Map, made on first use.
        EpsychMetaCache = []

        % --- Synthetic tab state (in memory) ---
        SynthSource = []                     % the schedule loaded (syntheticTaskSchedule / syntheticSessionSchedule)
        SynthSourceKey (1,1) string = ""     % what it was loaded for (synthSourceKey)
        SynthModel = []                      % the last preview: makeSyntheticRecording(PreviewOnly=true)

        % --- Clean up tab state (in memory) ---
        CleanupPlan = []                                        % planLocalCleanup table + Subject, Include ([] = no preview)
        CleanupPlanKeys (1,:) string = string.empty(1, 0)       % dataset keys it was made for
        CleanupRowMap (:,1) double = zeros(0, 1)                % CleanupPlan row of each CleanupTable.Data row

        % --- the last run error (Help > Report an issue sends it; issueReport) ---
        LastError MException = MException.empty(0, 1)   % what a run stopped on ([] when none)
        LastErrorTime (1,1) datetime = NaT              % when it was caught
    end

    properties (Constant)
        PrefGroup = 'EphysPreprocessingApp'
        RepoURL = "https://github.com/dstolz/ephys_analysis"        % the repository the issue items file against
        WikiURL = "https://github.com/dstolz/ephys_analysis/wiki"   % the Help menu's pages
    end

    methods
        function obj = EphysPreprocessingApp()
            % Construct, build the UI, restore preferences and the last config.
            obj.buildUI();
            obj.loadPreferences();
            obj.refreshCopySchedule(Fill=true);
            obj.refreshProbeList();
            obj.updateTitle();

            if nargout == 0
                clear obj
            end
        end

        % --- UI construction ---
        buildUI(obj)
        buildMenus(obj)
        buildCopyTab(obj)
        buildProjectTab(obj)
        buildTrialsTab(obj)
        buildProbeTab(obj)
        buildArtifactsTab(obj)
        buildSortingTab(obj)
        buildSignalsTab(obj)
        buildSpikesTab(obj)
        buildExportTab(obj)
        buildRunTab(obj)
        buildFlowTab(obj)
        buildVisualizeTab(obj)
        buildReviewTab(obj)
        buildSyntheticTab(obj)
        buildCleanupTab(obj)

        % --- config model ---
        cfg = gatherConfig(obj)
        rejected = applyConfig(obj, cfg, opts)
        setControlValue(obj, ctrl, value, name)
        t = numberText(obj, v)
        onConfigChanged(obj)
        updateTitle(obj)
        syncStepEnableStates(obj)
        syncTabStrip(obj)
        selectTab(obj, tab)
        P = gatherProjectSection(obj)
        applyProjectSection(obj, P)
        A = gatherAcquisitionSection(obj)
        applyAcquisitionSection(obj, A)
        onAcquisitionChanged(obj)
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
        P = gatherParallelSection(obj)
        applyParallelSection(obj, P)
        E = gatherExportSection(obj)
        applyExportSection(obj, E)
        onNewConfig(obj)
        onOpenConfig(obj)
        ok = openConfigFile(obj, file)
        ok = onSaveConfig(obj)
        ok = onSaveConfigAs(obj)
        onExportConfigCopy(obj)
        onGenerateScript(obj, kind)
        onCreateSyntheticProject(obj)
        a = onOpenAnalysisApp(obj, idx)
        S = createSyntheticProject(obj, root, opts)
        ok = confirmDiscard(obj)
        addRecentConfig(obj, file)
        refreshRecentMenu(obj)
        p = defaultConfigFolder(obj)

        % --- running ---
        pipe = buildPipeline(obj)
        tf = projectAtRoot(obj, root)
        tf = refuseWhileRunning(obj, what)
        runPipeline(obj, opts)
        onPipelineProgress(obj, evt)
        onRunStep(obj, step)
        onCancelRun(obj)
        onParallelControlsChanged(obj)
        onValidate(obj)
        showIssues(obj, issues)
        onPlan(obj)
        refreshStepPlan(obj, step)
        runLog(obj, fmt, varargin)
        setRunBar(obj, bar, frac)
        onRunDiagramToggled(obj)
        resetRunDiagram(obj, steps, dryRun)
        updateRunDiagram(obj, evt)
        finishRunDiagram(obj, R, outcome, note)
        refreshRunDiagram(obj)
        html = runDiagramHTML(obj)
        onResourceMonitorToggled(obj)
        startResourceMonitor(obj)
        stopResourceMonitor(obj)
        pollResourceMonitor(obj)
        showResourceSample(obj, S)

        % --- Copy tab ---
        onCopyFind(obj)
        onCopyRun(obj, dryRun)
        onCopyCancel(obj)
        startCopyMonitor(obj)
        stopCopyMonitor(obj)
        pollCopyJob(obj)
        setCopyRunning(obj, running)
        applyCopyResult(obj, sel, R)
        finishCopyRun(obj, R)
        showCopyProgress(obj, frac, msg, info)
        s = copySummaryText(obj, title, R)
        refreshCopyTable(obj)
        onCopyTableEdited(obj, evt)
        onCopyStitch(obj)
        onCopyUnstitch(obj)
        onBrowseCopyFolder(obj, field)
        roots = copyRecordingRoots(obj)
        copyLog(obj, msg)
        refreshCopySchedule(obj, opts)
        onCopyScheduleSave(obj)
        onCopyScheduleRemove(obj)
        onCopyScheduleRunNow(obj)
        onCopyScheduleLog(obj)

        % --- Project tab ---
        onScan(obj)
        refreshDatasetsTable(obj, opts)
        onNameTokensChanged(obj)
        setNameTokenChecks(obj, tokenNames, shown)
        syncTokenFilters(obj, tokenNames, values)
        idx = tickedDatasetIndices(obj)
        onDatasetCellSelection(obj, evt)
        onRefreshMetadata(obj)
        onSelectDatasets(obj, mode)
        onBrowseRoot(obj)
        onBrowseOutput(obj)
        onBrowseBehaviorDir(obj)
        onAssociateBehavior(obj)
        onClearBehavior(obj)
        idx = selectedDatasetIndices(obj)
        applyConfigToProject(obj, P)
        applyArtifactConfigToProject(obj)
        ok = saveManifests(obj, ds)

        % --- the active dataset (Dataset menu, every tab's Dataset box, Project-table row) ---
        selectDataset(obj, idx, opts)
        d = currentDataset(obj)
        populateDatasetPickers(obj)
        refreshDatasetMenu(obj)
        refreshDatasetPickers(obj)
        onViewManifest(obj, idx)
        dd = datasetPicker(obj, parent)
        highlightDatasetRow(obj, opts)

        % --- Tools panel (Project tab): the datasets in other programs ---
        idx = toolTargets(obj)
        syncToolsPanel(obj)
        onOpenTool(obj, tool)
        onOpenOutputFolder(obj, idx)

        % --- Trials tab ---
        onTrialsLoad(obj, mode)
        onTrialsPrefetch(obj)
        repairTrials(obj, cuts)
        refreshTrialsView(obj)
        refreshTrialsTable(obj)
        refreshTrialsPlot(obj)
        order = trialsColumnOrder(obj, shown)
        onTrialsTableMenu(obj, menu, evt)
        onTrialsPlotMenu(obj)
        clearTrialsView(obj)
        fillTrialsLines(obj, S)
        E = namedTrialsEvents(obj, S)
        onTrialsLinesEdited(obj, evt)
        setTrialsLineItems(obj, names, trialLine)
        syncTrialsButtons(obj)
        syncTrialsCuts(obj)
        onTrialsCutsChanged(obj)
        onTrialsApprove(obj, status)
        onTrialsWriteBehavior(obj)
        onTrialsToWorkspace(obj, source)
        onTrialsSettingsChanged(obj)

        % --- Artifacts tab ---
        onDetectArtifacts(obj)
        onArtifactControlsChanged(obj)
        refreshManualArtifactsTable(obj)
        refreshReferencePanel(obj)
        onSuggestReferenceExclude(obj)
        onReferenceExcludeEdited(obj)
        onClearManualArtifacts(obj)
        showArtifactView(obj)
        drawArtifactView(obj)
        tf = onArtViewInput(obj, kind, evt)
        syncArtProbeControls(obj)
        refreshArtChannelTable(obj)
        routeFigureInput(obj)

        % --- Visualize tab ---
        onPlotVisualization(obj)
        applyVizSettings(obj, what)
        onVizControlsChanged(obj, what)
        onVizViewChanged(obj)
        tf = onVizInput(obj, kind, evt)
        onVizButtonDown(obj)
        onVizButtonUp(obj)
        refreshVizShading(obj, draw)
        [iv, why] = vizDetectedIntervals(obj)
        tf = vizActive(obj)
        d = currentVizDataset(obj)
        onVizArtToggle(obj, val)
        onVizArtClear(obj)
        onVizArtMotion(obj)
        finishVizArtDrag(obj)
        updateVizArtStatus(obj)
        syncVizDataset(obj)

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
        setDropIfMember(obj, dd, value, name)
        onOptimizeKS4ForProbe(obj, ifMissing)
        onResetKS4Params(obj)
        p = defaultPythonExe(obj)
        onUseSortingFolder(obj)
        onUseAutoSorting(obj)
        refreshSortingLabel(obj)
        onLaunchPhy(obj, idx)
        launchPhy(obj, resultsDir, label)
        startKSMonitor(obj)
        stopKSMonitor(obj)
        pollKSRuns(obj)
        queueKSRun(obj, d, res)
        onStopKSQueue(obj)
        onStopKSRuns(obj)
        stopKSRuns(obj, names)
        markKSResult(obj, name, output, status, message, addSeconds)
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
        onExportEpochsToWorkspace(obj)

        % --- Flow tab ---
        refreshFlowChart(obj)
        [html, summary] = flowChartHTML(obj, opts)
        [html, summary, model] = flowOverviewHTML(obj)
        onSaveFlowChart(obj)
        onOpenFlowChartInBrowser(obj)
        onFlowViewChanged(obj)
        onFlowLayoutChanged(obj)
        onFlowNavigate(obj, evt)
        ctrls = flowNavControls(obj, target)
        clearFlowHighlight(obj)

        % --- Review tab ---
        loadReviewResults(obj)
        renderReviewPlots(obj)
        renderReviewUnitShank(obj)
        onBrowseReviewFolder(obj)
        onOpenReviewFolder(obj)
        onReviewOpenPhy(obj)
        syncReviewDataset(obj)
        onReviewUnitSelected(obj, evt)
        onReviewNoteEdited(obj, evt)
        onReviewAllUnits(obj)

        % --- Synthetic tab ---
        ok = onSynthLoadSource(obj)
        ok = onSynthPreview(obj)
        renderSynthPreview(obj)
        onSynthGenerate(obj)
        T = generateSynthetic(obj, opts)
        onSynthDesign(obj, action)
        onSynthControlsChanged(obj, what)
        onSynthSourceChanged(obj)
        syncSynthControls(obj)
        D = gatherSynthDesign(obj)
        applySynthDesign(obj, D)
        [vars, names, widths] = synthColumns(obj, kind)
        [lines, params, trialLine] = synthSourceLists(obj)
        key = synthSourceKey(obj)
        [args, acq] = synthGeneratorArgs(obj)
        root = synthOutputRoot(obj)
        [folder, why] = synthOutputFolder(obj, acq)

        % --- Clean up tab ---
        onCleanupPreview(obj)
        onCleanupRun(obj)
        R = runCleanup(obj, T)
        onCleanupMethodChanged(obj)
        onCleanupBrowseDest(obj)
        onCleanupSettingsChanged(obj, why)
        onCleanupFileTicked(obj, evt)
        onCleanupSelect(obj, how)
        refreshCleanupScope(obj)
        refreshCleanupTable(obj, part)

        % --- app-wide ---
        loadPreferences(obj)
        savePreferences(obj)
        onClose(obj)
        stopTimers(obj)
        setStatus(obj, message, hint)
        hint = suggestNextStep(obj)
        onTabChanged(obj)
        url = helpURL(obj, page)
        onHelp(obj, page)
        onReportIssue(obj, kind)
        body = issueReport(obj, kind, opts)
        [url, truncated] = issueURL(obj, kind, title, body)
    end
end
