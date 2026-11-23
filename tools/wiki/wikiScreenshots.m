function files = wikiScreenshots(outFolder, opts)
%wikiScreenshots  Take the wiki's EphysPipelineApp screenshots headlessly.
%   FILES = wikiScreenshots(OUTFOLDER) opens the app on a generated
%   synthetic project (createSyntheticProject, "standard" preset) at
%   1240x800, drives it through its own methods and saves each shot with
%   exportapp into OUTFOLDER under the name the wiki's images/ folder uses.
%   FILES = wikiScreenshots(OUTFOLDER, Config=C) takes the same shots of a
%   project of real recordings: the pipeline config C (see Config below).
%   "The shown dataset" is the first, or Dataset=.
%     app-copy-tab.png      Copy tab after Find sessions and Preview (dry
%                           run), over a source made from the project's
%                           recordings and ePsych files of the shown
%                           dataset's subject (in wiki_shots_work beside
%                           the project or config, removed at the end):
%                           its sessions paired, one ePsych file unpaired
%     app-trials-mismatch.png  Trials tab: the mismatch dataset (the
%                           synthetic late-start dataset, the second;
%                           Mismatch=) loaded, its count mismatch not yet cut
%     app-trials-resolved.png  the same after its cuts and Approve pairing
%     app-trials-clean.png  Trials tab: auto approval, prefetch, the shown
%                           dataset loaded
%                           (The Trials shots show the TrialType and
%                           RespCode columns and TrialType labels.)
%     app-project-empty.png Project tab before a project is scanned: the
%                           "No project is loaded yet." card (taken first,
%                           on the app as it opens)
%     app-project-tab.png   Project tab, the shown dataset active
%     app-probe-tab.png     Probe tab: the project's probe with channel 13
%                           of the shown dataset excluded (cleared again
%                           after the shot)
%     app-artifacts-tab.png Artifacts tab after Detect / Preview; the shown
%                           dataset has a manual period (0.3 s, 0.6 s after
%                           the end of its first automatic one)
%     app-sorting-tab.png   Sorting tab
%     app-signals-tab.png   Signals tab
%     app-spikes-tab.png    Spikes tab after its Preview
%     app-export-tab.png    Export tab with NWB ticked (off again after
%                           the shot)
%     app-analysis-tab.png  Analysis tab: the step on, an analysis config
%                           chosen (AnalysisConfig=; by default one like
%                           wikiToolScreenshots' synthetic one: a figure of
%                           each kind and a session figure), its figures
%                           table and its plan (switched off again after
%                           the shot)
%     app-diagram-tab.png   Diagram tab, Every parameter view
%     app-diagram-overview.png  Diagram tab, Data-flow overview view
%     app-synthetic-tab.png Synthetic tab after Preview (built-in task)
%     app-run-plan.png      Run tab after Validate + Plan (run diagram and
%                           resource monitor shown)
%     app-run-results.png   Run tab after a full serial run
%     app-visualize-traces.png   Visualize tab: the shown dataset's
%                           recording around its manual and first automatic
%                           artifact period, units, detected spikes and TTL
%                           rows over the traces
%     app-visualize-heatmap.png  the same window as a heatmap, high-passed
%     app-review-tab.png    Review tab, the shown dataset's first good unit
%                           (phy's label; none: its second unit). The
%                           synthetic ground-truth sort has no .bin, so its
%                           shank plot shows the template
%     app-review-notes.png  the units table scrolled to Notes, two typed
%     app-cleanup-tab.png   Clean up tab after Preview
%   Run it with MATLAB R2025a or later under -batch (see README.md here):
%     matlab -batch "addpath('C:\src\ephys_analysis\tools\wiki'); wikiScreenshots('C:\temp\shots', Source='C:\temp\src', Project='C:\temp\wiki_shots\synthetic_ephys')"
%     matlab -batch "addpath('C:\src\ephys_analysis\tools\wiki'); wikiScreenshots('C:\temp\shots', Source='C:\temp\src', Config='C:\temp\wiki_real\OFC_Pipeline_Config.json', Dataset='SUBJ-ID-1278_261008_095925', AnalysisConfig='C:\temp\wiki_real\OFC_Analysis_Config.json')"
%
%   Options
%     Source   source tree to run (default: this repository). Give a
%              git archive snapshot of the commit the wiki documents; only
%              its pipeline, analysis, vendor and toolboxes folders go on
%              the path, so .claude/worktrees copies never shadow the app.
%     Shots    names of the shots to take (default: all, as listed above)
%     Project  folder for the synthetic project (default: a new temp
%              folder). A folder that already holds one (its
%              synthetic_pipeline.json) is opened as it is, not rewritten:
%              the Visualize and Review shots then use its run outputs
%              when it has them, so a subset of shots needs no new run.
%              The run shots always run the pipeline. wikiToolScreenshots
%              takes such a folder too
%     Config   a pipeline config (.json) of a project of real recordings,
%              opened and scanned instead of a synthetic project (Project
%              is then not used). The shots change that project: the
%              mismatch dataset's pairing is cleared and approved with new
%              cuts, the shown dataset gets a manual artifact period and two
%              Review notes, and the run shots run the config over it,
%              rewriting its outputs. So give a config of a COPY of the
%              data, one whose paths (root, output root, sort folder, the
%              manifests' and sorts' own paths) all point into the copy,
%              with Transfer and AnalysisCopy off
%     Dataset  name of the shown dataset (default: the first)
%     Mismatch name of the dataset whose trial count mismatch the Trials
%              shots resolve (default: the synthetic project's second; with
%              Config, the first dataset whose pairing has a count mismatch,
%              and none: those two shots are skipped). With Config the cuts
%              are the fewest that pair the counts and pass the timing
%              cross-check (pairEpsychTrials)
%     AnalysisConfig  the analysis config (.json) the Analysis tab shot
%              chooses (default: a synthetic quick look written to the
%              work folder)
%     Wait     seconds to let the page render before each shot (default 2;
%              the results shot waits 10x as long). On a busy machine
%              exportapp can capture a stale frame, so run it when no other
%              MATLAB is working
%
%   The pipeline runs when app-run-results is wanted, or when a Visualize or
%   Review shot is and the project has no run outputs yet. The run leaves
%   the project processed; the Review notes are written to its sorted
%   output (cluster_notes.tsv).
%
%   The app keeps its preferences in a temporary file for the run
%   (AppPrefs.useTemporary), so every shot shows the defaults and your own
%   preferences are never read or changed, even when MATLAB has to be
%   killed (kill it if exportapp hangs: it has, now and then). SOURCE must
%   be a commit that has AppPrefs. With the lab database client at hand (a
%   CarasLabDB checkout beside SOURCE, useCarasLabDB) its preferences are
%   temporary too, and the status bar's lamp reads "Database: off".
%
%   See also wikiToolScreenshots, AppPrefs, EphysPipelineApp, exportapp.

arguments
    outFolder (1,1) string
    opts.Source (1,1) string = string(fileparts(fileparts(fileparts(mfilename('fullpath')))))
    opts.Shots (1,:) string = ["app-copy-tab.png" "app-project-empty.png" "app-project-tab.png" "app-trials-clean.png" ...
        "app-trials-mismatch.png" "app-trials-resolved.png" "app-probe-tab.png" "app-artifacts-tab.png" ...
        "app-sorting-tab.png" "app-signals-tab.png" "app-spikes-tab.png" "app-export-tab.png" ...
        "app-analysis-tab.png" "app-diagram-tab.png" "app-diagram-overview.png" "app-synthetic-tab.png" "app-run-plan.png" ...
        "app-run-results.png" "app-visualize-traces.png" "app-visualize-heatmap.png" ...
        "app-review-tab.png" "app-review-notes.png" "app-cleanup-tab.png"]
    opts.Project (1,1) string = ""
    opts.Config (1,1) string = ""
    opts.Dataset (1,1) string = ""
    opts.Mismatch (1,1) string = ""
    opts.AnalysisConfig (1,1) string = ""
    opts.Wait (1,1) double {mustBeNonnegative} = 2
end

src = opts.Source;
addpath(src);   % addpath_nogit and the root-level functions
for d = ["pipeline" "analysis" "vendor" "toolboxes"]
    if isfolder(fullfile(src, d)); addpath_nogit(fullfile(src, d)); end
end
fprintf('app: %s\n', which('EphysPipelineApp'));
if ~isfolder(outFolder); mkdir(outFolder); end
real = opts.Config ~= "";
if real
    assert(isfile(opts.Config), "wikiScreenshots:NoConfig", "No config file %s.", opts.Config);
    reuse = true;   % a project as it is, like a reused synthetic one
    base = string(fileparts(opts.Config));
    proj = "";
else
    proj = opts.Project;
    if proj == ""
        proj = string(fullfile(tempdir, "wiki_shots_" + string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')), "proj"));
    end
    reuse = isfile(fullfile(proj, 'synthetic_pipeline.json'));
    base = string(fileparts(proj));
end
work = fullfile(base, "wiki_shots_work");   % the Copy tab's source and the probe folder, removed at the end
if ~isfolder(work); mkdir(work); end
removeWork = onCleanup(@() rmdir(work, 's'));
files = strings(1, 0);

restorePrefs = AppPrefs.useTemporary(); %#ok<NASGU> the app starts from no preferences; yours are untouched
if LabBridge.available()   % the lab database client (a CarasLabDB checkout beside SOURCE): its settings too
    restoreClientPrefs = labclient.Prefs.useTemporary(); %#ok<NASGU> the lamp reads "Database: off"
end

app = EphysPipelineApp;
closeApp = onCleanup(@() closeIt(app));
app.Fig.Position = [40 40 1240 800];
drawnow;
if want("app-project-empty.png")   % before any project: the empty-state card
    app.selectTab(app.TabProject);
    shot("app-project-empty.png", 1);
end
wantTrials = want("app-trials-mismatch.png") || want("app-trials-resolved.png");
if real
    fprintf('config: %s\n', opts.Config);
    app.openConfigFile(opts.Config);
    app.onScan();
    proj = string(app.Config.Project.Root);
    app.selectTab(app.TabProject);
elseif reuse
    fprintf('project: %s (reused)\n', proj);
    app.openConfigFile(fullfile(proj, 'synthetic_pipeline.json'));
    app.onScan();
    app.selectTab(app.TabProject);
else
    S = app.createSyntheticProject(proj, Preset="standard", Overwrite=true);
end
names = arrayfun(@(d) string(d.Name), app.Project.Datasets);
ds = 1;   % the shown dataset
if opts.Dataset ~= ""; ds = datasetIndex(opts.Dataset); end
mismatch = 2;   % the late-start dataset: makeSyntheticProject's second scenario
cuts = [];
if opts.Mismatch ~= ""; mismatch = datasetIndex(opts.Mismatch); end
if real
    % Each count mismatch resolved by the fewest cuts that pair it: the
    % mismatch dataset's for the Trials shots, the others approved now (as
    % the synthetic project's are), so the Prefetch has none to warn about.
    D = app.Project.Datasets;
    allCuts = arrayfun(@(d) {cutsFor(d)}, D);
    if wantTrials
        if opts.Mismatch == ""; mismatch = find(~cellfun(@isempty, allCuts), 1); end
        if isempty(mismatch) || isempty(allCuts{mismatch})
            fprintf('no dataset has a trial count mismatch that cuts resolve: the mismatch shots are skipped\n');
            opts.Shots = setdiff(opts.Shots, ["app-trials-mismatch.png" "app-trials-resolved.png"], 'stable');
            wantTrials = false;
            mismatch = 0;
        else
            cuts = allCuts{mismatch};
            fprintf('mismatch: %s, cuts trials [%d %d] intervals [%d %d]\n', names(mismatch), cuts.trials, cuts.intervals);
        end
    else
        mismatch = 0;
    end
    for k = find(~cellfun(@isempty, allCuts))
        if k == mismatch; continue; end
        P = D(k).pairTrials(Cuts=allCuts{k}, Warn=false);
        D(k).setTrialPairing(P, "approved");
        app.saveManifests(D(k));
        fprintf('approved %s with cuts trials [%d %d] intervals [%d %d]\n', names(k), allCuts{k}.trials, allCuts{k}.intervals);
    end
end
if ~reuse
    for k = 1:numel(S.datasets)   % approve each pairing with the cuts its scenario needs
        c = S.datasets(k).expectedCuts;
        if (any(c.trials) || any(c.intervals)) && ~(k == mismatch && wantTrials)
            d = app.Project.dataset(S.datasets(k).name);
            P = d.pairTrials(Cuts=c, Warn=false);
            d.setTrialPairing(P, "approved");
        end
    end
    % A manual artifact period on the shown dataset, just after its first
    % automatic one, for the Artifacts and Visualize shots.
    d = app.Project.Datasets(ds);
    a = S.datasets(ds).artifacts(1, 2) + 0.6;
    d.addArtifact(a, a + 0.3);
    app.saveManifests(d);
end
app.refreshDatasetsTable();
app.selectDataset(ds);
app.TrialsAutoApproveCheckBox.Value = true;
app.onTrialsSettingsChanged();
app.TrialsParamColumns = ["TrialType" "RespCode"];   % what the Trials table's and plot's context menus set
app.TrialsLabelParams = "TrialType";

if want("app-copy-tab.png")
    % A source like the lab's, from the project: the shown dataset's
    % subject's ePsych files in nas/epsych_files/<subject>/, its recording
    % folders (the .rhd files only) in nas/intan_files/<subject>/, plus one
    % ePsych file two hours later that no recording pairs with.
    subj = names(ds).extractBefore("_");
    ep = fullfile(work, "nas", "epsych_files", subj);
    mkdir(ep);
    E = dir(fullfile(proj, subj, subj + "_*", subj + "_*.mat"));
    E = E(~cellfun(@isempty, regexp({E.name}, '^.+_\d{6}T\d{6}\.mat$', 'once')));
    for k = 1:numel(E)
        copyfile(fullfile(E(k).folder, E(k).name), ep);
        [~, rec] = fileparts(E(k).folder);
        mkdir(fullfile(work, "nas", "intan_files", subj, rec));
        copyfile(fullfile(E(k).folder, "*.rhd"), fullfile(work, "nas", "intan_files", subj, rec));
    end
    [~, last] = fileparts(E(end).name);
    t = datetime(extractAfter(last, subj + "_"), 'InputFormat', 'yyMMdd''T''HHmmss') + hours(2);
    copyfile(fullfile(E(end).folder, E(end).name), fullfile(ep, subj + "_" + string(t, 'yyMMdd''T''HHmmss') + ".mat"));
    days = arrayfun(@(k) datetime(extractBetween(string(E(k).name), subj + "_", "T"), 'InputFormat', 'yyMMdd'), 1:numel(E));
    app.selectTab(app.TabCopy);
    app.CopySubjectField.Value = char(subj);
    app.CopyFromDatePicker.Value = min(days);
    app.CopyToDatePicker.Value = max(days);
    app.CopyEpsychRootField.Value = char(fullfile(work, "nas", "epsych_files"));
    app.CopyRecordingRootsField.Value = char(fullfile(work, "nas", "intan_files"));
    app.CopyDestRootField.Value = char(fullfile(work, "local"));
    if ~real
        app.CopyMinDurationField.Value = 0.5;   % the synthetic recordings are about a minute long
    end
    app.onCopyFind();
    app.onCopyRun(true);
    scroll(app.CopyLogArea, 'top');   % scrolled to the bottom, the log exported blank
    shot("app-copy-tab.png", 1);
end

if wantTrials
    % As the Quick Start does it: load the mismatch dataset, see the
    % mismatch, cut and approve. A reused project (or a real one) may have
    % a record already, so it is cleared first. This comes before the
    % Prefetch below, which has no pairing left to review then.
    app.selectTab(app.TabTrials);
    app.selectDataset(mismatch);
    d = app.currentDataset();
    if real
        c = cuts;
        d.setTrialPairing([]);
        app.saveManifests(d);
    elseif reuse
        rec = d.TrialPairing;
        c = struct('trials', rec.cut_trials, 'intervals', rec.cut_intervals);
        d.setTrialPairing([]);
        app.saveManifests(d);
    else
        c = S.datasets(mismatch).expectedCuts;
    end
    app.onTrialsLoad("recorded");
    shot("app-trials-mismatch.png", 1);
    s = app.TrialsCutSpinners;
    s(1, 1).Value = c.trials(1);    s(1, 2).Value = c.trials(2);
    s(2, 1).Value = c.intervals(1); s(2, 2).Value = c.intervals(2);
    app.onTrialsCutsChanged();
    app.onTrialsApprove("approved");
    shot("app-trials-resolved.png", 1);
    app.selectDataset(ds);
end

if want("app-trials-clean.png")
    app.selectTab(app.TabTrials);
    app.onSelectDatasets("all");
    app.onTrialsPrefetch();
    app.onSelectDatasets("none");
    app.selectDataset(ds);
    app.onTrialsLoad("recorded");
    shot("app-trials-clean.png", 1);
end

app.selectDataset(ds);
app.selectTab(app.TabProject);
shot("app-project-tab.png", 1);

if want("app-probe-tab.png")
    % A probe folder with the project's probe and the repository's library.
    pf = fullfile(work, "probes");
    mkdir(pf);
    copyfile(fullfile(src, "pipeline", "probes", "*.json"), pf);
    probe = app.Config.Probe.DefaultProbeFile;
    copyfile(probe, pf);
    app.selectTab(app.TabProbe);
    app.ProbeFolderField.Value = char(pf);
    app.refreshProbeList();
    [~, n, e] = fileparts(probe);
    app.selectProbeRow(find(endsWith(app.ProbePaths, n + e), 1));
    app.ExcludeChannelsField.Value = '13';
    app.onApplyExclude("selected");
    app.onProbeSelected();
    shot("app-probe-tab.png", 1);
    app.ExcludeChannelsField.Value = '';
    app.onApplyExclude("selected");
end

if want("app-artifacts-tab.png") || (real && (want("app-visualize-traces.png") || want("app-visualize-heatmap.png")))
    app.selectTab(app.TabArtifacts);
    app.onDetectArtifacts();
    d = app.currentDataset();
    iv = app.ArtView.intervals;
    if real && ~isempty(iv)
        % The first automatic period a minute in (not the recording's
        % onset), shown, and the manual period the synthetic project gets
        % when it is made: 0.3 s, 0.6 s after it.
        k = find(iv(:, 1) > 60, 1);
        if isempty(k); k = 1; end
        if isempty(d.ManualArtifacts)
            a = iv(k, 2) + 0.6;
            d.addArtifact(a, a + 0.3);
            app.saveManifests(d);
            app.refreshManualArtifactsTable();
        end
        app.ArtViewSpinner.Value = k;
        app.showArtifactView("artifact");
    end
    shot("app-artifacts-tab.png", 1.5);
end

app.selectTab(app.TabSorting);
shot("app-sorting-tab.png", 1);
app.selectTab(app.TabSignals);
shot("app-signals-tab.png", 1);
if want("app-spikes-tab.png")
    app.selectTab(app.TabSpikes);
    app.onSpikesPreview();
    shot("app-spikes-tab.png", 1);
end
app.selectTab(app.TabExport);
% NWB ticked for the shot only: the run needs no Python with pynwb
app.ExpNWBCheckBox.Value = true;
app.ExpNWBCheckBox.ValueChangedFcn(app.ExpNWBCheckBox, []);
shot("app-export-tab.png", 1);
app.ExpNWBCheckBox.Value = false;
app.ExpNWBCheckBox.ValueChangedFcn(app.ExpNWBCheckBox, []);
if want("app-analysis-tab.png")
    % AnalysisConfig, or wikiToolScreenshots' "Synthetic quick look" saved
    % in the work folder. The step is switched off again, so the run does
    % not draw it.
    acfg = opts.AnalysisConfig;
    if acfg == ""
        a = EphysAnalysisConfig();
        a.Name = "Synthetic quick look";
        a.Description = "A figure of each kind, grouped by Depth";
        a.Defaults.Selection.groupBy = "Depth";
        a.Export.Formats = "png";
        a = a.addFigure("rasterPsth", Id="unit_card");
        a = a.addFigure("tuning", Id="tuning");
        a = a.addFigure("heatmap", Id="heatmap");
        a = a.addFigure("probemap", Id="probemap");
        a = a.addFigure("corrmap", Id="corrmap");
        a = a.addFigure("continuous", Id="lfp");
        a = a.addFigure("rasterPsth", Id="unit_days");   % drawn once across the sessions: "across sessions" in the table
        a.Figures(end).sessions.enabled = true;
        acfg = fullfile(work, "synthetic_quicklook.json");
        a.save(acfg);
    end
    app.AnaEnableCheckBox.Value = true;
    app.onAnalysisControlsChanged("enable");
    app.AnaConfigField.Value = char(acfg);
    app.onAnalysisControlsChanged("file");
    app.selectTab(app.TabAnalysis);
    app.refreshStepPlan("analysis");
    shot("app-analysis-tab.png", 1.5);
    app.AnaEnableCheckBox.Value = false;
    app.AnaConfigField.Value = '';
    app.onAnalysisControlsChanged("file");
end
if want("app-diagram-tab.png") || want("app-diagram-overview.png")
    app.selectTab(app.TabFlow);
    app.FlowViewDropDown.Value = "detail";   % the overview is the default
    app.onFlowViewChanged();
    shot("app-diagram-tab.png", 2.5);
    app.FlowViewDropDown.Value = "overview";
    app.onFlowViewChanged();
    shot("app-diagram-overview.png", 2.5);
end
if want("app-synthetic-tab.png")
    app.selectTab(app.TabSynthetic);
    app.onSynthPreview();
    shot("app-synthetic-tab.png", 1.5);
end

afterRun = ["app-visualize-traces.png" "app-visualize-heatmap.png" "app-review-tab.png" "app-review-notes.png"];
needRun = want("app-run-results.png") || (any(ismember(afterRun, opts.Shots)) && ~hasOutputs(app.Project));
if want("app-run-plan.png") || needRun
    app.RunParallelCheckBox.Value = false;   % a serial run
    app.onParallelControlsChanged();
    app.selectTab(app.TabRun);   % starts the resource monitor
    waitSample(30);
    app.onValidate();
    app.onPlan();
    waitSample(5);
    shot("app-run-plan.png", 2);
    if needRun
        t0 = tic;
        app.runPipeline(Confirm=false);   % no "Run ... ?" question: nobody answers it here
        fprintf('run: %s (%.0f s)\n', app.RunStepLabel.Text, toc(t0));
        waitSample(5);
        % Freeze the panel on its last sample: exportapp has hung while the
        % monitor's 2 s timer kept updating the page.
        app.stopResourceMonitor();
        scroll(app.RunLogArea, 'top');   % scrolled to the bottom, the log exported blank
        shot("app-run-results.png", 10);
    end
    app.stopResourceMonitor();
end

if want("app-visualize-traces.png") || want("app-visualize-heatmap.png")
    app.selectDataset(ds);
    d = app.currentDataset();
    t0 = 0;
    if ~isempty(d.ManualArtifacts); t0 = max(0, d.ManualArtifacts(1, 1) - 2); end
    app.VizStartField.Value = t0;
    app.VizDurField.Value = 3;
    app.VizTraceColorDropDown.Value = 'shank';
    app.selectTab(app.TabVisualize);   % loads the dataset (onPlotVisualization)
    if any(strcmp(app.VizSourceDropDown.ItemsData, 'recording'))
        app.VizSourceDropDown.Value = 'recording';
        app.onVizControlsChanged("source");
    end
    % The automatic scale fits the artifact; a fixed one shows the signal.
    app.VizSpacingField.Value = 400;
    app.onVizControlsChanged("spacing");
    shot("app-visualize-traces.png", 2);
    app.VizModeDropDown.Value = 'heatmap';
    app.onVizControlsChanged("mode");
    app.VizHighpassField.Value = '300';
    app.onVizControlsChanged("processing");
    app.VizSpacingField.Value = 100;     % the heatmap's color range: +-100 uV
    app.onVizControlsChanged("spacing");
    shot("app-visualize-heatmap.png", 2);
end

if want("app-review-tab.png") || want("app-review-notes.png")
    app.selectDataset(ds);
    app.selectTab(app.TabReview);      % loads its sorted output (syncReviewDataset)
    U = app.ReviewUnitsTable.Data;     % the first good unit (phy's label), else the second unit
    if istable(U); g = string(U{:, 2}); else; g = string(U(:, 2)); end
    r = find(g == "good", 1);
    if isempty(r); r = min(2, numel(g)); end
    app.ReviewUnitsTable.Selection = r;
    app.onReviewUnitSelected(struct('Indices', [r 1]));
    shot("app-review-tab.png", 2);
    nc = find(strcmp(app.ReviewUnitsTable.ColumnName, 'Notes'), 1);
    if isempty(nc); nc = 11; end
    notes = ["clear refractory period" "check the waveform in phy"];
    for r = 1:2
        app.onReviewNoteEdited(struct('Indices', [r nc], 'NewData', notes(r)));
    end
    scroll(app.ReviewUnitsTable, 'column', nc);
    shot("app-review-notes.png", 1);
end

if want("app-cleanup-tab.png")
    app.selectTab(app.TabCleanup);
    app.onCleanupPreview();
    shot("app-cleanup-tab.png", 1);
end
fprintf('project: %s\n', proj);


    function tf = want(name)
        tf = any(opts.Shots == name);
    end

    function k = datasetIndex(name)
        k = find(names == name, 1);
        assert(~isempty(k), "wikiScreenshots:NoDataset", "The project has no dataset %s.", name);
    end

    function shot(name, waitFactor)
        if ~want(name); return; end
        drawnow; pause(opts.Wait * waitFactor); drawnow;
        f = fullfile(outFolder, name);
        try
            exportapp(app.Fig, f);
        catch ME
            figs = findall(groot, 'Type', 'figure');
            ok = isvalid(app.Fig);
            vis = "-";
            if ok; vis = string(app.Fig.Visible); end
            names = "none";
            if ~isempty(figs); names = strjoin(string(get(figs, 'Name')), " | "); end
            fprintf(2, 'NOT written: %s (%s). The app''s window valid %d, visible %s; open windows: %s\n', name, ME.message, ...
                ok, vis, names);
            return
        end
        files(end+1) = f;
        fprintf('wrote %s\n', f);
    end

    function waitSample(tmax)
        %waitSample  Until the resource monitor has shown a sample (or TMAX s).
        t0 = tic;
        while toc(t0) < tmax && ~startsWith(string(app.RunMonitorNote.Text), "Sampled every")
            pause(0.5);
        end
    end
end


function cuts = cutsFor(d)
%cutsFor  The cuts that resolve dataset D's trial count mismatch ([] when it has none, or none of those tried does).
%   CUTS (fields trials and intervals, each [fromStart fromEnd]) are the
%   fewest, up to 3 at each end, that leave as many trials as intervals,
%   no partial interval, and pass pairEpsychTrials' timing cross-check.
cuts = [];
try
    P = d.pairTrials(Cuts="none", Warn=false);
catch
    return   % no behavior, no trial line
end
if ~P.countMismatch; return; end
best = Inf;
for a = 0:3, for b = 0:3, for c = 0:3, for e = 0:3 %#ok<ALIGN>
    n = a + b + c + e;
    if n >= best || P.nTrials - a - b ~= P.nIntervals - c - e; continue; end
    C = struct('trials', [a b], 'intervals', [c e]);
    try
        Q = d.pairTrials(Cuts=C, Warn=false);
    catch
        continue
    end
    if ~Q.countMismatch && Q.timingMismatch == 0 && ~any(Q.flag == "partial")
        best = n; cuts = C;
    end
end, end, end, end
end


function tf = hasOutputs(P)
%hasOutputs  Every dataset of the project has a spikes file (a run finished).
tf = P.NumDatasets > 0 && all(arrayfun(@(d) d.outputs().has("spikes"), P.Datasets));
end


function closeIt(app)
try
    if ~isempty(app) && isvalid(app.Fig)
        app.stopKSMonitor();
        app.stopResourceMonitor();
        delete(app.Fig);
    end
catch
end
end
