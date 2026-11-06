function onRemovePanel(obj)
%onRemovePanel  Remove the selected panel, or all the panels selected (Shift+click); the other panels keep their places (removePanel).
%   The space a panel held is left free (New panel's Largest empty space
%   finds it). The panel drawn after the shown one is selected, else the
%   one before, alone. One undo step, "Remove panel", or "Remove panels"
%   with several selected (selectedPanelIds: the Layout section's button
%   then reads "Remove 3 panels"; Arrange's box menu removes them too).
%   The panels go from the preview at once (paintEditFirst), before the
%   editor is read back; commitFigureEdit then settles the preview.
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
j = obj.SelectedPanel;
if j < 1 || j > numel(obj.Config.Figures(k).panels); return; end
sel = selectedPanelIds(obj);
shown = obj.Config.Figures(k);   % the edit made on the config as it is, cheaply: shown on the preview before the editor is read back
for id = sel(ismember(sel, [shown.panels.id]))
    shown = EphysAnalysisConfig.removePanel(shown, id);
end
paintEditFirst(obj, shown);
cfg = obj.gatherConfig();
fig = cfg.Figures(k);
for id = sel
    fig = EphysAnalysisConfig.removePanel(fig, id);
end
cfg.Figures(k) = fig;
obj.FigurePanelExtra = strings(1, 0);
obj.SelectedPanel = min(j, numel(fig.panels));
obj.SelectedLayer = 1;
action = "Remove panel";
if numel(sel) > 1; action = "Remove panels"; end
commitFigureEdit(obj, cfg, "Removed " + strjoin(sel, ", ") + ".", Action=action);
end
