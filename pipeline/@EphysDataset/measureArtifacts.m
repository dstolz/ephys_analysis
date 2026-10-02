function M = measureArtifacts(obj, X, rows, opts)
%measureArtifacts  Score a stretch of signal with every artifact detection method.
%   M = ds.measureArtifacts(X, ROWS) scores the rows ROWS (logical
%   [nSamples x 1], or row indices) of the [nSamples x nChan] signal X
%   (microvolts) with each method detectArtifacts has, the baselines (median
%   / MAD) taken over all of X as detection takes them over its chunk, and
%   says whether each method would flag the stretch. Display only: nothing
%   is written. The Artifacts tab measures a stretch dragged over its plot
%   with it (Measure), against the window drawn.
%
%   Options
%   -------
%     Fs           sample rate (Hz); defaults to ds.Fs
%     Thresholds   [rms mad microvolts commonmode]; NaN entries take
%                  detectArtifacts' defaults (9, 8, 1500, 1500)
%     RmsWindowMs  running-RMS window (ms); NaN = ~1 ms
%     MinChannels  channels that must exceed together (default 2)
%     Channels     columns of X that take part (default NaN: all); the
%                  others report NaN and count toward nothing
%     CommonModeX  the same samples unreferenced, for "commonmode" (a
%                  common reference subtracts the very mean it looks for);
%                  default [] = X itself
%     CommonMode   false when no unreferenced signal is to hand: the
%                  "commonmode" row then reports NaN (default true)
%
%   M struct
%   --------
%     nSamples, durationSec, nChan
%     rmsUV, peakUV, p2pUV   [1 x nChan] RMS, peak |x| and peak-to-peak of the
%                            stretch (microvolts)
%     methods  struct array, one per method (rms, mad, microvolts, commonmode):
%       method, label, unit ("SD" or "uV"), threshold, rmsWindowMs (rms only)
%       channelPeak   [1 x nChan] the method's peak statistic in the stretch
%                     (commonmode: one value repeated; NaN when left out)
%       peak          its largest over the channels taking part
%       channelsOver  channels whose peak exceeds the threshold
%                     (commonmode: 1 or 0)
%       fraction      share of the stretch's samples the method flags
%                     (MinChannels applied; no stitching or padding)
%       flags         true when it flags any sample of the stretch
%
%   See also EphysDataset.detectArtifacts, EphysDataset.analyzeArtifacts.

arguments
    obj (1,1) EphysDataset
    X double
    rows (:,1)
    opts.Fs (1,1) double = NaN
    opts.Thresholds (1,4) double = NaN(1, 4)
    opts.RmsWindowMs (1,1) double = NaN
    opts.MinChannels (1,1) double {mustBeInteger, mustBePositive} = 2
    opts.Channels (1,:) double = NaN
    opts.CommonModeX double = []
    opts.CommonMode (1,1) logical = true
end

Fs = opts.Fs;
if isnan(Fs); Fs = obj.Fs; end
if ~(Fs > 0)
    error('EphysDataset:measureArtifacts:NoFs', ...
        'Sample rate unknown; pass Fs or run refreshMetadata first.');
end
[nSamples, nChan] = size(X);
if islogical(rows)
    if numel(rows) ~= nSamples
        error('EphysDataset:measureArtifacts:BadRows', ...
            'A logical ROWS must have one entry per row of X (%d).', nSamples);
    end
    rows = find(rows);
end
if isempty(rows) || any(rows < 1 | rows > nSamples | rows ~= round(rows))
    error('EphysDataset:measureArtifacts:BadRows', ...
        'ROWS must pick at least one row of X (1 to %d).', nSamples);
end
ch = opts.Channels;
if isscalar(ch) && isnan(ch)
    ch = 1:nChan;
end
if ~all(ch >= 1 & ch <= nChan & ch == round(ch))
    error('EphysDataset:measureArtifacts:BadChannels', ...
        'Channels must be column indices of X (1 to %d).', nChan);
end
nDet = numel(ch);
minCh = min(opts.MinChannels, max(nDet, 1));

S = X(rows, :);
M = struct();
M.nSamples = numel(rows);
M.durationSec = numel(rows) / Fs;
M.nChan = nChan;
M.rmsUV = sqrt(mean(S.^2, 1));
M.peakUV = max(abs(S), [], 1);
M.p2pUV = max(S, [], 1) - min(S, [], 1);

names = ["rms", "mad", "microvolts", "commonmode"];
labels = ["Running RMS", "MAD", "Absolute", "Common mode"];
units = ["SD", "SD", "uV", "uV"];
defaults = [9, 8, 1500, 1500];
thr = opts.Thresholds;
thr(isnan(thr)) = defaults(isnan(thr));

methods = struct('method', {}, 'label', {}, 'unit', {}, 'threshold', {}, 'rmsWindowMs', {}, ...
    'channelPeak', {}, 'peak', {}, 'channelsOver', {}, 'fraction', {}, 'flags', {});
for i = 1:numel(names)
    m = struct('method', names(i), 'label', labels(i), 'unit', units(i), ...
        'threshold', thr(i), 'rmsWindowMs', NaN, 'channelPeak', NaN(1, nChan), ...
        'peak', NaN, 'channelsOver', 0, 'fraction', 0, 'flags', false);
    if names(i) == "commonmode"
        if opts.CommonMode && nDet > 0
            Xc = X;
            if ~isempty(opts.CommonModeX)
                if ~isequal(size(opts.CommonModeX), size(X))
                    error('EphysDataset:measureArtifacts:BadCommonModeX', ...
                        'CommonModeX must be the size of X.');
                end
                Xc = opts.CommonModeX;
            end
            sc = artifactScore(Xc(:, ch), names(i), Fs, NaN);
            hit = sc(rows) > thr(i);
            m.peak = max(sc(rows));
            m.channelPeak(ch) = m.peak;
            m.channelsOver = double(m.peak > thr(i));
            m.fraction = mean(hit);
            m.flags = any(hit);
        end
    elseif nDet > 0
        [sc, m.rmsWindowMs] = artifactScore(X(:, ch), names(i), Fs, opts.RmsWindowMs);
        sc = sc(rows, :);
        exceed = sc > thr(i);
        hit = sum(exceed, 2) >= minCh;
        m.channelPeak(ch) = max(sc, [], 1);
        m.peak = max(m.channelPeak(ch));
        m.channelsOver = nnz(any(exceed, 1));
        m.fraction = mean(hit);
        m.flags = any(hit);
    end
    methods(i) = m;
end
M.methods = methods;
M.minChannels = opts.MinChannels;
end
