function [rect, g] = snapRect(rect, prev, others, step, tol, opts)
%snapRect  Snap a panel's rect moved or resized over the preview: to the other panels, the page and a step grid; and the smart guides it earns (pure).
%   [RECT, G] = snapRect(RECT, PREV, OTHERS, STEP, TOL) takes RECT, a
%   panel's [x y width height] (0-1 of the page, from its bottom-left
%   corner) where the pointer put it, and PREV, the rect before the drag
%   (the one the figure holds), which tells a move from a resize:
%     move    (PREV's width and height): the whole rect shifts, on each
%             axis apart, to the nearest candidate within TOL: an edge of
%             another panel (OTHERS, a row each) on either edge of the
%             rect (the same edge: aligned; the opposite one: abutting,
%             flush), another panel's center or the page's (0.5) on the
%             rect's center, the page's edges (0, 1), or equal spacing
%             (the gap to the nearest panel on one side equal to that
%             panel's gap to the next one beyond it, or to the gap on the
%             other side); else the nearer of its two edges goes to the
%             STEP grid. It stays on the page.
%     resize  only the edge or edges moved snap (one per axis): to the
%             other panels' edges, the page's edge on that side, an equal
%             size (its width or height that of another panel), else the
%             STEP grid; no centers. A width or height stays at least 0.01.
%     point   PREV = [] and RECT = [x y 0 0]: a corner clicked (Set
%             corners) snaps to the other panels' edges, the page's edges,
%             else the grid.
%   STEP [x y] is the grid's step on each axis (0: no grid), TOL [x y] how
%   near a candidate must be (0: no snapping: only what lines up exactly
%   counts, for the guides: Alt held, an arrow key's nudge). A candidate
%   wins by its distance; at a tie edges come first, then the page,
%   centers, spacing and size.
%
%   G describes every cue the smart guides draw (arrangeCues), for RECT as
%   snapped:
%     mode     "move" | "resize" | "point"
%     rect     RECT
%     moved    [low high] edges moved, a row per axis (x, y): all for a
%              move, the dragged edges for a resize
%     x, y     what each axis snapped to: struct kind ("edge" | "page" |
%              "center" | "spacing" | "size" | "grid" | ""), other (index
%              into OTHERS; 0 = the page or none)
%     lines    alignment lines, a row [x0 y0 x1 y1] each: through every
%              edge or center of the rect (a moved edge when resizing)
%              that lines up with another panel's, from that panel to
%              the rect and a little past both; the page's center line
%              when the rect is centered on it (moving)
%     gaps     distance readouts, a struct each: axis ("x" | "y"), seg
%              ([x0 y0 x1 y1], along the gap at the middle of the extent
%              the two share), value (the gap, 0-1 of the page along
%              AXIS), other (index into OTHERS; 0 = the page's edge),
%              equal (true: one of an equal-spacing pair, a move that
%              ends with a gap as its neighbor's: whichever candidate put
%              it there). On each side
%              of the rect, to the nearest panel facing it (or the
%              page's edge), when under Reach of the page and not flush;
%              with equal spacing both gaps of the pair (the one between
%              two other panels too)
%     size     equal size, when a resized width or height is another
%              panel's: struct axis ("x" | "y"), other (index into OTHERS),
%              name (its id: Names), rect (its rect); [] = none
%   Options
%     Names  the other panels' ids (G.size.name)
%     Reach  the longest gap read out, 0-1 of the page (default 0.25)
%     Min    the least width or height a resize leaves (default 0.01)
%
%   See also EphysFigGenApp.onArrangeMoving, arrangeCues, figureNeighbors.
arguments
    rect (1,4) double
    prev double
    others (:,4) double
    step (1,2) double {mustBeNonnegative}
    tol (1,2) double {mustBeNonnegative}
    opts.Names (1,:) string = strings(1, 0)
    opts.Reach (1,1) double = 0.25
    opts.Min (1,1) double = 0.01
end
eps0 = 1e-9;
bad = ~(all(isfinite(others), 2) & others(:, 3) > 0 & others(:, 4) > 0);
others(bad, :) = NaN;   % (a bad rect is nobody's: every comparison with it is false; the indices stay)
if isempty(prev)
    mode = "point";
    rect(3:4) = 0;
elseif all(abs(rect(3:4) - prev(3:4)) < eps0)
    mode = "move";
else
    mode = "resize";
end
axes2 = ["x" "y"];
kinds = ["edge" "page" "center" "spacing" "size" "grid"];
none = struct('kind', "", 'other', 0);
g = struct('mode', mode, 'rect', rect, 'moved', false(2, 2), 'x', none, 'y', none, 'lines', zeros(0, 4), ...
    'gaps', struct('axis', {}, 'seg', {}, 'value', {}, 'other', {}, 'equal', {}), 'size', []);
pairs = {zeros(0, 2), zeros(0, 2)};   % equal spacing on x, on y: rows [low high], 0 = the rect
moved = false(2, 2);                   % per axis: its low edge moved, its high edge moved
n = size(others, 1);
idx = (1:n).';
for a = 1:2
    b = 3 - a;
    lo = rect(a); sz = rect(a + 2); hi = lo + sz;
    olo = others(:, a); ohi = olo + others(:, a + 2); osz = others(:, a + 2);
    C = zeros(0, 4);   % candidates: [delta rank other edge]; rank: the index into KINDS; edge 1 low, 2 high, 3 center
    switch mode
        case "move"
            moved(a, :) = true;
            for e = 1:2
                v = lo * (e == 1) + hi * (e == 2);
                C = [C; olo - v, ones(n, 1), idx, e * ones(n, 1); ohi - v, ones(n, 1), idx, e * ones(n, 1)]; %#ok<AGROW>
            end
            mid = (lo + hi) / 2;
            C = [C; 0 - lo, 2, 0, 1; 1 - hi, 2, 0, 2; (olo + ohi) / 2 - mid, 3 * ones(n, 1), idx, 3 * ones(n, 1); 0.5 - mid, 3, 0, 3];
            across = overlap(rect(b), rect(b) + rect(b + 2), others(:, b), others(:, b) + others(:, b + 2)) > eps0;
            C = [C; spacing(lo, sz, olo, ohi, others, a, across, eps0)]; %#ok<AGROW>
        case "resize"
            moved(a, 1) = abs(rect(a) - prev(a)) > eps0;
            moved(a, 2) = abs(hi - (prev(a) + prev(a + 2))) > eps0;
            if all(moved(a, :)); moved(a, 1) = false; end   % (no resize on this axis: the high edge leads)
            for e = find(moved(a, :))
                v = lo * (e == 1) + hi * (e == 2);
                C = [C; olo - v, ones(n, 1), idx, e * ones(n, 1); ohi - v, ones(n, 1), idx, e * ones(n, 1)]; %#ok<AGROW>
                if e == 1   % the page's edge on that side; a width or height another panel has
                    C = [C; 0 - lo, 2, 0, 1; (hi - osz) - lo, 5 * ones(n, 1), idx, ones(n, 1)]; %#ok<AGROW>
                else
                    C = [C; 1 - hi, 2, 0, 2; (lo + osz) - hi, 5 * ones(n, 1), idx, 2 * ones(n, 1)]; %#ok<AGROW>
                end
            end
        otherwise   % a point: the other panels' edges and the page's
            moved(a, 1) = true;
            C = [olo - lo, ones(n, 1), idx, ones(n, 1); ohi - lo, ones(n, 1), idx, ones(n, 1); 0 - lo, 2, 0, 1; 1 - lo, 2, 0, 1];
    end
    C = C(fits(C, mode, lo, hi, opts.Min, eps0), :);
    pick = [];
    near = abs(C(:, 1)) <= tol(a) + 1e-12;
    if any(near)
        Cn = C(near, :);
        [~, o] = sortrows([abs(Cn(:, 1)) Cn(:, 2)]);
        pick = Cn(o(1), :);
    elseif step(a) > 0   % else the step grid: the nearer of the edges that may move
        G = zeros(0, 4);
        for e = find(moved(a, :))
            v = lo * (e == 1) + hi * (e == 2);
            G(end+1, :) = [round(v / step(a)) * step(a) - v, 6, 0, e]; %#ok<AGROW>
        end
        G = G(fits(G, mode, lo, hi, opts.Min, eps0), :);
        if ~isempty(G)
            [~, i] = min(abs(G(:, 1)));
            pick = G(i, :);
        end
    end
    if ~isempty(pick)
        other = pick(3);
        if pick(2) == 4; other = 0; end   % (a spacing candidate's third column is its pair's index)
        g.(axes2(a)) = struct('kind', kinds(pick(2)), 'other', other);
        d = pick(1);
        switch mode
            case "move"
                lo = min(max(lo + d, 0), max(1 - sz, 0));
            case "resize"
                if pick(4) == 1
                    lo = lo + d;
                    sz = hi - lo;
                else
                    sz = sz + d;
                end
            otherwise
                lo = min(max(lo + d, 0), 1);
        end
    end
    rect(a) = lo;
    rect(a + 2) = sz;
end
g.rect = rect;
g.moved = moved;
% what holds where it ended (whichever candidate won: a center can put it at an equal spacing too)
for a = 1:2
    b = 3 - a;
    lo = rect(a); sz = rect(a + 2);
    olo = others(:, a); ohi = olo + others(:, a + 2);
    if mode == "move"   % equal spacing: the pairs whose gaps match now
        across = overlap(rect(b), rect(b) + rect(b + 2), others(:, b), others(:, b) + others(:, b + 2)) > eps0;
        [S, P] = spacing(lo, sz, olo, ohi, others, a, across, eps0);
        for i = find(abs(S(:, 1)) <= 1e-6).'
            pairs{a} = [pairs{a}; P{S(i, 3)}];
        end
        pairs{a} = unique(pairs{a}, 'rows', 'stable');
    elseif mode == "resize" && any(moved(a, :)) && isempty(g.size)   % equal size: another panel as wide (high)
        q = find(abs(others(:, a + 2) - sz) <= 1e-6, 1);
        if ~isempty(q)
            g.size = struct('axis', axes2(a), 'other', q, 'name', nameOf(opts.Names, q), 'rect', others(q, :));
        end
    end
end
g.lines = alignLines(rect, others, mode, moved);
g.gaps = gapReadouts(rect, others, mode, pairs, opts.Reach, eps0);
end


function [S, P] = spacing(lo, sz, olo, ohi, others, a, across, eps0)
%spacing  Equal-spacing candidates on axis A: rows [delta 4 i 1] (i: the pair's index in P), P the pairs [low high] (0 = the rect).
S = zeros(0, 4);
P = {};
hi = lo + sz;
b = 3 - a;
L = nearestBelow(lo, olo, ohi, across, eps0);
R = nearestAbove(hi, olo, ohi, across, eps0);
if ~isempty(L) && ~isempty(R)   % the same gap on both sides
    x = (ohi(L) + olo(R) - sz) / 2;
    if x - ohi(L) > eps0
        P{end+1} = [L 0; 0 R];
        S(end+1, :) = [x - lo, 4, numel(P), 1];
    end
end
if ~isempty(L)   % the gap to L as L's to the panel beyond it
    withL = overlap(others(L, b), others(L, b) + others(L, b + 2), others(:, b), others(:, b) + others(:, b + 2)) > eps0;
    withL(L) = false;
    LL = nearestBelow(olo(L), olo, ohi, withL, eps0);
    if ~isempty(LL) && olo(L) - ohi(LL) > eps0
        P{end+1} = [LL L; L 0];
        S(end+1, :) = [ohi(L) + (olo(L) - ohi(LL)) - lo, 4, numel(P), 1];
    end
end
if ~isempty(R)
    withR = overlap(others(R, b), others(R, b) + others(R, b + 2), others(:, b), others(:, b) + others(:, b + 2)) > eps0;
    withR(R) = false;
    RR = nearestAbove(ohi(R), olo, ohi, withR, eps0);
    if ~isempty(RR) && olo(RR) - ohi(R) > eps0
        P{end+1} = [0 R; R RR];
        S(end+1, :) = [olo(R) - (olo(RR) - ohi(R)) - hi, 4, numel(P), 2];
    end
end
end


function k = nearestBelow(v, olo, ohi, ok, eps0)
%nearestBelow  The panel wholly below V (its high edge at or under V) among OK, nearest to it; [] = none.
c = find(ok & ohi <= v + eps0 & olo < v - eps0);
[~, i] = max(ohi(c));
k = c(i);
end


function k = nearestAbove(v, olo, ohi, ok, eps0)
c = find(ok & olo >= v - eps0 & ohi > v + eps0);
[~, i] = min(olo(c));
k = c(i);
end


function s = overlap(a0, a1, b0, b1)
%overlap  The extent [A0 A1] shares with each [B0 B1] (< 0: apart).
s = min(a1, b1) - max(a0, b0);
end


function L = alignLines(rect, others, mode, moved)
%alignLines  The alignment lines: every edge (or center) of RECT that lines up with another panel's, spanning both and a little past.
L = zeros(0, 4);
pad = 0.02;
tolLine = 1e-6;
for a = 1:2
    b = 3 - a;
    lo = rect(a); hi = lo + rect(a + 2);
    vals = [lo hi (lo + hi) / 2];
    use = [moved(a, 1) moved(a, 2) mode == "move"];
    if mode == "point"; use = [true false false]; end
    olo = others(:, a); ohi = olo + others(:, a + 2);
    for e = find(use)
        v = vals(e);
        if e < 3
            hit = abs(olo - v) <= tolLine | abs(ohi - v) <= tolLine;
        else
            hit = abs((olo + ohi) / 2 - v) <= tolLine;
        end
        if any(hit)
            ext = [others(hit, b); others(hit, b) + others(hit, b + 2); rect(b); rect(b) + rect(b + 2)];
            span = [max(min(ext) - pad, 0), min(max(ext) + pad, 1)];
            L(end+1, :) = lineAt(a, v, span); %#ok<AGROW>
        end
        if e == 3 && abs(v - 0.5) <= tolLine
            L(end+1, :) = lineAt(a, 0.5, [0 1]); %#ok<AGROW>
        end
    end
end
end


function r = lineAt(a, v, span)
%lineAt  A line at V on axis A (x: a vertical line), along the other axis over SPAN.
if a == 1
    r = [v span(1) v span(2)];
else
    r = [span(1) v span(2) v];
end
end


function G = gapReadouts(rect, others, mode, pairs, reach, eps0)
%gapReadouts  The distance readouts: equal-spacing pairs first, then the nearest panel or page edge on each side not already read.
G = struct('axis', {}, 'seg', {}, 'value', {}, 'other', {}, 'equal', {});
if mode == "point"; return; end
all4 = [rect; others];   % index 1 = the rect, k + 1 = others(k)
names = ["x" "y"];
done = false(2, 2);   % per axis: the rect's low side, high side read out
for a = 1:2
    for r = 1:size(pairs{a}, 1)
        p = pairs{a}(r, :);
        lowR = all4(p(1) + 1, :);
        highR = all4(p(2) + 1, :);
        G(end+1) = gapBetween(a, lowR, highR, p(1) + p(2) * (p(1) == 0), true); %#ok<AGROW>
        if p(1) == 0; done(a, 2) = true; end
        if p(2) == 0; done(a, 1) = true; end
    end
end
for a = 1:2
    b = 3 - a;
    lo = rect(a); hi = lo + rect(a + 2);
    olo = others(:, a); ohi = olo + others(:, a + 2);
    across = overlap(rect(b), rect(b) + rect(b + 2), others(:, b), others(:, b) + others(:, b + 2)) > eps0;
    if ~done(a, 1)
        k = nearestBelow(lo, olo, ohi, across, eps0);
        if isempty(k)
            gap = gapToPage(a, rect, 0);
        else
            gap = gapBetween(a, others(k, :), rect, k, false);
        end
        if gap.value > 1e-6 && gap.value <= reach; G(end+1) = gap; end %#ok<AGROW>
    end
    if ~done(a, 2)
        k = nearestAbove(hi, olo, ohi, across, eps0);
        if isempty(k)
            gap = gapToPage(a, rect, 1);
        else
            gap = gapBetween(a, rect, others(k, :), k, false);
        end
        if gap.value > 1e-6 && gap.value <= reach; G(end+1) = gap; end %#ok<AGROW>
    end
end
for i = 1:numel(G); G(i).axis = names(G(i).axis); end
end


function s = gapBetween(a, lowR, highR, other, equal)
%gapBetween  The gap on axis A from LOWR's high edge to HIGHR's low edge, at the middle of the extent the two share across.
b = 3 - a;
v0 = lowR(a) + lowR(a + 2);
v1 = highR(a);
c = (max(lowR(b), highR(b)) + min(lowR(b) + lowR(b + 2), highR(b) + highR(b + 2))) / 2;
s = struct('axis', a, 'seg', segAt(a, v0, v1, c), 'value', v1 - v0, 'other', other, 'equal', equal);
end


function s = gapToPage(a, rect, side)
%gapToPage  The gap on axis A from RECT to the page's edge SIDE (0 low, 1 high), at the rect's middle across.
b = 3 - a;
c = rect(b) + rect(b + 2) / 2;
if side == 0
    v0 = 0; v1 = rect(a);
else
    v0 = rect(a) + rect(a + 2); v1 = 1;
end
s = struct('axis', a, 'seg', segAt(a, v0, v1, c), 'value', v1 - v0, 'other', 0, 'equal', false);
end


function r = segAt(a, v0, v1, c)
if a == 1
    r = [v0 c v1 c];
else
    r = [c v0 c v1];
end
end


function n = nameOf(names, k)
n = "";
if k >= 1 && k <= numel(names); n = names(k); end
end


function ok = fits(C, mode, lo, hi, minSize, eps0)
%fits  The candidates a resize can take: a width or height of at least MINSIZE, on the page (a move or a point takes any).
ok = true(size(C, 1), 1);
if mode ~= "resize" || isempty(C); return; end
newLo = lo + C(:, 1) .* (C(:, 4) == 1);
newHi = hi + C(:, 1) .* (C(:, 4) == 2);
ok = newHi - newLo >= minSize - eps0 & newLo >= -eps0 & newHi <= 1 + eps0;
end
