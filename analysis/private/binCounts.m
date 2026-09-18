function [counts, rel, ep] = binCounts(s, t0, edges)
%binCounts  Spike counts in bins around each event, and the raster.
%   [COUNTS, REL, EP] = binCounts(S, T0, EDGES) counts the spike times S (s)
%   in the bins EDGES (s, relative to each event, ascending) around every
%   event T0: COUNTS is [nBins x nEvents]. Bins are half-open [a, b): a
%   spike exactly at T0 + EDGES(end) is not counted. REL are the spike times
%   relative to their event and EP the event of each (column vectors; a
%   spike inside two overlapping windows appears twice). Work is
%   O(nSpikes + nEvents) plus the spikes inside the windows.

s = sort(double(s(:)));
t0 = double(t0(:));
nE = numel(t0);
nB = numel(edges) - 1;
counts = zeros(nB, nE);
a = countBelow(s, t0 + edges(1)) + 1;   % first spike at or after the window start
b = countBelow(s, t0 + edges(end));     % last spike before the window end
wantRaster = nargout > 1;
relc = cell(nE, 1); epc = cell(nE, 1);
for e = 1:nE
    if b(e) < a(e); continue; end
    r = s(a(e):b(e)) - t0(e);
    counts(:, e) = histcounts(r, edges).';
    if wantRaster
        relc{e} = r;
        epc{e} = repmat(e, numel(r), 1);
    end
end
if wantRaster
    rel = vertcat(relc{:}, zeros(0, 1));
    ep = vertcat(epc{:}, zeros(0, 1));
end
end
