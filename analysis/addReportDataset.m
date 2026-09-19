function report = addReportDataset(report, src)
%addReportDataset  Start a dataset's section of a report.
%   REPORT = addReportDataset(REPORT, SRC) appends the dataset SRC
%   (loadAnalysisSource) with its summary tables (reportSummaryTables, when
%   the report's IncludeSummary is on). Figures added next with
%   addReportFigure go into this section.
%
%   See also newAnalysisReport, addReportFigure, reportSummaryTables.

arguments
    report (1,1) struct
    src (1,1) struct
end

summary = [];
if report.options.IncludeSummary
    summary = reportSummaryTables(src);
end
entry = struct('plot', {}, 'kind', {}, 'title', {}, 'caption', {}, 'spec', {}, 'R', {}, ...
    'images', {}, 'files', {}, 'status', {}, 'message', {});
report.datasets(end+1) = struct('name', src.name, 'key', src.key, 'folder', src.folder, ...
    'summary', summary, 'entries', entry);
end
