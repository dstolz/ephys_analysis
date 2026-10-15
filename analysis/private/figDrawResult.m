function hk = figDrawResult(ax)
%figDrawResult  What a figure panel's draw function returns, before it draws.
%   HK = figDrawResult(AX) is struct('axes', AX, 'legendHandles', [],
%   'legendLabels', [], 'legendGroup', [], 'yName', "", 'extraAxes', []):
%   the panel's axes,
%   the objects it offers renderFigure's one legend with their labels and
%   whether each is a trial group's entry (legendGroup true: renderFigure
%   lists each group once, from the panel that draws the groups best), and
%   the y label renderFigure puts on the panel ("" = the draw function, or
%   the renderer it called, labeled the axes itself), and extraAxes: further
%   axes the panel drew in its tile (a coherence panel's phase axes under
%   its magnitude; empty for the others), which renderFigure dresses with
%   the panel type's looks too.
%
%   See also renderFigure, figurePanelRegistry.
hk = struct('axes', ax, 'legendHandles', gobjects(1, 0), 'legendLabels', strings(1, 0), ...
    'legendGroup', false(1, 0), 'yName', "", 'extraAxes', gobjects(1, 0));
end
