function [iv, given] = explicitIntervals(v)
%explicitIntervals  Resolve an ArtifactIntervals option.
%   [IV, GIVEN] = explicitIntervals(V) returns GIVEN = false for the option
%   default NaN, meaning "work out the intervals from the dataset". Anything
%   else is an explicit [k x 2] list of seconds, and an empty list means
%   "silence nothing". The default is a scalar NaN because every empty k x 2
%   matrix compares equal, so an empty-matrix default cannot be told apart
%   from an explicit empty list.
given = ~(isscalar(v) && isnan(v));
if ~given
    iv = zeros(0, 2);
elseif isempty(v)
    iv = zeros(0, 2);
elseif size(v, 2) == 2
    iv = double(v);
else
    error('EphysDataset:BadArtifactIntervals', ...
        'ArtifactIntervals must be a [k x 2] matrix of seconds (got %s).', mat2str(size(v)));
end
end
