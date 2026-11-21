function [ch, bad, dropped] = excludedChannels(obj)
%excludedChannels  The channels every step leaves out.
%   CH = ds.excludedChannels() returns, 1-based and sorted, ExcludeChannels
%   (set on the Probe tab), the channels switched off or on during the
%   recording (DroppedChannels: zero where a file lacks them) and, while
%   ArtifactConfig.ExcludeBadChannels is on, BadChannels. They take no part
%   in the common reference, artifact detection or sorting (dropped from
%   the sorter's chanMap; they stay in the .bin). The bad and switched
%   channels are also left out of spike detection and dropped by the
%   Signals step, so the exports hold none of them; ExcludeChannels are,
%   there, as Spikes.Channels and Signals.ExcludeHandling say. Nothing is
%   worked out here: a run settles BadChannels first (prepareBadChannels).
%
%   [CH, BAD] = ds.excludedChannels() also returns the bad channels in
%   force: BadChannels (none while ExcludeBadChannels is off) and the
%   switched channels, whatever ExcludeBadChannels says.
%
%   [CH, BAD, DROPPED] = ds.excludedChannels() also returns the switched
%   channels alone (their places in NativeNames).
%
%   See also EphysDataset.prepareBadChannels, EphysDataset.referenceChannels.

dropped = double.empty(1, 0);
if ~isempty(obj.DroppedChannels)
    dropped = reshape(find(ismember(obj.NativeNames, [obj.DroppedChannels.native])), 1, []);
end
bad = dropped;
if EphysDataset.normalizeArtifactConfig(obj.ArtifactConfig).ExcludeBadChannels
    bad = unique([reshape(obj.BadChannels, 1, []), dropped]);
end
ch = unique([obj.ExcludeChannels, bad]);
if isempty(ch)
    ch = double.empty(1, 0);
end
if isempty(bad)
    bad = double.empty(1, 0);
end
end
