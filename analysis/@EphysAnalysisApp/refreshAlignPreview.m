function refreshAlignPreview(obj)
%refreshAlignPreview  Epochs the Defaults give on the active dataset: count, groups, trials.
%   Runs epochTable with the config's Defaults (event, window, selection):
%   "N epochs from M of T trials (scope)", a bar per group in its color
%   with its count on top, and the kept trials (with their group) in the
%   table. With "Show the epochs Pairing and Artifacts exclude" ticked
%   (AlignBarsExcluded), each bar counts the epochs of every pairing flag,
%   artifacts or not, the excluded ones stacked on the kept (barsWithExcluded).
%   An alignment that gives no epoch shows why. The epoch diagram beside
%   them (AlignEpochDiagram) draws how the Defaults cut the dataset.
%   While the app starts (AppSplash) on another tab nothing is drawn:
%   onTabChanged draws it when the Alignment tab first shows.
ax = obj.AlignAxes;
L = obj.AlignSummaryLabel;
d = obj.AlignEpochDiagram;
if isempty(obj.Runner) || obj.ActiveIdx < 1
    L.Text = "Scan and pick a dataset to see its epochs.";
    d.clear("Scan and pick a dataset to see how its epochs are cut.");
    return
end
if obj.Splash.isActive() && obj.Tabs.SelectedTab ~= obj.TabAlign
    return   % the app is starting on another tab: drawn when the Alignment tab first shows (onTabChanged)
end
cla(ax);
legend(ax, 'off');
obj.AlignTrialsTable.Data = table();
D = obj.Config.Defaults;
try
    src = obj.Runner.source(obj.ActiveIdx);
catch ME
    L.Text = "No epochs: " + string(ME.message);
    L.FontColor = [0.75 0.1 0.1];
    d.clear("Cannot read " + obj.Runner.Names(obj.ActiveIdx) + ": " + string(ME.message));
    return
end
d.update(src, D.EventRef, D.Window, D.Selection, Title="Defaults on " + src.name);
withExcluded = obj.AlignBarsExcluded.Value;
try
    [E, G] = epochTable(src, D.EventRef, Window=D.Window, Selection=D.Selection);
catch ME
    L.Text = "No epochs: " + string(ME.message);
    L.FontColor = [0.75 0.1 0.1];
    if withExcluded
        try   % what Pairing and the artifacts took, when they took every epoch
            [n, label, color] = barsWithExcluded(src, D, table(), table());
            drawBars(ax, n, label, color);
        catch
        end
    end
    return
end
U = E.Properties.UserData;
nT = numel(unique(E.trial(isfinite(E.trial))));
txt = sprintf("%d epochs", height(E));
if src.hasTrials
    txt = txt + sprintf(" from %d of %d trials", nT, src.nTrials);
end
if height(G) > 1; txt = txt + sprintf(" in %d groups", height(G)); end
txt = txt + " (" + U.scope + " scope)";
if U.nDroppedNoSequence > 0; txt = txt + sprintf("; %d the sequence did not follow", U.nDroppedNoSequence); end
if U.nDroppedNoStop > 0; txt = txt + sprintf("; %d without a stop event", U.nDroppedNoStop); end
if U.nDroppedEdge > 0; txt = txt + sprintf("; %d leave the recording", U.nDroppedEdge); end
if U.nDroppedArtifact > 0; txt = txt + sprintf("; %d touch an artifact period", U.nDroppedArtifact); end
L.Text = txt + ".";
L.FontColor = [0.1 0.1 0.1];
n = G.n; label = G.label; color = G.color;
if withExcluded
    try
        [n, label, color] = barsWithExcluded(src, D, E, G);
    catch ME
        L.Text = L.Text + " (Excluded epochs not counted: " + string(ME.message) + ")";
    end
end
drawBars(ax, n, label, color);
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


function [n, label, color] = barsWithExcluded(src, D, E, G)
%barsWithExcluded  Per group: [kept, excluded by Pairing, excluded by an artifact] epochs.
%   The epochs of every pairing flag with the artifact epochs kept, in
%   their groups; an epoch the Defaults keep (E, by its event) is kept,
%   one they drop that touches an artifact on a trial of a ticked flag is
%   the artifacts', the rest Pairing's. Groups keep their colors (G).
sel = trialSelection(D.Selection);
every = sel;
every.pairingFlags = string.empty(1, 0);
every.maxGroups = Inf;
[Ea, Ga] = epochTable(src, D.EventRef, Window=D.Window, Selection=every, Artifacts="keep");
kept = false(height(Ea), 1);
if height(E) > 0; kept = ismember(Ea.t0, E.t0); end
flagOk = true(height(Ea), 1);
if src.hasTrials && ~isempty(sel.pairingFlags) && ismember("PairingFlag", string(src.trials.Properties.VariableNames))
    has = isfinite(Ea.trial);
    flagOk(has) = ismember(string(src.trials.PairingFlag(Ea.trial(has))), sel.pairingFlags);
end
art = ~kept & flagOk & Ea.artifact & sel.excludeArtifacts;
pair = ~kept & ~art;
nG = height(Ga);
n = [accumarray(Ea.groupIndex, kept, [nG 1]) accumarray(Ea.groupIndex, pair, [nG 1]) accumarray(Ea.groupIndex, art, [nG 1])];
label = Ga.label;
color = Ga.color;
if height(G) > 0
    [in, at] = ismember(label, G.label);
    color(in, :) = G.color(at(in), :);
end
end


function drawBars(ax, n, label, color)
%drawBars  A bar per group in its color, its count on top; columns 2-3 of N stacked on (Pairing, artifacts).
nG = size(n, 1);
x = 1:nG;
if size(n, 2) == 1
    b = bar(ax, x, n, 'FaceColor', 'flat');
    b.CData = color;
else
    b = bar(ax, x, n, 'stacked', 'FaceColor', 'flat');
    b(1).CData = color;
    b(2).CData = repmat([0.74 0.74 0.74], nG, 1);
    b(3).CData = repmat([0.93 0.45 0.40], nG, 1);
    names = ["kept" "Pairing excludes" "artifacts exclude"];
    on = [true any(n(:, 2:3) > 0, 1)];
    legend(ax, b(on), names(on), 'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off', ...
        'AutoUpdate', 'off');
end
tot = sum(n, 2);
ax.YLim = [0 max([tot; 1]) * 1.2];   % room for the counts
fs = 11 - 2 * (nG > 6);
text(ax, x, tot, " " + string(tot) + " ", 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
    'FontSize', fs, 'FontWeight', 'bold', 'Color', [0.1 0.1 0.1], 'Clipping', 'off', 'Tag', 'epochCount');
set(ax, 'XTick', x, 'XTickLabel', label, 'TickLabelInterpreter', 'none', 'XLim', [0.4 nG + 0.6], ...
    'XTickLabelRotation', 30 * (nG > 2));   % the labels clear each other beside the epoch diagram
ylabel(ax, 'Epochs');
title(ax, "Epochs per group");
end
