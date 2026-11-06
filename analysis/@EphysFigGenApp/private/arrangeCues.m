function arrangeCues(obj, rect, g, opts)
%arrangeCues  Arrange's smart guides over the preview for a panel being moved or resized: alignment lines, distances, equal spacing and size, a readout.
%   arrangeCues(OBJ, RECT, G) draws, in the Arrange overlay's axes (its
%   data units the page's 0-1), the cues snapRect found for RECT (G):
%     alignment lines   a magenta line through each edge or center that
%                       lines up with another panel's (or the page's
%                       center), from that panel to RECT and a little past
%     distances         a short double-ended line across each gap read
%                       out (to the nearest panel or the page's edge on a
%                       side, under a quarter of the page), its length at
%                       its middle in the Panels section's units
%                       (FigureRectUnits, on the figure's export page:
%                       figurePage): "0.50 cm"
%     equal spacing     both gaps of the pair read "= 0.50 cm"
%     equal size        the panel matched outlined faintly, dashed
%     readout           by the moved corner: "x 2.00, y 4.50 · 9.00 x 6.00 cm"
%                       (a move), "9.00 x 6.00 cm" (a resize, "= raster_1"
%                       after it with an equal size), "x 2.00, y 4.50 cm"
%                       (a corner clicked)
%   The objects (lines and texts, Tag "arrangeGuide", none taking a click)
%   are made with the overlay (arrangeGuides, from syncArrangeOverlay; here
%   only when the overlay lacks them) and reused: a cue not needed is
%   hidden, so a drag changes their data only; which are shown is kept
%   with them (the overlay's guides.on), so a step reads no Visible back.
%   arrangeCues(OBJ, [], []) hides them all (a drag released, Escape, the
%   nudge's timer).
%   arrangeCues(..., PageCm=CM, Dpi=DPI): the figure's export page and dpi
%   as the caller has them (a drag's step: onArrangeMoving reads them once
%   per drag), else figurePage's.
%
%   See also snapRect, EphysFigGenApp.onArrangeMoving, EphysFigGenApp.nudgePanel.
arguments
    obj
    rect
    g
    opts.PageCm = []
    opts.Dpi = []
end
O = obj.FigureArrangeOverlay;
if ~isstruct(O) || isempty(O.axes) || ~isvalid(O.axes); return; end
G = O.guides;
if isempty(G) || ~isvalid(G.readout)
    if isempty(g); return; end
    G = arrangeGuides(O.axes);
    O.guides = G;
    obj.FigureArrangeOverlay = O;
end
objs = [G.lines G.gapLines G.gapTexts G.size G.readout];
if isempty(g)
    if any(G.on); setShown(obj, G, objs, false(size(objs))); end
    return
end
ax = O.axes;
px = max(ax.Position(3:4), 1);   % the page in px: a few px of offset in its 0-1
u = obj.FigureRectUnits;
if isempty(opts.PageCm) || isempty(opts.Dpi)
    [pageCm, dpi] = figurePage(obj);
else
    [pageCm, dpi] = deal(opts.PageCm, opts.Dpi);
end
[~, d, tail] = unitsShown([], "", u);
on = false(size(objs));

% the alignment lines
for i = 1:min(size(g.lines, 1), numel(G.lines))
    L = g.lines(i, :);
    set(G.lines(i), 'XData', L([1 3]), 'YData', L([2 4]));
    on(i) = true;
end
% the distances, equal spacing marked
off = numel(G.lines);
for i = 1:min(numel(g.gaps), numel(G.gapLines))
    q = g.gaps(i);
    s = q.seg;
    v = figureRectConvert(q.value, "normalized", u, pageCm, dpi, q.axis);
    t = sprintf("%.*f%s", d, v, tail);
    if q.equal; t = "= " + t; end
    mid = [(s(1) + s(3)) / 2, (s(2) + s(4)) / 2];
    if q.axis == "x"
        set(G.gapLines(i), 'XData', s([1 3]), 'YData', s([2 4]), 'Marker', '|');
        set(G.gapTexts(i), 'Position', [mid(1), mid(2) + 3 / px(2), 0], 'String', t, 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom');
    else
        set(G.gapLines(i), 'XData', s([1 3]), 'YData', s([2 4]), 'Marker', '_');
        set(G.gapTexts(i), 'Position', [mid(1) + 4 / px(1), mid(2), 0], 'String', t, 'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'middle');
    end
    on(off + i) = true;
    on(off + numel(G.gapLines) + i) = true;
end
% equal size: the panel matched, outlined
off = numel(G.lines) + 2 * numel(G.gapLines);
extra = "";
if isstruct(g.size) && ~isempty(g.size)
    r = g.size.rect;
    set(G.size, 'XData', r(1) + [0 r(3) r(3) 0 0], 'YData', r(2) + [0 0 r(4) r(4) 0]);
    on(off + 1) = true;
    extra = "  = " + g.size.name;
end
% the readout, by the corner the pointer moves
v = unitsShown(rect, "normalized", u, pageCm, dpi, "rect");
switch g.mode
    case "move",   t = sprintf("x %.*f, y %.*f · %.*f x %.*f%s", d, v(1), d, v(2), d, v(3), d, v(4), tail);
    case "resize", t = sprintf("%.*f x %.*f%s", d, v(3), d, v(4), tail) + extra;
    otherwise,     t = sprintf("x %.*f, y %.*f%s", d, v(1), d, v(2), tail);
end
corner = rect(1:2) + rect(3:4);   % top right, unless the resize moves the left or bottom edge
if g.mode == "resize" && isfield(g, 'moved') && ~isempty(g.moved)
    if g.moved(1, 1); corner(1) = rect(1); end
    if g.moved(2, 1); corner(2) = rect(2); end
end
h = 'left'; vv = 'bottom'; dx = 6 / px(1); dy = 6 / px(2);
if corner(1) > 0.75; h = 'right'; dx = -dx; end
if corner(2) > 0.9; vv = 'top'; dy = -dy; end
set(G.readout, 'Position', [corner + [dx dy], 0], 'String', t, 'HorizontalAlignment', h, 'VerticalAlignment', vv);
on(end) = true;
setShown(obj, G, objs, on);
end


function setShown(obj, G, objs, on)
%setShown  Show the cue objects OBJS where ON, hide the rest: only those that change (G.on, what they show now), noted in the overlay.
vis = G.on;
set(objs(on & ~vis), 'Visible', 'on');
set(objs(~on & vis), 'Visible', 'off');
G.on = on;
O = obj.FigureArrangeOverlay;
O.guides = G;
obj.FigureArrangeOverlay = O;
end
