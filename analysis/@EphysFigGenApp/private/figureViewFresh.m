function [tf, look, page] = figureViewFresh(obj, k)
%figureViewFresh  Whether figure K's kept preview is the figure as it is now; LOOK says how the tree shows it.
%   [TF, LOOK, PAGE] = figureViewFresh(OBJ, K) (K: SelectedFigure by default)
%   looks at the figure's container (FigureViews by its id; the
%   FigurePreview* properties for the one shown): TF is true when it is
%   drawn and was drawn with the key the figure has now (figureViewKey).
%   PAGE is true when it is drawn with that key but for its page alone
%   (figureViewKey's page: the Export tab's page changed since): what it
%   holds is the figure as it is now, laid out on the old page, so it is
%   drawn again on the new one from what it holds, nothing computed
%   (previewFigureView: redrawFigurePreview Page=true).
%   LOOK (markFigureTree) is
%     "fresh"   drawn and current
%     "stale"   drawn from another key, or Out of date, canceled, waiting
%               for Preview, computing or drawing
%     "failed"  the preview failed
%     "none"    not drawn: no container (never shown, or dropped by the
%               cap), nothing to draw yet (idle), or the dataset cannot
%               draw it (skipped)
%   It is the one test of a drawing being current: the preview's tails
%   (finishPreview: Drawn or Out of date), markStaleDrawing, the tree,
%   a switch back (previewFigureView), and what reads the drawing --
%   Open in window, Export preview, Save look as design, Forget looks
%   (onOpenFigureWindow, onExportPreview, onSaveDesign) -- read it, not
%   the badge alone.
%
%   See also figureViewKey, markFigureTree, previewFigureView, finishPreview.
if nargin < 2; k = obj.SelectedFigure; end
tf = false;
look = "none";
page = false;
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
        key = figureViewKey(obj, k);
        tf = ~isempty(drawn) && isequaln(drawn, key);
        look = "stale";
        if tf; look = "fresh"; end
        if ~tf && nargout > 2 && isstruct(drawn) && isfield(drawn, 'page') && isstruct(key)
            page = isequaln(rmfield(drawn, 'page'), rmfield(key, 'page'));   % the figure as it is now, on another page
        end
    case "failed"
        look = "failed";
    case {"idle" "skipped"}
        look = "none";
    otherwise
        look = "stale";
end
end
