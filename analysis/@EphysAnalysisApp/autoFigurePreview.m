function autoFigurePreview(obj)
%autoFigurePreview  Redraw the figure preview when the Figures tab shows, Auto is on and the last one was quick.
%   Called after an edit of the figure, the defaults or the dataset; when it
%   does not redraw, a drawn preview is marked out of date
%   (setFigurePreviewState "stale"). A canceled or failed preview waits for
%   the Preview button (FigurePreviewSeconds is Inf then). The limit is
%   FigureAutoPreviewSeconds (AutoPreviewSeconds, 2 s; a test raises it so
%   a loaded machine does not leave its previews out of date).
%   An edit of text alone -- a panel's x or y label or title, the figure's
%   title -- is set on the drawn preview instead (inPlaceFigurePreview:
%   nothing computed, no busy card, no panel drawn again), when it is
%   current but for that edit; with Auto on, that is done whatever the
%   last preview took.
%   A session figure (sessions.enabled) is not redrawn on an edit: it
%   computes every session, so it waits for Preview (or a pick in the
%   observation list); the status line says so. The figure tree's marks
%   follow every call (markFigureTree): an edit of the defaults or another
%   dataset can put other figures' kept previews out of date too.
k = obj.SelectedFigure;
if k >= 1 && k <= numel(obj.Config.Figures) && obj.Config.Figures(k).sessions.enabled
    clearSessionFigurePreview(obj);   % the kept figures were computed before this edit
    if obj.FigurePreviewState == "drawn"; obj.setFigurePreviewState("stale"); end
    if ~isempty(obj.FigurePreviewLabel) && ~ismember(obj.FigurePreviewState, ["computing" "drawing"])
        obj.FigurePreviewLabel.Text = "A figure across sessions computes every session: press Preview to draw it.";
    end
    markFigureTree(obj);
    return
end
auto = ~isempty(obj.Tabs) && obj.Tabs.SelectedTab == obj.TabFigures && obj.FigureAutoCheckBox.Value;
if auto && inPlaceFigurePreview(obj)   % text alone changed: set on the drawing, however long the last preview took
    markFigureTree(obj);
    return
end
if ~auto || obj.FigurePreviewSeconds >= obj.FigureAutoPreviewSeconds
    if obj.FigurePreviewState == "drawn"; obj.setFigurePreviewState("stale"); end
    markFigureTree(obj);   % the other figures' previews too (another dataset, the defaults)
    return
end
obj.refreshFigurePreview();
markFigureTree(obj);
end
