function repairTrials(obj, cuts)
%repairTrials  Pair the Trials-tab dataset from the in-memory events and show it.
%   CUTS is "recorded", "none" or a struct (trials, intervals), see
%   EphysDataset.pairTrials. Cuts that cannot be applied leave the shown
%   pairing as it is (and put the spinners back).
d = obj.currentDataset();
if isempty(d) || isempty(obj.TrialsEvents); return; end
try
    P = d.pairTrials(Events=obj.TrialsEvents, Cuts=cuts, Warn=false);
catch ME
    if isstruct(cuts) && ~isempty(obj.TrialsPairing)
        obj.refreshTrialsView();
        obj.setStatus("Trials: " + string(ME.message));
    else
        obj.TrialsPairing = [];
        obj.refreshTrialsView();
        obj.TrialsSummaryLabel.Text = "Could not pair: " + string(ME.message);
        obj.TrialsSummaryLabel.FontColor = [0.7 0.1 0.1];
    end
    return
end
obj.TrialsPairing = P;
obj.refreshTrialsView();
if isstruct(cuts)
    obj.setStatus(sprintf("Trials: cut %d + %d trial(s) and %d + %d interval(s) (start + end); not saved - Approve to keep it.", ...
        cuts.trials(1), cuts.trials(2), cuts.intervals(1), cuts.intervals(2)));
elseif P.countMismatch
    obj.setStatus("Trials: " + d.Name + " - the numbers of trials and intervals differ. Cut from the start or the end to resolve it, then Approve.");
end
end
