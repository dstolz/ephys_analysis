function report = addReportFigure(report, spec, R, opts)
%addReportFigure  Add one plot to the current dataset of a report.
%   REPORT = addReportFigure(REPORT, SPEC, R, Files=F, Images=I, Pages=P)
%   adds the plot SPEC (plotFor) and its result R to the last dataset added
%   with addReportDataset, with its caption (plotCaption), the figure files
%   exported for it (F, linked from the HTML report), the HTML report's
%   image of each page (I: a cell of reportImage structs) and the PDF
%   report's page of each page (P: reportPdfPage's files), both made from
%   the figures that were exported, so nothing is drawn again.
%
%   What the report's Format needs and was not given is drawn now, every
%   page once: the images of an HTML report ("html" / "both", at the
%   report's Dpi, in its EmbedFormat) and the pages of a PDF report ("pdf"
%   / "both"). R itself is not kept, so a run over many datasets holds
%   only images and page files, never every result.
%
%   REPORT = addReportFigure(REPORT, SPEC, [], Status="error", Message=M)
%   records a plot that could not be drawn (listed in the report).
%
%   Caption=TXT gives the caption instead of plotCaption's. A figure of the
%   Figures section (SPEC with panels, its kind "figure"; R its
%   figureCompute result for one observation, figureCaption the caption)
%   is added as one entry for all its observations: its Images and Pages
%   are what the caller drew, page by page, and nothing is drawn here
%   (drawReportPages draws plots only).
%
%   See also newAnalysisReport, reportImage, reportPdfPage, writeHtmlReport,
%   writePdfReport.

arguments
    report (1,1) struct
    spec (1,1) struct
    R
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
isFigure = isfield(spec, 'panels');   % a figure of the Figures section: the caller draws its pages
kind = "figure";
if isfield(spec, 'kind'); kind = string(spec.kind); end
e = struct('plot', spec.id, 'kind', kind, 'title', spec.title, 'caption', "", 'spec', spec, ...
    'images', {cell(1, 0)}, 'pages', string.empty(1, 0), 'files', opts.Files, 'status', opts.Status, 'message', opts.Message);
if ~isempty(R) && opts.Status == "done"
    if ~isempty(opts.Caption)
        e.caption = string(opts.Caption);
    elseif ~isFigure
        e.caption = plotCaption(spec, R);
    end
    e.images = opts.Images;
    e.pages = opts.Pages;
    needImages = report.options.Format ~= "pdf" && isempty(e.images);
    needPages = report.options.Format ~= "html" && isempty(e.pages);
    if (needImages || needPages) && ~isFigure
        [images, pages] = drawReportPages(R, spec, report, Images=needImages, Pages=needPages);
        if needImages; e.images = images; end
        if needPages; e.pages = pages; end
    end
end
k = numel(report.datasets);
report.datasets(k).entries(end+1) = e;
end
