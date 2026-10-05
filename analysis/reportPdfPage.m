function file = reportPdfPage(fig, report, opts)
%reportPdfPage  One drawn page as the PDF report holds it: a vector PDF file.
%   FILE = reportPdfPage(FIG, REPORT, Files=F) writes the figure FIG (one
%   page drawn by renderPlot) as a one-page vector PDF (exportFigure,
%   Format "pdf") into REPORT's page folder (newAnalysisReport; it goes
%   when the report does) and returns its path, for
%   addReportFigure(..., Pages=). F lists the files just exported from FIG
%   (exportFigure): a .pdf among them is copied instead of exporting FIG
%   again.
%
%   The runner and the standalone script make the pages from the figures
%   they export, so a PDF report draws nothing again: writePdfReport puts
%   these pages together.
%
%   Errors: reportPdfPage:NoPages (a report started for HTML only).
%
%   See also reportImage, addReportFigure, writePdfReport, exportFigure.

arguments
    fig (1,1) matlab.ui.Figure
    report (1,1) struct
    opts.Files (1,:) string = string.empty(1, 0)
end

folder = report.pageFolder;
if folder == ""
    error('reportPdfPage:NoPages', 'The report keeps no PDF pages: start it with Options.Format "pdf" or "both".');
end
[~, name] = fileparts(tempname);
base = fullfile(folder, string(name));
pdf = opts.Files(endsWith(opts.Files, ".pdf", 'IgnoreCase', true));
if ~isempty(pdf)
    if ~isfolder(folder); mkdir(folder); end
    file = base + ".pdf";
    copyfile(pdf(1), file);
else
    file = exportFigure(fig, base, Format="pdf");   % creates the folder
end
end
