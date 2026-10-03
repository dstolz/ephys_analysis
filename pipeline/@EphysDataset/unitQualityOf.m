function [units, Q] = unitQualityOf(units, info, opts)
%unitQualityOf  Add quality metrics to sorted units, given the recording's length.
%   [UNITS, Q] = EphysDataset.unitQualityOf(UNITS, INFO, NumSamples=N)
%   is ds.unitQuality without a dataset: UNITS and INFO as readPhyUnits /
%   readSortedUnits return them, N the samples of the recording that was
%   sorted (its .bin). Kilosort4 sorts from tmin to tmax of it (the sort's
%   settings.json; 0 and the end by default) and counts spike times from
%   its start, so the metrics are taken over that span: its samples, its
%   start subtracted from the spike times. It adds per unit the metrics of
%   unitQualityMetrics
%   (SpikeInterface's definitions) as column fields of UNITS -
%   firingRate, isiViolationsRatio, isiViolationsCount, presenceRatio,
%   amplitudeCutoff, snr, driftPtp, driftStd, driftMad - and UNITS.quality
%   (the settings, where the length came from, how SNR was measured, the
%   cache). Q is the same as a table, unitId first.
%
%   From the sort's results folder (UNITS.resultsDir):
%     amplitudes   amplitudes.npy, through INFO.spikeAmplitudes (Kilosort4's
%                  per-spike template scaling): the amplitude cutoff
%     positions    the y column of spike_positions.npy (Kilosort4's per-spike
%                  location, um): drift; NaN without it
%   SNR is the largest |value| of the unit's template on its peak channel
%   (UNITS.templateWaveform, used only when UNITS.templateUnits is "uV")
%   over that channel's noise, which NoiseFcn(CHANNELS) returns in uV
%   (ds.unitQuality measures the recording); NaN without uV templates or
%   a NoiseFcn.
%
%   Cache: the spike-train metrics of every cluster in the folder and the
%   noise of each channel measured are kept in <resultsDir>/
%   quality_metrics.json (schema ephys-unit-quality/1) with the size and
%   time of the files they came from, N and the settings; a later call with
%   the same files and settings reads it. A merge or split in phy (which
%   rewrites spike_clusters.npy) makes it stale. A folder that cannot be
%   written is a warning (EphysDataset:unitQuality:CacheNotWritten).
%
%   Options
%     NumSamples        required
%     NumSamplesSource  text recorded in UNITS.quality (default "given")
%     NoiseFcn          [] | @(channels) uV noise per 1-based recording channel
%     Cache             true
%     Metrics           struct of unitQualityMetrics options
%
%   See also EphysDataset.unitQuality, unitQualityMetrics, unitQualityPass.

arguments
    units (1,1) struct
    info (1,1) struct
    opts.NumSamples (1,1) double {mustBePositive, mustBeInteger}
    opts.NumSamplesSource (1,1) string = "given"
    opts.NoiseFcn = []
    opts.Cache (1,1) logical = true
    opts.Metrics (1,1) struct = struct()
end
dir0 = string(units.resultsDir);
fs = units.fs;
nU = numel(units.unitId);
[first, nSamp, spanNote] = sortedSpan(dir0, fs, opts.NumSamples);
metricArgs = [namedargs2cell(opts.Metrics), {'FirstSample', first}];

% --- every cluster of the folder: spike-train metrics (cached) ---------------
inputs = fingerprint(dir0);
cacheFile = fullfile(dir0, "quality_metrics.json");
key = struct('numSamples', nSamp, 'firstSample', first, 'fs', fs, 'metrics', opts.Metrics);
C = [];
cacheState = "computed";
if opts.Cache
    C = readCache(cacheFile, inputs, key);
    if ~isempty(C); cacheState = "read"; end
end
if isempty(C)
    [C.ids, C.Q] = clusterMetrics(dir0, info, fs, nSamp, metricArgs);
    C.noiseChannels = zeros(1, 0);
    C.noiseUV = zeros(1, 0);
end

% --- noise per channel (for SNR), cached with the metrics ----------------------
haveUV = isfield(units, 'templateUnits') && string(units.templateUnits) == "uV" ...
    && isfield(units, 'templateWaveform') && numel(units.templateWaveform) == nU;
noiseUV = nan(nU, 1);
noiseNote = "";
if ~haveUV
    tu = "";
    if isfield(units, 'templateUnits'); tu = string(units.templateUnits); end
    noiseNote = "no SNR: templates not in uV (templateUnits """ + tu + """)";
elseif isempty(opts.NoiseFcn)
    noiseNote = "no SNR: the noise was not measured";
else
    need = unique(units.channel(isfinite(units.channel))).';
    missing = setdiff(need, C.noiseChannels);
    if ~isempty(missing)
        try
            sigma = opts.NoiseFcn(missing);
            C.noiseChannels = [C.noiseChannels, missing];
            C.noiseUV = [C.noiseUV, reshape(double(sigma), 1, [])];
            if cacheState == "read"; cacheState = "read, noise added"; end
        catch ME
            warning('EphysDataset:unitQuality:NoNoise', ...
                'The noise could not be measured (%s); SNR is NaN.', ME.message);
            noiseNote = "no SNR: the noise could not be measured (" + string(ME.message) + ")";
        end
    end
    [tf, loc] = ismember(units.channel(:), C.noiseChannels);
    noiseUV(tf) = C.noiseUV(loc(tf));
end
peakUV = nan(nU, 1);
if haveUV
    peakUV = cellfun(@(w) max(abs(double(w(:))), [], 'omitnan'), units.templateWaveform(:));
end

% --- the rows of these units ------------------------------------------------------
[tf, loc] = ismember(double(units.unitId(:)), C.ids);
if ~all(tf)
    error('EphysDataset:unitQuality:Mismatch', ...
        'Units %s are not in the spike clusters of %s.', mat2str(units.unitId(~tf)), dir0);
end
Q = C.Q(loc, :);
Q.snr = abs(peakUV) ./ noiseUV;
Q.snr(~(noiseUV > 0)) = NaN;
for v = string(Q.Properties.VariableNames)
    units.(v) = Q.(v);
end
[~, S] = unitQualityMetrics({}, 'Fs', fs, 'NumSamples', nSamp, metricArgs{:});
units.quality = struct('settings', S, 'numSamples', nSamp, 'firstSample', first, ...
    'numSamplesSource', opts.NumSamplesSource + spanNote, ...
    'snrNoise', noiseNote, 'cache', cacheState, 'cacheFile', cacheFile);
Q = [table(double(units.unitId(:)), 'VariableNames', {'unitId'}), Q];

if opts.Cache && cacheState ~= "read"
    writeCache(cacheFile, inputs, key, C, S);
end
end


function [ids, Q] = clusterMetrics(dir0, info, fs, nSamp, metricArgs)
%clusterMetrics  unitQualityMetrics of every cluster in the folder (all spikes of INFO).
clu = double(info.spikeClusters(:));
[ids, ~, k] = unique(clu);
n = numel(ids);
s = int64(info.spikeSamples(:));
amp = double(info.spikeAmplitudes(:));
spikes = accumarray(k, (1:numel(clu)).', [n 1], @(r) {s(sort(r))});
ampC = {};
if any(isfinite(amp))
    ampC = accumarray(k, (1:numel(clu)).', [n 1], @(r) {amp(sort(r))});
end
posC = {};
fPos = fullfile(dir0, 'spike_positions.npy');
if isfile(fPos)
    P = double(readNPY(fPos));
    if size(P, 1) == numel(clu) && size(P, 2) >= 2
        y = P(:, 2);
        posC = accumarray(k, (1:numel(clu)).', [n 1], @(r) {y(sort(r))});
    end
end
Q = unitQualityMetrics(spikes, 'Fs', fs, 'NumSamples', nSamp, 'Amplitudes', ampC, 'PositionsY', posC, metricArgs{:});
end


function F = fingerprint(dir0)
%fingerprint  Size and modification time (whole seconds, exact in JSON) of the files the metrics come from.
F = struct();
for f = ["spike_times.npy" "spike_clusters.npy" "amplitudes.npy" "spike_positions.npy" ...
         "templates.npy" "params.py" "settings.json"]
    d = dir(fullfile(dir0, f));
    k = matlab.lang.makeValidName(f);
    if isscalar(d)
        F.(k) = struct('bytes', d.bytes, 'modified', round(d.datenum * 86400));
    else
        F.(k) = struct('bytes', -1, 'modified', -1);
    end
end
end


function C = readCache(file, inputs, key)
%readCache  The cached metrics when they were computed from these files and settings, else [].
C = [];
if ~isfile(file); return; end
s = readJsonFile(file, ErrorOnFail=false);
try
    if ~(isstruct(s) && string(s.schema) == "ephys-unit-quality/1"); return; end
    if ~isequaln(normalizeNum(s.inputs), normalizeNum(inputs)); return; end
    if ~(s.key.numSamples == key.numSamples && s.key.fs == key.fs); return; end
    if ~(isfield(s.key, 'firstSample') && s.key.firstSample == key.firstSample); return; end
    if ~isequaln(normalizeNum(orEmpty(s.key.metrics)), normalizeNum(key.metrics)); return; end
    rows = s.clusters;
    if iscell(rows); rows = [rows{:}]; end
    T = struct2table(rows(:), 'AsArray', true);
    num = @(v) double(stringifiedNum(v));
    C.ids = num(T.unitId);
    vars = ["firingRate" "isiViolationsRatio" "isiViolationsCount" "presenceRatio" ...
        "amplitudeCutoff" "snr" "driftPtp" "driftStd" "driftMad"];
    Q = table();
    for v = vars
        Q.(v) = num(T.(v));
    end
    C.Q = Q;
    C.noiseChannels = reshape(double(s.noise.channels), 1, []);
    C.noiseUV = reshape(num(s.noise.uV), 1, []);
catch
    C = [];
end
end


function writeCache(file, inputs, key, C, S)
%writeCache  Write quality_metrics.json; a folder that cannot be written is only a warning.
%   The metrics and noise levels are written as "%.17g" strings, which read
%   back to the very same doubles, so a cached value equals a computed one.
Qs = table();
for v = string(C.Q.Properties.VariableNames)
    Qs.(v) = exact(C.Q.(v));
end
rows = table2struct([table(C.ids(:), 'VariableNames', {'unitId'}), Qs]);
s = struct('schema', "ephys-unit-quality/1", 'inputs', inputs, 'key', key, ...
    'definitions', S.definitions, 'clusters', rows, ...
    'noise', struct('channels', C.noiseChannels, 'uV', exact(C.noiseUV)), ...
    'provenance', provenanceForJson(ephysProvenance()));
try
    writeJsonFile(file, s, NonFinite="string");
catch ME
    warning('EphysDataset:unitQuality:CacheNotWritten', ...
        'The quality metrics could not be cached in %s (%s); they are computed again next time.', file, ME.message);
end
end


function v = stringifiedNum(v)
%stringifiedNum  JSON values back to numbers: "NaN" / "Inf" strings, null ([]) to NaN.
if iscell(v)
    v = cellfun(@one, v);
elseif isstring(v) || ischar(v)
    v = str2double(string(v));
end
    function x = one(e)
        if isempty(e); x = NaN; elseif isnumeric(e); x = double(e); else; x = str2double(string(e)); end
    end
end


function s = normalizeNum(s)
%normalizeNum  Structs compared after JSON: every number a double, field order sorted.
if isstruct(s)
    s = orderfields(s);
    for f = string(fieldnames(s)).'
        s.(f) = normalizeNum(s.(f));
    end
elseif isnumeric(s) || islogical(s)
    s = double(s);
elseif ischar(s)
    s = string(s);
end
end


function s = orEmpty(s)
if isempty(s); s = struct(); end
end


function t = exact(v)
%exact  Doubles as strings that read back to the same doubles ("%.17g"; NaN, Inf as such).
t = strings(size(v));
for k = 1:numel(v)
    t(k) = sprintf('%.17g', v(k));
end
end


function [first, n, note] = sortedSpan(dir0, fs, total)
%sortedSpan  The samples Kilosort4 sorted: tmin to tmax (settings.json) of TOTAL.
%   As Kilosort4's io: imin = int(tmin fs), imax = int(tmax fs) capped at
%   the end (the whole recording without them).
first = 0; last = total; note = "";
cfg = readJsonFile(fullfile(dir0, 'settings.json'), ErrorOnFail=false);
if isstruct(cfg)
    if isfield(cfg, 'tmin') && isnumeric(cfg.tmin) && isscalar(cfg.tmin) && cfg.tmin > 0
        first = min(floor(double(cfg.tmin) * fs), total);
    end
    if isfield(cfg, 'tmax') && isnumeric(cfg.tmax) && isscalar(cfg.tmax) && isfinite(cfg.tmax) && cfg.tmax > 0
        last = min(floor(double(cfg.tmax) * fs), total);
    end
end
n = last - first;
if first > 0 || last < total
    note = sprintf("; the sort's span, samples %d to %d (settings.json tmin / tmax)", first, last);
end
if ~(n > 0)
    error('EphysDataset:unitQuality:NoSpan', ...
        'The sort in %s covers no samples (tmin / tmax beyond the %d samples of the recording).', dir0, total);
end
end
