function files = exportFigure(fig, fileBase, opts)
%exportFigure  Write a figure as PNG, EPS, SVG and / or PDF.
%   FILES = exportFigure(FIG, FILEBASE, Format=["png" "svg"], Dpi=150)
%   writes FILEBASE + "." + format for each format and returns the paths
%   written (the folder is created):
%     png  exportgraphics(..., Resolution=Dpi)
%     pdf  exportgraphics(..., ContentType="vector", Append=Append)
%     eps  exportgraphics(..., ContentType="vector")
%     svg  print(..., "-dsvg", "-vector")
%   FIG should be a classic figure (newExportFigure); before R2025a a
%   uifigure raises exportFigure:UIFigure (R2025a exports both alike). An
%   unknown format raises exportFigure:BadFormat before anything is written.
%
%   Options: Format, Dpi, Append (PDF only: add a page to an existing file).
%
%   See also newExportFigure, figureFileName, writePdfReport.

arguments
    fig (1,1) matlab.ui.Figure
    fileBase (1,1) string
    opts.Format (1,:) string = "png"
    opts.Dpi (1,1) double {mustBePositive} = 150
    opts.Append (1,1) logical = false
end

fmts = lower(opts.Format);
bad = setdiff(fmts, ["png" "eps" "svg" "pdf"]);
if ~isempty(bad)
    error('exportFigure:BadFormat', 'Unknown format(s) %s (png, eps, svg, pdf).', strjoin(bad, ", "));
end
if isMATLABReleaseOlderThan("R2025a") && matlab.ui.internal.isUIFigure(fig)
    % Before R2025a print cannot write SVG / EPS from a uifigure.
    error('exportFigure:UIFigure', 'Export needs a classic figure (newExportFigure), not a uifigure.');
end
d = fileparts(fileBase);
if strlength(d) > 0 && ~isfolder(d)
    [ok, msg] = mkdir(d);
    if ~ok
        error('exportFigure:CannotWrite', 'Cannot create %s: %s', d, msg);
    end
end
files = strings(1, 0);
ws = warning('off', 'MATLAB:print:ContentTypeImageSuggested');   % rasters and heatmaps are large but fine as vectors
restore = onCleanup(@() warning(ws));
for fmt = fmts
    f = fileBase + "." + fmt;
    switch fmt
        case "png"
            exportgraphics(fig, f, 'Resolution', opts.Dpi);
        case "pdf"
            exportgraphics(fig, f, 'ContentType', 'vector', 'Append', opts.Append);
        case "eps"
            exportgraphics(fig, f, 'ContentType', 'vector');
        case "svg"
            print(fig, char(f), '-dsvg', '-vector');
    end
    files(end+1) = f; %#ok<AGROW>
end
end
