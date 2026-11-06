function spec = drawnSpecAt(obj)
%drawnSpecAt  The spec the preview was drawn from (FigurePreviewResult's) at the selected figure's rects as they are now; [] when it cannot stand in for Config.figureFor.
%   SPEC = drawnSpecAt(OBJ) after an edit of the rects alone (Arrange:
%   commitFigureEdit's onlyRects), so the spec need not be computed again
%   (figureFor passes the rects and the layout on as they are): the rects
%   and the layout are the figure's. [] when no drawing of
%   this figure is held, or its panels are not the figure's (by id, in
%   order).
%
%   See also inPlaceFigurePreview, arrangedPreview, layoutPreview.
spec = [];
k = obj.SelectedFigure;
F = obj.FigurePreviewResult;
if k < 1 || k > numel(obj.Config.Figures) || ~isstruct(F) || ~isfield(F, 'spec') || ~isstruct(F.spec) || ~isfield(F.spec, 'panels')
    return
end
fig = obj.Config.Figures(k);
if F.spec.id ~= fig.id || numel(F.spec.panels) ~= numel(fig.panels) ...
        || (~isempty(fig.panels) && ~isequal([F.spec.panels.id], [fig.panels.id]))
    return
end
spec = F.spec;
for j = 1:numel(fig.panels); spec.panels(j).rect = fig.panels(j).rect; end
if isfield(fig, 'layout'); spec.layout = fig.layout; end   % (a layout edited since the drawing: LayoutOnly lays it out)
end
