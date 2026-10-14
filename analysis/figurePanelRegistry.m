function reg = figurePanelRegistry()
%figurePanelRegistry  How each figure panel type is computed and drawn.
%   REG = figurePanelRegistry() is a struct with one field per panel type
%   of EphysAnalysisConfig.panelTypes() (raster, psth, continuous, heatmap,
%   waveforms, behavior, probemap, corrmap), each a struct with
%     compute  @(src, panel, E, G, ctx) -> P, the panel's result: P.layers,
%              one entry per layer of the panel (figurePanelLayers: name,
%              source, binding, category, eventsAs, skip, R, meta). SRC is
%              loadAnalysisSource's, PANEL one of figureFor's resolved
%              panels, E / G the panel's epochs and groups (epochTable; []
%              for a panel that is not aligned) and CTX what
%              EphysAnalysisRunner.computeFigure passes: check (the
%              checkpoint handle for Check=, or []), checkpoint, observation,
%              observe, ref (the panel's), window, selection (the
%              figure's), style, errorType / nBoot (figureErrorType) and
%              skips (figureSkipReason's reason per layer)
%     draw     the draw function (renderFigure's), [] until it is written
%   EphysAnalysisRunner.computeFigure and renderFigure dispatch through it
%   (no switch on the type). The functions live in analysis/private:
%   computeRasterPanel, computePsthPanel, computeContinuousPanel,
%   computeHeatmapPanel, computeWaveformsPanel, computeBehaviorPanel,
%   computeProbeMapPanel, computeCorrMapPanel.
%
%   See also EphysAnalysisRunner.computeFigure, EphysAnalysisConfig.panelTypes.

reg = struct();
reg.raster     = entry(@computeRasterPanel);
reg.psth       = entry(@computePsthPanel);
reg.continuous = entry(@computeContinuousPanel);
reg.heatmap    = entry(@computeHeatmapPanel);
reg.waveforms  = entry(@computeWaveformsPanel);
reg.behavior   = entry(@computeBehaviorPanel);
reg.probemap   = entry(@computeProbeMapPanel);
reg.corrmap    = entry(@computeCorrMapPanel);
end


function e = entry(compute)
e = struct('compute', compute, 'draw', []);
end
