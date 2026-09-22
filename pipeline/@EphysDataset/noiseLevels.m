function nl = noiseLevels(obj, opts)
%noiseLevels  Per-channel background noise level over the whole recording.
%   NL = ds.noiseLevels() streams the recording one chunk at a time (the same
%   streamPlan loop as analyzeArtifacts and toBin, so only one chunk is ever in
%   memory) and returns the per-channel level of the noise the Gaussian
%   artifact fill is drawn from (blankArtifacts(Fill="noise"),
%   ArtifactConfig.Fill). Nothing is written.
%
%   The estimate is robust and covers the whole recording: each chunk
%   contributes its per-channel median and robust SD (1.4826 x MAD), and the
%   levels reported are the medians of those across every chunk. A robust
%   statistic is what makes the level the recording's *background* noise: the
%   artifacts being erased, however large, do not inflate it, so no artifact
%   detection is needed here.
%
%   Options
%   -------
%     Files          (1,:) string  subset/order of files (default: all)
%     ChannelOrder   (1,:) double  1-based reorder/subset of amplifier channels
%     Filter         (1,1) logical  filter each chunk before measuring (default
%                    false). The level must describe the signal the fill will
%                    sit in, so measure on the band the data is written in:
%                    toBin passes its own write filter when it filters, and a
%                    high-pass at ArtifactConfig.NoiseBandHz (the spike band a
%                    sorter works in) when it does not.
%     FilterType     "highpass"|"lowpass"|"bandpass" (default "highpass")
%     FilterCutoff   scalar or [lo hi] Hz  (default 300)
%     FilterOrder    (1,1) double          (default 4)
%     Reference      (1,1) logical  measure the common-referenced signal
%                    (default true: what readChunkUV returns, the signal the
%                    fill sits in); false measures the recording as stored
%                    (suggestReferenceExclude)
%     MaxChunks      (1,1) double  read at most this many chunks, spread evenly
%                    over the recording (default Inf: every chunk)
%     MaxChunkSamples (1,1) double  cap on samples per chunk (split formats)
%     UseParallel    (1,1) logical  run the chunks on a process pool (default
%                    false); the result is identical, and the rules and the
%                    memory cap on workers are those of detectSpikes
%     MaxWorkers     (1,1) double  cap on chunks in flight (NaN = automatic)
%     ProgressFcn    function handle  ProgressFcn(i, nChunks, chunkName)
%
%   Output NL struct: sigma [1 x nChan] robust SD in microvolts, center
%   [1 x nChan] median in microvolts, nChan, channelNames, nChunks, nSamples,
%   fs, filtered, filterType, filterCutoff, filterOrder, method ("mad").
%
%   See also EphysDataset.blankArtifacts, EphysDataset.toBin,
%   EphysDataset.analyzeArtifacts.

arguments
    obj (1,1) EphysDataset
    opts.Files (1,:) string = string.empty(1,0)
    opts.ChannelOrder (1,:) double {mustBeInteger, mustBePositive} = []
    opts.Filter (1,1) logical = false
    opts.FilterType (1,1) string {mustBeMember(opts.FilterType, ["highpass","lowpass","bandpass"])} = "highpass"
    opts.FilterCutoff (1,:) double {mustBePositive} = 300
    opts.FilterOrder (1,1) double {mustBeInteger, mustBePositive} = 4
    opts.Reference (1,1) logical = true
    opts.MaxChunks (1,1) double {mustBePositive} = Inf
    opts.MaxChunkSamples (1,1) double = NaN
    opts.UseParallel (1,1) logical = false
    opts.MaxWorkers (1,1) double = NaN
    opts.ProgressFcn = []
end

if obj.NumFiles == 0
    obj.discoverFiles();
end
if obj.NumFiles == 0
    error('EphysDataset:noiseLevels:NoFiles', 'No recording files in %s', obj.Folder);
end
if isnan(obj.Fs) || isempty(obj.PerFile)
    obj.refreshMetadata();
end

if opts.Reference
    obj.prepareReference();
end

plan = obj.streamPlan(Files=opts.Files, MaxChunkSamples=opts.MaxChunkSamples);
if isempty(plan)
    error('EphysDataset:noiseLevels:NoFiles', 'No readable recording data in %s', obj.Folder);
end
if numel(plan) > opts.MaxChunks
    plan = plan(unique(round(linspace(1, numel(plan), opts.MaxChunks))));
end

Fs = obj.Fs;
nChunks = numel(plan);
filt = struct('use', opts.Filter, 'type', opts.FilterType, ...
    'cutoff', opts.FilterCutoff, 'order', opts.FilterOrder);
chanOrder = opts.ChannelOrder;

pool = [];
nWorkers = 1;
if opts.UseParallel && nChunks > 1
    [pool, nWorkers] = parallelChunkPool(plan, obj.NumChannels, opts.MaxWorkers, 5, "noiseLevels");
end
reference = opts.Reference;
R = mapChunks(@(i) noiseChunk(obj, plan(i), chanOrder, filt, Fs, reference), ...
    reshape(string({plan.name}), 1, []), Pool=pool, NumWorkers=nWorkers, ...
    ProgressFcn=opts.ProgressFcn);

% Reduce: one row per chunk that held data, then the per-channel median of
% those rows - the recording's level, taken over every chunk of it.
sig = nan(nChunks, 0);
cen = nan(nChunks, 0);
nSamples = 0;
nUsed = 0;
for i = 1:nChunks
    r = R{i};
    if isempty(r); continue; end
    if isempty(sig)
        sig = nan(nChunks, numel(r.sigma));
        cen = nan(nChunks, numel(r.sigma));
    elseif numel(r.sigma) ~= size(sig, 2)
        error('EphysDataset:noiseLevels:ChannelMismatch', ...
            ['Amplifier channel count changed mid-dataset (%d -> %d) at %s; ' ...
             'one noise level per channel cannot cover the recording.'], ...
            size(sig, 2), numel(r.sigma), plan(i).name);
    end
    nUsed = nUsed + 1;
    sig(nUsed, :) = r.sigma;
    cen(nUsed, :) = r.center;
    nSamples = nSamples + r.nSamples;
end
if nUsed == 0
    error('EphysDataset:noiseLevels:NoData', 'No amplifier data in %s', obj.Folder);
end
sig = sig(1:nUsed, :);
cen = cen(1:nUsed, :);

channelNames = obj.ChannelNames;
if ~isempty(chanOrder)
    if isempty(channelNames) || max(chanOrder) > numel(channelNames)
        channelNames = string.empty(1,0);
    else
        channelNames = channelNames(chanOrder);
    end
end

nl = struct();
nl.sigma        = median(sig, 1);
nl.center       = median(cen, 1);
nl.nChan        = size(sig, 2);
nl.channelNames = channelNames;
nl.nChunks      = nUsed;
nl.nSamples     = nSamples;
nl.fs           = Fs;
nl.filtered     = opts.Filter;
nl.filterType   = opts.FilterType;
nl.filterCutoff = opts.FilterCutoff;
nl.filterOrder  = opts.FilterOrder;
nl.method       = "mad";
end
