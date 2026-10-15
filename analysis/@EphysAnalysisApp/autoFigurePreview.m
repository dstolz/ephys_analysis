function autoFigurePreview(obj)
%autoFigurePreview  Redraw the figure preview when the Figures tab shows, Auto is on and the last one was quick.
%   Called after an edit of the figure, the defaults or the dataset; when it
%   does not redraw, a drawn preview is marked out of date
%   (setFigurePreviewState "stale"). A canceled or failed preview waits for
%   the Preview button (FigurePreviewSeconds is Inf then). The limit is
%   FigureAutoPreviewSeconds (AutoPreviewSeconds, 2 s; a test raises it so
%   a loaded machine does not leave its previews out of date).
if isempty(obj.Tabs) || obj.Tabs.SelectedTab ~= obj.TabFigures ...
        || ~obj.FigureAutoCheckBox.Value || obj.FigurePreviewSeconds >= obj.FigureAutoPreviewSeconds
    if obj.FigurePreviewState == "drawn"; obj.setFigurePreviewState("stale"); end
    return
end
obj.refreshFigurePreview();
end
