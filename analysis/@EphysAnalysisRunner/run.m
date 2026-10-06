function T = run(obj, opts)
%run  Run every enabled plot on every dataset; export and report.
%   T = r.run(Datasets=, Plots=, Export=, Report=) runs runDataset on each
%   dataset in turn and returns (and keeps in r.Results) one row per dataset
%   and plot: Dataset, Plot, Kind, Status (done | skipped | error |
%   cancelled), Message, Files, Seconds. With Report it builds the report
%   (newAnalysisReport) and writes it (Report.Format: html, pdf or both)
%   to Report.Folder / Report.FileName -- one report over all datasets, or
%   one per dataset with Report.PerDataset. The written files are in
%   r.ReportFiles. ProgressFcn hears how far the whole run is: dataset j of
%   n starts at (j-1)/n and its plots share its 1/n. cancel() stops before
%   the next plot; the rest are "cancelled". Every run that reaches a
%   dataset ends by writing a run record (config, code version, machine, Results) to
%   <report folder>/analysis_runs (r.RunRecordFile).
%
%   Options
%     Datasets  indices, keys or names (default all)
%     Plots     plot ids (default Config.enabledPlots())
%     Export    write figure files (default Config.Export.Enabled)
%     Report    write the report (default Config.Report.Enabled)
%
%   See also EphysAnalysisRunner.runDataset, EphysAnalysisRunner.plan,
%   writeHtmlReport, writePdfReport.

arguments
    obj (1,1) EphysAnalysisRunner
    opts.Datasets = []
    opts.Plots (1,:) string = string.empty(1, 0)
    opts.Export = []
    opts.Report = []
end

cfg = obj.Config;
obj.CancelRequested = false;
obj.RunRecordFile = "";
started = datetime('now');
doExport = cfg.Export.Enabled;
if ~isempty(opts.Export); doExport = logical(opts.Export); end
doReport = cfg.Report.Enabled;
if ~isempty(opts.Report); doReport = logical(opts.Report); end
ids = opts.Plots;
if isempty(ids); ids = cfg.enabledPlots(); end
if isempty(opts.Datasets)
    idx = 1:numel(obj.Outputs);
elseif isnumeric(opts.Datasets)
    idx = reshape(opts.Datasets, 1, []);
else
    idx = arrayfun(@(k) obj.index(k), reshape(string(opts.Datasets), 1, []));
    idx = idx(idx > 0);
end
obj.Results = EphysAnalysisRunner.emptyResults();
obj.ReportFiles = string.empty(1, 0);
P = cfg.Report;
perDataset = doReport && P.PerDataset;
if doReport && ~perDataset
    obj.Report = newReport(cfg);
end
obj.log("Analysis ""%s"": %d dataset(s) x %d plot(s)", cfg.Name, numel(idx), numel(ids));
cancelled = false;
for j = 1:numel(idx)
    k = idx(j);
    if perDataset; obj.Report = newReport(cfg); end
    try
        span = [j - 1, j] / numel(idx);   % this dataset's share of the run, which its plots report within
        obj.progress(span(1), "Dataset " + obj.Names(k));
        obj.runDataset(k, Plots=ids, Export=doExport, Report=doReport, Span=span);   % appends to obj.Results
    catch ME
        if ME.identifier ~= "EphysAnalysisRunner:Cancelled"; rethrow(ME); end
        cancelled = true;
        if ~any(obj.Results.Dataset == obj.Names(k))   % cancelled before the dataset started
            for id = ids
                obj.Results(end+1, :) = {obj.Names(k), id, kindOf(cfg, id), "cancelled", "cancelled", "", 0};
            end
        end
    end
    if cancelled
        for kk = idx(j+1:end)
            for id = ids
                obj.Results(end+1, :) = {obj.Names(kk), id, kindOf(cfg, id), "cancelled", "cancelled", "", 0};
            end
        end
        obj.log("Cancelled.");
        break
    end
    if perDataset
        obj.ReportFiles = [obj.ReportFiles writeReports(obj, k)];
    end
