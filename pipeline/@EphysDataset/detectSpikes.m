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
%     Filter        filter before detecting (default true). With false the
%                   raw trace is detected on, and the crossings are tested
%                   relative to each channel's median (its baseline,
%                   INFO.center), which the filter would have removed; the
%                   amplitudes and waveforms stay the trace's values
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
%     Align         "auto" (default): the extremum Polarity looks for, the
%                   trough for "negative", the peak for "positive", the
%                   extremum for "both" | "trough" (local minimum) | "peak"
%                   (local maximum) | "extremum" (largest |x|) | "none" (the
%                   first threshold-crossing sample). The aligned sample is
%                   both the timestamp and the waveform center; INFO.align
%                   names the one used.
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
%   Coincident events (one spike seen on several neighboring sites)
%     Coincidence   "none" (default): every channel on its own | "remove":
%                   keep each spike once, on the site where it is largest |
%                   "tag": keep every copy and number them (info.eventId,
%                   info.primary). Two events are copies of one spike when
%                   their sites lie within CoincidenceRadiusUm of each other
%                   and their aligned samples (the troughs, with Align
%                   "trough") within CoincidenceJitterMs. Going from the
%                   largest |amplitude| down (the deepest trough first), an
%                   event no larger one has claimed is the spike's primary
%                   and claims its copies, so every copy lies within the
%                   radius and the jitter of its primary.
%     CoincidenceRadiusUm
%                   neighbor distance between sites, in um (default 50)
%     CoincidenceJitterMs
%                   the most two copies' aligned samples may differ by
%                   (default 0.5 ms); events further apart are separate
%                   spikes
%     SitePositions [nChan x 2] x and y in um of each channel's site, one
%                   row per column of X (per channel of ChannelOrder in
%                   whole-recording mode), as EphysDataset.channelLayout
%                   gives them; NaN = off the probe (never a neighbor).
%                   Required unless Coincidence is "none".
%   Coincident events are found after the minimum detection period and the
%   amplitude ceiling, over the whole recording at once in whole-recording
%   mode (chunk joins play no part).
%
%   Waveforms
%     Waveforms     [] (default): extract when a second output is requested;
%                   true: extract even with one output; false: never extract
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
%     GroupChannels channels filtered and detected at a time (default NaN =
%                   automatic: about 64 MB of the block per group, at least 8
%                   channels; a group is never a lone column). The result does
%                   not depend on it; only the memory held at once does (a few
%                   group-sized copies on top of the block, not several copies
%                   of the whole block)
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
%   Thresholds are estimated PER CHUNK by default (ThresholdScope "chunk";
%   info.thresholdScope): the noise estimate of a chunk uses only that
%   chunk's samples, as it does for a block, so the threshold varies from
%   chunk to chunk with the noise, and with how the recording happens to be
%   split into files. info.threshold / info.noise / info.degenerate are then
%   [nChunks x nChan].
%
%   With ThresholdScope "recording", each channel gets one threshold from
%   its noise over the WHOLE recording: a first pass streams the recording
%   as detection does (the same chunks, context, artifact erasing and
%   band-pass) and counts every sample once, then detection runs with those
%   thresholds. The thresholds then follow neither the file layout nor each
%   chunk's noise (only the band-pass's settling at chunk joins, ~0.01 uV,
%   reaches them), and a session's thresholds compare with another's. "std"
%   and "rms" are exact; "mad" (median and median absolute deviation) and
%   "percentile" come from a histogram of 0.05 uV bins over +/-2000 uV
%   (info.noiseEstimate says so): a percentile lies within one bin of the
%   sample it estimates (the ceil(p*n)-th smallest |x|), and the noise
%   level from the median and MAD within ~0.1% of the exact value on a
%   band-passed trace, within ~0.2 uV on an unfiltered one (whose samples
%   sit on the recording's steps, 0.195 uV for Intan, so its exact median
%   and MAD are quantized too). A channel whose statistic lies beyond the
%   range, or within one bin of 0, is left degenerate. The first pass reads the
%   recording once more, chunk after chunk (UseParallel applies to the
%   detection pass only). info.threshold / info.noise / info.degenerate are
%   then [1 x nChan]. "absolute" thresholds are the same either way.
%
%   Extra options, accepted only in this mode
%     ThresholdScope   (1,1) string  "chunk" (default: each chunk's own noise)
%                      | "recording" (each channel's noise over the whole
%                      recording; see above)
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
%                      alignment window, the minimum detection period and,
%                      when filtering, 4 periods of the band's low edge, over
%                      which the band-pass settles: 40 ms for Band(1) = 100 Hz)
%     ProgressFcn      function handle  ProgressFcn(i, nChunks, chunkName),
%                      called before each chunk (serial) or on the client as
%                      each chunk finishes (UseParallel; i is then the number
%                      of chunks done and chunkName the one just finished)
%     UseParallel      (1,1) logical  detect the chunks on a process pool
%                      (default false): the open pool when there is one,
%                      otherwise a pool sized to the worker cap. The result is
%                      identical to the serial one. Needs the Parallel
%                      Computing Toolbox and the sample count of every chunk
%                      up front (always known for the split formats; from the
%                      *.rhd headers otherwise); when either is missing, or a
%                      thread pool is open, a warning is issued and the chunks
%                      run serially. Each worker reads its own chunk plus the
%                      context before it: for the split formats that is a
%                      small window, but for traditional *.rhd files it means
%                      also reading the preceding file, so expect about twice
%                      the I/O and up to two files in memory per worker.
%     MaxWorkers       (1,1) double  cap on chunks in flight at once (default
%                      NaN = automatic). The cap is always limited by free
%                      memory - the chunk and a few channel-group copies of it
%                      per worker, about 2 to 2.6 chunks for 64 channels (1.9
%                      GB for a 60 s chunk) - so memory rarely holds back a
%                      12-worker pool.
%     RejectIntervals (:,2) double  periods whose events are dropped after
%                      detection (default none), [tStart tEnd) seconds on the
%                      clock of the timestamps: the recording is detected on
%                      as read, and an event whose aligned sample lies in a
%                      period is removed before the coincident copies are
%                      found, so an artifact never claims a real spike on a
%                      neighboring site as its copy. Counted in
%                      INFO.nRejectedArtifact. spikesToMat(ArtifactMode=
%                      "reject") passes them
%     ArtifactIntervals (:,2) double  artifact periods erased before
%                      detection (default none): [tStart tEnd) seconds on the
%                      clock of the returned timestamps (the recording's,
%                      TimeOffset aside), as EphysDataset.artifactIntervals
%                      gives them. The samples they cover
%                      (EphysDataset.artifactSamples, those the .bin and
%                      spike rejection take) are set to NaN in every chunk
%                      read, context included, so they stay out of the noise
%                      estimates, never cross threshold, and the band-pass
%                      runs a line across them (see Conventions): an
%                      artifact cannot ring into its neighbors or raise the
%                      threshold. Reported in INFO.artifacts.
%
%   Memory: one chunk plus the padding is held at a time (per worker with
%   UseParallel), and the filter and the detector work on a group of its
%   channels at a time (GroupChannels), so the peak is the chunk plus a few
%   group-sized copies: about 2.2 chunks for 64 channels, where filtering the
%   whole chunk at once held 5 to 8. The returned
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
%   threshold; the band-pass sees them as a straight line between the finite
%   samples around them (held flat at the ends), so they do not ring into
%   their neighbors, and they are NaN again in the filtered trace.
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
%     center [1 x nChan] the median each channel's crossings were tested
%     relative to (0 with Filter true)
%     rejectedIndex {1 x nChan} rows cut by MaxAmplitudeUV,
%     droppedEdgeIndex {1 x nChan} rows cut by EdgeHandling="drop"
%     nEdgeWindows [1 x nChan] events whose window left the data,
%     nRejectedAmplitude [1 x nChan] events cut by MaxAmplitudeUV
%     timeOffset, maxAmplitudeUV
%     coincidence  mode, radiusUm, jitterMs and jitterSamples (as rounded
%                  to samples; NaN for "none"), positions [nChan x 2] um,
%                  neighbors {1 x nChan} (the channels within the radius of
%                  each) and nCopies [1 x nChan] (events found to be a copy
%                  of a larger one on a neighbor: removed with "remove",
%                  kept with "tag"). With "remove", index, amplitude,
%                  count, rate and nEdgeWindows describe the events kept.
%     eventId {1 x nChan}, primary {1 x nChan}  ("tag" only) per event: the
%                  number its spike has (1, 2, ... in time order over every
%                  channel), shared by the primary and its copies, and true
%                  for the primary
%
%   Whole-recording mode drops rejectedIndex/droppedEdgeIndex (they are
%   chunk-local) and adds:
%     source "recording", thresholdScope "chunk" | "recording"
%     threshold / noise / degenerate as [nChunks x nChan] ("chunk") or
%             [1 x nChan] ("recording")
%     noiseEstimate  how the recording-wide noise was measured ([] for
%             "chunk", and for "absolute", which measures nothing): method,
%             estimator ("exact" for std / rms, "histogram" for mad /
%             percentile), binUV and rangeUV (the histogram; NaN when
%             exact), nSamples [1 x nChan] samples counted, nOutOfRange
%             [1 x nChan] of them beyond +/-rangeUV (counted, not placed),
%             beyondRange [1 x nChan] (the statistic lies beyond
%             +/-rangeUV: warning EphysDataset:detectSpikes:NoiseBeyondRange)
%             and belowResolution [1 x nChan] (a MAD or percentile below
%             one bin, a flat channel: noise NaN). Both leave the channel
%             degenerate.
%     edgePadMs, edgePadSamples  context actually carried across boundaries
%     chunks  struct array (name, sampleOffset, nSamples, startSec) of the
%             chunks read; startSec is the time of the chunk's first sample on
%             the clock of the timestamps
%     chunkThreshold  what each chunk was detected against and found, for a
%             QC plot over time (stairs(c.startSec, c.threshold) shows the
%             steps at file boundaries): startSec and durationSec
%             [nChunks x 1], threshold, noise, degenerate, count and rate
%             [nChunks x nChan] - the threshold and noise applied in the
%             chunk (the recording-wide ones, repeated, with ThresholdScope
%             "recording"), whether the channel was degenerate there, and the
%             events kept in its samples (after the minimum period, the
%             amplitude ceiling, RejectIntervals and Coincidence) with their
%             rate in Hz
%     files   the chunk names, in the order read
%     artifacts  the ArtifactIntervals erased: intervals (merged; zeros(0,2)
%             for none) and nSamples (recording samples set to NaN)
%     nRejectedArtifact [1 x nChan] events dropped for lying in a
%             RejectIntervals period (zeros without any)
%     options  every option as run (but ProgressFcn, ArtifactIntervals and
%             RejectIntervals),
%             with Fs and EdgePadMs as resolved; Threshold NaN is the
%             method's default, thresholdInput the value it stood for
%
%   Examples
%   --------
%     ts = ds.detectSpikes();                                  % whole recording
%     [ts, wf, info] = ds.detectSpikes(ThresholdMethod="absolute", ...
%         Threshold=60, ChannelOrder=1:16);
%     ts = ds.detectSpikes(UseParallel=true);                  % chunks on a pool
%     L  = ds.channelLayout();                                 % each spike once,
%     ts = ds.detectSpikes(Coincidence="remove", ...           % on its largest site
%         SitePositions=[L.x; L.y].', CoincidenceJitterMs=0.5);
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
%   EphysDataset.streamPlan, EphysDataset.readData, EphysDataset.channelLayout.

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
        ["auto","trough","peak","extremum","none"])} = "auto"
    opts.AlignWindowMs (1,1) double {mustBeNonnegative} = 1
    opts.MinPeriodMs (1,1) double {mustBeNonnegative} = 1
    opts.MaxAmplitudeUV (1,1) double {mustBePositive} = Inf
    opts.Coincidence (1,1) string {mustBeMember(opts.Coincidence, ["none","remove","tag"])} = "none"
    opts.CoincidenceRadiusUm (1,1) double {mustBePositive, mustBeFinite} = 50
    opts.CoincidenceJitterMs (1,1) double {mustBeNonnegative, mustBeFinite} = 0.5
    opts.SitePositions (:,2) double = zeros(0, 2)
    opts.Waveforms = []          % [] -> extract when a second output is requested
    opts.WindowMs (1,2) double = [-0.5 1.5]
    opts.WaveformSource (1,1) string {mustBeMember(opts.WaveformSource, ...
        ["filtered","raw"])} = "filtered"
    opts.EdgeHandling (1,1) string {mustBeMember(opts.EdgeHandling, ...
        ["nan","drop"])} = "nan"
    opts.Fs (1,1) double = NaN
    opts.TimeOffset (1,1) double = 0
    opts.GroupChannels (1,1) double = NaN
    % --- whole-recording mode only (X omitted) ---
    opts.ThresholdScope (1,1) string {mustBeMember(opts.ThresholdScope, ["chunk" "recording"])} = "chunk"
    opts.Files (1,:) string = string.empty(1,0)
    opts.ChannelOrder (1,:) double {mustBeInteger, mustBePositive} = []
    opts.MaxChunkSamples (1,1) double = NaN
    opts.EdgePadMs (1,1) double = NaN
    opts.ProgressFcn = []
    opts.UseParallel (1,1) logical = false
    opts.MaxWorkers (1,1) double = NaN
    opts.ArtifactIntervals (:,2) double {mustBeFinite} = zeros(0, 2)
    opts.RejectIntervals (:,2) double {mustBeFinite} = zeros(0, 2)
