function lines = trialStatsText(F)
%trialStatsText  A figure's trial panels' statistics in words: one line per panel, for a caption or a report.
%   LINES = trialStatsText(F) for a computed figure F (figureCompute,
%   figureSessionCompute; any struct with panels(k).id, .type and
%   .layers(j).R) is a string column, one line per trial panel
%   (EphysAnalysisConfig.TrialPanelTypes) with a computed layer, in panel
%   order, read from the layers' R (computeTrialPanel, trialPanelStats:
%   R.stats, R.categories, R.series, R.drops), e.g.
%     "trialDist_1: Hit 412 ± 18.3 ms (n = 12), Miss 655 ± 40.1 ms (n = 9);
%      Rank-sum p = 0.000123; Hit vs Miss p = 0.000123 (holm)***;
%      3 trials without a Platform offset"
%   The parts, joined by "; ":
%     the summary  per category and series with values: its label (the
%                  category's, the series', "<category> · <series>" when
%                  both have several levels, else the measure's), the
%                  center (mean or median, the panel's summary) ± the half
%                  width of its error (or "[lo, hi]" when the error is not
%                  symmetric: iqr, ci95), the measure's unit and n
%     the tests    each omnibus test with a p value: "<test> p = <p>"
%                  ("<series>: " first when there is one per series)
%     the pairs    each pair with a p value: "<a> vs <b> p = <adjusted p>
%                  (<adjustment>)<stars>" (no adjustment named for "none";
%                  no stars for n.s.)
%     a scatter    each series' correlation and fit: "Pearson r = 0.61,
%                  p = 0.004; linear fit R² = 0.37" ("<series>: " first
%                  with several series)
%     the drops    of each computed layer, when any: "<k> trials without a
%                  <B>" (the measure's B event; the x measure's too),
%                  "<k> without a value", "<k> unpaired" (a scatter's
%                  values without a partner); "<layer>: " first with
%                  several layers
%   Numbers have 3 significant digits (no exponent from 1000 to 10^7);
%   a NaN p (too few values, test "none") is left out. Empty when F has no
%   trial panel computed.
%   figureCaption(..., Results=) appends these lines; the runner passes
%   each observation's F there.
%
%   See also figureCaption, trialStats, trialPanelStats, latencyMethodText.

arguments
    F (1,1) struct
end

lines = strings(0, 1);
if ~isfield(F, 'panels'); return; end
for k = 1:numel(F.panels)
    P = F.panels(k);
    if ~isfield(P, 'type') || ~ismember(string(P.type), EphysAnalysisConfig.TrialPanelTypes) || ~isfield(P, 'layers')
        continue
    end
    done = find(arrayfun(@(l) isstruct(l.R) && isfield(l.R, 'stats') && (~isfield(l, 'skip') || l.skip == ""), P.layers));
    if isempty(done); continue; end
    R = P.layers(done(1)).R;
    id = string(P.type) + "_" + k;
    if isfield(P, 'id') && string(P.id) ~= ""; id = string(P.id); end
    parts = [summaryText(R) testText(R) pairText(R) corrText(R) dropText(P.layers(done))];
    parts = parts(parts ~= "");
    if isempty(parts); continue; end
    lines(end+1, 1) = id + ": " + strjoin(parts, "; "); %#ok<AGROW>
end
end


function s = summaryText(R)
%summaryText  "<label> <center> ± <err> <unit> (n = k)" per category and series with values.
Tb = R.stats.table;
nC = height(R.categories);
nS = height(R.series);
unit = "";
if isfield(R, 'unit') && string(R.unit) ~= ""; unit = " " + string(R.unit); end
items = strings(1, 0);
for r = 1:height(Tb)
    if Tb.n(r) == 0; continue; end
    c = Tb.category(r);
    z = Tb.series(r);
    if nC > 1 && nS > 1
        lab = R.categories.label(c) + " " + char(183) + " " + R.series.label(z);
    elseif nC > 1
        lab = R.categories.label(c);
    elseif nS > 1
        lab = R.series.label(z);
    else
        lab = string(R.label);
    end
    v = Tb.center(r);
    lo = Tb.lo(r);
    hi = Tb.hi(r);
    if isfinite(lo) && isfinite(hi)
        if abs((hi - v) - (v - lo)) <= 1e-9 * max(1, abs(v))
            num = num3(v) + " " + char(177) + " " + num3((hi - lo) / 2);
        else
            num = num3(v) + " [" + num3(lo) + ", " + num3(hi) + "]";
        end
    else
        num = num3(v);
    end
    items(end+1) = lab + " " + num + unit + " (n = " + Tb.n(r) + ")"; %#ok<AGROW>
end
s = joinOr(items, ", ");
end


function s = testText(R)
%testText  "<test> p = <p>" for each omnibus test with a p value.
T = R.stats.test;
items = strings(1, 0);
for t = reshape(T, 1, [])
    if ~isfinite(t.p); continue; end
    pre = "";
    if numel(T) > 1 && t.per >= 1 && t.per <= height(R.series); pre = R.series.label(t.per) + ": "; end
    items(end+1) = pre + string(t.label) + " p = " + num3(t.p); %#ok<AGROW>
