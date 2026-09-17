function [pool, nWorkers] = parallelChunkPool(plan, nChan, maxWorkers, copies, who)
%parallelChunkPool  Process pool and in-flight cap for mapping PLAN's chunks.
%   [POOL, NWORKERS] = parallelChunkPool(PLAN, NCHAN, MAXWORKERS, COPIES, WHO)
%   decides whether the chunks of a streamPlan can be processed on a parallel
%   pool and how many may be in flight at once. POOL is the process pool to use
%   (reused when one is open, started otherwise) and NWORKERS the cap on
%   concurrent chunks, or POOL = [] and NWORKERS = 1 when the chunks must run
%   serially, in which case the warning EphysDataset:<WHO>:SerialFallback says
%   why. This is the one place the worker count is derived.
%
%   The cap comes from memory: every in-flight chunk costs about COPIES times
%   one double-precision chunk (the chunk itself plus the working copies the
%   filters and the detector make), so
%     nWorkers = min( floor((available - reserve) / (COPIES * chunkBytes)),
%                     MAXWORKERS, pool size )
%   with chunkBytes = max(plan.nSamples) * NCHAN * 8 and reserve = max(2 GB,
%   10 % of available) kept for the client. On a 32 GB machine with 60-second,
%   64-channel chunks that is 4-5 workers, well below a default 12-worker pool.
%
%   Serial reasons, in the order checked: fewer than two chunks; a chunk whose
%   sample count is unknown (traditional *.rhd files with an unparsed header);
%   an unknown channel count; MAXWORKERS < 2; no Parallel Computing Toolbox;
%   memory for fewer than two workers; no pool could be opened; the open pool
%   is not a process pool (thread pools give no speed-up for reading and
%   filtering and are refused rather than run slowly).
%
%   Inputs
%     plan        streamPlan struct array (uses nSamples)
%     nChan       channels per chunk as read (all channels, before any subset)
%     maxWorkers  cap requested by the caller; NaN = automatic only
%     copies      working copies of one chunk per worker (5 for artifact
%                 detection, 6 for spike detection, which also reads context)
%     who         method name for the warning id
%
%   See also mapChunks, EphysDataset.detectSpikes, EphysDataset.artifactIntervals.

arguments
    plan (1,:) struct
    nChan (1,1) double
    maxWorkers (1,1) double = NaN
    copies (1,1) double {mustBePositive} = 5
    who (1,1) string = "detectSpikes"
end

pool = [];
nWorkers = 1;
why = "";

if numel(plan) < 2
    why = "only one chunk";
elseif isempty(plan) || any(isnan([plan.nSamples]))
    why = "chunk sample counts are unknown";
elseif isnan(nChan) || nChan < 1
    why = "the channel count is unknown";
elseif ~isnan(maxWorkers) && maxWorkers < 2
    why = "MaxWorkers=" + string(maxWorkers);
elseif ~(license('test', 'Distrib_Computing_Toolbox') && exist('gcp', 'file'))
    why = "Parallel Computing Toolbox is not available";
else
    chunkBytes = max([plan.nSamples]) * nChan * 8;
    perWorker  = copies * chunkBytes;
    avail      = availableBytes();
    reserve    = max(2e9, 0.10 * avail);
    nMem       = floor((avail - reserve) / perWorker);
    cap = nMem;
    if ~isnan(maxWorkers)
        cap = min(cap, floor(maxWorkers));
    end
    if cap < 2
        why = sprintf("memory allows only %d worker(s) for %.0f MB chunks", ...
            max(nMem, 0), chunkBytes / 2^20);
    else
        try
            p = gcp('nocreate');
            if isempty(p)
                c = parcluster('Processes');
                p = parpool(c, max(1, min(cap, c.NumWorkers)));
            end
            if ~isa(p, 'parallel.ProcessPool')
                why = "the open pool is a " + string(class(p)) + ", not a process pool";
            elseif p.NumWorkers < 2
                why = "the pool has only one worker";
            else
                pool = p;
                nWorkers = min(cap, p.NumWorkers);
            end
        catch ME
            why = "no parallel pool could be opened: " + string(ME.message);
        end
    end
end

if isempty(pool)
    nWorkers = 1;
    warning("EphysDataset:" + who + ":SerialFallback", ...
        'UseParallel ignored (%s); processing chunks serially.', why);
end
end


function b = availableBytes()
%availableBytes  Memory available to MATLAB arrays (Windows), else a
%   conservative 8 GB.
b = 8e9;
if ispc
    try
        m = memory;
        b = double(m.MemAvailableAllArrays);
    catch
    end
end
end
