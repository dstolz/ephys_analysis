function [ch, bad] = excludedChannels(obj)
%excludedChannels  The channels every step leaves out.
%   CH = ds.excludedChannels() returns, 1-based and sorted, ExcludeChannels
%   (set on the Probe tab) and, while ArtifactConfig.ExcludeBadChannels is
%   on, BadChannels. They take no part in the common reference, artifact
%   detection or sorting (dropped from the sorter's chanMap; they stay in
%   the .bin). The bad channels are also left out of spike detection and
%   dropped by the Signals step, so the exports hold none of them;
%   ExcludeChannels are, there, as Spikes.Channels and
%   Signals.ExcludeHandling say. Nothing is worked out here: a run settles
%   BadChannels first (prepareBadChannels).
%
%   [CH, BAD] = ds.excludedChannels() also returns the BadChannels in force
%   (none while ExcludeBadChannels is off).
%
%   See also EphysDataset.prepareBadChannels, EphysDataset.referenceChannels.

bad = double.empty(1, 0);
if EphysDataset.normalizeArtifactConfig(obj.ArtifactConfig).ExcludeBadChannels
    bad = unique(obj.BadChannels);
end
ch = unique([obj.ExcludeChannels, bad]);
if isempty(ch)
    ch = double.empty(1, 0);
end
end
