function ok = inPlaceFigurePreview(obj)
%inPlaceFigurePreview  Set an edit of text alone (a panel's label or title, the figure's title) on the drawn preview: nothing computed or drawn.
%   OK = inPlaceFigurePreview(OBJ) is autoFigurePreview's first try after
%   an edit. When the selected figure's preview is drawn (its badge Drawn)
%   from the dataset, observation and scan it would be drawn from now
%   (FigurePreviewDrawn: figureViewKey but the figure), the figure as it is
%   now (Config.figureFor, at the scale the preview draws it: previewScale) is
%   given to renderFigure with InPlaceOnly: when it differs from the one
%   drawn in text alone, the text is set on the labels and titles drawn and
%   the layout done again -- what a whole drawing would make, with no
%   compute, no busy card (setFigurePreviewState) and no panel drawn again.
%   Then the result held (FigurePreviewResult) takes the figure's spec (as
%   computeFigure gives it), the preview is current (FigurePreviewDrawn)
%   and the selected panel outlined again (markFigurePanel); the badge stays
%   Drawn. OK is false, and nothing is done, for any other edit or preview
%   (a session figure, another figure shown, not drawn): the caller
%   computes and draws as after any edit.
%
%   See also autoFigurePreview, renderFigure, redrawFigurePreview.
ok = false;
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures) || obj.Config.Figures(k).sessions.enabled; return; end
id = obj.Config.Figures(k).id;
F = obj.FigurePreviewResult;
P = obj.FigurePreviewPanel;
if obj.FigurePreviewState ~= "drawn" || ~isstruct(F) || ~isfield(F, 'id') || string(F.id) ~= id ...
        || obj.FigureViewId ~= id || isempty(P) || ~isvalid(P)
    return
end
was = obj.FigurePreviewDrawn;
now = figureViewKey(obj, k);
if ~isstruct(was) || ~isstruct(now) || ~isequaln(rmfield(was, 'figure'), rmfield(now, 'figure')); return; end   % other data, observation or scan
spec = obj.Config.figureFor(k);
spec.enabled = true;   % (as refreshFigurePreview computes it)
try
    [~, how] = renderFigure(F, spec, P, Scale=previewScale(obj, spec), OnRemember=@(rules) obj.rememberFigureAesthetics(id, rules), ...
        OnGoto=@(role, panel) obj.gotoFigureSetting(id, role, panel), ...
        OnAxisEdit=@(panel, change) obj.onFigureAxisEdited(id, panel, change), ...
        OnSelect=@(panel, ctrl) obj.onFigurePanelClicked(id, panel, ctrl, false), ...
        InPlaceOnly=true);
catch ME
    obj.log(id + ": the edit could not be set on the preview, so it is drawn again: " + string(ME.message));
    return
end
if how ~= "inplace"; return; end
F.spec = spec;
obj.FigurePreviewResult = F;
obj.FigurePreviewDrawn = now;
obj.markFigurePanel();
ok = true;
end
