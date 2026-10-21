function [neighbors, nb] = siteNeighbors(pos, radiusUm)
%siteNeighbors  Which sites lie within a distance of each other on the probe.
%   [NEIGHBORS, NB] = siteNeighbors(POS, RADIUSUM) takes the sites' [x y]
%   positions in um, POS [n x 2] (NaN = off the probe), and returns
%   NEIGHBORS {1 x n}, the sites within RADIUSUM of each (ascending, the site
%   itself not among them), and NB [n x n] logical, the same as a symmetric
%   matrix. The distance is the true one between the sites' xc / yc,
%   whatever their shank (kcoords); a site off the probe has no neighbors.
%   The rule EphysDataset.detectSpikes' Coincidence uses, and what
%   SpikeNeighborsDialog draws.
%
%   See also EphysDataset.detectSpikes, EphysDataset.channelLayout, SpikeNeighborsDialog.

arguments
    pos (:,2) double
    radiusUm (1,1) double {mustBeNonnegative}
end
n = size(pos, 1);
x = pos(:, 1);
y = pos(:, 2);
nb = hypot(x - x.', y - y.') <= radiusUm * (1 + 1e-9) & ~eye(n);   % NaN is never within
neighbors = cell(1, n);
for k = 1:n
    neighbors{k} = find(nb(k, :));
end
end
