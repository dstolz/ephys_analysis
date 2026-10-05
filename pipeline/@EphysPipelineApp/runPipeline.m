function runPipeline(obj, opts)
%runPipeline  Run the pipeline (all enabled steps, or Steps=...) on the Run tab.
%   Validates first and shows the issues; blocks on errors, on blocking plan
%   rows (EphysPipeline.checkRun), on text fields that do not parse, and
%   when the scanned project is not the one under the config's root
%   (buildPipeline). Progress, results, the log and the run diagram update
%   live; Cancel stops at the next boundary. Each background Kilosort4 run
%   is handed to the monitor (KSRuns) as it starts; the runs the monitor
%   follows, going or queued, are the pipeline's PriorRuns (buildPipeline):
%   the going ones take slots of Sorting.MaxConcurrent and the sorting step
%   skips the datasets of both. With "Queue the waiting runs" ticked, the
%   sorting step writes each dataset's run files and queues the run with
%   the monitor (queueKSRun), which starts it when a slot frees, so the Run
%   goes on at once. Either way the monitor restates each background run's
%   result row when it ends (markKSResult). While the Run is under way,
%   config edits are not pushed onto the datasets it is processing (they
%   are once it ends), and Scan and the per-dataset edits are refused
%   (refuseWhileRunning).
arguments
    obj (1,1) EphysPreprocessingApp
    opts.Steps (1,:) string = string.empty(1,0)
    opts.DryRun (1,1) logical = false
end
if obj.RunActive
    uialert(obj.Fig, "A run is already in progress.", "Run");
    return
end
try
    pipe = obj.buildPipeline();   % gathers the working config
catch ME
    uialert(obj.Fig, string(ME.message), "Run");
    return
end
cfg = obj.Config;
obj.selectTab(obj.TabRun);
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
try
    pipe.checkRun(Steps=opts.Steps);   % the plan's blocking rows (duplicate outputs, "error: ...")
catch ME
    uialert(obj.Fig, string(ME.message), "Run");
    return
end

pipe.ProgressFcn = @(evt) obj.onPipelineProgress(evt);
pipe.LaunchFcn = @(run) addKSRun(obj, run);
if obj.RunKSQueueCheckBox.Value && cfg.Sorting.Execution == "background"
    pipe.QueueFcn = @(d, res) obj.queueKSRun(d, res);
end
obj.Pipe = pipe;
obj.RunActive = true;
obj.syncTabStrip();
obj.RunButton.Enable = "off"; obj.RunDryButton.Enable = "off"; obj.RunCancelButton.Enable = "on";
obj.ScanButton.Enable = "off"; obj.RefreshMetaButton.Enable = "off";
cleanup = onCleanup(@() finishRun(obj));
obj.setRunBar(obj.RunOverallBar, 0); obj.setRunBar(obj.RunStepBar, 0);
obj.RunOverallText.Text = ""; obj.RunStepText.Text = "";
obj.RunStepLabel.Text = "Starting...";
obj.RunResults = EphysPipeline.emptyResults();
obj.RunResultsTable.ColumnName = {'Step', 'Dataset', 'Status', 'Message', 'Output', 'Seconds'};
obj.RunResultsTable.ColumnWidth = {80, 'fit', 110, '1x', '2x', 64};
obj.RunResultsTable.Data = obj.RunResults;
obj.setStatus("Running the pipeline...", "");
steps = opts.Steps;
if isempty(steps); steps = cfg.enabledSteps(); end
obj.resetRunDiagram(steps, opts.DryRun);

outcome = "done"; note = "";
try
    pipe.run(Steps=opts.Steps, DryRun=opts.DryRun);
    if pipe.CancelRequested; outcome = "cancelled"; end
catch ME
    outcome = "error"; note = string(ME.message);
    obj.LastError = ME;                      % Help > Report an issue sends it with its stack
    obj.LastErrorTime = datetime('now');
    obj.runLog("ERROR: %s", ME.message);
    uialert(obj.Fig, "Run stopped:" + newline + string(ME.message), "Run");
end
R = pipe.Results;   % with the rows the monitor restated since
obj.finishRunDiagram(R, outcome, note);
obj.RunResults = R;
obj.RunResultsTable.Data = R;
obj.refreshDatasetsTable();
obj.ReviewDatasetIdx = -1;   % new sorted output: the Review tab reloads
obj.refreshSortingLabel();
obj.refreshManualArtifactsTable();
obj.refreshReferencePanel();
n = height(R);
nErr = nnz(startsWith(R.Status, "error"));
nCan = nnz(R.Status == "cancelled");
obj.RunStepLabel.Text = sprintf("Finished: %d result(s), %d error(s), %d cancelled.", n, nErr, nCan);
obj.setStatus(sprintf("Pipeline finished: %d result(s), %d error(s), %d cancelled.", n, nErr, nCan));
end


function addKSRun(obj, run)
%addKSRun  The pipeline's LaunchFcn: follow a background run from its start.
obj.KSRuns(end+1) = run;
obj.startKSMonitor();
end


function finishRun(obj)
if obj.RunDiagram.phase == "running"   % runPipeline stopped before it could close the diagram
    obj.finishRunDiagram(EphysPipeline.emptyResults(), "error", "The run stopped unexpectedly.");
end
obj.RunActive = false;
obj.Pipe = [];
if ~isempty(obj.Project) && obj.Project.NumDatasets > 0
    EphysPipeline.applyConfigToDatasets(obj.Config, obj.Project);   % the edits made during the run
end
if isvalid(obj.Fig)
    obj.RunButton.Enable = "on"; obj.RunDryButton.Enable = "on"; obj.RunCancelButton.Enable = "off";
    obj.ScanButton.Enable = "on"; obj.RefreshMetaButton.Enable = "on";
    obj.syncTabStrip();
end
end
