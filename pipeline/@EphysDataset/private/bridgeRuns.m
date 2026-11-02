function X = bridgeRuns(X, on, off, N, center, ctx, w, skip)
%bridgeRuns  Fill each run of rows with a line between its edges (plus noise).
%   X = bridgeRuns(X, ON, OFF, N, CENTER, CTX, W, SKIP) replaces rows
%   ON(k):OFF(k) of X (sorted, disjoint runs), per channel, with a straight
%   line from the mean of the (up to W) rows before the run to the mean of
%   those after it, plus the run's rows of the noise N ([sum(OFF-ON+1) x
%   nChan], in row order; [] = no noise, a bare line). The rows averaged
%   never reach into a neighboring run. A run at the top of X starts from the
%   last W rows of CTX; with one side missing the run is held at the other
%   side's level, with both missing at CENTER ([1 x nChan]).
%
%   SKIP (default 0): the rows averaged start SKIP rows away from the run,
%   not next to it, so a run whose edge sits on the skirt of an artifact
%   (a detection that was not padded) does not take its level from the skirt.
%   Where the neighbor or the end of X leaves no room for the guard, the
%   rows next to the run are used.
%
%   X keeps its class and is changed in place (call it as X = bridgeRuns(X,
%   ...)), so a whole recording in single is never copied: blankArtifacts'
%   noise fill and deriveSignals' fill of the artifact periods share it.
if nargin < 8
    skip = 0;
end
nRows = size(X, 1);
used = 0;                                  % rows of N consumed so far
for k = 1:numel(on)
    a = on(k);
    b = off(k);
    L = b - a + 1;
    before = [];
    if a > 1
        floorRow = 1;
        if k > 1; floorRow = off(k-1) + 1; end
        hi = a - 1 - skip;
        if hi < floorRow; hi = a - 1; end   % no room for the guard
        before = mean(X(max(floorRow, hi - w + 1):hi, :), 1);
    elseif ~isempty(ctx)
        before = mean(ctx(max(1, end-w+1):end, :), 1);
    end
    after = [];
    if b < nRows
        ceilRow = nRows;
        if k < numel(on); ceilRow = on(k+1) - 1; end
        lo = b + 1 + skip;
        if lo > ceilRow; lo = b + 1; end
        after = mean(X(lo:min(ceilRow, lo + w - 1), :), 1);
    end
    if isempty(before) && isempty(after)
        level = center;
    elseif isempty(after)
        level = before;
    elseif isempty(before)
        level = after;
    else
        level = before + (after - before) .* ((1:L).' / (L + 1));
    end
    if isempty(N)
        X(a:b, :) = level + zeros(L, 1);   % a held level fills every row too
    else
        X(a:b, :) = level + N(used+1:used+L, :);
    end
    used = used + L;
end
end
