function R = unitCorrelation(spikeTimes, E, opts)
%unitCorrelation  Correlation of every pair of units' per-epoch responses, per group.
%   R = unitCorrelation(ST, E, Name=Value) measures each unit's response in
%   every epoch window of E (epochTable: [tStart, tStop), so "between"
%   epochs have their own lengths) and correlates the units pairwise over
%   the epochs of each group: an [nUnits x nUnits] matrix per group (the
%   trial-to-trial covariation of the units' responses). ST is {nUnits x 1}
%   spike times, s. Pure: no I/O, no graphics.
%
%   Options
%     Metric         "mean" (default): spikes in the window / its length |
%                    "peak": the largest binned rate in the window (bins of
%                    BinSec from tStart, smoothed by SmoothSec; a bin that
%                    runs past tStop is not used)
%     Type           "pearson" (default) | "spearman" (Pearson of the ranks,
%                    ties averaged)
%     BinSec         bin width for "peak", s (default 0.01)
%     SmoothSec      Gaussian SD for "peak", s (0 = none, the default)
%     Baseline       [b0 b1] s around t0: the baseline window of each epoch
%     BaselineMode   "none" (default) | "subtract" (each epoch's response
%                    minus its own baseline rate; scaling a unit's
%                    responses would not change a correlation)
%     Groups, Meta, Labels   as in spikePSTH
%
%   An epoch whose response is not finite (a window shorter than one bin)
%   is left out of its group. A unit whose responses do not vary has NaN
%   correlations; so does every pair of a group with fewer than 3 epochs.
%
%   R fields: kind "corrmap", r / p [nUnits x nUnits x nGroups] (p: two-sided,
%   from t = r sqrt((n-2) / (1-r^2)) with n-2 degrees of freedom; for
%   Spearman an approximation), meanR [nGroups x 1] (mean over the pairs),
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
if opts.Metric == "peak"
    nB = floor(max([dur; 0]) / opts.BinSec + 1e-9);
    if nB < 1
        error('unitCorrelation:BadWindow', 'Every epoch window is shorter than one %g s bin.', opts.BinSec);
    end
    edges = (0:nB) * opts.BinSec;
    whole = edges(2:end).' <= dur.' + 1e-9;   % [nBins x nEpochs]: bins inside each window
end
resp = NaN(nE, nU);
for u = 1:nU
    s = sort(double(st{u}(:)));
    if opts.Metric == "mean"
        resp(:, u) = (countBelow(s, E.tStop) - countBelow(s, E.tStart)) ./ dur;
    else
        r = binCounts(s, E.tStart, edges) / opts.BinSec;
        r(~whole) = NaN;
        r = gaussianSmooth(r, opts.SmoothSec / opts.BinSec);
        resp(:, u) = max(r, [], 1, 'omitnan').';
    end
    if useBase
        base = (countBelow(s, E.t0 + b(2)) - countBelow(s, E.t0 + b(1))) / (b(2) - b(1));
        resp(:, u) = resp(:, u) - base;
    end
end
resp(~isfinite(resp)) = NaN;

rho = NaN(nU, nU, nG); p = NaN(nU, nU, nG);
nUsed = zeros(nG, 1); meanR = NaN(nG, 1);
off = ~eye(nU);
for g = 1:nG
    X = resp(gIdx == g, :);
    X = X(all(isfinite(X), 2), :);
    n = size(X, 1);
    nUsed(g) = n;
    if n < 3; continue; end
    if opts.Type == "spearman"; X = rankColumns(X); end
    [rho(:, :, g), p(:, :, g)] = pearson(X);
    v = rho(:, :, g);
    v = v(off & isfinite(v));
    if ~isempty(v); meanR(g) = mean(v); end
end

R = struct();
R.kind = "corrmap";
R.r = rho;
R.p = p;
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
R.params = struct('Metric', opts.Metric, 'Type', opts.Type, 'BinSec', opts.BinSec, 'SmoothSec', opts.SmoothSec, ...
    'Baseline', b, 'BaselineMode', opts.BaselineMode);
R.created = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
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
