function [col, C, colQ] = probeColumns(x, shank, xq)
%probeColumns  The probe's physical shanks: its sites grouped by x, whatever their kcoords.
%   [COL, C] = probeColumns(X, SHANK) groups the sites at X (um) into
%   columns, left to right: sites further apart in x than a shank's own
%   columns are (max(30 um, 3 times the median x step inside a kcoords
%   group SHANK)) are on different shanks. So a site a Kilosort map parks
%   on a kcoords group of its own, above a shank, is on that shank's column.
%   COL: each site's column (0 where X is not finite). C: struct with one
%   entry per column in each field: lo, hi (its sites' x extent), center,
%   shank (the kcoords group holding most of its sites), n (its sites).
%   [COL, C, COLQ] = probeColumns(X, SHANK, XQ) also gives the column of
%   each point XQ (a unit's position): the one it falls in, else the
%   nearest (0 where XQ is not finite or there is no column).
%
%   See also renderProbeMap, renderWaveforms.

if nargin < 3; xq = zeros(0, 1); end
x = double(x(:));
shank = double(shank(:));
if numel(shank) ~= numel(x); shank = zeros(size(x)); end
ok = isfinite(x);
steps = zeros(0, 1);
for k = unique(shank(ok)).'
    u = unique(x(ok & shank == k));
    steps = [steps; diff(u)]; %#ok<AGROW>
end
steps = steps(steps > 1e-6);
within = 0;
if ~isempty(steps); within = median(steps); end
split = max(30, 3 * within);

ux = unique(x(ok));
edges = [0; find(diff(ux) > split); numel(ux)];
nC = numel(edges) - 1;
C = struct('lo', zeros(1, nC), 'hi', zeros(1, nC), 'center', zeros(1, nC), 'shank', zeros(1, nC), 'n', zeros(1, nC));
col = zeros(numel(x), 1);
for c = 1:nC
    C.lo(c) = ux(edges(c) + 1);
    C.hi(c) = ux(edges(c + 1));
    C.center(c) = (C.lo(c) + C.hi(c)) / 2;
    on = ok & x >= C.lo(c) & x <= C.hi(c);
    col(on) = c;
    C.n(c) = nnz(on);
    C.shank(c) = mode(shank(on));
end

xq = double(xq(:));
colQ = zeros(numel(xq), 1);
if nC == 0; return; end
for i = find(isfinite(xq)).'
    d = max(C.lo - xq(i), 0) + max(xq(i) - C.hi, 0);   % 0 inside a column
    [~, colQ(i)] = min(d);
end
end
