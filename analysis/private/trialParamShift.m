function s = trialParamShift(src, ref, trial)
%trialParamShift  Each event's shift by its trial's value of REF.offsetParam, s.
%   S = trialParamShift(SRC, REF, TRIAL) is zeros(size(TRIAL)) when
%   REF.offsetParam is "", else the value of that trial parameter on each
%   row TRIAL of src.trials, in s (REF.offsetParamUnit "ms" is divided by
%   1000). An event outside the trials (TRIAL NaN) or whose trial's value
%   is not finite gets NaN. Errors: resolveEvents:NoTrials (no paired
%   trials), resolveEvents:NoParam (no such column), resolveEvents:BadParam
%   (not numeric).
%
%   See also eventRef, resolveEvents, epochTable.
s = zeros(size(trial));
p = ref.offsetParam;
if p == ""; return; end
if ~src.hasTrials
    error('resolveEvents:NoTrials', '%s has no paired trials, so events cannot be shifted by the trial parameter "%s".', src.name, p);
end
T = src.trials;
if ~ismember(p, string(T.Properties.VariableNames))
    error('resolveEvents:NoParam', '%s: no trial parameter "%s" to shift the %s events by.', src.name, p, ref.line);
end
v = T.(p);
if ~((isnumeric(v) || islogical(v)) && size(v, 2) == 1)
    error('resolveEvents:BadParam', '%s: the trial parameter "%s" is not one number per trial, so it cannot shift event times.', src.name, p);
end
scale = 1;
if ref.offsetParamUnit == "ms"; scale = 1 / 1000; end
s = NaN(size(trial));
has = isfinite(trial);
s(has) = double(v(trial(has))) * scale;
s(~isfinite(s)) = NaN;
end
