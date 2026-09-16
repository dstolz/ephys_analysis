function [ts, wf, info] = detectSpikes(obj, X, opts)
%detectSpikes  Spike detection by simple voltage thresholding.
%   TS = ds.detectSpikes() detects spikes over the WHOLE recording, streaming it
%   one chunk at a time, and returns TS as a {1 x nChan} cell array of spike
%   times in seconds relative to the start of the recording. Nothing is written
%   to disk and the *.rhd / *.dat files are never modified. See
%   "Whole-recording mode" below for the options and caveats specific to it.
%
%   TS = ds.detectSpikes(X) detects spikes in the [nSamples x nChan] microvolt
%   block X instead, each channel independently, and returns TS as a {1 x nChan}
%   cell array of spike times in seconds (always a cell array, also for one
%   channel). Both forms run the same detector with the same options.
%
%   With the defaults the data is band-pass filtered 500-5000 Hz, the threshold
%   is 4 robust SDs (MAD/0.6745) *below* zero on each channel, each crossing is
%   aligned to its trough, and events less than 1 ms apart are discarded.
%
%   [TS, WF] = ds.detectSpikes(...) also returns waveforms: WF{c} is
%   [nSpikes x nWin] microvolts spanning WindowMs ([-0.5 1.5] ms by default)
%   around each spike, one row per spike, in the same order as TS{c}. Waveforms
%   are extracted only when a second output is requested or Waveforms=true;
%   timestamps only is the default.
%
%   [TS, WF, INFO] = ds.detectSpikes(...) also returns the parameters actually
%   used together with the per-channel thresholds, noise estimates, sample
%   indices, amplitudes and counts (see INFO below).
%
%   Options
%   -------
%   Filtering (applied to a copy; X is never modified)
%     Filter        filter before detecting (default true)
%     Band          band-pass edges [lo hi] Hz (default [500 5000])
%     FilterOrder   Butterworth order passed to filterContinuous (default 4)
%
%   Threshold (computed per channel on the filtered trace)
%     Polarity      "negative" (default) | "positive" | "both"
%                   cross when x < -thr, x > thr, or |x| > thr respectively
%     ThresholdMethod
%       "mad"        (default) thr = Threshold * median(|x-median(x)|)/0.6745
%                    robust SD; the usual choice because spikes inflate STD
%       "std"        thr = Threshold * std(x)
%       "rms"        thr = Threshold * sqrt(mean(x.^2))
%       "percentile" thr = the Threshold-th percentile of |x|
%       "absolute"   thr = Threshold, in microvolts (Threshold is required)
%     Threshold     the number that goes with ThresholdMethod: a multiplier for
%                   mad/std/rms (default 4), a percentile in (0 100] for
%                   "percentile" (default 99.9), or microvolts for "absolute"
%                   (no default). Always a positive magnitude - Polarity, not
%                   the sign of Threshold, sets the direction.
%
%   Events
%     Align         "trough" (default, local minimum) | "peak" (local maximum) |
%                   "extremum" (largest |x|, pairs with Polarity "both") |
%                   "none" (the first threshold-crossing sample). The aligned
%                   sample is both the timestamp and the waveform center.
%     AlignWindowMs search window for the extremum, starting at the crossing
%                   (default 1 ms). The search always covers at least the whole
%                   run of above-threshold samples.
%     MinPeriodMs   minimum detection period: after alignment, an event is kept
%                   only if it is at least this far from the previous kept event
%                   (default 1 ms, floor of 1 sample, so duplicates from two
%                   crossings aligning to one extremum are always removed)
%     MaxAmplitudeUV
%                   reject events whose aligned amplitude exceeds this in
%                   absolute value (default Inf = keep everything)
%
%   Waveforms
%     Waveforms     force extraction even with one output (default false)
%     WindowMs      [before after] in milliseconds relative to the aligned
%                   sample (default [-0.5 1.5]; before <= after)
%     WaveformSource
%                   "filtered" (default) or "raw" - which trace the snippets are
%                   cut from. Alignment and thresholds always use the filtered
%                   trace.
%     EdgeHandling  a window running past the start/end of the data is padded
%                   with NaN ("nan", default, so TS is unaffected) or the event
%                   is dropped from both WF and TS ("drop")
%
%   Other
%     Fs            sample rate (Hz); defaults to ds.Fs. Block form only - in
%                   whole-recording mode the rate comes from the file headers.
%     TimeOffset    seconds added to every timestamp (default 0), so a block
%                   read at a sample offset can report recording-relative times
%
%   Whole-recording mode
%   --------------------
%   ds.detectSpikes() (X omitted or passed as []) detects over the whole
%   recording without ever holding it all in memory. The recording is streamed
%   in the same units toBin and analyzeArtifacts use - one *.rhd file per chunk
%   for the traditional format, bounded sample windows for the split formats -
%   and every chunk is detected with the options above, so every layout works.
%
%   Chunk boundaries are not detection boundaries: each chunk is detected
%   together with EdgePadMs of real data carried over from the previous chunk,
%   and the last EdgePadMs of each chunk is held back and reported with the next
%   one. Every returned event therefore has at least that much genuine signal on
%   both sides for filter settling, extremum search and its waveform window (the
%   first and last samples of the recording excepted - there is nothing beyond
%   them), the regions tile the recording exactly so nothing is detected twice,
%   and MinPeriodMs is re-applied across the joins.
%
%   Thresholds, however, are still estimated PER CHUNK (info.thresholdScope is
%   "chunk"): the noise estimate of a chunk uses only that chunk's samples, as
%   it does for a block, so the threshold varies from chunk to chunk with the
%   noise. info.threshold / info.noise / info.degenerate are [nChunks x nChan]
%   for this reason. Use ThresholdMethod="absolute" (microvolts) for one fixed
%   threshold across the whole recording.
%
%   Extra options, accepted only in this mode
%     Files            (1,:) string  subset/order of *.rhd files to detect on
%                      (traditional format only; the split formats hold one
%                      recording). Timestamps stay relative to the first sample
%                      actually read.
%     ChannelOrder     (1,:) double  1-based reorder/subset of amplifier
%                      channels, applied to every chunk (as in toBin)
%     MaxChunkSamples  (1,1) double  cap on samples per chunk for the split
%                      formats (see streamPlan)
%     EdgePadMs        (1,1) double  context carried across chunk boundaries
%                      (default 10 ms; always at least the waveform window, the
%                      alignment window and the minimum detection period)
%     ProgressFcn      function handle  ProgressFcn(i, nChunks, chunkName),
%                      called before each chunk (serial) or on the client as
%                      each chunk finishes (UseParallel, completion order)
%     UseParallel      (1,1) logical  detect the chunks in parallel on the
%                      current parallel pool, starting the default pool if none
%                      is open (default false). The result is identical to the
%                      serial one. Needs the Parallel Computing Toolbox and the
%                      sample count of every chunk up front (always known for
%                      the split formats; from the *.rhd headers otherwise);
%                      when either is missing a warning is issued and the
%                      chunks run serially. Each worker reads its own chunk plus
%                      the context before it: for the split formats that is a
%                      small window, but for traditional *.rhd files it means
%                      also reading the preceding file, so expect about twice
%                      the I/O and up to two files in memory per worker.
%
%   Memory: one chunk plus the padding is held at a time (per worker with
%   UseParallel), but the returned
%   timestamps - and the waveforms, when asked for - accumulate for the whole
%   recording.
%
%   Conventions
%   -----------
%   Timestamps are t = (index - 1)/Fs + TimeOffset, i.e. the same convention as
%   readData's t vector and Kilosort/phy sample indices - one sample earlier
%   than the t = row/Fs convention used by detectArtifacts intervals and
%   digital-input events. INFO.index holds the 1-based rows of X, or, in
%   whole-recording mode, the 1-based sample index into the recording.
%
%   Noise/threshold estimates use the whole block, so detect on windows long
%   enough to characterize the noise (a second or more) and expect chunk-to-chunk
%   variation when streaming. Non-finite samples (e.g. NaN from
%   blankArtifacts(Fill="nan")) are excluded from the estimates and never cross
%   threshold.
%
%   INFO fields
%   -----------
%     fs, nSamples, nChan, durationSec, channelNames (when known)
%     filterApplied, band, filterOrder
%     polarity, thresholdMethod, thresholdInput
%     threshold [1 x nChan]  positive magnitude actually applied, microvolts
%     noise     [1 x nChan]  the noise estimate (NaN for percentile/absolute)
%     degenerate [1 x nChan] logical; channels with a non-positive/non-finite
%                threshold (flat or empty), forced to Inf so nothing is detected
%     align, alignWindowMs, alignWindowSamples
%     minPeriodMs, minPeriodSamples  (actual values after rounding to samples)
%     windowMs, windowSamples, waveformTimeMs [1 x nWin], waveformSource,
%     waveformsExtracted, edgeHandling
%     count [1 x nChan], rate [1 x nChan] (Hz over durationSec)
%     index {1 x nChan} 1-based rows of X, amplitude {1 x nChan} signed
%     microvolts of the filtered trace at each aligned sample
%     rejectedIndex {1 x nChan} rows cut by MaxAmplitudeUV,
%     droppedEdgeIndex {1 x nChan} rows cut by EdgeHandling="drop"
%     nEdgeWindows [1 x nChan] events whose window left the data,
%     nRejectedAmplitude [1 x nChan] events cut by MaxAmplitudeUV
%     timeOffset, maxAmplitudeUV
%
%   Whole-recording mode drops rejectedIndex/droppedEdgeIndex (they are
%   chunk-local) and adds:
%     source "recording", thresholdScope "chunk"
%     threshold / noise / degenerate as [nChunks x nChan]
%     edgePadMs, edgePadSamples  context actually carried across boundaries
%     chunks  struct array (name, sampleOffset, nSamples) of the chunks read
%     files   the chunk names, in the order read
%
%   Examples
%   --------
%     ts = ds.detectSpikes();                                  % whole recording
%     [ts, wf, info] = ds.detectSpikes(ThresholdMethod="absolute", ...
%         Threshold=60, ChannelOrder=1:16);
%     ts = ds.detectSpikes(UseParallel=true);                  % chunks on a pool
%
%     d  = ds.readData();                                      % one block
%     ts = ds.detectSpikes(d.amplifier);                       % times only
%     [ts, wf, info] = ds.detectSpikes(d.amplifier, ...        % + waveforms
%         Band=[300 6000], Threshold=4.5, MinPeriodMs=1.5);
%     plot(info.waveformTimeMs, wf{1}(1:50,:).');
%
%   Any microvolt matrix works, with or without a real recording folder:
%     ts = EphysDataset().detectSpikes(X, Fs=30000);
%
%   Requires the Signal Processing Toolbox when Filter is true (BUTTER,
%   FILTFILT, through filterContinuous).
%
%   See also EphysDataset.filterContinuous, EphysDataset.detectArtifacts,
%   EphysDataset.streamPlan, EphysDataset.readData.

arguments
    obj (1,1) EphysDataset
    X double = []
    opts.Filter (1,1) logical = true
    opts.Band (1,2) double {mustBePositive} = [500 5000]
    opts.FilterOrder (1,1) double {mustBeInteger, mustBePositive} = 4
    opts.Polarity (1,1) string {mustBeMember(opts.Polarity, ...
        ["negative","positive","both"])} = "negative"
    opts.ThresholdMethod (1,1) string {mustBeMember(opts.ThresholdMethod, ...
        ["mad","std","rms","percentile","absolute"])} = "mad"
    opts.Threshold (1,1) double = NaN
    opts.Align (1,1) string {mustBeMember(opts.Align, ...
        ["trough","peak","extremum","none"])} = "trough"
    opts.AlignWindowMs (1,1) double {mustBeNonnegative} = 1
    opts.MinPeriodMs (1,1) double {mustBeNonnegative} = 1
    opts.MaxAmplitudeUV (1,1) double {mustBePositive} = Inf
    opts.Waveforms = []          % [] -> extract when a second output is requested
    opts.WindowMs (1,2) double = [-0.5 1.5]
    opts.WaveformSource (1,1) string {mustBeMember(opts.WaveformSource, ...
        ["filtered","raw"])} = "filtered"
    opts.EdgeHandling (1,1) string {mustBeMember(opts.EdgeHandling, ...
        ["nan","drop"])} = "nan"
    opts.Fs (1,1) double = NaN
    opts.TimeOffset (1,1) double = 0
    % --- whole-recording mode only (X omitted) ---
    opts.Files (1,:) string = string.empty(1,0)
    opts.ChannelOrder (1,:) double {mustBeInteger, mustBePositive} = []
    opts.MaxChunkSamples (1,1) double = NaN
    opts.EdgePadMs (1,1) double = NaN
    opts.ProgressFcn = []
    opts.UseParallel (1,1) logical = false
end

if isempty(opts.Waveforms)
    doWave = nargout >= 2;
else
    doWave = logical(opts.Waveforms);
end

streamOnly = ["Files" "ChannelOrder" "MaxChunkSamples" "EdgePadMs" "ProgressFcn" ...
              "UseParallel"];

if ~isempty(X)
    % ---- block mode: detect on the matrix the caller handed us -------------
    given = streamOnly([~isempty(opts.Files), ~isempty(opts.ChannelOrder), ...
        ~isnan(opts.MaxChunkSamples), ~isnan(opts.EdgePadMs), ...
        ~isempty(opts.ProgressFcn), opts.UseParallel]);
    if ~isempty(given)
        error('EphysDataset:detectSpikes:BlockOption', ...
            ['%s appl%s only when detecting over a whole recording ' ...
             '(ds.detectSpikes() with no data block).'], ...
            strjoin(given, ', '), ternaryStr(isscalar(given), "ies", "y"));
    end
    [ts, wf, info] = detectBlock(obj, X, opts, doWave);
    return
end

% ---- whole-recording mode ----------------------------------------------
if ~isempty(opts.ProgressFcn) && ~isa(opts.ProgressFcn, 'function_handle')
    error('EphysDataset:detectSpikes:ProgressFcn', ...
        'ProgressFcn must be a function handle or [].');
end
if obj.Folder == ""
    error('EphysDataset:detectSpikes:NoData', ...
        ['ds.detectSpikes() with no data block needs a recording folder, and ' ...
         'this dataset has none. Pass the microvolt matrix: ds.detectSpikes(X).']);
end
if ~isnan(opts.Fs)
    error('EphysDataset:detectSpikes:FsNotAllowed', ...
        ['Fs cannot be set when detecting over a whole recording; the sample ' ...
         'rate comes from the file headers. Pass a data block to override it.']);
end
if obj.NumFiles == 0
    obj.discoverFiles();
end
if obj.NumFiles == 0
    error('EphysDataset:detectSpikes:NoFiles', 'No Intan files in %s', obj.Folder);
end
if isnan(obj.Fs) || isempty(obj.PerFile)
    obj.refreshMetadata();
end
Fs = obj.Fs;
if isnan(Fs) || Fs <= 0
    error('EphysDataset:detectSpikes:NoFs', ...
        'Sample rate unknown for %s; run refreshMetadata first.', obj.Folder);
end

% Options handed to the per-chunk detector. The streaming-only ones are dropped,
% the rate is pinned to the header rate, and TimeOffset is applied once at the
% end (each chunk is detected in its own sample frame).
blockOpts = rmfield(opts, cellstr(streamOnly));
blockOpts.Fs = Fs;
blockOpts.TimeOffset = 0;

% Context carried across chunk boundaries: enough for filter settling plus
% whatever the alignment window, the waveform window and the minimum detection
% period need, so a boundary never truncates any of them.
padMs = opts.EdgePadMs;
if isnan(padMs); padMs = 10; end
mustBeNonnegative(padMs)
w0 = round(opts.WindowMs(1) * 1e-3 * Fs);
w1 = round(opts.WindowMs(2) * 1e-3 * Fs);
minPerSamp = max(1, round(opts.MinPeriodMs * 1e-3 * Fs));
pad = max([1, round(padMs * 1e-3 * Fs), ...
           max(0, round(opts.AlignWindowMs * 1e-3 * Fs)), ...
           minPerSamp, abs(w0), abs(w1)]);

plan = obj.streamPlan(Files=opts.Files, MaxChunkSamples=opts.MaxChunkSamples);
nChunks = numel(plan);

% A flat channel would warn once per chunk; collect and report it once instead.
wstate = warning('off', 'EphysDataset:detectSpikes:DegenerateThreshold');
restoreWarning = onCleanup(@() warning(wstate));

useParallel = false;
if opts.UseParallel && nChunks > 1
    [useParallel, whyNot] = parallelAvailable(plan);
    if ~useParallel
        warning('EphysDataset:detectSpikes:SerialFallback', ...
            'UseParallel ignored (%s); detecting chunks serially.', whyNot);
    end
end

% One result per chunk (empty for chunks that held no amplifier data), in
% recording order. Each holds the events that chunk finalized plus the events it
% held back for the next chunk; only the last chunk's held-back events are kept.
R = cell(1, nChunks);

if useParallel
    % Every chunk's position in the recording is known from the plan, so each
    % worker reads its own context (the up-to-2*pad samples before the chunk)
    % instead of receiving it from the previous iteration. The blocks, and hence
    % the result, are identical to the serial loop below.
    starts = [0 cumsum([plan.nSamples])];
    progQ  = [];
    if ~isempty(opts.ProgressFcn)
        progQ = parallel.pool.DataQueue;
        progFcn = opts.ProgressFcn;
        afterEach(progQ, @(i) progFcn(i, nChunks, plan(i).name));
    end
    chanOrder = opts.ChannelOrder;
    parfor i = 1:nChunks
        R{i} = parallelChunk(obj, plan, i, starts(i), pad, chanOrder, ...
            blockOpts, doWave);
        if ~isempty(progQ)
            send(progQ, i); %#ok<PFBNS>
        end
    end
else
    consumed = 0;       % samples read so far = 0-based index of the next sample
    tail     = [];      % trailing samples of the previous chunk, kept as context
    nChan    = NaN;
    for i = 1:nChunks
        if ~isempty(opts.ProgressFcn)
            opts.ProgressFcn(i, nChunks, plan(i).name);
        end

        Xc = readChunk(obj, plan(i), opts.ChannelOrder);
        if isempty(Xc)
            continue
        end
        if isnan(nChan)
            nChan = size(Xc, 2);
            tail  = zeros(0, nChan);
        elseif size(Xc, 2) ~= nChan
            error('EphysDataset:detectSpikes:ChannelMismatch', ...
                'Chunk "%s" has %d channels; earlier chunks had %d.', ...
                plan(i).name, size(Xc, 2), nChan);
        end

        B = [tail; Xc];
        R{i} = detectChunk(obj, B, plan(i).name, consumed, size(tail, 1), ...
            pad, blockOpts, doWave);

        consumed = consumed + size(Xc, 1);
        tail     = B(max(1, size(B,1) - 2*pad + 1):end, :);
    end
end

R = [R{:}];
nProcessed = numel(R);
if nProcessed == 0
    error('EphysDataset:detectSpikes:NoAmplifierData', ...
        'No amplifier data was read from %s.', obj.Folder);
end
nChan = R(1).nChan;
bad = find([R.nChan] ~= nChan, 1);
if ~isempty(bad)
    error('EphysDataset:detectSpikes:ChannelMismatch', ...
        'Chunk "%s" has %d channels; earlier chunks had %d.', ...
        R(bad).name, R(bad).nChan, nChan);
end

infoRef   = R(1).info;
thrAll    = vertcat(R.threshold);
noiseAll  = vertcat(R.noise);
degAll    = vertcat(R.degenerate);
chunkInfo = struct('name', {R.name}, 'sampleOffset', {R.sampleOffset}, ...
    'nSamples', {R.nSamples});

% The last chunk's held-back tail has no following chunk to give it right-hand
% context - the recording ends there - so it is reported as detected.
lastR = R(end);
nRejAmp   = sum(vertcat(R.nRej), 1)  + lastR.pendRej;
nDropEdge = sum(vertcat(R.nDrop), 1) + lastR.pendDrop;
idxAcc = cell(1, nChan); ampAcc = cell(1, nChan); wfAcc = cell(1, nChan);
for c = 1:nChan
    idxAcc{c} = [arrayfun(@(r) r.idx{c}, R, 'UniformOutput', false), lastR.pendIdx(c)];
    ampAcc{c} = [arrayfun(@(r) r.amp{c}, R, 'UniformOutput', false), lastR.pendAmp(c)];
    if doWave
        wfAcc{c} = [arrayfun(@(r) r.wf{c}, R, 'UniformOutput', false), lastR.pendWf(c)];
    end
end
nSamplesTotal = lastR.sampleOffset + lastR.nSamples;
ts    = cell(1, nChan);
wf    = cell(1, nChan);
sIdx  = cell(1, nChan);
sAmp  = cell(1, nChan);
count = zeros(1, nChan);
nEdge = zeros(1, nChan);
for c = 1:nChan
    idx = vertcat(idxAcc{c}{:});
    amp = vertcat(ampAcc{c}{:});
    if isempty(idx); idx = zeros(0,1); amp = zeros(0,1); end
    W = [];
    if doWave
        W = vertcat(wfAcc{c}{:});
    end
    % The finalized regions tile the recording in order, so idx is already
    % sorted; re-apply the minimum detection period across the joins (within a
    % chunk the detector has already enforced it).
    if ~isempty(idx)
        keep = true(numel(idx), 1);
        last = -Inf;
        for k = 1:numel(idx)
            if idx(k) - last >= minPerSamp
                last = idx(k);
            else
                keep(k) = false;
            end
        end
        idx = idx(keep);
        amp = amp(keep);
        if doWave; W = W(keep, :); end
    end
    if doWave
        wf{c} = W;
        % Only the very start/end of the recording can truncate a window now.
        nEdge(c) = nDropEdge(c) + nnz(idx + w0 < 1 | idx + w1 > nSamplesTotal);
    end
    ts{c}    = (idx - 1) / Fs + opts.TimeOffset;
    sIdx{c}  = idx;
    sAmp{c}  = amp;
    count(c) = numel(idx);
end

% Channel names follow ChannelOrder, like the data columns.
channelNames = obj.ChannelNames;
if ~isempty(opts.ChannelOrder)
    if numel(channelNames) >= max(opts.ChannelOrder)
        channelNames = channelNames(opts.ChannelOrder);
    else
        channelNames = string.empty(1, 0);
    end
end
if numel(channelNames) ~= nChan
    channelNames = string.empty(1, 0);
end

durationSec = nSamplesTotal / Fs;

info = rmfield(infoRef, {'rejectedIndex', 'droppedEdgeIndex'});
info.source         = "recording";
info.nSamples       = nSamplesTotal;
info.nChan          = nChan;
info.durationSec    = durationSec;
info.channelNames   = channelNames;
info.thresholdScope = "chunk";
info.threshold      = thrAll;
info.noise          = noiseAll;
info.degenerate     = logical(degAll);
info.count          = count;
if durationSec > 0
    info.rate = count / durationSec;
else
    info.rate = nan(1, nChan);
end
info.index              = sIdx;
info.amplitude          = sAmp;
info.nEdgeWindows       = nEdge;
info.nRejectedAmplitude = nRejAmp;
info.timeOffset         = opts.TimeOffset;
info.edgePadSamples     = pad;
info.edgePadMs          = 1e3 * pad / Fs;
info.chunks             = chunkInfo;
info.files              = string({plan.name});

clear restoreWarning     % restore the warning state before the summary below
degAny = any(logical(degAll), 1);
if any(degAny)
    warning('EphysDataset:detectSpikes:DegenerateThreshold', ...
        ['Non-positive or non-finite threshold on channel(s) %s in at least one ' ...
         'chunk (flat or empty signal); no spikes detected there.'], ...
        mat2str(find(degAny)));
end
end


function s = ternaryStr(cond, a, b)
%ternaryStr  Pick one of two strings (plural agreement in the option guard).
if cond; s = a; else; s = b; end
end


function X = readChunk(obj, chunk, chanOrder)
%readChunk  One streaming chunk in microvolts, with ChannelOrder applied.
X = obj.readChunkUV(chunk);      % [nSamp x nChan] microvolts, all channels
if isempty(X) || isempty(chanOrder)
    return
end
if max(chanOrder) > size(X, 2)
    error('EphysDataset:detectSpikes:BadChannelOrder', ...
        'ChannelOrder references channel %d but the recording has %d.', ...
        max(chanOrder), size(X, 2));
end
X = X(:, chanOrder);
end


function R = detectChunk(obj, B, name, chunkFirst0, nCtx, pad, blockOpts, doWave)
%detectChunk  Detect on one context-prefixed chunk and split its events.
%   B is [nCtx rows of the preceding recording; the chunk], chunkFirst0 the
%   0-based recording index of the chunk's first sample. Events in rows this
%   chunk finalizes go to idx/amp/wf/nRej/nDrop; events in the last pad samples
%   (held back as the next chunk's context) go to the pend* fields, which the
%   caller keeps only for the final chunk. Indices are recording-global 1-based.
n       = size(B, 1) - nCtx;
nChan   = size(B, 2);
first0  = chunkFirst0 - nCtx;                    % 0-based index of B(1)
total0  = chunkFirst0 + n;                       % samples read including this chunk
rep0    = chunkFirst0 - min(pad, chunkFirst0);   % first sample not yet finalized
rowLo   = rep0 - first0 + 1;                     % rows of B finalized by this chunk
rowHi   = total0 - min(pad, total0) - first0;

[~, wfB, infoB] = detectBlock(obj, B, blockOpts, doWave);

R = struct('name', name, 'sampleOffset', chunkFirst0, 'nSamples', n, ...
    'nChan', nChan, 'threshold', infoB.threshold, 'noise', infoB.noise, ...
    'degenerate', infoB.degenerate);
[R.idx, R.amp, R.wf, R.pendIdx, R.pendAmp, R.pendWf] = deal(cell(1, nChan));
[R.nRej, R.nDrop, R.pendRej, R.pendDrop] = deal(zeros(1, nChan));
for c = 1:nChan
    iB  = infoB.index{c};
    fin = iB >= rowLo & iB <= rowHi;             % finalized now
    pen = iB > rowHi;                            % deferred to the next chunk
    R.idx{c}     = iB(fin) + first0;
    R.amp{c}     = infoB.amplitude{c}(fin);
    R.pendIdx{c} = iB(pen) + first0;
    R.pendAmp{c} = infoB.amplitude{c}(pen);
    if doWave
        R.wf{c}     = wfB{c}(fin, :);
        R.pendWf{c} = wfB{c}(pen, :);
    end
    rj = infoB.rejectedIndex{c};
    R.nRej(c)    = nnz(rj >= rowLo & rj <= rowHi);
    R.pendRej(c) = nnz(rj > rowHi);
    dp = infoB.droppedEdgeIndex{c};
    R.nDrop(c)    = nnz(dp >= rowLo & dp <= rowHi);
    R.pendDrop(c) = nnz(dp > rowHi);
end

% Keep the chunk-independent info (the per-event fields are rebuilt at the end).
[infoB.index, infoB.amplitude, infoB.rejectedIndex, infoB.droppedEdgeIndex] = ...
    deal({});
R.info = infoB;
end


function R = parallelChunk(obj, plan, i, chunkFirst0, pad, chanOrder, blockOpts, doWave)
%parallelChunk  Worker body for UseParallel: read chunk i and its context.
%   The context is the last min(2*pad, chunkFirst0) samples before the chunk -
%   exactly the tail the serial loop would carry in - read from the split .dat
%   window directly, or from as many preceding *.rhd files as it spans.
wstate = warning('off', 'EphysDataset:detectSpikes:DegenerateThreshold');
restoreWarning = onCleanup(@() warning(wstate)); %#ok<NASGU>

R = [];
Xc = readChunk(obj, plan(i), chanOrder);
if isempty(Xc)
    return
end
if size(Xc, 1) ~= plan(i).nSamples
    error('EphysDataset:detectSpikes:ChunkSizeMismatch', ...
        ['Chunk "%s" holds %d samples but its header says %d, so chunk ' ...
         'positions cannot be computed up front. Use UseParallel=false.'], ...
        plan(i).name, size(Xc, 1), plan(i).nSamples);
end

nCtx = min(2*pad, chunkFirst0);
if nCtx == 0
    ctx = zeros(0, size(Xc, 2));
elseif plan(i).kind == "split"
    ctx = obj.readSplitWindow(plan(i).sampleOffset - nCtx, nCtx);
    if ~isempty(chanOrder); ctx = ctx(:, chanOrder); end
else
    parts = {};
    got = 0;
    for j = i-1:-1:1
        if plan(j).nSamples == 0; continue; end
        Xj = readChunk(obj, plan(j), chanOrder);
        if isempty(Xj); continue; end
        parts = [{Xj} parts]; %#ok<AGROW>
        got = got + size(Xj, 1);
        if got >= nCtx; break; end
    end
    ctx = vertcat(parts{:});
    if size(ctx, 2) ~= size(Xc, 2)
        error('EphysDataset:detectSpikes:ChannelMismatch', ...
            'Chunk "%s" has %d channels; earlier chunks had %d.', ...
            plan(i).name, size(Xc, 2), size(ctx, 2));
    end
    ctx = ctx(end-nCtx+1:end, :);
end

R = detectChunk(obj, [ctx; Xc], plan(i).name, chunkFirst0, nCtx, pad, ...
    blockOpts, doWave);
end


function [ok, why] = parallelAvailable(plan)
%parallelAvailable  Whether the chunks of PLAN can be detected on a pool.
ok = false;
why = "";
if any(isnan([plan.nSamples]))
    why = "chunk sample counts are unknown";
    return
end
if ~(license('test', 'Distrib_Computing_Toolbox') && exist('gcp', 'file'))
    why = "Parallel Computing Toolbox is not available";
    return
end
try
    if isempty(gcp())
        why = "no parallel pool could be opened";
        return
    end
catch ME
    why = "no parallel pool could be opened: " + ME.message;
    return
end
ok = true;
end


function [ts, wf, info] = detectBlock(obj, X, opts, doWave)
%detectBlock  Detect spikes in one in-memory [nSamples x nChan] microvolt block.
%   The detector itself: both ds.detectSpikes(X) and the whole-recording
%   streaming loop above run every block through here. doWave is explicit (the
%   caller decides whether waveforms are wanted), and the returned info.index /
%   info.rejectedIndex / info.droppedEdgeIndex are rows of X.

% ---- sample rate -------------------------------------------------------
Fs = opts.Fs;
if isnan(Fs); Fs = obj.Fs; end
if isnan(Fs) || Fs <= 0
    error('EphysDataset:detectSpikes:NoFs', ...
        'Sample rate unknown; pass opts.Fs or run refreshMetadata first.');
end

[nSamples, nChan] = size(X);
if nSamples == 1 && nChan > 1
    error('EphysDataset:detectSpikes:RowVector', ...
        ['X must be [nSamples x nChan] (time down the rows); got 1 sample on ' ...
         '%d channels. Transpose it.'], nChan);
end

% ---- option checks -----------------------------------------------------
if opts.WindowMs(1) > opts.WindowMs(2)
    error('EphysDataset:detectSpikes:BadWindow', ...
        'WindowMs must be [before after] with before <= after; got [%g %g].', ...
        opts.WindowMs(1), opts.WindowMs(2));
end

thrIn = opts.Threshold;
if isnan(thrIn)
    switch opts.ThresholdMethod
        case "percentile", thrIn = 99.9;
        case "absolute"
            error('EphysDataset:detectSpikes:NoThreshold', ...
                'ThresholdMethod "absolute" requires Threshold in microvolts.');
        otherwise,         thrIn = 4;    % mad / std / rms multiplier
    end
end
if ~isfinite(thrIn) || thrIn <= 0
    error('EphysDataset:detectSpikes:BadThreshold', ...
        'Threshold must be finite and positive; got %g.', thrIn);
end
if opts.ThresholdMethod == "percentile" && thrIn > 100
    error('EphysDataset:detectSpikes:BadPercentile', ...
        'Threshold must be a percentile in (0 100] for ThresholdMethod "percentile"; got %g.', thrIn);
end

% ---- filtering ---------------------------------------------------------
if opts.Filter
    if opts.Band(1) >= opts.Band(2)
        error('EphysDataset:detectSpikes:BadBand', ...
            'Band must be [low high] with low < high; got [%g %g].', ...
            opts.Band(1), opts.Band(2));
    end
    if opts.Band(2) >= Fs/2
        error('EphysDataset:detectSpikes:BandAboveNyquist', ...
            ['Band upper edge (%g Hz) must be below Nyquist (%g Hz). Lower Band ' ...
             'or set Filter=false.'], opts.Band(2), Fs/2);
    end
    Xf = obj.filterContinuous(X, Type="bandpass", Cutoff=opts.Band, ...
        Order=opts.FilterOrder, Fs=Fs);
else
    Xf = X;
end

% Waveforms are cut from the filtered trace unless the raw one was asked for.
if opts.WaveformSource == "raw"
    Xw = X;
else
    Xw = Xf;
end

% ---- sample-domain parameters (report what rounding actually gave) -----
w0        = round(opts.WindowMs(1)   * 1e-3 * Fs);
w1        = round(opts.WindowMs(2)   * 1e-3 * Fs);
offs      = w0:w1;                                  % [1 x nWin]
alignSamp = max(0, round(opts.AlignWindowMs * 1e-3 * Fs));
minPerSamp = max(1, round(opts.MinPeriodMs  * 1e-3 * Fs));


% ---- per-channel thresholds -------------------------------------------
thr        = inf(1, nChan);
noise      = nan(1, nChan);
degenerate = false(1, nChan);
for c = 1:nChan
    x  = Xf(:, c);
    xv = x(isfinite(x));                 % noise estimates ignore NaN/Inf
    if isempty(xv)
        degenerate(c) = true;
        continue
    end
    switch opts.ThresholdMethod
        case "mad"
            noise(c) = median(abs(xv - median(xv))) / 0.6745;
            thr(c)   = thrIn * noise(c);
        case "std"
            noise(c) = std(xv);
            thr(c)   = thrIn * noise(c);
        case "rms"
            noise(c) = sqrt(mean(xv.^2));
            thr(c)   = thrIn * noise(c);
        case "percentile"
            thr(c)   = localPercentile(abs(xv), thrIn);
        case "absolute"
            thr(c)   = thrIn;
    end
    if ~isfinite(thr(c)) || thr(c) <= 0
        degenerate(c) = true;
        thr(c) = Inf;                    % detect nothing rather than everything
    end
end
if any(degenerate)
    warning('EphysDataset:detectSpikes:DegenerateThreshold', ...
        ['Non-positive or non-finite threshold on channel(s) %s (flat or empty ' ...
         'signal); no spikes detected there.'], mat2str(find(degenerate)));
end

% ---- detection ---------------------------------------------------------
ts     = cell(1, nChan);
wf     = cell(1, nChan);
sIdx   = cell(1, nChan);
sAmp   = cell(1, nChan);
rejIdx = repmat({zeros(0,1)}, 1, nChan);
dropIdx = repmat({zeros(0,1)}, 1, nChan);
count  = zeros(1, nChan);
nEdge  = zeros(1, nChan);
nRejAmp = zeros(1, nChan);

for c = 1:nChan
    xf = Xf(:, c);

    switch opts.Polarity                 % NaN never satisfies these
        case "negative", over = xf < -thr(c);
        case "positive", over = xf >  thr(c);
        case "both",     over = abs(xf) > thr(c);
    end

    d   = diff([0; double(over); 0]);
    on  = find(d ==  1);                 % first sample of each run
    off = find(d == -1) - 1;             % last sample of each run

    % Align each crossing to its extremum (min/max/|max|) in the search window,
    % which spans the run plus AlignWindowMs from the crossing.
    idx = zeros(numel(on), 1);
    for k = 1:numel(on)
        s = on(k);
        e = min(nSamples, max(off(k), s + alignSamp));
        switch opts.Align
            case "trough",   [~, jx] = min(xf(s:e));
            case "peak",     [~, jx] = max(xf(s:e));
            case "extremum", [~, jx] = max(abs(xf(s:e)));
            otherwise,       jx = 1;     % "none": the crossing sample itself
        end
        idx(k) = s + jx - 1;
    end

    % Minimum detection period: greedy, keeping the earlier of two close events.
    if ~isempty(idx)
        idx  = sort(idx);
        keep = true(numel(idx), 1);
        last = -Inf;
        for k = 1:numel(idx)
            if idx(k) - last >= minPerSamp
                last = idx(k);
            else
                keep(k) = false;
            end
        end
        idx = idx(keep);
    end

    amp = xf(idx);

    % Amplitude ceiling (artifact rejection)
    if isfinite(opts.MaxAmplitudeUV) && ~isempty(idx)
        bad = abs(amp) > opts.MaxAmplitudeUV;
        nRejAmp(c) = nnz(bad);
        rejIdx{c}  = idx(bad);
        idx = idx(~bad);
        amp = amp(~bad);
    end

    % Waveforms
    if doWave
        I     = idx + offs;              % [nEvents x nWin], implicit expansion
        inRng = I >= 1 & I <= nSamples;
        whole = all(inRng, 2);           % windows fully inside the block
        nEdge(c) = nnz(~whole);
        if opts.EdgeHandling == "drop" && any(~whole)
            dropIdx{c} = idx(~whole);
            idx   = idx(whole);
            amp   = amp(whole);
            I     = I(whole, :);
            inRng = inRng(whole, :);
        end
        W   = nan(size(I));              % padding for windows past the edges
        src = Xw(:, c);
        W(inRng) = src(I(inRng));
        wf{c} = W;
    end

    ts{c}    = (idx - 1) / Fs + opts.TimeOffset;
    sIdx{c}  = idx;
    sAmp{c}  = amp;
    count(c) = numel(idx);
end

% ---- info --------------------------------------------------------------
durationSec = nSamples / Fs;

info = struct();
info.fs            = Fs;
info.nSamples      = nSamples;
info.nChan         = nChan;
info.durationSec   = durationSec;
if numel(obj.ChannelNames) == nChan
    info.channelNames = obj.ChannelNames;
else
    info.channelNames = string.empty(1, 0);
end
info.filterApplied = opts.Filter;
info.band          = opts.Band;
info.filterOrder   = opts.FilterOrder;
info.polarity        = opts.Polarity;
info.thresholdMethod = opts.ThresholdMethod;
info.thresholdInput  = thrIn;
info.threshold       = thr;
info.noise           = noise;
info.degenerate      = degenerate;
info.align               = opts.Align;
info.alignWindowMs       = 1e3 * alignSamp / Fs;
info.alignWindowSamples  = alignSamp;
info.minPeriodMs         = 1e3 * minPerSamp / Fs;
info.minPeriodSamples    = minPerSamp;
info.windowMs          = 1e3 * [w0 w1] / Fs;
info.windowSamples     = [w0 w1];
info.waveformTimeMs    = 1e3 * offs / Fs;
info.waveformSource    = opts.WaveformSource;
info.waveformsExtracted = doWave;
info.edgeHandling      = opts.EdgeHandling;
info.count  = count;
if durationSec > 0
    info.rate = count / durationSec;
else
    info.rate = nan(1, nChan);
end
info.index     = sIdx;
info.amplitude = sAmp;
info.rejectedIndex   = rejIdx;
info.droppedEdgeIndex = dropIdx;
info.nEdgeWindows       = nEdge;
info.nRejectedAmplitude = nRejAmp;
info.maxAmplitudeUV     = opts.MaxAmplitudeUV;
info.timeOffset         = opts.TimeOffset;
end


function v = localPercentile(x, p)
% Linear-interpolation percentile of a vector, matching PRCTILE's convention
% (sample i of n sits at percentile 100*(i-0.5)/n) without the Statistics
% Toolbox. x must already have its non-finite values removed.
x = sort(x(:));
n = numel(x);
if n == 0
    v = NaN;
    return
end
r = p / 100 * n - 0.5;            % 0-based position among the sorted samples
if r <= 0
    v = x(1);
elseif r >= n - 1
    v = x(n);
else
    lo = floor(r);
    v  = x(lo + 1) + (r - lo) * (x(lo + 2) - x(lo + 1));
end
end
