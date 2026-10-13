function labels = rasterMarkLabels(marks)
%rasterMarkLabels  The labels of a plot's raster event marks, in drawing order.
%   LABELS = rasterMarkLabels(MARKS) names each mark of Plot.rasterEvents
%   MARKS (EventMark structs) by its eventRefLabel, as epochEvents labels it
%   (and R.rasterEvents holds it): "Trough onset", "Trial offset then
%   Trough onset", ... A 1 x n string. The legend and the aesthetics
%   editor's groups go by these labels.
%
%   See also epochEvents, rasterMarkLooks, eventRefLabel.

labels = strings(1, numel(marks));
refs = eventMarkRef(marks);
for k = 1:numel(refs)
    labels(k) = eventRefLabel(refs(k));
end
end
