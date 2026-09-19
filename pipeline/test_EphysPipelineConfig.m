function test_EphysPipelineConfig()
%test_EphysPipelineConfig  Verification suite for the pipeline config class.
%   Covers defaults, normalization on set, exact JSON round trips (Inf, NaN,
%   [] nullables, one-element string lists, 1x2 bands), schema checks, the
%   Kilosort4 settings builder, probe-layout Kilosort4 defaults on synthetic
%   layouts, probe parameter files (write, load, refusals, the shipped
%   files), the derived-signal options builder (every
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
check(any(EphysPipelineConfig.Sections == "Parallel") && ~cfg.Parallel.Enabled && isnan(cfg.Parallel.MaxWorkers) ...
    && ~isfield(cfg.Spikes, 'UseParallel'), 'the Parallel section exists with its defaults; Spikes has no UseParallel');
cfg.Parallel = struct('MaxWorkers', "4");
check(cfg.Parallel.MaxWorkers == 4 && islogical(cfg.Parallel.Enabled) && ~cfg.Parallel.Enabled, ...
    'a partial Parallel section is coerced and completed');
c5 = EphysPipelineConfig.fromStruct(struct('Spikes', struct('UseParallel', true)));
check(any(contains(c5.LoadWarnings, "Spikes.UseParallel")), 'Spikes.UseParallel from an older file is dropped with a warning');

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
cfg.Parallel.Enabled = true; cfg.Parallel.MaxWorkers = NaN;
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
check(c3.Parallel.Enabled && isnan(c3.Parallel.MaxWorkers) && contains(txt, '"MaxWorkers": "NaN"'), ...
    'the Parallel section round-trips (NaN MaxWorkers as a string)');
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

fprintf('\n== 3b. ks4ProbeDefaults ==\n');
S0 = EphysPipelineConfig.defaults("Sorting");
% 4 shanks x 16 sites in two staggered columns 17.32 um apart, rows 10 um apart
[xs, ys, kc] = deal([]);
for s = 0:3
    xs = [xs; 150*s + repmat([-8.66; 8.66], 8, 1)]; %#ok<AGROW>
    ys = [ys; (0:10:150).']; %#ok<AGROW>
    kc = [kc; repmat(s, 16, 1)]; %#ok<AGROW>
end
poly = struct('chanMap', (0:63).', 'xc', xs, 'yc', ys, 'kcoords', kc);
pf = fullfile(root, 'poly2.json');
writeJsonFile(pf, poly);
[V1, r1] = EphysPipelineConfig.ks4ProbeDefaults(pf);
G = r1.Geometry;
check(r1.Probe == string(pf) && G.NumSites == 64 && G.NumShanks == 4 && G.RowPitchUm == 10 ...
    && G.LateralPitchUm == 17.32 && G.NearestSiteUm == 20 && startsWith(r1.Summary, "64 sites on 4 shanks"), ...
    'geometry of a 4-shank staggered probe read from its file');
check(isequal(string(fieldnames(V1)).', EphysPipelineConfig.KS4ProbeParams) ...
    && isequal(string(fieldnames(r1.Reasons)).', EphysPipelineConfig.KS4ProbeParams) && all(structfun(@(t) t ~= "", r1.Reasons)), ...
    'one value and one reason per probe-dependent parameter');
check(V1.nblocks == 0 && V1.dmin == 10 && V1.dminx == 17.32 && V1.nearest_chans == 10 ...
    && V1.nearest_templates == 58 && V1.min_template_size == 15 && V1.x_centers == 4, ...
    '64 sites on 4 shanks: no drift correction, row / column spacing, one x center per shank');
check(isequaln(EphysPipelineConfig.ks4ProbeDefaults(poly), V1), 'a decoded probe struct gives the same values');
[V4, r4] = EphysPipelineConfig.ks4ProbeDefaults(poly, ExcludeChannels=[1 2 17 18 33 34 49 50]);
check(r4.Geometry.NumSites == 56 && r4.Geometry.NumExcluded == 8 && V4.nearest_templates == 56 && isempty(r4.Notes), ...
    'excluded channels (chanMap + 1) are dropped before counting sites');
site = (0:383).';
xp = [43 11 59 27];
[V5, r5] = EphysPipelineConfig.ks4ProbeDefaults(struct('xc', xp(mod(site, 4) + 1).', 'yc', 20 * floor(site / 2)));
check(V5.nblocks == 5 && V5.dmin == 20 && V5.dminx == 32 && V5.x_centers == 1 ...
    && V5.nearest_templates == 58 && r5.Geometry.NumShanks == 1, ...
    'a Neuropixels-like shank: non-rigid drift correction, dminx from same-row pairs (32 um)');
[xs, ys, kc] = deal([]);
for s = 0:3
    xs = [xs; 250*s + repmat([0; 32], 16, 1)]; %#ok<AGROW>
    ys = [ys; kron(15*(0:15).', [1; 1])]; %#ok<AGROW>
    kc = [kc; repmat(s, 32, 1)]; %#ok<AGROW>
end
V6 = EphysPipelineConfig.ks4ProbeDefaults(struct('xc', xs, 'yc', ys, 'kcoords', kc));
check(V6.nblocks == 1 && V6.dmin == 15 && V6.dminx == 32 && V6.x_centers == 4, ...
    'a dense 128-site 4-shank probe: rigid drift correction');
[V7, r7] = EphysPipelineConfig.ks4ProbeDefaults(struct('xc', zeros(8, 1), 'yc', 100 * (0:7).'));
check(V7.dmin == 100 && V7.dminx == 32 && V7.min_template_size == 50 && V7.nearest_chans == 8 ...
    && V7.nearest_templates == 8 && V7.x_centers == 1 && isnan(r7.Geometry.LateralPitchUm), ...
    'a sparse single column: wider templates, neighbour counts capped at the site count, dminx left at the default');
[gx, gy] = meshgrid(0:200:1800, 0:200:1800);
[V8, r8] = EphysPipelineConfig.ks4ProbeDefaults(struct('xc', gx(:), 'yc', gy(:)));
check(V8.x_centers == 9 && V8.nblocks == 0 && V8.dminx == 200 && isempty(r8.Notes), ...
    'a 2-D grid: one x center per 200 um of width, sparse rows skip drift correction');
[~, r9] = EphysPipelineConfig.ks4ProbeDefaults(rmfield(poly, 'kcoords'));
check(r9.Geometry.NumShanks == 1 && r9.Geometry.LateralPitchUm == 17.32 && isscalar(r9.Notes) && contains(r9.Notes, "kcoords"), ...
    'shanks without kcoords: rows aligned across shanks are not pairs, and a note asks for kcoords');
check(strcmp(errorId(@() EphysPipelineConfig.ks4ProbeDefaults(struct('xc', 1:3, 'yc', 1:2))), 'EphysPipelineConfig:BadProbe') ...
    && strcmp(errorId(@() EphysPipelineConfig.ks4ProbeDefaults(poly, ExcludeChannels=1:64)), 'EphysPipelineConfig:ProbeEmpty'), ...
    'mismatched coordinates and an all-excluded probe are refused');

fprintf('\n== 3c. probe parameter files (writeKS4Params, ks4ForProbe) ==\n');
paramsFile = EphysPipelineConfig.ks4ParamsFile(pf);
check(paramsFile == fullfile(string(root), "poly2.ks4.json"), 'a probe map''s parameter file is <name>.ks4.json next to it');
check(strcmp(errorId(@() EphysPipelineConfig.ks4ForProbe(S0, pf)), 'EphysPipelineConfig:NoProbeParams'), ...
    'loading for a probe without a parameter file errors');
written = EphysPipelineConfig.writeKS4Params(pf, V1, Description=r1.Summary, Reasons=r1.Reasons);
P = readJsonFile(paramsFile);
check(written == paramsFile && P.schema == "ephys-ks4-params/1" && P.probe == "poly2.json" ...
    && isequal(string(fieldnames(P.KS4)).', EphysPipelineConfig.KS4ProbeParams) && P.KS4.dminx == 17.32 ...
    && string(P.description) == r1.Summary && string(P.reasons.x_centers) == r1.Reasons.x_centers, ...
    'writeKS4Params writes the schema, the probe name, the description, the values and the reasons');
check(strcmp(errorId(@() EphysPipelineConfig.writeKS4Params(pf, V1)), 'EphysPipelineConfig:ParamsExist') ...
    && strcmp(errorId(@() EphysPipelineConfig.writeKS4Params(pf, struct('nblock', 1), Overwrite=true)), 'EphysPipelineConfig:BadParams') ...
    && strcmp(errorId(@() EphysPipelineConfig.writeKS4Params(pf, struct(), Overwrite=true)), 'EphysPipelineConfig:BadParams'), ...
    'an existing file, unknown names and an empty set are refused');
S = S0;
S.KS4.Th_learned = 7;
S.KS4.max_channel_distance = 8;
S.KS4ExtraJSON = "{""nblocks"": 2}";
[S1, rep] = EphysPipelineConfig.ks4ForProbe(S, pf);
check(S1.KS4.nblocks == 0 && S1.KS4.dmin == 10 && S1.KS4.dminx == 17.32 && S1.KS4.x_centers == 4 ...
    && S1.KS4.Th_learned == 7 && S1.KS4.max_channel_distance == 8 && S1.KS4ExtraJSON == S.KS4ExtraJSON, ...
    'ks4ForProbe sets the file''s parameters and keeps the others and the extra JSON');
check(rep.File == paramsFile && rep.Description == r1.Summary ...
    && isequal(rep.Changes.Parameter.', EphysPipelineConfig.KS4ProbeParams) ...
    && isequal(rep.Changes.Changed.', [false true true false false false false]) ...
    && rep.Changes.Old(2) == "" && rep.Changes.New(3) == "17.32" && rep.Changes.Reason(7) == r1.Reasons.x_centers, ...
    'the report lists each parameter with old / new text and the file''s reason');
check(isscalar(rep.Notes) && contains(rep.Notes, "nblocks"), 'an extra JSON entry overriding a loaded value is noted');
writeJsonFile(paramsFile, struct('schema', "ephys-ks4-params/1", ...
    'KS4', struct('x_centers', 2, 'artifact_threshold', "Inf", 'dmin', [], 'Th_universal', 8)));
S2 = S1;
S2.KS4.artifact_threshold = 500;
[S3, rep3] = EphysPipelineConfig.ks4ForProbe(S2, pf);
check(isinf(S3.KS4.artifact_threshold) && isempty(S3.KS4.dmin) && S3.KS4.Th_universal == 8 && S3.KS4.x_centers == 2 ...
    && S3.KS4.dminx == 17.32 && isequal(rep3.Changes.Parameter.', ["artifact_threshold" "dmin" "Th_universal" "x_centers"]) ...
    && rep3.Description == "" && all(rep3.Changes.Reason == ""), ...
    'a hand-written file loads only what it lists ("Inf", [] = blank), in parameter-spec order');
writeJsonFile(paramsFile, struct('schema', "ephys-ks4-params/1", 'KS4', struct('nblock', 1)));
idUnknown = errorId(@() EphysPipelineConfig.ks4ForProbe(S0, pf));
writeJsonFile(paramsFile, struct('schema', "something-else", 'KS4', struct('nblocks', 1)));
idSchema = errorId(@() EphysPipelineConfig.ks4ForProbe(S0, pf));
writeJsonFile(paramsFile, struct('schema', "ephys-ks4-params/1", 'KS4', struct('nblocks', "many")));
idValue = errorId(@() EphysPipelineConfig.ks4ForProbe(S0, pf));
check(strcmp(idUnknown, 'EphysPipelineConfig:BadParams') && strcmp(idSchema, 'EphysPipelineConfig:BadParams') ...
    && strcmp(idValue, 'EphysPipelineConfig:BadValue'), 'unknown names, another schema and a non-numeric value are refused');
probeDir = fullfile(here, 'probes');
shipped = dir(fullfile(probeDir, "*" + EphysPipelineConfig.KS4ParamsSuffix));
shipped = string({shipped.name});
loads = ~isempty(shipped);
for k = 1:numel(shipped)
    probeMap = fullfile(probeDir, extractBefore(shipped(k), EphysPipelineConfig.KS4ParamsSuffix) + ".json");
    try
        [~, rk] = EphysPipelineConfig.ks4ForProbe(S0, probeMap);
        loads = loads && isfile(probeMap) && height(rk.Changes) >= 1;
    catch
        loads = false;
    end
end
check(loads, 'every parameter file shipped in pipeline/probes belongs to a probe map and loads');

fprintf('\n== 4. signalOptions ==\n');
G = EphysPipelineConfig.defaults("Signals");
so = EphysPipelineConfig.signalOptions(G);
check(isequal(so.dataTypeOut, "LFP") && so.LFP_Fs == 1000 && ~isfield(so, 'LFP_bpLoHi') ...
    && ~isfield(so, 'keepAmpChannels') && so.labelField == "custom" && ~isfield(so, 'lineNames'), 'defaults -> LFP only, no filters');
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
check(~isfield(d, 'UseParallel') && ~isfield(d, 'MaxWorkers'), 'detectOptions carries no parallel options without a Parallel section');
dP = EphysPipelineConfig.detectOptions(K, struct('Enabled', true, 'MaxWorkers', NaN));
check(islogical(dP.UseParallel) && dP.UseParallel && ~isfield(dP, 'MaxWorkers'), ...
    'detectOptions(K, P) adds UseParallel and omits an automatic MaxWorkers');
po = EphysPipelineConfig.parallelOptions(struct('Enabled', true, 'MaxWorkers', 3));
check(po.UseParallel && po.MaxWorkers == 3 && isequal(fieldnames(EphysPipelineConfig.parallelOptions(struct())), {'UseParallel'}), ...
    'parallelOptions: UseParallel always, MaxWorkers only when set');
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
E.EpochSource = "behavior"; E.EpochWindow = [-0.1 0.4]; E.EpochSpikeTimeBase = "window";
eo = EphysPipelineConfig.exportOptions(E, "epochs");
check(~isfield(eo, 'Validate') && eo.EventSource == "behavior" && isequal(eo.Window, [-0.1 0.4]) ...
    && eo.SpikeTimeBase == "window" && eo.Incomplete == "nan" && eo.OnsetRule == "event", ...
    'exportOptions for the epoch exporter uses its own option names');

fprintf('\n== 6. validate ==\n');
cfg = EphysPipelineConfig();
iss = cfg.validate();
check(any(iss.Step == "project" & iss.Field == "Root" & iss.Severity == "error"), 'an empty root is an error');
cfg.Project.Root = root;
cfg.Spikes.Band = [5000 500];                         % invalid but the step is off
iss = cfg.validate();
check(~any(iss.Severity == "error") && any(iss.Field == "OutputRoot" & iss.Severity == "warning"), ...
    'disabled steps are not checked; missing output root warns');
cfg.Parallel.MaxWorkers = 0;
iss = cfg.validate();
check(any(iss.Step == "parallel" & iss.Field == "MaxWorkers" & iss.Severity == "error"), 'MaxWorkers = 0 is an error');
cfg.Parallel.MaxWorkers = 2.5;
iss = cfg.validate();
check(any(iss.Step == "parallel" & iss.Field == "MaxWorkers" & iss.Severity == "error"), 'a fractional MaxWorkers is an error');
cfg.Parallel.MaxWorkers = NaN;
cfg.Parallel.Enabled = true;
iss = cfg.validate();
check(~any(iss.Step == "parallel" & iss.Severity == "error") ...
    && (license('test', 'Distrib_Computing_Toolbox') || any(iss.Step == "parallel" & iss.Severity == "warning")), ...
    'NaN MaxWorkers is fine; Parallel without the toolbox warns');
cfg.Parallel.Enabled = false;
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
check(EphysPipelineConfig().Sorting.Engine == "spikeinterface", 'sorting runs through SpikeInterface by default');
cfg.Sorting.Engine = "bogus";
iss = cfg.validate();
check(any(iss.Step == "sorting" & iss.Field == "Engine" & iss.Severity == "error"), 'an unknown sorting engine is an error');
cfg.Sorting.Engine = "kilosort";
iss = cfg.validate();
check(~any(iss.Step == "sorting" & iss.Severity == "error"), 'the native engine validates');
cfg.Sorting.Engine = "spikeinterface";
cfg.Export.Enabled = true;
iss = cfg.validate();
check(any(iss.Step == "export" & iss.Field == "Formats" & iss.Severity == "error") ...
    && any(iss.Step == "export" & iss.Field == "Signals" & iss.Severity == "warning"), ...
    'export needs a format; warns when Signals is off');
cfg.Export.Formats = ["chronux" "bogus"];
iss = cfg.validate();
check(any(iss.Field == "Formats" & contains(iss.Message, "bogus")), 'unknown export format is reported');
cfg.Export.Formats = ["chronux" "epochs"];
cfg.Export.EpochWindow = [0.5 -0.5];
iss = cfg.validate();
check(~any(iss.Field == "Formats" & iss.Severity == "error") ...
    && any(iss.Field == "EpochWindow" & iss.Severity == "error"), ...
    '"epochs" is a known format; a reversed epoch window is an error');
cfg.Export.EpochWindow = [-0.2 0.5];
cfg.Export.IncludeEvents = false;
iss = cfg.validate();
check(any(iss.Field == "IncludeEvents" & iss.Severity == "error"), ...
    'epochs around a digital line need the digital-input events');
cfg.Export.IncludeEvents = true;
cfg.Export.Formats = "chronux";
check(isequal(cfg.enabledSteps(), ["probe" "sorting" "spikes" "export"]) && cfg.stepEnabled("probe") && ~cfg.stepEnabled("signals"), ...
    'enabledSteps / stepEnabled');
check(strcmp(errorId(@() cfg.stepSection("nope")), 'EphysPipelineConfig:BadStep'), 'unknown step errors');

fprintf('\n== name tokens ==\n');
cfg = EphysPipelineConfig();
[v, n, ok] = parseNameTokens("SUBJ-ID-1245_260916_143015", cfg.Project.NamePattern);
check(ok && isequal(n, ["SubjectID" "Date" "Time"]) && isequal(v, ["SUBJ-ID-1245" "260916" "143015"]) ...
    && cfg.Project.TokenColumns == "SubjectID", 'the default pattern splits subject, yyMMdd, HHmmss; SubjectID is a column');
[v, ~, ok] = parseNameTokens("recA", cfg.Project.NamePattern);
check(~ok && isequal(v, ["" "" ""]), 'a non-matching name gives empty tokens');
cfgV = EphysPipelineConfig();
cfgV.Project.NamePattern = "{SubjectID}_{Date:yyMMdd}";
cfgV.Spikes.Enabled = true; cfgV.Spikes.Source = "sorted"; cfgV.Export.Enabled = false;
iss = cfgV.validate(CheckPaths=false);
check(any(iss.Field == "NamePattern" & iss.Severity == "error" & contains(iss.Message, "Time")), ...
    'steps reading sorted units need SubjectID, Date and Time tokens (they label the units)');
cfgV.Spikes.Source = "detect";
iss = cfgV.validate(CheckPaths=false);
check(~any(iss.Field == "NamePattern"), 'without sorted units the pattern only feeds the dataset table');
[v, n, ok] = parseNameTokens("M7_rig(2)_260916_extra", "{Subject}_{Rig:rig\((\d)\)}_{Date:yyMMdd}*");
check(ok && isequal(n, ["Subject" "Rig" "Date"]) && isequal(v, ["M7" "rig(2)" "260916"]), ...
    'regex formats (inner groups do not shift tokens) and a trailing *');
check(strcmp(errorId(@() parseNameTokens("", "{a}_{a}")), 'parseNameTokens:BadPattern') ...
    && strcmp(errorId(@() parseNameTokens("", "{1x}")), 'parseNameTokens:BadPattern') ...
    && strcmp(errorId(@() parseNameTokens("", "{a")), 'parseNameTokens:BadPattern'), ...
    'duplicate / invalid / unclosed tokens error');
check(isequal(EphysPipelineConfig.parseTokenColumns(" Date; SubjectID,,Date "), ["Date" "SubjectID"]), ...
    'TokenColumns list text parses in order without repeats');
cfg.Project.TokenColumns = "SubjectID, Nope";
iss = cfg.validate(CheckPaths=false);
check(any(iss.Field == "TokenColumns" & iss.Severity == "warning" & contains(iss.Message, "Nope")), ...
    'a token column not in the pattern warns');
cfg.Project.NamePattern = "{bad";
iss = cfg.validate(CheckPaths=false);
check(any(iss.Field == "NamePattern" & iss.Severity == "error"), 'an invalid pattern is a validation error');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysPipelineConfig:Failures', '%d checks failed.', nFail);
end
end
