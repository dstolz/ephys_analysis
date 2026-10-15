function A = figureAurocCalls(F)
%figureAurocCalls  The auROC result of a computed figure, for its caption: how it was made and the calls.
%   A = figureAurocCalls(F) takes F from figureCompute (one observation of
%   a figure) and returns the first auROC result its panels hold (a PSTH or
%   a heat map of spikes with the baseline Mode "auroc": a layer's
%   R.auroc, spikePSTH's), as a struct with fields method, windows,
%   baseline ([b0 b1] s), modulationWindow, cutoff, cutoffValue, settings
%   (the Auroc settings), labels (the trial groups', a column), nIncrease
%   and nDecrease (per group) and nUnits (the units tested), or [] when no
%   panel holds one. The run collects one per observation and figureCaption
%   (Auroc=) sums their calls.
%
%   See also figureCaption, spikePSTH, aurocCall, EphysAnalysisRunner.runDataset.

A = [];
if ~isstruct(F) || ~isfield(F, 'panels'); return; end
for k = 1:numel(F.panels)
    L = F.panels(k).layers;
    for j = 1:numel(L)
        R = L(j).R;
        if ~isstruct(R) || ~isscalar(R) || ~isfield(R, 'auroc') || ~isstruct(R.auroc) || isempty(R.auroc); continue; end
        a = R.auroc;
        labels = "all";
        if isfield(R, 'groups') && istable(R.groups) && ismember('label', R.groups.Properties.VariableNames)
            labels = string(R.groups.label(:));
        end
        A = struct('method', string(a.method), 'windows', string(a.windows), 'baseline', a.baseline, ...
            'modulationWindow', a.modulationWindow, 'cutoff', string(a.cutoff), 'cutoffValue', a.cutoffValue, ...
            'settings', a.settings, 'labels', labels, 'nIncrease', a.nIncrease(:), 'nDecrease', a.nDecrease(:), ...
            'nUnits', a.nUnits);
        return
    end
end
end
