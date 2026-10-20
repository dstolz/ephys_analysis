function P = computeEventTracePanel(src, panel, E, G, ctx)
%computeEventTracePanel  A figure's event-trace panel: each events layer's intervals, onset to offset, in each epoch.
%   P = computeEventTracePanel(SRC, PANEL, E, G, CTX) (figurePanelRegistry's
%   compute for "eventTrace"; CTX from EphysAnalysisRunner.computeFigure)
%   has P.layers, one per layer of PANEL (figurePanelLayers). Each events
%   layer (one digital or derived line, its event an EventMark) is
%   epochIntervals of eventMarkRef(L.event) over the panel's epochs E, with
%   R.kind "eventTrace" (fields line, label, epoch, on, off, window,
%   nEpochs: s from each epoch's event, not clipped) and what orders its
%   epochs' sub-rows as a raster's (figEpochOrder): epochGroup (each
%   epoch's row of G), epochStop (its stop latency, NaN without), groups
%   (G), epochs (E: a trial parameter's column) and, with options.trials
%   "rows" and rasterSort "event", rasterSortEvent (label, t: eventLatency
%   of options.rasterSortEvent); combineSessions concatenates them across
%   sessions. Its name ("" = automatic) is the line's. Its eventsAs is not
%   used. A layer of another source is skipped ("An event-trace panel
%   draws events layers only"), and a line whose intervals have no offset
%   at or after their onset is skipped with epochIntervals' reason; a line
%   without an event in the epochs is an empty row, not skipped. The
%   options are the draw function's (drawEventTracePanel).
%
%   See also figurePanelRegistry, epochIntervals, drawEventTracePanel, figEpochOrder.

o = panel.options;
P = struct('layers', figurePanelLayers(panel, ctx.skips));
sortEv = [];
if o.trials == "rows" && o.rasterSort == "event" && ~isempty(o.rasterSortEvent) ...
        && any(arrayfun(@(l) l.skip == "", P.layers))
    ctx.checkpoint();
    try
        [t, label] = eventLatency(src, E, o.rasterSortEvent);
        sortEv = struct('label', label, 't', t);
    catch ME
        for j = 1:numel(P.layers)
            if P.layers(j).skip == ""; P.layers(j).skip = figureLayerError(ME); end
        end
        return
    end
end
gi = ones(height(E), 1);
if ismember("groupIndex", string(E.Properties.VariableNames)); gi = double(E.groupIndex(:)); end
stop = NaN(height(E), 1);
if ismember("t1", string(E.Properties.VariableNames)); stop = E.t1(:) - E.t0(:); end
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
    R.epochGroup = gi;
    R.epochStop = stop;
    R.groups = G;
    R.epochs = E;
    if ~isempty(sortEv); R.rasterSortEvent = sortEv; end
    P.layers(j).R = R;
    if P.layers(j).name == ""; P.layers(j).name = R.line; end
end
end
