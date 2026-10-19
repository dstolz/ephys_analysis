function drawFigureSchematic(obj)
%drawFigureSchematic  Draw the selected figure's arrangement in the editor's schematic (FigureSchematic).
%   The grid in proportion (its rows' relative heights and its columns'
%   relative widths, [] = equal; the gaps between them as the spacing
%   says, px against the export figure's size, at least a sliver): one
%   patch per panel, at its own size in its cell and where its alignment
%   puts it there, filled with a pale
%   color of its type, the selected panel (SelectedPanel) with a dark edge
%   and its name in bold, each with its type and how many layers it has in
%   its middle; a press on a panel picks it, and dragging it moves it to
%   an empty cell or beside another panel (onSchematicPress). Cells no
%   panel covers are dotted; an outline goes round the grid.
%   The axes is a uiaxes in the Arrangement section's first row. One made
%   or kept while its row is 0 px high (no figure, the section collapsed)
%   does not draw again, so while the row is not shown the axes is only
%   cleared, and it is made afresh when the row shows again
%   (layoutFigureEditor marks it so: the row's panel's UserData false).
ax = obj.FigureSchematic;
k = obj.SelectedFigure;
S = obj.FigureSections;
i = find([S.Name] == "arrangement", 1);
shown = k >= 1 && k <= numel(obj.Config.Figures) && ~isempty(i) && S(i).Visible && S(i).Expanded;
holder = obj.FigureEditor.schematicPanel;
if ~shown
    if ~isempty(ax) && isvalid(ax); cla(ax); end
    holder.UserData = false;
    return
end
if isempty(ax) || ~isvalid(ax) || ~isequal(holder.UserData, true)
    delete(holder.Children);
    ax = uiaxes(uigridlayout(holder, [1 1], "Padding", [0 0 0 0]));
    ax.Toolbar.Visible = "off";
    disableDefaultInteractivity(ax);
    ax.YDir = "reverse";   % axis ij: row 1 on top
    set(ax, "XTick", [], "YTick", [], "XColor", "none", "YColor", "none", "Color", "none", "Box", "off");   % axis off
    obj.FigureSchematic = ax;
    holder.UserData = true;
end
cla(ax);
fig = obj.Config.Figures(k);
G = fig.grid;
nr = max(1, round(G.rows));
nc = max(1, round(G.cols));
cy = edges(G.rowHeights, nr);
cx = edges(G.colWidths, nc);
cells = EphysAnalysisConfig.figureCells(fig);
[gy, gx] = schematicGaps(G, nr, nc, obj.Config.Export);
gray = [0.72 0.72 0.72];
for r = 1:size(cells, 1)
    for c = 1:size(cells, 2)
        if cells(r, c) ~= 0; continue; end
        b = inside(cx, cy, gx, gy, c, c, r, r);
        x = b([1 2 2 1 1]);
        y = b([3 3 4 4 3]);
        line(ax, x, y, "Color", gray, "LineStyle", ":", "LineWidth", 1, "HitTest", "off", "Tag", "schematicEmpty");
    end
end
PT = EphysAnalysisConfig.panelTypes();
for q = 1:numel(fig.panels)
    p = fig.panels(q);
    r0 = min(max(round(p.row), 1), nr);
    c0 = min(max(round(p.col), 1), nc);
    r1 = min(nr, r0 + max(1, round(p.rowSpan)) - 1);
    c1 = min(nc, c0 + max(1, round(p.colSpan)) - 1);
    b = inside(cx, cy, gx, gy, c0, c1, r0, r1);
    s = [1 1];   % its own size in its cell, where its alignment puts it
    if numel(p.size) == 2 && all(isfinite(p.size) & p.size > 0); s = min(reshape(p.size, 1, 2), 1); end
    w = (b(2) - b(1)) * s(1);
    h = (b(4) - b(3)) * s(2);
    x0 = b(1) + (b(2) - b(1) - w) * shareOf(p.align, ["left" "center" "right"]); x1 = x0 + w;
    y0 = b(3) + (b(4) - b(3) - h) * shareOf(p.valign, ["top" "middle" "bottom"]); y1 = y0 + h;   % y runs down
    sel = q == obj.SelectedPanel;
    edge = [0.53 0.53 0.53];
    width = 1;
    if sel; edge = [0.13 0.13 0.13]; width = 2.5; end
    patch(ax, [x0 x1 x1 x0], [y0 y0 y1 y1], fillOf(p.type), "EdgeColor", edge, "LineWidth", width, ...
        "Tag", "schematicPanel", "UserData", q, "ButtonDownFcn", @(~, evt) obj.onSchematicPress(q, evt));
    row = PT.Type == p.type;
    label = p.type;
    if any(row); label = PT.Label(row); end
    nl = numel(p.layers);
    words = [label; sprintf("%d layer%s", nl, repmat('s', 1, nl ~= 1))];
    if sel; words(1) = p.id + ": " + label; end
    text(ax, (x0 + x1) / 2, (y0 + y1) / 2, words, "HorizontalAlignment", "center", "VerticalAlignment", "middle", ...
        "FontSize", 10, "FontWeight", ternary(sel, "bold", "normal"), "Color", [0.13 0.13 0.13], ...
        "Interpreter", "none", "HitTest", "off", "PickableParts", "none", "Clipping", "on");
end
rectangle(ax, "Position", [0 0 1 1], "EdgeColor", [0.4 0.4 0.4], "HitTest", "off", "PickableParts", "none");
ax.XLim = [-0.01 1.01];
ax.YLim = [-0.02 1.02];
end


function e = edges(sizes, n)
%edges  The cumulative edges 0..1 of N rows (columns) of relative SIZES ([] = equal).
s = ones(1, n);
if numel(sizes) == n && all(isfinite(sizes)) && all(sizes > 0); s = reshape(sizes, 1, []); end
e = [0 cumsum(s) / sum(s)];
end


function [gy, gx] = schematicGaps(G, nr, nc, export)
%schematicGaps  The gaps between the rows (GY, NR - 1) and columns (GX, NC - 1) in the schematic's units (the grid is 1 x 1).
%   In proportion: px against the export figure's size (FigureSizeCm, as
%   newExportFigure makes it), % against the mean row (column); at least
%   a sliver, so the panels stay apart, and at most a third of a row.
px = EphysAnalysisConfig.GridSpacingPx;
i = find(EphysAnalysisConfig.GridSpacings(1:numel(px)) == G.spacing, 1);
if isempty(i)
    gy = gapsOf(G.rowGaps, G.rowGap, nr - 1);
    gx = gapsOf(G.colGaps, G.colGap, nc - 1);
    pct = G.gapUnits == "%";
