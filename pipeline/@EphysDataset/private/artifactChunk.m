function r = artifactChunk(obj, chunk, chanOrder, filt, det, Fs)
%artifactChunk  Detect artifacts in one streaming chunk (worker body).
%   R = artifactChunk(DS, CHUNK, CHANORDER, FILT, DET, FS) reads one
%   streamPlan chunk, optionally subsets / reorders its channels, optionally
%   filters it, runs detectArtifacts and returns what the callers accumulate:
%     nSamples       rows read (the chunk's contribution to the sample offset)
%     intervals      [k x 2] chunk-local seconds (detectArtifacts convention),
%                    neither stitched nor padded: the callers join and pad the
%                    whole recording's list once (artifactRun), so the result
%                    does not depend on where the chunks end
%     channelCounts  [1 x nChan] samples each channel exceeded its threshold
%                    (0 for the channels DET.channels leaves out)
%     rmsWindowMs    the RMS window actually used
%   or [] when the chunk held no amplifier data. It is the single per-chunk
%   function shared by artifactIntervals and analyzeArtifacts, run serially or
%   on a process pool by mapChunks; the chunk itself never leaves the worker.
%
%   The chunk is read common-referenced (applyReference), except for the
%   "commonmode" method: the reference subtracts the very mean that method
%   looks for, so it reads the chunk as recorded. A signal derived without
%   the reference (deriveSignals leaves the LFP unreferenced) would still
%   carry a broad artifact the reference cancels, so with DET.alsoUnreferenced
%   the chunk is also scored, as recorded and unfiltered, with the
%   "commonmode" test (DET.commonThreshold) and the two masks are combined.
%
%   FILT: struct(use, type, cutoff, order); DET: struct(method, threshold,
%   rmsWindowMs, minChannels, channels, baseline, context, alsoUnreferenced,
%   commonThreshold), channels being the columns (after CHANORDER) that take
%   part in detection, baseline the recording's own (artifactBaseline; []
%   = the chunk's) and context the rows read beside the chunk (on each side)
%   for the filter and the running RMS to settle in.
%
%   See also mapChunks, artifactRun, EphysDataset.detectArtifacts,
%   EphysDataset.readChunkUV.

r = [];
ref = det.method ~= "commonmode";
both = det.alsoUnreferenced && ref;
share = both && obj.referenceMode() ~= "wcar";   % CAR / CMR of the rows as read: one read serves both
usePad = det.context > 0 && isfinite(chunk.sampleOffset) && isfinite(chunk.nSamples) ...
    && chunk.nSamples > 0 && obj.supportsRandomAccess();

[X, rows] = readRows(obj, chunk, det.context, usePad, ref && ~share);   % [nSamples x nChan], microvolts, all channels
if isempty(X)
    return
end
mask2 = [];
if share
    mask2 = commonModeMask(obj, X, chanOrder, det, Fs, rows);   % X is as recorded
    X = obj.applyReference(X);
end
X = subsetChannels(X, chanOrder);
if filt.use
    X = obj.filterContinuous(X, Type=filt.type, Cutoff=filt.cutoff, ...
        Order=filt.order, Fs=Fs);
end

% MergeGapMs and PadMs are the caller's, once over the whole list.
[mask, intervals, st] = obj.detectArtifacts(X, Method=det.method, ...
    Threshold=det.threshold, RmsWindowMs=det.rmsWindowMs, ...
    MinChannels=det.minChannels, Fs=Fs, Channels=det.channels, ...
    Baseline=det.baseline, Rows=rows);
clear X

if both && ~share
    Xu = readRows(obj, chunk, det.context, usePad, false);
    mask2 = commonModeMask(obj, Xu, chanOrder, det, Fs, rows);
end
if ~isempty(mask2)
    mask = mask | mask2;
    intervals = maskIntervals(mask, Fs);
end

r = struct();
r.nSamples      = rows(2) - rows(1) + 1;
r.intervals     = intervals;
r.channelCounts = st.channelExceedCounts;
r.rmsWindowMs   = st.rmsWindowMs;
end


function [X, rows] = readRows(obj, chunk, ctx, usePad, reference)
%readRows  The chunk, with up to CTX rows of the recording on either side
%   when USEPAD. ROWS is [first last] of the chunk itself within X; the rows
%   beyond the recording's ends are not there (a window read stops at the end).
if ~usePad
    X = obj.readChunkUV(chunk, Reference=reference);
    rows = [1 size(X, 1)];
    return
end
a = chunk.sampleOffset;
a0 = max(0, a - ctx);
X = obj.readWindowUV(a0, (a - a0) + chunk.nSamples + ctx, Reference=reference);
rows = [(a - a0) + 1, min((a - a0) + chunk.nSamples, size(X, 1))];
end


function mask = commonModeMask(obj, Xu, chanOrder, det, Fs, rows)
%commonModeMask  The chunk's rows where the unreferenced mean across the
%   channels that take part exceeds the common-mode threshold.
mask = obj.detectArtifacts(subsetChannels(Xu, chanOrder), Method="commonmode", ...
    Threshold=det.commonThreshold, Fs=Fs, Channels=det.channels, Rows=rows);
end


function X = subsetChannels(X, chanOrder)
if isempty(chanOrder)
    return
end
if max(chanOrder) > size(X, 2)
    error('EphysDataset:analyzeArtifacts:BadChannelOrder', ...
        'ChannelOrder references channel %d but recording has %d.', ...
        max(chanOrder), size(X, 2));
end
X = X(:, chanOrder);
end


function iv = maskIntervals(mask, Fs)
%maskIntervals  Runs of MASK as half-open [first - 1, last)/Fs.
d = diff([0; mask(:); 0]);
on = find(d == 1);
off = find(d == -1) - 1;
iv = zeros(0, 2);
if ~isempty(on)
    iv = [on - 1, off] ./ Fs;
end
end
