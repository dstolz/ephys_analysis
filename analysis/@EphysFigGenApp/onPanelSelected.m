function onPanelSelected(obj, k)
%onPanelSelected  Pick panel K of the selected figure (a click on its patch in the schematic): its rows fill the editor.
%   Its first layer is picked. The figure is unchanged, so the preview
%   stays as it is.
f = obj.SelectedFigure;
if f < 1 || f > numel(obj.Config.Figures); return; end
if k < 1 || k > numel(obj.Config.Figures(f).panels); return; end
if k ~= obj.SelectedPanel; obj.SelectedLayer = 1; end
obj.SelectedPanel = k;
obj.applyFigureEditor();
obj.setStatus("Selected " + obj.Config.Figures(f).panels(k).id + ".");
end
