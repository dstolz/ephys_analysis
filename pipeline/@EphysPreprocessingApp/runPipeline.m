function runPipeline(obj, opts)
%runPipeline  Run the pipeline (all enabled steps, or Steps=...) on the Run tab.
%   Validates first and shows the issues; blocks on errors. Progress,
%   results, the log and the run diagram update live; Cancel stops at the
%   next boundary. Background Kilosort4 runs are handed to the existing
%   monitor (KSRuns).
arguments
    obj (1,1) EphysPreprocessingApp
    opts.Steps (1,:) string = string.empty(1,0)
    opts.DryRun (1,1) logical = false
end
if obj.RunActive
    uialert(obj.Fig, "A run is already in progress.", "Run");
    return
end
if isempty(obj.Project) || obj.Project.NumDatasets == 0
    uialert(obj.Fig, "Scan a project root first (Project tab).", "Run");
    return
end
obj.selectTab(obj.TabRun);
cfg = obj.gatherConfig();
obj.Config = cfg;
issues = cfg.validate();
obj.showIssues(issues);
if any(issues.Severity == "error")
    uialert(obj.Fig, "The config has errors (see the issues table on the Run tab).", "Run");
    return
end
if isempty(opts.Steps) && isempty(cfg.enabledSteps())
    uialert(obj.Fig, "No step is enabled.", "Run");
    return
end

pipe = obj.buildPipeline();
pipe.ProgressFcn = @(evt) obj.onPipelineProgress(evt);
obj.Pipe = pipe;
obj.RunActive = true;
obj.syncTabStrip();
obj.RunButton.Enable = "off"; obj.RunDryButton.Enable = "off"; obj.RunCancelButton.Enable = "on";
cleanup = onCleanup(@() finishRun(obj));
obj.setRunBar(obj.RunOverallBar, 0); obj.setRunBar(obj.RunStepBar, 0);
obj.RunOverallText.Text = ""; obj.RunStepText.Text = "";
obj.RunStepLabel.Text = "Starting...";
obj.RunResultsTable.ColumnName = {'Step', 'Dataset', 'Status', 'Message', 'Output', 'Seconds'};
obj.RunResultsTable.ColumnWidth = {80, 'fit', 110, '1x', '2x', 64};
obj.RunResultsTable.Data = EphysPipeline.emptyResults();
obj.setStatus("Running the pipeline...", "");
steps = opts.Steps;
if isempty(steps); steps = cfg.enabledSteps(); end
obj.resetRunDiagram(steps, opts.DryRun);

R = EphysPipeline.emptyResults();
outcome = "done"; note = "";
try
    R = pipe.run(Steps=opts.Steps, DryRun=opts.DryRun);
    if pipe.CancelRequested; outcome = "cancelled"; end
catch ME
    R = pipe.Results;
    outcome = "error"; note = string(ME.message);
    obj.LastError = ME;                      % Help > Report an issue sends it with its stack
    obj.LastErrorTime = datetime('now');
    obj.runLog("ERROR: %s", ME.message);
    uialert(obj.Fig, "Run stopped:" + newline + string(ME.message), "Run");
end
obj.finishRunDiagram(R, outcome, note);
obj.RunResultsTable.Data = R;
if ~isempty(pipe.LaunchedRuns)
    obj.KSRuns = [obj.KSRuns, pipe.LaunchedRuns];
    obj.startKSMonitor();
end
obj.refreshDatasetsTable();
obj.ReviewDatasetIdx = -1;   % new sorted output: the Review tab reloads
obj.refreshSortingLabel();
obj.refreshManualArtifactsTable();
n = height(R);
nErr = nnz(startsWith(R.Status, "error"));
nCan = nnz(R.Status == "cancelled");
obj.RunStepLabel.Text = sprintf("Finished: %d result(s), %d error(s), %d cancelled.", n, nErr, nCan);
obj.setStatus(sprintf("Pipeline finished: %d result(s), %d error(s), %d cancelled.", n, nErr, nCan));
end


function finishRun(obj)
if obj.RunDiagram.phase == "running"   % runPipeline stopped before it could close the diagram
    obj.finishRunDiagram(EphysPipeline.emptyResults(), "error", "The run stopped unexpectedly.");
end
obj.RunActive = false;
obj.Pipe = [];
if isvalid(obj.Fig)
    obj.RunButton.Enable = "on"; obj.RunDryButton.Enable = "on"; obj.RunCancelButton.Enable = "off";
    obj.syncTabStrip();
end
end
