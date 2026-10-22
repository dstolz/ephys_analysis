function P = computeHeatmapPanel(src, panel, E, G, ctx)
%computeHeatmapPanel  A figure's heat map panel: one layer's units or channels by time.
%   P = computeHeatmapPanel(SRC, PANEL, E, G, CTX) (figurePanelRegistry's
%   compute for "heatmap"; CTX from EphysAnalysisRunner.computeFigure) has
%   P.layers, one per layer of PANEL (figurePanelLayers). The first enabled
%   layer that is not events marks is the map:
%     units / detected / events train   figurePointLayer: spikePSTH with the
%         panel's bins, measure, baseline and maskAfterStop (no raster):
%         R.rate [nBins x nUnits x nGroups]; baseline Mode "auroc" (with
%         options.auroc) gives auROC curves and their calls (R.auroc)
%     LFP / MUA / SPIKE / AUX           figureSignalLayer: evokedPotential
%         with the baseline subtracted (Mode other than "none"): R.mean
%         [nTime x nChannels x nGroups]
%   With options.rows "trials" a spike (or train) map layer keeps its
%   raster (Raster=true) and its first unit's epochs become the rows:
%   R.trialMatrix [nEpochs x nBins], R.trialOrder (top row first, sorted
%   as a raster by rasterSort / rasterSortOrder / rasterByGroup; "event"
%   by eventLatency of rasterSortEvent, "latency" by the unit's first-spike
%   latency), R.trialGroup and R.trialRowsName
%   (figTrialMatrix: binned from the unit's train, kept for it by
%   KeepTrains and dropped after); a layer that keeps several units (e.g.
%   one following the observation through its channel) or an auROC
%   baseline skips the layer.
%   Every group is computed; options.group picks the one drawn (rows
%   "items"), and options.order / cLim are the draw function's. Events marks layers are
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
trials = isfield(o, 'rows') && o.rows == "trials";   % one unit's epochs as the rows
mapped = false;
for j = 1:numel(P.layers)
    if P.layers(j).skip == "disabled"; continue; end
    L = panel.layers(j);
    isMarks = L.source == "events" && L.eventsAs ~= "train";   % marks or spans: lines over the map
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
    elseif isMarks
        P.layers(j) = figurePointLayer(src, L, P.layers(j), E, G, ctx, Window=[w.pre w.post], Raster=false);
    else
        P.layers(j) = figurePointLayer(src, L, P.layers(j), E, G, ctx, Window=[w.pre w.post], ...
            BinSec=o.bins.BinSec, SmoothSec=o.bins.SmoothSec, Measure=o.measure, Baseline=b, ...
            BaselineMode=o.baseline.Mode, MaskAfterStop=o.maskAfterStop, Raster=trials, Auroc=o.auroc, KeepTrains=trials);
        if trials && P.layers(j).skip == ""
            P.layers(j) = trialRows(src, P.layers(j), E, o, ctx);
        end
    end
end
end


function lay = trialRows(src, lay, E, o, ctx)
%trialRows  A heat map of trials: the layer's first unit's epochs by time (figTrialMatrix), sorted as a raster.
R = lay.R;
if ~isstruct(R) || ~isfield(R, 'raster') || isempty(R.raster); return; end
if numel(R.raster) > 1   % e.g. every unit on an observed channel: a heat map of trials is one unit's
    lay.skip = "A heat map of trials draws one unit: this layer keeps " + numel(R.raster);
    lay.R = [];
    return
end
if R.params.BaselineMode == "auroc"
    lay.skip = "A heat map of trials takes no auROC baseline";
    lay.R = [];
    return
end
if o.rasterSort == "event" && ~isempty(o.rasterSortEvent)
    ctx.checkpoint();
    try
        [t, label] = eventLatency(src, E, o.rasterSortEvent);
        R.rasterSortEvent = struct('label', label, 't', t);
    catch ME
        lay.skip = figureLayerError(ME);
        lay.R = [];
        return
    end
end
[R.trialMatrix, R.trialOrder, R.trialGroup, R.trialRowsName] = figTrialMatrix(R, o);
if isfield(R, 'trains'); R = rmfield(R, 'trains'); end   % binned: not kept in the result
lay.R = R;
end
