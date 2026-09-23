function h = renderPlotFigures(obj, R, spec, opts)
%renderPlotFigures  Draw one page of a computed plot into a target (the app's preview).
%   H = r.renderPlotFigures(R, SPEC, Target=T, Page=P) draws page P into T
%   (an axes, uiaxes, panel, ...) with renderPlot and returns its H. Runs
%   draw each page into its own newExportFigure instead, one at a time
%   (runDataset). The axes are not linked: one linkaxes call over a PSTH
%   page's rasters and rates adds about half its drawing time.
%
%   See also renderPlot, plotPageCount, EphysAnalysisRunner.runDataset.

arguments
    obj (1,1) EphysAnalysisRunner %#ok<INUSA>
    R (1,1) struct
    spec (1,1) struct
    opts.Target = []
    opts.Page (1,1) double {mustBePositive, mustBeInteger} = 1
end

if isempty(opts.Target)
    error('EphysAnalysisRunner:NoTarget', 'renderPlotFigures draws into a target (Target=); runDataset draws the pages of a run.');
end
h = renderPlot(R, spec, opts.Target, Page=opts.Page);
end
