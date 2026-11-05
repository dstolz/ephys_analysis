function onArrangeMoved(obj, id, evt)
%onArrangeMoved  A drag of a panel's box over the preview ended (Arrange): the panel takes the rect, one step of the undo history.
%   onArrangeMoved(OBJ, ID, EVT) is the ROIMoved listener of panel ID's
%   widget (arrangeWidget). The smart guides go, and the selected panels'
%   size labels come back (arrangeSizeLabels); EVT.CurrentPosition is
%   snapped again as during the drag (onArrangeMoving: the box may report
%   where the pointer left it rather than where it was snapped to), kept
%   on the page with a width and height of at least 0.01, and set as the
%   panel's rect (commitFigureEdit, "Move panel" or "Resize panel": one
%   undo step per drag). The status bar says where the panel is now ("Moved psth_1:
%   9.0 x 6.0 cm at 0, 6."). A drag that leaves the rect as it was changes
%   nothing (a release with no step of a drag before it, where it started,
%   is not snapped either); one Escape canceled (cancelArrange) puts the
%   box back.
%   The panel's plots, moved along during the drag (onArrangeMoving),
%   are laid out exactly at the new rect then: commitFigureEdit with
%   Arrange (arrangedPreview) lays the preview out whatever Auto and the
%   time a preview takes, and draws it again only when the move changes
%   which panels touch which and Auto may (else it is marked out of
%   date: "Laid out; press Preview ..."). A drag that ends where it
%   began puts them back.
%   With several panels selected (Shift+click) the others take the same
%   shift, or the same change of size about the same edges (arrangeGroup,
%   on the dragged one's snapped rect), in the same undo step, "Move
%   panels" or "Resize panels".
%   A press that selected the box (selectLightly: FigureSelectPending)
%   has the editor's rows filled now, however the drag ends
%   (finishPendingSelect; a move's commitFigureEdit fills them itself).
%   ID ":legend", the floating legend's box (dragged or resized, or its
%   menu's Make it a legend panel here, EVT []): a legend panel is added
%   at the box (onNewPanel, Type "legend", Where "rect": "Add panel"), so
%   the legend stays where it was put.
%
%   See also EphysFigGenApp.onArrangeMoving, EphysFigGenApp.syncArrangeOverlay, commitFigureEdit.
arguments
    obj (1,1) EphysFigGenApp
    id (1,1) string
    evt = []
end
mode = obj.FigureArrangeMode;
if mode == "corners"; return; end
obj.FigureArrangeMode = "";
labels = onCleanup(@() arrangeSizeLabels(obj));   % the selected panels' sizes back, at their rects as they end up
D = obj.FigureDrag;
obj.FigureDrag = [];
parts = [];   % the panel's drawn parts the drag moved (onArrangeMoving)
if isstruct(D) && isfield(D, 'parts'); parts = D.parts; end
G = struct('id', {}, 'rect0', {}, 'w', {}, 'parts', {});   % the others selected, moved along
if isstruct(D) && isfield(D, 'group'); G = D.group; end
arrangeCues(obj, [], []);
C = arrangeContext(obj, id);
if isempty(C) || isempty(C.w) || ~isvalid(C.w)
    finishPendingSelect(obj);
    return
end
if mode == "canceled"
    arrangeWidgetSet(C.w, C.rect0);
    for i = 1:numel(G); arrangeWidgetSet(G(i).w, G(i).rect0); end
    finishPendingSelect(obj, "");   % (Escape filled the rows already: cancelArrange)
    return
end
if ~isempty(G)   % (not snapped to the panels that move along)
    keep = ~ismember(C.names, [G.id]);
    C.others = C.others(keep, :);
    C.names = C.names(keep);
end
obj.FigureArrangeFocus = true;
if isempty(evt)
    raw = double(C.w.Position);
else
    raw = double(reshape(evt.CurrentPosition, 1, 4));
    if mode ~= "drag" && all(abs(raw - C.rect0) < 1e-12)   % a click that moved nothing: no snap to the grid either
        arrangeWidgetSet(C.w, C.rect0);
        finishPendingSelect(obj);   % (a press that selected the box: the editor's rows now)
        return
    end
end
if obj.FigureSnap && ~C.alt
    rect = snapRect(raw, C.rect0, C.others, C.step, C.tol, Names=C.names);
else
    rect = raw;
end
rect(3:4) = min(max(rect(3:4), 0.01), 1);
rect(1:2) = min(max(rect(1:2), 0), 1 - rect(3:4));
R = zeros(0, 4);
if ~isempty(G); [rect, R] = arrangeGroup(C.rect0, rect, vertcat(G.rect0)); end
u = obj.FigureRectUnits;
if id == ":legend"
    finishPendingSelect(obj, "");   % (before the editor is read back)
    obj.onNewPanel(Type="legend", Where="rect", Rect=rect);
    return
end
if all(abs(rect - C.rect0) < 1e-12)
    arrangeWidgetSet(C.w, C.rect0);
    if ~isempty(parts); arrangePartsAt(parts, parts.box0); end   % back where they were drawn
    for i = 1:numel(G)
        arrangeWidgetSet(G(i).w, G(i).rect0);
        if ~isempty(G(i).parts); arrangePartsAt(G(i).parts, G(i).parts.box0); end
    end
    finishPendingSelect(obj, "");   % (a press that selected the box: the editor's rows now)
    showPanelPlace(obj);
    obj.setStatus(id + " is where it was.");
    return
end
resize = any(abs(rect(3:4) - C.rect0(3:4)) > 1e-9);
cfg = obj.Config;   % the config as it is, the rects alone changed (the editor's fields showed the drag, not an edit)
cfg.Figures(C.k).panels(C.j).rect = rect;
ids = [cfg.Figures(C.k).panels.id];
for i = 1:numel(G)
    q = find(ids == G(i).id, 1);
    if ~isempty(q); cfg.Figures(C.k).panels(q).rect = R(i, :); end
end
if resize
    [action, verb] = deal("Resize panel", "Resized ");
else
    [action, verb] = deal("Move panel", "Moved ");
end
if isempty(G)
    msg = verb + id + ": " + rectText(rect, u, C.pageCm, C.dpi) + ".";
else
    action = action + "s";
    msg = verb + strjoin([id G.id], ", ") + " (" + (numel(G) + 1) + " panels); " + id + ": " + rectText(rect, u, C.pageCm, C.dpi) + ".";
end
commitFigureEdit(obj, cfg, msg, Action=action, Arrange=true);
end
