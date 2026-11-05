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
%     Measure        what each bin holds: "rate" (default, spikes/s) |
%                    "count" (spikes per bin per epoch) | "probability" (the
%                    share of epochs with at least one spike in the bin)
%     Baseline       [b0 b1] s around the event whose measure is the baseline
%                    (spikes in [b0, b1) from the event, counted directly,
%                    so it may lie outside Window; "probability" uses whole
%                    BinSec bins from b0)
%     BaselineMode   "none" (default) | "subtract" (rate - baseline) |
%                    "zscore" ((rate - mean) / SD, both over the baseline's
%                    whole BinSec bins of the group's trial-averaged PSTH,
%                    the definition of epochMatrixNormalize's "zscore": the
%                    SD does not depend on the baseline's length; the
%                    baseline needs at least two whole bins) |
%                    "percent" (100 (rate - mean) / mean) | "auroc" (each
%                    window's auROC against the baseline, 0 to 1:
%                    aurocCurves with Auroc's settings; see below)
%     Auroc          BaselineMode "auroc": EphysAnalysisConfig.defaults(
%                    "Auroc") fields (method, windows, windowSec, stepSec,
%                    modulationWindow, cutoff, threshold, test, nResamples,
%                    correction, alpha, modulatedOnly; marks is for the
%                    renderers); missing ones take their defaults
%     MaskAfterStop  drop each epoch's bins from its stop event t1 on, the
%                    bin the stop falls inside included (its count covers
%                    only part of the bin, so its rate would read low), and
%                    the raster's spikes from the stop on (the mean then
%                    covers only the epochs still going)
%     Raster         keep every spike's time for rasters (default true)
%     Groups         the groups table from epochTable (labels, colors);
%                    default: built from E.groupIndex / E.group
%     Meta           unit table (selectUnits); its label names the units
%     Labels         unit labels (default Meta.label, else "u1", ...)
%     Check          a function handle called with no input before each unit
%                    (default []); it may throw to stop (the app's Cancel
%                    button). Passed on to aurocCurves
%     ErrorType      the error band around each PSTH, over the group's
%                    epochs (errorBounds): "sem" (default, mean +/- SEM),
%                    "std" (mean +/- SD) or "ci95" (a bootstrap 95% CI of
%                    the mean, percentile; ErrorResamples resamples of the
%                    epochs, default 1000). A baseline mode turns the band's
%                    edges as it turns the mean (the baseline itself is not
%                    resampled)
%
%   R fields: kind "psth", t (bin centers, column), edges, window (the span
%   the bins cover, edges([1 end]); params.Window is the one asked for),
%   rate / sem / count [nBins x nUnits x nGroups] (rate and sem in the
%   Measure's unit, or the baseline's; count = spikes summed over the
%   epochs), rateUnsmoothed [nBins x nUnits x nGroups] (rate without
%   SmoothSec: the mean of the unsmoothed epochs, turned by the baseline as
%   rate is; rate itself when SmoothSec is 0 or with "auroc"; a PSTH
%   panel's smoothed line smooths it on its own), measure, nEpochs
%   [nGroups x 1], raster (1 x nUnits struct: times relative to the event,
%   epoch = row of E, group), epochGroup / epochStop [nEpochs x 1] (group
%   and t1 - t0 of every epoch), stopMean [nGroups x 1] mean t1 - t0,
%   baselineRate [nUnits x nGroups] (the baseline's mean: spikes counted in
%   [b0, b1), for "zscore" the mean of the whole bins) and baselineSD
%   (the SD of the group's trial-averaged baseline bins, unsmoothed; NaN
%   with fewer than two whole bins), groups, labels, meta, n
%   (= nEpochs), units, params, auroc ([] but with BaselineMode "auroc"),
%   err (the error band: type, lo / hi [nBins x nUnits x nGroups], over
%   "epochs", nBoot; R.rate +/- R.sem for "sem"), created.
%
%   With BaselineMode "auroc" the curves are aurocCurves': t, edges and
%   window are the auROC windows' (centers; boundaries; the span they
%   cover), rate is the auROC [nWindows x nUnits x nGroups] (units
%   "auROC"), sem and err's lo / hi are NaN, count the spikes in each window, and
%   baselineRate / baselineSD are NaN. SmoothSec is not used: the auROC
%   compares the bins as counted. R.auroc holds the rest of aurocCurves'
%   result (starts, stops, inModulation, mean, phasic, p, q, direction,
%   modulated, cutoff, cutoffValue, nModulated, nIncrease, nDecrease,
%   nUnits (the units tested), baseline, modulationWindow, method,
%   windows, params, toolbox) and settings (Auroc, normalized). With
%   Auroc.modulatedOnly only the units modulated in at least one group are
%   kept (every per-unit field follows; the counts stay those of every
%   unit tested).
%
%   Errors: spikePSTH:BadWindow (pre >= post, or no whole bin fits),
%   spikePSTH:BadBaseline, spikePSTH:NoneModulated (modulatedOnly and no
%   unit is), and aurocCurves'.
%
%   See also epochTable, selectUnits, firingRate, figureCompute, renderFigure.

