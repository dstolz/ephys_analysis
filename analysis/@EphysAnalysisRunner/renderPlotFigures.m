function figs = renderPlotFigures(obj, R, spec, opts)
%renderPlotFigures  Draw a computed plot: into a target, or one figure per page.
%   H = r.renderPlotFigures(R, SPEC, Target=T, Page=P) draws page P into T (an
%   axes, uiaxes, panel, ...; the app's preview) and returns renderPlot's H.
%   FIGS = r.renderPlotFigures(R, SPEC) makes one invisible
%   newExportFigure(Config.Export) per page (plotPageCount) and draws each
%   page into it: the figures to export. Close them when done.
%
%   See also renderPlot, plotPageCount, newExportFigure, exportFigure.

arguments
    obj (1,1) EphysAnalysisRunner
    R (1,1) struct
    spec (1,1) struct
    opts.Target = []
    opts.Page (1,1) double {mustBePositive, mustBeInteger} = 1
end

if ~isempty(opts.Target)
    figs = renderPlot(R, spec, opts.Target, Page=opts.Page);
    return
end
n = plotPageCount(R, spec);
figs = gobjects(1, n);
for p = 1:n
    figs(p) = newExportFigure(obj.Config.Export);
    renderPlot(R, spec, figs(p), Page=p);
end
end
