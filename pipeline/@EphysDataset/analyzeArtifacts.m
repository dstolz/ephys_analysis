function summary = analyzeArtifacts(obj, opts)
%analyzeArtifacts  Summarize automatic artifact detection over the recording.
%   SUMMARY = ds.analyzeArtifacts() streams the recording one chunk at a time
%   (per *.rhd file for the traditional format, or bounded sample windows for the
%   split formats - the same one-chunk-in-memory invariant toBin relies on), runs
%   detectArtifacts on each chunk with the dataset's ArtifactConfig, and
%   accumulates statistics WITHOUT writing anything to disk. It is the read-only
%   counterpart to toBin's blanking step, used by the Artifacts tab to preview
%   how much of the recording would be zeroed. ExcludeChannels take no part
%   in the detection (as in artifactIntervals) and count 0 in channelCounts.
%   The chunks are detected against the recording's own baselines, with
%   context beside each, and their runs stitched (MergeGapMs) and padded
%   (PadMs) once over the whole list (artifactRun), so the summary is the
%   same whatever MaxChunkSamples is, and its intervals are
%   artifactIntervals' automatic ones.
%
%   Options (any omitted option falls back to ds.ArtifactConfig)
%   -----------------------------------------------------------
%     Files          (1,:) string  subset/order of files (default: all)
%     ChannelOrder   (1,:) double  1-based reorder/subset of amplifier channels
%     Method/Threshold/RmsWindowMs/MergeGapMs/MinChannels/PadMs  detection params
%       (see detectArtifacts; RmsWindowMs/MergeGapMs/PadMs in milliseconds)
%     Filter         (1,1) logical  high/band-pass before detecting (default:
%                    ds.ArtifactConfig.Filter, so preview and runs agree)
%     FilterType/FilterCutoff/FilterOrder   filter params (default: ArtifactConfig)
%     ProgressFcn    function handle  ProgressFcn(i, nChunks, chunkName), before
%                    each chunk (serial) or as each chunk finishes (parallel)
%     MaxChunkSamples (1,1) double  cap on samples per chunk (split formats)
%     CommonModeUnreferenced, CommonModeThreshold   under a common reference,
%                    also test the unreferenced recording for a common mode
%                    (default true, 1500 uV; see artifactIntervals)
%     UseParallel    (1,1) logical  run the chunks on a process pool (default
%                    false; the result is identical; the rules and the memory
%                    cap on workers are those of detectSpikes)
%     MaxWorkers     (1,1) double  cap on chunks in flight (NaN = automatic)
%
%   Output SUMMARY struct
%   ---------------------
%     method, threshold, rmsWindowMs, mergeGapMs, minChannels, padMs
%     fs, nSamples, durationSec, nChan, channelNames
%     channelCounts  [1 x nChan]  samples each channel exceeded its threshold
%                    (0 for ExcludeChannels)
%     channelPct     [1 x nChan]  channelCounts as percent of nSamples
%     nBlanked       combined samples flagged (would be zeroed on every channel)
%     fraction       nBlanked / nSamples
%     pctDuration    100 * fraction
%     nIntervals     number of contiguous artifact intervals
%     intervals      [nIntervals x 2] those intervals, [tStart tEnd] in
%                    recording-relative seconds (the artifactIntervals
%                    convention; stitched and padded, a run cut by a chunk
%                    boundary is one row; not combined with the manual
%                    periods)
%     files          files analyzed
%
%   See also EphysDataset.detectArtifacts, EphysDataset.toBin.

arguments
    obj (1,1) EphysDataset
    opts.Files (1,:) string = string.empty(1,0)
    opts.ChannelOrder (1,:) double {mustBeInteger, mustBePositive} = []
    opts.Method (1,1) string = ""
    opts.Threshold (1,1) double = NaN
    opts.RmsWindowMs (1,1) double = NaN
    opts.MergeGapMs (1,1) double = NaN
    opts.MinChannels (1,1) double = NaN
    opts.PadMs (1,1) double = NaN
    opts.Filter = []                % [] -> ds.ArtifactConfig.Filter
    opts.FilterType (1,1) string {mustBeMember(opts.FilterType, ["","highpass","lowpass","bandpass"])} = ""
    opts.FilterCutoff (1,:) double {mustBePositive} = []
    opts.FilterOrder (1,1) double = NaN
    opts.ProgressFcn = []
    opts.MaxChunkSamples (1,1) double = NaN
    opts.CommonModeUnreferenced (1,1) logical = true
    opts.CommonModeThreshold (1,1) double {mustBePositive} = 1500
    opts.UseParallel (1,1) logical = false
    opts.MaxWorkers (1,1) double = NaN