arguments
    spikeTimes
    E table
    opts.Window (1,2) double = [-0.2 0.5]
    opts.BinSec (1,1) double {mustBePositive} = 0.01
    opts.Measure (1,1) string {mustBeMember(opts.Measure, ["rate" "count" "probability"])} = "rate"
    opts.SmoothSec (1,1) double {mustBeNonnegative} = 0
    opts.Baseline double = []
    opts.BaselineMode (1,1) string {mustBeMember(opts.BaselineMode, ["none" "subtract" "zscore" "percent" "auroc"])} = "none"
    opts.Auroc = struct()
    opts.MaskAfterStop (1,1) logical = false
    opts.Raster (1,1) logical = true
    opts.Groups = []
    opts.Meta = []
    opts.Labels (1,:) string = string.empty(1,0)
    opts.Check = []
    opts.ErrorType (1,1) string {mustBeMember(opts.ErrorType, ["sem" "std" "ci95"])} = "sem"
    opts.ErrorResamples (1,1) double {mustBePositive, mustBeInteger} = 1000
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

isAuroc = opts.BaselineMode == "auroc";
useBase = opts.BaselineMode ~= "none" && ~isAuroc;
if opts.BaselineMode ~= "none"
    b = opts.Baseline;
    if numel(b) ~= 2 || ~(b(2) > b(1))
        error('spikePSTH:BadBaseline', 'BaselineMode "%s" needs Baseline = [b0 b1] with b0 < b1.', opts.BaselineMode);
    end
end
if useBase
    baseEdges = b(1) + (0:floor((b(2) - b(1)) / bin + 1e-9)) * bin;   % the baseline's whole bins from b0
    if opts.Measure == "probability" && numel(baseEdges) < 2
        error('spikePSTH:BadBaseline', 'A probability baseline needs a whole %g s bin: [%g %g] is shorter.', bin, b(1), b(2));
    end
    if opts.BaselineMode == "zscore" && numel(baseEdges) < 3
        error('spikePSTH:BadBaseline', ['BaselineMode "zscore" takes the SD over the baseline''s whole %g s bins, so it needs ' ...
            'at least two of them: [%g %g] holds %d.'], bin, b(1), b(2), numel(baseEdges) - 1);
    end
end

rate = NaN(nB, nU, nG); sem = NaN(nB, nU, nG); count = zeros(nB, nU, nG);
errLo = NaN(nB, nU, nG); errHi = NaN(nB, nU, nG);
smoothed = opts.SmoothSec > 0 && ~isAuroc;   % the means without SmoothSec are kept too (R.rateUnsmoothed)
rate0 = [];
if smoothed; rate0 = NaN(nB, nU, nG); end
baseRate = NaN(nU, nG); baseSD = NaN(nU, nG);
raster = struct('times', cell(1, nU), 'epoch', cell(1, nU), 'group', cell(1, nU));
mask = false(nB, nE);
if opts.MaskAfterStop   % the bins reaching past the stop (a bin the stop falls inside counts only part of its width)
    mask = isfinite(stopRel).' & edges(2:end).' > stopRel.' + 1e-9;
