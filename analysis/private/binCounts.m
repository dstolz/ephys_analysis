function [counts, rel, ep] = binCounts(s, t0, edges)
%binCounts  Spike counts in bins around each event, and the raster.
%   [COUNTS, REL, EP] = binCounts(S, T0, EDGES) counts the spike times S (s)
%   in the bins EDGES (s, relative to each event, ascending) around every
%   event T0: COUNTS is [nBins x nEvents]. Bins are half-open [a, b): a
%   spike exactly at T0 + EDGES(end) is not counted. REL are the spike times
%   relative to their event and EP the event of each (column vectors, by
%   event then time; a spike inside two overlapping windows appears
%   twice). One vectorized pass over every (spike, window) pair: work is
%   O(nSpikes + nEvents) plus the spikes inside the windows. An event that
%   is not finite counts nothing.

s = double(s(:));
if ~issorted(s); s = sort(s); end       % spike trains usually come sorted
t0 = double(t0(:));
nE = numel(t0);
nB = numel(edges) - 1;
a = countBelow(s, t0 + edges(1)) + 1;   % first spike at or after each window start
b = countBelow(s, t0 + edges(end));     % last spike before each window end
n = b - a + 1;                          % spikes per window
n(~(n > 0)) = 0;
ep = reshape(repelem((1:nE).', n), [], 1);   % the window of each (spike, window) pair
first = cumsum([0; n(1:end-1)]);        % pairs before each window's
k = (1:sum(n)).' - first(ep) + a(ep) - 1;   % the spike of each pair: a(e) .. b(e)
rel = s(k) - t0(ep);
bin = discretize(rel, edges);           % as histcounts: [a, b), the last bin [a, b]
ok = ~isnan(bin);
counts = reshape(accumarray(bin(ok) + nB * (ep(ok) - 1), 1, [nB * nE 1]), nB, nE);   % [bin, event] as one index
end
