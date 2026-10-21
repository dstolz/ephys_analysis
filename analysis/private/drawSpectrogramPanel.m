function hk = drawSpectrogramPanel(ax, P, look)
%drawSpectrogramPanel  Draw a figure's spectrogram panel: one channel's or unit's power over time and frequency, one trial group.
%   HK = drawSpectrogramPanel(AX, P, LOOK) draws the panel result P
%   (F.panels(k) of EphysAnalysisRunner.computeFigure) into the axes AX,
%   as renderFigure asks (LOOK: style, colors, W, spec, panel, panelId,
%   isTop, isBottom, epochs, groups, observation, isTime). Its map layer
%   (chronuxSpecgram or chronuxSpikeSpecgram: computeSpectrogramPanel) is drawn for the trial group
%   options.group (clipped to the groups there are) as an image over time
%   from the event (x, the panel's window) and frequency (y), role "image",
%   as renderChronux draws a spectrogram: the power in dB (options.scale
%   "db" or "log") or as is ("linear") in the design's heat colormap; a
%   baseline-normalized one (baseline Mode db, percent, zscore: signed;
%   ratio as log2) in its units on the diverging colormap centered on no
%   change. Color limits options.cLim, else the 1st to 99th percentile
%   (chronuxAutoLimits; symmetric when signed). Style.ShowZeroLine draws
%   the event's line; a color bar (role "colorbar") names the units,
%   inside the axes at their right edge when another time panel shares the
%   column (so the time axes line up, as a heat map's). With several groups
%   the title names the group and its epochs. The events layers drawn as
%   marks become latency lines of the group and a rug (figEventMarks).
%   Skipped layers are noted (figLayerNotes). HK.yName "Frequency (Hz)".
%
%   See also renderFigure, renderChronux, computeSpectrogramPanel, figurePanelRegistry.
style = look.style;
o = look.panel.options;
hk = figDrawResult(ax);
j = find(arrayfun(@(l) l.skip == "" && isstruct(l.R) && isfield(l.R, 'kind') ...
    && ismember(l.R.kind, ["chronuxSpecgram" "chronuxSpikeSpecgram"]), P.layers), 1);
if isempty(j)
    tagPart(ax, "axes", "", look.panelId);
    figLayerNotes(ax, P, look, false);
    return
end
R = P.layers(j).R;
nG = size(R.S, 4);
g = min(max(1, round(o.group)), nG);
normalized = R.baseline.mode ~= "none";
if normalized
    Z = R.S(:, :, 1, g);
    units = R.baseline.units;
    signed = R.baseline.mode ~= "ratio";
    if R.baseline.mode == "ratio"; Z = log2(Z); units = "log2 ratio"; signed = true; end
elseif o.scale == "linear"
    Z = R.S(:, :, 1, g);
    units = R.units;
    signed = false;
else
    Z = 10 * log10(R.S(:, :, 1, g));
    units = "dB re 1 " + R.units;
    signed = false;
end
if signed
    cmap = designColormap(style, "diverging", "blueWhiteRed");
else
    cmap = designColormap(style, "heat", "parula");
end
x = Z.';
name = P.layers(j).name;
tagPart(imagesc(ax, R.t, R.f, x, 'AlphaData', double(isfinite(x))), "image", name);
tagPart(ax, "axes", "", look.panelId);   % after imagesc, which resets a replaced axes' properties
set(ax, 'YDir', 'normal', 'Layer', 'top');
colormap(ax, cmap);
cl = o.cLim;
if ~(numel(cl) == 2 && cl(2) > cl(1))
    v = x(isfinite(x));
    cl = chronuxAutoLimits(v, signed);
end
clim(ax, cl);
if style.ShowZeroLine
    hold(ax, 'on');
    tagPart(xline(ax, 0, ':', 'Color', [0.2 0.2 0.2], 'LineWidth', 1, 'HandleVisibility', 'off'), "zeroLine");
    hold(ax, 'off');
end
st = style;
st.XLim = [];
st.YLim = [];
st.CLim = [];
styleAxes(ax, st);
grid(ax, 'off');
W = look.W;
if numel(W) == 2 && W(2) > W(1)
    xlim(ax, W);
elseif numel(R.t) > 1
    xlim(ax, double(R.t([1 end]).'));
end
if numel(R.f) > 1; ylim(ax, double(R.f([1 end]).')); end
cb = tagPart(colorbar(ax), "colorbar");
cb.Label.String = units;
if look.panel.sharesTime && inTimeColumn(look)
    cb.Location = 'east';   % beside the axes it would narrow them, out of line with the time panels above and below
end
if nG > 1
    title(ax, sprintf('%s (n = %d)', string(R.groups.label(g)), R.nTrials(1, g)), 'FontWeight', 'normal', 'Interpreter', 'none');
end
[hm, lm] = figEventMarks(ax, P, look, g, "mark");
for m = 1:numel(hm)
    hk.legendHandles(end+1) = hm(m);
    hk.legendLabels(end+1) = lm(m);
    hk.legendGroup(end+1) = false;
end
figLayerNotes(ax, P, look, true);
hk.yName = "Frequency (Hz)";
end


function tf = inTimeColumn(look)
%inTimeColumn  True when another time panel shares a column with this one (drawHeatmapPanel's rule).
PT = EphysAnalysisConfig.panelTypes();
p = look.panel;
tf = false;
for q = reshape(look.spec.panels, 1, [])
    row = PT.Type == q.type;
    if q.id == p.id || ~any(row) || ~PT.SharesTime(row); continue; end
    if q.col <= p.col + p.colSpan - 1 && p.col <= q.col + q.colSpan - 1
        tf = true;
        return
    end
end
end
