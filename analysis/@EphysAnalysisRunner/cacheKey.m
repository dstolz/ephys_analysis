function key = cacheKey(datasetKey, spec)
%cacheKey  The ResultCache key of one plot's result on one dataset.
%   KEY = EphysAnalysisRunner.cacheKey(DATASETKEY, SPEC) is DATASETKEY +
%   "|" + jsonencode(core), core being SPEC without what only changes how a
%   result is drawn -- id, title, enabled, style, aesthetics,
%   sessionAesthetics, note, overlays, histStyle, fill, fillAlpha,
%   normalize, stack, stackSpacing, rasterSortOrder, rasterByGroup, jitter,
%   xScale, value, order, layout -- with rasterEvents cut to what is
%   computed (lines, sequences, edge, scope), waveform to its maxSpikes, and
%   what those fields decide for the compute added back: the error the
%   compute makes (plotErrorType: type and resamples) and whether unit
%   waveforms are read. So a per-dataset plot and a session plot that
%   differ only in their looks share one result, and a session plot whose
%   trial groups are pooled (groupBy cleared) does not. (jsonencode writes
%   Inf as null; no field the cache keys on holds NaN.)
%
%   See also EphysAnalysisRunner.cachedPlot, EphysAnalysisRunner.computePlot.

arguments
    datasetKey (1,1) string
    spec (1,1) struct
end

[et, nb] = plotErrorType(spec);
waves = ismember(spec.source, EphysAnalysisConfig.SpikeSources) && (spec.kind == "waveforms" || ...
    (spec.waveform.mode ~= "off" && (spec.kind == "raster" || (ismember(spec.kind, ["psth" "tuning"]) && spec.layout ~= "overlay"))));
drop = ["id" "title" "enabled" "style" "aesthetics" "sessionAesthetics" "note" "overlays" "histStyle" "fill" "fillAlpha" ...
    "normalize" "stack" "stackSpacing" "rasterSortOrder" "rasterByGroup" "jitter" "xScale" "value" "order" "layout"];
core = rmfield(spec, intersect(drop, string(fieldnames(spec))));
if isfield(core, 'rasterEvents') && isstruct(core.rasterEvents)
    m = core.rasterEvents;
    core.rasterEvents = struct('lines', m.lines, 'sequences', m.sequences, 'edge', m.edge, 'scope', m.scope);
end
if isfield(core, 'waveform') && isstruct(core.waveform)
    core.waveform = struct('maxSpikes', core.waveform.maxSpikes);
end
core.errorType = et;
core.errorResamples = nb;
core.readsWaveforms = waves;
key =datasetKey + "|" + string(jsonencode(core));
end
