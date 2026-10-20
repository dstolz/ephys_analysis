function ref = eventMarkRef(marks)
%eventMarkRef  The event references of raster event marks, without their look.
%   REF = eventMarkRef(MARKS) is the 1 x n EventRef struct array of the
%   EventMark structs MARKS (Plot.rasterEvents): each mark's fields but its
%   look (marker, size, color and the span's spanStyle, spanWidth,
%   spanAlpha), so eventRef, eventRefLabel and epochEvents take them.
%
%   See also epochEvents, rasterMarkLabels, rasterMarkLooks.

ref = repmat(EphysAnalysisConfig.defaults("EventRef"), 1, numel(marks));
look = ["marker" "size" "color" "spanStyle" "spanWidth" "spanAlpha"];
for k = 1:numel(marks)
    m = marks(k);
    m = rmfield(m, intersect(look, string(fieldnames(m))));
    ref(k) = EphysAnalysisConfig.normalizeSection("EventRef", m);
end
end
