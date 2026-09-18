function f = plotFileName(pattern, name, spec, R, page, nPages)
%plotFileName  The file name (no extension) of one page of an exported plot.
%   F = plotFileName(PATTERN, NAME, SPEC, R, PAGE, NPAGES) fills
%   Export.FilenamePattern (figureFileName) with Name = NAME (the dataset),
%   Plot = SPEC.id, Kind = SPEC.kind, Group = "all", Unit = the first unit on
%   the page of a paged psth / raster / tuning grid ("all" otherwise), Index =
%   PAGE and Date = today, and appends "_p<PAGE>" when NPAGES > 1 and the
%   pattern names neither {Index} nor {Unit}, so pages never overwrite each
%   other.
%
%   See also figureFileName, exportFigure, EphysAnalysisRunner.runDataset.

unit = "all";
if nPages > 1 && isfield(R, 'labels') && ismember(spec.kind, ["psth" "raster" "tuning"])
    per = max(1, round(spec.style.MaxTiles));
    i = (page - 1) * per + 1;
    if i <= numel(R.labels); unit = R.labels(i); end
end
f = figureFileName(pattern, struct('Name', name, 'Plot', spec.id, 'Kind', spec.kind, 'Group', "all", ...
    'Unit', unit, 'Index', page));
if nPages > 1 && ~contains(pattern, ["{Index}" "{Unit}"])
    f = f + "_p" + page;
end
end
