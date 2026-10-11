function [lines, params, trialLine] = synthSourceLists(~)
%synthSourceLists  The digital lines and numeric Epsych2 parameters of the built-in task.
%   From a task schedule drawn aside (the global random stream is left as
%   it was); the Synthetic tab offers them in its Event and Parameter lists.
state = rng;
restore = onCleanup(@() rng(state));
S = syntheticTaskSchedule(NumTrials=4);
lines = reshape(string(S.lineNames), 1, []);
trialLine = string(S.trialLine);
params = strings(1, 0);
for v = string(S.trials.Properties.VariableNames)
    x = S.trials.(v);
    if ~ismember(v, ["Onset" "Offset"]) && (isnumeric(x) || islogical(x)) && size(x, 2) == 1
        params(end+1) = v; %#ok<AGROW>
    end
end
end
