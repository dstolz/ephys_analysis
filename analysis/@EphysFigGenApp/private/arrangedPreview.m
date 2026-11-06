function arrangedPreview(obj, msg, opts)
%arrangedPreview  The preview after Arrange placed a panel (a drag released, an arrow key, Set corners): the drawing moved in place at once, never drawn again while Arrange is on.
%   arrangedPreview(OBJ, MSG) is what commitFigureEdit does in place of
%   autoFigurePreview for an edit of the panels' rects made in Arrange
%   (Arrange=true), and it says MSG in the status bar after (commitFigureEdit
%   leaves it here, so a release paints once). The preview shows the
%   figure (previewShowsFigure) and
%   the drawing there is laid out at the new rects whatever Auto, the
%   time a redraw would take (previewCost) and the badge say, and only
%   the panels that moved are laid out (PlaceMoved: their neighbors keep
%   their places unless a shared edge moves them; nothing else is
%   measured):
%     - drawn, and only the places changed: laid out in place and current
%       (inPlaceFigurePreview: renderFigure's in-place path)
%     - drawn, and the move changes which panels touch which (a time
%       stack's labels) or the top-left panel, so a whole drawing would be
%       due: the panels are laid out at the new places all the same
%       (renderFigure LayoutOnly), nothing drawn or dressed again; the
%       preview is out of date (badge Out of date), FigureArrangeDirty is
%       set, and the status bar says MSG and "Laid out; the labels follow
%       when Arrange is off." Arrange off draws it again when Auto may
%       (onArrangeToggled).
%     - out of date already (an edit Auto did not draw, a slow preview):
%       laid out at the new places all the same (LayoutOnly); it stays out
%       of date, FigureArrangeDirty set, the status bar saying so
%   A session figure is left to autoFigurePreview (its preview is drawn
%   across the sessions: it waits for Preview); so is a preview of
%   anything else. The figure tree's marks follow (markFigureTree).
%
%   arrangedPreview(OBJ, MSG, RectsOnly=true): the edit set the rects
%   alone (commitFigureEdit's onlyRects), so the in-place layout compares
%   nothing else (inPlaceFigurePreview RectsOnly).
%
%   See also commitFigureEdit, inPlaceFigurePreview, layoutPreview, onArrangeToggled, renderFigure.
arguments
    obj (1,1) EphysFigGenApp
    msg (1,1) string
    opts.RectsOnly (1,1) logical = false
end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures) || obj.Config.Figures(k).sessions.enabled || ~previewShowsFigure(obj)
    if msg ~= ""; obj.setStatus(msg); end
    obj.markFigurePanel();   % (the boxes at the new rects)
    obj.autoFigurePreview();
    return
end
state0 = obj.FigurePreviewState;
if state0 == "drawn" && inPlaceFigurePreview(obj, PlaceMoved=true, RectsOnly=opts.RectsOnly)   % only the places changed: laid out in place, current
    markFigureTree(obj);
    if msg ~= ""; obj.setStatus(msg); end
    return
end
spec = [];
if opts.RectsOnly; spec = drawnSpecAt(obj); end   % (the spec drawn, at the new rects: nothing else is read)
laid = layoutPreview(obj, spec, PlaceMoved=true);   % the labels as drawn: dressed again once Arrange is off
if ~laid; obj.markFigurePanel(); end   % (laid out, the panel is marked there: the boxes at the new rects)
obj.FigureArrangeDirty = true;
if state0 == "drawn"; obj.setFigurePreviewState("stale"); end
markFigureTree(obj);
if laid; msg = strtrim(msg + " Laid out; the labels follow when Arrange is off."); end
if msg ~= ""; obj.setStatus(msg); end   % (the one paint of the release)
end
