function txt = plotCaption(spec, R)
%plotCaption  One sentence saying what a plot shows and how it was made.
%   TXT = plotCaption(SPEC, R) describes the plot SPEC (from plotFor) and its
%   result R (computePlot / the compute functions, with R.epochs), e.g.
%     "PSTH, Stim onset, first per trial; window [-0.2 0.8] s; bins 10 ms,
%      smooth 20 ms; trials: PairingFlag ok & Hit; groups by Depth
%      (n = 4, 5); 12 sorted units (su, mua)"
%   The reports print it under each figure.
%
%   See also renderPlot, writeHtmlReport, writePdfReport.

spec = plotSpecFor(R, spec);
K = EphysAnalysisConfig.plotKinds();
parts = K.Label(K.Kind == spec.kind);
if spec.kind == "probemap"
    parts(end+1) = sprintf("%s of each site", R.valueName);
    parts(end+1) = sourceText(spec, R);
    txt = strjoin(parts, "; ") + ".";
    return
end
U = struct();
if isfield(R, 'epochs') && istable(R.epochs); U = R.epochs.Properties.UserData; end
if isfield(U, 'ref')
    r = U.ref;
    where = " in the recording";
    if U.scope == "trial"; where = " per trial"; end
    which = r.which;
    if which == "nth"; which = ordinal(r.n); end
    if which == "all"; which = "every"; end
    p1 = spec.kind;
    p1 = K.Label(K.Kind == p1) + ", " + r.line + " " + r.edge + ", " + which + where;
    if r.offsetSec ~= 0; p1 = p1 + sprintf(" %+g s", r.offsetSec); end
    parts = p1;
    w = U.window;
    if w.mode == "between"
        parts(end+1) = sprintf("window %s%s to %s %s%s", r.line, offs(w.pre), w.stop.line, w.stop.edge, offs(w.post));
    else
        parts(end+1) = sprintf("window [%g %g] s", w.pre, w.post);
        if ~isempty(w.stop); parts(end+1) = "stop at " + w.stop.line + " " + w.stop.edge; end
    end
end
if isfield(R, 'params')
    P = R.params;
    if isfield(P, 'BinSec')
        b = sprintf("bins %g ms", 1000 * P.BinSec);
        if P.SmoothSec > 0; b = b + sprintf(", smooth %g ms", 1000 * P.SmoothSec); end
        parts(end+1) = b;
    end
    mode = "";
    if isfield(P, 'BaselineMode'); mode = P.BaselineMode; end
    if isfield(P, 'Normalize'); mode = P.Normalize; end
    if mode ~= "" && mode ~= "none" && isfield(P, 'Baseline') && numel(P.Baseline) == 2
        parts(end+1) = sprintf("baseline %s over [%g %g] s", mode, P.Baseline(1), P.Baseline(2));
    end
end
if isfield(U, 'selection')
    s = U.selection;
    tr = strings(1, 0);
    if ~isempty(s.pairingFlags); tr(end+1) = "PairingFlag " + strjoin(s.pairingFlags, "|"); end
    if ~isempty(s.response);     tr(end+1) = strjoin(s.response, "|"); end
    if s.filter ~= "";           tr(end+1) = "(" + s.filter + ")"; end
    if ~isempty(s.trials);       tr(end+1) = "rows " + mat2str(s.trials); end
    if ~isempty(tr) && U.nTrials > 0; parts(end+1) = "trials: " + strjoin(tr, " & "); end
    n = R.n(:).';
    if spec.kind == "tuning"; n = sum(R.n, 1); end
    if ~isempty(s.groupBy)
        parts(end+1) = sprintf("groups by %s (n = %s)", strjoin(s.groupBy, " x "), strjoin(string(n), ", "));
    elseif isfield(R, 'epochs')
        parts(end+1) = sprintf("n = %d epochs", height(R.epochs));
    end
end
if spec.kind == "tuning" && R.seriesParam ~= ""
    parts(end+1) = "one curve per " + R.seriesParam;
end
parts(end+1) = sourceText(spec, R);
txt = strjoin(parts, "; ") + ".";
end


function s = sourceText(spec, R)
nItems = numel(R.labels);
if isfield(R, 'n') && spec.kind == "probemap"; nItems = R.n; end
switch spec.source
    case "units"
        s = sprintf("%d sorted unit(s)", nItems);
        if ~isempty(spec.units.classes); s = s + " (" + strjoin(spec.units.classes, ", ") + ")"; end
    case "detected"
        s = sprintf("threshold detections on %d channel(s)", nItems);
    otherwise
        s = sprintf("%s, %d channel(s)", spec.source, nItems);
end
end


function s = offs(x)
if x == 0
    s = "";
else
    s = sprintf(" %+g s", x);
end
end


function s = ordinal(n)
suffix = "th";
if mod(n, 100) < 11 || mod(n, 100) > 13
    switch mod(n, 10)
        case 1, suffix = "st";
        case 2, suffix = "nd";
        case 3, suffix = "rd";
    end
end
s = n + suffix;
end
