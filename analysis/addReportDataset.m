function report = addReportDataset(report, src)
%addReportDataset  Start a dataset's section of a report.
%   REPORT = addReportDataset(REPORT, SRC) appends the dataset SRC
%   (loadAnalysisSource) with its summary tables (reportSummaryTables, when
%   the report's IncludeSummary is on) and its star (starred: the
%   dataset's own star, DatasetFavorites; the reports mark it). Figures
%   added next with addReportFigure go into this section.
%
%   See also newAnalysisReport, addReportFigure, reportSummaryTables,
%   DatasetFavorites.

arguments
    report (1,1) struct
    src (1,1) struct
end

summary = [];
if report.options.IncludeSummary
    summary = reportSummaryTables(src);
end
entry = struct('plot', {}, 'kind', {}, 'title', {}, 'caption', {}, 'spec', {}, ...
    'images', {}, 'pages', {}, 'files', {}, 'status', {}, 'message', {}, 'obsKeys', {}, 'obsLabels', {});
starred = false;
try
    fav = DatasetFavorites(src);
    starred = fav.Dataset;
catch   % a source without outputs: no star
end
report.datasets(end+1) = struct('name', src.name, 'key', src.key, 'folder', src.folder, ...
    'summary', summary, 'entries', entry, 'kind', "dataset", 'starred', starred);
end
