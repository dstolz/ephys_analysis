function [ts, wf, info] = detectSpikes(obj, X, opts)
%detectSpikes  Spike detection by simple voltage thresholding.
%   TS = ds.detectSpikes(X) detects spikes in the [nSamples x nChan] microvolt
%   block X, each channel independently, and returns TS as a {1 x nChan} cell
%   array of spike times in seconds (always a cell array, also for one channel).
%   With the defaults the data is band-pass filtered 500-5000 Hz, the threshold
%   is 4 robust SDs (MAD/0.6745) *below* zero on each channel, each crossing is
%   aligned to its trough, and events less than 1 ms apart are discarded.
%
%   [TS, WF] = ds.detectSpikes(X) also returns waveforms: WF{c} is
%   [nSpikes x nWin] microvolts spanning WindowMs ([-0.5 1.5] ms by default)
%   around each spike, one row per spike, in the same order as TS{c}. Waveforms
%   are extracted only when a second output is requested or Waveforms=true;
%   timestamps only is the default.
%
%   [TS, WF, INFO] = ds.detectSpikes(X) also returns the parameters actually
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
%     EdgeHandling  a window running past the start/end of X is padded with NaN
%                   ("nan", default, so TS is unaffected) or the event is
%                   dropped from both WF and TS ("drop")
%
%   Other
%     Fs            sample rate (Hz); defaults to ds.Fs
%     TimeOffset    seconds added to every timestamp (default 0), so a block
%                   read at a sample offset can report recording-relative times
%
%   Conventions
%   -----------
%   Timestamps are t = (row - 1)/Fs + TimeOffset, i.e. the same convention as
%   readData's t vector and Kilosort/phy sample indices - one sample earlier
%   than the t = row/Fs convention used by detectArtifacts intervals and
%   digital-input events. INFO.index holds the 1-based rows of X.
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
%     nEdgeWindows [1 x nChan] events whose window left the block,
%     nRejectedAmplitude [1 x nChan] events cut by MaxAmplitudeUV
%     timeOffset, maxAmplitudeUV
%
%   Examples
%   --------
%     d  = ds.readData();
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
%   EphysDataset.readData.

arguments
    obj (1,1) EphysDataset
    X double
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
    opts.Waveforms (1,1) logical = false
    opts.WindowMs (1,2) double = [-0.5 1.5]
    opts.WaveformSource (1,1) string {mustBeMember(opts.WaveformSource, ...
        ["filtered","raw"])} = "filtered"
    opts.EdgeHandling (1,1) string {mustBeMember(opts.EdgeHandling, ...
        ["nan","drop"])} = "nan"
    opts.Fs (1,1) double = NaN
    opts.TimeOffset (1,1) double = 0
end

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

doWave = opts.Waveforms || nargout >= 2;

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
