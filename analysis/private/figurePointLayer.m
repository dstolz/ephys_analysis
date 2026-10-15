function lay = figurePointLayer(src, L, lay, E, G, ctx, opts)
%figurePointLayer  One point-process layer of a raster, PSTH or heat map panel: units, detections or a line's events.
%   LAY = figurePointLayer(SRC, L, LAY, E, G, CTX, Name=Value) computes the
%   layer L (figureFor's spec) of a panel over its epochs E and groups G
%   (epochTable) for the dataset SRC and fills LAY (figurePanelLayers'
%   entry for it): R, meta, name ("" = automatic) and skip.
%     units / detected   figureLayerItems resolves the binding for
%         CTX.observation; selectUnits(src, units, Ref=CTX.ref,
%         Selection=CTX.selection); spikePSTH over E (one unit when the
%         layer follows a unit). aggregate "mean" adds R.layerMean
%         (figureLayerMean: the mean over the units, a band across them);
%         Waveform.mode other than "off" adds R.waveforms (unitWaveforms of
%         the layer's units)
%     events, marks      R = struct(kind "events", marks = epochEvents(src,
%         E, Sequences=eventMarkRef(L.event)), label, look = L.event)
%     events, train      the line's events as a spike train: resolveEvents
%         (eventMarkRef(L.event), every paired trial or the recording),
%         moved to the continuous clock exactly as epochTable makes
%         t0Continuous, with a one-row meta (selectUnits' columns; label =
%         eventRefLabel, class "event"), then spikePSTH: an ordinary
%         one-unit PSTH result (raster rows, rate)
%   Each spikePSTH result also gets epochs (E), dataset and, from Name=Value,
%   nothing else: a raster panel adds its sort event itself.
%   Data the dataset lacks (no unit left, no such event) skips the layer
%   with the reason (figureLayerError); EphysAnalysisRunner:Canceled
%   passes through.
%
%   Options (spikePSTH's): Window [pre post], BinSec, SmoothSec, Measure,
%   Baseline, BaselineMode, MaskAfterStop, Raster, Auroc (BaselineMode
%   "auroc": the panel's options.auroc; R.auroc then holds the calls);
%   Waveform (the panel's options.waveform, [] = none).
%
%   See also EphysAnalysisRunner.computeFigure, figureLayerItems, spikePSTH, epochEvents.

arguments
    src (1,1) struct
    L (1,1) struct
    lay (1,1) struct
    E table
    G table
    ctx (1,1) struct
    opts.Window (1,2) double
    opts.BinSec (1,1) double = 0.01
    opts.SmoothSec (1,1) double = 0
    opts.Measure (1,1) string = "rate"
    opts.Baseline double = []
    opts.BaselineMode (1,1) string = "none"
    opts.MaskAfterStop (1,1) logical = false
    opts.Raster (1,1) logical = true
    opts.Waveform = []
    opts.Auroc = struct()
end

ctx.checkpoint();
if L.source == "events"
    ref = eventMarkRef(L.event);
    label = eventRefLabel(ref);
    if lay.name == ""; lay.name = label; end
    try
        if L.eventsAs == "train"
            [st, meta] = eventTrain(src, ref, label);
            lay.R = psthOf(src, st, meta, E, G, ctx, opts);
            lay.meta = meta;
        else
            M = epochEvents(src, E, Sequences=ref);
            lay.R = struct('kind', "events", 'marks', M, 'label', label, 'look', L.event);
        end
    catch ME
        lay.skip = figureLayerError(ME);
    end
    return
end

it = figureLayerItems(L, ctx.observation, ctx.observe, []);
if it.skip ~= ""; lay.skip = it.skip; return; end
try
    [st, meta] = selectUnits(src, it.units, Ref=ctx.ref, Selection=ctx.selection);
    lay.R = psthOf(src, st, meta, E, G, ctx, opts);
catch ME
    lay.skip = figureLayerError(ME);
    return
end
lay.meta = meta;
if lay.name == ""; lay.name = figureUnitsName(meta, L); end
if L.aggregate == "mean"
    lay.R.layerMean = figureLayerMean(lay.R.rate, lay.R.t, ctx.errorType, ctx.nBoot, "units");
end
wf = opts.Waveform;
if isstruct(wf) && wf.mode ~= "off"
    ctx.checkpoint();
    lay.R.waveforms = unitWaveforms(src, meta, Source=L.source, MaxSpikes=wf.maxSpikes, Check=ctx.check);
end
end


function R = psthOf(src, st, meta, E, G, ctx, opts)
%psthOf  spikePSTH of the layer's trains over the panel's epochs, with the epochs and the dataset.
R = spikePSTH(st, E, Window=opts.Window, BinSec=opts.BinSec, SmoothSec=opts.SmoothSec, Measure=opts.Measure, ...
    Baseline=opts.Baseline, BaselineMode=opts.BaselineMode, MaskAfterStop=opts.MaskAfterStop, Raster=opts.Raster, ...
    Groups=G, Meta=meta, Auroc=opts.Auroc, Check=ctx.check, ErrorType=ctx.errorType, ErrorResamples=ctx.nBoot);
R.epochs = E;
R.dataset = src.name;
end


function [st, meta] = eventTrain(src, ref, label)
%eventTrain  A line's events as a one-unit spike train on the continuous clock (epochTable's t0Continuous rule).
[t, ~, ~, shift] = resolveEvents(src, ref, []);
off = ref.offsetSec + shift;
t = sort((round((t - off) * src.fs) - 1) / src.fs + off);   % row r at r/Fs happened at (r-1)/Fs
st = {t(:)};
meta = table(label, NaN, "event", NaN, "", NaN, NaN, NaN, numel(t), ...
    'VariableNames', {'label', 'unitId', 'class', 'channel', 'channelName', 'shank', 'x', 'y', 'nSpikes'});
end