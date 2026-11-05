function autoFigurePreview(obj)
%autoFigurePreview  Redraw the figure preview when the Figures tab shows and the redraw fits under the Auto slider's limit.
%   Called after an edit of the figure, the defaults or the dataset; when it
%   does not redraw, a drawn preview is marked out of date
%   (setFigurePreviewState "stale"). The Auto slider (FigureAutoSlider,
%   0 to 1) gives the limit (autoRedrawLimit): 0 is off, 1 redraws after
%   every edit, and between, an edit redraws while the time it is
%   predicted to take is under AutoRedrawScale * T / (1 - T) s (2 s at
%   the default 0.5). The prediction (previewCost) is the drawing's time
%   alone for an edit of the looks (the runner reuses the data it
%   computed), the compute's and the drawing's for an edit of the data, as
%   the figure's last preview took them; 0 for a figure not timed yet.
%   A canceled or failed preview waits for the Preview button
%   (FigurePreviewSeconds is Inf then), whatever the slider says.
%   An edit of text alone -- a panel's x or y label or title, the figure's
%   title -- is set on the drawn preview instead (inPlaceFigurePreview:
%   nothing computed, no busy card, no panel drawn again), when it is
%   current but for that edit; with Auto on, that is done whatever its
%   limit.
%   A redraw whose data the runner holds already (Undo and Redo, an edit
%   of the looks, a panel removed) is drawn from them with no busy card,
%   the panels the edit left alone kept (quickFigurePreview); else it is
%   computed and drawn with the card (refreshFigurePreview).
%   A session figure (sessions.enabled) is not redrawn on an edit: it
%   computes every session, so it waits for Preview (or a pick in the
%   observation list); the status line says so. The figure tree's marks
%   follow every call (markFigureTree): an edit of the defaults or another
%   dataset can put other figures' kept previews out of date too.
%
%   See also autoRedrawLimit, previewCost, refreshFigurePreview.
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
limit = autoRedrawLimit(obj);
auto = ~isempty(obj.Tabs) && obj.Tabs.SelectedTab == obj.TabFigures && limit > 0;
if auto && inPlaceFigurePreview(obj)   % text alone changed: set on the drawing, whatever Auto's limit
    markFigureTree(obj);
    return
end
if ~auto || previewCost(obj) >= limit
    if obj.FigurePreviewState == "drawn"; obj.setFigurePreviewState("stale"); end
    markFigureTree(obj);   % the other figures' previews too (another dataset, the defaults)
    return
end
if quickFigurePreview(obj)   % all of it in the runner's cache: drawn with no busy card, the panels left alone kept
    markFigureTree(obj);
    return
end
obj.refreshFigurePreview();
markFigureTree(obj);
end
