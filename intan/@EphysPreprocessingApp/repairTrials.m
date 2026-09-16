function repairTrials(obj, assignment)
%repairTrials  Pair the Trials-tab dataset from the in-memory events and show it.
%   ASSIGNMENT is "recorded", "auto" or an interval index per trial.
d = obj.currentTrialsDataset();
if isempty(d) || isempty(obj.TrialsEvents); return; end
try
    obj.TrialsPairing = d.pairTrials(Events=obj.TrialsEvents, Assignment=assignment);
catch ME
    obj.TrialsPairing = [];
    obj.refreshTrialsView();
    obj.TrialsSummaryLabel.Text = "Could not pair: " + string(ME.message);
    obj.TrialsSummaryLabel.FontColor = [0.7 0.1 0.1];
    return
end
obj.refreshTrialsView();
end
