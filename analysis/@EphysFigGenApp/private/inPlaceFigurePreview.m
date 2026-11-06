function ok = inPlaceFigurePreview(obj, opts)
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
%   and the selected panel outlined again (markFigurePanel, once: the axes'
%   listeners wait while the layout moves them, layingOut); the badge stays
%   Drawn. OK is false, and nothing is done, for any other edit or preview
%   (a session figure, a probe figure, another figure shown, not drawn): the caller
%   computes and draws as after any edit.
%
%   inPlaceFigurePreview(OBJ, PlaceMoved=true) lays out only the panels
%   whose rects changed (renderFigure's PlaceMoved): Arrange's release
%   (arrangedPreview).
%   inPlaceFigurePreview(..., RectsOnly=true): the edit set the panels'
%   rects alone (commitFigureEdit's onlyRects): the spec is the one drawn
%   (FigurePreviewResult's) with the figure's rects, not computed again
%   (Config.figureFor), and renderFigure compares nothing else
%   (RectsOnly).
%
%   See also autoFigurePreview, renderFigure, redrawFigurePreview.
arguments
    obj (1,1) EphysFigGenApp
    opts.PlaceMoved (1,1) logical = false
    opts.RectsOnly (1,1) logical = false
end
ok = false;
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures) || obj.Config.Figures(k).sessions.enabled; return; end
id = obj.Config.Figures(k).id;
F = obj.FigurePreviewResult;
P = obj.FigurePreviewPanel;
if obj.FigurePreviewState ~= "drawn" || ~isstruct(F) || ~isfield(F, 'id') || string(F.id) ~= id ...
        || obj.FigureViewId ~= id || isempty(P) || ~isvalid(P) || (isfield(F, 'kind') && string(F.kind) == "probeFigure")
    return   % (a probe figure's page is drawn whole: renderProbeFigure sets nothing in place)
end
was = obj.FigurePreviewDrawn;
now = figureViewKey(obj, k);
if ~isstruct(was) || ~isstruct(now) || ~isequaln(rmfield(was, 'figure'), rmfield(now, 'figure')); return; end   % other data, observation or scan
spec = [];
if opts.RectsOnly; spec = drawnSpecAt(obj); end   % the spec drawn, at the new rects
if ~isstruct(spec)
    opts.RectsOnly = false;
    spec = obj.Config.figureFor(k);
    spec.enabled = true;   % (as refreshFigurePreview computes it)
end
quiet = layingOut(obj);   % the axes' listeners wait: the panels are marked once, below %#ok<NASGU>
try
    [~, how] = renderFigure(F, spec, P, Scale=previewScale(obj, spec), OnRemember=@(rules) obj.rememberFigureAesthetics(id, rules), ...
        OnGoto=@(role, panel) obj.gotoFigureSetting(id, role, panel), ...
        OnAxisEdit=@(panel, change) obj.onFigureAxisEdited(id, panel, change), ...
        OnSelect=@(panel, ctrl, shift) obj.onFigurePanelClicked(id, panel, ctrl, false, shift), ...
        InPlaceOnly=true, PlaceMoved=opts.PlaceMoved || opts.RectsOnly, RectsOnly=opts.RectsOnly);
catch ME
    obj.log(id + ": the edit could not be set on the preview, so it is drawn again: " + string(ME.message));
    return
end
clear quiet
if how ~= "inplace"; return; end
F.spec = spec;
obj.FigurePreviewResult = F;
obj.FigurePreviewDrawn = now;
obj.markFigurePanel();
ok = true;
end
