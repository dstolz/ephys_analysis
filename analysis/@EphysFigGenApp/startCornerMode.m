function ok = startCornerMode(obj, what, payload)
%startCornerMode  Set corners: wait for two clicks on the preview, the corners of a panel's rect, then place what WHAT says there.
%   OK = startCornerMode(OBJ, WHAT, PAYLOAD), WHAT:
%     "set"    the selected panel takes the rect ("Set corners": Set
%              corners in the Layout section, a box's right-click menu)
%     "new"    a new panel: PAYLOAD holds onNewPanel's options (Type,
%              Id, Title, Options, ...: New panel's "Draw it on the
%              preview (two clicks)"), placed at the rect as Where "rect"
%     "block"  a saved figure's panels as one block: PAYLOAD holds
%              onNewPanel's Set, Alignment, ...
%   The preview must show the selected figure (previewShowsFigure);
%   Arrange is switched on when it is off (onArrangeToggled). Then the
%   boxes are locked (arrangeWidgetLock), the pointer is a crosshair and
%   the status bar says "Click the first corner (Esc cancels)."; the
%   window's pointer callbacks are kept (FigureDrag) to come back after.
%   The first click on the page (onArrangeClicked: cornerClick) is one
%   corner, a dashed rectangle follows the pointer from it, the second is
%   the opposite corner. Escape (onKeyPress, any tab) or a click off the
%   page cancels (cancelArrange). OK is false when it could not start
%   (the status bar says why).
%
%   See also EphysFigGenApp.onSetCorners, EphysFigGenApp.onNewPanel, cornerClick,
%   EphysFigGenApp.cancelArrange.
arguments
    obj (1,1) EphysFigGenApp
    what (1,1) string {mustBeMember(what, ["set" "new" "block"])}
    payload = []
end
ok = false;
if obj.FigureArrangeMode ~= ""; obj.cancelArrange(""); end
k = obj.SelectedFigure;
if ~previewShowsFigure(obj)
    msg = "Preview the figure first; Arrange switches on.";
    if k >= 1 && k <= numel(obj.Config.Figures) && obj.Config.Figures(k).probe.enabled
        msg = "Arrange is off for a probe figure: its panels are drawn in every tile.";
    end
    obj.setStatus(msg);
    return
end
fig = obj.Config.Figures(k);
if what == "set"
    j = obj.SelectedPanel;
    if j < 1 || j > numel(fig.panels)
        obj.setStatus("Set corners: select a panel first.");
        return
    end
    payload = fig.panels(j).id;
end
if ~obj.FigureArrange
    b = obj.FigureArrangeButton;
    if isempty(b) || ~isvalid(b); return; end
    b.Value = true;
    obj.onArrangeToggled();
    if ~obj.FigureArrange; return; end   % (no license: it said so)
end
if ~obj.syncArrangeOverlay(); return; end
obj.FigureCorners = struct('what', what, 'payload', {payload}, 'first', []);
obj.FigureDrag = struct('oldMotion', {obj.Fig.WindowButtonMotionFcn}, 'oldDown', {obj.Fig.WindowButtonDownFcn});
obj.FigureArrangeMode = "corners";
O = obj.FigureArrangeOverlay;
for w = [O.widgets.values {O.legend}]
    if ~isempty(w{1}); arrangeWidgetLock(w{1}, true); end
end
obj.Fig.WindowButtonDownFcn = @(~, ~) offPage(obj);
obj.Fig.Pointer = "crosshair";
switch what
    case "set",   obj.setStatus("Set corners of " + payload + ": click the first corner (Esc cancels).");
    otherwise,    obj.setStatus("Draw the new panel: click the first corner (Esc cancels).");
end
ok = true;
end


function offPage(obj)
%offPage  A click while Set corners waits: off the page it cancels (on it, the overlay or a box takes it: cornerClick).
if ~isvalid(obj) || obj.FigureArrangeMode ~= "corners"; return; end
[~, inside] = pageAtPointer(obj);
if ~inside; obj.cancelArrange("Set corners canceled: the click was off the page; the figure is unchanged."); end
end
