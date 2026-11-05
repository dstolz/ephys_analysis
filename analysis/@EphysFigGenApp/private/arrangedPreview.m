function arrangedPreview(obj, msg)
%arrangedPreview  The preview after Arrange placed a panel (a drag released, an arrow key, Set corners): laid out at the new rects at once, drawn again only when it must and may.
%   arrangedPreview(OBJ, MSG) is what commitFigureEdit does in place of
%   autoFigurePreview for an edit of the panels' rects made in Arrange
%   (Arrange=true). The preview shows the figure (previewShowsFigure) and
%   the drawing there is laid out at the new rects whatever Auto, the
%   time a redraw would take (previewCost) and the badge say:
%     - drawn, and only the places changed: laid out in place and current
%       (inPlaceFigurePreview: renderFigure's in-place path)
%     - drawn, and the move changes which panels touch which (a time
%       stack's labels) or the top-left panel, so a whole drawing is due:
%       laid out at the new places first (renderFigure LayoutOnly, nothing
%       drawn); then, with Auto on and the drawing quick enough (previewCost
%       under autoRedrawLimit), drawn again (refreshFigurePreview);
%       else marked out of date and the status bar says MSG and "Laid
%       out; press Preview (or switch Arrange off) to redraw the labels."
%     - out of date already (an edit Auto did not draw, a slow preview):
%       laid out at the new places all the same (LayoutOnly); it stays out
%       of date, the status bar saying so
%   A session figure is left to autoFigurePreview (its preview is drawn
%   across the sessions: it waits for Preview); so is a preview of
%   anything else. The figure tree's marks follow (markFigureTree).
%
%   See also commitFigureEdit, inPlaceFigurePreview, autoFigurePreview, renderFigure.
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures) || obj.Config.Figures(k).sessions.enabled || ~previewShowsFigure(obj)
    obj.autoFigurePreview();
    return
end
state0 = obj.FigurePreviewState;
if state0 == "drawn" && inPlaceFigurePreview(obj)   % only the places changed: laid out in place, current
    markFigureTree(obj);
    return
end
laid = layoutPreview(obj);
note = " Laid out; press Preview (or switch Arrange off) to redraw the labels.";
if state0 == "drawn"   % a whole drawing is due: the panels touch others now, or another one is top-left
    limit = autoRedrawLimit(obj);
    auto = ~isempty(obj.Tabs) && obj.Tabs.SelectedTab == obj.TabFigures && limit > 0;
    if auto && previewCost(obj) < limit   % (a place is a look: the drawing's time)
        obj.refreshFigurePreview();
        markFigureTree(obj);
        return
    end
    obj.setFigurePreviewState("stale");
end
if laid; obj.setStatus(strtrim(msg + note)); end
markFigureTree(obj);
end
