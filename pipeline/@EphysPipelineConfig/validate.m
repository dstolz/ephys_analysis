function issues = validate(obj, opts)
%validate  Check the config for problems, enabled steps only.
%   ISSUES = cfg.validate() returns a table (Step, Field, Severity, Message)
%   with Severity "error" (the run cannot start) or "warning". Project,
%   Parallel and Probe are always checked; step sections only when Enabled.
%   Cross-step rules are checked too (e.g. a background sorting run cannot
%   feed the sorted-unit consumers in the same run). An empty table means clean.
%
%   Options: CheckPaths (default true) also checks that Root / files exist.
%
%   See also EphysPipelineConfig, EphysPipeline.plan.

arguments
    obj (1,1) EphysPipelineConfig
    opts.CheckPaths (1,1) logical = true
end

Step = strings(0, 1); Field = strings(0, 1); Severity = strings(0, 1); Message = strings(0, 1);
    function add(step, field, sev, msg)
        Step(end+1, 1) = step; Field(end+1, 1) = field; Severity(end+1, 1) = sev; Message(end+1, 1) = msg;
    end

% --- Project -------------------------------------------------------------------
P = obj.Project;
if P.Root == ""
    add("project", "Root", "error", "Project root is empty.");
elseif opts.CheckPaths && ~isfolder(P.Root)
    add("project", "Root", "error", "Project root does not exist: " + P.Root);
end
if P.OutputRoot == ""
    add("project", "OutputRoot", "warning", "No output root: outputs are written next to each recording.");
end
if P.Selection == "list" && isempty(P.Datasets)
    add("project", "Datasets", "warning", "Selection is ""list"" but no datasets are listed; nothing will run.");
