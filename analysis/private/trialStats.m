function S = trialStats(V, cat, ser, opts)
%trialStats  A trial panel's summary statistics, group tests, fits and correlations.
%   S = trialStats(V, CAT, SER, Name=Value) for the per-value table V (a
%   trial panel's stacked R.values: value, and x on a scatter) with CAT and
%   SER [height(V) x 1] each value's category and series (trialGrouping;
%   0 = left out). Never an error for too few values: what cannot be
%   computed is NaN. Fields of S:
%     table    one row per category and series: category, series, n, center
%              (the mean, or the median with Summary "median"), lo, hi
%              (errorBounds(v, 1, ErrorType, ErrorResamples, Summary); NaN
%              with ErrorType "off" or n < 2), mean, median, q1, q3, min,
%              max (prctile's quartiles)
%     test     the omnibus tests, a struct array: name (the function:
%              ranksum, ttest2, kruskalwallis, anova1, or "none"), label
%              ("Rank-sum", "t-test", "Kruskal-Wallis", "ANOVA"), across
%              ("categories" | "series"), per (the series, 0 across
%              series), p, stat (rank sum, t, chi-square, F), df ([] for
%              rank-sum; [between within] for ANOVA), n (values tested),
%              levels (the levels tested). With more than one category the
%              categories are compared within each series, else the
%              series. Only levels with at least 2 values take part; fewer
%              than two such levels give p NaN. Test "auto" is ranksum for
%              2 levels, else kruskalwallis(..., 'off'); "ranksum" with
%              more levels is kruskalwallis, "ttest2" with more is anova1;
%              "none" gives p NaN
%     pairs    table, one row per pair compared: per, a, b (levels), n1,
%              n2, test ("ranksum", or "ttest2" under a parametric choice),
%              p, pAdj (pAdjust(p, Adjust) over the pairs of one series),
%              stars ("***" pAdj < 0.001, "**" < 0.01, "*" < 0.05, "n.s.",
%              "" for NaN), sig (pAdj < Alpha). TestPairs "all": every
%              pair; "first": each level vs level 1. A level with fewer than
%              2 values gives p NaN
%     fit      per series (V with x, Fit not "none"): kind, coef (polyfit's,
%              highest power first; [] for a moving fit), xg, yg (the curve:
%              100 points over the x range for linear / poly2 / poly3, the
%              x-sorted points for movmean / movmedian over FitWindow
%              points), lo, hi (fitlm + predict's 95% band of the curve;
%              NaN for a moving fit), r2, n, nLeftOut. On a "log" XScale /
%              YScale the fit is made in log10 units (values <= 0 left out,
%              nLeftOut); coef and r2 are in those units, xg / yg / lo / hi
%              in data units
%     corr     per series (V with x, Corr not "none"): type ("pearson" |
%              "spearman"), r, p (corr), n, in the units of the fit
%     options  the options used
%   The tests, fits and bootstrap bands need the Statistics and Machine
%   Learning Toolbox.
%
%   See also trialPanelStats, trialGrouping, errorBounds, pAdjust.

arguments
    V table
    cat (:,1) double
    ser (:,1) double
    opts.NCategories (1,1) double = max([0; cat])
    opts.NSeries (1,1) double = max([0; ser])
    opts.Summary (1,1) string = "mean"
    opts.ErrorType (1,1) string = "sem"
    opts.ErrorResamples (1,1) double = 1000
    opts.Test (1,1) string = "auto"
    opts.TestPairs (1,1) string = "all"
    opts.Adjust (1,1) string = "holm"
    opts.Alpha (1,1) double = 0.05
    opts.Fit (1,1) string = "none"
    opts.FitWindow (1,1) double = 10
    opts.Corr (1,1) string = "none"
    opts.XScale (1,1) string = "linear"
    opts.YScale (1,1) string = "linear"
end

nC = opts.NCategories;
nS = opts.NSeries;
y = double(V.value);
S = struct();
S.options = opts;

% --- the summary per category and series ------------------------------------------
nR = nC * nS;
[cc, ss] = ndgrid(1:nC, 1:nS);
Tb = table(cc(:), ss(:), zeros(nR, 1), NaN(nR, 1), NaN(nR, 1), NaN(nR, 1), NaN(nR, 1), NaN(nR, 1), NaN(nR, 1), ...
    NaN(nR, 1), NaN(nR, 1), NaN(nR, 1), 'VariableNames', ...
    {'category', 'series', 'n', 'center', 'lo', 'hi', 'mean', 'median', 'q1', 'q3', 'min', 'max'});
for r = 1:nR
    v = y(cat == Tb.category(r) & ser == Tb.series(r) & isfinite(y));
    Tb.n(r) = numel(v);
    if isempty(v); continue; end
    Tb.mean(r) = mean(v);
    Tb.median(r) = median(v);
    q = prctile(v, [25 75]);
    Tb.q1(r) = q(1); Tb.q3(r) = q(2);
    Tb.min(r) = min(v); Tb.max(r) = max(v);
    Tb.center(r) = Tb.mean(r);
    if opts.Summary == "median"; Tb.center(r) = Tb.median(r); end
    if ismember(opts.ErrorType, ["sem" "std" "ci95" "iqr"]) && numel(v) >= 2
        [Tb.lo(r), Tb.hi(r)] = errorBounds(v, 1, opts.ErrorType, opts.ErrorResamples, opts.Summary);
    end
end
S.table = Tb;

% --- the tests: categories within each series, else the series ---------------------
parametric = ismember(opts.Test, ["ttest2" "anova1"]);
pairTest = "ranksum";
if parametric; pairTest = "ttest2"; end
tests = struct('name', {}, 'label', {}, 'across', {}, 'per', {}, 'p', {}, 'stat', {}, 'df', {}, 'n', {}, 'levels', {});
pc = cell(0, 1);
if nC > 1
    for s = 1:nS
        inS = ser == s & cat >= 1 & isfinite(y);
        [tests(end+1), pc{end+1}] = compare(y(inS), cat(inS), nC, "categories", s, opts, pairTest); %#ok<AGROW>
    end
elseif nS > 1
    in = ser >= 1 & cat >= 1 & isfinite(y);
    [tests(1), pc{1}] = compare(y(in), ser(in), nS, "series", 0, opts, pairTest);
end
S.test = tests;
P = vertcat(pc{:}, emptyPairs());
P.pAdj = NaN(height(P), 1);
for s = unique(P.per).'
    r = P.per == s;
    method = opts.Adjust;
    if ~ismember(method, ["bh" "holm" "bonferroni" "none"]); method = "holm"; end
    P.pAdj(r) = pAdjust(P.p(r), method);
end
P.stars = starsOf(P.pAdj);
P.sig = P.pAdj < opts.Alpha;
S.pairs = P;

% --- fits and correlations (a scatter: x against value, per series) ---------------
S.fit = struct('kind', {}, 'coef', {}, 'xg', {}, 'yg', {}, 'lo', {}, 'hi', {}, 'r2', {}, 'n', {}, 'nLeftOut', {});
S.corr = struct('type', {}, 'r', {}, 'p', {}, 'n', {});
if ~ismember("x", string(V.Properties.VariableNames)); return; end
x = double(V.x);
xLog = opts.XScale == "log";
yLog = opts.YScale == "log";
for s = 1:nS
    in = ser == s & cat >= 1 & isfinite(x) & isfinite(y);
    xs = x(in); ys = y(in);
    keep = true(size(xs));
    if xLog; keep = keep & xs > 0; end
    if yLog; keep = keep & ys > 0; end
    nOut = nnz(~keep);
    xs = xs(keep); ys = ys(keep);
    if xLog; xs = log10(xs); end
    if yLog; ys = log10(ys); end
    if opts.Fit ~= "none"
        F = fitOf(xs, ys, opts.Fit, opts.FitWindow);
        F.nLeftOut = nOut;
        if xLog; F.xg = 10 .^ F.xg; end
        if yLog; F.yg = 10 .^ F.yg; F.lo = 10 .^ F.lo; F.hi = 10 .^ F.hi; end
        S.fit(s) = F;
    end
    if opts.Corr ~= "none"
        C = struct('type', opts.Corr, 'r', NaN, 'p', NaN, 'n', numel(xs));
        if numel(xs) >= 3
            typ = "Pearson";
            if opts.Corr == "spearman"; typ = "Spearman"; end
            [C.r, C.p] = corr(xs, ys, 'Type', char(typ));
        end
        S.corr(s) = C;
    end
end
end


function [T, P] = compare(y, g, nL, across, per, opts, pairTest)
%compare  The omnibus test over the levels of G (1..NL) and the pairs, for one series (or across series).
cnt = accumarray(g, 1, [nL 1]);
use = find(cnt >= 2);
k = numel(use);
name = opts.Test;
switch opts.Test
    case "auto",    if k == 2; name = "ranksum"; else; name = "kruskalwallis"; end
    case "ranksum", if k > 2; name = "kruskalwallis"; end
    case "ttest2",  if k > 2; name = "anova1"; end
end
T = struct('name', name, 'label', testLabel(name), 'across', across, 'per', per, 'p', NaN, 'stat', NaN, 'df', [], ...
    'n', sum(cnt(use)), 'levels', reshape(use, 1, []));
if name ~= "none" && k >= 2
    in = ismember(g, use);
    [T.p, T.stat, T.df] = runTest(name, y(in), g(in));
end
% the pairs
switch opts.TestPairs
    case "first", ab = [ones(nL - 1, 1) (2:nL).'];
    otherwise
        if nL >= 2; ab = nchoosek(1:nL, 2); else; ab = zeros(0, 2); end
end
nP = size(ab, 1);
P = emptyPairs();
if nP == 0; return; end
p = NaN(nP, 1);
if opts.Test ~= "none"
    for i = 1:nP
        if cnt(ab(i, 1)) >= 2 && cnt(ab(i, 2)) >= 2
            p(i) = runTest(pairTest, y(g == ab(i, 1) | g == ab(i, 2)), g(g == ab(i, 1) | g == ab(i, 2)));
        end
    end
end
P = table(repmat(per, nP, 1), ab(:, 1), ab(:, 2), cnt(ab(:, 1)), cnt(ab(:, 2)), repmat(pairTest, nP, 1), p, ...
    'VariableNames', {'per', 'a', 'b', 'n1', 'n2', 'test', 'p'});
end


function [p, stat, df] = runTest(name, y, g)
%runTest  One test of Y by the groups G (two levels for ranksum / ttest2).
y = y(:); g = g(:);
u = unique(g);
stat = NaN; df = [];
switch name
    case "ranksum"
        [p, ~, st] = ranksum(y(g == u(1)), y(g == u(2)));
        stat = st.ranksum;
    case "ttest2"
        [~, p, ~, st] = ttest2(y(g == u(1)), y(g == u(2)));
        stat = st.tstat; df = st.df;
    case "kruskalwallis"
        [p, tbl] = kruskalwallis(y, g, 'off');
        stat = tbl{2, 5}; df = tbl{2, 3};
    case "anova1"
        [p, tbl] = anova1(y, g, 'off');
        stat = tbl{2, 5}; df = [tbl{2, 3} tbl{3, 3}];
    otherwise
        p = NaN;
end
end


function s = testLabel(name)
switch name
    case "ranksum",       s = "Rank-sum";
    case "ttest2",        s = "t-test";
    case "kruskalwallis", s = "Kruskal-Wallis";
    case "anova1",        s = "ANOVA";
    otherwise,            s = "";
end
end


function s = starsOf(p)
%starsOf  Stars for adjusted p values: *** < 0.001, ** < 0.01, * < 0.05, n.s., "" for NaN.
s = repmat("n.s.", numel(p), 1);
s(p < 0.05) = "*";
s(p < 0.01) = "**";
s(p < 0.001) = "***";
s(isnan(p)) = "";
end


function P = emptyPairs()
P = table(zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), strings(0, 1), zeros(0, 1), ...
    'VariableNames', {'per', 'a', 'b', 'n1', 'n2', 'test', 'p'});
end


function F = fitOf(x, y, kind, w)
%fitOf  One series' fit in the units given (log10 already taken).
F = struct('kind', kind, 'coef', [], 'xg', zeros(0, 1), 'yg', zeros(0, 1), 'lo', zeros(0, 1), 'hi', zeros(0, 1), ...
    'r2', NaN, 'n', numel(x), 'nLeftOut', 0);
n = numel(x);
if n < 2; return; end
switch kind
    case {"linear" "poly2" "poly3"}
        deg = find(kind == ["linear" "poly2" "poly3"]);
        if n < deg + 1 || numel(unique(x)) < deg + 1; return; end
        state = warning('off', 'all');
        restore = onCleanup(@() warning(state));
        F.coef = polyfit(x, y, deg);
        F.xg = linspace(min(x), max(x), 100).';
        F.yg = polyval(F.coef, F.xg);
        F.lo = NaN(100, 1); F.hi = NaN(100, 1);
        spec = 'linear';
        if deg > 1; spec = sprintf('poly%d', deg); end
        mdl = fitlm(x, y, spec);
        F.r2 = mdl.Rsquared.Ordinary;
        if n > deg + 1
            [~, ci] = predict(mdl, F.xg);   % the 95% confidence band of the curve
            F.lo = ci(:, 1); F.hi = ci(:, 2);
        end
        clear restore
    case {"movmean" "movmedian"}
        [xs, o] = sort(x);
        w = max(2, round(w));
        if kind == "movmean"
            yg = movmean(y(o), w);
        else
            yg = movmedian(y(o), w);
        end
        F.xg = xs; F.yg = yg;
        F.lo = NaN(n, 1); F.hi = NaN(n, 1);
        ss = sum((y - mean(y)) .^ 2);
        if ss > 0; F.r2 = 1 - sum((y(o) - yg) .^ 2) / ss; end
end
end
