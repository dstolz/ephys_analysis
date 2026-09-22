function ch = referenceChannels(obj)
%referenceChannels  The channels averaged into the common reference.
%   CH = ds.referenceChannels() returns the 1-based amplifier channels (in
%   recording order) the CAR / CMR is taken over: all NumChannels of them
%   except ExcludeChannels (left out of sorting) and ReferenceExclude (left
%   out of the reference, see suggestReferenceExclude).
%
%   See also EphysDataset.applyReference.

n = obj.NumChannels;
if isnan(n)
    obj.refreshMetadata();
    n = obj.NumChannels;
end
ch = setdiff(1:n, [obj.ExcludeChannels, obj.ReferenceExclude]);
end
