function [R, E, G] = computePlot(obj, src, spec) %#ok<INUSD>
%computePlot  Compute one plot's result for one dataset: the one compute path.
%   [R, E, G] = r.computePlot(SRC, SPEC) with SRC from source() and SPEC from
%   Config.plotFor(id):
%     psth / raster / heatmap of spikes
%         [E, G] = epochTable(src, spec.ref, Window=spec.window, Selection=spec.selection,
%             Baseline=, Columns=spec.rasterSort) (the artifact test covers a
%             baseline outside the window; Columns only for a trial parameter)
%         [st, meta] = selectUnits(src, spec.units, Ref=spec.ref, Selection=spec.selection)
%             (Ref / Selection: the events of an enabled units.response test)
%         R = spikePSTH(st, E, Window=[pre post], BinSec=, SmoothSec=, Measure=,
%             Baseline=, BaselineMode=, MaskAfterStop=, Raster=, Groups=G, Meta=meta,
%             Auroc=spec.auroc) (Auroc: baseline Mode "auroc")
%     evoked / heatmap of a signal
%         [E, G] = epochTable(...)
%         [Y, fs, meta] = selectChannels(src, spec.source, Channels=spec.channels)
%         R = evokedPotential(Y, fs, E, Window=[pre post], Baseline=, Groups=G,
%             Meta=meta, Units=)
%     rate      firingRate(st, E, Measure=, Baseline=, Normalize=spec.baseline.Mode, ...)
%     tuning    epochTable(..., Columns=[param seriesParam]), firingRate, then
%               tuningCurve(F.rate, E.(param), Series=E.(seriesParam), ...)
%     corrmap   unitCorrelation(st, E, Metric=spec.metric, Type=spec.correlation,
%               BinSec=, SmoothSec=, Baseline=, BaselineMode=, Groups=G, Meta=meta)
%     probemap  probeMapValues(unitSummary(src, Source=, Units=, Ref=, Selection=), src.probe, Value=)
%     behavior  epochTable(..., Columns=[param seriesParam yParam], Incomplete="keep",
%               Artifacts="keep") (every event's epoch: the window and the
%               signals' artifact periods do not concern behavior), then
%               behaviorValues(y, E.(param), Series=E.(seriesParam), ...) with
%               y = E.(yParam), or 1000 * (E.t1 - E.t0) (ms) for yParam "stop"
%   A raster of spikes (raster, or psth with withRaster) with event lines
%   to mark (spec.rasterEvents.lines) also gets R.rasterEvents =
%   epochEvents(src, E, Lines=, Edge=, Scope=).
%     waveforms [~, meta] = selectUnits(src, spec.units, Ref=, Selection=); R holds
%               meta, labels, one group, and the probe map; the waveforms below
%   A waveforms plot, a raster, or a PSTH or tuning grid, of spikes with
%   spec.waveform.mode other than "off" also gets R.waveforms = unitWaveforms(src, R.meta,
%   Source=spec.source, MaxSpikes=spec.waveform.maxSpikes): the units it
%   kept, in its order.
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
        [E, G] = epochTable(src, spec.ref, Window=w, Selection=spec.selection, Baseline=b, Columns=sortColumns(spec));
        if isSignal
            [Y, fs, meta] = selectChannels(src, spec.source, Channels=spec.channels);
            R = evokedPotential(Y, fs, E, Window=[w.pre w.post], Baseline=b, Groups=G, Meta=meta, Units=meta.units(1));
        else
            [st, meta] = selectUnits(src, spec.units, Ref=spec.ref, Selection=spec.selection);
            R = spikePSTH(st, E, Window=[w.pre w.post], BinSec=spec.bins.BinSec, SmoothSec=spec.bins.SmoothSec, ...
                Measure=spec.measure, Baseline=b, BaselineMode=spec.baseline.Mode, MaskAfterStop=spec.maskAfterStop, ...
                Raster=spec.kind == "raster" || (spec.kind == "psth" && spec.withRaster), Groups=G, Meta=meta, ...
                Auroc=spec.auroc);
            if isfield(R, 'raster') && ~isempty(R.raster) && ~isempty(spec.rasterEvents.lines)
                m = spec.rasterEvents;
                R.rasterEvents = epochEvents(src, E, Lines=m.lines, Edge=m.edge, Scope=m.scope);
            end
        end
    case "evoked"
        [E, G] = epochTable(src, spec.ref, Window=w, Selection=spec.selection, Baseline=b);
        [Y, fs, meta] = selectChannels(src, spec.source, Channels=spec.channels);
        R = evokedPotential(Y, fs, E, Window=[w.pre w.post], Baseline=b, Groups=G, Meta=meta, Units=meta.units(1));
    case "rate"
        [E, G] = epochTable(src, spec.ref, Window=w, Selection=spec.selection, Baseline=b);
        [st, meta] = selectUnits(src, spec.units, Ref=spec.ref, Selection=spec.selection);
        R = firingRate(st, E, Measure=spec.measure, Baseline=b, Normalize=spec.baseline.Mode, Groups=G, Meta=meta);
    case "tuning"
        cols = [spec.param spec.seriesParam];
        [E, G] = epochTable(src, spec.ref, Window=w, Selection=spec.selection, Baseline=b, Columns=cols(cols ~= ""));
        [st, meta] = selectUnits(src, spec.units, Ref=spec.ref, Selection=spec.selection);
        F = firingRate(st, E, Measure=spec.measure, Baseline=b, Normalize=spec.baseline.Mode, Groups=G, Meta=meta);
        series = [];
        if spec.seriesParam ~= ""; series = E.(spec.seriesParam); end
        R = tuningCurve(F.rate, E.(spec.param), Series=series, Param=spec.param, SeriesParam=spec.seriesParam, ...
            Meta=meta, Units=F.units);
    case "corrmap"
        [E, G] = epochTable(src, spec.ref, Window=w, Selection=spec.selection, Baseline=b);
        [st, meta] = selectUnits(src, spec.units, Ref=spec.ref, Selection=spec.selection);
        R = unitCorrelation(st, E, Metric=spec.metric, Type=spec.correlation, BinSec=spec.bins.BinSec, ...
            SmoothSec=spec.bins.SmoothSec, Baseline=b, BaselineMode=spec.baseline.Mode, Groups=G, Meta=meta);
    case "probemap"
        T = unitSummary(src, Source=spec.source, Units=spec.units, Ref=spec.ref, Selection=spec.selection);
        R = probeMapValues(T, src.probe, Value=spec.value);
        G = R.groups;
    case "waveforms"
        [~, meta] = selectUnits(src, spec.units, Ref=spec.ref, Selection=spec.selection);
        G = table(1, "all", [0.15 0.15 0.15], height(meta), 'VariableNames', {'index', 'label', 'color', 'n'});
        R = struct('kind', "waveforms", 'meta', meta, 'labels', meta.label, 'n', height(meta), 'groups', G, 'probe', src.probe);
    case "behavior"
        cols = [spec.param spec.seriesParam];
        if spec.yParam ~= "stop"; cols(end+1) = spec.yParam; end
        [E, G] = epochTable(src, spec.ref, Window=w, Selection=spec.selection, Columns=cols(cols ~= ""), ...
            Incomplete="keep", Artifacts="keep");
        series = [];
        if spec.seriesParam ~= ""; series = E.(spec.seriesParam); end
        if spec.yParam == "stop"
            y = 1000 * (E.t1 - E.t0);
            yName = "stop latency";
            if ~isempty(w.stop); yName = w.stop.line + " " + w.stop.edge + " latency"; end
            yUnits = "ms";
        else
            y = E.(spec.yParam);
            yName = spec.yParam;
            yUnits = "";
        end
        R = behaviorValues(y, E.(spec.param), Series=series, Param=spec.param, SeriesParam=spec.seriesParam, ...
            YName=yName, YUnits=yUnits);
    otherwise
        error('EphysAnalysisRunner:BadKind', 'Unknown plot kind "%s".', spec.kind);
end
if drawsWaveforms(spec)
    R.waveforms = unitWaveforms(src, R.meta, Source=spec.source, MaxSpikes=spec.waveform.maxSpikes);
end
R.epochs = E;
R.dataset = src.name;
R.spec = spec;
end


function c = sortColumns(spec)
%sortColumns  The trial parameter a raster sorts its epochs by, as epochTable Columns.
c = string.empty(1, 0);
if ismember(spec.kind, ["psth" "raster"]) && ~ismember(spec.rasterSort, ["" "stop"])
    c = spec.rasterSort;
end
end


function tf = drawsWaveforms(spec)
%drawsWaveforms  The plot draws each unit's waveform: a raster, or a PSTH or tuning grid, of spikes, with waveform.mode on; a waveforms plot.
tf = ismember(spec.source, EphysAnalysisConfig.SpikeSources) && (spec.kind == "waveforms" || ...
    (spec.waveform.mode ~= "off" && (spec.kind == "raster" || (ismember(spec.kind, ["psth" "tuning"]) && spec.layout ~= "overlay"))));
end
