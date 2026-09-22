function iv = artifactIntervals(obj, opts)
%artifactIntervals  Merged artifact periods (seconds) for SI silence_periods.
%   IV = ds.artifactIntervals() returns a [k x 2] matrix of [tStart tEnd] in
%   seconds, recording-relative (file 1 = t0), combining:
%     * every manual period in ds.ManualArtifacts (always included), and
%     * the automatic amplitude-deviation detector's intervals when
%       ds.ArtifactConfig.Enabled (or opts.IncludeAuto) is true.
%   Overlapping / adjacent periods are merged into one. Every period is
%   half-open, [tStart tEnd) on the 0-based sample clock (detectArtifacts,
%   manualArtifactMask), so an artifact cut by a chunk boundary comes back as
%   one period. runSpikeInterface passes this list to the generated Python so
%   SpikeInterface's silence_periods zeros exactly these spans in the
%   recording it feeds Kilosort4; the *.rhd files are never modified.
%
%   Auto intervals are found with the same streamPlan + artifactChunk loop the
%   Artifacts-tab preview uses (analyzeArtifacts), one chunk in memory at a time
%   (per worker with UseParallel), so the preview and the actual run agree.
%   Each chunk's intervals are shifted by the running sample offset so they are
%   global (recording-relative). The result does not depend on UseParallel.
%
%   Options (auto-detection params; each omitted option falls back to
%   ds.ArtifactConfig)
%   -------------------------------------------------------------------
%     IncludeAuto  logical  run the detector (default = ds.ArtifactConfig.Enabled)
%     Files        (1,:) string  subset/order of files (default: all)
%     Method/Threshold/RmsWindowMs/MergeGapMs/MinChannels/PadMs   detection params
%     Filter/FilterType/FilterCutoff/FilterOrder   detect on a filtered view
%       (default: ds.ArtifactConfig.Filter etc., so a config with Filter=true
%       is honored by runs, the preview and the Visualize overlay alike)
%     MaxChunkSamples (1,1) double  cap on samples per chunk (split formats)
%     UseParallel  (1,1) logical  run the chunks on a process pool (default
%       false); the rules and the memory cap on workers are those of
%       detectSpikes, and a warning reports a fall-back to serial
%     MaxWorkers   (1,1) double  cap on chunks in flight (NaN = automatic)
%     ProgressFcn  function handle  ProgressFcn(i, nChunks, chunkName), before
%       each chunk (serial) or as each chunk finishes (parallel)
%
%   See also EphysDataset.detectArtifacts, EphysDataset.analyzeArtifacts,
%   EphysDataset.runSpikeInterface, EphysDataset.ManualArtifacts.

arguments
    obj (1,1) EphysDataset
    opts.IncludeAuto = []           % [] -> ds.ArtifactConfig.Enabled
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
    opts.UseParallel (1,1) logical = false
    opts.MaxWorkers (1,1) double = NaN
    opts.ProgressFcn = []
end

acfg = EphysDataset.normalizeArtifactConfig(obj.ArtifactConfig);
[useFilter, fType, fCut, fOrd] = EphysDataset.resolveFilterOptions(acfg, ...
    opts.Filter, opts.FilterType, opts.FilterCutoff, opts.FilterOrder);

includeAuto = opts.IncludeAuto;
if isempty(includeAuto)
    includeAuto = logical(acfg.Enabled);
else
    includeAuto = logical(includeAuto);
end

% Manual periods are always included (explicit user intent).
manual = obj.ManualArtifacts;
if isempty(manual); manual = zeros(0, 2); end

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

% Resolve detection params (per-call overrides ds.ArtifactConfig).
method   = opts.Method;      if method == "";      method   = acfg.Method;      end
thr      = opts.Threshold;   if isnan(thr);        thr      = acfg.Threshold;   end
rmsWinMs = opts.RmsWindowMs; if isnan(rmsWinMs);   rmsWinMs = acfg.RmsWindowMs; end
mergeGap = opts.MergeGapMs;  if isnan(mergeGap);   mergeGap = acfg.MergeGapMs;  end
minCh    = opts.MinChannels; if isnan(minCh);      minCh    = acfg.MinChannels; end
padMs    = opts.PadMs;       if isnan(padMs);      padMs    = acfg.PadMs;       end

Fs   = obj.Fs;
plan = obj.streamPlan(Files=opts.Files, MaxChunkSamples=opts.MaxChunkSamples);
nChunks = numel(plan);
filt = struct('use', useFilter, 'type', fType, 'cutoff', fCut, 'order', fOrd);
det  = struct('method', method, 'threshold', thr, 'rmsWindowMs', rmsWinMs, ...
    'minChannels', minCh, 'mergeGapMs', mergeGap, 'padMs', padMs);

pool = [];
nWorkers = 1;
if opts.UseParallel && nChunks > 1
    [pool, nWorkers] = parallelChunkPool(plan, obj.NumChannels, opts.MaxWorkers, 5, "artifactIntervals");
end
R = mapChunks(@(i) artifactChunk(obj, plan(i), [], filt, det, Fs), ...
    reshape(string({plan.name}), 1, []), Pool=pool, NumWorkers=nWorkers, ...
    ProgressFcn=opts.ProgressFcn);

% Shift each chunk's intervals by the samples read before it, in recording
% order - exactly the offsets the serial loop accumulates.
auto = zeros(0, 2);
offsetSamp = 0;
for i = 1:nChunks
    r = R{i};
    if isempty(r)
        continue
    end
    if ~isempty(r.intervals)
        auto = [auto; r.intervals + offsetSamp / Fs]; %#ok<AGROW> shift to global seconds
    end
    offsetSamp = offsetSamp + r.nSamples;
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
