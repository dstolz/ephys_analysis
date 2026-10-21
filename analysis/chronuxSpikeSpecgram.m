function R = chronuxSpikeSpecgram(SP, TB, S, opts)
%chronuxSpikeSpecgram  Multitaper spectrograms of spike trains over aligned trials (Chronux mtspectrumpt, window by window).
%   R = chronuxSpikeSpecgram(SP, TB, S, Name=Value): SP spike trains
%   (chronuxTrainsOf), TB an aligned chronuxTimeBase, S chronuxSettings.
%   Each train's spikes are cut into TB's trials (chronuxSpikeCut, stamped
%   from the window's start) and, per group, each moving window of
%   S.movingwin(1) s, stepped by S.movingwin(2) s on a grid of S.spikeFs Hz
%   (params.Fs = S.spikeFs; the tapers' T is the window), goes to
%   mtspectrumpt with trialave = 1, S.fscorr its finite-size correction.
%   The windows are one grid over the epoch, as chronuxSpecgram's: Chronux's
%   own mtspecgrampt spans the first to the last spike, so its times would
%   differ from group to group. S.baseline then compares each frequency
%   with its mean over S.baselineWindow (chronuxNormalize). R.t is each
%   window's center, s from the event. Pure: no I/O, no graphics. Needs
%   Chronux on the path.
%   Errors chronuxSpikeSpecgram:Short when the window is under two grid
%   points or longer than a trial, chronuxSpikeSpecgram:TooLarge when the
%   result would hold more than MaxMB, chronuxSpikeSpecgram:Aligned for a
%   time base other than "aligned".
%
%   Options
%     Check       called with no input after each train (default [])
%     MaxMB       the result's limit (default 1000)
%     Provenance, Dataset   kept in R
%
%   R fields: kind "chronuxSpikeSpecgram", t [nT x 1] s, f [nF x 1] Hz, S
%   [nT x nF x nU x nG] (spikes/s, or the baseline's units), rate [nU x nG]
%   (spikes/s over the trials), labels (the trains'), index (into the
%   file's trains), source, nTrials [nU x nG], zerosp [nU x nG] (trials
%   without a spike), groups, params, tapers, movingwin, baseline (mode,
%   window, units), aligned (true), settings, timeBase, signal "spikes",
%   fs (S.spikeFs), units, dataset, provenance, created: chronuxSpecgram's
%   shape, a train in place of a channel.
%
%   See also chronuxSpecgram, chronuxSpikeSpectrum, renderChronux, mtspectrumpt.
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
if TB.mode ~= "aligned"
    error('chronuxSpikeSpecgram:Aligned', 'A spike spectrogram is computed over aligned epochs, not a "%s" time base.', TB.mode);
end
sfs = S.spikeFs;
mw = S.movingwin;
nWin = round(mw(1) * sfs);
nStep = round(mw(2) * sfs);
if nWin < 2 || nStep < 1
    error('chronuxSpikeSpecgram:Short', 'The moving window [%g %g] s is under two points (or its step under one) at %g Hz.', mw(1), mw(2), sfs);
end
T = diff(TB.window);
nTime = round(T * sfs) + 1;   % the trial's grid, 0:1/sfs:T (chronuxSpikeSpectrum's)
if nWin > nTime
    error('chronuxSpikeSpecgram:Short', 'The %g s moving window is longer than the %g s epoch.', mw(1), T);
end
[params, tap] = chronuxParams(S, sfs, nWin / sfs);
params.err = 0;   % one spectrum per window: no error bars
params.tapers = dpsschk(params.tapers, nWin, sfs);   % once, as mtspecgrampt does
nfft = max(2 ^ (nextpow2(nWin) + params.pad), nWin);
f = getfgrid(sfs, nfft, params.fpass);
f = f(:);
nF = numel(f);
w0 = (1:nStep:nTime - nWin + 1).';
t = TB.window(1) + (w0 - 1 + (nWin - 1) / 2) / sfs;
nT = numel(t);
nU = numel(SP.times);
G = TB.groups;
nG = height(G);
mb = nT * nF * nU * nG * 8 / 2^20;
if mb > opts.MaxMB
    error('chronuxSpikeSpecgram:TooLarge', ['The spectrogram would hold %.0f MB (over %g MB): pick fewer units, ' ...
        'a larger step or a narrower fpass.'], mb, opts.MaxMB);
end
P = NaN(nT, nF, nU, nG);
rate = NaN(nU, nG);
nTr = zeros(nU, nG);
zs = zeros(nU, nG);
for u = 1:nU
    [data, counts] = chronuxSpikeCut(SP.times(u), TB.starts, TB.window, "window");
    for g = 1:nG
        sel = TB.groupIndex == g;
        nTr(u, g) = nnz(sel);
        zs(u, g) = nnz(counts(sel) == 0);
        if nTr(u, g) == 0; continue; end
        rate(u, g) = sum(counts(sel)) / (nTr(u, g) * T);
        if all(counts(sel) == 0); continue; end
        dg = data(sel);
        for k = 1:nT
            tk = (w0(k) - 1 + (0:nWin - 1)) / sfs;   % the window's grid, s from the trial's start
            P(k, :, u, g) = mtspectrumpt(inWindow(dg, tk(1), tk(end)), params, double(S.fscorr), tk);
        end
    end
    if ~isempty(opts.Check); opts.Check(); end
end
[P, bu] = chronuxNormalize(P, t, S.baseline, S.baselineWindow);
base = struct('mode', S.baseline, 'window', S.baselineWindow, 'units', bu);
R = struct('kind', "chronuxSpikeSpecgram", 't', t, 'f', f, 'S', P, 'rate', rate, 'labels', SP.labels, 'index', SP.index, ...
    'source', SP.source, 'nTrials', nTr, 'zerosp', zs, 'groups', G, 'params', params, 'tapers', tap, 'movingwin', mw, ...
    'baseline', base, 'aligned', true, 'settings', S, 'timeBase', chronuxTimeSummary(TB), 'signal', "spikes", 'fs', sfs, ...
    'units', "spikes/s", 'dataset', opts.Dataset, 'provenance', opts.Provenance, ...
    'created', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
end


function d = inWindow(d, a, b)
%inWindow  Each trial's spikes in [A B] only: mtfftpt keeps a trial's every spike when none is in its grid.
for i = 1:numel(d)
    x = d(i).times(:);
    d(i).times = x(x >= a & x <= b);
end
end
