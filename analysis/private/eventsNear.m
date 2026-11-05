function C = eventsNear(src, ref, tA, trialA, direction, opts)
%eventsNear  The events of a reference after (or before) each of a set of events, nearest first.
%   C = eventsNear(SRC, REF, TA, TRIALA, DIRECTION) is, for each event TA
%   [n x 1] (s; TRIALA [n x 1] its row of src.trials, NaN: none) of the
%   dataset SRC (loadAnalysisSource), a column of the times of the events
%   of the eventRef REF (normalized: eventRef) that could follow it
%   (DIRECTION "after") or precede it ("before"), found as stopTimes finds
%   a stop event:
%     - in the event's own trial (that trial's TrialEvents, the intervals
%       overlapping it, through pickEvents with REF.which "all": durations,
%       timeRange from the trial onset, the sequence) when it has one and
%       REF's scope is "trial" or "auto"; scope "trial" without a trial
%       gives none
%     - else over the recording (src.events, the same filters, every
%       event once and a binary search per event)
%   "after" keeps the events whose edge, moved by REF.offsetSec and the
%   shift of REF.offsetParam (the value of TRIALA's trial), is at or after
%   TA, ascending; "before" those at or before TA, descending: C{j}(1) is
%   the nearest. REF.which is NOT applied: the caller picks (first = C{j}(1),
%   nth = C{j}(n), last = C{j}(end), all = C{j}). An event whose trial has
%   no value of REF.offsetParam gets none. The sequence's steps are
%   prepared once (followSequence).
%
%   So for "after": stopTimes(SRC, REF, TA, TRIALA) equals C{j}(1) (first),
%   C{j}(REF.n) (nth) or C{j}(end) (last), NaN where that is missing
%   (test_TrialMeasure checks it). stopTimes keeps its own binary search
%   (one result per event, no lists) because epochTable calls it for
%   every epoch of a long recording.
%
%   Option Count (Inf): keep at most this many events per entry, the
%   nearest; trialMeasure passes 1 for which "first" and n for "nth", so a
%   recording-scope reference does not list the whole recording per event.
%   Errors: resolveEvents:NoLine, and trialParamShift's.
%
%   See also stopTimes, trialMeasure, pickEvents, followSequence.

arguments
    src (1,1) struct
    ref (1,1) struct
    tA double
    trialA double
    direction (1,1) string {mustBeMember(direction, ["after" "before"])} = "after"
    opts.Count (1,1) double {mustBePositive} = Inf
end

tA = tA(:);
trialA = trialA(:);
n = numel(tA);
C = repmat({zeros(0, 1)}, n, 1);
if n == 0; return; end
isTrialLine = ref.line == "Trial" || (src.trialLine ~= "" && ref.line == src.trialLine);
shift = trialParamShift(src, ref, trialA);
prep = [];
if isfield(ref, 'sequence') && ~isempty(ref.sequence)
    prep = followSequence(src, ref);
end
ok = isfinite(shift) & isfinite(tA);
if ref.scope == "trial"
    useTrial = true(n, 1);
elseif ref.scope == "auto"
    useTrial = src.hasTrials & isfinite(trialA);
else
    useTrial = false(n, 1);
end
col = 1 + (ref.edge == "offset");
allRef = ref;
allRef.which = "all";
after = direction == "after";
cnt = opts.Count;

% --- events with a trial: that trial's intervals --------------------------------
inTrial = find(ok & useTrial & isfinite(trialA) & src.hasTrials).';
if ~isempty(inTrial)
    T = src.trials;
    on = T.TrialOnset;
    off = T.TrialOffset;
    evs = [];
    if ~isTrialLine
        if ~isfield(T.TrialEvents, char(ref.line))
            error('resolveEvents:NoLine', '%s: no digital line "%s" for the event.', src.name, ref.line);
        end
        evs = T.TrialEvents;
    end
    for j = inTrial
        r = trialA(j);
        if isTrialLine
            iv = [on(r) off(r)];
        else
            iv = double(evs(r).(ref.line));
        end
        if isempty(iv); continue; end
        [e, ~, rows] = pickEvents(iv, allRef, on(r), -Inf, src, prep);   % ascending by edge, offsetSec added
        x = iv(rows, col);
        lim = tA(j) - ref.offsetSec - shift(j);   % stopTimes' test: edge >= t0 - offsetSec - shift
        if after
            c = e(x >= lim);
        else
            c = flipud(e(x <= lim));
        end
        C{j} = c(1:min(numel(c), cnt)) + shift(j);
    end
end

% --- the others: over the recording ---------------------------------------------
rec = find(ok & ~useTrial).';
if ~isempty(rec)
    line = ref.line;
    if isTrialLine; line = src.trialLine; end
    if ~isfield(src.events, line)
        error('resolveEvents:NoLine', '%s: no digital line "%s" for the event.', src.name, line);
    end
    recIv = double(src.events.(line));
    if isempty(recIv); recIv = zeros(0, 2); end
    % every qualifying event once: its own edge xs (sorted) and the time it aligns to ts
    allRef.offsetSec = 0;
    [ts, ~, rows] = pickEvents(recIv, allRef, 0, -Inf, src, prep);
    xs = recIv(rows, col);
    m = numel(xs);
    lim = tA(rec) - ref.offsetSec - shift(rec);
    for i = 1:numel(rec)
        j = rec(i);
        if after
            i0 = countBelow(xs, lim(i)) + 1;           % the first edge at or after the event
            idx = i0:min(m, i0 + cnt - 1);
        else
            i1 = countBelow(xs, lim(i) + eps(lim(i)));   % the last edge at or before it
            idx = i1:-1:max(1, i1 - cnt + 1);
        end
        C{j} = reshape(ts(idx), [], 1) + ref.offsetSec + shift(j);
    end
end
end
