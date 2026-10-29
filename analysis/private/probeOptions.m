function o = probeOptions(popts)
%probeOptions  A probe figure's layout settings (Figure.probe) with every field: those POPTS lacks from the defaults.
%   O = probeOptions(POPTS) for SPEC.probe (EphysAnalysisConfig.defaults(
%   "FigureProbe")): enabled, layout, overlap, lanes, shanks, channels,
%   depthRange, maxTiles, maxPerSite, tileWidth, tileHeight, tileScale,
%   labels, sharedY, scaleTile, showSites, leaders. A field POPTS lacks (or
%   POPTS not a struct) takes the default; text fields are strings.
%
%   See also probeTileLayout, renderProbeFigure.
try
    d = EphysAnalysisConfig.defaults("FigureProbe");
catch
    d = struct('enabled', false, 'layout', "schematic", 'overlap', "nudge", 'lanes', 2, 'shanks', [], 'channels', [], ...
        'depthRange', [], 'maxTiles', 64, 'maxPerSite', 3, 'tileWidth', 0.9, 'tileHeight', 0.9, 'tileScale', 1, ...
        'labels', "short", 'sharedY', true, 'scaleTile', true, 'showSites', true, 'leaders', true);
end
o = d;
if ~isstruct(popts) || ~isscalar(popts); return; end
for f = reshape(string(fieldnames(popts)), 1, [])
    o.(f) = popts.(f);
end
for f = ["layout" "overlap" "labels"]
    o.(f) = string(o.(f));
end
end
