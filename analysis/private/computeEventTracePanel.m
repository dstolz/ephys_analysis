function P = computeEventTracePanel(src, panel, E, G, ctx) %#ok<INUSL>
%computeEventTracePanel  A figure's event-trace panel: each events layer's intervals, onset to offset, in each epoch.
%   P = computeEventTracePanel(SRC, PANEL, E, G, CTX) (figurePanelRegistry's
%   compute for "eventTrace"; CTX from EphysAnalysisRunner.computeFigure)
%   has P.layers, one per layer of PANEL (figurePanelLayers). Each events
%   layer (one digital or derived line, its event an EventMark) is
%   epochIntervals of eventMarkRef(L.event) over the panel's epochs E, with
%   R.kind "eventTrace" (fields line, label, epoch, on, off, window,
%   nEpochs: s from each epoch's event, not clipped); its name ("" =
%   automatic) is the line's. Its eventsAs is not used. A layer of another
%   source is skipped ("An event-trace panel draws events layers only"),
%   and a line whose intervals have no offset after their onset is skipped
%   with epochIntervals' reason; a line without an event in the epochs is
%   an empty row, not skipped. The options are the draw function's
%   (drawEventTracePanel).
%
%   See also figurePanelRegistry, epochIntervals, drawEventTracePanel.

P = struct('layers', figurePanelLayers(panel, ctx.skips));
for j = 1:numel(P.layers)
    if P.layers(j).skip ~= ""; continue; end
    L = panel.layers(j);
    if L.source ~= "events"
        P.layers(j).skip = "An event-trace panel draws events layers only";
        continue
    end
    ctx.checkpoint();
    try
        R = epochIntervals(src, E, eventMarkRef(L.event));
    catch ME
        P.layers(j).skip = figureLayerError(ME);
        continue
    end
    R.kind = "eventTrace";
    P.layers(j).R = R;
    if P.layers(j).name == ""; P.layers(j).name = R.line; end
end
end
