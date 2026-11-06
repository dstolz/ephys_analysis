function d = onEditAesthetics(obj)
%onEditAesthetics  Open the aesthetics editor on the figure preview, the selected panel's axes picked.
%   D = onEditAesthetics(obj) is the Edit aesthetics... button above the
%   preview, right of Favorites: the same PlotAestheticsDialog a right-click
%   on a part of the preview opens (PlotAesthetics.edit), without the
%   right-click. It opens on the selected panel's axes (selectedPanelAxes);
%   on the plot's first part when the preview shows no panel of the
%   selected figure as such (a probe figure, an older drawing). Every part
%   of the plot is in its list, so any of them can be picked there. D is
%   the dialog ([] when none opened). With nothing drawn it says to preview
%   first.
arguments
    obj (1,1) EphysFigGenApp
end
d = [];
P = obj.FigurePreviewPanel;
if isempty(P) || ~isvalid(P) || ~isappdata(P, PlotAesthetics.ContextKey)
    uialert(obj.Fig, "Preview a figure first: the editor changes the colors, lines, fonts and labels of the preview.", ...
        "Edit aesthetics");
    return
end
h = P;   % (the editor's first row when no panel is picked)
A = selectedPanelAxes(obj, P);
if ~isempty(A); h = A{1}(1); end
try
    d = PlotAesthetics.edit(h);
catch ME
    uialert(obj.Fig, ME.message, "Edit aesthetics");
end
end
