function onAddFigureOverlay(obj, shape)
%onAddFigureOverlay  Add a line ("line") or a patch ("region") to the selected panel's overlays and edit it.
%   The new overlay gets a name no overlay of the figure's panels has
%   ("Line 1", "Patch 1", ...: one aesthetics rule on a name reaches every
%   panel's overlay of that name) and
%   the defaults of EphysAnalysisConfig.defaults("Overlay"): a dashed red
%   line at 0, or a gray patch from 0 to 0.1 at 25 % opacity, over the
%   panel's data. It is picked in the list, its rows ready to edit.
arguments
    obj (1,1) EphysAnalysisApp
    shape (1,1) string {mustBeMember(shape, ["line" "region"])}
end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
j = obj.SelectedPanel;
if j < 1 || j > numel(obj.Config.Figures(k).panels); return; end
E = obj.FigureEditor;
items = overlayGather(E);
ov = EphysAnalysisConfig.defaults("Overlay");
ov.shape = shape;
stem = "Line";
if shape == "region"; stem = "Patch"; end
ov.name = overlayFreeName([items otherOverlays(obj)], stem + " 1", stem);   % a name no overlay of the figure has
items(1, end+1) = ov;
overlayList(E, items, numel(items));
overlayShow(E, ov);
obj.onConfigChanged("figure");
obj.setStatus("Added the overlay " + ov.name + " to " + obj.Config.Figures(k).panels(j).id + ".");
end


function O = otherOverlays(obj)
%otherOverlays  The overlays of the selected figure's other panels (the selected one's are the editor's list).
O = repmat(EphysAnalysisConfig.defaults("Overlay"), 1, 0);
fig = obj.Config.Figures(obj.SelectedFigure);
for q = setdiff(1:numel(fig.panels), obj.SelectedPanel)
    O = [O fig.panels(q).overlays]; %#ok<AGROW>
end
end
