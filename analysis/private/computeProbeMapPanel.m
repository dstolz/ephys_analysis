function P = computeProbeMapPanel(src, panel, E, G, ctx) %#ok<INUSL>
%computeProbeMapPanel  A figure's probe map panel: the layer's units on the probe, colored by their value (units per site: the sites).
%   P = computeProbeMapPanel(SRC, PANEL, E, G, CTX) (figurePanelRegistry's
%   compute for "probemap"; not aligned, so E and G are unused) has
%   P.layers, one per layer of PANEL (figurePanelLayers). Its first enabled
%   layer (units / detected) gets, as probeMapValues' probe map,
%     T = unitSummary(src, Source=, Units=, Ref=, Selection=)
%     R = probeMapValues(T, src.probe, Value=options.value)
%   plus R.dataset; the layer's meta is T. The observed unit (a unit
%   figure) is F.observation, for the draw function to ring its site.
%
%   See also figurePanelRegistry, unitSummary, probeMapValues, renderProbeMap.

o = panel.options;
P = struct('layers', figurePanelLayers(panel, ctx.skips));
[ctx.errorType, ctx.nBoot] = figureErrorType(ctx.spec, panel);   % the band this panel draws ("sem" where none)
[j, P.layers] = figureFirstLayer(P.layers, "A probe map");
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
    T = unitSummary(src, Source=L.source, Units=it.units, Ref=ctx.ref, Selection=ctx.selection);
    R = probeMapValues(T, src.probe, Value=o.value);
catch ME
    P.layers(j).skip = figureLayerError(ME);
    return
end
R.dataset = src.name;
lay.R = R;
lay.meta = T;
if lay.name == ""; lay.name = R.valueName; end
P.layers(j) = lay;
end
