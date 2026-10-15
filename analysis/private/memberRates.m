function M = memberRates(R, norm, p)
%memberRates  The member sessions' rates (R.members.rate [nBins x nTiles x nMembers]) divided as normalizeRates divided the series.
%   M = memberRates(R, NORM, P) with NORM the normalize mode and P
%   normalizeRates' divisor ([] for "none"): a per-series divisor
%   (groupPeak) divides each member by its series'. Shared by renderPSTH
%   and drawPsthPanel.
%
%   See also normalizeRates, memberLines.
M = R.members.rate;
if norm == "none" || isempty(p); return; end
if size(p, 3) > 1   % groupPeak: each member by its series' peak
    p = p(:, :, R.members.series);
end
M = M ./ p;
end
