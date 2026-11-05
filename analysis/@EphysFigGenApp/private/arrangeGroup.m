function [rect, rects] = arrangeGroup(rect0, rect, rects0, minSize)
%arrangeGroup  The other selected panels follow the one dragged or nudged: the same shift, or the same change of width and height about the same edges (pure).
%   [RECT, RECTS] = arrangeGroup(RECT0, RECT, RECTS0) takes the dragged
%   panel's rect when the drag started (RECT0) and where it goes now
%   (RECT, snapped), and the other selected panels' rects when it started
%   (RECTS0, a row each; [x y width height], 0-1 of the page):
%     a move (RECT the size of RECT0)  every rect shifts by RECT(1:2) -
%              RECT0(1:2), the shift cut so that every one, the dragged one
%              too, stays on the page: the group keeps its shape (RECT is
%              then the dragged one's place with the shift cut)
%     a resize  on each axis the dragged rect's edges that moved (left or
%              right, bottom or top) move as much in every rect: a wider
%              right edge widens each about its left edge, a corner changes
%              both; each cut to the page and kept at least MINSIZE (0.01)
%              wide and high (the edge that moved gives way)
%   RECTS0 empty: RECT as it is.
%
%   See also EphysFigGenApp.onArrangeMoving, EphysFigGenApp.nudgePanel, selectedPanelIds.
if nargin < 4; minSize = 0.01; end
rects = rects0;
if isempty(rects0); return; end
if all(abs(rect(3:4) - rect0(3:4)) < 1e-9)   % a move: one shift for all, kept on the page
    d = rect(1:2) - rect0(1:2);
    R = [rect0; rects0];
    lo = max(-R(:, 1:2), [], 1);
    hi = min(1 - R(:, 1:2) - R(:, 3:4), [], 1);
    d = min(max(d, lo), hi);
    rect = [rect0(1:2) + d, rect0(3:4)];
    rects(:, 1:2) = rects0(:, 1:2) + d;
    return
end
for a = 1:2   % a resize: the same edges by the same amounts
    dLo = rect(a) - rect0(a);
    dHi = (rect(a) + rect(a + 2)) - (rect0(a) + rect0(a + 2));
    lo = max(rects0(:, a) + dLo, 0);
    hi = min(rects0(:, a) + rects0(:, a + 2) + dHi, 1);
    small = hi - lo < minSize;
    if any(small)
        if abs(dHi) >= abs(dLo)
            hi(small) = min(lo(small) + minSize, 1);
            lo(small) = hi(small) - minSize;
        else
            lo(small) = max(hi(small) - minSize, 0);
            hi(small) = lo(small) + minSize;
        end
    end
    rects(:, a) = lo;
    rects(:, a + 2) = hi - lo;
end
end
