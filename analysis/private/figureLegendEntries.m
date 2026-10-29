function [lh, ll] = figureLegendEntries(hks, types, G)
%figureLegendEntries  The figure's legend: each group once (from the panel that draws the groups best), then the rest, each label once.
%
%   See also renderFigure, renderProbeFigure.
lh = gobjects(1, 0);
ll = strings(1, 0);
withGroups = false(1, numel(hks));
for k = 1:numel(hks)
    withGroups(k) = ~isempty(hks{k}) && any(hks{k}.legendGroup);
end
src = 0;
if istable(G) && height(G) > 1
    for t = ["psth" "continuous" "raster"]
        src = find(withGroups & types == t, 1);
        if ~isempty(src); break; end
    end
    if isempty(src); src = find(withGroups, 1); end
    if isempty(src); src = 0; end
end
if src > 0
    hk = hks{src};
    for i = find(hk.legendGroup)
        if any(ll == hk.legendLabels(i)); continue; end
        lh(end+1) = hk.legendHandles(i); %#ok<AGROW>
        ll(end+1) = hk.legendLabels(i); %#ok<AGROW>
    end
end
for k = 1:numel(hks)
    hk = hks{k};
    if isempty(hk); continue; end
    for i = find(~hk.legendGroup)
        if any(ll == hk.legendLabels(i)) || ~isgraphics(hk.legendHandles(i)); continue; end
        lh(end+1) = hk.legendHandles(i); %#ok<AGROW>
        ll(end+1) = hk.legendLabels(i); %#ok<AGROW>
    end
end
end