end
s = joinOr(items, "; ");
end


function s = pairText(R)
%pairText  "<a> vs <b> p = <pAdj> (<adjust>)<stars>" for each pair with a p value.
s = "";
P = R.stats.pairs;
if ~istable(P) || height(P) == 0; return; end
adjust = "holm";
if isfield(R.stats, 'options') && isfield(R.stats.options, 'Adjust'); adjust = string(R.stats.options.Adjust); end
nC = height(R.categories);
L = R.series.label;
if nC > 1; L = R.categories.label; end
items = strings(1, 0);
for r = 1:height(P)
    p = P.pAdj(r);
    if ~isfinite(p); continue; end
    pre = "";
    if nC > 1 && height(R.series) > 1 && P.per(r) >= 1; pre = R.series.label(P.per(r)) + ": "; end
    txt = pre + L(P.a(r)) + " vs " + L(P.b(r)) + " p = " + num3(p);
    if adjust ~= "none"; txt = txt + " (" + adjust + ")"; end
    st = string(P.stars(r));
    if st ~= "n.s."; txt = txt + st; end
    items(end+1) = txt; %#ok<AGROW>
end
s = joinOr(items, ", ");
end


function s = corrText(R)
%corrText  A scatter's correlation and fit per series: "Pearson r = 0.61, p = 0.004; linear fit R² = 0.37".
s = "";
if ~isfield(R.stats, 'corr') || ~isfield(R.stats, 'fit'); return; end
C = R.stats.corr;
Ft = R.stats.fit;
nS = max(numel(C), numel(Ft));
items = strings(1, 0);
for z = 1:nS
    bits = strings(1, 0);
    if z <= numel(C) && isfinite(C(z).r)
        ty = string(C(z).type);
        b = upper(extractBefore(ty, 2)) + extractAfter(ty, 1) + " r = " + num3(C(z).r);
        if isfinite(C(z).p); b = b + ", p = " + num3(C(z).p); end
        bits(end+1) = b; %#ok<AGROW>
    end
    if z <= numel(Ft) && isfinite(Ft(z).r2)
        bits(end+1) = fitWord(Ft(z).kind) + " fit R" + char(178) + " = " + num3(Ft(z).r2); %#ok<AGROW>
    end
    if isempty(bits); continue; end
    pre = "";
    if nS > 1 && z <= height(R.series); pre = R.series.label(z) + ": "; end
    items(end+1) = pre + strjoin(bits, "; "); %#ok<AGROW>
end
s = joinOr(items, "; ");
end


function s = dropText(layers)
%dropText  What each computed layer left out: trials without its B event, without a value, unpaired.
items = strings(1, 0);
for j = 1:numel(layers)
    R = layers(j).R;
    if ~isfield(R, 'drops') || ~isstruct(R.drops); continue; end
    D = R.drops;
    bits = [noB(D, 'nNoB', R, 'measure') noB(D, 'xNoB', R, 'xMeasure')];
    nv = getOr(D, 'nNoValue') + getOr(D, 'xNoValue');
    if nv > 0; bits(end+1) = nv + " without a value"; end %#ok<AGROW>
    nu = getOr(D, 'nUnpaired');
    if nu > 0; bits(end+1) = nu + " unpaired"; end %#ok<AGROW>
    if isempty(bits); continue; end
    pre = "";
    if numel(layers) > 1
        nm = string(layers(j).name);
        if nm == "" && isfield(R, 'label'); nm = string(R.label); end
        pre = nm + ": ";
    end
    items(end+1) = pre + strjoin(bits, ", "); %#ok<AGROW>
end
s = joinOr(items, "; ");
end


function b = noB(D, f, R, mf)
%noB  "<k> trials without a <B>": a measure's A events without their B.
b = strings(1, 0);
n = getOr(D, f);
if n <= 0; return; end
what = "its second event";
if isfield(R, mf) && isstruct(R.(mf)) && isfield(R.(mf), 'to') && isstruct(R.(mf).to)
    what = eventRefLabel(R.(mf).to);
end
w = "trials";
if n == 1; w = "trial"; end
b = n + " " + w + " without a " + what;
end


function v = getOr(D, f)
v = 0;
if isfield(D, f) && isnumeric(D.(f)) && isscalar(D.(f)) && isfinite(D.(f)); v = double(D.(f)); end
end


function s = fitWord(kind)
switch string(kind)
    case "linear",    s = "linear";
    case "poly2",     s = "quadratic";
    case "poly3",     s = "cubic";
    case "movmean",   s = "moving-mean";
    case "movmedian", s = "moving-median";
    otherwise,        s = string(kind);
end
end


function s = joinOr(items, sep)
s = "";
if ~isempty(items); s = strjoin(items, sep); end
end


function s = num3(x)
%num3  A number with 3 significant digits ("14400", not "1.44e+04", from 1000 up to 10^7).
r = round(x, 3, 'significant');
if isfinite(r) && abs(r) >= 1000 && abs(r) < 1e7
    s = string(sprintf('%.0f', r));
else
    s = string(sprintf('%.3g', x));
end
end
