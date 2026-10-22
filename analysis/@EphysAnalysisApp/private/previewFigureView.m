function previewFigureView(obj, opts)
%previewFigureView  The figure just shown (syncFigureView): its kept preview as it is when still current, else drawn again.
%   previewFigureView(OBJ) leaves the shown container alone when its
%   preview is current (figureViewFresh: drawn, with the key of the figure
%   as it is now: figureViewKey); else it is drawn as after an edit
%   (autoFigurePreview: at once while Auto is on and the Figures tab
%   shows, else marked Out of date), its last preview's time forgotten
%   first (a figure shown is drawn even when its last preview was slow).
%   Switched=false (Undo or Redo of the shown figure's own edit) keeps
%   that time, as an edit does. While a preview computes nothing is done:
%   refreshFigurePreview shows the selected figure and calls this when it
%   is done.
%
%   See also syncFigureView, figureViewFresh, autoFigurePreview.
arguments
    obj (1,1) EphysAnalysisApp
    opts.Switched (1,1) logical = true
end
if ismember(obj.FigurePreviewState, ["computing" "drawing"]); return; end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures)
    obj.refreshFigurePreview();   % no figure: the panel and the badge say so
    return
end
if figureViewFresh(obj); return; end
if opts.Switched; obj.FigurePreviewSeconds = 0; end
obj.autoFigurePreview();
end
