function pairs = rectOverlaps(fig)
%rectOverlaps  The pairs of a figure's panels whose rects overlap.
%   PAIRS = EphysAnalysisConfig.rectOverlaps(FIG) lists the panels of
%   figure FIG (a Figures entry) whose rects overlap, as an n x 2 array of
%   panel indices [j k] with j < k, sorted by j then k (zeros(0, 2) when
%   none do). Two rects overlap when they share more than RectTol (0-1 of
%   the page) both across and up: panels put flush, or a hair apart or
%   into each other, do not. Where two panels overlap, the later one (k)
%   is drawn on top (validate warns; orderPanel changes the order). A
%   rect that is not 4 finite numbers overlaps nothing.
%
%   See also EphysAnalysisConfig.freeRect, EphysAnalysisConfig.orderPanel,
%   figureNeighbors.

arguments
    fig (1,1) struct
end

n = numel(fig.panels);
pairs = zeros(0, 2);
if n < 2; return; end
R = NaN(n, 4);
for k = 1:n
    r = double(fig.panels(k).rect);
    if numel(r) == 4 && all(isfinite(r)); R(k, :) = reshape(r, 1, 4); end
end
tol = EphysAnalysisConfig.RectTol;
for j = 1:n - 1
    for k = j + 1:n
        ox = min(R(j, 1) + R(j, 3), R(k, 1) + R(k, 3)) - max(R(j, 1), R(k, 1));
        oy = min(R(j, 2) + R(j, 4), R(k, 2) + R(k, 4)) - max(R(j, 2), R(k, 2));
        if ox > tol && oy > tol; pairs(end+1, :) = [j k]; end %#ok<AGROW>
    end
end
end
