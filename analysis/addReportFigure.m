function report = addReportFigure(report, spec, F, opts)
%addReportFigure  Add one figure to the current dataset of a report.
%   REPORT = addReportFigure(REPORT, SPEC, F, Files=, Images=, Pages=,
%   Caption=) adds the figure SPEC (figureFor's spec; its kind "figure",
%   given or assumed) to the last dataset added with addReportDataset, as
%   one entry for all its observations: F is a figureCompute result of it
%   (any one observation's: it is not kept), Caption its caption
%   (figureCaption), Files the figure files exported for it (linked from
%   the HTML report), Images the HTML report's image of each page (a cell
%   of reportImage structs) and Pages the PDF report's page of each page
%   (reportPdfPage's files), all made by the caller from the pages it drew,
%   so nothing is drawn here and a run over many datasets holds only
%   images and page files, never every result.
%
%   REPORT = addReportFigure(REPORT, SPEC, [], Status="error", Message=M)
%   records a figure that could not be drawn (or Status="skipped": one
%   that was not), listed in the report with M.
%
%   See also newAnalysisReport, figureCaption, reportImage, reportPdfPage,
%   writeHtmlReport, writePdfReport.

arguments
    report (1,1) struct
    spec (1,1) struct
    F
    opts.Files (1,:) string = string.empty(1,0)
    opts.Images (1,:) cell = cell(1, 0)
    opts.Pages (1,:) string = string.empty(1, 0)
    opts.Status (1,1) string = "done"
    opts.Message (1,1) string = ""
    opts.Caption = []
end

if isempty(report.datasets)
    error('addReportFigure:NoDataset', 'Add a dataset (addReportDataset) before its figures.');
end
kind = "figure";
if isfield(spec, 'kind'); kind = string(spec.kind); end
e = struct('plot', spec.id, 'kind', kind, 'title', spec.title, 'caption', "", 'spec', spec, ...
    'images', {cell(1, 0)}, 'pages', string.empty(1, 0), 'files', opts.Files, 'status', opts.Status, 'message', opts.Message);
if ~isempty(F) && opts.Status == "done"
    if ~isempty(opts.Caption); e.caption = string(opts.Caption); end
    e.images = opts.Images;
    e.pages = opts.Pages;
end
k = numel(report.datasets);
report.datasets(k).entries(end+1) = e;
end
