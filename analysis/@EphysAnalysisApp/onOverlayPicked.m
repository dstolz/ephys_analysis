function onOverlayPicked(obj)
%onOverlayPicked  Show the overlay picked in the plot editor's overlay list in the rows below it.
%   What the rows held for the overlay shown before is kept first
%   (overlayGather). Picking changes nothing in the config, so the preview
%   is not redrawn.
E = obj.PlotEditor;
items = overlayGather(E);
k = E.ovList.Value;
if ~isnumeric(k) || ~isscalar(k) || k < 1 || k > numel(items); return; end
overlayList(E, items, k);
overlayShow(E, items(k));
obj.syncPlotEditor();
end
