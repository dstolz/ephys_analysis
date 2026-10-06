function runAnalysis(obj, opts)
%runAnalysis  Run the analysis config's plots on the selected datasets: figures and report.
%   Loads Analysis.ConfigFile, an EphysAnalysisApp config, when the step
%   runs (EphysPipelineConfig.loadAnalysisConfig), so what is saved in the
%   analysis app applies to the next run, and runs it with
%   EphysAnalysisRunner over the selected datasets: its Source is replaced
%   by this project and their keys (analysisConfig), and each dataset's
%   outputs are also looked for in the Signals / Spikes / Export OutputDir
%   folders (EphysPipelineConfig.outputSearchDirs). The figure files are
%   written with Analysis.Figures and the report with Analysis.Report,
%   where and as the analysis config's Export and Report sections say; the
%   runner also writes its own run record (<report folder>/analysis_runs).
%
%   Results: one row per dataset and enabled plot, step "analysis:<plot
%   id>": done (Output: the files written), skipped (Message: why the
%   dataset cannot have that plot, plotSkipReason), error or cancelled; and
%   one "analysis:report" row per report: Dataset "" for one report over
%   every dataset, else the dataset's name (Report.PerDataset). A config
%   that cannot be loaded, and a dataset whose outputs cannot be read or
%   that the analysis does not find, are "error" rows (step "analysis");
%   the other datasets still run. Progress goes out as the "analysis" step,
%   dataset by dataset; cancel() stops before the next plot, and a report
%   over every dataset is then not written.
%
%   Options: Datasets (indices), DryRun (writes nothing: "dry run" rows say
%   what each plot and report would write; see analysisTargets).
%
%   Needs the analysis module (the repository's analysis folder) on the path.
%
%   See also EphysAnalysisRunner, EphysAnalysisConfig, EphysPipeline.analysisTargets.

arguments
    obj (1,1) EphysPipeline
    opts.Datasets (1,:) double = []
    opts.DryRun (1,1) logical = false
end

A = obj.Config.Analysis;
idx = opts.Datasets;
if isempty(idx); idx = obj.DatasetIdx; end
ds = obj.Project.Datasets(idx);
n = numel(ds);
if n == 0; return; end
if obj.CancelRequested
    for d = ds; obj.addResult("analysis", d.Name, "cancelled", "not run"); end
    error('EphysPipeline:Cancelled', 'Cancelled by user.');
end
t0 = tic;

obj.progress("analysis", ds(1).Name, 1, n, 0, 1, "reading the analysis config");
[acfg, msg] = obj.analysisConfig(idx);
if isempty(acfg)
    obj.log("[analysis] ERROR %s", msg);
    for d = ds; obj.addResult("analysis", d.Name, "error", msg, A.ConfigFile, toc(t0)); end
    return
end
ids = acfg.enabledPlots();
obj.log("[analysis] ""%s"" (%s): %d plot(s) on %d dataset(s)", acfg.Name, A.ConfigFile, numel(ids), n);

if opts.DryRun
    T = obj.analysisTargets(acfg, idx);
    for r = 1:height(T)
        if startsWith(T.Status(r), "error")
            obj.addResult(T.Step(r), T.Dataset(r), "error", T.Note(r), T.Output(r), 0);
        else
            obj.addResult(T.Step(r), T.Dataset(r), "dry run", "would write: " + T.Note(r), T.Output(r), 0);
        end
    end
    obj.log("[analysis] dry run: %d plot(s) x %d dataset(s)%s", numel(ids), n, ...
        ternary(A.Report, ", and the report", ""));
    return
end

% The runner scans the project root again and keeps the selected keys (a
% key it does not find is an error row below, not a warning).
ws = warning('off', 'EphysAnalysisRunner:UnknownDataset');
try
    runner = EphysAnalysisRunner(acfg, LogFcn=@(m) obj.log("[analysis] %s", m), ...
        SearchDirs=EphysPipelineConfig.outputSearchDirs(obj.Config));
    warning(ws);
catch scanErr
    warning(ws);
    obj.log("[analysis] ERROR %s", scanErr.message);
    for d = ds; obj.addResult("analysis", d.Name, "error", string(scanErr.message), "", toc(t0)); end
    return
end

% Each dataset's outputs are read first, so one that cannot be read is an
% error row of its own rather than the end of the whole analysis.
keys = obj.Project.datasetKeys();
keys = keys(idx);
runIdx = zeros(1, 0);   % indices into runner.Outputs, in the pipeline's order
for k = 1:n
    at = find(runner.Keys == keys(k), 1);
    if isempty(at)
        obj.addResult("analysis", ds(k).Name, "error", ...
            "the analysis found no dataset " + keys(k) + " under " + obj.Config.Project.Root, "", 0);
        continue
    end
    obj.progress("analysis", ds(k).Name, 1, n, 0, 1, "reading its outputs");   % before the first dataset's plots: the bar stays at 0
    try
        runner.source(at);
        runIdx(end+1) = at; %#ok<AGROW>
    catch readErr
        if strcmp(readErr.identifier, 'EphysPipeline:Cancelled'); rethrow(readErr); end
        obj.log("[analysis] %s: ERROR reading its outputs: %s", ds(k).Name, readErr.message);
        obj.addResult("analysis", ds(k).Name, "error", "its outputs could not be read: " + string(readErr.message), ...
            string(ds(k).outputFolder()), 0);
    end
end
if isempty(runIdx); return; end

runner.ProgressFcn = @onProgress;
failure = [];
try
    R = runner.run(Datasets=runIdx, Export=A.Figures, Report=A.Report);
catch runErr
    failure = runErr;
    R = runner.Results;
end
for r = 1:height(R)
    obj.addResult("analysis:" + R.Plot(r), R.Dataset(r), R.Status(r), R.Message(r), R.Files(r), R.Seconds(r));
end
if A.Report
    addReportRows();
end
if ~isempty(failure)
    obj.log("[analysis] ERROR %s", failure.message);
end
if obj.CancelRequested
    error('EphysPipeline:Cancelled', 'Cancelled by user.');
end


    function onProgress(frac, message)
        %onProgress  The runner's progress (a fraction of its whole run) as
        %   the pipeline's: dataset jj of the mm it analyses, how far through it.
        if obj.CancelRequested
            runner.cancel();   % the runner stops before its next plot, records the rest "cancelled"
            return
        end
        mm = numel(runIdx);
        jj = min(mm, floor(frac * mm + 1e-9) + 1);
        dsName = runner.Names(runIdx(jj));
        message = string(message);
        if startsWith(message, "Dataset ")
            message = "starting";
        elseif startsWith(message, dsName + ": ")
            message = "plot " + extractAfter(message, dsName + ": ");
        end
        try
            obj.progress("analysis", dsName, jj, mm, min(max(frac * mm - (jj - 1), 0), 1), 1, message);
        catch progressErr
            if ~strcmp(progressErr.identifier, 'EphysPipeline:Cancelled'); rethrow(progressErr); end
            runner.cancel();
        end
    end


    function addReportRows()
        %addReportRows  One row per report the runner wrote, or why it wrote none.
        rep = acfg.Report;
        if ~isempty(failure)
            obj.addResult("analysis:report", "", "error", string(failure.message), strjoin(runner.ReportFiles, "; "), 0);
            return
        end
        stopped = any(R.Status == "cancelled");
        if ~rep.PerDataset
            if stopped
                obj.addResult("analysis:report", "", "cancelled", "not written: the run was cancelled", "", 0);
            else
                obj.addResult("analysis:report", "", "done", sprintf("%s report over %d dataset(s)", ...
                    formatText(rep.Format), numel(runIdx)), strjoin(runner.ReportFiles, "; "), 0);
            end
            return
        end
        for jr = runIdx
            want = EphysAnalysisRunner.reportFiles(acfg, struct('OutputFolder', runner.datasetFolder(jr), ...
                'OutputRoot', runner.outputRoot(), 'Root', acfg.Source.Root, 'Name', runner.Names(jr)));
            written = want(ismember(want, runner.ReportFiles));
            if ~isempty(written)
                obj.addResult("analysis:report", runner.Names(jr), "done", formatText(rep.Format) + " report of this dataset", ...
                    strjoin(written, "; "), 0);
            elseif stopped
                obj.addResult("analysis:report", runner.Names(jr), "cancelled", "not written: the run was cancelled", "", 0);
            end
        end
    end
end


function t = formatText(fmt)
%formatText  "HTML", "PDF" or "HTML + PDF" for Report.Format.
t = upper(replace(string(fmt), "both", "html + pdf"));
end


function out = ternary(cond, a, b)
if cond; out = string(a); else; out = string(b); end
end
