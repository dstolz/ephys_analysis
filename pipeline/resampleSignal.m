function [Y, FsOut] = resampleSignal(X, FsIn, FsOut)
%resampleSignal  A signal at another rate, anti-aliased, t = 0 kept on the first sample.
%   [Y, FS] = resampleSignal(X, FsIn, FsOut) resamples each column of X
%   ([nSamples x nChannels], row k at (k-1)/FsIn) to FS, the rate
%   FsIn*p/q for [p, q] = rat(FsOut/FsIn) (exact for the usual pairs:
%   2000 -> 500, 1000 -> 128, 30000 -> 1000), with the Signal Processing
%   Toolbox's resample. Y has ceil(nSamples*p/q) rows, row j at (j-1)/FS,
%   and the class of X (single stays single; the work is done in double).
%
%   The anti-aliasing filter is resample's linear-phase FIR low-pass (a
%   Kaiser window, n = 10, beta = 8), applied with its delay taken out, so
%   nothing shifts in time. Measured against the rate FS reached: content
%   up to 0.38*FS passes within 0.1%, the response is -3 dB at 0.475*FS
%   and -6 dB at the new Nyquist frequency FS/2, and everything above
%   0.62*FS is at least 60 dB down. So the band 0 to 0.38*FS is flat and
%   free of aliases (what folds into it comes from above 0.62*FS): pick FS
%   at least 2.6 times the highest frequency studied. When downsampling,
%   the filter's cutoff is the new rate's; when upsampling, the old rate's.
%
%   resample alone filters against zeros beyond the signal, which pulls
%   the first and last 10 output samples toward 0: X is mirrored past
%   both ends first (padarray 'symmetric', by a multiple of q input
%   samples so that t = 0 stays on the first sample) and the extra output
%   cut away, so a constant stays constant to its ends. The columns are
%   done a block at a time (about 2^25 samples), so a whole recording
%   needs little memory beyond X and Y. A NaN or Inf sample spreads over
%   the filter's length (10 samples of the lower rate each way).
%
%   FsOut = FsIn returns X unchanged. An empty X gives zeros(0, nChannels);
%   one row is returned as it is (resample needs more than one sample).
%
%   Used by mTRFExport.resample (the mTRF connectors), epochMatrix and
%   sessionData (epochMatrixSettings' signal.downsample: the dataset
%   browser's Downsample... dialog), and DatasetOutputs.resampled
%   (selectChannels' Rate: the analysis app's figures, the analysis
%   config's Source.Downsample).
%
%   Example
%     [Y, fs] = selectChannels(src, "LFP");          % 1000 Hz
%     [Y, fs] = resampleSignal(Y, fs, 250);          % 250 Hz: flat to 95 Hz
%
%   See also resample, mTRFExport, epochMatrixSettings, sessionData.

arguments
    X (:,:) {mustBeNumeric}
    FsIn (1,1) double {mustBePositive, mustBeFinite}
    FsOut (1,1) double {mustBePositive, mustBeFinite}
end

if FsOut == FsIn
    Y = X;
    return
end
[p, q] = rat(FsOut / FsIn, 1e-9);
reached = FsIn * p / q;
if abs(reached - FsOut) > 1e-9 * FsOut; FsOut = reached; end   % else the rate asked for, exactly
[n, nCol] = size(X);
cls = class(X);
if ~ismember(cls, ["single" "double"]); cls = 'double'; end
if n == 0
    Y = zeros(0, nCol, cls);
    return
end
if n == 1
    Y = cast(X, cls);   % resample needs more than one sample
    return
end
% the filter reaches 10 samples of the lower rate past each end: n*max(p,q)/p input
% samples; m is a multiple of q (so the output grid keeps t = 0) at least that long
m = q * ceil(10 / min(p, q));
nOut = ceil(n * p / q);
keep = m / q * p + (1:nOut);
Y = zeros(nOut, nCol, cls);
k = max(1, floor(2^25 / (n + 2 * m)));   % columns per block
for c0 = 1:k:nCol
    cc = c0:min(nCol, c0 + k - 1);
    y = resample(padarray(double(X(:, cc)), [m 0], 'symmetric'), p, q, 10, 8);
    Y(:, cc) = y(keep, :);
end
end
