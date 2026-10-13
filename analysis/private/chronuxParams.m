function [params, info] = chronuxParams(S, fs, T)
%chronuxParams  The Chronux params of settings S (chronuxSettings) for data at FS Hz, trials T s long.
%   [PARAMS, INFO] = chronuxParams(S, FS, T): tapers [TW K] (taperMode
%   "TWK" as given; "Wp" from the half bandwidth W over T,
%   ChronuxDataset.tapersFor), pad, Fs = FS, fpass (fmax Inf = FS/2; a
%   fmax above FS/2 is cut to it), err ([1 p] theoretical, [2 p]
%   jackknife, 0 none) and trialave 1, checked by
%   ChronuxDataset.makeParams. T is the length Chronux computes each
%   spectrum over: the trial, or the moving window of a spectrogram.
%   INFO: TW, K, halfBandwidthHz (TW/T), T, notes (strings: K above
%   2TW-1, fmax cut to Nyquist).
%
%   See also chronuxSettings, ChronuxDataset.makeParams, ChronuxDataset.tapersFor.
notes = strings(1, 0);
if S.taperMode == "Wp"
    tapers = ChronuxDataset.tapersFor(S.W, T, P=S.p);
else
    tapers = [S.TW S.K];
end
if tapers(2) > 2 * tapers(1) - 1
    notes(end+1) = sprintf("K = %d is above 2TW-1 = %g: the extra tapers are poorly concentrated", tapers(2), 2 * tapers(1) - 1);
end
fp = S.fpass;
if isinf(fp(2)); fp(2) = fs / 2; end
if fp(2) > fs / 2
    notes(end+1) = sprintf("fmax %g Hz is above Nyquist at %g Hz: cut to %g Hz", fp(2), fs, fs / 2);
    fp(2) = fs / 2;
end
if fp(1) >= fp(2)
    error('chronuxParams:Fpass', 'fpass [%g %g] Hz leaves no frequencies below Nyquist (%g Hz).', S.fpass(1), S.fpass(2), fs / 2);
end
switch S.err
    case "none",        er = 0;
    case "theoretical", er = [1 S.errP];
    case "jackknife",   er = [2 S.errP];
end
w = warning('off', 'ChronuxDataset:TapersK');   % said in the notes instead
restore = onCleanup(@() warning(w));
params = ChronuxDataset.makeParams(fs, Tapers=tapers, Pad=S.pad, Fpass=fp, Err=er, TrialAve=1);
info = struct('TW', tapers(1), 'K', tapers(2), 'halfBandwidthHz', tapers(1) / T, 'T', T, 'notes', notes);
end
