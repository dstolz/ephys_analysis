function n = plotPageCount(R, spec)
%plotPageCount  How many pages renderPlot draws a result on.
%   N = plotPageCount(R, SPEC): grids of units (psth "grid", raster, tuning
%   "grid") and of channels (evoked "grid") hold Style.MaxTiles tiles per
%   page; every other plot is one page. A result computed for one page
%   (computePlot Page=, R.page = [page nPages]) counts the pages of the whole.
%
%   See also renderPlot, EphysAnalysisRunner.runDataset.

if isfield(R, 'page'); n = R.page(2); return; end
spec = plotSpecFor(R, spec);
per = max(1, round(spec.style.MaxTiles));
n = max(1, ceil(gridItems(R, spec) / per));
end
