function R = mapChunks(fcn, names, opts)
%mapChunks  R{i} = fcn(i) for every chunk, serially or on a process pool.
%   R = mapChunks(FCN, NAMES, Pool=, NumWorkers=, ProgressFcn=) evaluates
%   FCN(i) for i = 1:numel(NAMES) and returns the results in recording order
%   whatever the order they finish in. It is the one chunk loop shared by the
%   streaming methods (detectSpikes, artifactIntervals, analyzeArtifacts), so
%   serial and parallel runs call exactly the same per-chunk function and
%   produce exactly the same result.
%
%   Serial (Pool = [], the default): for i = 1:n, ProgressFcn(i, n, NAMES(i))
%   is called BEFORE chunk i, then R{i} = FCN(i).
%
%   Parallel (Pool = a parallel.ProcessPool): chunks are submitted with
%   parfeval in order, at most NumWorkers in flight at once (the memory cap
%   from parallelChunkPool, independent of the pool size), and collected with
%   fetchNext. ProgressFcn(nDone, n, NAMES(k)) is called ON THE CLIENT after
%   each chunk k finishes, with a monotone done-count, so a caller's progress
%   bar behaves in both modes and a ProgressFcn that throws (the way
%   EphysPipeline cancels) stops the loop: the outstanding futures are
%   cancelled before the error propagates. A worker error propagates with the
%   identifier and message the serial path would raise. An interrupt (Ctrl-C)
%   cancels the outstanding futures too, through an onCleanup that holds the
%   futures in a handle object rather than reading this workspace, which is
%   already being torn down when cleanup runs.
%
%   FCN's inputs are serialized to the workers on every call; keep them to the
%   dataset handle, the plan and small option structs. Only FCN's result comes
%   back, never the chunk data.
%
%   See also parallelChunkPool, parfeval, fetchNext.

arguments
    fcn (1,1) function_handle
    names (1,:) string
    opts.Pool = []
    opts.NumWorkers (1,1) double {mustBeInteger, mustBePositive} = 1
    opts.ProgressFcn = []
end

n = numel(names);
R = cell(1, n);
progress = opts.ProgressFcn;

if isempty(opts.Pool)
    for i = 1:n
        if ~isempty(progress)
            progress(i, n, names(i));
        end
        R{i} = fcn(i);
    end
    return
end

held = containers.Map('KeyType', 'char', 'ValueType', 'any');   % handle: safe in cleanup
guard = onCleanup(@() cancelHeld(held)); %#ok<NASGU>
F = parallel.FevalFuture.empty(1, 0);
next = 1;
done = 0;
while done < n
    % Keep the window full: chunk k is always future k, so the index fetchNext
    % returns is the chunk index.
    while next <= n && (next - 1 - done) < opts.NumWorkers
        F(next) = parfeval(opts.Pool, fcn, 1, next);
        held('F') = F;
        next = next + 1;
    end
    try
        [k, r] = fetchNext(F);
    catch ME
        ME = workerError(F, ME);   % before cancelling: a cancelled future reports its own error
        cancelHeld(held);
        throw(ME);
    end
    R{k} = r;
    done = done + 1;
    if ~isempty(progress)
        try
            progress(done, n, names(k));
        catch ME
            cancelHeld(held);
            rethrow(ME);
        end
    end
end
remove(held, 'F');
end


function cancelHeld(held)
%cancelHeld  Cancel the futures held in the map, if any (finished ones are no-ops).
if isKey(held, 'F')
    try
        cancel(held('F'));
    catch
    end
    remove(held, 'F');
end
end


function ME = workerError(F, ME)
%workerError  The error a failed future raised, else the one fetchNext threw.
%   A future that errored keeps its MException in Error; unwrapped from the
%   ParallelException that carries it, its identifier is the one the serial
%   path raises, so callers can match on it.
for f = F
    if ~isempty(f.Error)
        ME = unwrap(f.Error);
        return
    end
end
ME = unwrap(ME);
end


function ME = unwrap(ME)
if isa(ME, 'ParallelException') && ~isempty(ME.remotecause) ...
        && isa(ME.remotecause{1}, 'MException')
    ME = ME.remotecause{1};
end
end
