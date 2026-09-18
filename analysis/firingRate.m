function R = firingRate(spikeTimes, E, opts)
%firingRate  Firing rate of each unit in each epoch window, and per group.
%   R = firingRate(ST, E, Name=Value) counts the spikes of every train in ST
%   ({nUnits x 1} spike times, s) inside each epoch window of E (epochTable:
%   [tStart, tStop), so "between" epochs have their own lengths) and
%   divides by the window's length. Pure: no I/O, no graphics.
%
%   Options
%     Baseline    [b0 b1] s around t0: the baseline window of each epoch
%                 ([] = none)
%     Normalize   "none" (default) | "subtract" (rate - that epoch's
%                 baseline rate) | "ratio" (rate / the unit's mean baseline
%                 rate) | "zscore" ((rate - mean baseline) / SD of the
%                 baseline over all epochs)
%     Groups, Meta, Labels   as in spikePSTH
%
%   R fields: kind "rate", rate / count [nEpochs x nUnits] (rate after
%   Normalize, count raw), rawRate, duration [nEpochs x 1], baseline
%   [nEpochs x nUnits] (baseline rate per epoch, NaN without Baseline),
%   meanRate / sem / median [nUnits x nGroups], baselineRate [nUnits x
%   nGroups], epochIndex (E.epoch), groupIndex, groups, labels, meta, n
%   (epochs per group), units, params, created.
%
%   See also epochTable, selectUnits, tuningCurve, renderRates.

arguments
    spikeTimes
    E table
    opts.Baseline double = []
    opts.Normalize (1,1) string {mustBeMember(opts.Normalize, ["none" "subtract" "ratio" "zscore"])} = "none"
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
useBase = ~isempty(b);
if useBase && (numel(b) ~= 2 || ~(b(2) > b(1)))
    error('firingRate:BadBaseline', 'Baseline must be [b0 b1] with b0 < b1.');
end
if opts.Normalize ~= "none" && ~useBase
    error('firingRate:BadBaseline', 'Normalize "%s" needs a Baseline window.', opts.Normalize);
end

dur = E.tStop - E.tStart;
count = zeros(nE, nU);
base = NaN(nE, nU);
for u = 1:nU
    s = sort(double(st{u}(:)));
    count(:, u) = countIn(s, E.tStart, E.tStop);
    if useBase
        base(:, u) = countIn(s, E.t0 + b(1), E.t0 + b(2)) / (b(2) - b(1));
    end
end
raw = count ./ dur;
switch opts.Normalize
    case "none",     rate = raw; units = "spikes/s";
    case "subtract", rate = raw - base; units = "spikes/s - baseline";
    case "ratio",    rate = raw ./ mean(base, 1, 'omitnan'); units = "x baseline";
    case "zscore",   rate = (raw - mean(base, 1, 'omitnan')) ./ std(base, 0, 1, 'omitnan'); units = "z (baseline)";
end
rate(~isfinite(rate)) = NaN;

meanRate = NaN(nU, nG); sem = NaN(nU, nG); med = NaN(nU, nG); baseRate = NaN(nU, nG);
for g = 1:nG
    rows = gIdx == g;
    if ~any(rows); continue; end
    meanRate(:, g) = mean(rate(rows, :), 1, 'omitnan').';
    sem(:, g) = semOf(rate(rows, :), 1).';
    med(:, g) = median(rate(rows, :), 1, 'omitnan').';
    if useBase; baseRate(:, g) = mean(base(rows, :), 1, 'omitnan').'; end
end

R = struct();
R.kind = "rate";
R.rate = rate;
R.count = count;
R.rawRate = raw;
R.duration = dur;
R.baseline = base;
R.meanRate = meanRate;
R.sem = sem;
R.median = med;
R.baselineRate = baseRate;
R.epochIndex = E.epoch;
R.groupIndex = gIdx;
R.groups = G;
R.labels = unitLabels(nU, opts.Labels, opts.Meta);
R.meta = opts.Meta;
R.n = accumarray(gIdx, 1, [nG 1]);
R.units = units;
R.params = struct('Baseline', b, 'Normalize', opts.Normalize);
R.created = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end


function c = countIn(s, a, b)
%countIn  Spikes in [a, b) for each row (s sorted; NaN where a or b is not finite).
c = countBelow(s, b) - countBelow(s, a);
end