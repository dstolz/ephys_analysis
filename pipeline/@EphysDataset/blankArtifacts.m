function X = blankArtifacts(obj, X, mask, opts)
%blankArtifacts  Replace artifact samples in [nSamples x nChan] data.
%   Y = ds.blankArtifacts(X, MASK) sets the rows of X flagged by the logical
%   MASK (as returned by detectArtifacts) to zero on every channel.
%
%   Y = ds.blankArtifacts(X, MASK, opts) with:
%     Fill   "zero" | "noise" | "hold" | "nan"   (default "zero")
%            "zero"  set flagged samples to 0
%            "noise" replace them with Gaussian noise matched to each
%                    channel's own noise level (see NoiseSigma/NoiseCenter).
%                    A sorter reads a zeroed block as a signal discontinuity
%                    - Kilosort4's whitening, threshold and drift estimates
%                    all assume continuous noise - so noise is what the
%                    pipeline fills artifact periods with by default
%                    (ArtifactConfig.Fill).
%            "hold"  hold the last clean sample value across each flagged run
%            "nan"   set flagged samples to NaN (caller must handle before int16)
%     NoiseSigma   scalar or [1 x nChan] per-channel SD of the fill, in the
%                  units of X (microvolts). Default [] estimates it from the
%                  unflagged rows of X itself (robust SD, 1.4826 x MAD);
%                  pass ds.noiseLevels() to match the whole recording.
%     NoiseCenter  scalar or [1 x nChan] per-channel mean of the fill
%                  (default []: the median of the unflagged rows of X).
%     Stream       RandStream used to draw the noise, so a run is
%                  reproducible (default []: the global stream).
%
%   The mask length must equal size(X,1).
%
%   See also EphysDataset.detectArtifacts, EphysDataset.noiseLevels.

arguments
    obj (1,1) EphysDataset %#ok<INUSA>
    X double
    mask (:,1) logical
    opts.Fill (1,1) string {mustBeMember(opts.Fill, ["zero","noise","hold","nan"])} = "zero"
    opts.NoiseSigma (1,:) double {mustBeNonnegative} = []
    opts.NoiseCenter (1,:) double = []
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
        % Per-channel white Gaussian noise. The level comes from the caller
        % (the whole recording's, from noiseLevels) or, when it does not, from
        % this block's own clean samples.
        [sigma, center] = fillLevels(X, mask, opts.NoiseSigma, opts.NoiseCenter, nChan);
        n = nnz(mask);
        if isempty(opts.Stream)
            R = randn(n, nChan);
        else
            R = randn(opts.Stream, n, nChan);
        end
        X(mask, :) = R .* sigma + center;

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
