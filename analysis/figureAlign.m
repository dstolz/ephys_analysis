function [rects, info] = figureAlign(rects, which, how, opts)
%figureAlign  Line up some of a figure's panels, or space them evenly: by their boxes, their axes, or their axes with their labels (pure).
%   RECTS = figureAlign(RECTS, WHICH, HOW) moves the panels WHICH of a
%   figure whose panels' rects are RECTS (a row each, [x y width height],
%   0-1 of the page from its bottom-left corner, as Panel.rect) and gives
%   all the rects back. WHICH: indices into the rows of RECTS, the first
%   the panel others can be lined up with (To "first"). Only those panels
%   move, only along one axis, and none changes size. HOW:
%     "left" "center" "right"   their left edges, centers or right edges
%                               lined up (they move across the page)
%     "top" "middle" "bottom"   their top edges, middles or bottom edges
%                               lined up (they move up or down)
%     "spaceX"   equal gaps between them across the page
%     "spaceY"   equal gaps between them up the page
%   For spacing, panels whose extents across overlap (a column, for
%   "spaceX"; a row, for "spaceY") move as one: in a grid of panels each
%   column (row) keeps its shape and the gaps between the columns (rows)
%   are made equal.
%
%   Options
%     Feature  what is lined up or spaced (default "box"):
%              "box"     the panels' boxes: their rects
%              "axes"    their plot areas as the layout draws them (the
%                        axes; a panel of several axes, all of them)
%              "labels"  their axes with the tick labels, axis labels,
%                        title and note band round them, as drawn
%              "axes" and "labels" need Layout.
%     To       what they are lined up with (default "selection"):
%              "selection"  the extent of all of them (left: the leftmost;
%                           center: the middle of their extent)
%              "first"      the first of WHICH, which does not move
%              "page"       the page (Feature "axes": the area under the
%                           figure's title, inside its margin, where the
%                           layout keeps them; "labels": that area less
%                           the layout's padding, the room it keeps
%                           between the labels and the page's edge)
%              Spacing with an even gap (Gap []): "selection" and "first"
%              keep the outermost where they are and space the ones
%              between (three or more needed); "page" spreads them from
%              one edge of the page to the other (two or more). With a
%              Gap: "selection" keeps the first in reading order where it
%              is (the leftmost; for spaceY the topmost), "first" keeps
%              the first of WHICH, "page" centers them all on the page.
%     Gap      [] (default: even gaps) or the gap between them, 0-1 of the
%              page along the axis spaced (figureRectConvert converts a
%              length)
%     Layout   [] or the layout of the figure as drawn (figureLayout keeps
%              it on the canvas: appdata FigureLayoutResult) with its
%              panels in the order of RECTS: its page, size, top, margin,
%              scale, the settings the panels were placed with (how) and
%              what each panel's labels take (cells). The panels' places
%              are worked out again from it for each try (figurePlace), so
%              a panel's labels moving it in from its rect are counted:
%              the rects are moved until the axes (or labels) line up,
%              within a quarter of a pixel.
%
%   A panel moves only as far as the page allows (its rect stays on it).
%   A panel whose axes cannot get where they should -- its labels need the
%   room by the page's edge or by a neighbor, so its plot area stays put
%   however its rect moves -- is left where its axes got as far as they
%   could and reported held.
%
%   INFO: moved (logical, one per row of RECTS: its rect changed), held
%   (logical, one per row: one of WHICH that did not get where it should,
%   by more than half a pixel), groups (spacing: how many columns or rows
%   were spaced; aligning: the number of panels), room (false when spacing
%   with a Gap or across the page does not fit: nothing moved), gap
%   (spacing: the gap left between them, 0-1 of the page along the axis;
%   NaN when nothing was spaced).
%
%   Example
%     r = [0.05 0.55 0.4 0.4; 0.5 0.6 0.4 0.35; 0.1 0.05 0.8 0.4];
%     r = figureAlign(r, [1 2], "top")              % the two upper panels' tops lined up
%     r = figureAlign(r, 1:3, "left", To="page")    % every left edge at the page's
%     r = figureAlign(r, [1 2], "spaceX", Gap=0.05) % 5% of the page's width between them
%
%   See also figureRectConvert, figureNeighbors, figurePlace, figureLayout.

arguments
    rects (:,4) double
    which (1,:) double {mustBeInteger, mustBePositive}
    how (1,1) string {mustBeMember(how, ["left" "center" "right" "top" "middle" "bottom" "spaceX" "spaceY"])}
    opts.Feature (1,1) string {mustBeMember(opts.Feature, ["box" "axes" "labels"])} = "box"
    opts.To (1,1) string {mustBeMember(opts.To, ["selection" "first" "page"])} = "selection"
    opts.Gap double = []
    opts.Layout = []
end
n = size(rects, 1);
which = unique(which, 'stable');
if any(which > n); error('figureAlign:which', 'WHICH names a panel past the %d rects.', n); end
if ~isempty(opts.Gap) && ~(isscalar(opts.Gap) && isfinite(opts.Gap) && opts.Gap >= 0)
    error('figureAlign:gap', 'Gap is [] (even gaps) or a number of 0 or more (0-1 of the page).');
end
info = struct('moved', false(1, n), 'held', false(1, n), 'groups', numel(which), 'room', true, 'gap', NaN);
if isempty(which); return; end
M = model(opts.Layout, opts.Feature, n);
a = 1 + ismember(how, ["top" "middle" "bottom" "spaceY"]);   % 1: across (x), 2: up (y)
F0 = features(rects, M);
lo = F0(which, a);
hi = F0(which, a) + F0(which, a + 2);
page = M.bounds(a, :);
rects0 = rects;
if startsWith(how, "space")
    [want, info.groups, info.room, info.gap] = spacing(lo, hi, a, opts.To, opts.Gap, page);
    if isempty(want); return; end
    side = "lo";
else
    side = extractSide(how);
    edge = edgeOf(lo, hi, side);
    switch opts.To
        case "selection"
            switch side
                case "lo",  t = min(lo);
                case "hi",  t = max(hi);
                otherwise,  t = (min(lo) + max(hi)) / 2;
            end
        case "first"
            t = edge(1);
        otherwise
            t = edgeOf(page(1), page(2), side);
    end
    want = repmat(t, numel(which), 1);
end
[rects, err] = solve(rects, which, a, side, want, M);
info.moved = any(abs(rects - rects0) > 1e-12, 2).';
info.held(which) = abs(err) > M.half(a);
end


function side = extractSide(how)
%extractSide  The edge HOW lines up: "lo" (left, bottom), "mid" (center, middle) or "hi" (right, top).
switch how
    case {"left" "bottom"}, side = "lo";
    case {"right" "top"},   side = "hi";
    otherwise,              side = "mid";
end
end


function e = edgeOf(lo, hi, side)
%edgeOf  The edge SIDE ("lo", "mid", "hi") of extents [LO HI].
switch side
    case "lo",  e = lo;
    case "hi",  e = hi;
    otherwise,  e = (lo + hi) / 2;
end
end


function [want, groups, room, d] = spacing(lo, hi, a, to, gap, page)
%spacing  Where each panel's low edge goes for equal gaps (WANT, a column; [] when nothing is to be done), the groups spaced, whether they fit, the gap D.
%   The panels whose extents [LO HI] along the axis overlap by more than a
%   hair are a group (a column or row) moving as one. A = 2 (up the page):
%   the first in reading order is the topmost, so the axis is flipped for
%   the arithmetic (and back).
want = [];
room = true;
d = NaN;
first = 1;   % (the first of WHICH)
if a == 2   % flipped: "low" is the top
    [lo, hi] = deal(1 - hi, 1 - lo);
    page = 1 - flip(page);
end
[g, glo, ghi] = groupsOf(lo, hi);
groups = numel(glo);
w = ghi - glo;
switch true
    case isempty(gap) && to == "page"
        if groups < 2; return; end
        d = (page(2) - page(1) - sum(w)) / (groups - 1);
        if d < 0; room = false; d = NaN; return; end
        start = page(1);
    case isempty(gap)
        if groups < 3; return; end
        d = (ghi(end) - glo(1) - sum(w)) / (groups - 1);
        start = glo(1);
    otherwise
        if groups < 2 && to ~= "page"; return; end
        d = gap;
        total = sum(w) + d * (groups - 1);
        switch to
            case "page"
                if total > page(2) - page(1) + 1e-9; room = false; d = NaN; return; end
                start = (page(1) + page(2) - total) / 2;
            case "first"
                f = g(first);   % the first panel's group stays put
                start = glo(f) - sum(w(1:f-1)) - d * (f - 1);
            otherwise
                start = glo(1);
        end
end
pos = start + [0; cumsum(w(1:end-1) + d)];   % each group's low edge
want = lo + pos(g) - glo(g);   % each panel keeps its place in its group
if a == 2; want = 1 - (want + (hi - lo)); end   % back: the low (bottom) edge
end


function [g, glo, ghi] = groupsOf(lo, hi)
%groupsOf  The extents [LO HI] merged where they overlap (by more than 1e-6): G each one's group, in order along the axis; GLO, GHI the groups' extents.
[slo, o] = sort(lo);
shi = hi(o);
m = numel(lo);
gs = zeros(m, 1);
glo = zeros(0, 1);
ghi = zeros(0, 1);
for i = 1:m
    if i > 1 && slo(i) < ghi(end) - 1e-6
        ghi(end) = max(ghi(end), shi(i));
    else
        glo(end+1, 1) = slo(i); %#ok<AGROW>
        ghi(end+1, 1) = shi(i); %#ok<AGROW>
    end
    gs(i) = numel(glo);
end
g = zeros(m, 1);
g(o) = gs;
end


function [rects, err] = solve(rects, which, a, side, want, M)
%solve  The rects of WHICH moved along axis A until their feature's edge SIDE is at WANT (a column), as far as each can go; ERR what is left.
%   One panel at a time, in the order of WHICH, each moved by what its
%   edge misses with the others where they are now, the figure laid out
%   again after each move (features); sweeps until every edge is there
%   (or six sweeps). An edge that followed its rect only part of the way
%   was either held (its labels keep its plot area off the page's edge or
%   a neighbor: placed with its rect moved only as far as its edge went,
%   the edge is where it got to) or gives way to a neighbor bit by bit
%   (it is not: the next sweep goes on from there). A held panel keeps
%   its rect where its edge stopped, so its plot area is not squeezed,
%   and moves no more; so does one at the page's edge (a rect stays on
%   the page). Boxes (no layout) line up in one sweep.
m = numel(which);
free = true(m, 1);
err = want - edgeAt(features(rects, M));
for sweep = 1:6
    moved = false;
    for i = 1:m
        if ~free(i) || abs(err(i)) <= M.tol(a); continue; end
        q = which(i);
        r0 = rects(q, a);
        r1 = min(max(r0 + err(i), 0), 1 - rects(q, a + 2));
        if abs(r1 - r0) <= M.tol(a)   % at the page's edge already
            free(i) = false;
            continue
        end
        rects(q, a) = r1;
        e = want - edgeAt(features(rects, M));
        df = err(i) - e(i);   % how far its edge followed
        if M.laid && abs(df - (r1 - r0)) > M.tol(a)
            rt = rects;
            rt(q, a) = r0 + df;
            et = want - edgeAt(features(rt, M));
            if abs(et(i) - e(i)) <= M.tol(a)   % moved only as far as its edge went, the edge is where it got to: held
                rects = rt;
                e = et;
                free(i) = false;
            end
        end
        err = e;
        moved = true;
    end
    if ~M.laid || ~moved; break; end   % (boxes: one sweep is exact)
