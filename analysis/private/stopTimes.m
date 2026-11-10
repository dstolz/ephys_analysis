function t1 = stopTimes(src, stop, t0, trial)
%stopTimes  The event of STOP following each epoch event (NaN when none).
%   T1 = stopTimes(SRC, STOP, T0, TRIAL) is, for each event T0 of trial
%   TRIAL (NaN: none), the first (STOP.which) event of the eventRef STOP at
%   or after it: in that trial's intervals (its TrialEvents) when the epoch
%   has one and STOP's scope is "trial" or "auto", else over the recording.
%   A STOP with an offsetParam is moved by the epoch's trial's value of it.
%   epochTable's stop events (t1) and eventLatency use it.
%
%   The stop line's events are filtered, sorted and (with a sequence)
%   checked once for the whole recording, then each epoch binary-searches
%   them (countBelow); in trial scope each epoch's trial intervals are small,
%   so pickEvents runs on them, with the sequence's steps prepared once.
n = numel(t0);
t1 = NaN(n, 1);
isTrialLine = stop.line == "Trial" || (src.trialLine ~= "" && stop.line == src.trialLine);
shift = trialParamShift(src, stop, trial);
prep = [];
if isfield(stop, 'sequence') && ~isempty(stop.sequence)
    prep = followSequence(src, stop);
end
fix = lineCleaner(src, stop);   % the stop line stitched and past its refractory period (as given without either)
ok = isfinite(shift);
if stop.scope == "trial"
    useTrial = true(n, 1);
elseif stop.scope == "auto"
    useTrial = src.hasTrials & isfinite(trial(:));
else
    useTrial = false(n, 1);
end

% --- epochs with a trial: that trial's intervals --------------------------------
inTrial = find(ok & useTrial & isfinite(trial(:)) & src.hasTrials).';
if ~isempty(inTrial)
    T = src.trials;
    on = T.TrialOnset;
    off = T.TrialOffset;
    evs = [];
    if ~isTrialLine
        if ~isfield(T.TrialEvents, char(stop.line))
            error('resolveEvents:NoLine', '%s: no digital line "%s" for the stop event.', src.name, stop.line);
        end
        evs = T.TrialEvents;
    end
    for j = inTrial
        r = trial(j);
        if isTrialLine
            iv = [on(r) off(r)];
        else
            iv = fix(double(evs(r).(stop.line)));
        end
        e = pickEvents(iv, stop, on(r), t0(j) - stop.offsetSec - shift(j), src, prep);
        if ~isempty(e); t1(j) = e(1) + shift(j); end
    end
end

% --- the others: over the recording ---------------------------------------------
rec = find(ok & ~useTrial);
if ~isempty(rec)
    line = stop.line;
    if isTrialLine; line = src.trialLine; end
    if ~isfield(src.events, line)
        error('resolveEvents:NoLine', '%s: no digital line "%s" for the stop event.', src.name, line);
    end
    recIv = double(src.events.(line));
    if isempty(recIv); recIv = zeros(0, 2); end
    recIv = fix(recIv);
    % every qualifying event once: its own edge xs (sorted) and the time it
    % aligns to ts (the sequence's step, else the edge itself)
    allRef = stop;
    allRef.which = "all";
    allRef.offsetSec = 0;
    [ts, ~, rows] = pickEvents(recIv, allRef, 0, -Inf, src, prep);
    xs = recIv(rows, 1 + (stop.edge == "offset"));
    m = numel(xs);
    after = t0(rec) - stop.offsetSec - shift(rec);
    i0 = countBelow(xs, after(:)) + 1;                 % the first event at or after each epoch's event
    i0(after(:) == -Inf) = 1;
    switch stop.which
        case "last", pos = repmat(m, size(i0));
        case "nth",  pos = i0 + stop.n - 1;
        otherwise,   pos = i0;                           % "first" (and "all": its first)
    end
    has = isfinite(pos) & pos >= i0 & pos <= m;
    t1(rec(has)) = ts(pos(has)) + stop.offsetSec + shift(rec(has));
end
end
