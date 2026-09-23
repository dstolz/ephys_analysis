function r = artifactChunk(obj, chunk, chanOrder, filt, det, Fs)
%artifactChunk  Detect artifacts in one streaming chunk (worker body).
%   R = artifactChunk(DS, CHUNK, CHANORDER, FILT, DET, FS) reads one
%   streamPlan chunk, optionally subsets / reorders its channels, optionally
%   filters it, runs detectArtifacts and returns what the callers accumulate:
%     nSamples       rows read (the chunk's contribution to the sample offset)
%     intervals      [k x 2] chunk-local seconds (detectArtifacts convention)
%     nBlanked       samples flagged on the combined mask
%     channelCounts  [1 x nChan] samples each channel exceeded its threshold
%                    (0 for the channels DET.channels leaves out)
%     numIntervals   contiguous flagged runs in this chunk
%     rmsWindowMs    the RMS window actually used
%   or [] when the chunk held no amplifier data. It is the single per-chunk
%   function shared by artifactIntervals and analyzeArtifacts, run serially or
%   on a process pool by mapChunks; the chunk itself never leaves the worker.
%
%   The chunk is read common-referenced (applyReference), except for the
%   "commonmode" method: the reference subtracts the very mean that method
%   looks for, so it reads the chunk as recorded.
%
%   FILT: struct(use, type, cutoff, order); DET: struct(method, threshold,
%   rmsWindowMs, minChannels, mergeGapMs, padMs, channels), channels being
%   the columns (after CHANORDER) that take part in detection.
%
%   See also mapChunks, EphysDataset.detectArtifacts, EphysDataset.readChunkUV.

r = [];
% [nSamples x nChan], microvolts, all channels
X = obj.readChunkUV(chunk, Reference=det.method ~= "commonmode");
if isempty(X)
    return
end

if ~isempty(chanOrder)
    if max(chanOrder) > size(X, 2)
        error('EphysDataset:analyzeArtifacts:BadChannelOrder', ...
            'ChannelOrder references channel %d but recording has %d.', ...
            max(chanOrder), size(X, 2));
    end
    X = X(:, chanOrder);
end

if filt.use
    X = obj.filterContinuous(X, Type=filt.type, Cutoff=filt.cutoff, ...
        Order=filt.order, Fs=Fs);
end

[mask, intervals, st] = obj.detectArtifacts(X, Method=det.method, ...
    Threshold=det.threshold, RmsWindowMs=det.rmsWindowMs, ...
    MinChannels=det.minChannels, MergeGapMs=det.mergeGapMs, ...
    PadMs=det.padMs, Fs=Fs, Channels=det.channels);

r = struct();
r.nSamples      = size(X, 1);
r.intervals     = intervals;
r.nBlanked      = nnz(mask);
r.channelCounts = st.channelExceedCounts;
r.numIntervals  = st.numIntervals;
r.rmsWindowMs   = st.rmsWindowMs;
end
