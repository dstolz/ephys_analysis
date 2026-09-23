function report = addReportFigure(report, spec, R, opts)
%addReportFigure  Add one plot to the current dataset of a report.
%   REPORT = addReportFigure(REPORT, SPEC, R, Files=F, Images=I) adds the
%   plot SPEC (plotFor) and its result R to the last dataset added with
%   addReportDataset, with its caption (plotCaption), the figure files
%   exported for it (F, linked from the HTML report) and the HTML report's
%   image of each page (I: a cell of reportImage structs, made from the
%   figures that were exported, so nothing is drawn again).
%
%   Without Images, a report written only as HTML draws every page now
%   (at the report's Dpi, in its EmbedFormat). An HTML-only report then
%   drops R, so a run over many datasets does not hold every result; a PDF
%   report ("pdf" / "both") keeps R to draw it again as vector pages (and,
%   without Images, the HTML images when it is written).
%
%   REPORT = addReportFigure(REPORT, SPEC, [], Status="error", Message=M)
%   records a plot that could not be drawn (listed in the report).
%
%   See also newAnalysisReport, reportImage, writeHtmlReport, writePdfReport.

arguments
    report (1,1) struct
    spec (1,1) struct
    R
    opts.Files (1,:) string = string.empty(1,0)
    opts.Images (1,:) cell = cell(1, 0)
    opts.Status (1,1) string = "done"
    opts.Message (1,1) string = ""
end

if isempty(report.datasets)
    error('addReportFigure:NoDataset', 'Add a dataset (addReportDataset) before its figures.');
end
e = struct('plot', spec.id, 'kind', spec.kind, 'title', spec.title, 'caption', "", 'spec', spec, ...
    'R', [], 'images', {cell(1, 0)}, 'files', opts.Files, 'status', opts.Status, 'message', opts.Message);
if ~isempty(R) && opts.Status == "done"
    e.caption = plotCaption(spec, R);
    e.images = opts.Images;
    if report.options.Format ~= "html"
        e.R = R;
    elseif isempty(e.images)
        e.images = reportImages(R, spec, report);
    end
end
k = numel(report.datasets);
report.datasets(k).entries(end+1) = e;
end
