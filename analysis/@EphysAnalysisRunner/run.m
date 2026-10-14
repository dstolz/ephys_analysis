function T = run(obj, opts)
%run  Run every enabled plot and figure on every dataset; export and report.
%   T = r.run(Datasets=, Plots=, Figures=, Export=, Report=) runs
%   runDataset on each dataset in turn (its plots, then its figures, a
%   page per observation) and returns (and keeps in r.Results) one row per
%   dataset and plot or figure: Dataset, Plot (the plot's or figure's id),
%   Kind ("figure" for a figure), Status (done | skipped | error |
%   canceled), Message, Files, Seconds. With Report it builds the report
%   (newAnalysisReport) and writes it (Report.Format: html, pdf or both)
%   to Report.Folder / Report.FileName -- one report over all datasets, or
%   one per dataset with Report.PerDataset. The written files are in
%   r.ReportFiles. ProgressFcn hears how far the whole run is: dataset j of
%   n starts at (j-1)/n and its plots and figures share its 1/n. cancel()
%   stops before the next plot or figure observation; the rest are
%   "canceled". Every run that reaches a
%   dataset ends by writing a run record (config, code version, machine, Results) to
%   <report folder>/analysis_runs (r.RunRecordFile).
%
%   Session plots (SessionPlots=) run after the datasets, unless the run
%   was canceled: the report gets a section "Across sessions"
%   (addReportSection, its summary the sessions table), then each session
%   plot runs (runSessionPlot) and adds its "sessions: <label>" rows. The
%   result cache is cleared at the start and told which per-dataset
%   results the session plots need (CacheWanted), so runDataset keeps them
%   and a session plot whose spec matches its base plot's computes nothing
%   again. With Report.PerDataset the session plots get a report of their
%   own, <FileName>_sessions. Progress spans the datasets and the session
%   plots alike (each one 1 / (nDatasets + nSessionPlots) of the run); a
%   cancel during the session plots marks them and the rest "canceled".
%
%   Options
%     Datasets      indices, keys or names (default all)
%     Plots         plot ids ([] = default: Config.enabledPlots();
%                   string.empty(1, 0) = none)
%     Figures       figure ids ([] = default: Config.enabledFigures();
%                   string.empty(1, 0) = none), e.g. one figure alone:
%                   run(Figures=id, Plots=string.empty(1, 0))
%     SessionPlots  session plot ids (default Config.enabledSessionPlots();
%                   string.empty = none)
%     Export        write figure files (default Config.Export.Enabled)
%     Report        write the report (default Config.Report.Enabled)
%
%   See also EphysAnalysisRunner.runDataset, EphysAnalysisRunner.runSessionPlot,
%   EphysAnalysisRunner.plan, writeHtmlReport, writePdfReport.

arguments
    obj (1,1) EphysAnalysisRunner
    opts.Datasets = []
    opts.Plots = []
    opts.Figures = []
    opts.SessionPlots = []
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
ids = EphysAnalysisRunner.idList(opts.Plots, @() cfg.enabledPlots());
fids = EphysAnalysisRunner.idList(opts.Figures, @() cfg.enabledFigures());
if isempty(opts.Datasets)
    idx = 1:numel(obj.Outputs);
elseif isnumeric(opts.Datasets)
    idx = reshape(opts.Datasets, 1, []);
else
    idx = arrayfun(@(k) obj.index(k), reshape(string(opts.Datasets), 1, []));
    idx = idx(idx > 0);
end
sids = opts.SessionPlots;
if isnumeric(sids) && isempty(sids)
    sids = cfg.enabledSessionPlots();
else
    sids = reshape(string(sids), 1, []);
end
obj.Results = EphysAnalysisRunner.emptyResults();
obj.ReportFiles = string.empty(1, 0);
obj.clearResultCache();
obj.CacheWanted = wantedKeys(obj, sids, idx);
P = cfg.Report;
perDataset = doReport && P.PerDataset;
if doReport && ~perDataset
    obj.Report = newReport(cfg);
end
obj.log("Analysis ""%s"": %d dataset(s) x %d plot(s) and %d figure(s), %d session plot(s)", ...
    cfg.Name, numel(idx), numel(ids), numel(fids), numel(sids));
canceled = false;
nUnits = numel(idx) + numel(sids);   % the run's progress: a share per dataset and per session plot
for j = 1:numel(idx)
    k = idx(j);
    if perDataset; obj.Report = newReport(cfg); end
    try
        span = [j - 1, j] / nUnits;   % this dataset's share of the run, which its plots report within
        obj.progress(span(1), "Dataset " + obj.Names(k));
        obj.runDataset(k, Plots=ids, Figures=fids, Export=doExport, Report=doReport, Span=span);   % appends to obj.Results
    catch ME
        if ME.identifier ~= "EphysAnalysisRunner:Canceled"; rethrow(ME); end
        canceled = true;
        if ~any(obj.Results.Dataset == obj.Names(k))   % canceled before the dataset started
            cancelDataset(obj, obj.Names(k), ids, fids);
        end
    end
    if canceled
        for kk = idx(j+1:end)
            cancelDataset(obj, obj.Names(kk), ids, fids);
        end
        cancelSessionPlots(obj, sids);
        obj.log("Canceled.");
        break
    end
    if perDataset
        obj.ReportFiles = [obj.ReportFiles writeReports(obj, k)];
    end
