function report = addReportFigure(report, spec, F, opts)
%addReportFigure  Add one figure to the current dataset of a report.
%   REPORT = addReportFigure(REPORT, SPEC, F, Files=, Images=, Pages=,
%   Observations=, Caption=) adds the figure SPEC (figureFor's spec; its kind "figure",
%   given or assumed) to the last dataset added with addReportDataset, as
%   one entry for all its observations: F is a figureCompute result of it
%   (any one observation's: it is not kept), Caption its caption
%   (figureCaption), Files the figure files exported for it (linked from
%   the HTML report), Images the HTML report's image of each page (a cell
%   of reportImage structs) and Pages the PDF report's page of each page
%   (reportPdfPage's files), all made by the caller from the pages it drew,
%   so nothing is drawn here and a run over many datasets holds only
%   images and page files, never every result. Observations is the
%   figureObservations table of the pages, a row per page in their order:
%   the entry keeps each page's observation (obsKeys: "unit|<data>|<id>",
%   "channel|<data>|<channel>" or "dataset"; obsLabels: its picker label
%   without the trial group), which the reports group the pages by when
%   Report.Order is "unit". Without it, or when its rows do not match the
%   pages, the entry keeps none and is reported whole, in figure order.
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
    opts.Observations = []   % figureObservations rows, one per page
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
    'images', {cell(1, 0)}, 'pages', string.empty(1, 0), 'files', opts.Files, 'status', opts.Status, 'message', opts.Message, ...
    'obsKeys', string.empty(1, 0), 'obsLabels', string.empty(1, 0));
if ~isempty(F) && opts.Status == "done"
    if ~isempty(opts.Caption); e.caption = string(opts.Caption); end
    e.images = opts.Images;
    e.pages = opts.Pages;
    T = opts.Observations;
    if istable(T) && height(T) > 0 && height(T) == max(numel(e.images), numel(e.pages))
        data = "";
        if isfield(spec, 'observe') && isfield(spec.observe, 'data'); data = string(spec.observe.data); end
        [e.obsKeys, e.obsLabels] = observationKeys(T, data);
    end
end
k = numel(report.datasets);
report.datasets(k).entries(end+1) = e;
end


function [keys, labels] = observationKeys(T, data)
%observationKeys  Each row's observation as the reports group it: a key and its label (the trial group dropped).
%   A unit: "unit|<data>|<unitId>"; a channel: "channel|<data>|<recording
%   channel>" (one without a recording channel, e.g. AUX, by its label);
%   the dataset: "dataset". Every trial group of one observation shares
%   its key.
n = height(T);
keys = strings(1, n);
labels = strings(1, n);
for i = 1:n
    lab = T.label(i);
    g = T.groupLabel(i);
    if g ~= "" && endsWith(lab, " · " + g)
        lab = extractBefore(lab, strlength(lab) - strlength(g) - 2);
    end
    labels(i) = lab;
    switch T.kind(i)
        case "unit"
            keys(i) = "unit|" + data + "|" + T.unitId(i);
        case "channel"
            if isfinite(T.channel(i))
                keys(i) = "channel|" + data + "|" + T.channel(i);
            else
                keys(i) = "channel|" + data + "|" + lab;
            end
        otherwise
            keys(i) = "dataset";
    end
end
end
