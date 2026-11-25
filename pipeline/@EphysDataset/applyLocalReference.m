function X = applyLocalReference(obj, X)
%applyLocalReference  Subtract each group's local reference channel from [nSamples x nChan] data.
%   Y = ds.applyLocalReference(X): while ArtifactConfig.LocalReference is
%   on, each group of LocalReferenceMap has its reference channel
%   subtracted, sample by sample, from the group's channels. X holds all
%   of the recording's amplifier channels, in recording order
%   (microvolts). The reference columns are taken from X before any
%   column is changed, so a reference channel that is itself in another
%   group is subtracted as it is in X. A reference channel in its own
%   group becomes zeros, so every step leaves it out
%   (localReferenceZeroed, excludedChannels). Channels in no group are
%   returned unchanged (channels off the probe; localReferenceProblems
%   requires every channel on the probe to be in a group). While
%   LocalReference is off, or for an empty X, X is returned unchanged.
%   Each sample is referenced on its own, so the result does not depend
%   on how the recording is cut into chunks or windows.
%
%   applyReference calls it before the common reference, so readChunkUV
%   and readWindowUV subtract it first, and the weighted CAR (wcarRows,
%   prepareWCAR) and deriveSignals do the same: the common reference
%   (CAR / CMR / WCAR) is taken over the locally referenced channels.
%
%   With LocalReference on and no group, it is an error
%   (EphysDataset:LocalReference:NotSet), and so is a group channel past
%   the columns of X (EphysDataset:LocalReference:BadChannels).
%
%   See also EphysDataset.applyReference, EphysDataset.localReferenceProblems,
%   EphysDataset.localReferenceZeroed, LocalReferenceDialog.

if isempty(X) || ~obj.localReferenceOn()
    return
end
M = obj.LocalReferenceMap;
if isempty(M)
    error('EphysDataset:LocalReference:NotSet', ...
        ['The local reference of %s is on, but no reference channel is assigned. Assign one per shank ' ...
         'or per probe (Artifacts tab, Local reference...) or turn the local reference off.'], obj.Name);
end
refs = [M.reference];
top = max([refs, M.channels]);
if top > size(X, 2)
    error('EphysDataset:LocalReference:BadChannels', ...
        ['The local reference of %s names channel %d, but the data has %d column(s); it must hold ' ...
         'all of the recording''s amplifier channels, in recording order.'], obj.Name, top, size(X, 2));
end
R = X(:, refs);   % the reference channels before any group is changed
for k = 1:numel(M)
    c = M(k).channels;
    X(:, c) = X(:, c) - R(:, k);
end
end
