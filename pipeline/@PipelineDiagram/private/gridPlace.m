function [N, E, W, H] = gridPlace(N, E, opts)
%gridPlace  Size the boxes, put them on the grid and route the arrows.
%   [N, E, W, H] = gridPlace(N, E) lays out the nodes N and the edges E of a
%   grid diagram (PipelineDiagram.overview, PipelineDiagram.manifest) and
%   returns them with their geometry, and the drawing's width and height.
%   Nodes sit on the grid by row and col, on five columns, a row as tall as
%   its tallest box; the arrows run at right angles through the gaps
%   between rows and columns. gridPlace(N, E, ColW=W) sets the boxes' width.
%   A node may carry a drawn body (body, its SVG, and bodyH, its height) under
%   its lines; see gridNodeSVG.
%
%   gridPlace(N, E, Direction="horizontal") lays it out from left to right: a
%   row of the grid becomes a column, a column a row as tall as its tallest box
%   (the files still hang under their box), and each arrow leaves the right of
%   its source (the last file hung under it, or the box) and enters the left of
%   its target's box. The routing is the same: it works in a frame along the
%   flow (y) and across it (x), and the axes are flipped at the end.
arguments
    N
    E
    opts.ColW (1,1) double = 206
    opts.Direction (1,1) string {mustBeMember(opts.Direction, ["vertical" "horizontal"])} = "vertical"
end
horizontal = opts.Direction == "horizontal";
L = geometry();
L.colW = opts.ColW;
L.pillFlush = horizontal;
for k = 1:numel(N)
    N(k) = sizeNode(N(k), L);
end
ids = [N.id];
at = @(id) find(ids == id, 1);
if horizontal   % room on a box's left for the arrows it takes
    for t = reshape(unique([E.to], "stable"), 1, [])
        k = at(t);
        grow = max(0, L.portGap * (nnz([E.to] == t) + 1) - N(k).boxH);
        N(k).boxH = N(k).boxH + grow;
        N(k).h = N(k).h + grow;
    end
end
if horizontal
    along = [N.w]; across = [N.h];
else
    along = [N.h]; across = [N.w];
end
colSize = zeros(1, 5);
for c = 0:4
    colSize(c + 1) = max([across([N.col] == c), 0]);
end
if ~horizontal; colSize(:) = L.colW; end   % every column as wide, used or not
L.colX = L.margin + [0, cumsum(colSize(1:end-1) + L.gapX)];
L.colSize = colSize;
nRows = max([N.row]) + 1;
rowH = zeros(1, nRows);
for r = 0:nRows - 1
    rowH(r + 1) = max(along([N.row] == r));
end

% The tracks of each gap between rows: one per source leaving the row above
% ("x:<id>") and one per arrow reaching the row below through a lane
% ("a:<to>:<from>": a target such as Copy outputs takes several).
from = arrayfun(@(e) N(at(e.from)).row, E);
to = arrayfun(@(e) N(at(e.to)).row, E);
viaLane = to > from + 1 & ~isnan([E.lane]);
nets = cell(1, nRows - 1);
for g = 0:nRows - 2
    lanes = viaLane & to == g + 1;
    nets{g + 1} = [reshape("x:" + unique([E(from == g).from], "stable"), 1, []), ...
        reshape("a:" + [E(lanes).to] + ":" + [E(lanes).from], 1, [])];
end
gapH = cellfun(@(c) max(L.gapMin, L.track * (numel(c) + 1)), nets);
rowY = L.top + [0, cumsum(rowH(1:end-1) + gapH)];
% The boxes in the frame: x across the flow, y along it.
F = struct('id', {N.id}, 'row', {N.row}, 'x', 0, 'y', 0, 'w', 0, 'h', 0, 'exit', 0, 'ports', 0);
for k = 1:numel(N)
    x = L.colX(N(k).col + 1);
    F(k).x = x;
    F(k).y = rowY(N(k).row + 1);
    F(k).w = across(k);
    F(k).h = along(k);
    F(k).exit = x + across(k) / 2;
    F(k).ports = across(k);
    if horizontal
        F(k).exit = x + exitOffset(N(k), L);
        F(k).ports = N(k).boxH;
    end
end
% Ports: the arrows into a box spread over its side, in the list's order.
for t = reshape(unique([E.to], "stable"), 1, [])
    k = find([E.to] == t);
    n = F(at(t));
    for j = 1:numel(k)
        E(k(j)).portX = n.x + n.ports * j / (numel(k) + 1);
    end
