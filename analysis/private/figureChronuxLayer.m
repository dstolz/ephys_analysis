function [X, lay] = figureChronuxLayer(src, L, lay, ctx)
%figureChronuxLayer  One layer of a spectral figure panel read for the Chronux analyses: a signal's columns or spike trains.
%   [X, LAY] = figureChronuxLayer(SRC, L, LAY, CTX) resolves the layer L
%   (figureFor's spec) of a spectrum, spectrogram or coherence panel for
%   CTX.observation (figureLayerItems) and reads it, filling LAY
%   (figurePanelLayers' entry: meta, name "" = automatic, skip):
%     LFP / MUA / SPIKE / AUX   selectChannels (the extract as cached), the
%         layer's columns copied: X.kind "signal", X.D (chronuxBlockOf: the
%         whole recording of those columns, D.channels = 1:n), X.cols (the
%         extract's columns), X.nRows, X.names ("LFP ch 12": the recording
%         channel, else the column's label)
%     units / detected   selectUnits(src, units, Ref=CTX.ref,
%         Selection=CTX.selection): X.kind "spikes", X.SP (chronuxTrainsOf,
%         SP.index = 1:n), X.unitIds, X.names (shortUnitLabels), X.lastSpike
%   Data the dataset lacks skips the layer with the reason (figureLayerError;
%   X.kind "" then); EphysAnalysisRunner:Canceled passes through.
%
%   See also computeSpectrumPanel, computeSpectrogramPanel, computeCoherencePanel,
%   figureLayerItems, chronuxBlockOf, chronuxTrainsOf.
X = struct('kind', "", 'D', [], 'SP', [], 'cols', zeros(1, 0), 'unitIds', zeros(1, 0), 'nRows', NaN, ...
    'names', strings(1, 0), 'lastSpike', NaN, 'source', L.source);
ctx.checkpoint();
if ismember(L.source, EphysAnalysisConfig.SignalSources)
    try
        [Y, fs, metaAll] = selectChannels(src, L.source, Channels=[]);   % every column, the cached signal itself
    catch ME
        lay.skip = figureLayerError(ME);
        return
    end
    it = figureLayerItems(L, ctx.observation, ctx.observe, metaAll);
    if it.skip ~= ""; lay.skip = it.skip; return; end
    nCh = height(metaAll);
    cols = reshape(double(it.columns), 1, []);
    if isempty(cols); cols = 1:nCh; end
    if any(cols < 1 | cols > nCh | cols ~= round(cols))
        lay.skip = sprintf("the %s extract has %d channel(s); the layer asks for %s", L.source, nCh, mat2str(cols));
        return
    end
    metaC = metaAll(cols, :);
    names = strings(1, numel(cols));
    for i = 1:numel(cols)
        rc = NaN;
        if ismember("recordingChannel", string(metaC.Properties.VariableNames)); rc = metaC.recordingChannel(i); end
        if isfinite(rc)
            names(i) = L.source + " ch " + rc;
        else
            names(i) = L.source + " " + string(metaC.label(i));
        end
    end
    X.kind = "signal";
    X.D = chronuxBlockOf(Y(:, cols), fs, metaC, L.source, names);
    X.cols = cols;
    X.nRows = size(Y, 1);
    X.names = names;
    lay.meta = metaC;
    if lay.name == ""
        if isscalar(cols)
            lay.name = names(1);
        else
            lay.name = L.source + " (" + numel(cols) + " channels)";
        end
    end
    return
end
it = figureLayerItems(L, ctx.observation, ctx.observe, []);
if it.skip ~= ""; lay.skip = it.skip; return; end
try
    [st, meta] = selectUnits(src, it.units, Ref=ctx.ref, Selection=ctx.selection);
catch ME
    lay.skip = figureLayerError(ME);
    return
end
names = reshape(shortUnitLabels(meta.label), 1, []);
X.kind = "spikes";
X.SP = chronuxTrainsOf(st, meta, L.source, names);
X.unitIds = reshape(double(meta.unitId), 1, []);
X.names = names;
last = 0;
for u = 1:numel(st)
    if ~isempty(st{u}); last = max(last, max(st{u})); end
end
X.lastSpike = last;
lay.meta = meta;
if lay.name == ""; lay.name = figureUnitsName(meta, L); end
end
