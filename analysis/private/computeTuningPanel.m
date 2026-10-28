function P = computeTuningPanel(src, panel, E, G, ctx)
%computeTuningPanel  A figure's tuning curve panel: each point layer's rate against a trial parameter.
%   P = computeTuningPanel(SRC, PANEL, E, G, CTX) (figurePanelRegistry's
%   compute for "tuning"; CTX from EphysAnalysisRunner.computeFigure) has
%   P.layers, one per layer of PANEL (figurePanelLayers). The parameters
%   are figureTuningParam's (options.param, "" = the figure's first
%   groupBy parameter, else the trials' first numeric one; seriesParam),
%   columns of E (computeFigure copies them onto the epochs: epochTable's
%   Columns). Each enabled units / detected layer, resolved for the
%   observation by figureLayerItems, is, as tuningCurve's curve,
%     [st, meta] = selectUnits(src, units, Ref=CTX.ref, Selection=CTX.selection)
%     F = firingRate(st, E, Measure=, Baseline=, Normalize=options.baseline.Mode,
%         Groups=G, Meta=meta)
%     R = tuningCurve(F.rate, E.(param), Series=E.(seriesParam) ([] for
%         none), Param=, SeriesParam=, Meta=meta, Units=F.units,
%         ErrorType=, ErrorResamples=)
%   (R.mean [nX x nUnits x nSeries], R.err, R.groups: one row per series),
%   with R.epochs (E) and R.dataset; aggregate "mean" adds R.layerMean
%   (figureLayerMean over the units: mean, lo, hi [nX x 1 x nSeries]);
%   options.waveform.mode other than "off" adds R.waveforms (unitWaveforms
%   of the layer's units, the inset). A parameter E lacks skips every
%   layer ("no trial parameter X"); data the dataset lacks (no unit left,
%   no epoch with a value: tuningCurve:NoValues) skips the layer with the
%   reason (figureLayerError).
%
%   See also figurePanelRegistry, drawTuningPanel, tuningCurve, firingRate.

o = panel.options;
b = [];
if o.baseline.Mode ~= "none"; b = o.baseline.Window; end
P = struct('layers', figurePanelLayers(panel, ctx.skips));
[ctx.errorType, ctx.nBoot] = figureErrorType(ctx.spec, panel);   % the error bars this panel draws ("sem" where none)
[param, series] = figureTuningParam(o, ctx.selection, src);
vars = string(E.Properties.VariableNames);
missing = [param series];
missing = missing(missing ~= "" & ~ismember(missing, vars));
on = find(arrayfun(@(l) l.skip == "", P.layers));
if param == "" || ~isempty(missing)
    why = "no numeric trial parameter to tune over";
    if ~isempty(missing); why = "no trial parameter " + missing(1); end
    for j = on; P.layers(j).skip = why; end
    return
end
for j = on
    L = panel.layers(j);
    lay = P.layers(j);
    ctx.checkpoint();
    it = figureLayerItems(L, ctx.observation, ctx.observe, []);
    if it.skip ~= ""; P.layers(j).skip = it.skip; continue; end
    try
        [st, meta] = selectUnits(src, it.units, Ref=ctx.ref, Selection=ctx.selection);
        F = firingRate(st, E, Measure=o.measure, Baseline=b, Normalize=o.baseline.Mode, Groups=G, Meta=meta);
        s = [];
        if series ~= ""; s = E.(series); end
        R = tuningCurve(F.rate, E.(param), Series=s, Param=param, SeriesParam=series, Meta=meta, Units=F.units, ...
            ErrorType=ctx.errorType, ErrorResamples=ctx.nBoot);
    catch ME
        P.layers(j).skip = figureLayerError(ME);
        continue
    end
    R.epochs = E;
    R.dataset = src.name;
    if L.aggregate == "mean"
        R.layerMean = figureLayerMean(R.mean, R.x, ctx.errorType, ctx.nBoot, "units");
    end
    wf = o.waveform;
    if isstruct(wf) && wf.mode ~= "off"
        ctx.checkpoint();
        R.waveforms = unitWaveforms(src, meta, Source=L.source, MaxSpikes=wf.maxSpikes, Template=wf.mode == "template", Check=ctx.check);
    end
    lay.R = R;
    lay.meta = meta;
    if lay.name == ""; lay.name = figureUnitsName(meta, L); end
    P.layers(j) = lay;
end
end
