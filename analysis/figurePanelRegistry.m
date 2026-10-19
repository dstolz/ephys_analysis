function reg = figurePanelRegistry()
%figurePanelRegistry  How each figure panel type is computed and drawn.
%   REG = figurePanelRegistry() is a struct with one field per panel type
%   of EphysAnalysisConfig.panelTypes() (raster, psth, continuous, heatmap,
%   waveforms, probemap, corrmap, rate, tuning, spectrum, spectrogram,
%   coherence, eventTrace), each a struct with
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
%     draw     @(ax, P, look) -> hk, the panel drawn into the axes AX:
%              P is the panel's result (F.panels(k) of computeFigure),
%              LOOK what renderFigure passes (style, colors: the trial
%              groups' palette, W: the panel's [pre post], spec, panel: the
%              spec's panel, panelId, isTop, isBottom, epochs, groups,
%              observation, isTime) and HK figDrawResult's struct: axes,
%              legendHandles, legendLabels, legendGroup, yName, extraAxes
%              (a coherence panel's phase axes under its magnitude)
%   EphysAnalysisRunner.computeFigure and renderFigure dispatch through it
%   (no switch on the type). The functions live in analysis/private:
%   computeRasterPanel, computePsthPanel, computeContinuousPanel,
%   computeHeatmapPanel, computeWaveformsPanel, computeProbeMapPanel,
%   computeCorrMapPanel, computeRatePanel, computeTuningPanel,
%   computeSpectrumPanel, computeSpectrogramPanel, computeCoherencePanel,
%   computeEventTracePanel,
%   and drawRasterPanel, drawPsthPanel, drawContinuousPanel,
%   drawHeatmapPanel, drawWaveformsPanel, drawProbeMapPanel,
%   drawCorrMapPanel, drawRatePanel, drawTuningPanel, drawSpectrumPanel,
%   drawSpectrogramPanel, drawCoherencePanel, drawEventTracePanel.
%
%   See also EphysAnalysisRunner.computeFigure, renderFigure, EphysAnalysisConfig.panelTypes.

reg = struct();
reg.raster     = entry(@computeRasterPanel,     @drawRasterPanel);
reg.psth       = entry(@computePsthPanel,       @drawPsthPanel);
reg.continuous = entry(@computeContinuousPanel, @drawContinuousPanel);
reg.heatmap    = entry(@computeHeatmapPanel,    @drawHeatmapPanel);
reg.waveforms  = entry(@computeWaveformsPanel,  @drawWaveformsPanel);
reg.probemap   = entry(@computeProbeMapPanel,   @drawProbeMapPanel);
reg.corrmap    = entry(@computeCorrMapPanel,    @drawCorrMapPanel);
reg.rate       = entry(@computeRatePanel,       @drawRatePanel);
reg.tuning     = entry(@computeTuningPanel,     @drawTuningPanel);
reg.spectrum   = entry(@computeSpectrumPanel,   @drawSpectrumPanel);
reg.spectrogram = entry(@computeSpectrogramPanel, @drawSpectrogramPanel);
reg.coherence  = entry(@computeCoherencePanel,  @drawCoherencePanel);
reg.eventTrace = entry(@computeEventTracePanel, @drawEventTracePanel);
end


function e = entry(compute, draw)
e = struct('compute', compute, 'draw', draw);
end
