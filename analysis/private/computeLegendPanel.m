function P = computeLegendPanel(src, panel, E, G, ctx) %#ok<INUSL>
%computeLegendPanel  A figure's legend panel: nothing to compute (it holds the figure's legend).
%   P = computeLegendPanel(SRC, PANEL, E, G, CTX) (figurePanelRegistry's
%   compute for "legend") has P.layers, one per layer of PANEL
%   (figurePanelLayers; a legend panel has none), each as it was given.
%   renderFigure puts the figure's legend on the panel's hidden axes.
%
%   See also figurePanelRegistry, drawLegendPanel, renderFigure.

P = struct('layers', figurePanelLayers(panel, ctx.skips));
end
