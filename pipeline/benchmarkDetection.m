function R = benchmarkDetection(opts)
%benchmarkDetection  Score spike and artifact detection against synthetic ground truth.
%   R = benchmarkDetection(Name=Value) writes synthetic recordings
%   (makeSyntheticRecording) whose truth is known - every unit's spike rows
%   and template on every site, every artifact period - runs the spike
%   detector (EphysDataset.detectSpikes over the whole recording) and the
%   automatic artifact detector (EphysDataset.analyzeArtifacts) on them,
%   and scores both against that truth.
%
%   The recordings: units of the given trough amplitudes (raw, on the peak
%   site; the template spreads over the neighboring sites as the generator
%   draws it), firing without events at RateHz, over the generator's
%   default background (white noise, 1/f noise, LFP rhythms, line noise)
%   and its two artifacts (a 150 ms burst and a 400 ms saturating step).
%
%   Spikes. The true artifact periods are erased first (detectSpikes'
%   ArtifactIntervals), so the two detectors are scored apart; true spikes
%   and detections within MarginMs of an artifact period are left out.
%     per unit, on its peak channel:
%       recall       its spikes with a detection within ToleranceMs
%       snr          its template's trough, band-passed as detection does,
%                    over the channel's noise level (info.noise; NaN for the
%                    "percentile" and "absolute" methods)
%     per channel, each detection is one of:
%       matched      within ToleranceMs of a spike of a unit visible there
%                    (template trough at least VisibleFraction x the
%                    channel's threshold)
%       duplicate    not matched, but within DuplicateMs of such a spike: a
%                    second crossing of the same spike (the band-passed
%                    waveform's later lobes, past MinPeriodMs)
%       isolated     neither: a noise crossing
%     precision = matched / all detections; duplicateHz, isolatedHz per
%     second of scored recording; duplicatesPerSpike per visible spike.
%   Artifacts (analyzeArtifacts with ArtifactConfig, Enabled):
%     per true period: found (a detected interval overlaps it), coverage
%     (the fraction of it detected), onsetMs / offsetMs (detected minus
%     true edge; negative = earlier); falseArtifacts lists the detected
%     intervals that overlap no true period.
%
%   Options
%     Folder          where to write the recordings (default: a new folder
%                     under tempdir, removed at the end unless Keep)
%     Keep            false: true keeps the recordings
%     Seeds           1:2, one recording per seed
%     NumTrials       8: the recording's length in trials of the built-in
%                     task (makeSyntheticRecording)
%     NumChannels     8 (one shank of 25 um pitch, makeSyntheticProbe)
%     AmplitudesUV    [40 60 90 140 200]: one unit per entry
%     Channels        their peak channels (default: spread over the
%                     channels, the largest unit last)
%     WidthMs         0.2: trough width (Gaussian sigma)
%     RateHz          10
%     Background      struct of SyntheticDesign background fields to change
%     Format          "traditional" (default: 30 s *.rhd files, which are
%                     the detectors' chunks) | any makeSyntheticRecording format
%     DetectOptions   detectSpikes options (default: the pipeline's,
%                     EphysPipelineConfig.detectOptions of the default
%                     Spikes section)
%     ArtifactConfig  EphysDataset artifact settings (default:
%                     EphysDataset.defaultArtifactConfig, Enabled)
%     ToleranceMs     0.5    DuplicateMs  3    VisibleFraction  0.5
%     MarginMs        2
%     HighSNR         6: summary.recallHighSNR is the lowest recall of the
%                     units at or above this SNR
%     ReportFile      "": write R as JSON here (writeJsonFile)
%     ProgressFcn     ProgressFcn(message)
%
%   R fields
%     units      table: seed, unit, channel, amplitudeUV, snr, thresholdUV,
%                spikes, detected, recall
%     channels   table: seed, channel, detections, matched, duplicates,
%                isolated, precision, visibleSpikes, duplicatesPerSpike,
%                duplicateHz, isolatedHz, thresholdUV, noiseUV
%     artifacts  table: seed, kind, startS, endS, found, intervals,
%                coverage, onsetMs, offsetMs
%     falseArtifacts  table: seed, startS, endS
%     summary    recallHighSNR, recallByUnit (mean over seeds), precision,
%                maxDuplicatesPerSpike, maxIsolatedHz, artifactRecall,
%                artifactMinCoverage, artifactMaxEdgeMs, falseArtifacts
%     settings   the options used; provenance (ephysProvenance)
%
%   See also test_DetectionBenchmark, makeSyntheticRecording,
%   EphysDataset.detectSpikes, EphysDataset.analyzeArtifacts.

arguments
    opts.Folder (1,1) string = ""
    opts.Keep (1,1) logical = false
    opts.Seeds (1,:) double {mustBeInteger, mustBeNonnegative} = 1:2
    opts.NumTrials (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(opts.NumTrials, 4)} = 8
    opts.NumChannels (1,1) double {mustBeInteger, mustBePositive} = 8
    opts.AmplitudesUV (1,:) double {mustBePositive} = [40 60 90 140 200]
    opts.Channels (1,:) double {mustBeInteger, mustBePositive} = []
    opts.WidthMs (1,1) double {mustBePositive} = 0.2
    opts.RateHz (1,1) double {mustBePositive} = 10
    opts.Background (1,1) struct = struct()
    opts.Format (1,1) string = "traditional"
    opts.DetectOptions (1,1) struct = EphysPipelineConfig.detectOptions(EphysPipelineConfig.defaults("Spikes"))
    opts.ArtifactConfig (1,1) struct = EphysDataset.defaultArtifactConfig()
    opts.ToleranceMs (1,1) double {mustBePositive} = 0.5
    opts.DuplicateMs (1,1) double {mustBePositive} = 3
    opts.VisibleFraction (1,1) double {mustBePositive} = 0.5
    opts.MarginMs (1,1) double {mustBeNonnegative} = 2
    opts.HighSNR (1,1) double {mustBePositive} = 6
    opts.ReportFile (1,1) string = ""
    opts.ProgressFcn = []
end

nU = numel(opts.AmplitudesUV);
nCh = opts.NumChannels;
chans = opts.Channels;
if isempty(chans)
    [~, order] = sort(opts.AmplitudesUV);
    spread = max(1, min(nCh, round(linspace(1, nCh, nU))));
    chans = zeros(1, nU);
    chans(order) = spread;
end
if numel(chans) ~= nU || any(chans > nCh)
    error('benchmarkDetection:Channels', 'Channels must give one channel (1 to %d) per amplitude.', nCh);
end
for f = ["ArtifactIntervals" "Fs" "ChannelOrder" "ProgressFcn"]
    if isfield(opts.DetectOptions, f)
        error('benchmarkDetection:DetectOptions', 'DetectOptions cannot set %s here.', f);
    end
end

root = opts.Folder;
made = root == "";
if made
    root = string(tempname);
end
if ~isfolder(root); mkdir(root); end
if made && ~opts.Keep
    removeRoot = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>
end

D = benchDesign(opts, chans);
unitNames = ["seed" "unit" "channel" "amplitudeUV" "snr" "thresholdUV" "spikes" "detected" "recall"];
chanNames = ["seed" "channel" "detections" "matched" "duplicates" "isolated" "precision" ...
    "visibleSpikes" "duplicatesPerSpike" "duplicateHz" "isolatedHz" "thresholdUV" "noiseUV"];
artNames  = ["seed" "startS" "endS" "found" "intervals" "coverage" "onsetMs" "offsetMs"];
Urows = zeros(0, numel(unitNames));
Crows = zeros(0, numel(chanNames));
Arows = zeros(0, numel(artNames));
artKinds = strings(0, 1);
Frows = zeros(0, 3);
for seed = opts.Seeds
    say(opts, sprintf('seed %d: writing the recording', seed));
    folder = fullfile(root, sprintf('BENCH-%02d_260101_%06d', seed, 120000 + seed));
    genArgs = {'Design', D, 'NumChannels', nCh, 'NumTrials', opts.NumTrials, 'Seed', seed, ...
        'Format', opts.Format, 'SortedOutput', false, 'WriteManifest', false, 'Subject', "BENCH"};
    P = makeSyntheticRecording(folder, genArgs{:}, 'PreviewOnly', true);
    T = makeSyntheticRecording(folder, genArgs{:});
    model = P.model;
    if ~isequal({model.units.samples}, {T.units.samples})
        error('benchmarkDetection:Truth', 'The preview''s spike trains differ from the recording''s (seed %d).', seed);
    end
    Fs = T.Fs;
    ds = EphysDataset(string(T.folder));

    % --- spikes -------------------------------------------------------------
    say(opts, sprintf('seed %d: detecting spikes', seed));
    dopt = opts.DetectOptions;
    dopt.Waveforms = false;
    dopt.ArtifactIntervals = T.artifacts;
    dArgs = namedargs2cell(dopt);
    [~, ~, info] = ds.detectSpikes(dArgs{:});
    thr = median(info.threshold, 1, 'omitnan');           % per channel (chunk scope: over the chunks)
    noise = median(info.noise, 1, 'omitnan');
    margin = round(opts.MarginMs * 1e-3 * Fs);
    artRows = [round(T.artifacts(:, 1) * Fs) + 1 - margin, round(T.artifacts(:, 2) * Fs) + margin];
    keepRow = @(r) ~any(r(:) >= artRows(:, 1).' & r(:) <= artRows(:, 2).', 2);
    nKept = T.nSamples - sum(min(artRows(:, 2), T.nSamples) - max(artRows(:, 1), 1) + 1);
    scoredSec = nKept / Fs;
    tol = round(opts.ToleranceMs * 1e-3 * Fs);
    dupW = round(opts.DuplicateMs * 1e-3 * Fs);
    filt = opts.DetectOptions;

    trueRows = cell(1, nU);
    for u = 1:nU
        s = model.units(u).samples(:);
        trueRows{u} = s(keepRow(s));
    end
    for u = 1:nU
        c = model.units(u).peakChannel;
        det = info.index{c}(:);
        hit = nearest(trueRows{u}, det) <= tol;
        trough = filteredTrough(ds, model.units(u).template(:, c), filt, Fs);
        Urows(end+1, :) = [seed, u, c, opts.AmplitudesUV(u), trough / noise(c), thr(c), ...
            numel(hit), nnz(hit), nnz(hit) / max(numel(hit), 1)]; %#ok<AGROW>
    end
    for c = 1:nCh
        det = info.index{c}(:);
        det = det(keepRow(det));
        vis = arrayfun(@(q) max(-q.template(:, c)) >= opts.VisibleFraction * thr(c), model.units);
        visRows = sort(vertcat(trueRows{vis}, zeros(0, 1)));
        d = nearest(det, visRows);
        matched = d <= tol;
        dup = ~matched & d <= dupW;
        iso = ~matched & ~dup;
        nDet = numel(det);
        Crows(end+1, :) = [seed, c, nDet, nnz(matched), nnz(dup), nnz(iso), ...
            nnz(matched) / max(nDet, 1), numel(visRows), nnz(dup) / max(numel(visRows), 1), ...
            nnz(dup) / scoredSec, nnz(iso) / scoredSec, thr(c), noise(c)]; %#ok<AGROW>
    end

    % --- artifacts ----------------------------------------------------------
    say(opts, sprintf('seed %d: detecting artifacts', seed));
    a = opts.ArtifactConfig;
    a.Enabled = true;
    ds.ArtifactConfig = a;
    S = ds.analyzeArtifacts();
    iv = S.intervals;
    if isempty(iv); iv = zeros(0, 2); end
    over = iv(:, 1) < T.artifacts(:, 2).' & iv(:, 2) > T.artifacts(:, 1).';   % [nDetected x nTrue]
    for k = 1:size(T.artifacts, 1)
        t0 = T.artifacts(k, 1); t1 = T.artifacts(k, 2);
        o = iv(over(:, k), :);
        cov = sum(min(o(:, 2), t1) - max(o(:, 1), t0)) / (t1 - t0);
        onMs = NaN; offMs = NaN;
        if ~isempty(o)
            onMs = 1e3 * (min(o(:, 1)) - t0);
            offMs = 1e3 * (max(o(:, 2)) - t1);
        end
        Arows(end+1, :) = [seed, t0, t1, ~isempty(o), size(o, 1), cov, onMs, offMs]; %#ok<AGROW>
        artKinds(end+1, 1) = string(model.artifactKinds(k)); %#ok<AGROW>
    end
    fa = iv(~any(over, 2), :);
    Frows = [Frows; repmat(seed, size(fa, 1), 1), fa]; %#ok<AGROW>
end

units = array2table(Urows, 'VariableNames', unitNames);
channels = array2table(Crows, 'VariableNames', chanNames);
arts = array2table(Arows, 'VariableNames', artNames);
arts = addvars(arts, artKinds, 'After', 'seed', 'NewVariableNames', 'kind');
arts.found = logical(arts.found);
falseArt = array2table(Frows, 'VariableNames', ["seed" "startS" "endS"]);

high = units.snr >= opts.HighSNR;
summary = struct();
summary.recallHighSNR = min([units.recall(high); NaN]);
summary.recallByUnit = groupsummary(units, "unit", "mean", ["recall" "snr"]);
summary.precision = sum(channels.matched) / max(sum(channels.detections), 1);
summary.maxDuplicatesPerSpike = max(channels.duplicatesPerSpike);
summary.maxIsolatedHz = max(channels.isolatedHz);
summary.artifactRecall = mean(arts.found);
summary.artifactMinCoverage = min(arts.coverage);
summary.artifactMaxEdgeMs = max(abs([arts.onsetMs; arts.offsetMs]));
summary.falseArtifacts = height(falseArt);

settings = rmfield(opts, {'ProgressFcn'});
settings.Channels = chans;
R = struct('units', units, 'channels', channels, 'artifacts', arts, 'falseArtifacts', falseArt, ...
    'summary', summary, 'settings', settings, 'provenance', ephysProvenance());
if opts.ReportFile ~= ""
    rep = R;
    for f = ["units" "channels" "artifacts" "falseArtifacts"]
        rep.(f) = table2struct(R.(f));
    end
    rep.summary.recallByUnit = table2struct(summary.recallByUnit);
    rep.provenance = provenanceForJson(R.provenance);
    writeJsonFile(opts.ReportFile, rep, NonFinite="string");
end
end


function D = benchDesign(opts, chans)
%benchDesign  Units of the given amplitudes, no events, no event-linked LFP.
nU = numel(opts.AmplitudesUV);
U = SyntheticDesign.unitTable(nU);
U.Name = "u" + (1:nU).';
U.Channel = chans(:);
U.AmplitudeUV = opts.AmplitudesUV(:);
U.WidthMs(:) = opts.WidthMs;
U.BaselineHz(:) = opts.RateHz;
D = SyntheticDesign();
B = D.Background;
for f = string(fieldnames(opts.Background)).'
    if ~isfield(B, f)
        error('benchmarkDetection:Background', 'Unknown background field "%s".', f);
    end
    B.(f) = opts.Background.(f);
end
D.Background = B;
D.Units = U;
end


function d = nearest(a, b)
%nearest  For each row index in A, the distance (samples) to the nearest one in B (Inf if none).
d = inf(numel(a), 1);
if isempty(a) || isempty(b)
    return
end
b = unique(b(:));                           % discretize needs increasing edges
j = discretize(a(:), [-Inf; b; Inf]);       % b(j-1) <= a < b(j)
lo = j - 1;                                 % the one at or below
hasLo = lo >= 1;
d(hasLo) = a(hasLo) - b(lo(hasLo));
hasHi = j <= numel(b);
d(hasHi) = min(d(hasHi), b(j(hasHi)) - a(hasHi));
end


function v = filteredTrough(ds, w, dopt, Fs)
%filteredTrough  |trough| of template column W as detection sees it (band-passed when Filter).
x = [zeros(400, 1); w(:); zeros(400, 1)];
if ~isfield(dopt, 'Filter') || dopt.Filter
    band = [500 5000]; order = 4;
    if isfield(dopt, 'Band'); band = dopt.Band; end
    if isfield(dopt, 'FilterOrder'); order = dopt.FilterOrder; end
    x = ds.filterContinuous(x, Type="bandpass", Cutoff=band, Order=order, Fs=Fs);
end
v = max(-x);
end


function say(opts, msg)
if ~isempty(opts.ProgressFcn)
    opts.ProgressFcn(string(msg));
end
end
