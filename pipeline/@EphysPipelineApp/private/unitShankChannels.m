function [chans, pk] = unitShankChannels(R, u)
%unitShankChannels  The sorted channels on the shank unit U was detected on.
%   [CHANS, PK] = unitShankChannels(R, U) gives every sorted channel (indices
%   into R.chanShanks) on the shank of unit U's peak channel PK, in channel
%   order. Both are empty when U is not a unit of the Review data R, or it
%   has no template, so no peak channel or shank.
%
%   See also drawUnitOnShank, EphysPipelineApp.renderReviewUnitShank.

chans = zeros(0, 1);
pk = [];
if isempty(R) || ~(u >= 1 && u <= numel(R.clusterID)) || isempty(R.wfFull)
    return
end
p = R.peakChan(u);
if ~(isfinite(p) && p >= 1 && p <= numel(R.chanShanks))
    return
end
pk = p;
chans = find(R.chanShanks == R.chanShanks(pk));
end
