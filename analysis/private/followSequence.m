function [ok, t] = followSequence(src, ref, x)
%followSequence  Which events an event reference's sequence follows, and the event aligned to.
%   [OK, T] = followSequence(SRC, REF, X) takes the events X [n x 1] of
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
%   the recording).
%
%   See also resolveEvents, eventRef, pickEvents.

x = x(:);
n = numel(x);
ok = true(n, 1);
t = x;
steps = ref.sequence;
if isempty(steps) || n == 0; return; end

% the next trial's onset after each event: no step looks past it
bound = Inf(n, 1);
if src.hasTrials && height(src.trials) > 0
    on = sort(src.trials.TrialOnset(isfinite(src.trials.TrialOnset)));
    for j = 1:n
        k = find(on > x(j), 1);
        if ~isempty(k); bound(j) = on(k); end
    end
end

times = NaN(n, numel(steps));
prev = x;
prevKey = lineName(src, ref.line) + " " + ref.edge;
for s = 1:numel(steps)
    st = steps(s);
    name = lineName(src, st.line);
    iv = lineIntervals(src, name, st.line);
    dur = iv(:, 2) - iv(:, 1);
    iv = iv(dur >= st.minDurationSec & dur <= st.maxDurationSec, :);
    e = iv(:, 1 + (st.edge == "offset"));
    e = sort(e(isfinite(e)));
    strict = name + " " + st.edge == prevKey;   % the same events: start after the one before
    hit = NaN(n, 1);
    for j = find(ok).'
        lo = prev(j);
        hi = min(prev(j) + st.maxGapSec, bound(j));
        if strict
            i1 = find(e > lo, 1);
        else
            i1 = find(e >= lo, 1);
        end
        if isempty(i1) || e(i1) > hi
            c = 0;
        else
            c = find(e <= hi, 1, 'last') - i1 + 1;
        end
        if st.relation == "notFollowedBy"
            if c > 0; ok(j) = false; end
        elseif c >= st.n
            hit(j) = e(i1 + st.n - 1);
        else
            ok(j) = false;
        end
    end
    if st.relation == "followedBy"
        times(:, s) = hit;
        prev = hit;
        prevKey = name + " " + st.edge;
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
