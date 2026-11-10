function R = phaseCoherence(D, TB, S, opts)
%phaseCoherence  Inter-trial phase coherence (ITPC) of a signal's channels: how alike each frequency's phase is from trial to trial.
%   R = phaseCoherence(D, TB, S, Name=Value): D a block of a signal
%   (chronuxBlockOf), TB an aligned chronuxTimeBase (the epochs around an
%   event and their trial groups), S chronuxSettings (the multitaper
%   settings the spectral figure panels share: taperMode, TW, K, W, p,
%   pad, fpass, detrend, err, errP, overTime, movingwin). For each channel
%   and trial group, each trial (chronuxCut, S.detrend removed) is
%   multiplied by each Slepian taper (dpss) and Fourier transformed; each
%   coefficient is kept as its phase alone (a unit phasor), and
%       ITPC(f) = mean over the K tapers of |mean over the N trials of exp(i*phase)|
%   0 when the phases are random from trial to trial, 1 when every trial
%   has the same phase. One taper (TW 1, K 1) gives the usual single-taper
%   ITPC; several average independent estimates, a smoother ITPC with
%   less variance (each taper's phase is consistent across the trials,
%   so they are averaged after the magnitude, never pooled).
%     S.overTime false   one ITPC over the whole epoch (TB.window)
%     S.overTime true    an ITPC over each moving window S.movingwin
%                        ([window step] s) along the epoch: an image over
%                        time and frequency, R.t each window's center, s
%                        from the event (as chronuxSpecgram places them)
%   The 0 Hz and Nyquist bins are left out (their coefficients are real:
%   their phase is 0 or pi whatever the signal).
%   With S.err "theoretical" or "jackknife", R.confC is the level the ITPC
%   of N trials of random phases stays under with probability 1 - S.errP,
%   the same statistic over 4000 draws of uniform random phases (a fixed
%   seed: the same level on every call; for many trials, Rayleigh's
%   asymptotic law of each taper's resultant). With one taper it is close
%   to Rayleigh's sqrt(-log(errP) / N); the ITPC is biased up by about
%   sqrt(pi / (4N)) with few trials, which this level accounts for. With
%   "jackknife" (not over time) R.Clo / R.Chi are the confidence bars at
%   1 - S.errP: the leave-one-trial-out jackknife's standard error times
%   the t quantile (tinv, Statistics and Machine Learning Toolbox), within
%   0 to 1. Pure: no I/O, no graphics. Needs no Chronux (the tapers are the
%   Signal Processing Toolbox's dpss).
%
%   Options: Check (called with no input after each channel), MaxMB (the
%   result's limit, default 1000), Provenance, Dataset.
%   Errors phaseCoherence:Aligned (TB is not aligned), phaseCoherence:Short
%   (a moving window under two samples or longer than the epoch),
%   phaseCoherence:Fpass (no frequency left in fpass), phaseCoherence:TooLarge.
%
%   R fields: kind "phaseCoherence", f [nF x 1] Hz, t [nT x 1] s (over
%   time; else 0 x 1), C [nF x nCh x nG] (over time [nT x nF x nCh x nG]),
%   Clo / Chi ([] without jackknife bars), confC [nCh x nG] (NaN without
%   a level), labels, channels, nTrials [nCh x nG], groups, params,
%   tapers, movingwin, overTime, aligned (true), settings, timeBase,
%   signal, fs, dataset, provenance, created.
%
%   Example: the ITPC of an LFP channel over the epochs around Stim onset
%     TB = chronuxTimeBase("aligned", E=E, Window=[-0.2 0.8]);
%     S = chronuxSettings(struct('analysis', "itpc", 'TW', 2, 'K', 3, 'fpass', [2 80]));
%     R = phaseCoherence(chronuxBlockOf(Y, fs, meta, "LFP", meta.label), TB, S);
%     plot(R.f, R.C(:, 1, 1)); yline(R.confC(1, 1), '--');
%
%   See also chronuxSettings, chronuxSpecgram, chronuxCoherence, chronuxTimeBase, dpss.
arguments
    D (1,1) struct
    TB (1,1) struct
    S (1,1) struct
    opts.Check = []
    opts.MaxMB (1,1) double = 1000
    opts.Provenance = struct()
    opts.Dataset (1,1) string = ""
end
if TB.mode ~= "aligned"
    error('phaseCoherence:Aligned', 'Phase coherence is taken across trials aligned on an event: give an aligned time base.');
end
fs = D.fs;
nTime = round(TB.window(2) * fs) - round(TB.window(1) * fs) + 1;
mw = S.movingwin;
if S.overTime
    nWin = round(mw(1) * fs);
    nStep = round(mw(2) * fs);
    if nWin < 2 || nStep < 1
        error('phaseCoherence:Short', 'The moving window [%g %g] s is under two samples (or its step under one) at %g Hz.', mw(1), mw(2), fs);
    end
    if nWin > nTime
        error('phaseCoherence:Short', 'The %g s moving window is longer than the %g s epoch.', mw(1), nTime / fs);
    end
    w0 = (1:nStep:nTime - nWin + 1).';
    t = round(TB.window(1) * fs) / fs + (w0 - 1 + (nWin - 1) / 2) / fs;
else
    nWin = nTime;
    w0 = 1;
    t = zeros(0, 1);
end
[params, tap] = chronuxParams(S, fs, nWin / fs);
nfft = max(2 ^ (nextpow2(nWin) + params.pad), nWin);
fAll = (0:nfft - 1).' * fs / nfft;   % Chronux's grid (getfgrid)
fIdx = find(fAll >= params.fpass(1) & fAll <= params.fpass(2) & fAll > 0 & abs(fAll - fs / 2) > 1e-9 * fs);
if isempty(fIdx)
    error('phaseCoherence:Fpass', ['fpass [%g %g] Hz holds no frequency between 0 Hz and Nyquist on the %g Hz grid ' ...
        '(a %g s window): widen it.'], params.fpass(1), params.fpass(2), fs / nfft, nWin / fs);
end
f = fAll(fIdx);
nF = numel(f);
nCh = size(D.data, 2);
G = TB.groups;
nG = height(G);
nT = max(1, numel(t));
mb = nT * nF * nCh * nG * 8 / 2^20;
if mb > opts.MaxMB
    error('phaseCoherence:TooLarge', ['The phase coherence would hold %.0f MB (over %g MB): pick fewer channels, ' ...
        'a larger step or a narrower fpass.'], mb, opts.MaxMB);
end
tapers = dpss(nWin, tap.TW, tap.K);   % [nWin x K]: the phase does not depend on their scale
K = size(tapers, 2);
jack = ~S.overTime && S.err == "jackknife";
level = S.err ~= "none";
if S.overTime
    C = NaN(nT, nF, nCh, nG);
else
    C = NaN(nF, nCh, nG);
end
lo = []; hi = [];
if jack; lo = C; hi = C; end
confC = NaN(nCh, nG);
nTr = zeros(nCh, nG);
levels = dictionary(double.empty(0, 1), double.empty(0, 1));   % the null level by trial count (one simulation each)
for c = 1:nCh
    [X, kept] = chronuxCut(D, TB, c, S.detrend);
    gi = TB.groupIndex(kept);
    for g = 1:nG
        Xg = X(:, gi == g);
        N = size(Xg, 2);
        nTr(c, g) = N;
        if N == 0; continue; end
        for w = 1:numel(w0)
            U = phasors(Xg(w0(w) + (0:nWin - 1), :), tapers, nfft, fIdx);   % [nF x N x K]
            itpc = mean(abs(mean(U, 2, 'omitnan')), 3);                     % [nF x 1]
            if S.overTime
                C(w, :, c, g) = reshape(itpc, 1, []);
            else
                C(:, c, g) = itpc;
            end
        end
        if jack && N >= 3
            [lo(:, c, g), hi(:, c, g)] = jackknifeBars(U, C(:, c, g), S.errP);
        end
        if level
            if ~isKey(levels, N); levels(N) = nullLevel(N, K, S.errP); end
            confC(c, g) = levels(N);
        end
    end
    if ~isempty(opts.Check); opts.Check(); end
end
R = struct('kind', "phaseCoherence", 'f', f, 't', t, 'C', C, 'Clo', lo, 'Chi', hi, 'confC', confC, ...
    'labels', reshape(string(D.labels), 1, []), 'channels', D.channels, 'nTrials', nTr, 'groups', G, ...
    'params', params, 'tapers', tap, 'movingwin', mw, 'overTime', logical(S.overTime), 'aligned', true, ...
    'settings', S, 'timeBase', chronuxTimeSummary(TB), 'signal', string(D.signal), 'fs', fs, ...
    'dataset', opts.Dataset, 'provenance', opts.Provenance, ...
    'created', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
end


function U = phasors(X, tapers, nfft, fIdx)
%phasors  Each trial's (a column of X) tapered Fourier coefficients at the bins FIDX as unit phasors: [nF x nTrials x K].
%   A coefficient of 0 (a flat trial) has no phase: NaN, left out of the mean.
J = fft(X .* permute(tapers, [1 3 2]), nfft, 1);
J = J(fIdx, :, :);
U = J ./ abs(J);
U(~isfinite(U)) = NaN;
end


function [lo, hi] = jackknifeBars(U, itpc, p)
%jackknifeBars  The ITPC's 1-P confidence bars from the leave-one-trial-out jackknife.
%   U [nF x N x K]: the unit phasors; ITPC [nF x 1]: the estimate over all N.
N = size(U, 2);
U(isnan(U)) = 0;
Sk = sum(U, 2);                                    % [nF x 1 x K]
loo = mean(abs(Sk - U), 3) / (N - 1);              % [nF x N]: each trial left out
se = sqrt((N - 1) / N * sum((loo - mean(loo, 2)) .^ 2, 2));
q = tinv(1 - p / 2, N - 1);
lo = max(0, itpc - q * se);
hi = min(1, itpc + q * se);
end


function c = nullLevel(N, K, p)
%nullLevel  The 1-P quantile of the ITPC (the mean over K tapers of each one's resultant length) of N trials of random phases.
%   Simulated: exactly (uniform phases) while that is small, else each
%   taper's resultant length drawn from its asymptotic Rayleigh law,
%   sqrt(-log(u) / N), u uniform. A fixed seed per (N, K): the same level
%   on every call.
nSim = 4000;
rs = RandStream('mt19937ar', 'Seed', N * 64 + K);
if N * K * nSim <= 4e6
    v = zeros(nSim, 1);
    chunk = max(1, floor(1e6 / (N * K)));
    for s = 1:chunk:nSim
        m = min(chunk, nSim - s + 1);
        ph = 2 * pi * rand(rs, N, K, m);
        v(s:s + m - 1) = reshape(mean(abs(mean(exp(1i * ph), 1)), 2), [], 1);
    end
else
    v = mean(sqrt(-log(rand(rs, nSim, K)) / N), 2);
end
c = quantile(v, 1 - p);
end
