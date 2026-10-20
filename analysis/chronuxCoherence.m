function R = chronuxCoherence(D, TB, S, opts)
%chronuxCoherence  Multitaper coherence between pairs of a signal's channels (Chronux coherencyc, cohgramc).
%   R = chronuxCoherence(D, TB, S, Name=Value): D a block of a signal
%   (chronuxBlockOf) holding the channels of every pair, TB a
%   chronuxTimeBase, S chronuxSettings. The pairs are S.seed against
%   S.partner (pairMode "pair"), or S.seed against every other channel
%   of S.channels (all when empty; "seed"), all as columns of the
%   signal. For each pair and group the trials of both channels
%   (chronuxCut, together, so a trial dropped from one is dropped from
%   both) go to coherencyc with trialave = 1: the coherence magnitude C
%   (0 to 1) and phase phi (radians: the angle of the cross-spectrum of a
%   and b, Chronux's convention) averaged over the trials and tapers, with confC (the magnitude a pair
%   of independent signals stays under at 1-p, err "theoretical" or
%   "jackknife"), phistd and, jackknife, the bars Clo / Chi. S.overTime:
%   cohgramc over the moving window instead, as chronuxSpecgram does (over
%   epochs: R.t from the event; over a stretch: one per clear stretch on
%   one time grid, NaN in between, no bars). Pure: no I/O, no graphics.
%   Needs Chronux on the path.
%
%   Options: Check (called after each pair), MaxMB (a coherogram's limit,
%   default 1000), Provenance, Dataset.
%
%   R fields: kind "chronuxCoherence" (or "chronuxCohgram"), f [nF x 1],
%   t [nT x 1] (cohgram), C and phi [nF x nP x nG] ([nT x nF x nP x nG]),
%   Clo / Chi ([] without jackknife bars), confC [nP x nG] (NaN without
%   bars), phistd ([] without), pairs (a table: a, b the signal's columns,
%   labelA, labelB, label "a-b"), labels (one per pair), nTrials [nP x nG],
%   groups, params, tapers, movingwin, aligned, settings, timeBase,
%   signal, fs, dataset, provenance, created.
%
%   See also chronuxSpectrum, chronuxSpecgram, renderChronux, coherencyc, cohgramc.
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
P = chronuxPairs(S, D.channels, D.labels);
nP = height(P);
G = TB.groups;
nG = height(G);
aligned = TB.mode == "aligned";
col = @(c) find(D.channels == c, 1);
if S.overTime
    kind = "chronuxCohgram";
    mw = S.movingwin;
    nWin = round(mw(1) * fs);
    nStep = round(mw(2) * fs);
    if nWin < 2 || nStep < 1
        error('chronuxCoherence:Short', 'The moving window [%g %g] s is under two samples (or its step under one) at %g Hz.', mw(1), mw(2), fs);
    end
    [params, tap] = chronuxParams(S, fs, nWin / fs);
    params.err = 0;
else
    kind = "chronuxCoherence";
    mw = S.movingwin;
    T = diff(round(TB.window * fs)) / fs + 1 / fs;
    [params, tap] = chronuxParams(S, fs, T);
    nWin = round(T * fs);
end
nfft = max(2 ^ (nextpow2(nWin) + params.pad), nWin);
f = getfgrid(fs, nfft, params.fpass);
f = f(:);
nF = numel(f);
nTr = zeros(nP, nG);
confC = NaN(nP, nG);
lo = []; hi = []; phistd = [];
t = zeros(0, 1);
if ~S.overTime
    C = NaN(nF, nP, nG);
    phi = C;
    hasErr = params.err(1) > 0;
    jack = params.err(1) == 2;
    if hasErr; phistd = C; end
    if jack; lo = C; hi = C; end
    for i = 1:nP
        [X, kept] = chronuxCut(D, TB, [col(P.a(i)) col(P.b(i))], S.detrend);
        gi = TB.groupIndex(kept);
        for g = 1:nG
            sel = gi == g;
            nTr(i, g) = nnz(sel);
            if nTr(i, g) == 0; continue; end
            x1 = X(:, sel, 1);
            x2 = X(:, sel, 2);
            if jack
                [c, ph, ~, ~, ~, ~, cc, ps, ce] = coherencyc(x1, x2, params);
                lo(:, i, g) = ce(1, :).';
                hi(:, i, g) = ce(2, :).';
            elseif hasErr
                [c, ph, ~, ~, ~, ~, cc, ps] = coherencyc(x1, x2, params);
            else
                [c, ph] = coherencyc(x1, x2, params);
            end
            C(:, i, g) = c(:);
            phi(:, i, g) = ph(:);
            if hasErr
                confC(i, g) = cc;
                phistd(:, i, g) = ps(:);
            end
        end
        if ~isempty(opts.Check); opts.Check(); end
    end
