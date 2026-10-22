function sz = figureExportSize(exportSection, F, spec)
%figureExportSize  The page a figure is exported on: [width height] in cm.
%   SZ = figureExportSize(EXPORT, F, SPEC) for a figure of the Figures
%   section (SPEC from figureFor, with panels; F from figureCompute, F.kind
%   "figure", or [] when only SPEC is at hand) and EXPORT, the Export
%   section of an EphysAnalysisConfig (or any struct with FigureSizeCm and
%   Dpi; the defaults [18 12] cm and 150 dpi where it has none):
%     SPEC.size.source "export" (the default)  EXPORT.FigureSizeCm, taller
%         when the arrangement needs it: 3.5 cm for each row of its grid
%         and 2 cm for the title and x label, never below FigureSizeCm(2)
%         (the width stays FigureSizeCm(1))
%     SPEC.size.source "own"   SPEC.size.width x height as they are, in
%         SPEC.size.units: "px" (pixels of the exported PNG, so inches at
%         EXPORT.Dpi), "in" or "cm"
%   newExportFigure sizes the export page with it, and the Figures tab
%   draws the preview at the same shape (the aspect ratio of SZ).
%
%   See also newExportFigure, figureSizePresets, figureSizeParse, figureSizeConvert.

arguments
    exportSection = struct()
    F = []
    spec = []
end

cm = [18 12];
dpi = 150;
if isstruct(exportSection) && isscalar(exportSection)
    if isfield(exportSection, 'FigureSizeCm') && isnumeric(exportSection.FigureSizeCm) && numel(exportSection.FigureSizeCm) == 2
        cm = double(reshape(exportSection.FigureSizeCm, 1, 2));
    end
    if isfield(exportSection, 'Dpi') && isnumeric(exportSection.Dpi) && isscalar(exportSection.Dpi) && exportSection.Dpi > 0
        dpi = double(exportSection.Dpi);
    end
end
z = [];
if isstruct(spec) && isscalar(spec) && isfield(spec, 'size') && isstruct(spec.size) && isfield(spec.size, 'source')
    z = spec.size;
end
if ~isempty(z) && string(z.source) == "own"
    sz = figureSizeConvert(double([z.width z.height]), string(z.units), "cm", dpi);
    return
end
sz = cm;
nRows = figureRows(F, spec);
if nRows > 0
    sz(2) = max(sz(2), 3.5 * nRows + 2);   % 3.5 cm a row of its arrangement, 2 cm for the title and x label
end
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