end

if obj.NumFiles == 0
    obj.discoverFiles();
end
if obj.NumFiles == 0
    error('EphysDataset:analyzeArtifacts:NoFiles', 'No recording files in %s', obj.Folder);
end
if isnan(obj.Fs) || isempty(obj.PerFile)
    obj.refreshMetadata();
end
% Settle the common reference's channels (and the weighted CAR's state)
% before any chunk is read.
obj.prepareReference();
obj.prepareWCAR();

% Resolve detection params (per-call overrides ds.ArtifactConfig).
cfg = EphysDataset.normalizeArtifactConfig(obj.ArtifactConfig);
method   = opts.Method;        if method == "";         method   = cfg.Method;       end
thr      = opts.Threshold;     if isnan(thr);           thr      = cfg.Threshold;    end
rmsWinMs = opts.RmsWindowMs;   if isnan(rmsWinMs);      rmsWinMs = cfg.RmsWindowMs;  end
mergeGapMs = opts.MergeGapMs;  if isnan(mergeGapMs);    mergeGapMs = cfg.MergeGapMs; end
minCh    = opts.MinChannels;   if isnan(minCh);         minCh    = cfg.MinChannels;  end
padMs    = opts.PadMs;         if isnan(padMs);         padMs    = cfg.PadMs;        end
[useFilter, fType, fCut, fOrd] = EphysDataset.resolveFilterOptions(cfg, ...
    opts.Filter, opts.FilterType, opts.FilterCutoff, opts.FilterOrder);

% Streaming plan (per *.rhd file for traditional; bounded sample windows for the
% split formats). The per-chunk work is artifactChunk, run by mapChunks.
plan = obj.streamPlan(Files=opts.Files, MaxChunkSamples=opts.MaxChunkSamples);

% Channel names from the parsed header (applying any reorder/subset), independent
% of which chunk we are on - identical for every supported format.
channelNames = obj.ChannelNames;
if ~isempty(opts.ChannelOrder)
    if isempty(channelNames) || max(opts.ChannelOrder) > numel(channelNames)
        channelNames = string.empty(1,0);   % resolved against data width below
    else
        channelNames = channelNames(opts.ChannelOrder);
    end
end

Fs = obj.Fs;
chanOrder = opts.ChannelOrder;
% The columns (after ChannelOrder) that take part in detection: every one but
% the ExcludeChannels.
recCh = chanOrder;
if isempty(recCh); recCh = 1:obj.NumChannels; end
filt = struct('use', useFilter, 'type', fType, 'cutoff', fCut, 'order', fOrd);
det  = struct('method', method, 'threshold', thr, 'rmsWindowMs', rmsWinMs, ...
    'minChannels', minCh, 'mergeGapMs', mergeGapMs, 'padMs', padMs, ...
    'channels', find(~ismember(recCh, obj.excludedChannels())));
run  = struct('UseParallel', opts.UseParallel, 'MaxWorkers', opts.MaxWorkers, ...
    'ProgressFcn', {opts.ProgressFcn}, 'caller', "analyzeArtifacts", ...
    'CommonModeUnreferenced', opts.CommonModeUnreferenced, 'CommonModeThreshold', opts.CommonModeThreshold);

% The chunks' detections, reduced in recording order and joined and padded
% once over the whole list, exactly as artifactIntervals does (artifactRun).
res = artifactRun(obj, plan, chanOrder, filt, det, Fs, run);
nSamples = res.nSamples;
nBlanked = res.nBlanked;
nIntervals = res.numIntervals;
intervals = res.intervals;
channelCounts = res.channelCounts;     % [1 x nChan], from the chunks that held data
rmsWindowMsUsed = res.rmsWindowMs;

if isempty(channelCounts); channelCounts = zeros(1, 0); end

summary = struct();
summary.method      = method;
summary.threshold   = thr;
summary.rmsWindowMs = rmsWindowMsUsed;
summary.mergeGapMs  = mergeGapMs;
summary.minChannels = minCh;
summary.padMs       = padMs;
summary.fs          = Fs;
summary.nSamples    = nSamples;
summary.durationSec = nSamples / max(Fs, 1);
summary.nChan       = numel(channelCounts);
summary.channelNames = channelNames;
summary.channelCounts = channelCounts;
summary.channelPct  = 100 * channelCounts / max(nSamples, 1);
summary.nBlanked    = nBlanked;
summary.fraction    = nBlanked / max(nSamples, 1);
summary.pctDuration = 100 * nBlanked / max(nSamples, 1);
summary.nIntervals  = nIntervals;
summary.intervals   = intervals;
summary.files       = string({plan.name});
end
