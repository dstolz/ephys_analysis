function R = onRunExport(obj, opts)
%onRunExport  Run the enabled plots on the ticked datasets: figures and report.
%   Validates first (errors stop it), then EphysAnalysisRunner.run with a
%   cancelable progress dialog. Plots= and Datasets= narrow the run (the
%   tests use them); by default every enabled plot and every ticked dataset.
arguments
    obj (1,1) EphysAnalysisApp
    opts.Plots = []      % [] = the enabled plots; string.empty(1, 0) = none; else ids
    opts.Figures = []    % likewise for the figures
    opts.Datasets = []
end
R = table();
if obj.Running; return; end
if isempty(obj.Runner)
    obj.onScan();
    if isempty(obj.Runner); return; end
end
cfg = obj.gatherConfig();
issues = cfg.validate();
if any(issues.Severity == "error")
    obj.IssuesTable.Data = issues;
    obj.setStatus("The config has errors (see the table); nothing was run.");
    return
end
idx = opts.Datasets;
if isempty(idx); idx = obj.tickedDatasetIndices(); end
if isempty(idx)
    obj.setStatus("No dataset is ticked to run (Data tab).");
    return
end
r = obj.Runner;
r.Config = cfg;
dlg = uiprogressdlg(obj.Fig, "Title", "Running the analysis", "Message", "Starting ...", "Cancelable", "on");
r.ProgressFcn = @(f, m) progress(r, dlg, f, m);
obj.Running = true;
set([obj.RunButton obj.PlanButton obj.ValidateButton], 'Enable', 'off');
set([obj.ToolbarRunTool obj.ToolbarPlanTool obj.ToolbarValidateTool], 'Enable', 'off');
obj.CancelButton.Enable = 'on';
obj.ToolbarCancelTool.Enable = 'on';
cleanup = onCleanup(@() finish(obj, dlg));
t0 = tic;
try
    R = r.run(Datasets=idx, Plots=opts.Plots, Figures=opts.Figures);
catch ME
    obj.log("Run failed: " + string(ME.message));
    uialert(obj.Fig, "The run failed:" + newline + string(ME.message), "Run");
    return
end
obj.ResultsTable.Data = withSubjectDate(obj, R);
obj.LastReportFiles = r.ReportFiles;
obj.LastExportFolder = "";
if cfg.Export.Enabled
    obj.LastExportFolder = figureFileName(cfg.Export.Folder, struct('OutputFolder', r.datasetFolder(idx(1)), ...
        'OutputRoot', r.outputRoot(), 'Root', cfg.Source.Root, 'Name', r.Names(idx(1))), Kind="folder");
end
obj.OpenFolderButton.Tooltip = openFolderTip(obj, cfg, idx);
obj.OpenReportButton.Enable = matlab.lang.OnOffSwitchState(~isempty(obj.LastReportFiles));
obj.OpenFolderButton.Enable = matlab.lang.OnOffSwitchState(obj.LastExportFolder ~= "" && isfolder(obj.LastExportFolder));
obj.ToolbarReportTool.Enable = obj.OpenReportButton.Enable;
obj.ToolbarFolderTool.Enable = obj.OpenFolderButton.Enable;
counts = arrayfun(@(s) nnz(R.Status == s), ["done" "skipped" "error" "canceled"]);
obj.RunLabel.Text = sprintf("Results: %d done, %d skipped, %d failed, %d canceled (%.0f s)", counts, toc(t0));
obj.setStatus(obj.RunLabel.Text);
clear cleanup
end


function progress(r, dlg, fraction, message)
if ~isvalid(dlg); return; end
dlg.Value = min(max(fraction, 0), 1);
dlg.Message = char(message);
if dlg.CancelRequested; r.cancel(); end
drawnow limitrate;
end


function finish(obj, dlg)
if isvalid(dlg); close(dlg); end
if ~isvalid(obj); return; end
obj.Running = false;
if ~isempty(obj.Runner); obj.Runner.ProgressFcn = []; end
set([obj.RunButton obj.PlanButton obj.ValidateButton], 'Enable', 'on');
set([obj.ToolbarRunTool obj.ToolbarPlanTool obj.ToolbarValidateTool], 'Enable', 'on');
obj.CancelButton.Enable = 'off';
obj.ToolbarCancelTool.Enable = 'off';
end


function tip = openFolderTip(obj, cfg, idx)
%openFolderTip  The Open figure folder button's tooltip: the first dataset's folder, and where the session plots' figures went.
tip = "The first dataset's figure folder of the last run.";
if isempty(cfg.enabledSessionPlots()); return; end
try
    r = obj.Runner;
    first = r.sessionTable(idx).index(1);
    folder = figureFileName(cfg.Export.SessionsFolder, struct('OutputFolder', r.datasetFolder(first), ...
        'OutputRoot', r.outputRoot(), 'Root', cfg.Source.Root, 'Name', r.Names(first)), Kind="folder");
    tip = tip + " The session plots' figures are in " + folder + ".";
catch
    tip = tip + " The session plots' figures are in the sessions folder (Export.SessionsFolder).";
end
end