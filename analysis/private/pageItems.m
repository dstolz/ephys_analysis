function [idx, nr, nc] = pageItems(n, page, maxTiles)
%pageItems  The items on one page of a grid, and a near-square grid for them.
%   [IDX, NR, NC] = pageItems(N, PAGE, MAXTILES): items (PAGE-1)*MAXTILES+1 ..
%   PAGE*MAXTILES of 1..N and an NR x NC grid that holds them.
maxTiles = max(1, round(maxTiles));
idx = (page - 1) * maxTiles + (1:maxTiles);
idx = idx(idx <= n);
m = max(1, numel(idx));
nc = ceil(sqrt(m));
nr = ceil(m / nc);
end
