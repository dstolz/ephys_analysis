function drawFigureSchematic(obj)
%drawFigureSchematic  Draw the selected figure's arrangement in the editor's schematic (FigureSchematic).
%   The grid in proportion (its rows' relative heights and its columns'
%   relative widths, [] = equal): one patch per panel, filled with a pale
%   color of its type, the selected panel (SelectedPanel) with a dark edge
%   and its name in bold, each with its type and how many layers it has in
%   its middle; a click on a panel picks it (onPanelSelected). Cells no
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
gap = 0.006;
gray = [0.72 0.72 0.72];
for r = 1:size(cells, 1)
    for c = 1:size(cells, 2)
        if cells(r, c) ~= 0; continue; end
        x = [cx(c) cx(c+1) cx(c+1) cx(c) cx(c)] + gap * [1 -1 -1 1 1];
        y = [cy(r) cy(r) cy(r+1) cy(r+1) cy(r)] + gap * [1 1 -1 -1 1];
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
    x0 = cx(c0) + gap; x1 = cx(c1 + 1) - gap;
    y0 = cy(r0) + gap; y1 = cy(r1 + 1) - gap;
    sel = q == obj.SelectedPanel;
    edge = [0.53 0.53 0.53];
    width = 1;
    if sel; edge = [0.13 0.13 0.13]; width = 2.5; end
    patch(ax, [x0 x1 x1 x0], [y0 y0 y1 y1], fillOf(p.type), "EdgeColor", edge, "LineWidth", width, ...
        "Tag", "schematicPanel", "UserData", q, "ButtonDownFcn", @(~, ~) obj.onPanelSelected(q));
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
    otherwise,         c = [0.92 0.92 0.92];
end
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
