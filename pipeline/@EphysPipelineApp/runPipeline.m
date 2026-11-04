function runPipeline(obj, opts)
%runPipeline  Run the pipeline (all enabled steps, or Steps=...) on the Run tab.
%   Validates first and shows the issues; blocks on errors, on blocking plan
%   rows (EphysPipeline.checkRun), on text fields that do not parse, and
%   when the scanned project is not the one under the config's root
%   (buildPipeline). Progress, results, the log and the run diagram update
%   live: the results table gains each row as the pipeline records it
%   (onPipelineProgress), and a row the monitor restates meanwhile shows at
%   once (markKSResult). Cancel stops at the next boundary. Each background
%   Kilosort4 run is handed to the monitor (KSRuns) as it starts; the runs
%   the monitor follows, going or queued, are the pipeline's PriorRuns
%   (buildPipeline): the going ones take slots of Sorting.MaxConcurrent and
%   the sorting step skips the datasets of both. With "Queue the waiting runs" ticked, the
%   sorting step writes each dataset's run files and queues the run with
%   the monitor (queueKSRun), which starts it when a slot frees, so the Run
%   goes on at once. Either way the monitor restates each background run's
%   result row when it ends (markKSResult). While the Run is under way,
%   config edits are not pushed onto the datasets it is processing (they
%   are once it ends), and Scan and the per-dataset edits are refused
%   (refuseWhileRunning). With Copy outputs on (the Transfer section), the
%   pipeline's output transfer is followed from its start
%   (followTransfer): the Run does not wait for it, and the copies go on in
%   the background after the Run, their progress in the tab's last row. A
%   Run is refused while an earlier Run's move is still going, since the
%   move removes the outputs it took once they are copied. With Copy files
%   for the analysis app on (the AnalysisCopy section), a Run that ran to
%   its end and was not a dry run copies the files EphysFigGenApp reads,
%   with the settings last used in the copy window, once its steps are over
%   (copyAnalysisFilesAfterRun); the Run is refused up front when that
%   window never had a destination chosen.
%
%   Before a run (not a rehearsal) the app asks "Run <steps> on <n>
%   datasets?" with Run, Show plan and Cancel (confirmRun; its "Don't ask
%   again" box is the preference ConfirmRun). Confirm=false skips the
%   question (the tests, scripts). A run that ends with datasets that
%   failed says which, with a button to the results and one to the log.
%   Closing the app during a run asks first (onClose).
arguments
    obj (1,1) EphysPipelineApp
    opts.Steps (1,:) string = string.empty(1,0)
    opts.DryRun (1,1) logical = false
    opts.Confirm (1,1) logical = true
end
if obj.RunActive
    AppDialog.alert(obj.Fig, "A run is already in progress. Wait for it to finish, or press Cancel.", "Run", "Icon", "warning");
    return
end
moving = obj.Transfers(arrayfun(@(X) X.Method == "move" && ~X.Done, obj.Transfers));
if ~isempty(moving)
    AppDialog.alert(obj.Fig, "The outputs of the last Run are still being moved to " + moving(1).Destination + ...
        ", and the move removes them here once they are copied. Wait for it to finish (the last row of the Run tab), " + ...
        "or stop it with Stop copying..., before running again.", "Run", "Icon", "warning");
    return
end
try
    pipe = obj.buildPipeline();   % gathers the working config
catch ME
    if ME.identifier == "EphysPipelineApp:NoProject"
        obj.alertNoProject("Run");
    else
        obj.reportFailure("Run", "start the run", "", ME, "fix what the message names, then press Run pipeline again");
    end
    return
end
cfg = obj.Config;
obj.selectTab(obj.TabRun);
issues = cfg.validate();
obj.showIssues(issues);
if any(issues.Severity == "error")
    bad = issues(issues.Severity == "error", :);
    AppDialog.alert(obj.Fig, sprintf("The config has %d error(s), so nothing was run. The first: %s > %s: %s", ...
        height(bad), bad.Step(1), bad.Field(1), bad.Message(1)) + newline + ...
        "The issues table on the Run tab lists them all; double-click a row to go to the setting.", "Run", "Icon", "error");
    return
end
if isempty(opts.Steps) && isempty(cfg.enabledSteps())
    AppDialog.alert(obj.Fig, "No step is switched on. Tick the steps to run in the Steps list of the Run tab, then press Run pipeline.", ...
        "Run", "Icon", "warning");
    return
end
try
    pipe.checkRun(Steps=opts.Steps);   % the plan's blocking rows (duplicate outputs, "error: ...")
catch ME
    obj.reportFailure("Run", "start the run", "", ME, "press Show plan to see the rows that block it, and fix them");
    return
end

