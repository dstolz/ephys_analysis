function onDuplicateOverlay(obj)
%onDuplicateOverlay  Copy the overlay picked in the plot editor, with its look, right after it.
%   The copy is named "<name> copy" (then "<name> copy 2", ...) and picked.
E = obj.PlotEditor;
items = overlayGather(E);
k = E.ovList.UserData.shown;
if k < 1 || k > numel(items); return; end
ov = items(k);
base = strtrim(ov.name);
if base == ""; base = "Overlay " + k; end
ov.name = overlayFreeName(items, base + " copy", base + " copy");
items = [items(1:k) ov items(k+1:end)];
overlayList(E, items, k + 1);
overlayShow(E, ov);
obj.onConfigChanged("plot");
obj.setStatus("Copied the overlay " + base + " as " + ov.name + ".");
end
