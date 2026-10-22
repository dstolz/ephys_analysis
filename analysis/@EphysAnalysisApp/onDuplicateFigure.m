function onDuplicateFigure(obj)
%onDuplicateFigure  Copy the selected figure right after it, as "<id> (2)" (the next free number), and select the copy.
%   The copy keeps every setting, its remembered looks and its observation
%   too (EphysAnalysisConfig.duplicateFigure): an automatic id copies as
%   "<automatic id> (n)" and goes on following the copy's own panels; an
%   id of the user's own as "<id> (n)", the user's too. The editor shows
%   the copy as the original had it (its sections, scroll, panel and
%   layer: saveFigureEditorState); the copy gets a preview container of
%   its own (syncFigureView), drawn as after an edit.
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
cfg = obj.gatherConfig();
from = cfg.Figures(k).id;
[cfg, id] = cfg.duplicateFigure(k);
if isKey(obj.FigureObservation, char(from)); obj.FigureObservation(char(id)) = obj.FigureObservation(char(from)); end
saveFigureEditorState(obj);   % the original's editor state, the copy's too
M = obj.FigureEditorStates;
if isa(M, 'containers.Map') && isKey(M, char(from)); M(char(id)) = M(char(from)); end
obj.SelectedFigure = k + 1;
obj.applyConfig(cfg, Action="Duplicate figure");
obj.setStatus("Duplicated " + from + " as " + id + ".");
obj.autoFigurePreview();
end
