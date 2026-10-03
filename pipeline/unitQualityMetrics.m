function [Q, S] = unitQualityMetrics(spikes, opts)
%unitQualityMetrics  Quality metrics of sorted units, as SpikeInterface defines them.
%   [Q, S] = unitQualityMetrics(SPIKES, Fs=, NumSamples=, Name=Value)
%   computes per unit the metrics of SpikeInterface's quality-metrics
%   module (spikeinterface.metrics.quality, version 0.105, default
%   parameters), on one recording segment:
%
%     firingRate          spikes / recording duration (Hz)
%     isiViolationsRatio  the relative rate of a hypothetical contaminating
%                         unit (Hill et al. 2011): V T / (2 N^2 (tr - tc)),
%                         V the inter-spike intervals shorter than tr =
%                         IsiThresholdMs, tc = MinIsiMs, N spikes, T the
%                         duration
%     isiViolationsCount  V
%     presenceRatio       the fraction of the whole PresenceBinS bins of the
%                         recording ([0 B), [B 2B), ... up to the last whole
%                         bin; the rest is left out) in which the unit fired;
%                         NaN for a recording shorter than one bin
%     amplitudeCutoff     the fraction of spikes estimated to be missing below
%                         the detection threshold, from the amplitude
%                         histogram (AmplitudeBins bins from the smallest to
%                         the largest amplitude, smoothed by a Gaussian of
%                         AmplitudeSmoothing bins and truncated to whole
%                         counts, as SpikeInterface's integer histogram is):
%                         the counts above the amplitude where the histogram
%                         last stands as high as at its lowest bin, over N
%                         plus them; at most 0.5. Amplitudes with a negative
%                         median are negated first. NaN with fewer than
%                         AmplitudeMinRatio x AmplitudeBins spikes, or no
%                         amplitudes
%     snr                 PeakAmplitudeUV ./ NoiseUV (NaN where either is)
%     driftPtp, driftStd, driftMad
%                         the drift of the unit's depth: the median y of its
%                         spikes in each whole DriftIntervalS interval with at
%                         least DriftMinSpikes spikes, less the median over all
%                         its spikes; their range, standard deviation (over N)
%                         and median absolute deviation (um). NaN with fewer
%                         than DriftMinBins intervals, when more than
%                         DriftMinValidFraction of them lack the spikes, or
%                         without positions
%
%   SPIKES is {nUnits x 1} spike sample indices, 0-based as in
%   spike_times.npy (units.samples of readPhyUnits), each sorted.
%
%   Options
%     Fs                  sample rate (Hz), required
%     NumSamples          samples in the recording the units were sorted
%                         from, required (the duration is NumSamples / Fs)
%     FirstSample         0-based sample where that recording starts in the
%                         spike times' clock (default 0): a sort of part of a
%                         recording (Kilosort4's tmin) counts its spike times
%                         from the recording's start, so they are shifted by
%                         it first
%     Amplitudes          {nUnits x 1} per-spike amplitudes, in spike order
%                         (Kilosort's amplitudes.npy); {} = none
%     PositionsY          {nUnits x 1} per-spike depth (um; the y column of
%                         Kilosort's spike_positions.npy); {} = none
%     PeakAmplitudeUV     [nUnits x 1] |extremum| of each unit's mean waveform
%                         on its peak channel (uV); [] = none
%     NoiseUV             [nUnits x 1] noise level on each unit's peak channel
%                         (uV, MAD / 0.6745); [] = none
%     IsiThresholdMs 1.5, MinIsiMs 0, PresenceBinS 60, AmplitudeBins 500,
%     AmplitudeSmoothing 3, AmplitudeMinRatio 5, DriftIntervalS 60,
%     DriftMinSpikes 100, DriftMinBins 2, DriftMinValidFraction 0.5
%
%   Q is a table, one row per unit, with the columns above. S holds the
%   settings used and their source.
%
%   test_UnitQuality compares every metric with the values SpikeInterface
%   itself gives (pipeline/testdata/unit_quality_golden.json, from
%   tools/golden/unit_quality_golden.py).
%
%   See also EphysDataset.unitQuality, unitQualityPass, EphysDataset.readPhyUnits.

arguments
    spikes cell
    opts.Fs (1,1) double {mustBePositive}
    opts.NumSamples (1,1) double {mustBeNonnegative, mustBeInteger}
    opts.FirstSample (1,1) double {mustBeNonnegative, mustBeInteger} = 0
    opts.Amplitudes cell = {}
    opts.PositionsY cell = {}
    opts.PeakAmplitudeUV double = []
    opts.NoiseUV double = []
    opts.IsiThresholdMs (1,1) double {mustBePositive} = 1.5
    opts.MinIsiMs (1,1) double {mustBeNonnegative} = 0
    opts.PresenceBinS (1,1) double {mustBePositive} = 60
    opts.AmplitudeBins (1,1) double {mustBePositive, mustBeInteger} = 500
    opts.AmplitudeSmoothing (1,1) double {mustBePositive} = 3
    opts.AmplitudeMinRatio (1,1) double {mustBeNonnegative} = 5
    opts.DriftIntervalS (1,1) double {mustBePositive} = 60
    opts.DriftMinSpikes (1,1) double {mustBeNonnegative} = 100
    opts.DriftMinBins (1,1) double {mustBeNonnegative} = 2
    opts.DriftMinValidFraction (1,1) double {mustBeNonnegative} = 0.5
end

spikes = spikes(:);
nU = numel(spikes);
for f = ["Amplitudes" "PositionsY"]
    if ~isempty(opts.(f)) && numel(opts.(f)) ~= nU
        error('unitQualityMetrics:Size', '%s must hold one array per unit (%d); got %d.', f, nU, numel(opts.(f)));
    end
end
for f = ["PeakAmplitudeUV" "NoiseUV"]
    if ~isempty(opts.(f)) && numel(opts.(f)) ~= nU
        error('unitQualityMetrics:Size', '%s must hold one value per unit (%d); got %d.', f, nU, numel(opts.(f)));
    end
end

fs = opts.Fs;
nSamp = opts.NumSamples;
durS = nSamp / fs;
% Whole bins [0 B), [B 2B), ..., the last one closed: SpikeInterface's
% compute_bin_edges_per_unit for one segment.
presenceEdges = binEdges(nSamp, fix(opts.PresenceBinS * fs));
driftEdges    = binEdges(nSamp, fix(opts.DriftIntervalS * fs));

firingRate = nan(nU, 1);
isiRatio   = nan(nU, 1);
isiCount   = nan(nU, 1);
presence   = nan(nU, 1);
ampCutoff  = nan(nU, 1);
driftPtp   = nan(nU, 1);
driftStd   = nan(nU, 1);
driftMad   = nan(nU, 1);
for u = 1:nU
    s = double(spikes{u}(:)) - opts.FirstSample;
    N = numel(s);
    if N == 0
        continue
    end
    firingRate(u) = N / durS;
    [isiRatio(u), isiCount(u)] = isiViolations(s / fs, durS, opts.IsiThresholdMs / 1000, opts.MinIsiMs / 1000);
    if fix(opts.PresenceBinS * fs) <= nSamp
        presence(u) = presenceRatio(s, presenceEdges);
    end
    if ~isempty(opts.Amplitudes)
        ampCutoff(u) = amplitudeCutoff(double(opts.Amplitudes{u}(:)), opts.AmplitudeBins, ...
            opts.AmplitudeSmoothing, opts.AmplitudeMinRatio);
    end
    if ~isempty(opts.PositionsY)
        [driftPtp(u), driftStd(u), driftMad(u)] = drift(s, double(opts.PositionsY{u}(:)), driftEdges, ...
            opts.DriftMinSpikes, opts.DriftMinBins, opts.DriftMinValidFraction);
    end
end
snr = nan(nU, 1);
if ~isempty(opts.PeakAmplitudeUV) && ~isempty(opts.NoiseUV)
    snr = abs(opts.PeakAmplitudeUV(:)) ./ opts.NoiseUV(:);
    snr(~(opts.NoiseUV(:) > 0)) = NaN;
end

Q = table(firingRate, isiRatio, isiCount, presence, ampCutoff, snr, driftPtp, driftStd, driftMad, ...
    'VariableNames', {'firingRate', 'isiViolationsRatio', 'isiViolationsCount', 'presenceRatio', ...
    'amplitudeCutoff', 'snr', 'driftPtp', 'driftStd', 'driftMad'});
S = rmfield(opts, {'Amplitudes', 'PositionsY', 'PeakAmplitudeUV', 'NoiseUV'});
S.definitions = "SpikeInterface 0.105 quality metrics (spikeinterface.metrics.quality), default parameters";
end


function e = binEdges(nSamp, B)
%binEdges  0, B, 2B, ... up to the last whole bin (the end of the recording beyond it is left out).
if B <= 0
    e = 0;
    return
end
e = (0:floor(nSamp / B)).' * B;
end


function [ratio, count] = isiViolations(t, durS, thrS, minS)
%isiViolations  SpikeInterface's isi_violations for one segment (T in s).
count = nnz(diff(t) < thrS);
N = numel(t);
violationTime = 2 * N * (thrS - minS);
totalRate = N / durS;
violationRate = count / violationTime;
ratio = violationRate / totalRate;
end


function r = presenceRatio(s, edges)
%presenceRatio  Fraction of the bins EDGES (numpy histogram: the last one closed) with a spike.
nb = numel(edges) - 1;
if nb < 1
    r = 0;
    return
end
h = histcounts(s, edges);     % [e_i, e_i+1), the last bin [e_end-1, e_end]: as numpy
r = nnz(h > 0) / nb;
end


function f = amplitudeCutoff(a, nBins, sigma, minRatio)
%amplitudeCutoff  SpikeInterface's amplitude_cutoff (the 0.105 version).
f = NaN;
a = a(isfinite(a));
if isempty(a) || numel(a) / nBins < minRatio
    return
end
if median(a) < 0
    a = -a;                   % amplitude_cutoff expects positive amplitudes
end
h = npHistogram(a, nBins);
pdf = fix(gaussianNearest(h, sigma));   % scipy keeps the int64 histogram's type: truncated to whole counts
G = find(pdf >= pdf(1), 1, 'last');
missed = sum(pdf(G+1:end));
f = min(missed / (numel(a) + missed), 0.5);
end


function h = npHistogram(a, nBins)
%npHistogram  numpy.histogram(a, nBins) counts: equal bins from min to max, the last one closed.
first = min(a); last = max(a);
if first == last
    first = first - 0.5; last = last + 0.5;
end
edges = (0:nBins).' * ((last - first) / nBins) + first;   % numpy.linspace
edges(end) = last;
norm = nBins / (last - first);
idx = floor((a - first) * norm);                           % 0-based bin
idx(idx == nBins) = nBins - 1;
dec = a < edges(idx + 1);
idx(dec) = idx(dec) - 1;
inc = a >= edges(idx + 2) & idx ~= nBins - 1;
idx(inc) = idx(inc) + 1;
h = accumarray(idx + 1, 1, [nBins 1]);
end


function y = gaussianNearest(x, sigma)
%gaussianNearest  scipy.ndimage.gaussian_filter1d(x, sigma, mode="nearest"), truncate 4.
%   The weights exp(-x^2 / (2 sigma^2)) over |x| <= floor(4 sigma + 0.5),
%   normalized; each output is the centre weight's term plus the pairs
%   (x(i-j) + x(i+j)) w(j), the outermost pair first, as scipy sums a
%   symmetric filter.
r = fix(4 * sigma + 0.5);
k = (-r:r).';
w = exp(-0.5 / sigma^2 * k.^2);
w = w / sum(w);
n = numel(x);
xp = [repmat(x(1), r, 1); x(:); repmat(x(end), r, 1)];   % "nearest": the edge values repeated
y = zeros(n, 1);
for i = 1:n
    c = i + r;
    acc = xp(c) * w(r + 1);
    for j = r:-1:1
        acc = acc + (xp(c - j) + xp(c + j)) * w(r + 1 - j);
    end
    y(i) = acc;
end
end


function [ptp, sd, md] = drift(s, y, edges, minSpikes, minBins, minValid)
%drift  SpikeInterface's drift metrics for one segment, positions Y of spikes S.
ptp = NaN; sd = NaN; md = NaN;
nb = numel(edges) - 1;
if nb < minBins || isempty(y)
    return
end
if numel(y) ~= numel(s)
    error('unitQualityMetrics:Size', 'A unit has %d spikes but %d positions.', numel(s), numel(y));
end
ref = median(y);
med = nan(nb, 1);
for b = 1:nb
    in = s >= edges(b) & s < edges(b + 1);     % searchsorted(left) bounds: [e_b, e_b+1)
    if nnz(in) >= minSpikes
        med(b) = median(y(in));
    end
end
d = med - ref;
if nnz(isnan(d)) > minValid * nb
    return
end
v = d(~isnan(d));
ptp = max(v) - min(v);
sd = std(v, 1);
md = median(abs(v - median(v)));
end
