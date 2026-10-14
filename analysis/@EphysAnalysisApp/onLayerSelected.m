function onLayerSelected(obj, j)
%onLayerSelected  Pick layer J of the selected panel (the Layers list): its rows fill the section.
%   The figure is unchanged, so the preview stays as it is.
if isempty(j) || ~isnumeric(j); return; end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
p = obj.SelectedPanel;
if p < 1 || p > numel(obj.Config.Figures(k).panels); return; end
if j(1) < 1 || j(1) > numel(obj.Config.Figures(k).panels(p).layers); return; end
obj.SelectedLayer = j(1);
obj.applyFigureEditor();
end
