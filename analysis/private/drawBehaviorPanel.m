function hk = drawBehaviorPanel(ax, P, look)
%drawBehaviorPanel  Draw a figure's behavior panel: a per-epoch value against a trial parameter.
%   HK = drawBehaviorPanel(AX, P, LOOK) draws the panel result P
%   (F.panels(k) of EphysAnalysisRunner.computeFigure) into the axes AX,
%   as renderFigure asks (LOOK: style, colors, W, spec, panel, panelId,
%   isTop, isBottom, epochs, groups, observation, isTime). Its first
%   computed layer (a behaviorValues result) is drawn by renderBehavior
%   into AX with the panel's options: Layout = display (points, line, box,
%   swarm, violin), Jitter, XScale and Style.YLim = yLim. Its series
%   (several: a seriesParam) are offered to the figure's one legend
%   (HK.legendHandles / legendLabels) instead of a legend of the panel's
%   own. The violin display without violinplot
%   (MATLAB before R2024b), or a skipped layer, is noted in the panel
%   (figLayerNotes). HK: figDrawResult's (renderBehavior labels the axes).
%
%   See also renderFigure, renderBehavior, behaviorValues, figurePanelRegistry.

style = look.style;
o = look.panel.options;
hk = figDrawResult(ax);
j = find(arrayfun(@(l) l.skip == "" && isstruct(l.R) && isfield(l.R, 'kind') && l.R.kind == "behavior", P.layers), 1);
if isempty(j)
    tagPart(ax, "axes", "", look.panelId);
    figLayerNotes(ax, P, look, false);
    return
end
st = style;
st.XLim = [];
st.YLim = [];
if numel(o.yLim) == 2 && o.yLim(2) > o.yLim(1); st.YLim = o.yLim; end
try
    h = renderBehavior(P.layers(j).R, ax, Layout=o.display, Jitter=logical(o.jitter), XScale=o.xScale, Style=st);
catch ME
    if ME.identifier ~= "renderBehavior:NoViolin"; rethrow(ME); end
    tagPart(ax, "axes", "", look.panelId);
    figLayerNotes(ax, P, look, false, ME.message);
    return
end
hk.axes = h.axes(1);
tagPart(hk.axes, "axes", "", look.panelId);
lgd = hk.axes.Legend;
if ~isempty(lgd) && isvalid(lgd)   % the series join the figure's one legend
    hk.legendHandles = reshape(lgd.PlotChildren, 1, []);
    hk.legendLabels = reshape(string(lgd.String), 1, []);
    hk.legendGroup = false(1, numel(hk.legendLabels));
    delete(lgd);
end
figLayerNotes(hk.axes, P, look, true);
end
