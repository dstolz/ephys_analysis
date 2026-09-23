function n = plotPageCount(R, spec)
%plotPageCount  How many pages renderPlot draws a result on.
%   N = plotPageCount(R, SPEC): grids of units (psth "grid", raster, tuning
%   "grid") and of channels (evoked "grid") hold Style.MaxTiles tiles per
%   page; every other plot is one page.
%
%   See also renderPlot, EphysAnalysisRunner.runDataset.

spec = plotSpecFor(R, spec);
per = max(1, round(spec.style.MaxTiles));
items = 1;
switch spec.kind
    case "psth"
        if spec.layout == "grid"; items = size(R.rate, 2); end
    case "raster"
        items = numel(R.raster);
    case "tuning"
        if spec.layout == "grid"; items = size(R.mean, 2); end
    case "evoked"
        if spec.layout == "grid"; items = size(R.mean, 2); end
end
n = max(1, ceil(items / per));
end
