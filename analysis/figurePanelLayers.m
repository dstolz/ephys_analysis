function layers = figurePanelLayers(panel, skips)
%figurePanelLayers  A figure panel's layer results before compute: one per layer of the spec, in order.
%   LAYERS = figurePanelLayers(PANEL, SKIPS) is a 1 x numel(PANEL.layers)
%   struct array, the shape of EphysAnalysisRunner.computeFigure's
%   F.panels(k).layers: every panel compute (figurePanelRegistry) starts
%   from it and fills R, meta and name, and computeFigure gives it as is to
%   a panel it skips. Fields
%     name      the layer's name ("" = automatic: the compute fills it in)
%     source, binding, category   as in the spec (figureFor)
%     eventsAs  "marks" | "train" for an events layer, else ""
%     skip      "" or why the layer is not computed: "disabled" for an
%               unticked layer, else SKIPS(j) (figureSkipReason's reason,
%               "" = compute it)
%     R         [] (the compute's result)
%     meta      [] (the units' or channels' table)
%   Layer j stays at index j whether or not it is computed, so a draw
%   function finds its look in PANEL.layers(j).
%
%   See also EphysAnalysisRunner.computeFigure, figurePanelRegistry.

arguments
    panel (1,1) struct
    skips (1,:) string = string.empty(1, 0)
end
n = numel(panel.layers);
layers = repmat(struct('name', "", 'source', "", 'binding', "", 'category', "", 'eventsAs', "", ...
    'skip', "", 'R', [], 'meta', []), 1, n);
for j = 1:n
    L = panel.layers(j);
    layers(j).name = L.name;
    layers(j).source = L.source;
    layers(j).binding = L.binding;
    if isfield(L, 'category'); layers(j).category = L.category; end
    if L.source == "events"; layers(j).eventsAs = L.eventsAs; end
    if ~L.enabled
        layers(j).skip = "disabled";
    elseif j <= numel(skips)
        layers(j).skip = skips(j);
    end
end
end
