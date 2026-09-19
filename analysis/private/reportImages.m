function images = reportImages(R, spec, report)
%reportImages  Every page of a plot rendered for the HTML report.
%   IMAGES = reportImages(R, SPEC, REPORT) is a cell of structs (format, data,
%   title): "png" pages hold base64 PNG at REPORT.options.Dpi, "svg" pages
%   the SVG text, each drawn into newExportFigure(REPORT.export).
fmt = report.options.EmbedFormat;
n = plotPageCount(R, spec);
images = cell(1, n);
for p = 1:n
    fig = newExportFigure(report.export);
    closer = onCleanup(@() close(fig));
    h = renderPlot(R, spec, fig, Page=p);
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
    images{p} = struct('format', fmt, 'data', data, 'title', string(h.title));
    clear closer
end
end
