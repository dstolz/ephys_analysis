function L = firstSpikeLatency(R, opts)
%firstSpikeLatency  Each epoch's first-spike latency from a spikePSTH result's raster rows, by one of three rules.
%   L = firstSpikeLatency(R, Name=Value) finds, for every epoch (row of
%   R.epochs; R.epochGroup gives each one's trial group) and every unit
%   asked for, the latency of its first response spike in the window
%   [MinSec, MaxSec], in s from the epoch's aligned event. It reads R.raster
%   (spikePSTH with Raster=true, or a result merged across sessions by
%   combineSessions): the very spike times the raster draws, already taken
%   relative to each epoch's event on the spikes' clock (spikePSTH: spike k
%   at (k-1)/Fs, the event at its t0Continuous, so a spike in the event's
%   own sample is at 0), with the stop mask applied when the panel masks
%   after the stop event. Nothing is aligned again here, so a latency and
%   the tick it marks agree. Epochs an artifact period dropped are not in R
%   (epochTable left them out); an epoch with no response spike in the
%   window has NaN. Pure: no I/O, no graphics. A figure computes it once per
%   unit and alignment for every panel that reads it (figureLatencies, from
%   the figure's latency block, defaults("Latency")).
%
%   The search window is [MinSec, MaxSec] with both ends included (within
%   1e-9 s, the rounding of a spike and an event on one sample grid, as
%   binCounts), clipped to the span the raster holds, R.edges([1 end]):
%   the raster keeps spikes in [edges(1), edges(end)), so a MaxSec at or
%   past the window's end means "up to the window's end" (Inf, the
%   default, says so).
%
%   Methods (Method=)
%     "first"     the first spike in the window (the default): exact on a
%                 clean unit, but a spontaneous spike before the response
%                 is taken as the latency
%     "surprise"  the first spike of the first burst in the window whose
%                 Poisson surprise passes Surprise (Legendy & Salcman 1985,
%                 J Neurophysiol 53:926-939). The surprise of n spikes in
%                 the time T from the first to the last is
%                 S = -log10 P(N >= n), N Poisson with mean r*T at the
%                 baseline rate r. A burst starts as MinSpikes consecutive
%                 spikes whose intervals are each under half the baseline's
%                 mean interval (1/(2r)); it takes the following spikes on
%                 while that raises S (looking up to 10 spikes ahead), then
%                 sheds spikes from its start while that raises S. The
%                 scan goes from the window's first spike on, every spike a
%                 possible start, and stops at the first burst with
%                 S >= Surprise; its first spike is the latency
%     "poisson"   the first spike at which the spikes counted since the
%                 window's start are improbable under the baseline rate, in
%                 the manner of Chase & Young 2007 (PNAS 104:5175-5180):
%                 the k-th spike in the window, at t_k, is the latency when
%                 P(N >= k) < Alpha, N Poisson with mean
%                 r*(t_k - MinSec) (MinSec clipped to the raster's span)
%   The baseline rate r (spikes/s) of "surprise" and "poisson" is the
%   spike count in the Baseline window over its length: every epoch's
%   counted together (BaselineRate "unit", the default) or each epoch's own
%   ("trial": an epoch with no baseline spike has r = 0, and then any
%   spike, or any MinSpikes spikes, are improbable: S = Inf, P = 0). The
%   Baseline window is [lo hi) s from the event (lo included), clipped to
%   the raster's span; [] (the default) is the part of the window before
%   the event, [edges(1) 0).
%
%   Options
%     Units         the raster's units (indices into R.raster), default
%                   every one
%     MinSec        the earliest latency, s from the event (default 0)
%     MaxSec        the latest, s (default Inf: the window's end)
%     Method        "first" (default) | "surprise" | "poisson"
%     Baseline      [] (default: before the event) or [lo hi] s
%     BaselineRate  "unit" (default) | "trial"
%     Alpha         "poisson": the improbability a count must reach
%                   (default 0.01)
%     Surprise      "surprise": the least surprise of a burst, -log10 P
%                   (default 3)
%     MinSpikes     "surprise": the fewest spikes a burst starts with
%                   (default 3; at least 2)
%
%   L fields
%     lat         [nEpochs x nUnits] the first response spike's latency, s
%                 (NaN: none)
%     spikeTime   [nEpochs x nUnits] that spike's time on the continuous
%                 clock, lat + R.epochs.t0Continuous (NaN where lat is, or
%                 everywhere when R.epochs has no t0Continuous, as a result
%                 merged across sessions)
%     rate        [nEpochs x nUnits] the baseline rate each epoch was
%                 tested against, spikes/s (NaN with "first")
%     window      [lo hi] the window searched, after clipping
%     baseline    [lo hi] the baseline window counted, after clipping ([]
%                 with "first")
%     method      the method; settings: a struct of Method, MinSec, MaxSec
%                 and the rule's own options as asked (Baseline,
%                 BaselineRate, Alpha or Surprise and MinSpikes)
%     units       the units, as asked (a row)
%     labels      their labels (R.labels; "" without them)
%     epochGroup  [nEpochs x 1] each epoch's group (R.epochGroup)
%     groups      R.groups
%     n           [nGroups x nUnits] the epochs of each group with a
%                 latency
%     nEpochs     [nGroups x 1] the epochs of each group
%
%   Errors: firstSpikeLatency:NoRaster (R holds no raster rows: spikePSTH
%   with Raster=false, or a merged result whose sessions had none),
%   firstSpikeLatency:BadWindow (MinSec > MaxSec, or either not a number),
%   firstSpikeLatency:NoBaseline ("surprise" or "poisson" with a baseline
%   window that holds none of the raster's span, as "before the event"
%   with a window starting at or after it), firstSpikeLatency:BadUnit.
%
%   See also responseOnset, figureLatencies, spikePSTH, rasterInto,
%   drawPsthPanel, combineSessions, poisscdf.

arguments
    R (1,1) struct
    opts.Units double = []
    opts.MinSec (1,1) double = 0
    opts.MaxSec (1,1) double = Inf
    opts.Method (1,1) string {mustBeMember(opts.Method, ["first" "surprise" "poisson"])} = "first"
    opts.Baseline double = []
    opts.BaselineRate (1,1) string {mustBeMember(opts.BaselineRate, ["unit" "trial"])} = "unit"
    opts.Alpha (1,1) double {mustBePositive, mustBeLessThan(opts.Alpha, 1)} = 0.01
    opts.Surprise (1,1) double {mustBePositive} = 3
    opts.MinSpikes (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(opts.MinSpikes, 2)} = 3
end

kept = isfield(R, 'raster') && isfield(R, 'epochGroup') && isfield(R, 'edges');
if kept && isfield(R, 'params') && isstruct(R.params) && isfield(R.params, 'Raster') && ~R.params.Raster
    kept = false;   % spikePSTH(..., Raster=false): the rows are there, empty
end
if kept && isempty(R.raster) && isfield(R, 'rate') && size(R.rate, 2) > 0
    kept = false;   % merged across sessions without the members' rows
end
if ~kept
    error('firstSpikeLatency:NoRaster', ['The result holds no raster rows (R.raster): compute it with ' ...
        'spikePSTH(..., Raster=true).']);
end
lo = opts.MinSec;
hi = opts.MaxSec;
if isnan(lo) || isnan(hi) || lo > hi
    error('firstSpikeLatency:BadWindow', 'The latency window [%g %g] s needs MinSec <= MaxSec.', lo, hi);
end
nU0 = numel(R.raster);
units = reshape(opts.Units, 1, []);
if isempty(opts.Units); units = 1:nU0; end
if any(units < 1 | units > nU0 | units ~= round(units))
    error('firstSpikeLatency:BadUnit', 'Units must be indices of the raster''s %d units.', nU0);
end
W = R.edges([1 end]);
lo = max(lo, W(1));
hi = min(hi, W(2));
tol = 1e-9;   % s: a spike and an event on one sample grid, equal up to rounding (binCounts)
method = opts.Method;
settings = struct('Method', method, 'MinSec', opts.MinSec, 'MaxSec', opts.MaxSec);
B = [];
if method ~= "first"
    B = opts.Baseline;
    if isempty(B); B = [W(1) 0]; end
    B = [max(B(1), W(1)) min(B(end), W(2))];
    if ~(B(2) > B(1))
        error('firstSpikeLatency:NoBaseline', ['The baseline window holds none of the raster''s span [%g %g] s: ' ...
            '"%s" needs a baseline rate (a window with time before the event, or a baseline window inside it).'], ...
            W(1), W(2), method);
    end
    settings.Baseline = opts.Baseline;
    settings.BaselineRate = opts.BaselineRate;
    if method == "poisson"
        settings.Alpha = opts.Alpha;
    else
        settings.Surprise = opts.Surprise;
        settings.MinSpikes = opts.MinSpikes;
    end
end

grp = double(R.epochGroup(:));
nE = numel(grp);
nU = numel(units);
lat = NaN(nE, nU);
rate = NaN(nE, nU);
for k = 1:nU
    t = double(R.raster(units(k)).times(:));
    ep = double(R.raster(units(k)).epoch(:));
    ok = ep >= 1 & ep <= nE & ep == round(ep);
    t = t(ok);
    ep = ep(ok);
    in = t >= lo - tol & t <= hi + tol;
    if method == "first"
        if any(in)
            lat(:, k) = accumarray(ep(in), t(in), [nE 1], @min, NaN);
        end
        continue
    end
    inB = t >= B(1) - tol & t < B(2) - tol;   % [lo hi): the event's own sample is the response's
    cnt = accumarray(ep(inB), 1, [nE 1]);
    if opts.BaselineRate == "unit"
        r = repmat(sum(cnt) / max(1, nE) / diff(B), nE, 1);
    else
        r = cnt / diff(B);
    end
    rate(:, k) = r;
    [es, order] = sortrows([ep(in) t(in)]);   % each epoch's spikes in the window, in time order
    ts = es(:, 2);
    es = es(:, 1);
    if isempty(order); continue; end
    first = [1; find(diff(es) > 0) + 1];
    last = [first(2:end) - 1; numel(es)];
    for i = 1:numel(first)
        e = es(first(i));
        te = ts(first(i):last(i));
        if method == "poisson"
            lat(e, k) = countOnset(te, r(e), lo, opts.Alpha);
        else
            lat(e, k) = burstOnset(te, r(e), opts.MinSpikes, opts.Surprise);
        end
    end
end

spikeTime = NaN(nE, nU);
if isfield(R, 'epochs') && istable(R.epochs) && height(R.epochs) == nE ...
        && ismember('t0Continuous', R.epochs.Properties.VariableNames)
    spikeTime = lat + double(R.epochs.t0Continuous(:));
end

G = [];
if isfield(R, 'groups'); G = R.groups; end
nG = max([0; grp(isfinite(grp))]);
if istable(G); nG = max(nG, height(G)); end
okG = isfinite(grp) & grp >= 1 & grp <= nG & grp == round(grp);
nEpochs = accumarray(grp(okG), 1, [nG 1]);
n = zeros(nG, nU);
for k = 1:nU
    have = okG & isfinite(lat(:, k));
    n(:, k) = accumarray(grp(have), 1, [nG 1]);
end
labels = strings(1, nU);
if isfield(R, 'labels') && numel(R.labels) >= max([units 0]); labels = reshape(string(R.labels(units)), 1, []); end

L = struct('lat', lat, 'spikeTime', spikeTime, 'rate', rate, 'window', [lo hi], 'baseline', B, 'method', method, ...
    'settings', settings, 'units', units, 'labels', labels, 'epochGroup', grp, 'groups', G, 'n', n, 'nEpochs', nEpochs);
end


function t = countOnset(te, r, lo, alpha)
%countOnset  The first spike (of TE, in time order) at which the count since LO is improbable at rate R: P(N >= k) < ALPHA.
t = NaN;
k = (1:numel(te)).';
p = poisscdf(k - 1, r * max(0, te(:) - lo), 'upper');   % P(N >= k), N ~ Poisson(r (t_k - lo))
at = find(p < alpha, 1);
if ~isempty(at); t = te(at); end
end


function t = burstOnset(te, r, minSpikes, thresh)
%burstOnset  The first spike of the first burst of TE (in time order) whose Poisson surprise at rate R reaches THRESH (Legendy & Salcman 1985).
t = NaN;
n = numel(te);
if n < minSpikes; return; end
te = te(:);
short = 1 / (2 * r);   % half the baseline's mean interval (Inf at r = 0: every interval is short)
isi = diff(te);
lookAhead = 10;
for i = 1:n - minSpikes + 1
    if any(isi(i:i + minSpikes - 2) >= short); continue; end   % a seed: MinSpikes spikes, each interval short
    a = i;
    b = i + minSpikes - 1;
    best = surprise(te, a, b, r);
    j = b + 1;
    miss = 0;
    while j <= n && miss < lookAhead   % take the following spikes on while the surprise rises
        s = surprise(te, a, j, r);
        if s > best
            best = s;
            b = j;
            miss = 0;
        else
            miss = miss + 1;
        end
        j = j + 1;
    end
    while b - a + 1 > minSpikes   % shed spikes from the start while that raises it
        s = surprise(te, a + 1, b, r);
        if s > best
            best = s;
            a = a + 1;
        else
            break
        end
    end
    if best >= thresh
        t = te(a);
        return
    end
end
end


function s = surprise(te, a, b, r)
%surprise  The Poisson surprise of spikes A to B of TE at rate R: -log10 P(N >= n), N Poisson with mean R (t_b - t_a).
s = -log10(poisscdf(b - a, r * (te(b) - te(a)), 'upper'));
end
