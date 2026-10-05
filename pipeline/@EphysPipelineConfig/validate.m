function issues = validate(obj, opts)
%validate  Check the config for problems, enabled steps only.
%   ISSUES = cfg.validate() returns a table (Step, Field, Severity, Message)
%   with Severity "error" (the run cannot start) or "warning". Project,
%   Acquisition, Parallel, Probe and Reference are always checked; step
%   sections only when Enabled.
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
TD = obj.Acquisition.TDT;
if ~(isnan(TD.GainToMicrovolts) || (isfinite(TD.GainToMicrovolts) && TD.GainToMicrovolts > 0))
    add("acquisition", "TDT.GainToMicrovolts", "error", ...
        "TDT.GainToMicrovolts must be NaN (automatic) or a positive number of microvolts per stored unit.");
end

% --- Probe (always) ------------------------------------------------------------
if obj.Probe.DefaultProbeFile ~= "" && opts.CheckPaths && ~isfile(obj.Probe.DefaultProbeFile)
    add("probe", "DefaultProbeFile", "error", "Default probe file not found: " + obj.Probe.DefaultProbeFile);
end
PR = obj.Probe;
if numel(PR.RuleSubjects) ~= numel(PR.RuleProbes)
    add("probe", "RuleSubjects", "error", "RuleSubjects and RuleProbes must have one entry each per rule.");
else
    for k = 1:numel(PR.RuleSubjects)
        if strtrim(PR.RuleSubjects(k)) == "" || strtrim(PR.RuleProbes(k)) == ""
            add("probe", "RuleSubjects", "error", sprintf("Probe rule %d needs both a subject pattern and a probe file.", k));
        elseif opts.CheckPaths && ~isfile(PR.RuleProbes(k))
            add("probe", "RuleProbes", "error", sprintf("Probe rule %d (%s): probe file not found: %s", k, PR.RuleSubjects(k), PR.RuleProbes(k)));
        end
    end
end

% --- Parallel (always) -----------------------------------------------------------
PL = obj.Parallel;
if ~isnan(PL.MaxWorkers) && ~(PL.MaxWorkers >= 1 && PL.MaxWorkers == round(PL.MaxWorkers))
    add("parallel", "MaxWorkers", "error", "MaxWorkers must be a whole number >= 1, or NaN for automatic.");
end
if PL.Enabled && ~license('test', 'Distrib_Computing_Toolbox')
    add("parallel", "Enabled", "warning", "Parallel is on but the Parallel Computing Toolbox is not licensed; the steps run serially.");
end

% --- Reference (always) ----------------------------------------------------------
% Every step that reads the recording takes it, whichever steps are on.
R = obj.Reference;
if ~ismember(R.Mode, ["none" "car" "cmr"])
    add("reference", "Mode", "error", "Reference.Mode must be ""none"", ""car"" or ""cmr"".");
end
if ~(R.BadLow >= 0 && R.BadHigh > R.BadLow)
    add("reference", "BadLow", "error", ...
        "The reference noise bounds must satisfy 0 <= BadLow < BadHigh.");
end

% --- Behavior --------------------------------------------------------------------
B = obj.Behavior;
if B.Enabled
    if ~B.Search
        % the associated sessions only: SearchDirs is not read
    elseif isempty(B.SearchDirs)
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
% The fill applies to the manual periods too, so it is checked whether or
% not automatic detection is on.
if ~ismember(A.Fill, ["noise" "zero"])
    add("artifacts", "Fill", "error", "Fill must be ""noise"" or ""zero"".");
end
if ~(isscalar(A.NoiseBandHz) && isfinite(A.NoiseBandHz) && A.NoiseBandHz >= 0)
    add("artifacts", "NoiseBandHz", "error", "NoiseBandHz must be 0 (broadband) or a positive frequency.");
end
if ~(isscalar(A.NoiseSeed) && (isnan(A.NoiseSeed) || (A.NoiseSeed >= 0 && A.NoiseSeed == round(A.NoiseSeed))))
    add("artifacts", "NoiseSeed", "error", "NoiseSeed must be a non-negative integer, or NaN for a new draw each run.");
