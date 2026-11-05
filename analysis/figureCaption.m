function txt = figureCaption(spec, T, opts)
%figureCaption  One sentence saying what a figure shows over a dataset's observations.
%   TXT = figureCaption(SPEC, T, Dataset=NAME) describes the figure SPEC
%   (figureFor) drawn for each row of T (figureObservations: the
%   observations of one dataset), e.g.
%     "rp: 12 observations (sorted units: su, mua) of RAT1_260918; panels:
%      raster, PSTH; aligned to Stim onset; window [-0.2 0.8] s; groups by
%      Depth."
%   Parts: the figure's id (and its title, when it has one), how many
%   observations of what kind (sorted units or detections and the unit
%   filter's classes, the observed extract's channels, or the dataset
%   itself), the panels' types in order (each type once), and, when a
%   panel with an enabled layer is aligned to events, the event
%   (eventRefLabel), the window ("from <event> to <stop>" for a "between"
%   window) and the trial grouping, and "one figure per trial group" for a
%   perGroup figure (T then has a row per observation and group, each
%   counted as an observation). The stars follow the count: "starred
%   only" for a figure that keeps only the starred observations
%   (observe.starred), else how many of them are starred (T.starred,
%   figureObservations' and figureSessionObservations' column) when any
%   are: "12 observations (sorted units: su, mua; 3 starred)"; one
%   observation of a session figure: "site ch 7 (starred) across 3
%   sessions". NAME (default "") is left out when
%   empty. The reports print it under the figure's pages
%   (addReportFigure Caption=).
%   A figure with an auROC PSTH or heat map (baseline Mode "auroc") says how
%   the auROC is made (the baseline window, from the PSTH's bins or each
%   epoch's count, the window length, tiled or sliding); Auroc=CALLS (one
%   figureAurocCalls result per observation, a struct array or a cell) adds
%   what the cutoff called, summed over the observations: "units called
%   over [0 0.5] s by a fixed cutoff (+/-0.2): Hit 2 up, 1 down; ... (of 6
%   units)" (none with the cutoff "none").
%   A raster with its first-spike marks on (options.firstSpike) and a PSTH
%   with its latency box plot on (options.latencyBox) say so, and how the
%   figure's latency block finds each epoch's latency (latencyMethodText:
%   its rule, window and baseline): "each epoch's first-spike latency
%   (the first spike in [0 50] ms) marked on the raster"; "a box plot of
%   the first-spike latencies (...) per trial group over the PSTH (median,
%   quartiles, whiskers to 1.5 IQR, outliers)". A raster or PSTH with its
%   onset line on (options.onsetLine) says how the onset is found: "the
%   unit's response onset (the CUSUM of the PSTH in 2 ms bins ...) drawn
%   on the raster" ("each trial group's" with "groups").
%   TXT = figureCaption(SPEC, T, Sessions=S) describes a session figure
%   drawn for each row of T (figureSessionObservations) across the sessions
%   S (sessionTable rows; those with status other than "done" are left
%   out): "rp: site ch 7 across 3 sessions (1 subject); panels: ...", or
%   "rp: 12 observations (sorted units, matched by site) across 3 sessions
%   (2 subjects); ...", then the panels, alignment and grouping as above,
%   and the series ("a color per session", "per subject", "all sessions
%   averaged") and the trial groups' handling ("trial groups pooled", "one
%   figure per trial group", "trial groups by line style").
%   A trial panel (trialDist, trialHist, trialScatter) says what it draws:
%   "a distribution of Stim onset -> Platform offset (ms) per trial by
%   TrialType (mean +/- SEM); rank-sum (2 levels) or Kruskal-Wallis tests
%   across the categories in each series, all pairs adjusted by Holm,
%   alpha 0.05" (its measures' labels, trialMeasureLabel; its categories
%   and, unless one layer is its one series, its series: "a color per
%   Depth (3 bins)"; summary and error; test, pairs, adjustment and
%   testAlpha; a scatter's x measure, fit and correlation; log axes).
%   A figure with a panel whose options.yLimMode is "batch" adds "y shared
%   across <N> observations" (YShared=N, the run's count: figureBatchYLim's
%   n), or "y shared across the run's observations" without it.
%   A probe figure (SPEC.probe.enabled; T its tiles, figureProbeTiles)
%   is one page: "rp: 23 units laid out at their sites on the probe (2
%   shanks) of RAT1_260918; panels: ...; aligned to ...", the shanks
%   counted from T.shank, then the panels, alignment and grouping as
%   above, and "each panel's y shared across the tiles" with
%   probe.sharedY (no batch range, no trial group per figure: a probe
%   figure shares y across its tiles itself and ignores perGroup).
%   A figure with trial panels (trial distribution, histogram, scatter)
%   says, per such panel ("<panel id>: " first when there are several),
%   what its SPEC asks: "trial measures: Stim onset → Platform offset (ms)"
%   (each enabled layer's measure, trialMeasureLabel; a scatter's "<y> vs
%   <x>"), "categories by TrialType; series by measure" (the figure's
%   trial groups by their groupBy parameters, a parameter (binned), the
%   session or the measure; series by measure only with several layers),
%   "mean ± SEM" (summary ± errorType), "rank-sum or Kruskal-Wallis test
%   (all pairs, holm, alpha 0.05)" (test, testPairs, adjust, testAlpha;
%   "no test" for test "none") and, on a scatter, "linear fit, Pearson
%   correlation". Results=FS (each observation's computed figure, a cell
%   or a struct array) appends what they found: trialStatsText's line per
%   trial panel, each line once (a trial panel's layers are fixed, so
%   every observation's lines are alike).
%
%   See also figureObservations, addReportFigure,
%   EphysAnalysisRunner.runDataset.

arguments
    spec (1,1) struct
    T table
    opts.Dataset (1,1) string = ""
    opts.Sessions = []
    opts.Auroc = []
    opts.YShared (1,1) double = NaN
    opts.Results = []
end

n = height(T);
across = istable(opts.Sessions);
ob = spec.observe;
switch ob.kind
    case "unit"
        what = "sorted units";
        if ob.data == "detected"; what = "threshold detections"; end
        if isfield(ob, 'units') && isfield(ob.units, 'classes') && ~isempty(ob.units.classes) && ob.data == "units"
            what = what + ": " + strjoin(ob.units.classes, ", ");
        end
    case "channel"
        what = ob.data + " channels";
    otherwise
        what = "the dataset";
end
nStar = 0;
if ismember("starred", string(T.Properties.VariableNames)); nStar = nnz(T.starred); end
starTxt = "";
if isfield(ob, 'starred') && ob.starred
    starTxt = "; starred only";
elseif nStar > 0
    starTxt = sprintf("; %d starred", nStar);
end
head = spec.id;
if isfield(spec, 'title') && spec.title ~= ""
    ttl = string(spec.title);
    if contains(ttl, "{")   % its label variables as one caption has them: the observations' left "<Unit>"
        [~, V] = figureLabelVariables(spec);
        if opts.Dataset ~= ""; V.Name = opts.Dataset; end
        ttl = figureFileName(ttl, V, Kind="label");
    end
    head = head + " (" + ttl + ")";
end
onProbe = ~across && isfield(spec, 'probe') && isstruct(spec.probe) && spec.probe.enabled;
if onProbe
    tw = ["unit" "units" "at its site" "at their sites"];
    if ob.kind == "unit" && ob.data == "detected"; tw(1:2) = ["detection" "detections"]; end
    if ob.kind == "channel"; tw(1:2) = [ob.data + " channel", ob.data + " channels"]; end
    nSh = 0;
    if ismember("shank", string(T.Properties.VariableNames)); nSh = numel(unique(T.shank(isfinite(T.shank)))); end
    first = sprintf("%s: %d %s laid out %s on the probe (%d shank%s%s)", head, n, tw(1 + (n ~= 1)), tw(3 + (n ~= 1)), ...
        nSh, plural(nSh), starTxt);
elseif across
    S = opts.Sessions;
    if ismember("status", string(S.Properties.VariableNames)); S = S(S.status == "done", :); end
    nS = height(S);
    subj = unique(S.subject(S.subject ~= ""));
    sTxt = sprintf("%d session%s", nS, plural(nS));
    if ~isempty(subj); sTxt = sTxt + sprintf(" (%d subject%s)", numel(subj), plural(numel(subj))); end
    ss = spec.sessions;
    if ob.kind == "unit"; what = what + ", matched by " + ss.match; end
    if n == 1 && ob.kind == "dataset"   % the dataset itself (its label names the sessions: not "2 sessions across 2 sessions")
        first = head + ": the dataset across " + sTxt;
    elseif n == 1
        star = "";
        if nStar > 0; star = " (starred)"; end
        first = head + ": " + string(T.label(1)) + star + " across " + sTxt;
    else
        first = sprintf("%s: %d observation%s (%s%s) across %s", head, n, plural(n), what, starTxt, sTxt);
    end
else
    first = sprintf("%s: %d observation%s (%s%s)", head, n, plural(n), what, starTxt);
end
if opts.Dataset ~= ""; first = first + " of " + opts.Dataset; end
parts = string(first);

PT = EphysAnalysisConfig.panelTypes();
types = strings(1, 0);
aligned = false;
for k = 1:numel(spec.panels)
    p = spec.panels(k);
    row = PT.Type == p.type;
    if any(row)
        lbl = PT.Label(row);
        if lbl ~= upper(lbl); lbl = lower(lbl); end   % "raster", "heat map"; "PSTH" kept
        types(end+1) = lbl; %#ok<AGROW>
        if PT.Aligned(row) && ~isempty(p.layers) && any([p.layers.enabled]); aligned = true; end
    else
        types(end+1) = p.type; %#ok<AGROW>
    end
end
if ~isempty(types); parts(end+1) = "panels: " + strjoin(unique(types, 'stable'), ", "); end
if aligned
    parts(end+1) = "aligned to " + eventRefLabel(spec.ref);
    w = spec.window;
    if w.mode == "between" && ~isempty(w.stop)
        parts(end+1) = "window from " + eventRefLabel(spec.ref) + offs(w.pre) + " to " + eventRefLabel(w.stop) + offs(w.post);
    else
        parts(end+1) = sprintf("window [%g %g] s", w.pre, w.post);
    end
    g = spec.selection.groupBy;
    if ~isempty(g); parts(end+1) = "groups by " + strjoin(g, " x "); end
    parts = [parts aurocText(spec, opts.Auroc) latencyText(spec)];
end
parts = [parts trialSpecText(spec)];
if across
    switch ss.series
        case "session", parts(end+1) = "a color per session";
        case "subject", parts(end+1) = "a color per subject, its sessions averaged";
        otherwise, parts(end+1) = "all sessions averaged";
    end
    if isfield(spec.selection, 'groupBy') && ~isempty(spec.selection.groupBy)
        switch ss.trialGroups
            case "pool", parts(end+1) = "trial groups pooled";
            case "each", parts(end+1) = "one figure per trial group";
            otherwise, parts(end+1) = "trial groups by line style";
        end
    end
    if ss.facet == "subject"; parts(end+1) = "one figure per subject"; end
elseif onProbe
    if spec.probe.sharedY; parts(end+1) = "each panel's y shared across the tiles"; end
elseif isfield(ob, 'perGroup') && ob.perGroup && isfield(spec.selection, 'groupBy') && ~isempty(spec.selection.groupBy)
    parts(end+1) = "one figure per trial group";
end
if ~onProbe && ~isempty(figureBatchPanels(spec))
    if isfinite(opts.YShared) && opts.YShared > 0
        parts(end+1) = sprintf("y shared across %d observation%s", opts.YShared, plural(opts.YShared));
    else
        parts(end+1) = "y shared across the run's observations";
    end
end
txt = strjoin(parts, "; ") + ".";
stats = resultsText(opts.Results);
if ~isempty(stats); txt = txt + " " + strjoin(stats + ".", " "); end
end


function parts = trialSpecText(spec)
%trialSpecText  What each trial panel of SPEC measures, how it groups, summarizes and tests (figureCaption's header).
parts = strings(1, 0);
isT = arrayfun(@(p) ismember(p.type, EphysAnalysisConfig.TrialPanelTypes) && ~isempty(p.layers) && any([p.layers.enabled]), ...
    spec.panels);
many = nnz(isT) > 1;
for k = find(isT)
    p = spec.panels(k);
    o = p.options;
    L = p.layers([p.layers.enabled]);
    labs = strings(1, 0);
    for j = 1:numel(L)
        lab = trialMeasureLabel(L(j).measure);
        if p.type == "trialScatter" && isfield(L(j), 'xMeasure') && isstruct(L(j).xMeasure)
            lab = lab + " vs " + trialMeasureLabel(L(j).xMeasure);
        end
        labs(end+1) = lab; %#ok<AGROW>
    end
    labs = unique(labs, 'stable');
    word = "trial measure";
    if numel(labs) > 1; word = "trial measures"; end
    first = word + ": " + strjoin(labs, ", ");
    if many
        id = string(p.type) + "_" + k;
        if isfield(p, 'id') && string(p.id) ~= ""; id = string(p.id); end
        first = id + ": " + first;
    end
    parts(end+1) = first; %#ok<AGROW>
    by = strings(1, 0);
    if p.type == "trialDist" && isfield(o, 'categories')
        by(end+1) = "categories by " + groupingWords(spec, p, o.categories, optOf(o, 'categoryParam', ""), optOf(o, 'categoryBins', [])); %#ok<AGROW>
    end
    if isfield(o, 'series') && ~(o.series == "layer" && numel(L) < 2)
        by(end+1) = "series by " + groupingWords(spec, p, o.series, optOf(o, 'seriesParam', ""), optOf(o, 'seriesBins', [])); %#ok<AGROW>
    end
    if ~isempty(by); parts(end+1) = strjoin(by, ", "); end %#ok<AGROW>
    sm = string(optOf(o, 'summary', "mean"));
    et = string(optOf(o, 'errorType', "off"));
    if et ~= "off"; sm = sm + " " + char(177) + " " + errorWord(et); end
    parts(end+1) = sm; %#ok<AGROW>
    parts(end+1) = testWords(o); %#ok<AGROW>
    if p.type == "trialScatter"
        fc = strings(1, 0);
        fit = string(optOf(o, 'fit', "none"));
        switch fit
            case "none"
            case "poly2", fc(end+1) = "quadratic fit";
            case "poly3", fc(end+1) = "cubic fit";
            case "movmean", fc(end+1) = sprintf("moving-mean fit (%g points)", optOf(o, 'fitWindow', 10));
            case "movmedian", fc(end+1) = sprintf("moving-median fit (%g points)", optOf(o, 'fitWindow', 10));
            otherwise, fc(end+1) = fit + " fit";
        end
        cr = string(optOf(o, 'corr', "none"));
        if cr ~= "none"; fc(end+1) = upper(extractBefore(cr, 2)) + extractAfter(cr, 1) + " correlation"; end
        if ~isempty(fc); parts(end+1) = strjoin(fc, ", "); end %#ok<AGROW>
    end
end
end


function s = groupingWords(spec, p, how, param, bins)
%groupingWords  A trial panel's grouping in words: the trial groups' parameters, a parameter (binned), session, measure.
switch string(how)
    case "groups"
        g = strings(1, 0);
        if isstruct(p.selection) && isfield(p.selection, 'groupBy') && ~isempty(p.selection.groupBy)
            g = string(p.selection.groupBy);
        elseif isfield(spec, 'selection') && isstruct(spec.selection) && isfield(spec.selection, 'groupBy')
            g = string(spec.selection.groupBy);
        end
        s = "the trial groups";
        if ~isempty(g); s = strjoin(g, " x "); end
    case "param"
        s = string(param);
        if isscalar(bins)
            s = s + sprintf(" (%d bins)", round(bins));
        elseif numel(bins) >= 2
            s = s + " (bins " + strjoin(compose("%g", bins), ", ") + ")";
        end
    case "layer"
        s = "measure";
    otherwise
        s = string(how);
end
end


function s = testWords(o)
%testWords  "rank-sum test (all pairs, holm, alpha 0.05)", or "no test".
t = string(optOf(o, 'test', "auto"));
switch t
    case "none", s = "no test"; return
    case "auto", s = "rank-sum or Kruskal-Wallis test";
    case "ranksum", s = "rank-sum test";
    case "ttest2", s = "t-test";
    case "kruskalwallis", s = "Kruskal-Wallis test";
    case "anova1", s = "one-way ANOVA";
    otherwise, s = t + " test";
end
pairs = "all pairs";
if string(optOf(o, 'testPairs', "all")) == "first"; pairs = "each vs the first"; end
adj = string(optOf(o, 'adjust', "holm"));
if adj == "none"; adj = "unadjusted"; end
s = s + sprintf(" (%s, %s, alpha %g)", pairs, adj, optOf(o, 'testAlpha', 0.05));
end


function s = errorWord(et)
switch et
    case "sem", s = "SEM";
    case "std", s = "SD";
    case "ci95", s = "95% CI";
    case "iqr", s = "IQR";
    otherwise, s = et;
end
end


function v = optOf(o, f, d)
v = d;
if isfield(o, f) && ~isempty(o.(f)); v = o.(f); end
end


function lines = resultsText(res)
%resultsText  trialStatsText of each computed figure, each line once.
lines = strings(0, 1);
if isempty(res); return; end
if isstruct(res); res = num2cell(res); end
for i = 1:numel(res)
    F = res{i};
    if ~isstruct(F) || ~isscalar(F); continue; end
    t = trialStatsText(F);
    lines = [lines; t(~ismember(t, lines))]; %#ok<AGROW>
end
end


function parts = aurocText(spec, calls)
%aurocText  How the figure's auROC is made (its first PSTH or heat map panel with baseline Mode "auroc") and, given
%   the observations' calls (figureAurocCalls), what they found, e.g. "auROC against the baseline [-0.5 0] s, from the
%   PSTH's bins in 100 ms windows, tiled"; "units called over [0 0.5] s by a fixed cutoff (+/-0.2): Hit 5 up, 2 down;
%   FA 3 up, 0 down (of 12 units)".
parts = strings(1, 0);
P = [];
for k = 1:numel(spec.panels)
    o = spec.panels(k).options;
    if ismember(spec.panels(k).type, ["psth" "heatmap"]) && isfield(o, 'baseline') && isstruct(o.baseline) ...
            && o.baseline.Mode == "auroc" && isfield(o, 'auroc')
        P = o;
        break
    end
end
if isempty(P); return; end
a = P.auroc;
from = "the PSTH's bins";
if a.method == "epochs"; from = "each epoch's spike count"; end
how = "tiled";
if a.windows == "sliding"; how = sprintf("sliding every %g ms", 1000 * a.stepSec); end
parts = sprintf("auROC against the baseline [%g %g] s, from %s in %g ms windows, %s", ...
    P.baseline.Window(1), P.baseline.Window(2), from, 1000 * a.windowSec, how);
if iscell(calls); calls = [calls{:}]; end
if isempty(calls) || ~isstruct(calls) || a.cutoff == "none"; return; end
calls = reshape(calls, 1, []);
switch a.cutoff
    case "ci"
        v = unique(round([calls.cutoffValue], 3, 'significant'));
        v = v(isfinite(v));
        if isscalar(v)
            by = sprintf("the 95%% CI cutoff (+/-%.3g)", v);
        else
            by = "the 95% CI cutoff (each unit's)";
        end
    case "fixed"
        by = sprintf("a fixed cutoff (+/-%g)", a.threshold);
    case "shuffle"
        v = unique(round([calls.cutoffValue], 3, 'significant'));
        v = v(isfinite(v));
        q = sprintf("the %g%% quantile of the shuffled modulation", 100 * (1 - a.alpha));
        if isscalar(v)
            by = sprintf("the shuffle cutoff (+/-%.3g, %s)", v, q);
        else
            by = sprintf("the shuffle cutoff (%s, each unit's)", q);
        end
    otherwise   % "test"
        corr = upper(a.correction);
        if a.correction == "none"; corr = "unadjusted"; end
        by = sprintf("%s p (%s) <= %g", a.test, corr, a.alpha);
end
labels = strings(0, 1);
for c = calls; labels = [labels; c.labels(~ismember(c.labels, labels))]; end %#ok<AGROW>
up = zeros(numel(labels), 1); down = up;
for c = calls
    [~, at] = ismember(c.labels, labels);
    up(at) = up(at) + c.nIncrease(:);
    down(at) = down(at) + c.nDecrease(:);
end
counts = compose("%d up, %d down", up, down);
if numel(labels) > 1; counts = labels + " " + counts; end
txt = sprintf("units called over [%g %g] s by %s: %s (of %d units)", a.modulationWindow(1), a.modulationWindow(2), ...
    by, strjoin(counts, "; "), sum([calls.nUnits]));
if a.modulatedOnly; txt = txt + ", only the modulated drawn"; end
parts(end+1) = txt;
end


function parts = latencyText(spec)
%latencyText  The first-spike latencies a figure's raster marks and its PSTH's box plot draws, and the onset lines, with how its latency block finds them (the first panel of each type with each on).
parts = strings(1, 0);
did = strings(1, 0);
L = EphysAnalysisConfig.defaults("Latency");
if isfield(spec, 'latency') && isstruct(spec.latency); L = spec.latency; end
how = " (" + latencyMethodText(L) + ")";
for k = 1:numel(spec.panels)
    p = spec.panels(k);
    o = p.options;
    if p.type == "raster" && ~ismember("raster", did) && isfield(o, 'firstSpike') && isstruct(o.firstSpike) && o.firstSpike.enabled
        parts(end+1) = "each epoch's first-spike latency" + how + " marked on the raster"; %#ok<AGROW>
        did(end+1) = "raster"; %#ok<AGROW>
        how = "";   % said once
    elseif p.type == "psth" && ~ismember("psth", did) && isfield(o, 'latencyBox') && isstruct(o.latencyBox) ...
            && o.latencyBox.enabled && o.display ~= "heatmap"
        where = "over the PSTH";
        if isfield(o, 'stack') && o.stack == "groups"; where = "in each row of the PSTH"; end
        parts(end+1) = "a box plot of the first-spike latencies" + how + " per trial group " + where + ...
            " (median, quartiles, whiskers to 1.5 IQR, outliers)"; %#ok<AGROW>
        did(end+1) = "psth"; %#ok<AGROW>
        how = "";
    end
end
onset = " (" + latencyMethodText(L, "onset") + ")";
for k = 1:numel(spec.panels)
    p = spec.panels(k);
    o = p.options;
    if ~ismember(p.type, ["raster" "psth"]) || ~isfield(o, 'onsetLine') || o.onsetLine == "off" || ismember("onset", did)
        continue
    end
    whose = "the unit's response onset";
    if o.onsetLine == "groups"; whose = "each trial group's response onset"; end
    on = "on the raster";
    if p.type == "psth"; on = "on the PSTH"; end
    parts(end+1) = whose + onset + " drawn " + on; %#ok<AGROW>
    did(end+1) = "onset"; %#ok<AGROW>
end
end


function s = plural(n)
s = "";
if n ~= 1; s = "s"; end
end


function s = offs(x)
s = "";
if x ~= 0; s = sprintf(" %+g s", x); end
end
