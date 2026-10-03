function E = responseEpochs(src, ref, sel, opts)
%responseEpochs  The epochs of a response test: one fixed window holding its baseline and response windows.
%   E = responseEpochs(SRC, REF, SEL, Baseline=[b0 b1], Window=[w0 w1], Param=P)
%   is epochTable(SRC, REF, Window=[min(b0, w0) max(b1, w1)] (fixed),
%   Selection=SEL, Columns=P). That gives the events of the eventRef REF in
%   the trials the trialSelection SEL keeps, without the epochs whose
%   window leaves the recording or touches an artifact period, and with
%   the trial parameter P on each epoch. responseStats then uses every one
%   of them. REF and SEL may be [] for their defaults.
%
%   Errors: responseEpochs:BadWindow, and epochTable's.
%
%   See also responseStats, selectUnits, populationAnalysis, epochTable.

arguments
    src (1,1) struct
    ref = []
    sel = []
    opts.Baseline double = [-0.2 0]
    opts.Window double = [0 0.2]
    opts.Param (1,1) string = ""
end

b = opts.Baseline;
w = opts.Window;
if ~(numel(b) == 2 && numel(w) == 2 && all(isfinite([b(:); w(:)])) && b(2) > b(1) && w(2) > w(1))
    error('responseEpochs:BadWindow', 'Baseline and Window must each be [from to] with from < to (s from the event).');
end
win = struct('mode', "fixed", 'pre', min(b(1), w(1)), 'post', max(b(2), w(2)), 'stop', []);
cols = string.empty(1, 0);
if opts.Param ~= ""; cols = opts.Param; end
E = epochTable(src, ref, Window=win, Selection=sel, Columns=cols);
end
