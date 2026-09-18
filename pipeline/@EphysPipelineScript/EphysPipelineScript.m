classdef EphysPipelineScript
    % EphysPipelineScript  Generate MATLAB scripts that reproduce a config's run.
    %   Two forms:
    %     compact(cfg, ConfigFile=)   a short script that loads the JSON config
    %                                 and calls one EphysPipeline method per
    %                                 step (disabled steps are written out
    %                                 commented). Keep the config next to it.
    %     standalone(cfg)             every parameter written out as MATLAB
    %                                 literals; calls EphysProject /
    %                                 EphysDataset (and the pure option
    %                                 builders of EphysPipelineConfig) directly,
    %                                 never the EphysPipeline runner, so it
    %                                 documents exactly what a run does and
    %                                 needs no config file.
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
            L(end+1, 1) = "";
            L(end+1, 1) = "pipe = EphysPipeline(cfg);      % scans the project root, applies the manifests";
            L(end+1, 1) = "disp(pipe.plan());              % what will run; writes nothing";
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
            L(end+1, 1) = "P = EphysProject(root, OutputRoot=outputRoot, PythonExe=" + lit(cfg.Sorting.PythonExe) + ...
                ", CondaEnv=" + lit(cfg.Sorting.CondaEnv) + ", NamePattern=" + lit(cfg.Project.NamePattern) + ...
                ", Recursive=" + lit(cfg.Project.Recursive) + ");";
            L(end+1, 1) = "P.refresh();                       % headers + per-dataset manifests (probe, exclusions, ...)";
            if cfg.Project.Selection == "list"
                L(end+1, 1) = "keys = " + lit(cfg.Project.Datasets) + ";   % root-relative dataset keys";
                L(end+1, 1) = "idx = P.findByKey(keys);";
                L(end+1, 1) = "idx = idx(idx > 0);";
            else
                L(end+1, 1) = "idx = 1:P.NumDatasets;             % every dataset under the root";
            end
            L(end+1, 1) = "I = P.unitIdentities(Among=idx);   % subject + recording start that label sorted units";
            L(end+1, 1) = "if any(I.Status ~= ""ok""); disp(I(I.Status ~= ""ok"", [""Key"" ""Status"" ""Message""])); end";
            L(end+1, 1) = "";
            L(end+1, 1) = "% Shared settings pushed onto every dataset";
            L = [L; EphysPipelineScript.structLiteral("siConfig", cfg.Sorting.SI)];
            L = [L; EphysPipelineScript.structLiteral("artifactConfig", EphysPipelineConfig.artifactConfig(cfg.Artifacts))];
            L = [L; EphysPipelineScript.structLiteral("parallelOpts", EphysPipelineConfig.parallelOptions(cfg.Parallel))];
            L(end+1, 1) = "parallelArgs = namedargs2cell(parallelOpts);   % UseParallel / MaxWorkers for the chunked steps";
            L(end+1, 1) = "for k = idx";
            L(end+1, 1) = "    d = P.Datasets(k);";
            L(end+1, 1) = "    d.PythonExe = " + lit(cfg.Sorting.PythonExe) + ";";
            L(end+1, 1) = "    d.CondaEnv = " + lit(cfg.Sorting.CondaEnv) + ";";
            L(end+1, 1) = "    d.SIConfig = siConfig;";
            L(end+1, 1) = "    d.ArtifactConfig = artifactConfig;";
            L(end+1, 1) = "end";
            L(end+1, 1) = "";

            % --- probe ---------------------------------------------------------------
            L(end+1, 1) = "%% Probe (preflight)";
            L(end+1, 1) = "defaultProbe = " + lit(cfg.Probe.DefaultProbeFile) + ";";
            L(end+1, 1) = "for k = idx";
            L(end+1, 1) = "    d = P.Datasets(k);";
            L(end+1, 1) = "    if d.ProbeFile == """" && defaultProbe ~= """"";
            L(end+1, 1) = "        d.ProbeFile = defaultProbe;";
            if cfg.Probe.WriteDefaultToManifest
                L(end+1, 1) = "        d.writeManifest();";
            end
            L(end+1, 1) = "    end";
            L(end+1, 1) = "    fprintf('%s: probe %s\n', d.Name, d.ProbeFile);";
            L(end+1, 1) = "end";
            L(end+1, 1) = "";

            % --- behavior ------------------------------------------------------------
            L = [L; EphysPipelineScript.stepHeader("Behavior (Epsych2 sessions)", cfg.stepEnabled("behavior"))];
            B = cfg.Behavior;
            L(end+1, 1) = "sessions = findEpsychSessions(" + lit(B.SearchDirs) + ");";
            L(end+1, 1) = "for k = idx";
            L(end+1, 1) = "    d = P.Datasets(k);";
            L(end+1, 1) = "    if d.BehaviorFile == """" || ~isfile(d.BehaviorFile) || " + lit(logical(B.Overwrite));
            L(end+1, 1) = "        m = matchEpsychSession(sessions, d, Match=" + lit(B.Match) + ...
                ", MaxStartOffsetMin=" + lit(B.MaxStartOffsetMin) + ");";
            L(end+1, 1) = "        if m.file ~= """"";
            L(end+1, 1) = "            d.BehaviorFile = m.file;";
            L(end+1, 1) = "            d.writeManifest();";
            L(end+1, 1) = "        end";
            L(end+1, 1) = "        fprintf('%s: behavior %s (%s)\n', d.Name, m.file, m.reason);";
            L(end+1, 1) = "    end";
            if B.WriteFile
                L(end+1, 1) = "    if d.BehaviorFile ~= """" && isfile(d.BehaviorFile)";
                L(end+1, 1) = "        r = d.behaviorToMat(Overwrite=true);   % <Name>_behavior.mat, the one copy of the behavior data";
                L(end+1, 1) = "        fprintf('%s: wrote %s\n', d.Name, r.file);";
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
            if S.Engine == "kilosort"
                sortTitle = "Sorting: Kilosort4 (native, via a .bin)";
                sortCall = "d.runKilosort";
            else
                sortTitle = "Sorting: SpikeInterface + Kilosort4";
                sortCall = "d.runSpikeInterface";
            end
            L = [L; EphysPipelineScript.stepHeader(sortTitle, cfg.stepEnabled("sorting"))];
            [ks4, ~] = EphysPipelineConfig.ks4Settings(S);
            L = [L; EphysPipelineScript.structLiteral("ks4", ks4)];
            L(end+1, 1) = "for k = idx";
            L(end+1, 1) = "    d = P.Datasets(k);";
            L(end+1, 1) = "    if d.ProbeFile == """"; fprintf('%s: no probe, skipped\n', d.Name); continue; end";
            if S.SkipExisting
                L(end+1, 1) = "    if d.hasKilosortResults(); fprintf('%s: already sorted, skipped\n', d.Name); continue; end";
            end
            L(end+1, 1) = "    try";
            if cfg.Artifacts.ApplyToSorting
                L(end+1, 1) = "        iv = artifactIntervals(d);";
            else
                L(end+1, 1) = "        iv = d.artifactIntervals(IncludeAuto=false);";
            end
            L(end+1, 1) = "        res = " + sortCall + "(ExtraSettings=ks4, ArtifactIntervals=iv, DryRun=" + ...
                lit(logical(S.DryRun)) + ", Wait=" + lit(S.Execution == "blocking") + ");";
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
            L = [L; EphysPipelineScript.stepHeader("Export: analysis-toolbox files",cfg.stepEnabled("export"))];
            E = cfg.Export;
            L(end+1, 1) = "formats = " + lit(E.Formats) + ";";
            L(end+1, 1) = "for k = idx";
            L(end+1, 1) = "    d = P.Datasets(k);";
            L(end+1, 1) = "    extract = EphysDataset.recordedSignalFiles(" + sigFilesExpr + ");";
            L(end+1, 1) = "    spikesFile = fullfile(" + EphysPipelineScript.outDirExpr(K.OutputDir) + ", d.Name + " + lit(K.Suffix) + " + "".mat"");";
            L(end+1, 1) = "    if isempty(extract) || ~all(isfile(extract)); fprintf('%s: no extract file, skipped\n', d.Name); continue; end";
            L(end+1, 1) = "    for fmt = formats";
            L(end+1, 1) = "        outFile = fullfile(" + EphysPipelineScript.outDirExpr(E.OutputDir) + ", d.Name + ""_"" + fmt + "".mat"");";
            L(end+1, 1) = "        if isfile(outFile) && ~" + lit(logical(E.Overwrite)) + "; fprintf('%s: %s exists, skipped\n', d.Name, outFile); continue; end";
            L(end+1, 1) = "        try";
            L(end+1, 1) = "            o = EphysPipelineConfig.exportOptions(" + EphysPipelineScript.inlineStruct(E) + ", fmt);";
            if E.IncludeDetected
                L(end+1, 1) = "            if isfile(spikesFile); o.Detected = spikesFile; else; o.Detected = false; end";
            end
            L(end+1, 1) = "            args = namedargs2cell(o);";
            L(end+1, 1) = "            switch fmt";
            L(end+1, 1) = "                case ""chronux""";
            L(end+1, 1) = "                    r = d.exportChronux('File', outFile, 'Extract', extract, args{:});";
            L(end+1, 1) = "                case ""fieldtrip""";
            L(end+1, 1) = "                    r = d.exportFieldTrip('File', outFile, 'Extract', extract, args{:});";
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
