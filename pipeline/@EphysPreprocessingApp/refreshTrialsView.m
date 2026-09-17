function refreshTrialsView(obj)
%refreshTrialsView  Summary, trials table, cut spinners and lines plot from TrialsPairing.
P = obj.TrialsPairing;
obj.refreshTrialsTable();
obj.refreshTrialsPlot();
obj.syncTrialsButtons();
obj.syncTrialsCuts();
if isempty(P)
    return
end

% --- summary -----------------------------------------------------------------
d = obj.currentDataset();
if P.status == "approved"
    state = "APPROVED"; color = [0 0.45 0];
elseif P.recorded
    state = "recorded, NOT REVIEWED"; color = [0.75 0.4 0];
else
    state = "NOT RECORDED - review, then Approve"; color = [0.75 0.4 0];
end
if P.stale
    state = state + " (the recorded pairing no longer matched the session or the lines; its cuts were dropped)";
    color = [0.7 0.1 0.1];
end
txt = sprintf("%s: %s.  %s.", d.Name, state, P.summary);
if P.countMismatch
    txt = txt + newline + "WARNING: " + strjoin(P.warnings, " ");
    color = [0.7 0.1 0.1];
end
obj.TrialsSummaryLabel.Text = txt;
obj.TrialsSummaryLabel.FontColor = color;
end
