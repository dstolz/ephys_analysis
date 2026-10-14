function hk = drawWaveformsPanel(ax, P, look)
%drawWaveformsPanel  Draw a figure's unit waveforms panel: the observed unit's waveform, or several units' means overlaid.
%   HK = drawWaveformsPanel(AX, P, LOOK) draws the panel result P
%   (F.panels(k) of EphysAnalysisRunner.computeFigure) into the axes AX,
%   as renderFigure asks (LOOK: style, colors, W, spec, panel, panelId,
%   isTop, isBottom, epochs, groups, observation, isTime). Its first
%   computed layer (R.kind "waveforms": meta, labels, waveforms from
%   unitWaveforms) holds
%     one unit     drawn by renderWaveforms into AX (grid layout, the
%                  panel's options.waveform: mean, spikes or both, the
%                  label; Style.YLim = options.yLim)
%     several      (a fixed layer of several units) every unit's mean
%                  overlaid in a color of its own (role "waveMean", group =
%                  the unit's label), the spike time marked, each unit in
%                  the legend
%   A skipped layer's reason is noted (figLayerNotes). HK: figDrawResult's
%   (renderWaveforms labels the axes; the overlay's y label is the
%   amplitude).
%
%   See also renderFigure, renderWaveforms, unitWaveforms, figurePanelRegistry.

style = look.style;
o = look.panel.options;
hk = figDrawResult(ax);
j = find(arrayfun(@(l) l.skip == "" && isstruct(l.R) && isfield(l.R, 'kind') && l.R.kind == "waveforms", P.layers), 1);
if isempty(j)
    tagPart(ax, "axes", "", look.panelId);
    figLayerNotes(ax, P, look, false);
    return
end
R = P.layers(j).R;
W = R.waveforms;
nU = height(R.meta);
st = style;
st.XLim = [];
st.YLim = [];
if numel(o.yLim) == 2 && o.yLim(2) > o.yLim(1); st.YLim = o.yLim; end
if nU == 1
    h = renderWaveforms(R, ax, Layout="grid", Waveform=o.waveform, Style=st);
    hk.axes = h.axes(1);
    tagPart(hk.axes, "axes", "", look.panelId);
    figLayerNotes(hk.axes, P, look, true);
    return
end

tagPart(ax, "axes", "", look.panelId);
names = shortUnitLabels(R.labels);
order = probeOrder(R.meta, nU, style);
G = table((1:nU).', names(:), lines(nU), ones(nU, 1), 'VariableNames', {'index', 'label', 'color', 'n'});
C = groupPalette(G, style);
hold(ax, 'on');
drew = false;
for u = reshape(order, 1, [])
    if u > numel(W.mean) || isempty(W.mean{u}); continue; end
    hk.legendHandles(end+1) = tagPart(line(ax, W.timeMs{u}(:), W.mean{u}(:), 'Color', C(u, :), ...
        'LineWidth', max(1, style.LineWidth)), "waveMean", names(u));
    hk.legendLabels(end+1) = names(u);
    hk.legendGroup(end+1) = false;
    drew = true;
end
if drew
    tagPart(xline(ax, 0, ':', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off'), "waveZero");
end
hold(ax, 'off');
if ~drew
    figLayerNotes(ax, P, look, false, "No waveform for these units");
    return
end
axis(ax, 'tight');
styleAxes(ax, st);
xlabel(ax, 'Time (ms)');
u = unique(W.units(W.units ~= ""));
hk.yName = "Amplitude";
if isscalar(u); hk.yName = "Amplitude (" + ampText(u) + ")"; end
figLayerNotes(ax, P, look, true);
end


function s = ampText(units)
%ampText  The amplitude unit of a waveform (unitWaveforms' units).
switch units
    case "uV";       s = char(181) + "V";
    case "bin";      s = ".bin units";
    case "whitened"; s = "whitened";
    otherwise;       s = "a.u.";
end
end
