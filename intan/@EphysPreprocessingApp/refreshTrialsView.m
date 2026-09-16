function refreshTrialsView(obj)
%refreshTrialsView  Summary, trials table and residual plot from TrialsPairing.
P = obj.TrialsPairing;
ax = obj.TrialsAxes;
cla(ax);
removeStyle(obj.TrialsTable);
obj.syncTrialsButtons();
if isempty(P)
    obj.TrialsTable.Data = table();
    return
end

% --- summary -----------------------------------------------------------------
d = obj.currentTrialsDataset();
if P.status == "approved"
    state = "APPROVED"; color = [0 0.45 0];
elseif P.recorded
    state = "recorded, NOT REVIEWED"; color = [0.75 0.4 0];
else
    state = "NOT RECORDED - review, then Approve"; color = [0.75 0.4 0];
end
if P.stale
    state = state + " (the recorded pairing no longer matched the session or the lines and was re-aligned)";
    color = [0.7 0.1 0.1];
end
txt = sprintf("%s: %s.  %s.", d.Name, state, P.summary);
if ~isempty(P.unpairedIntervals)
    shown = P.unpairedIntervals(1:min(12, end));
    txt = txt + sprintf("  Unpaired interval(s): %s", strjoin(string(shown(:).'), ", "));
    if numel(P.unpairedIntervals) > numel(shown); txt = txt + ", ..."; end
end
obj.TrialsSummaryLabel.Text = txt;
obj.TrialsSummaryLabel.FontColor = color;

% --- table ----------------------------------------------------------------------
n = P.nTrials;
T = obj.TrialsPairing.columns;
trialIndex = (1:n).';
beh = [];
try
    beh = d.readBehavior();
catch
end
if istable(beh) && ismember("TrialIndex", string(beh.Properties.VariableNames)) && height(beh) == n
    trialIndex = double(beh.TrialIndex);
end
other = strings(n, 1);
for ln = string(fieldnames(P.lines)).'
    c = cellfun(@(x) size(x, 1), P.lines.(ln));
    has = c > 0;
    other(has) = other(has) + ln + ":" + string(c(has)) + " ";
end
obj.TrialsTable.Data = table((1:n).', trialIndex, T.TrialInterval, round(T.TrialOnset, 4), ...
    round(T.TrialOffset, 4), T.TrialOnsetSample, T.TrialOffsetSample, round(T.TimestampResidual, 3), ...
    T.PairingFlag, strtrim(other));
late = find(P.flag == "timestamp off");
none = find(P.flag == "unpaired");
if ~isempty(late)
    addStyle(obj.TrialsTable, uistyle("BackgroundColor", [1 0.95 0.75]), "row", late);
end
if ~isempty(none)
    addStyle(obj.TrialsTable, uistyle("BackgroundColor", [1 0.85 0.85]), "row", none);
end

% --- plot -----------------------------------------------------------------------
tol = obj.Config.Behavior.AlignToleranceS;
hold(ax, "on");
r = P.residual;
ok = P.flag == "ok";
plot(ax, find(ok), r(ok), "o", "Color", [0 0.45 0.74], "MarkerSize", 4, "DisplayName", "ok");
if ~isempty(late)
    plot(ax, late, r(late), "o", "Color", [0.85 0.5 0], "MarkerFaceColor", [0.85 0.5 0], ...
        "MarkerSize", 5, "DisplayName", "timestamp off");
end
if ~isempty(none)
    plot(ax, none, zeros(size(none)), "x", "Color", [0.8 0.1 0.1], "MarkerSize", 8, ...
        "LineWidth", 1.5, "DisplayName", "unpaired");
end
if n > 0
    plot(ax, [0.5 n + 0.5], [tol tol], ":", "Color", [0.5 0.5 0.5], "HandleVisibility", "off");
    plot(ax, [0.5 n + 0.5], -[tol tol], ":", "Color", [0.5 0.5 0.5], "HandleVisibility", "off");
    xlim(ax, [0.5 n + 0.5]);
end
hold(ax, "off");
legend(ax, "Location", "northeast");
title(ax, sprintf("Timestamp residual per trial (%s, clock offset %.2f s)", P.method, P.clockOffsetS));
end
