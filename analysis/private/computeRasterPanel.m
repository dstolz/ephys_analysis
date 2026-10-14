function P = computeRasterPanel(src, panel, E, G, ctx)
%computeRasterPanel  A figure's raster panel: each point layer's spike trains over the epochs.
%   P = computeRasterPanel(SRC, PANEL, E, G, CTX) (figurePanelRegistry's
%   compute for "raster"; CTX from EphysAnalysisRunner.computeFigure) has
%   P.layers, one per layer of PANEL (figurePanelLayers), each computed by
%   figurePointLayer with Raster=true over the panel's window: units /
%   detected layers are spikePSTH results (R.raster holds the rows; the
%   bins are 10 ms, unused by a raster), an events layer drawn as marks
%   is R.kind "events" (marks = epochEvents), one drawn as a train a
%   one-unit spikePSTH result of the line's events. With
%   options.waveform.mode on, units / detected layers carry R.waveforms
%   (the inset). With options.rasterSort "event", every spikePSTH result
%   gets R.rasterSortEvent = struct(label, t) (eventLatency of
%   options.rasterSortEvent: each epoch's latency to it), its sort key; a
%   trial-parameter sort reads R.epochs, which holds the parameter
%   (computeFigure's Columns).
%
%   See also figurePanelRegistry, figurePointLayer, rasterInto.

o = panel.options;
w = panel.window;
P = struct('layers', figurePanelLayers(panel, ctx.skips));
[ctx.errorType, ctx.nBoot] = figureErrorType(ctx.spec, panel);   % the band this panel draws ("sem" where none)
sortEv = [];
for j = 1:numel(P.layers)
    if P.layers(j).skip ~= ""; continue; end
    P.layers(j) = figurePointLayer(src, panel.layers(j), P.layers(j), E, G, ctx, Window=[w.pre w.post], ...
        MaskAfterStop=o.maskAfterStop, Raster=true, Waveform=o.waveform);
    R = P.layers(j).R;
    if o.rasterSort == "event" && isstruct(R) && isfield(R, 'raster')
        if isempty(sortEv)
            ctx.checkpoint();
            [t, label] = eventLatency(src, E, o.rasterSortEvent);
            sortEv = struct('label', label, 't', t);
        end
        P.layers(j).R.rasterSortEvent = sortEv;
    end
end
end
