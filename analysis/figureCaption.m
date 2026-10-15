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
%   counted as an observation). NAME (default "") is left out when
%   empty. The reports print it under the figure's pages
%   (addReportFigure Caption=).
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
%   See also plotCaption, figureObservations, addReportFigure,
%   EphysAnalysisRunner.runDataset.

arguments
    spec (1,1) struct
    T table
    opts.Dataset (1,1) string = ""
    opts.Sessions = []
end

n = height(T);
across = istable(opts.Sessions);
ob = spec.observe;
switch ob.kind
    case "unit"
        what = "sorted units";
        if ob.source == "detected"; what = "threshold detections"; end
        if isfield(ob, 'units') && isfield(ob.units, 'classes') && ~isempty(ob.units.classes) && ob.source == "units"
            what = what + ": " + strjoin(ob.units.classes, ", ");
        end
    case "channel"
        what = ob.signal + " channels";
    otherwise
        what = "the dataset";
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
        first = head + ": " + string(T.label(1)) + " across " + sTxt;
    else
        first = sprintf("%s: %d observation%s (%s) across %s", head, n, plural(n), what, sTxt);
    end
else
    first = sprintf("%s: %d observation%s (%s)", head, n, plural(n), what);
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


function s = plural(n)
s = "";
if n ~= 1; s = "s"; end
end


function s = offs(x)
s = "";
if x ~= 0; s = sprintf(" %+g s", x); end
end