end

    function e = edgeAt(F)
        e = edgeOf(F(which, a), F(which, a) + F(which, a + 2), side);
    end
end


function M = model(L, feature, n)
%model  How a panel's feature follows its rect: the boxes themselves, or the layout worked out again (figurePlace) from L's measures.
M = struct('feature', feature, 'laid', false, 'A', [], 'cells', [], 'how', {{}}, 'bounds', [0 1; 0 1], ...
    'tol', [1e-9 1e-9], 'half', [1e-6 1e-6]);
if feature == "box" && ~isstruct(L); return; end
if ~(isstruct(L) && all(isfield(L, {'size' 'top' 'margin' 'scale' 'how' 'cells'})) && numel(L.cells) == n)
    if feature == "box"; return; end
    error('figureAlign:layout', 'Feature "%s" needs Layout: the figure''s layout as drawn, with a cell per rect.', feature);
end
A = figureArea(double(reshape(L.size, 1, 2)), Top=L.top, Margin=L.margin, Scale=L.scale);
pg = A.page;
px = 1 ./ pg(3:4);   % a pixel, 0-1 of the page
M.A = A;
M.cells = L.cells;
M.how = L.how;
M.tol = px / 4;
M.half = px / 2;
if feature == "box"; return; end
M.laid = true;
ar = A.area;
if feature == "labels"   % (the layout keeps its padding between the labels and the area's edge)
    i = find(strcmpi(string(L.how(1:2:end)), "Padding"), 1);
    if ~isempty(i)
        pad = double(L.how{2 * i});
        ar = [ar(1:2) + pad, max(ar(3:4) - 2 * pad, 1)];
    end
end
M.bounds = [(ar(1) - pg(1)) / pg(3), (ar(1) + ar(3) - pg(1)) / pg(3); ...
    (ar(2) - pg(2)) / pg(4), (ar(2) + ar(4) - pg(2)) / pg(4)];
end


function F = features(rects, M)
%features  Each panel's feature box, 0-1 of the page: its rect, or its plot area (with its labels) as figurePlace places it at RECTS.
if ~M.laid
    F = rects;
    return
end
C = M.cells;
for k = 1:numel(C); C(k).rect = rects(k, :); end
L = figurePlace(M.A, C, M.how{:});
pg = M.A.page;
F = zeros(size(rects));
for k = 1:numel(C)
    b = L.panels(k).box;
    e = [b(1:2), b(1:2) + b(3:4)];
    if M.feature == "labels"
        in = reshape(double(C(k).inset), 1, 4);
        e = [e(1:2) - in(1:2), e(3:4) + in(3:4)];
        q = L.panels(k).band;
        if ~isempty(q); e = [min(e(1:2), q(1:2)), max(e(3:4), q(1:2) + q(3:4))]; end
    end
    F(k, :) = [(e(1:2) - pg(1:2)) ./ pg(3:4), (e(3:4) - e(1:2)) ./ pg(3:4)];
end
end
