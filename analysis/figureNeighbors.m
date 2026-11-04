function N = figureNeighbors(rects, tol)
%figureNeighbors  How a figure's panel rects lie to one another: shared extents, gaps, and which touch which.
%   N = figureNeighbors(RECTS, TOL), RECTS an n x 4 array of rects
%   ([x y width height] per row, y up: a panel's rect, 0-1 of the page,
%   or a layout's boxes in px) and TOL how near two edges must be to touch
%   (in RECTS' units; default EphysAnalysisConfig.RectTol), is a struct of
%   n x n arrays, row j about rect j and column k about rect k:
%     xShare   the share of the narrower of the two widths that their x
%              extents have in common (0: none; 1: one spans the other's
%              width); symmetric
%     yShare   the same of their heights
%     gapX     the space between their x extents: > 0 apart side by side,
%              0 flush, < 0 overlapping (minus the width they share);
%              symmetric
%     gapY     the same up the page
%     below    k touches j's bottom edge (k's top within TOL of j's
%              bottom) and xShare(j, k) >= 0.5: k is the panel under j
%     above    k's bottom within TOL of j's top, xShare >= 0.5: k over j
%     left     k's right edge within TOL of j's left, yShare >= 0.5
%     right    k's left edge within TOL of j's right, yShare >= 0.5
%     inColumn xShare(j, k) >= 0.5 (one column of the page, apart or not)
%     flushV   |gapY| <= TOL and their x extents share more than TOL:
%              stacked flush, one on the other (either order)
%     flushH   |gapX| <= TOL and their y extents share more than TOL:
%              side by side, flush
%   below(j, k) == above(k, j) and left(j, k) == right(k, j). On the
%   diagonal (a rect with itself) every logical is false, xShare and
%   yShare 1 and gapX and gapY NaN. A row that is not 4 finite numbers
%   (or a width or height <= 0) is nobody's neighbor: logicals false,
%   shares 0, gaps NaN.
%
%   See also EphysAnalysisConfig.rectOverlaps, EphysAnalysisConfig.panelOrder.

arguments
    rects (:,4) double
    tol (1,1) double {mustBeNonnegative} = EphysAnalysisConfig.RectTol
end

n = size(rects, 1);
ok = all(isfinite(rects), 2) & rects(:, 3) > 0 & rects(:, 4) > 0;
x0 = rects(:, 1); x1 = x0 + rects(:, 3);
y0 = rects(:, 2); y1 = y0 + rects(:, 4);
w = rects(:, 3); h = rects(:, 4);

ox = min(x1, x1.') - max(x0, x0.');   % the x extent two rects share (< 0: the gap between them)
oy = min(y1, y1.') - max(y0, y0.');
N.xShare = max(ox, 0) ./ min(w, w.');
N.yShare = max(oy, 0) ./ min(h, h.');
N.gapX = -ox;
N.gapY = -oy;
N.below = abs(y1.' - y0) <= tol & N.xShare >= 0.5;   % (j, k): k's top at j's bottom
N.above = abs(y0.' - y1) <= tol & N.xShare >= 0.5;   % k's bottom at j's top
N.left  = abs(x1.' - x0) <= tol & N.yShare >= 0.5;   % k's right edge at j's left edge
N.right = abs(x0.' - x1) <= tol & N.yShare >= 0.5;   % k's left edge at j's right edge
N.inColumn = N.xShare >= 0.5;
N.flushV = abs(N.gapY) <= tol & ox > tol;
N.flushH = abs(N.gapX) <= tol & oy > tol;

bad = ~ok | ~ok.';
self = logical(eye(n));
for f = ["below" "above" "left" "right" "inColumn" "flushV" "flushH"]
    N.(f)(bad | self) = false;
end
N.xShare(bad) = 0;
N.yShare(bad) = 0;
N.gapX(bad) = NaN;
N.gapY(bad) = NaN;
N.xShare(self & ~bad) = 1;
N.yShare(self & ~bad) = 1;
N.gapX(self) = NaN;
N.gapY(self) = NaN;
end
