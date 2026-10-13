function R = chronuxSpectrum(D, TB, S, opts)
%chronuxSpectrum  Multitaper power spectra of a signal's channels over trials (Chronux mtspectrumc).
%   R = chronuxSpectrum(D, TB, S, Name=Value): D a block of a signal
%   (loadChronuxExport, holding the rows TB.span needs), TB a
%   chronuxTimeBase, S chronuxSettings. For every column of D and every
%   group of TB, the group's trials (chronuxCut: S.detrend removed from
%   each) go to mtspectrumc with trialave = 1: the spectrum averaged over
%   the trials and the tapers, with jackknife or theoretical error bars
%   (S.err). Pure: no I/O, no graphics. Needs Chronux on the path.
%
%   Options
%     Check       called with no input after each channel's spectra
%                 (default []); it may throw to stop (Cancel)
%     Provenance  a struct kept as R.provenance (the file, its export)
%     Dataset     the dataset's name, kept as R.dataset
%
%   R fields: kind "chronuxSpectrum", f [nF x 1] Hz, S [nF x nCh x nG]
%   power (units^2/Hz, e.g. µV^2/Hz), Slo / Shi (the error bars, [] with
%   err "none"), labels, channels (D's), nTrials [nCh x nG] (the trials
%   each spectrum averages), droppedEdge / droppedNonFinite [nCh x 1],
%   groups, params (the exact Chronux params), tapers (TW, K,
%   halfBandwidthHz, T, notes), settings, timeBase (TB without its
%   per-trial vectors), signal, fs, units, dataset, provenance, created.
%
%   See also chronuxSpecgram, chronuxTimeBase, renderChronux, mtspectrumc.
arguments
    D (1,1) struct
    TB (1,1) struct
    S (1,1) struct
    opts.Check = []
    opts.Provenance = struct()
    opts.Dataset (1,1) string = ""
end
ChronuxDataset.requireChronux();
fs = D.fs;
nCh = size(D.data, 2);
G = TB.groups;
nG = height(G);
T = diff(round(TB.window * fs)) / fs + 1 / fs;   % the trial's length, s
[params, tap] = chronuxParams(S, fs, T);
nTime = round(T * fs);
nfft = max(2 ^ (nextpow2(nTime) + params.pad), nTime);
f = getfgrid(fs, nfft, params.fpass);
f = f(:);
nF = numel(f);
P = NaN(nF, nCh, nG);
hasErr = params.err(1) > 0;
if hasErr; lo = NaN(nF, nCh, nG); hi = lo; else; lo = []; hi = []; end
nTr = zeros(nCh, nG);
dropE = zeros(nCh, 1);
dropN = zeros(nCh, 1);
for c = 1:nCh
    [X, kept, info] = chronuxCut(D, TB, c, S.detrend);
    dropE(c) = info.droppedEdge;
    dropN(c) = info.droppedNonFinite;
    gi = TB.groupIndex(kept);
    for g = 1:nG
        Xg = X(:, gi == g);
        nTr(c, g) = size(Xg, 2);
        if nTr(c, g) == 0; continue; end
        if hasErr
            [s, ~, e] = mtspectrumc(Xg, params);
            lo(:, c, g) = e(1, :).';
            hi(:, c, g) = e(2, :).';
        else
            s = mtspectrumc(Xg, params);
        end
        P(:, c, g) = s(:);
    end
    if ~isempty(opts.Check); opts.Check(); end
end
R = struct('kind', "chronuxSpectrum", 'f', f, 'S', P, 'Slo', lo, 'Shi', hi, 'labels', reshape(string(D.labels), 1, []), ...
    'channels', D.channels, 'nTrials', nTr, 'droppedEdge', dropE, 'droppedNonFinite', dropN, 'groups', G, ...
    'params', params, 'tapers', tap, 'settings', S, 'timeBase', chronuxTimeSummary(TB), 'signal', string(D.signal), 'fs', fs, ...
    'units', chronuxPowerUnits(D.units), 'dataset', opts.Dataset, 'provenance', opts.Provenance, ...
    'created', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
end

