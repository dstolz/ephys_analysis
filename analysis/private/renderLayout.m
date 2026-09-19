function [tl, ax] = renderLayout(target, nr, nc)
%renderLayout  A fresh nr x nc tiled layout in TARGET, or TARGET itself.
%   [TL, AX] = renderLayout(TARGET, NR, NC): an axes or uiaxes TARGET is
%   cleared and returned as AX (TL = []): the caller draws one panel there.
%   A figure, uifigure, panel, tab or tiled layout is emptied and gets a
%   compact NR x NC tiled layout TL (AX = []); a grid layout gets a
%   borderless panel holding it. Renderers never create figures.

tl = []; ax = [];
if isa(target, 'matlab.graphics.axis.Axes') || isa(target, 'matlab.ui.control.UIAxes')
    cla(target, 'reset');
    ax = target;
    return
end
if isa(target, 'matlab.graphics.layout.TiledChartLayout')
    delete(target.Children);
    target.GridSize = [nr nc];
    tl = target;
    return
end
if isa(target, 'matlab.ui.container.GridLayout')
    delete(target.Children);
    target = uipanel(target, 'BorderType', 'none', 'BackgroundColor', 'w');
elseif isa(target, 'matlab.ui.Figure')
    clf(target);
elseif isgraphics(target)
    delete(target.Children);
else
    error('renderPlot:BadTarget', 'Draw into an axes, a figure, a panel, a tab, a grid layout or a tiled layout.');
end
tl = tiledlayout(target, nr, nc, 'TileSpacing', 'compact', 'Padding', 'compact');
end
