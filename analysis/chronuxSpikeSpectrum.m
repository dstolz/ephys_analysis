function R = chronuxSpikeSpectrum(SP, TB, S, opts)
%chronuxSpikeSpectrum  Multitaper spectra of spike trains over trials (Chronux mtspectrumpt).
%   R = chronuxSpikeSpectrum(SP, TB, S, Name=Value): SP spike trains
%   (chronuxSpikeTrains), TB a chronuxTimeBase (made without Fs over a
%   stretch: segments on the spike clock), S chronuxSettings. Each
%   train's spikes are cut into TB's trials (chronuxSpikeCut, stamped from
%   the window's start) and, per group, go to mtspectrumpt with trialave
%   = 1 on a grid of S.spikeFs Hz over the trial (params.Fs = S.spikeFs),
%   S.fscorr its finite-size correction. A point process's spectrum tends
%   to its mean rate at high frequencies (R.rate); a dip below it at low
%   frequencies is a refractory period, a peak a rhythm. Pure: no I/O, no
%   graphics. Needs Chronux on the path.
%
%   Options: Check (called after each train), Provenance, Dataset.
%
%   R fields: kind "chronuxSpikeSpectrum", f [nF x 1], S [nF x nU x nG]
%   (spikes/s), Slo / Shi (the error bars, [] with err "none"), rate
%   [nU x nG] (spikes/s over the trials), labels (the trains'), index
%   (into the file's trains), source, nTrials [nU x nG], zerosp [nU x nG]
%   (trials without a spike), groups, params, tapers, settings, timeBase,
%   units, dataset, provenance, created.
%
%   See also chronuxSpikeField, chronuxUnitCoherence, renderChronux, mtspectrumpt.
arguments
    SP (1,1) struct
    TB (1,1) struct
    S (1,1) struct
    opts.Check = []
    opts.Provenance = struct()
    opts.Dataset (1,1) string = ""
end
ChronuxDataset.requireChronux();
sfs = S.spikeFs;
T = diff(TB.window);
[params, tap] = chronuxParams(S, sfs, T);
t = 0:1 / sfs:T;
nfft = max(2 ^ (nextpow2(numel(t)) + params.pad), numel(t));
f = getfgrid(sfs, nfft, params.fpass);
f = f(:);
nF = numel(f);
nU = numel(SP.times);
G = TB.groups;
nG = height(G);
P = NaN(nF, nU, nG);
hasErr = params.err(1) > 0;
if hasErr; lo = P; hi = P; else; lo = []; hi = []; end
rate = NaN(nU, nG);
nTr = zeros(nU, nG);
zs = zeros(nU, nG);
for u = 1:nU
    [data, counts] = chronuxSpikeCut(SP.times(u), TB.starts, TB.window, "window");
    for g = 1:nG
        sel = TB.groupIndex == g;
        nTr(u, g) = nnz(sel);
        zs(u, g) = nnz(counts(sel) == 0);
        if nTr(u, g) == 0 || all(counts(sel) == 0); continue; end
        if hasErr
            [s, ~, r, e] = mtspectrumpt(data(sel), params, double(S.fscorr), t);
            lo(:, u, g) = e(1, :).';
            hi(:, u, g) = e(2, :).';
        else
            [s, ~, r] = mtspectrumpt(data(sel), params, double(S.fscorr), t);
        end
        P(:, u, g) = s(:);
        rate(u, g) = mean(r);
    end
    if ~isempty(opts.Check); opts.Check(); end
end
R = struct('kind', "chronuxSpikeSpectrum", 'f', f, 'S', P, 'Slo', lo, 'Shi', hi, 'rate', rate, 'labels', SP.labels, ...
    'index', SP.index, 'source', SP.source, 'nTrials', nTr, 'zerosp', zs, 'groups', G, 'params', params, 'tapers', tap, ...
    'settings', S, 'timeBase', chronuxTimeSummary(TB), 'signal', "spikes", 'units', "spikes/s", 'dataset', opts.Dataset, ...
    'provenance', opts.Provenance, 'created', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
end
