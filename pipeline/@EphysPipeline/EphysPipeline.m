classdef EphysPipeline < handle
    % EphysPipeline  Run an EphysPipelineConfig over a project's datasets.
    %   The one runner shared by the GUI, generated scripts and the command
    %   line. It owns no settings of its own: everything comes from the config,
    %   per-dataset state (probe, exclusions, manual artifacts, sorting and
    %   behavior associations) from each dataset's manifest.
    %
    %     cfg  = EphysPipelineConfig.load("my_pipeline.json");
    %     pipe = EphysPipeline(cfg);           % scans cfg.Project.Root
    %     disp(pipe.plan())                    % what would run, writes nothing
    %     R = pipe.run();                      % every enabled step, in order
    %     R = pipe.run(Steps=["signals" "export"]);
    %
    %   Steps, in execution order (EphysPipelineConfig.StepNames):
    %     probe      checkProbes        assign the default probe, check channel counts
    %     behavior   checkBehavior      associate Epsych2 sessions (matchEpsychSession),
    %                                   pair trials with the trial line (pairTrials)
    %     artifacts  runArtifacts       compute + cache artifact intervals
    %     sorting    runSorting         SpikeInterface + Kilosort4 (runSpikeInterface)
    %     signals    runSignals         derived LFP/MUA/SPIKE/AUX .mat (toMat)
    %     spikes     runSpikeDetection  detected and/or sorted spikes .mat (spikesToMat)
    %     export     runExport          analysis-toolbox / epoch files (Export.Formats)
    %   Each step method can be called directly (it then runs even if the
    %   step is disabled in the config).
    %
    %   Progress and cancellation
    %     ProgressFcn(evt) receives struct(step, dataset, index, count, done,
    %     total, message): STEP is one of the step names above (artifact
    %     detection that Sorting or Spikes needs reports as that step), INDEX
    %     of COUNT places the dataset in the step's selection and DONE of
    %     TOTAL is how far that dataset is, so the step is
    %     (INDEX - 1 + DONE/TOTAL) / COUNT done. run() also sends one event
    %     with dataset "" and INDEX 0 as each step starts.
    %     cancel() (e.g. from a GUI button) makes the next
    %     progress notification throw EphysPipeline:Cancelled; the current
    %     dataset is marked "cancelled" (its output, written atomically, is
    %     never left half-done) and the run stops. LogFcn(msg) receives one
    %     line per event (default: fprintf).
    %
    %   Results is a table (Step, Dataset, Status, Message, Output, Seconds),
    %   one row per step x dataset. LaunchedRuns lists background Kilosort4
    %   runs (same shape the app's KSRuns monitor consumes).
    %
    %   Background Kilosort4 runs
    %     At most Sorting.MaxConcurrent run at once: runSorting waits for a
    %     free slot before each launch and returns once the last dataset has
    %     started. LaunchFcn(run) receives each run (a LaunchedRuns element)
    %     as it starts, so a monitor can follow it while the rest wait.
    %     SortingWaiting is how many datasets the step has still to start.
    %     PriorRuns lists runs started elsewhere (e.g. by an earlier run the
    %     app still monitors), in LaunchedRuns' shape; while they are going
    %     they take slots too. Sorting.Devices shares GPUs out: each run
    %     gets the one the fewest running runs use (sortingSlot).
    %     With QueueFcn set, runSorting starts nothing itself: it writes
    %     each dataset's run files and passes the prepared run to
    %     QueueFcn(d, res), whose owner starts it later with
    %     d.launchSorting(res, Wait=false, Device=...). The step then
    %     returns without waiting for a slot. updateResult restates a row
    %     once such a run starts or ends.
    %
    %   See also EphysPipelineConfig, EphysPipelineScript, EphysProject, EphysDataset.

    properties
        Config      EphysPipelineConfig   % assigning a new config re-applies it to the datasets
        Project     EphysProject
        DatasetIdx  (1,:) double = double.empty(1,0)   % selected datasets (indices into Project.Datasets)
        ProgressFcn = []
        LogFcn      = @(msg) fprintf('%s\n', msg)
        LaunchFcn   = []
        QueueFcn    = []
        PriorRuns   struct = EphysPipeline.emptyRuns()
    end

    properties (SetAccess = protected)
        CancelRequested (1,1) logical = false
        Results table = EphysPipeline.emptyResults()
        LaunchedRuns struct = EphysPipeline.emptyRuns()
        SortingWaiting (1,1) double = 0
    end

    methods
        % --- methods defined in separate files ---
        T = plan(obj, opts)
        R = run(obj, opts)
        runSorting(obj, opts)
        runSignals(obj, opts)
        runSpikeDetection(obj, opts)
        runExport(obj, opts)

        function obj = EphysPipeline(cfg, opts)
            %EphysPipeline  Build the project for a config (or use a given one).
            arguments
                cfg (1,1) EphysPipelineConfig
                opts.Project = []
                opts.Refresh (1,1) logical = true
            end
            if isempty(opts.Project)
                if cfg.Project.Root == "" || ~isfolder(cfg.Project.Root)
                    error('EphysPipeline:NoRoot', 'Project root does not exist: "%s".', cfg.Project.Root);
                end
                obj.Project = EphysProject(cfg.Project.Root, OutputRoot=cfg.Project.OutputRoot, ...
                    PythonExe=cfg.Sorting.PythonExe, CondaEnv=cfg.Sorting.CondaEnv, ...
                    NamePattern=cfg.Project.NamePattern, Recursive=cfg.Project.Recursive, ...
                    ReaderOptions=cfg.Acquisition);
                obj.Project.refresh();
            else
                obj.Project = opts.Project;
                if opts.Refresh
                    obj.Project.refresh();
                end
            end
            obj.Config = cfg;   % set.Config pushes the settings onto the datasets
        end

        function set.Config(obj, cfg)
            %set.Config  Re-apply the config to the project and re-select datasets.
            obj.Config = cfg;
            if ~isempty(obj.Project) %#ok<MCSUP>
                EphysPipeline.applyConfigToDatasets(cfg, obj.Project); %#ok<MCSUP>
                obj.selectDatasets(); %#ok<MCSUP>
            end
        end

        function selectDatasets(obj)
            %selectDatasets  DatasetIdx from Project.Selection / Project.Datasets.
            P = obj.Project;
            n = P.NumDatasets;
            if obj.Config.Project.Selection == "list"
                keys = obj.Config.Project.Datasets;
                idx = P.findByKey(keys);
                missing = keys(idx == 0);
                if ~isempty(missing)
                    warning('EphysPipeline:UnknownDataset', ...
                        'Selected dataset key(s) not found under %s: %s', P.Root, strjoin(missing, ', '));
                end
                obj.DatasetIdx = idx(idx > 0);
            else
                obj.DatasetIdx = 1:n;
            end
        end

        function cancel(obj)
            %cancel  Stop at the next progress notification.
            obj.CancelRequested = true;
        end

        function reset(obj)
            %reset  Clear Results, LaunchedRuns and the cancel flag.
            obj.Results = EphysPipeline.emptyResults();
            obj.LaunchedRuns = EphysPipeline.emptyRuns();
            obj.SortingWaiting = 0;
            obj.CancelRequested = false;
        end

        function log(obj, fmt, varargin)
            %log  Send one line to LogFcn.
            if isempty(obj.LogFcn); return; end
            if nargin > 2
                msg = sprintf(fmt, varargin{:});
            else
                msg = char(string(fmt));
            end
            obj.LogFcn(string(msg));
        end

        function progress(obj, step, dataset, index, count, done, total, message)
            %progress  Notify ProgressFcn; throws EphysPipeline:Cancelled after cancel().
            if obj.CancelRequested
                error('EphysPipeline:Cancelled', 'Cancelled by user.');
            end
            if ~isempty(obj.ProgressFcn)
                evt = struct('step', string(step), 'dataset', string(dataset), 'index', index, ...
                    'count', count, 'done', done, 'total', total, 'message', string(message));
                obj.ProgressFcn(evt);
            end
        end

        function addResult(obj, step, dataset, status, message, output, seconds)
            %addResult  Append one row to Results.
            if nargin < 7; seconds = 0; end
            if nargin < 6; output = ""; end
            obj.Results(end+1, :) = {string(step), string(dataset), string(status), ...
                string(message), string(output), seconds};
        end

        function updateResult(obj, step, dataset, output, status, message, addSeconds)
            %updateResult  Restate the Results row of STEP x DATASET x OUTPUT.
            %   For work that ends after its step has returned, such as a
            %   background Kilosort4 run: the last matching row takes STATUS
            %   and MESSAGE, and ADDSECONDS (default 0) is added to its
            %   Seconds. Without a matching row nothing changes. See
            %   restateResult.
            if nargin < 7; addSeconds = 0; end
            obj.Results = EphysPipeline.restateResult(obj.Results, step, dataset, output, ...
                status, message, addSeconds);
        end

        function logParallel(obj, step)
            %logParallel  One log line per step when the Parallel section is on.
            P = obj.Config.Parallel;
            if ~P.Enabled; return; end
            if isnan(P.MaxWorkers); w = "auto"; else; w = string(P.MaxWorkers); end
            obj.log("[%s] parallel: chunks on the process pool (MaxWorkers=%s)", step, w);
        end

        function ds = selected(obj, idx)
            %selected  The selected datasets (or the given indices).
            if nargin < 2 || isempty(idx); idx = obj.DatasetIdx; end
            ds = obj.Project.Datasets(idx);
        end

        function f = outputPathFor(obj, step, d)
            %outputPathFor  Where a step writes for dataset D.
            %   Blank OutputDir settings mean the dataset's output folder
            %   (<OutputRoot>/<Name>, or the recording folder without an
            %   output root). "signals" gives one file per ticked signal type
            %   when Signals.SeparateFiles (see EphysDataset.signalFiles);
            %   "signals:base" is the name those are derived from.
            c = obj.Config;
            switch string(step)
                case "signals:base"
                    f = fullfile(dirOr(c.Signals.OutputDir, d), d.Name + string(c.Signals.Suffix) + ".mat");
                case "signals"
                    f = obj.outputPathFor("signals:base", d);
                    types = ["LFP" "MUA" "SPIKE" "AUX"];
                    types = types([c.Signals.LFP c.Signals.MUA c.Signals.SPIKE c.Signals.AUX]);
                    if c.Signals.SeparateFiles && ~isempty(types)
                        f = EphysDataset.signalFiles(f, types);
                    end
                case "spikes"
                    f = fullfile(dirOr(c.Spikes.OutputDir, d), d.Name + string(c.Spikes.Suffix) + ".mat");
                case "export:chronux"
                    f = fullfile(dirOr(c.Export.OutputDir, d), d.Name + "_chronux.mat");
                case "export:fieldtrip"
                    f = fullfile(dirOr(c.Export.OutputDir, d), d.Name + "_fieldtrip.mat");
                case "export:epochs"
                    f = fullfile(dirOr(c.Export.OutputDir, d), d.Name + "_epochs.mat");
                case "sorting"
                    f = string(d.kilosortDir());
                case "artifacts"
                    f = fullfile(d.outputFolder(), d.Name + "_artifacts.json");
                case "behavior"
                    f = fullfile(d.outputFolder(), d.Name + "_behavior.mat");
                otherwise
                    f = "";
            end
            f = string(f);
            function p = dirOr(setting, d)
                if strlength(strtrim(string(setting))) == 0
                    p = string(d.outputFolder());
                else
                    p = string(setting);
                end
            end
        end

        function o = outputsFor(obj, d, varargin)
            %outputsFor  DatasetOutputs for dataset D, including the step folders.
            %   OUT = pipe.outputsFor(d) is d.outputs() with the configured
            %   Signals / Spikes / Export OutputDir folders added to SearchDirs,
            %   so files written elsewhere by this config are found too. D is an
            %   EphysDataset or an index into Project.Datasets; further
            %   Name=Value options go to DatasetOutputs.
            %
            %   See also DatasetOutputs, EphysDataset.outputs.
            if isnumeric(d); d = obj.Project.Datasets(d); end
            c = obj.Config;
            dirs = [string(c.Signals.OutputDir), string(c.Spikes.OutputDir), string(c.Export.OutputDir)];
            dirs = strtrim(dirs);
            o = d.outputs('SearchDirs', dirs(strlength(dirs) > 0), varargin{:});
        end

        %% --- preflight steps ----------------------------------------------------
        function checkProbes(obj, opts)
            %checkProbes  Assign the default probe where missing; check channel counts.
            arguments
                obj (1,1) EphysPipeline
                opts.Datasets (1,:) double = []
            end
            c = obj.Config.Probe;
            ds = obj.selected(opts.Datasets);
            for k = 1:numel(ds)
                d = ds(k);
                obj.progress("probe", d.Name, k, numel(ds), 0, 1, "checking the probe");
                t0 = tic;
                note = "";
                if d.ProbeFile == "" && c.DefaultProbeFile ~= ""
                    d.ProbeFile = c.DefaultProbeFile;
                    note = "default probe assigned";
                    if c.WriteDefaultToManifest
                        d.writeManifest();
                        note = note + " (saved to manifest)";
                    end
                end
                if d.ProbeFile == ""
                    st = "no probe";
                elseif ~isfile(d.ProbeFile)
                    st = "probe file missing";
                    note = string(d.ProbeFile);
                else
                    pm = DatasetTracker.probeMeta(readJsonFile(d.ProbeFile, ErrorOnFail=false));
                    if isfinite(pm.nChan) && ~isnan(d.NumChannels) && pm.nChan > d.NumChannels
                        st = "probe-channel mismatch";
                        note = sprintf("probe has %d sites, recording %d channels", pm.nChan, d.NumChannels);
                    else
                        st = "ok";
                        if note == ""; note = string(d.ProbeFile); end
                    end
                end
                obj.log("[probe] %s: %s %s", d.Name, st, note);
                obj.addResult("probe", d.Name, st, note, d.ProbeFile, toc(t0));
            end
        end

        function checkBehavior(obj, opts)
            %checkBehavior  Associate Epsych2 session files (see matchEpsychSession).
            %   With Behavior.WriteFile, every dataset that has a session
            %   afterwards (matched now or kept) also gets
            %   <outputFolder>/<Name>_behavior.mat (behaviorToMat), rewritten
            %   each run: the one file that carries the behavior data.
            %   With Behavior.PairTrials the trials are first paired, in
            %   order, with the TrialLine intervals (EphysDataset.pairTrials;
            %   the digital events are read once and cached). A reviewed
            %   pairing recorded in the manifest (its cuts) is reused while it
            %   still matches. With Behavior.AutoApprove, a pairing whose
            %   trial and interval counts match without cuts is approved
            %   ("auto-approved"; EphysDataset.autoApproveTrialPairing).
            %   Anything else is recorded as "unreviewed" and reported as
            %   "needs review", or "count mismatch" when the numbers of
            %   trials and intervals differ (a "behavior:pairing" result row,
            %   and a WARNING log line; resolve it on the app's Trials tab).
            %   The pairing columns are written into the behavior file either
            %   way.
            arguments
                obj (1,1) EphysPipeline
                opts.Datasets (1,:) double = []
            end
            c = obj.Config.Behavior;
            ds = obj.selected(opts.Datasets);
            T = findEpsychSessions(c.SearchDirs);
            obj.log("[behavior] %d Epsych2 session file(s) under %s", height(T), strjoin(c.SearchDirs, "; "));
            for k = 1:numel(ds)
                d = ds(k);
                obj.progress("behavior", d.Name, k, numel(ds), 0, 1, "Epsych2 session");
                t0 = tic;
                if d.BehaviorFile ~= "" && isfile(d.BehaviorFile) && ~c.Overwrite
                    obj.addResult("behavior", d.Name, "associated", "kept existing association", d.BehaviorFile, toc(t0));
                else
                    m = matchEpsychSession(T, d, Match=c.Match, MaxStartOffsetMin=c.MaxStartOffsetMin);
                    if m.file ~= ""
                        d.BehaviorFile = m.file;
                        d.writeManifest();
                        st = "matched (" + m.method + ")";
                    elseif m.ambiguous
                        st = "ambiguous";
                    else
                        st = "unmatched";
                    end
                    obj.log("[behavior] %s: %s - %s", d.Name, st, m.reason);
                    obj.addResult("behavior", d.Name, st, m.reason, m.file, toc(t0));
                end
                P = [];
                if c.PairTrials && d.BehaviorFile ~= "" && isfile(d.BehaviorFile)
                    P = obj.pairTrialsFor(d, k, numel(ds));
                end
                if c.WriteFile && d.BehaviorFile ~= "" && isfile(d.BehaviorFile)
                    out = obj.outputPathFor("behavior", d);
                    try
                        r = d.behaviorToMat(File=out, Overwrite=true, Pairing=P);
                        obj.log("[behavior] %s: wrote %s (%d trials)", d.Name, r.file, r.nTrials);
                        obj.addResult("behavior:file", d.Name, "done", sprintf("%d trials", r.nTrials), r.file, r.seconds);
                    catch ME
                        obj.log("[behavior] %s: ERROR writing %s: %s", d.Name, out, ME.message);
                        obj.addResult("behavior:file", d.Name, "error", string(ME.message), out, 0);
                    end
                end
            end
        end

        function P = pairTrialsFor(obj, d, k, n)
            %pairTrialsFor  Pair D's trials, record the result, report it.
            %   A new result is recorded as unreviewed, or approved when
            %   Behavior.AutoApprove is on and its counts match. Returns the
            %   pairTrials struct, or [] when pairing failed.
            t0 = tic;
            P = [];
            try
                cb = @(i, nFiles, name) obj.progress("behavior", d.Name, k, n, i - 1, nFiles, ...
                    "reading digital events: " + string(name));
                P = d.pairTrials(ProgressFcn=cb, Warn=false);
                if obj.Config.Behavior.AutoApprove
                    P = d.autoApproveTrialPairing(P);
                end
                if ~P.recorded
                    d.setTrialPairing(P, "unreviewed");
                end
                if P.status ~= "approved"
                    st = "needs review";
                elseif P.autoApproved
                    st = "auto-approved";
                else
                    st = "approved";
                end
                msg = P.summary;
                if P.stale
                    msg = msg + " (the recorded pairing no longer matched and its cuts were dropped)";
                end
                if P.countMismatch
                    if st ~= "approved"; st = "count mismatch"; end
                    obj.log("[behavior] %s: WARNING %s", d.Name, strjoin(P.warnings, " "));
                    msg = msg + " - " + strjoin(P.warnings, " ");
                end
                obj.log("[behavior] %s: pairing %s - %s", d.Name, st, msg);
                obj.addResult("behavior:pairing", d.Name, st, msg, d.manifestFile(), toc(t0));
            catch ME
                if strcmp(ME.identifier, 'EphysPipeline:Cancelled'); rethrow(ME); end
                st = "error";
                if strcmp(ME.identifier, 'pairEpsychTrials:NoTrialLine'); st = "no trial line"; end
                obj.log("[behavior] %s: pairing %s: %s", d.Name, upper(st), ME.message);
                obj.addResult("behavior:pairing", d.Name, st, string(ME.message), "", toc(t0));
            end
        end

        %% --- artifacts ----------------------------------------------------------------
        function runArtifacts(obj, opts)
            %runArtifacts  Compute (and cache) the artifact intervals of each dataset.
            arguments
                obj (1,1) EphysPipeline
                opts.Datasets (1,:) double = []
            end
            ds = obj.selected(opts.Datasets);
            n = numel(ds);
            if n > 0; obj.logParallel("artifacts"); end
            for k = 1:n
                d = ds(k);
                if obj.CancelRequested
                    obj.addResult("artifacts", d.Name, "cancelled", "not run");
                    continue
                end
                t0 = tic;
                try
                    obj.progress("artifacts", d.Name, k, n, 0, 1, "artifact intervals");
                    [iv, src] = obj.artifactIntervalsFor(d, ...
                        @(done, total, msg) obj.progress("artifacts", d.Name, k, n, done, total, msg));
                    obj.addResult("artifacts", d.Name, "done", sprintf("%d interval(s), %s", size(iv, 1), src), ...
                        obj.outputPathFor("artifacts", d), toc(t0));
                catch ME
                    if strcmp(ME.identifier, 'EphysPipeline:Cancelled')
                        obj.addResult("artifacts", d.Name, "cancelled", "cancelled during detection", "", toc(t0));
                        continue
                    end
                    obj.log("[artifacts] %s: ERROR %s", d.Name, ME.message);
                    obj.addResult("artifacts", d.Name, "error", string(ME.message), "", toc(t0));
                end
            end
            if obj.CancelRequested
                error('EphysPipeline:Cancelled', 'Cancelled by user.');
            end
        end

        function [iv, source] = artifactIntervalsFor(obj, d, report)
            %artifactIntervalsFor  Artifact intervals for D, from the cache when valid.
            %   The cache (<outputFolder>/<Name>_artifacts.json) is keyed by a
            %   fingerprint of its schema, the artifact config, the manual
            %   periods and the recording files, so a change to any of them
            %   recomputes. Schema 2: half-open [tStart tEnd) intervals.
            %   SOURCE is "cache", "computed" or the manual-only note.
            %   REPORT(done, total, message) hears how far a detection is, so
            %   the step that needs the intervals can report it as its own
            %   progress; by default it goes out as the artifacts step on
            %   dataset 1 of 1.
            if nargin < 3
                report = @(done, total, msg) obj.progress("artifacts", d.Name, 1, 1, done, total, msg);
            end
            a = obj.Config.Artifacts;
            acfg = EphysPipelineConfig.artifactConfig(a);
            d.ArtifactConfig = acfg;
            manual = d.ManualArtifacts;
            if isempty(manual); manual = zeros(0, 2); end
            if ~acfg.Enabled
                iv = d.artifactIntervals(IncludeAuto=false);
                source = "manual periods only (auto-detection off)";
                return
            end
            schema = "ephys-artifacts/2";
            % Keyed by what decides the intervals: the fill fields say how the
            % periods are erased, not which they are, so a change there must
            % not throw away a detection.
            det = rmfield(acfg, intersect(fieldnames(acfg), {'Fill', 'NoiseBandHz', 'NoiseSeed'}));
            fp = string(jsonencode(struct('schema', schema, 'config', det, 'manual', manual, ...
                'files', cellstr(d.Files(:).'), 'nSamples', d.NumSamples)));
            cacheFile = obj.outputPathFor("artifacts", d);
            if a.CacheIntervals && isfile(cacheFile)
                c = readJsonFile(cacheFile, ErrorOnFail=false);
                if isstruct(c) && isfield(c, 'fingerprint') && string(c.fingerprint) == fp
                    iv = c.intervals;
                    if isempty(iv); iv = zeros(0, 2); end
                    if isvector(iv) && numel(iv) == 2; iv = double(iv(:)).'; end
                    iv = double(iv);
                    source = "cache";
                    obj.log("[artifacts] %s: %d interval(s) from cache%s", d.Name, size(iv, 1), coverageNote(iv, d));
                    return
                end
            end
            cb = @(i, nChunks, name) report(i - 1, nChunks, "detecting: " + string(name));
            popt = namedargs2cell(EphysPipelineConfig.parallelOptions(obj.Config.Parallel));
            iv = d.artifactIntervals('ProgressFcn', cb, popt{:});
            source = "computed";
            if a.CacheIntervals
                writeJsonFile(cacheFile, struct('schema', schema, 'dataset', d.Name, ...
                    'fingerprint', fp, 'intervals', iv, 'nIntervals', size(iv, 1), ...
                    'created', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'))));
            end
            obj.log("[artifacts] %s: %d interval(s) computed%s", d.Name, size(iv, 1), coverageNote(iv, d));
        end

        function [iv, source] = artifactIntervalsForStep(obj, d, applyAuto, report)
            %artifactIntervalsForStep  Manual + (optionally cached auto) intervals.
            %   REPORT and SOURCE as in artifactIntervalsFor; SOURCE is
            %   "manual" when the automatic detections do not apply.
            if applyAuto
                [iv, source] = obj.artifactIntervalsFor(d, report);
            else
                iv = d.artifactIntervals(IncludeAuto=false);
                source = "manual";
            end
        end
    end

    methods (Static)
        function applyConfigToDatasets(cfg, P)
            %applyConfigToDatasets  Push the config's shared settings onto every dataset.
            %   Sets PythonExe, CondaEnv, SIConfig, ArtifactConfig, TrialConfig,
            %   ReaderOptions (Acquisition), OutputDir (<OutputRoot>/<Name> when
            %   an output root is set), and the NamePattern and DatasetKey that
            %   label sorted units. A changed Acquisition section changes which
            %   folders are recordings (Open Ephys modes): rescan the project
            %   (EphysProject.discover) for that. Never touches
            %   the per-dataset manifest state: ProbeFile, ExcludeChannels,
            %   ManualArtifacts, SortingDir, BehaviorFile.
            arguments
                cfg (1,1) EphysPipelineConfig
                P (1,1) EphysProject
            end
            P.PythonExe  = cfg.Sorting.PythonExe;
            P.CondaEnv   = cfg.Sorting.CondaEnv;
            P.OutputRoot = cfg.Project.OutputRoot;
            P.NamePattern = cfg.Project.NamePattern;
            P.ReaderOptions = cfg.Acquisition;
            acfg = EphysPipelineConfig.artifactConfig(cfg.Artifacts);
            tcfg = EphysPipelineConfig.trialConfig(cfg);
            for k = 1:P.NumDatasets
                d = P.Datasets(k);
                d.PythonExe      = cfg.Sorting.PythonExe;
                d.CondaEnv       = cfg.Sorting.CondaEnv;
                d.SIConfig       = cfg.Sorting.SI;
                d.ArtifactConfig = acfg;
                d.TrialConfig    = tcfg;
                d.ReaderOptions  = cfg.Acquisition;
                d.NamePattern    = cfg.Project.NamePattern;
                d.DatasetKey     = EphysProject.relativeKey(P.Root, d.Folder);
                if cfg.Project.OutputRoot ~= ""
                    d.OutputDir = fullfile(cfg.Project.OutputRoot, d.Name);
                end
            end
        end

        function T = emptyResults()
            T = table('Size', [0 6], ...
                'VariableTypes', {'string', 'string', 'string', 'string', 'string', 'double'}, ...
                'VariableNames', {'Step', 'Dataset', 'Status', 'Message', 'Output', 'Seconds'});
        end

        function s = emptyRuns()
            %emptyRuns  0x0 struct array in the shape of LaunchedRuns.
            %   Name, statusFile, resultsDir, logFile (ks4_run.log), logPos
            %   (bytes of the log already shown), done, device (torch device,
            %   "" = Kilosort4's choice) and started (datetime).
            s = struct('Name', {}, 'statusFile', {}, 'resultsDir', {}, ...
                'logFile', {}, 'logPos', {}, 'done', {}, 'device', {}, 'started', {});
        end

        function run = sortRun(name, res)
            %sortRun  The LaunchedRuns element for a run launchSorting started.
            %   RUN = EphysPipeline.sortRun(NAME, RES): NAME is the dataset's,
            %   RES what EphysDataset.launchSorting returned.
            run = struct('Name', string(name), 'statusFile', string(res.statusFile), ...
                'resultsDir', string(res.resultsDir), 'logFile', string(res.stdoutLog), ...
                'logPos', 0, 'done', false, 'device', string(res.device), 'started', datetime('now'));
        end

        function T = restateResult(T, step, dataset, output, status, message, addSeconds)
            %restateResult  A Results table with one row restated.
            %   T = EphysPipeline.restateResult(T, STEP, DATASET, OUTPUT,
            %   STATUS, MESSAGE, ADDSECONDS): the last row of T with that
            %   Step, Dataset and Output takes STATUS and MESSAGE, and
            %   ADDSECONDS is added to its Seconds. T is unchanged without
            %   such a row. See updateResult.
            if isempty(T) || ~istable(T); return; end
            i = find(T.Step == string(step) & T.Dataset == string(dataset) & T.Output == string(output), 1, 'last');
            if isempty(i); return; end
            T.Status(i) = string(status);
            T.Message(i) = string(message);
            T.Seconds(i) = T.Seconds(i) + addSeconds;
        end
    end
end


function s = coverageNote(iv, d)
%coverageNote  ", covering X of Y s (Z%)" for artifact intervals IV.
%   Adds a warning past EphysDataset.MaxSilencedFraction, the share at which
%   sorting refuses to run.
[share, covered] = EphysDataset.silencedFraction(iv, d.NumSamples / d.Fs);
if isempty(iv) || isnan(share)
    s = "";
    return
end
s = string(sprintf(", covering %.4g of %.4g s (%.0f%%)", covered, d.NumSamples / d.Fs, 100 * share));
if share > EphysDataset.MaxSilencedFraction
    s = s + sprintf(" - WARNING: sorting refuses to silence more than %.0f%%; check the artifact settings", ...
        100 * EphysDataset.MaxSilencedFraction);
end
end
