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
%   counts the events left out for lacking a value; an event of a sequence
%   is named step by step ("Trial offset then Trough onset", eventRefLabel)
%   and the events its sequence did not follow are counted; a raster says how its
%   rows are sorted (by an event's latency: how many epochs had no such
%   event and went last) and which events it marks; a behavior plot what it
%   plots against what, per series, and how many epochs had no value; a
%   PSTH or raster with the mean aux signal (R.aux) which channels it
%   shows and how (each channel, or their vector magnitude; the baseline
%   subtracted), where, over how many epochs, and how many epochs left the
%   AUX signal or held missing samples and were left out of it. With
%   Style.ShowSEM, what the error bands or bars show: "bands: mean +/- SEM
%   across epochs", "mean +/- SD", or "the bootstrap 95% CI of the mean
%   (1000 resamples, percentile)" -- across the units for an overlay of
%   several units (PSTH, tuning). A result merged across sessions
%   (combineSessions) says over how many sessions and subjects, what its
%   series are and the band across sessions ("one series per subject, mean
%   +/- SEM across sessions"; a 95% CI across sessions is a t interval, not
%   a bootstrap), how units were matched ("units matched by site", "by the
%   mapping file", "each session's units on its own tile"), how many
%   sessions are drawn faint, and counts its tiles ("12 sites", "8 cells",
%   "37 session-units"). The reports print it under each figure.
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
    parts = [parts sessionText(R)];
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
    p1 = K.Label(K.Kind == p1) + ", " + eventRefLabel(r) + shiftText(r) + ", " + which + where;
    if r.offsetSec ~= 0; p1 = p1 + sprintf(" %+g s", r.offsetSec); end
    parts = p1;
    w = U.window;
    if spec.kind == "behavior"
        if ~isempty(w.stop); parts(end+1) = "stop at " + eventRefLabel(w.stop) + shiftText(w.stop); end
    elseif w.mode == "between"
        parts(end+1) = sprintf("window %s%s to %s%s%s", alignedLine(r), offs(w.pre), eventRefLabel(w.stop), shiftText(w.stop), offs(w.post));
    else
        parts(end+1) = sprintf("window [%g %g] s", w.pre, w.post);
        if R.kind == "psth" && isfield(R, 'window') && numel(R.window) == 2 && max(abs(R.window(:).' - [w.pre w.post])) > 1e-9
            what = "whole bins";
            if isfield(R, 'auroc') && isstruct(R.auroc) && ~isempty(R.auroc); what = "auROC windows"; end
            parts(end) = parts(end) + sprintf(" (%s: [%g %g] s)", what, R.window(1), R.window(2));   % bins count from the event
        end
        if ~isempty(w.stop); parts(end+1) = "stop at " + eventRefLabel(w.stop) + shiftText(w.stop); end
    end
end
if spec.kind == "corrmap"
    type = "Pearson";
    if R.type == "spearman"; type = "Spearman"; end
    parts(end+1) = sprintf("%s correlation of each epoch's %s rate between every pair of units", type, R.metric);
    if isfield(R, 'fisherZ') && R.fisherZ
        parts(end) = parts(end) + ", Fisher z-transformed (z = atanh r; mean r averaged in z)";
    end
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
    if spec.layout ~= "box"
        [~, ~, E] = resultBounds(R, 'mean');
        pm = errPhrase(E.type, E.nBoot);
        if isMerged(R) && isfield(R, 'err') && isfield(R.err, 'over') && R.err.over == "sessions"
            switch R.sessionSeries.error   % the band across sessions
                case "sem",  pm = " +/- SEM across sessions";
                case "sd",   pm = " +/- SD across sessions";
                case "ci95", pm = " and its 95% CI across sessions (" + R.sessionSeries.errorNote + ")";
                otherwise,   pm = "";
            end
        end
        if ~spec.style.ShowSEM; pm = ""; end
        parts(end) = replace(parts(end), " +/- SEM", pm);
    end
end
if isfield(U, 'nDroppedNoValue') && U.nDroppedNoValue > 0
    parts(end+1) = sprintf("%d event(s) without a value of %s left out", U.nDroppedNoValue, U.ref.offsetParam);
end
if isfield(U, 'nDroppedNoSequence') && U.nDroppedNoSequence > 0
    parts(end+1) = sprintf("%d event(s) the sequence did not follow left out", U.nDroppedNoSequence);
end
if isfield(U, 'nDroppedArtifact') && U.nDroppedArtifact > 0
    parts(end+1) = sprintf("%d epoch(s) touching an artifact period left out", U.nDroppedArtifact);
end
if spec.kind == "psth"
    switch spec.normalize
        case "unitPeak",  parts(end+1) = "each unit's PSTHs normalized to its largest peak";
        case "groupPeak", parts(end+1) = "each PSTH normalized to its own peak";
        case "allPeak",   parts(end+1) = "every PSTH normalized to the largest peak of all";
    end
    if spec.stack && size(R.rate, 3) > 1
        parts(end+1) = "groups stacked, first at the bottom";
        if spec.withRaster && spec.stackRaster && isfield(R, 'raster') && ~isempty(R.raster)
            parts(end) = parts(end) + ", each with its raster above it (epochs first at the bottom)";
            nMost = max(histcounts(R.epochGroup, 0.5:1:height(R.groups) + 0.5));
            if isfinite(spec.stackRasterTrials) && spec.stackRasterTrials < nMost
                parts(end+1) = sprintf("each raster at most %d epochs, spread over its order (the PSTHs use all)", spec.stackRasterTrials);
            end
            if spec.stackRasterEqual; parts(end+1) = "raster rows of one height in every group"; end
        end
    end
end
et = errorText(spec, R);
if et ~= ""; parts(end+1) = et; end
if ismember(spec.kind, ["psth" "raster"]) && isfield(R, 'raster') && ~isempty(R.raster)
    by = spec.rasterSort;
    if by == "stop"; by = "stop latency"; end
    nNoEvent = 0;
    if by == "event"
        [ev, nNoEvent] = sortEventText(spec, R);
        by = ev + " latency";
    end
    if by == "" && spec.rasterSortOrder == "descending"; by = "time"; end
    within = " within each group";
    inRows = spec.kind == "psth" && spec.stack && spec.stackRaster && height(R.groups) > 1;   % a row's raster is its group's
    if ~spec.rasterByGroup && height(R.groups) > 1 && ~inRows; within = " across groups"; end
    if by ~= ""
        dir = "";
        if spec.rasterSortOrder == "descending"; dir = ", descending"; end
        parts(end+1) = "raster epochs sorted by " + by + dir + within;
        if nNoEvent > 0
            parts(end+1) = sprintf("%d epoch(s) with no %s after their event sorted last", nNoEvent, ev);
        end
    elseif within == " across groups"
        parts(end+1) = "raster epochs in time order across groups";
    end
    if isfield(R, 'rasterEvents') && ~isempty(R.rasterEvents)
        parts(end+1) = "raster marks: " + strjoin([R.rasterEvents.label], ", ") + " (every one in each epoch's window)";
    end
end
if isfield(R, 'waveforms') && spec.waveform.mode ~= "off"
    parts(end+1) = waveText(spec, R.waveforms);
end
if ismember(spec.kind, ["psth" "raster"]) && isfield(R, 'aux') && isstruct(R.aux) && ~isempty(R.aux) && spec.aux.mode ~= "off"
    parts = [parts auxText(spec, R)];
end
parts = [parts sessionText(R)];
parts(end+1) = sourceText(spec, R);
txt = strjoin(parts, "; ") + ".";
end


function tf = isMerged(R)
%isMerged  A result merged across sessions (combineSessions).
tf = isfield(R, 'sessions') && istable(R.sessions) && isfield(R, 'sessionSeries') && isstruct(R.sessionSeries);
end


function parts = sessionText(R)
%sessionText  How a result merged across sessions was made, e.g. "across 3 sessions (2 subjects)", "one series
%   per subject, mean +/- SEM across sessions", "units matched by site", "3 sessions drawn faint" (none: empty).
%   Sessions without a subject are not counted as one; with none named the "(N subjects)" clause is left out.
parts = strings(1, 0);
if ~isMerged(R); return; end
S = R.sessions;
X = R.sessionSeries;
done = true(height(S), 1);
if ismember("status", string(S.Properties.VariableNames)); done = S.status == "done"; end
n = nnz(done);
s = sprintf("across %d session%s", n, plural(n));
if ismember("subject", string(S.Properties.VariableNames))
    subj = string(S.subject(done));
    m = numel(unique(subj(~ismissing(subj) & subj ~= "")));   % as combineSessions' subtitle: no subject is not one
    if m > 0; s = s + sprintf(" (%d subject%s)", m, plural(m)); end
end
parts = s;
err = sessionErrWords(X.error, X.errorNote);
switch X.mode
    case "session"
        parts(end+1) = "one series per session";
    case "subject"
        parts(end+1) = "one series per subject";
        if err ~= ""; parts(end) = parts(end) + ", " + err + " across sessions"; end
    otherwise
        if err ~= ""; parts(end+1) = err + " across sessions"; else; parts(end+1) = "the mean of the sessions"; end
end
if isfield(X, 'trialGroups') && X.trialGroups == "combine"
    parts(end) = parts(end) + ", a line style per trial group";
end
switch X.match
    case "site",    parts(end+1) = "units matched by site";
    case "mapping", parts(end+1) = "units matched by the mapping file";
    case "pool",    parts(end+1) = "each session's units on its own tile";
    case "channel", parts(end+1) = "channels matched by recording channel";
end
if isfield(R, 'members') && isstruct(R.members) && isfield(R.members, 'series') && ~isempty(R.members.series)
    k = numel(R.members.series);
    parts(end+1) = sprintf("%d session%s drawn faint", k, plural(k));
end
end


function s = sessionErrWords(type, note)
%sessionErrWords  The band across sessions: "mean +/- SEM", "mean +/- SD", "the mean and its 95% CI (t)" ("": none).
switch type
    case "sem",  s = "mean +/- SEM";
    case {"sd", "std"}, s = "mean +/- SD";
    case "ci95"
        if note == "" || startsWith(note, "95%"); s = "the mean and its 95% CI (t distribution)";
        else; s = "the mean +/- " + replace(note, "×", "x"); end
    otherwise,   s = "";
end
end


function s = plural(n)
s = "";
if n ~= 1; s = "s"; end
end


function [s, nNone] = sortEventText(spec, R)
%sortEventText  The event a raster is sorted by ("Platform offset"), and how many epochs have none.
nNone = 0;
if isfield(R, 'rasterSortEvent') && isstruct(R.rasterSortEvent) && isfield(R.rasterSortEvent, 'label')
    s = string(R.rasterSortEvent.label);
    nNone = nnz(~isfinite(R.rasterSortEvent.t));
elseif ~isempty(spec.rasterSortEvent)
    s = eventRefLabel(spec.rasterSortEvent);
else
    s = "event";
end
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


function parts = auxText(spec, R)
%auxText  The mean aux signal: what it is, where it is drawn, its epochs and those left out of it.
A = R.aux;
aux = EphysAnalysisConfig.normalizeSection("Aux", spec.aux);   % as the renderers read it: fields left out take their defaults
ch = strjoin(reshape(A.channelLabels, 1, []), ", ");
stat = "mean";
if isfield(A, 'statistic'); stat = A.statistic; end
rectified = isfield(A, 'rectified') && A.rectified;
if A.mode == "magnitude"
    s = "aux: " + stat + " vector magnitude (square root of the sum of squares, in each epoch at every sample) of " + ch;
elseif rectified
    s = "aux: " + stat + " of the rectified (absolute value, in each epoch at every sample) " + ch;
else
    s = "aux: " + stat + " of " + ch;
end
if isfield(A.params, 'Baseline') && numel(A.params.Baseline) == 2
    s = s + sprintf(" with each epoch's mean over [%g %g] s subtracted from each channel", A.params.Baseline(1), A.params.Baseline(2));
    if A.mode == "magnitude"; s = s + " first"; end
end
s = s + " (" + A.units + ")";
stacked = spec.kind == "psth" && spec.stack && isfield(R, 'rate') && size(R.rate, 3) > 1;
place = auxPlace(aux, stacked);   % a stack's right axis is its rows' peaks; an image is not drawn on one
what = "PSTH";
if spec.kind == "raster" || (place == "above" && spec.withRaster && ~(stacked && spec.stackRaster) && isfield(R, 'raster') && ~isempty(R.raster))
    what = "raster";
end
switch place
    case "below", s = s + ", in a panel below the " + what;
    case "above", s = s + ", in a panel above the " + what;
    otherwise
        s = s + ", on the " + what + "'s right axis";
        op = aux.overPosition;
        if numel(op) == 2 && ~isequal(op, [0 1])
            s = s + sprintf(" (from %g to %g of its height)", op(1), op(2));
        end
end
switch aux.display
    case "stacked", s = s + ", each trace in a row of its own";
    case "heatmap", s = s + ", as a heat map, a row per trace";
end
if numel(aux.yLim) == 2
    if aux.display == "heatmap"
        s = s + sprintf(", color scale [%g %g] %s", aux.yLim(1), aux.yLim(2), A.units);
    else
        s = s + sprintf(", y limits [%g %g] %s", aux.yLim(1), aux.yLim(2), A.units);
    end
end
if A.byGroup && height(A.groups) > 1
    s = s + sprintf(", one trace per group (n = %s epochs)", strjoin(string(A.nEpochs(:).'), ", "));
else
    s = s + sprintf(" (n = %d epochs)", sum(A.nEpochs));
end
if aux.errorType ~= "off" && aux.display ~= "heatmap"
    [~, ~, E] = resultBounds(A, 'mean');
    s = s + ", bands: " + auxErrWords(E.type, E.nBoot, stat) + " across epochs";
end
parts = s;
nOut = A.droppedEdge + A.droppedNonFinite;
if nOut > 0
    parts(end+1) = sprintf("%d epoch(s) leaving the AUX signal or holding missing samples left out of the aux %s", nOut, stat);
end
end


function s = errorText(spec, R)
%errorText  What a PSTH's, evoked plot's, rate plot's or tuning curve's error bands or bars show ("": none drawn).
%   Over the epochs, the error R.err holds; over the units, for an overlay
%   of several units, the style's (the renderer makes it).
s = "";
if ~spec.style.ShowSEM; return; end
across = "epochs";
switch spec.kind
    case "psth"
        if isAuroc(R); return; end
        what = "bands"; field = 'rate';
        if spec.layout == "overlay" && size(R.rate, 2) > 1; across = "units"; end
    case "evoked"
        if spec.layout == "butterfly"; return; end
        what = "bands"; field = 'mean';
    case "rate"
        if spec.layout ~= "bar"; return; end
        what = "error bars"; field = 'meanRate';
    case "tuning"
        what = "error bars"; field = 'mean';
        if spec.layout == "overlay" && size(R.mean, 2) > 1; across = "units"; end
    otherwise
        return
end
if across == "epochs" && isMerged(R) && isfield(R, 'err') && isfield(R.err, 'over') && R.err.over == "sessions"
    return   % the band across sessions: sessionText says what it is
end
if across == "units"
    type = spec.style.ErrorType;
    nBoot = spec.style.ErrorResamples;
else
    [~, ~, E] = resultBounds(R, field);
    type = E.type;
    nBoot = E.nBoot;
end
s = what + ": " + errWords(type, nBoot) + " across " + across;
end


function s = errWords(type, nBoot)
%errWords  An error band's name: "mean +/- SEM", "mean +/- SD", or the bootstrap CI and how it was made.
switch type
    case "std",  s = "mean +/- SD";
    case "ci95", s = sprintf("the bootstrap 95%% CI of the mean (%d resamples, percentile)", nBoot);
    otherwise,   s = "mean +/- SEM";
end
end


function s = auxErrWords(type, nBoot, stat)
%auxErrWords  The aux band's name: errWords' for the mean, the median's for the median, or the interquartile range.
if type == "iqr"
    s = "the interquartile range (25th to 75th percentile)";
elseif stat == "median"
    switch type
        case "std",  s = "median +/- SD";
        case "ci95", s = sprintf("the bootstrap 95%% CI of the median (%d resamples, percentile)", nBoot);
        otherwise,   s = "median +/- SEM";
    end
else
    s = errWords(type, nBoot);
end
end


function s = errPhrase(type, nBoot)
%errPhrase  " +/- SEM" in a behavior caption, or what stands for it.
switch type
    case "std",  s = " +/- SD";
    case "ci95", s = sprintf(" and its bootstrap 95%% CI (%d resamples of the epochs, percentile)", nBoot);
    otherwise,   s = " +/- SEM";
end
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
if isMerged(R)   % the tiles matched across sessions
    match = R.sessionSeries.match;
    switch match
        case "site",    s = sprintf("%d site%s", nItems, plural(nItems));
        case "mapping", s = sprintf("%d cell%s", nItems, plural(nItems));
        case "pool"
            s = sprintf("%d session-unit%s", nItems, plural(nItems));
            if spec.source == "detected"; s = sprintf("threshold detections on %d session-channel%s", nItems, plural(nItems)); end
        otherwise
            s = sprintf("%s, %d channel%s", spec.source, nItems, plural(nItems));
    end
    if spec.source == "units" && ~isempty(spec.units.classes) && match ~= "channel"
        s = s + " (" + strjoin(spec.units.classes, ", ") + ")";
    end
    return
end
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


function s = alignedLine(r)
%alignedLine  The line of the event an epoch is aligned to (a sequence's aligned step's).
s = r.line;
if ~isfield(r, 'sequence') || isempty(r.sequence); return; end
a = r.alignStep;
if isinf(a); a = find([r.sequence.relation] == "followedBy", 1, 'last'); end
if ~isempty(a) && a >= 1; s = r.sequence(a).line; end
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
