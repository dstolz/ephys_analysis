function [mask, intervals, stats] = detectArtifacts(obj, X, opts)
%detectArtifacts  Flag large transient artifacts across channels.
%   [MASK, INTERVALS, STATS] = ds.detectArtifacts(X) screens the
%   [nSamples x nChan] signal X for artifacts and returns:
%     MASK       [nSamples x 1] logical, true where an artifact is present
%     INTERVALS  [k x 2] artifact intervals in seconds [tStart tEnd), one per
%                contiguous run of MASK: half-open on the 0-based sample
%                clock, so row r (sample r-1, at (r-1)/Fs) is inside when
%                tStart <= (r-1)/Fs < tEnd. A run of rows a..b is [a-1, b]/Fs;
%                a one-sample run is one sample long. manualArtifactMask maps
%                it back to exactly those samples.
%     STATS      struct with the threshold(s) used and per-channel exceedance
%
%   Options
%   -------
%     Method      "rms" | "mad" | "microvolts" | "commonmode"   (default "rms")
%       "rms"        per-channel running RMS amplitude; a sample is flagged on a
%                    channel when its running RMS rises Threshold robust standard
%                    deviations above that channel's baseline. Polarity-blind
%                    (the signal is squared), so it catches large excursions of
%                    either sign. This is the automatic amplitude-deviation
%                    detector; see RmsWindow.
%       "mad"        per-channel robust z = |x - median| / (1.4826*MAD); a
%                    sample is flagged on a channel when z > Threshold.
%       "microvolts" absolute amplitude threshold in microvolts (|x| > Threshold).
%       "commonmode" flag the across-channel mean when |mean| > Threshold (uV).
%                    Give it the signal as recorded: a common reference
%                    (CAR / CMR) subtracts that very mean, so on referenced
%                    data it stays near 0 (artifactIntervals, analyzeArtifacts
%                    and toBin read it unreferenced for this method).
%     Threshold   scalar; default 9 (rms, in robust SD), 8 (mad),
%                 1500 (microvolts/commonmode)
%     RmsWindowMs running-RMS window length in milliseconds (Method "rms" only);
%                 default ~1 ms. Converted to samples with Fs.
%     MinChannels minimum channels that must exceed simultaneously (default 2;
%                 ignored for "commonmode")
%     Channels    columns of X that take part (default NaN: all of them).
%                 The others never flag a sample, count toward MinChannels
%                 or enter the common mode, and report 0 in
%                 channelExceedCounts; the streaming callers leave
%                 ExcludeChannels out this way, so dead or broken sites
%                 cannot erase a period on every channel. [] = none: nothing
%                 is flagged.
%     MergeGapMs  milliseconds; gaps of <= MergeGapMs of clean signal between two
%                 flagged runs are filled so they blank as one continuous
%                 artifact block ("stitching"). Applied before PadMs. Default 0.
%     PadMs       expand each flagged region by +/- this many milliseconds
%                 (default 0)
%     Fs          sample rate (Hz); defaults to ds.Fs. All millisecond options
%                 are converted to samples with this rate.
%     Baseline    struct with fields center and sigma, each a scalar or one
%                 value per column of X (median and 1.4826 x MAD of the running
%                 RMS for "rms", of the signal for "mad"; NaN = taken from X
%                 for that column). Default [] takes them over X itself. The
%                 streaming callers pass the recording's own (artifactBaseline)
%                 so a chunk of mostly stimulation does not set its own, and
%                 the result does not depend on how the recording was cut.
%     Rows        [first last] rows of X that are scored and returned
%                 (default: all). The rows outside are context only: they feed
%                 the running RMS and the baselines, never flag a sample, and
%                 are not in MASK, INTERVALS (counted from row FIRST) or the
%                 counts. The streaming callers read context beside a chunk
%                 so a filter or the running RMS has no edge at the chunk's
%                 ends.
%
%   MergeGapMs and PadMs apply to this block alone. A caller that cuts a
%   recording into chunks detects each with both 0 and joins and pads the
%   whole list once (artifactIntervals, analyzeArtifacts), so what is stitched
%   and padded does not depend on where the chunks end.
%
%   STATS fields: method, threshold, rmsWindowMs, minChannels, mergeGapMs,
%   padMs, fraction (of samples flagged), numIntervals, and
%   channelExceedCounts [1 x nChan] - the number of samples each channel
%   exceeded its threshold (before the MinChannels combination; 0 for the
%   channels Channels leaves out), used to summarize artifacts per channel.
%
%   See also EphysDataset.blankArtifacts, EphysDataset.toBin, EphysDataset.analyzeArtifacts.

arguments
    obj (1,1) EphysDataset
    X double
    opts.Method (1,1) string {mustBeMember(opts.Method, ...
        ["rms","mad","microvolts","commonmode"])} = "rms"
    opts.Threshold (1,1) double = NaN
    opts.RmsWindowMs (1,1) double = NaN
    opts.MinChannels (1,1) double {mustBeInteger, mustBePositive} = 2
    opts.MergeGapMs (1,1) double {mustBeNonnegative} = 0
    opts.PadMs (1,1) double {mustBeNonnegative} = 0
    opts.Fs (1,1) double = NaN
    opts.Channels (1,:) double = NaN
    opts.Baseline = []
    opts.Rows (1,:) double = []
end

