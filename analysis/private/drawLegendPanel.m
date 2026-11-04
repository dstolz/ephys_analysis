function hk = drawLegendPanel(ax, P, look) %#ok<INUSD>
%drawLegendPanel  A figure's legend panel: its axes hidden, nothing drawn (renderFigure puts the figure's legend on them).
%   HK = drawLegendPanel(AX, P, LOOK) (figurePanelRegistry's draw for
%   "legend") hides the axes AX (Visible off, no clicks: Tag "legendHost",
%   so PlotAesthetics lists the legend as the figure's own and the panel as
%   no tile) and draws nothing on them: HK is figDrawResult(AX), with no
%   legend entries of its own. renderFigure then puts the figure's legend
%   on AX, laid out in the panel's box (figureLayout), or, in a preview,
%   a gray note saying why it holds none.
%
%   See also figurePanelRegistry, computeLegendPanel, renderFigure, figureLayout.

set(ax, 'Visible', 'off', 'XLim', [0 1], 'YLim', [0 1], 'HitTest', 'off', 'PickableParts', 'none', 'Tag', 'legendHost');
hk = figDrawResult(ax);
end
