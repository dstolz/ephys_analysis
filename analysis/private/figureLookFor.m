function look = figureLookFor(F, spec, p, P, style, colors, isTime)
%figureLookFor  What a panel's draw function is given besides its result (figurePanelRegistry's LOOK).
%
%   See also renderFigure, renderProbeFigure.
W = figureFixedWindow(p.window);
look = struct('style', style, 'colors', colors, 'W', W, 'spec', spec, 'panel', p, 'panelId', p.id, ...
    'isTop', p.row == 1, 'isBottom', p.row + p.rowSpan - 1 >= spec.grid.rows, 'epochs', [], 'groups', [], ...
    'observation', F.observation, 'isTime', isTime);
look.epochs = P.epochs;
if ~istable(look.epochs); look.epochs = F.epochs; end
look.groups = P.groups;
if ~istable(look.groups); look.groups = F.groups; end
end
