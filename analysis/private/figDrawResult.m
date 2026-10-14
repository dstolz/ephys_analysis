function hk = figDrawResult(ax)
%figDrawResult  What a figure panel's draw function returns, before it draws.
%   HK = figDrawResult(AX) is struct('axes', AX, 'legendHandles', [],
%   'legendLabels', [], 'legendGroup', [], 'yName', ""): the panel's axes,
%   the objects it offers renderFigure's one legend with their labels and
%   whether each is a trial group's entry (legendGroup true: renderFigure
%   lists each group once, from the panel that draws the groups best), and
%   the y label renderFigure puts on the panel ("" = the draw function, or
%   the renderer it called, labeled the axes itself).
%
%   See also renderFigure, figurePanelRegistry.
hk = struct('axes', ax, 'legendHandles', gobjects(1, 0), 'legendLabels', strings(1, 0), ...
    'legendGroup', false(1, 0), 'yName', "");
end
