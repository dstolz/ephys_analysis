function cfg = gatherConfig(obj)
%gatherConfig  The config the controls show: name, Source, Defaults, the edited plot and session plot, Export, Report.
%   The session plot in the Sessions tab's editor (SelectedSessionPlot) is
%   taken from it (gatherSessionEditor); the other session plots as they
%   are in obj.Config. So is the figure in the Figures tab's editor
%   (SelectedFigure: gatherFigureEditor).
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
k = obj.SelectedSessionPlot;
if k >= 1 && k <= numel(cfg.SessionPlots)
    cfg.SessionPlots(k) = obj.gatherSessionEditor();
end
k = obj.SelectedFigure;
if k >= 1 && k <= numel(cfg.Figures)
    cfg.Figures(k) = obj.gatherFigureEditor();
end
end
