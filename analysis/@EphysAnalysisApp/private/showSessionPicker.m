function showSessionPicker(obj, labels, j)
%showSessionPicker  The "Figure:" drop-down under the preview: shown with LABELS (J picked) when a session figure makes several.
%   One label or none hides it. refreshFigurePreview fills it after a
%   session figure is computed; syncFigureView shows it again as the
%   figure it shows left it.
dd = obj.FigureSessionDropDown;
if isempty(dd) || ~isvalid(dd); return; end
g = dd.Parent;
if numel(labels) > 1
    dd.ItemsData = [];
    set(dd, "Items", "Figure: " + labels, "ItemsData", 1:numel(labels), "Value", j, "Visible", "on");
    g.ColumnWidth{3} = 230;
else
    dd.ItemsData = [];
    set(dd, "Items", "(all)", "ItemsData", 1, "Value", 1, "Visible", "off");
    g.ColumnWidth{3} = 0;
end
end
