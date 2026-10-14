function fig = newExportFigure(exportSection, R, spec, opts)
%newExportFigure  An invisible classic figure of the export size, to render into.
%   FIG = newExportFigure(EXPORT) makes figure('Visible', 'off') with a white
%   background, EXPORT.FigureSizeCm ([width height] cm; the Export section
%   of an EphysAnalysisConfig, or any struct with that field; default
%   [18 12]) and paper size to match. Always a classic figure, never a
%   uifigure: EPS and SVG export, and print, need one. Close it when done.
%
%   FIG = newExportFigure(EXPORT, R, SPEC, Page=P) sizes it for page P of
%   the plot SPEC computed as R (what renderPlot draws there): a grid page
%   (plotPageCount) is made taller when its rows of tiles need it, 3 cm a
%   row (4.5 cm for a PSTH with a raster over each panel; 1.5 cm more for
%   a panel of the mean aux signal below or above, R.aux) and 1.5 cm for
%   the title and x label, so a page of many units stays legible. The
%   width stays FigureSizeCm(1), and the height is never below
%   FigureSizeCm(2).
%
%   FIG = newExportFigure(EXPORT, F, SPEC) sizes it for a figure (the
%   Figures section: SPEC from figureFor, with panels; F from
%   figureCompute, F.kind "figure"): one observation's panels on one page,
%   3.5 cm for each row of the arrangement (SPEC.grid.rows) and 2 cm for
%   the title and x label, never below FigureSizeCm(2). Page is not used.
%
%   See also exportFigure, renderPlot, renderFigure, EphysAnalysisRunner.runDataset.

arguments
    exportSection = struct()
    R = []
    spec = []
    opts.Page (1,1) double {mustBePositive, mustBeInteger} = 1
end

x = EphysAnalysisConfig.normalizeSection("Export", onlyKnown(exportSection));
sz = x.FigureSizeCm;
nRows = figureRows(R, spec);
if nRows > 0
    sz(2) = max(sz(2), 3.5 * nRows + 2);   % a figure: 3.5 cm a row of its arrangement, 2 cm for the title and x label
elseif ~isempty(R)
    sz(2) = max(sz(2), gridHeightCm(R, spec, opts.Page));
end
fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'centimeters', 'Position', [1 1 sz(1) sz(2)], ...
    'PaperUnits', 'centimeters', 'PaperSize', sz, 'PaperPosition', [0 0 sz(1) sz(2)], ...
    'InvertHardcopy', 'off', 'IntegerHandle', 'off', 'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none');
end


function rows = figureRows(R, spec)
%figureRows  The arrangement's rows of a figure of the Figures section (SPEC with panels, or F.kind "figure"); 0 = a plot.
rows = 0;
if isstruct(spec) && isscalar(spec) && isfield(spec, 'panels') && isfield(spec, 'grid')
    rows = spec.grid.rows;
elseif isstruct(R) && isscalar(R) && isfield(R, 'kind') && isequal(string(R.kind), "figure") && isfield(R, 'spec')
    rows = R.spec.grid.rows;
end
end


function h = gridHeightCm(R, spec, page)
%gridHeightCm  The height page PAGE of a grid needs (0: not a grid).
spec = plotSpecFor(R, spec);
n = gridItems(R, spec);
h = 0;
if n < 2; return; end
page = min(page, plotPageCount(R, spec));
[~, nr] = pageItems(n, page, spec.style.MaxTiles);
row = 3;
if spec.kind == "psth" && spec.withRaster && isfield(R, 'raster') && ~isempty(R.raster); row = 4.5; end
if ismember(spec.kind, ["psth" "raster"]) && isfield(R, 'aux') && ~isempty(R.aux) && spec.aux.mode ~= "off" ...
        && ismember(auxPlace(spec.aux, spec.kind == "psth" && spec.stack && size(R.rate, 3) > 1), ["above" "below"])
    row = row + 1.5;   % the aux panel (a stack's "over" goes below, and a heat map's)
    if spec.aux.display ~= "lines"; row = row + 0.5; end   % a row each: room for the labels
end
h = nr * row + 1.5;
end


function s = onlyKnown(s)
%onlyKnown  Keep only Export fields (a struct with other fields is fine).
if ~isstruct(s) || isempty(s); s = struct(); return; end
known = fieldnames(EphysAnalysisConfig.defaults("Export"));
s = rmfield(s, setdiff(fieldnames(s), known));
end
