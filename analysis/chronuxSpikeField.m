function R = chronuxSpikeField(D, SP, TB, S, opts)
%chronuxSpikeField  Spike-field coherence of spike trains with a signal's channel (Chronux coherencycpt).
%   R = chronuxSpikeField(D, SP, TB, S, Name=Value): D a block of a signal
%   (loadChronuxExport) holding S.fieldChannel, SP spike trains
%   (chronuxSpikeTrains), TB a chronuxTimeBase (with the signal's rows
%   over a stretch), S chronuxSettings. The field's trials are cut once
%   (chronuxCut, S.detrend removed); each train's spikes are cut to the
%   very same samples -- trial i spans the field's rows r .. r+n-1, so its
%   spikes are those within half a sample of them, stamped from row r's
%   time (r-1)/fs -- and, per group, both go to coherencycpt with trialave
%   = 1 on the field's time grid (params.Fs = the signal's rate): the
%   coherence magnitude C and phase phi (the angle of the cross-spectrum
%   of the field and the spikes, Chronux's convention), confC, phistd and, jackknife, Clo / Chi. Pure: no I/O, no
%   graphics. Needs Chronux on the path.
%
%   Options: Check (called after each train), Provenance, Dataset.
%
%   R fields: kind "chronuxSpikeField", f, C and phi [nF x nU x nG],
%   Clo / Chi, confC [nU x nG], phistd, pairs (a table: the train's index,
%   labelA (the train), labelB (the field channel), label), labels,
%   field (the channel's column and label), nTrials, zerosp [nU x nG]
%   (trials without a spike), groups, params, tapers, settings, timeBase,
%   signal, fs, dataset, provenance, created.
%
%   See also chronuxSpikeSpectrum, chronuxUnitCoherence, chronuxCoherence, coherencycpt.
arguments
    D (1,1) struct
    SP (1,1) struct
    TB (1,1) struct
    S (1,1) struct
    opts.Check = []
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
[X, kept, info] = chronuxCut(D, TB, c, S.detrend);
nTime = info.nTime;
T = nTime / fs;
[params, tap] = chronuxParams(S, fs, T);
t = (0:nTime - 1) / fs;
nfft = max(2 ^ (nextpow2(nTime) + params.pad), nTime);
f = getfgrid(fs, nfft, params.fpass);
f = f(:);
nF = numel(f);
nU = numel(SP.times);
G = TB.groups;
nG = height(G);
gi = TB.groupIndex(kept);
first = (round(TB.starts(kept) * fs) + round(TB.window(1) * fs)) / fs;   % each trial's first row, (r-1)/fs
C = NaN(nF, nU, nG);
phi = C;
confC = NaN(nU, nG);
hasErr = params.err(1) > 0;
jack = params.err(1) == 2;
phistd = []; lo = []; hi = [];
if hasErr; phistd = C; end
if jack; lo = C; hi = C; end
nTr = zeros(nU, nG);
zs = zeros(nU, nG);
for u = 1:nU
    [sp, counts] = chronuxSpikeCut(SP.times(u), first, [-0.5 nTime - 0.5] / fs, "onset");
    for g = 1:nG
        sel = gi == g;
        nTr(u, g) = nnz(sel);
        zs(u, g) = nnz(counts(sel) == 0);
        if nTr(u, g) == 0 || all(counts(sel) == 0); continue; end
        x = X(:, sel);
        if jack
            [cc, ph, ~, ~, ~, ~, ~, conf, ps, ce] = coherencycpt(x, sp(sel), params, double(S.fscorr), t);
            lo(:, u, g) = ce(1, :).';
            hi(:, u, g) = ce(2, :).';
        elseif hasErr
            [cc, ph, ~, ~, ~, ~, ~, conf, ps] = coherencycpt(x, sp(sel), params, double(S.fscorr), t);
        else
            [cc, ph] = coherencycpt(x, sp(sel), params, double(S.fscorr), t);
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
labelA = reshape(SP.labels, [], 1);
labelB = repmat(fieldLabel, nU, 1);
pairs = table(reshape(SP.index, [], 1), labelA, labelB, labelA + "-" + labelB, 'VariableNames', {'a', 'labelA', 'labelB', 'label'});
R = struct('kind', "chronuxSpikeField", 'f', f, 'C', C, 'phi', phi, 'Clo', lo, 'Chi', hi, 'confC', confC, ...
    'phistd', phistd, 'pairs', pairs, 'labels', reshape(pairs.label, 1, []), ...
    'field', struct('channel', S.fieldChannel, 'label', fieldLabel), 'source', SP.source, 'nTrials', nTr, ...
    'zerosp', zs, 'groups', G, 'params', params, 'tapers', tap, 'settings', S, 'timeBase', chronuxTimeSummary(TB), ...
    'signal', string(D.signal), 'fs', fs, 'dataset', opts.Dataset, 'provenance', opts.Provenance, ...
    'created', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
end
