function refreshAlignPreview(obj)
%refreshAlignPreview  Epochs the Defaults give on the active dataset: count, groups, trials.
%   Runs epochTable with the config's Defaults (event, window, selection):
%   "N epochs from M of T trials (scope); groups ...", a bar per group in
%   its colour, and the kept trials (with their group) in the table. An
%   alignment that gives no epoch shows why.
ax = obj.AlignAxes;
L = obj.AlignSummaryLabel;
if isempty(obj.Runner) || obj.ActiveIdx < 1
    L.Text = "Scan and pick a dataset to see its epochs.";
    return
end
cla(ax);
obj.AlignTrialsTable.Data = table();
D = obj.Config.Defaults;
try
    src = obj.Runner.source(obj.ActiveIdx);
    [E, G] = epochTable(src, D.EventRef, Window=D.Window, Selection=D.Selection);
catch ME
    L.Text = "No epochs: " + string(ME.message);
    L.FontColor = [0.75 0.1 0.1];
    return
end
U = E.Properties.UserData;
nT = numel(unique(E.trial(isfinite(E.trial))));
txt = sprintf("%d epochs", height(E));
if src.hasTrials
    txt = txt + sprintf(" from %d of %d trials", nT, src.nTrials);
end
txt = txt + " (" + U.scope + " scope)";
if U.nDroppedNoStop > 0; txt = txt + sprintf("; %d without a stop event", U.nDroppedNoStop); end
if U.nDroppedEdge > 0; txt = txt + sprintf("; %d leave the recording", U.nDroppedEdge); end
txt = txt + ". Groups: " + strjoin(G.label + " (" + G.n + ")", "; ");
L.Text = txt;
L.FontColor = [0.1 0.1 0.1];
b = bar(ax, 1:height(G), G.n, 'FaceColor', 'flat');
b.CData = G.color;
set(ax, 'XTick', 1:height(G), 'XTickLabel', G.label, 'TickLabelInterpreter', 'none');
ylabel(ax, 'Epochs');
title(ax, "Epochs per group: " + src.name, 'Interpreter', 'none');
if src.hasTrials
    [mask, ~, gi] = selectTrials(src, D.Selection);
    T = src.trials;
    vars = string(T.Properties.VariableNames);
    keep = intersect(["TrialIndex" "PairingFlag" D.Selection.groupBy src.respField "TrialOnset" "TrialOffset"], vars, 'stable');
    keep = keep(keep ~= "");
    Tt = T(mask, cellstr(keep));
    Tt.Group = G.label(gi(mask));
    Tt.Epochs = arrayfun(@(r) nnz(E.trial == r), find(mask));
    obj.AlignTrialsTable.Data = Tt;
end
end
