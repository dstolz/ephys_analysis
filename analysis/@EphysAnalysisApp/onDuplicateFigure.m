function onDuplicateFigure(obj)
%onDuplicateFigure  Copy the selected figure under a new id ("figure_<n>"), right after it, and select the copy.
%   The copy keeps every setting, its remembered looks and its observation too.
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
cfg = obj.gatherConfig();
f = cfg.Figures(k);
from = f.id;
f.id = "";
[cfg, id] = cfg.addFigure(f);   % appended
F = cfg.Figures;
cfg.Figures = [F(1:k) F(end) F(k+1:end-1)];
if isKey(obj.FigureObservation, char(from)); obj.FigureObservation(char(id)) = obj.FigureObservation(char(from)); end
obj.SelectedFigure = k + 1;
obj.applyConfig(cfg);
obj.setStatus("Duplicated " + from + " as " + id + ".");
obj.autoFigurePreview();
end