end

if opts.Align == "auto"
    % The extremum the polarity looks for: a positive crossing aligned to the
    % trough would land on the undershoot after the peak.
    switch opts.Polarity
        case "negative", opts.Align = "trough";
        case "positive", opts.Align = "peak";
        case "both",     opts.Align = "extremum";
    end
end

if ~isnan(opts.GroupChannels) && (opts.GroupChannels < 1 || opts.GroupChannels ~= round(opts.GroupChannels))
    error('EphysDataset:detectSpikes:BadGroupChannels', ...
        'GroupChannels must be a positive whole number (NaN = automatic); got %g.', opts.GroupChannels);
end

if isempty(opts.Waveforms)
    doWave = nargout >= 2;
else
    doWave = logical(opts.Waveforms);
end

streamOnly = ["Files" "ChannelOrder" "MaxChunkSamples" "EdgePadMs" "ProgressFcn" ...
              "UseParallel" "MaxWorkers" "ArtifactIntervals" "ThresholdScope" "RejectIntervals"];

if ~isequal(size(X), [0 0])   % a block with no rows is still a block, not the recording
    % ---- block mode: detect on the matrix the caller handed us -------------
    given = streamOnly([~isempty(opts.Files), ~isempty(opts.ChannelOrder), ...
        ~isnan(opts.MaxChunkSamples), ~isnan(opts.EdgePadMs), ...
        ~isempty(opts.ProgressFcn), opts.UseParallel, ~isnan(opts.MaxWorkers), ...
        ~isempty(opts.ArtifactIntervals), opts.ThresholdScope ~= "chunk", ...
        ~isempty(opts.RejectIntervals)]);
    if ~isempty(given)
        error('EphysDataset:detectSpikes:BlockOption', ...
            ['%s appl%s only when detecting over a whole recording ' ...
             '(ds.detectSpikes() with no data block).'], ...
            strjoin(given, ', '), ternaryStr(isscalar(given), "ies", "y"));
    end
    checkSitePositions(opts, size(X, 2));
    [ts, wf, info] = detectBlock(obj, X, opts, doWave);
    [ts, wf, info] = applyCoincidence(ts, wf, info, opts, doWave);
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
    error('EphysDataset:detectSpikes:NoFiles', 'No recording files in %s', obj.Folder);
end
if isnan(obj.Fs) || isempty(obj.PerFile)
    obj.refreshMetadata();