end
patternParses = true;
try
    [~, tokenNames] = parseNameTokens("", P.NamePattern);
    for t = setdiff(EphysPipelineConfig.parseTokenColumns(P.TokenColumns), tokenNames, 'stable')
        add("project", "TokenColumns", "warning", "Token column """ + t + """ is not in the name pattern.");
    end
catch ME
    patternParses = false;
    add("project", "NamePattern", "error", string(ME.message));
end

% --- Acquisition (always) ------------------------------------------------------
OE = obj.Acquisition.OpenEphys;
if ~ismember(OE.Recordings, ["concatenate" "separate" "single"])
    add("acquisition", "OpenEphys.Recordings", "error", ...
        "OpenEphys.Recordings must be ""concatenate"", ""separate"" or ""single"".");
end
if OE.RecordNode ~= "" && isempty(regexp(OE.RecordNode, '^\d+$', 'once'))
    add("acquisition", "OpenEphys.RecordNode", "error", ...
        "OpenEphys.RecordNode must be empty or a Record Node id (digits, e.g. 101).");
end

% --- Probe (always) ------------------------------------------------------------
if obj.Probe.DefaultProbeFile ~= "" && opts.CheckPaths && ~isfile(obj.Probe.DefaultProbeFile)
    add("probe", "DefaultProbeFile", "error", "Default probe file not found: " + obj.Probe.DefaultProbeFile);
end

% --- Parallel (always) -----------------------------------------------------------
PL = obj.Parallel;
if ~isnan(PL.MaxWorkers) && ~(PL.MaxWorkers >= 1 && PL.MaxWorkers == round(PL.MaxWorkers))
    add("parallel", "MaxWorkers", "error", "MaxWorkers must be a whole number >= 1, or NaN for automatic.");
end
if PL.Enabled && ~license('test', 'Distrib_Computing_Toolbox')
    add("parallel", "Enabled", "warning", "Parallel is on but the Parallel Computing Toolbox is not licensed; the steps run serially.");
end

% --- Behavior --------------------------------------------------------------------
B = obj.Behavior;
if B.Enabled
    if isempty(B.SearchDirs)
        add("behavior", "SearchDirs", "warning", "No search folders for Epsych2 sessions; nothing can be matched.");
    elseif opts.CheckPaths
        for d = B.SearchDirs
            if ~isfolder(d); add("behavior", "SearchDirs", "warning", "Search folder not found: " + d); end
        end
    end
    if ~(B.MaxStartOffsetMin > 0)
        add("behavior", "MaxStartOffsetMin", "error", "MaxStartOffsetMin must be positive.");
    end
    if B.PairTrials && strtrim(B.TrialLine) == ""
        add("behavior", "TrialLine", "error", "TrialLine must name the digital line that is on during trials.");
    end
end

% --- Artifacts -------------------------------------------------------------------
A = obj.Artifacts;
if A.Enabled
    if ~ismember(A.Method, ["rms" "mad" "microvolts" "commonmode"])
        add("artifacts", "Method", "error", "Unknown artifact method """ + A.Method + """.");
    end
    if ~(A.Threshold > 0); add("artifacts", "Threshold", "error", "Threshold must be positive."); end
    if ~(A.MinChannels >= 1); add("artifacts", "MinChannels", "error", "MinChannels must be >= 1."); end
    if A.Filter
        if any(~(A.FilterCutoff > 0)); add("artifacts", "FilterCutoff", "error", "Filter cut-off must be positive."); end
        if A.FilterType == "bandpass" && numel(A.FilterCutoff) ~= 2
            add("artifacts", "FilterCutoff", "error", "A band-pass filter needs [lo hi] cut-offs.");
        end
    end
end

% --- Sorting ---------------------------------------------------------------------
S = obj.Sorting;
if S.Enabled
    if S.PythonExe == ""
        add("sorting", "PythonExe", "error", "PythonExe is required to run Kilosort4.");
    elseif opts.CheckPaths && ~isfile(S.PythonExe)
        add("sorting", "PythonExe", "warning", "Python executable not found: " + S.PythonExe);
    end
    if ~ismember(S.Engine, ["spikeinterface" "kilosort"])
        add("sorting", "Engine", "error", "Engine must be ""spikeinterface"" or ""kilosort"".");
    end
    if ~ismember(S.Execution, ["background" "blocking"])
        add("sorting", "Execution", "error", "Execution must be ""background"" or ""blocking"".");
    end
    [~, msg] = EphysPipelineConfig.ks4Settings(S);
    if msg ~= ""; add("sorting", "KS4ExtraJSON", "error", msg); end
    if S.SI.Filter && ~(S.SI.FilterFreqMin < S.SI.FilterFreqMax)
        add("sorting", "SI.FilterFreqMin", "error", "SpikeInterface band-pass edges must satisfy min < max.");
    end
end

% --- Signals ---------------------------------------------------------------------
G = obj.Signals;
if G.Enabled || B.Enabled
    % Line naming also names the lines the Behavior step pairs trials with.
    if ~ismember(G.LabelField, ["custom" "native"])
        add("signals", "LabelField", "error", "LabelField must be ""custom"" or ""native"".");
    end
    try
        EphysDataset.parseLineNames(G.LineNames);
    catch ME
        add("signals", "LineNames", "error", string(ME.message));
    end
end
if G.Enabled
    try
        EphysPipelineConfig.signalOptions(G, NumChannels=64);
    catch ME
        add("signals", string(regexprep(ME.identifier, '^.*:Signals', '')), "error", string(ME.message));
    end
    if ~ismember(G.MatVersion, ["-v7.3" "-v7"])
        add("signals", "MatVersion", "error", "MatVersion must be -v7.3 or -v7.");
    end
    if G.MUA && ~(G.MUA_Fs > 0); add("signals", "MUA_Fs", "error", "MUA_Fs must be positive."); end
    if G.LFP && ~(G.LFP_Fs > 0); add("signals", "LFP_Fs", "error", "LFP_Fs must be positive."); end
end

% --- Spikes ----------------------------------------------------------------------
K = obj.Spikes;
if K.Enabled
    if ~ismember(K.Source, ["detect" "sorted" "both"])
        add("spikes", "Source", "error", "Source must be detect, sorted or both.");
    end
    if K.Source ~= "sorted"
        if K.Filter && ~(K.Band(1) < K.Band(2) && K.Band(1) > 0)
            add("spikes", "Band", "error", "Band must be [lo hi] with 0 < lo < hi.");
        end
        if isfinite(K.Threshold) && ~(K.Threshold > 0)
            add("spikes", "Threshold", "error", "Threshold must be positive (or NaN for the method default).");
        end
        if ~(K.WindowMs(1) < K.WindowMs(2))
            add("spikes", "WindowMs", "error", "WindowMs must be [before after] with before < after.");
        end
        if ~ismember(K.Channels, ["all" "excludeManifest" "list"])
            add("spikes", "Channels", "error", "Channels must be all, excludeManifest or list.");
        elseif K.Channels == "list"
            try
                ch = EphysPipelineConfig.parseOrderedList(K.ChannelList, "Spikes channel list");
                if isempty(ch); add("spikes", "ChannelList", "error", "Channels is ""list"" but the list is empty."); end
            catch ME
                add("spikes", "ChannelList", "error", string(ME.message));
            end
        end
        try
            EphysPipelineConfig.validateSuffix(K.Suffix);
        catch ME
            add("spikes", "Suffix", "error", string(ME.message));
        end
    end
    if K.Source ~= "detect" && isempty(K.Groups) && ~K.IncludeNoise
        add("spikes", "Groups", "warning", "No unit groups selected; every non-noise cluster is kept.");
    end
end

% --- Export ----------------------------------------------------------------------
E = obj.Export;
if E.Enabled
    if isempty(E.Formats)
        add("export", "Formats", "error", "Export is enabled but no format is selected (" + strjoin(obj.ExportFormats, " / ") + ").");
    else
        bad = setdiff(E.Formats, obj.ExportFormats);
        if ~isempty(bad); add("export", "Formats", "error", "Unknown export format(s): " + strjoin(bad, ", ")); end
    end
    if ~G.Enabled
        add("export", "Signals", "warning", "The Signals step is off; each dataset needs an existing extract file.");
    end
    if E.IncludeDetected && ~(K.Enabled && K.Source ~= "sorted")
        add("export", "IncludeDetected", "warning", "Detected spikes are included only where a spikes file already exists.");
    end
end

% --- cross-step ------------------------------------------------------------------
needsSorted = (K.Enabled && K.Source ~= "detect") || (E.Enabled && E.IncludeUnits);
if needsSorted && patternParses
    id = EphysDataset.nameIdentity("", P.NamePattern);
    if id.reason == "pattern"
        add("project", "NamePattern", "error", id.message + " Sorted units are labelled from the dataset name.");
    end
end
if S.Enabled && S.Execution == "background" && ~S.DryRun && needsSorted
    add("sorting", "Execution", "error", ...
        "Sorting runs in the background but a later step in this run uses the sorted units; " + ...
        "set Execution to ""blocking"" or run those steps after sorting finishes.");
end

issues = table(Step, Field, Severity, Message);
end
