function test_EphysPipelineConfig()
%test_EphysPipelineConfig  Verification suite for the pipeline config class.
%   Covers defaults, normalization on set, exact JSON round trips (Inf, NaN,
%   [] nullables, one-element string lists, 1x2 bands), schema checks, the
%   Kilosort4 settings builder, the derived-signal options builder (every
%   error id and each ExcludeHandling mode), the detection option builders
%   and validate(). No recordings or toolboxes are needed.
%
%   Usage:  test_EphysPipelineConfig

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

root = fullfile(tempdir, sprintf('PipeCfg_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>

nPass = 0; nFail = 0;
    function check(cond, msg)
        if cond
            nPass = nPass + 1;
            fprintf('  PASS: %s\n', msg);
        else
            nFail = nFail + 1;
            fprintf(2, '  FAIL: %s\n', msg);
        end
    end
    function id = errorId(fcn)
        id = '';
        try
            fcn();
        catch ME
            id = ME.identifier;
        end
    end

fprintf('\n== 1. defaults and normalization ==\n');
cfg = EphysPipelineConfig();
check(cfg.Name == "Untitled" && all(isfield(cfg.toStruct(), cellstr(EphysPipelineConfig.Sections))), ...
    'a fresh config has every section');
check(isequal(EphysPipelineConfig.StepNames, ["probe" "behavior" "artifacts" "sorting" "signals" "spikes" "export"]), ...
    'step order');
check(isequal(cfg.Spikes.Band, [500 5000]) && isnan(cfg.Spikes.Threshold) && isinf(cfg.Spikes.MaxAmplitudeUV) ...
    && isempty(cfg.Sorting.KS4.dmin) && isinf(cfg.Sorting.KS4.tmax) && cfg.Sorting.KS4.nblocks == 0 ...
    && islogical(cfg.Sorting.KS4.templates_from_data) && isequal(cfg.Sorting.KS4.drift_smoothing, [0.5 0.5 0.5]), ...
    'typed defaults (bands, NaN/Inf autos, nullable [], KS4 typed per spec)');
cfg.Spikes = struct('Threshold', "4", 'Band', {{"300", "3000"}}, 'Source', 'sorted', 'Waveforms', "true");
check(cfg.Spikes.Threshold == 4 && isequal(cfg.Spikes.Band, [300 3000]) && cfg.Spikes.Source == "sorted" ...
    && islogical(cfg.Spikes.Waveforms) && cfg.Spikes.Waveforms && cfg.Spikes.Polarity == "negative", ...
    'assigning a partial section fills the rest and coerces types');
cfg.Project.Datasets = "mouse1/sess1";
check(isstring(cfg.Project.Datasets) && isequal(size(cfg.Project.Datasets), [1 1]), 'a one-element string list stays a string array');
cfg.Project.Datasets = {'a', 'b'};
check(isequal(cfg.Project.Datasets, ["a" "b"]), 'cellstr lists become string rows');
cfg.Export.Formats = [];
check(isstring(cfg.Export.Formats) && isempty(cfg.Export.Formats), 'an empty list stays an empty string list');
[s, unknown] = EphysPipelineConfig.normalizeSection("Probe", struct('Nope', 1, 'DefaultProbeFile', 'p.json'));
check(isequal(unknown, "Probe.Nope") && s.DefaultProbeFile == "p.json" && islogical(s.WriteDefaultToManifest), ...
    'unknown fields are reported and dropped');
check(strcmp(errorId(@() EphysPipelineConfig.normalizeSection("Spikes", struct('Threshold', 'abc'))), ...
    'EphysPipelineConfig:BadValue'), 'a non-numeric value for a numeric field errors');
check(strcmp(errorId(@() EphysPipelineConfig.defaults("Nope")), 'EphysPipelineConfig:BadSection'), 'unknown section errors');
c2 = EphysPipelineConfig.fromStruct(struct('name', "x", 'Spikes', struct('Enabled', true, 'Bogus', 1), 'Extra', 2));
check(c2.Name == "x" && c2.Spikes.Enabled && numel(c2.LoadWarnings) == 2, 'fromStruct collects load warnings');

fprintf('\n== 2. save / load round trip ==\n');
cfg = EphysPipelineConfig();
cfg.Name = "roundtrip";
cfg.Description = "with awkward values";
cfg.Project.Root = "C:\data";
cfg.Project.Selection = "list";
cfg.Project.Datasets = "only/one";
cfg.Sorting.Enabled = true;
cfg.Sorting.KS4.dmin = 25;
cfg.Sorting.KS4.tmax = 100;
cfg.Sorting.KS4.artifact_threshold = Inf;
cfg.Sorting.KS4.drift_smoothing = [1 2 3];
cfg.Sorting.KS4ExtraJSON = "{""foo"": 1}";
cfg.Spikes.Threshold = NaN;
cfg.Spikes.MaxAmplitudeUV = Inf;
cfg.Spikes.WindowMs = [-1 2];
cfg.Spikes.Groups = "good";
cfg.Export.Formats = "chronux";
cfg.Export.Signals = string.empty(1,0);
cfg.Behavior.SearchDirs = ["D:\beh" "E:\beh"];
f = fullfile(root, 'cfg.json');
cfg = cfg.save(f);
check(isfile(f) && cfg.File == string(f), 'save writes the file and records File');
txt = fileread(f);
check(contains(txt, '"schema": "ephys-pipeline-config"') && contains(txt, '"version": 1') ...
    && contains(txt, '"Threshold": "NaN"') && contains(txt, '"MaxAmplitudeUV": "Inf"'), ...
    'JSON carries schema / version and Inf / NaN as strings');
c3 = EphysPipelineConfig.load(f);
check(c3.isequalConfig(cfg) && isequaln(c3.toStruct(), cfg.toStruct()), 'load reproduces the config exactly (isequaln)');
check(isequal(c3.Project.Datasets, "only/one") && isequal(c3.Export.Formats, "chronux") ...
    && isequal(c3.Spikes.Groups, "good") && isequal(size(c3.Export.Signals), [1 0]) ...
    && isequal(c3.Behavior.SearchDirs, ["D:\beh" "E:\beh"]), 'one-element and empty string lists survive');
check(isequal(c3.Spikes.WindowMs, [-1 2]) && isequal(c3.Sorting.KS4.drift_smoothing, [1 2 3]) ...
    && c3.Sorting.KS4.dmin == 25 && isinf(c3.Sorting.KS4.artifact_threshold) && isempty(c3.Sorting.KS4.n_chan_bin), ...
    'rows, nullables and Inf survive');
check(c3.File == string(f) && isempty(c3.LoadWarnings), 'File is set and nothing was dropped');
bad = fullfile(root, 'bad.json');
writeJsonFile(bad, struct('schema', "something-else", 'version', 1));
check(strcmp(errorId(@() EphysPipelineConfig.load(bad)), 'EphysPipelineConfig:BadSchema'), 'wrong schema is refused');
writeJsonFile(bad, struct('schema', "ephys-pipeline-config", 'version', 2));
check(strcmp(errorId(@() EphysPipelineConfig.load(bad)), 'EphysPipelineConfig:BadSchema'), 'wrong version is refused');
writeJsonFile(bad, struct('schema', "ephys-pipeline-config", 'version', 1, 'Spikes', struct('Weird', 3)));
ws = warning('off', 'EphysPipelineConfig:LoadWarnings');
c4 = EphysPipelineConfig.load(bad);
warning(ws);
check(numel(c4.LoadWarnings) == 1 && contains(c4.LoadWarnings(1), "Weird"), 'unknown fields on load are reported');

fprintf('\n== 3. ks4Settings ==\n');
S = EphysPipelineConfig.defaults("Sorting");
[ks, msg] = EphysPipelineConfig.ks4Settings(S);
check(msg == "" && ~isfield(ks, 'tmax') && ~isfield(ks, 'artifact_threshold') && ~isfield(ks, 'n_chan_bin') ...
    && ~isfield(ks, 'dmin') && ~isfield(ks, 'nt0min'), 'Inf and [] autos are omitted (KS4 default)');
check(ks.nblocks == 0 && ks.tmin == 0 && islogical(ks.templates_from_data) && ks.templates_from_data ...
    && isequal(ks.drift_smoothing, [0.5 0.5 0.5]) && ks.batch_size == 120000, 'typed named fields');
S.KS4.dmin = 20; S.KS4.tmax = 60; S.KS4.nblocks = 2.4;
S.KS4ExtraJSON = "{""nblocks"": 5, ""custom"": [1, 2]}";
[ks, msg] = EphysPipelineConfig.ks4Settings(S);
check(msg == "" && ks.dmin == 20 && ks.tmax == 60 && ks.nblocks == 5 && isequal(ks.custom(:).', [1 2]), ...
    'set autos are included, ints rounded, extra JSON merged last and overriding');
S.KS4ExtraJSON = "{not json";
[~, msg] = EphysPipelineConfig.ks4Settings(S);
check(msg ~= "", 'bad extra JSON is reported');
check(EphysPipelineConfig.ks4ParamText('floatinf', Inf) == "Infinity" && EphysPipelineConfig.ks4ParamText('nullable', []) == "" ...
    && EphysPipelineConfig.ks4ParamText('vector', [1 2]) == "1, 2" && EphysPipelineConfig.ks4ParamText('int', 3) == "3", ...
    'ks4ParamText renders typed values');
[v1, ok1] = EphysPipelineConfig.ks4ParamFromText('floatinf', 'inf');
[v2, ok2] = EphysPipelineConfig.ks4ParamFromText('nullable', 'null');
[v3, ok3] = EphysPipelineConfig.ks4ParamFromText('vector', '1, 2 3');
[~, ok4] = EphysPipelineConfig.ks4ParamFromText('float', 'abc');
check(isinf(v1) && ok1 && isempty(v2) && ok2 && isequal(v3, [1 2 3]) && ok3 && ~ok4, 'ks4ParamFromText parses edit-field text');

fprintf('\n== 4. signalOptions ==\n');
G = EphysPipelineConfig.defaults("Signals");
so = EphysPipelineConfig.signalOptions(G);
check(isequal(so.dataTypeOut, "LFP") && so.LFP_Fs == 1000 && ~isfield(so, 'LFP_bpLoHi') ...
    && ~isfield(so, 'keepAmpChannels') && so.labelField == "custom_channel_name", 'defaults -> LFP only, no filters');
G2 = G; G2.MUA = true; G2.SPIKE = true; G2.SPIKE_KeepOriginal = false; G2.LFP_HighpassOn = true; G2.LFP_LowpassOn = true;
G2.LFP_NotchOn = true; G2.LFP_NotchHz = "60, 120"; G2.KeepChannels = "1-4, 8"; G2.ChannelRemap = "4-1";
so = EphysPipelineConfig.signalOptions(G2);
check(isequal(so.dataTypeOut, ["LFP" "MUA" "SPIKE"]) && isequal(so.LFP_bpLoHi, [1 300]) && isequal(so.LFP_NotchHz, [60 120]) ...
    && so.SPIKE_Fs == 20000 && isequal(so.keepAmpChannels, [1 2 3 4 8]) && isequal(so.channelRemap, [4 3 2 1]), ...
    'all signals with filters, notch, keep list and descending remap');
G4 = G; G4.LFP = false; G4.AUX = true;
so = EphysPipelineConfig.signalOptions(G4);
check(isequal(so.dataTypeOut, "AUX") && ~isfield(so, 'LFP_Fs'), 'AUX alone -> dataTypeOut "AUX"');
errs = struct();
G3 = G; G3.LFP = false;                              errs.NoSignals       = errorId(@() EphysPipelineConfig.signalOptions(G3));
G3 = G; G3.BadMode = "manual";                       errs.BadList         = errorId(@() EphysPipelineConfig.signalOptions(G3));
G3 = G; G3.BadMode = "auto"; G3.LFP = false; G3.MUA = true; errs.AutoBadNeedsLFP = errorId(@() EphysPipelineConfig.signalOptions(G3));
G3 = G; G3.BadMode = "auto"; G3.BadThreshold = 0;    errs.BadThreshold    = errorId(@() EphysPipelineConfig.signalOptions(G3));
G3 = G; G3.LFP_LowpassOn = true; G3.LFP_LowpassHz = 600; errs.LFPNyquist  = errorId(@() EphysPipelineConfig.signalOptions(G3));
G3 = G; G3.LFP_NotchOn = true; G3.LFP_NotchHz = "499"; errs.LFPNotch      = errorId(@() EphysPipelineConfig.signalOptions(G3));
G3 = G; G3.MUA = true; G3.MUA_bpLoHi = [5000 300];   errs.Band            = errorId(@() EphysPipelineConfig.signalOptions(G3));
G3 = G; G3.KeepChannels = "1, x";                    errs.IndexList       = errorId(@() EphysPipelineConfig.signalOptions(G3));
G3 = G; G3.LFP_NotchOn = true; G3.LFP_NotchHz = "60, -5"; errs.FreqList   = errorId(@() EphysPipelineConfig.signalOptions(G3));
G3 = G; G3.Suffix = "bad:name";                      errs.BadSuffix       = errorId(@() EphysPipelineConfig.signalOptions(G3));
allOk = true;
for fnm = string(fieldnames(errs)).'
    if ~strcmp(errs.(fnm), "EphysPipelineConfig:Signals" + fnm)
        allOk = false;
        fprintf(2, '    %s -> %s\n', fnm, errs.(fnm));
    end
end
check(allOk, 'every signalOptions error id is raised');
G4 = G; G4.ExcludeHandling = "drop";
so = EphysPipelineConfig.signalOptions(G4, ExcludeChannels=[2 3], NumChannels=8);
check(isequal(so.keepAmpChannels, [1 4 5 6 7 8]), 'ExcludeHandling="drop" removes manifest exclusions');
G4.KeepChannels = "1-4";
so = EphysPipelineConfig.signalOptions(G4, ExcludeChannels=[2 3]);
check(isequal(so.keepAmpChannels, [1 4]), '"drop" intersects with an explicit keep list');
check(strcmp(errorId(@() EphysPipelineConfig.signalOptions(G4, ExcludeChannels=[1 2 3 4])), ...
    'EphysPipelineConfig:SignalsExcludeHandling'), 'dropping everything is an error');
G5 = G; G5.ExcludeHandling = "interpolate";
so = EphysPipelineConfig.signalOptions(G5, ExcludeChannels=[2 3]);
check(isequal(so.badChannels, [2 3]), 'ExcludeHandling="interpolate" makes them bad channels');
G5.BadMode = "manual"; G5.BadList = "5";
so = EphysPipelineConfig.signalOptions(G5, ExcludeChannels=[2 3]);
check(isequal(so.badChannels, [2 3 5]), '"interpolate" unions with a manual bad list');
G5.BadMode = "auto";
check(strcmp(errorId(@() EphysPipelineConfig.signalOptions(G5, ExcludeChannels=2)), ...
    'EphysPipelineConfig:SignalsExcludeHandling'), '"interpolate" + auto bad detection is refused');
so = EphysPipelineConfig.signalOptions(G5, ExcludeChannels=[]);
check(so.badChannels == -3, 'auto bad-channel threshold is encoded as a negative number');

fprintf('\n== 5. detectOptions / spikeChannels / artifactConfig / exportOptions ==\n');
K = EphysPipelineConfig.defaults("Spikes");
d = EphysPipelineConfig.detectOptions(K);
check(~isfield(d, 'Threshold') && ~isfield(d, 'MaxChunkSamples') && ~isfield(d, 'EdgePadMs') ...
    && d.Filter && isequal(d.Band, [500 5000]) && d.ThresholdMethod == "mad" && ~d.Waveforms, ...
    'NaN autos are omitted from DetectOptions');
K.Threshold = 5; K.MaxChunkSamples = 2000;
d = EphysPipelineConfig.detectOptions(K);
check(d.Threshold == 5 && d.MaxChunkSamples == 2000, 'set values are forwarded');
dsFake = struct('NumChannels', 6, 'ExcludeChannels', [2 5]);
K.Channels = "excludeManifest";
check(isequal(EphysPipelineConfig.spikeChannels(K, dsFake), [1 3 4 6]), 'excludeManifest channel selection');
K.Channels = "list"; K.ChannelList = "6-4";
check(isequal(EphysPipelineConfig.spikeChannels(K, dsFake), [6 5 4]), 'list channel selection');
K.Channels = "all";
check(isempty(EphysPipelineConfig.spikeChannels(K, dsFake)), 'all -> []');
A = EphysPipelineConfig.defaults("Artifacts"); A.Enabled = true; A.Filter = true; A.Threshold = 7;
ac = EphysPipelineConfig.artifactConfig(A);
check(isequal(sort(fieldnames(ac)), sort(fieldnames(EphysDataset.defaultArtifactConfig()))) ...
    && ac.Enabled && ac.Filter && ac.Threshold == 7 && ac.FilterCutoff == 300, 'artifactConfig maps onto EphysDataset.ArtifactConfig');
E = EphysPipelineConfig.defaults("Export"); E.IncludeUnits = false; E.Signals = "LFP";
eo = EphysPipelineConfig.exportOptions(E, "fieldtrip");
check(islogical(eo.Units) && ~eo.Units && isequal(eo.Signals, "LFP") && ~isfield(eo, 'Behavior') && eo.Validate, ...
    'exportOptions for the FieldTrip exporter');
eo = EphysPipelineConfig.exportOptions(E, "chronux");
check(~isfield(eo, 'Validate') && eo.Events && ~eo.Detected, 'exportOptions for the Chronux exporter');

fprintf('\n== 6. validate ==\n');
cfg = EphysPipelineConfig();
iss = cfg.validate();
check(any(iss.Step == "project" & iss.Field == "Root" & iss.Severity == "error"), 'an empty root is an error');
cfg.Project.Root = root;
cfg.Spikes.Band = [5000 500];                         % invalid but the step is off
iss = cfg.validate();
check(~any(iss.Severity == "error") && any(iss.Field == "OutputRoot" & iss.Severity == "warning"), ...
    'disabled steps are not checked; missing output root warns');
cfg.Spikes.Enabled = true;
iss = cfg.validate();
check(any(iss.Step == "spikes" & iss.Field == "Band" & iss.Severity == "error"), 'enabled step settings are checked');
cfg.Spikes.Band = [500 5000];
cfg.Sorting.Enabled = true;
iss = cfg.validate();
check(any(iss.Step == "sorting" & iss.Field == "PythonExe" & iss.Severity == "error"), 'sorting needs PythonExe');
cfg.Sorting.PythonExe = "C:\nope\python.exe";
cfg.Spikes.Source = "sorted";
iss = cfg.validate();
check(any(iss.Step == "sorting" & iss.Field == "Execution" & iss.Severity == "error") ...
    && any(iss.Field == "PythonExe" & iss.Severity == "warning"), ...
    'background sorting feeding the sorted-unit consumers is an error; missing python warns');
cfg.Sorting.Execution = "blocking";
iss = cfg.validate();
check(~any(iss.Field == "Execution"), 'blocking sorting resolves the cross-step rule');
cfg.Export.Enabled = true;
iss = cfg.validate();
check(any(iss.Step == "export" & iss.Field == "Formats" & iss.Severity == "error") ...
    && any(iss.Step == "export" & iss.Field == "Signals" & iss.Severity == "warning"), ...
    'export needs a format; warns when Signals is off');
cfg.Export.Formats = ["chronux" "bogus"];
iss = cfg.validate();
check(any(iss.Field == "Formats" & contains(iss.Message, "bogus")), 'unknown export format is reported');
check(isequal(cfg.enabledSteps(), ["probe" "sorting" "spikes" "export"]) && cfg.stepEnabled("probe") && ~cfg.stepEnabled("signals"), ...
    'enabledSteps / stepEnabled');
check(strcmp(errorId(@() cfg.stepSection("nope")), 'EphysPipelineConfig:BadStep'), 'unknown step errors');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysPipelineConfig:Failures', '%d checks failed.', nFail);
end
end