elseif aligned
    nTime = round(TB.window(2) * fs) - round(TB.window(1) * fs) + 1;
    if nWin > nTime
        error('chronuxCoherence:Short', 'The %g s moving window is longer than the %g s epoch.', mw(1), nTime / fs);
    end
    w0 = (1:nStep:nTime - nWin + 1).';
    t = round(TB.window(1) * fs) / fs + (w0 - 1 + (nWin - 1) / 2) / fs;
    tooBig(2 * numel(t) * nF * nP * nG, opts.MaxMB);
    C = NaN(numel(t), nF, nP, nG);
    phi = C;
    for i = 1:nP
        [X, kept] = chronuxCut(D, TB, [col(P.a(i)) col(P.b(i))], S.detrend);
        gi = TB.groupIndex(kept);
        for g = 1:nG
            sel = gi == g;
            nTr(i, g) = nnz(sel);
            if nTr(i, g) == 0; continue; end
            [c, ph] = cohgramc(X(:, sel, 1), X(:, sel, 2), mw, params);
            C(:, :, i, g) = reshape(c, numel(t), nF);
            phi(:, :, i, g) = reshape(ph, numel(t), nF);
        end
        if ~isempty(opts.Check); opts.Check(); end
    end
else
    step = nStep / fs;
    a = TB.runs(1, 1);
    nT = floor((TB.runs(end, 2) - a) / step) + 1;
    tooBig(2 * nT * nF * nP, opts.MaxMB);
    t = a + (0:nT - 1).' * step + (nWin - 1) / 2 / fs;
    C = NaN(nT, nF, nP, 1);
    phi = C;
    runs = TB.runRows - (D.row0 - 1);
    for i = 1:nP
        for r = 1:size(runs, 1)
            n = runs(r, 2) - runs(r, 1) + 1;
            if n < nWin; continue; end
            x = double(D.data(runs(r, 1):runs(r, 2), [col(P.a(i)) col(P.b(i))]));
            switch S.detrend
                case "constant", x = x - mean(x, 1);
                case "linear",   x = detrend(x, 1);
            end
            [c, ph] = cohgramc(x(:, 1), x(:, 2), mw, params);
            c = reshape(c, [], nF);
            ph = reshape(ph, [], nF);
            w0 = (1:nStep:n - nWin + 1).';
            k = round((TB.runs(r, 1) + (w0 - 1) / fs - a) / step) + 1;
            ok = k >= 1 & k <= nT;
            C(k(ok), :, i, 1) = c(ok, :);
            phi(k(ok), :, i, 1) = ph(ok, :);
        end
        nTr(i, 1) = nnz(any(isfinite(C(:, :, i, 1)), 2));   % windows
        if ~isempty(opts.Check); opts.Check(); end
    end
end
R = struct('kind', kind, 'f', f, 't', t, 'C', C, 'phi', phi, 'Clo', lo, 'Chi', hi, 'confC', confC, ...
    'phistd', phistd, 'pairs', P, 'labels', reshape(P.label, 1, []), 'nTrials', nTr, 'groups', G, 'params', params, ...
    'tapers', tap, 'movingwin', mw, 'aligned', aligned, 'settings', S, 'timeBase', chronuxTimeSummary(TB), ...
    'signal', string(D.signal), 'fs', fs, 'dataset', opts.Dataset, 'provenance', opts.Provenance, ...
    'created', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
end


function tooBig(n, maxMB)
mb = n * 8 / 2^20;
if mb > maxMB
    error('chronuxCoherence:TooLarge', ['The coherogram would hold %.0f MB (over %g MB): pick fewer pairs, ' ...
        'a shorter range, a larger step or a narrower fpass.'], mb, maxMB);
end
end


function P = chronuxPairs(S, channels, labels)
%chronuxPairs  The channel pairs a coherence takes: S.seed with S.partner (pairMode "pair"), or with every other
% channel of S.channels (all of CHANNELS when empty; "seed"), as a table (a, b the signal's columns, labelA, labelB, label).
% Errors chronuxCoherence:BadPair when a channel is not at hand, the pair is a channel with itself, or no pair is left.
channels = reshape(double(channels), 1, []);
labels = reshape(string(labels), 1, []);
seed = S.seed;
if S.pairMode == "pair"
    others = S.partner;
else
    others = S.channels;
    if isempty(others); others = channels; end
    others = others(others ~= seed);
end
need = [seed others];
if any(~ismember(need, channels))
    error('chronuxCoherence:BadPair', 'Channel(s) %s of the pairs are not among those read.', ...
        strjoin(string(need(~ismember(need, channels))), ", "));
end
if isempty(others) || any(others == seed)
    error('chronuxCoherence:BadPair', 'The coherence needs two different channels: pick a partner other than the seed.');
end
n = numel(others);
a = repmat(seed, n, 1);
b = others(:);
name = @(c) labels(arrayfun(@(x) find(channels == x, 1), c));
labelA = reshape(name(a), [], 1);
labelB = reshape(name(b), [], 1);
P = table(a, b, labelA, labelB, labelA + "-" + labelB, 'VariableNames', {'a', 'b', 'labelA', 'labelB', 'label'});
end
