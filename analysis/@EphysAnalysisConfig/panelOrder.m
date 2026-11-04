function order = panelOrder(fig)
%panelOrder  A figure's panels in reading order: top first, then left to right.
%   ORDER = EphysAnalysisConfig.panelOrder(FIG) is the indices of figure
%   FIG's panels (a row) sorted by their rects' top edges, highest first,
%   then by their left edges, leftmost first: sortrows(round([-(y + h)
%   x], 3)), so edges within 0.0005 of the page count as level. Panels
%   level on both keep their order in FIG.panels. ORDER(1) is the top-left
%   panel (the one that carries the observation in the title,
%   autoFigureId's first type). A rect that is not 4 numbers sorts last.
%
%   See also EphysAnalysisConfig.autoFigureId, figureNeighbors.

arguments
    fig (1,1) struct
end

n = numel(fig.panels);
K = Inf(n, 2);
for k = 1:n
    r = double(fig.panels(k).rect);
    if numel(r) == 4 && all(isfinite(r)); K(k, :) = [-(r(2) + r(4)), r(1)]; end
end
[~, order] = sortrows(round(K, 3));
order = reshape(order, 1, []);
end
