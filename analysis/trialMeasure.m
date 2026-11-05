function [T, info] = trialMeasure(src, m, mask)
%trialMeasure  One number per trial (or per event) from a trial's events or parameters.
%   [T, INFO] = trialMeasure(SRC, M, MASK) measures the trial measure M
%   (EphysAnalysisConfig.defaults("TrialMeasure"): kind, from, to,
%   direction, maxGapSec, param, unit, label) on the dataset SRC
%   (loadAnalysisSource), over the trials MASK keeps (logical over
%   src.trials, as selectTrials returns it; [] = every paired trial).
%   Pure: no I/O, no graphics.
%
%   T is a table with one row per value:
%     trial   row of src.trials the value belongs to (NaN: none, a
%             recording-scope event outside the trials of a dataset
%             without paired trials)
%     value   the measure, in M.unit for the time kinds ("ms" = s x 1000,
%             the default; "s"), a count for "count", the column's own
%             values for "param"
%     tA, tB  the A and B events, s on the digital clock (tB NaN for
%             "duration" and "param"; for "count" the first B counted, NaN
%             when none; tA is TrialOnset for "param")
%     k       which interval of its trial (or of the recording) A is, as
%             resolveEvents' K (1 for "param")
%   INFO has kind, label (M.label, else trialMeasureLabel's automatic
%   text), unit ("" for count and param), nA (A events found; trials
%   considered for param), nNoB (A events with no B, or none within
%   M.maxGapSec: delay only) and nNoValue (A events M.from's offsetParam
%   dropped, plus: duration events with no interval, param trials with a
%   non-finite value).
%
%   Kinds
%     delay     A = resolveEvents(SRC, M.from, MASK); for each A the B
%               events of M.to after it (M.direction "after": at or after
%               A, nearest first) or before it ("before": at or before A,
%               nearest first; the values are negative), found as a stop
%               event is (eventsNear: A's own trial's TrialEvents in trial
%               or auto scope, else the recording; M.to's offsetParam by
%               A's trial). M.to.which picks: "first" the nearest, "last"
%               the farthest, "nth" the n-th nearest, "all" every one
%               (several rows per A). value = tB - tA. A B farther than
%               M.maxGapSec from A is dropped; an A left without one counts
%               in nNoB. Invariant (test_TrialMeasure): with "after" and
%               which "first", tB == stopTimes(SRC, M.to, tA, trial), so
%               eventLatency is the same delay.
%     duration  A as above; value = offset - onset of the interval each A
%               is an edge of (eventIntervals: the line, or the aligned
%               step's line of a sequence; "Trial" is the trial).
%     count     A as above; value = how many events of M.to (resolveEvents
%               with which "all", every trial) lie in [tA, tA +
%               M.maxGapSec) and, when A has a trial, no later than its
%               TrialOffset + 1/fs (the first low row, still the trial's
%               own: containingTrial's rule; trials do not overlap, so the
%               next trial's onset never comes first); without a trial, the
%               window ends before the next A. A line with no event of
%               M.to counts 0.
%     param     the numeric trial column M.param on the kept trials;
%               non-finite values are left out (nNoValue).
%
%   Errors: trialMeasure:NoValues (no value is left; resolveEvents:NoEvents
%   for the A events is let through as it is, with its own hint),
%   trialMeasure:NoParam (kind "param" without paired trials, without a
%   parameter or with one the trials lack), trialMeasure:BadParam (the
%   column is not one number per trial), trialMeasure:BadKind;
%   resolveEvents' (NoLine, NoTrials, NoParam, BadParam, NoEvents) are
%   rethrown.
%
%   See also eventLatency, resolveEvents, selectTrials, computeTrialDistPanel.

arguments
    src (1,1) struct
    m (1,1) struct
    mask = []
end

kind = string(fieldOr(m, 'kind', "delay"));
unit = string(fieldOr(m, 'unit', "ms"));
scale = 1;
if unit == "ms"; scale = 1000; end
maxGap = double(fieldOr(m, 'maxGapSec', Inf));
if isempty(maxGap) || ~isfinite(maxGap); maxGap = Inf; end
info = struct('kind', kind, 'label', measureLabel(m), 'unit', unit, 'nA', 0, 'nNoB', 0, 'nNoValue', 0);
switch kind
    case "delay"
        [T, info] = delayValues(src, m, mask, maxGap, scale, info);
    case "duration"
        from = eventRef(m.from);
        [tA, trA, kA, shift, nNo] = resolveEvents(src, from, mask);
        [on, off] = eventIntervals(src, from, tA, shift);
        good = isfinite(on) & isfinite(off);
        T = makeTable(trA(good), (off(good) - on(good)) * scale, tA(good), NaN(nnz(good), 1), kA(good));
        info.nA = numel(tA);
        info.nNoValue = nNo + nnz(~good);
    case "count"
        [T, info] = countValues(src, m, mask, maxGap, info);
        info.unit = "";
    case "param"
        [T, info] = paramValues(src, m, mask, info);
        info.unit = "";
    otherwise
        error('trialMeasure:BadKind', 'The kind of a trial measure is delay, duration, count or param, not "%s".', kind);
end
if height(T) == 0
    error('trialMeasure:NoValues', ['%s: the trial measure "%s" gives no value (%d A event(s), %d with no B ' ...
        'within the gap, %d without a value).'], src.name, info.label, info.nA, info.nNoB, info.nNoValue);
end
end


function [T, info] = delayValues(src, m, mask, maxGap, scale, info)
%delayValues  Kind "delay": B - A per A event (several per A with which "all").
from = eventRef(m.from);
to = eventRef(m.to);
direction = string(fieldOr(m, 'direction', "after"));
[tA, trA, kA, ~, nNo] = resolveEvents(src, from, mask);
cnt = Inf;
if to.which == "first"; cnt = 1; elseif to.which == "nth"; cnt = to.n; end
C = eventsNear(src, to, tA, trA, direction, Count=cnt);
n = numel(tA);
bc = cell(n, 1);
nNoB = 0;
for j = 1:n
    c = C{j};
    switch to.which
        case "first", c = c(1:min(1, end));
        case "last",  c = c(max(1, end):end);
        case "nth",   c = c(to.n:min(to.n, end));
    end
    c = c(abs(c - tA(j)) <= maxGap);
    if isempty(c); nNoB = nNoB + 1; end
    bc{j} = c(:);
end
nB = cellfun(@numel, bc);
idx = repelem((1:n).', nB);
tB = vertcat(bc{:}, zeros(0, 1));
T = makeTable(trA(idx), (tB - tA(idx)) * scale, tA(idx), tB, kA(idx));
info.nA = n;
info.nNoB = nNoB;
info.nNoValue = nNo;
end


function [T, info] = countValues(src, m, mask, maxGap, info)
%countValues  Kind "count": the B events in each A's window [tA, tA + maxGap), cut at A's trial's end.
from = eventRef(m.from);
to = eventRef(m.to);
to.which = "all";
[tA, trA, kA, ~, nNo] = resolveEvents(src, from, mask);
try
    tB = resolveEvents(src, to, []);
catch ME
    if ME.identifier ~= "resolveEvents:NoEvents"; rethrow(ME); end
    tB = zeros(0, 1);   % no B event at all: every count is 0
end
tB = sort(tB(:));
n = numel(tA);
tol = 0;
if isfield(src, 'fs') && isscalar(src.fs) && isfinite(src.fs) && src.fs > 0; tol = 1 / src.fs; end
endIn = Inf(n, 1);      % inclusive: the trial's end
endEx = tA + maxGap;    % exclusive: the gap, or the next A without a trial
has = isfinite(trA) & src.hasTrials;
if any(has)
    endIn(has) = src.trials.TrialOffset(trA(has)) + tol;
end
if any(~has)
    u = unique(tA);
    nx = countBelow(u, tA + eps(tA)) + 1;   % the first A after each
    nextA = Inf(n, 1);
    ok = nx <= numel(u);
    nextA(ok) = u(nx(ok));
    endEx(~has) = min(endEx(~has), nextA(~has));
end
lo = below(tB, tA);                          % B before A
hiEx = below(tB, endEx);                     % B before the exclusive end
f = isfinite(endIn);
endIn(f) = endIn(f) + eps(endIn(f));         % at or before: strictly below the next float
hiIn = below(tB, endIn);                     % B at or before the inclusive end
c = max(min(hiEx, hiIn) - lo, 0);
first = NaN(n, 1);
some = c > 0;
first(some) = tB(lo(some) + 1);
T = makeTable(trA, c, tA, first, kA);
info.nA = n;
info.nNoValue = nNo;
end


function c = below(s, x)
%below  How many of the sorted S lie strictly below each X (Inf: all of them).
c = countBelow(s, x);
c(x == Inf) = numel(s);
c(x == -Inf) = 0;
end


function [T, info] = paramValues(src, m, mask, info)
%paramValues  Kind "param": a numeric trial column on the kept trials.
p = string(fieldOr(m, 'param', ""));
if ~src.hasTrials
    error('trialMeasure:NoParam', '%s has no paired trials, so it has no trial parameter %s to plot.', src.name, p);
end
if p == ""
    error('trialMeasure:NoParam', '%s: the trial measure has no trial parameter chosen.', src.name);
end
Tr = src.trials;
if ~ismember(p, string(Tr.Properties.VariableNames))
    error('trialMeasure:NoParam', '%s: no trial parameter %s (parameters: %s).', src.name, p, strjoin(string(src.paramNames), ", "));
end
v = Tr.(p);
if ~((isnumeric(v) || islogical(v)) && size(v, 2) == 1)
    error('trialMeasure:BadParam', '%s: the trial parameter %s is not one number per trial.', src.name, p);
end
n = height(Tr);
if isempty(mask); mask = true(n, 1); end
rows = find(mask(:));
val = double(v(rows));
good = isfinite(val);
T = makeTable(rows(good), val(good), Tr.TrialOnset(rows(good)), NaN(nnz(good), 1), ones(nnz(good), 1));
info.nA = numel(rows);
info.nNoValue = nnz(~good);
end


function T = makeTable(trial, value, tA, tB, k)
T = table(double(trial(:)), double(value(:)), double(tA(:)), double(tB(:)), double(k(:)), ...
    'VariableNames', {'trial', 'value', 'tA', 'tB', 'k'});
end


function s = measureLabel(m)
%measureLabel  M.label, else trialMeasureLabel's automatic text.
if exist('trialMeasureLabel', 'file') == 2
    s = trialMeasureLabel(m);
    return
end
s = autoLabel(m);   % TODO(p1 merge): trialMeasureLabel ships with the schema package; drop this fallback then
end


function s = autoLabel(m)
%autoLabel  The automatic label (until trialMeasureLabel is on the path): "Stim onset → Platform offset (ms)".
s = string(fieldOr(m, 'label', ""));
if s ~= ""; return; end
kind = string(fieldOr(m, 'kind', "delay"));
unit = " (" + string(fieldOr(m, 'unit', "ms")) + ")";
switch kind
    case "delay"
        a = piece(eventRef(m.from));
        b = piece(eventRef(m.to));
        if string(fieldOr(m, 'direction', "after")) == "before"
            s = b + " before " + a + unit;
        else
            s = a + " " + char(8594) + " " + b + unit;
        end
    case "duration"
        s = eventRef(m.from).line + " duration" + unit;
    case "count"
        s = piece(eventRef(m.to)) + "s after " + piece(eventRef(m.from));
    otherwise
        s = string(fieldOr(m, 'param', ""));
end
end


function s = piece(ref)
%piece  An event in words as eventLatency names it ("last Platform offset", "+ RespLatency (ms)").
s = eventRefLabel(ref);
switch ref.which
    case "last", s = "last " + s;
    case "nth",  s = ordinalOf(ref.n) + " " + s;
end
if ref.offsetParam ~= ""; s = s + " + " + ref.offsetParam + " (" + ref.offsetParamUnit + ")"; end
if ref.offsetSec ~= 0; s = s + sprintf(" %+g s", ref.offsetSec); end
end


function s = ordinalOf(n)
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


function v = fieldOr(s, name, default)
v = default;
if isfield(s, name) && ~isempty(s.(name)); v = s.(name); end
end
