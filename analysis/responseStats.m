function [T, info] = responseStats(spikeTimes, E, opts)
%responseStats  Per unit: does it respond to the event, and is the response tuned to a trial parameter?
%   [T, INFO] = responseStats(ST, E, Baseline=[b0 b1], Window=[w0 w1])
%   tests every spike train of ST ({nUnits x 1} spike times, s, on the
%   continuous clock: selectUnits) over the epochs of E (epochTable). It
%   counts each unit's spikes per epoch in the baseline window
%   [t0 + b0, t0 + b1) and the response window [t0 + w0, t0 + w1)
%   (firingRate, so on the spikes' clock from E.t0Continuous). Then, per
%   unit, with the Statistics and Machine Learning Toolbox:
%     evoked   p = signrank(response, baseline): the Wilcoxon signed-rank
%              test of the paired rates over the epochs, two-sided, with
%              signrank's default method. direction is "excited" when the
%              one-sided test for response > baseline (tail "right") gives
%              the smaller p, "suppressed" when the one for response <
%              baseline (tail "left") does, and "none" when the two agree
%              to 1e-12 (equal rank sums), or for an untested unit
%     tuning   with Param: p = kruskalwallis(response, E.(Param), "off"):
%              the Kruskal-Wallis test of the response window's rates
%              across the parameter's levels. Epochs without a level are
%              left out, and a unit with fewer than two levels is not
%              tested
%   When the two windows are equally long, both tests run on the spike
%   counts. Rates are the counts divided by one constant, so the result is
%   the same, but the differences have no rounding error. Otherwise they
%   run on the rates.
%   Each test's p values are then adjusted over the units tested (pAdjust,
%   Correction). A unit is responsive (tuned) when its adjusted p is at
%   most Alpha.
%
%   Only epochs whose window [tStart, tStop] holds both test windows are
%   used, because there epochTable checked the recording's ends and the
%   artifact periods. The others are left out with the warning
%   responseStats:EpochsLeftOut: epochs flagged incomplete or artifact
%   (epochTable Incomplete / Artifacts "keep"), and epochs too short for
%   the windows. An epoch table made for the test:
%     E = epochTable(src, ref, Window=struct('pre', min(b0, w0), 'post', max(b1, w1)), ...
%             Selection=sel, Columns=param);
%   (selectUnits' response selection makes exactly this one.)
%
%   T, one row per unit:
%     unit           1..nUnits (the row of ST)
%     label          Meta.label when Meta has one, else "unit <k>"
%     nEpochs        the epochs tested
%     baselineRate, responseRate   mean rates over those epochs, spikes/s
%     pEvoked, qEvoked (adjusted), direction, responsive
%     with Param: nLevels, pTuning, qTuning (adjusted), tuned, bestLevel
%     (the level with the highest mean response rate; on a tie, the first
%     in sorted order) and bestRate (that mean, spikes/s)
%   A unit that is not tested has NaN p and q, and is neither responsive
%   nor tuned.
%   INFO: baseline, window, param, correction, alpha, nEpochs,
%   nEpochsLeftOut, nTestedEvoked, nTestedTuning, counts (true: the tests
%   ran on counts), toolbox (the Statistics and Machine Learning Toolbox's
%   version), created.
%
%   Errors: responseStats:NoToolbox, responseStats:BadWindow,
%   responseStats:BadOption, responseStats:NoColumn,
%   responseStats:NoEpochs.
%
%   See also selectUnits, pAdjust, firingRate, epochTable, signrank,
%   kruskalwallis.

arguments
    spikeTimes
    E table
    opts.Baseline double = [-0.2 0]
    opts.Window double = [0 0.2]
    opts.Param (1,1) string = ""
    opts.Correction (1,1) string = "bh"
    opts.Alpha (1,1) double = 0.05
    opts.Meta = []
end

b = opts.Baseline;
w = opts.Window;
if ~(numel(b) == 2 && numel(w) == 2 && all(isfinite([b(:); w(:)])) && b(2) > b(1) && w(2) > w(1))
    error('responseStats:BadWindow', ...
        'Baseline and Window must each be [from to] with from < to (s from the event).');
end
if ~ismember(opts.Correction, ["bh" "holm" "bonferroni" "none"])
    error('responseStats:BadOption', 'Correction is bh, holm, bonferroni or none (got "%s").', opts.Correction);
end
if ~(opts.Alpha > 0 && opts.Alpha <= 1)
    error('responseStats:BadOption', 'Alpha must be in (0, 1] (got %g).', opts.Alpha);
end
param = opts.Param;
need = "signrank";
if param ~= ""; need(end+1) = "kruskalwallis"; end
if ~license('test', 'Statistics_Toolbox') || any(arrayfun(@(f) exist(f, 'file') == 0, need))
    error('responseStats:NoToolbox', ...
        'responseStats needs the Statistics and Machine Learning Toolbox (%s).', strjoin(need, ", "));
end
if param ~= "" && ~ismember(param, string(E.Properties.VariableNames))
    error('responseStats:NoColumn', ...
        'The epochs have no column "%s" (epochTable''s Columns option copies a trial parameter onto them).', param);
end

if iscell(spikeTimes); st = reshape(spikeTimes, [], 1); else; st = {spikeTimes}; end
nU = numel(st);

% --- the epochs that hold both windows -------------------------------------------------
lo = min(b(1), w(1));
hi = max(b(2), w(2));
tol = 1e-9;   % s; far below a sample period
use = E.tStart <= E.t0 + lo + tol & E.tStop >= E.t0 + hi - tol;
vars = string(E.Properties.VariableNames);
if ismember("complete", vars); use = use & E.complete; end
if ismember("artifact", vars); use = use & ~E.artifact; end
nAll = height(E);
nOut = nnz(~use);
if nOut > 0
    warning('responseStats:EpochsLeftOut', ...
        ['%d of %d epoch(s) are left out of the response tests: they are flagged incomplete or artifact, ' ...
         'or their window does not hold [%g %g] s around the event.'], nOut, nAll, lo, hi);
end
E = E(use, :);
nE = height(E);
if nE == 0
    error('responseStats:NoEpochs', 'No epoch is left for the response tests (%d left out).', nOut);
end

% --- counts in the two windows ------------------------------------------------------------
Ew = E;
Ew.tStart = E.t0 + w(1);
Ew.tStop = E.t0 + w(2);
F = firingRate(st, Ew, Measure="count", Baseline=b);
cResp = F.count;          % [nEpochs x nUnits]
cBase = F.baseline;
lenR = w(2) - w(1);
lenB = b(2) - b(1);
rateR = cResp / lenR;
rateB = cBase / lenB;
counts = lenR == lenB;
if counts
    xR = cResp; xB = cBase;
else
    xR = rateR; xB = rateB;
end

% --- the tests ---------------------------------------------------------------------------
nEp = zeros(nU, 1);
baseRate = NaN(nU, 1); respRate = NaN(nU, 1);
pE = NaN(nU, 1);
dirn = repmat("none", nU, 1);
for u = 1:nU
    ok = isfinite(xR(:, u)) & isfinite(xB(:, u));
    nEp(u) = nnz(ok);
    if nEp(u) == 0; continue; end
    baseRate(u) = mean(rateB(ok, u));
    respRate(u) = mean(rateR(ok, u));
    x = xR(ok, u); y = xB(ok, u);
    pE(u) = signrank(x, y);
    pRight = signrank(x, y, 'tail', 'right');
    pLeft = signrank(x, y, 'tail', 'left');
    if abs(pRight - pLeft) <= 1e-12 * max(pRight, pLeft)
        % equal rank sums: the two tails are equal up to rounding
    elseif pRight < pLeft
        dirn(u) = "excited";
    elseif pLeft < pRight
        dirn(u) = "suppressed";
    end
end
qE = pAdjust(pE, opts.Correction);
label = "unit " + (1:nU).';
if istable(opts.Meta) && ismember("label", string(opts.Meta.Properties.VariableNames)) && height(opts.Meta) == nU
    label = string(opts.Meta.label(:));
end
T = table((1:nU).', label, nEp, baseRate, respRate, pE, qE, dirn, qE <= opts.Alpha, ...
    'VariableNames', {'unit', 'label', 'nEpochs', 'baselineRate', 'responseRate', ...
    'pEvoked', 'qEvoked', 'direction', 'responsive'});

nTuned = 0;
if param ~= ""
    lev = E.(param);
    if iscell(lev); lev = string(lev); end
    hasLev = ~ismissing(lev);
    [levels, ~, li] = unique(lev(hasLev));       % sorted
    nLev = zeros(nU, 1);
    pT = NaN(nU, 1);
    bestRate = NaN(nU, 1);
    if isnumeric(levels) || islogical(levels)
        best = NaN(nU, 1);
    else
        best = strings(nU, 1);
        best(:) = missing;
    end
    xL = xR(hasLev, :);
    rL = rateR(hasLev, :);
    for u = 1:nU
        ok = isfinite(xL(:, u));
        g = li(ok);
        present = unique(g);
        nLev(u) = numel(present);
        if nLev(u) < 2; continue; end
        grp = lev(hasLev);
        grp = grp(ok);
        if isstring(grp); grp = cellstr(grp); end
        pT(u) = kruskalwallis(xL(ok, u), grp, 'off');
        m = accumarray(g, rL(ok, u), [numel(levels) 1], @mean, NaN);
        [bestRate(u), k] = max(m);                % NaN (absent levels) is never the max
        best(u) = levels(k);
    end
    qT = pAdjust(pT, opts.Correction);
    T.nLevels = nLev;
    T.pTuning = pT;
    T.qTuning = qT;
    T.tuned = qT <= opts.Alpha;
    T.bestLevel = best;
    T.bestRate = bestRate;
    nTuned = nnz(isfinite(pT));
end

info = struct();
info.baseline = b;
info.window = w;
info.param = param;
info.correction = opts.Correction;
info.alpha = opts.Alpha;
info.nEpochs = nE;
info.nEpochsLeftOut = nOut;
info.nTestedEvoked = nnz(isfinite(pE));
info.nTestedTuning = nTuned;
info.counts = counts;
v = ver('stats');
info.toolbox = "";
if ~isempty(v); info.toolbox = string(v(1).Name) + " " + string(v(1).Version) + " " + string(v(1).Release); end
info.created = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end
