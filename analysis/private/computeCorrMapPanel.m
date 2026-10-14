function P = computeCorrMapPanel(src, panel, E, G, ctx)
%computeCorrMapPanel  A figure's unit correlation panel: pairwise correlation of the layer's units' per-epoch rates.
%   P = computeCorrMapPanel(SRC, PANEL, E, G, CTX) (figurePanelRegistry's
%   compute for "corrmap") has P.layers, one per layer of PANEL
%   (figurePanelLayers). Its first enabled layer (units / detected) gets,
%   as computePlot's correlation map,
%     [st, meta] = selectUnits(src, units, Ref=, Selection=)
%     R = unitCorrelation(st, E, Metric=options.metric, Type=
%         options.correlation, FisherZ=, BinSec=, SmoothSec=, Baseline=,
%         BaselineMode=, Groups=G, Meta=meta)
%   (r / p [nUnits x nUnits x nGroups]) plus R.epochs and dataset. Every
%   group is computed; options.group picks the one drawn.
%
%   See also figurePanelRegistry, unitCorrelation, renderCorrMap.

o = panel.options;
b = [];
if o.baseline.Mode ~= "none"; b = o.baseline.Window; end
P = struct('layers', figurePanelLayers(panel, ctx.skips));
[ctx.errorType, ctx.nBoot] = figureErrorType(ctx.spec, panel);   % the band this panel draws ("sem" where none)
[j, P.layers] = figureFirstLayer(P.layers, "A unit correlation map");
if j == 0 || P.layers(j).skip ~= ""; return; end
L = panel.layers(j);
lay = P.layers(j);
it = figureLayerItems(L, ctx.observation, ctx.observe, []);
if it.skip ~= ""
    P.layers(j).skip = it.skip;
    return
end
ctx.checkpoint();
try
    [st, meta] = selectUnits(src, it.units, Ref=ctx.ref, Selection=ctx.selection);
catch ME
    P.layers(j).skip = figureLayerError(ME);
    return
end
R = unitCorrelation(st, E, Metric=o.metric, Type=o.correlation, FisherZ=logical(o.fisherZ), BinSec=o.bins.BinSec, ...
    SmoothSec=o.bins.SmoothSec, Baseline=b, BaselineMode=o.baseline.Mode, Groups=G, Meta=meta);
R.epochs = E;
R.dataset = src.name;
lay.R = R;
lay.meta = meta;
if lay.name == ""; lay.name = height(meta) + " " + L.source; end
P.layers(j) = lay;
end
