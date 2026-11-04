function sz = figureExportSize(exportSection, F, spec)
%figureExportSize  The page a figure is exported on: [width height] in cm.
%   SZ = figureExportSize(EXPORT, F, SPEC) for a figure of the Figures
%   section (SPEC from figureFor, with panels; F from figureCompute, F.kind
%   "figure", or [] when only SPEC is at hand) and EXPORT, the Export
%   section of an EphysAnalysisConfig (or any struct with FigureSizeCm and
%   Dpi; the defaults [18 12] cm and 150 dpi where it has none):
%     SPEC.size.source "export" (the default)  EXPORT.FigureSizeCm as it
%         is: the panels' rects are parts of the page, however many there
%         are
%     SPEC.size.source "own"   SPEC.size.width x height as they are, in
%         SPEC.size.units: "px" (pixels of the exported PNG, so inches at
%         EXPORT.Dpi), "in" or "cm"
%   A probe figure's page (F from figureProbeCompute, F.kind
%   "probeFigure") with SPEC.size.source "export" is FigureSizeCm(1) wide
%   and max(FigureSizeCm(2), min(80, 2 + nRows * nLevels * 1.5)) cm
%   tall, nRows the rows of its tiles (probeTileLayout(F, SPEC.probe);
%   0 without a tile) and nLevels the panels' levels in a tile (the
%   distinct top edges of their rects, to 0.01 of the page): 1.5 cm a
%   panel level of each row of tiles, 2 cm for the title, at most 80 cm.
%   SPEC is F.spec when not given.
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
if isstruct(F) && isscalar(F) && isfield(F, 'kind') && isequal(string(F.kind), "probeFigure")
    sp = spec;
    if ~(isstruct(sp) && isscalar(sp) && isfield(sp, 'panels') && isfield(sp, 'probe')); sp = F.spec; end
    nRows = 0;
    if F.nTiles > 0
        L = probeTileLayout(F, sp.probe);
        nRows = L.nRows;
    end
    levels = 0;   % the panels' levels in a tile: their rects' distinct top edges
    if ~isempty(sp.panels)
        R = reshape([sp.panels.rect], 4, []);
        levels = numel(unique(round(R(2, :) + R(4, :), 2)));
    end
    sz = [cm(1) max(cm(2), min(80, 2 + nRows * levels * 1.5))];   % 1.5 cm a panel level of each row of tiles, 2 cm for the title
end
end
