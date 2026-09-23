function X = applyReference(obj, X)
%applyReference  Subtract the common reference from [nSamples x nChan] data.
%   Y = ds.applyReference(X) subtracts, sample by sample, one global
%   reference from every channel of X (all of the recording's amplifier
%   channels, in recording order, microvolts), as ArtifactConfig.Reference
%   says:
%     "none"  X is returned unchanged
%     "car"   common average reference: the mean across the reference
%             channels (Ludwig et al. 2009, J Neurophysiol 101:1679)
%     "cmr"   common median reference: their median, which a large spike or
%             artifact on a few channels cannot drag along
%   The reference channels are referenceChannels(): every channel except
%   ExcludeChannels and ReferenceExclude. Those channels are still
%   referenced; they only stay out of the average. Each sample is referenced
%   on its own, so the result does not depend on how the recording is cut
%   into chunks or windows.
%
%   readChunkUV and readWindowUV call this on every read, so the reference
%   comes before artifact detection, the noise levels of the artifact fill,
%   the Kilosort4 .bin and spike detection, and deriveSignals calls it on
%   the whole recording it reads, a block of rows at a time, so the derived
%   LFP / MUA / SPIKE are referenced alike. The one exception is the
%   "commonmode" artifact detector, which looks for the very mean this
%   subtracts and so reads the chunk unreferenced. readData itself returns
%   the recording as stored.
%
%   See also EphysDataset.referenceChannels, EphysDataset.suggestReferenceExclude,
%   EphysDataset.prepareReference.

acfg = EphysDataset.normalizeArtifactConfig(obj.ArtifactConfig);
mode = string(acfg.Reference);
if mode == "none" || isempty(X)
    return
end

ch = obj.referenceChannels();
ch = ch(ch <= size(X, 2));
if isempty(ch)
    error('EphysDataset:applyReference:NoChannels', ...
        'Every channel of %s is left out of the common reference; include at least one.', obj.Name);
end

switch mode
    case "car"
        ref = mean(X(:, ch), 2);
    case "cmr"
        ref = median(X(:, ch), 2);
    otherwise
        error('EphysDataset:applyReference:BadMode', ...
            'Unknown Reference "%s" (use "none", "car" or "cmr").', mode);
end
X = X - ref;
end
