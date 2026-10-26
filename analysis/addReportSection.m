function report = addReportSection(report, name, opts)
%addReportSection  Start a section of a report that is not one dataset's (e.g. "Across sessions").
%   REPORT = addReportSection(REPORT, NAME, Summary=S) appends a section
%   titled NAME to REPORT.datasets (kind "section"; key and folder "") with
%   the summary tables S, a struct of tables (e.g. struct('sessions', T)),
%   shown when the report's IncludeSummary is on: writeHtmlReport and
%   writePdfReport print each field of a summary with its label
%   ("sessions" -> "Sessions"; an unknown field by its name). Figures added
%   next with addReportFigure go into this section.
%
%   See also newAnalysisReport, addReportDataset, addReportFigure.

arguments
    report (1,1) struct
    name (1,1) string
    opts.Summary = []
end

summary = [];
if report.options.IncludeSummary && isstruct(opts.Summary) && ~isempty(fieldnames(opts.Summary))
    summary = opts.Summary;
end
entry = struct('plot', {}, 'kind', {}, 'title', {}, 'caption', {}, 'spec', {}, ...
    'images', {}, 'pages', {}, 'files', {}, 'status', {}, 'message', {});
report.datasets(end+1) = struct('name', name, 'key', "", 'folder', "", 'summary', summary, 'entries', entry, ...
    'kind', "section", 'starred', false, 'tags', {{}});
end
