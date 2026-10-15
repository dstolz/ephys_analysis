function clearSessionFigurePreview(obj)
%clearSessionFigurePreview  Forget a session figure's kept preview results and hide the "Figure:" drop-down under the preview.
%   Called when another figure is selected or the selected one is edited,
%   so the drop-down never redraws a result that is no longer current
%   (refreshFigurePreview's Redraw).
obj.FigureSessionResults = [];
dd = obj.FigureSessionDropDown;
if isempty(dd) || ~isvalid(dd); return; end
dd.ItemsData = [];
set(dd, "Items", "(all)", "ItemsData", 1, "Value", 1, "Visible", "off");
g = dd.Parent;
if isprop(g, 'ColumnWidth') && numel(g.ColumnWidth) >= 3; g.ColumnWidth{3} = 0; end
end
