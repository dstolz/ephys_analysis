function h = gridNodeSVG(n)
%gridNodeSVG  One box (with its badge and text) and the files hung under it.
%   A node may carry a drawn body under its lines: body, its SVG drawn from
%   (0, 0), and bodyH, its height, which gridPlace adds to the box's. Its
%   badge is green unless the node is dim, or has a badgeClass of its own.
x = n.x; y = n.y; w = n.w;
isSrc = n.kind == "src";
tc = ternary(isSrc, "t src", "t");
dc = ternary(isSrc, "d src", "d");
parts = sprintf("<rect class=""box %s"" x=""%.1f"" y=""%.1f"" width=""%.1f"" height=""%.1f"" rx=""7""/>", n.kind, x, y, w, n.boxH);
if ~isSrc
    parts = parts + sprintf("<path class=""bar"" d=""M%.1f %.1fh-0.5a6.5 6.5 0 0 0 -6.5 6.5v%.1fa6.5 6.5 0 0 0 6.5 6.5h0.5z""/>", ...
        x + 7, y, n.boxH - 13);
end
parts = parts + sprintf("<text class=""%s"" x=""%.1f"" y=""%.1f"">%s</text>", tc, x + 14, y + 17, gridEsc(n.title));
if n.badge ~= ""
    bw = gridTextWidth(n.badge, 10) + 12;
    bc = ternary(n.dim, "", " on");
    if isfield(n, 'badgeClass') && n.badgeClass ~= ""; bc = " " + n.badgeClass; end
    parts = parts + sprintf("<rect class=""badge%s"" x=""%.1f"" y=""%.1f"" width=""%.1f"" height=""15"" rx=""7.5""/>", ...
        bc, x + w - 8 - bw, y + 6, bw) ...
        + sprintf("<text class=""bt%s"" x=""%.1f"" y=""%.1f"" text-anchor=""middle"">%s</text>", ...
        bc, x + w - 8 - bw / 2, y + 17, gridEsc(n.badge));
end
for j = 1:numel(n.lines)
    parts = parts + sprintf("<text class=""%s"" x=""%.1f"" y=""%.1f"">%s</text>", dc, x + 14, y + 18 + 14 * j, gridEsc(n.lines(j)));
end
if isfield(n, 'body') && n.body ~= ""
    parts = parts + sprintf("<g transform=""translate(%.1f %.1f)"">", x + 14, y + 25 + 14 * numel(n.lines)) + n.body + "</g>";
end
h = "<g class=""node c-" + n.key + """ data-id=""" + n.id + """>" ...
    + "<g class=""hit" + ternary(n.dim, " dim", "") + """" + navAttr(n.target, n.title) + ">" + parts + "</g>";

if ~isempty(n.outs)
    cx = x + w / 2;
    P = n.outs;
    h = h + "<g class=""wire" + ternary(n.dim, " dim", "") + """>" ...
        + sprintf("<path class=""ln"" d=""M%.1f %.1fV%.1f""/>", cx, y + n.boxH, P(end).y) ...
        + gridJoin(arrayfun(@(p) sprintf("<path class=""head"" d=""M%.1f %.1fL%.1f %.1fL%.1f %.1fZ""/>", ...
            cx - 4.5, p.y - 8, cx + 4.5, p.y - 8, cx, p.y), P, "UniformOutput", false)) + "</g>";
    for j = 1:numel(P)
        p = P(j);
        body = sprintf("<rect class=""pbox"" x=""%.1f"" y=""%.1f"" width=""%.1f"" height=""%.1f"" rx=""9""/>", p.x, p.y, p.w, p.h) ...
            + sprintf("<text class=""pt"" x=""%.1f"" y=""%.1f"">%s</text>", p.x + 9, p.y + 14, gridEsc(p.title));
        for i = 1:numel(p.lines)
            body = body + sprintf("<text class=""pd"" x=""%.1f"" y=""%.1f"">%s</text>", p.x + 9, p.y + 14 + 13 * i, gridEsc(p.lines(i)));
        end
        cls = "hit pill" + ternary(p.kind == "out", "", " " + p.kind) + ternary(p.dim, " dim", "");
        h = h + "<g class=""" + cls + """" + navAttr(p.target, p.title) + ">" + body + "</g>";
    end
end
h = h + "</g>";
end


function a = navAttr(target, title)
%navAttr  The attributes setup() looks for to make a box open its controls.
if strlength(target) == 0
    a = "";
else
    a = " data-nav=""" + gridEsc(target) + """ data-title=""" + gridEsc(title) + """";
end
end


function v = ternary(tf, a, b)
if tf; v = string(a); else; v = string(b); end
end
