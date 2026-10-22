function fitFigureViews(obj)
%fitFigureViews  Shape each figure's preview container like its figure's export page, letterboxed in the preview's cell.
%   fitFigureViews(OBJ) gives every container of FigureViews (syncFigureView)
%   the aspect ratio of the page its figure is exported on
%   (figureExportSize: the figure's own size, else the Export tab's, taller
%   when the rows need it), as large as fits the preview's cell
%   (FigurePreviewHost, its gray showing round it) and centered, so the
%   preview represents the export. The container with no figure ("")
%   fills the cell. A container that changes size lays its figure out again
%   by itself (figureLayout), so nothing is drawn here. Called when the
%   cell is resized, a figure is shown or edited (applyFigureEditor,
%   onConfigChanged) and before a preview is drawn (refreshFigurePreview).
%
%   See also figureExportSize, onFigureSizeEdited, refreshFigurePreview.
arguments
    obj (1,1) EphysAnalysisApp
end
H = obj.FigurePreviewHost;
if isempty(H) || ~isvalid(H) || isempty(obj.FigureViews); return; end
V = obj.FigureViews;
for i = 1:numel(V)
    P = V(i).Panel;
    if ~isvalid(P); continue; end
    box = figureViewBox(obj, V(i).Id);
    if ~isempty(box) && ~isequal(P.Position, box); P.Position = box; end
end
end
