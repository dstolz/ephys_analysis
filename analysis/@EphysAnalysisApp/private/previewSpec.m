function spec = previewSpec(obj, spec, widthPx)
%previewSpec  SPEC as the preview draws it: its fonts and lines scaled by how the preview's page compares with the exported one.
%   SPEC = previewSpec(OBJ, SPEC, WIDTHPX) scales SPEC.style's FontSize,
%   LineWidth and SiteSize by the width the figure is drawn at (WIDTHPX,
%   default the preview container's) over the width of its export page at
%   96 dpi (figureExportSize), clamped to 0.35-3. So a page drawn smaller
%   or larger than it is exported shows its text and lines in the same
%   proportion to the page as the export does; at the export's own size
%   nothing changes. Only the style is scaled: sizes set by the looks
%   (the aesthetics editor's rules) are not. The config keeps the
%   unscaled SPEC.
%
%   See also fitFigureViews, onOpenFigureWindow, figureExportSize.
arguments
    obj (1,1) EphysAnalysisApp
    spec (1,1) struct
    widthPx (1,1) double = NaN
end
if isnan(widthPx)
    P = obj.FigurePreviewPanel;
    if isempty(P) || ~isvalid(P); return; end
    widthPx = P.InnerPosition(3);
end
if ~(widthPx > 40); return; end   % not laid out yet
cm = figureExportSize(obj.Config.Export, [], spec);
s = min(max(widthPx / (cm(1) / 2.54 * 96), 0.35), 3);
for f = ["FontSize" "LineWidth" "SiteSize"]
    v = spec.style.(f);
    if isnumeric(v) && isscalar(v) && isfinite(v) && v > 0; spec.style.(f) = v * s; end
end
end