end
gapTop = rowY(1:end-1) + rowH(1:end-1);

% Order each gap's tracks to cross (and never overlap) as little as they
% can: every order of one gap at a time, the current one kept on a tie. A
% gap of more than five tracks (the arrows converging on Copy outputs) is
% ordered by the length of each track's run instead, the shortest on top:
% arrows converging on one box then nest without crossing.
route = @(order) routeAll(F, E, at, from, viaLane, order, gapTop, L);
order = nets;
for g = find(cellfun(@numel, nets) > 5)
    order{g} = byRun(nets{g}, F, E, at, viaLane, L);
end
best = score(route(order));
for pass = 1:2
    for g = 1:numel(order)
        cur = order{g};
        if numel(cur) > 5; continue; end
        P = perms(1:numel(cur));
        for p = 1:size(P, 1)
            trial = order;
            trial{g} = cur(P(p, :));
            s = score(route(trial));
            if s < best
                best = s;
                order = trial;
            end
        end
    end
end
E = route(order);
W = 2 * L.margin + sum(colSize) + 4 * L.gapX;
H = rowY(end) + rowH(end) + L.bottom;
for k = 1:numel(N)
    if horizontal
        N(k) = moveNode(N(k), F(k).y, F(k).x, L);
    else
        N(k) = moveNode(N(k), F(k).x, F(k).y, L);
    end
end
if horizontal
    for k = 1:numel(E)
        E(k).points = fliplr(E(k).points);
    end
    [W, H] = deal(H, W);
end
end


function d = exitOffset(n, L)
%exitOffset  How far below a box's top its arrows leave, left to right: at the
%   middle of the last file hung under it, or of the box.
d = n.boxH / 2;
if isempty(n.outs); return; end
d = n.boxH + L.wireGap;
for j = 1:numel(n.outs) - 1
    d = d + n.outs(j).h + L.pillGap;
end
d = d + n.outs(end).h / 2;
end


function nets = byRun(nets, F, E, at, viaLane, L)
%byRun  A gap's tracks, shortest run across first: a source's from its
%   center to the farthest port it reaches, a lane's from the lane to its port.
run = zeros(size(nets));
for k = 1:numel(nets)
    p = split(extractAfter(nets(k), 2), ":");
    if startsWith(nets(k), "x:")
        s = F(at(p(1)));
        mine = find([E.from] == p(1));
        ends = [E(mine).portX];   % across to its port, or to the lane it goes down
        lane = viaLane(mine);
        ends(lane) = arrayfun(@(e) laneX(L, e.lane), E(mine(lane)));
        if ~isempty(ends); run(k) = max(abs(ends - s.exit)); end
    else
        e = E([E.to] == p(1) & [E.from] == p(2));
        run(k) = abs(e(1).portX - laneX(L, e(1).lane));
    end
end
[~, i] = sort(run);
nets = nets(i);
end


function n = sizeNode(n, L)
%sizeNode  Wrap the text to the box width and size the box and its files.
n.w = L.colW;
bw = 0;
if n.badge ~= ""; bw = gridTextWidth(n.badge, 10) + 12; end
n.title = gridFit(n.title, n.w - 22 - bw - 6, 12.5 * 1.07);
n.lines = gridWrap(n.lines, n.w - 22, 11);
n.boxH = 27 + 14 * numel(n.lines);
if isfield(n, 'bodyH'); n.boxH = n.boxH + n.bodyH; end
n.h = n.boxH;
for j = 1:numel(n.outs)
    p = n.outs(j);
    p.w = n.w - 2 * L.pillInset;
    p.title = gridFit(p.title, p.w - 18, 11.5 * 1.07);
    p.lines = gridWrap(p.lines, p.w - 18, 10.5);
    p.h = 21 + 13 * numel(p.lines);
    if isempty(p.dim); p.dim = n.dim; end
    gap = L.pillGap;
    if j == 1; gap = L.wireGap; end
    n.h = n.h + gap + p.h;
    n.outs(j) = p;
end
end


function n = moveNode(n, x, y, L)
n.x = x;
n.y = y;
py = y + n.boxH + L.wireGap;
for j = 1:numel(n.outs)
    n.outs(j).x = x + L.pillInset;
    if L.pillFlush; n.outs(j).x = x + n.w - n.outs(j).w; end   % its right edge where the arrows leave
    n.outs(j).y = py;
    py = py + n.outs(j).h + L.pillGap;
