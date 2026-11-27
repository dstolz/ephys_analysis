function ok = redrawFigurePreview(obj, opts)
%redrawFigurePreview  Draw the preview's computed figure again with the figure as it is now, computing nothing.
%   OK = redrawFigurePreview(OBJ) is for an edit that changes how the
%   figure is drawn but not what it is computed from -- its size
%   (onFigureSizeEdited), the Export tab's page it follows (onConfigChanged
%   "export"; previewFigureView for a figure shown after that change, its
%   kept preview current but for the page) -- while the preview is drawn
%   and was current before the edit (the caller checks: figureViewFresh,
%   its PAGE for previewFigureView): the result it holds
%   (FigurePreviewResult) is rendered again into the container
%   (renderFigure, as refreshFigurePreview calls it), at the new page's
%   scale (previewScale), the selected panel outlined again, and the
%   preview marked current (FigurePreviewDrawn: figureViewKey).
%   Page=true (the Export tab's page alone changed): a figure across
%   sessions is drawn again too, from its kept figures (FigureSessionResults,
%   refreshFigurePreview Redraw), their key made the figure's on the new
%   page, nothing computed.
%   OK is false, and nothing is done, when there is no drawn preview of
%   the selected figure to draw again (not drawn, a session figure without
%   Page, without kept figures or with kept figures that are not the
%   drawing's, the preview busy, a run going for a session figure): the
%   caller leaves it to autoFigurePreview.
%
%   See also onFigureSizeEdited, onConfigChanged, refreshFigurePreview, previewScale.
arguments
    obj (1,1) EphysFigGenApp
    opts.Page (1,1) logical = false
end
ok = false;
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
F = obj.FigurePreviewResult;
id = obj.Config.Figures(k).id;
if obj.FigurePreviewState ~= "drawn" || isempty(F) || ~isfield(F, 'id') || string(F.id) ~= id; return; end
if obj.Config.Figures(k).sessions.enabled
    K = obj.FigureSessionResults;
    if ~opts.Page || obj.Running || ~(isstruct(K) && isfield(K, 'res') && K.spec.id == id) || ~isequaln(K.key, obj.FigurePreviewDrawn)
        return   % (kept figures the drawing is not: a look remembered since is not in them)
    end
    obj.FigureSessionResults.key = figureViewKey(obj, k);   % the kept figures are the figure as it is now but for the page, which the redraw takes
    obj.refreshFigurePreview(Redraw=true);   % (drawSessionEntry: the figure picked under the preview, at the new page's scale)
    ok = obj.FigurePreviewState == "drawn";
    return
end
spec = obj.Config.figureFor(k);
spec.enabled = true;
obj.fitFigureViews();
try
    renderFigure(F, spec, obj.FigurePreviewPanel, Scale=previewScale(obj, spec), OnRemember=@(rules) obj.rememberFigureAesthetics(spec.id, rules), ...
        OnGoto=@(role, panel) obj.gotoFigureSetting(spec.id, role, panel), ...
        OnAxisEdit=@(panel, change) obj.onFigureAxisEdited(spec.id, panel, change), ...
        OnSelect=@(panel, ctrl, shift) obj.onFigurePanelClicked(spec.id, panel, ctrl, false, shift));
catch ME
    obj.log(spec.id + " could not be drawn again: " + string(ME.message));
    return
end
obj.markFigurePanel();
obj.FigurePreviewDrawn = figureViewKey(obj, k);
ok = true;
end
