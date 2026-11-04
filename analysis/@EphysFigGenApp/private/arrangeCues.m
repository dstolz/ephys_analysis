function arrangeCues(obj, rect, g)
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
%   are made once per overlay and reused: a cue not needed is hidden, so
%   a drag changes their data only. arrangeCues(OBJ, [], []) hides them
%   all (a drag released, Escape, the nudge's timer).
%
%   See also snapRect, EphysFigGenApp.onArrangeMoving, EphysFigGenApp.nudgePanel.
O = obj.FigureArrangeOverlay;
if ~isstruct(O) || isempty(O.axes) || ~isvalid(O.axes); return; end
G = O.guides;
if isempty(G) || ~isvalid(G.readout)
    if isempty(g); return; end
    G = makeGuides(O.axes);
    O.guides = G;
    obj.FigureArrangeOverlay = O;
end
objs = [G.lines G.gapLines G.gapTexts G.size G.readout];
if isempty(g)
    set(objs(strcmp(get(objs, 'Visible'), 'on')), 'Visible', 'off');
    return
end
ax = O.axes;
px = max(ax.Position(3:4), 1);   % the page in px: a few px of offset in its 0-1
u = obj.FigureRectUnits;
[pageCm, dpi] = figurePage(obj);
[~, d] = unitsShown([], "", u);
tails = struct('normalized', "", 'p', " %", 'cm', " cm", 'in', " in", 'px', " px");
tail = tails.(strrep(char(u), '%', 'p'));
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
vis = strcmp(get(objs, 'Visible'), 'on').';
set(objs(on & ~vis), 'Visible', 'on');
set(objs(~on & vis), 'Visible', 'off');
end


function G = makeGuides(ax)
%makeGuides  The cue objects in the overlay AX, hidden: 8 alignment lines, 8 distance lines with their texts, the equal-size outline, the readout.
magenta = [0.9 0.1 0.6];
common = {'Tag', 'arrangeGuide', 'Visible', 'off', 'HitTest', 'off', 'PickableParts', 'none', 'Clipping', 'off'};
G.lines = gobjects(1, 8);
for i = 1:8
    G.lines(i) = line(ax, [0 0], [0 0], 'Color', magenta, 'LineWidth', 1, common{:});
end
G.gapLines = gobjects(1, 8);
G.gapTexts = gobjects(1, 8);
for i = 1:8
    G.gapLines(i) = line(ax, [0 0], [0 0], 'Color', magenta, 'LineWidth', 1, 'Marker', '|', 'MarkerSize', 8, common{:});
    G.gapTexts(i) = text(ax, 0, 0, "", 'Color', magenta, 'FontSize', 9, 'FontWeight', 'bold', 'Interpreter', 'none', ...
        'BackgroundColor', [1 1 1], 'Margin', 1, common{:});
end
G.size = line(ax, [0 0], [0 0], 'Color', [0.95 0.55 0.8], 'LineWidth', 1.5, 'LineStyle', '--', common{:});
G.readout = text(ax, 0, 0, "", 'Color', [0.15 0.15 0.15], 'FontSize', 9, 'Interpreter', 'none', ...
    'BackgroundColor', [1 1 0.88], 'EdgeColor', [0.6 0.6 0.6], 'Margin', 2, common{:});
end
