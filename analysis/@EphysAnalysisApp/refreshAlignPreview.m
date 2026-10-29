function refreshAlignPreview(obj)
%refreshAlignPreview  Epochs the Defaults give on the active dataset: count, groups, trials.
%   Runs epochTable with the config's Defaults (event, window, selection):
%   "N epochs from M of T trials (scope)", a bar per group in its color
%   with its count on top, and the kept trials (with their group) in the
%   table. With "Show the epochs Pairing and Artifacts exclude" ticked
%   (AlignBarsExcluded), each bar counts the epochs of every pairing flag,
%   artifacts or not, the excluded ones stacked on the kept. The count, the
%   bars and the excluded epochs are EpochGroupCounts' (summary, drawBars,
%   withExcluded), as in DatasetBrowser's Epochs per group window.
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
            [n, label, color] = EpochGroupCounts.withExcluded(src, D.EventRef, D.Window, D.Selection, table(), table());
            EpochGroupCounts.drawBars(ax, n, label, color);
        catch
        end
    end
    return
end
L.Text = EpochGroupCounts.summary(src, E, G);
L.FontColor = [0.1 0.1 0.1];
n = G.n; label = G.label; color = G.color;
if withExcluded
    try
        [n, label, color] = EpochGroupCounts.withExcluded(src, D.EventRef, D.Window, D.Selection, E, G);
    catch ME
        L.Text = L.Text + " (Excluded epochs not counted: " + string(ME.message) + ")";
    end
end
EpochGroupCounts.drawBars(ax, n, label, color);
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

