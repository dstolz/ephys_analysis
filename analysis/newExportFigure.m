function fig = newExportFigure(exportSection, F, spec)
%newExportFigure  An invisible classic figure of the export size, to render into.
%   FIG = newExportFigure(EXPORT) makes figure('Visible', 'off') with a white
%   background, EXPORT.FigureSizeCm ([width height] cm; the Export section
%   of an EphysAnalysisConfig, or any struct with that field; default
%   [18 12]) and paper size to match. Always a classic figure, never a
%   uifigure: EPS and SVG export, and print, need one. Close it when done.
%
%   FIG = newExportFigure(EXPORT, F, SPEC) sizes it for a figure of the
%   Figures section (SPEC from figureFor, with panels; F from
%   figureCompute, F.kind "figure"): one observation's panels on one page,
%   3.5 cm for each row of the arrangement (SPEC.grid.rows, else
%   F.spec.grid.rows) and 2 cm for the title and x label, never below
%   FigureSizeCm(2). The width stays FigureSizeCm(1).
%
%   See also exportFigure, renderFigure, EphysAnalysisRunner.runDataset.

arguments
    exportSection = struct()
    F = []
    spec = []
end

x = EphysAnalysisConfig.normalizeSection("Export", onlyKnown(exportSection));
sz = x.FigureSizeCm;
nRows = figureRows(F, spec);
if nRows > 0
    sz(2) = max(sz(2), 3.5 * nRows + 2);   % 3.5 cm a row of its arrangement, 2 cm for the title and x label
end
fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'centimeters', 'Position', [1 1 sz(1) sz(2)], ...
    'PaperUnits', 'centimeters', 'PaperSize', sz, 'PaperPosition', [0 0 sz(1) sz(2)], ...
    'InvertHardcopy', 'off', 'IntegerHandle', 'off', 'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none');
end


function rows = figureRows(F, spec)
%figureRows  The arrangement's rows of a figure (SPEC with panels, or F.kind "figure"); 0 = not given.
rows = 0;
if isstruct(spec) && isscalar(spec) && isfield(spec, 'panels') && isfield(spec, 'grid')
    rows = spec.grid.rows;
elseif isstruct(F) && isscalar(F) && isfield(F, 'kind') && isequal(string(F.kind), "figure") && isfield(F, 'spec')
    rows = F.spec.grid.rows;
end
end


function s = onlyKnown(s)
%onlyKnown  Keep only Export fields (a struct with other fields is fine).
if ~isstruct(s) || isempty(s); s = struct(); return; end
known = fieldnames(EphysAnalysisConfig.defaults("Export"));
s = rmfield(s, setdiff(fieldnames(s), known));
end
