function rect = freeRect(fig, opts)
%freeRect  The largest empty rectangle of a figure's page: where a new panel fits without covering one.
%   RECT = EphysAnalysisConfig.freeRect(FIG) is the largest axis-aligned
%   rectangle ([x y width height], 0-1 of the page from its bottom-left
%   corner) inside the page [0 0 1 1] that meets no panel of figure FIG
%   (a Figures entry): it may touch a panel's edge, never cover any of
%   it. Its edges are among the page's (0, 1) and the panels' rect
%   edges, so it fits flush against its neighbors. Of rectangles of one
%   area (to 1e-9) the lowest wins, then the leftmost. A figure without
%   panels: the whole page.
%   RECT = EphysAnalysisConfig.freeRect(FIG, MinSize=M) leaves out the
%   rectangles narrower or lower than M (0-1 of the page; default 0.08):
%   RECT is the largest of the others, [] when none is left. (A thin
%   strip larger in area than a usable gap does not hide the gap.) M as
%   [width height] sets the two apart (renderFigure's floating legend: a
%   space that holds it).
%   Panel rects are clipped to the page first; one that is not 4 finite
%   numbers is ignored.
%
%   See also EphysAnalysisConfig.placePanel, EphysAnalysisConfig.placeBlock,
%   EphysAnalysisConfig.rectOverlaps.

arguments
    fig (1,1) struct
    opts.MinSize (1,:) double {mustBeNonnegative} = 0.08
end
mn = opts.MinSize;
if isscalar(mn); mn = [mn mn]; end

R = zeros(0, 4);   % the panels' rects as [x0 y0 x1 y1], clipped to the page
for k = 1:numel(fig.panels)
    r = double(fig.panels(k).rect);
    if ~(numel(r) == 4 && all(isfinite(r))); continue; end
    lo = max(0, min(1, r(1:2)));
    hi = max(0, min(1, r(1:2) + r(3:4)));
    if all(hi > lo); R(end+1, :) = [lo hi]; end %#ok<AGROW>
end
tol = 1e-12;
xs = unique([0 1 R(:, 1).' R(:, 3).']);
ys = unique([0 1 R(:, 2).' R(:, 4).']);
best = [];
bestKey = [-Inf 0 0];   % [area -y -x]: the largest, then the lowest, then the leftmost
for i = 1:numel(xs) - 1
    for j = i + 1:numel(xs)
        x0 = xs(i);
        x1 = xs(j);
        w = x1 - x0;
        if w < mn(1) - tol; continue; end
        % the panels across this x band block their y ranges; the free y intervals lie between them
        in = R(:, 1) < x1 - tol & R(:, 3) > x0 + tol;
        B = sortrows(R(in, [2 4]));
        y = 0;
        gaps = zeros(0, 2);
        for b = 1:size(B, 1)
            if B(b, 1) > y + tol; gaps(end+1, :) = [y B(b, 1)]; end %#ok<AGROW>
            y = max(y, B(b, 2));
        end
        if y < 1 - tol; gaps(end+1, :) = [y 1]; end %#ok<AGROW>
        for g = 1:size(gaps, 1)
            h = gaps(g, 2) - gaps(g, 1);
            if h < mn(2) - tol; continue; end
            key = [round(w * h, 9), -gaps(g, 1), -x0];
            if isBetter(key, bestKey)
                bestKey = key;
                best = [x0, gaps(g, 1), w, h];
            end
        end
    end
end
rect = best;
end


function tf = isBetter(a, b)
%isBetter  A beats B: a larger area, else a lower bottom, else a left edge further left (keys [area -y -x]).
d = find(abs(a - b) > 1e-12, 1);
tf = ~isempty(d) && a(d) > b(d);
end
