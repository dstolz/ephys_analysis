function R = chronuxSpecgram(D, TB, S, opts)
%chronuxSpecgram  Multitaper spectrograms of a signal's channels (Chronux mtspecgramc).
%   R = chronuxSpecgram(D, TB, S, Name=Value): D a block of a signal
%   (chronuxBlockOf), TB a chronuxTimeBase, S chronuxSettings. Each
%   spectrum is computed over a window S.movingwin(1) s long, stepped by
%   S.movingwin(2) s (the tapers' T is the window). Pure: no I/O, no
%   graphics. Needs Chronux on the path.
%     aligned  every group's epochs (chronuxCut, S.detrend removed) go to
%              mtspecgramc with trialave = 1, then S.baseline compares
%              each frequency with its mean over S.baselineWindow
%              (chronuxNormalize). R.t is each window's center, s from
%              the event: rows w0 .. w0+n-1 of an epoch are centered at
%              its time window(1) + (w0-1 + (n-1)/2)/fs
%     range    each stretch clear of artifact periods (TB.runs) is one
%              spectrogram (S.detrend removed from it first); each window
%              goes to the nearest step of one grid of S.movingwin(2) s
%              steps over the range, NaN where no window was (the artifact
%              periods, and stretches shorter than a window). R.t is s on
%              the recording's continuous clock. TB needs the signal's
%              rows (chronuxTimeBase Fs=); its segments do not matter
%              here, so make them a window long (Segment=movingwin(1))
%   Errors chronuxSpecgram:TooLarge when the result would hold more than
%   MaxMB, chronuxSpecgram:Short when the window is longer than a trial.
%
%   Options
%     Check       called with no input after each channel (default [])
%     MaxMB       the result's limit (default 1000)
%     Provenance, Dataset   kept in R
%
%   R fields: kind "chronuxSpecgram", t [nT x 1] s, f [nF x 1] Hz, S [nT x
%   nF x nCh x nG] (power, or the baseline's units), labels, channels,
%   nTrials [nCh x nG], groups, params, tapers, movingwin, baseline (mode,
%   window, units: what S holds when normalized), aligned (true / false),
%   settings, timeBase, signal, fs, units (of power), dataset,
%   provenance, created.
%
%   See also chronuxSpectrum, chronuxTimeBase, renderChronux, mtspecgramc.
arguments
    D (1,1) struct
    TB (1,1) struct
    S (1,1) struct
    opts.Check = []
    opts.MaxMB (1,1) double = 1000
    opts.Provenance = struct()
    opts.Dataset (1,1) string = ""
end
ChronuxDataset.requireChronux();
fs = D.fs;
mw = S.movingwin;
nWin = round(mw(1) * fs);
nStep = round(mw(2) * fs);
if nWin < 2 || nStep < 1
    error('chronuxSpecgram:Short', 'The moving window [%g %g] s is under two samples (or its step under one) at %g Hz.', mw(1), mw(2), fs);
end
[params, tap] = chronuxParams(S, fs, nWin / fs);
params.err = 0;   % one spectrum per window: no error bars
nfft = max(2 ^ (nextpow2(nWin) + params.pad), nWin);
f = getfgrid(fs, nfft, params.fpass);
f = f(:);
nF = numel(f);
nCh = size(D.data, 2);
G = TB.groups;
nG = height(G);
aligned = TB.mode == "aligned";
nTr = zeros(nCh, nG);
if aligned
    nTime = round(TB.window(2) * fs) - round(TB.window(1) * fs) + 1;
    if nWin > nTime
        error('chronuxSpecgram:Short', 'The %g s moving window is longer than the %g s epoch.', mw(1), nTime / fs);
    end
    w0 = (1:nStep:nTime - nWin + 1).';
    t = round(TB.window(1) * fs) / fs + (w0 - 1 + (nWin - 1) / 2) / fs;
    tooBig(numel(t) * nF * nCh * nG, opts.MaxMB);
    P = NaN(numel(t), nF, nCh, nG);
    for c = 1:nCh
        [X, kept] = chronuxCut(D, TB, c, S.detrend);
        gi = TB.groupIndex(kept);
        for g = 1:nG
            Xg = X(:, gi == g);
            nTr(c, g) = size(Xg, 2);
            if nTr(c, g) == 0; continue; end
            s = mtspecgramc(Xg, mw, params);
            P(:, :, c, g) = reshape(s, numel(t), nF);
        end
        if ~isempty(opts.Check); opts.Check(); end
    end
    [P, bu] = chronuxNormalize(P, t, S.baseline, S.baselineWindow);
    base = struct('mode', S.baseline, 'window', S.baselineWindow, 'units', bu);
else
    step = nStep / fs;
    a = TB.runs(1, 1);
    b = TB.runs(end, 2);
    nT = floor((b - a) / step) + 1;
    tooBig(nT * nF * nCh, opts.MaxMB);
    t = a + (0:nT - 1).' * step + (nWin - 1) / 2 / fs;
    P = NaN(nT, nF, nCh, 1);
    runs = TB.runRows - (D.row0 - 1);   % rows of the block
    for c = 1:nCh
        for i = 1:size(runs, 1)
            n = runs(i, 2) - runs(i, 1) + 1;
            if n < nWin; continue; end
            x = double(D.data(runs(i, 1):runs(i, 2), c));
            switch S.detrend
                case "constant", x = x - mean(x);
                case "linear",   x = detrend(x, 1);
            end
            s = reshape(mtspecgramc(x, mw, params), [], nF);
            w0 = (1:nStep:n - nWin + 1).';
            first = TB.runs(i, 1) + (w0 - 1) / fs;   % each window's first sample, s
            k = round((first - a) / step) + 1;
            ok = k >= 1 & k <= nT;
            P(k(ok), :, c, 1) = s(ok, :);
        end
        nTr(c, 1) = nnz(any(isfinite(P(:, :, c, 1)), 2));   % windows
        if ~isempty(opts.Check); opts.Check(); end
    end
    base = struct('mode', "none", 'window', S.baselineWindow, 'units', "");
end
R = struct('kind', "chronuxSpecgram", 't', t, 'f', f, 'S', P, 'labels', reshape(string(D.labels), 1, []), ...
    'channels', D.channels, 'nTrials', nTr, 'groups', G, 'params', params, 'tapers', tap, 'movingwin', mw, ...
    'baseline', base, 'aligned', aligned, 'settings', S, 'timeBase', chronuxTimeSummary(TB), ...
    'signal', string(D.signal), 'fs', fs, 'units', chronuxPowerUnits(D.units), 'dataset', opts.Dataset, ...
    'provenance', opts.Provenance, 'created', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
end


function tooBig(n, maxMB)
mb = n * 8 / 2^20;
if mb > maxMB
    error('chronuxSpecgram:TooLarge', ['The spectrogram would hold %.0f MB (over %g MB): pick fewer channels, ' ...
        'a shorter range, a larger step or a narrower fpass.'], mb, maxMB);
end
end
