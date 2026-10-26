function s = previewScale(obj, spec, widthPx)
%previewScale  The scale a preview of SPEC is drawn at: the width it is drawn at over its export page's.
%   S = previewScale(OBJ, SPEC, WIDTHPX) is the width the figure is drawn
%   at (WIDTHPX, default the preview container's) over the width of its
%   export page at 96 dpi (figureExportSize), clamped to 0.35-3; 1 while
%   the container is not laid out. renderFigure(..., Scale=S) draws the
%   figure as it is exported and then scales every size -- fonts, lines,
%   markers, error bar caps, sites, the layout's gaps -- by S, whatever
%   set it (the style, a draw function, the design, the remembered looks,
%   the figure's own), so a page drawn smaller or larger than it is
%   exported shows everything in the same proportion to the page as the
%   export (and so the report, made from the exported pages) does; at the
%   export's own size nothing changes. The config keeps the sizes as
%   exported, and the aesthetics editor reads and sets them so.
%
%   See also fitFigureViews, onOpenFigureWindow, figureExportSize, renderFigure.
arguments
    obj (1,1) EphysAnalysisApp
    spec (1,1) struct
    widthPx (1,1) double = NaN
end
s = 1;
if isnan(widthPx)
    P = obj.FigurePreviewPanel;
    if isempty(P) || ~isvalid(P); return; end
    widthPx = P.InnerPosition(3);
end
if ~(widthPx > 40); return; end   % not laid out yet
cm = figureExportSize(obj.Config.Export, [], spec);
s = min(max(widthPx / (cm(1) / 2.54 * 96), 0.35), 3);
end
