function placeNote(N, note)
%placeNote  Put a plot's note where its settings say, once its looks are final (renderPlot).
%   placeNote(N, NOTE) positions the text drawNote made (N) by NOTE.placement,
%   .align, .valign and .x / .y, and draws its outline when NOTE.box. It
%   measures the text as it now is -- after the design's and the user's
%   rules -- so a design's font size or face is allowed for.
%
%   Outside the plot (below, above, right, left) the tiled layout gives up a
%   band as wide as the text and a little more, and the text sits in it; the
%   alignment then says where along the band (align across the plot for
%   below and above, valign up it for right and left). Over the plot (the
%   eight compass points and center) the text sits at that place in the
%   layout's whole area, title included. custom puts the text's anchor --
%   its left, center or right (align) and top, middle or bottom (valign) --
%   at NOTE.x and NOTE.y, 0-1 across and up the layout's area. A plot that
%   is one axes has its text in the axes; below and above go just past the
%   axes' edge, where its labels are.
%
%   See also drawNote, renderPlot.

t = N.text;
if isempty(t) || ~isgraphics(t); return; end
if note.box
    t.EdgeColor = t.Color;
    t.LineWidth = 0.75;
end
place = string(note.placement);
if isempty(N.host)
    placeInAxes(t, note, place);
    return
end
host = N.host;
tl = N.layout;

% the text's size and the room there is, in points
t.Units = 'points';
ext = t.Extent;
t.Units = 'data';
[W, H] = sizeOf(host);
pad = 6;
bw = ext(3) / W;      % the text's width and height, and the gap round it, as shares of the host
bh = ext(4) / H;
px = pad / W;
py = pad / H;

L = NaN; B = NaN;     % the text's lower-left corner in the host
base = [0 0 1 1];
shrink = isappdata(tl, 'NoteBase') && strcmp(tl.Units, 'normalized');
if shrink; base = getappdata(tl, 'NoteBase'); end
rect = [];
switch place
    case {"below" "above"}
        f = min(0.5, bh + 2 * py);
        if place == "below"
            B = (f - bh) / 2;
            rect = [base(1), base(2) + f * base(4), base(3), (1 - f) * base(4)];
        else
            B = 1 - f + (f - bh) / 2;
            rect = [base(1), base(2), base(3), (1 - f) * base(4)];
        end
        L = alongX(note.align, bw, px);
    case {"left" "right"}
        g = min(0.5, bw + 2 * px);
        if place == "left"
            L = (g - bw) / 2;
            rect = [base(1) + g * base(3), base(2), (1 - g) * base(3), base(4)];
        else
            L = 1 - g + (g - bw) / 2;
            rect = [base(1), base(2), (1 - g) * base(3), base(4)];
        end
        B = alongY(note.valign, bh, py);
    case "custom"
        t.Position = [note.x note.y 0];
        return
    otherwise    % the compass points and center
        L = alongX(columnOf(place), bw, px);
        B = alongY(rowOf(place), bh, py);
end
if shrink && ~isempty(rect)
    tl.OuterPosition = rect;
end
% the anchor the text's own alignment makes of its corner
x = L + bw * anchorShare(note.align, ["left" "center" "right"]);
y = B + bh * anchorShare(note.valign, ["bottom" "middle" "top"]);
t.Position = [x y 0];
end


function placeInAxes(t, note, place)
%placeInAxes  The note of a plot that is one axes: normalized to the axes, labels allowed for.
ax = ancestor(t, 'axes');
fs = t.FontSize;
ax.Units = 'points';
height = max(ax.Position(4), 50);
ax.Units = 'normalized';
gap = 2.8 * fs / height;   % past the x label
side = 0.02;
t.Units = 'normalized';
switch place
    case "below"
        pos = [shareOf(note.align) -gap];
        va = 'top';
    case "above"
        pos = [shareOf(note.align) 1 + gap / 3];
        va = 'bottom';
    case "right"
        pos = [1 + side shareOfV(note.valign)];
        va = char(note.valign);
    case "left"
        pos = [-side shareOfV(note.valign)];
        va = char(note.valign);
    case "custom"
        pos = [note.x note.y];
        va = char(note.valign);
    otherwise
        col = columnOf(place);
        row = rowOf(place);
        pos = [side + shareOf(col) * (1 - 2 * side), side + shareOfV(row) * (1 - 2 * side)];
        va = char(row);
        t.HorizontalAlignment = char(col);
end
t.Position = [pos 0];
t.VerticalAlignment = va;
switch place
    case "right",  t.HorizontalAlignment = 'left';
    case "left",   t.HorizontalAlignment = 'right';
end
end


function [W, H] = sizeOf(ax)
%sizeOf  The axes' size in points (a default when the figure has not been laid out yet).
W = 0; H = 0;
for attempt = 1:2
    ax.Units = 'points';
    p = ax.Position;
    ax.Units = 'normalized';
    W = p(3); H = p(4);
    if W > 20 && H > 20; return; end
    if attempt == 1; drawnow limitrate; end
end
W = 432; H = 288;
end


function L = alongX(align, bw, px)
%alongX  The left edge of a block bw wide, at the left, center or right of the host.
switch string(align)
    case "left",   L = px;
    case "center", L = (1 - bw) / 2;
    otherwise,     L = 1 - px - bw;
end
end


function B = alongY(valign, bh, py)
%alongY  The bottom edge of a block bh tall, at the top, middle or bottom of the host.
switch string(valign)
    case "top",    B = 1 - py - bh;
    case "middle", B = (1 - bh) / 2;
    otherwise,     B = py;
end
end


function s = anchorShare(name, order)
%anchorShare  Where a block's anchor is along it: 0, 0.5 or 1 for the first, second, third of ORDER.
s = (find(string(name) == order, 1) - 1) / 2;
if isempty(s); s = 0; end
end


function c = columnOf(place)
%columnOf  A compass point's column as an alignment: left (west), center or right (east).
c = "center";
if endsWith(place, "west"); c = "left"; end
if endsWith(place, "east"); c = "right"; end
end


function r = rowOf(place)
%rowOf  A compass point's row as an alignment: top (north), middle or bottom (south).
r = "middle";
if startsWith(place, "north"); r = "top"; end
if startsWith(place, "south"); r = "bottom"; end
end


function s = shareOf(align)
%shareOf  How far along the axes a left / center / right alignment is: 0, 0.5, 1.
s = (find(string(align) == ["left" "center" "right"], 1) - 1) / 2;
end


function s = shareOfV(valign)
%shareOfV  How far up the axes a bottom / middle / top alignment is: 0, 0.5, 1.
s = (find(string(valign) == ["bottom" "middle" "top"], 1) - 1) / 2;
end
