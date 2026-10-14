function onFigureSelected(obj, k)
%onFigureSelected  Edit figure K (its edits so far are already in the config) and preview it.
%   Its first panel and layer are picked; the picker lists its
%   observations (the one it last showed, when still there); the preview
%   is redrawn when K is another figure than before (Auto).
if isempty(k) || ~isnumeric(k); return; end
k = k(1);
if k < 1 || k > numel(obj.Config.Figures); return; end
other = k ~= obj.SelectedFigure;
obj.SelectedFigure = k;
if other
    obj.SelectedPanel = 1;
    obj.SelectedLayer = 1;
end
obj.refreshFigureList();
obj.applyFigureEditor();
obj.refreshFigureObservations();
obj.refreshEpochDiagram();
if ~other; return; end
obj.FigurePreviewResult = [];
obj.FigurePreviewSeconds = 0;
obj.autoFigurePreview();
end
