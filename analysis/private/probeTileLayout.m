function L = probeTileLayout(PF, popts)
%probeTileLayout  Where a probe figure's tiles go on the page: each unit's (or channel's) tile at its site, in normalized units (pure).
%   L = probeTileLayout(PF, POPTS) lays out the tiles of a probe figure
%   (figureProbeCompute's PF; only PF.tiles' x, y, shank, channel and
%   PF.sites' x, y, shank, included are read) as POPTS says (SPEC.probe:
%   layout, overlap, lanes, tileWidth, tileHeight, tileScale; a field it
%   lacks is the default, probeOptions). Everything is in normalized page
%   units, 0-1 across and up the drawing area, x and y scaled apart (a
%   probe is tall and thin: its µm aspect is never kept). Deterministic.
%
%   Columns  probeColumns over the included sites' x and shank (the
%            physical shanks whatever kcoords says); a tile's column is the
%            one its x falls in, else the nearest. With no included site
%            the tiles' own positions stand for the sites. Each column is a
%            band; its body (the pale shank renderProbeFigure draws) is
%            the middle quarter of the band, and an anchor's x is its
%            site's x across the body (the column's x extent over 80 % of
%            the body's width; the middle when the column has one x).
%   Pitch    the median step between the sorted distinct y values of
%            each column's included sites (pooled over the columns).
%   "schematic" (default)  equal bands, 1 / nCols wide. The tiles' and
%            included sites' y values, sorted, are clustered into rows: a
%            new row where the gap to the previous value exceeds half the
%            pitch (1 µm when the pitch is 0). Rows are equally spaced,
%            1 / nRows high, the lowest y at the bottom; a row's um is the
%            mean of its distinct values. A tile is tileHeight of its row
%            high, centered on it (its anchor's y); the m tiles of one row
%            and column share the band side by side in probe order (PF
%            order): each slot 1 / m of the band, a tile tileWidth of its
%            slot wide. Nothing overlaps; no tile is moved (no leaders).
%   "physical"  y linear in µm over the included sites' and the tiles'
%            range, padded by half a tile at each end; a tile is
%            tileHeight * tileScale * pitch µm high (a quarter of the y
%            range when the pitch is 0, 1 µm without a range; at most the
%            page). Band centers in proportion to the columns' µm centers,
%            each band as wide as the narrowest gap between centers allows;
%            when that is under half of 1 / nCols (a probe narrower than
%            its tiles) the bands spread evenly. The tiles of a column at
%            one y (two units on a site, or sites level with each other)
%            are a group: side by side in the band (or lane), as in a
%            schematic cell. Then POPTS.overlap, per column, on the groups
%            sorted by y:
%     "nudge"   (default) pushed apart to at least a tile's height, keeping
%               their order: a forward pass from the bottom (the first at
%               least half a tile above 0), the last clamped half a tile
%               under 1, then a backward pass. More than fit (m tiles
%               higher than the page) spread evenly from bottom to top,
%               overlapping.
%     "lanes"   group i of the column goes to lane mod(i - 1, lanes) + 1,
%               each lane 1 / lanes of the band, left to right; then nudge
%               within each lane.
%     "shrink"  every tile, w and h alike, times the largest factor <= 1
%               for which no two groups of a column overlap (the smallest
%               gap between neighbouring groups over a tile's height);
%               tiles stay centered on their anchors.
%     "allow"   drawn where they fall, centered on their anchors.
%   A tile is moved (L.moved) when its center is off its anchor's y, or
%   off its column's center line (a lane, a group's side-by-side slot), by
%   more than 1e-6.
%   A tile without a finite x and y has a NaN box and anchor and takes no
%   part in rows, columns or overlaps; when no tile has one, nothing else
%   is laid out (nCols and nRows 0). No tile at all: L.n 0, the fields
%   empty, nRows 0, yRange [NaN NaN].
%
%   L fields
%     n          numel(PF.tiles)
%     box        n x 4: each tile's [x y w h], bottom-left origin
%     anchor     n x 2: the tile's site
%     moved      n x 1: off its anchor (renderProbeFigure draws a leader)
%     col, row   n x 1: the tile's column, its schematic row (0: none)
%     cols       struct, one entry per column in each field: lo, hi,
%                center (the band, x), shank (kcoords, probeColumns), n
%                (included sites), yLo, yHi (the body's extent: its sites
%                half a row or half a pitch beyond, within 0-1), bodyLo,
%                bodyHi (the body's x)
%     rows       schematic: struct with y (row centers), um (µm), n
%                (tiles), one entry per row in each field; physical: those
%                fields empty
%     nRows      schematic: the rows; physical: the tiles that fit up the
%                page, round(1 / h)
%     nCols      the columns
%     depthTicks struct y, label (µm as text): schematic every row
%                (thinned to every k-th for at most 12), physical about 6
%                round numbers over the range
%     shrink     the factor "shrink" applied (1 otherwise)
%     yRange     [lo hi] µm the page spans
%     sites      struct x, y, included (one row per PF.sites row): each
%                site's place, NaN where it is not drawn (outside every
%                column by more than 15 µm, or off the page)
%
%   See also renderProbeFigure, probeColumns, figureProbeCompute.

arguments
    PF (1,1) struct
    popts = struct()
end
o = probeOptions(popts);
[tx, ty] = tilePositions(PF);
n = numel(tx);
[sx, sy, sk, inc] = siteFields(PF);
L = emptyLayout(n, numel(sx));
L.sites.included = inc;
if n == 0
    L.sites = struct('x', zeros(0, 1), 'y', zeros(0, 1), 'included', false(0, 1));
    return
end
okT = isfinite(tx) & isfinite(ty);
if ~any(okT); return; end

% the reference sites: the included ones, else the tiles' positions
ref = inc & isfinite(sx) & isfinite(sy);
if any(ref)
    rx = sx(ref); ry = sy(ref); rk = sk(ref);
else
    rx = tx(okT); ry = ty(okT); rk = tileShanks(PF, okT);
end
[rcol, C, tc] = probeColumns(rx, rk, tx);
tc(~okT) = 0;
nC = numel(C.center);
L.nCols = nC;
L.col = tc;

steps = zeros(0, 1);
for c = 1:nC
    steps = [steps; diff(unique(ry(rcol == c)))]; %#ok<AGROW>
end
steps = steps(steps > 1e-6);
pitch = 0;
if ~isempty(steps); pitch = median(steps); end

physical = string(o.layout) == "physical";
% the bands
if ~physical || nC == 1
    bw = 1 / nC;
    ctr = ((1:nC) - 0.5) / nC;
else
    cu = C.center;
    S = cu(end) - cu(1);
    g = min(diff(cu));
    bw = g / (S + g);
    if ~(S > 0) || bw < 0.5 / nC
        bw = 1 / nC;
        ctr = ((1:nC) - 0.5) / nC;
    else
        ctr = bw / 2 + (cu - cu(1)) / S * (1 - bw);
    end
end
body = bw / 4;
L.cols = struct('lo', ctr - bw / 2, 'hi', ctr + bw / 2, 'center', ctr, 'shank', C.shank, 'n', C.n, ...
    'yLo', zeros(1, nC), 'yHi', zeros(1, nC), 'bodyLo', ctr - body / 2, 'bodyHi', ctr + body / 2);
acrossX = @(x, c) ctr(c) + acrossBody(x, C.lo(c), C.hi(c)) * 0.8 * body;

% every site's column (drawn only near a column)
scol = zeros(numel(sx), 1);
if ~isempty(sx)
    [~, ~, scol] = probeColumns(rx, rk, sx);
    for i = 1:numel(sx)
        c = scol(i);
        if c == 0 || ~isfinite(sy(i)) || max(C.lo(c) - sx(i), 0) + max(sx(i) - C.hi(c), 0) > 15; scol(i) = 0; end
    end
end
for i = find(scol > 0).'
    L.sites.x(i) = acrossX(sx(i), scol(i));
end
for i = find(okT).'
    L.anchor(i, 1) = acrossX(tx(i), tc(i));
end

tw = double(o.tileWidth);
th = double(o.tileHeight);
if physical
    L = physicalLayout(L, o, tx, ty, okT, tc, rx, ry, rcol, sy, scol, pitch, bw, tw, th);
else
    L = schematicLayout(L, tx, ty, okT, tc, ry, rcol, sy, scol, pitch, bw, tw, th);
end
end


function L = schematicLayout(L, ~, ty, okT, tc, ry, rcol, sy, scol, pitch, bw, tw, th)
%schematicLayout  Rows of sites: the tiles' and sites' y clustered, rows equally spaced, a row's tiles side by side in its band.
tol = pitch / 2;
if pitch == 0; tol = 1; end
v = sort([ty(okT); ry]);
id = cumsum([1; diff(v) > tol]);
nR = id(end);
um = zeros(1, nR);
for r = 1:nR
    um(r) = mean(unique(v(id == r)));
end
rowY = ((1:nR) - 0.5) / nR;
rowOf = @(y) id(nearestIndex(v, y));
L.nRows = nR;
L.yRange = [v(1) v(end)];
h = th / nR;
rt = zeros(numel(ty), 1);
for i = find(okT).'
    rt(i) = rowOf(ty(i));
    L.anchor(i, 2) = rowY(rt(i));
end
L.row = rt;
cntR = zeros(1, nR);
for c = 1:numel(L.cols.center)
    for r = 1:nR
        on = find(okT & tc == c & rt == r);
        m = numel(on);
        cntR(r) = cntR(r) + m;
        if m == 0; continue; end
        slot = bw / m;
        w = tw * slot;
        for j = 1:m
            cx = L.cols.lo(c) + (j - 0.5) * slot;
            L.box(on(j), :) = [cx - w / 2, rowY(r) - h / 2, w, h];
        end
    end
end
L.rows = struct('y', rowY, 'um', um, 'n', cntR);
% the sites: their row (an excluded site between rows: in proportion between their µm)
for i = find(scol > 0).'
    [d, k] = min(abs(v - sy(i)));
    if d <= tol
        L.sites.y(i) = rowY(id(k));
    elseif nR > 1 && sy(i) > um(1) && sy(i) < um(end)
        L.sites.y(i) = interp1(um, rowY, sy(i));
    else
        L.sites.x(i) = NaN;
    end
end
% the bodies: each column's sites (and tiles) half a row beyond
for c = 1:numel(L.cols.center)
    rr = [arrayfun(rowOf, ry(rcol == c)); rt(okT & tc == c)];
    if isempty(rr); rr = 1; end
    L.cols.yLo(c) = (min(rr) - 1) / nR;
    L.cols.yHi(c) = max(rr) / nR;
end
k = 1:nR;
if nR > 12; k = 1:ceil(nR / 12):nR; end
L.depthTicks = struct('y', rowY(k), 'label', compose("%g", round(um(k))));
end


function L = physicalLayout(L, o, ~, ty, okT, tc, ~, ry, rcol, sy, scol, pitch, bw, tw, th)
%physicalLayout  y in µm, tiles a pitch high, groups of one y side by side, then the overlap strategy.
yAll = [ry; ty(okT)];
span0 = max(yAll) - min(yAll);
p = pitch;
if p == 0
    p = span0 / 4;
    if p == 0; p = 1; end
end
hu = th * double(o.tileScale) * p;
lo = min(yAll) - hu / 2;
hi = max(yAll) + hu / 2;
span = hi - lo;
yn = @(y) (y - lo) / span;
h = min(1, hu / span);
L.yRange = [lo hi];
L.nRows = max(1, round(1 / h));
L.anchor(okT, 2) = yn(ty(okT));
mode = string(o.overlap);
nl = 1;
if mode == "lanes"; nl = max(1, round(double(o.lanes))); end
nC = numel(L.cols.center);
% each column's groups (tiles at one y), sorted by y; their lane
G = cell(1, nC);   % per column: struct of tiles (cell), y, lane
for c = 1:nC
    on = find(okT & tc == c);
    [ys, s] = sortrows([L.anchor(on, 2) on]);
    ys = ys(:, 1);
    on = on(s);
    gid = cumsum([1; diff(ys) > 1e-9]);
    ng = numel(unique(gid(1:numel(on))));
    g = struct('tiles', {cell(1, ng)}, 'y', zeros(1, ng), 'lane', zeros(1, ng));
    for j = 1:ng
        g.tiles{j} = on(gid == j);
        g.y(j) = ys(find(gid == j, 1));
        g.lane(j) = mod(j - 1, nl) + 1;
    end
    G{c} = g;
end
f = 1;
if mode == "shrink"
    for c = 1:nC
        d = diff(G{c}.y);
        if ~isempty(d); f = min(f, min(d) / h); end
    end
end
L.shrink = f;
hh = h * f;
for c = 1:nC
    g = G{c};
    cy = g.y;
    if ismember(mode, ["nudge" "lanes"])
        for ln = 1:nl
            k = find(g.lane == ln);
            cy(k) = nudge(cy(k), hh);
        end
    end
    laneW = bw / nl;
    for j = 1:numel(g.y)
        on = g.tiles{j};
        m = numel(on);
        slot = laneW / m;
        w = tw * slot * f;
        x0 = L.cols.lo(c) + (g.lane(j) - 1) * laneW;
        for q = 1:m
            cx = x0 + (q - 0.5) * slot;
            L.box(on(q), :) = [cx - w / 2, cy(j) - hh / 2, w, hh];
            L.moved(on(q)) = abs(cy(j) - g.y(j)) > 1e-6 || abs(cx - L.cols.center(c)) > 1e-6;
        end
    end
end
% the sites, the bodies (half a pitch beyond their sites), the depth ticks
for i = find(scol > 0).'
    y = yn(sy(i));
    if y < 0 || y > 1; L.sites.x(i) = NaN; continue; end
    L.sites.y(i) = y;
end
for c = 1:nC
    ys = ry(rcol == c);
    if isempty(ys); ys = ty(okT & tc == c); end
    L.cols.yLo(c) = max(0, yn(min(ys)) - p / 2 / span);
    L.cols.yHi(c) = min(1, yn(max(ys)) + p / 2 / span);
end
t = roundTicks(lo, hi, 6);
L.depthTicks = struct('y', yn(t), 'label', compose("%g", t));
end


function c = nudge(c, h)
%nudge  Centers C (ascending) pushed apart to at least H, in order, inside [H/2, 1 - H/2]; more than fit: spread evenly.
m = numel(c);
if m == 0; return; end
if m * h > 1 + 1e-12
    if m == 1
        c = 0.5;
    else
        c = linspace(h / 2, 1 - h / 2, m);
    end
    return
end
c(1) = max(c(1), h / 2);
for i = 2:m
    c(i) = max(c(i), c(i - 1) + h);
end
c(m) = min(c(m), 1 - h / 2);
for i = m - 1:-1:1
    c(i) = min(c(i), c(i + 1) - h);
end
end


function t = roundTicks(lo, hi, n)
%roundTicks  About N round numbers (1, 2, 2.5, 5 x 10^k apart) from LO to HI.
span = hi - lo;
t = zeros(1, 0);
if ~(span > 0); return; end
for e = floor(log10(span / n)) + (0:2)
    for m = [1 2 2.5 5]
        s = m * 10^e;
        v = (ceil(lo / s - 1e-9):floor(hi / s + 1e-9)) * s;
        if numel(v) <= n
            t = v;
            return
        end
    end
end
end


function a = acrossBody(x, lo, hi)
%acrossBody  Where X sits across a column whose sites' x run from LO to HI: -0.5 to 0.5 (0 when the column has one x).
a = 0;
if hi - lo > 1e-9; a = min(max((x - (lo + hi) / 2) / (hi - lo), -0.5), 0.5); end
end


function i = nearestIndex(v, y)
%nearestIndex  The index of the value of V nearest Y (the first of equals).
[~, i] = min(abs(v - y));
end


function [x, y] = tilePositions(PF)
%tilePositions  The tiles' x and y (µm), NaN where a tile has none.
T = struct('x', {}, 'y', {});
if isfield(PF, 'tiles') && isstruct(PF.tiles); T = PF.tiles; end
n = numel(T);
x = NaN(n, 1);
y = NaN(n, 1);
for i = 1:n
    x(i) = scalarOf(T(i), 'x');
    y(i) = scalarOf(T(i), 'y');
end
end


function k = tileShanks(PF, on)
%tileShanks  The shanks of the tiles ON (0 where a tile has none).
k = zeros(nnz(on), 1);
idx = find(on);
for j = 1:numel(idx)
    v = scalarOf(PF.tiles(idx(j)), 'shank');
    if isfinite(v); k(j) = v; end
end
end


function v = scalarOf(s, f)
%scalarOf  Field F of S as one double, NaN when it is missing, empty or not numeric.
v = NaN;
if isfield(s, f) && (isnumeric(s.(f)) || islogical(s.(f))) && ~isempty(s.(f)); v = double(s.(f)(1)); end
end


function [x, y, k, inc] = siteFields(PF)
%siteFields  PF.sites' x, y, shank and included as columns (none without a sites table).
x = zeros(0, 1); y = x; k = x; inc = false(0, 1);
if ~isfield(PF, 'sites') || ~istable(PF.sites) || height(PF.sites) == 0; return; end
S = PF.sites;
names = string(S.Properties.VariableNames);
m = height(S);
col = @(f, d) colOf(S, names, f, d, m);
x = col("x", NaN);
y = col("y", NaN);
k = col("shank", 0);
inc = logical(col("included", 1));
end


function v = colOf(S, names, f, d, m)
%colOf  Column F of table S as a double column, D everywhere when it has none.
if ismember(f, names)
    v = double(S.(f));
    v = v(:);
else
    v = repmat(d, m, 1);
end
end


function L = emptyLayout(n, nSites)
%emptyLayout  The layout of N tiles placed nowhere (NaN boxes), on no column or row.
L = struct();
L.n = n;
L.box = NaN(n, 4);
L.anchor = NaN(n, 2);
L.moved = false(n, 1);
L.col = zeros(n, 1);
L.row = zeros(n, 1);
L.cols = struct('lo', zeros(1, 0), 'hi', zeros(1, 0), 'center', zeros(1, 0), 'shank', zeros(1, 0), 'n', zeros(1, 0), ...
    'yLo', zeros(1, 0), 'yHi', zeros(1, 0), 'bodyLo', zeros(1, 0), 'bodyHi', zeros(1, 0));
L.rows = struct('y', zeros(1, 0), 'um', zeros(1, 0), 'n', zeros(1, 0));
L.nRows = 0;
L.nCols = 0;
L.depthTicks = struct('y', zeros(1, 0), 'label', strings(1, 0));
L.shrink = 1;
L.yRange = [NaN NaN];
L.sites = struct('x', NaN(nSites, 1), 'y', NaN(nSites, 1), 'included', false(nSites, 1));
end
