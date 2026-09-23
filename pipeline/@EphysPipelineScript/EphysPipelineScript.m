classdef EphysPipelineScript
    % EphysPipelineScript  Generate MATLAB scripts that reproduce a config's run.
    %   Two forms:
    %     compact(cfg, ConfigFile=)   a short script that loads the JSON config,
    %                                 makes run()'s checks (checkRun: config
    %                                 errors and blocking plan rows stop it)
    %                                 and calls one EphysPipeline method per
    %                                 step (disabled steps are written out
    %                                 commented). Keep the config next to it.
    %     standalone(cfg)             every parameter written out as MATLAB
    %                                 literals; calls EphysProject /
    %                                 EphysDataset (and the pure option
    %                                 builders of EphysPipelineConfig) directly,
    %                                 never the EphysPipeline runner, so it
    %                                 documents exactly what a run does and
    %                                 needs no config file. Each step does what
    %                                 the runner's does (the behavior step's
    %                                 trial pairing and approval included); the
    %                                 runner's cache of artifact detections and
    %                                 its plan checks are left out.
    %   Both return the script text; pass File= to write it (write()).
    %
    %   The literal(value) helper renders strings, string lists, numbers
    %   (including Inf / NaN / []), logicals and structs so that
    %   eval(literal(v)) reproduces v.
    %
    %   See also EphysPipelineConfig, EphysPipeline.

    methods (Static)
        function txt = compact(cfg, opts)
            %compact  Script that loads the config JSON and drives EphysPipeline.
            arguments
                cfg (1,1) EphysPipelineConfig
                opts.ConfigFile (1,1) string = ""
                opts.File (1,1) string = ""
            end
            configFile = opts.ConfigFile;
            if configFile == ""; configFile = cfg.File; end
            if configFile == ""
                error('EphysPipelineScript:NoConfigFile', ...
                    'The compact script needs the config saved to a file: pass ConfigFile= or save the config first.');
            end
            L = strings(0, 1);
            L(end+1, 1) = "%% Preprocessing pipeline: " + cfg.Name;
            L(end+1, 1) = "% Generated " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')) + " by EphysPipelineScript.compact.";
            L(end+1, 1) = "% Loads the saved config and runs one pipeline step per line. Edit the JSON";
            L(end+1, 1) = "% (or set fields on cfg below) and run again. Disabled steps are commented out.";
            if cfg.Description ~= ""
                L(end+1, 1) = "% " + cfg.Description;
            end
            L(end+1, 1) = "";
            L(end+1, 1) = "cfg = EphysPipelineConfig.load(" + EphysPipelineScript.literal(configFile) + ");";
            L(end+1, 1) = "";
            L(end+1, 1) = "% --- overrides (uncomment to change without editing the JSON) ---";
            L(end+1, 1) = "% cfg.Project.OutputRoot = " + EphysPipelineScript.literal(cfg.Project.OutputRoot) + ";";
            L(end+1, 1) = "% cfg.Project.Selection = ""all"";";
            L(end+1, 1) = "% cfg.Sorting.Execution = ""blocking"";";
            L(end+1, 1) = "% cfg.Sorting.MaxConcurrent = 2;   % background Kilosort4 runs at once";
            L(end+1, 1) = "";
            L(end+1, 1) = "pipe = EphysPipeline(cfg);      % scans the project root, applies the manifests";
            L(end+1, 1) = "planned = pipe.checkRun();      % run()'s checks: a config error or a blocking plan row stops here";
            L(end+1, 1) = "disp(planned);                  % what will run";
            L(end+1, 1) = "";
            calls = struct('probe', "pipe.checkProbes();", 'behavior', "pipe.checkBehavior();", ...
                'artifacts', "pipe.runArtifacts();", 'sorting', "pipe.runSorting();", ...
                'signals', "pipe.runSignals();", 'spikes', "pipe.runSpikeDetection();", ...
                'export', "pipe.runExport();");
            for step = EphysPipelineConfig.StepNames
                line = calls.(step);
                if cfg.stepEnabled(step)
                    L(end+1, 1) = line + "   % " + step; %#ok<AGROW>
                else
                    L(end+1, 1) = "% " + line + "   % " + step + " (disabled in the config)"; %#ok<AGROW>
                end
            end
            L(end+1, 1) = "";
            L(end+1, 1) = "disp(pipe.Results);";
            L(end+1, 1) = "% pipe.run();   % or: validate + plan + every enabled step in one call";
            txt = strjoin(L, newline) + newline;
            if opts.File ~= ""
                EphysPipelineScript.write(opts.File, txt);
            end
        end

        function txt = standalone(cfg, opts)
            %standalone  Script with every parameter written out; no config file needed.
            arguments
                cfg (1,1) EphysPipelineConfig
                opts.File (1,1) string = ""
            end
            lit = @EphysPipelineScript.literal;
            L = strings(0, 1);
            L(end+1, 1) = "%% Preprocessing pipeline: " + cfg.Name + " (standalone)";
            L(end+1, 1) = "% Generated " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')) + " by EphysPipelineScript.standalone.";
            L(end+1, 1) = "% Every setting is written out below; the script calls EphysProject / EphysDataset";
            L(end+1, 1) = "% directly and needs no config file. The config it came from, for reference:";
            for jl = splitlines(string(jsonencode(cfg.toStruct(), 'PrettyPrint', true))).'
                L(end+1, 1) = "%   " + jl; %#ok<AGROW>
            end
            L(end+1, 1) = "";

            % --- project + selection ---------------------------------------------
            L(end+1, 1) = "%% Project";
            L(end+1, 1) = "root       = " + lit(cfg.Project.Root) + ";";
            L(end+1, 1) = "outputRoot = " + lit(cfg.Project.OutputRoot) + ";";
            L = [L; EphysPipelineScript.structLiteral("readerOptions", cfg.Acquisition)];
            L(end+1, 1) = "P = EphysProject(root, OutputRoot=outputRoot, PythonExe=" + lit(cfg.Sorting.PythonExe) + ...
                ", CondaEnv=" + lit(cfg.Sorting.CondaEnv) + ", NamePattern=" + lit(cfg.Project.NamePattern) + ...
                ", Recursive=" + lit(cfg.Project.Recursive) + ", ReaderOptions=readerOptions);";
            if cfg.Project.Selection == "list"
                L(end+1, 1) = "keys = " + lit(cfg.Project.Datasets) + ";   % root-relative dataset keys";
                L(end+1, 1) = "idx = P.findByKey(keys);";
                L(end+1, 1) = "idx = idx(idx > 0);";
            else
                L(end+1, 1) = "idx = 1:P.NumDatasets;             % every dataset under the root";
            end
            L(end+1, 1) = "P.refresh(Datasets=idx);           % headers + per-dataset manifests (probe, exclusions, ...)";
            L(end+1, 1) = "I = P.unitIdentities(Among=idx);   % subject + recording start that label sorted units";
            L(end+1, 1) = "if any(I.Status ~= ""ok""); disp(I(I.Status ~= ""ok"", [""Key"" ""Status"" ""Message""])); end";
            L(end+1, 1) = "";
            L(end+1, 1) = "% Shared settings pushed onto every dataset";
            L = [L; EphysPipelineScript.structLiteral("artifactConfig", EphysPipelineConfig.artifactConfig(cfg.Artifacts))];
            L = [L; EphysPipelineScript.structLiteral("trialConfig", EphysPipelineConfig.trialConfig(cfg))];
            L = [L; EphysPipelineScript.structLiteral("parallelOpts", EphysPipelineConfig.parallelOptions(cfg.Parallel))];
            L(end+1, 1) = "parallelArgs = namedargs2cell(parallelOpts);   % UseParallel / MaxWorkers for the chunked steps";
            L(end+1, 1) = "for k = idx";
            L(end+1, 1) = "    d = P.Datasets(k);";
            L(end+1, 1) = "    d.PythonExe = " + lit(cfg.Sorting.PythonExe) + ";";
            L(end+1, 1) = "    d.CondaEnv = " + lit(cfg.Sorting.CondaEnv) + ";";
            L(end+1, 1) = "    d.ArtifactConfig = artifactConfig;";
            L(end+1, 1) = "    d.TrialConfig = trialConfig;        % trial line, line names and polarity, signal rates";
            L(end+1, 1) = "end";
            L(end+1, 1) = "";

            % --- probe ---------------------------------------------------------------
            L(end+1, 1) = "%% Probe (preflight)";
            L(end+1, 1) = "defaultProbe = " + lit(cfg.Probe.DefaultProbeFile) + ";   % for datasets without a probe of their own";
            L(end+1, 1) = "for k = idx";
            L(end+1, 1) = "    d = P.Datasets(k);";
            L(end+1, 1) = "    probe = d.ProbeFile;";
            L(end+1, 1) = "    if probe == """"; probe = defaultProbe; end";
            if cfg.Probe.WriteDefaultToManifest
                L(end+1, 1) = "    if d.ProbeFile == """" && probe ~= """"";
                L(end+1, 1) = "        d.ProbeFile = probe;   % the default, saved to the manifest (Probe.WriteDefaultToManifest)";
                L(end+1, 1) = "        d.writeManifest();";
                L(end+1, 1) = "    end";
            end
            L(end+1, 1) = "    fprintf('%s: probe %s\n', d.Name, probe);";
            L(end+1, 1) = "end";
            L(end+1, 1) = "";

            % --- behavior ------------------------------------------------------------
            L = [L; EphysPipelineScript.stepHeader("Behavior (Epsych2 sessions)", cfg.stepEnabled("behavior"))];
            B = cfg.Behavior;
            L(end+1, 1) = "sessions = findEpsychSessions(" + lit(B.SearchDirs) + ");";
            L(end+1, 1) = "for k = idx";
            L(end+1, 1) = "    d = P.Datasets(k);";
            match = "matchEpsychSession(sessions, d, Match=" + lit(B.Match) + ", MaxStartOffsetMin=" + lit(B.MaxStartOffsetMin) + ")";
            ind = "    ";
            note = "   % Behavior.Overwrite: matched again";
            if ~B.Overwrite
                L(end+1, 1) = "    if d.BehaviorFile ~= """"   % an association is kept, also while its file is not there";
                L(end+1, 1) = "        fprintf('%s: behavior %s (kept)\n', d.Name, d.BehaviorFile);";
                L(end+1, 1) = "    else";
                ind = "        ";
                note = "";
            end
            L(end+1, 1) = ind + "m = " + match + ";" + note;
            L(end+1, 1) = ind + "if m.file ~= """"";
            L(end+1, 1) = ind + "    d.BehaviorFile = m.file;";
            L(end+1, 1) = ind + "    d.writeManifest();";
            L(end+1, 1) = ind + "end";
            L(end+1, 1) = ind + "fprintf('%s: behavior %s (%s)\n', d.Name, m.file, m.reason);";
            if ~B.Overwrite
                L(end+1, 1) = "    end";
            end
            L(end+1, 1) = "    if d.BehaviorFile == """" || ~isfile(d.BehaviorFile); continue; end";
            L(end+1, 1) = "    pairing = [];";
            if B.PairTrials
                L(end+1, 1) = "    try   % the trials, in order, with the " + B.TrialLine + " intervals (a recorded pairing's cuts are reused)";
                L(end+1, 1) = "        pairing = d.pairTrials(Warn=false);";
                if B.AutoApprove
                    L(end+1, 1) = "        pairing = d.autoApproveTrialPairing(pairing);   % Behavior.AutoApprove: counts that match without cuts";
                end
                L(end+1, 1) = "        if ~pairing.recorded; d.setTrialPairing(pairing, ""unreviewed""); end";
                L(end+1, 1) = "        fprintf('%s: pairing %s - %s\n', d.Name, pairing.status, pairing.summary);";
                L(end+1, 1) = "        if pairing.countMismatch; fprintf(2, '%s: WARNING %s\n', d.Name, strjoin(pairing.warnings, "" "")); end";
                L(end+1, 1) = "    catch ME";
                L(end+1, 1) = "        fprintf(2, '%s: pairing FAILED: %s\n', d.Name, ME.message);";
                L(end+1, 1) = "        pairing = [];";
                L(end+1, 1) = "    end";
            end
            if B.WriteFile
                L(end+1, 1) = "    try   % <outputFolder>/<Name>_behavior.mat, the one copy of the behavior data";
                L(end+1, 1) = "        r = d.behaviorToMat(Overwrite=true, Pairing=pairing);";
                L(end+1, 1) = "        fprintf('%s: wrote %s\n', d.Name, r.file);";
                L(end+1, 1) = "    catch ME";
                L(end+1, 1) = "        fprintf(2, '%s: behavior file FAILED: %s\n', d.Name, ME.message);";
                L(end+1, 1) = "    end";
            end
            L(end+1, 1) = "end";
            L = [L; EphysPipelineScript.stepFooter(cfg.stepEnabled("behavior"))];

            % --- artifacts helper ----------------------------------------------------
            L(end+1, 1) = "%% Artifact intervals (manual periods always; automatic detection when enabled)";
            L(end+1, 1) = "artifactIntervals = @(d) d.artifactIntervals(parallelArgs{:});";
            L(end+1, 1) = "";

            % --- sorting -------------------------------------------------------------
            S = cfg.Sorting;
            L = [L; EphysPipelineScript.stepHeader("Sorting: Kilosort4 (via a .bin)", cfg.stepEnabled("sorting"))];
            [ks4, ~] = EphysPipelineConfig.ks4Settings(S);
            L = [L; EphysPipelineScript.structLiteral("ks4", ks4)];
            background = S.Execution == "background" && ~S.DryRun;
            devices = ~isempty(S.Devices) && ~S.DryRun;
            if background
                L(end+1, 1) = "maxConcurrent = " + lit(S.MaxConcurrent) + ";   % background runs at once; the next waits for a free slot";
                if devices
                    L(end+1, 1) = "devices = " + lit(S.Devices) + ";   % torch devices: each run gets the one the fewest running runs use";
                end
                L(end+1, 1) = "launched = [];   % each run started (launchSorting results)";
            end
            L(end+1, 1) = "for k = idx";
            L(end+1, 1) = "    d = P.Datasets(k);";
            L(end+1, 1) = "    probe = d.ProbeFile;";
            L(end+1, 1) = "    if probe == """"; probe = defaultProbe; end";
            L(end+1, 1) = "    if probe == """"; fprintf('%s: no probe, skipped\n', d.Name); continue; end";
            L(end+1, 1) = "    if ~isfile(probe); fprintf('%s: probe file missing (%s), skipped\n', d.Name, probe); continue; end";
            if S.SkipExisting
                L(end+1, 1) = "    if d.hasKilosortResults() || d.sortingMissing(); fprintf('%s: already sorted, skipped\n', d.Name); continue; end";
            end
            L(end+1, 1) = "    try";
            if S.DryRun
                L(end+1, 1) = "        iv = [];   % a dry run writes no .bin, so nothing is blanked";
            elseif cfg.Artifacts.ApplyToSorting
                L(end+1, 1) = "        iv = artifactIntervals(d);";
            else
                L(end+1, 1) = "        iv = d.artifactIntervals(IncludeAuto=false);";
            end
            if background
                L(end+1, 1) = "        res = d.runKilosort(ProbeFile=probe, ExtraSettings=ks4, ArtifactIntervals=iv, Launch=false);   % write the run files";
                if devices
                    L(end+1, 1) = "        device = waitForSortingSlot(launched, maxConcurrent, Devices=devices);";
                    L(end+1, 1) = "        res = d.launchSorting(res, Wait=false, Device=device);";
                else
                    L(end+1, 1) = "        waitForSortingSlot(launched, maxConcurrent);";
                    L(end+1, 1) = "        res = d.launchSorting(res, Wait=false);";
                end
                L(end+1, 1) = "        launched = [launched, res];";
            else
                devArg = "";
                if devices; devArg = ", Device=" + lit(S.Devices(1)); end
                L(end+1, 1) = "        res = d.runKilosort(ProbeFile=probe, ExtraSettings=ks4, ArtifactIntervals=iv, DryRun=" + ...
                    lit(logical(S.DryRun)) + ", Wait=" + lit(S.Execution == "blocking") + devArg + ");";
            end
            L(end+1, 1) = "        d.writeManifest();";
            L(end+1, 1) = "        fprintf('%s: sorting -> %s\n', d.Name, res.resultsDir);";
            L(end+1, 1) = "    catch ME";
            L(end+1, 1) = "        fprintf(2, '%s: sorting FAILED: %s\n', d.Name, ME.message);";
            L(end+1, 1) = "    end";
            L(end+1, 1) = "end";
            L = [L; EphysPipelineScript.stepFooter(cfg.stepEnabled("sorting"))];

            % --- signals -------------------------------------------------------------
            L = [L; EphysPipelineScript.stepHeader("Signals: derived LFP / MUA / SPIKE / AUX (toMat)", cfg.stepEnabled("signals"))];
            G = cfg.Signals;
            sigTypes = ["LFP" "MUA" "SPIKE" "AUX"];
            sigTypes = sigTypes([G.LFP G.MUA G.SPIKE G.AUX]);
            % Files the Signals step writes for dataset d (one per type when SeparateFiles).
            if G.SeparateFiles && ~isempty(sigTypes)
                sigFilesExpr = "EphysDataset.signalFiles(fullfile(" + EphysPipelineScript.outDirExpr(G.OutputDir) + ...
                    ", d.Name + " + lit(G.Suffix) + " + "".mat""), " + lit(sigTypes) + ")";
            else
                sigFilesExpr = "string(fullfile(" + EphysPipelineScript.outDirExpr(G.OutputDir) + ", d.Name + " + lit(G.Suffix) + " + "".mat""))";
            end
            L = [L; EphysPipelineScript.structLiteral("signals", G)];
            L(end+1, 1) = "for k = idx";
            L(end+1, 1) = "    d = P.Datasets(k);";
            L(end+1, 1) = "    outFile = fullfile(" + EphysPipelineScript.outDirExpr(G.OutputDir) + ", d.Name + " + lit(G.Suffix) + " + "".mat"");";
            L(end+1, 1) = "    outFiles = " + sigFilesExpr + ";";
            L(end+1, 1) = "    if any(isfile(outFiles)) && ~signals.Overwrite; fprintf('%s: %s exists, skipped\n', d.Name, strjoin(outFiles, ', ')); continue; end";
            L(end+1, 1) = "    try";
            L(end+1, 1) = "        sigOpts = EphysPipelineConfig.signalOptions(signals, ExcludeChannels=d.ExcludeChannels, NumChannels=d.NumChannels);";
            L(end+1, 1) = "        if isfield(sigOpts, 'badChannels')   % the geometry for them: its own probe, else the default";
            L(end+1, 1) = "            sigOpts.probeFile = d.ProbeFile;";
            L(end+1, 1) = "            if sigOpts.probeFile == """"; sigOpts.probeFile = defaultProbe; end";
            L(end+1, 1) = "        end";
            if G.BlankArtifacts
                % erased before any signal is derived, recorded in every file (info.artifacts)
                if cfg.Artifacts.ApplyToSignals
                    L(end+1, 1) = "        sigOpts.artifactIntervals = artifactIntervals(d);   % erased before deriving";
                else
                    L(end+1, 1) = "        sigOpts.artifactIntervals = d.artifactIntervals(IncludeAuto=false);   % erased before deriving";
                end
            end
            L(end+1, 1) = "        r = d.toMat(File=outFile, SeparateFiles=signals.SeparateFiles, SignalOptions=sigOpts, MatVersion=signals.MatVersion, Overwrite=signals.Overwrite);";
            L(end+1, 1) = "        fprintf('%s: wrote %s\n', d.Name, strjoin(r.file, ', '));";
            L(end+1, 1) = "    catch ME";
            L(end+1, 1) = "        fprintf(2, '%s: signals FAILED: %s\n', d.Name, ME.message);";
            L(end+1, 1) = "    end";
            L(end+1, 1) = "end";
            L = [L; EphysPipelineScript.stepFooter(cfg.stepEnabled("signals"))];

            % --- spikes --------------------------------------------------------------
            L = [L; EphysPipelineScript.stepHeader("Spikes: detected and/or sorted (spikesToMat)", cfg.stepEnabled("spikes"))];
            K = cfg.Spikes;
            L = [L; EphysPipelineScript.structLiteral("spikes", K)];
            L = [L; EphysPipelineScript.structLiteral("detectOptions", EphysPipelineConfig.detectOptions(K, cfg.Parallel))];
            L(end+1, 1) = "for k = idx";
            L(end+1, 1) = "    d = P.Datasets(k);";
            L(end+1, 1) = "    outFile = fullfile(" + EphysPipelineScript.outDirExpr(K.OutputDir) + ", d.Name + " + lit(K.Suffix) + " + "".mat"");";
            L(end+1, 1) = "    if isfile(outFile) && ~spikes.Overwrite; fprintf('%s: %s exists, skipped\n', d.Name, outFile); continue; end";
            if K.Source ~= "detect"
                L(end+1, 1) = "    if ~d.hasKilosortResults(); fprintf('%s: no sorted units, skipped\n', d.Name); continue; end";
            end
            L(end+1, 1) = "    try";
            L(end+1, 1) = "        channels = EphysPipelineConfig.spikeChannels(spikes, d);";
            if K.Source ~= "sorted" && K.RejectArtifacts
                if cfg.Artifacts.ApplyToSpikes
                    L(end+1, 1) = "        iv = artifactIntervals(d);";
                else
                    L(end+1, 1) = "        iv = d.artifactIntervals(IncludeAuto=false);";
                end
                L(end+1, 1) = "        extra = {'ArtifactIntervals', iv};";
            else
                L(end+1, 1) = "        extra = {};";
            end
            L(end+1, 1) = "        r = d.spikesToMat('File', outFile, 'Source', spikes.Source, 'DetectOptions', detectOptions, ...";
            L(end+1, 1) = "            'Channels', channels, 'RejectArtifacts', spikes.RejectArtifacts, 'Groups', spikes.Groups, ...";
            L(end+1, 1) = "            'IncludeNoise', spikes.IncludeNoise, 'Templates', spikes.Templates, ...";
            L(end+1, 1) = "            'MatVersion', spikes.MatVersion, 'Overwrite', spikes.Overwrite, extra{:});";
            L(end+1, 1) = "        fprintf('%s: wrote %s\n', d.Name, r.file);";
            L(end+1, 1) = "    catch ME";
            L(end+1, 1) = "        fprintf(2, '%s: spikes FAILED: %s\n', d.Name, ME.message);";
            L(end+1, 1) = "    end";
            L(end+1, 1) = "end";
            L = [L; EphysPipelineScript.stepFooter(cfg.stepEnabled("spikes"))];

            % --- export --------------------------------------------------------------
            L = [L; EphysPipelineScript.stepHeader("Export: analysis-toolbox and epoch files",cfg.stepEnabled("export"))];
            E = cfg.Export;
            % The extract files Export reads (EphysPipeline.exportExtractFiles):
            % with separate files, only those of Export.Signals when it lists any.
            if G.SeparateFiles && ~isempty(E.Signals)
                exFilesExpr = "EphysDataset.signalFiles(fullfile(" + EphysPipelineScript.outDirExpr(G.OutputDir) + ...
                    ", d.Name + " + lit(G.Suffix) + " + "".mat""), " + lit(upper(E.Signals)) + ")";
            else
                exFilesExpr = sigFilesExpr;
            end
            L(end+1, 1) = "formats = " + lit(E.Formats) + ";";
            L(end+1, 1) = "for k = idx";
            L(end+1, 1) = "    d = P.Datasets(k);";
            L(end+1, 1) = "    extract = EphysDataset.recordedSignalFiles(" + exFilesExpr + ");";
            L(end+1, 1) = "    if isempty(extract) || ~all(isfile(extract)); fprintf('%s: no extract file, skipped\n', d.Name); continue; end";
            if E.IncludeUnits
                L(end+1, 1) = "    if d.sortingMissing(); fprintf(2, '%s: the sorted-output folder %s is not there, skipped\n', d.Name, d.SortingDir); continue; end";
            end
            L(end+1, 1) = "    outFiles = fullfile(" + EphysPipelineScript.outDirExpr(E.OutputDir) + ", d.Name + ""_"" + formats + "".mat"");";
            if ~E.Overwrite
                L(end+1, 1) = "    if all(isfile(outFiles)); fprintf('%s: %s exist, skipped\n', d.Name, strjoin(outFiles, ', ')); continue; end";
            end
            L(end+1, 1) = "    try   % the inputs, read once for every format";
            L(end+1, 1) = "        S = load(extract(1));";
            L(end+1, 1) = "        for f = extract(2:end)   % each per-type file adds its signal";
            L(end+1, 1) = "            X = load(f);";
            L(end+1, 1) = "            for sig = [""LFP"" ""MUA"" ""SPIKE"" ""AUX""]";
            L(end+1, 1) = "                if isfield(X.Y, sig) && ~isempty(X.Y.(sig)) && isfield(X.info, sig)";
            L(end+1, 1) = "                    S.Y.(sig) = X.Y.(sig); S.info.(sig) = X.info.(sig);";
            L(end+1, 1) = "                end";
            L(end+1, 1) = "            end";
            L(end+1, 1) = "        end";
            if E.IncludeUnits
                L(end+1, 1) = "        units = false;";
                L(end+1, 1) = "        if d.hasKilosortResults(); units = d.readSortedUnits(Groups=" + lit(E.Groups) + "); end";
            end
            if E.IncludeDetected
                L(end+1, 1) = "        detected = false;";
                L(end+1, 1) = "        spikesFile = fullfile(" + EphysPipelineScript.outDirExpr(K.OutputDir) + ", d.Name + " + lit(K.Suffix) + " + "".mat"");";
                L(end+1, 1) = "        if isfile(spikesFile)";
                L(end+1, 1) = "            M = load(spikesFile, 'detected');";
                L(end+1, 1) = "            if isfield(M, 'detected') && ~isempty(M.detected); detected = M.detected; end";
                L(end+1, 1) = "        end";
            end
            L(end+1, 1) = "        % where the inputs came from, as each exporter records it (Sources)";
            L(end+1, 1) = "        sources = struct('extractFile', strjoin(extract, ""; ""), 'spikesFile', """", 'sortingDir', """");";
            if E.IncludeUnits
                L(end+1, 1) = "        if isstruct(units); sources.sortingDir = string(d.sortingResultsDir()); end";
            end
            if E.IncludeDetected
                L(end+1, 1) = "        if isstruct(detected); sources.spikesFile = spikesFile; end";
            end
            L(end+1, 1) = "    catch ME";
            L(end+1, 1) = "        fprintf(2, '%s: export inputs FAILED: %s\n', d.Name, ME.message);";
            L(end+1, 1) = "        continue";
            L(end+1, 1) = "    end";
            L(end+1, 1) = "    for j = 1:numel(formats)";
            L(end+1, 1) = "        fmt = formats(j);";
            if ~E.Overwrite
                L(end+1, 1) = "        if isfile(outFiles(j)); fprintf('%s: %s exists, skipped\n', d.Name, outFiles(j)); continue; end";
            end
            L(end+1, 1) = "        try";
            L(end+1, 1) = "            o = EphysPipelineConfig.exportOptions(" + EphysPipelineScript.inlineStruct(E) + ", fmt);";
            if E.IncludeUnits
                L(end+1, 1) = "            o.Units = units;";
            end
            if E.IncludeDetected
                L(end+1, 1) = "            o.Detected = detected;";
            end
            L(end+1, 1) = "            o.Sources = sources;";
            L(end+1, 1) = "            args = namedargs2cell(o);";
            L(end+1, 1) = "            switch fmt";
            L(end+1, 1) = "                case ""chronux""";
            L(end+1, 1) = "                    r = d.exportChronux('File', outFiles(j), 'Extract', S, args{:});";
            L(end+1, 1) = "                case ""fieldtrip""";
            L(end+1, 1) = "                    r = d.exportFieldTrip('File', outFiles(j), 'Extract', S, args{:});";
            L(end+1, 1) = "                case ""epochs""";
            L(end+1, 1) = "                    r = d.exportEpochs('File', outFiles(j), 'Extract', S, args{:});";
            L(end+1, 1) = "                otherwise";
            L(end+1, 1) = "                    error('Unknown export format ""%s"".', fmt);";
            L(end+1, 1) = "            end";
            L(end+1, 1) = "            fprintf('%s: wrote %s\n', d.Name, r.file);";
            L(end+1, 1) = "        catch ME";
            L(end+1, 1) = "            fprintf(2, '%s: export (%s) FAILED: %s\n', d.Name, fmt, ME.message);";
            L(end+1, 1) = "        end";
            L(end+1, 1) = "    end";
            L(end+1, 1) = "end";
            L = [L; EphysPipelineScript.stepFooter(cfg.stepEnabled("export"))];

            txt = strjoin(L, newline) + newline;
            if opts.File ~= ""
                EphysPipelineScript.write(opts.File, txt);
            end
        end

        function write(file, txt)
            %write  Write script text to FILE (creating the folder).
            arguments
                file (1,1) string
                txt (1,1) string
            end
            d = fileparts(file);
            if strlength(d) > 0 && ~isfolder(d); mkdir(d); end
            fid = fopen(file, 'w');
            if fid < 0
                error('EphysPipelineScript:CannotWrite', 'Cannot open %s for writing.', file);
            end
            fwrite(fid, char(txt), 'char');
            fclose(fid);
        end

        function s = literal(v)
            %literal  MATLAB source text that evaluates back to V.
            if isstring(v) || ischar(v)
                v = string(v);
                if isscalar(v)
                    s = """" + replace(v, """", """""") + """";
                elseif isempty(v)
                    s = "string.empty(1,0)";
                else
                    parts = arrayfun(@(x) """" + replace(x, """", """""") + """", v(:).');
                    s = "[" + strjoin(parts, " ") + "]";
                end
            elseif islogical(v)
                if isempty(v)
                    s = "logical.empty(1,0)";
                elseif isscalar(v)
                    if v; s = "true"; else; s = "false"; end
                else
                    s = "logical(" + string(mat2str(double(v))) + ")";
                end
            elseif isnumeric(v)
                if isempty(v)
                    s = "[]";
                else
                    s = string(mat2str(double(v), 15));
                end
            elseif isstruct(v)
                if isempty(fieldnames(v))
                    s = "struct()";
                else
                    parts = strings(1, 0);
                    for f = string(fieldnames(v)).'
                        val = v.(f);
                        if iscell(val) || (isstruct(val) && ~isscalar(val))
                            parts(end+1) = "'" + f + "', {" + EphysPipelineScript.literal(val) + "}"; %#ok<AGROW>
                        else
                            parts(end+1) = "'" + f + "', " + EphysPipelineScript.literal(val); %#ok<AGROW>
                        end
                    end
                    s = "struct(" + strjoin(parts, ", ") + ")";
                end
            elseif iscell(v)
                parts = cellfun(@(x) EphysPipelineScript.literal(x), v(:).', 'UniformOutput', false);
                s = "{" + strjoin(string(parts), ", ") + "}";
            else
                error('EphysPipelineScript:Literal', 'Cannot render a %s as a literal.', class(v));
            end
        end

        function L = structLiteral(name, s)
            %structLiteral  Lines "name = struct(); name.field = ...;" for a struct.
            L = strings(0, 1);
            L(end+1, 1) = name + " = struct();";
            for f = string(fieldnames(s)).'
                v = s.(f);
                if isstruct(v) && isscalar(v)
                    L = [L; EphysPipelineScript.structLiteral(name + "." + f, v)]; %#ok<AGROW>
                else
                    L(end+1, 1) = name + "." + f + " = " + EphysPipelineScript.literal(v) + ";"; %#ok<AGROW>
                end
            end
        end
    end

    methods (Static, Access = private)
        function s = inlineStruct(v)
            s = EphysPipelineScript.literal(v);
        end

        function e = outDirExpr(setting)
            %outDirExpr  Expression for a step's output folder for dataset d.
            if strlength(strtrim(string(setting))) == 0
                e = "d.outputFolder()";
            else
                e = EphysPipelineScript.literal(string(setting));
            end
        end

        function L = stepHeader(title, enabled)
            L = strings(0, 1);
            if enabled
                L(end+1, 1) = "%% " + title;
            else
                L(end+1, 1) = "%% " + title + " (disabled in the config: skipped)";
                L(end+1, 1) = "if false   % set to true to run this step";
            end
        end

        function L = stepFooter(enabled)
            L = strings(0, 1);
            if ~enabled
                L(end+1, 1) = "end";
            end
            L(end+1, 1) = "";
        end
    end
end
