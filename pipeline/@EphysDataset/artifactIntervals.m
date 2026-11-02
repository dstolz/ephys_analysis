function [iv, detected] = artifactIntervals(obj, opts)
%artifactIntervals  Merged artifact periods (seconds) erased before sorting.
%   IV = ds.artifactIntervals() returns a [k x 2] matrix of [tStart tEnd] in
%   seconds, recording-relative (file 1 = t0), combining:
%     * every manual period in ds.ManualArtifacts (unless IncludeManual is
%       false), and
%     * the automatic amplitude-deviation detector's intervals when
%       ds.ArtifactConfig.Enabled (or opts.IncludeAuto) is true, with the
%       bounds moved by hand in ds.ArtifactAdjustments (adjustArtifacts;
%       unless IncludeManual is false).
%   Overlapping / adjacent periods are merged into one. Every period is
%   half-open, [tStart tEnd) on the 0-based sample clock (detectArtifacts,
%   manualArtifactMask), so an artifact cut by a chunk boundary comes back as
%   one period. runKilosort passes this list to toBin, which erases exactly
%   these spans in the .bin it feeds Kilosort4; the recording files are never
%   modified.
%
%   [IV, DETECTED] = ds.artifactIntervals(...) also returns how the detection
%   ran, for toBin's report: struct(channelCounts [1 x nChan], samples each
%   channel exceeded its threshold; rmsWindowMs, the window as resolved). Its
%   channelCounts is [] and its rmsWindowMs NaN when nothing was detected on.
%
%   Auto intervals are found with the same streamPlan + artifactChunk loop the
%   Artifacts-tab preview uses (analyzeArtifacts), one chunk in memory at a time
%   (per worker with UseParallel), so the preview and the actual run agree.
%   Each chunk's intervals are shifted by the running sample offset so they are
%   global (recording-relative), then stitched (MergeGapMs) and padded (PadMs)
%   once over the whole list. The baselines of "rms" and "mad" are the
%   recording's own, and a chunk is read with context beside it for the filter
%   and the running RMS, so the result depends on neither UseParallel nor
%   MaxChunkSamples (artifactRun). A reference that a derived signal does not
%   take (the LFP, by default) would hide a broad artifact the reference
%   cancels: so under a common reference (CAR / CMR / weighted CAR) the
%   recording as recorded is also tested for a common mode above
%   CommonModeThreshold (see below).
%   ExcludeChannels take no part in the detection: a dead or broken site
%   (which after a common reference also carries the reference's inverse)
%   must not erase a period on every channel. A detection is recorded in
%   ds.Processing.artifacts (recordDetection: the settings as run, the
%   reference read through, what it found) for the manifest's processing
%   block.
%
%   Options (auto-detection params; each omitted option falls back to
%   ds.ArtifactConfig)
%   -------------------------------------------------------------------
%     IncludeAuto  logical  run the detector (default = ds.ArtifactConfig.Enabled)
%     IncludeManual logical  add ds.ManualArtifacts and apply
%       ds.ArtifactAdjustments (default true; false gives the automatic
%       detection alone, as the detector finds it and EphysPipeline caches it)
%     Files        (1,:) string  subset/order of files (default: all)
%     Method/Threshold/RmsWindowMs/MergeGapMs/MinChannels/PadMs   detection params
%     Filter/FilterType/FilterCutoff/FilterOrder   detect on a filtered view
%       (default: ds.ArtifactConfig.Filter etc., so a config with Filter=true
%       is honored by runs, the preview and the Visualize overlay alike)
%     MaxChunkSamples (1,1) double  cap on samples per chunk (split formats)
%     CommonModeUnreferenced (1,1) logical  under a common reference, also flag
%       the samples where the unreferenced recording's mean across the
%       channels that take part exceeds CommonModeThreshold, and combine the
%       two (default true; ignored for Reference "none" and Method
%       "commonmode", which read the recording unreferenced already). The
%       reference removes a broad artifact from the signals that take it,
%       but not from the ones derived without it (deriveSignals: the LFP
%       unless referenceSignals says otherwise).
%     CommonModeThreshold (1,1) double  that test's threshold, microvolts
%       (default 1500, detectArtifacts' "commonmode" default)
%     UseParallel  (1,1) logical  run the chunks on a process pool (default
%       false); the rules and the memory cap on workers are those of
%       detectSpikes, and a warning reports a fall-back to serial
%     MaxWorkers   (1,1) double  cap on chunks in flight (NaN = automatic)
%     ProgressFcn  function handle  ProgressFcn(i, nChunks, chunkName), before
%       each chunk (serial) or as each chunk finishes (parallel)
%
%   See also EphysDataset.detectArtifacts, EphysDataset.analyzeArtifacts,
%   EphysDataset.runKilosort, EphysDataset.ManualArtifacts.

arguments
    obj (1,1) EphysDataset
    opts.IncludeAuto = []           % [] -> ds.ArtifactConfig.Enabled
    opts.IncludeManual (1,1) logical = true
    opts.Files (1,:) string = string.empty(1,0)
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
    opts.MaxChunkSamples (1,1) double = NaN
    opts.CommonModeUnreferenced (1,1) logical = true
    opts.CommonModeThreshold (1,1) double {mustBePositive} = 1500
    opts.UseParallel (1,1) logical = false
    opts.MaxWorkers (1,1) double = NaN
    opts.ProgressFcn = []
end

acfg = EphysDataset.normalizeArtifactConfig(obj.ArtifactConfig);
[useFilter, fType, fCut, fOrd] = EphysDataset.resolveFilterOptions(acfg, ...
    opts.Filter, opts.FilterType, opts.FilterCutoff, opts.FilterOrder);

detected = struct('channelCounts', [], 'rmsWindowMs', NaN);
includeAuto = opts.IncludeAuto;
if isempty(includeAuto)
    includeAuto = logical(acfg.Enabled);
else
    includeAuto = logical(includeAuto);
end

% Manual periods are included (explicit user intent) unless the caller wants
% the automatic detection alone.
manual = obj.ManualArtifacts;
if isempty(manual) || ~opts.IncludeManual; manual = zeros(0, 2); end

if ~includeAuto
    iv = mergeIntervals(manual);
    return
end

% --- automatic detection over the whole recording, chunk by chunk ---------
if obj.NumFiles == 0
    obj.discoverFiles();
end
if obj.NumFiles == 0
    iv = mergeIntervals(manual);   % nothing to detect on
    return
end
if isnan(obj.Fs) || isempty(obj.PerFile)
    obj.refreshMetadata();
end
% Settle the common reference's channels (and the weighted CAR's state)
% before any chunk is read.
obj.prepareReference();
obj.prepareWCAR();

% Resolve detection params (per-call overrides ds.ArtifactConfig).
method   = opts.Method;      if method == "";      method   = acfg.Method;      end
thr      = opts.Threshold;   if isnan(thr);        thr      = acfg.Threshold;   end
rmsWinMs = opts.RmsWindowMs; if isnan(rmsWinMs);   rmsWinMs = acfg.RmsWindowMs; end
mergeGap = opts.MergeGapMs;  if isnan(mergeGap);   mergeGap = acfg.MergeGapMs;  end
minCh    = opts.MinChannels; if isnan(minCh);      minCh    = acfg.MinChannels; end
padMs    = opts.PadMs;       if isnan(padMs);      padMs    = acfg.PadMs;       end

Fs   = obj.Fs;
plan = obj.streamPlan(Files=opts.Files, MaxChunkSamples=opts.MaxChunkSamples);
filt = struct('use', useFilter, 'type', fType, 'cutoff', fCut, 'order', fOrd);
det  = struct('method', method, 'threshold', thr, 'rmsWindowMs', rmsWinMs, ...
    'minChannels', minCh, 'mergeGapMs', mergeGap, 'padMs', padMs, ...
    'channels', setdiff(1:obj.NumChannels, obj.excludedChannels()));
run  = struct('UseParallel', opts.UseParallel, 'MaxWorkers', opts.MaxWorkers, ...
    'ProgressFcn', {opts.ProgressFcn}, 'caller', "artifactIntervals", ...
    'CommonModeUnreferenced', opts.CommonModeUnreferenced, 'CommonModeThreshold', opts.CommonModeThreshold);

% The chunks' detections, joined and padded once (artifactRun).
res = artifactRun(obj, plan, [], filt, det, Fs, run);
auto = res.intervals;
detected = struct('channelCounts', res.channelCounts, 'rmsWindowMs', res.rmsWindowMs);
% How the detection ran, for the manifest (Processing.artifacts).
s = EphysDataset.detectionSettings(acfg);
s.Enabled = true;
s.Method = method;
s.Threshold = thr;
s.RmsWindowMs = rmsWinMs;
s.MergeGapMs = mergeGap;
s.MinChannels = minCh;
s.PadMs = padMs;
s.Filter = useFilter;
s.FilterType = fType;
s.FilterCutoff = fCut;
s.FilterOrder = fOrd;
s.Files = opts.Files;
s.MaxChunkSamples = opts.MaxChunkSamples;
s.CommonModeUnreferenced = opts.CommonModeUnreferenced;
s.CommonModeThreshold = opts.CommonModeThreshold;
obj.recordDetection(s, auto, obj.referenceInfo());
if opts.IncludeManual
    auto = obj.adjustArtifacts(auto);   % the bounds moved by hand, before any merge
end

iv = mergeIntervals([manual; auto]);
end


function out = mergeIntervals(iv)
%mergeIntervals  Sort [k x 2] half-open second-intervals and merge overlapping
%   or touching ones ([a b) and [b c) are one span).
if isempty(iv)
    out = zeros(0, 2);
    return
end
iv = iv(iv(:, 2) > iv(:, 1), :);           % drop empty spans (a detection is never empty)
if isempty(iv)
    out = zeros(0, 2);
    return
end
iv = sortrows(iv, 1);
out = iv(1, :);
for k = 2:size(iv, 1)
    if iv(k, 1) <= out(end, 2)             % overlap or touch -> extend
        out(end, 2) = max(out(end, 2), iv(k, 2));
    else
        out(end+1, :) = iv(k, :); %#ok<AGROW>
    end
end
end
