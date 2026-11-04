function onRemoveFigure(obj)
%onRemoveFigure  Remove the selected figure; the one taking its place is selected and shown.
%   Its preview container goes (syncFigureView frees it) and so does the
%   editor state it left; the figure taking its place comes back as it was
%   left (restoreFigureEditorState) with its kept preview when still
%   current, else drawn again (previewFigureView).
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
cfg = obj.gatherConfig();
id = cfg.Figures(k).id;
cfg = cfg.removeFigure(id);
if isKey(obj.FigureObservation, char(id)); remove(obj.FigureObservation, char(id)); end
if isa(obj.FigureEditorStates, 'containers.Map') && isKey(obj.FigureEditorStates, char(id)); remove(obj.FigureEditorStates, char(id)); end
obj.SelectedFigure = min(k, numel(cfg.Figures));
obj.SelectedPanel = 1;
obj.SelectedLayer = 1;
S = [];
if obj.SelectedFigure >= 1; S = restoreFigureEditorState(obj, cfg.Figures(obj.SelectedFigure).id); end
obj.applyConfig(cfg, Action="Remove figure");
scrollFigureEditor(obj, S);
obj.setStatus("Removed " + id + ".");
previewFigureView(obj);   % (no figure left: the panel and the badge say so)
end
