function im = reportImage(fig, report, opts)
%reportImage  One drawn page as the HTML report embeds it.
%   IM = reportImage(FIG, REPORT, Title=T, Files=F) exports the figure FIG
%   (one page drawn by renderFigure) the way REPORT (newAnalysisReport)
%   embeds images: with EmbedFormat "png" a PNG at REPORT.options.Dpi,
%   base64; with "svg" the SVG text. F lists the files just exported from
%   FIG (exportFigure), or already on disk for it: an .svg (or, for "png",
%   a .png, at the dpi it was written at) among them is read instead of
%   printing FIG again. IM is a struct (format, data, title) for
%   addReportFigure(..., Images=); T is the PNG's alt text (renderFigure's
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
have = opts.Files(endsWith(opts.Files, "." + fmt, 'IgnoreCase', true) & isfile(opts.Files));
if ~isempty(have)
    data = readData(have(1), fmt);
else
    tmp = string(tempname);
    if fmt == "svg"
        f = exportFigure(fig, tmp, Format="svg");
    else
        f = exportFigure(fig, tmp, Format="png", Dpi=report.options.Dpi);
    end
    data = readData(f, fmt);
    delete(f);
end
im = struct('format', fmt, 'data', data, 'title', opts.Title);
end


function data = readData(f, fmt)
%readData  The SVG's text, or the PNG's bytes in base64.
if fmt == "svg"
    data = string(fileread(f));
    return
end
fid = fopen(f, 'r');
bytes = fread(fid, Inf, '*uint8');
fclose(fid);
data = string(matlab.net.base64encode(bytes));
end
