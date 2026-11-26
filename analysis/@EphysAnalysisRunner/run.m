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
%   A figure with a panel whose options.yLimMode is "batch" (and the run
%   draws: Export or Report) is measured before the datasets: every
%   observation of it on every dataset of the run (batchYLimits), so its
%   pages share one y range across the whole run (r.BatchYLim; passed to
%   runDataset, whose caption says "y shared across <n> observations").
%   A session figure measures its own observations (runSessionFigure).
%
%   With the lab database on here, the run is recorded as one analysis
%   event (LabCapture.analysisRun): the files it read (each dataset's read
%   ledger, DatasetOutputs.Reads) as its inputs, its reports, run record
%   and figure files as its outputs (not the files kept from an earlier
%   run, KeptFiles); status "succeeded", or "failed" when it was canceled,
%   threw, or drew no figure because every one it tried failed. LogFcn
%   hears what was noted (the event, its status, how many inputs and
%   outputs) and which files were left out: those under no storage root
%   mapped here, and the kept ones.
%
%   A run that throws (an error, not a cancel) still ends as every run
%   does, with its run record (outcome "failed" and the error) and its lab
%   database record, both listing the figure files and reports written
%   before the error (ReportFiles grows as each report file is written);
%   then the error is rethrown. Ctrl+C is no error: it stops MATLAB
%   itself, and such a run has neither (cancel() stops a run that is
%   recorded).
%
%   The run reads Config once, when it starts, and passes that config to
%   every step (runDataset, runSessionFigure, batchYLimits: Config=; the
%   report, the run record and LabCapture.analysisRun's record): Config
%   may be set while the run goes (a ProgressFcn; EphysFigGenApp, whose
%   window stays usable meanwhile) and the run still draws, writes and
%   records the config it started with -- its figures (a figure renamed
%   meanwhile is still found), folders and file names, and the config in
%   the report, the run record and the database. The new Config is the
%   next run's. So are the user's plot design and remembered plot rules
%   (preferences, not the config): the run takes them when it starts
%   (holdPageLooks) and draws every page in them, in this MATLAB or on a
%   worker (submitPage), whatever design is chosen or look remembered
%   while it goes.
%
%   The run record (schema "ephys-analysis-run/2") holds the run id,
%   outcome (finished | canceled | failed) and error ("<identifier>:
%   <message>" of a failed run, else ""), start, end and seconds, the
%   datasets, figures and session
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
%     Observation     one observation (a struct: kind "unit" | "channel"
%                     | "dataset", data, unitId, channel, label; default
%                     [] = all): each figure is drawn only for what
%                     matches it (runDataset, figureObservations; a
%                     figure of the dataset draws the dataset), a figure
%                     with no match is "skipped" with the reason, and no
%                     session figure runs: each is a "skipped" row
%                     "sessions: all" (and, in the one report over the
%                     run, an entry under "Across sessions") saying it is
%                     drawn across the sessions, not for one dataset's
%                     observation (the app's Test report)
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

cfg = obj.Config;   % read once: every step below takes this one, whatever Config becomes while the run goes
obj.CancelRequested = false;
obj.RunRecordFile = "";
obj.PagesSeen = 0;   % usePagePool: the workers start once the run has enough pages
obj.PoolFailed = false;
obj.PageLooks = [];   % taken anew: the user's plot design and remembered plot rules as they are now
looksBack = obj.holdPageLooks(); %#ok<NASGU> every page of the run is drawn in them, here or on a worker (forgotten when it ends)
started = datetime('now');
doExport = cfg.Export.Enabled;
if ~isempty(opts.Export); doExport = logical(opts.Export); end
doReport = cfg.Report.Enabled;
if ~isempty(opts.Report); doReport = logical(opts.Report); end
fids = EphysAnalysisRunner.idList(opts.Figures, @() cfg.enabledFigures());
fids = fids(~arrayfun(@(f) cfg.isSessionFigure(f), fids));   % session figures are drawn across the datasets, not per dataset
sfids = EphysAnalysisRunner.idList(opts.SessionFigures, @() cfg.enabledSessionFigures());
sfOut = string.empty(1, 0);   % the session figures an Observation= run leaves out
if isstruct(opts.Observation)   % one dataset's observation: no figure across the sessions
    sfOut = sfids;
    sfids = string.empty(1, 0);
end
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
obj.KeptFiles = string.empty(1, 0);
for k = idx; obj.Outputs(k).clearReads(); end   % what this run reads: its inputs for the lab database
P = cfg.Report;
perDataset = doReport && P.PerDataset;
if doReport && ~perDataset
    obj.Report = newReport(cfg);
end
obj.log("Analysis ""%s"": %d dataset(s) x %d figure(s), %d session figure(s)", cfg.Name, numel(idx), numel(fids), numel(sfids));
canceled = false;
obj.BatchYLim = struct('figure', cell(1, 0), 'id', cell(1, 0), 'lim', cell(1, 0), 'n', cell(1, 0));
obj.clearBatchCache();
cacheBack = onCleanup(@() obj.clearBatchCache());   % the figures kept while measuring go with the run
quiet = LabBridge.suspend(); %#ok<NASGU>   % nothing is sent to the lab database while the run draws (labclient.Sync)
failure = [];   % the error that stopped the run (not a cancel): its run record and lab database record say so, then it is rethrown
try
    if (doExport || doReport) && ~isempty(idx)   % "batch" panels: one y range over the run's every observation, measured first
        for id = fids
            try
                spec = cfg.figureFor(id);
                if isempty(figureBatchPanels(spec)); continue; end
                obj.BatchYLim = [obj.BatchYLim obj.batchYLimits(idx, spec, Observation=opts.Observation, Config=cfg)];
            catch ME
                if ME.identifier ~= "EphysAnalysisRunner:Canceled"; rethrow(ME); end
                canceled = true;
                break
            end
        end
    end
    if canceled
        for kk = idx; cancelDataset(obj, obj.Names(kk), fids); end
        cancelSessionFigures(obj, sfids);
        obj.log("Canceled.");
        idx = idx([]);
    end
    nUnits = numel(idx) + numel(sfids) + (doReport && ~perDataset);   % the run's progress: a share per dataset, session figure and the one report
    for j = 1:numel(idx)
        k = idx(j);
        if perDataset; obj.Report = newReport(cfg); end
        try
            span = [j - 1, j] / nUnits;   % this dataset's share of the run, which its figures report within
            obj.progress(span(1), "Dataset " + obj.Names(k));
            obj.runDataset(k, Figures=fids, Export=doExport, Report=doReport, Span=span, ...
                Observation=opts.Observation, BatchYLim=obj.BatchYLim, Config=cfg);   % appends to obj.Results
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
            writeReports(obj, cfg, k, obj.Names(k), [j j] / nUnits);   % adds to obj.ReportFiles
        end
    end

    % --- session figures, after the datasets -----------------------------------------------------
    if ~canceled && ~isempty(sfids) && ~isempty(idx)
        if doReport
            if perDataset; obj.Report = newReport(cfg); end
            obj.Report = addReportSection(obj.Report, "Across sessions", Summary=struct('sessions', sessionsSummary(obj, idx, cfg)));
        end
        for i = 1:numel(sfids)
            span = [numel(idx) + i - 1, numel(idx) + i] / nUnits;
            try
                obj.progress(span(1), "Session figure " + sfids(i));
                obj.runSessionFigure(sfids(i), idx, Export=doExport, Report=doReport, Span=span, Config=cfg);   % appends to obj.Results
            catch ME
                if ME.identifier ~= "EphysAnalysisRunner:Canceled"; rethrow(ME); end
                canceled = true;
                cancelSessionFigures(obj, sfids(i:end));
                obj.log("Canceled.");
                break
            end
        end
        if perDataset && ~canceled
            writeReports(obj, cfg, idx(1), "sessions", [1 1]);
        end
    end
    if ~canceled && ~isempty(sfOut) && ~isempty(idx)
        skipSessionFigures(obj, cfg, sfOut, doReport && ~perDataset);
    end
    if doReport && ~perDataset && ~canceled && ~isempty(idx)
        writeReports(obj, cfg, idx(1), obj.Names(idx(1)), [nUnits - 1, nUnits] / nUnits);
    end
catch ME
    failure = ME;   % recorded below, with what was written before it, then rethrown
end
if ~isempty(idx)
    outcome = "finished";
    if canceled; outcome = "canceled"; end
    why = "";
    if ~isempty(failure)
        outcome = "failed";
        why = string(failure.message);
        if string(failure.identifier) ~= ""; why = string(failure.identifier) + ": " + why; end
    end
    obj.RunRecordFile = writeRunRecord(obj, cfg, idx, fids, sfids, started, outcome, why);
    try
        [~, noted] = LabCapture.analysisRun(obj, idx, Started=started, Finished=datetime('now'), Outcome=outcome, ...
            Error=why, RunRecord=obj.RunRecordFile, Config=cfg);   % for the lab database, when it is on here: the config the run started with
        logLabRecord(obj, noted);
    catch ME
        warning('EphysAnalysisRunner:LabCapture', 'The run was not noted for the lab database: %s', ME.message);
        obj.log("Lab database: the run was not noted: %s", ME.message);
    end
end
if ~isempty(failure)
    rethrow(failure);   % the caller sees the error; the files, the run record and the record are there
end
try
    obj.progress(1, "Done");
catch
end
T = obj.Results;
end


function logLabRecord(obj, noted)
%logLabRecord  Say (LogFcn) what the lab database's record of the run holds: NOTED, LabCapture.analysisRun's second output.
%   Nothing while the database is off here. The event, its status and how
%   many inputs and outputs it has (or that nothing was noted), then the
%   files it leaves out: those under no storage root mapped here, by
%   folder (their paths are in the record's unrecorded_outputs), and the
%   figure files kept from an earlier run (kept_outputs).
if noted.why == "off"; return; end
if noted.id ~= ""
    obj.log("Lab database: the run is noted as analysis event %s, status %s, %d input(s) and %d output(s); it waits in this computer's outbox until it is sent", ...
        noted.id, noted.status, noted.inputs, noted.outputs);
else
    obj.log("Lab database: nothing noted for this run: it read no file and wrote none under a storage root mapped here");
end
if ~isempty(noted.unrecorded)
    obj.log("Lab database: %d file(s) the run wrote are not recorded, being under no storage root mapped here (map one in File > Database...): in %s", ...
        numel(noted.unrecorded), folderList(noted.unrecorded));
end
if ~isempty(noted.kept)
    obj.log("Lab database: %d figure file(s) kept from an earlier run (Export.Overwrite off) are not outputs of this run: in %s", ...
        numel(noted.kept), folderList(noted.kept));
end
end


function txt = folderList(files)
%folderList  The folders FILES are in, the first three, then how many more.
d = unique(string(cellfun(@fileparts, cellstr(files), 'UniformOutput', false)), "stable");
txt = strjoin(d(1:min(3, numel(d))), ", ");
if numel(d) > 3; txt = txt + sprintf(" and %d more folder(s)", numel(d) - 3); end
end


function cancelSessionFigures(obj, sfids)
%cancelSessionFigures  A "canceled" row for each session figure not run.
for id = sfids
    if ~any(obj.Results.Plot == id & startsWith(obj.Results.Dataset, "sessions: "))
        obj.Results(end+1, :) = {"sessions: all", id, "figure", "canceled", "canceled", "", 0};
    end
end
end


function skipSessionFigures(obj, cfg, sfids, inReport)
%skipSessionFigures  A "skipped" row for each session figure an Observation= run leaves out (and, INREPORT, an entry).
%   A figure across sessions matches its observations across the datasets,
%   so it is not drawn for one dataset's observation; the report lists it
%   under "Across sessions" with that reason.
why = "it is drawn across the sessions, not for one dataset's observation";
if inReport
    obj.Report = addReportSection(obj.Report, "Across sessions");
end
for id = sfids
    obj.Results(end+1, :) = {"sessions: all", id, "figure", "skipped", why, "", 0};
    obj.log("sessions: %s skipped (%s)", id, why);
    if inReport
        k = cfg.figureIndex(id);
        if k > 0; spec = cfg.Figures(k); else; spec = EphysAnalysisConfig.defaults("Figure"); spec.id = id; end
        spec.kind = "figure";
        obj.Report = addReportFigure(obj.Report, spec, [], Status="skipped", Message=why);
    end
end
end


function T = sessionsSummary(obj, idx, cfg)
%sessionsSummary  The "Across sessions" section's table: the run's sessions by date (CFG: the run's config, its name pattern).
S = obj.sessionTable(idx, cfg);
T = table(S.label, S.subject, S.dateText, S.name, S.key, S.tags, ...
    'VariableNames', {'Session', 'Subject', 'Date', 'Dataset', 'Key', 'Tags'});
T = [T, S(:, startsWith(S.Properties.VariableNames, DatasetVariables.ColumnPrefix))];   % the datasets' variables, after Tags
end


function file = writeRunRecord(obj, cfg, idx, fids, sfids, started, outcome, why)
%writeRunRecord  What this run did and with what: <report folder>/analysis_runs/<runId>_<name>.json.
%   Schema ephys-analysis-run/2: the run id, outcome (finished | canceled |
%   failed) and error (WHY: "<identifier>: <message>" of the error that
%   stopped a failed run, "" otherwise, as the pipeline's run record
%   writes it), start, end, the
%   datasets, figures and session figures, the report files, the Results
%   rows, the files found through the lab database (fromDatabase), the
%   code and machine (ephysProvenance) and the config: CFG, the one the run
%   started with (not Config, which may have changed meanwhile). The
%   report folder is CFG's Report.Folder resolved for the first dataset, whether
%   or not a report was written. A record that cannot be written is a
%   warning, never an error.
file = "";
try
    folder = figureFileName(cfg.Report.Folder, struct('OutputFolder', obj.datasetFolder(idx(1)), ...
        'OutputRoot', obj.outputRoot(cfg), 'Root', cfg.Source.Root, 'Name', obj.Names(idx(1))), Kind="folder");
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
    rec.error = string(why);
    rec.started = string(started, "yyyy-MM-dd'T'HH:mm:ss");
    rec.finished = string(finished, "yyyy-MM-dd'T'HH:mm:ss");
    rec.seconds = seconds(finished - started);
    rec.datasets = cellstr(obj.Names(idx));
    rec.figures = cellstr(fids);
    rec.sessionFigures = cellstr(sfids);
    rec.reportFiles = cellstr(obj.ReportFiles);
    rec.results = num2cell(table2struct(obj.Results)).';
    db = struct('dataset', {}, 'files', {});   % what was found in folders the lab database named (DatasetOutputs)
    for k = reshape(idx, 1, [])
        f = obj.Outputs(k).databaseFiles();
        if ~isempty(f); db(end + 1) = struct('dataset', obj.Names(k), 'files', {cellstr(f)}); end %#ok<AGROW>
    end
    rec.fromDatabase = db;
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


function files = writeReports(obj, cfg, k, name, span)
%writeReports  Write obj.Report as HTML and / or PDF (reportFiles); {OutputFolder} = dataset K's.
%   CFG is the run's config (the one it started with): its Report section
%   and folder tokens name the files. NAME (the dataset's name for a
%   per-dataset report) is the report's
%   {Name}: "sessions" names the session figures' own report
%   <FileName>_sessions. ProgressFcn hears its pages ("Writing the report:
%   page 3/12") across SPAN, the run's fraction [from to] it has (both
%   the same: the bar stays); a cancel waits for the report to be written.
%   Each file is added to obj.ReportFiles as soon as it is written, so
%   when the next one throws (the PDF after the HTML) the run record and
%   the lab database's record still list the one on disk.
want = EphysAnalysisRunner.reportFiles(cfg, struct('OutputFolder', obj.datasetFolder(k), ...
    'OutputRoot', obj.outputRoot(cfg), 'Root', cfg.Source.Root, 'Name', name));
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
    obj.ReportFiles(end+1) = files(end);
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