Fs = opts.Fs;
if isnan(Fs); Fs = obj.Fs; end
if isnan(Fs) || Fs <= 0
    error('EphysDataset:detectArtifacts:NoFs', ...
        'Sample rate unknown; pass opts.Fs or run refreshMetadata first.');
end

% Default thresholds per method
thr = opts.Threshold;
if isnan(thr)
    switch opts.Method
        case "rms",        thr = 9;
        case "mad",        thr = 8;
        otherwise,         thr = 1500;  % microvolts / commonmode
    end
end

[nRows, nChan] = size(X);

% The columns that take part; the rest are left out of X here and report 0.
ch = opts.Channels;
if isscalar(ch) && isnan(ch)
    ch = 1:nChan;
elseif ~all(ch >= 1 & ch <= nChan & ch == round(ch))
    error('EphysDataset:detectArtifacts:BadChannels', ...
        'Channels must be column indices of X (1 to %d).', nChan);
end
if ~isequal(ch, 1:nChan)
    X = X(:, ch);
end
nDet = numel(ch);

% The rows that are scored and returned; the others are context.
core = opts.Rows;
if isempty(core)
    core = [1 nRows];
elseif ~(numel(core) == 2 && all(core == round(core)) && core(1) >= 1 && core(2) <= nRows && core(2) >= core(1))
    error('EphysDataset:detectArtifacts:BadRows', ...
        'Rows must be [first last] rows of X (1 to %d).', nRows);
end
nSamples = core(2) - core(1) + 1;

% The recording's baselines, one per column of X that takes part.
base = opts.Baseline;
if ~isempty(base)
    if ~(isstruct(base) && isscalar(base) && all(isfield(base, {'center', 'sigma'})))
        error('EphysDataset:detectArtifacts:BadBaseline', ...
            'Baseline must be a struct with fields center and sigma.');
    end
    base.center = pickColumns(base.center, nChan, ch);
    base.sigma = pickColumns(base.sigma, nChan, ch);
end

% Convert the millisecond options to samples with the data sample rate.
mergeGapSamp = round(opts.MergeGapMs * 1e-3 * Fs);
padSamp      = round(opts.PadMs      * 1e-3 * Fs);

% The statistic each method thresholds (artifactScore, shared with
% measureArtifacts), then the channels that exceed it at each sample.
[score, rmsWindowMs] = artifactScore(X, opts.Method, Fs, opts.RmsWindowMs, base);
if nSamples < nRows
    score = score(core(1):core(2), :);
end
if opts.Method == "commonmode"
    mask = score > thr;
    counts = repmat(nnz(mask), 1, nDet);
else
    exceed = score > thr;
    mask = sum(exceed, 2) >= min(opts.MinChannels, nDet);
    counts = sum(exceed, 1);
end

mask = mask(:);
if nDet == 0
    mask = false(nSamples, 1);     % no channel takes part: nothing to flag
end

% Runs of flagged rows; stitch those separated by short clean gaps into one
% block, then pad them. Both work on the runs, not the samples.
[on, off] = maskRuns(mask);
if ~isempty(on) && (mergeGapSamp > 0 || padSamp > 0)
    if mergeGapSamp > 0
        [on, off] = joinRuns(on, off, mergeGapSamp);
    end
    if padSamp > 0
        on = max(1, on - padSamp);
        off = min(nSamples, off + padSamp);
        [on, off] = joinRuns(on, off, 0);   % padded runs that now touch are one
    end
    mask = runsToMask(on, off, nSamples);
end

intervals = zeros(0, 2);
if ~isempty(on)
    intervals = [on - 1, off] ./ Fs;   % half-open [first - 1, last)/Fs
end

stats = struct();
stats.method      = opts.Method;
stats.threshold   = thr;
stats.rmsWindowMs = rmsWindowMs;
stats.minChannels = opts.MinChannels;
stats.mergeGapMs  = opts.MergeGapMs;
stats.padMs       = opts.PadMs;
stats.fraction    = nnz(mask) / max(nSamples, 1);
stats.numIntervals = size(intervals, 1);
stats.channelExceedCounts = zeros(1, nChan);
stats.channelExceedCounts(ch) = counts;
end


function [on, off] = maskRuns(mask)
% First and last row of each run of true rows in MASK.
d = diff([0; mask(:); 0]);
on  = find(d == 1);
off = find(d == -1) - 1;
end


function [on, off] = joinRuns(on, off, gap)
% Runs ON(k):OFF(k) (sorted, disjoint) with at most GAP rows between one and
% the next become one run, so closely spaced artifacts blank as one block;
% GAP 0 joins the runs that touch or overlap. O(runs), not O(samples).
if numel(on) < 2
    return
end
first = [true; (on(2:end) - off(1:end-1) - 1) > gap];   % starts a block
last = [first(2:end); true];                             % ends one
on = on(first);
off = off(last);
end


function mask = runsToMask(on, off, n)
% The [n x 1] logical mask of runs ON(k):OFF(k) (disjoint, none touching).
d = zeros(n + 1, 1);
d(on) = 1;
d(off + 1) = d(off + 1) - 1;
mask = cumsum(d(1:n)) > 0;
end


function v = pickColumns(v, nChan, ch)
% A baseline given for all NCHAN columns of X, or as a scalar, for the
% columns CH that take part.
v = double(v(:).');
if numel(v) == nChan
    v = v(ch);
elseif ~isscalar(v)
    error('EphysDataset:detectArtifacts:BadBaseline', ...
        'The baseline has %d value(s) but X has %d column(s).', numel(v), nChan);
end
end
