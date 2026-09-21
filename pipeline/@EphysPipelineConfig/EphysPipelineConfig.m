classdef EphysPipelineConfig
    % EphysPipelineConfig  Everything a preprocessing run needs, in one value.
    %   A config holds the parameters of every pipeline step, which steps are
    %   enabled, the project root / output root and the dataset selection. It
    %   has no GUI dependency: the app edits one, EphysPipeline runs one, and
    %   generated scripts load one. It round-trips through JSON exactly
    %   (Inf / NaN / empty values included).
    %
    %   Sections (one struct property each; see defaults(section))
    %     Project    Root, OutputRoot, Selection "all"|"list", Datasets (keys),
    %                NamePattern (dataset-name tokens, see parseNameTokens),
    %                TokenColumns (tokens shown as dataset-table columns)
    %     Acquisition  reader options: OpenEphys.Recordings ("concatenate" |
    %                "separate" | "single"), OpenEphys.RecordNode,
    %                OpenEphys.Stream (see OpenEphysReader)
    %     Parallel   Enabled, MaxWorkers (NaN = automatic): run the chunks of
    %                the artifacts and spike-detection steps on a process pool
    %     Probe      DefaultProbeFile, WriteDefaultToManifest
    %     Behavior   Enabled, SearchDirs, Match, MaxStartOffsetMin, Overwrite,
    %                WriteFile, PairTrials, AutoApprove, TrialLine
    %     Artifacts  Enabled + detector / filter settings, ApplyTo*, CacheIntervals
    %     Sorting    Enabled, Engine (spikeinterface | kilosort), PythonExe,
    %                CondaEnv, Execution, MaxConcurrent (background runs at
    %                once; the others wait for a free slot), Devices
    %                (torch devices such as "cuda:0" "cuda:1" shared out
    %                among the runs; none = Kilosort4's choice), DryRun,
    %                SkipExisting, SI (SpikeInterface), KS4 (typed per
    %                kilosortParamSpec), KS4ExtraJSON
    %     Signals    Enabled + the derived-signal (toMat) settings,
    %                ExcludeHandling, LabelField ("custom" | "native" names),
    %                LineNames ("native=name" digital-line names) and
    %                InvertedLines (digital-line polarity); the line naming
    %                and polarity are also used by the trial pairing
    %     Spikes     Enabled, Source, detection settings, sorted-unit settings,
    %                output settings
    %     Export     Enabled, Formats (a subset of ExportFormats: the
    %                analysis-toolbox files and the event-organized epochs),
    %                what to include, the Epoch* settings of the epoch format
    %
    %   Usage
    %     cfg = EphysPipelineConfig();                 % defaults
    %     cfg.Project.Root = "D:\EPHYS";
    %     cfg.Signals.Enabled = true;                  % sections are normalized on set
    %     cfg.save("my_pipeline.json");
    %     cfg = EphysPipelineConfig.load("my_pipeline.json");
    %     issues = cfg.validate();                     % table of problems
    %     pipe = EphysPipeline(cfg); pipe.run();
    %
    %   Values are coerced to the type and shape of the corresponding default
    %   whenever a section is assigned (so a 1-element string list read back
    %   from JSON is a string array again, "Inf" is Inf, ...). Unknown fields
    %   are dropped with a warning (LoadWarnings lists them after load).
    %
    %   See also EphysPipeline, EphysPipelineScript, EphysPipelineConfig.defaults,
    %   EphysPipelineConfig.validate.

    properties
        Name        (1,1) string = "Untitled"
        Description (1,1) string = ""
        Project     struct = EphysPipelineConfig.defaults("Project")
        Acquisition struct = EphysPipelineConfig.defaults("Acquisition")
        Parallel    struct = EphysPipelineConfig.defaults("Parallel")
        Probe       struct = EphysPipelineConfig.defaults("Probe")
        Behavior    struct = EphysPipelineConfig.defaults("Behavior")
        Artifacts   struct = EphysPipelineConfig.defaults("Artifacts")
        Sorting     struct = EphysPipelineConfig.defaults("Sorting")
        Signals     struct = EphysPipelineConfig.defaults("Signals")
        Spikes      struct = EphysPipelineConfig.defaults("Spikes")
        Export      struct = EphysPipelineConfig.defaults("Export")
    end

    properties (Transient)
        File         (1,1) string = ""            % where it was loaded from / saved to
        LoadWarnings (1,:) string = string.empty(1,0)
    end

    properties (Constant)
        Schema   = "ephys-pipeline-config"
        Version  = 1
        Sections = ["Project" "Acquisition" "Parallel" "Probe" "Behavior" "Artifacts" "Sorting" "Signals" "Spikes" "Export"]
        % Execution order of the steps (Project, Acquisition and Parallel are not steps; Probe is a preflight).
        StepNames = ["probe" "behavior" "artifacts" "sorting" "signals" "spikes" "export"]
        % Section that holds each step's settings.
        StepSections = ["Probe" "Behavior" "Artifacts" "Sorting" "Signals" "Spikes" "Export"]
        % Export formats the Export step can write: one per analysis
        % toolbox, plus "epochs", the same data organized by event. Each has
        % an EphysDataset.export<Format> method.
        ExportFormats = ["chronux" "fieldtrip" "epochs"]
        % Kilosort4 parameters that depend on the probe layout: what
        % ks4ProbeDefaults derives and what a probe's parameter file holds
        % when it is created from the Sorting tab.
        KS4ProbeParams = ["nblocks" "dmin" "dminx" "nearest_chans" "nearest_templates" "min_template_size" "x_centers"]
        % A probe map <name>.json keeps its Kilosort4 parameters in <name>.ks4.json.
        KS4ParamsSuffix = ".ks4.json"
        KS4ParamsSchema = "ephys-ks4-params/1"
    end

    methods
        % --- methods defined in separate files ---
        issues = validate(obj, opts)

        function obj = EphysPipelineConfig(s)
            %EphysPipelineConfig  Defaults, or from a struct (see fromStruct).
            if nargin > 0 && ~isempty(s)
                obj = EphysPipelineConfig.fromStruct(s);
            end
        end

        %% --- normalizing setters -------------------------------------------
        function obj = set.Project(obj, s);   obj.Project   = EphysPipelineConfig.normalizeSection("Project", s);   end
        function obj = set.Acquisition(obj, s); obj.Acquisition = EphysPipelineConfig.normalizeSection("Acquisition", s); end
        function obj = set.Parallel(obj, s);  obj.Parallel  = EphysPipelineConfig.normalizeSection("Parallel", s);  end
        function obj = set.Probe(obj, s);     obj.Probe     = EphysPipelineConfig.normalizeSection("Probe", s);     end
        function obj = set.Behavior(obj, s);  obj.Behavior  = EphysPipelineConfig.normalizeSection("Behavior", s);  end
        function obj = set.Artifacts(obj, s); obj.Artifacts = EphysPipelineConfig.normalizeSection("Artifacts", s); end
        function obj = set.Sorting(obj, s);   obj.Sorting   = EphysPipelineConfig.normalizeSection("Sorting", s);   end
        function obj = set.Signals(obj, s);   obj.Signals   = EphysPipelineConfig.normalizeSection("Signals", s);   end
        function obj = set.Spikes(obj, s);    obj.Spikes    = EphysPipelineConfig.normalizeSection("Spikes", s);    end
        function obj = set.Export(obj, s);    obj.Export    = EphysPipelineConfig.normalizeSection("Export", s);    end

        %% --- struct / JSON --------------------------------------------------
        function s = toStruct(obj)
            %toStruct  Plain struct (schema, version, name, description, sections).
            s = struct('schema', EphysPipelineConfig.Schema, 'version', EphysPipelineConfig.Version, ...
                'name', obj.Name, 'description', obj.Description);
            for sec = EphysPipelineConfig.Sections
                s.(sec) = obj.(sec);
            end
        end

        function obj = save(obj, file)
            %save  Write the config as pretty JSON (atomic; Inf/NaN as strings).
            arguments
                obj (1,1) EphysPipelineConfig
                file (1,1) string
            end
            writeJsonFile(file, obj.toStruct(), NonFinite="string");
            obj.File = file;
        end

        function tf = isStep(~, name)
            tf = ismember(string(name), EphysPipelineConfig.StepNames);
        end

        function s = stepSection(obj, step)
            %stepSection  The settings struct of a step ("sorting" -> Sorting).
            ix = find(EphysPipelineConfig.StepNames == string(step), 1);
            if isempty(ix)
                error('EphysPipelineConfig:BadStep', 'Unknown step "%s".', string(step));
            end
            s = obj.(EphysPipelineConfig.StepSections(ix));
        end

        function tf = stepEnabled(obj, step)
            %stepEnabled  Whether a step runs (probe is always on).
            s = obj.stepSection(step);
            if isfield(s, 'Enabled'); tf = logical(s.Enabled); else; tf = true; end
        end

        function names = enabledSteps(obj)
            names = EphysPipelineConfig.StepNames(arrayfun(@(n) obj.stepEnabled(n), EphysPipelineConfig.StepNames));
        end

        function tf = isequalConfig(obj, other)
            %isequalConfig  True when two configs hold the same values (NaN == NaN).
            tf = isequaln(obj.toStruct(), other.toStruct());
        end
    end

    methods (Static)
        % --- methods defined in separate files ---
        spec  = kilosortParamSpec()
        s     = defaults(section)
        [s, unknown] = normalizeSection(section, s)
        [ks4, errMsg] = ks4Settings(sorting)
        [sorting, report] = ks4ForProbe(sorting, probeFile)
        [values, report] = ks4ProbeDefaults(probe, opts)
        file  = ks4ParamsFile(probeFile)
        file  = writeKS4Params(probeFile, values, opts)
        s     = signalOptions(signals, opts)
        v     = parseOrderedList(txt, what)
        v     = parseFreqList(txt, what)

        function obj = fromStruct(s)
            %fromStruct  Build a config from a struct (e.g. decoded JSON).
            %   Missing sections take their defaults; unknown fields are dropped
            %   and listed in LoadWarnings.
            arguments
                s (1,1) struct
            end
            obj = EphysPipelineConfig();
            warn = string.empty(1, 0);
            if isfield(s, 'name');        obj.Name = string(s.name);               end
            if isfield(s, 'description'); obj.Description = string(s.description); end
            for sec = EphysPipelineConfig.Sections
                if isfield(s, sec)
                    [v, unknown] = EphysPipelineConfig.normalizeSection(sec, s.(sec));
                    obj.(sec) = v;
                    if ~isempty(unknown)
                        warn(end+1) = sec + ": dropped unknown field(s) " + strjoin(unknown, ", "); %#ok<AGROW>
                    end
                end
            end
            known = ["schema" "version" "name" "description" EphysPipelineConfig.Sections];
            extra = setdiff(string(fieldnames(s)).', known);
            if ~isempty(extra)
                warn(end+1) = "dropped unknown top-level field(s) " + strjoin(extra, ", ");
            end
            obj.LoadWarnings = warn;
        end

        function obj = load(file)
            %load  Read a config JSON; errors on a wrong schema or version.
            arguments
                file (1,1) string
            end
            s = readJsonFile(file);
            if ~isstruct(s) || ~isfield(s, 'schema') || string(s.schema) ~= EphysPipelineConfig.Schema
                error('EphysPipelineConfig:BadSchema', ...
                    '%s is not an %s file.', file, EphysPipelineConfig.Schema);
            end
            if ~isfield(s, 'version') || double(s.version) ~= EphysPipelineConfig.Version
                error('EphysPipelineConfig:BadSchema', ...
                    '%s has config version %s; this code reads version %d only.', ...
                    file, string(jsonencode(s.version)), EphysPipelineConfig.Version);
            end
            obj = EphysPipelineConfig.fromStruct(s);
            obj.File = file;
            if ~isempty(obj.LoadWarnings)
                warning('EphysPipelineConfig:LoadWarnings', '%s: %s', file, strjoin(obj.LoadWarnings, '; '));
            end
        end

        function validateSuffix(sfx)
            %validateSuffix  Error (EphysPipelineConfig:SignalsBadSuffix) on file-name characters.
            if ~isempty(regexp(char(string(sfx)), '[\\/:*?"<>|]', 'once'))
                error('EphysPipelineConfig:SignalsBadSuffix', ...
                    'File suffix contains characters not allowed in file names: \\ / : * ? " < > |');
            end
        end

        function names = parseTokenColumns(txt)
            %parseTokenColumns  Project.TokenColumns list text -> string row of token names.
            t = strtrim(split(string(txt), [",", ";"])).';
            names = unique(t(t ~= ""), 'stable');
        end

        function key = datasetKey(root, folder)
            %datasetKey  Root-relative key used in Project.Datasets (see EphysProject.relativeKey).
            key = EphysProject.relativeKey(root, folder);
        end

        %% --- per-step option builders ----------------------------------------
        function tc = trialConfig(cfg)
            %trialConfig  EphysDataset.TrialConfig from the Behavior section
            %   (plus Signals.LabelField / LineNames / InvertedLines, the
            %   digital-line naming and polarity every events output shares).
            %   SignalFs holds the rate of every enabled derived signal (LFP,
            %   MUA, SPIKE; SPIKE only when resampled) so the pairing adds
            %   sample columns for each.
            B = cfg.Behavior;
            S = cfg.Signals;
            fs = struct();
            if S.LFP;   fs.LFP = S.LFP_Fs; end
            if S.MUA;   fs.MUA = S.MUA_Fs; end
            if S.SPIKE && ~S.SPIKE_KeepOriginal; fs.SPIKE = S.SPIKE_Fs; end
            tc = EphysDataset.defaultTrialConfig();
            tc.TrialLine      = B.TrialLine;
            tc.InvertedLines  = S.InvertedLines;
            tc.SignalFs       = fs;
            tc.LabelField     = S.LabelField;
            tc.LineNames      = S.LineNames;
        end

        function cfg = artifactConfig(a)
            %artifactConfig  The Artifacts section as an EphysDataset.ArtifactConfig.
            a = EphysPipelineConfig.normalizeSection("Artifacts", a);
            cfg = EphysDataset.defaultArtifactConfig();
            for f = string(fieldnames(cfg)).'
                if isfield(a, f); cfg.(f) = a.(f); end
            end
        end

        function d = detectOptions(sp, par)
            %detectOptions  The Spikes section as spikesToMat DetectOptions.
            %   NaN-valued "auto" settings (Threshold, MaxChunkSamples,
            %   EdgePadMs) are left out so detectSpikes uses its own defaults.
            %   With a Parallel section as the second argument its options
            %   (parallelOptions: UseParallel, MaxWorkers) are added.
            sp = EphysPipelineConfig.normalizeSection("Spikes", sp);
            d = struct('Filter', sp.Filter, 'Band', sp.Band, 'FilterOrder', sp.FilterOrder, ...
                'Polarity', sp.Polarity, 'ThresholdMethod', sp.ThresholdMethod, ...
                'Align', sp.Align, 'AlignWindowMs', sp.AlignWindowMs, ...
                'MinPeriodMs', sp.MinPeriodMs, 'MaxAmplitudeUV', sp.MaxAmplitudeUV, ...
                'Waveforms', sp.Waveforms, 'WindowMs', sp.WindowMs, ...
                'WaveformSource', sp.WaveformSource, 'EdgeHandling', sp.EdgeHandling);
            if isfinite(sp.Threshold);       d.Threshold       = sp.Threshold;       end
            if isfinite(sp.MaxChunkSamples); d.MaxChunkSamples = sp.MaxChunkSamples; end
            if isfinite(sp.EdgePadMs);       d.EdgePadMs       = sp.EdgePadMs;       end
            if nargin > 1
                p = EphysPipelineConfig.parallelOptions(par);
                for f = string(fieldnames(p)).'
                    d.(f) = p.(f);
                end
            end
        end

        function p = parallelOptions(par)
            %parallelOptions  The Parallel section as UseParallel / MaxWorkers options.
            %   A struct for namedargs2cell: UseParallel always, MaxWorkers only
            %   when set (NaN = the automatic, memory-derived cap is left to the
            %   dataset methods).
            par = EphysPipelineConfig.normalizeSection("Parallel", par);
            p = struct('UseParallel', logical(par.Enabled));
            if isfinite(par.MaxWorkers); p.MaxWorkers = par.MaxWorkers; end
        end

        function ch = spikeChannels(sp, ds)
            %spikeChannels  1-based channels to detect on for dataset DS ([] = all).
            sp = EphysPipelineConfig.normalizeSection("Spikes", sp);
            switch sp.Channels
                case "all"
                    ch = [];
                case "excludeManifest"
                    n = ds.NumChannels;
                    if isnan(n); ch = []; else; ch = setdiff(1:n, ds.ExcludeChannels); end
                case "list"
                    ch = EphysPipelineConfig.parseOrderedList(sp.ChannelList, "Spikes channel list");
            end
        end

        function o = exportOptions(e, fmt)
            %exportOptions  Name-value struct for the export<Format> method of FMT.
            %   The shared options, plus Validate (fieldtrip) or the Epoch*
            %   settings under the epoch exporter's own names (epochs).
            e = EphysPipelineConfig.normalizeSection("Export", e);
            o = struct();
            if ~isempty(e.Signals); o.Signals = e.Signals; end
            if e.IncludeUnits;    o.Units = [];    else; o.Units = false;    end
            o.Detected = logical(e.IncludeDetected);
            o.Events   = logical(e.IncludeEvents);
            o.Groups     = e.Groups;
            o.Overwrite  = logical(e.Overwrite);
            o.MatVersion = e.MatVersion;
            if nargin > 1 && string(fmt) == "fieldtrip"
                o.Validate = logical(e.Validate);
            end
            if nargin > 1 && string(fmt) == "epochs"
                o.EventSource   = e.EpochSource;
                o.EventLine     = e.EpochLine;
                o.Window        = e.EpochWindow;
                o.OnsetRule     = e.EpochOnsetRule;
                o.Incomplete    = e.EpochIncomplete;
                o.NonFinite     = e.EpochNonFinite;
                o.SpikeTimeBase = e.EpochSpikeTimeBase;
                o.Class         = e.EpochClass;
            end
        end

        function txt = ks4ParamText(kind, value)
            %ks4ParamText  Typed KS4 value -> text for an edit field.
            switch string(kind)
                case "floatinf"
                    if isempty(value) || ~isfinite(value); txt = "Infinity"; else; txt = string(value); end
                case "nullable"
                    if isempty(value) || (isnumeric(value) && any(isnan(value))); txt = ""; else; txt = string(value); end
                case "vector"
                    if isempty(value); txt = ""; else; txt = strjoin(string(value(:).'), ", "); end
                otherwise
                    txt = string(value);
            end
        end

        function [value, ok] = ks4ParamFromText(kind, txt)
            %ks4ParamFromText  Edit-field text -> typed KS4 value ([] / Inf / row).
            ok = true;
            t = strtrim(string(txt));
            switch string(kind)
                case "floatinf"
                    if t == "" || any(lower(t) == ["inf" "+inf" "infinity"])
                        value = Inf;
                    else
                        value = str2double(t); ok = ~isnan(value);
                    end
                case "nullable"
                    if t == "" || any(lower(t) == ["null" "none" "nan"])
                        value = [];
                    else
                        value = str2double(t); ok = ~isnan(value);
                    end
                case "vector"
                    if t == ""
                        value = double.empty(1, 0);
                    else
                        value = sscanf(char(replace(t, ",", " ")), '%g').';
                        ok = ~isempty(value) && ~any(isnan(value));
                    end
                case "bool"
                    value = any(lower(t) == ["1" "true" "yes" "on"]);
                case "int"
                    value = round(str2double(t)); ok = ~isnan(value);
                otherwise
                    value = str2double(t); ok = ~isnan(value);
            end
        end
    end
end
