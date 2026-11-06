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
%   With several panels selected (Shift+click: selectedPanelIds) a drag of
%   any of them moves them all by the same shift, kept on the page as a
%   group, or resizes them all alike (the same edges by the same amounts:
%   arrangeGroup); the snapping and the guides are the dragged box's (the
%   others selected are not snapped to), and every selected panel's plots
%   go with its box.
%   The first step of a drag selects the panel when the click did not, as
%   a press does (selectLightly: its box blue, its fields; the editor's
%   other rows follow at the release), notes the drag (FigureArrangeMode
%   "drag"; the Position listeners on the preview's axes wait meanwhile:
%   markFigurePanel) and hides the selected panels' size labels
%   (arrangeSizeLabels) until it ends; after Escape (cancelArrange) the
%   box stays where it was until the drag ends. What a step reads that the
%   drag does not change (the rects, the page, the snap step and reach:
%   arrangeContext; the overlay's place) is read on the first step and
%   kept in FigureDrag (ctx). The box and the guides (their readout gives
%   the place and size) follow every step; the plots follow on the first
%   step and then at most every 40 ms (FigureDrag.moved), and the Position
%   and Size fields at most every quarter second (FigureDrag.fields: a
%   field's new value repaints the editor, the dearest part of a step's
%   paint); the release shows the rect in them exactly (showPanelPlace).
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
D = obj.FigureDrag;
if mode == "drag" && isstruct(D) && isfield(D, 'ctx') && D.id == id && isvalid(D.ctx.w)
    C = D.ctx;   % (read on the first step: the drag changes none of it)
    C.alt = altHeld(obj);
else
    C = arrangeContext(obj, id);
    if isempty(C) || isempty(C.w) || ~isvalid(C.w); return; end
end
if mode == "canceled"   % Escape: the box stays put until the drag ends
    arrangeWidgetSet(C.w, C.rect0);
    return
end
first = mode ~= "drag";
if first
    obj.FigureArrangeMode = "drag";
    obj.FigureArrangeFocus = true;
    arrangeClickDone(obj);   % a drag: a click on one of several selected boxes keeps them all
    stopSelectTimer(obj);   % (an earlier release's refill waits for this drag's: fillSelectLater)
    if C.j > 0 && C.j ~= obj.SelectedPanel   % (no click came first: the box dragged is the primary now)
        sel = selectedPanelIds(obj);
        if any(sel == id)
            obj.FigurePanelExtra = [sel(2:end) sel(1)];
        else
            obj.FigurePanelExtra = strings(1, 0);
        end
        selectLightly(obj, C.j);   % its box and fields now; the editor's rows after the release (fillSelectLater)
    end
    G = dragGroup(obj, id);
    if ~isempty(G)   % the others selected move along: no snapping to them
        keep = ~ismember(C.names, [G.id]);
        C.others = C.others(keep, :);
        C.names = C.names(keep);
    end
    C.pg = obj.FigureArrangeOverlay.axes.Position;   % the page on the canvas, px
    D = struct('id', id, 'parts', {arrangeParts(obj, id, C.rect0)}, 'group', G, 'ctx', C, 'moved', tic, 'fields', tic);   % what moves with the box
    obj.FigureDrag = D;
    arrangeSizeLabels(obj);   % hidden: the readout shows the size now
end
G = D.group;
if ~isempty(alt); C.alt = logical(alt); end
raw = double(reshape(evt.CurrentPosition, 1, 4));
if obj.FigureSnap && ~C.alt
    [rect, g] = snapRect(raw, C.rect0, C.others, C.step, C.tol, Names=C.names);
else
    [rect, g] = snapRect(raw, C.rect0, C.others, [0 0], [0 0], Names=C.names);   % only the cues
end
pg = C.pg;
toPx = @(r) [pg(1:2) + r(1:2) .* pg(3:4), r(3:4) .* pg(3:4)];
live = first || toc(D.moved) > 0.04;   % the plots: at most every 40 ms (exact once released)
if live && ~first
    D.moved = tic;
    obj.FigureDrag = D;
end
if ~isempty(G)   % the same shift, or the same change of size about the same edges, for each one selected
    [rect, R] = arrangeGroup(C.rect0, rect, vertcat(G.rect0));
    for i = 1:numel(G)
        arrangeWidgetSet(G(i).w, R(i, :));
        if live && ~isempty(G(i).parts); arrangePartsAt(G(i).parts, toPx(R(i, :))); end
    end
end
arrangeWidgetSet(C.w, rect);
if live && ~isempty(D.parts)   % the panel's plots go with it
    arrangePartsAt(D.parts, toPx(rect));
end
arrangeCues(obj, rect, g, PageCm=C.pageCm, Dpi=C.dpi);
if C.j > 0 && C.j == obj.SelectedPanel && (first || toc(D.fields) > 0.25)
    showRect(obj, rect, C);
    if ~first; D.fields = tic; obj.FigureDrag = D; end
end
end


function tf = altHeld(obj)
%altHeld  Alt (Option) is held now (the window's CurrentModifier): no snapping.
tf = false;
try
    tf = any(string(obj.Fig.CurrentModifier) == "alt");
catch
end
end


function G = dragGroup(obj, id)
%dragGroup  The other panels selected with the one dragged (selectedPanelIds), each with its rect, box and drawn parts as the drag starts.
G = struct('id', {}, 'rect0', {}, 'w', {}, 'parts', {});
sel = selectedPanelIds(obj);
if numel(sel) < 2 || ~any(sel == id); return; end
for o = sel(sel ~= id)
    Co = arrangeContext(obj, o);
    if isempty(Co) || isempty(Co.w) || ~isvalid(Co.w) || any(~isfinite(Co.rect0)); continue; end
    G(end+1) = struct('id', o, 'rect0', Co.rect0, 'w', Co.w, 'parts', {arrangeParts(obj, o, Co.rect0)}); %#ok<AGROW>
end
end


function showRect(obj, rect, C)
%showRect  The Position and Size fields showing RECT in the Layout section's units (no callback runs).
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
