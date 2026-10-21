function onRemoveFigureOverlay(obj)
%onRemoveFigureOverlay  Remove the overlay picked in the figure editor from the selected panel; the next one is picked.
E = obj.FigureEditor;
items = overlayGather(E);
k = E.ovList.UserData.shown;
if k < 1 || k > numel(items); return; end
name = strtrim(items(k).name);
if name == ""; name = "Overlay " + k; end
items(k) = [];
k = min(k, numel(items));
overlayList(E, items, k);
if k >= 1; overlayShow(E, items(k)); end
obj.onConfigChanged("figure", "Remove overlay");
obj.setStatus("Removed the overlay " + name + ".");
end
