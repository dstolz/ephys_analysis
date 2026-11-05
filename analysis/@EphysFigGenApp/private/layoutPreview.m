function ok = layoutPreview(obj, spec)
%layoutPreview  The drawing in the preview (drawn or out of date) laid out at a figure's rects, nothing drawn (renderFigure LayoutOnly).
%   OK = layoutPreview(OBJ) lays it out at the selected figure's rects and
%   layout as they are now (Config.figureFor, as refreshFigurePreview
%   draws it): arrangedPreview after a panel placed in Arrange.
%   OK = layoutPreview(OBJ, SPEC) lays it out as SPEC says, which may
%   leave panels of the drawing out or give the rest in another order (by
%   id): paintEditFirst, a panel removed or reordered shown before the
%   editor is read back. The panels left out go from the preview.
%   OK is true when it was laid out (renderFigure's HOW "layout"); then the
%   selected panel is outlined again (markFigurePanel: the boxes on the
%   page the layout left), once: the axes' listeners wait while the layout
%   moves them (layingOut). False, and nothing done, when no drawing is
%   kept (FigurePreviewResult no struct) or renderFigure could not lay it
%   out (an error is logged).
%
%   See also arrangedPreview, paintEditFirst, renderFigure.
ok = false;
F = obj.FigurePreviewResult;
if ~isstruct(F); return; end
if nargin < 2
    spec = obj.Config.figureFor(obj.SelectedFigure);
    spec.enabled = true;   % (as refreshFigurePreview draws it)
end
quiet = layingOut(obj);   % the axes' listeners wait: the panels are marked once, below %#ok<NASGU>
try
    [~, how] = renderFigure(F, spec, obj.FigurePreviewPanel, LayoutOnly=true);
catch ME
    clear quiet
    obj.log(spec.id + ": the preview could not be laid out at the new places: " + string(ME.message));
    obj.markFigurePanel();   % (a layout begun: the outline and the boxes where it left them)
    return
end
clear quiet
ok = how == "layout";
if ok; obj.markFigurePanel(); end   % (the boxes on the page the layout left)
end
