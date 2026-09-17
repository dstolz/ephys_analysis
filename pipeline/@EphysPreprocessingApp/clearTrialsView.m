function clearTrialsView(obj)
%clearTrialsView  Forget the loaded events / pairing (dataset changed or rescanned).
obj.TrialsEvents = [];
obj.TrialsEventsIdx = 0;
obj.TrialsPairing = [];
obj.refreshTrialsView();
obj.TrialsSummaryLabel.Text = "Press Load to read the digital lines and pair the trials.";
obj.TrialsSummaryLabel.FontColor = [0.3 0.3 0.3];
end
