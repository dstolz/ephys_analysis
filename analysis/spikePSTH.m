function R = spikePSTH(spikeTimes, E, opts)
%spikePSTH  Peri-event time histograms of spike trains, per group.
%   R = spikePSTH(ST, E, Name=Value) bins the spike trains ST ({nUnits x 1}
%   of spike times in s, or one vector) around the epochs of E (epochTable:
%   t0, t0Continuous, t1, groupIndex, group) and averages them per group.
%   Spike times are on the continuous clock ((sample-1)/Fs) and are taken
%   relative to each epoch's t0Continuous, the event on that clock, so a
%   spike in the event's own sample is at 0. Pure: no I/O, no graphics.
%   (Named spikePSTH so it does not shadow Chronux's psth.)
%
%   Options
%     Window         [pre post] s around the event (default [-0.2 0.5])
%     BinSec         bin width, s (default 0.01). Bins are whole multiples
%                    of BinSec from the event, [k, k+1) x BinSec, so the
%                    event is always an edge and no bin mixes spikes from
%                    before and after it; they are half-open (a spike
%                    exactly at a bin's end is in the next one). Window
%                    shrinks to the whole bins inside it (R.window): [-0.25
%                    0.5] in 0.1 s bins is [-0.2 0.5]
%     SmoothSec      Gaussian SD, s, applied to each epoch's rate before
%                    averaging (0 = none; renormalized at the edges)
%     Baseline       [b0 b1] s around the event whose rate is the baseline
%                    (spikes in [b0, b1) from the event, counted directly,
%                    so it may lie outside Window)
%     BaselineMode   "none" (default) | "subtract" (rate - baseline) |
%                    "zscore" ((rate - mean) / SD over the group's epochs) |
%                    "percent" (100 (rate - mean) / mean)
%     MaskAfterStop  drop each epoch's bins from its stop event t1 on (the
%                    mean then covers only the epochs still going)
%     Raster         keep every spike's time for rasters (default true)
%     Groups         the groups table from epochTable (labels, colours);
%                    default: built from E.groupIndex / E.group
%     Meta           unit table (selectUnits); its label names the units
%     Labels         unit labels (default Meta.label, else "u1", ...)
%
%   R fields: kind "psth", t (bin centres, column), edges, window (the span
%   the bins cover, edges([1 end]); params.Window is the one asked for),
%   rate / sem / count [nBins x nUnits x nGroups] (rate and sem in spikes/s
%   or the baseline unit; count = spikes summed over the epochs), nEpochs
%   [nGroups x 1], raster (1 x nUnits struct: times relative to the event,
%   epoch = row of E, group), epochGroup / epochStop [nEpochs x 1] (group
%   and t1 - t0 of every epoch), stopMean [nGroups x 1] mean t1 - t0,
%   baselineRate / baselineSD [nUnits x nGroups], groups, labels, meta, n
%   (= nEpochs), units, params, created.
%
%   Errors: spikePSTH:BadWindow (pre >= post, or no whole bin fits),
%   spikePSTH:BadBaseline.
%
%   See also epochTable, selectUnits, firingRate, renderPSTH, renderRaster.

arguments
    spikeTimes
    E table
    opts.Window (1,2) double = [-0.2 0.5]
    opts.BinSec (1,1) double {mustBePositive} = 0.01
    opts.SmoothSec (1,1) double {mustBeNonnegative} = 0
    opts.Baseline double = []
    opts.BaselineMode (1,1) string {mustBeMember(opts.BaselineMode, ["none" "subtract" "zscore" "percent"])} = "none"
    opts.MaskAfterStop (1,1) logical = false
    opts.Raster (1,1) logical = true
    opts.Groups = []
    opts.Meta = []
    opts.Labels (1,:) string = string.empty(1,0)
end

st = asCell(spikeTimes);
nU = numel(st);
W = opts.Window;
if ~(W(2) > W(1))
    error('spikePSTH:BadWindow', 'Window must be [pre post] with pre < post.');
end
bin = opts.BinSec;
edges = (ceil(W(1) / bin - 1e-9) : floor(W(2) / bin + 1e-9)) * bin;   % whole bins, an edge at the event
nB = numel(edges) - 1;
if nB < 1
    error('spikePSTH:BadWindow', 'Window [%g %g] s holds no whole %g s bin aligned to the event.', W(1), W(2), bin);
end
t = (edges(1:end-1) + edges(2:end)).' / 2;

G = groupsFor(E, opts.Groups);
nG = height(G);
gIdx = E.groupIndex;
nE = height(E);
ta = E.t0Continuous;   % the events on the spikes' clock
stopRel = E.t1 - E.t0;

useBase = opts.BaselineMode ~= "none";
if useBase
    b = opts.Baseline;
    if numel(b) ~= 2 || ~(b(2) > b(1))
        error('spikePSTH:BadBaseline', 'BaselineMode "%s" needs Baseline = [b0 b1] with b0 < b1.', opts.BaselineMode);
    end
end

rate = NaN(nB, nU, nG); sem = NaN(nB, nU, nG); count = zeros(nB, nU, nG);
baseRate = NaN(nU, nG); baseSD = NaN(nU, nG);
raster = struct('times', cell(1, nU), 'epoch', cell(1, nU), 'group', cell(1, nU));
mask = false(nB, nE);
if opts.MaskAfterStop
    for e = 1:nE
        if isfinite(stopRel(e)); mask(:, e) = edges(1:end-1).' >= stopRel(e); end
    end
end
for u = 1:nU
    if opts.Raster
        [c, rel, ep] = binCounts(st{u}, ta, edges);
        keepR = true(size(rel));
        if opts.MaskAfterStop
            keepR = ~(isfinite(stopRel(ep)) & rel >= stopRel(ep));
        end
        raster(u).times = rel(keepR);
        raster(u).epoch = ep(keepR);
        raster(u).group = gIdx(ep(keepR));
    else
        c = binCounts(st{u}, ta, edges);
    end
    r = c / opts.BinSec;
    r(mask) = NaN;
    c(mask) = 0;
    if opts.SmoothSec > 0
        r = gaussianSmooth(r, opts.SmoothSec / opts.BinSec);
    end
    if useBase
        bc = binCounts(st{u}, ta, [b(1) b(2)]);
        br = bc(:) / (b(2) - b(1));
    end
    for g = 1:nG
        cols = gIdx == g;
        if ~any(cols); continue; end
        m = mean(r(:, cols), 2, 'omitnan');
        s = semOf(r(:, cols), 2);
        if useBase
            mu = mean(br(cols));
            sd = std(br(cols));
            baseRate(u, g) = mu;
            baseSD(u, g) = sd;
            switch opts.BaselineMode
                case "subtract"
                    m = m - mu;
                case "zscore"
                    if sd > 0; m = (m - mu) / sd; s = s / sd; else; m(:) = NaN; s(:) = NaN; end
                case "percent"
                    if mu > 0; m = 100 * (m - mu) / mu; s = 100 * s / mu; else; m(:) = NaN; s(:) = NaN; end
            end
        end
        rate(:, u, g) = m;
        sem(:, u, g) = s;
        count(:, u, g) = sum(c(:, cols), 2);
    end
end

nEpochs = accumarray(gIdx, 1, [nG 1]);
stopMean = NaN(nG, 1);
for g = 1:nG
    v = stopRel(gIdx == g);
    if any(isfinite(v)); stopMean(g) = mean(v, 'omitnan'); end
end

R = struct();
R.kind = "psth";
R.t = t;
R.edges = edges;
R.window = edges([1 end]);
R.rate = rate;
R.sem = sem;
R.count = count;
R.nEpochs = nEpochs;
R.raster = raster;
R.epochGroup = gIdx;
R.epochStop = stopRel;
R.stopMean = stopMean;
R.baselineRate = baseRate;
R.baselineSD = baseSD;
R.groups = G;
R.labels = unitLabels(nU, opts.Labels, opts.Meta);
R.meta = opts.Meta;
R.n = nEpochs;
switch opts.BaselineMode
    case "none",     R.units = "spikes/s";
    case "subtract", R.units = "spikes/s - baseline";
    case "zscore",   R.units = "z (baseline)";
    case "percent",  R.units = "% change from baseline";
end
R.params = struct('Window', W, 'BinSec', opts.BinSec, 'SmoothSec', opts.SmoothSec, ...
    'Baseline', opts.Baseline, 'BaselineMode', opts.BaselineMode, 'MaskAfterStop', opts.MaskAfterStop, ...
    'Raster', opts.Raster);
R.created = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end


function st = asCell(x)
if iscell(x)
    st = reshape(x, [], 1);
else
    st = {x};
end
end
