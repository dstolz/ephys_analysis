function L = figurePlace(A, panels, opts)
%figurePlace  Where a figure's panels go in pixels: each rect's plot area, its labels kept clear of the neighbors and the page edge (pure).
%   L = figurePlace(A, PANELS, Name=Value) places the panels of a figure on
%   the page A (figureArea's: page, area, title; pixel boxes [x y width
%   height] from the canvas's bottom-left corner). PANELS has one element
%   per panel:
%     rect    [x y width height], 0-1 of A.page from its bottom-left corner
%             (Panel.rect)
%     inset   [left bottom right top] px: the room the panel's labels take
%             round its plot area (tick labels, axis labels, its title, a
%             color bar outside), 0 on a side where nothing sits
%     band    "" or the side of its note's band: "below", "above", "left"
%             or "right" (the band holds the panel's labels on that side:
%             give that side's inset as 0)
%     need    the thickness its note's band asks for, px
%     shares  its axes' shares of its plot area, top to bottom (1: one
%             axes; a coherence panel's magnitude over its phase: [2 1])
%     fixed   (optional; default false) a legend panel: its insets count
%             as 0 (its axes are hidden), so it never moves a neighbor, and
%             no neighbor's labels move it
%
%   Mode "plot" (the default; Figure.layout.boxesMean "plot"): a rect is
%   the panel's plot area, moved in only as far as its labels need. Every
%   step only shrinks a box, never shifts or grows one, and none depends on
%   the order of PANELS:
%     0. The rects in px. Two rects whose facing edges lie within Tol of
%        each other, with their extents across sharing more than Tol, are
%        flush: their shared edge is snapped to the edges' mean and the
%        insets on those two sides count as 0 (the user put them flush: a
%        time stack has no labels there; labels a flush panel keeps run
%        over its neighbor). Two rects sharing more than Tol both across
%        and up overlap and are left alone. Edges within Tol of each other
%        (left, bottom, right and top edges each apart) form aligned
%        classes.
%     1. The edges of A.area (the page's margin, the title band) are
%        obstacles: a side with an inset is moved in by d = inset + Padding
%        - room (room: from the box's edge to the area's), when d > 0; a
%        side without one only as far as it sticks out of the area.
%     2. Two separated rects (apart by more than Tol, their extents across
%        sharing more than Tol) need the insets of their facing sides and
%        Padding (when either has one) between their plot areas; the
%        shortfall d = need - gap is split between the two sides in
%        proportion to each one's inset (plus Padding / 2 where it has
%        one). A side takes the largest move any pair or edge asks of it.
%     3. The sides of an aligned class all take the largest move of the
%        class, so plot edges that lined up still do (a panel can move in
%        for a neighbor it merely lines up with, as a grid's would). An
%        edge held flush and a legend panel's edges take none.
%     4. The moves are applied, a box never narrower or lower than MinSize
%        px from them (clipped: its labels may then overlap).
%     5. Steps 1-4 again on the moved boxes while any shortfall is over
%        0.5 px, at most 3 times.
%     6. A note's band, at most half the box, comes off the side its note
%        is on, and the axes share what is left top to bottom.
%   Mode "outer" ("outer"): a rect encloses the panel with its labels: the
%   plot area is the rect, clipped to A.area, less inset + Padding on each
%   side with an inset (flush pairs' facing sides have none, so they stay
%   flush); aligned classes take the largest; then steps 4 and 6.
%   A legend panel (fixed) is placed as its rect, clipped to A.area.
%
%   Options
%     Mode     "plot" (default) | "outer"
%     Padding  px of clear space between a panel's labels and its
%              neighbors' labels or the area's edge (outer: between the
%              rect's edge and the labels); default 0
%     Tol      px within which two edges meet or line up (default 2)
%     MinSize  px a plot area keeps at least each way (default 12)
%
%   L fields (pixel boxes [x y width height] from the bottom left)
%     page, area, title  A's
%     panels   one per PANELS: outer (its rect in px, flush edges snapped),
%              box (its plot area; without the note's band), axes (one row
%              per share: each axes' plot box, top to bottom), band (its
%              note's band; [] = none), nudged ([left bottom right top]: px
%              each side was moved in), clipped (true when MinSize stopped
%              a move)
%     neighbors  figureNeighbors of the outer boxes, at Tol
%
%   See also figureArea, figureLayout, renderFigure, figureNeighbors.

arguments
    A (1,1) struct
    panels struct
    opts.Mode (1,1) string {mustBeMember(opts.Mode, ["plot" "outer"])} = "plot"
    opts.Padding (1,1) double {mustBeNonnegative} = 0
    opts.Tol (1,1) double {mustBeNonnegative} = 2
    opts.MinSize (1,1) double {mustBeNonnegative} = 12
end
n = numel(panels);
pg = double(A.page);
ar = double(A.area);
pad = opts.Padding;
tol = opts.Tol;
L = struct('page', pg, 'area', ar, 'title', [], ...
    'panels', struct('outer', {}, 'box', {}, 'axes', {}, 'band', {}, 'nudged', {}, 'clipped', {}), ...
    'neighbors', figureNeighbors(zeros(0, 4), tol));
if isfield(A, 'title'); L.title = A.title; end
if n == 0; return; end

% 0. the rects as px edges [x0 y0 x1 y1], the insets, the legend panels
E = zeros(n, 4);
I = zeros(n, 4);
fixed = false(n, 1);
for k = 1:n
    r = double(panels(k).rect);
    if ~(numel(r) == 4 && all(isfinite(r))); r = [0 0 1 1]; end
    r(3:4) = max(r(3:4), 0);
    E(k, :) = [pg(1) + r(1) * pg(3), pg(2) + r(2) * pg(4), pg(1) + (r(1) + r(3)) * pg(3), pg(2) + (r(2) + r(4)) * pg(4)];
    I(k, :) = max(0, reshape(double(panels(k).inset), 1, 4));
    if isfield(panels, 'fixed') && ~isempty(panels(k).fixed); fixed(k) = logical(panels(k).fixed(1)); end
end
I(fixed, :) = 0;
P = facing(E, tol);   % [a b sideA sideB gap]: a's side faces b's (a over b: 2 and 4; a left of b: 3 and 1)
flush = abs(P(:, 5)) <= tol;
E = snapFlush(E, P(flush, :), n);
held = false(n, 4);   % sides held where they are: an edge flush with a panel's, every side of a legend panel
held(fixed, :) = true;
for i = reshape(find(flush), 1, [])
    a = P(i, 1); b = P(i, 2);
    if fixed(a) || fixed(b); continue; end   % against a legend panel: its neighbor's labels are still kept clear of it
    I(a, P(i, 3)) = 0;
    I(b, P(i, 4)) = 0;
    held(a, P(i, 3)) = true;
    held(b, P(i, 4)) = true;
end
Q = P(~flush | fixed(P(:, 1)) | fixed(P(:, 2)), :);   % the pairs that keep their labels apart
Q = Q(Q(:, 5) >= -tol, :);
cls = zeros(n, 4);   % each side's aligned class (0: a legend panel's)
for c = 1:4
    cls(~fixed, c) = chains(E(~fixed, c), tol);
end

W = E(:, 3) - E(:, 1);
H = E(:, 4) - E(:, 2);
Nd = zeros(n, 4);        % how far each side is moved in
clipped = false(n, 1);
if opts.Mode == "outer"
    room = [E(:, 1) - ar(1), E(:, 2) - ar(2), ar(1) + ar(3) - E(:, 3), ar(2) + ar(4) - E(:, 4)];
    Nd = I + pad * (I > 0) + max(0, -room);
    Nd = classMax(Nd, cls, held);
    [Nd, clipped] = keepMin(Nd, W, H, opts.MinSize, clipped);
else
    for it = 1:3
        B = E + [Nd(:, 1:2) -Nd(:, 3:4)];
        [s, dmax] = demands(B, I, Q, fixed, ar, pad);
        if dmax <= 0.5; break; end
        Nd = Nd + classMax(s, cls, held);
        [Nd, clipped] = keepMin(Nd, W, H, opts.MinSize, clipped);
    end
end

% 6. each panel's note band and axes
B = E + [Nd(:, 1:2) -Nd(:, 3:4)];
outer = [E(:, 1:2), W, H];
for k = 1:n
    box = [B(k, 1:2), max(B(k, 3:4) - B(k, 1:2), 0)];
    band = [];
    need = 0;
    if isfield(panels, 'need'); need = max(0, double(panels(k).need)); end
    side = "";
    if isfield(panels, 'band'); side = string(panels(k).band); end
    if isempty(side); side = ""; end
    switch side
        case "below"
            b = min(need, box(4) / 2);
            band = [box(1), box(2), box(3), b];
            box = box + [0 b 0 -b];
        case "above"
            b = min(need, box(4) / 2);
            band = [box(1), box(2) + box(4) - b, box(3), b];
            box(4) = box(4) - b;
        case "left"
            b = min(need, box(3) / 2);
            band = [box(1), box(2), b, box(4)];
            box = box + [b 0 -b 0];
        case "right"
            b = min(need, box(3) / 2);
            band = [box(1) + box(3) - b, box(2), b, box(4)];
            box(3) = box(3) - b;
    end
    f = 1;
    if isfield(panels, 'shares'); f = reshape(double(panels(k).shares), 1, []); end
    if isempty(f) || any(~(f > 0)); f = 1; end
    f = f / sum(f);
    X = zeros(numel(f), 4);
    yTop = box(2) + box(4);
    for i = 1:numel(f)
        hi = box(4) * f(i);
        X(i, :) = [box(1), yTop - hi, box(3), hi];
        yTop = yTop - hi;
    end
    L.panels(k) = struct('outer', outer(k, :), 'box', box, 'axes', X, 'band', band, 'nudged', Nd(k, :), 'clipped', clipped(k));
end
L.neighbors = figureNeighbors(outer, tol);
end


function P = facing(E, tol)
%facing  The pairs of boxes (edges [x0 y0 x1 y1]) one over or beside the other: [a b sideA sideB gap], a's side facing b's.
%   One over the other: their x extents share more than TOL, a the upper
%   (sides 2, 4: a's bottom, b's top). Side by side: their y extents share
%   more than TOL, a the left one (sides 3, 1). GAP: the space between the
%   facing edges (< 0: they cross). Pairs sharing more than TOL both ways
%   overlap and are not listed.
n = size(E, 1);
P = zeros(0, 5);
for j = 1:n - 1
    for k = j + 1:n
        ox = min(E(j, 3), E(k, 3)) - max(E(j, 1), E(k, 1));
        oy = min(E(j, 4), E(k, 4)) - max(E(j, 2), E(k, 2));
        if ox > tol && oy > tol; continue; end
        if ox > tol
            if E(j, 2) + E(j, 4) >= E(k, 2) + E(k, 4); a = j; b = k; else; a = k; b = j; end
            P(end+1, :) = [a b 2 4 E(a, 2) - E(b, 4)]; %#ok<AGROW>
        elseif oy > tol
            if E(j, 1) + E(j, 3) <= E(k, 1) + E(k, 3); a = j; b = k; else; a = k; b = j; end
            P(end+1, :) = [a b 3 1 E(b, 1) - E(a, 3)]; %#ok<AGROW>
        end
    end
end
end


function E = snapFlush(E, F, n)
%snapFlush  The edges flush pairs F share ([a b sideA sideB gap] rows), each set of edges joined by them snapped to their mean.
%   An edge is node (side - 1) * n + panel, its index into E; the sets are
%   the connected components of the flush pairs, whatever their order.
lab = 1:4 * n;
for i = 1:size(F, 1)
    u = lab((F(i, 3) - 1) * n + F(i, 1));
    v = lab((F(i, 4) - 1) * n + F(i, 2));
    lab(lab == v) = u;
end
for c = unique(lab)
    m = find(lab == c);
    if numel(m) > 1; E(m) = mean(E(m)); end
end
end


function c = chains(v, tol)
%chains  Classes of values that lie within TOL of a neighbor once sorted (aligned edges), as class numbers.
c = zeros(size(v));
if isempty(v); return; end
[sv, o] = sort(v(:));
c(o) = cumsum([1; diff(sv) > tol]);
end


function [s, dmax] = demands(B, I, Q, fixed, ar, pad)
%demands  How far each side of the boxes B (edges) must move in for its labels (steps 1 and 2), and the largest shortfall.
need = I + pad * (I > 0);
room = [B(:, 1) - ar(1), B(:, 2) - ar(2), ar(1) + ar(3) - B(:, 3), ar(2) + ar(4) - B(:, 4)];
D = need - room;
s = max(D, 0);
dmax = max([0; D(:)]);
for i = 1:size(Q, 1)
    a = Q(i, 1); b = Q(i, 2); sa = Q(i, 3); sb = Q(i, 4);
    if sa == 2
        g = B(a, 2) - B(b, 4);
    else
        g = B(b, 1) - B(a, 3);
    end
    ia = I(a, sa);
    ib = I(b, sb);
    d = ia + ib + pad * (ia > 0 || ib > 0) - g;
    wa = (ia + pad / 2 * (ia > 0)) * ~fixed(a);
    wb = (ib + pad / 2 * (ib > 0)) * ~fixed(b);
    if d <= 0 || wa + wb <= 0; continue; end
    dmax = max(dmax, d);
    s(a, sa) = max(s(a, sa), d * wa / (wa + wb));
    s(b, sb) = max(s(b, sb), d * wb / (wa + wb));
end
end


function s = classMax(s, cls, held)
%classMax  Every side of an aligned class moved as far as the furthest of it (step 3); held sides keep their own.
for c = 1:4
    for q = reshape(unique(cls(cls(:, c) > 0, c)), 1, [])
        m = cls(:, c) == q;
        v = max(s(m, c));
        s(m & ~held(:, c), c) = v;
    end
end
end


function [Nd, clipped] = keepMin(Nd, W, H, minSize, clipped)
%keepMin  The moves cut back where a box would get narrower or lower than MINSIZE px (step 4).
for k = 1:size(Nd, 1)
    t = Nd(k, 1) + Nd(k, 3);
    if t > 0 && W(k) - t < minSize - 1e-9
        Nd(k, [1 3]) = Nd(k, [1 3]) * max(0, W(k) - minSize) / t;
        clipped(k) = true;
    end
    t = Nd(k, 2) + Nd(k, 4);
    if t > 0 && H(k) - t < minSize - 1e-9
        Nd(k, [2 4]) = Nd(k, [2 4]) * max(0, H(k) - minSize) / t;
        clipped(k) = true;
    end
end
end
