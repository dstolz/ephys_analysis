function X = filterContinuous(obj, X, opts)
%filterContinuous  Zero-phase Butterworth filtering of [nSamples x nChan] data.
%   Y = ds.filterContinuous(X) high-pass filters X (default 300 Hz) using a
%   zero-phase 4th-order Butterworth design and FILTFILT, applied column-wise
%   (time down the rows, channels across the columns). A cut-off below 0.5%
%   of Nyquist (or Order > 4) is applied as second-order sections, which stay
%   stable far below the sample rate (1 Hz, or a [1 300] band at 20-30 kHz),
%   where the transfer-function form loses precision or produces NaN; above
%   that the transfer function is exact and ~3x faster, so it is used there.
%
%   Y = ds.filterContinuous(X, opts) with name-value options:
%     Type    "highpass" | "lowpass" | "bandpass"   (default "highpass")
%     Cutoff  scalar Hz (high/low-pass) or [lo hi] Hz (bandpass)  (default 300)
%     Order   filter order (default 4)
%     Fs      sample rate (Hz); defaults to ds.Fs
%
%   All cutoffs must be strictly below Nyquist (Fs/2). This method is static-
%   friendly: it uses only X, opts and ds.Fs, so it can be applied per file in
%   the streaming toBin path or to an in-memory matrix.
%
%   Filtering is done in double; Y is returned in the class of X. Integer
%   inputs are rounded and saturated on the way back, so filter unsigned
%   integer data as a signed or floating-point type (high-pass output is
%   bipolar and would clip at zero).
%
%   Requires the Signal Processing Toolbox (BUTTER, ZP2SOS, SOS2TF, FILTFILT).
%
%   See also BUTTER, ZP2SOS, FILTFILT, EphysDataset.toBin.

arguments
    obj (1,1) EphysDataset
    X {mustBeNumeric}
    opts.Type (1,1) string {mustBeMember(opts.Type, ["highpass","lowpass","bandpass"])} = "highpass"
    opts.Cutoff (1,:) double {mustBePositive} = 300
    opts.Order (1,1) double {mustBeInteger, mustBePositive} = 4
    opts.Fs (1,1) double = NaN
end

Fs = opts.Fs;
if isnan(Fs)
    Fs = obj.Fs;
end
if isnan(Fs) || Fs <= 0
    error('EphysDataset:filterContinuous:NoFs', ...
        'Sample rate unknown; pass opts.Fs or run refreshMetadata first.');
end

nyq = Fs / 2;

switch opts.Type
    case "highpass"
        if ~isscalar(opts.Cutoff)
            error('EphysDataset:filterContinuous:BadCutoff', ...
                'highpass requires a scalar Cutoff.');
        end
        if opts.Cutoff >= nyq
            error('EphysDataset:filterContinuous:CutoffAboveNyquist', ...
                'Cutoff (%g Hz) must be below Nyquist (%g Hz).', opts.Cutoff, nyq);
        end
        [z, p, k] = butter(opts.Order, opts.Cutoff / nyq, 'high');

    case "lowpass"
        if ~isscalar(opts.Cutoff)
            error('EphysDataset:filterContinuous:BadCutoff', ...
                'lowpass requires a scalar Cutoff.');
        end
        if opts.Cutoff >= nyq
            error('EphysDataset:filterContinuous:CutoffAboveNyquist', ...
                'Cutoff (%g Hz) must be below Nyquist (%g Hz).', opts.Cutoff, nyq);
        end
        [z, p, k] = butter(opts.Order, opts.Cutoff / nyq, 'low');

    case "bandpass"
        if numel(opts.Cutoff) ~= 2
            error('EphysDataset:filterContinuous:BadCutoff', ...
                'bandpass requires Cutoff = [low high].');
        end
        if opts.Cutoff(1) >= opts.Cutoff(2)
            error('EphysDataset:filterContinuous:BadBand', ...
                'bandpass Cutoff must be [low high] with low < high.');
        end
        if opts.Cutoff(2) >= nyq
            error('EphysDataset:filterContinuous:CutoffAboveNyquist', ...
                'Upper cutoff (%g Hz) must be below Nyquist (%g Hz).', opts.Cutoff(2), nyq);
        end
        [z, p, k] = butter(opts.Order, opts.Cutoff / nyq, 'bandpass');
end

% Second-order sections keep a low cut-off stable: the [b,a] polynomials of a
% [10 300] Hz band at 30 kHz give NaN and a 1 Hz high-pass is off by ~1.5 uV.
% But FILTFILT runs sections ~3x slower, so the transfer-function form is kept
% where it is exact - every cut-off at least 0.5% of Nyquist (75 Hz at 30 kHz)
% and Order <= 4, where the two agree to ~1e-6 uV - which covers the spike and
% artifact bands. A single section (a 2nd-order high- or low-pass) goes as
% [b,a] too: FILTFILT cannot tell a 1x6 section from a transfer function, and
% at second order both forms are equally stable.
% filtfilt operates column-wise -> [nSamples x nChan] is already correct.
% Filter in double for numerical stability, then return in the input class.
[sos, g] = zp2sos(z, p, k);
if size(sos, 1) == 1 || (opts.Order <= 4 && min(opts.Cutoff / nyq) >= 0.005)
    [b, a] = sos2tf(sos, g);
    coeffs = {b, a};
else
    coeffs = {sos, g};
end
inClass = class(X);
X = cast(filtfilt(coeffs{:}, double(X)), inClass);
end
