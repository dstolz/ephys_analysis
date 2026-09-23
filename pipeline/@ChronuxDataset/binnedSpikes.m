function [data, params, t, info] = binnedSpikes(obj, opts)
%binnedSpikes  Spike trains as Chronux binned counts [bins x channels/trials].
%   [DATA, PARAMS, T] = cx.binnedSpikes() bins spike times into counts and
%   returns a [nBins x nUnits] double matrix, the Chronux params (params.Fs is
%   the bin rate), and T, the left edge of every bin in seconds. That is the
%   input form of mtspectrumpb, mtspecgrampb, coherencypb and coherencycpb,
%   which expect counts per bin at params.Fs (they report the rate as
%   mean(count)*Fs).
%
%     [c, params] = cx.binnedSpikes(BinFs=1000);
%     [S, f, R] = mtspectrumpb(c, params);            % Chronux
%
%   Binning rule: bin k covers [t0+(k-1)/BinFs, t0+k/BinFs), half-open, so
%   every spike falls in exactly one bin. nBins = floor((t1-t0)*BinFs), i.e. a
%   trailing partial bin of a given TimeRange is dropped rather than being
%   short of time; T(k) is the bin's left edge, the same convention as the
%   continuous time base (sample k at t = (k-1)/Fs). Counts are counts, never
%   rates or smoothed.
%
%   Options
%   -------
%     Times       what to bin: the struct array from cx.spikes or
%                 cx.spikeTrials (trials become columns), a cell array of
%                 vectors, or a numeric vector. Default: cx.spikes()
%     BinFs       bin rate in Hz (default: the SpikeFs property). Chronux's
%                 point-binned routines assume at most one spike per bin is
%                 typical; bins coarse enough to hold several spikes blur the
%                 process, and info.maxCount reports the worst case
%     TimeRange   [t0 t1] seconds covered by the bins. Default: the analysis
%                 window cx.spikes would use (the recording). With times
%                 supplied directly, unset ends cover every spike: whole bins
%                 from t0 = 0 (or the start of the earliest spike's bin on the
%                 grid k/BinFs, when a spike is negative) through the bin
%                 holding the last spike
%     Source, ResultsDir, Units, Groups, DetectOptions   forwarded to
%                 ChronuxDataset.spikes when Times is not given
%     Tapers, Pad, Fpass, Err, TrialAve   per-call params overrides
%
%   INFO: nBins, binFs, binWidthSec, timeRange, nUnits, labels, counts (total
%   per column), maxCount (the largest single bin), rates, droppedOutsideRange.
%
%   See also ChronuxDataset.spikes, ChronuxDataset.spikeTrials.

arguments
    obj (1,1) ChronuxDataset
    opts.Times = []
    opts.BinFs (1,1) double = NaN
    opts.TimeRange (1,2) double = [-Inf Inf]
    opts.Source (1,1) string = "auto"
    opts.ResultsDir (1,1) string = ""
    opts.Units = []
    opts.Groups (1,:) string = string.empty(1,0)
    opts.DetectOptions struct = struct()
    opts.Tapers (1,:) double = double.empty(1,0)
    opts.Pad double = []
    opts.Fpass (1,:) double = double.empty(1,0)
    opts.Err (1,:) double = double.empty(1,0)
    opts.TrialAve double = []
end

binFs = opts.BinFs;
if isnan(binFs); binFs = obj.SpikeFs; end
if ~isfinite(binFs) || binFs <= 0
    error('ChronuxDataset:BadBinFs', 'BinFs must be a positive, finite rate.');
end

% --- the spike trains and the window they live in -----------------------
nBins = NaN;                           % set below when the spikes fix the end
if isempty(opts.Times)
    [S, ~, ~, sinfo] = obj.spikes(Source=opts.Source, ResultsDir=opts.ResultsDir, ...
        Units=opts.Units, Groups=opts.Groups, DetectOptions=opts.DetectOptions, ...
        TimeRange=opts.TimeRange, SpikeFs=binFs);
    labels = sinfo.labels;
    tr     = sinfo.timeRange;
else
    S = ChronuxDataset.toPointProcess(opts.Times);
    labels = "unit" + string(1:numel(S));
    tr = opts.TimeRange;
    v = vertcat(S.times);              % every supplied spike
    if isinf(tr(1))
        tr(1) = 0;
        if ~isempty(v) && min(v) < 0   % e.g. spikeTrials' "onset" stamps
            tr(1) = floor(min(v) * binFs) / binFs;
            if tr(1) > min(v); tr(1) = tr(1) - 1 / binFs; end
        end
    end
    if isinf(tr(2))
        tr(2) = tr(1);                 % no spike: an empty window (error below)
        if ~isempty(v)
            % whole bins through the one holding the last spike, which the
            % half-open test below would otherwise leave out
            nBins = floor((max(v) - tr(1)) * binFs) + 1;
            if tr(1) + nBins / binFs <= max(v); nBins = nBins + 1; end
            tr(2) = tr(1) + nBins / binFs;
        end
    end
end
if ~(tr(2) > tr(1))
    error('ChronuxDataset:BadTimeRange', ...
        'The binning window [%g %g] s is empty.', tr(1), tr(2));
end

if isnan(nBins)
    nBins = floor((tr(2) - tr(1)) * binFs + 1e-9);
end
if nBins < 1
    error('ChronuxDataset:NoBins', ...
        'A %g s window at BinFs = %g Hz gives no whole bin.', tr(2) - tr(1), binFs);
end
edges = tr(1) + (0:nBins) / binFs;     % nBins+1 edges, bins are [e(k) e(k+1))
t     = edges(1:nBins);                % left edge of each bin

nUnits = numel(S);
data = zeros(nBins, nUnits);
maxCount = zeros(1, nUnits);
dropped  = 0;
for k = 1:nUnits
    v = S(k).times;
    in = v >= edges(1) & v < edges(end);
    dropped = dropped + nnz(~in);
    c = histcounts(v(in), edges);      % [1 x nBins], half-open bins
    data(:, k) = c(:);
    maxCount(k) = max([0, c]);
end

params = obj.params(Fs=binFs, Tapers=opts.Tapers, Pad=opts.Pad, ...
    Fpass=opts.Fpass, Err=opts.Err, TrialAve=opts.TrialAve);

info = struct();
info.nBins       = nBins;
info.binFs       = binFs;
info.binWidthSec = 1 / binFs;
info.timeRange   = [edges(1) edges(end)];
info.nUnits      = nUnits;
info.labels      = labels;
info.counts      = sum(data, 1);
info.maxCount    = maxCount;
info.rates       = sum(data, 1) / (edges(end) - edges(1));
info.droppedOutsideRange = dropped;

if any(maxCount > 1)
    warning('ChronuxDataset:CoarseBins', ...
        ['Up to %d spikes land in one %g ms bin; Chronux''s binned point-process ' ...
         'routines assume finer bins. Raise BinFs, or use spikes/spikeTrials ' ...
         'with mtspectrumpt instead.'], max(maxCount), 1e3 / binFs);
end
end
