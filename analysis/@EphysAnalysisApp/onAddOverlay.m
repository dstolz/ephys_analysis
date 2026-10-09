function onAddOverlay(obj, shape)
%onAddOverlay  Add a line ("line") or a patch ("region") to the plot's overlays and edit it.
%   The new overlay gets a name of its own ("Line 1", "Patch 1", ...) and
%   the defaults of EphysAnalysisConfig.defaults("Overlay"): a dashed red
%   line at 0, or a gray patch from 0 to 0.1 at 25 % opacity, over the
%   data of every panel. It is picked in the list, its rows ready to edit.
arguments
    obj (1,1) EphysAnalysisApp
    shape (1,1) string {mustBeMember(shape, ["line" "region"])}
end
if obj.SelectedPlot < 1 || obj.SelectedPlot > numel(obj.Config.Plots); return; end
E = obj.PlotEditor;
items = overlayGather(E);
ov = EphysAnalysisConfig.defaults("Overlay");
ov.shape = shape;
stem = "Line";
if shape == "region"; stem = "Patch"; end
ov.name = overlayFreeName(items, stem + " 1", stem);
items(1, end+1) = ov;
overlayList(E, items, numel(items));
overlayShow(E, ov);
obj.onConfigChanged("plot");
obj.setStatus("Added the overlay " + ov.name + ".");
end