end
end


function E = routeAll(F, E, at, from, viaLane, order, gapTop, L)
%routeAll  Every arrow's polyline under one order of the gaps' tracks:
%   down from the bottom of its source (or the file it leaves from) to its
%   source's track, across, and down onto its port -- or, through a lane,
%   across to the lane, down it to its target's track, across and down.
trackY = @(net, g) gapTop(g + 1) + L.track * find(order{g + 1} == net, 1);
for k = 1:numel(E)
    s = F(at(E(k).from));
    t = F(at(E(k).to));
    sx = s.exit;
    yx = trackY("x:" + s.id, from(k));
    px = E(k).portX;
    if viaLane(k)
        lx = laneX(L, E(k).lane);
        ya = trackY("a:" + t.id + ":" + s.id, t.row - 1);
        pts = [sx, s.y + s.h; sx, yx; lx, yx; lx, ya; px, ya; px, t.y];
    else
        pts = [sx, s.y + s.h; sx, yx; px, yx; px, t.y];
    end
    E(k).points = simplify(pts);
end
end


function p = simplify(p)
%simplify  Drop repeated points and the middle of straight runs.
keep = [true; any(abs(diff(p)) > 1e-6, 2)];
p = p(keep, :);
k = 2;
while k < size(p, 1)
    a = p(k, :) - p(k - 1, :);
    b = p(k + 1, :) - p(k, :);
    if abs(a(1) * b(2) - a(2) * b(1)) < 1e-6
        p(k, :) = [];
    else
        k = k + 1;
    end
end
end


function s = score(E)
%score  Crossings between arrows from different sources, plus a heavy
%   penalty for each stretch two of them would share. A source's arrows
%   share their first stretch, so a crossing is counted once per point.
[h, v] = segments(E);
tol = 0.5;
[i, j] = find(v.x' > h.x1 + tol & v.x' < h.x2 - tol & h.y > v.y1' + tol & h.y < v.y2' - tol & h.src ~= v.src');
at = unique(round([v.x(j), h.y(i), min(h.src(i), v.src(j)), max(h.src(i), v.src(j))]), "rows");
s = size(at, 1) + 100 * (overlaps(h.y, h.x1, h.x2, h.src) + overlaps(v.x, v.y1, v.y2, v.src));
end


function n = overlaps(at, lo, hi, src)
%overlaps  Pairs of collinear segments from different sources sharing a stretch.
M = abs(at - at') < 0.5 & min(hi, hi') - max(lo, lo') > 0.5 & src ~= src';
n = nnz(triu(M, 1));
end


function [h, v] = segments(E)
%segments  The horizontal and vertical pieces of every arrow, each with
%   its source (as a number) and its end points in increasing order.
H = zeros(0, 4); V = zeros(0, 4);
srcs = unique([E.from]);
for k = 1:numel(E)
    p = E(k).points;
    id = find(srcs == E(k).from);
    for j = 1:size(p, 1) - 1
        a = p(j, :); b = p(j + 1, :);
        if abs(a(2) - b(2)) < 1e-6
            H(end+1, :) = [a(2), min(a(1), b(1)), max(a(1), b(1)), id]; %#ok<AGROW>
        else
            V(end+1, :) = [a(1), min(a(2), b(2)), max(a(2), b(2)), id]; %#ok<AGROW>
        end
    end
end
h = struct('y', H(:, 1), 'x1', H(:, 2), 'x2', H(:, 3), 'src', H(:, 4));
v = struct('x', V(:, 1), 'y1', V(:, 2), 'y2', V(:, 3), 'src', V(:, 4));
end


function L = geometry()
L = struct('margin', 16, 'top', 10, 'bottom', 12, 'colW', 206, 'gapX', 34, ...
    'track', 9, 'gapMin', 30, 'wireGap', 16, 'pillGap', 8, 'pillInset', 12, 'portGap', 13, 'pillFlush', false);
end


function x = laneX(L, u)
%laneX  A lane's position across the flow: column u's center, or the middle of
%   the gap after it.
c = floor(u) + 1;
if u == round(u)
    x = L.colX(c) + L.colSize(c) / 2;
else
    x = L.colX(c) + L.colSize(c) + L.gapX / 2;
end
end
