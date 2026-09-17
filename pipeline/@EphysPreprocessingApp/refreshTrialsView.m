function refreshTrialsView(obj)
%refreshTrialsView  Summary, trials table, cut spinners and lines plot from TrialsPairing.
P = obj.TrialsPairing;
ax = obj.TrialsAxes;
cla(ax);
legend(ax, "off");
removeStyle(obj.TrialsTable);
obj.syncTrialsButtons();
obj.syncTrialsCuts();
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

% --- table ----------------------------------------------------------------------
n = P.nTrials;
T = P.columns;
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
    round(T.TrialOffset, 4), T.TrialOnsetSample, T.TrialOffsetSample, T.PairingFlag, strtrim(other));
cut = find(P.flag == "cut");
part = find(P.flag == "partial");
none = find(P.flag == "unpaired");
if ~isempty(cut)
    addStyle(obj.TrialsTable, uistyle("BackgroundColor", [0.9 0.9 0.9], "FontColor", [0.45 0.45 0.45]), "row", cut);
end
if ~isempty(part)
    addStyle(obj.TrialsTable, uistyle("BackgroundColor", [1 0.92 0.78]), "row", part);
end
if ~isempty(none)
    addStyle(obj.TrialsTable, uistyle("BackgroundColor", [1 0.85 0.85]), "row", none);
end

% --- plot: the digital lines over the recording -------------------------------
E = P.events;
names = [P.trialLine, setdiff(string(fieldnames(E)).', P.trialLine, 'stable')];
nL = numel(names);
iv = P.intervals;
nI = size(iv, 1);
state = repmat("unpaired", nI, 1);
state(P.interval(~isnan(P.interval))) = "ok";
state(P.partialIntervals) = "partial";
isCut = false(nI, 1);
isCut(1:P.cutIntervals(1)) = true;
isCut(nI - P.cutIntervals(2) + 1:nI) = true;
state(isCut) = "cut";
colors = struct('ok', [0 0.45 0.74], 'partial', [0.85 0.5 0], 'cut', [0.55 0.55 0.55], 'unpaired', [0.8 0.1 0.1]);
labels = struct('ok', "paired", 'partial', "partial (recording edge)", 'cut', "cut", 'unpaired', "unpaired");
hold(ax, "on");
for st = ["ok" "partial" "cut" "unpaired"]
    k = find(state == st);
    if ~isempty(k)
        segments(ax, iv(k, :), nL, colors.(st), 8, labels.(st));
    end
end
for j = 2:nL
    segments(ax, E.(names(j)), nL - j + 1, [0.4 0.4 0.4], 5, "");
end
hold(ax, "off");
tEnd = max([P.nSamples / P.Fs, iv(:).', 1]);
xlim(ax, [0 tEnd]);
ylim(ax, [0.4 nL + 0.6]);
yticks(ax, 1:nL);
yticklabels(ax, cellstr(flip(names)));
if nI > 0
    legend(ax, "Location", "eastoutside");
end
title(ax, sprintf("Digital lines over the recording (%s: %d interval(s), %d trial(s))", P.trialLine, nI, n));
end


function segments(ax, iv, y, color, width, name)
%segments  Draw [k x 2] intervals (s) as bars at height Y; | marks the ends.
if isempty(iv); return; end
x = [iv(:, 1), iv(:, 2), NaN(size(iv, 1), 1)].';
yy = y * ones(size(x));
h = plot(ax, x(:), yy(:), "-", "Color", color, "LineWidth", width, "Marker", "|", "MarkerSize", 9);
if name == ""
    h.HandleVisibility = "off";
else
    h.DisplayName = name;
end
end
