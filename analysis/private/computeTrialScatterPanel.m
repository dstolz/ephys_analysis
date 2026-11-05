function P = computeTrialScatterPanel(src, panel, E, G, ctx) %#ok<INUSL>
%computeTrialScatterPanel  A figure's trial scatter panel: a p1 stub, replaced by package p2 (trial measures).
%   P = computeTrialScatterPanel(SRC, PANEL, E, G, CTX) (figurePanelRegistry's
%   compute for "trialScatter") has P.layers, one per layer of PANEL
%   (figurePanelLayers), every enabled one skipped with "trial panels are
%   computed in a later package": the schema (panelTypes, validate,
%   templates) is in place, the compute (trialMeasure, the grouping and
%   statistics) is not yet. Package p2 replaces this stub.
%
%   See also figurePanelRegistry, drawTrialScatterPanel.

P = struct('layers', figurePanelLayers(panel, ctx.skips));
for j = 1:numel(P.layers)
    if P.layers(j).skip == ""; P.layers(j).skip = "trial panels are computed in a later package"; end
end
end
