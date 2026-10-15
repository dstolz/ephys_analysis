function P = computeWaveformsPanel(src, panel, E, G, ctx) %#ok<INUSL>
%computeWaveformsPanel  A figure's unit waveforms panel: the layer's units' mean waveforms and spikes.
%   P = computeWaveformsPanel(SRC, PANEL, E, G, CTX) (figurePanelRegistry's
%   compute for "waveforms"; not aligned, so E and G are unused) has
%   P.layers, one per layer of PANEL (figurePanelLayers). Its first enabled
%   layer (units / detected; the observed unit when it follows the
%   observation) gets, as computePlot's waveforms plot,
%     R = struct(kind "waveforms", meta, labels, n, groups (one "all"
%         row), probe, dataset)
%     R.waveforms = unitWaveforms(src, meta, Source=, MaxSpikes=
%         options.waveform.maxSpikes, Check=)
%   (timeMs, mean, spikes, from, units, total, note, maxSpikes per unit).
%   In the probe layout (options.layout "probe") every further enabled
%   layer is resolved too, without reading waveforms: R = struct(kind
%   "ring", meta, source), the units the draw function rings on the probe
%   (e.g. a layer following the observed unit); in the grid layout they
%   are skipped ("A waveforms panel draws its first enabled layer only").
%
%   See also figurePanelRegistry, unitWaveforms, renderWaveforms.

o = panel.options;
P = struct('layers', figurePanelLayers(panel, ctx.skips));
[ctx.errorType, ctx.nBoot] = figureErrorType(ctx.spec, panel);   % the band this panel draws ("sem" where none)
probe = isfield(o, 'layout') && o.layout == "probe";
if probe   % every enabled layer: the first is drawn, the others ringed
    on = find(arrayfun(@(l) l.skip ~= "disabled", P.layers));
    j = 0;
    if ~isempty(on); j = on(1); end
    for i = on(2:end)
        if P.layers(i).skip ~= ""; continue; end
        P.layers(i) = ringLayer(src, panel.layers(i), P.layers(i), ctx);
    end
else
    [j, P.layers] = figureFirstLayer(P.layers, "A waveforms panel");
end
if j == 0 || P.layers(j).skip ~= ""; return; end
L = panel.layers(j);
lay = P.layers(j);
it = figureLayerItems(L, ctx.observation, ctx.observe, []);
if it.skip ~= ""
    P.layers(j).skip = it.skip;
    return
end
ctx.checkpoint();
try
    [~, meta] = selectUnits(src, it.units, Ref=ctx.ref, Selection=ctx.selection);
catch ME
    P.layers(j).skip = figureLayerError(ME);
    return
end
G1 = table(1, "all", [0.15 0.15 0.15], height(meta), 'VariableNames', {'index', 'label', 'color', 'n'});
R = struct('kind', "waveforms", 'meta', meta, 'labels', meta.label, 'n', height(meta), 'groups', G1, 'probe', []);
R.probe = src.probe;
ctx.checkpoint();
R.waveforms = unitWaveforms(src, meta, Source=L.source, MaxSpikes=o.waveform.maxSpikes, Check=ctx.check);
R.dataset = src.name;
lay.R = R;
lay.meta = meta;
if lay.name == ""
    if height(meta) == 1
        lay.name = shortUnitLabels(meta.label);
    else
        lay.name = height(meta) + " " + L.source;
    end
end
P.layers(j) = lay;
end


function lay = ringLayer(src, L, lay, ctx)
%ringLayer  A further layer of a probe layout: only which units it names (rung on the probe), no waveforms read.
it = figureLayerItems(L, ctx.observation, ctx.observe, []);
if it.skip ~= ""; lay.skip = it.skip; return; end
ctx.checkpoint();
try
    [~, meta] = selectUnits(src, it.units, Ref=ctx.ref, Selection=ctx.selection);
catch ME
    lay.skip = figureLayerError(ME);
    return
end
lay.R = struct('kind', "ring", 'meta', meta, 'source', L.source);
lay.meta = meta;
if lay.name == ""; lay.name = figureUnitsName(meta, L); end
end
