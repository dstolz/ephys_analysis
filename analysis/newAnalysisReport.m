function report = newAnalysisReport(opts)
%newAnalysisReport  An empty report to collect datasets and figures into.
%   REPORT = newAnalysisReport(Title=, Config=, Export=, Options=) starts
%   the struct that addReportDataset / addReportFigure fill and
%   writeHtmlReport / writePdfReport write:
%     title     the report's title
%     created   when it was started
%     config    the config as a plain struct (EphysAnalysisConfig.toStruct),
%               printed at the end when Options.IncludeConfig
%     options   the Report section (Format, EmbedFormat, Dpi, Include*)
%     export    the Export section (FigureSizeCm sizes the figures)
%     datasets  struct array: name, key, folder, summary, entries
%
%   See also addReportDataset, addReportFigure, writeHtmlReport,
%   writePdfReport, EphysAnalysisRunner.

arguments
    opts.Title (1,1) string = "Analysis report"
    opts.Config = struct()
    opts.Export = struct()
    opts.Options = struct()
end

report = struct();
report.title = opts.Title;
report.created = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
report.config = opts.Config;
report.options = EphysAnalysisConfig.normalizeSection("Report", opts.Options);
report.export = EphysAnalysisConfig.normalizeSection("Export", opts.Export);
report.datasets = struct('name', {}, 'key', {}, 'folder', {}, 'summary', {}, 'entries', {});
end
