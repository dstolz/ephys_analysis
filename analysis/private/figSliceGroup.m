function R = figSliceGroup(R, g)
%figSliceGroup  A compute result cut to one trial group, for a renderer that draws its first group.
%   RG = figSliceGroup(R, G) keeps group G (a row of R.groups) of a
%   spikePSTH, evokedPotential or unitCorrelation result, so renderHeatmap
%   and renderCorrMap, which draw the first group into an axes, draw G:
%     [.. x .. x nGroups] arrays    rate, sem, count, mean, r, p, z,
%                                   err.lo / err.hi, layerMean.mean / lo /
%                                   hi: (:, :, G)
%     one value per group           n, nEpochs, stopMean, meanR: (G)
%     [nUnits x nGroups]            baselineRate, baselineSD: (:, G)
%     groups                        its row G
%     auroc (an auROC result)       mean, phasic, p, q, direction,
%                                   modulated: (:, G); nModulated,
%                                   nIncrease, nDecrease: (G)
%   A G outside 1..nGroups is clipped to it. The epochs (R.epochs,
%   R.epochGroup, R.raster) are left as they are.
%
%   See also drawHeatmapPanel, drawCorrMapPanel.

nG = height(R.groups);
if nG <= 1; return; end
g = min(max(1, round(g)), nG);
for f = ["rate" "sem" "count" "mean" "r" "p" "z"]
    if isfield(R, f) && isnumeric(R.(f)) && size(R.(f), 3) == nG
        R.(f) = R.(f)(:, :, g);
    end
end
if isfield(R, 'err') && isstruct(R.err)
    for f = ["lo" "hi"]
        if isfield(R.err, f) && size(R.err.(f), 3) == nG; R.err.(f) = R.err.(f)(:, :, g); end
    end
end
if isfield(R, 'layerMean') && isstruct(R.layerMean)
    for f = ["mean" "lo" "hi"]
        if isfield(R.layerMean, f) && size(R.layerMean.(f), 3) == nG; R.layerMean.(f) = R.layerMean.(f)(:, :, g); end
    end
end
for f = ["n" "nEpochs" "stopMean" "meanR"]
    if isfield(R, f) && numel(R.(f)) == nG
        R.(f) = R.(f)(g);
    end
end
for f = ["baselineRate" "baselineSD"]
    if isfield(R, f) && ismatrix(R.(f)) && size(R.(f), 2) == nG
        R.(f) = R.(f)(:, g);
    end
end
if isfield(R, 'auroc') && isstruct(R.auroc) && ~isempty(R.auroc)
    A = R.auroc;
    for f = ["mean" "phasic" "p" "q" "direction" "modulated"]
        if isfield(A, f) && ismatrix(A.(f)) && size(A.(f), 2) == nG; A.(f) = A.(f)(:, g); end
    end
    for f = ["nModulated" "nIncrease" "nDecrease"]
        if isfield(A, f) && numel(A.(f)) == nG; A.(f) = A.(f)(g); end
    end
    R.auroc = A;
end
R.groups = R.groups(g, :);
end
