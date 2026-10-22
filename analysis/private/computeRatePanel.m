function P = computeRatePanel(src, panel, E, G, ctx)
%computeRatePanel  A figure's firing rate panel: each point layer's rate in every epoch window, per trial group.
%   P = computeRatePanel(SRC, PANEL, E, G, CTX) (figurePanelRegistry's
%   compute for "rate"; CTX from EphysAnalysisRunner.computeFigure) has
%   P.layers, one per layer of PANEL (figurePanelLayers). Each enabled
%   units / detected layer, resolved for the observation by
%   figureLayerItems (the observed unit, or the fixed units it names), is,
%   as firingRate's rates,
%     [st, meta] = selectUnits(src, units, Ref=CTX.ref, Selection=CTX.selection)
%     R = firingRate(st, E, Measure=options.measure, Baseline=<the
%         baseline window, Mode not "none">, Normalize=options.baseline.Mode,
%         Groups=G, Meta=meta, ErrorType=, ErrorResamples=)
%   (R.meanRate [nUnits x nGroups], R.rate [nEpochs x nUnits], R.err: the
%   error figureErrorType gives a rate panel: the style's with ShowSEM and
%   display "bar", else "sem"), with R.epochs (E) and R.dataset; aggregate
%   "mean" adds R.layerMean (figureLayerMean over the units' means: mean,
%   lo, hi [1 x 1 x nGroups]); options.waveform.mode other than "off"
%   adds R.waveforms (unitWaveforms of the layer's units, the inset). E
%   may be "between" epochs (each its own length). options.display and
%   yLim are the draw function's. Data the dataset lacks skips the layer
%   with the reason (figureLayerError).
%
%   See also figurePanelRegistry, drawRatePanel, firingRate.

o = panel.options;
b = [];
if o.baseline.Mode ~= "none"; b = o.baseline.Window; end
P = struct('layers', figurePanelLayers(panel, ctx.skips));
[ctx.errorType, ctx.nBoot] = figureErrorType(ctx.spec, panel);   % the error bars this panel draws ("sem" where none)
for j = find(arrayfun(@(l) l.skip == "", P.layers))
    L = panel.layers(j);
    lay = P.layers(j);
    ctx.checkpoint();
    it = figureLayerItems(L, ctx.observation, ctx.observe, []);
    if it.skip ~= ""; P.layers(j).skip = it.skip; continue; end
    try
        [st, meta] = selectUnits(src, it.units, Ref=ctx.ref, Selection=ctx.selection);
        R = firingRate(st, E, Measure=o.measure, Baseline=b, Normalize=o.baseline.Mode, Groups=G, Meta=meta, ...
            ErrorType=ctx.errorType, ErrorResamples=ctx.nBoot);
    catch ME
        P.layers(j).skip = figureLayerError(ME);
        continue
    end
    R.epochs = E;
    R.dataset = src.name;
    if L.aggregate == "mean"
        [nU, nG] = size(R.meanRate);
        R.layerMean = figureLayerMean(reshape(R.meanRate, 1, nU, nG), [], ctx.errorType, ctx.nBoot, "units");
    end
    wf = o.waveform;
    if isstruct(wf) && wf.mode ~= "off"
        ctx.checkpoint();
        R.waveforms = unitWaveforms(src, meta, Source=L.source, MaxSpikes=wf.maxSpikes, Check=ctx.check);
    end
    lay.R = R;
    lay.meta = meta;
    if lay.name == ""; lay.name = figureUnitsName(meta, L); end
    P.layers(j) = lay;
end
end
