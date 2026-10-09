function A = aurocCurves(spikeTimes, E, opts)
%aurocCurves  auROC of each unit's firing against its baseline over time, and which units are modulated.
%   A = aurocCurves(ST, E, Name=Value) measures, for every spike train of ST
%   ({nUnits x 1} spike times, s, on the continuous clock: selectUnits) and
%   every group of the epochs E (epochTable), how far the firing in each
%   window around the event stands apart from the firing in the baseline:
%   the area under the receiver operating characteristic curve, auROC
%   (Cohen et al. 2012, Nature 482:85; Macedo-Lima, Hamlette & Caras 2024,
%   Curr Biol 34:3354). 0.5 is no difference, above 0.5 more firing than in
%   the baseline, below 0.5 less. Pure: no I/O, no graphics.
%
%   Spikes are counted in BinSec bins on a grid from the event (bin k is
%   [k, k+1) x BinSec, half-open, as in spikePSTH; a spike on an edge, to
%   within 1e-9 s, is in the bin that starts there), relative to each
%   epoch's t0Continuous. Every auROC window is a whole number of bins.
%
%   The values compared (Method)
%     "psth"    (default) the trial-averaged PSTH's bins: the bins inside a
%               window against the bins inside the baseline, as the Caras
%               lab's calculate_auROC.py does for the paper (10 ms bins,
%               100 ms windows)
%     "epochs"  the epochs: each epoch's spike count in the window against
%               every epoch's counts in the baseline's window-long pieces
%               (back to back from the baseline's start; a remainder at
%               its end is not used)
%   The auROC is P(window value > baseline value) + P(equal) / 2 over all
%   pairs. That is the area under the ROC curve that a criterion swept
%   from 0 to the largest value draws, computed exactly from ranks (aucOf).
%   Measure "rate" and "count" give the same auROC, since only the order
%   of the values counts. "probability" compares spike / no spike (psth:
%   the share of epochs with a spike in each bin). A unit with no spike at
%   all in the span counted (Window and Baseline) over a group's epochs
%   has no auROC there: its curve, mean and phasic modulation are NaN, so
%   it is not called and stays out of the 95% CI cutoff
%   (calculate_auROC.py gives such a unit NaN too).
%
%   The windows (Windows)
%     "tiled"   (default) back to back, WindowSec long, edges at whole
%               multiples of WindowSec from the event (the event is an
%               edge)
%     "sliding" WindowSec long, one starting every StepSec (whole multiples
%               of StepSec from the event); neighbors share bins
%   Only windows wholly inside Window are used. The curve's time of a
%   window is its center.
%
%   Each unit's call, per group (Cutoff; made by aurocCall), from the
%   windows wholly inside ModulationWindow: their mean auROC ("mean") and
%   mean |auROC - 0.5| ("phasic", the paper's phasic modulation)
%     "ci"      (default) as in the paper: c is the upper bound of the 95%
%               confidence interval of the mean phasic modulation over
%               every unit and group, mean + t(0.975, n-1) x SD / sqrt(n)
%               (tinv). A unit is modulated upwards when its mean auROC
%               is above 0.5 + c, downwards when below 0.5 - c. c depends
%               on the units passed in, and it narrows as more are added
%     "fixed"   the same with c = Threshold
%     "test"    a p value per unit and group (Test), adjusted over every
%               unit and group tested (pAdjust, Correction); modulated
%               when it is at most Alpha, upwards when the mean auROC is
%               above 0.5, downwards when below
%     "none"    no call
%   With Call=false the units are measured (and, with Cutoff "test",
%   tested) but not called: to call them with the units of other calls,
%   their mean, phasic and p stacked, in one aurocCall (populationAnalysis
%   pools every dataset's units so).
%   Test
%     "bootstrap" (default) the epochs are resampled with replacement
%               NResamples times and the mean auROC recomputed each time.
%               p = 2 x the share of resamples on the far side of 0.5
%               (+1 smoothed, capped at 1)
%     "ranksum" ranksum of the window values inside ModulationWindow
%               (pooled) against the baseline values: the test behind the
%               auROC. Values from the same epochs are not independent,
%               so its p values tend to be too small
%     "shuffle" each epoch's bins are shifted circularly by a random
%               amount over the span counted (Window and Baseline
%               together), NResamples times, which breaks the lock to the
%               event. p is the share of shuffles (+1 smoothed) whose
%               phasic modulation reaches the observed one
%   The random draws come from their own stream (Seed), so a result can be
%   reproduced and the global generator is left alone.
%
%   Options
%     Window          [pre post] s around the event (default [-0.5 1])
%     Baseline        [b0 b1] s from the event (default [-0.5 0]), cut to
%                     the whole bins inside it (A.baseline); it may lie
%                     outside Window
%     BinSec          bin width, s (default 0.01)
%     Measure         "rate" (default) | "count" | "probability"
%     Method          "psth" (default) | "epochs"
%     Windows         "tiled" (default) | "sliding"
%     WindowSec       auROC window, s (default 0.1): a whole number of bins
%     StepSec         sliding: the step, s (default 0.01): a whole number
%                     of bins
%     MaskAfterStop   leave out each epoch's bins from its stop event t1 on
%                     (epochs: an epoch's window or piece that has any)
%     ModulationWindow  [m0 m1] s from the event (default [0 0.5])
%     Cutoff          "ci" (default) | "fixed" | "test" | "none"
%     Threshold       fixed: |mean auROC - 0.5| above this (default 0.1)
%     Test            "bootstrap" (default) | "ranksum" | "shuffle"
%     NResamples      bootstrap / shuffle: how many (default 1000)
%     Correction      test: "bh" (default) | "holm" | "bonferroni" | "none"
%     Alpha           test: 0.05
%     Call            true (default): call the units here; false: leave
%                     the call fields as Cutoff "none" gives them, for
%                     aurocCall over a larger pool
%     Seed            the random stream's seed (default 0)
%     Check           a function handle called with no input before each unit
%                     and group (default []); it may throw to stop (the app's
%                     Cancel button)
%     Groups          the groups table from epochTable (default: built
%                     from E.groupIndex / E.group)
%
%   A fields: t [nWindows x 1] (window centers, s), starts, stops (the
%   windows, s), edges (row: the boundaries a bar plot draws, half a step
%   either side of each center; for tiled windows their edges), window
%   (the span the windows cover), auroc [nWindows x nUnits x nGroups],
%   count (spikes in each window summed over the group's epochs, same
%   size), inModulation [nWindows x 1], mean, phasic, p, q [nUnits x
%   nGroups] (NaN where not computed), direction [nUnits x nGroups]
%   ("increase" | "decrease" | "none"; "" without a call), modulated
%   [nUnits x nGroups], cutoff (the Cutoff), cutoffValue (c; NaN for
%   "test" and "none"), nModulated / nIncrease / nDecrease [nGroups x 1],
%   nUnits, baseline, modulationWindow, method, windows, groups, params
%   (every option as used), toolbox (the Statistics and Machine Learning
%   Toolbox's version), created.
%
%   Needs the Statistics and Machine Learning Toolbox (tiedrank; tinv for
%   "ci"; ranksum for the ranksum test).
%
%   Errors: aurocCurves:BadOption, aurocCurves:BadWindow,
%   aurocCurves:BadBaseline, aurocCurves:BadModulation,
%   aurocCurves:NoToolbox. Warnings (the "ci" cutoff, aurocCall's):
%   aurocCall:NoCutoff (fewer than two units and groups with a phasic
%   modulation), aurocCall:WideCutoff (c >= 0.5, so no unit can be called:
%   too few units for the interval).
%
%   See also aurocCall, spikePSTH, selectUnits, populationAnalysis,
%   responseStats, pAdjust, tiedrank.

arguments
    spikeTimes
    E table
    opts.Window (1,2) double = [-0.5 1]
    opts.Baseline double = [-0.5 0]
    opts.BinSec (1,1) double {mustBePositive} = 0.01
    opts.Measure (1,1) string {mustBeMember(opts.Measure, ["rate" "count" "probability"])} = "rate"
    opts.Method (1,1) string = "psth"
    opts.Windows (1,1) string = "tiled"
    opts.WindowSec (1,1) double = 0.1
    opts.StepSec (1,1) double = 0.01
    opts.MaskAfterStop (1,1) logical = false
    opts.ModulationWindow double = [0 0.5]
    opts.Cutoff (1,1) string = "ci"
    opts.Threshold (1,1) double = 0.1
    opts.Test (1,1) string = "bootstrap"
    opts.NResamples (1,1) double = 1000
    opts.Correction (1,1) string = "bh"
    opts.Alpha (1,1) double = 0.05
    opts.Call (1,1) logical = true
    opts.Seed (1,1) double = 0
    opts.Check = []
    opts.Groups = []
end

% --- options -------------------------------------------------------------------------------
checkOption(opts.Method, ["psth" "epochs"], "Method");
checkOption(opts.Windows, ["tiled" "sliding"], "Windows");
checkOption(opts.Cutoff, ["ci" "fixed" "test" "none"], "Cutoff");
checkOption(opts.Test, ["bootstrap" "ranksum" "shuffle"], "Test");
checkOption(opts.Correction, ["bh" "holm" "bonferroni" "none"], "Correction");
if ~(opts.Alpha > 0 && opts.Alpha <= 1)
    error('aurocCurves:BadOption', 'Alpha must be in (0, 1] (got %g).', opts.Alpha);
end
if ~(opts.Threshold >= 0 && opts.Threshold < 0.5)
    error('aurocCurves:BadOption', 'Threshold is |auROC - 0.5| and must be in [0, 0.5) (got %g).', opts.Threshold);
end
runTest = opts.Cutoff == "test";
resample = runTest && opts.Test ~= "ranksum";
if resample && ~(opts.NResamples >= 1 && opts.NResamples == round(opts.NResamples))
    error('aurocCurves:BadOption', 'NResamples must be a whole number >= 1 (got %g).', opts.NResamples);
end
need = "tiedrank";
if opts.Cutoff == "ci"; need(end+1) = "tinv"; end
if runTest && opts.Test == "ranksum"; need(end+1) = "ranksum"; end
if ~license('test', 'Statistics_Toolbox') || any(arrayfun(@(f) exist(f, 'file') == 0, need))
    error('aurocCurves:NoToolbox', 'auROC needs the Statistics and Machine Learning Toolbox (%s).', strjoin(need, ", "));
end

% --- the bins and windows, in bins from the event ---------------------------------------
bin = opts.BinSec;
W = opts.Window;
if ~(W(2) > W(1))
    error('aurocCurves:BadWindow', 'Window must be [pre post] with pre < post.');
end
nWb = wholeBins(opts.WindowSec, bin, "WindowSec");
nSb = nWb;
if opts.Windows == "sliding"; nSb = wholeBins(opts.StepSec, bin, "StepSec"); end
kLo = ceil(W(1) / bin - 1e-9);
kHi = floor(W(2) / bin + 1e-9);
s = (ceil(kLo / nSb - 1e-9) : floor((kHi - nWb) / nSb + 1e-9)).' * nSb;   % window starts
if isempty(s)
    error('aurocCurves:BadWindow', 'Window [%g %g] s holds no whole %g s auROC window.', W(1), W(2), nWb * bin);
end
nW = numel(s);
b = opts.Baseline;
if ~(numel(b) == 2 && all(isfinite(b)) && b(2) > b(1))
    error('aurocCurves:BadBaseline', 'Baseline must be [b0 b1] with b0 < b1 (s from the event).');
end
bLo = ceil(b(1) / bin - 1e-9);
bHi = floor(b(2) / bin + 1e-9);
nT = 0;
if opts.Method == "psth"
    if bHi <= bLo
        error('aurocCurves:BadBaseline', 'Baseline [%g %g] s holds no whole %g s bin.', b(1), b(2), bin);
    end
else
    nT = floor((bHi - bLo) / nWb);
    if nT < 1
        error('aurocCurves:BadBaseline', 'Baseline [%g %g] s is shorter than one %g s auROC window.', b(1), b(2), nWb * bin);
    end
    bHi = bLo + nT * nWb;
end
m = opts.ModulationWindow;
if ~(numel(m) == 2 && all(isfinite(m)) && m(2) > m(1))
    error('aurocCurves:BadModulation', 'ModulationWindow must be [m0 m1] with m0 < m1 (s from the event).');
end
inMod = s * bin >= m(1) - 1e-9 & (s + nWb) * bin <= m(2) + 1e-9;
if ~any(inMod) && opts.Cutoff ~= "none"
    error('aurocCurves:BadModulation', ...
        'The modulation window [%g %g] s holds none of the %g s auROC windows (they cover [%g %g] s).', ...
        m(1), m(2), nWb * bin, s(1) * bin, (s(end) + nWb) * bin);
end
fLo = min(kLo, bLo);
fHi = max(kHi, bHi);
edgesF = (fLo:fHi) * bin;   % the fine bins counted
nF = fHi - fLo;
winIdx = (s.' - fLo + 1) + (0:nWb-1).';   % [nWb x nW] the bins of each window
baseIdx = ((bLo - fLo + 1):(bHi - fLo)).';
tileFirst = (bLo - fLo + 1) + (0:nT-1).' * nWb;   % epochs: the baseline pieces' first bins

% --- the epochs ---------------------------------------------------------------------------
if iscell(spikeTimes); st = reshape(spikeTimes, [], 1); else; st = {spikeTimes}; end
nU = numel(st);
G = groupsFor(E, opts.Groups);
nG = height(G);
gIdx = E.groupIndex;
nE = height(E);
ta = E.t0Continuous;
mask = false(nF, nE);
if opts.MaskAfterStop
    stopRel = E.t1 - E.t0;
    for e = 1:nE   % a stop on a bin's start (to rounding) masks that bin, as binCounts puts a spike there in it
        if isfinite(stopRel(e)); mask(:, e) = edgesF(1:end-1).' >= stopRel(e) - 1e-9; end
    end
end
prob = opts.Measure == "probability";

% --- per unit and group --------------------------------------------------------------------
auc = NaN(nW, nU, nG);
cnt = zeros(nW, nU, nG);
mn = NaN(nU, nG); ph = NaN(nU, nG); p = NaN(nU, nG);
rs = RandStream('mt19937ar', 'Seed', opts.Seed);
modW = find(inMod).';
for u = 1:nU
    if ~isempty(opts.Check); opts.Check(); end
    C = binCounts(st{u}, ta, edgesF);   % [nF x nE]
    C(mask) = 0;
    if opts.Method == "psth"
        X = C;
        if prob; X = double(C > 0); end
        Uok = double(~mask);
    else
        Wv = rangeSums(C, mask, winIdx(1, :).', nWb, prob);   % [nW x nE]
        Bv = rangeSums(C, mask, tileFirst, nWb, prob);        % [nT x nE]
    end
    for g = 1:nG
        if ~isempty(opts.Check); opts.Check(); end
        cols = find(gIdx == g);
        if isempty(cols); continue; end
        csum = sum(C(:, cols), 2);
        cnt(:, u, g) = sum(reshape(csum(winIdx), nWb, nW), 1).';
        if ~any(csum); continue; end   % silent here: no auROC (NaN), so out of the cutoff, as calculate_auROC.py
        if opts.Method == "psth"
            v = sum(X(:, cols), 2) ./ sum(Uok(:, cols), 2);   % the mean over the epochs not masked
            a = aucOf(reshape(v(winIdx), nWb, nW), v(baseIdx));
        else
            a = aucOf(Wv(:, cols).', reshape(Bv(:, cols), [], 1));
        end
        auc(:, u, g) = a(:);
        if ~any(inMod); continue; end
        mn(u, g) = mean(a(inMod), 'omitnan');
        ph(u, g) = mean(abs(a(inMod) - 0.5), 'omitnan');
        if ~runTest || ~isfinite(mn(u, g)); continue; end
        switch opts.Test
            case "ranksum"
                if opts.Method == "psth"
                    x = v(unique(winIdx(:, inMod))); y = v(baseIdx);
                else
                    x = Wv(inMod, cols); y = Bv(:, cols);
                end
                x = x(~isnan(x)); y = y(~isnan(y));
                if ~isempty(x) && ~isempty(y); p(u, g) = ranksum(x(:), y(:)); end
            case "bootstrap"
                if opts.Method == "psth"
                    mstar = bootPsth(X(:, cols), Uok(:, cols), winIdx(:, modW), baseIdx, opts.NResamples, rs);
                else
                    mstar = bootEpochs(Wv(modW, cols), Bv(:, cols), opts.NResamples, rs);
                end
                p(u, g) = twoSided(mstar);
            case "shuffle"
                if opts.Method == "psth"
                    dstar = shufflePsth(X(:, cols), Uok(:, cols), winIdx(:, modW), baseIdx, opts.NResamples, rs);
                else
                    dstar = shuffleEpochs(C(:, cols), mask(:, cols), [winIdx(1, modW).'; tileFirst], numel(modW), ...
                        nWb, prob, opts.NResamples, rs);
                end
                dstar = dstar(isfinite(dstar));
                p(u, g) = (1 + sum(dstar >= ph(u, g) - 1e-12)) / (numel(dstar) + 1);
        end
    end
end

A = struct();
A.t = (s + nWb / 2) * bin;
A.starts = s * bin;
A.stops = (s + nWb) * bin;
A.edges = ([s; s(end) + nSb].' + (nWb - nSb) / 2) * bin;
A.window = [A.starts(1) A.stops(end)];
A.auroc = auc;
A.count = cnt;
A.inModulation = inMod;
A.mean = mn;
A.phasic = ph;
A.p = p;
cut = opts.Cutoff;
if ~opts.Call; cut = "none"; end   % the units' call is made elsewhere, over a larger pool
A = aurocCall(A, Cutoff=cut, Threshold=opts.Threshold, Correction=opts.Correction, Alpha=opts.Alpha);
A.nUnits = nU;
A.baseline = [bLo bHi] * bin;
A.modulationWindow = m(:).';
A.method = opts.Method;
A.windows = opts.Windows;
A.groups = G;
A.params = rmfield(opts, 'Groups');
v = ver('stats');
A.toolbox = "";
if ~isempty(v); A.toolbox = string(v(1).Version); end
A.created = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end


function checkOption(v, allowed, name)
if ~ismember(v, allowed)
    error('aurocCurves:BadOption', '%s is %s (got "%s").', name, strjoin(allowed, ", "), v);
end
end


function n = wholeBins(x, bin, name)
%wholeBins  X s as a whole number (>= 1) of BIN s bins.
n = round(x / bin);
if ~(isfinite(x) && n >= 1 && abs(x / bin - n) < 1e-6)
    error('aurocCurves:BadOption', '%s (%g s) must be a whole number of %g s bins.', name, x, bin);
end
end


function V = rangeSums(C, mask, first, len, prob)
%rangeSums  Each epoch's spike count in the ranges of LEN bins from FIRST: [nRanges x nEpochs].
%   A range with a masked bin is NaN; PROB gives 1 for a spike, 0 for none.
cs = [zeros(1, size(C, 2)); cumsum(C, 1)];
ms = [zeros(1, size(C, 2)); cumsum(double(mask), 1)];
V = cs(first + len, :) - cs(first, :);
if prob; V = double(V > 0); end
V(ms(first + len, :) - ms(first, :) > 0) = NaN;
end


function W = multiplicities(rs, n, N)
%multiplicities  How often each of N bootstrap resamples draws each of n epochs: [n x N].
idx = randi(rs, n, n, N);
W = accumarray([idx(:), repelem((1:N).', n)], 1, [n N]);
end


function mstar = bootPsth(X, Uok, winIdx, baseIdx, N, rs)
%bootPsth  The mean auROC over the windows WINIDX in N bootstrap resamples of the epochs (psth).
Wt = multiplicities(rs, size(X, 2), N);
V = (X * Wt) ./ (Uok * Wt);   % each resample's PSTH
a = zeros(size(winIdx, 2), N);
for w = 1:size(winIdx, 2)
    a(w, :) = aucOf(V(winIdx(:, w), :), V(baseIdx, :));
end
mstar = mean(a, 1, 'omitnan');
end


function mstar = bootEpochs(Wv, Bv, N, rs)
%bootEpochs  The mean auROC over the windows (rows of WV) in N bootstrap resamples of the epochs.
%   The values are counts (or 0 / 1), so each resample's auROC comes from
%   the histograms of its values: those of the resampled epochs, summed.
nEg = size(Wv, 2);
Wt = multiplicities(rs, nEg, N);
K = max([Wv(:); Bv(:); 0], [], 'omitnan');
ok = ~isnan(Bv);
[~, e] = find(ok);
HB = accumarray([Bv(ok) + 1, e], 1, [K + 1, nEg]) * Wt;
a = zeros(size(Wv, 1), N);
for w = 1:size(Wv, 1)
    x = Wv(w, :);
    k = ~isnan(x);
    HA = accumarray([x(k).' + 1, find(k).'], 1, [K + 1, nEg]) * Wt;
    a(w, :) = aucHist(HA, HB);
end
mstar = mean(a, 1, 'omitnan');
end


function dstar = shufflePsth(X, Uok, winIdx, baseIdx, N, rs)
%shufflePsth  The phasic modulation over the windows WINIDX with each epoch's bins circularly shifted (psth).
[nF, nEg] = size(X);
rows = unique([winIdx(:); baseIdx]);
[~, wPos] = ismember(winIdx, rows);
[~, bPos] = ismember(baseIdx, rows);
shifts = randi(rs, [0 nF - 1], nEg, N);
nR = numel(rows);
chunk = max(1, floor(4e6 / (nR * nEg)));
a = zeros(size(winIdx, 2), N);
for n1 = 1:chunk:N
    n2 = min(N, n1 + chunk - 1);
    sh = reshape(shifts(:, n1:n2), 1, nEg, []);
    lin = mod(rows - 1 - sh, nF) + 1 + nF * (0:nEg-1);   % [nR x nEg x nc] the bin each one comes from
    V = reshape(sum(X(lin), 2) ./ sum(Uok(lin), 2), nR, []);
    for w = 1:size(winIdx, 2)
        a(w, n1:n2) = aucOf(V(wPos(:, w), :), V(bPos, :));
    end
end
dstar = mean(abs(a - 0.5), 1, 'omitnan');
end


function dstar = shuffleEpochs(C, mask, first, nMod, len, prob, N, rs)
%shuffleEpochs  The phasic modulation over the first NMOD ranges with each epoch's bins circularly shifted (epochs).
%   FIRST: the first bin of each modulation window, then of each baseline
%   piece; every range is LEN bins.
[nF, nEg] = size(C);
cs = [zeros(1, nEg); cumsum([C; C], 1)];   % doubled, so a shifted range never wraps
ms = [zeros(1, nEg); cumsum(double([mask; mask]), 1)];
shifts = randi(rs, [0 nF - 1], nEg, N);
nR = numel(first);
chunk = max(1, floor(4e6 / (nR * nEg)));
a = zeros(nMod, N);
for n1 = 1:chunk:N
    n2 = min(N, n1 + chunk - 1);
    nc = n2 - n1 + 1;
    sh = reshape(shifts(:, n1:n2), 1, nEg, []);
    o = mod(first - 1 - sh, nF) + (2 * nF + 1) * (0:nEg-1);   % [nR x nEg x nc] 0-based start in each column
    V = cs(o + len + 1) - cs(o + 1);
    if prob; V = double(V > 0); end
    V(ms(o + len + 1) - ms(o + 1) > 0) = NaN;
    K = max([V(:); 0], [], 'omitnan');
    B = reshape(V(nMod+1:end, :, :), [], nc);   % every epoch's baseline pieces, per shuffle
    HB = histCols(B, K);
    for w = 1:nMod
        a(w, n1:n2) = aucHist(histCols(reshape(V(w, :, :), nEg, nc), K), HB);
    end
end
dstar = mean(abs(a - 0.5), 1, 'omitnan');
end


function H = histCols(V, K)
%histCols  Counts of each value 0..K in each column of V (NaN left out): [K+1 x nCols].
ok = ~isnan(V);
[~, j] = find(ok);
H = accumarray([V(ok) + 1, j], 1, [K + 1, size(V, 2)]);
end


function a = aucHist(HA, HB)
%aucHist  aucOf from the histograms of two sets of whole values 0..K, column by column.
nA = sum(HA, 1);
nB = sum(HB, 1);
below = cumsum(HB, 1) - HB;
a = sum(HA .* (below + HB / 2), 1) ./ (nA .* nB);
a(nA == 0 | nB == 0) = NaN;
end


function p = twoSided(mstar)
%twoSided  2 x the share of resampled means on the far side of 0.5 (+1 smoothed), at most 1.
mstar = mstar(isfinite(mstar));
n = numel(mstar);
lo = sum(mstar <= 0.5 + 1e-12);
hi = sum(mstar >= 0.5 - 1e-12);
p = min(1, 2 * (min(lo, hi) + 1) / (n + 1));
end
