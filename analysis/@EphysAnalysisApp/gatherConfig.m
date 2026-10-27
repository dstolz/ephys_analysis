function cfg = gatherConfig(obj)
%gatherConfig  The config the controls show: name, Source, Defaults, the edited figure, Export, Report.
%   The figure in the Figures tab's editor (SelectedFigure) is taken from
%   it (gatherFigureEditor); the other figures as they are in obj.Config
%   (the list buttons change them there directly). Fields without a
%   control keep obj.Config's values (AlignControls.read).
cfg = obj.Config;
cfg.Name = string(obj.ConfigNameField.Value);
cfg.Description = string(obj.ConfigDescField.Value);
cfg.Source = obj.gatherSourceSection();
D = cfg.Defaults;
[ref, win, sel] = AlignControls.read(obj.AlignControls, D.EventRef, D.Window, D.Selection);
cfg.Defaults = struct('EventRef', ref, 'Window', win, 'Selection', sel);
cfg.Export = obj.gatherExportSection();
cfg.Report = obj.gatherReportSection();
k = obj.SelectedFigure;
if k >= 1 && k <= numel(cfg.Figures)
    cfg.Figures(k) = obj.gatherFigureEditor();
end
end
