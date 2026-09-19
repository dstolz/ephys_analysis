function refreshPlotList(obj)
%refreshPlotList  The plot list: "<id>  (<kind>)", disabled plots marked "(off)".
P = obj.Config.Plots;
n = numel(P);
if n == 0
    obj.PlotsListBox.Items = {};
    obj.PlotsListBox.ItemsData = [];
    return
end
items = strings(1, n);
for k = 1:n
    items(k) = P(k).id + "  (" + P(k).kind + ")";
    if ~P(k).enabled; items(k) = items(k) + "  (off)"; end
end
obj.PlotsListBox.Items = cellstr(items);
obj.PlotsListBox.ItemsData = 1:n;
if obj.SelectedPlot >= 1 && obj.SelectedPlot <= n
    obj.PlotsListBox.Value = obj.SelectedPlot;
end
end
