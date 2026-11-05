function onPanelSelected(obj, k)
%onPanelSelected  Pick panel K of the selected figure (Ctrl+Click on it in the preview, Ctrl+] and Ctrl+[, Ctrl+Alt+arrows): its rows fill the editor.
%   Its first layer is picked. The figure is unchanged, so the preview
%   stays as it is, and so do the figure's own rows (applyFigureEditor
%   Scope "panel": only the panel's and its layer's rows are filled).
f = obj.SelectedFigure;
if f < 1 || f > numel(obj.Config.Figures); return; end
if k < 1 || k > numel(obj.Config.Figures(f).panels); return; end
if k ~= obj.SelectedPanel; obj.SelectedLayer = 1; end
obj.SelectedPanel = k;
obj.applyFigureEditor(Scope="panel");   % the figure's own rows show it already
obj.setStatus("Selected " + obj.Config.Figures(f).panels(k).id + ".");
end