else
    gy = repmat(px(i), 1, nr - 1);
    gx = repmat(px(i), 1, nc - 1);
    pct = false;
end
if pct
    gy = gy / 100 / nr;
    gx = gx / 100 / nc;
else
    cm = [18 12];
    if isfield(export, 'FigureSizeCm') && numel(export.FigureSizeCm) == 2; cm = export.FigureSizeCm; end
    cm(2) = max(cm(2), 3.5 * nr + 2);
    gy = gy / (cm(2) / 2.54 * 96);
    gx = gx / (cm(1) / 2.54 * 96);
end
gy = min(max(gy, 0.008), 1 / (3 * nr));
gx = min(max(gx, 0.008), 1 / (3 * nc));
end


function g = gapsOf(list, one, n)
%gapsOf  N gaps: LIST when it has N, else ONE each.
g = reshape(double(list), 1, []);
if numel(g) ~= n; g = repmat(double(one), 1, n); end
end


function b = inside(cx, cy, gx, gy, c0, c1, r0, r1)
%inside  The box [x0 x1 y0 y1] of the cells c0..c1, r0..r1 less half the gap to each neighbor (a sliver at the grid's edge).
edge = 0.006;
b = [cx(c0) cx(c1 + 1) cy(r0) cy(r1 + 1)];
if c0 > 1; b(1) = b(1) + gx(c0 - 1) / 2; else; b(1) = b(1) + edge; end
if c1 < numel(cx) - 1; b(2) = b(2) - gx(c1) / 2; else; b(2) = b(2) - edge; end
if r0 > 1; b(3) = b(3) + gy(r0 - 1) / 2; else; b(3) = b(3) + edge; end
if r1 < numel(cy) - 1; b(4) = b(4) - gy(r1) / 2; else; b(4) = b(4) - edge; end
end


function s = shareOf(v, order)
%shareOf  0, 0.5 or 1 for the first, second or third of ORDER (0.5 when V is none of them).
s = (find(string(v) == order, 1) - 1) / 2;
if isempty(s); s = 0.5; end
end


function c = fillOf(type)
%fillOf  The pale fill of a panel type in the schematic.
switch type
    case "raster",     c = [0.976 0.871 0.871];
    case "psth",       c = [0.875 0.914 0.973];
    case "continuous", c = [0.871 0.949 0.890];
    case "heatmap",    c = [0.984 0.933 0.839];
    case "waveforms",  c = [0.925 0.886 0.965];
    case "probemap",   c = [0.949 0.949 0.863];
    case "corrmap",    c = [0.965 0.871 0.918];
    case "rate",       c = [0.851 0.937 0.957];
    case "tuning",     c = [0.957 0.906 0.851];
    case "spectrum",   c = [0.886 0.937 0.875];
    case "spectrogram", c = [0.976 0.902 0.808];
    case "coherence",  c = [0.890 0.882 0.965];
    case "eventTrace", c = [0.937 0.902 0.886];
    otherwise,         c = [0.92 0.92 0.92];
end
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