end

% --- session plots, after the datasets --------------------------------------------------
if ~canceled && ~isempty(sids) && ~isempty(idx)
    if doReport
        if perDataset; obj.Report = newReport(cfg); end
        obj.Report = addReportSection(obj.Report, "Across sessions", Summary=struct('sessions', sessionsSummary(obj, idx)));
    end
    for i = 1:numel(sids)
        span = [numel(idx) + i - 1, numel(idx) + i] / nUnits;
        try
            obj.progress(span(1), "Session plot " + sids(i));
            obj.runSessionPlot(sids(i), idx, Export=doExport, Report=doReport, Span=span);   % appends to obj.Results
        catch ME
            if ME.identifier ~= "EphysAnalysisRunner:Canceled"; rethrow(ME); end
            canceled = true;
            cancelSessionPlots(obj, sids(i:end));
            obj.log("Canceled.");
            break
        end
    end
    if perDataset && ~canceled
        obj.ReportFiles = [obj.ReportFiles writeReports(obj, idx(1), "sessions")];
    end
end
if doReport && ~perDataset && ~canceled && ~isempty(idx)
    obj.ReportFiles = writeReports(obj, idx(1));
end
if ~isempty(idx)
    outcome = "finished";
    if canceled; outcome = "canceled"; end
    obj.RunRecordFile = writeRunRecord(obj, idx, ids, fids, sids, started, outcome);
end
try
    obj.progress(1, "Done");
catch
end
T = obj.Results;
end


function keys = wantedKeys(obj, sids, idx)
%wantedKeys  The cache keys of the session plots' per-dataset results (runDataset keeps those it computes).
keys = string.empty(1, 0);
cfg = obj.Config;
for id = sids
    try
        spec = cfg.sessionPlotFor(id);
        sp = cfg.SessionPlots(cfg.sessionPlotIndex(id));
    catch
        continue   % no base plot: runSessionPlot reports it
    end
    ks = idx;
    if sp.datasets == "list"
        ks = arrayfun(@(key) obj.index(key), reshape(sp.datasetKeys, 1, []));
        ks = ks(ks > 0);
    end
    for k = ks
        keys(end+1) = EphysAnalysisRunner.cacheKey(obj.Keys(k), spec); %#ok<AGROW>
    end
end
keys = unique(keys, 'stable');
end


function cancelSessionPlots(obj, sids)
%cancelSessionPlots  A "canceled" row for each session plot not run.
cfg = obj.Config;
for id = sids
    kind = "";
    k = cfg.sessionPlotIndex(id);
    if k > 0 && cfg.plotIndex(cfg.SessionPlots(k).plot) > 0
        kind = cfg.Plots(cfg.plotIndex(cfg.SessionPlots(k).plot)).kind;
    end
    if ~any(obj.Results.Plot == id & startsWith(obj.Results.Dataset, "sessions: "))
        obj.Results(end+1, :) = {"sessions: all", id, kind, "canceled", "canceled", "", 0};
    end
end
end


function T = sessionsSummary(obj, idx)
%sessionsSummary  The "Across sessions" section's table: the run's sessions by date.
S = obj.sessionTable(idx);
T = table(S.label, S.subject, S.dateText, S.name, S.key, ...
    'VariableNames', {'Session', 'Subject', 'Date', 'Dataset', 'Key'});
end


function file = writeRunRecord(obj, idx, ids, fids, sids, started, outcome)
%writeRunRecord  What this run did and with what: <report folder>/analysis_runs/<runId>_<name>.json.
%   Schema ephys-analysis-run/1: the run id, outcome, start, end, the
%   datasets, plots, figures and session plots, the report files, the Results rows, the code and
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
    rec.figures = cellstr(fids);
    rec.sessionPlots = cellstr(sids);
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


function files = writeReports(obj, k, name)
%writeReports  Write obj.Report as HTML and / or PDF (reportFiles); {OutputFolder} = dataset K's.
%   NAME (default the dataset's name) is the per-dataset report's suffix:
%   "sessions" names the session plots' own report <FileName>_sessions.
cfg = obj.Config;
if nargin < 3; name = obj.Names(k); end
want = EphysAnalysisRunner.reportFiles(cfg, struct('OutputFolder', obj.datasetFolder(k), ...
    'OutputRoot', obj.outputRoot(), 'Root', cfg.Source.Root, 'Name', name));
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


function cancelDataset(obj, name, ids, fids)
%cancelDataset  A "canceled" row for each plot and figure of a dataset the run did not reach.
cfg = obj.Config;
for id = ids
    obj.Results(end+1, :) = {name, id, cfg.Plots(cfg.plotIndex(id)).kind, "canceled", "canceled", "", 0};
end
for id = fids
    obj.Results(end+1, :) = {name, id, "figure", "canceled", "canceled", "", 0};
end
end