end
if doReport && ~perDataset && ~cancelled && ~isempty(idx)
    obj.ReportFiles = writeReports(obj, idx(1));
end
if ~isempty(idx)
    outcome = "finished";
    if cancelled; outcome = "cancelled"; end
    obj.RunRecordFile = writeRunRecord(obj, idx, ids, started, outcome);
end
try
    obj.progress(1, "Done");
catch
end
T = obj.Results;
end


function file = writeRunRecord(obj, idx, ids, started, outcome)
%writeRunRecord  What this run did and with what: <report folder>/analysis_runs/<runId>_<name>.json.
%   Schema ephys-analysis-run/1: the run id, outcome, start, end, the
%   datasets and plots, the report files, the Results rows, the code and
%   machine (ephysProvenance) and the config. The report folder is
%   Report.Folder resolved for the first dataset, whether or not a report
%   was written. A record that cannot be written is a warning, never an
%   error.
file = "";
try
    cfg = obj.Config;
    folder = figureFileName(cfg.Report.Folder, struct('OutputFolder', obj.datasetFolder(idx(1)), ...
        'OutputRoot', obj.outputRoot(), 'Root', cfg.Source.Root, 'Name', obj.Names(idx(1))), Kind="folder");
    prov = ephysProvenance(RunId=string(started, "yyyyMMdd'T'HHmmssSSS"));
    name = regexprep(char(cfg.Name), '[^\w\-]', '_');
    if isempty(name); name = 'analysis'; end
    file = string(fullfile(folder, "analysis_runs", prov.runId + "_" + name + ".json"));
    finished = datetime('now');
    rec = struct();
    rec.schema = "ephys-analysis-run/1";
    rec.runId = prov.runId;
    rec.name = cfg.Name;
    rec.outcome = string(outcome);
    rec.started = string(started, "yyyy-MM-dd'T'HH:mm:ss");
    rec.finished = string(finished, "yyyy-MM-dd'T'HH:mm:ss");
    rec.seconds = seconds(finished - started);
    rec.datasets = cellstr(obj.Names(idx));
    rec.plots = cellstr(ids);
    rec.reportFiles = cellstr(obj.ReportFiles);
    rec.results = num2cell(table2struct(obj.Results)).';
    rec.provenance = rmfield(prov, 'config');
    rec.config = cfg.toStruct();
    writeJsonFile(file, rec, NonFinite="string");
    obj.log("Run record: %s", file);
catch ME
    warning('EphysAnalysisRunner:RunRecord', 'The run record could not be written (%s): %s', file, ME.message);
    file = "";
end
end


function report = newReport(cfg)
title = replace(cfg.Report.Title, "{Name}", cfg.Name);
title = replace(title, "{Date}", string(datetime('now', 'Format', 'yyyy-MM-dd')));
report = newAnalysisReport(Title=title, Config=cfg.toStruct(), Export=cfg.Export, Options=cfg.Report);
end


function files = writeReports(obj, k)
%writeReports  Write obj.Report as HTML and / or PDF (reportFiles); {OutputFolder} = dataset K's.
cfg = obj.Config;
want = EphysAnalysisRunner.reportFiles(cfg, struct('OutputFolder', obj.datasetFolder(k), ...
    'OutputRoot', obj.outputRoot(), 'Root', cfg.Source.Root, 'Name', obj.Names(k)));
files = string.empty(1, 0);
for f = want
    if endsWith(f, ".html")
        files(end+1) = writeHtmlReport(obj.Report, f); %#ok<AGROW>
    else
        files(end+1) = writePdfReport(obj.Report, f); %#ok<AGROW>
    end
end
obj.log("Report: %s", strjoin(files, ", "));
end


function k = kindOf(cfg, id)
k = cfg.Plots(cfg.plotIndex(id)).kind;
end