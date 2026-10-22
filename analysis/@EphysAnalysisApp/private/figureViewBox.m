function box = figureViewBox(obj, id)
%figureViewBox  Where figure ID's preview container goes in the preview's cell: the shape of its export page, letterboxed.
%   BOX = figureViewBox(OBJ, ID) is [x y width height] in pixels in
%   FigurePreviewHost: the page the figure is exported on (figureExportSize:
%   its own size, else the Export tab's, taller when the rows need it) as
%   large as fits the cell, with 4 px of ground round it, centered. The
%   container of no figure (ID ""), or of one gone from the config, fills
%   the cell. BOX is [] while the cell is too small to lay out (not
%   shown yet).
%
%   See also fitFigureViews, newFigureView, figureExportSize.
box = [];
H = obj.FigurePreviewHost;
if isempty(H) || ~isvalid(H); return; end
pos = H.InnerPosition;
w = pos(3);
h = pos(4);
if w < 40 || h < 40; return; end
box = [1 1 w h];
k = 0;
if id ~= ""; k = obj.Config.figureIndex(id); end
if k < 1; return; end
cm = figureExportSize(obj.Config.Export, [], obj.Config.Figures(k));
a = cm(1) / cm(2);
gap = 4;
bw = min(w - 2 * gap, (h - 2 * gap) * a);
bh = bw / a;
box = [1 + floor((w - bw) / 2), 1 + floor((h - bh) / 2), max(floor(bw), 20), max(floor(bh), 20)];
end
