function out = artifactRun(obj, plan, chanOrder, filt, det, Fs, run)
%artifactRun  The automatic artifact detection over a streamPlan, as one list.
%   OUT = artifactRun(DS, PLAN, CHANORDER, FILT, DET, FS, RUN) detects the
%   artifacts of every chunk of PLAN (artifactChunk, serially or on a process
%   pool) and joins them into the recording's list. It is the one routine
%   behind artifactIntervals and analyzeArtifacts, so the preview and the run
%   agree. What it does so the list does not depend on how the recording was
%   cut into chunks:
%     - the baselines (median / MAD of the running RMS or of the signal) are
%       the recording's own (artifactBaseline), not each chunk's, so a chunk
%       that is mostly stimulation does not set its own;
%     - each chunk is read with context beside it, enough for the filter to
%       settle and the running RMS to fill its window, so a chunk's ends carry
%       no edge;
%     - the chunks detect with no stitching and no padding, and the whole
%       list is stitched (gaps up to DET.mergeGapMs) and padded (DET.padMs)
%       once, so a run cut by a chunk boundary is one run, and padding is
%       clipped at the recording's ends only.
%   FILT, DET and FS are artifactChunk's; DET also holds mergeGapMs and padMs.
%   RUN: UseParallel, MaxWorkers, ProgressFcn, caller (the name in a serial
%   fall-back warning), CommonModeUnreferenced (also test the unreferenced
%   recording for a common mode, see artifactChunk) and CommonModeThreshold.
%
%   OUT: intervals [k x 2] recording-relative seconds [tStart tEnd), the
%   samples read before each chunk added (the listed chunks laid end to end),
%   nSamples, channelCounts [1 x nChan], rmsWindowMs, nBlanked (samples the
%   intervals cover) and numIntervals; channelCounts is 0x0 when no chunk held
%   data.
%
%   See also artifactChunk, artifactBaseline, mapChunks,
%   EphysDataset.artifactIntervals, EphysDataset.analyzeArtifacts.

nChunks = numel(plan);

% Context for the filter and the running RMS, and the recording's baselines:
% only when there is more than one chunk (one chunk is the recording).
ctx = 0;
if nChunks > 1
    if det.method == "rms"
        [~, wms] = artifactScore(zeros(1, 1), "rms", Fs, det.rmsWindowMs);
        ctx = max(1, round(wms * 1e-3 * Fs));
    end
    if filt.use
        ctx = ctx + filterSettle(filt, Fs);
    end
end
det.context = ctx;
det.baseline = [];
if nChunks > 1
    det.baseline = artifactBaseline(obj, plan, chanOrder, filt, det, Fs, ctx);
end
det.alsoUnreferenced = run.CommonModeUnreferenced && obj.referenceMode() ~= "none" ...
    && det.method ~= "commonmode";
det.commonThreshold = run.CommonModeThreshold;

pool = [];
nWorkers = 1;
if run.UseParallel && nChunks > 1
    copies = 5 + wcarCopies(obj, plan) + det.alsoUnreferenced;
    [pool, nWorkers] = parallelChunkPool(plan, obj.NumChannels, run.MaxWorkers, copies, run.caller);
end
R = mapChunks(@(i) artifactChunk(obj, plan(i), chanOrder, filt, det, Fs), ...
    reshape(string({plan.name}), 1, []), Pool=pool, NumWorkers=nWorkers, ...
    ProgressFcn=run.ProgressFcn);

% Reduce in recording order. The sums are integer-valued, so the result does
% not depend on the order the chunks finished in. Each chunk's intervals are
% shifted by the samples read before it.
nSamples = 0;
counts = [];                 % [1 x nChan], from the first chunk that held data
rmsWindowMs = NaN;
parts = cell(nChunks, 1);
for i = 1:nChunks
    r = R{i};
    if isempty(r)
        continue
    end
    if isempty(counts)
        counts = r.channelCounts;
    else
        counts = counts + r.channelCounts;
    end
    parts{i} = r.intervals + nSamples / Fs;
    nSamples = nSamples + r.nSamples;
    if isnan(rmsWindowMs); rmsWindowMs = r.rmsWindowMs; end
end
iv = joinAndPad(vertcat(parts{:}), Fs, det.mergeGapMs, det.padMs, nSamples);

out = struct();
out.intervals     = iv;
out.nSamples      = nSamples;
out.channelCounts = counts;
out.rmsWindowMs   = rmsWindowMs;
out.nBlanked      = sum(round(iv(:, 2) * Fs) - round(iv(:, 1) * Fs));
out.numIntervals  = size(iv, 1);
end


function iv = joinAndPad(iv, Fs, gapMs, padMs, nSamples)
%joinAndPad  Stitch runs separated by at most GAPMS and pad every run by PADMS.
%   IV [k x 2] seconds, sorted, on the sample grid (detectArtifacts'
%   convention: sample s lies at s/Fs, a run of rows a..b is [a-1, b)/Fs).
%   The gaps are stitched first, then the runs padded and any that now touch
%   joined, as detectArtifacts does for a block; the padding is clipped to
%   [0, NSAMPLES) samples.
if isempty(iv)
    iv = zeros(0, 2);
    return
end
a = round(iv(:, 1) * Fs);          % 0-based first sample
b = round(iv(:, 2) * Fs);          % 0-based end, exclusive
[a, b] = joinRuns(a, b, round(gapMs * 1e-3 * Fs));
pad = round(padMs * 1e-3 * Fs);
if pad > 0
    a = max(0, a - pad);
    b = min(nSamples, b + pad);
    [a, b] = joinRuns(a, b, 0);
end
iv = [a, b] ./ Fs;
end


function [a, b] = joinRuns(a, b, gap)
%joinRuns  Runs [a, b) (sorted) with at most GAP samples between one and the
%   next become one run.
if numel(a) < 2
    return
end
b = cummax(b);                      % a run inside the one before it ends where that one does
first = [true; (a(2:end) - b(1:end-1)) > gap];
last = [first(2:end); true];
a = a(first);
b = b(last);
end


function n = filterSettle(filt, Fs)
%filterSettle  Rows after which the zero-phase detection filter has forgotten
%   an edge to 1e-6: the decay of its slowest pole, at most 10 s. 0 when the
%   filter cannot be designed (filterContinuous then says why).
n = 0;
switch string(filt.type)
    case "highpass", type = 'high';
    case "lowpass",  type = 'low';
    otherwise,       type = 'bandpass';
end
try
    [~, p, ~] = butter(filt.order, filt.cutoff / (Fs / 2), type);
    n = ceil(log(1e-6) / log(max(abs(p))));
catch
    return
end
if ~isfinite(n) || n < 0
    n = 0;
end
n = min(n, round(10 * Fs));
end
