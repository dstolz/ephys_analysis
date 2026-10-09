function txt = plotCaption(spec, R)
%plotCaption  One sentence saying what a plot shows and how it was made.
%   TXT = plotCaption(SPEC, R) describes the plot SPEC (from plotFor) and its
%   result R (computePlot / the compute functions, with R.epochs), e.g.
%     "PSTH, Stim onset, first per trial; window [-0.2 0.8] s; bins 10 ms,
%      smooth 20 ms; trials: PairingFlag ok & Hit; groups by Depth
%      (n = 4, 5); 12 sorted units (su, mua)"
%   A tuning curve ignores the trial groups: its caption counts the epochs
%   of each curve instead ("n = 12 epochs", or "one curve per TrialType
%   (n = 5, 7 epochs)"). Epochs left out for touching an artifact period
%   are counted ("3 epoch(s) touching an artifact period left out"). A
%   spikePSTH result whose whole bins (counted from
%   the event, R.window) span less than the window says so: "window
%   [-0.2 0.8] s (whole bins: [-0.18 0.78] s)". An auROC result (spikePSTH
%   BaselineMode "auroc") says how the auROC was made and, with a cutoff,
%   how many units each group's call finds modulated up and down. A plot
%   with unit waveforms (R.waveforms) says what its boxes show ("each
%   unit's mean waveform and up to 100 of its spikes on its peak channel")
%   and how many units fell back to their template; a waveforms plot adds
%   how its units are laid out and scaled. An event shifted by a
%   trial parameter says so ("RespWindow onset + RespLatency (ms)") and
%   counts the events left out for lacking a value; a raster says how its
%   rows are sorted and which events it marks; a behavior plot what it
%   plots against what, per series, and how many epochs had no value. The
%   reports print it under each figure.
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
if spec.kind == "waveforms"
    parts(end+1) = waveText(spec, R.waveforms) + waveLayoutText(spec);
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
    p1 = K.Label(K.Kind == p1) + ", " + r.line + " " + r.edge + shiftText(r) + ", " + which + where;
    if r.offsetSec ~= 0; p1 = p1 + sprintf(" %+g s", r.offsetSec); end
    parts = p1;
    w = U.window;
    if spec.kind == "behavior"
        if ~isempty(w.stop); parts(end+1) = "stop at " + w.stop.line + " " + w.stop.edge + shiftText(w.stop); end
    elseif w.mode == "between"
        parts(end+1) = sprintf("window %s%s to %s %s%s%s", r.line, offs(w.pre), w.stop.line, w.stop.edge, shiftText(w.stop), offs(w.post));
    else
        parts(end+1) = sprintf("window [%g %g] s", w.pre, w.post);
        if R.kind == "psth" && isfield(R, 'window') && numel(R.window) == 2 && max(abs(R.window(:).' - [w.pre w.post])) > 1e-9
            what = "whole bins";
            if isfield(R, 'auroc') && isstruct(R.auroc) && ~isempty(R.auroc); what = "auROC windows"; end
            parts(end) = parts(end) + sprintf(" (%s: [%g %g] s)", what, R.window(1), R.window(2));   % bins count from the event
        end
        if ~isempty(w.stop); parts(end+1) = "stop at " + w.stop.line + " " + w.stop.edge + shiftText(w.stop); end
    end
end
if spec.kind == "corrmap"
    type = "Pearson";
    if R.type == "spearman"; type = "Spearman"; end
    parts(end+1) = sprintf("%s correlation of each epoch's %s rate between every pair of units", type, R.metric);
end
if isfield(R, 'params')
    P = R.params;
    auroc = isfield(R, 'auroc') && isstruct(R.auroc) && ~isempty(R.auroc);
    if isfield(P, 'BinSec') && ~(isfield(P, 'Metric') && P.Metric == "mean")
        b = sprintf("bins %g ms", 1000 * P.BinSec);
        if P.SmoothSec > 0 && ~auroc; b = b + sprintf(", smooth %g ms", 1000 * P.SmoothSec); end
        parts(end+1) = b;
    end
    mode = "";
    if isfield(P, 'BaselineMode'); mode = P.BaselineMode; end
    if isfield(P, 'Normalize'); mode = P.Normalize; end
    if auroc
        parts = [parts aurocText(R)];
    elseif mode ~= "" && mode ~= "none" && isfield(P, 'Baseline') && numel(P.Baseline) == 2
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
    if ~ismember(spec.kind, ["tuning" "behavior"])   % their curves are their series (below), not the trial groups
        if ~isempty(s.groupBy)
            parts(end+1) = sprintf("groups by %s (n = %s)", strjoin(s.groupBy, " x "), strjoin(string(R.n(:).'), ", "));
        elseif isfield(R, 'epochs')
            parts(end+1) = sprintf("n = %d epochs", height(R.epochs));
        end
    end
end
if spec.kind == "tuning"
    n = sum(R.n, 1);   % epochs per curve
    if R.seriesParam ~= ""
        parts(end+1) = sprintf("one curve per %s (n = %s epochs)", R.seriesParam, strjoin(string(n), ", "));
    else
        parts(end+1) = sprintf("n = %d epochs", sum(n));
    end
end
if spec.kind == "behavior"
    what = R.yName;
    if R.units ~= ""; what = what + " (" + R.units + ")"; end
    parts(end+1) = what + " by " + R.param;
    n = sum(R.n, 1);   % epochs per series
    if R.seriesParam ~= ""
        parts(end+1) = sprintf("one series per %s (n = %s epochs)", R.seriesParam, strjoin(string(n), ", "));
    else
        parts(end+1) = sprintf("n = %d epochs", sum(n));
    end
    if R.nMissing > 0
        parts(end+1) = sprintf("%d epoch(s) without a value of %s or %s left out", R.nMissing, R.yName, R.param);
    end
    switch spec.layout
        case "box",    parts(end+1) = "box plots (median, quartiles, whiskers to 1.5 IQR, outliers as dots)";
        case "violin", parts(end+1) = "violins of the values' density, with the mean +/- SEM";
        case "swarm",  parts(end+1) = "every epoch's value, with the mean +/- SEM";
        case "points", parts(end+1) = "every epoch's value, with the mean +/- SEM";
        case "line",   parts(end+1) = "mean +/- SEM";
    end
    if ~spec.style.ShowSEM && spec.layout ~= "box"; parts(end) = replace(parts(end), " +/- SEM", ""); end
end
if isfield(U, 'nDroppedNoValue') && U.nDroppedNoValue > 0
    parts(end+1) = sprintf("%d event(s) without a value of %s left out", U.nDroppedNoValue, U.ref.offsetParam);
end
if isfield(U, 'nDroppedArtifact') && U.nDroppedArtifact > 0
    parts(end+1) = sprintf("%d epoch(s) touching an artifact period left out", U.nDroppedArtifact);
end
if spec.kind == "psth"
    switch spec.normalize
        case "unitPeak",  parts(end+1) = "each unit's PSTHs normalized to its largest peak";
        case "groupPeak", parts(end+1) = "each PSTH normalized to its own peak";
    end
    if spec.stack && size(R.rate, 3) > 1
        parts(end+1) = "groups stacked, first at the bottom";
    end
end
if ismember(spec.kind, ["psth" "raster"]) && isfield(R, 'raster') && ~isempty(R.raster)
    by = spec.rasterSort;
    if by == "stop"; by = "stop latency"; end
    if by == "" && spec.rasterSortOrder == "descending"; by = "time"; end
    within = " within each group";
    if ~spec.rasterByGroup && height(R.groups) > 1; within = " across groups"; end
    if by ~= ""
        dir = "";
        if spec.rasterSortOrder == "descending"; dir = ", descending"; end
        parts(end+1) = "raster epochs sorted by " + by + dir + within;
    elseif within == " across groups"
        parts(end+1) = "raster epochs in time order across groups";
    end
    if isfield(R, 'rasterEvents') && ~isempty(R.rasterEvents)
        where = "in each epoch's window";
        if spec.rasterEvents.scope == "trial"; where = "in each epoch's own trial"; end
        parts(end+1) = "raster marks: " + strjoin([R.rasterEvents.label], ", ") + " (every one " + where + ")";
    end
end
if isfield(R, 'waveforms') && spec.waveform.mode ~= "off"
    parts(end+1) = waveText(spec, R.waveforms);
end
parts(end+1) = sourceText(spec, R);
txt = strjoin(parts, "; ") + ".";
end


function s = waveText(spec, W)
%waveText  What each unit's waveform box shows, and where it fell back.
n = W.maxSpikes;
over = "";
if spec.source == "units"; over = sprintf(" (of up to %d spikes)", n); end
switch spec.waveform.mode
    case "mean",      s = "each unit's mean waveform" + over;
    case "subsample", s = sprintf("up to %d of each unit's spikes", n);
    otherwise,        s = sprintf("each unit's mean waveform and up to %d of its spikes", n);
end
s = s + " on its peak channel";
nT = nnz(W.from == "template");
nN = nnz(W.from == "none");
if nT > 0; s = s + sprintf(", %d by their template (the sorted .bin is not there)", nT); end
if nN > 0; s = s + sprintf(", none for %d", nN); end
end


function s = waveLayoutText(spec)
%waveLayoutText  How a waveforms plot lays its units out and scales them.
if spec.layout == "probe"
    s = ", each at its unit's place on the probe";
else
    s = ", one tile per unit";
end
if spec.waveform.ampScale == "common"
    s = s + ", on one amplitude scale";
else
    s = s + ", each on its own amplitude scale";
end
end


function parts = aurocText(R)
%aurocText  How an auROC result was made and what its call found, e.g.
%   "auROC against the baseline [-0.5 0] s, from the PSTH's bins in 100 ms
%   windows, tiled"; "units called over [0 0.5] s by the 95% CI cutoff
%   (+/-0.043): Hit 5 up, 2 down; FA 3 up, 0 down (of 12 units)".
A = R.auroc;
a = A.settings;
from = "the PSTH's bins";
if A.method == "epochs"; from = "each epoch's spike count"; end
how = "tiled";
if A.windows == "sliding"; how = sprintf("sliding every %g ms", 1000 * a.stepSec); end
parts = sprintf("auROC against the baseline [%g %g] s, from %s in %g ms windows, %s", ...
    A.baseline(1), A.baseline(2), from, 1000 * a.windowSec, how);
switch A.cutoff
    case "none"
        return
    case "ci"
        by = sprintf("the 95%% CI cutoff (+/-%.3g)", A.cutoffValue);
    case "fixed"
        by = sprintf("a fixed cutoff (+/-%g)", a.threshold);
    case "test"
        corr = upper(a.correction);
        if a.correction == "none"; corr = "unadjusted"; end
        by = sprintf("%s p (%s) <= %g", a.test, corr, a.alpha);
end
labels = R.groups.label;
counts = compose("%d up, %d down", A.nIncrease(:), A.nDecrease(:));
if numel(labels) > 1; counts = string(labels(:)) + " " + counts; end
txt = sprintf("units called over [%g %g] s by %s: %s (of %d units)", A.modulationWindow(1), A.modulationWindow(2), ...
    by, strjoin(counts, "; "), A.nUnits);
if a.modulatedOnly; txt = txt + ", only the modulated drawn"; end
parts(end+1) = txt;
end


function s = sourceText(spec, R)
if spec.kind == "behavior" || spec.source == "trials"
    s = "from the paired trials";
    return
end
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


function s = shiftText(r)
%shiftText  " + RespLatency (ms)" for an event shifted by a trial parameter, else "".
s = "";
if isfield(r, 'offsetParam') && r.offsetParam ~= ""
    s = " + " + r.offsetParam + " (" + r.offsetParamUnit + ")";
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
