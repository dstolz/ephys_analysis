function P = computeContinuousPanel(src, panel, E, G, ctx)
%computeContinuousPanel  A figure's continuous signal panel: each signal layer's epoch mean.
%   P = computeContinuousPanel(SRC, PANEL, E, G, CTX) (figurePanelRegistry's
%   compute for "continuous"; CTX from EphysAnalysisRunner.computeFigure)
%   has P.layers, one per layer of PANEL (figurePanelLayers):
%     LFP / MUA / SPIKE / AUX   figureSignalLayer: evokedPotential over the
%         layer's columns (the observed unit's channel, the observed
%         channel, or the fixed channels) with the panel's baseline (Mode
%         "subtract": each epoch's mean over its Window), transform
%         ("rectify"), statistic and error type (options.errorType, "sem"
%         when "off"): R.mean / err [nTime x nChannels x nGroups];
%         aggregate "mean" adds R.layerMean. With options.trials "faint"
%         or "only" the epochs' traces are kept too (KeepEpochs): R.data
%         [nTime x nChannels x nTrials], R.trialEpochs, R.trialGroup, at
%         most options.maxTrials epochs picked evenly over their order
%     events (marks)            figurePointLayer: R.kind "events", the
%         marks' latencies (drawn as lines)
%   options.display, stackSpacing and yLim are the draw function's.
%
%   See also figurePanelRegistry, figureSignalLayer, evokedPotential.

o = panel.options;
w = panel.window;
b = [];
if o.baseline.Mode ~= "none"; b = o.baseline.Window; end
P = struct('layers', figurePanelLayers(panel, ctx.skips));
[ctx.errorType, ctx.nBoot] = figureErrorType(ctx.spec, panel);   % the band this panel draws ("sem" where none)
for j = 1:numel(P.layers)
    if P.layers(j).skip ~= ""; continue; end
    L = panel.layers(j);
    if L.source == "events"
        P.layers(j) = figurePointLayer(src, L, P.layers(j), E, G, ctx, Window=[w.pre w.post], Raster=false);
    else
        P.layers(j) = figureSignalLayer(src, L, P.layers(j), E, G, ctx, Window=[w.pre w.post], Baseline=b, ...
            Rectify=o.transform == "rectify", Statistic=o.statistic, KeepEpochs=o.trials ~= "off", MaxTrials=o.maxTrials);
    end
end
end
