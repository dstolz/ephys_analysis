function clearTrialsView(obj)
%clearTrialsView  Forget the loaded events / session / pairing (dataset changed or rescanned).
obj.TrialsEvents = [];
obj.TrialsEventsIdx = 0;
obj.TrialsSession = [];
obj.TrialsPairing = [];
obj.refreshTrialsView();
d = obj.currentDataset();
if isempty(d)
    obj.TrialsSummaryLabel.Text = "Scan a project, pick a dataset with an Epsych2 session and press Load.";
else
    obj.TrialsSummaryLabel.Text = "Press Load to read the digital lines of " + d.Name + " and pair its trials.";
end
obj.TrialsSummaryLabel.FontColor = [0.3 0.3 0.3];
end
