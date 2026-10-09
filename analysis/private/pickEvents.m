function [e, k, r, nNoSeq, failRows] = pickEvents(iv, ref, origin, after, src)
%pickEvents  Apply an event reference to one set of intervals.
%   [E, K, R] = pickEvents(IV, REF, ORIGIN, AFTER, SRC) keeps the [on off]
%   intervals IV whose length lies in [REF.minDurationSec, REF.maxDurationSec]
%   and whose REF.edge time, minus ORIGIN, lies in REF.timeRange; of those,
%   the edges at or after AFTER (default -Inf) whose REF.sequence completes
%   (followSequence on the dataset SRC; not needed without a sequence) are
%   ranked by time and REF.which / REF.n picks among them. E are the picked
%   events (the line's own edges, or the steps REF.alignStep names) plus
%   REF.offsetSec, K their ranks (1-based) and R their rows of IV.
%   NNOSEQ is how many events the sequence cost: the picks REF.which would
%   have made without it, less those it made (every event the sequence
%   does not follow, for which "all"); FAILROWS the rows of IV whose
%   sequence did not complete.

if nargin < 4 || isempty(after); after = -Inf; end
e = zeros(0, 1); k = zeros(0, 1); r = zeros(0, 1);
nNoSeq = 0; failRows = zeros(0, 1);
if isempty(iv); return; end
dur = iv(:, 2) - iv(:, 1);
if ref.edge == "onset"; x = iv(:, 1); else; x = iv(:, 2); end
rel = x - origin;
ok = dur >= ref.minDurationSec & dur <= ref.maxDurationSec ...
    & rel >= ref.timeRange(1) & rel <= ref.timeRange(2) & x >= after;
row = find(ok);
[x, o] = sort(x(ok));
row = row(o);
t = x;
if isfield(ref, 'sequence') && ~isempty(ref.sequence)
    nBefore = numel(choose(numel(x), ref));
    [pass, t] = followSequence(src, ref, x);
    failRows = row(~pass);
    x = x(pass); t = t(pass); row = row(pass);
    nNoSeq = nBefore - numel(choose(numel(x), ref));
end
sel = choose(numel(x), ref);
e = t(sel) + ref.offsetSec;
k = sel(:);
r = row(sel);
end


function sel = choose(n, ref)
%choose  The ranks REF.which / REF.n picks out of N events.
switch ref.which
    case "first", sel = 1:min(1, n);
    case "last",  sel = n:n;
    case "all",   sel = 1:n;
    case "nth",   sel = ref.n:min(ref.n, n);
end
sel = sel(sel >= 1);
end
