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
%   with its latency box plot on (options.latencyBox) say so with their
%   latency window: "each epoch's first spike in [0 50] ms marked on the
%   raster"; "a box plot of the first-spike latencies in [0 to the window's
%   end] per trial group over the PSTH (median, quartiles, whiskers to 1.5
%   IQR, outliers)".
%   TXT = figureCaption(SPEC, T, Sessions=S) describes a session figure
%   drawn for each row of T (figureSessionObservations) across the sessions
%   S (sessionTable rows; those with status other than "done" are left
%   out): "rp: site ch 7 across 3 sessions (1 subject); panels: ...", or
%   "rp: 12 observations (sorted units, matched by site) across 3 sessions
%   (2 subjects); ...", then the panels, alignment and grouping as above,
%   and the series ("a color per session", "per subject", "all sessions
%   averaged") and the trial groups' handling ("trial groups pooled", "one
%   figure per trial group", "trial groups by line style").
%
%   See also figureObservations, addReportFigure,
%   EphysAnalysisRunner.runDataset.

arguments
    spec (1,1) struct
    T table
    opts.Dataset (1,1) string = ""
    opts.Sessions = []
    opts.Auroc = []
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
if isfield(spec, 'title') && spec.title ~= ""; head = head + " (" + spec.title + ")"; end
if across
    S = opts.Sessions;
    if ismember("status", string(S.Properties.VariableNames)); S = S(S.status == "done", :); end
    nS = height(S);
    subj = unique(S.subject(S.subject ~= ""));
    sTxt = sprintf("%d session%s", nS, plural(nS));
    if ~isempty(subj); sTxt = sTxt + sprintf(" (%d subject%s)", numel(subj), plural(numel(subj))); end
    ss = spec.sessions;
    if ob.kind == "unit"; what = what + ", matched by " + ss.match; end
    if n == 1
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
elseif isfield(ob, 'perGroup') && ob.perGroup && isfield(spec.selection, 'groupBy') && ~isempty(spec.selection.groupBy)
    parts(end+1) = "one figure per trial group";
end
txt = strjoin(parts, "; ") + ".";
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
%latencyText  The first-spike latency a figure's raster marks and its PSTH's box plot draws, with each one's window (the first panel of each type with it on).
parts = strings(1, 0);
did = strings(1, 0);
for k = 1:numel(spec.panels)
    p = spec.panels(k);
    o = p.options;
    if p.type == "raster" && ~ismember("raster", did) && isfield(o, 'firstSpike') && isstruct(o.firstSpike) && o.firstSpike.enabled
        parts(end+1) = "each epoch's first spike in " + windowText(o.firstSpike) + " marked on the raster"; %#ok<AGROW>
        did(end+1) = "raster"; %#ok<AGROW>
    elseif p.type == "psth" && ~ismember("psth", did) && isfield(o, 'latencyBox') && isstruct(o.latencyBox) ...
            && o.latencyBox.enabled && o.display ~= "heatmap"
        where = "over the PSTH";
        if o.stack; where = "in each row of the PSTH"; end
        parts(end+1) = "a box plot of the first-spike latencies in " + windowText(o.latencyBox) + " per trial group " + where + ...
            " (median, quartiles, whiskers to 1.5 IQR, outliers)"; %#ok<AGROW>
        did(end+1) = "psth"; %#ok<AGROW>
    end
end
end


function s = windowText(L)
%windowText  A latency window in ms: "[0 50] ms", "[5 ms to the window's end]".
if isfinite(L.maxSec)
    s = sprintf("[%g %g] ms", 1000 * L.minSec, 1000 * L.maxSec);
else
    s = sprintf("[%g ms to the window's end]", 1000 * L.minSec);
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
