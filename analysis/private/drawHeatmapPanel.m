function hk = drawHeatmapPanel(ax, P, look)
%drawHeatmapPanel  Draw a figure's heat map panel: one layer's units or channels by time, for one trial group.
%   HK = drawHeatmapPanel(AX, P, LOOK) draws the panel result P
%   (F.panels(k) of EphysAnalysisRunner.computeFigure) into the axes AX,
%   as renderFigure asks (LOOK: style, colors, W, spec, panel, panelId,
%   isTop, isBottom, epochs, groups, observation, isTime). Its map layer,
%   the first computed layer that is not events marks (a spikePSTH or an
%   evokedPotential result: every group computed), is cut to the group
%   options.group (clipped to the groups there are; figSliceGroup) and
%   drawn by renderHeatmap into AX (Order = options.order, Style.CLim =
%   options.cLim): an image of the rows by time, titled with the group and
%   its epochs, with its color bar. A panel that shares the figure's time
%   axis with other time panels in its column keeps the color bar inside
%   the axes, at their right edge, so its time axis lines up with theirs.
%   The events
%   layers drawn as marks become latency lines of the drawn group and a
%   rug (figEventMarks, in the marks' colors). Skipped layers are noted
%   (figLayerNotes). HK: figDrawResult's (no legend entries but the marks';
%   renderHeatmap labels the axes).
%
%   See also renderFigure, renderHeatmap, figSliceGroup, figurePanelRegistry.

style = look.style;
o = look.panel.options;
hk = figDrawResult(ax);
j = find(arrayfun(@(l) l.skip == "" && isstruct(l.R) && (isfield(l.R, 'rate') || isfield(l.R, 'mean')) ...
    && isfield(l.R, 'kind') && l.R.kind ~= "events", P.layers), 1);
if isempty(j)
    tagPart(ax, "axes", "", look.panelId);
    figLayerNotes(ax, P, look, false);
    return
end
R = P.layers(j).R;
g = min(max(1, round(o.group)), height(R.groups));
st = style;
st.XLim = [];
st.YLim = [];
st.CLim = [];
if numel(o.cLim) == 2 && o.cLim(2) > o.cLim(1); st.CLim = o.cLim; end
h = renderHeatmap(figSliceGroup(R, g), ax, Order=o.order, Style=st);
ax = h.axes(1);
hk.axes = ax;
tagPart(ax, "axes", "", look.panelId);
if look.panel.sharesTime && inTimeColumn(look) && ~isempty(h.colorbar) && isgraphics(h.colorbar)
    h.colorbar.Location = 'east';   % beside the axes it would narrow them, out of line with the time panels above and below
end
if numel(look.W) == 2 && look.W(2) > look.W(1); xlim(ax, look.W); end
[hm, lm] = figEventMarks(ax, P, look, g, "mark");
for m = 1:numel(hm)
    hk.legendHandles(end+1) = hm(m);
    hk.legendLabels(end+1) = lm(m);
    hk.legendGroup(end+1) = false;
end
figLayerNotes(ax, P, look, true);
end


function tf = inTimeColumn(look)
%inTimeColumn  True when another time panel (raster, PSTH, continuous, heat map) shares a column with this one.
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
