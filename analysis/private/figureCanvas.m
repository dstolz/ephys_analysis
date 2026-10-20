function [canvas, ax] = figureCanvas(target)
%figureCanvas  What renderFigure lays a figure out on: TARGET emptied, or TARGET itself when it is an axes.
%   [CANVAS, AX] = figureCanvas(TARGET): an axes or uiaxes TARGET is
%   cleared and returned as AX (CANVAS = []): the caller draws one panel
%   there. A figure, uifigure, panel or tab is emptied and is CANVAS (AX =
%   []): it holds the figure's axes, which figureLayout places in pixels; a
%   grid layout is emptied and gets a borderless white panel as CANVAS. A
%   uifigure's container stops resizing its children itself
%   (AutoResizeChildren off): figureLayout lays them out again when it
%   changes size. The axes go straight into a figure, not into a panel of
%   it: print cannot write a figure holding UI components as SVG. Renderers
%   never create figures. Error: renderFigure:BadTarget.
%
%   See also renderFigure, figureLayout.

canvas = [];
ax = [];
if isa(target, 'matlab.graphics.axis.Axes') || isa(target, 'matlab.ui.control.UIAxes')
    cla(target, 'reset');
    ax = target;
    return
end
if isa(target, 'matlab.ui.Figure')
    clf(target);
    canvas = target;
elseif isa(target, 'matlab.ui.container.Panel') || isa(target, 'matlab.ui.container.Tab')
    delete(target.Children);
    canvas = target;
elseif isa(target, 'matlab.ui.container.GridLayout')
    delete(target.Children);
    canvas = uipanel(target, 'BorderType', 'none', 'BackgroundColor', 'w');
else
    error('renderFigure:BadTarget', 'Draw a figure into an axes, a figure, a panel, a tab or a grid layout.');
end
if isprop(canvas, 'AutoResizeChildren'); canvas.AutoResizeChildren = 'off'; end
end
