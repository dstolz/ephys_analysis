function L = rasterMarkLooks(marks, labels)
%rasterMarkLooks  How each raster event mark is drawn.
%   L = rasterMarkLooks(MARKS, LABELS) gives, for the M-th mark LABELS(M)
%   (R.rasterEvents' labels, in their order), a struct with marker, size
%   and color ([r g b]): those of the EventMark in MARKS (Plot.rasterEvents)
%   with that label (rasterMarkLabels), the first if several share it. A
%   color "" is the mark's automatic color (rasterMarkColor's M-th). A
%   label no mark has gets EventMark's default marker and size and its
%   automatic color.
%
%   See also rasterMarkLabels, epochEvents, renderRaster.

def = EphysAnalysisConfig.defaults("EventMark");
labels = string(labels);
have = string.empty(1, 0);
if isstruct(marks) && ~isempty(marks)
    have = rasterMarkLabels(marks);
else
    marks = repmat(def, 1, 0);
end
L = repmat(struct('marker', "", 'size', 0, 'color', [0 0 0]), 1, numel(labels));
for m = 1:numel(labels)
    k = find(have == labels(m), 1);
    mk = def;
    if ~isempty(k); mk = EphysAnalysisConfig.coerceStruct(def, marks(k), "rasterEvents"); end
    L(m) = struct('marker', mk.marker, 'size', mk.size, 'color', rasterMarkColor(mk.color, m));
end
end
