function P = computePsthPanel(src, panel, E, G, ctx)
%computePsthPanel  A figure's PSTH panel: each point layer's peri-event rate.
%   P = computePsthPanel(SRC, PANEL, E, G, CTX) (figurePanelRegistry's
%   compute for "psth"; CTX from EphysAnalysisRunner.computeFigure) has
%   P.layers, one per layer of PANEL (figurePanelLayers), each computed by
%   figurePointLayer with the panel's bins, measure, baseline (Mode and
%   Window; Mode "auroc" with options.auroc: auROC curves, R.auroc the
%   calls) and maskAfterStop, and its band's error type (CTX.errorType,
%   figureErrorType): units / detected layers and events trains are
%   spikePSTH results (rate / err [nBins x nUnits x nGroups]; aggregate
%   "mean" adds R.layerMean), events marks are R.kind "events" (their
%   latencies, drawn as lines). The rows of a raster are kept (Raster=true)
%   when an events-marks layer is drawn, and when options.latencyBox is
%   enabled on a trace display (the box plot's first-spike latencies are
%   read from them at draw time: firstSpikeLatency). options.normalize,
%   histStyle, fill, stack, stackSpacing, latencyBox's look and yLim are
%   the draw function's.
%
%   See also figurePanelRegistry, figurePointLayer, spikePSTH.

o = panel.options;
w = panel.window;
b = [];
if o.baseline.Mode ~= "none"; b = o.baseline.Window; end
P = struct('layers', figurePanelLayers(panel, ctx.skips));
[ctx.errorType, ctx.nBoot] = figureErrorType(ctx.spec, panel);   % the band this panel draws ("sem" where none)
on = arrayfun(@(l) l.skip == "", P.layers);
marks = any(on & arrayfun(@(L) L.source == "events" && L.eventsAs == "marks", panel.layers));
box = isfield(o, 'latencyBox') && o.latencyBox.enabled && o.display ~= "heatmap";   % the box plot reads the raster's rows
for j = find(on)
    P.layers(j) = figurePointLayer(src, panel.layers(j), P.layers(j), E, G, ctx, Window=[w.pre w.post], ...
        BinSec=o.bins.BinSec, SmoothSec=o.bins.SmoothSec, Measure=o.measure, Baseline=b, BaselineMode=o.baseline.Mode, ...
        MaskAfterStop=o.maskAfterStop, Raster=marks || box, Waveform=o.waveform, Auroc=o.auroc);
end
end
