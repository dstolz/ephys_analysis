function cfg = gatherConfig(obj)
%gatherConfig  The config the controls show: name, Source, Defaults, the edited plot, Export, Report.
%   Plots other than the one in the editor are taken from obj.Config as
%   they are (the list buttons change them there directly), but for the
%   others selected with it: they take what the editor's plot changed since
%   the editor last showed it (ShownPlot), and keep the rest
%   (spreadPlotEdit). Fields without a control keep obj.Config's values
%   (gatherAlignControls).
cfg = obj.Config;
cfg.Name = string(obj.ConfigNameField.Value);
cfg.Description = string(obj.ConfigDescField.Value);
cfg.Source = obj.gatherSourceSection();
D = cfg.Defaults;
[ref, win, sel] = obj.gatherAlignControls(obj.AlignControls, D.EventRef, D.Window, D.Selection);
cfg.Defaults = struct('EventRef', ref, 'Window', win, 'Selection', sel);
cfg.Export = obj.gatherExportSection();
cfg.Report = obj.gatherReportSection();
ks = obj.selectedPlots();
if ~isempty(ks)
    cfg.Plots(ks(1)) = obj.gatherPlotEditor();
    if numel(ks) > 1 && ~isempty(fieldnames(obj.ShownPlot))
        cfg.Plots = spreadPlotEdit(cfg.Plots, ks(1), ks(2:end), obj.ShownPlot, cfg.Defaults);
    end
end
end
