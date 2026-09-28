function v = tdtValueAtOnsets(t, onset, offset, value, tol)
%tdtValueAtOnsets  The value an epoc store holds at each time T.
%   V = tdtValueAtOnsets(T, ONSET, OFFSET, VALUE, TOL) returns, for each
%   time T(i) (s from the block start), the VALUE of the store's epoc that is
%   active then: its onset is at most TOL after T(i) and its offset is after
%   T(i) (an Inf offset never ends). An epoc without an offset (NaN) counts
%   only when its onset is within TOL of T(i). When several are active, the
%   one with the latest onset wins; when none is, V(i) is NaN. TOL absorbs
%   the timestamp jitter between stores (the callers pass one sample).
%
%   Plain MATLAB (no string or arguments syntax) so it also runs in Octave.

t = t(:); onset = onset(:); offset = offset(:); value = value(:);
v = NaN(numel(t), 1);
for i = 1:numel(t)
    started = onset <= t(i) + tol;
    open = offset > t(i) | (isnan(offset) & abs(onset - t(i)) <= tol);
    j = find(started & open);
    if isempty(j); continue; end
    [~, m] = max(onset(j));
    v(i) = value(j(m));
end
end
