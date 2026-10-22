function hk = figDrawResult(ax)
%figDrawResult  What a figure panel's draw function returns, before it draws.
%   HK = figDrawResult(AX) is struct('axes', AX, 'legendHandles', [],
%   'legendLabels', [], 'legendGroup', [], 'yName', "", 'extraAxes', []):
%   the panel's axes,
%   the objects it offers renderFigure's one legend with their labels and
%   whether each is a trial group's entry (legendGroup true: renderFigure
%   lists each group once, from the panel that draws the groups best), and
%   the y label renderFigure puts on the panel ("" = the draw function, or
%   the renderer it called, labeled the axes itself), extraAxes: further
%   axes the panel drew in its tile (a coherence panel's phase axes under
%   its magnitude; empty for the others), which renderFigure dresses with
%   the panel type's looks too, and yExtent: the panel's y extent in its
%   values' units, [lo hi], where its axes do not show it (a stack's rows:
%   the reach of them all); [NaN NaN] = its axes' y limits say it
%   (renderFigure's H.panels(k).yExtent, a run's batch range:
%   figureYExtents).
%
%   See also renderFigure, figurePanelRegistry.
hk = struct('axes', ax, 'legendHandles', gobjects(1, 0), 'legendLabels', strings(1, 0), ...
    'legendGroup', false(1, 0), 'yName', "", 'extraAxes', gobjects(1, 0), 'yExtent', [NaN NaN]);
end
