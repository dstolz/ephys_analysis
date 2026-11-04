function A = figureArea(sz, opts)
%figureArea  The page of a figure drawn on SZ pixels: inside its margin, and the area under its title band (pure).
%   A = figureArea(SZ, Name=Value), SZ = [width height] pixels (the canvas
%   drawn in), is a struct of pixel boxes [x y width height] from the
%   canvas's bottom-left corner:
%     page   the canvas inside a margin of Margin x Scale px on every side:
%            what a panel's rect (Panel.rect, 0-1 of the page) is read in
%     area   the page under the title band: where the panels may go
%            (figurePlace keeps every panel's plot area and labels in it)
%     title  the title band, Top px at the top of the page; [] when Top
%            is 0 (the area is then the page)
%   A side never shrinks below 1 px.
%
%   Options
%     Top     px the figure's title and subtitle take (default 0); not
%             scaled: renderFigure measures them as drawn
%     Margin  px round the page (default 6)
%     Scale   what Margin is multiplied by (default 1): renderFigure's
%             Scale, a drawing shown larger or smaller than its export page
%
%   See also figurePlace, figureLayout, renderFigure, renderProbeFigure.

arguments
    sz (1,2) double
    opts.Top (1,1) double = 0
    opts.Margin (1,1) double = 6
    opts.Scale (1,1) double = 1
end
m = opts.Margin * opts.Scale;
x0 = m;
y0 = m;
x1 = max(x0 + 1, sz(1) - m);
y1 = max(y0 + 1, sz(2) - m);
A = struct('page', [x0, y0, x1 - x0, y1 - y0], 'area', [], 'title', []);
top = max(0, opts.Top);
if top > 0
    A.title = [x0, y1 - top, x1 - x0, top];
    y1 = y1 - top;
end
A.area = [x0, y0, x1 - x0, max(1, y1 - y0)];
end
