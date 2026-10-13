function [X, kept, info] = chronuxCut(D, TB, cols, detrendMode)
%chronuxCut  The trials of time base TB cut out of a signal block D, as Chronux takes them.
%   [X, KEPT, INFO] = chronuxCut(D, TB, COLS, DETREND): D is a block of a
%   signal (loadChronuxExport: data, fs, row0), TB a chronuxTimeBase,
%   COLS columns of D.data. X is [nTime x nTrials] double for one column,
%   [nTime x nTrials x nCols] for several; KEPT the trials of TB kept
%   (indices into TB.starts). Trial i is rows base(i) + (s0:s1) of the
%   signal, s0 = round(TB.window(1)*fs), s1 = round(TB.window(2)*fs),
%   base(i) = round(TB.starts(i)*fs) + 1: the row nearest the trial's time
%   0 on the continuous clock -- an epochTable event's t0Continuous, the
%   rule evokedPotential uses, or a segment's first row, exactly. A trial
%   that leaves the block, or holds a non-finite sample, is left out and
%   counted (INFO.droppedEdge, droppedNonFinite). DETREND ("none" |
%   "constant" | "linear") is removed from each trial and column. The
%   cutting is ChronuxDataset.trials' (OnsetRule "sample").
%
%   See also chronuxTimeBase, ChronuxDataset.trials, evokedPotential.
fs = D.fs;
base = round(TB.starts * fs) + 1 - (D.row0 - 1);   % rows of the block
cx = ChronuxDataset(D.data, Fs=fs);
w = [warning('off', 'ChronuxDataset:IncompleteTrials'), warning('off', 'ChronuxDataset:NonFiniteTrials')];
restore = onCleanup(@() warning(w));
s0 = round(TB.window(1) * fs);
s1 = round(TB.window(2) * fs);
try
    [X, ~, ~, I] = cx.trials((base - 1) / fs, [s0 s1] / fs, Channels=cols, OnsetRule="sample", ...
        Incomplete="drop", NonFinite="drop", Detrend=detrendMode, Class="double");
catch ME
    if ME.identifier ~= "ChronuxDataset:NoTrials"; rethrow(ME); end
    nT = s1 - s0 + 1;
    X = zeros(nT, 0, numel(cols));
    if isscalar(cols); X = zeros(nT, 0); end
    kept = zeros(1, 0);
    info = struct('nTime', nT, 'droppedEdge', numel(base), 'droppedNonFinite', 0, 'T', (s0:s1) / fs);
    return
end
kept = I.keptTrials;
info = struct('nTime', I.nTime, 'droppedEdge', numel(I.droppedIncomplete), ...
    'droppedNonFinite', numel(I.droppedNonFinite), 'T', I.T);
end
