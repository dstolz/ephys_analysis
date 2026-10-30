function h = gridEdgeSVG(e, nameOf)
%gridEdgeSVG  One arrow: its path with rounded corners, a head on its target and
%   a tooltip saying what it carries. NAMEOF gives a node id's name there.
%   The head points the way the arrow's last stretch runs: down, or to the right.
cls = "edge c-" + e.from + ternary(e.on, "", " off") + ternary(e.dim, " dim", "");
p = e.points;
x = p(end, 1); y = p(end, 2);
if abs(y - p(end - 1, 2)) < 1e-6
    head = [x - 8, y - 4.5, x - 8, y + 4.5, x, y];
else
    head = [x - 4.5, y - 8, x + 4.5, y - 8, x, y];
end
h = "<g class=""" + cls + """ data-from=""" + e.from + """ data-to=""" + e.to + """><title>" ...
    + gridEsc(nameOf(e.from) + " -> " + nameOf(e.to) + ": " + e.note) + "</title>" ...
    + "<path class=""ln"" d=""" + roundedPath(p, 7) + """/>" ...
    + sprintf("<path class=""head"" d=""M%.1f %.1fL%.1f %.1fL%.1f %.1fZ""/>", head) ...
    + "</g>";
end


function d = roundedPath(p, r)
%roundedPath  SVG path through the points P, each corner rounded (radius
%   up to R, less where the pieces around it are short).
d = sprintf("M%.1f %.1f", p(1, 1), p(1, 2));
for k = 2:size(p, 1) - 1
    a = p(k, :) - p(k - 1, :); b = p(k + 1, :) - p(k, :);
    rr = min([r, norm(a) / 2, norm(b) / 2]);
    in = p(k, :) - rr * a / norm(a);
    out = p(k, :) + rr * b / norm(b);
    d = d + sprintf("L%.1f %.1fQ%.1f %.1f %.1f %.1f", in, p(k, :), out);
end
d = d + sprintf("L%.1f %.1f", p(end, 1), p(end, 2));
end


function v = ternary(tf, a, b)
if tf; v = string(a); else; v = string(b); end
end
