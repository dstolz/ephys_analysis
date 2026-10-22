function [tf, look] = figureViewFresh(obj, k)
%figureViewFresh  Whether figure K's kept preview is the figure as it is now; LOOK says how the tree shows it.
%   [TF, LOOK] = figureViewFresh(OBJ, K) (K: SelectedFigure by default)
%   looks at the figure's container (FigureViews by its id; the
%   FigurePreview* properties for the one shown): TF is true when it is
%   drawn and was drawn with the key the figure has now (figureViewKey).
%   LOOK (markFigureTree) is
%     "fresh"   drawn and current
%     "stale"   drawn from another key, or Out of date, canceled, waiting
%               for Preview, computing or drawing
%     "failed"  the preview failed
%     "none"    not drawn: no container (never shown, or dropped by the
%               cap), nothing to draw yet (idle), or the dataset cannot
%               draw it (skipped)
%
%   See also figureViewKey, markFigureTree, previewFigureView.
if nargin < 2; k = obj.SelectedFigure; end
tf = false;
look = "none";
if k < 1 || k > numel(obj.Config.Figures); return; end
id = obj.Config.Figures(k).id;
if id == obj.FigureViewId
    state = obj.FigurePreviewState;
    drawn = obj.FigurePreviewDrawn;
else
    V = obj.FigureViews;
    if isempty(V); return; end
    i = find([V.Id] == id, 1);
    if isempty(i); return; end
    state = V(i).State;
    drawn = V(i).Drawn;
end
switch state
    case "drawn"
        tf = ~isempty(drawn) && isequaln(drawn, figureViewKey(obj, k));
        look = "stale";
        if tf; look = "fresh"; end
    case "failed"
        look = "failed";
    case {"idle" "skipped"}
        look = "none";
    otherwise
        look = "stale";
end
end
