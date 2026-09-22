function S = makeSyntheticProject(root, opts)
%makeSyntheticProject  Write a synthetic project (recordings + Epsych2 sessions) for testing the pipeline.
%   S = makeSyntheticProject(root) creates, under ROOT, a project the app and
%   the pipeline can run end to end without any real data or Python:
%
%     <root>/
%       synthetic_pipeline.json          a pipeline config for this project
%       <Subject>_probe.json             a probe map matching the channel count
%       README.txt                       what is in here and what to expect
%       <Subject>/
%         <Subject>_<yymmdd>_<HHMMSS>/   one recording per scenario, on
%                                        consecutive days (makeSyntheticRecording);
%                                        Open Ephys formats: the GUI's session
%                                        folder <Subject>_<yyyy-MM-dd>_<HH-mm-ss>
%           *.rhd                        Intan RHX-style files (or the other layouts;
%                                        Open Ephys: Record Node 101/)
%           <Subject>_<yymmdd>T<HHMMSS>.mat   its Epsych2 session
%           <Name>_manifest.json         probe + session associated
%           kilosort4/                   ground-truth units as Kilosort4 / phy output
%
%   The recordings hold spiking units, LFP, artifacts, six digital lines
%   (InTrial is the trial line) and accelerometer inputs; each Epsych2
%   session has one trial per InTrial interval. The four scenarios differ in
%   how the recording covers the session, so the trial pairing has one case
%   of each kind to review: "clean" (counts agree), "late-start" (the
%   recording started during trial 3), "early-stop" (it stopped during trial
%   N-2) and "spurious" (an extra InTrial pulse before the first trial). See
%   makeSyntheticRecording for the details and S.datasets(k).expectedCuts
%   for the cuts that resolve each mismatch.
%
%   The config enables the behavior (matching + pairing), artifacts, signals
%   (LFP, MUA, AUX), spikes (detected + sorted) and export (Chronux +
%   FieldTrip) steps, with outputs next to each recording; sorting is off
%   (it needs Python). Open it in the app (File > Open config, or File >
%   Create synthetic test project..., which does all of this) or run it:
%
%     S = makeSyntheticProject("D:\scratch\synthetic_ephys");
%     pipe = EphysPipeline(EphysPipelineConfig.load(S.configFile));
%     disp(pipe.plan()); pipe.run();
%
%   Options
%     Preset         "standard" (default: 30 kHz, 16 channels, 12 trials, 30 s
%                    files, ~250 MB for the four datasets) | "small" (20 kHz,
%                    8 channels, 6 trials, 10 s files, ~40 MB). Fs,
%                    NumChannels, NumTrials and FileSeconds override the preset
%     Subject        "SYNTH-01"
%     Scenarios      ["clean" "late-start" "early-stop" "spurious"] (any subset / order)
%     Format         "traditional" (default) | "one-file-per-signal" | "binary" |
%                    "openephys-binary" | "openephys-legacy" | "openephys-nwb". For
%                    the Open Ephys formats the config sets Project.NamePattern
%                    to OpenEphysReader.DefaultNamePattern and names the TTL
%                    lines (Signals.LineNames: TTL4=InTrial, ...)
%     Parts          1: Open Ephys formats only, recordings per session (see
%                    makeSyntheticRecording)
%     Seed           1 (dataset k uses Seed + k - 1)
%     SortedOutput   true: write the ground-truth sorted output
%     Artifacts      true
%     InvertedLines  lines written active-low; listed in Signals.InvertedLines
%     Overwrite      false: error when ROOT is not empty. true replaces a
%                    project written by this function (and nothing else)
%     ProgressFcn    ProgressFcn(fraction, message)
%
%   S fields: root, subject, preset, format, configFile, probeFile,
%   readmeFile, datasets (the makeSyntheticRecording truth, one per
%   scenario), bytes, options.
%
%   Error identifiers: makeSyntheticProject:Exists, makeSyntheticProject:NotSynthetic.
%
%   See also makeSyntheticRecording, makeSyntheticProbe, EphysPipeline,
%   EphysPreprocessingApp.

