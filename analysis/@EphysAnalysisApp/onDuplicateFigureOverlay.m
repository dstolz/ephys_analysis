function onDuplicateFigureOverlay(obj)
%onDuplicateFigureOverlay  Copy the overlay picked in the figure editor, with its look, right after it.
%   The copy is named "<name> copy" (then "<name> copy 2", ...: a name no
%   overlay of the figure's panels has) and picked.
%   The Figures tab's copy of onDuplicateOverlay (the Plots tab's).
E = obj.FigureEditor;
items = overlayGather(E);
k = E.ovList.UserData.shown;
if k < 1 || k > numel(items); return; end
ov = items(k);
base = strtrim(ov.name);
if base == ""; base = "Overlay " + k; end
ov.name = overlayFreeName([items otherOverlays(obj)], base + " copy", base + " copy");   % no overlay of the figure has it
items = [items(1:k) ov items(k+1:end)];
overlayList(E, items, k + 1);
overlayShow(E, ov);
obj.onConfigChanged("figure");
obj.setStatus("Copied the overlay " + base + " as " + ov.name + ".");
end


function O = otherOverlays(obj)
%otherOverlays  The overlays of the selected figure's other panels (the selected one's are the editor's list).
O = repmat(EphysAnalysisConfig.defaults("Overlay"), 1, 0);
f = obj.SelectedFigure;
if f < 1 || f > numel(obj.Config.Figures); return; end
fig = obj.Config.Figures(f);
for q = setdiff(1:numel(fig.panels), obj.SelectedPanel)
    O = [O fig.panels(q).overlays]; %#ok<AGROW>
end
end
