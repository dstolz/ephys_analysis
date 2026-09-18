function cfg = gatherConfig(obj)
%gatherConfig  The config the controls show: name, Source, Defaults, the edited plot, Export, Report.
%   Plots other than the one in the editor are taken from obj.Config as
%   they are (the list buttons change them there directly).
cfg = obj.Config;
cfg.Name = string(obj.ConfigNameField.Value);
cfg.Description = string(obj.ConfigDescField.Value);
cfg.Source = obj.gatherSourceSection();
[ref, win, sel] = obj.gatherAlignControls(obj.AlignControls);
cfg.Defaults = struct('EventRef', ref, 'Window', win, 'Selection', sel);
cfg.Export = obj.gatherExportSection();
cfg.Report = obj.gatherReportSection();
k = obj.SelectedPlot;
if k >= 1 && k <= numel(cfg.Plots)
    cfg.Plots(k) = obj.gatherPlotEditor();
end
end
