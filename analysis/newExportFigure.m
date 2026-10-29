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
%   figureCompute, F.kind "figure"): figureExportSize's page -- the
%   figure's own size when SPEC.size.source is "own" (px at the Export dpi,
%   in or cm), else the FigureSizeCm above, taller by 3.5 cm for each row
%   of the arrangement and 2 cm for the title and x label, never below
%   FigureSizeCm(2) (the width stays FigureSizeCm(1)). A probe figure (F
%   from figureProbeCompute, F.kind "probeFigure") gets a page as tall as
%   its rows of tiles need (figureExportSize: 1.5 cm a panel row of each
%   row of tiles and 2 cm, at most 80 cm).
%
%   See also exportFigure, renderFigure, EphysAnalysisRunner.runDataset.

arguments
    exportSection = struct()
    F = []
    spec = []
end

x = EphysAnalysisConfig.normalizeSection("Export", onlyKnown(exportSection));
sz = figureExportSize(x, F, spec);
fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'centimeters', 'Position', [1 1 sz(1) sz(2)], ...
    'InvertHardcopy', 'off', 'IntegerHandle', 'off', 'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none');
% the paper once the window is made: a page taller than the screen (a probe figure's) gets its paper fitted to the
% screen while the figure is made, so the paper is set after, and is the page
set(fig, 'PaperUnits', 'centimeters', 'PaperSize', sz, 'PaperPosition', [0 0 sz(1) sz(2)]);
end


function s = onlyKnown(s)
%onlyKnown  Keep only Export fields (a struct with other fields is fine).
if ~isstruct(s) || isempty(s); s = struct(); return; end
known = fieldnames(EphysAnalysisConfig.defaults("Export"));
s = rmfield(s, setdiff(fieldnames(s), known));
end
