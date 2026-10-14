function M = figureLayerMean(X, t, type, nBoot, over)
%figureLayerMean  A layer's mean over its units or channels, with a band across them (aggregate "mean").
%   M = figureLayerMean(X, T, TYPE, NBOOT, OVER) averages X [nTime x nItems
%   x nGroups] (a PSTH's rate, an evoked result's mean) over its items
%   (dimension 2) and gives the band across them: errorBounds of TYPE
%   ("sem", "std", "ci95" with NBOOT resamples, "iqr"), NaN where fewer
%   than two items have a value. The band is across the items, not the
%   epochs: today's overlay PSTH and the aux magnitude's mean. M fields:
%     t      T (the time axis)
%     mean   [nTime x 1 x nGroups]
%     lo, hi [nTime x 1 x nGroups] the band's edges
%     type   TYPE
%     over   OVER ("units" | "channels")
%     n      nItems
%
%   See also errorBounds, EphysAnalysisRunner.computeFigure.

arguments
    X {mustBeNumeric}
    t
    type (1,1) string
    nBoot (1,1) double
    over (1,1) string
end
X = double(X);
M = struct('t', t, 'mean', mean(X, 2, 'omitnan'), 'lo', [], 'hi', [], 'type', type, 'over', over, 'n', size(X, 2));
[M.lo, M.hi] = errorBounds(X, 2, type, nBoot);
end
