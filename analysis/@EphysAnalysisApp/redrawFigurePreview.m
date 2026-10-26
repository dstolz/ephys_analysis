function ok = redrawFigurePreview(obj)
%redrawFigurePreview  Draw the preview's computed figure again with the figure as it is now, computing nothing.
%   OK = redrawFigurePreview(OBJ) is for an edit that changes how the
%   figure is drawn but not what it is computed from -- its size
%   (onFigureSizeEdited) -- while the preview is drawn: the result it
%   holds (FigurePreviewResult) is rendered again into the container
%   (renderFigure, as refreshFigurePreview calls it), the selected panel
%   outlined again, and the preview marked current (FigurePreviewDrawn).
%   OK is false, and nothing is done, when there is no drawn preview of
%   the selected figure to draw again (not drawn, a session figure, the
%   preview busy): the caller leaves it to autoFigurePreview.
%
%   See also onFigureSizeEdited, refreshFigurePreview, previewScale.
ok = false;
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
F = obj.FigurePreviewResult;
if obj.FigurePreviewState ~= "drawn" || isempty(F) || ~isfield(F, 'id') || string(F.id) ~= obj.Config.Figures(k).id; return; end
if obj.Config.Figures(k).sessions.enabled; return; end
spec = obj.Config.figureFor(k);
spec.enabled = true;
obj.fitFigureViews();
try
    renderFigure(F, spec, obj.FigurePreviewPanel, Scale=previewScale(obj, spec), OnRemember=@(rules) obj.rememberFigureAesthetics(spec.id, rules), ...
        OnGoto=@(role, panel) obj.gotoFigureSetting(spec.id, role, panel), ...
        OnAxisEdit=@(panel, change) obj.onFigureAxisEdited(spec.id, panel, change), ...
        OnSelect=@(panel, ctrl) obj.onFigurePanelClicked(spec.id, panel, ctrl, false));
catch ME
    obj.log(spec.id + " could not be drawn again: " + string(ME.message));
    return
end
obj.markFigurePanel();
obj.FigurePreviewDrawn = figureViewKey(obj, k);
ok = true;
end
