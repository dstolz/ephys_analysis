function markStaleDrawing(obj)
%markStaleDrawing  The shown preview, when its badge says Drawn but the drawing is not the figure as it is now, says Out of date.
%   markStaleDrawing(OBJ) sets the badge to Out of date
%   (setFigurePreviewState "stale") when it says Drawn and the key the
%   drawing was made from (FigurePreviewDrawn) is no longer the selected
%   figure's (figureViewFresh: figureViewKey); else it changes nothing.
%   For a change that draws nothing: an edit or an observation picked
%   while a run goes (refreshFigurePreview computes nothing then), a look
%   remembered on a drawing that was not current
%   (rememberFigureAesthetics), other figures edited (onApplyToFigures).
%
%   See also figureViewFresh, figureViewKey, setFigurePreviewState.
if obj.FigurePreviewState == "drawn" && ~figureViewFresh(obj)
    obj.setFigurePreviewState("stale");
end
end
