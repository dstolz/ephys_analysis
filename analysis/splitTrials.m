function S = splitTrials(T, K, opts)
%splitTrials  Assign trials to cross-validation folds (or a train/test split) in blocks of consecutive trials.
%   S = splitTrials(T, K) splits the trials into K folds that hold out
%   neighboring trials together. Trials next to each other in time share
%   slow drift, spike history and (for windows that overlap) the very same
%   samples, so folds of randomly picked trials are tested on data they
%   were trained on and the prediction is inflated. Here:
%     - trials whose windows overlap (each chained to the next that
%       starts before it ends) form one group, and a group is never split
%       between folds
%     - the groups, in time order, are cut into K blocks of consecutive
%       trials holding about the same number of trials each
%   T is [nTrials x 2] [tStart tStop) windows, one row per trial, in any
%   one unit (s on the continuous clock; sample rows as [first last+1]); or
%   an integer nTrials (no windows: trials in order, none overlapping). Rows
%   may be in any order: the blocks follow the windows' starts. K is an
%   integer >= 2, or Inf for as many folds as there are groups (leave one
%   trial, or one group of overlapping trials, out). A K above the number of
%   groups is cut down to it with a warning.
%
%   S = splitTrials(T, TestFraction=0.2) is a train/test split instead: two
%   folds, the test fold (2) holding the last groups worth about
%   TestFraction of the trials (a block at the end of the session, not trials
%   picked from all over it).
%
%   Options
%     Blocked        true (default): blocks of consecutive trials, as above.
%                    false: whole groups dealt out at random to the folds
%                    (the usual shuffled cross-validation, still without
%                    splitting a group); Seed makes it repeatable
%     Seed           the seed of that shuffle (0); a private random stream:
%                    MATLAB's global one is left alone
%     TestFraction   see above (K must then be left out)
%     Tolerance      windows closer than this overlap by nothing (1e-9: a
%                    stop that equals the next start by one rounding)
%
%   S has
%     fold      [nTrials x 1] the fold of each trial (1 .. nFolds), in the
%               order of T
%     nFolds    the folds made (K, or fewer when groups were too few or too big)
%     group     [nTrials x 1] the overlap group of each trial (numbered in
%               time order; a trial that overlaps none is its own group)
%     nGroups, nMerged   the groups, and the trials sharing a group with another
%     train, test   [nTrials x nFolds] logical; column f holds fold f out
%     blocked   as given
%
%   Errors: splitTrials:BadWindows (NaN, or a stop before its start),
%   splitTrials:NoFolds (neither K nor TestFraction), splitTrials:BadFolds,
%   splitTrials:OneGroup (fewer than two groups: nothing to hold out).
%
%   See also mTRFExport.folds, NeuroGLMExport, selectTrials.

arguments
    T double
    K double = []
    opts.Blocked (1,1) logical = true
    opts.Seed (1,1) double = 0
    opts.TestFraction double = []
    opts.Tolerance (1,1) double {mustBeNonnegative} = 1e-9
end

if isscalar(T)
    if T ~= round(T) || T < 0
        error('splitTrials:BadWindows', 'A single number must be a trial count.');
    end
    n = T;
    group = (1:n).';
else
    if size(T, 2) ~= 2
        error('splitTrials:BadWindows', 'T must be [nTrials x 2] windows [tStart tStop), or a trial count.');
    end
    if any(isnan(T), 'all') || any(T(:, 2) < T(:, 1))
        error('splitTrials:BadWindows', 'Every window needs a start and a stop at or after it.');
    end
    n = size(T, 1);
    [a, ord] = sort(T(:, 1));
    b = T(ord, 2);
    runEnd = cummax(b);
    first = [true; a(2:end) >= runEnd(1:end-1) - opts.Tolerance];   % a window starting after all before it ended
    group = zeros(n, 1);
    group(ord) = cumsum(first);
end
nGroups = max([group; 0]);
sizes = accumarray(group, 1, [nGroups 1]);
if nGroups < 2
    error('splitTrials:OneGroup', ...
        'The %d trial(s) form %d group(s) (trials with overlapping windows stay together): nothing to hold out.', n, nGroups);
end

% the fold boundaries, as fractions of the trials
if ~isempty(opts.TestFraction)
    if ~isempty(K)
        error('splitTrials:BadFolds', 'Give K folds or a TestFraction, not both.');
    end
    f = opts.TestFraction;
    if ~isscalar(f) || ~(f > 0 && f < 1)
        error('splitTrials:BadFolds', 'TestFraction must be between 0 and 1.');
    end
    edges = [1 - f, 1];
elseif isempty(K)
    error('splitTrials:NoFolds', 'Give the number of folds K (or Inf), or a TestFraction.');
else
    if ~isscalar(K) || ~(K >= 2) || (isfinite(K) && K ~= round(K))
        error('splitTrials:BadFolds', 'K must be an integer of at least 2, or Inf.');
    end
    if K > nGroups
        if isfinite(K)
            warning('splitTrials:FewerFolds', ...
                '%d folds asked for but the %d trials form only %d group(s) (overlapping trials stay together): %d folds.', ...
                K, n, nGroups, nGroups);
        end
        K = nGroups;
    end
    edges = (1:K) / K;
end

if isempty(opts.TestFraction) && K == nGroups
    foldOf = (1:nGroups).';                                % one group per fold: leave one out
else
    % the groups in the order they fill the folds: in time (blocked) or shuffled
    order = (1:nGroups).';
    if ~opts.Blocked
        order = randperm(RandStream('twister', 'Seed', opts.Seed), nGroups).';
    end
    mid = (cumsum(sizes(order)) - sizes(order) / 2) / n;  % each group's middle, as a fraction of the trials
    foldOf = zeros(nGroups, 1);
    for i = 1:nGroups
        foldOf(order(i)) = find(mid(i) < edges, 1);
    end
    [~, ~, foldOf] = unique(foldOf);                       % no empty fold: number them 1 ..
end
fold = foldOf(group);
nFolds = max(fold);
if nFolds < 2
    error('splitTrials:OneGroup', ...
        'The %d trial(s) form groups too big to fill two folds (trials with overlapping windows stay together).', n);
end

S = struct();
S.fold = fold;
S.nFolds = nFolds;
S.group = group;
S.nGroups = nGroups;
S.nMerged = nnz(sizes(group) > 1);
S.train = fold ~= 1:nFolds;
S.test = fold == 1:nFolds;
S.blocked = opts.Blocked;
end
