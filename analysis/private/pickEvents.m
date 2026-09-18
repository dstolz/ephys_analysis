function [e, k] = pickEvents(iv, ref, origin, after)
%pickEvents  Apply an event reference to one set of intervals.
%   [E, K] = pickEvents(IV, REF, ORIGIN, AFTER) keeps the [on off] intervals
%   IV whose length lies in [REF.minDurationSec, REF.maxDurationSec] and whose
%   REF.edge time, minus ORIGIN, lies in REF.timeRange; of those, the edges at
%   or after AFTER (default -Inf) are ranked by time and REF.which / REF.n
%   picks among them. E are the picked times plus REF.offsetSec and K their
%   ranks (1-based).

if nargin < 4; after = -Inf; end
e = zeros(0, 1); k = zeros(0, 1);
if isempty(iv); return; end
dur = iv(:, 2) - iv(:, 1);
if ref.edge == "onset"; x = iv(:, 1); else; x = iv(:, 2); end
rel = x - origin;
ok = dur >= ref.minDurationSec & dur <= ref.maxDurationSec ...
    & rel >= ref.timeRange(1) & rel <= ref.timeRange(2) & x >= after;
x = sort(x(ok));
n = numel(x);
switch ref.which
    case "first", sel = 1:min(1, n);
    case "last",  sel = n:n;
    case "all",   sel = 1:n;
    case "nth",   sel = ref.n:min(ref.n, n);
end
sel = sel(sel >= 1);
e = x(sel) + ref.offsetSec;
k = sel(:);
end
