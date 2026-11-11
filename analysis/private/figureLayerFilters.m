function F = figureLayerFilters(L)
%figureLayerFilters  The filters (a SignalFilter chain) a figure layer reads its signal through: 1x0 for none.
%   F = figureLayerFilters(L) for a layer of a figure spec (figureFor adds
%   L.filters: Source.SignalFilter's filter for its signal, then its
%   panel's options.filter, the enabled ones) is that chain, 1x0 when it
%   has none (no field: a spec made before filters existed).
%   figureSignalLayer and figureChronuxLayer read the layer's columns
%   through it (selectChannels' Filter), the whole recording filtered
%   before the epochs are cut.
%
%   See also EphysAnalysisConfig.figureFor, figureLayerRate, selectChannels, SignalFilter.
F = repmat(SignalFilter.defaults(), 1, 0);
if isfield(L, 'filters'); F = SignalFilter.chain(L.filters); end
end
