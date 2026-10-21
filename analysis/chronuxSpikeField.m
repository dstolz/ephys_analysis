function R = chronuxSpikeField(D, SP, TB, S, opts)
%chronuxSpikeField  Spike-field coherence of spike trains with a signal's channel (Chronux coherencycpt, cohgramcpt).
%   R = chronuxSpikeField(D, SP, TB, S, Name=Value): D a block of a signal
%   (chronuxBlockOf) holding S.fieldChannel, SP spike trains
%   (chronuxTrainsOf), TB a chronuxTimeBase (with the signal's rows
%   over a stretch), S chronuxSettings. The field's trials are cut once
%   (chronuxCut, S.detrend removed); each train's spikes are cut to the
%   very same samples -- trial i spans the field's rows r .. r+n-1, so its
%   spikes are those within half a sample of them, stamped from row r's
%   time (r-1)/fs -- and, per group, both go to coherencycpt with trialave
%   = 1 on the field's time grid (params.Fs = the signal's rate): the
%   coherence magnitude C and phase phi (the angle of the cross-spectrum
%   of the field and the spikes, Chronux's convention), confC, phistd and, jackknife, Clo / Chi.
%   S.overTime: cohgramcpt over the moving window instead, as
%   chronuxCoherence does (over epochs: R.t from the event; over a
%   stretch: each clear stretch one trial, its windows on one time grid of
%   S.movingwin(2) s steps, NaN in between; no bars). Pure: no I/O, no
%   graphics. Needs Chronux on the path.
%
%   Options: Check (called after each train), MaxMB (a coherogram's limit,
%   default 1000), Provenance, Dataset.
%
%   R fields: kind "chronuxSpikeField" (or "chronuxCohgram"), f, t [nT x 1]
%   (cohgram), C and phi [nF x nU x nG] ([nT x nF x nU x nG]), Clo / Chi,
%   confC [nU x nG], phistd, pairs (a table: the train's index, labelA
%   (the train), labelB (the field channel), label), labels, field (the
%   channel's column and label), nTrials (a coherogram over a stretch: its
%   windows), zerosp [nU x nG] (trials without a spike), groups, params,
%   tapers, movingwin, aligned, settings, timeBase, signal, fs, dataset,
%   provenance, created.
%   Errors chronuxSpikeField:NoField, chronuxSpikeField:Short (a moving
%   window under two samples or longer than the epoch),
%   chronuxSpikeField:TooLarge (a coherogram over MaxMB).
%
%   See also chronuxSpikeSpectrum, chronuxUnitCoherence, chronuxCoherence, coherencycpt, cohgramcpt.
arguments
    D (1,1) struct
    SP (1,1) struct
    TB (1,1) struct
    S (1,1) struct
    opts.Check = []
    opts.MaxMB (1,1) double = 1000
    opts.Provenance = struct()
    opts.Dataset (1,1) string = ""
end
ChronuxDataset.requireChronux();
fs = D.fs;
c = find(D.channels == S.fieldChannel, 1);
if isempty(c)
    error('chronuxSpikeField:NoField', 'The field channel %d was not read.', S.fieldChannel);
end
fieldLabel = string(D.labels(c));
nU = numel(SP.times);
G = TB.groups;
nG = height(G);
aligned = TB.mode == "aligned";
mw = S.movingwin;
t = zeros(0, 1);
confC = NaN(nU, nG);
phistd = []; lo = []; hi = [];
nTr = zeros(nU, nG);
zs = zeros(nU, nG);
if ~S.overTime
    kind = "chronuxSpikeField";
    [X, kept, info] = chronuxCut(D, TB, c, S.detrend);
    nTime = info.nTime;
    [params, tap] = chronuxParams(S, fs, nTime / fs);
    tt = (0:nTime - 1) / fs;
    nfft = max(2 ^ (nextpow2(nTime) + params.pad), nTime);
    f = getfgrid(fs, nfft, params.fpass);
    f = f(:);
    nF = numel(f);
    gi = TB.groupIndex(kept);
    first = (round(TB.starts(kept) * fs) + round(TB.window(1) * fs)) / fs;   % each trial's first row, (r-1)/fs
    C = NaN(nF, nU, nG);
    phi = C;
    hasErr = params.err(1) > 0;
    jack = params.err(1) == 2;
    if hasErr; phistd = C; end
    if jack; lo = C; hi = C; end
    for u = 1:nU
        [sp, counts] = chronuxSpikeCut(SP.times(u), first, [-0.5 nTime - 0.5] / fs, "onset");
        for g = 1:nG
            sel = gi == g;
            nTr(u, g) = nnz(sel);
            zs(u, g) = nnz(counts(sel) == 0);
            if nTr(u, g) == 0 || all(counts(sel) == 0); continue; end
            x = X(:, sel);
            if jack
                [cc, ph, ~, ~, ~, ~, ~, conf, ps, ce] = coherencycpt(x, sp(sel), params, double(S.fscorr), tt);
                lo(:, u, g) = ce(1, :).';
                hi(:, u, g) = ce(2, :).';
            elseif hasErr
                [cc, ph, ~, ~, ~, ~, ~, conf, ps] = coherencycpt(x, sp(sel), params, double(S.fscorr), tt);
            else
                [cc, ph] = coherencycpt(x, sp(sel), params, double(S.fscorr), tt);
            end
            C(:, u, g) = cc(:);
            phi(:, u, g) = ph(:);
            if hasErr
                confC(u, g) = conf;
                phistd(:, u, g) = ps(:);
            end
        end
        if ~isempty(opts.Check); opts.Check(); end
    end
else
    kind = "chronuxCohgram";
    nWin = round(mw(1) * fs);
    nStep = round(mw(2) * fs);
    if nWin < 2 || nStep < 1
        error('chronuxSpikeField:Short', 'The moving window [%g %g] s is under two samples (or its step under one) at %g Hz.', mw(1), mw(2), fs);
    end
    [params, tap] = chronuxParams(S, fs, nWin / fs);
    params.err = 0;
    nfft = max(2 ^ (nextpow2(nWin) + params.pad), nWin);
    f = getfgrid(fs, nfft, params.fpass);
    f = f(:);
    nF = numel(f);
    if aligned
        [X, kept, info] = chronuxCut(D, TB, c, S.detrend);
        nTime = info.nTime;
        if nWin > nTime
            error('chronuxSpikeField:Short', 'The %g s moving window is longer than the %g s epoch.', mw(1), nTime / fs);
        end
        w0 = (1:nStep:nTime - nWin + 1).';   % cohgramcpt's windows
        t = round(TB.window(1) * fs) / fs + (w0 - 1 + (nWin - 1) / 2) / fs;
        tooBig(2 * numel(t) * nF * nU * nG, opts.MaxMB);
        C = NaN(numel(t), nF, nU, nG);
        phi = C;
        gi = TB.groupIndex(kept);
        first = (round(TB.starts(kept) * fs) + round(TB.window(1) * fs)) / fs;
        for u = 1:nU
            [sp, counts] = chronuxSpikeCut(SP.times(u), first, [-0.5 nTime - 0.5] / fs, "onset");
            for i = 1:numel(sp); sp(i).times = sp(i).times + 1 / fs; end   % cohgramcpt: sample k at k/fs
            for g = 1:nG
                sel = gi == g;
                nTr(u, g) = nnz(sel);
                zs(u, g) = nnz(counts(sel) == 0);
                if nTr(u, g) == 0 || all(counts(sel) == 0); continue; end
                [cc, ph] = cohgramcpt(X(:, sel), sp(sel), mw, params, double(S.fscorr));
                C(:, :, u, g) = reshape(cc, numel(t), nF);
                phi(:, :, u, g) = reshape(ph, numel(t), nF);
            end
            if ~isempty(opts.Check); opts.Check(); end
        end
    else
        step = nStep / fs;
        a = TB.runs(1, 1);
        nT = floor((TB.runs(end, 2) - a) / step) + 1;
        tooBig(2 * nT * nF * nU, opts.MaxMB);
        t = a + (0:nT - 1).' * step + (nWin - 1) / 2 / fs;
        C = NaN(nT, nF, nU, 1);
        phi = C;
        runs = TB.runRows - (D.row0 - 1);   % rows of the block
        for u = 1:nU
            st = SP.times(u).times(:);
            for r = 1:size(runs, 1)
                n = runs(r, 2) - runs(r, 1) + 1;
                t0 = TB.runs(r, 1);   % the stretch's first row's time
                in = st >= t0 - 0.5 / fs & st < t0 + (n - 0.5) / fs;
                if n < nWin || ~any(in); continue; end
                x = double(D.data(runs(r, 1):runs(r, 2), c));
                switch S.detrend
                    case "constant", x = x - mean(x);
                    case "linear",   x = detrend(x, 1);
                end
                [cc, ph] = cohgramcpt(x, struct('times', st(in) - t0 + 1 / fs), mw, params, double(S.fscorr));
                cc = reshape(cc, [], nF);
                ph = reshape(ph, [], nF);
                w0 = (1:nStep:n - nWin + 1).';
                k = round((t0 + (w0 - 1) / fs - a) / step) + 1;
                ok = k >= 1 & k <= nT;
                C(k(ok), :, u, 1) = cc(ok, :);
                phi(k(ok), :, u, 1) = ph(ok, :);
            end
            nTr(u, 1) = nnz(any(isfinite(C(:, :, u, 1)), 2));   % windows
            if ~isempty(opts.Check); opts.Check(); end
        end
    end
end
labelA = reshape(SP.labels, [], 1);
labelB = repmat(fieldLabel, nU, 1);
pairs = table(reshape(SP.index, [], 1), labelA, labelB, labelA + "-" + labelB, 'VariableNames', {'a', 'labelA', 'labelB', 'label'});
R = struct('kind', kind, 'f', f, 't', t, 'C', C, 'phi', phi, 'Clo', lo, 'Chi', hi, 'confC', confC, ...
    'phistd', phistd, 'pairs', pairs, 'labels', reshape(pairs.label, 1, []), ...
    'field', struct('channel', S.fieldChannel, 'label', fieldLabel), 'source', SP.source, 'nTrials', nTr, ...
    'zerosp', zs, 'groups', G, 'params', params, 'tapers', tap, 'movingwin', mw, 'aligned', aligned, 'settings', S, ...
    'timeBase', chronuxTimeSummary(TB), 'signal', string(D.signal), 'fs', fs, 'dataset', opts.Dataset, ...
    'provenance', opts.Provenance, 'created', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
end


function tooBig(n, maxMB)
mb = n * 8 / 2^20;
if mb > maxMB
    error('chronuxSpikeField:TooLarge', ['The coherogram would hold %.0f MB (over %g MB): pick fewer units, ' ...
        'a shorter range, a larger step or a narrower fpass.'], mb, maxMB);
end
end
