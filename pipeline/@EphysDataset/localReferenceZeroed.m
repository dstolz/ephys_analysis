function ch = localReferenceZeroed(obj)
%localReferenceZeroed  The channels the local reference makes all zeros.
%   CH = ds.localReferenceZeroed() returns, 1-based and sorted, the
%   reference channels of LocalReferenceMap that are in their own group:
%   referenced to themselves, they hold zeros after applyLocalReference.
%   While ArtifactConfig.LocalReference is off it returns none.
%   excludedChannels counts them as bad channels in force, so every step
%   leaves them out: the common reference, artifact detection, sorting,
%   spike detection and the derived signals.
%
%   See also EphysDataset.applyLocalReference, EphysDataset.excludedChannels.

ch = double.empty(1, 0);
if ~obj.localReferenceOn()
    return
end
M = obj.LocalReferenceMap;
for k = 1:numel(M)
    if ismember(M(k).reference, M(k).channels)
        ch(end + 1) = M(k).reference; %#ok<AGROW>
    end
end
ch = sort(ch);
end
