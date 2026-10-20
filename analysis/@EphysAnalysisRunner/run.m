function T = run(obj, opts)
%run  Run every enabled figure on every dataset, then the session figures; export and report.
%   T = r.run(Datasets=, Figures=, SessionFigures=, Export=, Report=) runs
%   runDataset on each dataset in turn (its figures, a page per
%   observation) and returns (and keeps in r.Results) one row per dataset
%   and figure: Dataset, Plot (the figure's id), Kind ("figure"), Status
%   (done | skipped | error | canceled), Message, Files, Seconds. With
%   Report it builds the report (newAnalysisReport) and writes it
%   (Report.Format: html, pdf or both) to Report.Folder / Report.FileName
%   -- one report over all datasets, or one per dataset with
%   Report.PerDataset. The written files are in r.ReportFiles.
%   ProgressFcn hears how far the whole run is: dataset j of n starts at
%   (j-1)/n and its figures share its 1/n. cancel() stops before the next
%   figure observation; the rest are "canceled". Every run that reaches a
%   dataset ends by writing a run record (config, code version, machine,
%   Results) to <report folder>/analysis_runs (r.RunRecordFile).
%
%   Session figures (SessionFigures=: figures whose sessions.enabled is
%   true; never drawn per dataset, whatever Figures= names) run after the
%   datasets, unless the run was canceled: the report gets a section
%   "Across sessions" (addReportSection, its summary the sessions table),
%   then each session figure runs (runSessionFigure: a page per matched
%   observation, rows "sessions: <label>" of Kind "figure"). With
%   Report.PerDataset they get a report of their own,
%   <FileName>_sessions. Progress spans the datasets and the session
%   figures alike (each one 1 / (nDatasets + nSessionFigures) of the
%   run, and the one report over them all a share of its own, after
%   them); a cancel during the session figures marks it and the rest
%   "canceled". Writing a report reports its pages ("Writing the report:
%   page 3/12"), and a per-dataset report's pages at its dataset's end.
%
%   The run record (schema "ephys-analysis-run/2") holds the run id,
%   outcome, start, end and seconds, the datasets, figures and session
%   figures, the report files, the Results rows, the code and machine
%   (ephysProvenance) and the config.
%
%   Options
%     Datasets        indices, keys or names (default all)
%     Figures         figure ids ([] = default: Config.enabledFigures();
%                     string.empty(1, 0) = none)
%     SessionFigures  session figure ids ([] = default:
%                     Config.enabledSessionFigures(); string.empty = none),
%                     e.g. one session figure alone: run(SessionFigures=id,
%                     Figures=string.empty(1, 0))
%     Export          write figure files (default Config.Export.Enabled)
%     Report          write the report (default Config.Report.Enabled)
%     Observation     one observation (a struct: kind "unit" | "channel",
%                     data, unitId, channel, label; default [] = all):
%                     each figure is drawn only for what matches it
%                     (runDataset, figureObservations), a figure with
%                     no match is "skipped" with the reason, and no
%                     session figure runs (the app's Unit report)
%
%   See also EphysAnalysisRunner.runDataset, EphysAnalysisRunner.runSessionFigure,
%   EphysAnalysisRunner.plan, writeHtmlReport, writePdfReport.

arguments
    obj (1,1) EphysAnalysisRunner
    opts.Datasets = []
    opts.Figures = []
    opts.SessionFigures = []
    opts.Export = []
    opts.Report = []
    opts.Observation = []
end

cfg = obj.Config;
obj.CancelRequested = false;
obj.RunRecordFile = "";
started = datetime('now');
doExport = cfg.Export.Enabled;
if ~isempty(opts.Export); doExport = logical(opts.Export); end
doReport = cfg.Report.Enabled;
if ~isempty(opts.Report); doReport = logical(opts.Report); end
fids = EphysAnalysisRunner.idList(opts.Figures, @() cfg.enabledFigures());
fids = fids(~arrayfun(@(f) cfg.isSessionFigure(f), fids));   % session figures are drawn across the datasets, not per dataset
sfids = EphysAnalysisRunner.idList(opts.SessionFigures, @() cfg.enabledSessionFigures());
if isstruct(opts.Observation); sfids = string.empty(1, 0); end   % one dataset's observation: no figure across the sessions
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
obj.log("Analysis ""%s"": %d dataset(s) x %d figure(s), %d session figure(s)", cfg.Name, numel(idx), numel(fids), numel(sfids));
canceled = false;
nUnits = numel(idx) + numel(sfids) + (doReport && ~perDataset);   % the run's progress: a share per dataset, session figure and the one report
for j = 1:numel(idx)
    k = idx(j);
    if perDataset; obj.Report = newReport(cfg); end
    try
        span = [j - 1, j] / nUnits;   % this dataset's share of the run, which its figures report within
        obj.progress(span(1), "Dataset " + obj.Names(k));
        obj.runDataset(k, Figures=fids, Export=doExport, Report=doReport, Span=span, ...
            Observation=opts.Observation);   % appends to obj.Results
    catch ME
        if ME.identifier ~= "EphysAnalysisRunner:Canceled"; rethrow(ME); end
        canceled = true;
        if ~any(obj.Results.Dataset == obj.Names(k))   % canceled before the dataset started
            cancelDataset(obj, obj.Names(k), fids);
        end
    end
    if canceled
        for kk = idx(j+1:end)
            cancelDataset(obj, obj.Names(kk), fids);
        end
        cancelSessionFigures(obj, sfids);
        obj.log("Canceled.");
        break
    end
    if perDataset
        obj.ReportFiles = [obj.ReportFiles writeReports(obj, k, obj.Names(k), [j j] / nUnits)];
    end
end

% --- session figures, after the datasets -----------------------------------------------------
if ~canceled && ~isempty(sfids) && ~isempty(idx)
    if doReport
        if perDataset; obj.Report = newReport(cfg); end
        obj.Report = addReportSection(obj.Report, "Across sessions", Summary=struct('sessions', sessionsSummary(obj, idx)));
    end
    for i = 1:numel(sfids)
        span = [numel(idx) + i - 1, numel(idx) + i] / nUnits;
        try
            obj.progress(span(1), "Session figure " + sfids(i));
            obj.runSessionFigure(sfids(i), idx, Export=doExport, Report=doReport, Span=span);   % appends to obj.Results
        catch ME
            if ME.identifier ~= "EphysAnalysisRunner:Canceled"; rethrow(ME); end
            canceled = true;
            cancelSessionFigures(obj, sfids(i:end));
            obj.log("Canceled.");
            break
        end
    end
    if perDataset && ~canceled
        obj.ReportFiles = [obj.ReportFiles writeReports(obj, idx(1), "sessions", [1 1])];
    end
end
if doReport && ~perDataset && ~canceled && ~isempty(idx)
    obj.ReportFiles = writeReports(obj, idx(1), obj.Names(idx(1)), [nUnits - 1, nUnits] / nUnits);
end
if ~isempty(idx)
    outcome = "finished";
    if canceled; outcome = "canceled"; end
    obj.RunRecordFile = writeRunRecord(obj, idx, fids, sfids, started, outcome);
end
try
    obj.progress(1, "Done");
catch
end
T = obj.Results;
end


function cancelSessionFigures(obj, sfids)
%cancelSessionFigures  A "canceled" row for each session figure not run.
for id = sfids
    if ~any(obj.Results.Plot == id & startsWith(obj.Results.Dataset, "sessions: "))
        obj.Results(end+1, :) = {"sessions: all", id, "figure", "canceled", "canceled", "", 0};
    end
end
end


function T = sessionsSummary(obj, idx)
%sessionsSummary  The "Across sessions" section's table: the run's sessions by date.
S = obj.sessionTable(idx);
T = table(S.label, S.subject, S.dateText, S.name, S.key, ...
    'VariableNames', {'Session', 'Subject', 'Date', 'Dataset', 'Key'});
end


function file = writeRunRecord(obj, idx, fids, sfids, started, outcome)
%writeRunRecord  What this run did and with what: <report folder>/analysis_runs/<runId>_<name>.json.
%   Schema ephys-analysis-run/2: the run id, outcome, start, end, the
%   datasets, figures and session figures, the report files, the Results
%   rows, the code and machine (ephysProvenance) and the config. The
%   report folder is Report.Folder resolved for the first dataset, whether
%   or not a report was written. A record that cannot be written is a
%   warning, never an error.
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
    rec.schema = "ephys-analysis-run/2";
    rec.runId = prov.runId;
    rec.name = cfg.Name;
    rec.outcome = string(outcome);
    rec.started = string(started, "yyyy-MM-dd'T'HH:mm:ss");
    rec.finished = string(finished, "yyyy-MM-dd'T'HH:mm:ss");
    rec.seconds = seconds(finished - started);
    rec.datasets = cellstr(obj.Names(idx));
    rec.figures = cellstr(fids);
    rec.sessionFigures = cellstr(sfids);
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


function files = writeReports(obj, k, name, span)
%writeReports  Write obj.Report as HTML and / or PDF (reportFiles); {OutputFolder} = dataset K's.
%   NAME (the dataset's name for a per-dataset report) is the report's
%   {Name}: "sessions" names the session figures' own report
%   <FileName>_sessions. ProgressFcn hears its pages ("Writing the report:
%   page 3/12") across SPAN, the run's fraction [from to] it has (both
%   the same: the bar stays); a cancel waits for the report to be written.
cfg = obj.Config;
want = EphysAnalysisRunner.reportFiles(cfg, struct('OutputFolder', obj.datasetFolder(k), ...
    'OutputRoot', obj.outputRoot(), 'Root', cfg.Source.Root, 'Name', name));
files = string.empty(1, 0);
nf = numel(want);
for i = 1:nf
    f = want(i);
    part = span(1) + (span(2) - span(1)) * [i - 1, i] / nf;
    report = @(done, total, msg) reportProgress(obj, part(1) + (part(2) - part(1)) * done / max(total, 1), msg);
    if endsWith(f, ".html")
        files(end+1) = writeHtmlReport(obj.Report, f, ProgressFcn=report); %#ok<AGROW>
    else
        files(end+1) = writePdfReport(obj.Report, f, ProgressFcn=report); %#ok<AGROW>
    end
end
obj.log("Report: %s", strjoin(files, ", "));
end


function reportProgress(obj, fraction, message)
%reportProgress  ProgressFcn(fraction, message) while a report is written; unlike
%   progress(), never a cancel: the datasets' pages are drawn, so the report is finished.
if ~isempty(obj.ProgressFcn)
    obj.ProgressFcn(fraction, string(message));
end
end


function cancelDataset(obj, name, fids)
%cancelDataset  A "canceled" row for each figure of a dataset the run did not reach.
for id = fids
    obj.Results(end+1, :) = {name, id, "figure", "canceled", "canceled", "", 0};
end
end