end
if A.Enabled
    if ~ismember(A.Method, ["rms" "mad" "microvolts" "commonmode"])
        add("artifacts", "Method", "error", "Unknown artifact method """ + A.Method + """.");
    end
    if ~(A.Threshold > 0)
        add("artifacts", "Threshold", "error", "Threshold must be positive.");
    elseif ismember(A.Method, ["microvolts" "commonmode"]) && A.Threshold < 50
        % A robust-SD multiplier (the rms / mad default, 9) read as microvolts
        % sits inside the noise and flags almost every sample.
        add("artifacts", "Threshold", "warning", sprintf(['The %s threshold is in microvolts; ' ...
            '%g uV is within the noise and flags almost every sample (the default is 1500).'], ...
            A.Method, A.Threshold));
    end
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
if ~ismember(S.Quality.unknown, ["pass" "fail"])
    add("sorting", "Quality", "error", "Quality.unknown must be ""pass"" or ""fail"".");
end
for f = ["isiViolationsRatioMax" "presenceRatioMin" "amplitudeCutoffMax" "snrMin" "driftPtpMax" "firingRateMin"]
    if S.Quality.(f) < 0
        add("sorting", "Quality", "error", "Quality." + f + " must be NaN (not applied) or at least 0.");
    end
end
if S.Enabled
    if S.PythonExe == ""
        add("sorting", "PythonExe", "error", "PythonExe is required to run Kilosort4.");
    elseif opts.CheckPaths && ~isfile(S.PythonExe)
        add("sorting", "PythonExe", "warning", "Python executable not found: " + S.PythonExe);
    end
    if ~ismember(S.Execution, ["background" "blocking"])
        add("sorting", "Execution", "error", "Execution must be ""background"" or ""blocking"".");
    end
    if ~(isfinite(S.MaxConcurrent) && S.MaxConcurrent >= 1 && S.MaxConcurrent == round(S.MaxConcurrent))
        add("sorting", "MaxConcurrent", "error", "MaxConcurrent (Kilosort4 runs at once) must be a whole number >= 1.");
    end
    if ~(S.KS4.nt > 0 && S.KS4.nt == round(S.KS4.nt) && mod(S.KS4.nt, 2) == 1)
        add("sorting", "KS4.nt", "error", "nt (spike template width) must be a positive odd integer.");
    end
    if ~(isfinite(S.KS4.shank_spacing) && S.KS4.shank_spacing >= 0)
        add("sorting", "KS4.shank_spacing", "error", "shank_spacing (extra distance between shanks for sorting) must be 0 um or more.");
    end
    [ks4, msg] = EphysPipelineConfig.ks4Settings(S);
    if msg ~= ""; add("sorting", "KS4ExtraJSON", "error", msg); end
    badDev = S.Devices(~EphysDataset.isTorchDevice(S.Devices));
    if ~isempty(badDev)
        add("sorting", "Devices", "error", "Not a torch device: " + strjoin(badDev, ", ") + ...
            " (use cuda:0, cuda:1, ... or cpu).");
    elseif S.Execution == "blocking" && numel(S.Devices) > 1
        add("sorting", "Devices", "warning", "Blocking runs go one at a time on the first device, " + S.Devices(1) + ".");
    elseif S.Execution == "background" && isfinite(S.MaxConcurrent) && S.MaxConcurrent >= 1 ...
            && numel(S.Devices) > S.MaxConcurrent
        add("sorting", "Devices", "warning", sprintf("%d devices but %d Kilosort4 run(s) at once: %s stay(s) idle.", ...
            numel(S.Devices), S.MaxConcurrent, strjoin(S.Devices(floor(S.MaxConcurrent)+1:end), ", ")));
    end
    if ~isempty(S.Devices) && msg == "" && isfield(ks4, 'torch_device')
        add("sorting", "Devices", "warning", "Devices overrides torch_device in the extra Kilosort4 settings.");
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
    if K.Filter && ~(K.Band(1) < K.Band(2) && K.Band(1) > 0)
        add("spikes", "Band", "error", "Band must be [lo hi] with 0 < lo < hi.");
    end
    if isfinite(K.Threshold) && ~(K.Threshold > 0)
        add("spikes", "Threshold", "error", "Threshold must be positive (or NaN for the method default).");
    end
    if ~(K.WindowMs(1) < K.WindowMs(2))
        add("spikes", "WindowMs", "error", "WindowMs must be [before after] with before < after.");
    end
    if ~ismember(K.ThresholdScope, ["chunk" "recording"])
        add("spikes", "ThresholdScope", "error", "ThresholdScope must be chunk or recording.");
    end
    if ~ismember(K.ArtifactMode, ["reject" "erase" "none"])
        add("spikes", "ArtifactMode", "error", "ArtifactMode must be reject, erase or none.");
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
    if E.IncludeDetected && ~K.Enabled
        add("export", "IncludeDetected", "warning", "Detected spikes are included only where a spikes file already exists.");
    end
    if any(E.Formats == "kcsd")
        if ~isempty(E.Signals) && ~any(upper(E.Signals) == "LFP")
            add("export", "Signals", "error", "The kCSD export writes the LFP, but Export.Signals leaves it out.");
        elseif G.Enabled && ~G.LFP
            add("export", "Formats", "warning", "The Signals step derives no LFP; the kCSD export needs an existing LFP extract.");
        end
    end
    if any(E.Formats == "nwb")
        N = E.NWB;
        py = N.PythonExe;
        if py == ""; py = obj.Sorting.PythonExe; end
        if py == ""
            add("export", "NWB.PythonExe", "error", ...
                "The NWB export runs Python (pynwb, nwbinspector): set Export.NWB.PythonExe or the Sorting step's PythonExe.");
        end
        if N.Sex ~= "" && ~ismember(N.Sex, ["F" "M" "U" "O"])
            add("export", "NWB.Sex", "error", "NWB.Sex is F, M, U (unknown) or O (other).");
        end
        if N.Age ~= "" && isempty(regexp(N.Age, '^P(\d+Y)?(\d+M)?(\d+W)?(\d+D)?(T(\d+H)?(\d+M)?(\d+(\.\d+)?S)?)?(/.*)?$', 'once'))
            add("export", "NWB.Age", "error", "NWB.Age is an ISO 8601 duration, e.g. P90D (90 days) or P12W.");
        end
        if N.TimeZone ~= ""
            try
                datetime('now', 'TimeZone', N.TimeZone);
            catch
                add("export", "NWB.TimeZone", "error", "Unknown time zone """ + N.TimeZone + """ (an IANA name, e.g. America/New_York).");
            end
        end
        if N.SessionStartTime ~= ""
            try
                datetime(N.SessionStartTime, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
            catch
                add("export", "NWB.SessionStartTime", "error", "NWB.SessionStartTime is ""yyyy-MM-dd HH:mm:ss"".");
            end
        end
        unset = ["Species" "Sex" "Age"];
        unset = unset(arrayfun(@(f) N.(f) == "", unset));
        if ~isempty(unset)
            add("export", "NWB", "warning", "NWB." + strjoin(unset, ", NWB.") + ...
                " not set: nwbinspector reports a subject without them (nothing is made up for them).");
        end
    end
    if any(E.Formats == "epochs")
        w = E.EpochWindow;
        if numel(w) ~= 2 || w(2) <= w(1)
            add("export", "EpochWindow", "error", ...
                "The epoch window must be [tPre tPost] with tPre < tPost; got [" + strjoin(string(w), " ") + "].");
        end
        if ~ismember(E.EpochSource, ["line" "behavior"])
            add("export", "EpochSource", "error", "Epoch events come from a digital line or the paired trials (line / behavior).");
        end
        % eventEpochs' choices, checked here so a bad value fails validation, not every dataset
        choices = struct('EpochOnsetRule', ["event" "sample"], 'EpochIncomplete', ["nan" "drop" "error"], ...
            'EpochNonFinite', ["keep" "drop" "error"], 'EpochArtifacts', ["drop" "keep"], ...
            'EpochSpikeTimeBase', ["onset" "window" "absolute"], 'EpochClass', ["double" "single" "asis"]);
        for f = string(fieldnames(choices)).'
            if isfield(E, f) && ~(isscalar(string(E.(f))) && ismember(string(E.(f)), choices.(f)))
                add("export", f, "error", sprintf("%s must be one of %s.", f, strjoin(choices.(f), ", ")));
            end
        end
        if E.EpochSource == "line" && ~E.IncludeEvents
            add("export", "IncludeEvents", "error", "Epochs around a digital line need the digital-input events.");
        end
        if E.EpochSource == "behavior" && ~(B.Enabled && B.PairTrials)
            add("export", "EpochSource", "warning", "Epochs around behavior trials need a paired session (the behavior step with PairTrials, reviewed on the Trials tab).");
        end
    end
end

% --- cross-step ------------------------------------------------------------------
needsSorted = E.Enabled && E.IncludeUnits;
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
