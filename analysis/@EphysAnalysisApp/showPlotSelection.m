function showPlotSelection(obj)
%showPlotSelection  Say in the editor and over the preview how many plots are selected.
%   One plot (or none): the editor's panel is "Plot", the note under the
%   kind describes the kind (applyPlotEditor), the bar over the preview is
%   hidden. Several: the panel says how many, the kind row names their
%   kinds, and the note becomes an amber banner naming them, saying that
%   an edit goes to every one and that the options shown are those they
%   all have, with the first one's values; the bar over the preview, in
%   the same colours, says it draws the first one only.
ks = obj.selectedPlots();
n = numel(ks);
E = obj.PlotEditor;
B = obj.SelectionBar;
if isempty(fieldnames(E)) || isempty(fieldnames(B)); return; end
S = obj.PlotSections;
g = find([S.Name] == "general", 1);
r = find(cellfun(@(k) any(k == "note"), S(g).Keys), 1);
if n <= 1
    obj.PlotEditorPanel.Title = "Plot";
    set(E.note, "BackgroundColor", "none", "FontColor", [0.35 0.35 0.35], "FontWeight", "normal");
    S(g).Heights(r) = 30;
    set(obj.PreviewGrid, "RowHeight", {0, '1x'}, "RowSpacing", 0);
    B.Grid.Visible = "off";
    obj.PlotSections = S;
    return
end
amber = {[1.00 0.93 0.75], [0.55 0.33 0.00]};
P = obj.Config.Plots(ks);
ids = [P.id];
first = ids(1);
K = EphysAnalysisConfig.plotKinds();
kinds = unique([P.kind], 'stable');
labels = kinds;
for i = 1:numel(kinds)
    if any(K.Kind == kinds(i)); labels(i) = K.Label(K.Kind == kinds(i)); end
end
if isscalar(kinds)
    E.kind.Text = sprintf("%s  (%d plots)", labels, n);
else
    E.kind.Text = sprintf("%d plots: %s", n, strjoin(labels, ", "));
end
named = strjoin(ids(1:min(n, 4)), ", ");
if n > 4; named = named + sprintf(" and %d more", n - 4); end
E.note.Text = sprintf("%d plots selected: %s. A change here goes to all %d. Shown: only the options they all have, " + ...
    "with the values of %s (previewed).", n, named, n, first);
set(E.note, "BackgroundColor", amber{1}, "FontColor", amber{2}, "FontWeight", "bold");
S(g).Heights(r) = 50;
obj.PlotSections = S;
obj.PlotEditorPanel.Title = sprintf("Plots: %d selected, edited together", n);
B.Text.Text = sprintf("Previewing %s only, the first of the %d plots selected. Edits go to all %d.", first, n, n);
B.Text.FontColor = amber{2};
B.Grid.BackgroundColor = amber{1};
B.Text.Tooltip = "Selected: " + strjoin(ids, ", ") + ". The editor's changes go to every one of them; " + ...
    "the preview draws " + first + ", the first selected. Click a plot alone to edit it alone.";
set(obj.PreviewGrid, "RowHeight", {26, '1x'}, "RowSpacing", 4);
B.Grid.Visible = "on";
end
