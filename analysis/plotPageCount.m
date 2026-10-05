function n = plotPageCount(R, spec)
%plotPageCount  How many pages renderPlot draws a result on.
%   N = plotPageCount(R, SPEC): grids of units (psth "grid", raster, tuning
%   "grid") and of channels (evoked "grid") hold Style.MaxTiles tiles per
%   page; every other plot is one page.
%
%   See also renderPlot, EphysAnalysisRunner.runDataset.

spec = plotSpecFor(R, spec);
per = max(1, round(spec.style.MaxTiles));
n = max(1, ceil(gridItems(R, spec) / per));
end
