function [pageCm, dpi] = figurePage(obj, fig)
%figurePage  The page a figure is exported on, [width height] cm, and the Export tab's dpi: what the Panels section's lengths are measured on.
%   [PAGECM, DPI] = figurePage(OBJ) is the page of the selected figure
%   (figureExportSize: its own size, else the Export tab's) and the Export
%   section's Dpi (150 when it has none); [18 12] cm with no figure
%   selected. [PAGECM, DPI] = figurePage(OBJ, FIG) is FIG's (a Figures
%   entry). A panel's rect, the padding and the snap step in cm, in or px
%   are lengths on that page (figureRectConvert): a pixel is 1 / DPI inch,
%   as on the exported PNG.
%
%   See also figureExportSize, figureRectConvert, showPanelPlace.
if nargin < 2
    fig = [];
    k = obj.SelectedFigure;
    if k >= 1 && k <= numel(obj.Config.Figures); fig = obj.Config.Figures(k); end
end
X = obj.Config.Export;
pageCm = figureExportSize(X, [], fig);
dpi = 150;
if isstruct(X) && isfield(X, 'Dpi') && isnumeric(X.Dpi) && isscalar(X.Dpi) && X.Dpi > 0; dpi = double(X.Dpi); end
end