arguments
    root (1,1) string
    opts.Preset (1,1) string {mustBeMember(opts.Preset, ["standard" "small"])} = "standard"
    opts.Subject (1,1) string = "SYNTH-01"
    opts.Scenarios (1,:) string {mustBeMember(opts.Scenarios, ["clean" "late-start" "early-stop" "spurious"])} = ["clean" "late-start" "early-stop" "spurious"]
    opts.Format (1,1) string {mustBeMember(opts.Format, ["traditional" "one-file-per-signal" "binary" ...
        "openephys-binary" "openephys-legacy" "openephys-nwb"])} = "traditional"
    opts.Parts (1,1) double {mustBeInteger, mustBePositive} = 1
    opts.Fs (1,1) double = NaN
    opts.NumChannels (1,1) double = NaN
    opts.NumTrials (1,1) double = NaN
    opts.FileSeconds (1,1) double = NaN
    opts.Seed (1,1) double = 1
    opts.SortedOutput (1,1) logical = true
    opts.Artifacts (1,1) logical = true
    opts.InvertedLines (1,:) string = string.empty(1,0)
    opts.Overwrite (1,1) logical = false
    opts.ProgressFcn = []
end

configName = 'synthetic_pipeline.json';
isOE = startsWith(opts.Format, "openephys-");
switch opts.Preset
    case "standard", def = struct('Fs', 30000, 'NumChannels', 16, 'NumTrials', 12, 'FileSeconds', 30);
    case "small",    def = struct('Fs', 20000, 'NumChannels', 8,  'NumTrials', 6,  'FileSeconds', 10);
end
for f = ["Fs" "NumChannels" "NumTrials" "FileSeconds"]
    if isnan(opts.(f)); opts.(f) = def.(f); end
end
if isempty(opts.Scenarios)
    error('makeSyntheticProject:NoScenarios', 'Scenarios must name at least one scenario.');
end

    function tick(frac, msg)
        if ~isempty(opts.ProgressFcn); opts.ProgressFcn(frac, string(msg)); end
    end

% --- the root folder ---------------------------------------------------------------
root = string(root);
if isfolder(root) && numel(dir(root)) > 2
    if ~opts.Overwrite
        error('makeSyntheticProject:Exists', ...
            '%s is not empty. Pass Overwrite=true to replace a synthetic project written before.', root);
    end
    if ~isfile(fullfile(root, configName))
        error('makeSyntheticProject:NotSynthetic', ...
            '%s was not written by makeSyntheticProject (no %s); refusing to delete it.', root, configName);
    end
    [ok, msg] = rmdir(root, 's');
    if ~ok
        error('makeSyntheticProject:Overwrite', 'Could not remove %s: %s', root, msg);
    end
end
if ~isfolder(root); mkdir(root); end

% --- probe, datasets ------------------------------------------------------------------
probeFile = fullfile(root, opts.Subject + "_probe.json");
probe = makeSyntheticProbe(opts.NumChannels, File=probeFile);
n = numel(opts.Scenarios);
base = dateshift(datetime('now') - minutes(2), 'start', 'second');
datasets = [];
for k = 1:n
    acq = base - days(n - k);                       % one recording per day, the last one today
    acq.Format = 'yyMMdd_HHmmss';
    if isOE; acq.Format = 'yyyy-MM-dd_HH-mm-ss'; end  % the Open Ephys GUI's session folder
    folder = fullfile(root, opts.Subject, opts.Subject + "_" + string(acq));
    parts = 1;
    if isOE; parts = opts.Parts; end
    T = makeSyntheticRecording(folder, Subject=opts.Subject, Scenario=opts.Scenarios(k), ...
        Format=opts.Format, Fs=opts.Fs, NumChannels=opts.NumChannels, NumTrials=opts.NumTrials, ...
        FileSeconds=opts.FileSeconds, AcqTime=acq, Seed=opts.Seed + k - 1, Probe=probe, ...
        ProbeFile=probeFile, SortedOutput=opts.SortedOutput, Artifacts=opts.Artifacts, ...
        InvertedLines=opts.InvertedLines, WriteManifest=true, ...
        Parts=parts, ProgressFcn=@(f, m) tick((k - 1 + f) / (n + 0.5), m));
    if isempty(datasets); datasets = T; else; datasets(end+1) = T; end %#ok<AGROW>
end

