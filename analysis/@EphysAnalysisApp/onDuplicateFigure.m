function onDuplicateFigure(obj)
%onDuplicateFigure  Copy the selected figure right after it, as "<id> (2)" (the next free number), and select the copy.
%   The copy keeps every setting, its remembered looks and its observation
%   too (EphysAnalysisConfig.duplicateFigure): an automatic id copies as
%   "<automatic id> (n)" and goes on following the copy's own panels; an
%   id of the user's own as "<id> (n)", the user's too.
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
cfg = obj.gatherConfig();
from = cfg.Figures(k).id;
[cfg, id] = cfg.duplicateFigure(k);
if isKey(obj.FigureObservation, char(from)); obj.FigureObservation(char(id)) = obj.FigureObservation(char(from)); end
obj.SelectedFigure = k + 1;
obj.applyConfig(cfg, Action="Duplicate figure");
obj.setStatus("Duplicated " + from + " as " + id + ".");
obj.autoFigurePreview();
end
