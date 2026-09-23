function im = reportImage(fig, report, opts)
%reportImage  One drawn page as the HTML report embeds it.
%   IM = reportImage(FIG, REPORT, Title=T, Files=F) exports the figure FIG
%   (one page drawn by renderPlot) the way REPORT (newAnalysisReport)
%   embeds images: with EmbedFormat "png" a PNG at REPORT.options.Dpi,
%   base64; with "svg" the SVG text. F lists the files just exported from
%   FIG (exportFigure): an .svg among them is read instead of printing FIG
%   again. IM is a struct (format, data, title) for
%   addReportFigure(..., Images=); T is the PNG's alt text (renderPlot's
%   H.title).
%
%   The runner and the standalone script make the images from the figures
%   they export, so an HTML report draws nothing again.
%
%   See also addReportFigure, exportFigure, writeHtmlReport.

arguments
    fig (1,1) matlab.ui.Figure
    report (1,1) struct
    opts.Title (1,1) string = ""
    opts.Files (1,:) string = string.empty(1, 0)
end

fmt = report.options.EmbedFormat;
svg = opts.Files(endsWith(opts.Files, ".svg", 'IgnoreCase', true));
if fmt == "svg" && ~isempty(svg)
    data = string(fileread(svg(1)));
else
    tmp = string(tempname);
    if fmt == "svg"
        f = exportFigure(fig, tmp, Format="svg");
        data = string(fileread(f));
    else
        f = exportFigure(fig, tmp, Format="png", Dpi=report.options.Dpi);
        fid = fopen(f, 'r');
        bytes = fread(fid, Inf, '*uint8');
        fclose(fid);
        data = string(matlab.net.base64encode(bytes));
    end
    delete(f);
end
im = struct('format', fmt, 'data', data, 'title', opts.Title);
end
