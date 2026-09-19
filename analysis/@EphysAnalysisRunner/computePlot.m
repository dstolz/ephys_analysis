function [R, E, G] = computePlot(obj, src, spec) %#ok<INUSD>
%computePlot  Compute one plot's result for one dataset: the one compute path.
%   [R, E, G] = r.computePlot(SRC, SPEC) with SRC from source() and SPEC from
%   Config.plotFor(id):
%     psth / raster / heatmap of spikes
%         [E, G] = epochTable(src, spec.ref, Window=spec.window, Selection=spec.selection)
%         [st, meta] = selectUnits(src, spec.units)
%         R = spikePSTH(st, E, Window=[pre post], BinSec=, SmoothSec=,
%             Baseline=, BaselineMode=, MaskAfterStop=, Raster=, Groups=G, Meta=meta)
%     evoked / heatmap of a signal
%         [E, G] = epochTable(...)
%         [Y, fs, meta] = selectChannels(src, spec.source, Channels=spec.channels)
%         R = evokedPotential(Y, fs, E, Window=[pre post], Baseline=, Groups=G,
%             Meta=meta, Units=)
%     rate      firingRate(st, E, Baseline=, Normalize=spec.baseline.Mode, ...)
%     tuning    epochTable(..., Columns=[param seriesParam]), firingRate, then
%               tuningCurve(F.rate, E.(param), Series=E.(seriesParam), ...)
%     corrmap   unitCorrelation(st, E, Metric=spec.metric, Type=spec.correlation,
%               BinSec=, SmoothSec=, Baseline=, BaselineMode=, Groups=G, Meta=meta)
%     probemap  probeMapValues(unitSummary(src, Source=, Units=), src.probe, Value=)
%   R also gets epochs (E), dataset (the name) and spec. EphysAnalysisScript
%   writes these same calls out.
%
%   See also EphysAnalysisRunner.renderPlotFigures, EphysAnalysisRunner.runDataset.

w = spec.window;
b = [];
if spec.baseline.Mode ~= "none"; b = spec.baseline.Window; end
isSignal = ismember(spec.source, EphysAnalysisConfig.SignalSources);
E = [];
switch spec.kind
    case {"psth" "raster" "heatmap"}
        [E, G] = epochTable(src, spec.ref, Window=w, Selection=spec.selection);
        if isSignal
            [Y, fs, meta] = selectChannels(src, spec.source, Channels=spec.channels);
            R = evokedPotential(Y, fs, E, Window=[w.pre w.post], Baseline=b, Groups=G, Meta=meta, Units=meta.units(1));
        else
            [st, meta] = selectUnits(src, spec.units);
            R = spikePSTH(st, E, Window=[w.pre w.post], BinSec=spec.bins.BinSec, SmoothSec=spec.bins.SmoothSec, ...
                Baseline=b, BaselineMode=spec.baseline.Mode, MaskAfterStop=spec.maskAfterStop, ...
                Raster=spec.kind == "raster" || (spec.kind == "psth" && spec.withRaster), Groups=G, Meta=meta);
        end
    case "evoked"
        [E, G] = epochTable(src, spec.ref, Window=w, Selection=spec.selection);
        [Y, fs, meta] = selectChannels(src, spec.source, Channels=spec.channels);
        R = evokedPotential(Y, fs, E, Window=[w.pre w.post], Baseline=b, Groups=G, Meta=meta, Units=meta.units(1));
    case "rate"
        [E, G] = epochTable(src, spec.ref, Window=w, Selection=spec.selection);
        [st, meta] = selectUnits(src, spec.units);
        R = firingRate(st, E, Baseline=b, Normalize=spec.baseline.Mode, Groups=G, Meta=meta);
    case "tuning"
        cols = [spec.param spec.seriesParam];
        [E, G] = epochTable(src, spec.ref, Window=w, Selection=spec.selection, Columns=cols(cols ~= ""));
        [st, meta] = selectUnits(src, spec.units);
        F = firingRate(st, E, Baseline=b, Normalize=spec.baseline.Mode, Groups=G, Meta=meta);
        series = [];
        if spec.seriesParam ~= ""; series = E.(spec.seriesParam); end
        R = tuningCurve(F.rate, E.(spec.param), Series=series, Param=spec.param, SeriesParam=spec.seriesParam, ...
            Meta=meta, Units=F.units);
    case "corrmap"
        [E, G] = epochTable(src, spec.ref, Window=w, Selection=spec.selection);
        [st, meta] = selectUnits(src, spec.units);
        R = unitCorrelation(st, E, Metric=spec.metric, Type=spec.correlation, BinSec=spec.bins.BinSec, ...
            SmoothSec=spec.bins.SmoothSec, Baseline=b, BaselineMode=spec.baseline.Mode, Groups=G, Meta=meta);
    case "probemap"
        T = unitSummary(src, Source=spec.source, Units=spec.units);
        R = probeMapValues(T, src.probe, Value=spec.value);
        G = R.groups;
    otherwise
        error('EphysAnalysisRunner:BadKind', 'Unknown plot kind "%s".', spec.kind);
end
R.epochs = E;
R.dataset = src.name;
R.spec = spec;
end
