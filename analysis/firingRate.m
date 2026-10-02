function R = firingRate(spikeTimes, E, opts)
%firingRate  Firing rate of each unit in each epoch window, and per group.
%   R = firingRate(ST, E, Name=Value) counts the spikes of every train in ST
%   ({nUnits x 1} spike times, s) inside each epoch window of E (epochTable:
%   [tStart, tStop), so "between" epochs have their own lengths) and
%   divides by the window's length. The windows are moved to the spikes'
%   continuous clock first, by t0Continuous - t0 (see epochTable), so a
%   spike in the event's own sample is at the event. Pure: no I/O, no
%   graphics.
%
%   Options
%     Measure     "rate" (default, spikes/s) | "count" (spikes per epoch
%                 window) | "probability" (1 for an epoch with at least one
%                 spike in its window, else 0: a group's mean is the share of
%                 its epochs with a spike). The baseline window is measured
%                 the same way
%     Baseline    [b0 b1] s around the event: the baseline window of each
%                 epoch ([] = none)
%     Normalize   "none" (default) | "subtract" (value - that epoch's
%                 baseline) | "ratio" (value / the unit's mean baseline) |
%                 "zscore" ((value - mean baseline) / SD of the baseline over
%                 all epochs)
%     Groups, Meta, Labels   as in spikePSTH
%
%   R fields: kind "rate", measure, rate / count [nEpochs x nUnits] (the
%   Measure's value after Normalize, count raw), rawRate (before Normalize),
%   duration [nEpochs x 1], baseline [nEpochs x nUnits] (the baseline's
%   value per epoch, NaN without Baseline),
%   meanRate / sem / median [nUnits x nGroups], baselineRate [nUnits x
%   nGroups], epochIndex (E.epoch), groupIndex, groups, labels, meta, n
%   (epochs per group), units, params, created.
%
%   See also epochTable, selectUnits, tuningCurve, renderRates.

arguments
    spikeTimes
    E table
    opts.Measure (1,1) string {mustBeMember(opts.Measure, ["rate" "count" "probability"])} = "rate"
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
shift = E.t0Continuous - E.t0;   % the digital-event clock -> the spikes' clock
count = zeros(nE, nU);
base = NaN(nE, nU);
for u = 1:nU
    s = sort(double(st{u}(:)));
    count(:, u) = countIn(s, E.tStart + shift, E.tStop + shift);
    if useBase
        base(:, u) = countIn(s, E.t0Continuous + b(1), E.t0Continuous + b(2));
    end
end
switch opts.Measure
    case "rate"
        raw = count ./ dur;
        if useBase; base = base / (b(2) - b(1)); end
        unit = "spikes/s";
    case "count"
        raw = count;
        unit = "spikes/window";
    case "probability"
        raw = double(count > 0);
        raw(~isfinite(count)) = NaN;
        none = isnan(base);
        base = double(base > 0);
        base(none) = NaN;
        unit = "P(spike)/window";
end
switch opts.Normalize
    case "none",     rate = raw; units = unit;
    case "subtract", rate = raw - base; units = unit + " - baseline";
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
R.measure = opts.Measure;
R.params = struct('Measure', opts.Measure, 'Baseline', b, 'Normalize', opts.Normalize);
R.created = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end


function c = countIn(s, a, b)
%countIn  Spikes in [a, b) for each row (s sorted; NaN where a or b is not finite).
c = countBelow(s, b) - countBelow(s, a);
end