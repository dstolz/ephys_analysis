function r = noiseChunk(obj, chunk, chanOrder, filt, Fs, reference)
%noiseChunk  Per-channel noise level of one streaming chunk (worker body).
%   R = noiseChunk(DS, CHUNK, CHANORDER, FILT, FS, REFERENCE) reads one
%   streamPlan chunk (common-referenced when REFERENCE), optionally subsets /
%   reorders its channels, optionally filters it, and returns what
%   noiseLevels accumulates:
%     nSamples  rows read
%     center    [1 x nChan] per-channel median (microvolts)
%     sigma     [1 x nChan] per-channel robust SD, 1.4826 x MAD (microvolts)
%   or [] when the chunk held no amplifier data. Both statistics are robust, so
%   the artifacts in the chunk do not raise the level of the noise that will
%   replace them. The chunk itself never leaves the worker.
%
%   FILT: struct(use, type, cutoff, order).
%
%   See also mapChunks, EphysDataset.noiseLevels, EphysDataset.readChunkUV.

r = [];
X = obj.readChunkUV(chunk, Reference=reference);   % [nSamples x nChan], microvolts, all channels
if isempty(X)
    return
end

if ~isempty(chanOrder)
    if max(chanOrder) > size(X, 2)
        error('EphysDataset:noiseLevels:BadChannelOrder', ...
            'ChannelOrder references channel %d but recording has %d.', ...
            max(chanOrder), size(X, 2));
    end
    X = X(:, chanOrder);
end

if filt.use
    X = obj.filterContinuous(X, Type=filt.type, Cutoff=filt.cutoff, ...
        Order=filt.order, Fs=Fs);
end

med = median(X, 1);
r = struct();
r.nSamples = size(X, 1);
r.center   = med;
r.sigma    = median(abs(X - med), 1) * 1.4826;
end
