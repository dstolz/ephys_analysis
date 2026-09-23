function X = bridgeRuns(X, on, off, N, center, ctx, w)
%bridgeRuns  Fill each run of rows with a line between its edges (plus noise).
%   X = bridgeRuns(X, ON, OFF, N, CENTER, CTX, W) replaces rows ON(k):OFF(k)
%   of X (sorted, disjoint runs), per channel, with a straight line from the
%   mean of the (up to W) rows before the run to the mean of those after it,
%   plus the run's rows of the noise N ([sum(OFF-ON+1) x nChan], in row
%   order; [] = no noise, a bare line). The rows averaged never reach into a
%   neighbouring run. A run at the top of X starts from the last W rows of
%   CTX; with one side missing the run is held at the other side's level,
%   with both missing at CENTER ([1 x nChan]).
%
%   X keeps its class and is changed in place (call it as X = bridgeRuns(X,
%   ...)), so a whole recording in single is never copied: blankArtifacts'
%   noise fill and deriveSignals' fill of the artifact periods share it.
nRows = size(X, 1);
used = 0;                                  % rows of N consumed so far
for k = 1:numel(on)
    a = on(k);
    b = off(k);
    L = b - a + 1;
    before = [];
    if a > 1
        first = a - w;
        if k > 1; first = max(first, off(k-1) + 1); end
        before = mean(X(max(1, first):a-1, :), 1);
    elseif ~isempty(ctx)
        before = mean(ctx(max(1, end-w+1):end, :), 1);
    end
    after = [];
    if b < nRows
        last = b + w;
        if k < numel(on); last = min(last, on(k+1) - 1); end
        after = mean(X(b+1:min(nRows, last), :), 1);
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
