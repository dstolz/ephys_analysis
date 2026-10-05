function images = reportImages(R, spec, report)
%reportImages  Every page of a plot drawn for the HTML report.
%   IMAGES = reportImages(R, SPEC, REPORT) is a cell of reportImage structs
%   (format, data, title), one per page, each drawn into
%   newExportFigure(REPORT.export, R, SPEC, Page=p): for a plot added to the
%   report without the images of its exported pages (addReportFigure).
n = plotPageCount(R, spec);
images = cell(1, n);
for p = 1:n
    fig = newExportFigure(report.export, R, spec, Page=p);
    closer = onCleanup(@() close(fig));
    h = renderPlot(R, spec, fig, Page=p);
    images{p} = reportImage(fig, report, Title=h.title);
    clear closer
end
end
