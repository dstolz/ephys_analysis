function [score, rmsWindowMs] = artifactScore(X, method, Fs, rmsWindowMs)
%artifactScore  The per-sample statistic an artifact detection method thresholds.
%   [SCORE, WMS] = artifactScore(X, METHOD, FS, RMSWINDOWMS) scores the
%   [nSamples x nChan] signal X (microvolts) as METHOD compares it with its
%   threshold, the baselines (median / MAD) taken over all of X:
%     "rms"        robust z of the per-channel running RMS (window
%                  RMSWINDOWMS ms; NaN or <= 0 = ~1 ms) [nSamples x nChan]
%     "mad"        robust z |x - median| / (1.4826*MAD)  [nSamples x nChan]
%     "microvolts" |x|                                   [nSamples x nChan]
%     "commonmode" |mean across channels|                [nSamples x 1]
%   WMS is the running-RMS window used (ms, after rounding to samples; NaN
%   for the other methods). Shared by detectArtifacts and measureArtifacts,
%   so a measurement scores a stretch exactly as detection does.
%
%   See also EphysDataset.detectArtifacts, EphysDataset.measureArtifacts.

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
        med = median(r, 1);
        sd  = median(abs(r - med), 1) * 1.4826;   % robust SD of the RMS
        sd(sd == 0) = eps;
        score = (r - med) ./ sd;              % positive => elevated amplitude
    case "mad"
        med = median(X, 1);
        madv = median(abs(X - med), 1) * 1.4826;
        madv(madv == 0) = eps;
        score = abs(X - med) ./ madv;
    case "microvolts"
        score = abs(X);
    case "commonmode"
        score = abs(mean(X, 2));
end
end
