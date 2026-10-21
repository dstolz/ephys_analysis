function onSchematicPress(obj, q, evt)
%onSchematicPress  A press on panel Q in the arrangement's schematic: pick it, and drag it to a new place.
%   onSchematicPress(OBJ, Q, EVT) picks panel Q (onPanelSelected) and, for a
%   left press, starts a drag: the window's WindowButtonMotionFcn and
%   WindowButtonUpFcn are set until the release (the ones it had come back
%   then). EVT is the patch's hit event: its IntersectionPoint (the press in
%   the schematic's data units) and the window's CurrentPoint (pixels) tie
%   the pointer's pixels to the schematic at the press, so the drag follows
%   the pointer however the editor was scrolled before it; on every motion
%   the scale comes again from the schematic's pixel box (a scroll during
%   the drag is not followed: a grid's scroll offset cannot be read).
%   schematicPixel is the inverse, for the tests. Without a hit point the
%   panel's middle is taken.
%   While the pointer moves, a dashed outline of the panel follows it and
%   the drop target is shaded:
%     an empty cell                the panel moves there (its row and
%                                  column; its spans clipped to the grid);
%                                  where it would overlap another panel
%                                  the cell is no target (not shaded) and a
%                                  release there says why
%     the edge band of a panel     the outer third of another panel along
%                                  the middle third of one of its edges:
%                                  the panel is taken from its place
%                                  (removePanel) and put above, below, left
%                                  or right of that panel (placePanel), a
%                                  new row or column; it keeps its place
%                                  in the figure's panel order. As Remove
%                                  panel, taking it away drops the rows and
%                                  columns no other panel starts in, so a
%                                  panel spanning such a row loses it (A
%                                  over rows 1-2 beside C over B: B dragged
%                                  above C drops row 2, and A spans one
%                                  row)
%   Anything else (the panel itself, another panel's middle or corners) is
%   no target. The release applies the target as a structural edit
%   (commitFigureEdit: the schematic, the editor and the preview follow); a
%   release with no target only picks the panel; a release outside the
%   schematic, or Escape (cancelSchematicDrag), cancels. The Arrangement's
%   buttons do the same steps one at a time.
%
%   See also drawFigureSchematic, cancelSchematicDrag, schematicPixel.
if nargin < 3; evt = []; end
if ~isempty(obj.FigureDrag); cancelSchematicDrag(obj, ""); end
f = obj.SelectedFigure;
if f < 1 || f > numel(obj.Config.Figures); return; end
fig = obj.Config.Figures(f);
if q < 1 || q > numel(fig.panels); return; end
obj.onPanelSelected(q);
if ~strcmp(obj.Fig.SelectionType, 'normal'); return; end   % a right or double click only picks
ax = obj.FigureSchematic;
if isempty(ax) || ~isvalid(ax); return; end
rect = panelRect(fig, q);
xy0 = [(rect(1) + rect(3)) / 2, (rect(2) + rect(4)) / 2];
if isstruct(evt) || isobject(evt)
    try
        ip = evt.IntersectionPoint;
        if numel(ip) >= 2 && all(isfinite(ip(1:2))); xy0 = double(ip(1:2)); end
    catch
    end
end
scale = scaleOf(ax);
p0 = double(obj.Fig.CurrentPoint(1:2));
corner = p0 - (xy0 - [ax.XLim(1) ax.YLim(1)]) ./ scale;   % the window's pixel of the schematic's top-left corner (axis ij)
D = struct('figure', f, 'id', fig.panels(q).id, 'q', q, 'p0', p0, 'xy0', xy0, 'corner', corner, 'lim0', [ax.XLim(1) ax.YLim(1)], ...
    'scale', scale, 'grab', xy0 - [(rect(1) + rect(3)) / 2, (rect(2) + rect(4)) / 2], 'rect', rect, ...
    'target', struct('kind', "none"), 'outline', gobjects(0), 'shade', gobjects(0), ...
    'oldMotion', {obj.Fig.WindowButtonMotionFcn}, 'oldUp', {obj.Fig.WindowButtonUpFcn});
obj.FigureDrag = D;
obj.Fig.WindowButtonMotionFcn = @(~, ~) dragMove(obj);
obj.Fig.WindowButtonUpFcn = @(~, ~) dragRelease(obj);
end


function dragMove(obj)
%dragMove  The pointer moved while a panel is dragged: the outline follows it, the drop target is shaded.
%   Anything going wrong cancels the drag (the status bar says what).
try
    moveStep(obj);
catch ME
    cancelSchematicDrag(obj, "Drag canceled: " + string(ME.message));
end
end


function moveStep(obj)
%moveStep  dragMove's work.
D = obj.FigureDrag;
if isempty(D); return; end
ax = obj.FigureSchematic;
if isempty(ax) || ~isvalid(ax) || obj.SelectedFigure ~= D.figure
    cancelSchematicDrag(obj, "");
    return
end
D.scale = scaleOf(ax);   % the schematic's pixel box now
obj.FigureDrag = D;
xy = pointerAt(obj, D);
fig = obj.Config.Figures(D.figure);
T = targetAt(fig, D, xy);
r = D.rect;
c = xy - D.grab;   % the outline's middle
w = (r(3) - r(1)) / 2;
h = (r(4) - r(2)) / 2;
X = c(1) + [-w w w -w -w];
Y = c(2) + [-h -h h h -h];
if isempty(D.outline) || ~isvalid(D.outline)
    D.outline = line(ax, X, Y, 'Color', [0.1 0.1 0.1], 'LineStyle', '--', 'LineWidth', 1.5, 'HitTest', 'off', ...
        'PickableParts', 'none', 'Tag', 'schematicDragOutline');
else
    set(D.outline, 'XData', X, 'YData', Y);
end
if T.kind == "none"
    if ~isempty(D.shade) && isvalid(D.shade); D.shade.Visible = 'off'; end
else
    s = T.shade;
    SX = [s(1) s(3) s(3) s(1)];
    SY = [s(2) s(2) s(4) s(4)];
    if isempty(D.shade) || ~isvalid(D.shade)
        D.shade = patch(ax, SX, SY, [0.16 0.47 0.85], 'FaceAlpha', 0.35, 'EdgeColor', [0.06 0.30 0.66], 'LineWidth', 2, ...
            'HitTest', 'off', 'PickableParts', 'none', 'Tag', 'schematicDropTarget');
    else
        set(D.shade, 'XData', SX, 'YData', SY, 'Visible', 'on');
    end
end
D.target = T;
obj.FigureDrag = D;
end


function dragRelease(obj)
%dragRelease  The press ends: apply the drop target under the pointer, or cancel (outside the schematic).
D = obj.FigureDrag;
if isempty(D); return; end
if obj.SelectedFigure ~= D.figure || obj.SelectedFigure > numel(obj.Config.Figures)
    cancelSchematicDrag(obj, "");
    return
end
xy = pointerAt(obj, D);
if any(xy < 0) || any(xy > 1)
    cancelSchematicDrag(obj, "Drag canceled: released outside the arrangement.");
    return
end
fig = obj.Config.Figures(D.figure);
T = targetAt(fig, D, xy);
endDrag(obj, D);
switch T.kind
    case "cell"
        moveToCell(obj, D, T);
    case "edge"
        moveBeside(obj, D, T);
    otherwise
        obj.drawFigureSchematic();   % the outline goes; a press and release on the panel only picked it
        if isfield(T, 'why') && T.why ~= ""
            obj.setStatus(T.why);
        elseif ~isequal(panelAt(fig, xy), D.q)
            obj.setStatus("Nothing to drop " + D.id + " on there: drop it on an empty cell, or near the middle of " + ...
                "another panel's edge (above, below, left or right of it).");
        end
end
end


function moveToCell(obj, D, T)
%moveToCell  The dragged panel to the empty cell T.row, T.col (its spans clipped to the grid), unless it would overlap.
cfg = obj.gatherConfig();
k = D.figure;
fig = cfg.Figures(k);
qi = find([fig.panels.id] == D.id, 1);
if isempty(qi); obj.drawFigureSchematic(); return; end
p = fig.panels(qi);
p.row = T.row;
p.col = T.col;
rs = min(p.rowSpan, fig.grid.rows - T.row + 1);
cs = min(p.colSpan, fig.grid.cols - T.col + 1);
clipped = rs ~= p.rowSpan || cs ~= p.colSpan;
p.rowSpan = rs;
p.colSpan = cs;
fig.panels(qi) = p;
[~, over] = EphysAnalysisConfig.figureCells(fig);
if ~isempty(over)
    o = over(1, :);
    o = o(o ~= qi);
    obj.drawFigureSchematic();
    obj.setStatus(sprintf("%s does not fit at row %d, column %d: it would overlap %s. Shrink its spans first, " + ...
        "or drop it on an edge.", D.id, T.row, T.col, fig.panels(o(1)).id));
    return
end
cfg.Figures(k) = fig;
obj.SelectedPanel = qi;
msg = sprintf("Moved %s to row %d, column %d.", D.id, T.row, T.col);
if clipped; msg = msg + sprintf(" Its spans became %d x %d to fit the grid.", rs, cs); end
commitFigureEdit(obj, cfg, msg, Action="Move panel");
end


function moveBeside(obj, D, T)
%moveBeside  The dragged panel taken from its place and put T.where of the panel T.anchor (a new row or column).
cfg = obj.gatherConfig();
k = D.figure;
fig = cfg.Figures(k);
qi = find([fig.panels.id] == D.id, 1);
if isempty(qi) || ~any([fig.panels.id] == T.anchor); obj.drawFigureSchematic(); return; end
p = fig.panels(qi);
try
    fig = EphysAnalysisConfig.removePanel(fig, p.id);
    fig = EphysAnalysisConfig.placePanel(fig, p, T.where, T.anchor);
catch ME
    obj.drawFigureSchematic();
    obj.setStatus("Config: " + string(ME.message));
    return
end
n = numel(fig.panels);
fig.panels = fig.panels([1:qi-1, n, qi:n-1]);   % placePanel appended it: back to its place in the panel order
cfg.Figures(k) = fig;
obj.SelectedPanel = qi;
commitFigureEdit(obj, cfg, "Moved " + p.id + " " + T.where + " " + T.anchor + ".", Action="Move panel");
end


function xy = pointerAt(obj, D)
%pointerAt  The pointer in the schematic's data units: its pixels from the schematic's top-left corner, at its scale now.
p = double(obj.Fig.CurrentPoint(1:2));
xy = D.lim0 + (p - D.corner) .* D.scale;
end


function s = scaleOf(ax)
%scaleOf  The schematic's data units per pixel, [x y] (y negative: it runs down, axis ij), from its plot box now.
units = ax.Units;
ax.Units = 'pixels';
box = ax.InnerPosition;
ax.Units = units;
if ~(numel(box) == 4 && all(box(3:4) > 20)); box = [1 1 400 160]; end
s = [diff(ax.XLim) / box(3), -diff(ax.YLim) / box(4)];
end


function T = targetAt(fig, D, xy)
%targetAt  What a release at XY would do: an empty cell, an edge of another panel, or nothing.
%   T.kind "cell" (row, col), "edge" (where, anchor: a panel id) or "none";
%   T.shade the rectangle to shade, [x0 y0 x1 y1] in the schematic's units.
T = struct('kind', "none");
if any(xy < 0) || any(xy > 1); return; end
nr = max(1, round(fig.grid.rows));
nc = max(1, round(fig.grid.cols));
cy = edges(fig.grid.rowHeights, nr);
cx = edges(fig.grid.colWidths, nc);
r = min(nr, max(1, find(xy(2) >= cy(1:end-1), 1, 'last')));
c = min(nc, max(1, find(xy(1) >= cx(1:end-1), 1, 'last')));
cells = EphysAnalysisConfig.figureCells(fig);
if r > size(cells, 1) || c > size(cells, 2); return; end
t = cells(r, c);
if t == 0
    [fits, other] = fitsAt(fig, D, r, c);
    if fits
        T = struct('kind', "cell", 'row', r, 'col', c, 'shade', [cx(c) cy(r) cx(c+1) cy(r+1)]);
    else
        T = struct('kind', "none", 'why', sprintf("%s does not fit at row %d, column %d: it would overlap %s. " + ...
            "Shrink its spans first, or drop it beside a panel.", D.id, r, c, other));
    end
    return
end
if t == D.q; return; end
s = panelRect(fig, t);
u = (xy(1) - s(1)) / max(eps, s(3) - s(1));   % across the panel, 0-1
v = (xy(2) - s(2)) / max(eps, s(4) - s(2));   % down it, 0-1
mid = @(z) z >= 1/3 && z <= 2/3;
w = (s(3) - s(1)) / 3;
h = (s(4) - s(2)) / 3;
where = "";
if v < 1/3 && mid(u)
    where = "above"; shade = [s(1) s(2) s(3) s(2) + h];
elseif v > 2/3 && mid(u)
    where = "below"; shade = [s(1) s(4) - h s(3) s(4)];
elseif u < 1/3 && mid(v)
    where = "left"; shade = [s(1) s(2) s(1) + w s(4)];
elseif u > 2/3 && mid(v)
    where = "right"; shade = [s(3) - w s(2) s(3) s(4)];
end
if where == ""; return; end
T = struct('kind', "edge", 'where', where, 'anchor', fig.panels(t).id, 'shade', shade);
end


function [tf, other] = fitsAt(fig, D, r, c)
%fitsAt  Whether the dragged panel, moved to the empty cell (R, C) with its spans clipped to the grid, overlaps no panel; OTHER: the one it would.
tf = true;
other = "";
qi = find([fig.panels.id] == D.id, 1);
if isempty(qi); tf = false; return; end
p = fig.panels(qi);
p.row = r;
p.col = c;
p.rowSpan = min(p.rowSpan, fig.grid.rows - r + 1);
p.colSpan = min(p.colSpan, fig.grid.cols - c + 1);
fig.panels(qi) = p;
[~, over] = EphysAnalysisConfig.figureCells(fig);
if isempty(over); return; end
tf = false;
o = over(1, :);
o = o(o ~= qi);
if isempty(o); o = over(1, 1); end
other = fig.panels(o(1)).id;
end


function q = panelAt(fig, xy)
%panelAt  The panel under XY (0 = none).
q = 0;
for k = 1:numel(fig.panels)
    s = panelRect(fig, k);
    if xy(1) >= s(1) && xy(1) <= s(3) && xy(2) >= s(2) && xy(2) <= s(4); q = k; return; end
end
end


function s = panelRect(fig, q)
%panelRect  Panel Q's rectangle in the schematic, [x0 y0 x1 y1] (y down), as drawFigureSchematic draws it.
G = fig.grid;
nr = max(1, round(G.rows));
nc = max(1, round(G.cols));
cy = edges(G.rowHeights, nr);
cx = edges(G.colWidths, nc);
p = fig.panels(q);
r0 = min(max(round(p.row), 1), nr);
c0 = min(max(round(p.col), 1), nc);
r1 = min(nr, r0 + max(1, round(p.rowSpan)) - 1);
c1 = min(nc, c0 + max(1, round(p.colSpan)) - 1);
s = [cx(c0) cy(r0) cx(c1 + 1) cy(r1 + 1)];
end


function e = edges(sizes, n)
%edges  The cumulative edges 0..1 of N rows (columns) of relative SIZES ([] = equal), as drawFigureSchematic's.
s = ones(1, n);
if numel(sizes) == n && all(isfinite(sizes)) && all(sizes > 0); s = reshape(sizes, 1, []); end
e = [0 cumsum(s) / sum(s)];
end


function endDrag(obj, D)
%endDrag  The window's pointer callbacks back as they were before the press; no drag.
if isvalid(obj.Fig)
    obj.Fig.WindowButtonMotionFcn = D.oldMotion;
    obj.Fig.WindowButtonUpFcn = D.oldUp;
end
obj.FigureDrag = [];
end
