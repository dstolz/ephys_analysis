function [lines, params, trialLine] = synthSourceLists(obj)
%synthSourceLists  The digital lines and numeric Epsych2 parameters the Synthetic tab offers.
%   From the loaded source (onSynthLoadSource); for the built-in task
%   without one, from a task schedule drawn aside (the global random stream
%   is left as it was); for a dataset source not yet loaded, empty (the
%   design's own lines are still offered, see syncSynthControls).
lines = strings(1, 0); params = strings(1, 0); trialLine = "InTrial";
S = obj.SynthSource;
if isempty(S) && obj.SynthSourceDropDown.Value == "task"
    state = rng;
    restore = onCleanup(@() rng(state));
    S = syntheticTaskSchedule(NumTrials=4);
end
if isempty(S); return; end
lines = reshape(string(S.lineNames), 1, []);
trialLine = string(S.trialLine);
for v = string(S.trials.Properties.VariableNames)
    x = S.trials.(v);
    if ~ismember(v, ["Onset" "Offset"]) && (isnumeric(x) || islogical(x)) && size(x, 2) == 1
        params(end+1) = v; %#ok<AGROW>
    end
end
end
