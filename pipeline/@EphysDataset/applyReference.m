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
%   the Kilosort4 .bin and spike detection; deriveSignals subtracts the same
%   reference (referenceTrace) from the derived signals that take it
%   (referenceSignals: MUA and SPIKE by default). The one exception is the
%   "commonmode" artifact detector, which looks for the very mean this
%   subtracts and so reads the chunk unreferenced. readData itself returns
%   the recording as stored.
%
%   See also EphysDataset.referenceTrace, EphysDataset.referenceChannels,
%   EphysDataset.suggestReferenceExclude,
%   EphysDataset.prepareReference.

r = obj.referenceTrace(X);
if isempty(r)
    return   % "none", or no data
end
X = X - r;
end
