function ch = referenceChannels(obj, opts)
%referenceChannels  The channels averaged into the common reference.
%   CH = ds.referenceChannels() returns the 1-based amplifier channels (in
%   recording order) the CAR / CMR is taken over: all NumChannels of them
%   except excludedChannels (ExcludeChannels and, while ExcludeBadChannels
%   is on, BadChannels) and ReferenceExclude (left
%   out of the reference, see suggestReferenceExclude).
%
%   CH = ds.referenceChannels(Exclude=CH2) also leaves the recording
%   channels CH2 out (deriveSignals: the channels the Signals step lists as
%   bad, which it replaces by interpolation).
%
%   While ArtifactConfig.LocalReference is on, only the channels of
%   LocalReferenceMap's groups count: the common reference is taken over
%   the locally referenced channels, and a channel in no group (a site
%   that is not connected, a channel off the probe), which keeps the
%   recording's own reference, stays out of the average (it is still
%   referenced).
%
%   See also EphysDataset.applyReference.

arguments
    obj (1,1) EphysDataset
    opts.Exclude (1,:) double = double.empty(1, 0)
end

n = obj.NumChannels;
if isnan(n)
    obj.refreshMetadata();
    n = obj.NumChannels;
end
ch = setdiff(1:n, [obj.excludedChannels(), obj.ReferenceExclude, opts.Exclude]);
if obj.localReferenceOn() && ~isempty(obj.LocalReferenceMap)
    ch = intersect(ch, [obj.LocalReferenceMap.channels]);   % the locally referenced channels only
    ch = reshape(ch, 1, []);
end
end
