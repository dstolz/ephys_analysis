function [score, rmsWindowMs] = artifactScore(X, method, Fs, rmsWindowMs, base)
%artifactScore  The per-sample statistic an artifact detection method thresholds.
%   [SCORE, WMS] = artifactScore(X, METHOD, FS, RMSWINDOWMS, BASE) scores the
%   [nSamples x nChan] signal X (microvolts) as METHOD compares it with its
%   threshold:
%     "rms"        robust z of the per-channel running RMS (window
%                  RMSWINDOWMS ms; NaN or <= 0 = ~1 ms) [nSamples x nChan]
%     "mad"        robust z |x - median| / (1.4826*MAD)  [nSamples x nChan]
%     "microvolts" |x|                                   [nSamples x nChan]
%     "commonmode" |mean across channels|                [nSamples x 1]
%   WMS is the running-RMS window used (ms, after rounding to samples; NaN
%   for the other methods). Shared by detectArtifacts and measureArtifacts,
%   so a measurement scores a stretch exactly as detection does.
%
%   BASE (optional struct with fields center and sigma, each a scalar or
%   [1 x nChan]; [] = from X) gives the baselines the z-scores are taken
%   against: the median (center) and robust SD (sigma, 1.4826 x MAD) of the
%   running RMS ("rms") or of the signal ("mad"). A NaN entry is taken from X
%   for that channel. Without BASE they are taken over all of X, NaN samples
%   left out; for "rms", from every 8th sample of the running RMS once X has
%   2^17 rows or more (the running RMS is an average of the window, so the
%   thinned values give the same level). A caller scoring a piece of a
%   recording passes the recording's own baselines (artifactBaseline), so
%   the score does not depend on where the piece was cut. BASE = struct(
%   'center', 0, 'sigma', 1) gives the running RMS itself.
%
%   See also EphysDataset.detectArtifacts, EphysDataset.measureArtifacts.

if nargin < 5
    base = [];
end
rmsWindowMs_in = rmsWindowMs;
rmsWindowMs = NaN;
switch method
    case "rms"
        % Per-channel running RMS amplitude, then a robust z-score of that RMS
        % against the channel's own baseline (median / MAD of the RMS). Squaring
        % makes it polarity-blind; the running window smooths single-sample
        % spikes so genuine high-amplitude episodes stand out.
        if isnan(rmsWindowMs_in) || rmsWindowMs_in <= 0
            w = max(1, round(Fs * 0.001));   % ~1 ms default
        else
            w = max(1, round(rmsWindowMs_in * 1e-3 * Fs));
        end
        rmsWindowMs = 1e3 * w / Fs;           % actual window after rounding
        r = sqrt(movmean(X.^2, w, 1));
        stride = 1;
        if w >= 8 && size(r, 1) >= 2^17
            stride = 8;                       % a baseline needs no more than every 8th averaged value
        end
        [med, sd] = levels(r, base, stride);
        score = (r - med) ./ sd;              % positive => elevated amplitude
    case "mad"
        [med, sd] = levels(X, base, 1);
        score = abs(X - med) ./ sd;
    case "microvolts"
        score = abs(X);
    case "commonmode"
        score = abs(mean(X, 2));
end
end


function [med, sd] = levels(r, base, stride)
%levels  Median and robust SD (1.4826 x MAD) of each column of R: BASE's
%   where it has a value, else R's own (every STRIDE-th row), NaN left out.
%   sd is never 0.
nCol = size(r, 2);
med = NaN(1, nCol);
sd = NaN(1, nCol);
if ~isempty(base)
    med = expandRow(base.center, nCol);
    sd = expandRow(base.sigma, nCol);
end
miss = isnan(med) | isnan(sd);
if any(miss)
    rs = r(1:stride:end, miss);
    m = median(rs, 1, 'omitnan');
    med(miss) = m;
    sd(miss) = median(abs(rs - m), 1, 'omitnan') * 1.4826;   % robust SD of the statistic
end
sd(sd == 0) = eps;
end


function v = expandRow(v, nCol)
%expandRow  A scalar or [1 x nCol] baseline as a [1 x nCol] row.
v = double(v(:).');
if isscalar(v)
    v = repmat(v, 1, nCol);
elseif numel(v) ~= nCol
    error('EphysDataset:artifactScore:BaselineSize', ...
        'The baseline has %d value(s) but the data has %d channel(s).', numel(v), nCol);
end
end
