function r = figureLayerRate(L)
%figureLayerRate  The rate (Hz) a figure layer reads its signal at: its downsample, [] = the rate on file.
%   R = figureLayerRate(L) for a layer of a figure spec (figureFor adds
%   L.downsample: Source.Downsample's rate for its signal) is that rate,
%   or [] when it has none (no field, empty, not a positive number).
%   figureSignalLayer and figureChronuxLayer read the layer's columns at R
%   when it is below the rate on file (selectChannels' Rate).
%
%   See also EphysAnalysisConfig.figureFor, selectChannels, figureSignalLayer, figureChronuxLayer.
r = [];
if isfield(L, 'downsample') && isnumeric(L.downsample) && isscalar(L.downsample) && isfinite(L.downsample) && L.downsample > 0
    r = double(L.downsample);
end
end
