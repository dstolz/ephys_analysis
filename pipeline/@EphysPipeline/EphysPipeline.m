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
    %     probe      checkProbes        check each probe (the default where none is
    %                                   assigned, see probeFor) against the channel count
    %     behavior   checkBehavior      associate Epsych2 sessions (matchEpsychSession;
    %                                   Behavior.Search), pair trials with the
    %                                   trial line (pairTrials), write the behavior file
    %     artifacts  runArtifacts       compute + cache artifact intervals
    %     sorting    runSorting         Kilosort4 on a .bin (runKilosort)
    %     signals    runSignals         derived LFP/MUA/SPIKE/AUX .mat (toMat)
    %     spikes     runSpikeDetection  detected and/or sorted spikes .mat (spikesToMat)
    %     export     runExport          analysis-toolbox / epoch files (Export.Formats)
    %   Each step method can be called directly (it then runs even if the
    %   step is disabled in the config); call checkRun() first for the checks
    %   run() makes before any step (config errors, blocking plan rows). Each
    %   takes DryRun=true: it then writes nothing and records "dry run" rows
    %   saying what it would do.
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
    %     app still monitors), in LaunchedRuns' shape, queued ones (queued
    %     true, see sortRun) included; while they are going they take slots
    %     too. A dataset with a run in PriorRuns or LaunchedRuns that is
    %     queued or still going is skipped (activeRun), so its .bin is never
    %     rewritten under Kilosort4. Sorting.Devices shares GPUs out: each
    %     run gets the one the fewest running runs use (sortingSlot).
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

    properties (Access = private)
        % Automatic artifact detections of this run (artifactIntervalsFor),
        % by dataset folder and fingerprint, so the steps that need them
        % detect once even with Artifacts.CacheIntervals off. reset() empties it.
        Detections = []
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
            %   The project's datasets are found and the config applied to
            %   them all; only the selected ones are then refreshed (headers
            %   and manifests, EphysProject.refresh). Refresh=false skips
            %   that (e.g. for a Project= the app has scanned already).
            arguments
                cfg (1,1) EphysPipelineConfig
                opts.Project = []
                opts.Refresh (1,1) logical = true
            end
            obj.Detections = containers.Map('KeyType', 'char', 'ValueType', 'any');
            if isempty(opts.Project)
                if cfg.Project.Root == "" || ~isfolder(cfg.Project.Root)
                    error('EphysPipeline:NoRoot', 'Project root does not exist: "%s".', cfg.Project.Root);
                end
                obj.Project = EphysProject(cfg.Project.Root, OutputRoot=cfg.Project.OutputRoot, ...
                    PythonExe=cfg.Sorting.PythonExe, CondaEnv=cfg.Sorting.CondaEnv, ...
                    NamePattern=cfg.Project.NamePattern, Recursive=cfg.Project.Recursive, ...
                    ReaderOptions=cfg.Acquisition);
            else
                obj.Project = opts.Project;
            end
            obj.Config = cfg;   % set.Config pushes the settings onto the datasets and selects them
            if opts.Refresh
                obj.Project.refresh(Datasets=obj.DatasetIdx);
            end
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
            %reset  Clear Results, LaunchedRuns, this run's artifact detections and the cancel flag.
            obj.Results = EphysPipeline.emptyResults();
            obj.LaunchedRuns = EphysPipeline.emptyRuns();
            obj.SortingWaiting = 0;
            obj.CancelRequested = false;
            obj.Detections = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end

        function T = checkRun(obj, opts)
            %checkRun  The checks run() makes before any step: validate, then plan.
            %   T = pipe.checkRun(Steps=...) errors with
            %   EphysPipeline:ConfigInvalid on a config error (validate; its
            %   warnings are logged) and with EphysPipeline:PlanInvalid on a
            %   blocking plan row (Status "duplicate ..." or "error: ..."), else
            %   returns the plan of the steps (default: the enabled ones). A
            %   script that calls the step methods one by one calls it first.
            %
            %   See also EphysPipeline.run, EphysPipeline.plan, EphysPipelineConfig.validate.
            arguments
                obj (1,1) EphysPipeline
                opts.Steps (1,:) string = string.empty(1,0)
            end
            issues = obj.Config.validate();
            if any(issues.Severity == "error")
                e = issues(issues.Severity == "error", :);
                error('EphysPipeline:ConfigInvalid', 'The config has %d error(s):\n%s', height(e), ...
                    strjoin(e.Step + "." + e.Field + ": " + e.Message, newline));
            end
            for w = issues.Message(issues.Severity == "warning").'
                obj.log("[validate] warning: %s", w);
            end
            T = obj.plan(Steps=opts.Steps);
            blocking = T(startsWith(T.Status, "duplicate") | startsWith(T.Status, "error"), :);
            if ~isempty(blocking)
                error('EphysPipeline:PlanInvalid', 'The plan has %d blocking row(s):\n%s', height(blocking), ...
                    strjoin(blocking.Step + " " + blocking.Dataset + ": " + blocking.Status + " " + blocking.Note, newline));
            end
        end

        function f = probeFor(obj, d)
            %probeFor  The probe file dataset D is sorted with.
            %   Its own ProbeFile (from its manifest), else the config's
            %   Probe.DefaultProbeFile, read at each call, so an edited
            %   default applies at once; "" for none. The default is not
            %   assigned to D unless Probe.WriteDefaultToManifest (checkProbes).
            f = d.ProbeFile;
            if f == ""
                f = obj.Config.Probe.DefaultProbeFile;
            end
        end

        function run = activeRun(obj, d)
            %activeRun  A Kilosort4 run for dataset D that is queued or still going, [] when none.
            %   Looks through PriorRuns and LaunchedRuns for a run writing into
            %   D's kilosort4 folder (resultsDir, whose .bin sits beside it)
            %   that is not done: queued, or running by its status file
            %   (EphysDataset.sortRunState). runSorting skips such a dataset.
            run = [];
            runs = [obj.PriorRuns(:); obj.LaunchedRuns(:)];
            if isempty(runs); return; end
            mine = runs(EphysDataset.pathKey([runs.resultsDir]) == EphysDataset.pathKey(d.kilosortDir()));
            for r = reshape(mine, 1, [])
                if ~r.done && (r.queued || EphysDataset.sortRunState(r.statusFile) == "running")
                    run = r;
                    return
                end
            end
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

        function f = exportExtractFiles(obj, d)
            %exportExtractFiles  The extract files the Export step reads for dataset D.
            %   The Signals step's files (outputPathFor "signals"), or - with
            %   Signals.SeparateFiles and a non-empty Export.Signals - only the
            %   <Name><Suffix>_<TYPE>.mat files of those signal types. An _AUX
            %   file that was never written is left out (recordedSignalFiles).
            c = obj.Config;
            if c.Signals.SeparateFiles && ~isempty(c.Export.Signals)
                f = EphysDataset.signalFiles(obj.outputPathFor("signals:base", d), upper(c.Export.Signals));
            else
                f = obj.outputPathFor("signals", d);
            end
            f = EphysDataset.recordedSignalFiles(f);
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
            %checkProbes  Check each dataset's probe against its channel count.
            %   The probe is the dataset's own, else Probe.DefaultProbeFile
            %   (probeFor). With Probe.WriteDefaultToManifest the default is
            %   assigned (ProbeFile) and saved to the manifest; otherwise it
            %   is only used, never assigned, so no later manifest write
            %   records it and an edited default applies at once. Status:
            %   "ok", "no probe", "probe file missing" or "probe-channel
            %   mismatch". DryRun: the default is not saved (the note says it
            %   would be).
            arguments
                obj (1,1) EphysPipeline
                opts.Datasets (1,:) double = []
                opts.DryRun (1,1) logical = false
            end
            c = obj.Config.Probe;
            ds = obj.selected(opts.Datasets);
            for k = 1:numel(ds)
                d = ds(k);
                obj.progress("probe", d.Name, k, numel(ds), 0, 1, "checking the probe");
                t0 = tic;
                probe = obj.probeFor(d);
                note = "";
                if d.ProbeFile == "" && probe ~= ""
                    note = "default probe";
                    if c.WriteDefaultToManifest && opts.DryRun
                        note = "default probe, would be saved to the manifest (dry run)";
                    elseif c.WriteDefaultToManifest
                        d.ProbeFile = probe;
                        d.writeManifest();
                        note = "default probe, saved to the manifest";
                    end
                end
                [st, detail] = EphysPipeline.probeStatus(probe, d);
                parts = [note detail];
                note = strjoin(parts(parts ~= ""), "; ");
                obj.log("[probe] %s: %s %s", d.Name, st, note);
                obj.addResult("probe", d.Name, st, note, probe, toc(t0));
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
            %
            %   An associated session is kept unless Behavior.Overwrite, also
            %   while its file is not there ("behavior file missing": a disk or
            %   share that is not connected), so no other session replaces it.
            %   With Behavior.Search off, SearchDirs is not searched and
            %   nothing is matched: only the sessions already associated (by
            %   hand, or the one in the recording folder) are paired and
            %   written, and a dataset without one is reported "no session".
            %   DryRun: sessions are matched, but nothing is associated,
            %   paired or written; "dry run" rows say what would be.
            arguments
                obj (1,1) EphysPipeline
                opts.Datasets (1,:) double = []
                opts.DryRun (1,1) logical = false
            end
            c = obj.Config.Behavior;
            ds = obj.selected(opts.Datasets);
            if c.Search
                T = findEpsychSessions(c.SearchDirs);
                obj.log("[behavior] %d Epsych2 session file(s) under %s", height(T), strjoin(c.SearchDirs, "; "));
            else
                obj.log("[behavior] no search (Behavior.Search is off): the associated sessions only");
            end
            for k = 1:numel(ds)
                d = ds(k);
                obj.progress("behavior", d.Name, k, numel(ds), 0, 1, "Epsych2 session");
                t0 = tic;
                session = d.BehaviorFile;
                if session == "" && ~c.Search
                    obj.log("[behavior] %s: no associated session", d.Name);
                    obj.addResult("behavior", d.Name, "no session", ...
                        "no session associated (Behavior.Search is off: associate one by hand)", "", toc(t0));
                elseif session ~= "" && (~c.Overwrite || ~c.Search)
                    if isfile(session)
                        obj.addResult("behavior", d.Name, "associated", "kept existing association", session, toc(t0));
                    else
                        obj.log("[behavior] %s: the associated session file is not there: %s", d.Name, session);
                        obj.addResult("behavior", d.Name, "behavior file missing", ...
                            "the association is kept while its file is not there (Behavior.Overwrite re-matches)", session, toc(t0));
                    end
                else
                    m = matchEpsychSession(T, d, Match=c.Match, MaxStartOffsetMin=c.MaxStartOffsetMin);
                    msg = m.reason;
                    if m.file ~= "" && opts.DryRun
                        st = "dry run";
                        msg = "would associate it (" + m.method + "): " + m.reason;
                        session = m.file;
                    elseif m.file ~= ""
                        d.BehaviorFile = m.file;
                        d.writeManifest();
                        st = "matched (" + m.method + ")";
                        session = m.file;
                    elseif m.ambiguous
                        st = "ambiguous";
                    else
                        st = "unmatched";
                    end
                    obj.log("[behavior] %s: %s - %s", d.Name, st, msg);
                    obj.addResult("behavior", d.Name, st, msg, m.file, toc(t0));
                end
                if session == "" || ~isfile(session)
                    continue
                end
                out = obj.outputPathFor("behavior", d);
                if opts.DryRun
                    if c.PairTrials
                        obj.addResult("behavior:pairing", d.Name, "dry run", ...
                            "would pair the trials with the " + c.TrialLine + " intervals", d.manifestFile(), 0);
                    end
                    if c.WriteFile
                        obj.addResult("behavior:file", d.Name, "dry run", "would write the behavior file", out, 0);
                    end
                    continue
                end
                P = [];
                if c.PairTrials
                    P = obj.pairTrialsFor(d, k, numel(ds));
                end
                if c.WriteFile
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
            %   See artifactIntervalsFor. DryRun: nothing is read or written;
            %   a "dry run" row says what would be done.
            arguments
                obj (1,1) EphysPipeline
                opts.Datasets (1,:) double = []
                opts.DryRun (1,1) logical = false
            end
            ds = obj.selected(opts.Datasets);
            n = numel(ds);
            if n > 0 && ~opts.DryRun; obj.logParallel("artifacts"); end
            A = obj.Config.Artifacts;
            for k = 1:n
                d = ds(k);
                if obj.CancelRequested
                    obj.addResult("artifacts", d.Name, "cancelled", "not run");
                    continue
                end
                t0 = tic;
                if opts.DryRun
                    out = obj.outputPathFor("artifacts", d);
                    if ~A.Enabled
                        what = "would use the manual periods only (auto-detection off)";
                    elseif A.CacheIntervals && isfile(out)
                        what = "would reuse the cached detection when the settings match, else detect";
                    else
                        what = "would detect artifacts over the whole recording";
                    end
                    obj.log("[artifacts] %s: dry run - %s", d.Name, what);
                    obj.addResult("artifacts", d.Name, "dry run", what, out, toc(t0));
                    continue
                end
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
            %artifactIntervalsFor  Artifact intervals for D: the manual periods plus the automatic detection.
            %   The automatic detection alone is cached
            %   (<outputFolder>/<Name>_artifacts.json, when
            %   Artifacts.CacheIntervals) and kept for the rest of the run
            %   (until reset), keyed by a fingerprint of what decides it: the
            %   schema, the detector settings, the channels of the common
            %   reference, ExcludeChannels and the recording files; a change
            %   to any of them detects again. The manual periods are merged in
            %   on every call (EphysDataset.mergeIntervals), so marking one on
            %   the Visualize tab needs no new detection. Schema 3: half-open
            %   [tStart tEnd) intervals of the automatic detection. SOURCE is
            %   "computed", "cache", "reused" (detected earlier in this run) or
            %   the manual-only note. REPORT(done, total, message) hears how
            %   far a detection is, so the step that needs the intervals can
            %   report it as its own progress; by default it goes out as the
            %   artifacts step on dataset 1 of 1.
            if nargin < 3
                report = @(done, total, msg) obj.progress("artifacts", d.Name, 1, 1, done, total, msg);
            end
            a = obj.Config.Artifacts;
            acfg = EphysPipelineConfig.artifactConfig(a);
            d.ArtifactConfig = acfg;
            if ~acfg.Enabled
                iv = d.artifactIntervals(IncludeAuto=false);
                source = "manual periods only (auto-detection off)";
                return
            end
            schema = "ephys-artifacts/3";
            % Keyed by what decides the detection: the fill fields say how the
            % periods are erased, not which they are, so a change there must
            % not throw away a detection.
            det = rmfield(acfg, intersect(fieldnames(acfg), {'Fill', 'NoiseBandHz', 'NoiseSeed'}));
            % Detection runs on the common-referenced signal, so the channels
            % the reference is taken over decide the intervals too, and it
            % leaves out the excluded channels.
            refCh = [];
            if acfg.Reference ~= "none"
                if d.prepareReference()
                    obj.log("[artifacts] %s: common reference leaves out suggested channel(s) [%s]", ...
                        d.Name, EphysDataset.formatChannelList(d.ReferenceExclude));
                end
                refCh = d.referenceChannels();
            end
            fp = string(jsonencode(struct('schema', schema, 'config', det, 'reference', refCh, ...
                'exclude', d.ExcludeChannels, 'files', cellstr(d.Files(:).'), 'nSamples', d.NumSamples)));
            key = char(EphysDataset.pathKey(d.Folder) + "|" + fp);
            cacheFile = obj.outputPathFor("artifacts", d);
            source = "";
            if isKey(obj.Detections, key)
                auto = obj.Detections(key);
                source = "reused";
                how = "detected earlier in this run";
            elseif a.CacheIntervals && isfile(cacheFile)
                c = readJsonFile(cacheFile, ErrorOnFail=false);
                if isstruct(c) && all(isfield(c, {'fingerprint', 'intervals'})) && string(c.fingerprint) == fp
                    auto = double(reshape(c.intervals, [], 2));
                    source = "cache";
                    how = "from cache";
                end
            end
            if source == ""
                cb = @(i, nChunks, name) report(i - 1, nChunks, "detecting: " + string(name));
                popt = namedargs2cell(EphysPipelineConfig.parallelOptions(obj.Config.Parallel));
                auto = d.artifactIntervals('IncludeManual', false, 'ProgressFcn', cb, popt{:});
                source = "computed";
                how = "computed";
                if a.CacheIntervals
                    writeJsonFile(cacheFile, struct('schema', schema, 'dataset', d.Name, ...
                        'fingerprint', fp, 'intervals', auto, 'nIntervals', size(auto, 1), ...
                        'created', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'))));
                end
            end
            obj.Detections(key) = auto;
            iv = EphysDataset.mergeIntervals([d.ManualArtifacts; auto]);
            obj.log("[artifacts] %s: %d interval(s) %s, %d manual period(s)%s", d.Name, size(auto, 1), how, ...
                size(d.ManualArtifacts, 1), coverageNote(iv, d));
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
            %   Sets PythonExe, CondaEnv, ArtifactConfig, TrialConfig,
            %   ReaderOptions (Acquisition), OutputDir (<OutputRoot>/<Name>, or
            %   "" - outputs next to the recording - without an output root),
            %   and the NamePattern and DatasetKey that label sorted units. Two
            %   recordings with the same name share <OutputRoot>/<Name>: plan()
            %   stops a run on either. A changed Acquisition section changes which
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
                d.ArtifactConfig = acfg;
                d.TrialConfig    = tcfg;
                d.ReaderOptions  = cfg.Acquisition;
                d.NamePattern    = cfg.Project.NamePattern;
                d.DatasetKey     = EphysProject.relativeKey(P.Root, d.Folder);
                if cfg.Project.OutputRoot ~= ""
                    d.OutputDir = fullfile(cfg.Project.OutputRoot, d.Name);
                else
                    d.OutputDir = "";
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
            %   Name, statusFile, resultsDir (the run's kilosort4 folder: it
            %   identifies the dataset, see activeRun), logFile (ks4_run.log),
            %   logPos (bytes of the log already shown), done, device (torch
            %   device, "" = Kilosort4's choice), started (datetime; NaT while
            %   queued) and queued (true for a prepared run not started yet).
            s = struct('Name', {}, 'statusFile', {}, 'resultsDir', {}, ...
                'logFile', {}, 'logPos', {}, 'done', {}, 'device', {}, 'started', {}, 'queued', {});
        end

        function run = sortRun(name, res, opts)
            %sortRun  The LaunchedRuns element for a run launchSorting started.
            %   RUN = EphysPipeline.sortRun(NAME, RES): NAME is the dataset's,
            %   RES what EphysDataset.launchSorting returned.
            %   RUN = EphysPipeline.sortRun(NAME, RES, Queued=true) describes a
            %   run prepared (runKilosort with Launch=false, RES its result) and
            %   waiting in a queue, for PriorRuns: queued, started NaT.
            arguments
                name
                res (1,1) struct
                opts.Queued (1,1) logical = false
            end
            started = datetime('now');
            if opts.Queued; started = NaT; end
            run = struct('Name', string(name), 'statusFile', string(res.statusFile), ...
                'resultsDir', string(res.resultsDir), 'logFile', string(res.stdoutLog), ...
                'logPos', 0, 'done', false, 'device', string(res.device), 'started', started, ...
                'queued', opts.Queued);
        end

        function [st, note] = probeStatus(probe, d)
            %probeStatus  How the probe file PROBE fits dataset D, and a note.
            %   ST is "no probe", "probe file missing", "probe-channel
            %   mismatch" (more sites than recorded channels) or "ok"; NOTE is
            %   the file, or the two counts. Shared by checkProbes and plan.
            note = "";
            if probe == ""
                st = "no probe";
            elseif ~isfile(probe)
                st = "probe file missing";
                note = probe;
            else
                pm = DatasetTracker.probeMeta(readJsonFile(probe, ErrorOnFail=false));
                if isfinite(pm.nChan) && ~isnan(d.NumChannels) && pm.nChan > d.NumChannels
                    st = "probe-channel mismatch";
                    note = sprintf("probe has %d sites, recording %d channels", pm.nChan, d.NumChannels);
                else
                    st = "ok";
                    note = probe;
                end
            end
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
