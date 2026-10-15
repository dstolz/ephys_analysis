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
%   A heat map of trials (options.rows "trials": R.trialMatrix, computed
%   by computeHeatmapPanel) draws one unit's epochs instead, every group:
%   a row per epoch in R.trialOrder (an image in the design's heat
%   colormap, Style.HeatColormap, options.cLim), each epoch's group as a
%   thin strip of its color along the left edge (role "rasterBand", the
%   groups offered to the legend), the zero line, a color bar in the
%   measure's unit, the unit's name and epoch count as its title, the
%   marks' latency lines; y label the rows' sort (R.trialRowsName);
%   options.group is not used.
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
if isfield(R, 'trialMatrix')
    hk = drawTrials(ax, P, look, j, hk);
    return
end
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


function hk = drawTrials(ax, P, look, j, hk)
%drawTrials  A heat map of one unit's epochs: a row per epoch in the raster's order, the groups as a color strip at the left.
style = look.style;
o = look.panel.options;
R = P.layers(j).R;
M = R.trialMatrix(R.trialOrder, :);
grp = R.trialGroup(R.trialOrder);
nE = size(M, 1);
nG = height(R.groups);
colors = look.colors;
if size(colors, 1) ~= nG; colors = groupPalette(R.groups, style); end
W = look.W;
if numel(W) ~= 2; W = R.edges([1 end]); end
W = double(reshape(W, 1, 2));
if style.HeatColormap == ""
    cmap = designColormap(style, "heat", "parula");
else
    cmap = feval(char(style.HeatColormap), 256);
end
tagPart(imagesc(ax, R.t(:).', 1:nE, M, 'AlphaData', double(isfinite(M))), "image", P.layers(j).name);
tagPart(ax, "axes", "", look.panelId);   % after imagesc, which resets a replaced axes' properties
set(ax, 'YDir', 'reverse');
colormap(ax, cmap);
v = M(isfinite(M));
cl = [0 1];
if ~isempty(v); cl = [min(v) max(v)]; end
if cl(2) <= cl(1); cl = cl + [-0.5 0.5]; end
if numel(o.cLim) == 2 && o.cLim(2) > o.cLim(1); cl = o.cLim; end
clim(ax, cl);
hold(ax, 'on');
if nG > 1   % each epoch's group: a thin strip of its color along the left edge
    w = 0.025 * diff(W);
    for k = 1:nG
        rows = reshape(find(grp == k), 1, []);
        if isempty(rows); continue; end
        X = repmat([W(1); W(1) + w; W(1) + w; W(1)], 1, numel(rows));
        Y = [rows - 0.5; rows - 0.5; rows + 0.5; rows + 0.5];
        tagPart(patch(ax, X, Y, colors(k, :), 'EdgeColor', 'none', 'HandleVisibility', 'off'), "rasterBand", R.groups.label(k));
        hk.legendHandles(end+1) = tagPart(patch(ax, 'XData', NaN, 'YData', NaN, 'FaceColor', colors(k, :), 'EdgeColor', 'none'), ...
            "rasterBand", R.groups.label(k));
        hk.legendLabels(end+1) = string(R.groups.label(k));
        hk.legendGroup(end+1) = true;
    end
end
if style.ShowZeroLine; tagPart(xline(ax, 0, '--', 'Color', [1 1 1], 'LineWidth', 1, 'HandleVisibility', 'off'), "zeroLine"); end
hold(ax, 'off');
st = style;
st.XLim = [];
st.YLim = [];
st.CLim = [];
styleAxes(ax, st);
grid(ax, 'off');
xlim(ax, W);
ylim(ax, [0.5 max(1, nE) + 0.5]);
cb = colorbar(ax);
cb.Label.String = R.units;
if look.panel.sharesTime && inTimeColumn(look)
    cb.Location = 'east';   % beside the axes it would narrow them, out of line with the time panels above and below
end
title(ax, sprintf('%s (%d epochs)', P.layers(j).name, nE), 'FontWeight', 'normal', 'Interpreter', 'none');
[hm, lm] = figEventMarks(ax, P, look, 1:max(1, nG), "mark");
for m = 1:numel(hm)
    hk.legendHandles(end+1) = hm(m);
    hk.legendLabels(end+1) = lm(m);
    hk.legendGroup(end+1) = false;
end
figLayerNotes(ax, P, look, true);
hk.yName = R.trialRowsName;
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