% --- the pipeline config -----------------------------------------------------------------
tick(n / (n + 0.5), "Writing the pipeline config");
configFile = fullfile(root, configName);
cfg = EphysPipelineConfig();
cfg.Name = "Synthetic test project";
cfg.Description = sprintf("%d synthetic %s recording(s) with Epsych2 sessions (%s); written by makeSyntheticProject on %s.", ...
    n, opts.Format, strjoin(opts.Scenarios, ", "), string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')));
cfg.Project.Root = root;
cfg.Project.OutputRoot = "";                         % outputs next to each recording, as in the lab
if isOE
    cfg.Project.NamePattern = OpenEphysReader.DefaultNamePattern;
    cfg.Signals.LineNames = datasets(1).lineNames;   % TTL1=Trough, ..., TTL4=InTrial, ...
end
cfg.Probe.DefaultProbeFile = probeFile;
cfg.Probe.WriteDefaultToManifest = true;
cfg.Behavior.Enabled = true;
cfg.Behavior.SearchDirs = root;
cfg.Behavior.Match = "prefix-then-time";
cfg.Behavior.MaxStartOffsetMin = 10;
cfg.Behavior.WriteFile = true;
cfg.Behavior.PairTrials = true;
cfg.Behavior.TrialLine = "InTrial";
cfg.Artifacts.Enabled = opts.Artifacts;
cfg.Signals.Enabled = true;
cfg.Signals.LFP = true;
cfg.Signals.MUA = true;
cfg.Signals.SPIKE = false;
cfg.Signals.AUX = opts.Format ~= "binary";
cfg.Signals.LFP_Fs = 1000;
cfg.Signals.InvertedLines = opts.InvertedLines;
cfg.Spikes.Enabled = true;
if opts.SortedOutput; cfg.Spikes.Source = "both"; else; cfg.Spikes.Source = "detect"; end
cfg.Spikes.Waveforms = true;
cfg.Export.Enabled = true;
cfg.Export.Formats = ["chronux" "fieldtrip"];
cfg.Export.IncludeUnits = opts.SortedOutput;
cfg.Export.IncludeDetected = true;
cfg.Export.IncludeEvents = true;
cfg = cfg.save(configFile);
issues = cfg.validate();
bad = issues(issues.Severity == "error", :);
if ~isempty(bad)
    warning('makeSyntheticProject:ConfigIssues', 'The generated config has validation errors: %s', ...
        strjoin(bad.Field + ": " + bad.Message, "; "));
end

% --- README ----------------------------------------------------------------------------------
readmeFile = fullfile(root, 'README.txt');
writeReadme(readmeFile, root, configFile, probeFile, datasets, opts);

% --- verify: the project scans back --------------------------------------------------------------
P = EphysProject(root, ReaderOptions=cfg.Acquisition);
if P.NumDatasets ~= n
    error('makeSyntheticProject:Verify', 'Expected %d recording folder(s) under %s but EphysProject found %d.', ...
        n, root, P.NumDatasets);
end
tick(1, "Done");

S = struct();
S.root       = root;
S.subject    = opts.Subject;
S.preset     = opts.Preset;
S.format     = opts.Format;
S.configFile = string(configFile);
S.probeFile  = string(probeFile);
S.readmeFile = string(readmeFile);
S.datasets   = datasets;
S.bytes      = sum([datasets.bytes]);
S.options    = rmfield(opts, 'ProgressFcn');
end


%% ---------------------------------------------------------------------------
function writeReadme(file, root, configFile, probeFile, D, opts)
fid = fopen(file, 'w');
if fid < 0; return; end
c = onCleanup(@() fclose(fid));
w = @(varargin) fprintf(fid, [varargin{1} '\n'], varargin{2:end});
w('Synthetic ephys test project');
w('============================');
w('');
w('Written by makeSyntheticProject on %s. Everything in this folder is synthetic:', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')));
w('no animal, no real recording. It exists to exercise the preprocessing pipeline and');
w('the app (EphysPreprocessingApp) end to end without real data or Python.');
w('');
w('Layout');
w('  %s   pipeline config: File > Open config in the app, or', configFile);
w('      pipe = EphysPipeline(EphysPipelineConfig.load("%s")); pipe.run();', configFile);
w('  %s   probe map (%d channels)', probeFile, opts.NumChannels);
w('  %s/<recording>/     one folder per dataset (below)', fullfile(root, opts.Subject));
w('');
if startsWith(opts.Format, "openephys-")
    w('Every recording: an Open Ephys GUI session (%s format, Record Node 101), %g Hz, %d headstage', erase(opts.Format, "openephys-"), opts.Fs, opts.NumChannels);
    w('channels (CH1..), 3 AUX (accelerometer) inputs, TTL lines TTL1..TTL6 named by the config''s');
    w('Signals.LineNames: TTL1=Trough, TTL2=Platform, TTL3=Stim, TTL4=InTrial (the trial line),');
    w('TTL5=RespWindow, TTL6=Commutator (never active, so never seen). %d recording(s) per session.', opts.Parts);
    w('Amplifier data holds LFP');
else
    w('Every recording: %s layout, %g Hz, %d amplifier channels (A-000..), 3 accelerometer inputs', opts.Format, opts.Fs, opts.NumChannels);
    w('(accelX/Y/Z, Intan layouts only), 6 digital lines in RHX order: Trough, Platform, Stim,');
    w('InTrial (the trial line), RespWindow, Commutator (never active). Amplifier data holds LFP');
end
w('rhythms, noise, 60 Hz, a stimulus-evoked potential, %d spiking units and%s two large', numel(D(1).units), ternary(opts.Artifacts, '', ' (Artifacts off) no'));
w('artifacts (one saturates the ADC). The Epsych2 session (<subject>_<yymmdd>T<HHMMSS>.mat,');
w('variables Data + Info) sits in the recording folder and starts 65 s before the recording.');
if opts.SortedOutput
    w('kilosort4/ holds the ground-truth units as Kilosort4 / phy output, so the');
    w('Spikes (sorted), Export (units) and Review steps work without running Python.');
end
if ~isempty(opts.InvertedLines)
    w('Lines written active-low (on = low): %s. The config lists them in Signals.InvertedLines.', strjoin(opts.InvertedLines, ', '));
end
w('');
w('Datasets (Epsych2 trials vs InTrial intervals in the recording)');
for k = 1:numel(D)
    T = D(k);
    w('');
    w('  %s   scenario "%s"', T.name, T.scenario);
    w('    %d trials in the session, %d InTrial intervals in the recording (%.0f s, %d file(s))', T.nTrials, T.nIntervals, T.duration, numel(T.files));
    switch T.scenario
        case "clean"
            w('    Every trial pairs with a whole interval; nothing to cut. Approve as is.');
        case "late-start"
            w('    The recording started 1.2 s into trial 3: trials 1-2 have no interval and interval 1');
            w('    is partial (it begins at sample 1). On the Trials tab cut %d trials and %d interval', T.expectedCuts.trials(1), T.expectedCuts.intervals(1));
            w('    from the START (cutting 2 trials only pairs trial 3 with the partial interval).');
        case "early-stop"
            w('    The recording stopped in the middle of trial %d: the last interval is partial (it ends', T.nTrials - 2);
            w('    at the last sample) and trials %d-%d have none. Cut %d trials and %d interval from the END.', T.nTrials - 1, T.nTrials, T.expectedCuts.trials(2), T.expectedCuts.intervals(2));
        case "spurious"
            w('    A 40 ms InTrial pulse before the first trial is not a trial: cut %d interval from the START.', T.expectedCuts.intervals(1));
    end
    w('    Units: %s', strjoin(arrayfun(@(u) sprintf("%d@ch%d %.0fuV %s %s", u.id, u.peakChannel, u.amplitudeUV, u.label, u.modulation), T.units), ", "));
    if ~isempty(T.artifacts)
        w('    Artifacts (s): %s', strjoin(compose("%.2f-%.2f", T.artifacts), ", "));
    end
    w('    Session: %s', T.behaviorFile);
end
w('');
w('Suggested walk-through in the app: File > Open config (this folder''s synthetic_pipeline.json),');
w('Scan; Trials tab: Load each dataset, resolve the mismatches with the cut spinners, Approve;');
w('Run tab: Plan, then Run (behavior, artifacts, signals, spikes, export). Then open the outputs');
w('(<recording>/<name>_behavior.mat, _extract_*.mat, _spikes.mat, _chronux.mat, _fieldtrip.mat)');
w('or the Review tab. Delete this folder when you are done; regenerate it with');
w('makeSyntheticProject or File > Create synthetic test project... in the app.');
end


function s = ternary(tf, a, b)
if tf; s = a; else; s = b; end
end
