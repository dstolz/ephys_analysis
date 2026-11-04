function cornerClick(obj)
%cornerClick  A click on the page while Set corners waits (startCornerMode): the first corner, or the opposite one, which places the rect.
%   The pointer (pageAtPointer: the window's CurrentPoint on the page,
%   0-1) snaps as a corner does (snapRect, a point: the other panels'
%   edges, the page's, else the step's grid; not with Snap off or Alt
%   held). The first click keeps the corner (FigureCorners.first), draws a
%   dashed rectangle from it to the pointer as it moves (the window's
%   WindowButtonMotionFcn while it waits; the readout says where the
%   pointer is) and asks for the opposite corner. The second gives the
%   rect between the two, on the page; one under 0.02 of the page either
%   way is refused (the status bar says so, and the first corner stays).
%   Then Set corners ends (cancelArrange) and the rect is used as
%   FigureCorners.what says: "set" the panel's rect (commitFigureEdit,
%   "Set corners"), "new" a new panel there (onNewPanel, Where "rect",
%   "Add panel"), "block" a saved figure's panels there (onNewPanel, Set).
%   A click off the page cancels.
%
%   See also EphysFigGenApp.startCornerMode, EphysFigGenApp.onArrangeClicked, pageAtPointer.
Cn = obj.FigureCorners;
O = obj.FigureArrangeOverlay;
if ~isstruct(Cn) || ~isstruct(O) || ~isvalid(O.axes); return; end
[p, inside] = pageAtPointer(obj);
if ~inside
    obj.cancelArrange("Set corners canceled: the click was off the page; the figure is unchanged.");
    return
end
id = "";
if Cn.what == "set"; id = string(Cn.payload); end
[p, g] = snapCorner(obj, p, id);
if isempty(Cn.first)
    Cn.first = p;
    obj.FigureCorners = Cn;
    if isempty(O.band) || ~isvalid(O.band)
        O.band = line(O.axes, p(1), p(2), 'Color', [0.05 0.45 0.95], 'LineWidth', 1.5, 'LineStyle', '--', ...
            'Tag', 'arrangeBand', 'HitTest', 'off', 'PickableParts', 'none', 'Clipping', 'off');
        obj.FigureArrangeOverlay = O;
    end
    set(O.band, 'XData', p(1), 'YData', p(2));
    arrangeCues(obj, [p 0 0], g);   % the corner's alignment lines and where it is
    obj.Fig.WindowButtonMotionFcn = @(~, ~) follow(obj);
    obj.setStatus("Now click the opposite corner (Esc cancels).");
    return
end
a = Cn.first;
rect = [min(a, p), abs(p - a)];
rect(3:4) = min(rect(3:4), 1 - rect(1:2));
if any(rect(3:4) < 0.02)
    obj.setStatus("Too small: click the opposite corner farther from the first (Esc cancels).");
    return
end
what = Cn.what;
payload = Cn.payload;
obj.cancelArrange("");   % back to plain Arrange: the pointer, the window's callbacks, the boxes free
switch what
    case "set"
        k = obj.SelectedFigure;
        if k < 1 || k > numel(obj.Config.Figures); return; end
        cfg = obj.gatherConfig();
        j = find([cfg.Figures(k).panels.id] == id, 1);
        if isempty(j)
            obj.setStatus("Set corners: " + id + " is gone.");
            return
        end
        cfg.Figures(k).panels(j).rect = rect;
        [pageCm, dpi] = figurePage(obj);
        commitFigureEdit(obj, cfg, id + ": " + rectText(rect, obj.FigureRectUnits, pageCm, dpi) + ".", Action="Set corners");
    otherwise   % a new panel, or a saved figure's block, at the rect
        o = payload;
        if ~isstruct(o); o = struct(); end
        o.Where = "rect";
        o.Rect = rect;
        args = namedargs2cell(o);
        obj.onNewPanel(args{:});
end
end


function [p, g] = snapCorner(obj, p, id)
%snapCorner  A corner snapped as Arrange snaps (snapRect, a point): to the other panels' edges and the page's, else the grid; G its cues.
C = arrangeContext(obj, id);
others = zeros(0, 4);
if ~isempty(C); others = C.others; end
if isempty(C) || ~obj.FigureSnap || C.alt
    [~, g] = snapRect([p 0 0], [], others, [0 0], [0 0]);
    return
end
[q, g] = snapRect([p 0 0], [], C.others, C.step, C.tol, Names=C.names);
p = q(1:2);
end


function follow(obj)
%follow  The pointer moved while the second corner is awaited: the dashed rectangle from the first corner to it.
if ~isvalid(obj) || obj.FigureArrangeMode ~= "corners" || ~isstruct(obj.FigureCorners) || isempty(obj.FigureCorners.first); return; end
[p, inside] = pageAtPointer(obj);
if ~inside; return; end
id = "";
if obj.FigureCorners.what == "set"; id = string(obj.FigureCorners.payload); end
band(obj, obj.FigureCorners.first, snapCorner(obj, p, id));
end


function band(obj, a, p)
%band  The dashed rectangle between the corners A and P, and the readout of the second.
O = obj.FigureArrangeOverlay;
if ~isstruct(O) || isempty(O.band) || ~isvalid(O.band); return; end
set(O.band, 'XData', [a(1) p(1) p(1) a(1) a(1)], 'YData', [a(2) a(2) p(2) p(2) a(2)]);
r = [min(a, p), abs(p - a)];
[~, g] = snapRect([p 0 0], [], zeros(0, 4), [0 0], [0 0]);   % the cues' shape, with none of them
g.mode = "resize";   % the readout: the rect's size, by the corner the pointer is at
g.rect = r;
g.moved = [p(1) < a(1), p(1) >= a(1); p(2) < a(2), p(2) >= a(2)];
arrangeCues(obj, r, g);
end