end
% Settle the common reference's channels (and the weighted CAR's state)
% before any chunk is read.
obj.prepareReference();
obj.prepareWCAR();
Fs = obj.Fs;
if isnan(Fs) || Fs <= 0
    error('EphysDataset:detectSpikes:NoFs', ...
        'Sample rate unknown for %s; run refreshMetadata first.', obj.Folder);
end
% The sites must match the channels before the recording is read.
if ~isempty(opts.ChannelOrder)
    checkSitePositions(opts, numel(opts.ChannelOrder));
elseif isfinite(obj.NumChannels)
    checkSitePositions(opts, obj.NumChannels);
end

% Options handed to the per-chunk detector. The streaming-only ones are dropped,
% the rate is pinned to the header rate, and TimeOffset is applied once at the
% end (each chunk is detected in its own sample frame).
blockOpts = rmfield(opts, cellstr(streamOnly));
blockOpts.Fs = Fs;
blockOpts.TimeOffset = 0;

% The recording samples the artifact periods cover, [first last] 1-based,
% erased (NaN) in every chunk before it is detected.
artIv = EphysDataset.mergeIntervals(opts.ArtifactIntervals);
artRuns = EphysDataset.artifactSamples(artIv, Fs, Inf);
% The recording samples of the periods whose events are dropped after detection.
rejRuns = EphysDataset.artifactSamples(EphysDataset.mergeIntervals(opts.RejectIntervals), Fs, Inf);

% Context carried across chunk boundaries: enough for filter settling plus
% whatever the alignment window, the waveform window and the minimum detection
% period need, so a boundary never truncates any of them. The band-pass rings
% for a few periods of its low edge, so a low Band(1) needs more than the
% default 10 ms: 4 periods leave a join within ~0.01 uV of the unbroken trace,
% even with a large spike right at the end of the block that is filtered.
padMs = opts.EdgePadMs;
if isnan(padMs); padMs = 10; end
mustBeNonnegative(padMs)
w0 = round(opts.WindowMs(1) * 1e-3 * Fs);
w1 = round(opts.WindowMs(2) * 1e-3 * Fs);
minPerSamp = max(1, round(opts.MinPeriodMs * 1e-3 * Fs));
settle = 0;
if opts.Filter
    settle = ceil(4 * Fs / opts.Band(1));
end
pad = max([1, round(padMs * 1e-3 * Fs), settle, ...
           max(0, round(opts.AlignWindowMs * 1e-3 * Fs)), ...
           minPerSamp, abs(w0), abs(w1)]);

plan = obj.streamPlan(Files=opts.Files, MaxChunkSamples=opts.MaxChunkSamples);
nChunks = numel(plan);

% A flat channel would warn once per chunk; collect and report it once instead.
wstate = warning('off', 'EphysDataset:detectSpikes:DegenerateThreshold');
restoreWarning = onCleanup(@() warning(wstate));

% ThresholdScope "recording": one threshold per channel, from its noise over
% the whole recording (noisePass, a first pass over the same chunks); every
% chunk is then detected against it. The option checks detectBlock makes come
% first, so a bad option stops before the pass. "absolute" needs no pass.
progress = opts.ProgressFcn;
noiseEst = [];
if opts.ThresholdScope == "recording" && opts.ThresholdMethod ~= "absolute"
    checkWindow(blockOpts);
    thrIn = thresholdInput(blockOpts);
    checkBand(blockOpts, Fs);
    passProgress = [];
    if ~isempty(progress)
        passProgress = @(i, n, name) opts.ProgressFcn(i, 2*n, "noise level: " + string(name));
        progress = @(i, n, name) opts.ProgressFcn(n + i, 2*n, name);
    end
    noiseEst = noisePass(obj, plan, pad, blockOpts, Fs, artRuns, opts.ChannelOrder, thrIn, passProgress);
    blockOpts.FixedThreshold = noiseEst.threshold;
    blockOpts.FixedNoise = noiseEst.noise;
end

pool = [];
nWorkers = 1;
if opts.UseParallel && nChunks > 1
    [pool, nWorkers] = parallelChunkPool(plan, obj.NumChannels, opts.MaxWorkers, ...
        chunkCopies(max([plan.nSamples]), obj.NumChannels, opts.GroupChannels) + wcarCopies(obj, plan), "detectSpikes");
end

% One result per chunk (empty for chunks that held no amplifier data), in
% recording order. Each holds the events that chunk finalized plus the events it
% held back for the next chunk; only the last chunk's held-back events are kept.
R = cell(1, nChunks);

if ~isempty(pool)
    % Every chunk's position in the recording is known from the plan, so each
    % worker reads its own context (the up-to-2*pad samples before the chunk)
    % instead of receiving it from the previous iteration. The blocks, and hence
    % the result, are identical to the serial loop below. mapChunks keeps at
    % most nWorkers chunks in flight and reports progress on the client.
    starts = [0 cumsum([plan.nSamples])];
    chanOrder = opts.ChannelOrder;
    % A window read gives the samples before a chunk in the recording; that is
    % the serial loop's context only when the chunks follow each other there
    % (every file, in order). A Files list that skips or reorders files is
    % given the previous listed chunk instead, as the serial loop gives it.
    offs = [plan.sampleOffset];
    contiguous = obj.supportsRandomAccess() && all(isfinite(offs)) ...
        && all(offs(2:end) == offs(1:end-1) + [plan(1:end-1).nSamples]);
    R = mapChunks(@(i) parallelChunk(obj, plan, i, starts(i), pad, chanOrder, blockOpts, doWave, contiguous, artRuns), ...
        reshape(string({plan.name}), 1, []), Pool=pool, NumWorkers=nWorkers, ...
        ProgressFcn=progress);
