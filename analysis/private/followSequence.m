function [ok, t] = followSequence(src, ref, x, prep)
%followSequence  Which events an event reference's sequence follows, and the event aligned to.
%   PREP = followSequence(SRC, REF) filters and sorts each step's line once
%   (and the trials' onsets), for a caller that checks many sets of events
%   against one reference (resolveEvents per trial, stopTimes per epoch):
%   pass it back as followSequence(SRC, REF, X, PREP). Without PREP it is
%   made on every call.
%
%   [OK, T] = followSequence(SRC, REF, X, PREP) takes the events X [n x 1] of
%   REF.line / REF.edge (s, the digital-event clock, before REF.offsetSec)
%   of the dataset SRC (loadAnalysisSource) and walks REF.sequence from
%   each:
%     followedBy     the step's REF.sequence(k).n-th event (its line's
%                    intervals of the step's length, by its edge) after the
%                    event before it, within maxGapSec, must exist; it
%                    becomes the event before the next step
%     notFollowedBy  no such event may come after the event before it,
%                    within maxGapSec
%   "After" is at or after, but never the event before itself: a step on
%   the same line and edge as the event before starts after it. With
%   paired trials no step looks past the onset of the first trial that
%   starts after X (an event on that onset still counts).
%   OK [n x 1] is true where the sequence completes; T [n x 1] is the
%   event REF.alignStep names (0: X itself, k: step k, Inf: the last
%   followedBy step), NaN where OK is false. Without a sequence OK is all
%   true and T is X. Errors: resolveEvents:NoLine (a step's line is not in
%   the recording). Every event is checked at once, each step by a binary
%   search of its sorted edges (countBelow).
%
%   See also resolveEvents, eventRef, pickEvents.

if nargin < 3
    ok = stepEdges(src, ref);
    return
end
if nargin < 4 || isempty(prep)
    prep = stepEdges(src, ref);
end
x = x(:);
n = numel(x);
ok = true(n, 1);
t = x;
steps = ref.sequence;
if isempty(steps) || n == 0; return; end

% the next trial's onset after each event: no step looks past it
bound = Inf(n, 1);
if ~isempty(prep.on)
    nb = countAtMost(prep.on, x) + 1;       % the first onset after each event
    has = nb <= numel(prep.on);
    bound(has) = prep.on(nb(has));
end

times = NaN(n, numel(steps));
prev = x;
for s = 1:numel(steps)
    st = steps(s);
    e = prep.edges{s};
    idx = find(ok);
    lo = prev(idx);
    hi = min(lo + st.maxGapSec, bound(idx));
    if prep.strict(s)                       % the same events: start after the one before
        i1 = countAtMost(e, lo) + 1;
    else
        i1 = countBelow(e, lo) + 1;
    end
    c = max(countAtMost(e, hi) - i1 + 1, 0);   % the step's events in [lo, hi] (NaN: none)
    if st.relation == "notFollowedBy"
        ok(idx(c > 0)) = false;
    else
        good = c >= st.n;
        hit = NaN(n, 1);
        hit(idx(good)) = e(i1(good) + st.n - 1);
        ok(idx(~good)) = false;
        times(:, s) = hit;
        prev = hit;
    end
end

a = ref.alignStep;
if isinf(a)
    a = find([steps.relation] == "followedBy", 1, 'last');
    if isempty(a); a = 0; end
end
if a >= 1; t = times(:, a); end
t(~ok) = NaN;
end


function prep = stepEdges(src, ref)
%stepEdges  Each step's qualifying edges, sorted (edges), whether a step starts strictly after the event before it (strict), and the trials' onsets, sorted (on).
steps = ref.sequence;
prep = struct('edges', {cell(1, numel(steps))}, 'strict', false(1, numel(steps)), 'on', zeros(0, 1));
if src.hasTrials && height(src.trials) > 0
    prep.on = sort(src.trials.TrialOnset(isfinite(src.trials.TrialOnset)));
end
prevKey = lineName(src, ref.line) + " " + ref.edge;
for s = 1:numel(steps)
    st = steps(s);
    name = lineName(src, st.line);
    iv = lineIntervals(src, name, st.line);
    dur = iv(:, 2) - iv(:, 1);
    iv = iv(dur >= st.minDurationSec & dur <= st.maxDurationSec, :);
    e = iv(:, 1 + (st.edge == "offset"));
    prep.edges{s} = sort(e(isfinite(e)));
    prep.strict(s) = name + " " + st.edge == prevKey;   % the same events: start after the one before
    if st.relation == "followedBy"
        prevKey = name + " " + st.edge;
    end
end
end


function c = countAtMost(s, v)
%countAtMost  Number of elements of the sorted S at or below each V (countBelow counts those strictly below).
%   Event times are positive, so v + eps(v) is the next float above v and
%   "below it" is "at most v". An infinite V counts every element.
v = v(:);
c = countBelow(s, v + eps(v));
c(v == Inf) = numel(s);
end


function name = lineName(src, line)
%lineName  The recording's name of a line ("Trial" = the pairing's trial line).
name = line;
if line == "Trial" && src.trialLine ~= ""
    name = src.trialLine;
end
end


function iv = lineIntervals(src, name, line)
%lineIntervals  [on off] intervals of a line over the recording.
if isfield(src.events, name)
    iv = double(src.events.(name));
elseif line == "Trial" && src.hasTrials
    iv = [src.trials.TrialOnset src.trials.TrialOffset];
elseif src.hasTrials && height(src.trials) > 0 && isfield(src.trials.TrialEvents, char(name))
    iv = unique(double(vertcat(src.trials.TrialEvents.(name), zeros(0, 2))), 'rows');   % the trials' copies, once each
else
    error('resolveEvents:NoLine', '%s: no digital line "%s" for the event sequence (lines: %s).', ...
        src.name, line, strjoin(string(fieldnames(src.events)), ", "));
end
if isempty(iv); iv = zeros(0, 2); end
end
