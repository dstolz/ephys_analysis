function onArrangeMoving(obj, id, evt, alt)
%onArrangeMoving  A step of a drag of a panel's box over the preview (Arrange): the box snapped, the smart guides, the rect's fields; the figure untouched.
%   onArrangeMoving(OBJ, ID, EVT) is the MovingROI listener of panel ID's
%   widget (arrangeWidget; ID ":legend" for the floating legend's box).
%   EVT.CurrentPosition is where the pointer put the box, [x y width
%   height] 0-1 of the page; the rect the figure holds tells a move (same
%   size) from a resize (the edges dragged). With Snap on (FigureSnap) and
%   Alt not held the box snaps (private/snapRect): moved, to the other
%   panels' edges (aligned or abutting), their centers and the page's,
%   the page's edges, an equal spacing, else the snap step's grid; resized,
%   only the dragged edges, to edges, an equal size, else the grid. The
%   box is set there and the panel's drawn parts go with it (its axes,
%   note band, color bars, the legend in a legend panel; the floating
%   legend with its box: arrangeParts, arrangePartsAt, their places
%   shifted or scaled with the box, nothing measured or laid out), the
%   smart guides are drawn for it (private/arrangeCues: alignment lines,
%   distances, equal spacing and size, a readout by the corner), and the
%   Position and Size fields show it (when it is the selected panel's).
%   The figure takes the rect when the drag ends (onArrangeMoved), and
%   the preview is laid out exactly then.
%   The first step of a drag selects the panel (when the click did not)
%   and notes the drag (FigureArrangeMode "drag"); after Escape
%   (cancelArrange) the box stays where it was until the drag ends.
%   onArrangeMoving(OBJ, ID, EVT, ALT): ALT true or false in place of the
%   window's CurrentModifier (the tests).
%
%   See also EphysFigGenApp.onArrangeMoved, EphysFigGenApp.syncArrangeOverlay, snapRect, arrangeCues.
arguments
    obj (1,1) EphysFigGenApp
    id (1,1) string
    evt
    alt = []
end
mode = obj.FigureArrangeMode;
if mode == "corners"; return; end
C = arrangeContext(obj, id);
if isempty(C) || isempty(C.w) || ~isvalid(C.w); return; end
if mode == "canceled"   % Escape: the box stays put until the drag ends
    arrangeWidgetSet(C.w, C.rect0);
    return
end
if mode ~= "drag"
    obj.FigureArrangeMode = "drag";
    obj.FigureArrangeFocus = true;
    if C.j > 0 && C.j ~= obj.SelectedPanel
        obj.onPanelSelected(C.j);   % (its fields then show this panel)
        C = arrangeContext(obj, id);
        if isempty(C) || isempty(C.w) || ~isvalid(C.w); return; end
    end
    obj.FigureDrag = struct('id', id, 'parts', {arrangeParts(obj, id, C.rect0)});   % what moves with the box
end
if ~isempty(alt); C.alt = logical(alt); end
raw = double(reshape(evt.CurrentPosition, 1, 4));
if obj.FigureSnap && ~C.alt
    [rect, g] = snapRect(raw, C.rect0, C.others, C.step, C.tol, Names=C.names);
else
    [rect, g] = snapRect(raw, C.rect0, C.others, [0 0], [0 0], Names=C.names);   % only the cues
end
arrangeWidgetSet(C.w, rect);
D = obj.FigureDrag;
if isstruct(D) && isfield(D, 'parts') && ~isempty(D.parts)   % the panel's plots go with it (exact once released)
    pg = obj.FigureArrangeOverlay.axes.Position;
    arrangePartsAt(D.parts, [pg(1:2) + rect(1:2) .* pg(3:4), rect(3:4) .* pg(3:4)]);
end
arrangeCues(obj, rect, g);
if C.j > 0 && C.j == obj.SelectedPanel; showRect(obj, rect, C); end
end


function showRect(obj, rect, C)
%showRect  The Position and Size fields showing RECT in the Panels section's units (no callback runs).
E = obj.FigureEditor;
if ~isfield(E, 'rectX') || ~isvalid(E.rectX); return; end
was = obj.Applying;
obj.Applying = true;
restore = onCleanup(@() setApplying(obj, was));
v = unitsShown(rect, "normalized", obj.FigureRectUnits, C.pageCm, C.dpi, "rect");
F = [E.rectX E.rectY E.rectW E.rectH];
for i = 1:4
    if F(i).Value ~= v(i); F(i).Value = v(i); end   % (only what changed: each set is a round trip to the window)
end
end


function setApplying(obj, tf)
if isvalid(obj); obj.Applying = tf; end
end
