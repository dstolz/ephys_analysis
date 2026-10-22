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
    w = 230;
else
    if ~isequal(string(dd.Items), "(all)")   % (as it is on most switches: left alone)
        dd.ItemsData = [];
        set(dd, "Items", "(all)", "ItemsData", 1, "Value", 1);
    end
    dd.Visible = "off";
    w = 0;
end
if ~isequal(g.ColumnWidth{3}, w); g.ColumnWidth{3} = w; end
end
