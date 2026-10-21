function [primary, eventId, nCopies, neighbors] = coincidentEvents(idx, amp, pos, radiusUm, jitterSamples)
%coincidentEvents  The copies of one spike that neighboring sites detected.
%   [PRIMARY, EVENTID, NCOPIES, NEIGHBORS] = coincidentEvents(IDX, AMP, POS,
%   RADIUSUM, JITTERSAMPLES) takes each channel's events, IDX {1 x nChan}
%   (sorted sample indices) and AMP {1 x nChan} (the signed amplitude at
%   each, the trough's with Align "trough"), and the channels' sites, POS
%   [nChan x 2] x and y in um (NaN = off the probe, never a neighbor).
%
%   Two events are copies of one spike when their sites lie within
%   RADIUSUM of each other and their samples within JITTERSAMPLES. Going
%   from the largest |amplitude| down (ties: the earlier, then the lower
%   channel), an event no larger one has claimed is a primary, and claims
%   each unclaimed copy of it: non-maximum suppression, so every copy lies
%   within the radius and the jitter of its own primary.
%
%   PRIMARY {1 x nChan} logical per event, EVENTID {1 x nChan} the number
%   of its primary (1, 2, ... in time order) shared by the primary and its
%   copies, NCOPIES [1 x nChan] the events claimed as copies, NEIGHBORS
%   {1 x nChan} the channels within the radius of each, ascending
%   (siteNeighbors).
%
%   See also EphysDataset.detectSpikes, siteNeighbors.

nChan = numel(idx);
[neighbors, nb] = siteNeighbors(pos, radiusUm);

n = cellfun(@numel, idx);
N = sum(n);
chU = repelem((1:nChan).', n(:));
tU = zeros(N, 1);
aU = zeros(N, 1);
if N > 0
    tU = vertcat(idx{:});
    aU = abs(vertcat(amp{:}));
end
[t, ord] = sort(tU);         % stable: within a channel the order is kept
ch = chU(ord);
a = aU(ord);

% Copy pairs: events within the jitter on neighboring sites. At lag k an
% event can pair with the k-th event after it only if it paired in time
% with the (k-1)-th, so the candidates shrink lag by lag.
pairs = {};
act = (1:N-1).';
k = 1;
while ~isempty(act)
    j = act + k;
    in = j <= N;
    act = act(in); j = j(in);
    near = t(j) - t(act) <= jitterSamples;
    act = act(near); j = j(near);
    hit = nb(ch(act) + (ch(j) - 1) * nChan);
    pairs{end+1} = [act(hit) j(hit)]; %#ok<AGROW>
    k = k + 1;
end
P = vertcat(pairs{:});
if isempty(P); P = zeros(0, 2); end

% Rank from the largest |amplitude| down; each pair points from the
% higher-ranked event to the lower.
[~, byRank] = sortrows([-a, t, ch]);
rank = zeros(N, 1);
rank(byRank) = 1:N;
from = P(:, 1);
to = P(:, 2);
swap = rank(to) < rank(from);
[from(swap), to(swap)] = deal(to(swap), from(swap));
[from, o] = sort(from);
to = to(o);
cnt = accumarray(from, 1, [N 1]);
ptr = [0; cumsum(cnt)];

claimed = false(N, 1);
owner = (1:N).';
for e = byRank(cnt(byRank) > 0).'
    if claimed(e); continue; end
    for p = ptr(e)+1:ptr(e+1)
        q = to(p);
        if ~claimed(q)
            claimed(q) = true;
            owner(q) = e;
        end
    end
end
num = cumsum(~claimed);      % primaries numbered in time order
id = num(owner);

primaryU = true(N, 1);
idU = zeros(N, 1);
primaryU(ord) = ~claimed;
idU(ord) = id;
primary = reshape(mat2cell(primaryU, n(:), 1), 1, []);
eventId = reshape(mat2cell(idU, n(:), 1), 1, []);
nCopies = reshape(accumarray(chU, ~primaryU, [nChan 1]), 1, []);
end
