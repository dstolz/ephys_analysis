function previewFigureView(obj, opts)
%previewFigureView  The figure just shown (syncFigureView): its kept preview as it is when still current, else drawn again.
%   previewFigureView(OBJ) leaves the shown container alone when its
%   preview is current (figureViewFresh: drawn, with the key of the figure
%   as it is now: figureViewKey). A preview that is the figure as it is now
%   but laid out on another page (the Export tab's page changed while
%   another figure showed: figureViewFresh's PAGE) is drawn again on the
%   new page from what it holds, nothing computed, whatever Auto says, as
%   the shown figure is on that change (redrawFigurePreview Page=true; a
%   figure across sessions from its kept figures, which are not
%   forgotten). Else it is drawn as after an edit
%   (autoFigurePreview: at once while Auto is on and the Figures tab
%   shows, else marked Out of date; a figure across sessions waits for
%   Preview, its kept figures forgotten), its last preview's time
%   forgotten first (a figure shown is drawn even when its last preview
%   was slow); so is a figure across sessions on another page while a run
%   goes (redrawFigurePreview draws none then). Not when the figure was
%   canceled, failed or waits for a large signal extract (its time is Inf):
%   it is shown as it was left, its badge and line saying so, and waits for
%   Preview as after an edit (autoFigurePreview), instead of computing, and
%   failing or being canceled again, on every return.
%   Switched=false (Undo or Redo of the shown figure's own edit) keeps
%   that time, as an edit does. While a preview computes nothing is done:
%   refreshFigurePreview shows the selected figure and calls this when it
%   is done.
%
%   See also syncFigureView, figureViewFresh, redrawFigurePreview, autoFigurePreview.
arguments
    obj (1,1) EphysFigGenApp
    opts.Switched (1,1) logical = true
end
if ismember(obj.FigurePreviewState, ["computing" "drawing"]); return; end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures)
    obj.refreshFigurePreview();   % no figure: the panel and the badge say so
    return
end
[fresh, ~, page] = figureViewFresh(obj);
if fresh; return; end
if page && obj.redrawFigurePreview(Page=true)   % drawn on the old page: drawn again on the new one from what it holds
    markFigureTree(obj);
    return
end
if opts.Switched && ~isinf(obj.FigurePreviewSeconds); obj.FigurePreviewSeconds = 0; end   % (Inf: it was canceled, failed or too large, and waits for Preview)
obj.autoFigurePreview();
end
