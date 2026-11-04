function onRemovePanel(obj)
%onRemovePanel  Remove the selected panel; the other panels keep their places (removePanel).
%   The space it held is left free (New panel's Largest empty space finds
%   it). The panel drawn after it is selected, else the one before. One
%   undo step, "Remove panel".
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
j = obj.SelectedPanel;
if j < 1 || j > numel(obj.Config.Figures(k).panels); return; end
cfg = obj.gatherConfig();
fig = cfg.Figures(k);
id = fig.panels(j).id;
fig = EphysAnalysisConfig.removePanel(fig, id);
cfg.Figures(k) = fig;
obj.SelectedPanel = min(j, numel(fig.panels));
obj.SelectedLayer = 1;
commitFigureEdit(obj, cfg, "Removed " + id + ".", Action="Remove panel");
end
