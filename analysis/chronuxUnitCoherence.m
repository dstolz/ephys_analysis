function R = chronuxUnitCoherence(SP, TB, S, opts)
%chronuxUnitCoherence  Coherence between pairs of spike trains (Chronux coherencypt).
%   R = chronuxUnitCoherence(SP, TB, S, Name=Value): SP spike trains
%   (chronuxTrainsOf; SP.index their numbers), TB a
%   chronuxTimeBase (made without Fs over a stretch), S chronuxSettings.
%   The pairs are train S.unitSeed against S.unitPartner (pairMode
%   "pair"), or against every other train of SP ("seed"), by their
%   numbers. Both trains' spikes are cut into TB's trials
%   (chronuxSpikeCut, stamped from the window's start) and, per group, go
%   to coherencypt with trialave = 1 on a grid of S.spikeFs Hz: the
%   coherence magnitude C and phase phi (the angle of the cross-spectrum
%   of the seed and the other train, Chronux's convention), confC, phistd and, jackknife, Clo / Chi.
%   S.overTime: a coherogram instead, coherencypt over each moving window
%   of S.movingwin(1) s stepped by S.movingwin(2) s (the tapers' T is the
%   window; no bars): over epochs one grid over the epoch, R.t its
%   windows' centers from the event; over a stretch each clear stretch
%   (TB.runs) one trial, its windows on one time grid, NaN in between.
%   Chronux's own cohgrampt spans the first to the last spike instead, so
%   its times would differ from group to group. Pure: no I/O, no graphics.
%   Needs Chronux on the path.
%
%   Options: Check (called after each pair), MaxMB (a coherogram's limit,
%   default 1000), Provenance, Dataset.
%
%   R fields: kind "chronuxUnitCoherence" (or "chronuxCohgram"), f, t [nT
%   x 1] (cohgram), C and phi [nF x nP x nG] ([nT x nF x nP x nG]), Clo /
%   Chi, confC [nP x nG], phistd, pairs (a table: a, b the trains'
%   numbers, labelA, labelB, label), labels, nTrials (a coherogram over a
%   stretch: its windows), zerosp [nP x nG] (trials where either train has
%   no spike), groups, params, tapers, movingwin, aligned, settings,
%   timeBase, source, signal, fs (S.spikeFs), dataset, provenance, created.
%
%   Errors chronuxUnitCoherence:BadPair (a train not in SP, or a train
%   with itself), chronuxUnitCoherence:Short (a moving window under two
%   points or longer than the epoch), chronuxUnitCoherence:TooLarge (a
%   coherogram over MaxMB).
%
%   See also chronuxSpikeSpectrum, chronuxSpikeField, coherencypt.
arguments
    SP (1,1) struct
    TB (1,1) struct
    S (1,1) struct
    opts.Check = []
    opts.MaxMB (1,1) double = 1000
    opts.Provenance = struct()
    opts.Dataset (1,1) string = ""
end
ChronuxDataset.requireChronux();
if S.pairMode == "pair"
    others = S.unitPartner;
else
    others = SP.index(SP.index ~= S.unitSeed);
end
if ~ismember(S.unitSeed, SP.index) || any(~ismember(others, SP.index)) || isempty(others) || any(others == S.unitSeed)
    error('chronuxUnitCoherence:BadPair', 'The coherence needs two different spike trains among those picked.');
end
pos = @(k) find(SP.index == k, 1);
sfs = S.spikeFs;
T = diff(TB.window);
aligned = TB.mode == "aligned";
mw = S.movingwin;
nP = numel(others);
G = TB.groups;
nG = height(G);
t = zeros(0, 1);
confC = NaN(nP, nG);
phistd = []; lo = []; hi = [];
nTr = zeros(nP, nG);
zs = zeros(nP, nG);
if ~S.overTime
    kind = "chronuxUnitCoherence";
    [params, tap] = chronuxParams(S, sfs, T);
    tt = 0:1 / sfs:T;
    nfft = max(2 ^ (nextpow2(numel(tt)) + params.pad), numel(tt));
    f = getfgrid(sfs, nfft, params.fpass);
    f = f(:);
    nF = numel(f);
    C = NaN(nF, nP, nG);
    phi = C;
    hasErr = params.err(1) > 0;
    jack = params.err(1) == 2;
    if hasErr; phistd = C; end
    if jack; lo = C; hi = C; end
    [d1, n1] = chronuxSpikeCut(SP.times(pos(S.unitSeed)), TB.starts, TB.window, "window");
    for i = 1:nP
        [d2, n2] = chronuxSpikeCut(SP.times(pos(others(i))), TB.starts, TB.window, "window");
        for g = 1:nG
            sel = TB.groupIndex == g;
            nTr(i, g) = nnz(sel);
            zs(i, g) = nnz(sel(:) & (n1(:) == 0 | n2(:) == 0));
            if nTr(i, g) == 0 || all(n1(sel) == 0) || all(n2(sel) == 0); continue; end
            if jack
                [cc, ph, ~, ~, ~, ~, ~, conf, ps, ce] = coherencypt(d1(sel), d2(sel), params, double(S.fscorr), tt);
                lo(:, i, g) = ce(1, :).';
                hi(:, i, g) = ce(2, :).';
            elseif hasErr
                [cc, ph, ~, ~, ~, ~, ~, conf, ps] = coherencypt(d1(sel), d2(sel), params, double(S.fscorr), tt);
            else
                [cc, ph] = coherencypt(d1(sel), d2(sel), params, double(S.fscorr), tt);
            end
            C(:, i, g) = cc(:);
            phi(:, i, g) = ph(:);
            if hasErr
                confC(i, g) = conf;
                phistd(:, i, g) = ps(:);
            end
        end
        if ~isempty(opts.Check); opts.Check(); end
    end
else
    kind = "chronuxCohgram";
    nWin = round(mw(1) * sfs);
    nStep = round(mw(2) * sfs);
    if nWin < 2 || nStep < 1
        error('chronuxUnitCoherence:Short', 'The moving window [%g %g] s is under two points (or its step under one) at %g Hz.', mw(1), mw(2), sfs);
    end
    [params, tap] = chronuxParams(S, sfs, nWin / sfs);
    params.err = 0;
    params.tapers = dpsschk(params.tapers, nWin, sfs);   % once, as cohgrampt does
    nfft = max(2 ^ (nextpow2(nWin) + params.pad), nWin);
    f = getfgrid(sfs, nfft, params.fpass);
    f = f(:);
    nF = numel(f);
    if aligned
        nTime = round(T * sfs) + 1;   % the trial's grid, 0:1/sfs:T
        if nWin > nTime
            error('chronuxUnitCoherence:Short', 'The %g s moving window is longer than the %g s epoch.', mw(1), T);
        end
        w0 = (1:nStep:nTime - nWin + 1).';
        t = TB.window(1) + (w0 - 1 + (nWin - 1) / 2) / sfs;
        tooBig(2 * numel(t) * nF * nP * nG, opts.MaxMB);
        C = NaN(numel(t), nF, nP, nG);
        phi = C;
        [d1, n1] = chronuxSpikeCut(SP.times(pos(S.unitSeed)), TB.starts, TB.window, "window");
        for i = 1:nP
            [d2, n2] = chronuxSpikeCut(SP.times(pos(others(i))), TB.starts, TB.window, "window");
            for g = 1:nG
                sel = TB.groupIndex == g;
                nTr(i, g) = nnz(sel);
                zs(i, g) = nnz(sel(:) & (n1(:) == 0 | n2(:) == 0));
                if nTr(i, g) == 0 || all(n1(sel) == 0) || all(n2(sel) == 0); continue; end
                [C(:, :, i, g), phi(:, :, i, g)] = windowed(d1(sel), d2(sel), (w0 - 1) / sfs, nWin, nF, params, S);
            end
            if ~isempty(opts.Check); opts.Check(); end
        end
    else
        step = nStep / sfs;
        a = TB.runs(1, 1);
        nT = floor((TB.runs(end, 2) - a) / step) + 1;
        tooBig(2 * nT * nF * nP, opts.MaxMB);
        t = a + (0:nT - 1).' * step + (nWin - 1) / 2 / sfs;
        C = NaN(nT, nF, nP, 1);
        phi = C;
        s1 = SP.times(pos(S.unitSeed)).times(:);
        for i = 1:nP
            s2 = SP.times(pos(others(i))).times(:);
            for r = 1:size(TB.runs, 1)
                ra = TB.runs(r, 1);
                rb = TB.runs(r, 2);
                in1 = s1 >= ra & s1 < rb;
                in2 = s2 >= ra & s2 < rb;
                nPts = floor((rb - ra) * sfs + 1e-9) + 1;
                if nPts < nWin || ~any(in1) || ~any(in2); continue; end
                starts = ra + ((1:nStep:nPts - nWin + 1).' - 1) / sfs;
                [c, ph] = windowed(struct('times', s1(in1)), struct('times', s2(in2)), starts, nWin, nF, params, S);
                k = round((starts - a) / step) + 1;
                ok = k >= 1 & k <= nT;
                C(k(ok), :, i, 1) = c(ok, :);
                phi(k(ok), :, i, 1) = ph(ok, :);
            end
            nTr(i, 1) = nnz(any(isfinite(C(:, :, i, 1)), 2));   % windows
            if ~isempty(opts.Check); opts.Check(); end
        end
    end
end
a = repmat(S.unitSeed, nP, 1);
b = reshape(others, [], 1);
labelA = reshape(SP.labels(arrayfun(pos, a)), [], 1);
labelB = reshape(SP.labels(arrayfun(pos, b)), [], 1);
pairs = table(a, b, labelA, labelB, labelA + "-" + labelB, 'VariableNames', {'a', 'b', 'labelA', 'labelB', 'label'});
R = struct('kind', kind, 'f', f, 't', t, 'C', C, 'phi', phi, 'Clo', lo, 'Chi', hi, 'confC', confC, ...
    'phistd', phistd, 'pairs', pairs, 'labels', reshape(pairs.label, 1, []), 'source', SP.source, 'nTrials', nTr, ...
    'zerosp', zs, 'groups', G, 'params', params, 'tapers', tap, 'movingwin', mw, 'aligned', aligned, 'settings', S, ...
    'timeBase', chronuxTimeSummary(TB), 'signal', "spikes", 'fs', sfs, 'dataset', opts.Dataset, ...
    'provenance', opts.Provenance, 'created', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
end


function [C, phi] = windowed(d1, d2, starts, nWin, nF, params, S)
%windowed  coherencypt of the trials D1 and D2 (trialave) over each window of NWIN grid points from STARTS (s on their clock).
C = NaN(numel(starts), nF);
phi = C;
for k = 1:numel(starts)
    tk = starts(k) + (0:nWin - 1) / S.spikeFs;
    [c, ph] = coherencypt(inWindow(d1, tk(1), tk(end)), inWindow(d2, tk(1), tk(end)), params, double(S.fscorr), tk);
    C(k, :) = c(:).';
    phi(k, :) = ph(:).';
end
end


function d = inWindow(d, a, b)
%inWindow  Each trial's spikes in [A B] only: mtfftpt keeps a trial's every spike when none is in its grid.
for i = 1:numel(d)
    x = d(i).times(:);
    d(i).times = x(x >= a & x <= b);
end
end


function tooBig(n, maxMB)
mb = n * 8 / 2^20;
if mb > maxMB
    error('chronuxUnitCoherence:TooLarge', ['The coherogram would hold %.0f MB (over %g MB): pick fewer units, ' ...
        'a shorter range, a larger step or a narrower fpass.'], mb, maxMB);
end
end
