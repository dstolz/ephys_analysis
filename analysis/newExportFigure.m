function fig = newExportFigure(exportSection)
%newExportFigure  An invisible classic figure of the export size, to render into.
%   FIG = newExportFigure(EXPORT) makes figure('Visible', 'off') with a white
%   background, EXPORT.FigureSizeCm ([width height] cm; the Export section
%   of an EphysAnalysisConfig, or any struct with that field; default
%   [18 12]) and paper size to match. Always a classic figure, never a
%   uifigure: EPS and SVG export, and print, need one. Close it when done.
%
%   See also exportFigure, renderPlot, EphysAnalysisRunner.runDataset.

arguments
    exportSection = struct()
end

x = EphysAnalysisConfig.normalizeSection("Export", onlyKnown(exportSection));
sz = x.FigureSizeCm;
fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'centimeters', 'Position', [1 1 sz(1) sz(2)], ...
    'PaperUnits', 'centimeters', 'PaperSize', sz, 'PaperPosition', [0 0 sz(1) sz(2)], ...
    'InvertHardcopy', 'off', 'IntegerHandle', 'off', 'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none');
end


function s = onlyKnown(s)
%onlyKnown  Keep only Export fields (a struct with other fields is fine).
if ~isstruct(s) || isempty(s); s = struct(); return; end
known = fieldnames(EphysAnalysisConfig.defaults("Export"));
s = rmfield(s, setdiff(fieldnames(s), known));
end
