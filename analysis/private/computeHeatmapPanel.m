function P = computeHeatmapPanel(src, panel, E, G, ctx)
%computeHeatmapPanel  A figure's heat map panel: one layer's units or channels by time.
%   P = computeHeatmapPanel(SRC, PANEL, E, G, CTX) (figurePanelRegistry's
%   compute for "heatmap"; CTX from EphysAnalysisRunner.computeFigure) has
%   P.layers, one per layer of PANEL (figurePanelLayers). The first enabled
%   layer that is not events marks is the map:
%     units / detected / events train   figurePointLayer: spikePSTH with the
%         panel's bins, measure, baseline and maskAfterStop (no raster):
%         R.rate [nBins x nUnits x nGroups]
%     LFP / MUA / SPIKE / AUX           figureSignalLayer: evokedPotential
%         with the baseline subtracted (Mode other than "none"): R.mean
%         [nTime x nChannels x nGroups]
%   Every group is computed; options.group picks the one drawn, and
%   options.order / cLim are the draw function's. Events marks layers are
%   computed too (R.kind "events": latency lines over the map); a further
%   map layer is skipped ("A heat map draws its first enabled layer
%   only").
%
%   See also figurePanelRegistry, figurePointLayer, figureSignalLayer.

o = panel.options;
w = panel.window;
b = [];
if o.baseline.Mode ~= "none"; b = o.baseline.Window; end
P = struct('layers', figurePanelLayers(panel, ctx.skips));
[ctx.errorType, ctx.nBoot] = figureErrorType(ctx.spec, panel);   % the band this panel draws ("sem" where none)
mapped = false;
for j = 1:numel(P.layers)
    if P.layers(j).skip == "disabled"; continue; end
    L = panel.layers(j);
    isMarks = L.source == "events" && L.eventsAs == "marks";
    if ~isMarks
        if mapped
            P.layers(j).skip = "A heat map draws its first enabled layer only";
            continue
        end
        mapped = true;
    end
    if P.layers(j).skip ~= ""; continue; end
    if ismember(L.source, EphysAnalysisConfig.SignalSources)
        P.layers(j) = figureSignalLayer(src, L, P.layers(j), E, G, ctx, Window=[w.pre w.post], Baseline=b);
    else
        P.layers(j) = figurePointLayer(src, L, P.layers(j), E, G, ctx, Window=[w.pre w.post], ...
            BinSec=o.bins.BinSec, SmoothSec=o.bins.SmoothSec, Measure=o.measure, Baseline=b, ...
            BaselineMode=o.baseline.Mode, MaskAfterStop=o.maskAfterStop, Raster=false);
    end
end
end
