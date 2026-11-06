function onArrangeAlign(obj, how)
%onArrangeAlign  Arrange's align bar: the selected panels lined up or spaced evenly, one step of Undo.
%   onArrangeAlign(OBJ, HOW), HOW one of figureAlign's: "left", "center",
%   "right", "top", "middle", "bottom" (their edges or centers lined up),
%   "spaceX", "spaceY" (equal gaps across or up the page; a column or row
%   of panels moves as one). It acts on the panels selected
%   (selectedPanelIds: the one the editor shows first, then those added
%   with Shift+click) of the selected figure, by the bar's choices:
%   FigureAlignBy (what is lined up: the panels' boxes, their axes, or
%   their axes with their labels, as the preview lays them out: appdata
%   FigureLayoutResult, its panels matched by id), FigureAlignTo (the
%   selection, the first selected, the page; one panel alone is lined up
%   with the page) and FigureAlignGap (Space evenly's gap, converted to
%   0-1 of the page along the axis: figureRectConvert; [] even gaps).
%   The panels only move, never change size, and stay on the page. The
%   new rects are one edit (commitFigureEdit, Action "Align panels" or
%   "Space panels", Arrange=true: laid out in place, never redrawn while
%   Arrange is on). The status bar says what moved, the gap left between
%   them, and which panels went only as far as their labels let them (the
%   page's edge or a neighbor holding them), or why nothing moved: no
%   panel selected, too few to space, already lined up, a gap that does
%   not fit. When the preview has no layout of every panel (not drawn
%   yet), the axes and labels cannot be measured: their boxes are lined
%   up, and the status bar says so.
%
%   See also figureAlign, syncAlignBar, EphysFigGenApp.nudgePanel, selectedPanelIds.
arguments
    obj (1,1) EphysFigGenApp
    how (1,1) string {mustBeMember(how, ["left" "center" "right" "top" "middle" "bottom" "spaceX" "spaceY"])}
end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures) || isempty(obj.Config.Figures(k).panels); return; end
[ok, why] = previewShowsFigure(obj);
if ~ok
    obj.setStatus(why);
    return
end
if obj.FigureArrangeMode == "corners"; obj.cancelArrange(""); end
fig = obj.Config.Figures(k);
sel = selectedPanelIds(obj);
space = startsWith(how, "space");
if isempty(sel)
    obj.setStatus("Arrange: select the panels to line up (click a box; Shift+click adds more).");
    return
end
if space && numel(sel) < 2
    obj.setStatus("Space evenly: select two or more panels (Shift+click their boxes).");
    return
end
pids = [fig.panels.id];
n = numel(pids);
which = arrayfun(@(s) find(pids == s, 1), sel);
rects = zeros(n, 4);
for j = 1:n; rects(j, :) = reshape(double(fig.panels(j).rect), 1, 4); end
by = obj.FigureAlignBy;
to = obj.FigureAlignTo;
note = "";
if ~space && isscalar(sel) && to ~= "page"
    to = "page";   % (one panel: lined up with itself is no move)
    note = " (one panel: to the page)";
end
L = [];
if by ~= "box"
    L = layoutFor(obj.FigurePreviewPanel, pids);
    if isempty(L)
        by = "box";
        note = note + " The preview is not laid out for every panel yet: their boxes were lined up (Preview, Ctrl+P, then again for the axes).";
    end
end
a = 1 + ismember(how, ["top" "middle" "bottom" "spaceY"]);
axisName = ternary(a == 1, "x", "y");
[pageCm, dpi] = figurePage(obj, fig);
gap = [];
G = obj.FigureAlignGap;
if space && isstruct(G)
    gap = figureRectConvert(double(G.value), string(G.units), "normalized", pageCm, dpi, axisName);
end
[r2, info] = figureAlign(rects, which, how, Feature=by, To=to, Gap=gap, Layout=L);
what = struct('box', "boxes", 'axes', "axes", 'labels', "axes and labels").(by);
toWord = struct('selection', "to the selection", 'first', "to " + sel(1), 'page', "to the page").(to);
if space
    across = ternary(a == 1, "across", "up the page");
    unit = ternary(a == 1, "columns", "rows");
    if ~info.room
        obj.setStatus("Space evenly " + across + ": the " + numel(sel) + " panels do not fit on the page " + ...
            ternary(isempty(gap), "side by side", "with that gap") + ".");
        return
    end
    if info.groups < 2 || (isempty(gap) && to ~= "page" && info.groups < 3)
        obj.setStatus("Space evenly " + across + ": the panels selected make " + info.groups + " " + ...
            ternary(info.groups == 1, extractBefore(unit, strlength(unit)), unit) + ". Without a Gap, the outermost stay where " + ...
            "they are, so it takes three or more; give a Gap, or space them to the page.");
        return
    end
end
if ~any(info.moved)
    obj.setStatus(ternary(space, "Already evenly spaced", "Already lined up") + " (" + what + ", " + toWord + "): nothing moved.");
    return
end
cfg = obj.Config;   % the rects alone changed
F = cfg.Figures;   % (set once: each assignment of Figures normalizes the figure changed)
for j = find(info.moved); F(k).panels(j).rect = r2(j, :); end
cfg.Figures = F;
list = strjoin(pids(sort(which)), ", ");   % (in the figure's order)
if space
    [g, ~, tail] = unitsShown(info.gap, "normalized", obj.FigureRectUnits, pageCm, dpi, axisName);
    msg = "Spaced " + numel(sel) + " panels evenly " + across + " (" + what + ", " + info.groups + " " + unit + ", " + ...
        sprintf("%g", g) + tail + " apart): " + list + ".";
    action = "Space panels";
else
    sideWord = struct('left', "Left edges", 'center', "Centers", 'right', "Right edges", 'top', "Top edges", ...
        'middle', "Middles", 'bottom', "Bottom edges").(how);
    msg = sideWord + " lined up (" + what + ", " + toWord + "): " + list + ".";
    action = "Align panels";
end
held = pids(info.held);
if ~isempty(held)
    if by == "box"
        msg = msg + " " + strjoin(held, ", ") + ": kept on the page.";
    else
        msg = msg + " " + strjoin(held, ", ") + " went as far as " + ternary(isscalar(held), "its", "their") + ...
            " labels let " + ternary(isscalar(held), "it", "them") + ": the page's edge or a neighbor holds them.";
    end
end
wait = ~isempty(obj.FigureSelectTimer);   % a release's refill waits for this edit (fillSelectLater)
if wait; stopSelectTimer(obj); end
commitFigureEdit(obj, cfg, msg + note, Action=action, Arrange=true);
if wait; fillSelectLater(obj, ""); end
end


function L = layoutFor(P, pids)
%layoutFor  The preview's last layout (appdata FigureLayoutResult) with its cells in the order of the panels PIDS; [] when it does not hold them all.
L = [];
if isempty(P) || ~isvalid(P) || ~isappdata(P, 'FigureLayoutResult'); return; end
R = getappdata(P, 'FigureLayoutResult');
if ~isstruct(R) || ~all(isfield(R, {'ids' 'cells' 'size' 'top' 'margin' 'scale' 'how'})) || numel(R.ids) ~= numel(pids) ...
        || numel(R.cells) ~= numel(pids) || ~all(ismember(pids, string(R.ids)))
    return
end
order = arrayfun(@(id) find(string(R.ids) == id, 1), pids);
R.cells = R.cells(order);
R.ids = R.ids(order);
L = R;
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
