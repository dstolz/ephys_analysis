function R = chronuxUnitCoherence(SP, TB, S, opts)
%chronuxUnitCoherence  Coherence between pairs of spike trains (Chronux coherencypt).
%   R = chronuxUnitCoherence(SP, TB, S, Name=Value): SP spike trains
%   (chronuxSpikeTrains; SP.index their numbers in the file), TB a
%   chronuxTimeBase (made without Fs over a stretch), S chronuxSettings.
%   The pairs are train S.unitSeed against S.unitPartner (pairMode
%   "pair"), or against every other train of SP ("seed"), by their
%   numbers in the file. Both trains' spikes are cut into TB's trials
%   (chronuxSpikeCut, stamped from the window's start) and, per group, go
%   to coherencypt with trialave = 1 on a grid of S.spikeFs Hz: the
%   coherence magnitude C and phase phi (the angle of the cross-spectrum
%   of the seed and the other train, Chronux's convention), confC, phistd and, jackknife, Clo / Chi. Pure: no I/O, no graphics.
%   Needs Chronux on the path.
%
%   Options: Check (called after each pair), Provenance, Dataset.
%
%   R fields: kind "chronuxUnitCoherence", f, C and phi [nF x nP x nG],
%   Clo / Chi, confC [nP x nG], phistd, pairs (a table: a, b the trains'
%   numbers, labelA, labelB, label), labels, nTrials, zerosp [nP x nG]
%   (trials where either train has no spike), groups, params, tapers,
%   settings, timeBase, source, dataset, provenance, created.
%
%   Errors chronuxUnitCoherence:BadPair (a train not in SP, or a train
%   with itself).
%
%   See also chronuxSpikeSpectrum, chronuxSpikeField, coherencypt.
arguments
    SP (1,1) struct
    TB (1,1) struct
    S (1,1) struct
    opts.Check = []
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
[params, tap] = chronuxParams(S, sfs, T);
t = 0:1 / sfs:T;
nfft = max(2 ^ (nextpow2(numel(t)) + params.pad), numel(t));
f = getfgrid(sfs, nfft, params.fpass);
f = f(:);
nF = numel(f);
nP = numel(others);
G = TB.groups;
nG = height(G);
C = NaN(nF, nP, nG);
phi = C;
confC = NaN(nP, nG);
hasErr = params.err(1) > 0;
jack = params.err(1) == 2;
phistd = []; lo = []; hi = [];
if hasErr; phistd = C; end
if jack; lo = C; hi = C; end
nTr = zeros(nP, nG);
zs = zeros(nP, nG);
[d1, n1] = chronuxSpikeCut(SP.times(pos(S.unitSeed)), TB.starts, TB.window, "window");
for i = 1:nP
    [d2, n2] = chronuxSpikeCut(SP.times(pos(others(i))), TB.starts, TB.window, "window");
    for g = 1:nG
        sel = TB.groupIndex == g;
        nTr(i, g) = nnz(sel);
        zs(i, g) = nnz(sel(:) & (n1(:) == 0 | n2(:) == 0));
        if nTr(i, g) == 0 || all(n1(sel) == 0) || all(n2(sel) == 0); continue; end
        if jack
            [cc, ph, ~, ~, ~, ~, ~, conf, ps, ce] = coherencypt(d1(sel), d2(sel), params, double(S.fscorr), t);
            lo(:, i, g) = ce(1, :).';
            hi(:, i, g) = ce(2, :).';
        elseif hasErr
            [cc, ph, ~, ~, ~, ~, ~, conf, ps] = coherencypt(d1(sel), d2(sel), params, double(S.fscorr), t);
        else
            [cc, ph] = coherencypt(d1(sel), d2(sel), params, double(S.fscorr), t);
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
a = repmat(S.unitSeed, nP, 1);
b = reshape(others, [], 1);
labelA = reshape(SP.labels(arrayfun(pos, a)), [], 1);
labelB = reshape(SP.labels(arrayfun(pos, b)), [], 1);
pairs = table(a, b, labelA, labelB, labelA + "-" + labelB, 'VariableNames', {'a', 'b', 'labelA', 'labelB', 'label'});
R = struct('kind', "chronuxUnitCoherence", 'f', f, 'C', C, 'phi', phi, 'Clo', lo, 'Chi', hi, 'confC', confC, ...
    'phistd', phistd, 'pairs', pairs, 'labels', reshape(pairs.label, 1, []), 'source', SP.source, 'nTrials', nTr, ...
    'zerosp', zs, 'groups', G, 'params', params, 'tapers', tap, 'settings', S, 'timeBase', chronuxTimeSummary(TB), ...
    'signal', "spikes", 'dataset', opts.Dataset, 'provenance', opts.Provenance, ...
    'created', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
end
