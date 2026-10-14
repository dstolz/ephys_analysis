function onRemovePanel(obj)
%onRemovePanel  Remove the selected panel; the rows and columns no panel starts in any more go too (removePanel).
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
commitFigureEdit(obj, cfg, "Removed " + id + "; empty rows and columns dropped.");
end
