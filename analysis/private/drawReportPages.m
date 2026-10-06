function [images, pages] = drawReportPages(R, spec, report, opts)
%drawReportPages  Every page of a plot drawn once for the report: its HTML images and / or its PDF pages.
%   [IMAGES, PAGES] = drawReportPages(R, SPEC, REPORT, Images=TF, Pages=TF)
%   draws each page into newExportFigure(REPORT.export, R, SPEC, Page=p)
%   and makes its reportImage (Images: a cell of structs) and its
%   reportPdfPage (Pages: a string of files): for a plot added to the
%   report without those of its exported pages (addReportFigure).
arguments
    R (1,1) struct
    spec (1,1) struct
    report (1,1) struct
    opts.Images (1,1) logical = true
    opts.Pages (1,1) logical = false
end
n = plotPageCount(R, spec);
images = cell(1, 0);
pages = strings(1, 0);
if opts.Images; images = cell(1, n); end
if opts.Pages; pages = strings(1, n); end
for p = 1:n
    fig = newExportFigure(report.export, R, spec, Page=p);
    closer = onCleanup(@() close(fig));
    h = renderPlot(R, spec, fig, Page=p);
    if opts.Images; images{p} = reportImage(fig, report, Title=h.title); end
    if opts.Pages; pages(p) = reportPdfPage(fig, report); end
    clear closer
end
end