end
batchCI = opts.ErrorType == "ci95" && ~isAuroc;   % the bootstrap bands of all the units at once, after the loop (errorBounds)
rAll = [];
if batchCI; rAll = NaN(nB, nE, nU); end
for u = 1:nU
    if ~isempty(opts.Check); opts.Check(); end
    if opts.Raster
        [c, rel, ep] = binCounts(st{u}, ta, edges);
        keepR = true(size(rel));
        if opts.MaskAfterStop
            keepR = ~(isfinite(stopRel(ep)) & rel >= stopRel(ep) - 1e-9);   % the spikes from the stop on
        end
        raster(u).times = rel(keepR);
        raster(u).epoch = ep(keepR);
        raster(u).group = gIdx(ep(keepR));
    elseif ~isAuroc
        c = binCounts(st{u}, ta, edges);
    end
    if isAuroc; continue; end   % aurocCurves below
    switch opts.Measure
        case "rate",        r = c / opts.BinSec;
        case "count",       r = c;
        case "probability", r = double(c > 0);
    end
    r(mask) = NaN;
    c(mask) = 0;
    r0 = r;   % the epochs' unsmoothed rates (rate0)
    if smoothed
        r = gaussianSmooth(r, opts.SmoothSec / opts.BinSec);
    end
    if batchCI; rAll(:, :, u) = r; end
    if useBase
        bb = [];   % the baseline's whole bins, [nBaseBins x nE], in the Measure's unit
        if numel(baseEdges) >= 2
            bc = binCounts(st{u}, ta, baseEdges);
            switch opts.Measure
                case "rate",        bb = bc / opts.BinSec;
                case "count",       bb = bc;
                case "probability", bb = double(bc > 0);
            end
        end
        switch opts.Measure
            case "rate"
                bc = binCounts(st{u}, ta, [b(1) b(2)]);
                br = bc(:) / (b(2) - b(1));
            case "count"
                bc = binCounts(st{u}, ta, [b(1) b(2)]);
                br = bc(:) / (b(2) - b(1)) * opts.BinSec;   % spikes per bin
            case "probability"
                br = mean(bb, 1, 'omitnan').';
        end
    end
    for g = 1:nG
        cols = gIdx == g;
        if ~any(cols); continue; end
        m = mean(r(:, cols), 2, 'omitnan');
        s = semOf(r(:, cols), 2);
        if batchCI
            lo = NaN(nB, 1); hi = lo;   % bootstrapped below, for all the units at once
        else
            [lo, hi] = errorBounds(r(:, cols), 2, opts.ErrorType, opts.ErrorResamples);
        end
        if useBase
            mu = mean(br(cols));
            sd = NaN;
            if size(bb, 1) >= 2   % mean and SD over the bins of the group's trial-averaged baseline, as epochMatrixNormalize
                trace = mean(bb(:, cols), 2);
                sd = std(trace);
                if opts.BaselineMode == "zscore"; mu = mean(trace); end
            end
            baseRate(u, g) = mu;
            baseSD(u, g) = sd;
            switch opts.BaselineMode
                case "subtract"
                    m = m - mu; lo = lo - mu; hi = hi - mu;
                case "zscore"
                    if sd > 0
                        m = (m - mu) / sd; s = s / sd; lo = (lo - mu) / sd; hi = (hi - mu) / sd;
                    else
                        m(:) = NaN; s(:) = NaN; lo(:) = NaN; hi(:) = NaN;
                    end
                case "percent"
                    if mu > 0
                        m = 100 * (m - mu) / mu; s = 100 * s / mu; lo = 100 * (lo - mu) / mu; hi = 100 * (hi - mu) / mu;
                    else
                        m(:) = NaN; s(:) = NaN; lo(:) = NaN; hi(:) = NaN;
                    end
            end
        end
        if smoothed   % the group's unsmoothed mean, turned by the baseline as the mean is
            m0 = mean(r0(:, cols), 2, 'omitnan');
            if useBase; m0 = bandAs(m0, opts.BaselineMode, mu, sd); end
            rate0(:, u, g) = m0;
        end
        rate(:, u, g) = m;
        sem(:, u, g) = s;
        errLo(:, u, g) = lo;
        errHi(:, u, g) = hi;
        count(:, u, g) = sum(c(:, cols), 2);
    end
end

if batchCI   % bootci for a group's units together (its resamples depend on the epochs only, so each unit's band is the one alone)
    chunk = max(1, floor(4000 / nB));   % units per call: bootci holds nBoot x bins x units
    for g = 1:nG
        cols = find(gIdx == g);
        if isempty(cols); continue; end
        for u1 = 1:chunk:nU
            us = u1:min(nU, u1 + chunk - 1);
            [lo, hi] = errorBounds(rAll(:, cols, us), 2, "ci95", opts.ErrorResamples);   % [nB x 1 x numel(us)]
            if useBase
                lo = bandAs(lo, opts.BaselineMode, baseRate(us, g), baseSD(us, g));
                hi = bandAs(hi, opts.BaselineMode, baseRate(us, g), baseSD(us, g));
            end
            errLo(:, us, g) = reshape(lo, nB, []);
            errHi(:, us, g) = reshape(hi, nB, []);
        end
    end
    rAll = [];
end

nEpochs = accumarray(gIdx, 1, [nG 1]);
stopMean = NaN(nG, 1);
for g = 1:nG
    v = stopRel(gIdx == g);
    if any(isfinite(v)); stopMean(g) = mean(v, 'omitnan'); end
