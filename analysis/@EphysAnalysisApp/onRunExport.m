function R = onRunExport(obj, opts)
%onRunExport  Run the enabled figures on the ticked datasets, then the session figures: figure files and report.
%   Validates first (errors stop it), then EphysAnalysisRunner.run with a
%   cancelable progress dialog (the Export tab's and the toolbar's Cancel
%   stop it too: onCancelRun). Figures= and Datasets= narrow the run (the
%   tests use them); by default every enabled figure on every ticked
%   dataset, then every enabled session figure across them.
%   SessionFigures=, Export= and Report= are run's
%   ([] = the config's); Config= runs that config instead of the controls'
%   (gatherConfig) and Title= names the progress dialog: the Figures tab's
%   Generate (onGenerateFigure) runs one figure that way, and Unit report
%   (onUnitReport) one observation (Observation=, run's). The dialog's
%   message is the runner's (what it is on, the report's pages) and the
%   time left (ProgressClock). One run goes at a
%   time (Running): Run, Plan, Validate and Generate are off meanwhile, and
%   the previews compute nothing.
arguments
    obj (1,1) EphysAnalysisApp
    opts.Figures = []    % [] = the enabled figures; string.empty(1, 0) = none; else ids
    opts.SessionFigures = [] % likewise for the session figures (figures drawn across the datasets)
    opts.Datasets = []
    opts.Export = []     % [] = Export.Enabled
    opts.Report = []     % [] = Report.Enabled
    opts.Config = []     % an EphysAnalysisConfig to run ([] = gatherConfig)
    opts.Title (1,1) string = "Running the analysis"
    opts.Observation = [] % run's: one observation only (the Figures tab's Unit report, onUnitReport)
end
R = table();
if obj.Running; return; end
if isempty(obj.Runner)
    obj.onScan();
    if isempty(obj.Runner); return; end
end
cfg = opts.Config;
if ~isa(cfg, 'EphysAnalysisConfig'); cfg = obj.gatherConfig(); end
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
dlg = uiprogressdlg(obj.Fig, "Title", opts.Title, "Message", "Starting ...", "Cancelable", "on");
clock = ProgressClock();   % the time left, in the dialog's message
r.ProgressFcn = @(f, m) progress(r, dlg, clock, f, m);
obj.Running = true;
set([obj.RunButton obj.PlanButton obj.ValidateButton obj.FigureGenerateButton obj.FigureUnitReportButton], 'Enable', 'off');
set([obj.ToolbarRunTool obj.ToolbarPlanTool obj.ToolbarValidateTool], 'Enable', 'off');
obj.CancelButton.Enable = 'on';
obj.ToolbarCancelTool.Enable = 'on';
cleanup = onCleanup(@() finish(obj, dlg));
t0 = tic;
try
    R = r.run(Datasets=idx, Figures=opts.Figures, SessionFigures=opts.SessionFigures, ...
        Export=opts.Export, Report=opts.Report, Observation=opts.Observation);
catch ME
    obj.log("Run failed: " + string(ME.message));
    uialert(obj.Fig, "The run failed:" + newline + string(ME.message), "Run");
    return
end
obj.ResultsTable.Data = withSubjectDate(obj, R);
obj.LastReportFiles = r.ReportFiles;
obj.LastExportFolder = "";
doExport = cfg.Export.Enabled;
if ~isempty(opts.Export); doExport = logical(opts.Export); end
if doExport
    obj.LastExportFolder = figureFileName(cfg.Export.Folder, struct('OutputFolder', r.datasetFolder(idx(1)), ...
        'OutputRoot', r.outputRoot(), 'Root', cfg.Source.Root, 'Name', r.Names(idx(1))), Kind="folder");
end
sids = EphysAnalysisRunner.idList(opts.SessionFigures, @() cfg.enabledSessionFigures());
obj.OpenFolderButton.Tooltip = openFolderTip(obj, cfg, idx, sids);
obj.OpenReportButton.Enable = matlab.lang.OnOffSwitchState(~isempty(obj.LastReportFiles));
obj.OpenFolderButton.Enable = matlab.lang.OnOffSwitchState(obj.LastExportFolder ~= "" && isfolder(obj.LastExportFolder));
obj.ToolbarReportTool.Enable = obj.OpenReportButton.Enable;
obj.ToolbarFolderTool.Enable = obj.OpenFolderButton.Enable;
counts = arrayfun(@(s) nnz(R.Status == s), ["done" "skipped" "error" "canceled"]);
obj.RunLabel.Text = sprintf("Results: %d done, %d skipped, %d failed, %d canceled (%.0f s)", counts, toc(t0));
obj.setStatus(obj.RunLabel.Text);
clear cleanup
end


function progress(r, dlg, clock, fraction, message)
if ~isvalid(dlg); return; end
dlg.Value = min(max(fraction, 0), 1);
dlg.Message = char(clock.message(message, fraction));
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
obj.FigureGenerateButton.Enable = matlab.lang.OnOffSwitchState(obj.SelectedFigure >= 1 && obj.SelectedFigure <= numel(obj.Config.Figures));
obj.FigureUnitReportButton.Enable = unitReportEnable(obj);
obj.CancelButton.Enable = 'off';
obj.ToolbarCancelTool.Enable = 'off';
end


function tip = openFolderTip(obj, cfg, idx, sids)
%openFolderTip  The Open figure folder button's tooltip: the first dataset's folder, and where the session figures' files went.
tip = "The first dataset's figure folder of the last run.";
if isempty(sids); return; end
try
    r = obj.Runner;
    first = r.sessionTable(idx).index(1);
    folder = figureFileName(cfg.Export.SessionsFolder, struct('OutputFolder', r.datasetFolder(first), ...
        'OutputRoot', r.outputRoot(), 'Root', cfg.Source.Root, 'Name', r.Names(first)), Kind="folder");
    tip = tip + " The session figures' files are in " + folder + ".";
catch
    tip = tip + " The session figures' files are in the sessions folder (Export.SessionsFolder).";
end
end