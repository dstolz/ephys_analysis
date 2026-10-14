function hk = drawCorrMapPanel(ax, P, look)
%drawCorrMapPanel  Draw a figure's unit correlation panel: one layer's pairwise correlations, for one trial group.
%   HK = drawCorrMapPanel(AX, P, LOOK) draws the panel result P
%   (F.panels(k) of EphysAnalysisRunner.computeFigure) into the axes AX,
%   as renderFigure asks (LOOK: style, colors, W, spec, panel, panelId,
%   isTop, isBottom, epochs, groups, observation, isTime). Its first
%   computed layer (a unitCorrelation result: every group computed) is cut
%   to the group options.group (clipped to the groups there are;
%   figSliceGroup) and drawn by renderCorrMap into AX (Style.CLim =
%   options.cLim): the units by units image, titled with the group, its
%   epochs and the mean r, with its color bar. A skipped layer's reason is
%   noted (figLayerNotes). HK: figDrawResult's (renderCorrMap labels the
%   axes).
%
%   See also renderFigure, renderCorrMap, figSliceGroup, figurePanelRegistry.

style = look.style;
o = look.panel.options;
hk = figDrawResult(ax);
j = find(arrayfun(@(l) l.skip == "" && isstruct(l.R) && isfield(l.R, 'kind') && l.R.kind == "corrmap", P.layers), 1);
if isempty(j)
    tagPart(ax, "axes", "", look.panelId);
    figLayerNotes(ax, P, look, false);
    return
end
R = P.layers(j).R;
st = style;
st.XLim = [];
st.YLim = [];
st.CLim = [];
if numel(o.cLim) == 2 && o.cLim(2) > o.cLim(1); st.CLim = o.cLim; end
h = renderCorrMap(figSliceGroup(R, o.group), ax, Style=st);
hk.axes = h.axes(1);
tagPart(hk.axes, "axes", "", look.panelId);
figLayerNotes(hk.axes, P, look, true);
end