end
window = edges([1 end]);
labels = unitLabels(nU, opts.Labels, opts.Meta);
meta = opts.Meta;
aur = [];
if isAuroc
    [rate, sem, count, t, edges, window, aur, keep] = aurocResult(st, E, W, b, opts, G);
    errLo = NaN(size(rate)); errHi = NaN(size(rate));   % an auROC has no band
    raster = raster(keep);
    baseRate = baseRate(keep, :);
    baseSD = baseSD(keep, :);
    labels = labels(keep);
    if istable(meta) && height(meta) == nU; meta = meta(keep, :); end
end

R = struct();
R.kind = "psth";
R.t = t;
R.edges = edges;
R.window = window;
R.rate = rate;
R.rateUnsmoothed = rate;   % SmoothSec 0, or an auROC: the rate itself
if smoothed; R.rateUnsmoothed = rate0; end
R.sem = sem;
R.err = struct('type', opts.ErrorType, 'lo', errLo, 'hi', errHi, 'over', "epochs", 'nBoot', opts.ErrorResamples);
R.count = count;
R.nEpochs = nEpochs;
R.raster = raster;
R.epochGroup = gIdx;
R.epochStop = stopRel;
R.stopMean = stopMean;
R.baselineRate = baseRate;
R.baselineSD = baseSD;
R.groups = G;
R.labels = labels;
R.meta = meta;
R.n = nEpochs;
switch opts.Measure
    case "rate",        unit = "spikes/s";
    case "count",       unit = "spikes/bin";
    case "probability", unit = "P(spike)/bin";
end
switch opts.BaselineMode
    case "none",     R.units = unit;
    case "subtract", R.units = unit + " - baseline";
    case "zscore",   R.units = "z (baseline)";
    case "percent",  R.units = "% change from baseline";
    case "auroc",    R.units = "auROC";
end
R.measure = opts.Measure;
R.params = struct('Window', W, 'BinSec', opts.BinSec, 'Measure', opts.Measure, 'SmoothSec', opts.SmoothSec, ...
    'Baseline', opts.Baseline, 'BaselineMode', opts.BaselineMode, 'MaskAfterStop', opts.MaskAfterStop, ...
    'Raster', opts.Raster);
R.auroc = aur;
R.created = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end


function [rate, sem, count, t, edges, window, aur, keep] = aurocResult(st, E, W, b, opts, G)
%aurocResult  BaselineMode "auroc": aurocCurves with the Auroc settings, and the units kept.
a = EphysAnalysisConfig.normalizeSection("Auroc", opts.Auroc);
A = aurocCurves(st, E, Window=W, Baseline=b, BinSec=opts.BinSec, Measure=opts.Measure, Method=a.method, ...
    Windows=a.windows, WindowSec=a.windowSec, StepSec=a.stepSec, MaskAfterStop=opts.MaskAfterStop, ...
    ModulationWindow=a.modulationWindow, Cutoff=a.cutoff, Threshold=a.threshold, Test=a.test, ...
    NResamples=a.nResamples, Correction=a.correction, Alpha=a.alpha, Groups=G, Check=opts.Check);
keep = true(numel(st), 1);
if a.modulatedOnly
    keep = any(A.modulated, 2);
    if ~any(keep)
        error('spikePSTH:NoneModulated', ...
            'No unit is modulated (auROC cutoff "%s", %d unit(s) tested), so modulatedOnly leaves none to draw.', ...
            a.cutoff, numel(st));
    end
end
rate = A.auroc(:, keep, :);
sem = NaN(size(rate));
count = A.count(:, keep, :);
t = A.t;
edges = A.edges;
window = A.window;
aur = rmfield(A, ["t" "edges" "window" "auroc" "count" "groups"]);
for f = ["mean" "phasic" "p" "q" "direction" "modulated"]
    aur.(f) = aur.(f)(keep, :);
end
aur.settings = a;
end


function x = bandAs(x, mode, mu, sd)
%bandAs  A band's edges X [nBins x 1 x nUnits] moved as the baseline mode moves the mean (MU, SD: one per unit).
mu = reshape(mu, 1, 1, []);
sd = reshape(sd, 1, 1, []);
switch mode
    case "subtract"
        x = x - mu;
    case "zscore"
        x = (x - mu) ./ sd;
        x(:, :, ~(sd > 0)) = NaN;
    case "percent"
        x = 100 * (x - mu) ./ mu;
        x(:, :, ~(mu > 0)) = NaN;
end
end


function st = asCell(x)
if iscell(x)
    st = reshape(x, [], 1);
else
    st = {x};
end
end