else
    consumed = 0;       % samples read so far = 0-based index of the next sample
    tail     = [];      % trailing samples of the previous chunk, kept as context
    nChan    = NaN;
    for i = 1:nChunks
        if ~isempty(progress)
            progress(i, nChunks, plan(i).name);
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

        % The context and the chunk are never joined into one array: the
        % detector stacks them a group of channels at a time.
        R{i} = detectChunk(obj, tail, Xc, plan(i).name, consumed, ...
            pad, blockOpts, doWave, artRuns);

        consumed = consumed + size(Xc, 1);
        tail     = lastRows(tail, Xc, 2*pad);
        Xc       = []; %#ok<NASGU>   freed before the next chunk is read
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
erasedAll = vertcat(R.erased);
chunkStart = ([R.sampleOffset] / Fs + opts.TimeOffset).';   % the time of each chunk's first sample, as the timestamps count it
chunkInfo = struct('name', {R.name}, 'sampleOffset', {R.sampleOffset}, ...
    'nSamples', {R.nSamples}, 'startSec', num2cell(chunkStart.'));

% The last chunk's held-back tail has no following chunk to give it right-hand
% context - the recording ends there - so it is reported as detected.
lastR = R(end);
nRejAmp   = sum(vertcat(R.nRej), 1)  + lastR.pendRej;
nDropEdge = sum(vertcat(R.nDrop), 1) + lastR.pendDrop;
% Each chunk's events per channel, [nChan x nChunks] cells (one reshape, not a
% call per chunk and channel).
Ridx = reshape([R.idx], nChan, []);
Ramp = reshape([R.amp], nChan, []);
Rwf  = cell(nChan, numel(R));
if doWave
    Rwf = reshape([R.wf], nChan, []);
end
nSamplesTotal = lastR.sampleOffset + lastR.nSamples;
ts    = cell(1, nChan);
wf    = cell(1, nChan);
sIdx  = cell(1, nChan);
sAmp  = cell(1, nChan);
count = zeros(1, nChan);
nEdge = zeros(1, nChan);
nRejArt = zeros(1, nChan);
for c = 1:nChan
    idx = vertcat(Ridx{c, :}, lastR.pendIdx{c});
    amp = vertcat(Ramp{c, :}, lastR.pendAmp{c});
    if isempty(idx); idx = zeros(0,1); amp = zeros(0,1); end
    W = [];
    if doWave
        W = vertcat(Rwf{c, :}, lastR.pendWf{c});
    end
    % The finalized regions tile the recording in order, so idx is already
    % sorted; re-apply the minimum detection period across the joins (within a
    % chunk the detector has already enforced it).
    if ~isempty(idx)
        keep = deadTime(idx, minPerSamp);
        if ~all(keep)
            idx = idx(keep);
            amp = amp(keep);
            if doWave; W = W(keep, :); end
        end
    end
    % RejectIntervals: the events inside a period go, before the coincident
    % copies are found below, so none of them can claim a neighbor's spike.
    if ~isempty(rejRuns) && ~isempty(idx)
        keep = ~inRuns(idx, rejRuns);
        nRejArt(c) = nnz(~keep);
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
info.thresholdScope = opts.ThresholdScope;
info.noiseEstimate  = [];
if opts.ThresholdScope == "chunk"
    info.threshold  = thrAll;
    info.noise      = noiseAll;
    info.degenerate = logical(degAll);
elseif isempty(noiseEst)
    % "absolute": the same threshold in every chunk, nothing measured; a
    % channel is degenerate only when no chunk held a sample of it.
    info.degenerate = all(logical(degAll), 1);
    info.threshold  = repmat(thresholdInput(blockOpts), 1, nChan);
    info.threshold(info.degenerate) = Inf;
    info.noise      = nan(1, nChan);
else
    info.threshold  = noiseEst.threshold;
    info.noise      = noiseEst.noise;
    info.degenerate = noiseEst.degenerate;
    info.noiseEstimate = rmfield(noiseEst, {'threshold', 'noise', 'degenerate'});
end
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
info.nRejectedArtifact  = nRejArt;
info.timeOffset         = opts.TimeOffset;
info.edgePadSamples     = pad;
info.edgePadMs          = 1e3 * pad / Fs;
info.chunks             = chunkInfo;
info.files              = string({plan.name});
info.options            = rmfield(opts, {'ProgressFcn', 'ArtifactIntervals', 'RejectIntervals'});   % every option as run
info.options.Fs         = Fs;
info.options.EdgePadMs  = info.edgePadMs;
erased = artRuns(artRuns(:, 1) <= nSamplesTotal, :);
erased(:, 2) = min(erased(:, 2), nSamplesTotal);
info.artifacts          = struct('intervals', artIv, ...
    'nSamples', sum(erased(:, 2) - erased(:, 1) + 1));
% Copies of one spike on neighboring sites, over the whole recording at once.
checkSitePositions(opts, nChan);
[ts, wf, info] = applyCoincidence(ts, wf, info, opts, doWave);
info.chunkThreshold = chunkThresholds(info, chunkStart, [R.sampleOffset], [R.nSamples], ...
    thrAll, noiseAll, degAll, Fs, nSamplesTotal);

clear restoreWarning     % restore the warning state before the summary below
if opts.ThresholdScope == "chunk"
    degAny = any(logical(degAll) & ~erasedAll, 1);   % a chunk erased whole is not a flat signal
    if any(degAny)
        warning('EphysDataset:detectSpikes:DegenerateThreshold', ...
            ['Non-positive or non-finite threshold on channel(s) %s in at least one ' ...
             'chunk (flat or empty signal); no spikes detected there.'], ...
            mat2str(find(degAny)));
    end
    return
end
beyond = false(1, nChan);
if ~isempty(noiseEst)
    beyond = noiseEst.beyondRange;
end
flat = info.degenerate & ~beyond;
if any(flat)
    warning('EphysDataset:detectSpikes:DegenerateThreshold', ...
        ['Non-positive or non-finite recording-wide threshold on channel(s) %s (flat ' ...
         'or empty signal, or a noise level below the %g uV the estimate resolves); ' ...
         'no spikes detected there.'], mat2str(find(flat)), noiseBinUV());
end
if any(beyond)
    warning('EphysDataset:detectSpikes:NoiseBeyondRange', ...
        ['The noise level of channel(s) %s lies beyond the +/-%g uV the recording-wide ' ...
         '"%s" estimate covers; no spikes detected there. ThresholdMethod "std", "rms" ' ...
         'or "absolute", or ThresholdScope "chunk", have no such limit.'], ...
        mat2str(find(beyond)), noiseRangeUV(), opts.ThresholdMethod);
end
end


function s = ternaryStr(cond, a, b)
%ternaryStr  Pick one of two strings (plural agreement in the option guard).
if cond; s = a; else; s = b; end
end


function tf = inRuns(idx, runs)
%inRuns  True for each 1-based sample in one of the sorted, disjoint RUNS ([first last]).
%   Each sample is placed by the last run starting at or before it.
k = discretize(idx, [runs(:, 1); Inf]);   % NaN before the first run
tf = ~isnan(k);
tf(tf) = idx(tf) <= runs(k(tf), 2);
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


function R = detectChunk(obj, ctx, Xc, name, chunkFirst0, pad, blockOpts, doWave, artRuns)
%detectChunk  Detect on one chunk with the context before it and split its events.
%   The block detected is B = [CTX; XC]: CTX the rows of the preceding
%   recording, XC the chunk (kept apart; detectBlock stacks them a group of
%   channels at a time, so B is never held whole). chunkFirst0 is the 0-based
%   recording index of the chunk's first sample. The rows the
%   artifact runs ARTRUNS ([first last] 1-based recording samples) cover are
%   erased (NaN) first, context included. Events in rows this
%   chunk finalizes go to idx/amp/wf/nRej/nDrop; events in the last pad samples
%   (held back as the next chunk's context) go to the pend* fields, which the
%   caller keeps only for the final chunk. Indices are recording-global 1-based.
nCtx    = size(ctx, 1);
n       = size(Xc, 1);
nChan   = size(Xc, 2);
first0  = chunkFirst0 - nCtx;                    % 0-based index of B(1)
total0  = chunkFirst0 + n;                       % samples read including this chunk
rep0    = chunkFirst0 - min(pad, chunkFirst0);   % first sample not yet finalized
rowLo   = rep0 - first0 + 1;                     % rows of B finalized by this chunk
rowHi   = total0 - min(pad, total0) - first0;

% The artifact periods are erased from B (NaN stays out of the noise
% estimates, never crosses threshold, and the band-pass runs a line across
% it): detectBlock does it on each group of channels it takes.
blockOpts.EraseRows = rowRuns(nCtx + n, first0, artRuns);

[~, wfB, infoB, erased] = detectBlock(obj, {ctx, Xc}, blockOpts, doWave);

R = struct('name', name, 'sampleOffset', chunkFirst0, 'nSamples', n, ...
    'nChan', nChan, 'threshold', infoB.threshold, 'noise', infoB.noise, ...
    'degenerate', infoB.degenerate, 'erased', erased);   % erased: every sample in an artifact period
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


function R = parallelChunk(obj, plan, i, chunkFirst0, pad, chanOrder, blockOpts, doWave, contiguous, artRuns)
%parallelChunk  Worker body for UseParallel: read chunk i and its context.
%   The context is the last min(2*pad, chunkFirst0) samples before the chunk -
%   exactly the tail the serial loop would carry in - read as one window when
%   the plan's chunks follow each other in the recording (CONTIGUOUS), else
%   from as many preceding listed chunks as it spans.
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
elseif contiguous
    ctx = obj.readWindowUV(plan(i).sampleOffset - nCtx, nCtx);
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

R = detectChunk(obj, ctx, Xc, plan(i).name, chunkFirst0, pad, ...
    blockOpts, doWave, artRuns);
end


function [ts, wf, info, erased] = detectBlock(obj, X, opts, doWave)
%detectBlock  Detect spikes in one in-memory [nSamples x nChan] microvolt block.
%   The detector itself: both ds.detectSpikes(X) and the whole-recording
%   streaming loop above run every block through here. doWave is explicit (the
%   caller decides whether waveforms are wanted), and the returned info.index /
%   info.rejectedIndex / info.droppedEdgeIndex are rows of X.
%
%   X is the block, or {A, B} for the rows of A above the rows of B (the
%   context and the chunk of the streaming loop), which are never joined: the
%   block is filtered and detected a group of channels at a time
%   (channelGroups), so only one group's copy and filtered trace are held,
%   whatever the channel count. A channel's result does not depend on which
%   channels share its group. opts.EraseRows ([first last] rows, 1-based) are
%   set to NaN in each group before anything else; ERASED [1 x nChan] is true
%   for a channel left with no number at all.

% ---- sample rate -------------------------------------------------------
Fs = opts.Fs;
if isnan(Fs); Fs = obj.Fs; end
if isnan(Fs) || Fs <= 0
    error('EphysDataset:detectSpikes:NoFs', ...
        'Sample rate unknown; pass opts.Fs or run refreshMetadata first.');
end

[nSamples, nChan] = stackSize(X);
if nSamples == 1 && nChan > 1
    error('EphysDataset:detectSpikes:RowVector', ...
        ['X must be [nSamples x nChan] (time down the rows); got 1 sample on ' ...
         '%d channels. Transpose it.'], nChan);
end

% ---- option checks -----------------------------------------------------
checkWindow(opts);
thrIn = thresholdInput(opts);

% ---- sample-domain parameters (report what rounding actually gave) -----
w0        = round(opts.WindowMs(1)   * 1e-3 * Fs);
w1        = round(opts.WindowMs(2)   * 1e-3 * Fs);
offs      = w0:w1;                                  % [1 x nWin]
alignSamp = max(0, round(opts.AlignWindowMs * 1e-3 * Fs));
minPerSamp = max(1, round(opts.MinPeriodMs  * 1e-3 * Fs));

% ---- thresholds fixed from outside --------------------------------------
fixed = isfield(opts, 'FixedThreshold') && ~isempty(opts.FixedThreshold);
if fixed
    % ThresholdScope "recording": every block gets the thresholds of the
    % whole recording (noisePass), not its own.
    if numel(opts.FixedThreshold) ~= nChan
        error('EphysDataset:detectSpikes:ChannelMismatch', ...
            'The recording-wide thresholds are for %d channels; this block has %d.', ...
            numel(opts.FixedThreshold), nChan);
    end
    fixedThr   = reshape(double(opts.FixedThreshold), 1, []);
    fixedNoise = reshape(double(opts.FixedNoise), 1, []);
end
eraseRows = zeros(0, 2);
if isfield(opts, 'EraseRows'); eraseRows = opts.EraseRows; end

ts     = cell(1, nChan);
wf     = cell(1, nChan);
sIdx   = cell(1, nChan);
sAmp   = cell(1, nChan);
rejIdx = repmat({zeros(0,1)}, 1, nChan);
dropIdx = repmat({zeros(0,1)}, 1, nChan);
count  = zeros(1, nChan);
nEdge  = zeros(1, nChan);
nRejAmp = zeros(1, nChan);
thr        = inf(1, nChan);
noise      = nan(1, nChan);
degenerate = false(1, nChan);
ctr        = zeros(1, nChan);       % the baseline each channel's crossings are tested relative to
erased     = false(1, nChan);

groups = channelGroups(nSamples, nChan, opts.GroupChannels);
for gi = 1:numel(groups)
    cols = groups{gi};
    Xg = stackCols(X, cols);
    for r = 1:size(eraseRows, 1)
        Xg(eraseRows(r, 1):eraseRows(r, 2), :) = NaN;
    end
    erased(cols) = all(isnan(Xg), 1);

    % ---- filtering -----------------------------------------------------
    Xfg = blockFilter(obj, Xg, opts, Fs);
    % Waveforms are cut from the filtered trace unless the raw one was asked for.
    if opts.WaveformSource == "raw"
        Xwg = Xg;
    else
        Xwg = Xfg;
        Xg = []; %#ok<NASGU>             only the filtered group is needed from here
    end

    for j = 1:numel(cols)
        c  = cols(j);
        xf = Xfg(:, j);

        % ---- baseline ---------------------------------------------------
        % The band-pass removes a channel's offset; without it the raw trace is
        % taken relative to its median, so a DC offset neither crosses the
        % threshold on its own nor biases the amplitudes.
        if ~opts.Filter
            xv = finiteOnly(xf);
            if ~isempty(xv); ctr(c) = median(xv); end
        end
        xc = xf;                         % the crossings, relative to the baseline (0 when filtered)
        if ctr(c) ~= 0
            xc = xf - ctr(c);
        end

        % ---- threshold --------------------------------------------------
        if fixed
            thr(c)   = fixedThr(c);
            noise(c) = fixedNoise(c);
            degenerate(c) = ~isfinite(thr(c)) || thr(c) <= 0;
            if degenerate(c); thr(c) = Inf; end      % detect nothing rather than everything
        else
            xv = finiteOnly(xc);                     % noise estimates ignore NaN/Inf
            if isempty(xv)
                degenerate(c) = true;
            else
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
        end

        % ---- detection --------------------------------------------------
        switch opts.Polarity                 % NaN never satisfies these
            case "negative", over = xc < -thr(c);
            case "positive", over = xc >  thr(c);
            case "both",     over = abs(xc) > thr(c);
        end
        hit = find(over);                    % the runs of above-threshold samples
        if isempty(hit)
            on  = zeros(0, 1);
            off = zeros(0, 1);
        else
            gap = diff(hit) > 1;
            on  = hit([true; gap]);          % first sample of each run
            off = hit([gap; true]);          % last sample of each run
        end

        % Align each crossing to its extremum (min/max/|max|) in the search window,
        % which spans the run plus AlignWindowMs from the crossing.
        idx = alignEvents(xf, on, off, alignSamp, nSamples, opts.Align);

        % Minimum detection period: greedy, keeping the earlier of two close events.
        if ~isempty(idx)
            if ~issorted(idx); idx = sort(idx); end
            keep = deadTime(idx, minPerSamp);
            if ~all(keep); idx = idx(keep); end
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
            % A window runs w0:w1 around its sample, so it lies inside the block
            % exactly when its first and last samples do.
            whole = idx + w0 >= 1 & idx + w1 <= nSamples;
            nEdge(c) = nnz(~whole);
            if opts.EdgeHandling == "drop" && any(~whole)
                dropIdx{c} = idx(~whole);
                idx   = idx(whole);
                amp   = amp(whole);
                whole = whole(whole);
            end
            wf{c} = cutWindows(Xwg(:, j), idx, offs, whole, nSamples);
        end

        ts{c}    = (idx - 1) / Fs + opts.TimeOffset;
        sIdx{c}  = idx;
        sAmp{c}  = amp;
        count(c) = numel(idx);
    end
end
if any(degenerate)
    warning('EphysDataset:detectSpikes:DegenerateThreshold', ...
        ['Non-positive or non-finite threshold on channel(s) %s (flat or empty ' ...
         'signal); no spikes detected there.'], mat2str(find(degenerate)));
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
info.center          = ctr;
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
info.nRejectedArtifact  = zeros(1, nChan);   % RejectIntervals: whole-recording mode only
info.maxAmplitudeUV     = opts.MaxAmplitudeUV;
info.timeOffset         = opts.TimeOffset;
end


function checkWindow(opts)
%checkWindow  WindowMs must be [before after] with before <= after.
if opts.WindowMs(1) > opts.WindowMs(2)
    error('EphysDataset:detectSpikes:BadWindow', ...
        'WindowMs must be [before after] with before <= after; got [%g %g].', ...
        opts.WindowMs(1), opts.WindowMs(2));
end
end


function checkSitePositions(opts, nChan)
%checkSitePositions  Coincidence needs one site position per channel.
if opts.Coincidence == "none"
    return
end
if isempty(opts.SitePositions)
    error('EphysDataset:detectSpikes:NoSitePositions', ...
        ['Coincidence "%s" needs SitePositions: the [x y] um of each channel''s site ' ...
         '(EphysDataset.channelLayout), or Coincidence "none".'], opts.Coincidence);
end
if size(opts.SitePositions, 1) ~= nChan
    error('EphysDataset:detectSpikes:SitePositions', ...
        'SitePositions has %d rows; there are %d channels to detect on.', ...
        size(opts.SitePositions, 1), nChan);
end
end


function [ts, wf, info] = applyCoincidence(ts, wf, info, opts, doWave)
%applyCoincidence  Find (Coincidence) the copies of each spike on neighboring sites.
%   "remove" drops the copies from TS, WF and INFO's per-event fields, and
%   recounts count, rate and nEdgeWindows; "tag" keeps them and adds
%   info.eventId / info.primary. info.coincidence says what was found.
nChan = numel(ts);
C = struct('mode', opts.Coincidence, 'radiusUm', opts.CoincidenceRadiusUm, ...
    'jitterMs', NaN, 'jitterSamples', NaN, 'positions', zeros(0, 2), ...
    'neighbors', {cell(1, 0)}, 'nCopies', zeros(1, nChan));
if opts.Coincidence == "none"
    info.coincidence = C;
    return
end
J = round(opts.CoincidenceJitterMs * 1e-3 * info.fs);
[primary, eventId, nCopies, neighbors] = coincidentEvents(info.index, info.amplitude, ...
    opts.SitePositions, opts.CoincidenceRadiusUm, J);
C.jitterMs = 1e3 * J / info.fs;
C.jitterSamples = J;
C.positions = opts.SitePositions;
C.neighbors = neighbors;
C.nCopies = nCopies;
if opts.Coincidence == "tag"
    info.eventId = eventId;
    info.primary = primary;
else
    w = info.windowSamples;
    for c = 1:nChan
        keep = primary{c};
        if all(keep); continue; end
        gone = info.index{c}(~keep);
        if doWave
            info.nEdgeWindows(c) = info.nEdgeWindows(c) - ...
                nnz(gone + w(1) < 1 | gone + w(2) > info.nSamples);
            wf{c} = wf{c}(keep, :);
        end
        ts{c} = ts{c}(keep);
        info.index{c} = info.index{c}(keep);
        info.amplitude{c} = info.amplitude{c}(keep);
        info.count(c) = nnz(keep);
    end
    if info.durationSec > 0
        info.rate = info.count / info.durationSec;
    end
end
info.coincidence = C;
end


function thrIn = thresholdInput(opts)
%thresholdInput  The Threshold option, checked; NaN gives the method's default.
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
end


function checkBand(opts, Fs)
%checkBand  With Filter on, Band must be [low high], low < high < Nyquist.
if ~opts.Filter
    return
end
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
end


function Xf = blockFilter(obj, X, opts, Fs)
%blockFilter  The trace detection runs on: X band-passed (Filter on), else X.
if ~opts.Filter
    Xf = X;
    return
end
checkBand(opts, Fs);
% FILTFILT refuses non-finite samples (NaN from blankArtifacts(Fill="nan")):
% it filters a straight line across them instead - no step to ring - and
% they are NaN again afterwards, so they cannot cross threshold.
bad = ~isfinite(X);
if any(bad, 'all')
    Xf = obj.filterContinuous(bridgeNonFinite(X, bad), Type="bandpass", ...
        Cutoff=opts.Band, Order=opts.FilterOrder, Fs=Fs);
    Xf(bad) = NaN;
else
    Xf = obj.filterContinuous(X, Type="bandpass", Cutoff=opts.Band, ...
        Order=opts.FilterOrder, Fs=Fs);
end
end


function [n, c] = stackSize(X)
%stackSize  Rows and columns of a block given as a matrix or as {A, B} (A above B).
if iscell(X)
    n = size(X{1}, 1) + size(X{2}, 1);
    c = size(X{2}, 2);
else
    [n, c] = size(X);
end
end


function Xg = stackCols(X, cols)
%stackCols  The columns COLS of a block given as a matrix or as {A, B} (A above B).
if iscell(X)
    Xg = [X{1}(:, cols); X{2}(:, cols)];
elseif numel(cols) == size(X, 2)
    Xg = X;                         % the whole block: no copy until something writes to it
else
    Xg = X(:, cols);
end
end


function groups = channelGroups(nSamples, nChan, forced)
%channelGroups  The column groups a block is filtered and detected in, one group at a time.
%   {1 x nGroups} of column ranges, as even as they can be. A group is about
%   64 MB of doubles but never fewer than 8 channels (a 60 s chunk at 30 kHz:
%   8): FILTFILT runs the columns of a matrix on several threads, and 1-4
%   channels at a time took twice as long as 8-64 (measured). A group is never
%   a lone column (unless the block is one): FILTFILT filters one column with
%   another routine than several, and on a short signal the two differ in the
%   last bit, while any two or more columns give the same numbers as the whole
%   block does (checked from 2 to 39 columns, 300 to 600000 samples). So the
%   groups change the peak memory and not the answer. FORCED (the GroupChannels
%   option, NaN = automatic) sets the channels per group.
if nChan < 1
    groups = cell(1, 0);
    return
end
if isnan(forced)
    cols = max(8, floor(2^26 / (8 * max(nSamples, 1))));
else
    cols = forced;
end
nGroups = max(1, ceil(nChan / cols));
while nGroups > 1 && floor(nChan / nGroups) < 2
    nGroups = nGroups - 1;
end
edges = round(linspace(0, nChan, nGroups + 1));
groups = arrayfun(@(k) edges(k)+1:edges(k+1), 1:nGroups, 'UniformOutput', false);
end


function c = chunkCopies(nSamples, nChan, forced)
%chunkCopies  Copies of one [nSamples x nChan] chunk of doubles a detection holds at once.
%   The chunk itself plus, at its peak, the working copies of one channel
%   group (channelGroups): the group's raw and filtered columns, what FILTFILT
%   makes of them and, with artifact periods erased or the recording-wide
%   thresholds counting the samples, the line drawn across the NaN and the
%   histogram indices. Measured on 64 channels x 20 s chunks: 2.2 chunks
%   (plain), 2.5 (artifacts erased), 2.5 (ThresholdScope "recording"), against 5.2,
%   7.3 and 8.4 when the whole chunk was filtered at once; the working copies
%   come to at most 8 group-sized arrays. parallelChunkPool turns this into the
%   number of chunks in flight.
g = channelGroups(nSamples, nChan, forced);
width = 1;
if ~isempty(g); width = max(cellfun(@numel, g)); end
c = 1 + 8 * min(1, width / max(nChan, 1));
end


function xv = finiteOnly(x)
%finiteOnly  The finite samples of the column X (X itself when all of them are).
fin = isfinite(x);
if all(fin)
    xv = x;
else
    xv = x(fin);
end
end


function idx = alignEvents(xf, on, off, alignSamp, nSamples, mode)
%alignEvents  The aligned sample of each run of above-threshold samples.
%   The run [ON(k) OFF(k)] is searched from its first sample to the later of
%   its last sample and ON(k) + ALIGNSAMP (not past the block) for the sample
%   MODE names: "trough" the minimum of XF, "peak" the maximum, "extremum" the
%   largest |XF| (the first of equal ones), "none" the first sample itself.
%   Runs no longer than the window all search the same number of samples, so
%   their windows are taken as one matrix; the longer ones one by one.
nRun = numel(on);
idx = zeros(nRun, 1);
if nRun == 0
    return
end
if mode == "none"
    idx = on;
    return
end
short = (off - on) <= alignSamp;
w = 0:alignSamp;
rows = find(short);
step = max(1, floor(4e6 / (alignSamp + 1)));      % windows per matrix
for b = 1:step:numel(rows)
    k = rows(b:min(numel(rows), b + step - 1));
    S = on(k) + w;                                % [nk x nWin] samples searched
    past = S > nSamples;                          % beyond the block: not searched
    S(past) = nSamples;
    V = reshape(xf(S), size(S));
    V(past) = NaN;                                % MIN / MAX skip NaN
    switch mode
        case "trough",   [~, jx] = min(V, [], 2);
        case "peak",     [~, jx] = max(V, [], 2);
        case "extremum", [~, jx] = max(abs(V), [], 2);
    end
    idx(k) = on(k) + jx - 1;
end
for k = find(~short).'
    s = on(k);
    e = min(nSamples, max(off(k), s + alignSamp));
    switch mode
        case "trough",   [~, jx] = min(xf(s:e));
        case "peak",     [~, jx] = max(xf(s:e));
        case "extremum", [~, jx] = max(abs(xf(s:e)));
    end
    idx(k) = s + jx - 1;
end
end


function keep = deadTime(idx, minPerSamp)
%deadTime  Which of the ascending samples IDX survive a minimum detection period.
%   Greedy: an event is kept when it lies at least MINPERSAMP after the last
%   one kept, so the earlier of two close events wins. Only events with a
%   neighbor closer than that can be dropped, and such a cluster is always
%   separated from the rest by gaps of at least MINPERSAMP, so only they are
%   walked one by one.
n = numel(idx);
keep = true(n, 1);
if n < 2
    return
end
near = diff(idx) < minPerSamp;
if ~any(near)
    return
end
last = -Inf;
for k = find([near; false] | [false; near]).'
    if idx(k) - last >= minPerSamp
        last = idx(k);
    else
        keep(k) = false;
    end
end
end


function W = cutWindows(src, idx, offs, whole, nSamples)
%cutWindows  The snippets of the column SRC around the samples IDX, one row each.
%   OFFS is the window relative to a sample; the part of a window outside
%   1..NSAMPLES is NaN. WHOLE flags the windows that lie entirely inside, which
%   are cut without any test.
I = idx + offs;                                   % [nEvents x nWin]
if all(whole)
    W = reshape(src(I), size(I));
    return
end
W = nan(size(I));
if any(whole)
    Iw = I(whole, :);
    W(whole, :) = reshape(src(Iw), size(Iw));
end
Ie = I(~whole, :);
inRng = Ie >= 1 & Ie <= nSamples;
We = nan(size(Ie));
We(inRng) = src(Ie(inRng));
W(~whole, :) = We;
end


function T = lastRows(A, B, m)
%lastRows  The last M rows of [A; B] (all of them when there are fewer).
nB = size(B, 1);
if nB >= m
    T = B(nB - m + 1:end, :);
else
    T = [A(max(1, size(A, 1) - (m - nB) + 1):end, :); B];
end
end


function runs = rowRuns(nRows, first0, artRuns)
%rowRuns  The rows of a block the artifact runs cover, [first last] 1-based.
%   Row 1 of the block is recording sample FIRST0 + 1; ARTRUNS are [first last]
%   1-based recording samples.
k = artRuns(:, 2) > first0 & artRuns(:, 1) <= first0 + nRows;
runs = [max(1, artRuns(k, 1) - first0), min(nRows, artRuns(k, 2) - first0)];
end


function C = chunkThresholds(info, startSec, offsets, nSamp, thr, noise, deg, Fs, nSamplesTotal)
%chunkThresholds  What each chunk was detected against and found, for a QC plot over time.
%   One row per chunk, one column per channel: the threshold and noise it
%   applied, whether the channel was degenerate there, the events that lie in
%   its samples (INFO.index, after everything else removed) and their rate.
nChunks = numel(offsets);
nChan = size(thr, 2);
edges = [offsets(:); nSamplesTotal] + 0.5;        % chunk k holds samples offsets(k)+1 .. offsets(k+1)
count = zeros(nChunks, nChan);
for c = 1:nChan
    count(:, c) = histcounts(info.index{c}, edges);
end
dur = nSamp(:) / Fs;
C = struct('startSec', startSec(:), 'durationSec', dur, 'threshold', thr, 'noise', noise, ...
    'degenerate', logical(deg), 'count', count, 'rate', count ./ dur);
end


function X = bridgeNonFinite(X, bad)
%bridgeNonFinite  The samples flagged BAD replaced, per channel, by a straight
%   line between the finite samples around them (held at the nearest finite
%   sample at either end; 0 on a channel with fewer than two).
X(bad) = NaN;
X = fillmissing(X, 'linear', 1, 'EndValues', 'nearest');
X(isnan(X)) = 0;
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


function w = noiseBinUV()
%noiseBinUV  Bin width (uV) of the recording-wide "mad" / "percentile" histograms.
w = 0.05;
end


function r = noiseRangeUV()
%noiseRangeUV  The histograms place samples within +/- this (uV); beyond, they are only counted.
r = 2000;
end


function est = noisePass(obj, plan, pad, blockOpts, Fs, artRuns, chanOrder, thrIn, progress)
%noisePass  Each channel's noise over the whole recording (ThresholdScope "recording").
%   Streams PLAN as the serial detection loop does - each chunk after the
%   last 2*PAD samples of the one before, the artifact runs erased, the
%   band-pass (blockFilter) - and counts every recording sample once, in the
%   chunk whose detection finalizes it: the rows detectChunk finalizes, and
%   at the end the rows the last chunk holds back. Non-finite (erased)
%   samples are not counted, as detectBlock leaves them out.
%     "std"         exact: per-chunk counts, means and sums of squared
%                   deviations merged (Chan, Golub & LeVeque 1979)
%     "rms"         exact: the sum of squares over the count
%     "mad"         histogram of noiseBinUV() bins over +/-noiseRangeUV()
%                   (beyond it, counted at either end) with a piecewise-
%                   linear CDF F: the median m is where F reaches 0.5, the
%                   MAD the half-width d where F(m+d) - F(m-d) reaches 0.5
%                   (bisection); noise = MAD / 0.6745, as detectBlock
%     "percentile"  histogram of |x| alike; the threshold is where its CDF
%                   reaches Threshold/100
%   A statistic beyond the histogram's range cannot be placed (beyondRange);
%   a MAD or percentile below one bin is not resolved (belowResolution: a
%   flat channel), and its noise is NaN, not 0. Either leaves the channel
%   degenerate (threshold Inf), as an empty or zero-noise one does.
%   EST: threshold, noise, degenerate [1 x nChan], and what info.noiseEstimate
%   reports: method, estimator ("histogram" | "exact"), binUV and rangeUV
%   (NaN for "exact"), nSamples and nOutOfRange [1 x nChan], beyondRange
%   and belowResolution [1 x nChan].
method = blockOpts.ThresholdMethod;
W  = noiseBinUV();
Rg = noiseRangeUV();
switch method
    case "mad",        nb = round(2 * Rg / W) + 2;   % below -Rg | Rg/W*2 bins | from Rg up
    case "percentile", nb = round(Rg / W) + 1;       % Rg/W bins of |x| | from Rg up
    otherwise,         nb = 0;
end

nChunks  = numel(plan);
consumed = 0;       % samples read so far = 0-based index of the next sample
tail     = [];      % trailing samples of the previous chunk, kept as context
nChan    = NaN;
pend     = [];      % the latest chunk's held-back rows (filtered)
acc      = [];
for i = 1:nChunks
    if ~isempty(progress)
        progress(i, nChunks, plan(i).name);
    end
    Xc = readChunk(obj, plan(i), chanOrder);
    if isempty(Xc)
        continue
    end
    if isnan(nChan)
        nChan = size(Xc, 2);
        tail  = zeros(0, nChan);
        acc   = struct('n', zeros(1, nChan), 'mean', zeros(1, nChan), 'm2', zeros(1, nChan), ...
            'sumsq', zeros(1, nChan), 'counts', zeros(nb, nChan));
    elseif size(Xc, 2) ~= nChan
        error('EphysDataset:detectSpikes:ChannelMismatch', ...
            'Chunk "%s" has %d channels; earlier chunks had %d.', ...
            plan(i).name, size(Xc, 2), nChan);
    end

    % B = [tail; Xc], filtered and counted a group of channels at a time
    % (as detectBlock does), so it is never held whole.
    nB     = size(tail, 1) + size(Xc, 1);
    first0 = consumed - size(tail, 1);           % 0-based index of B(1)
    total0 = consumed + size(Xc, 1);
    rowLo  = consumed - min(pad, consumed) - first0 + 1;   % as detectChunk
    rowHi  = total0 - min(pad, total0) - first0;
    runs   = rowRuns(nB, first0, artRuns);
    pend   = zeros(nB - rowHi, nChan);
    groups = channelGroups(nB, nChan, blockOpts.GroupChannels);
    for gi = 1:numel(groups)
        cols = groups{gi};
        Xg = stackCols({tail, Xc}, cols);
        for r = 1:size(runs, 1)
            Xg(runs(r, 1):runs(r, 2), :) = NaN;
        end
        Xf = blockFilter(obj, Xg, blockOpts, Fs);
        Xg = [];                                 %#ok<NASGU>
        acc = accumulateCols(acc, cols, Xf(rowLo:rowHi, :), method, W, Rg, nb);
        pend(:, cols) = Xf(rowHi+1:end, :);
    end

    consumed = total0;
    tail     = lastRows(tail, Xc, 2*pad);
    Xc       = []; %#ok<NASGU>   freed before the next chunk is read
end
if isnan(nChan)
    error('EphysDataset:detectSpikes:NoAmplifierData', ...
        'No amplifier data was read from %s.', obj.Folder);
end
acc = accumulateNoise(acc, pend, method, W, Rg, nb);   % the recording's end has no next chunk

noise  = nan(1, nChan);
thr    = nan(1, nChan);
beyond = false(1, nChan);              % the statistic lies beyond +/-Rg
below  = false(1, nChan);              % ... within one bin of 0: not resolved
nOut   = zeros(1, nChan);
switch method
    case "std"
        ok = acc.n > 1;
        noise(ok) = sqrt(acc.m2(ok) ./ (acc.n(ok) - 1));   % STD's N-1 normalization
        noise(acc.n == 1) = 0;                             % std of one sample
        thr = thrIn * noise;
    case "rms"
        ok = acc.n > 0;
        noise(ok) = sqrt(acc.sumsq(ok) ./ acc.n(ok));
        thr = thrIn * noise;
    case "mad"
        for c = find(acc.n > 0)
            Fk = cumsum(acc.counts(:, c)) / acc.n(c);
            Fk = Fk(1:end-1);                  % F at the knots -Rg:W:Rg (fraction below each)
            [~, madUV, beyond(c)] = histMad(Fk, W, Rg);
            below(c) = ~beyond(c) && madUV < W;
            if ~beyond(c) && ~below(c)
                noise(c) = madUV / 0.6745;
            end
            nOut(c) = acc.counts(1, c) + acc.counts(end, c);
        end
        thr = thrIn * noise;
    case "percentile"
        for c = find(acc.n > 0)
            Fk = [0; cumsum(acc.counts(1:end-1, c)) / acc.n(c)];   % F at the knots 0:W:Rg
            v  = invCdf(Fk, thrIn / 100, 0, W);
            beyond(c) = isnan(v);
            below(c)  = ~beyond(c) && v < W;
            if ~beyond(c) && ~below(c)
                thr(c) = v;
            end
            nOut(c) = acc.counts(end, c);
        end
end
degenerate = ~isfinite(thr) | thr <= 0;
thr(degenerate) = Inf;                  % detect nothing rather than everything

est = struct();
est.threshold   = thr;
est.noise       = noise;
est.degenerate  = degenerate;
est.method      = method;
if nb > 0
    est.estimator = "histogram";
    est.binUV     = W;
    est.rangeUV   = Rg;
else
    est.estimator = "exact";
    est.binUV     = NaN;
    est.rangeUV   = NaN;
end
est.nSamples    = acc.n;
est.nOutOfRange = nOut;
est.beyondRange = beyond;
est.belowResolution = below;
end


function acc = accumulateCols(acc, cols, Y, method, W, Rg, nb)
%accumulateCols  accumulateNoise for the channels COLS, whose samples Y holds.
g = struct('n', acc.n(cols), 'mean', acc.mean(cols), 'm2', acc.m2(cols), ...
    'sumsq', acc.sumsq(cols), 'counts', acc.counts(:, cols));
g = accumulateNoise(g, Y, method, W, Rg, nb);
acc.n(cols)        = g.n;
acc.mean(cols)     = g.mean;
acc.m2(cols)       = g.m2;
acc.sumsq(cols)    = g.sumsq;
acc.counts(:, cols) = g.counts;
end


function acc = accumulateNoise(acc, Y, method, W, Rg, nb)
%accumulateNoise  Add the finite samples of Y [n x nChan] to the running sums.
if isempty(Y)
    return
end
ok = isfinite(Y);
nB = sum(ok, 1);
switch method
    case "std"
        Y0 = Y; Y0(~ok) = 0;
        mB = sum(Y0, 1) ./ max(nB, 1);
        D  = (Y0 - mB) .* ok;
        m2B = sum(D.^2, 1);
        n = acc.n + nB;
        has = nB > 0;
        delta = mB - acc.mean;
        acc.mean(has) = acc.mean(has) + delta(has) .* nB(has) ./ n(has);
        acc.m2(has) = acc.m2(has) + m2B(has) + delta(has).^2 .* acc.n(has) .* nB(has) ./ n(has);
    case "rms"
        Y0 = Y; Y0(~ok) = 0;
        acc.sumsq = acc.sumsq + sum(Y0.^2, 1);
    case "mad"
        k = min(floor((Y + Rg) / W) + 2, nb - 1);   % [-Rg + (k-2)W, -Rg + (k-1)W) -> k
        k(Y < -Rg) = 1;
        k(Y >= Rg) = nb;
        acc.counts = acc.counts + binCounts(k, ok, nb);
    case "percentile"
        A = abs(Y);
        k = min(floor(A / W) + 1, nb - 1);          % [(k-1)W, kW) -> k
        k(A >= Rg) = nb;
        acc.counts = acc.counts + binCounts(k, ok, nb);
end
acc.n = acc.n + nB;
end


function C = binCounts(k, ok, nb)
%binCounts  [nb x nChan] counts of the bin indices K (one column per channel) where OK.
nChan = size(k, 2);
lin = k + (0:nChan-1) * nb;
C = reshape(accumarray(lin(ok), 1, [nb * nChan, 1]), nb, nChan);
end


function [m, madUV, beyond] = histMad(Fk, W, Rg)
%histMad  Median and MAD from the CDF knots FK at -Rg:W:Rg.
%   The median is where the piecewise-linear CDF reaches 0.5; the MAD the
%   half-width d at which F(m+d) - F(m-d) reaches 0.5, found by bisection
%   on [0, Rg - |m|]. BEYOND: either lies outside the knots.
madUV  = NaN;
m      = invCdf(Fk, 0.5, -Rg, W);
beyond = isnan(m);
if beyond
    return
end
lo = 0;
hi = Rg - abs(m);
if cdfAt(Fk, m + hi, W, Rg) - cdfAt(Fk, m - hi, W, Rg) < 0.5
    beyond = true;
    return
end
for it = 1:60
    mid = (lo + hi) / 2;
    if cdfAt(Fk, m + mid, W, Rg) - cdfAt(Fk, m - mid, W, Rg) >= 0.5
        hi = mid;
    else
        lo = mid;
    end
end
madUV = hi;
end


function x = invCdf(Fk, p, x0, W)
%invCdf  Where the piecewise-linear CDF through the knots x0 + (0:K-1)*W
%   first reaches P (NaN when it does so at the first knot or never).
j = find(Fk >= p, 1);
if isempty(j) || j == 1
    x = NaN;
    return
end
x = x0 + (j - 2) * W + W * (p - Fk(j - 1)) / (Fk(j) - Fk(j - 1));
end


function F = cdfAt(Fk, v, W, Rg)
%cdfAt  The piecewise-linear CDF through the knots -Rg:W:Rg at V (constant beyond them).
K = numel(Fk);
t = (v + Rg) / W;                         % 0-based knot position
if t <= 0
    F = Fk(1);
elseif t >= K - 1
    F = Fk(K);
else
    j = floor(t);
    F = Fk(j + 1) + (t - j) * (Fk(j + 2) - Fk(j + 1));
end
end
