function refreshFigureList(obj)
%refreshFigureList  The Figures tab's list: "<id>  (<n> panels, per <observation kind>)", "  (off)" when disabled.
%   The observation kind is the figure's, resolved (observeKind: "auto"
%   says what it draws). The selected figure (SelectedFigure) is the
%   list's value.
F = obj.Config.Figures;
lb = obj.FigureList;
n = numel(F);
if n == 0
    set(lb, "Items", {}, "ItemsData", []);
    return
end
text = strings(1, n);
for k = 1:n
    m = numel(F(k).panels);
    text(k) = sprintf("%s  (%d panel%s, per %s)", F(k).id, m, repmat('s', 1, m ~= 1), EphysAnalysisConfig.observeKind(F(k)));
    if ~F(k).enabled; text(k) = text(k) + "  (off)"; end
end
k = min(max(obj.SelectedFigure, 1), n);
set(lb, "Items", cellstr(text), "ItemsData", 1:n, "Value", k);
end
