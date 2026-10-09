function t1 = stopTimes(src, stop, t0, trial)
%stopTimes  The event of STOP following each epoch event (NaN when none).
%   T1 = stopTimes(SRC, STOP, T0, TRIAL) is, for each event T0 of trial
%   TRIAL (NaN: none), the first (STOP.which) event of the eventRef STOP at
%   or after it: in that trial's intervals (its TrialEvents) when the epoch
%   has one and STOP's scope is "trial" or "auto", else over the recording.
%   A STOP with an offsetParam is moved by the epoch's trial's value of it.
%   epochTable's stop events (t1) and eventLatency use it.
n = numel(t0);
t1 = NaN(n, 1);
isTrialLine = stop.line == "Trial" || (src.trialLine ~= "" && stop.line == src.trialLine);
recIv = [];
shift = trialParamShift(src, stop, trial);
for j = 1:n
    if ~isfinite(shift(j)); continue; end
    useTrial = stop.scope == "trial" || (stop.scope == "auto" && src.hasTrials && isfinite(trial(j)));
    if useTrial
        if ~src.hasTrials || ~isfinite(trial(j)); continue; end
        r = trial(j);
        T = src.trials;
        if isTrialLine
            iv = [T.TrialOnset(r) T.TrialOffset(r)];
        elseif isfield(T.TrialEvents, char(stop.line))
            iv = double(T.TrialEvents(r).(stop.line));
        else
            error('resolveEvents:NoLine', '%s: no digital line "%s" for the stop event.', src.name, stop.line);
        end
        origin = T.TrialOnset(r);
    else
        if isempty(recIv)
            line = stop.line;
            if isTrialLine; line = src.trialLine; end
            if ~isfield(src.events, line)
                error('resolveEvents:NoLine', '%s: no digital line "%s" for the stop event.', src.name, line);
            end
            recIv = double(src.events.(line));
            if isempty(recIv); recIv = zeros(0, 2); end
        end
        iv = recIv;
        origin = 0;
    end
    e = pickEvents(iv, stop, origin, t0(j) - stop.offsetSec - shift(j), src);
    if ~isempty(e); t1(j) = e(1) + shift(j); end
end
end