copyForAnalysis = cfg.AnalysisCopy.Enabled && ~opts.DryRun;   % a dry run makes no files
if copyForAnalysis && ~OutputTransfer.isFullPath(AnalysisCopyDialog.settings().Destination)
    AppDialog.alert(obj.Fig, "Copy files for the analysis app is on, but no destination folder was chosen. " + ...
        "Choose it in File > Copy files for the analysis app... and close that window to keep it, then run again.", "Run", "Icon", "warning");
    return
end
steps = opts.Steps;
if isempty(steps); steps = cfg.enabledSteps(); end
if opts.Confirm && ~opts.DryRun
    choice = obj.confirmRun(steps, numel(obj.selectedDatasetIndices()));
    if choice == "plan"
        obj.onPlan();
        return
    elseif choice ~= "run"
        obj.setStatus("Run canceled: nothing was run.", "");
        return
    end
end

pipe.ProgressFcn = @(evt) obj.onPipelineProgress(evt);
pipe.LaunchFcn = @(run) addKSRun(obj, run);
pipe.TransferFcn = @(X) obj.followTransfer(X);
pipe.TransferWait = false;   % the copies go on in the background; the Run tab follows them
if obj.RunKSQueueCheckBox.Value && cfg.Sorting.Execution == "background"
    pipe.QueueFcn = @(d, res) obj.queueKSRun(d, res);
end
obj.Pipe = pipe;
obj.RunActive = true;
obj.syncTabStrip();
obj.RunButton.Enable = "off"; obj.RunDryButton.Enable = "off"; obj.RunCancelButton.Enable = "on";
obj.ToolbarRunTool.Enable = "off"; obj.ToolbarDryRunTool.Enable = "off"; obj.ToolbarCancelTool.Enable = "on";
obj.ScanButton.Enable = "off"; obj.RefreshMetaButton.Enable = "off";
cleanup = onCleanup(@() finishRun(obj));
obj.setRunBar(obj.RunOverallBar, 0); obj.setRunBar(obj.RunStepBar, 0);
obj.RunOverallText.Text = ""; obj.RunStepText.Text = "";
obj.RunStepLabel.Text = "Starting...";
obj.RunTimeLabel.Text = ""; obj.RunStepClock = []; obj.RunClockStep = "";
obj.RunResults = EphysPipeline.emptyResults();
obj.showRunResults(obj.RunResults);
obj.setStatus("Running the pipeline...", "");
obj.resetRunDiagram(steps, opts.DryRun);

outcome = "done"; note = "";
try
    pipe.run(Steps=opts.Steps, DryRun=opts.DryRun);
    if pipe.CancelRequested; outcome = "canceled"; end
catch ME
    outcome = "error"; note = string(ME.message);
    obj.reportFailure("Run", "finish the run", "", ME, ...
        "fix the cause named above, then press Run pipeline again; the Results table shows what finished before it stopped");
end
R = pipe.Results;   % with the rows the monitor restated since
obj.finishRunDiagram(R, outcome, note);
obj.RunResults = R;
obj.showRunResults(R);
obj.refreshDatasetsTable();
obj.ReviewDatasetIdx = -1;   % new sorted output: the Review tab reloads
obj.refreshSortingLabel();
obj.refreshManualArtifactsTable();
obj.refreshReferencePanel();
n = height(R);
nErr = nnz(startsWith(R.Status, "error"));
nCan = nnz(R.Status == "canceled");
obj.RunStepLabel.Text = sprintf("Finished: %d result(s), %d error(s), %d canceled.", n, nErr, nCan);
obj.RunTimeLabel.Text = "";   % the diagram says how long it took
obj.RunStepClock = [];
obj.setStatus(sprintf("Pipeline finished: %d result(s), %d error(s), %d canceled.", n, nErr, nCan));
if nErr > 0 && outcome ~= "error"   % a run that threw has told its cause already (reportFailure)
    obj.alertFailedDatasets(R);
end
if copyForAnalysis && outcome == "done"
    try
        obj.copyAnalysisFilesAfterRun(pipe);
    catch ME
        obj.runLog("[analysis copy] not made: %s", ME.message);
    end
end
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
obj.RunningDatasetIdx = 0;
if isvalid(obj.Fig); obj.highlightDatasetRow(); end
if ~isempty(obj.Project) && obj.Project.NumDatasets > 0
    EphysPipeline.applyConfigToDatasets(obj.Config, obj.Project);   % the edits made during the run
end
if isvalid(obj.Fig)
    obj.RunButton.Enable = "on"; obj.RunDryButton.Enable = "on"; obj.RunCancelButton.Enable = "off";
    obj.ToolbarRunTool.Enable = "on"; obj.ToolbarDryRunTool.Enable = "on"; obj.ToolbarCancelTool.Enable = "off";
    obj.ScanButton.Enable = "on"; obj.RefreshMetaButton.Enable = "on";
    obj.syncTabStrip();
end
end
