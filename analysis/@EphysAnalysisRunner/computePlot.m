function [R, E, G] = computePlot(obj, src, spec, opts) %#ok<INUSD>
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
%   or sequences to mark (spec.rasterEvents.lines, .sequences) also gets
%   R.rasterEvents = epochEvents(src, E, Lines=, Edge=, Scope=, Sequences=);
%   one sorted by an event (spec.rasterSort "event") gets R.rasterSortEvent,
%   its sort key: a struct of t and label from [t, label] =
%   eventLatency(src, E, spec.rasterSortEvent), each epoch's latency to the
%   event (s) and the event's name.
%     waveforms [~, meta] = selectUnits(src, spec.units, Ref=, Selection=); R holds
%               meta, labels, one group, and the probe map; the waveforms below
%   A waveforms plot, a raster, or a PSTH or tuning grid, of spikes with
%   spec.waveform.mode other than "off" also gets R.waveforms = unitWaveforms(src, R.meta,
%   Source=spec.source, MaxSpikes=spec.waveform.maxSpikes): the units it
%   kept, in its order.
%   R also gets epochs (E), dataset (the name) and spec. EphysAnalysisScript
%   writes these same calls out.
%   While PollFcn is set (the app's preview) the compute can be stopped: a
%   checkpoint runs between its steps, and the per-unit and per-epoch loops
%   of spikePSTH, aurocCurves, evokedPotential and unitWaveforms get it as
%   Check=; after cancel() the next one throws EphysAnalysisRunner:Canceled
%   (checkpoint). A read of one file or one epochTable call is not
%   interrupted; the checkpoint after it is.
%   Page=P (the app's preview; default 0 = every page) computes only the
%   units or channels on page P of a grid (plotPageCount): the selection is
%   put in probe order (probeOrder with spec.style) and cut to that page's
%   Style.MaxTiles, and R.page = [P nPages] tells renderPlot and
%   plotPageCount which page it holds. A plot that is not a grid ignores it.
%
%   See also EphysAnalysisRunner.renderPlotFigures, EphysAnalysisRunner.runDataset.

arguments
    obj (1,1) EphysAnalysisRunner
    src (1,1) struct
    spec (1,1) struct
    opts.Page (1,1) double {mustBeNonnegative, mustBeInteger} = 0
end
w = spec.window;
pg = [];   % [page nPages] when only one page is computed
b = [];
if spec.baseline.Mode ~= "none"; b = spec.baseline.Window; end
isSignal = ismember(spec.source, EphysAnalysisConfig.SignalSources);
E = [];
chk = [];   % the checkpoint the long steps call, while the app's preview polls (PollFcn)
if ~isempty(obj.PollFcn); chk = @() obj.checkpoint(); end
obj.checkpoint();
switch spec.kind
    case {"psth" "raster" "heatmap"}
        [E, G] = epochTable(src, spec.ref, Window=w, Selection=spec.selection, Baseline=b, Columns=sortColumns(spec));
        obj.checkpoint();
        if isSignal
            [Y, fs, meta] = selectChannels(src, spec.source, Channels=spec.channels);
            R = evokedPotential(Y, fs, E, Window=[w.pre w.post], Baseline=b, Groups=G, Meta=meta, Units=meta.units(1), Check=chk);
        else
            [st, meta] = selectUnits(src, spec.units, Ref=spec.ref, Selection=spec.selection);
            if spec.kind == "raster" || (spec.kind == "psth" && spec.layout == "grid")
                [k, pg] = pageRows(meta, spec, opts.Page); st = st(k); meta = meta(k, :);
            end
            R = spikePSTH(st, E, Window=[w.pre w.post], BinSec=spec.bins.BinSec, SmoothSec=spec.bins.SmoothSec, ...
                Measure=spec.measure, Baseline=b, BaselineMode=spec.baseline.Mode, MaskAfterStop=spec.maskAfterStop, ...
                Raster=spec.kind == "raster" || (spec.kind == "psth" && spec.withRaster), Groups=G, Meta=meta, ...
                Auroc=spec.auroc, Check=chk);
            m = spec.rasterEvents;
            obj.checkpoint();
            if isfield(R, 'raster') && ~isempty(R.raster) && (~isempty(m.lines) || ~isempty(m.sequences))
                R.rasterEvents = epochEvents(src, E, Lines=m.lines, Edge=m.edge, Scope=m.scope, Sequences=m.sequences);
            end
            if isfield(R, 'raster') && ~isempty(R.raster) && spec.rasterSort == "event"
                R.rasterSortEvent = sortEvent(src, E, spec.rasterSortEvent);
            end
        end
    case "evoked"
        [E, G] = epochTable(src, spec.ref, Window=w, Selection=spec.selection, Baseline=b);
        [Y, fs, meta] = selectChannels(src, spec.source, Channels=spec.channels);
        if spec.layout == "grid"
            [k, pg] = pageRows(meta, spec, opts.Page);
            if ~isempty(pg); Y = Y(:, k); meta = meta(k, :); end
        end
        R = evokedPotential(Y, fs, E, Window=[w.pre w.post], Baseline=b, Groups=G, Meta=meta, Units=meta.units(1), Check=chk);
    case "rate"
        [E, G] = epochTable(src, spec.ref, Window=w, Selection=spec.selection, Baseline=b);
        [st, meta] = selectUnits(src, spec.units, Ref=spec.ref, Selection=spec.selection);
        R = firingRate(st, E, Measure=spec.measure, Baseline=b, Normalize=spec.baseline.Mode, Groups=G, Meta=meta);
    case "tuning"
        cols = [spec.param spec.seriesParam];
        [E, G] = epochTable(src, spec.ref, Window=w, Selection=spec.selection, Baseline=b, Columns=cols(cols ~= ""));
        [st, meta] = selectUnits(src, spec.units, Ref=spec.ref, Selection=spec.selection);
        if spec.layout == "grid"
            [k, pg] = pageRows(meta, spec, opts.Page); st = st(k); meta = meta(k, :);
        end
        F = firingRate(st, E, Measure=spec.measure, Baseline=b, Normalize=spec.baseline.Mode, Groups=G, Meta=meta);
        series = [];
        if spec.seriesParam ~= ""; series = E.(spec.seriesParam); end
        R = tuningCurve(F.rate, E.(spec.param), Series=series, Param=spec.param, SeriesParam=spec.seriesParam, ...
            Meta=meta, Units=F.units);
    case "corrmap"
        [E, G] = epochTable(src, spec.ref, Window=w, Selection=spec.selection, Baseline=b);
        [st, meta] = selectUnits(src, spec.units, Ref=spec.ref, Selection=spec.selection);
        R = unitCorrelation(st, E, Metric=spec.metric, Type=spec.correlation, FisherZ=logical(spec.fisherZ), BinSec=spec.bins.BinSec, ...
            SmoothSec=spec.bins.SmoothSec, Baseline=b, BaselineMode=spec.baseline.Mode, Groups=G, Meta=meta);
    case "probemap"
        T = unitSummary(src, Source=spec.source, Units=spec.units, Ref=spec.ref, Selection=spec.selection);
        R = probeMapValues(T, src.probe, Value=spec.value);
        G = R.groups;
    case "waveforms"
        [~, meta] = selectUnits(src, spec.units, Ref=spec.ref, Selection=spec.selection);
        if spec.layout == "grid"
            [k, pg] = pageRows(meta, spec, opts.Page); meta = meta(k, :);
        end
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
            if ~isempty(w.stop); yName = eventRefLabel(w.stop) + " latency"; end
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
obj.checkpoint();
if drawsWaveforms(spec)
    R.waveforms = unitWaveforms(src, R.meta, Source=spec.source, MaxSpikes=spec.waveform.maxSpikes, Check=chk);
end
R.epochs = E;
R.dataset = src.name;
R.spec = spec;
if ~isempty(pg); R.page = pg; end
end


function [k, pg] = pageRows(meta, spec, page)
%pageRows  The rows of META on page PAGE of the grid, in probe order ([k, []]: every row, as listed).
n = height(meta);
k = (1:n).';
pg = [];
if page < 1; return; end
per = max(1, round(spec.style.MaxTiles));
nPages = max(1, ceil(n / per));
page = min(page, nPages);
order = probeOrder(meta, n, spec.style);
k = order(pageItems(n, page, per));
pg = [page nPages];
end


function c = sortColumns(spec)
%sortColumns  The trial parameter a raster sorts its epochs by, as epochTable Columns.
c = string.empty(1, 0);
if ismember(spec.kind, ["psth" "raster"]) && ~ismember(spec.rasterSort, ["" "stop" "event"])
    c = spec.rasterSort;
end
end


function S = sortEvent(src, E, ref)
%sortEvent  The raster's sort event: its label and each epoch's latency to it (eventLatency).
if isempty(ref)
    error('EphysAnalysisRunner:NoSortEvent', ['The raster sorts by an event''s latency (rasterSort "event"), ' ...
        'but rasterSortEvent names no event.']);
end
[t, label] = eventLatency(src, E, ref);
S = struct('label', label, 't', t);
end


function tf = drawsWaveforms(spec)
%drawsWaveforms  The plot draws each unit's waveform: a raster, or a PSTH or tuning grid, of spikes, with waveform.mode on; a waveforms plot.
tf = ismember(spec.source, EphysAnalysisConfig.SpikeSources) && (spec.kind == "waveforms" || ...
    (spec.waveform.mode ~= "off" && (spec.kind == "raster" || (ismember(spec.kind, ["psth" "tuning"]) && spec.layout ~= "overlay"))));
end
