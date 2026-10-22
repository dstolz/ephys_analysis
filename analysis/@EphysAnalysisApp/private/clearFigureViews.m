function clearFigureViews(obj)
%clearFigureViews  Drop every figure's preview container and kept editor state: another config is open.
%   Every container of FigureViews is deleted (their drawings, results
%   and right-click editors with them) and the editor states the figures
%   left (FigureEditorStates) are forgotten: the new config's figures may
%   share ids with the old one's, so nothing of theirs is taken for the
%   new. One container is left, "" (no figure), shown and empty, its
%   state the FigurePreview* properties; refreshFigureList then shows the
%   selected figure's own (syncFigureView). Called by applyConfig for a
%   config opened or made new (MarkSaved).
%
%   See also syncFigureView, applyConfig.
for v = reshape(obj.FigureViews, 1, [])
    if isvalid(v.Panel); delete(v.Panel); end
end
obj.FigureViews = struct([]);
if isa(obj.FigureEditorStates, 'containers.Map') && obj.FigureEditorStates.Count > 0; remove(obj.FigureEditorStates, keys(obj.FigureEditorStates)); end
forgetFigurePickers(obj);   % (the observation lists the figures kept)
v = newFigureView(obj, "");
v.Panel.Visible = 'on';
obj.FigureViews = v;
obj.FigureViewId = "";
obj.FigurePreviewPanel = v.Panel;
obj.FigurePreviewResult = [];
obj.FigurePreviewDrawn = [];
obj.FigurePreviewSeconds = 0;
obj.FigureSessionResults = [];
obj.FigurePreviewState = "idle";   % (the badge follows with the container shown next: syncFigureView)
showSessionPicker(obj, []);
end
