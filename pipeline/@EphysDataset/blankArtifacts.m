function X = blankArtifacts(obj, X, mask, opts)
%blankArtifacts  Replace artifact samples in [nSamples x nChan] data.
%   Y = ds.blankArtifacts(X, MASK) sets the rows of X flagged by the logical
%   MASK (as returned by detectArtifacts) to zero on every channel.
%
%   Y = ds.blankArtifacts(X, MASK, opts) with:
%     Fill   "zero" | "noise" | "hold" | "nan"   (default "zero")
%            "zero"  set flagged samples to 0
%            "noise" replace each flagged run with a straight line from the
%                    signal's level just before it to its level just after
%                    it - the mean of the 1 ms of clean samples on either
%                    side, per channel - plus Gaussian noise matched to each
%                    channel's own noise level (see NoiseSigma). The line
%                    keeps the fill on the local broadband level (LFP, an
%                    artifact's tail), so the run's edges leave no step for
%                    a sorter's high-pass to turn into spike-like
%                    transients. A run with clean samples on one side only
%                    (at the start or end of X) is held at that side's
%                    level; see Context. A sorter reads a zeroed block as a
%                    signal discontinuity - Kilosort4's whitening, threshold
%                    and drift estimates all assume continuous noise - so
%                    noise is what the pipeline fills artifact periods with
%                    by default (ArtifactConfig.Fill).
%            "hold"  hold the last clean sample value across each flagged run
%            "nan"   set flagged samples to NaN (caller must handle before int16)
%     NoiseSigma   scalar or [1 x nChan] per-channel SD of the noise, in the
%                  units of X (microvolts). Default [] estimates it from the
%                  unflagged rows of X itself (robust SD, 1.4826 x MAD);
%                  pass ds.noiseLevels() to match the whole recording.
%     NoiseCenter  scalar or [1 x nChan] level of a run with no clean sample
%                  on either side - the mask covers X and no Context is given
%                  (default []: the median of the unflagged rows of X, or of
%                  every row when there are none).
%     Context      [k x nChan] clean samples that came just before X, e.g.
%                  the end of the previous chunk of a stream: a run at X's
%                  first row starts from their mean (default []: such a run
%                  is held at the level after it). toBin passes the clean
%                  samples before the run a chunk ended in, so a run cut by
%                  a chunk boundary stays continuous.
%     Fs           sample rate (Hz) the 1 ms is counted in (default ds.Fs)
%     Stream       RandStream used to draw the noise, so a run is
%                  reproducible (default []: the global stream).
%
%   The mask length must equal size(X,1).
%
%   See also EphysDataset.detectArtifacts, EphysDataset.noiseLevels.

arguments
    obj (1,1) EphysDataset
    X double
    mask (:,1) logical
    opts.Fill (1,1) string {mustBeMember(opts.Fill, ["zero","noise","hold","nan"])} = "zero"
    opts.NoiseSigma (1,:) double {mustBeNonnegative} = []
    opts.NoiseCenter (1,:) double = []
    opts.Context double = []
    opts.Fs (1,1) double = NaN
    opts.Stream = []
end

if numel(mask) ~= size(X, 1)
    error('EphysDataset:blankArtifacts:SizeMismatch', ...
        'mask length (%d) must equal size(X,1) (%d).', numel(mask), size(X, 1));
end

if ~any(mask)
    return
end

nChan = size(X, 2);

switch opts.Fill
    case "zero"
        X(mask, :) = 0;

    case "noise"
        % A line across each run between the levels on either side, plus
        % per-channel white Gaussian noise. The noise level comes from the
        % caller (the whole recording's, from noiseLevels) or, when it does
        % not, from this block's own clean samples.
        Fs = opts.Fs;
        if isnan(Fs); Fs = obj.Fs; end
        if ~(Fs > 0)
            error('EphysDataset:blankArtifacts:NoFs', ...
                'Sample rate unknown; pass opts.Fs or run refreshMetadata first.');
        end
        if ~isempty(opts.Context) && size(opts.Context, 2) ~= nChan
            error('EphysDataset:blankArtifacts:BadContext', ...
                'Context has %d column(s) but the data has %d channel(s).', ...
                size(opts.Context, 2), nChan);
        end
        [sigma, center] = fillLevels(X, mask, opts.NoiseSigma, opts.NoiseCenter, nChan);
        n = nnz(mask);
        if isempty(opts.Stream)
            R = randn(n, nChan);
        else
            R = randn(opts.Stream, n, nChan);
        end
        d = diff([0; mask; 0]);
        X = bridgeRuns(X, find(d == 1), find(d == -1) - 1, R .* sigma, center, ...
            opts.Context, max(1, round(1e-3 * Fs)));

    case "nan"
        X(mask, :) = NaN;

    case "hold"
        % For each flagged run, hold the last clean sample (0 if run starts at 1)
        d = diff([0; mask; 0]);
        on  = find(d == 1);
        off = find(d == -1) - 1;
        for k = 1:numel(on)
            if on(k) > 1
                X(on(k):off(k), :) = repmat(X(on(k)-1, :), off(k)-on(k)+1, 1);
            else
                X(on(k):off(k), :) = 0;
            end
        end
end
end


function [sigma, center] = fillLevels(X, mask, sigma, center, nChan)
%fillLevels  Resolve the noise SD and centre to [1 x nChan] rows.
%   An empty one is estimated from the rows of X the mask leaves clean (from
%   every row when the mask covers the block), robustly so a second artifact
%   the detector missed does not inflate the fill.
if isempty(sigma) || isempty(center)
    clean = X(~mask, :);
    if isempty(clean); clean = X; end
    med = median(clean, 1);
    if isempty(sigma);  sigma  = median(abs(clean - med), 1) * 1.4826; end
    if isempty(center); center = med; end
end
sigma  = expand(sigma,  nChan, 'NoiseSigma');
center = expand(center, nChan, 'NoiseCenter');
end


function v = expand(v, nChan, name)
if isscalar(v)
    v = repmat(v, 1, nChan);
elseif numel(v) ~= nChan
    error('EphysDataset:blankArtifacts:BadNoiseLevels', ...
        '%s has %d value(s) but the data has %d channel(s).', name, numel(v), nChan);
end
v = reshape(v, 1, nChan);
end
