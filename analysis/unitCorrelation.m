function R = unitCorrelation(spikeTimes, E, opts)
%unitCorrelation  Correlation of every pair of units' per-epoch responses, per group.
%   R = unitCorrelation(ST, E, Name=Value) measures each unit's response in
%   every epoch window of E (epochTable: [tStart, tStop), so "between"
%   epochs have their own lengths) and correlates the units pairwise over
%   the epochs of each group: an [nUnits x nUnits] matrix per group (the
%   trial-to-trial covariation of the units' responses). ST is {nUnits x 1}
%   spike times, s, on the continuous clock; the windows are moved to it
%   by t0Continuous - t0 (see epochTable). Pure: no I/O, no graphics.
%
%   Options
%     Metric         "mean" (default): spikes in the window / its length |
%                    "peak": the largest binned rate in the window (bins of
%                    BinSec from tStart, smoothed by SmoothSec; a bin that
%                    runs past tStop is not used). With windows of different
%                    lengths ("between" epochs) only the first nB bins of
%                    every window are searched, nB the whole bins of the
%                    shortest window that holds one (R.peakBins): a longer
%                    window has more bins to take a maximum over, so its
%                    peak would grow with its length
%     Type           "pearson" (default) | "spearman" (Pearson of the ranks,
%                    ties averaged)
%     Detrend        true (default) | false: before correlating, subtract
%                    from each unit's responses their moving mean over k
%                    epochs of the group in time order (movmean, k about 20%
%                    of the group's epochs, odd, at least 5; omitting NaN),
%                    so two units whose rates drift slowly over the session
%                    (anesthesia, adaptation) do not correlate through the
%                    drift. R.response keeps the responses as measured; r, p
%                    and q are those of the detrended ones (p assumes n-2
%                    degrees of freedom, which the detrending lowers a bit)
%     FisherZ        false (default) | true: also give Fisher's z = atanh(r)
%                    (R.z) and take the mean over the pairs in z, back-
%                    transformed (meanR = tanh(mean z)): r is bounded and
%                    skewed near +-1, z is not. Diagonals of z are NaN.
%     BinSec         bin width for "peak", s (default 0.01)
%     SmoothSec      Gaussian SD for "peak", s (0 = none, the default)
%     Baseline       [b0 b1] s around the event: the baseline window of
%                    each epoch
%     BaselineMode   "none" (default) | "subtract" (each epoch's response
%                    minus its own baseline rate; scaling a unit's
%                    responses would not change a correlation)
%     Groups, Meta, Labels   as in spikePSTH
%
%   An epoch whose response is not finite (a window shorter than one bin)
%   is left out of its group. A unit whose responses do not vary has NaN
%   correlations; so does every pair of a group with fewer than 3 epochs.
%
%   R fields: kind "corrmap", r / p / q [nUnits x nUnits x nGroups] (z, with
%   FisherZ; fisherZ: the option; p: two-sided,
%   from t = r sqrt((n-2) / (1-r^2)) with n-2 degrees of freedom; for
%   Spearman an approximation; q: p adjusted for the group's pairs of units
%   by Benjamini-Hochberg, pAdjust(p, "bh") over each group's off-diagonal
%   pairs, each pair once; the diagonal is NaN), detrend (the option),
%   peakBins (nB, "peak" only, else NaN), meanR [nGroups x 1] (mean over the pairs),
%   nEpochs [nGroups x 1] (epochs used), response [nEpochs x nUnits] (after
%   BaselineMode), epochIndex (E.epoch), groupIndex, groups, labels, meta,
%   n (= nEpochs), metric, type, units (of the response), params, created.
%
%   See also epochTable, selectUnits, firingRate, spikePSTH, renderCorrMap.

arguments
    spikeTimes
    E table
    opts.Metric (1,1) string {mustBeMember(opts.Metric, ["mean" "peak"])} = "mean"
    opts.Type (1,1) string {mustBeMember(opts.Type, ["pearson" "spearman"])} = "pearson"
    opts.FisherZ (1,1) logical = false
    opts.Detrend (1,1) logical = true
    opts.BinSec (1,1) double {mustBePositive} = 0.01
    opts.SmoothSec (1,1) double {mustBeNonnegative} = 0
    opts.Baseline double = []
    opts.BaselineMode (1,1) string {mustBeMember(opts.BaselineMode, ["none" "subtract"])} = "none"
    opts.Groups = []
    opts.Meta = []
    opts.Labels (1,:) string = string.empty(1,0)
end

if iscell(spikeTimes); st = reshape(spikeTimes, [], 1); else; st = {spikeTimes}; end
nU = numel(st);
nE = height(E);
G = groupsFor(E, opts.Groups);
nG = height(G);
gIdx = E.groupIndex;
b = opts.Baseline;
useBase = opts.BaselineMode ~= "none";
if useBase && (numel(b) ~= 2 || ~(b(2) > b(1)))
    error('unitCorrelation:BadBaseline', 'BaselineMode "%s" needs Baseline = [b0 b1] with b0 < b1.', opts.BaselineMode);
end

dur = round((E.tStop - E.tStart) * 1e9) / 1e9;   % to the ns: equal windows give equal rates (ties, constant units)
nB = NaN;
if opts.Metric == "peak"
    nWhole = floor(dur / opts.BinSec + 1e-9);   % whole bins in each window
    usable = nWhole >= 1;                       % a shorter window has no response
    if ~any(usable)
        error('unitCorrelation:BadWindow', 'Every epoch window is shorter than one %g s bin.', opts.BinSec);
    end
    nB = min(nWhole(usable));   % the same bins for every window: a longer one would have more to take the peak over
    edges = (0:nB) * opts.BinSec;
    whole = repmat(usable.', nB, 1);   % [nBins x nEpochs]
end
shift = E.t0Continuous - E.t0;   % the digital-event clock -> the spikes' clock
wStart = E.tStart + shift;
wStop = E.tStop + shift;
resp = NaN(nE, nU);
for u = 1:nU
    s = sort(double(st{u}(:)));
    if opts.Metric == "mean"
        resp(:, u) = (countBelow(s, wStop) - countBelow(s, wStart)) ./ dur;
    else
        r = binCounts(s, wStart, edges) / opts.BinSec;
        r(~whole) = NaN;
        r = gaussianSmooth(r, opts.SmoothSec / opts.BinSec);
        resp(:, u) = max(r, [], 1, 'omitnan').';
    end
    if useBase
        base = (countBelow(s, E.t0Continuous + b(2)) - countBelow(s, E.t0Continuous + b(1))) / (b(2) - b(1));
        resp(:, u) = resp(:, u) - base;
    end
end
resp(~isfinite(resp)) = NaN;

rho = NaN(nU, nU, nG); p = NaN(nU, nU, nG);
nUsed = zeros(nG, 1); meanR = NaN(nG, 1);
off = ~eye(nU);
for g = 1:nG
    rows = find(gIdx == g);
    X = resp(rows, :);
    if opts.Detrend
        X = detrendTrials(X, E.t0Continuous(rows));
    end
    X = X(all(isfinite(X), 2), :);
    n = size(X, 1);
    nUsed(g) = n;
    if n < 3; continue; end
    if opts.Type == "spearman"; X = rankColumns(X); end
    [rho(:, :, g), p(:, :, g)] = pearson(X);
    v = rho(:, :, g);
    v = v(off & isfinite(v));
    if ~isempty(v)
        if opts.FisherZ
            meanR(g) = tanh(mean(atanh(max(min(v, 1 - eps), -1 + eps))));   % r = +-1 off the diagonal would be Inf
        else
            meanR(g) = mean(v);
        end
    end
end

q = NaN(nU, nU, nG);   % Benjamini-Hochberg over each group's pairs of units, each pair once
[ia, ib] = find(triu(true(nU), 1));
fwd = sub2ind([nU nU], ia, ib);
bwd = sub2ind([nU nU], ib, ia);
for g = 1:nG
    pg = p(:, :, g);
    qg = NaN(nU);
    qq = pAdjust(pg(fwd), "bh");
    qg(fwd) = qq;
    qg(bwd) = qq;
    q(:, :, g) = qg;
end

R = struct();
R.kind = "corrmap";
R.r = rho;
R.p = p;
R.q = q;
R.fisherZ = opts.FisherZ;
R.detrend = opts.Detrend;
R.peakBins = nB;
if opts.FisherZ
    z = atanh(max(min(rho, 1 - eps), -1 + eps));
    z(repmat(eye(nU) ~= 0, 1, 1, nG)) = NaN;
    z(~isfinite(rho)) = NaN;
    R.z = z;
end
R.meanR = meanR;
R.nEpochs = nUsed;
R.response = resp;
R.epochIndex = E.epoch;
R.groupIndex = gIdx;
R.groups = G;
R.labels = unitLabels(nU, opts.Labels, opts.Meta);
R.meta = opts.Meta;
R.n = nUsed;
R.metric = opts.Metric;
R.type = opts.Type;
R.units = "spikes/s";
if useBase; R.units = "spikes/s - baseline"; end
R.params = struct('Metric', opts.Metric, 'Type', opts.Type, 'FisherZ', opts.FisherZ, 'Detrend', opts.Detrend, 'BinSec', opts.BinSec, 'SmoothSec', opts.SmoothSec, ...
    'Baseline', b, 'BaselineMode', opts.BaselineMode);
R.created = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end


function X = detrendTrials(X, t)
%detrendTrials  Subtract each column's moving mean over k epochs in time order (NaN ignored).
%   k is about 20% of the epochs, odd and at least 5. A column that does not
%   vary stays constant (zero), not rounding noise from the moving mean.
n = size(X, 1);
if n < 2; return; end
k = max(5, round(0.2 * n));
k = k + (mod(k, 2) == 0);
[~, ord] = sort(t);
Xs = X(ord, :);
flat = max(Xs, [], 1, 'omitnan') == min(Xs, [], 1, 'omitnan');
Xd = Xs - movmean(Xs, k, 1, 'omitnan');
Xd(isfinite(Xs) & flat) = 0;
X(ord, :) = Xd;
end


function [r, p] = pearson(X)
%pearson  Pearson correlation of the columns of X and two-sided p values (no toolbox).
n = size(X, 1);
Xc = X - mean(X, 1);
ss = sqrt(sum(Xc .^ 2, 1));
r = (Xc.' * Xc) ./ (ss.' * ss);
flat = ss <= eps(max(abs(X), [], 1)) * n;   % a unit whose responses do not vary
r(flat, :) = NaN;
r(:, flat) = NaN;
r(r > 1) = 1;     % not min / max: they would turn NaN into +-1
r(r < -1) = -1;
d = find(~flat);
r(sub2ind(size(r), d, d)) = 1;
df = n - 2;
ok = isfinite(r);
t2 = r(ok) .^ 2 * df ./ max(1 - r(ok) .^ 2, 0);
p = NaN(size(r));
p(ok) = betainc(df ./ (df + t2), df / 2, 0.5);
p(logical(eye(size(r)))) = NaN;
end


function Q = rankColumns(X)
%rankColumns  Ranks down each column, tied values given their mean rank.
[n, m] = size(X);
Q = zeros(n, m);
for j = 1:m
    [v, ord] = sort(X(:, j));
    rk = (1:n).';
    k = 1;
    while k <= n
        e = k;
        while e < n && v(e + 1) == v(k); e = e + 1; end
        rk(k:e) = (k + e) / 2;
        k = e + 1;
    end
    Q(ord, j) = rk;
end
end
